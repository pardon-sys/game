"""第五层（机关迷城）和新系统的像素图。

输出到 assets/generated/：
  passive_icons.png   16x16 × 4   被动技能图标（0 挣脱强化，其余占位：问号）
（陷阱、怪物等在下面的函数里陆续加）

用法：python tools/art/gen_floor5_art.py
"""
from PIL import ImageDraw

from gen_expansion import _strip, blank, canvas
from palette import OUT, add_outline

GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
STEEL = (200, 212, 228, 255)
STEEL_D = (120, 134, 160, 255)
PINK = (255, 150, 205, 255)
PINK_D = (214, 86, 160, 255)
PINK_L = (255, 214, 236, 255)
WHITE = (250, 250, 255, 255)
DARK = (34, 22, 36, 255)
FRAME = (70, 40, 90, 255)
FRAME_L = (170, 120, 220, 255)


def _icon_base():
    img, d = canvas(16, 16)
    d.rounded_rectangle((0, 0, 15, 15), radius=3, fill=FRAME)
    d.rounded_rectangle((0, 0, 15, 15), radius=3, outline=FRAME_L)
    return img, d


def passive_struggle():
    """挣脱强化：断开的锁链 + 向上的金色箭头。"""
    img, d = _icon_base()
    # 左右两截锁链
    d.ellipse((2, 8, 6, 12), outline=STEEL)
    d.ellipse((9, 8, 13, 12), outline=STEEL)
    d.point((7, 9), fill=STEEL_D)
    d.point((8, 11), fill=STEEL_D)
    # 断口的火花
    d.point((7, 7), fill=GOLD)
    d.point((8, 13), fill=GOLD)
    # 向上的箭头
    d.polygon([(8, 1), (11, 4), (9, 4), (9, 7), (7, 7), (7, 4), (5, 4)], fill=GOLD)
    d.line((7, 4, 7, 6), fill=GOLD_D)
    return img


def passive_unknown():
    img, d = _icon_base()
    d.text((5, 2), "?", fill=FRAME_L)
    return img


def gen_passive_icons():
    _strip([passive_struggle(), passive_unknown(), passive_unknown(), passive_unknown()], 16, 16).save(OUT / "passive_icons.png")


def main():
    gen_passive_icons()
    print("第五层像素图已生成")


if __name__ == "__main__":
    main()
