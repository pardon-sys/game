"""第八层夜迷宫的像素图：新怪物、新陷阱 / 机关、巡逻的千手影子。输出 assets/generated/maze/<名字>.png。

  glow_moth      夜光羽蛾       16x16 × 2 帧（翅膀上 / 下），淡黄绿的发光翅膀
  dream_fluff    梦绒球         16x16 × 2 帧，薰衣草色的绒球、困困的眼睛
  lamp_imp       偷灯小鬼       16x16 × 2 帧，戴灭烛帽的小黑鬼
  laugh_jar      笑声收集瓶     16x16 × 4 帧（空 → 满，粉色的笑声旋涡）
  hand_shadow    千手的影子     48x48 × 2 帧，巨大的紫黑手影、中间一只眼睛
  mirror_puddle  镜面水洼       32x16，反着微光的水洼（地面）
  shadow_vine    影子缠腿藤     16x16 × 2 帧（贴地 / 缠起来）
  feather_curtain 羽毛门帘      16x24 × 2 帧（放下 / 卷起）
  moon_mirror    月光镜         16x24 × 4 帧（镜面朝右 / 下 / 左 / 上）
  hand_gate      千手之门       32x32 × 2 帧（关着：刻着手印 / 开着）
  cradle_bench   摇篮长椅       32x16
  living_wall    呼吸墙（活墙） 16x32 × 3 帧（上 16 = 墙顶、下 16 = 正面；紫色脉络一明一暗地起伏）
  living_crack   呼吸墙沉下后的地面裂纹 16x16 × 2 帧（暗 / 心跳前发亮）
用法：python tools/art/gen_floor08_maze_art.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

from palette import add_outline

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/generated/maze"


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def strip(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def glow_moth(f):
    img, d = canvas(16, 16)
    wing = (235, 245, 170, 230)
    wing_d = (180, 200, 110, 230)
    up = f == 0
    for side in (-1, 1):
        cx = 8 + side * 4
        top = 3 if up else 6
        d.polygon([(8, 8), (cx + side * 3, top), (cx + side * 4, top + 5), (8, 10)], fill=wing)
        d.polygon([(8, 9), (cx + side * 2, 13), (cx, 14), (8, 11)], fill=wing_d)
        d.point((cx + side * 2, top + 2), fill=(255, 255, 230, 255))
    d.rectangle((7, 6, 8, 12), fill=(90, 80, 70, 255))
    d.point((6, 4), fill=(90, 80, 70, 255))
    d.point((9, 4), fill=(90, 80, 70, 255))
    return add_outline(img)


def dream_fluff(f):
    img, d = canvas(16, 16)
    r = 6 if f == 0 else 5
    cy = 9 if f == 0 else 10
    d.ellipse((8 - r, cy - r, 8 + r, cy + r), fill=(205, 180, 240, 255))
    for a in range(0, 360, 30):
        x = 8 + math.cos(math.radians(a)) * (r + 0.5)
        y = cy + math.sin(math.radians(a)) * (r + 0.5)
        d.point((round(x), round(y)), fill=(230, 215, 255, 255))
    d.line((5, cy, 6, cy), fill=(90, 60, 120, 255))     # 困困的眼睛（闭着）
    d.line((10, cy, 11, cy), fill=(90, 60, 120, 255))
    d.point((8, cy + 2), fill=(255, 150, 200, 255))
    return add_outline(img)


def lamp_imp(f):
    img, d = canvas(16, 16)
    bob = 0 if f == 0 else 1
    d.ellipse((4, 6 + bob, 11, 14 + bob), fill=(45, 35, 60, 255))
    d.polygon([(4, 7 + bob), (8, 0 + bob), (11, 7 + bob)], fill=(70, 60, 85, 255))      # 灭烛帽
    d.point((8, 0 + bob), fill=(200, 200, 210, 255))
    d.point((6, 9 + bob), fill=(255, 210, 90, 255))
    d.point((9, 9 + bob), fill=(255, 210, 90, 255))
    d.line((3, 8 + bob, 4, 9 + bob), fill=(45, 35, 60, 255))                           # 尖耳朵
    d.line((12, 8 + bob, 11, 9 + bob), fill=(45, 35, 60, 255))
    d.line((6, 12 + bob, 9, 12 + bob), fill=(120, 90, 140, 255))
    return add_outline(img)


def laugh_jar(level):
    img, d = canvas(16, 16)
    d.rectangle((5, 2, 10, 3), fill=(160, 120, 90, 255))                                # 木塞
    d.rounded_rectangle((3, 4, 12, 14), 3, fill=(190, 225, 245, 120), outline=(220, 240, 255, 230))
    if level > 0:
        top = 13 - level * 3
        d.rounded_rectangle((4, top, 11, 13), 2, fill=(255, 150, 205, 220))
        for i in range(level):
            d.arc((5, top + 1, 10, top + 5), 0, 270, fill=(255, 220, 240, 255))
    d.line((5, 6, 5, 9), fill=(255, 255, 255, 220))
    d.point((5, 15), fill=(120, 90, 80, 255))
    d.point((10, 15), fill=(120, 90, 80, 255))
    return add_outline(img)


def hand_shadow(f):
    img, d = canvas(48, 48)
    col = (60, 25, 85, 200)
    col_l = (95, 50, 130, 210)
    spread = 0 if f == 0 else 2
    d.ellipse((12, 18, 36, 44), fill=col)                                               # 掌心
    for i, (x, h) in enumerate(((10, 14), (17, 8), (24, 6), (31, 8), (38, 14))):
        dx = (i - 2) * spread
        d.rounded_rectangle((x - 3 + dx, h, x + 3 + dx, 28), 3, fill=col)
        d.line((x + dx, h + 2, x + dx, h + 6), fill=col_l)
    d.ellipse((19, 26, 29, 34), fill=(230, 210, 255, 230))                             # 眼睛
    d.ellipse((22, 28, 26, 32), fill=(180, 40, 120, 255))
    return img


def mirror_puddle():
    img, d = canvas(32, 16)
    d.ellipse((1, 3, 30, 14), fill=(40, 55, 90, 200))
    d.ellipse((3, 4, 28, 12), fill=(70, 95, 140, 210))
    d.line((7, 6, 14, 6), fill=(200, 225, 255, 230))                                    # 反光
    d.line((18, 9, 23, 9), fill=(170, 200, 245, 200))
    d.point((11, 8), fill=(255, 255, 255, 255))
    return img


def shadow_vine(f):
    img, d = canvas(16, 16)
    col = (55, 30, 75, 255)
    tip = (120, 70, 160, 255)
    if f == 0:
        for x in (3, 8, 12):
            d.line((x, 15, x + 1, 11), fill=col)
            d.point((x + 1, 10), fill=tip)
        d.line((1, 15, 15, 15), fill=col)
    else:
        for i, x in enumerate((2, 7, 12)):
            d.arc((x - 3, 2 + i, x + 6, 15), 180, 360, fill=col, width=2)
            d.point((x + 1, 2 + i), fill=tip)
        d.line((1, 15, 15, 15), fill=col)
    return img


def feather_curtain(f):
    img, d = canvas(16, 24)
    d.rectangle((0, 0, 15, 2), fill=(110, 80, 60, 255))                                 # 横杆
    if f == 0:
        for x in range(1, 16, 3):
            d.line((x, 3, x, 21), fill=(235, 225, 245, 230))
            for y in range(5, 21, 4):
                d.line((x - 1, y, x + 1, y + 1), fill=(210, 190, 235, 230))
    else:
        d.rounded_rectangle((0, 2, 15, 6), 2, fill=(225, 210, 240, 240))                # 卷起来
        d.line((2, 4, 13, 4), fill=(190, 170, 220, 255))
    return add_outline(img)


def moon_mirror(f):
    img, d = canvas(16, 24)
    d.rectangle((6, 16, 9, 22), fill=(90, 95, 120, 255))                                # 底座
    d.rectangle((4, 21, 11, 23), fill=(70, 75, 100, 255))
    face = [(3, 3, 12, 15), (3, 6, 12, 15), (3, 3, 12, 15), (3, 3, 12, 12)][f]
    d.rounded_rectangle(face, 2, fill=(150, 175, 220, 255), outline=(220, 230, 255, 255))
    # 镜面朝向的那一侧画亮边
    edge = {0: ((12, 4), (12, 14)), 1: ((4, 15), (11, 15)), 2: ((3, 4), (3, 14)), 3: ((4, 3), (11, 3))}[f]
    d.line(edge, fill=(255, 255, 255, 255))
    d.line((5, 6, 7, 6), fill=(235, 245, 255, 255))
    return add_outline(img)


def hand_gate(f):
    img, d = canvas(32, 32)
    d.rectangle((0, 0, 31, 31), fill=(45, 35, 60, 255))
    d.rectangle((2, 2, 29, 31), fill=(25, 18, 35, 255) if f == 1 else (70, 50, 95, 255))
    if f == 0:
        for (x, y) in ((8, 8), (20, 6), (12, 18), (22, 20)):                             # 刻着的手印
            d.ellipse((x, y + 3, x + 6, y + 9), fill=(120, 80, 160, 255))
            for k in range(4):
                d.line((x + 1 + k * 1.5, y, x + 1 + k * 1.5, y + 3), fill=(120, 80, 160, 255))
        d.line((15, 2, 15, 31), fill=(40, 28, 55, 255))
    return add_outline(img)


def cradle_bench():
    img, d = canvas(32, 16)
    d.arc((1, 8, 31, 20), 180, 360, fill=(110, 75, 55, 255), width=2)                  # 摇篮底
    d.rectangle((3, 4, 28, 9), fill=(150, 105, 75, 255))
    d.rectangle((3, 4, 28, 5), fill=(185, 135, 95, 255))
    d.rectangle((3, 0, 5, 9), fill=(120, 85, 60, 255))
    d.rectangle((26, 0, 28, 9), fill=(120, 85, 60, 255))
    d.rectangle((7, 6, 24, 8), fill=(180, 160, 210, 255))                               # 小垫子
    return add_outline(img)


def living_wall(f):
    img, d = canvas(16, 32)
    glow = [0, 1, 2][f]
    vein = [(120, 60, 160, 255), (160, 80, 200, 255), (205, 120, 240, 255)][glow]
    # 墙顶：暗紫色的肉质顶面，中间一道脉络
    d.rectangle((0, 0, 15, 15), fill=(52, 30, 66, 255))
    d.rectangle((1, 1, 14, 3), fill=(78, 48, 96, 255))
    d.line((3, 6, 7, 9), fill=vein)
    d.line((7, 9, 12, 7), fill=vein)
    d.line((7, 9, 8, 13), fill=vein)
    # 正面：深一点，几条往下分叉的脉络，底部一圈暗边
    d.rectangle((0, 16, 15, 31), fill=(40, 22, 52, 255))
    d.line((0, 16, 15, 16), fill=(95, 60, 118, 255))
    for x0, x1 in ((3, 2), (8, 9), (12, 13)):
        d.line((x0, 17, x1, 24), fill=vein)
        d.line((x1, 24, x1 - 1, 29), fill=vein)
    d.line((8, 21, 11, 23), fill=vein)
    d.rectangle((0, 30, 15, 31), fill=(25, 12, 34, 255))
    if glow == 2:
        for (x, y) in ((8, 9), (2, 24), (9, 24), (13, 24)):
            d.point((x, y), fill=(255, 210, 255, 255))
    return img


def living_crack(f):
    img, d = canvas(16, 16)
    col = (150, 80, 200, 170) if f == 0 else (230, 150, 255, 235)
    d.line((1, 8, 5, 7), fill=col)
    d.line((5, 7, 8, 9), fill=col)
    d.line((8, 9, 14, 6), fill=col)
    d.line((5, 7, 6, 3), fill=col)
    d.line((8, 9, 9, 13), fill=col)
    d.line((11, 8, 12, 12), fill=col)
    if f == 1:
        d.point((8, 9), fill=(255, 230, 255, 255))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {
        "glow_moth": strip([glow_moth(0), glow_moth(1)]),
        "dream_fluff": strip([dream_fluff(0), dream_fluff(1)]),
        "lamp_imp": strip([lamp_imp(0), lamp_imp(1)]),
        "laugh_jar": strip([laugh_jar(i) for i in range(4)]),
        "hand_shadow": strip([hand_shadow(0), hand_shadow(1)]),
        "mirror_puddle": mirror_puddle(),
        "shadow_vine": strip([shadow_vine(0), shadow_vine(1)]),
        "feather_curtain": strip([feather_curtain(0), feather_curtain(1)]),
        "moon_mirror": strip([moon_mirror(i) for i in range(4)]),
        "hand_gate": strip([hand_gate(0), hand_gate(1)]),
        "cradle_bench": cradle_bench(),
        "living_wall": strip([living_wall(i) for i in range(3)]),
        "living_crack": strip([living_crack(0), living_crack(1)]),
    }
    for name, img in sheets.items():
        img.save(OUT / f"{name}.png")
    print("夜迷宫像素图：", ", ".join(sheets))


if __name__ == "__main__":
    main()
