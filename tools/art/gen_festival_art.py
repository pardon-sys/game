"""第 7 天庆功宴（floor_06_festival）的像素图：战后百废待兴的广场道具、摊位通关以后的装扮、摊位奖励的图标、戴铃铛的咕咕。

道具（festival_props() 由 gen_town_art.gen_props 加在小镇道具图集的最后，前面道具的图集位置不变）：
  totem_fixed      修好的狂欢图腾柱：扶正、缠着绷带木板、裂缝里透出暖光
  tent_patched     打满补丁的帐篷
  wall_half        补了一半的城墙：下半截新砖、上半截搭着脚手架
  lantern_rubble   碎石堆上插着一根挂笑声灯笼的竿子
  lantern_string   两根竿子之间的一串笑声灯笼
  crate_stall      木箱拼的临时摊位
  装扮（摊位通关以后出现，地图上带 show_flag = stall_<id>_done）：
  cookie_lights    饼干串灯（脚底猜猜乐 · 奶奶的摊位）
  ribbon_line      挂满彩色发绳的绳子（忍笑套圈）
  ice_sheep / ice_lantern / ice_girls  三座冰雕：蘑菇羊、笑脸灯笼、手拉手的两个小女孩（冰雕摊）
  ice_raw          还没刻的冰块（冰雕摊通关之前）
  fish_basin       篝火边的足疗鱼盆（捞痒痒鱼）
物品图标（16×16，assets/generated/item_<id>.png）：cookie、souvenir_wood_sheep、souvenir_ice_sheep、souvenir_fish_basin、souvenir_bell_collar
人物：npcs/goat_bell.png（咕咕戴着铃铛项圈，舔盐耐力赛通关以后在广场上闲逛）

用法：python tools/art/gen_festival_art.py（只出图标和咕咕）；道具跟着 python tools/art/gen_town_art.py 一起出。
"""
import math

from PIL import ImageDraw

from gen_expansion import blank, canvas
from palette import OUT, add_outline

WOOD = (170, 110, 70, 255)
WOOD_D = (110, 70, 45, 255)
WOOD_L = (210, 150, 100, 255)
STONE = (150, 140, 150, 255)
STONE_D = (100, 92, 104, 255)
BRICK = (190, 96, 72, 255)
BRICK_D = (140, 64, 52, 255)
BRICK_N = (214, 150, 110, 255)       # 新补的砖（颜色浅）
CLOTH = (200, 170, 130, 255)
CLOTH_D = (150, 120, 90, 255)
EYE = (60, 40, 60, 255)
LANTERN = (255, 196, 110, 255)
LANTERN_D = (220, 130, 70, 255)
ICE = (190, 230, 255, 230)
ICE_D = (120, 180, 230, 230)
ICE_L = (240, 252, 255, 255)
COOKIE = (214, 156, 92, 255)
COOKIE_D = (160, 104, 56, 255)
CHIP = (110, 66, 40, 255)
GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
RIBBONS = [(255, 120, 160), (120, 200, 255), (255, 220, 90), (150, 230, 140), (220, 150, 255)]


def _lantern(d, x, y, glow=True):
    """一盏笑声灯笼（5×6，带一张笑脸）。"""
    d.line((x + 2, y - 2, x + 2, y), fill=WOOD_D)
    d.ellipse((x, y, x + 5, y + 6), fill=LANTERN if glow else LANTERN_D)
    d.line((x, y + 6, x + 5, y + 6), fill=LANTERN_D)
    d.point((x + 1, y + 2), fill=EYE)
    d.point((x + 4, y + 2), fill=EYE)
    d.line((x + 2, y + 4, x + 3, y + 4), fill=EYE)


