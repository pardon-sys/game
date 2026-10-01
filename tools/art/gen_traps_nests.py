"""强制位移陷阱与怪物巢穴的像素图。

输出到 assets/generated/：
  vortex.png      48x48 x 2   吸痒漩涡（粉紫色螺旋，游戏里再旋转）
  bounce_pad.png  16x16 x 2   弹弹床（待机 / 压下弹起）
  soap.png        16x16 x 2   滑溜肥皂地板（泡沫和反光交替）
  nests.png       24x24 x 3 帧 x 5 行   怪物巢穴（帧 = 待机 / 生成中发光 / 打碎；
                  行 = 鼠洞、精灵花、史莱姆池、水母卵、宝箱堆）

用法：python tools/art/gen_traps_nests.py
"""
import math

from PIL import Image, ImageDraw

from gen_expansion import WOOD, WOOD_D, WOOD_L, _strip, blank, canvas
from palette import OUT, add_outline

PINK = (255, 150, 205, 255)
PINK_D = (214, 86, 160, 255)
PINK_L = (255, 214, 236, 255)
PURPLE = (170, 110, 230, 255)
PURPLE_D = (110, 64, 170, 255)
STONE = (139, 155, 180, 255)
STONE_D = (82, 96, 124, 255)
STONE_L = (192, 203, 220, 255)
DARK = (34, 22, 36, 255)
GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
SLIME = (110, 214, 120, 255)
SLIME_D = (52, 150, 80, 255)
SLIME_L = (190, 250, 190, 255)
JELLY = (190, 150, 255, 200)
JELLY_D = (120, 80, 200, 255)
GLOW = (255, 240, 150, 255)
SOAP = (200, 236, 255, 255)
SOAP_D = (140, 196, 236, 255)
WHITE = (250, 250, 255, 255)
GREEN = (80, 200, 120, 255)
GREEN_D = (40, 140, 80, 255)


def vortex(frame):
    """螺旋：三条旋臂，从外圈淡粉到中心深紫；第 2 帧旋臂错开一点（游戏里还会整体旋转）。"""
    img = blank(48, 48)
    d = ImageDraw.Draw(img)
    cx = cy = 23.5
    d.ellipse((2, 2, 45, 45), fill=(255, 150, 205, 40))
    d.ellipse((8, 8, 39, 39), fill=(220, 120, 220, 60))
    for arm in range(3):
        base = arm * 2 * math.pi / 3 + frame * 0.35
        for i in range(70):
            t = i / 69
            r = 21 * (1 - t) + 1.5
            a = base + t * 3.2 * math.pi
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            col = PINK_L if t < 0.3 else PINK if t < 0.65 else PURPLE
            w = 1 if t > 0.5 else 2
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=col)
    d.ellipse((19, 19, 28, 28), fill=PURPLE_D)
    d.ellipse((21, 21, 26, 26), fill=DARK)
    return img


def bounce_pad(frame):
    """粉色软垫装在弹簧上；第 2 帧压下 / 弹起（垫子更扁、有动作线）。"""
    img, d = canvas()
    d.rectangle((2, 12, 13, 14), fill=STONE_D)
    d.rectangle((3, 12, 12, 13), fill=STONE)
    top = 5 if frame == 0 else 8
    # 弹簧
    for y in range(top + 3, 12, 2):
        d.line((5, y, 10, y + 1), fill=STONE_L)
    # 垫子
    d.ellipse((1, top - 1, 14, top + 4), fill=PINK_D)
    d.ellipse((1, top - 2, 14, top + 2), fill=PINK)
    d.line((4, top - 1, 8, top - 1), fill=PINK_L)
    img = add_outline(img)
    if frame == 1:
        d = ImageDraw.Draw(img)
        d.line((2, 1, 2, 3), fill=PINK_L)
        d.line((7, 0, 7, 2), fill=PINK_L)
        d.line((12, 1, 12, 3), fill=PINK_L)
    return img


def soap(frame):
    """湿滑的地面：淡蓝水膜、几团泡沫、斜向反光（两帧泡沫位置和反光交替）。"""
    img, d = canvas()
    d.rectangle((0, 0, 15, 15), fill=(170, 214, 240, 120))
    for y in range(0, 16, 4):
        d.point(((y * 3 + frame * 2) % 16, y + 1), fill=SOAP_D)
    spots = [(3, 4), (11, 10), (12, 3), (5, 12)]
    for i, (x, y) in enumerate(spots):
        if (i + frame) % 2 == 0:
            d.ellipse((x - 2, y - 1, x + 2, y + 1), fill=WHITE)
            d.point((x - 1, y - 1), fill=SOAP)
        else:
            d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=SOAP)
    sx = 2 + frame * 5
    d.line((sx, 14, sx + 5, 9), fill=(255, 255, 255, 170))
    return img


