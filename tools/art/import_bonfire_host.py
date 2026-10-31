"""派对主人定向美术导入：保留生成源图，复用公主像素化器，输出原动画／立绘格式。
源图网格及状态映射写在此处；不会修改两位公主或其他镇民。
--hd：高清（非像素）版——同一批源图、同样的排法，不做像素化（平滑缩小），格子放大 K=3 倍，写 bonfire_host_hd.png /
  bonfire_host_magic_hd.png / bonfire_host_attack_hd.png（原像素图不动；游戏里按 UserSettings.art_style 切换，见 SpriteSheetAnimator）。
"""
from pathlib import Path
import json
import argparse
from PIL import Image, ImageDraw
import numpy as np
from import_princess2 import Pixelizer, SpritePixelizer
from import_sprites_v2 import _even_cuts
from import_portraits_v2 import key_white

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'tools/art/src/bonfire_host'
OUT=ROOT/'assets/generated'
META=json.loads((ROOT/'data/actors/princess_visuals.json').read_text())
STATES=META['order']; MAGIC=META['magic_order']
FACE=[0.22,0.02,0.78,0.48]
## 高清版的倍数和文件名后缀（--hd 时 K=3、SUFFIX="_hd"）
K=1
SUFFIX=""
PORTRAIT_SRC=OUT/'bonfire_host_portraits'
PORTRAIT_MAP=[('portraits1.PNG',['normal','happy','sad','surprise','angry','shy','chant','burst']),
              ('portraits2.PNG',['giggle','damaged','damaged_giggle','helpless_1','helpless_2','damaged_chant','damaged_giggle_chant','damaged_burst'])]
HEAD_RECTS=[[(116,16,252,169),(484,12,623,169),(869,85,1003,238),(1275,12,1414,173),
             (115,509,254,667),(487,504,620,663),(868,505,1005,666),(1260,503,1393,672)],
            [(76,21,236,195),(470,22,635,203),(816,79,986,270),(1158,64,1340,262),
             (37,666,200,852),(493,555,650,744),(824,565,996,751),(1186,559,1357,760)]]

def supplied_portraits():
    """用户白底原图只裁切导入；第二表逐行边界避开标签及横卧人物伸出的脚。"""
    source={}
    for file,names in PORTRAIT_MAP:
        im=Image.open(PORTRAIT_SRC/file).convert('RGB')
        rows=[(0,496,[0,385,751,1158,1586]),(496,992,[0,390,752,1155,1586])] if file=='portraits1.PNG' else [
            (0,497,[0,362,722,1078,1448]),(550,1009,[0,391,735,1084,1448])]
        for r,(top,bottom,xs) in enumerate(rows):
            for col in range(4):
                cell=key_white(np.asarray(im.crop((xs[col],top,xs[col+1],bottom))).astype(np.int32))
                bounds=cell.getbbox()
                if bounds is None: raise ValueError(f'Empty portrait: {file} {r} {col}')
                source[names[r*4+col]]=cell.crop(bounds)
    source['damaged_giggle_burst']=source['damaged_burst'].copy()
    return source

def grid(file,cols,rows):
    image=Image.open(SRC/file).convert('RGBA')
    alpha=np.asarray(image.getchannel('A'))>=128
    xs=_even_cuts(alpha.sum(0),0,image.width,[1]*cols,window=0.22)
    ys=_even_cuts(alpha.sum(1),0,image.height,[1]*rows,window=0.3)
    cells=[]
    for y in range(rows):
        for x in range(cols):
            c=image.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
            # 生成工具保留了alpha，去除alpha极低的边缘噪点，不做背景抠图或替换。
            c.putalpha(c.getchannel('A').point(lambda a: 255 if a>=128 else 0))
            b=c.getbbox()
            if b is None: raise ValueError(f'Empty source cell: {file} {x} {y}')
            cells.append(c.crop(b))
    return cells