# ------------------------------------------------------------------ 战后百废待兴的广场
def p_totem_fixed():
    """修好的狂欢图腾柱：三张笑脸扶正了，裂缝缠着绷带木板，顶上的羽毛换了新的，底下摆着一圈小灯笼。"""
    img, d = canvas(32, 54)
    faces = [((230, 110, 150), 40), ((120, 200, 230), 27), ((250, 200, 80), 14)]
    for (r, g, b), y in faces:
        d.rectangle((9, y, 22, y + 12), fill=(r, g, b, 255))
        d.line((9, y + 12, 22, y + 12), fill=(int(r * 0.6), int(g * 0.6), int(b * 0.6), 255))
        d.point((13, y + 4), fill=EYE)
        d.point((18, y + 4), fill=EYE)
        d.arc((12, y + 5, 19, y + 10), 0, 180, fill=EYE)
    # 绷带一样缠着的木板（修补过的地方）
    for y in (24, 37):
        d.rectangle((8, y, 23, y + 2), fill=WOOD_L)
        d.line((8, y + 2, 23, y + 2), fill=WOOD_D)
        d.point((10, y + 1), fill=WOOD_D)
        d.point((21, y + 1), fill=WOOD_D)
    d.polygon([(13, 14), (11, 3), (15, 9)], fill=(255, 140, 200, 255))
    d.polygon([(16, 14), (16, 1), (18, 10)], fill=(140, 230, 255, 255))
    d.polygon([(19, 14), (23, 4), (21, 13)], fill=(255, 230, 120, 255))
    d.ellipse((3, 50, 28, 53), fill=(90, 80, 90, 160))
    for x in (2, 25):
        _lantern(d, x, 45)
    return add_outline(img)


def p_tent_patched():
    """打满补丁的帐篷（攻防战时的伤员帐篷，现在给人歇脚）。"""
    img, d = canvas(36, 30)
    d.polygon([(2, 28), (18, 3), (34, 28)], fill=CLOTH)
    d.polygon([(18, 3), (34, 28), (24, 28)], fill=CLOTH_D)
    d.polygon([(14, 28), (18, 16), (22, 28)], fill=(70, 50, 40, 255))   # 门帘
    for (x, y, c) in ((8, 20, (150, 190, 120)), (24, 12, (200, 120, 130)), (27, 22, (130, 160, 210)), (12, 12, (220, 200, 120))):
        d.rectangle((x, y, x + 4, y + 3), fill=c + (255,))
        d.point((x, y), fill=(250, 250, 240, 255))           # 针脚
        d.point((x + 4, y + 3), fill=(250, 250, 240, 255))
    d.line((18, 3, 18, 0), fill=WOOD_D, width=2)
    return add_outline(img)


def p_wall_half():
    """补了一半的城墙：下半截是新砌的浅色砖，上半截缺口搭着脚手架，旁边挂一盏灯笼。"""
    img, d = canvas(48, 40)
    d.rectangle((2, 22, 45, 38), fill=BRICK_N)
    for row, y in enumerate(range(22, 38, 4)):
        d.line((2, y, 45, y), fill=(180, 120, 90, 255))
        for x in range(2 + (row % 2) * 4, 46, 8):
            d.line((x, y, x, y + 4), fill=(180, 120, 90, 255))
    # 上半截：旧墙只剩左边一截，右边是缺口
    d.rectangle((2, 8, 17, 22), fill=BRICK)
    for y in range(8, 22, 4):
        d.line((2, y, 17, y), fill=BRICK_D)
    d.polygon([(17, 8), (24, 14), (21, 22), (17, 22)], fill=BRICK)
    # 脚手架
    for x in (24, 44):
        d.line((x, 4, x, 38), fill=WOOD_D, width=2)
    for y in (10, 20):
        d.line((22, y, 46, y), fill=WOOD, width=2)
    d.line((24, 20, 44, 10), fill=WOOD_D)
    d.rectangle((30, 16, 37, 19), fill=BRICK_N)          # 搁在脚手架上的一摞砖
    _lantern(d, 39, 11)
    return add_outline(img)


def p_lantern_rubble():
    """碎石堆上插着一根竿子，挂着两盏笑声灯笼。"""
    img, d = canvas(24, 34)
    for (x, y, w, h, c) in ((2, 27, 7, 5, (130, 120, 130)), (8, 24, 8, 8, (110, 100, 110)), (15, 28, 7, 4, (140, 130, 120))):
        d.polygon([(x, y + h), (x + 1, y), (x + w, y + 1), (x + w, y + h)], fill=c + (255,))
    d.line((12, 25, 12, 3), fill=WOOD_D, width=2)
    d.line((12, 5, 20, 7), fill=WOOD_D)
    d.line((12, 5, 4, 8), fill=WOOD_D)
    _lantern(d, 17, 9)
    _lantern(d, 2, 10)
    return add_outline(img)


