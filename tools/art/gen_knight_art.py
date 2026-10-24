"""骑士篇的像素图：骑士的行走图（assets/generated/npcs/knight.png，4×4 格 32×32，行 = 下 / 左 / 右 / 上，列 1、3 迈步），
以及被诅咒附身的盔甲（npcs/knight_cursed.png：同一套格子，铠甲泛紫、手印爬满全身、面罩缝里透紫光，外面一圈紫色的光晕）。
外观：磨旧的银灰铠甲、面罩放下来的全盔（看不见脸）、破破烂烂的褪色深蓝披风（下摆撕成锯齿）、剑柄缠红绳、铠甲上几个淡紫色的小手印。
（伏笔：披风的颜色和金边是队长那件褪了色的样子；侧面和背面头盔下露出一小撮粉红的头发——和队长的发色一样，埋得很轻。）
用法：python tools/art/gen_knight_art.py
"""
import random

from PIL import Image

from gen_expansion import blank, canvas
from gen_town_art import _legs, _walk_fx, GOLD_D, LEATHER, ROSE
from palette import OUT, add_outline

STEEL, STEEL_D, STEEL_L = (168, 172, 184, 255), (108, 112, 128, 255), (206, 210, 220, 255)
CAPE, CAPE_D = (62, 70, 112, 255), (40, 44, 78, 255)
GOLD_FADED = (176, 150, 96, 255)
CORD = (186, 52, 58, 255)
CURSE = (160, 110, 210, 255)
VISOR = (36, 34, 46, 255)


def knight_frame(row, col):
    img, d = canvas(32, 32)
    swing = (1 if col == 1 else -1) if col in (1, 3) else 0
    hy = 8
    rnd = random.Random(row * 7 + col)
    # 披风（身后），下摆撕成锯齿
    hem = [(6 + i * 2, 28 + (1 if i % 2 else -1) + (rnd.randint(-1, 0) if row == 3 else 0)) for i in range(10)]
    if row == 3:
        d.polygon([(8, 14), (23, 14)] + list(reversed(hem)), fill=CAPE)
        d.line((15, 15, 15, 27), fill=CAPE_D)
        d.line((9, 16, 9, 26), fill=GOLD_FADED)
    else:
        d.polygon([(8, 14), (23, 14)] + list(reversed(hem)), fill=CAPE_D)
    _legs(d, row, swing, 24, 29, STEEL_D)
    # 铠甲
    d.rectangle((11, 14, 20, 24), fill=STEEL)
    d.line((11, 18, 20, 18), fill=GOLD_FADED)
    d.rectangle((11, 21, 20, 22), fill=LEATHER)
    if row == 0:
        d.line((13, 15, 13, 17), fill=STEEL_L)
        # 半个褪色的纹章
        d.point((16, 16), fill=GOLD_FADED)
        d.point((17, 15), fill=GOLD_FADED)
        d.point((17, 17), fill=GOLD_FADED)
        # 淡紫色的小手印
        d.point((12, 20), fill=CURSE)
        d.point((19, 23), fill=CURSE)
    elif row in (1, 2):
        d.point((15, 19), fill=CURSE)
    # 肩甲（有划痕）
    d.ellipse((8, 13, 13, 17), fill=STEEL)
    d.ellipse((18, 13, 23, 17), fill=STEEL)
    d.point((10, 15), fill=STEEL_D)
    d.point((21, 14), fill=STEEL_D)
    # 长剑（剑柄缠红绳），剑尖朝下在身侧
    if row != 3:
        sx = 24 if row in (0, 2) else 7
        sy = swing if row == 0 else 0
        sx += swing if row in (1, 2) else 0
        d.line((sx, 15 + sy, sx, 29), fill=STEEL_L)
        d.line((sx - 1, 16 + sy, sx + 1, 16 + sy), fill=GOLD_D)
        d.point((sx, 14 + sy), fill=CORD)
        d.point((sx, 13 + sy), fill=CORD)
        hx = 8 if sx > 15 else 23
        d.rectangle((hx, 19 - swing, hx + 1, 21 - swing), fill=STEEL_D)
    # 全盔：面罩放下来，只有一道黑色的缝
    d.ellipse((10, hy - 6, 21, hy + 5), fill=STEEL)
    d.line((10, hy, 21, hy), fill=STEEL_D)
    if row == 0:
        d.rectangle((12, hy - 1, 19, hy), fill=VISOR)
        d.line((15, hy + 1, 15, hy + 4), fill=STEEL_D)
    elif row in (1, 2):
        vx = (10, 14) if row == 1 else (17, 21)
        d.rectangle((vx[0], hy - 1, vx[1], hy), fill=VISOR)
        # 头盔下露出的一小撮头发
        nape = 19 if row == 1 else 11
        d.point((nape, hy + 5), fill=ROSE)
        d.point((nape + (1 if row == 1 else -1), hy + 5), fill=ROSE)
    else:
        d.line((15, hy - 5, 15, hy + 4), fill=STEEL_D)
        d.point((15, hy + 5), fill=ROSE)
        d.point((16, hy + 5), fill=ROSE)
    d.point((15 if row != 2 else 16, hy - 6), fill=STEEL_L)
    return add_outline(_walk_fx(img, col, 25, 29, 24))


def cursed_frame(row, col):
    """被诅咒附身：在普通的帧上把铠甲染紫、加满手印、面罩缝发光，外圈一层紫色光晕。"""
    base = knight_frame(row, col)
    px = base.load()
    rnd = random.Random(100 + row * 4 + col)
    out = Image.new("RGBA", base.size)
    glow = Image.new("RGBA", base.size)
    gp = glow.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # 铠甲（灰）往紫色偏
            if abs(r - g) < 18 and abs(g - b) < 22 and r > 90:
                px[x, y] = (min(255, r - 10), max(0, g - 40), min(255, b + 30), a)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < 32 and 0 <= y + dy < 32:
                    gp[x + dx, y + dy] = (170, 90, 230, 150)
    for _ in range(9):
        x, y = rnd.randint(11, 20), rnd.randint(14, 27)
        if px[x, y][3]:
            px[x, y] = (200, 140, 255, 255)
    if row in (0, 1, 2):
        for x in range(12, 20):
            if px[x, 7][3] and px[x, 7][0] < 60:
                px[x, 7] = (230, 170, 255, 255)
    out.alpha_composite(glow)
    out.alpha_composite(base)
    return out


def sheet_of(frame_fn):
    sheet = blank(32 * 4, 32 * 4)
    for row in range(4):
        for col in range(4):
            sheet.alpha_composite(frame_fn(row, col), (col * 32, row * 32))
    return sheet


def main():
    (OUT / "npcs").mkdir(exist_ok=True)
    sheet_of(knight_frame).save(OUT / "npcs" / "knight.png")
    sheet_of(cursed_frame).save(OUT / "npcs" / "knight_cursed.png")
    print("骑士 / 被诅咒附身的盔甲的行走图已生成：", OUT / "npcs")


if __name__ == "__main__":
    main()