def _rat_hole(state):
    img, d = canvas(24, 24)
    if state == 2:
        d.ellipse((2, 14, 21, 22), fill=STONE_D)
        for x, y in ((5, 15), (11, 13), (16, 16), (8, 18)):
            d.rectangle((x, y, x + 3, y + 2), fill=STONE)
        return add_outline(img)
    d.ellipse((1, 6, 22, 22), fill=STONE_D)
    d.ellipse((2, 6, 21, 20), fill=STONE)
    d.point((6, 9), fill=STONE_L)
    d.point((16, 8), fill=STONE_L)
    d.ellipse((6, 11, 17, 21), fill=DARK)
    if state == 1:
        d.point((9, 15), fill=GLOW)
        d.point((14, 15), fill=GLOW)
        d.line((6, 18, 3, 17), fill=STONE_L)
    return add_outline(img)


def _fairy_flower(state):
    img, d = canvas(24, 24)
    d.line((11, 14, 11, 22), fill=GREEN_D, width=2)
    d.ellipse((4, 17, 10, 20), fill=GREEN)
    d.ellipse((13, 17, 19, 20), fill=GREEN)
    if state == 2:
        d.ellipse((7, 11, 16, 15), fill=(170, 120, 150, 255))
        return add_outline(img)
    r = 7 if state == 1 else 6
    for k in range(5):
        a = k * 2 * math.pi / 5 - math.pi / 2
        x, y = 11.5 + math.cos(a) * r * 0.75, 10 + math.sin(a) * r * 0.75
        d.ellipse((x - 3.5, y - 3.5, x + 3.5, y + 3.5), fill=PINK)
        d.ellipse((x - 1.5, y - 1.5, x + 1, y + 1), fill=PINK_L)
    d.ellipse((8, 7, 15, 13), fill=GOLD)
    d.point((10, 9), fill=WHITE)
    img = add_outline(img)
    if state == 1:
        d = ImageDraw.Draw(img)
        for x, y in ((2, 3), (20, 2), (21, 9), (3, 11)):
            d.point((x, y), fill=GLOW)
            d.point((x + 1, y), fill=PINK_L)
    return img


def _slime_pool(state):
    img, d = canvas(24, 24)
    if state == 2:
        d.ellipse((4, 17, 19, 21), fill=SLIME_D)
        return add_outline(img)
    d.ellipse((1, 11, 22, 22), fill=SLIME_D)
    d.ellipse((2, 11, 21, 20), fill=SLIME)
    d.line((5, 13, 10, 13), fill=SLIME_L)
    bubbles = ((7, 15), (15, 14), (12, 17)) if state == 0 else ((6, 13), (15, 12), (11, 9), (17, 8))
    for x, y in bubbles:
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=SLIME_L)
    if state == 1:
        d.ellipse((8, 4, 15, 12), fill=SLIME)
        d.point((10, 7), fill=WHITE)
        d.point((13, 7), fill=WHITE)
    return add_outline(img)


def _jelly_egg(state):
    img, d = canvas(24, 24)
    if state == 2:
        for x, y in ((4, 18), (10, 19), (16, 17)):
            d.polygon([(x, y), (x + 3, y - 2), (x + 5, y + 1)], fill=JELLY_D)
        return add_outline(img)
    eggs = ((3, 11, 11, 21), (12, 9, 20, 21), (8, 4, 15, 14))
    for i, (x0, y0, x1, y1) in enumerate(eggs):
        d.ellipse((x0, y0, x1, y1), fill=JELLY_D)
        d.ellipse((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=JELLY)
        d.point((x0 + 2, y0 + 2), fill=WHITE)
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2 + 1
        col = GLOW if state == 1 else PURPLE
        d.ellipse((cx - 1, cy - 1, cx + 1, cy + 1), fill=col)
    return add_outline(img)


def _chest_pile(state):
    img, d = canvas(24, 24)

    def chest(x, y, open_=False):
        d.rectangle((x, y + 3, x + 9, y + 8), fill=WOOD)
        d.rectangle((x, y, x + 9, y + 3), fill=WOOD_L if not open_ else WOOD_D)
        d.line((x, y + 3, x + 9, y + 3), fill=WOOD_D)
        d.rectangle((x + 4, y + 3, x + 5, y + 5), fill=GOLD)
        if open_:
            d.line((x + 2, y + 4, x + 7, y + 4), fill=DARK)
            d.point((x + 3, y + 4), fill=GLOW)
            d.point((x + 6, y + 4), fill=GLOW)
    if state == 2:
        for x, y in ((3, 18), (9, 16), (15, 19)):
            d.rectangle((x, y, x + 4, y + 2), fill=WOOD_D)
        d.point((12, 20), fill=GOLD)
        return add_outline(img)
    chest(1, 13)
    chest(13, 13)
    chest(7, 4, open_=state == 1)
    return add_outline(img)


NESTS = [_rat_hole, _fairy_flower, _slime_pool, _jelly_egg, _chest_pile]


def main():
    _strip([vortex(f) for f in range(2)], 48, 48).save(OUT / "vortex.png")
    _strip([bounce_pad(f) for f in range(2)], 16, 16).save(OUT / "bounce_pad.png")
    _strip([soap(f) for f in range(2)], 16, 16).save(OUT / "soap.png")
    sheet = blank(24 * 3, 24 * len(NESTS))
    for row, fn in enumerate(NESTS):
        for state in range(3):
            sheet.alpha_composite(fn(state), (state * 24, row * 24))
    sheet.save(OUT / "nests.png")
    print("vortex / bounce_pad / soap / nests 已生成")


if __name__ == "__main__":
    main()
