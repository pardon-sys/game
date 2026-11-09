"""旧王宫的新素材（codex 画的白底大图 → 游戏里的像素图；提示词 tools/art/src/palace_sprites/prompts.md）：
  doll_maid_sheet.png    → assets/generated/npcs/doll_maid.png   人偶女仆，4x4 格、每格 32x32（同 npcs/guard.png 的排法：下 / 左 / 右 / 上 各 4 帧）
  palace_statue_sheet.png → assets/generated/palace_statue.png   浴场雕像，3 帧横排、每帧 32x48（站着 / 发光预警 / 弯腰刷）
  clock_keeper_sheet.png → assets/generated/npcs/clock_keeper.png  守钟人偶，4x4 格、每格 32x32（同人偶女仆）
  portrait_boss_sheet.png → assets/generated/portrait_boss.png     王座间的大画像，3 帧横排、每帧 64x88（完好 / 裂开伸手 / 烧穿）
  small_portrait_sheet.png → assets/generated/small_portrait.png   墙上的小画像，2 帧横排、每帧 28x36（睡着 / 醒了伸手）
  exit_markers_sheet.png → assets/generated/exit_markers.png       反省篇出口标记，5 帧、每帧 40x40（上楼梯 / 下楼梯 / 门 / 墙洞 / 梯子）
  clock_props_sheet.png → assets/generated/clock_props.png         钟楼道具，6 帧、每帧 48x56（齿轮 / 钟摆 / 风箱 / 钟 / 钟绳 / 宝箱）
  palace_misc_sheet.png → assets/generated/palace_misc.png         仆人回廊，3 帧、每帧 24x32（唤人铃 / 钥匙 / 小牌子）
  head_maid_sheet.png → assets/generated/npcs/head_maid.png        女仆长，4x4 格、每格 32x32
做法：白底抠掉（和边缘连通的白）→ 按格子切 → 每格取最大的人物块 → 等比缩到格子里（脚底对齐底边）→ 减色 + 1px 深色描边。
用法：python tools/art/gen_palace_sprites.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/art/src/palace_sprites"
OUT = ROOT / "assets/generated"
OUTLINE = (34, 22, 36, 255)


def key_white(img):
    """抠底：四个角是洋红（#FF00FF）就按洋红抠（画面里所有洋红都去掉，包括被围住的；再把洋红溢色的半透明边去掉）；
    否则按白底抠（只去掉和边缘连通的白）。"""
    rgb = np.asarray(img.convert("RGB")).astype(np.int32)
    corners = np.array([rgb[0, 0], rgb[0, -1], rgb[-1, 0], rgb[-1, -1]])
    if ((corners[:, 0] > 180) & (corners[:, 1] < 90) & (corners[:, 2] > 180)).sum() >= 3:
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        mag = (r > 140) & (b > 140) & (g < 120) & (np.abs(r - b) < 100)
        # 洋红边缘的过渡色（偏紫、偏粉的描边外圈）：和洋红相邻、绿色明显偏低的也去掉
        near = ndimage.binary_dilation(mag, iterations=2)
        fringe = near & (g < np.minimum(r, b) - 60) & (r > 100) & (b > 100)
        alpha = np.where(mag | fringe, 0, 255).astype(np.uint8)
        return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")
    bg = rgb.min(2) > 225
    lab, _ = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    alpha = np.where(np.isin(lab, list(border)), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")


def biggest(cell):
    a = np.asarray(cell.getchannel("A")) > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n == 0:
        return cell
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = sizes >= sizes.max() * 0.12   # 去掉零散的小碎块（气泡、纸片、动作线）
    mask = np.isin(lab, [i + 1 for i in range(n) if keep[i]])
    ys, xs = np.where(mask)
    out = np.asarray(cell).copy()
    out[..., 3] = np.where(mask, out[..., 3], 0)
    return Image.fromarray(out, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def _shrink(fig, s):
    """面积平均缩小（预乘 alpha，边缘不发白）+ 稍微提一点饱和度和对比（缩小以后颜色容易发灰）"""
    from PIL import ImageEnhance
    a = np.asarray(fig).astype(np.float32)
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4] / 255.0
    size = (max(1, round(fig.width * s)), max(1, round(fig.height * s)))
    small = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA").resize(size, Image.BOX)).astype(np.float32)
    al = small[..., 3:4]
    small[..., :3] = np.where(al > 0, small[..., :3] * 255.0 / np.maximum(al, 1), 0)
    img = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA")
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(1.35)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.15)
    return Image.fromarray(np.dstack([np.asarray(rgb), np.asarray(img.getchannel("A"))]), "RGBA")


def fit(fig, w, h, pad=1, scale=None):
    s = scale if scale else min((w - 2 * pad) / fig.width, (h - 2 * pad) / fig.height)
    small = _shrink(fig, s)
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    small = Image.fromarray(a, "RGBA")
    cell = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cell.alpha_composite(small, ((w - small.width) // 2, h - small.height - pad))
    return outline(cell)


def outline(img):
    a = np.asarray(img).copy()
    solid = a[..., 3] > 0
    grown = ndimage.binary_dilation(solid, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
    edge = grown & ~solid
    a[edge] = OUTLINE
    return Image.fromarray(a, "RGBA")


def quantize(sheet, colors=48):
    rgb = sheet.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.asarray(rgb), np.asarray(sheet.getchannel("A"))])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def grid_cells(img, cols, rows):
    """按人物的空白间隙切成 cols x rows 格（每行先按行的空白切，再按列的空白切；切不出来就均分）"""
    a = np.asarray(img.getchannel("A")) > 0
    def cuts(occ, n):
        idx = np.where(occ > 0)[0]
        if len(idx) == 0:
            return [round(i * len(occ) / n) for i in range(n + 1)]
        lo, hi = idx[0], idx[-1] + 1
        step = (hi - lo) / n
        out = [lo]
        for i in range(1, n):
            c = round(lo + step * i)
            win = range(max(lo, c - round(step * 0.3)), min(hi, c + round(step * 0.3)))
            out.append(min(win, key=lambda x: occ[x]) if len(win) else c)
        out.append(hi)
        return out
    ys = cuts(a.sum(1), rows)
    cells = []
    for r in range(rows):
        band = a[ys[r]:ys[r + 1]]
        xs = cuts(band.sum(0), cols)
        for c in range(cols):
            cells.append(img.crop((xs[c], ys[r], xs[c + 1], ys[r + 1])))
    return cells


def build_walker(src_name, out_name, label, cw=32, ch=32):
    """4x4 走路图（下 / 左 / 右 / 上 各 4 帧）→ 每格 cw x ch；16 帧用同一个缩放（按最高、最宽的那帧），脚底对齐"""
    src = SRC / src_name
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 4, 4)
    sheet = Image.new("RGBA", (cw * 4, ch * 4))
    figs = [biggest(c) for c in cells]
    hmax = max(f.height for f in figs)
    wmax = max(f.width for f in figs)
    sc = min((ch - 2) / hmax, (cw - 2) / wmax)
    for i, f in enumerate(figs):
        small = _shrink(f, sc)
        cell = Image.new("RGBA", (cw, ch))
        a = np.asarray(small).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        small = Image.fromarray(a, "RGBA")
        cell.alpha_composite(small, ((cw - small.width) // 2, ch - 1 - small.height))
        sheet.alpha_composite(outline(cell), ((i % 4) * cw, (i // 4) * ch))
    sheet.save(OUT / out_name)
    print(label + "：" + out_name)


def object_cells(img, n, merge=5):
    """按「东西」切：alpha 连通块膨胀 merge 像素合并（吊铃的小挂件这种贴得很近的算同一个东西；离得远的气泡、星星这类碎块面积小，取不到），取面积最大的 n 组、从左到右排；
    组数不对就返回 None（调用方退回按间隙均分）。"""
    a = np.asarray(img.getchannel("A")) > 0
    grown = ndimage.binary_dilation(a, iterations=merge)
    lab, k = ndimage.label(grown)
    if k < n:
        return None
    sizes = ndimage.sum(a, lab, range(1, k + 1))
    keep = sorted(range(1, k + 1), key=lambda i: -sizes[i - 1])[:n]
    if min(sizes[i - 1] for i in keep) < max(sizes) * 0.05:
        return None
    boxes = []
    for i in keep:
        ys, xs = np.where((lab == i) & a)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, i))
    boxes.sort(key=lambda b: b[0])
    out = []
    arr = np.asarray(img)
    for (x0, y0, x1, y1, i) in boxes:
        part = arr[y0:y1, x0:x1].copy()
        part[..., 3] = np.where(lab[y0:y1, x0:x1] == i, part[..., 3], 0)
        out.append(Image.fromarray(part, "RGBA"))
    return out


def build_strip(src_name, out_name, n, w, h, label, uniform=False):
    """一行 n 帧 → 每帧 w x h。uniform：整条用同一个缩放（动画帧、同一个东西的几种样子，大小和位置要一致）；
    否则每帧各自缩到放得下（一排不同的道具）。"""
    src = SRC / src_name
    if not src.exists():
        print("没有原图：", src)
        return
    keyed = key_white(Image.open(src))
    objs = object_cells(keyed, n)
    figs = objs if objs else [biggest(c) for c in grid_cells(keyed, n, 1)]
    sheet = Image.new("RGBA", (w * n, h))
    sc = min(min((w - 2) / f.width, (h - 2) / f.height) for f in figs) if uniform else None
    for i, f in enumerate(figs):
        sheet.alpha_composite(fit(f, w, h, scale=sc), (i * w, 0))
    sheet.save(OUT / out_name)
    print(label + "：" + out_name)


def defringe(out_name, recolor=None):
    """淡紫色的图在洋红底上抠完，边上会残留一圈粉紫色杂边：只看贴着透明处的边缘像素，偏洋红（红蓝高、绿很低）的去掉，里面的不动"""
    path = OUT / out_name
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    drop = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a or not (r > 200 and b > 190 and g < 95):
                continue
            edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                drop.append((x, y))
    for x, y in drop:
        px[x, y] = (0, 0, 0, 0)
    if recolor:
        # 里面的颜色按亮度重新上一套干净的淡紫（洋红底抠图会把淡紫抠花）
        dark, light = recolor
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if not a:
                    continue
                lum = (r * 0.3 + g * 0.59 + b * 0.11) / 255.0
                if lum < 0.25:
                    continue   # 描边
                t = min(1.0, max(0.0, (lum - 0.3) / 0.6))
                t = round(t * 3) / 3.0
                px[x, y] = (int(dark[0] + (light[0] - dark[0]) * t), int(dark[1] + (light[1] - dark[1]) * t), int(dark[2] + (light[2] - dark[2]) * t), 255)
    im.save(path)


def build_maid():
    src = SRC / "doll_maid_sheet.png"
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 4, 4)
    sheet = Image.new("RGBA", (128, 128))
    figs = [biggest(c) for c in cells]
    hmax = max(f.height for f in figs)
    for i, f in enumerate(figs):
        # 同一张图里人物大小一致：按最高的那个缩
        s = 30 / hmax
        small = _shrink(f, s)
        cell = Image.new("RGBA", (32, 32))
        a = np.asarray(small).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        small = Image.fromarray(a, "RGBA")
        cell.alpha_composite(small, ((32 - small.width) // 2, 31 - small.height))
        sheet.alpha_composite(outline(cell), ((i % 4) * 32, (i // 4) * 32))
    sheet.save(OUT / "npcs/doll_maid.png")
    print("人偶女仆：npcs/doll_maid.png")


def build_statue():
    src = SRC / "palace_statue_sheet.png"
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 3, 1)
    sheet = Image.new("RGBA", (96, 48))
    for i, c in enumerate(cells):
        sheet.alpha_composite(fit(biggest(c), 32, 48), (i * 32, 0))
    sheet.save(OUT / "palace_statue.png")
    print("浴场雕像：palace_statue.png")


def build_dance_doll():
    """舞会人偶：人偶女仆（npcs/doll_maid.png）的深蓝裙子换成粉色舞会裙（只改偏蓝、偏暗的颜色）"""
    src = OUT / "npcs/doll_maid.png"
    if not src.exists():
        return
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > r + 15) & (b > g + 5) & (a[..., 3] > 0)
    lum = (r + g + b) / 3.0
    a[..., 0] = np.where(blue, np.clip(lum * 1.9 + 60, 0, 255), r)
    a[..., 1] = np.where(blue, np.clip(lum * 0.9 + 30, 0, 255), g)
    a[..., 2] = np.where(blue, np.clip(lum * 1.3 + 50, 0, 255), b)
    Image.fromarray(a.astype(np.uint8), "RGBA").save(OUT / "npcs/dance_doll.png")
    print("舞会人偶：npcs/dance_doll.png")


if __name__ == "__main__":
    build_maid()
    build_statue()
    build_walker("clock_keeper_sheet.png", "npcs/clock_keeper.png", "守钟人偶")
    build_strip("portrait_boss_sheet.png", "portrait_boss.png", 3, 64, 88, "大画像")
    build_strip("small_portrait_sheet.png", "small_portrait.png", 2, 28, 36, "小画像")
    build_walker("head_maid_sheet.png", "npcs/head_maid.png", "女仆长")
    # 第四章追加事件（洋红底重画；动画条统一缩放）
    build_strip("clock_props_sheet.png", "clock_props.png", 6, 48, 56, "钟楼道具（齿轮 / 钟摆 / 风箱 / 钟 / 钟绳 / 宝箱）")
    build_strip("exit_markers_sheet.png", "exit_markers.png", 5, 40, 40, "出口标记（上楼梯 / 下楼梯 / 门 / 墙洞 / 梯子）")
    build_strip("palace_misc_sheet.png", "palace_misc.png", 3, 24, 32, "仆人回廊（唤人铃 / 钥匙 / 小牌子）")
    build_strip("clock_beetle_sheet.png", "clock_beetle.png", 4, 20, 18, "发条挠痒虫（三帧爬 + 翻倒）", uniform=True)
    build_strip("flying_book_sheet.png", "flying_book.png", 4, 22, 20, "飞书（三帧飞 + 合上夹）", uniform=True)
    build_strip("old_shoe_sheet.png", "old_shoe.png", 4, 20, 16, "旧鞋（三帧跳 + 张口）", uniform=True)
    build_strip("palace_events_sheet.png", "palace_events.png", 6, 40, 40, "追加事件道具（奶酪夹 / 夹子弹起 / 钟面 / 喷泉 / 徽记台 / 石堆）")
    build_strip("palace_events2_sheet.png", "palace_events2.png", 8, 36, 36, "追加事件道具二（海绵 / 点心托盘 / 羽毛笔 / 小铃铛 / 袜子 / 奶酪 / 钟发条 / 衣架书签的书）")
    build_strip("palace_props3_sheet.png", "palace_props3.png", 6, 40, 48, "事件点补图（骑士石像 / 粉摇篮 / 蓝摇篮 / 旋转吊铃 / 水槽 / 糕点台）")
    build_strip("pastry_chef_sheet.png", "npcs/pastry_chef.png", 4, 32, 40, "糕点师人偶（站着 ×2 / 端蛋糕 / 举打蛋器）", uniform=True)
    build_walker("rat_king_walk_sheet.png", "rat_king_walk.png", "胖鼠王·走路", 44, 44)
    build_strip("rat_king_act_sheet.png", "rat_king_act.png", 3, 44, 44, "胖鼠王·动作（探头 / 晕 / 扫胡子）", uniform=True)
    build_walker("scrub_doll_walk_sheet.png", "scrub_doll_walk.png", "搓澡人偶·走路", 48, 52)
    build_strip("scrub_doll_act_sheet.png", "scrub_doll_act.png", 3, 48, 52, "搓澡人偶·动作（挥刷 / 抓人 / 没海绵晕了）", uniform=True)
    build_walker("armor_guard_sheet.png", "npcs/armor_guard.png", "空铠甲卫兵")
    build_walker("captain_shade_sheet.png", "npcs/captain_shade.png", "年轻队长的幽影")
    # 第四章追加事件（第三批）
    build_strip("ice_sprite_sheet.png", "ice_sprite.png", 4, 22, 22, "冰糕精灵（三帧飘 + 伸手）", uniform=True)
    build_strip("palace_props4_sheet.png", "palace_props4.png", 6, 40, 48, "追加事件道具三（按摩椅 / 冻住的门 / 冰块蛋糕 / 生日蛋糕 / 空画框 / 镜面墙板）")
    build_strip("paint_imp_sheet.png", "paint_imp.png", 4, 24, 24, "颜料小人（三帧走 + 挥小刷子）", uniform=True)
    build_strip("paint_fx_sheet.png", "paint_fx.png", 6, 48, 48, "王座间特效（粉飞溅 / 蓝飞溅 / 画布碎片 / 金色笔触 / 金色星光 / 颜料手）")
    build_strip("garden_props_sheet.png", "garden_props.png", 6, 48, 48, "后花园（双人秋千 / 抱水瓶的小天使 / 凉亭 / 花坛 / 小水壶 / 干喷泉）")
    build_strip("flower_keeper_sheet.png", "npcs/flower_keeper.png", 4, 28, 36, "花园小店主（站着 ×2 / 噘嘴指着蔫花 / 撒花瓣）", uniform=True)
    build_strip("story_props_sheet.png", "story_props.png", 8, 40, 40, "剧情事件（首饰盒 合 / 开、红 / 蓝 / 黄宝石、日记页、茶具、花束）")
    build_strip("banquet_props_sheet.png", "banquet_props.png", 3, 80, 64, "小宴会厅（三人座长桌 / 蛋糕架 / 名牌）")
    build_strip("pants_hands_sheet.png", "pants_hands.png", 3, 20, 20, "千手裤的小手（蜷着 / 扭动 / 伸开挠）")
    defringe("pants_hands.png", ((128, 88, 180), (226, 206, 250)))
    build_strip("paint_wave_sheet.png", "paint_wave.png", 4, 56, 36, "颜料浪头（涌起 / 卷浪 / 碎开 / 落下）", uniform=True)
    build_strip("portrait_clean_sheet.png", "portrait_clean.png", 1, 64, 88, "画里的记忆走完以后：女王的画像（脸干干净净、闭着眼睛）")
    build_strip("toll_imps_sheet.png", "toll_imps.png", 4, 56, 44, "收路费的小鬼们（待机 ×2 / 伸手要钱 / 抱着金币开心）")
    build_strip("frame_soldier_sheet.png", "frame_soldier.png", 4, 28, 32, "画框小兵（三帧走 + 羽毛长矛戳）", uniform=True)
    build_strip("brush_sprite_sheet.png", "brush_sprite.png", 4, 28, 20, "羽毛画笔精（三帧飞 + 快速刷）", uniform=True)
    build_strip("small_portraits4_sheet.png", "small_portraits4.png", 8, 28, 36, "四色小画像（红 / 蓝 / 金 / 绿，各 睡着 + 醒着）", uniform=True)
    build_strip("throne_fx2_sheet.png", "throne_fx2.png", 8, 48, 48, "王座间特效二（画像之眼 / 光带 / 颜料星 / 出口画框 / 画架 / 护盾 / 吸引旋涡 / 颜料浪）")
    build_dance_doll()