def p_lantern_string():
    """两根竿子之间的一串笑声灯笼（挂在头顶，不挡路）。"""
    img, d = canvas(48, 26)
    d.line((1, 4, 1, 25), fill=WOOD_D, width=2)
    d.line((46, 4, 46, 25), fill=WOOD_D, width=2)
    d.arc((0, -4, 47, 14), 0, 180, fill=(90, 70, 60, 255))
    for k in range(5):
        x = 6 + k * 8
        y = 5 + int(6 * math.sin(math.pi * ((x + 2) / 47.0)))
        _lantern(d, x, y)
    return add_outline(img)


def p_crate_stall():
    """用木箱和旧帆布拼起来的临时摊位。"""
    img, d = canvas(32, 32)
    d.line((3, 30, 3, 8), fill=WOOD_D, width=2)
    d.line((28, 30, 28, 8), fill=WOOD_D, width=2)
    d.polygon([(1, 10), (16, 5), (31, 10), (31, 13), (1, 13)], fill=(170, 130, 160, 255))   # 旧帆布
    for x in range(1, 31, 6):
        d.polygon([(x, 13), (x + 3, 13), (x + 1, 16)], fill=(200, 160, 190, 255))
    d.point((10, 9), fill=(250, 240, 230, 255))
    for (x, y) in ((2, 21), (12, 21), (22, 21)):
        d.rectangle((x, y, x + 9, y + 9), fill=WOOD)
        d.rectangle((x, y, x + 9, y + 9), outline=WOOD_D)
        d.line((x, y, x + 9, y + 9), fill=WOOD_D)
    return add_outline(img)


# ------------------------------------------------------------------ 摊位通关以后的装扮
def p_cookie_lights():
    """饼干串灯：两根竿子之间挂着一串小饼干，饼干中间夹着小灯泡。"""
    img, d = canvas(40, 22)
    d.line((1, 3, 1, 21), fill=WOOD_D, width=2)
    d.line((38, 3, 38, 21), fill=WOOD_D, width=2)
    d.arc((0, -4, 39, 10), 0, 180, fill=(90, 70, 60, 255))
    for k in range(6):
        x = 4 + k * 6
        y = 3 + int(4 * math.sin(math.pi * ((x + 2) / 39.0)))
        if k % 2 == 0:
            d.ellipse((x, y, x + 4, y + 4), fill=COOKIE)
            d.point((x + 1, y + 1), fill=CHIP)
            d.point((x + 3, y + 3), fill=CHIP)
        else:
            d.ellipse((x + 1, y + 1, x + 3, y + 3), fill=(255, 240, 160, 255))
    return add_outline(img)


def p_ribbon_line():
    """套圈摊前面拉了一根绳，挂满了五颜六色的发绳。"""
    img, d = canvas(40, 22)
    d.line((1, 3, 1, 21), fill=WOOD_D, width=2)
    d.line((38, 3, 38, 21), fill=WOOD_D, width=2)
    d.line((1, 5, 38, 5), fill=(90, 70, 60, 255))
    for k in range(8):
        x = 4 + k * 4
        c = RIBBONS[k % len(RIBBONS)] + (255,)
        d.line((x, 5, x - 1, 11 + (k % 3)), fill=c)
        d.line((x + 1, 5, x + 2, 10 + (k % 2)), fill=c)
        d.point((x, 6), fill=c)
    return add_outline(img)


