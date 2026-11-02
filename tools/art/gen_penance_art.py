"""反省篇第一章（反省牢房）的道具像素图（16x16 一帧，横排；CG 舞台和地图上都用 CGActor 的陷阱演员画）：
  plush_doll.png     痒痒床头人偶：帧 0 坐着的旧布偶；帧 1 两只布手伸出来挠
  cat_guard.png      猫咪看守（橘猫）：帧 0 趴着；帧 1 抬头伸舌头 + 尾巴扫过来
  trophy_chest.png   队长的旧战利品箱：帧 0 上锁；帧 1 打开、露出袖套 / 袜子 / 短裤
  penance_bed.png    功能拘束挠痒床（32x16 一帧）：帧 0 收着；帧 1 脚枷扣上、羽毛排刷和腰侧软刷都伸出来
  wall_crack.png     墙角的裂缝：帧 0 裂缝；帧 1 挠脚鼠从缝里探出头
用法：python tools/art/gen_penance_art.py
"""
from PIL import Image, ImageDraw

from gen_expansion import _strip, canvas
from palette import OUT, add_outline
from gen_zone_art import (BRASS, BRISTLE, DARK, FEATHER, FUR, FUR_D, FUR_L, PINK, PINK_D, PINK_L, RAT, STEEL, STEEL_D,
                          STONE, STONE_D, WOOD, WOOD_D, WOOD_L, BLUSH)

CLOTH = (236, 214, 190, 255)
CLOTH_D = (190, 160, 140, 255)
GREY = (160, 160, 170, 255)


def plush_doll(frame):
    img, d = canvas()
    d.ellipse((4, 7, 11, 15), fill=CLOTH)          # 身子
    d.ellipse((4, 1, 11, 8), fill=CLOTH)           # 头
    d.ellipse((3, 0, 6, 3), fill=CLOTH_D)          # 耳朵
    d.ellipse((9, 0, 12, 3), fill=CLOTH_D)
    d.line((6, 4, 6, 5), fill=DARK)
    d.line((9, 4, 9, 5), fill=DARK)
    d.line((7, 6, 8, 6), fill=PINK_D)
    d.point((5, 5), fill=BLUSH)
    d.point((10, 5), fill=BLUSH)
    d.line((6, 10, 9, 10), fill=CLOTH_D)            # 补丁
    if frame == 0:
        d.ellipse((2, 9, 5, 12), fill=CLOTH)
        d.ellipse((10, 9, 13, 12), fill=CLOTH)
    else:                                          # 布手伸出来，手指一张一合
        d.line((4, 10, 0, 7), fill=CLOTH, width=2)
        d.line((11, 10, 15, 7), fill=CLOTH, width=2)
        for x in (0, 2):
            d.point((x, 5), fill=CLOTH_D)
        for x in (13, 15):
            d.point((x, 5), fill=CLOTH_D)
    return add_outline(img)


def cat_guard(frame):
    img, d = canvas()
    d.ellipse((2, 8, 12, 15), fill=FUR)             # 趴着的身子
    for x in (4, 7, 10):
        d.line((x, 9, x + 1, 13), fill=FUR_D)       # 条纹
    hy = 3 if frame else 5
    d.ellipse((8, hy, 15, hy + 7), fill=FUR)        # 头
    d.polygon([(8, hy + 2), (9, hy - 2), (11, hy + 1)], fill=FUR)
    d.polygon([(12, hy + 1), (14, hy - 2), (15, hy + 2)], fill=FUR)
    d.point((10, hy + 3), fill=DARK)
    d.point((13, hy + 3), fill=DARK)
    d.point((11, hy + 5), fill=PINK_D)
    d.ellipse((9, hy + 4, 14, hy + 7), fill=FUR_L) if frame == 0 else None
    if frame:
        d.line((11, hy + 6, 12, hy + 8), fill=PINK, width=2)   # 伸舌头
        d.arc((0, 2, 8, 12), 90, 250, fill=FUR_D, width=2)      # 尾巴扫过来
    else:
        d.arc((0, 9, 6, 15), 90, 270, fill=FUR_D, width=2)
    return add_outline(img)


def trophy_chest(frame):
    img, d = canvas()
    d.rectangle((1, 7, 14, 15), fill=WOOD)
    d.line((1, 11, 14, 11), fill=WOOD_D)
    for x in (1, 14):
        d.line((x, 7, x, 15), fill=BRASS)
    if frame == 0:
        d.rectangle((1, 4, 14, 7), fill=WOOD_L)
        d.rectangle((6, 6, 9, 9), fill=BRASS)
        d.point((7, 8), fill=DARK)
    else:
        d.polygon([(1, 7), (14, 7), (12, 1), (3, 1)], fill=WOOD_D)
        d.rectangle((3, 5, 6, 8), fill=PINK_L)       # 袖套
        d.rectangle((7, 4, 9, 8), fill=FEATHER)      # 袜子
        d.rectangle((10, 5, 13, 8), fill=STEEL)      # 握握手短裤
        d.point((11, 6), fill=CLOTH)
    return add_outline(img)


def penance_bed(frame):
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in (2, 29):
        d.line((x, 10, x, 15), fill=WOOD_D)
    d.rectangle((1, 7, 30, 10), fill=WOOD)
    d.rectangle((2, 5, 29, 8), fill=PINK_L)          # 床垫
    d.rectangle((2, 5, 7, 8), fill=FEATHER)          # 枕头
    d.rectangle((26, 3, 30, 9), fill=WOOD_D)         # 床尾的脚枷板
    for y in (5, 7):
        d.ellipse((27, y - 1, 29, y + 1), outline=STEEL_D)
    if frame:
        d.ellipse((26, 4, 28, 6), fill=STEEL)        # 扣上
        d.ellipse((26, 7, 28, 9), fill=STEEL)
        for x in range(23, 32, 2):                   # 羽毛排刷
            d.line((x, 12, x - 1, 15), fill=FEATHER)
        for x in (12, 18):                           # 腰侧软刷
            d.line((x, 4, x, 1), fill=BRISTLE)
            d.point((x - 1, 1), fill=BRISTLE)
            d.point((x + 1, 1), fill=BRISTLE)
        d.line((8, 10, 25, 10), fill=BRASS)          # 翻身板的轴
    return add_outline(img)


def wall_crack(frame):
    img, d = canvas()
    d.line((7, 0, 6, 5), fill=DARK, width=2)
    d.line((6, 5, 9, 9), fill=DARK, width=2)
    d.line((9, 9, 7, 15), fill=DARK, width=2)
    d.line((6, 5, 3, 7), fill=STONE_D)
    if frame:
        d.ellipse((5, 9, 11, 14), fill=RAT)          # 挠脚鼠探出头
        d.ellipse((5, 8, 7, 10), fill=RAT)
        d.ellipse((9, 8, 11, 10), fill=RAT)
        d.point((7, 11), fill=DARK)
        d.point((9, 11), fill=DARK)
        d.point((8, 13), fill=PINK)
    return add_outline(img)


def main():
    _strip([plush_doll(f) for f in range(2)], 16, 16).save(OUT / "plush_doll.png")
    _strip([cat_guard(f) for f in range(2)], 16, 16).save(OUT / "cat_guard.png")
    _strip([trophy_chest(f) for f in range(2)], 16, 16).save(OUT / "trophy_chest.png")
    _strip([penance_bed(f) for f in range(2)], 32, 16).save(OUT / "penance_bed.png")
    _strip([wall_crack(f) for f in range(2)], 16, 16).save(OUT / "wall_crack.png")
    print("反省牢房的道具图已生成")


if __name__ == "__main__":
    main()
