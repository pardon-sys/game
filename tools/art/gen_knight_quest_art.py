"""骑士篇四个支线的像素图。

道具（knight_quest_props() 由 gen_town_art.gen_props 加在小镇道具图集的最后，前面道具的图集位置不变）：
  barrel        木桶（地窖、藏手印碎片的地方）
  trapdoor      药剂师工房地板上通往地窖的活板门（地面）
  straw_mat     晒着的稻草垫（地面；支线「骑士救公主」的光脚地面：稻草扎脚心）
  pebble_path   鹅卵石小路（地面；光脚地面：一会儿舒服一会儿痒）
  plank_bundle  一捆栅栏木板（支线「夜里的栅栏」：城墙脚下扛起来）
  fence_gate    钉好的栅栏门
物品图标（16×16，assets/generated/item_<id>.png）：knight_medal（瓶盖和红布条做的「骑士勋章」）、calm_incense（药剂师奶奶的安神香）

用法：python tools/art/gen_knight_quest_art.py（只出图标）；道具跟着 python tools/art/gen_town_art.py 一起出。
"""
from gen_expansion import canvas
from palette import OUT, add_outline

WOOD = (170, 110, 70, 255)
WOOD_D = (110, 70, 45, 255)
WOOD_L = (210, 150, 100, 255)
IRON = (120, 116, 128, 255)
IRON_D = (78, 74, 88, 255)
STRAW = (232, 200, 110, 255)
STRAW_D = (190, 150, 70, 255)
STRAW_L = (250, 228, 160, 255)
PEBBLES = [(176, 168, 176, 255), (150, 142, 154, 255), (196, 186, 190, 255), (164, 150, 140, 255)]
RED = (210, 70, 80, 255)
RED_D = (150, 40, 55, 255)
CAP_C = (220, 200, 120, 255)
CAP_D = (170, 140, 70, 255)
INCENSE = (150, 110, 190, 255)
INCENSE_D = (100, 70, 140, 255)
SMOKE = (225, 215, 245, 200)


def p_barrel():
    img, d = canvas(14, 18)
    d.rectangle((2, 3, 11, 16), fill=WOOD)
    d.ellipse((2, 1, 11, 5), fill=WOOD_L)
    d.ellipse((3, 2, 10, 4), fill=WOOD_D)
    for y in (6, 13):
        d.line((2, y, 11, y), fill=IRON)
    for x in (5, 8):
        d.line((x, 6, x, 16), fill=WOOD_D)
    return add_outline(img)


def p_trapdoor():
    img, d = canvas(16, 16)
    d.rectangle((1, 1, 14, 14), fill=WOOD_D)
    d.rectangle((2, 2, 13, 13), fill=WOOD)
    for x in (6, 10):
        d.line((x, 2, x, 13), fill=WOOD_D)
    d.rectangle((6, 7, 9, 8), fill=IRON)
    d.point((7, 7), fill=IRON_D)
    return img


def p_straw_mat():
    img, d = canvas(32, 16)
    d.rectangle((1, 3, 30, 13), fill=STRAW_D)
    for i in range(0, 30, 2):
        d.line((1 + i, 3, 3 + i, 13), fill=STRAW if i % 4 else STRAW_L)
    for (x, y) in ((4, 2), (12, 14), (22, 2), (28, 14), (17, 1)):
        d.line((x, y, x + 2, y - 1), fill=STRAW)
    return img


def p_pebble_path():
    img, d = canvas(32, 16)
    import random
    rnd = random.Random(7)
    for i in range(22):
        x, y = rnd.randint(1, 27), rnd.randint(2, 11)
        w, h = rnd.randint(2, 4), rnd.randint(2, 3)
        d.ellipse((x, y, x + w, y + h), fill=PEBBLES[i % len(PEBBLES)])
    return img


def p_plank_bundle():
    img, d = canvas(24, 12)
    for i, y in enumerate((2, 5, 8)):
        d.rectangle((1 + (i % 2), y, 22 - (i % 2), y + 2), fill=WOOD_L if i == 0 else WOOD)
        d.line((1 + (i % 2), y + 2, 22 - (i % 2), y + 2), fill=WOOD_D)
    for x in (6, 17):
        d.line((x, 1, x, 11), fill=(130, 100, 70, 255))
    return add_outline(img)


def p_fence_gate():
    img, d = canvas(32, 20)
    for x in (2, 29):
        d.rectangle((x, 2, x + 2, 19), fill=WOOD_D)
    for x in range(6, 28, 4):
        d.rectangle((x, 5, x + 2, 18), fill=WOOD)
        d.point((x + 1, 5), fill=WOOD_L)
    for y in (8, 15):
        d.line((4, y, 28, y), fill=WOOD_D)
    d.line((5, 16, 27, 7), fill=WOOD_D)
    return add_outline(img)


def knight_quest_props():
    """gen_town_art.gen_props 加在图集最后的道具（名字, 图, 信息）。"""
    return [
        ("barrel", p_barrel(), {"body": [10, 6], "body_y": -3}),
        ("trapdoor", p_trapdoor(), {"floor": True}),
        ("straw_mat", p_straw_mat(), {"floor": True, "under": True}),
        ("pebble_path", p_pebble_path(), {"floor": True, "under": True}),
        ("plank_bundle", p_plank_bundle(), {"body": [20, 6], "body_y": -3}),
        ("fence_gate", p_fence_gate(), {"body": [28, 6], "body_y": -3}),
    ]


# ------------------------------------------------------------------ 物品图标（16×16）
def i_knight_medal():
    img, d = canvas(16, 16)
    d.polygon([(5, 0), (7, 6), (9, 6), (11, 0)], fill=RED)
    d.line((8, 0, 8, 6), fill=RED_D)
    d.ellipse((3, 5, 12, 14), fill=CAP_C)
    for i in range(8):
        x = 7.5 + 4.5 * (1 if i in (1, 2, 3) else (-1 if i in (5, 6, 7) else 0))
        d.point((int(x), 5 if i == 0 else 14 if i == 4 else 9), fill=CAP_D)
    d.line((6, 8, 9, 11), fill=RED_D)
    d.line((9, 8, 6, 11), fill=RED_D)
    return add_outline(img)


def i_calm_incense():
    img, d = canvas(16, 16)
    d.rectangle((4, 11, 11, 14), fill=(150, 120, 90, 255))
    d.line((4, 11, 11, 11), fill=(190, 160, 120, 255))
    d.rectangle((7, 4, 8, 11), fill=INCENSE)
    d.point((7, 4), fill=INCENSE_D)
    d.point((8, 3), fill=(255, 190, 120, 255))
    for (x, y) in ((9, 2), (10, 1), (6, 1)):
        d.point((x, y), fill=SMOKE)
    return add_outline(img)


def main():
    i_knight_medal().save(OUT / "item_knight_medal.png")
    i_calm_incense().save(OUT / "item_calm_incense.png")
    print("骑士篇支线的图标：", OUT)


if __name__ == "__main__":
    main()