def _ice_base(d, w):
    d.rectangle((w // 2 - 9, 26, w // 2 + 8, 29), fill=ICE_D)
    d.line((w // 2 - 9, 26, w // 2 + 8, 26), fill=ICE_L)


def p_ice_sheep():
    """冰雕：蘑菇羊。"""
    img, d = canvas(24, 30)
    _ice_base(d, 24)
    d.ellipse((4, 13, 20, 25), fill=ICE)
    d.ellipse((13, 9, 21, 17), fill=ICE)
    d.ellipse((11, 4, 23, 11), fill=ICE_D)
    d.point((18, 12), fill=ICE_D)
    for (x, y) in ((7, 16), (10, 14), (15, 7)):
        d.point((x, y), fill=ICE_L)
    for x in (7, 16):
        d.line((x, 24, x, 26), fill=ICE_D)
    return add_outline(img, (70, 110, 160, 255))


def p_ice_lantern():
    """冰雕：一盏笑脸灯笼。"""
    img, d = canvas(24, 30)
    _ice_base(d, 24)
    d.line((12, 2, 12, 6), fill=ICE_D)
    d.ellipse((4, 6, 20, 25), fill=ICE)
    d.line((4, 15, 20, 15), fill=ICE_D)
    d.point((9, 12), fill=ICE_D)
    d.point((15, 12), fill=ICE_D)
    d.arc((8, 13, 16, 20), 0, 180, fill=ICE_D)
    d.point((7, 9), fill=ICE_L)
    d.point((8, 8), fill=ICE_L)
    return add_outline(img, (70, 110, 160, 255))


def p_ice_girls():
    """冰雕：手拉手的两个小女孩（一个长卷发、一个短发）。"""
    img, d = canvas(28, 32)
    _ice_base(d, 28)
    for cx, long_hair in ((9, True), (19, False)):
        d.ellipse((cx - 4, 4, cx + 4, 12), fill=ICE)
        if long_hair:
            d.rectangle((cx - 5, 7, cx - 3, 16), fill=ICE_D)
            d.rectangle((cx + 3, 7, cx + 5, 16), fill=ICE_D)
        d.polygon([(cx - 5, 26), (cx - 2, 13), (cx + 2, 13), (cx + 5, 26)], fill=ICE)
        d.point((cx - 1, 8), fill=ICE_D)
        d.point((cx + 1, 8), fill=ICE_D)
    d.line((12, 17, 16, 17), fill=ICE_D, width=2)        # 牵着的手
    d.point((7, 6), fill=ICE_L)
    d.point((17, 6), fill=ICE_L)
    return add_outline(img, (70, 110, 160, 255))


def p_ice_raw():
    """还没刻的冰块（冰雕摊通关以前摆在那儿）。"""
    img, d = canvas(20, 22)
    d.rectangle((2, 4, 17, 20), fill=ICE)
    d.polygon([(2, 4), (6, 1), (20, 1), (17, 4)], fill=ICE_L)
    d.line((5, 7, 5, 13), fill=ICE_L)
    d.line((13, 10, 15, 16), fill=ICE_D)
    return add_outline(img, (70, 110, 160, 255))


def p_fish_basin():
    """篝火边的足疗鱼盆：木盆里几条小鱼游来游去。"""
    img, d = canvas(26, 16)
    d.ellipse((1, 3, 24, 15), fill=WOOD)
    d.ellipse((3, 4, 22, 12), fill=(110, 180, 220, 255))
    d.ellipse((5, 5, 20, 10), fill=(140, 205, 235, 255))
    for (x, y, c) in ((7, 7, (255, 150, 90)), (13, 6, (255, 210, 90)), (16, 9, (255, 130, 160))):
        d.line((x, y, x + 2, y), fill=c + (255,))
        d.point((x - 1, y - 1), fill=c + (255,))
        d.point((x - 1, y + 1), fill=c + (255,))
    d.line((3, 14, 22, 14), fill=WOOD_D)
    return add_outline(img)


def festival_props():
    """gen_town_art.gen_props 加在图集最后的道具（名字, 图, 信息）。"""
    lamp = [1.0, 0.75, 0.45]
    return [
        ("totem_fixed", p_totem_fixed(), {"body": [14, 6], "body_y": -3, "light": [1.0, 0.8, 0.6]}),
        ("tent_patched", p_tent_patched(), {"body": [30, 10], "body_y": -5}),
        ("wall_half", p_wall_half(), {"body": [44, 10], "body_y": -5, "light": lamp}),
        ("lantern_rubble", p_lantern_rubble(), {"body": [18, 6], "body_y": -3, "light": lamp}),
        ("lantern_string", p_lantern_string(), {"light": lamp}),
        ("crate_stall", p_crate_stall(), {"body": [28, 8], "body_y": -6}),
        ("cookie_lights", p_cookie_lights(), {"light": [1.0, 0.85, 0.55]}),
        ("ribbon_line", p_ribbon_line(), {}),
        ("ice_sheep", p_ice_sheep(), {"body": [16, 6], "body_y": -3, "light": [0.6, 0.85, 1.0]}),
        ("ice_lantern", p_ice_lantern(), {"body": [16, 6], "body_y": -3, "light": [0.6, 0.85, 1.0]}),
        ("ice_girls", p_ice_girls(), {"body": [18, 6], "body_y": -3, "light": [0.6, 0.85, 1.0]}),
        ("ice_raw", p_ice_raw(), {"body": [16, 6], "body_y": -3}),
        ("fish_basin", p_fish_basin(), {"body": [20, 6], "body_y": -3}),
    ]


# ------------------------------------------------------------------ 摊位奖励的图标（16×16）
def i_cookie():
    img, d = canvas(16, 16)
    d.ellipse((2, 3, 13, 14), fill=COOKIE)
    d.arc((2, 3, 13, 14), 30, 160, fill=COOKIE_D)
    for (x, y) in ((5, 6), (9, 5), (7, 9), (10, 10), (4, 10)):
        d.rectangle((x, y, x + 1, y + 1), fill=CHIP)
    d.point((12, 2), fill=(255, 255, 255, 255))
    return add_outline(img)


def i_wood_sheep():
    img, d = canvas(16, 16)
    d.ellipse((2, 6, 12, 13), fill=WOOD_L)
    d.ellipse((9, 3, 15, 9), fill=WOOD_L)
    d.ellipse((8, 1, 15, 5), fill=(200, 80, 90, 255))
    d.point((12, 6), fill=EYE)
    for x in (4, 9):
        d.line((x, 13, x, 15), fill=WOOD_D)
    d.line((3, 9, 7, 9), fill=WOOD)
    return add_outline(img)


def i_ice_sheep():
    img, d = canvas(16, 16)
    d.ellipse((2, 6, 12, 13), fill=ICE)
    d.ellipse((9, 3, 15, 9), fill=ICE)
    d.ellipse((8, 1, 15, 5), fill=ICE_D)
    d.point((12, 6), fill=ICE_D)
    for x in (4, 9):
        d.line((x, 13, x, 15), fill=ICE_D)
    d.point((4, 8), fill=ICE_L)
    return add_outline(img, (70, 110, 160, 255))


def i_fish_basin():
    img, d = canvas(16, 16)
    d.ellipse((1, 5, 14, 14), fill=WOOD)
    d.ellipse((3, 6, 12, 11), fill=(120, 190, 230, 255))
    d.line((5, 8, 7, 8), fill=(255, 150, 90, 255))
    d.point((4, 7), fill=(255, 150, 90, 255))
    d.line((9, 9, 10, 9), fill=(255, 210, 90, 255))
    d.point((11, 2), fill=(200, 230, 255, 255))
    d.point((12, 4), fill=(200, 230, 255, 255))
    return add_outline(img)


def i_bell_collar():
    img, d = canvas(16, 16)
    d.ellipse((1, 2, 14, 11), outline=(220, 80, 100, 255), width=2)
    d.ellipse((5, 8, 10, 13), fill=GOLD)
    d.line((5, 11, 10, 11), fill=GOLD_D)
    d.point((7, 12), fill=EYE)
    d.point((6, 9), fill=(255, 250, 210, 255))
    return add_outline(img)


ICONS = {"cookie": i_cookie, "souvenir_wood_sheep": i_wood_sheep, "souvenir_ice_sheep": i_ice_sheep,
         "souvenir_fish_basin": i_fish_basin, "souvenir_bell_collar": i_bell_collar}


# ------------------------------------------------------------------ 咕咕戴上铃铛项圈
def goat_bell_sheet():
    """蘑菇羊的行走图上，脖子的位置加一个红项圈 + 金铃铛。"""
    from gen_town_art import goat_frame
    sheet = blank(128, 128)
    for row in range(4):
        for col in range(4):
            f = goat_frame(row, col)
            d = ImageDraw.Draw(f)
            if row in (1, 2):
                face_left = row == 1
                hx = 4 if face_left else 20
                nx = hx + (7 if face_left else 1)
                d.line((nx, 17, nx, 21), fill=(220, 80, 100, 255))
                d.ellipse((nx - 1, 20, nx + 2, 23), fill=GOLD)
            elif row == 0:
                d.line((12, 21, 20, 21), fill=(220, 80, 100, 255))
                d.ellipse((14, 21, 17, 24), fill=GOLD)
                d.point((15, 23), fill=GOLD_D)
            else:
                d.line((12, 18, 20, 18), fill=(220, 80, 100, 255))
            sheet.alpha_composite(f, (col * 32, row * 32))
    return sheet


def main():
    for name, fn in ICONS.items():
        fn().save(OUT / ("item_%s.png" % name))
    (OUT / "npcs").mkdir(exist_ok=True)
    goat_bell_sheet().save(OUT / "npcs" / "goat_bell.png")
    print("庆功宴：图标 %d 个、戴铃铛的咕咕" % len(ICONS))


if __name__ == "__main__":
    main()