def sprite_cells(cells,size=32,fit=None):
    size*=K
    fit=size-4*K if fit is None else fit*K
    scale=min(fit/max(c.height for c in cells),fit/max(c.width for c in cells))
    if K>1:
        # 高清：平滑缩小（预乘 alpha），不像素化
        output=[]
        for c in cells:
            s=c.convert('RGBa').resize((max(1,round(c.width*scale)),max(1,round(c.height*scale))),Image.Resampling.LANCZOS).convert('RGBA')
            frame=Image.new('RGBA',(size,size))
            frame.alpha_composite(s,((size-s.width)//2,size-s.height-K))
            output.append(frame)
        return output
    keyed={('normal',i):c for i,c in enumerate(cells)}
    faces={key:FACE for key in keyed}
    px=SpritePixelizer(keyed,colors=64,eye_colors=8,face_boxes=faces)
    # 每张源表统一比例：保持同组帧的身体尺寸和步态，底部对齐。
    smalls=[px.downscale(c,scale,FACE) for c in cells]
    px.build_palette(smalls)
    output=[]
    for c in smalls:
        c=px.finish(c)
        frame=Image.new('RGBA',(size,size))
        frame.alpha_composite(c,((size-c.width)//2,size-c.height-1))
        output.append(frame)
    return output

def portraits():
    by_state=supplied_portraits()
    heads_by_state={}
    for (file,names),rects in zip(PORTRAIT_MAP,HEAD_RECTS):
        original=Image.open(PORTRAIT_SRC/file).convert('RGB')
        for name,rect in zip(names,rects):
            heads_by_state[name]=key_white(np.asarray(original.crop(rect)).astype(np.int32))
    heads_by_state['damaged_giggle_burst']=heads_by_state['damaged_burst'].copy()
    source=[by_state[name] for name in STATES+MAGIC]
    # 坐姿和横卧姿势独立取景，头像不能包含膝盖或偏到举起的灯笼。
    boxes={name:[.18,0,.80,.38] for name in STATES+MAGIC}
    boxes.update(helpless_1=[.22,0,.75,.46],helpless_2=[.02,.02,.53,.55],damaged_giggle=[.20,0,.78,.42])
    faces=[boxes[name] for name in STATES+MAGIC]
    px=Pixelizer(source,128,faces)
    sheet=Image.new('RGBA',(228*17,304)); heads=Image.new('RGBA',(64*17,64))
    for i,c in enumerate(source):
        scale=min(224/c.width,300/c.height)
        small=px(c,scale,faces[i])
        frame=Image.new('RGBA',(228,304))
        frame.alpha_composite(small,((228-small.width)//2,302-small.height))
        sheet.alpha_composite(frame,(228*i,0))
        # 头像围绕人物面部裁切，不把灯笼当中心。
        head=heads_by_state[(STATES+MAGIC)[i]].copy()
        head.thumbnail((62,62),Image.Resampling.LANCZOS)
        cell=Image.new('RGBA',(64,64));cell.alpha_composite(head,((64-head.width)//2,(64-head.height)//2))
        heads.alpha_composite(cell,(64*i,0))
    sheet.save(OUT/'portraits_bonfire_host.png');heads.save(OUT/'portrait_heads_bonfire_host.png')

def sprites(daily,portrait_extra):
    walk=sprite_cells(grid('walk.png',4,4))
    idle=sprite_cells(daily)
    extra=sprite_cells(grid('sprite_extras.png',4,5))
    seated=sprite_cells([portrait_extra[4]])[0]
    F=32*K
    sheet=Image.new('RGBA',(512*K,352*K))
    # 六个基础表情沿用蓝色公主方式：真实四向步态，正面待机换表情。
    base_indices=[0,1,2,3,4,5]
    for row in range(6):
        for d in range(4):
            for f in range(4):
                c=walk[d*4+f].copy()
                if d==0 and f==0:c=idle[base_indices[row]]
                sheet.alpha_composite(c,((d*4+f)*F,row*F))
    for r in range(5):
        for d in range(4):
            for f in range(4):
                if r==4:
                    # 生成源的末行没有完整坐姿，使用完整坐姿立绘做上身轻摇的四相位。
                    c=seated.copy()
                    upper=c.crop((0,0,F,23*K)).rotate([0,3,0,-3][f],Image.Resampling.NEAREST if K==1 else Image.Resampling.BICUBIC,expand=False)
                    c.paste((0,0,0,0),(0,0,F,23*K));c.alpha_composite(upper)
                elif r==3:
                    # 笑到失控的四相位沿用公主布局，方向共享动作帧。
                    c=extra[r*4+f]
                else:
                    c=extra[r*4+d].copy()
                    # 上身表情姿势 + 已生成的真实腿部步态，不能以整帧平移冒充走路。
                    if f!=0:
                        c.paste((0,0,0,0),(0,24*K,F,F))
                        c.alpha_composite(walk[d*4+f].crop((0,24*K,F,F)),(0,24*K))
                sheet.alpha_composite(c,((d*4+f)*F,(r+6)*F))
    sheet.save(OUT/f'bonfire_host{SUFFIX}.png')
    if K==1:
        # 普通镇民兼容图只有像素版
        compatibility=Image.new('RGBA',(128,128))
        for d in range(4): compatibility.alpha_composite(sheet.crop((d*128,0,(d+1)*128,32)),(0,d*32))
        (OUT/'npcs').mkdir(exist_ok=True)
        compatibility.save(OUT/'npcs/bonfire_host.png')
    # 主生成表实际为五行；第六行单独生成，不能按六行均分造成切帧错位。
    main_magic=grid('sprite_magic.png',6,5)
    last_magic=grid('sprite_magic_last.png',3,2)
    # 补图的源分辨率更高；先按同组中位高度归一，不能让最后一行把前五行压小。
    ratio=float(np.median([c.height for c in main_magic]))/float(np.median([c.height for c in last_magic]))
    last_magic=[c.resize((round(c.width*ratio),round(c.height*ratio)),Image.Resampling.LANCZOS) for c in last_magic]
    # 48格留出特效空间，本体不随格子放大到44像素，保持接近32格行走人物的比例。
    magic=sprite_cells(main_magic+last_magic,48,fit=32)
    magic_sheet=Image.new('RGBA',(288*K,288*K))
    for i,c in enumerate(magic):magic_sheet.alpha_composite(c,((i%6)*48*K,(i//6)*48*K))
    magic_sheet.save(OUT/f'bonfire_host_magic{SUFFIX}.png')
    attack=sprite_cells(grid('sprite_attack.png',3,4))
    attack_sheet=Image.new('RGBA',(384*K,352*K))
    for row in range(11):
        for i,c in enumerate(attack):
            frame=c.copy()
            if row in (6,8) and K==1:
                # 同一攻击动作的轻微尘痕，不换衣服或鞋。
                ImageDraw.Draw(frame).point((14,24),fill=(175,115,80,255))
            attack_sheet.alpha_composite(frame,(i*32*K,row*32*K))
    attack_sheet.save(OUT/f'bonfire_host_attack{SUFFIX}.png')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--portraits-only',action='store_true')
    parser.add_argument('--hd',action='store_true')
    args=parser.parse_args()
    if args.hd:
        # 只写高清精灵图集（立绘、像素图、manifest 都不动）
        global K,SUFFIX
        K,SUFFIX=3,'_hd'
        sprites(grid('portraits_daily.png',3,2),grid('portraits_extra.png',3,2))
        print('派对主人高清精灵图：bonfire_host_hd.png / bonfire_host_magic_hd.png / bonfire_host_attack_hd.png')
        return
    portraits()
    # 地图精灵继续使用旧美术源；不能将新全身立绘混入旧步态。
    if not args.portraits_only: sprites(grid('portraits_daily.png',3,2),grid('portraits_extra.png',3,2))
    manifest={'_说明':'import_bonfire_host.py；立绘来自用户提供的两张PNG，精灵沿用原imagegen源图；非运行时配置。','states':STATES,'magic':MAGIC,'portrait_cell':[228,304], 'head':64,'density':2,
              'source_grids':{'walk':[4,4],'sprite_extras':[4,5],'sprite_magic':[6,5],'sprite_magic_last':[3,2],'sprite_attack':[3,4],'portraits_daily':[3,2],'portraits_extra':[3,2],'portraits_magic':[3,2],'portraits_damaged_barefoot':[3,2]},
              'portrait_sources':dict(PORTRAIT_MAP),'portrait_alias':{'damaged_giggle_burst':'damaged_burst'},
              'barefoot_portraits':['damaged','damaged_giggle','helpless_1','helpless_2','damaged_chant','damaged_giggle_chant','damaged_burst','damaged_giggle_burst']}
    (SRC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('派对主人新立绘与头像导入完成；精灵独立保留原源图')

if __name__=='__main__':main()
