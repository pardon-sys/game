"""第五层（机关迷城）和新系统的像素图。

输出到 assets/generated/：
  passive_icons.png   16x16 × 4   被动技能图标（0 挣脱强化，其余占位：问号）
  snare.png 16x16×2 倒吊绳套（地上的绳圈 / 收紧）     cuffs.png 16x32×2 举手铐柱（铐环收着 / 伸出）
  clamp.png 16x16×2 夹腿枷台（张开 / 合拢）           wardrobe.png 16x32×3 挠痒衣柜（关 / 开 / 关着露出两只脚）
  mud.png 16x16×2 痒痒泥沼                           boots.png 16x16×2 痒痒长靴（立着 / 跳动）
  binding.png 16x16×2 羽毛绑腿（盘着 / 飘起）          legloop.png 16x16×2 单腿吊环（地上的绳环影子 / 收紧）
  teaser.png 16x16 × 2 帧 × 4 行 逗弄器（行 = 羽毛 / 刷子 / 史莱姆 / 小触手；帧 = 收着 / 伸出）
  wheel.png 16x16×3 痒痒转轮（羽毛面 / 刷子面 / 手面）  shower.png 16x16×2 羽毛雨喷口（关 / 喷）
  cage.png 64x24 落笼（羽毛笼 / 史莱姆笼 / 触手笼 16x24 + 影子 16x8）
  machine_imp.png 16x16×4 机关小工匠（走 2 帧 / 跑 2 帧）  mini_tentacle.png 16x16×2 小触手

用法：python tools/art/gen_floor5_art.py
"""
from PIL import ImageDraw

from gen_expansion import _strip, blank, canvas
from palette import OUT, add_outline

GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
STEEL = (200, 212, 228, 255)
STEEL_D = (120, 134, 160, 255)
STEEL_L = (230, 236, 246, 255)
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


ROPE = (222, 190, 130, 255)
ROPE_D = (160, 120, 80, 255)
WOOD = (189, 108, 74, 255)
WOOD_D = (120, 64, 48, 255)
WOOD_L = (222, 150, 102, 255)
STONE = (139, 155, 180, 255)
STONE_D = (82, 96, 124, 255)
STONE_L = (192, 203, 220, 255)
FLUFF = (255, 225, 240, 255)
MUD = (205, 110, 160, 255)
MUD_D = (150, 70, 120, 255)
MUD_L = (240, 160, 200, 255)
SLIME = (110, 214, 120, 255)
SLIME_L = (190, 250, 190, 255)
TENT = (230, 120, 190, 255)
TENT_D = (170, 70, 140, 255)
FEATHER = (250, 248, 255, 255)
BRISTLE = (240, 200, 120, 255)
RIBBON = (255, 120, 180, 255)
RIBBON_D = (200, 70, 130, 255)
SKIN = (255, 226, 214, 255)
SKIN_D = (226, 170, 160, 255)
BRASS = (230, 180, 70, 255)
BRASS_D = (170, 120, 40, 255)


def snare(frame):
    img, d = canvas()
    if frame == 0:
        d.ellipse((2, 8, 13, 14), outline=ROPE)
        d.ellipse((3, 9, 12, 13), outline=ROPE_D)
        d.line((13, 11, 15, 6), fill=ROPE)
    else:
        d.ellipse((5, 10, 10, 13), outline=ROPE)
        d.line((7, 10, 7, 0), fill=ROPE)
        d.line((8, 10, 8, 0), fill=ROPE_D)
    return img


def cuffs(frame):
    img, d = canvas(16, 32)
    d.rectangle((4, 4, 11, 30), fill=STONE_D)
    d.rectangle((5, 4, 10, 29), fill=STONE)
    d.line((6, 6, 6, 27), fill=STONE_L)
    d.rectangle((3, 2, 12, 5), fill=STONE_L)
    d.rectangle((3, 28, 12, 31), fill=STONE_D)
    if frame == 0:
        d.ellipse((5, 8, 8, 11), outline=STEEL)
        d.ellipse((8, 8, 11, 11), outline=STEEL)
    else:
        d.line((7, 7, 2, 3), fill=STEEL_D)
        d.line((8, 7, 13, 3), fill=STEEL_D)
        d.ellipse((0, 1, 4, 5), outline=STEEL)
        d.ellipse((11, 1, 15, 5), outline=STEEL)
    return add_outline(img)


def clamp(frame):
    img, d = canvas()
    d.rectangle((1, 11, 14, 14), fill=WOOD_D)
    d.rectangle((2, 11, 13, 13), fill=WOOD)
    gap = 5 if frame == 0 else 1
    for x0 in (1, 15 - 4):
        x = x0 - (gap - 1) // 2 if x0 == 1 else x0 + (gap - 1) // 2
        d.rectangle((max(x, 0), 4, min(x + 3, 15), 11), fill=WOOD)
        d.line((max(x, 0), 4, min(x + 3, 15), 4), fill=WOOD_L)
    for y in (6, 8, 10):
        d.point((5 - (gap - 1) // 2 if gap > 1 else 5, y), fill=FLUFF)
        d.point((10 + (gap - 1) // 2 if gap > 1 else 10, y), fill=FLUFF)
    return add_outline(img)


def wardrobe(frame):
    img, d = canvas(16, 32)
    d.rectangle((1, 3, 14, 30), fill=WOOD_D)
    d.rectangle((2, 4, 13, 29), fill=WOOD)
    d.rectangle((1, 1, 14, 3), fill=WOOD_L)
    if frame == 1:
        d.rectangle((3, 6, 12, 28), fill=DARK)
        for y in (10, 16, 22):
            d.point((5, y), fill=SKIN)
            d.point((10, y + 2), fill=SKIN)
    else:
        d.line((7, 5, 7, 28), fill=WOOD_D)
        d.point((6, 17), fill=BRASS)
        d.point((9, 17), fill=BRASS)
    if frame == 2:
        # 门缝里露出两只脚
        d.rectangle((4, 27, 6, 31), fill=SKIN)
        d.rectangle((9, 27, 11, 31), fill=SKIN)
        d.point((5, 30), fill=SKIN_D)
        d.point((10, 30), fill=SKIN_D)
    return add_outline(img)


def mud(frame):
    img, d = canvas()
    d.rectangle((0, 0, 15, 15), fill=MUD_D)
    d.rectangle((0, 1, 15, 14), fill=MUD)
    spots = [(3, 4), (11, 9), (6, 12), (12, 3)]
    for i, (x, y) in enumerate(spots):
        if (i + frame) % 2 == 0:
            d.ellipse((x - 1, y - 1, x + 1, y + 1), outline=MUD_L)
        else:
            d.point((x, y), fill=MUD_L)
    d.line((2 + frame * 3, 7, 3 + frame * 3, 9), fill=TENT)
    return img


def boots(frame):
    img, d = canvas()
    dy = 0 if frame == 0 else -2
    for x in (2, 9):
        d.rectangle((x, 3 + dy, x + 4, 11 + dy), fill=PINK_D)
        d.rectangle((x, 10 + dy, x + 6, 13 + dy), fill=PINK_D)
        d.rectangle((x + 1, 4 + dy, x + 3, 10 + dy), fill=PINK)
        d.point((x + 2, 2 + dy), fill=FEATHER)
        d.point((x + 3, 1 + dy), fill=FEATHER)
    return add_outline(img)


def binding(frame):
    img, d = canvas()
    if frame == 0:
        d.ellipse((2, 7, 13, 14), outline=RIBBON)
        d.ellipse((4, 9, 11, 12), outline=RIBBON_D)
        d.point((13, 6), fill=FEATHER)
        d.point((14, 5), fill=FEATHER)
    else:
        for y in (3, 7, 11):
            d.line((3, y, 12, y + 2), fill=RIBBON)
        d.point((2, 4), fill=FEATHER)
        d.point((13, 12), fill=FEATHER)
    return add_outline(img)


def legloop(frame):
    img, d = canvas()
    d.ellipse((4, 10, 11, 14), fill=(40, 25, 45, 120))
    if frame == 1:
        d.ellipse((5, 2, 10, 7), outline=ROPE)
        d.line((7, 0, 7, 2), fill=ROPE)
    return img


TEASER_TIPS = ["feather", "brush", "slime", "tentacle"]


def teaser(row, frame):
    img, d = canvas()
    d.rectangle((4, 10, 11, 15), fill=STEEL_D)
    d.rectangle((5, 11, 10, 14), fill=STEEL)
    d.point((7, 12), fill=PINK)
    length = 3 if frame == 0 else 7
    d.line((7, 10, 7, 10 - length), fill=STEEL_D)
    tx, ty = 7, 10 - length
    kind = TEASER_TIPS[row]
    if kind == "feather":
        d.polygon([(tx, ty), (tx - 3, ty - 4), (tx, ty - 6), (tx + 3, ty - 4)], fill=FEATHER)
        d.line((tx, ty, tx, ty - 5), fill=PINK_L)
    elif kind == "brush":
        d.rectangle((tx - 3, ty - 3, tx + 3, ty), fill=WOOD)
        for x in range(tx - 3, tx + 4, 2):
            d.line((x, ty - 3, x, ty - 6), fill=BRISTLE)
    elif kind == "slime":
        d.ellipse((tx - 3, ty - 5, tx + 3, ty + 1), fill=SLIME)
        d.point((tx - 1, ty - 3), fill=SLIME_L)
    else:
        d.line((tx, ty, tx - 2, ty - 3), fill=TENT, width=2)
        d.line((tx - 2, ty - 3, tx + 1, ty - 6), fill=TENT, width=2)
        d.point((tx - 1, ty - 2), fill=TENT_D)
    return add_outline(img)


def wheel(face):
    img, d = canvas()
    d.rectangle((6, 11, 9, 15), fill=STEEL_D)
    d.ellipse((1, 1, 14, 14), fill=BRASS_D)
    d.ellipse((2, 2, 13, 13), fill=BRASS)
    d.ellipse((6, 6, 9, 9), fill=BRASS_D)
    if face == 0:
        d.polygon([(7, 1), (4, 4), (7, 6), (10, 4)], fill=FEATHER)
    elif face == 1:
        d.rectangle((5, 1, 10, 3), fill=WOOD)
        for x in range(5, 11, 2):
            d.point((x, 0), fill=BRISTLE)
    else:
        d.rectangle((5, 0, 10, 4), fill=FEATHER)
        for x in (5, 7, 9):
            d.line((x, 0, x, 1), fill=STEEL_D)
    return add_outline(img)


def shower(frame):
    img, d = canvas()
    d.rectangle((2, 5, 13, 10), fill=STEEL_D)
    d.rectangle((3, 6, 12, 9), fill=DARK)
    for x in (4, 7, 10):
        d.line((x, 6, x, 9), fill=STEEL)
    if frame == 1:
        for x, y in ((4, 12), (8, 13), (11, 12), (6, 14)):
            d.point((x, y), fill=FEATHER)
    return img


def cage_sheet():
    sheet = blank(64, 24)
    for i, inner in enumerate(("feather", "slime", "tentacle")):
        img, d = canvas(16, 24)
        d.rectangle((2, 3, 13, 22), outline=BRASS_D)
        d.arc((2, 0, 13, 7), 180, 360, fill=BRASS_D)
        for x in (5, 8, 11):
            d.line((x, 3, x, 22), fill=BRASS)
        d.line((2, 12, 13, 12), fill=BRASS)
        d.line((7, 0, 7, -2), fill=BRASS)
        if inner == "feather":
            d.polygon([(6, 16), (4, 19), (7, 21), (9, 18)], fill=FEATHER)
            d.point((10, 9), fill=FEATHER)
        elif inner == "slime":
            d.ellipse((4, 15, 11, 21), fill=SLIME)
            d.point((6, 17), fill=SLIME_L)
        else:
            d.line((4, 21, 6, 15), fill=TENT, width=2)
            d.line((10, 21, 9, 14), fill=TENT, width=2)
        sheet.alpha_composite(add_outline(img), (i * 16, 0))
    sh, d = canvas(16, 8)
    d.ellipse((1, 1, 14, 7), fill=(30, 15, 35, 150))
    sheet.alpha_composite(sh, (48, 0))
    return sheet


def machine_imp(frame):
    """机关小工匠：戴护目镜的小精怪，背着扳手，手里拿一根小羽毛。"""
    img, d = canvas()
    run = frame >= 2
    step = frame % 2
    dy = -1 if step else 0
    d.ellipse((4, 4 + dy, 11, 11 + dy), fill=(120, 190, 150, 255))
    d.rectangle((5, 6 + dy, 10, 8 + dy), fill=BRASS_D)
    d.point((6, 7 + dy), fill=(160, 230, 255, 255))
    d.point((9, 7 + dy), fill=(160, 230, 255, 255))
    d.rectangle((5, 11 + dy, 10, 13 + dy), fill=WOOD)
    d.line((5, 14, 5 + (1 if step else 0), 15), fill=WOOD_D)
    d.line((10, 14, 10 - (1 if step else 0), 15), fill=WOOD_D)
    d.line((11, 9 + dy, 14, 4 + dy), fill=STEEL)
    d.point((14, 3 + dy), fill=STEEL_D)
    if run:
        d.line((1, 9 + dy, 3, 9 + dy), fill=STEEL_L)
        d.line((0, 11 + dy, 2, 11 + dy), fill=STEEL_L)
    else:
        d.polygon([(3, 10 + dy), (1, 7 + dy), (2, 6 + dy), (4, 9 + dy)], fill=FEATHER)
    return add_outline(img)


def mini_tentacle(frame):
    img, d = canvas()
    sway = 1 if frame else -1
    d.ellipse((3, 11, 12, 15), fill=TENT_D)
    for x0 in (5, 8, 11):
        d.line((x0, 12, x0 + sway, 7), fill=TENT, width=2)
        d.line((x0 + sway, 7, x0 - sway, 3), fill=TENT, width=1)
        d.point((x0 - sway, 2), fill=PINK_L)
    return add_outline(img)


def gen_traps():
    _strip([snare(f) for f in range(2)], 16, 16).save(OUT / "snare.png")
    _strip([cuffs(f) for f in range(2)], 16, 32).save(OUT / "cuffs.png")
    _strip([clamp(f) for f in range(2)], 16, 16).save(OUT / "clamp.png")
    _strip([wardrobe(f) for f in range(3)], 16, 32).save(OUT / "wardrobe.png")
    _strip([mud(f) for f in range(2)], 16, 16).save(OUT / "mud.png")
    _strip([boots(f) for f in range(2)], 16, 16).save(OUT / "boots.png")
    _strip([binding(f) for f in range(2)], 16, 16).save(OUT / "binding.png")
    _strip([legloop(f) for f in range(2)], 16, 16).save(OUT / "legloop.png")
    t = blank(32, 64)
    for row in range(4):
        for f in range(2):
            t.alpha_composite(teaser(row, f), (f * 16, row * 16))
    t.save(OUT / "teaser.png")
    _strip([wheel(f) for f in range(3)], 16, 16).save(OUT / "wheel.png")
    _strip([shower(f) for f in range(2)], 16, 16).save(OUT / "shower.png")
    cage_sheet().save(OUT / "cage.png")
    _strip([machine_imp(f) for f in range(4)], 16, 16).save(OUT / "machine_imp.png")
    _strip([mini_tentacle(f) for f in range(2)], 16, 16).save(OUT / "mini_tentacle.png")


def main():
    gen_passive_icons()
    gen_traps()
    print("第五层像素图已生成")


if __name__ == "__main__":
    main()
