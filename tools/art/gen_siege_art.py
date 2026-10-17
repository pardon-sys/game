"""小镇攻防战的像素图（输出到 assets/generated/siege/）。

  props.png + props.json  静态物件图集（名字 -> 区域）：
    wall_0 / wall_1 / wall_2   城墙一格的墙面（16x32：城垛 + 石墙；0 完好、1 裂缝、2 快塌了）
    wall_shell                 冰墙加固的冰壳（16x32，半透明）
    ladder                     梯子（16x48）
    pad_0 / pad_1              冰塔格（24x16：空着 / 高亮）
    site_0                     敌塔地基（24x16，黑紫色的乱石圈）
    hole                       冒怪的地洞（16x10）
    crystal                    冰晶（8x10，HUD 和掉落用）
    horn                       号角架（16x24，提前开打）
  （冰塔、敌塔、攻城怪、陷阱的图在后面几个函数里，跟着各自的阶段加）

用法：python tools/art/gen_siege_art.py
"""
import json
from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

from palette import OUT, add_outline

DIR = OUT / "siege"
STONE = (150, 140, 152, 255)
STONE_D = (98, 90, 104, 255)
STONE_L = (190, 182, 192, 255)
MORTAR = (70, 62, 76, 255)
WOOD = (170, 110, 70, 255)
WOOD_D = (110, 70, 45, 255)
ICE = (170, 225, 255, 255)
ICE_D = (90, 160, 225, 255)
ICE_L = (235, 250, 255, 255)
DARK = (60, 34, 70, 255)
DARK_L = (110, 60, 120, 255)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def wall_tile(dmg):
    """城墙一格：上面 8 像素是城垛（两个齿），下面是砌好的石块；dmg 越大裂缝越多、掉块。"""
    img, d = canvas(16, 32)
    rnd = random.Random(31 + dmg)
    # 城垛
    d.rectangle((0, 4, 15, 9), fill=STONE)
    d.rectangle((1, 0, 6, 4), fill=STONE)
    d.rectangle((10, 0, 15, 4), fill=STONE)
    d.line((1, 0, 6, 0), fill=STONE_L)
    d.line((10, 0, 15, 0), fill=STONE_L)
    d.line((0, 4, 15, 4), fill=STONE_L)
    # 石块
    d.rectangle((0, 10, 15, 31), fill=STONE_D)
    for row, y in enumerate(range(10, 32, 5)):
        d.line((0, y, 15, y), fill=MORTAR)
        off = 0 if row % 2 == 0 else 4
        for x in range(off, 16, 8):
            d.line((x, y, x, min(y + 5, 31)), fill=MORTAR)
        d.line((0, y + 1, 15, y + 1), fill=STONE)
    if dmg >= 1:
        x, y = rnd.randint(3, 11), 11
        for _ in range(6):
            nx, ny = x + rnd.randint(-2, 2), y + rnd.randint(2, 4)
            d.line((x, y, nx, ny), fill=(30, 24, 34, 255))
            x, y = nx, ny
    if dmg >= 2:
        d.rectangle((10, 0, 15, 3), fill=(0, 0, 0, 0))          # 城垛掉了一块
        d.polygon([(2, 20), (7, 18), (9, 24), (4, 27)], fill=(36, 28, 40, 255))
        for _ in range(3):
            x, y = rnd.randint(1, 14), rnd.randint(12, 30)
            d.line((x, y, x + rnd.randint(-3, 3), y + rnd.randint(2, 5)), fill=(30, 24, 34, 255))
    return img


def wall_shell():
    img, d = canvas(16, 32)
    d.rectangle((0, 0, 15, 31), fill=(170, 225, 255, 90))
    for x in (2, 7, 12):
        d.line((x, 1, x + 2, 30), fill=(235, 250, 255, 150))
    d.rectangle((0, 0, 15, 31), outline=(200, 240, 255, 170))
    return img


def ladder():
    img, d = canvas(16, 48)
    d.line((3, 0, 3, 47), fill=WOOD_D, width=2)
    d.line((12, 0, 12, 47), fill=WOOD_D, width=2)
    for y in range(3, 48, 6):
        d.line((3, y, 12, y), fill=WOOD, width=2)
    return add_outline(img)


def pad(lit):
    img, d = canvas(24, 16)
    d.ellipse((1, 2, 22, 14), fill=(120, 130, 150, 200), outline=(180, 220, 255, 255) if lit else (110, 140, 170, 230))
    d.ellipse((5, 4, 18, 12), outline=ICE if lit else (130, 170, 200, 200))
    c = (12, 8)
    for a in range(6):
        ang = a * math.pi / 3
        d.line((c[0], c[1], c[0] + round(math.cos(ang) * 5), c[1] + round(math.sin(ang) * 3)), fill=ICE_L if lit else ICE_D)
    return img


def site():
    img, d = canvas(24, 16)
    d.ellipse((1, 3, 22, 15), fill=(50, 30, 58, 210))
    for (x, y) in ((3, 6), (9, 3), (16, 4), (19, 9), (12, 11), (5, 11)):
        d.polygon([(x, y + 4), (x + 1, y), (x + 4, y + 1), (x + 4, y + 4)], fill=DARK_L)
    d.ellipse((9, 6, 14, 10), fill=(170, 60, 160, 230))
    return img


def hole():
    img, d = canvas(16, 10)
    d.ellipse((0, 1, 15, 9), fill=(70, 50, 40, 255))
    d.ellipse((3, 3, 12, 8), fill=(20, 12, 10, 255))
    for x in (1, 13):
        d.point((x, 2), fill=(120, 90, 70, 255))
    return img


def crystal():
    img, d = canvas(8, 10)
    d.polygon([(4, 0), (7, 4), (4, 9), (1, 4)], fill=ICE)
    d.polygon([(4, 0), (4, 9), (1, 4)], fill=ICE_D)
    d.line((4, 1, 4, 6), fill=ICE_L)
    return add_outline(img)


def horn():
    img, d = canvas(16, 24)
    d.line((8, 10, 8, 23), fill=WOOD_D, width=2)
    d.line((3, 23, 13, 23), fill=WOOD_D, width=2)
    d.polygon([(2, 4), (12, 2), (14, 8), (4, 9)], fill=(230, 200, 120, 255))
    d.ellipse((11, 1, 15, 9), fill=(250, 230, 160, 255), outline=(180, 140, 70, 255))
    d.line((3, 6, 12, 5), fill=(180, 140, 70, 255))
    return add_outline(img)


# ================================================================ 冰塔（6 种 × 2 级，24x32）
def ice_base(d, lvl):
    d.ellipse((2, 25, 21, 31), fill=(120, 150, 180, 255))
    d.ellipse((4, 26, 19, 30), fill=ICE_D)
    if lvl >= 2:
        for x in (3, 18):
            d.polygon([(x, 28), (x + 1, 21), (x + 3, 28)], fill=ICE_L)


def crystal_spire(d, x0, y0, x1, y1, col=ICE, dark=ICE_D, light=ICE_L):
    cx = (x0 + x1) // 2
    d.polygon([(cx, y0), (x1, y0 + (y1 - y0) // 3), (x1 - 1, y1), (x0 + 1, y1), (x0, y0 + (y1 - y0) // 3)], fill=col)
    d.polygon([(cx, y0), (x0, y0 + (y1 - y0) // 3), (x0 + 1, y1), (cx, y1)], fill=dark)
    d.line((cx + 1, y0 + 3, cx + 1, y1 - 3), fill=light)


def tower(kind, lvl):
    img, d = canvas(24, 32)
    ice_base(d, lvl)
    if kind == "icicle":
        crystal_spire(d, 6, 4 - (2 if lvl > 1 else 0), 17, 27)
        for (x, y) in ((4, 12), (17, 10)):
            d.polygon([(x, y), (x + 3, y + 2), (x + 1, y + 5)], fill=ICE_L)
        if lvl > 1:
            crystal_spire(d, 1, 12, 7, 26)
            crystal_spire(d, 16, 12, 22, 26)
    elif kind == "snowman":
        d.ellipse((5, 14, 18, 27), fill=(245, 250, 255, 255), outline=(180, 205, 230, 255))
        d.ellipse((7, 5, 16, 15), fill=(245, 250, 255, 255), outline=(180, 205, 230, 255))
        d.point((10, 9), fill=(40, 40, 60, 255)); d.point((13, 9), fill=(40, 40, 60, 255))
        d.polygon([(11, 11), (12, 11), (15, 12)], fill=(255, 150, 60, 255))
        d.rectangle((6, 14, 17, 15), fill=(255, 120, 160, 255))
        if lvl > 1:
            d.rectangle((8, 1, 15, 5), fill=(60, 60, 90, 255)); d.rectangle((6, 4, 17, 5), fill=(60, 60, 90, 255))
    elif kind == "decoy":
        # 公主形状的漂亮冰雕
        d.polygon([(11, 3), (14, 6), (13, 10), (10, 10), (9, 6)], fill=ICE_L)
        d.polygon([(6, 26), (9, 11), (14, 11), (17, 26)], fill=ICE)
        d.polygon([(6, 26), (9, 11), (11, 11), (11, 26)], fill=ICE_D)
        d.polygon([(9, 2), (11, 0), (12, 2), (14, 0), (14, 3), (9, 3)], fill=(255, 230, 140, 255))
        if lvl > 1:
            for (x, y) in ((3, 8), (19, 14), (4, 20)):
                d.point((x, y), fill=(255, 255, 255, 255)); d.point((x + 1, y), fill=ICE_L)
    elif kind == "mint":
        d.ellipse((3, 16, 20, 27), fill=(120, 230, 200, 255), outline=(60, 160, 140, 255))
        d.ellipse((6, 18, 17, 24), fill=(190, 255, 235, 255))
        d.line((11, 6, 11, 17), fill=(150, 240, 220, 255), width=2)
        for (x, y) in ((7, 8), (15, 6), (10, 3)):
            d.ellipse((x, y, x + 3, y + 3), fill=(200, 255, 240, 220))
        if lvl > 1:
            d.polygon([(2, 14), (6, 10), (5, 16)], fill=(90, 200, 120, 255)); d.polygon([(21, 14), (17, 10), (18, 16)], fill=(90, 200, 120, 255))
    elif kind == "frost":
        crystal_spire(d, 8, 6, 15, 26, (200, 235, 255, 255), (130, 190, 240, 255))
        for a in range(6):
            ang = a * math.pi / 3
            d.line((11, 12, 11 + round(math.cos(ang) * 8), 12 + round(math.sin(ang) * 8)), fill=ICE_L)
        if lvl > 1:
            d.ellipse((2, 4, 21, 20), outline=(220, 245, 255, 200))
    else:  # repair
        d.rectangle((6, 12, 17, 27), fill=STONE)
        d.rectangle((6, 12, 17, 14), fill=STONE_L)
        crystal_spire(d, 8, 2, 15, 13)
        d.line((5, 20, 18, 20), fill=ICE, width=2)
        if lvl > 1:
            d.rectangle((3, 16, 5, 27), fill=ICE_D); d.rectangle((18, 16, 20, 27), fill=ICE_D)
    return add_outline(img)


# ================================================================ 敌塔（10 种，24x40；黑紫木头 + 怪物的装饰）
EWOOD = (90, 50, 70, 255)
EWOOD_D = (55, 28, 45, 255)
EGLOW = (220, 90, 200, 255)


def etower_frame(d):
    d.polygon([(4, 38), (7, 12), (16, 12), (19, 38)], fill=EWOOD)
    d.polygon([(4, 38), (7, 12), (10, 12), (8, 38)], fill=EWOOD_D)
    d.line((5, 26, 18, 26), fill=EWOOD_D)
    d.ellipse((1, 34, 22, 39), fill=(50, 30, 58, 230))


def etower(kind):
    if kind in ("airdrop", "brush_battery", "resonance"):
        from puppet_art import tower
        return tower(kind)
    img, d = canvas(24, 40)
    etower_frame(d)
    if kind == "vine_pull":
        for x in (3, 20):
            d.line((x, 36, 11, 6), fill=(90, 170, 80, 255), width=2)
        d.ellipse((7, 2, 16, 11), fill=(120, 200, 100, 255)); d.ellipse((9, 4, 14, 9), fill=(255, 120, 180, 255))
    elif kind == "tailor":
        d.rectangle((5, 4, 18, 13), fill=(240, 200, 230, 255), outline=(150, 80, 130, 255))
        d.line((8, 8, 15, 8), fill=(150, 80, 130, 255))
        d.polygon([(16, 2), (21, 0), (20, 4)], fill=(200, 200, 220, 255))   # 剪刀
        d.ellipse((2, 15, 7, 20), fill=(255, 180, 210, 255))                 # 小手
    elif kind == "glue":
        d.ellipse((5, 4, 18, 14), fill=(190, 230, 120, 255), outline=(110, 150, 60, 255))
        for x in (7, 11, 15):
            d.line((x, 14, x, 18 + (x % 3)), fill=(170, 220, 100, 255), width=2)
    elif kind == "net":
        d.line((11, 2, 11, 14), fill=EWOOD_D, width=2)
        d.line((11, 3, 21, 8), fill=EWOOD_D, width=2)
        for i in range(4):
            d.line((14 + i * 2, 8, 13 + i * 2, 16), fill=(230, 220, 200, 255))
            d.line((13, 10 + i * 2, 21, 10 + i * 2), fill=(230, 220, 200, 255))
    elif kind == "silence":
        d.polygon([(11, 0), (17, 8), (11, 15), (5, 8)], fill=(150, 80, 220, 255))
        d.polygon([(11, 3), (14, 8), (11, 12), (8, 8)], fill=(220, 170, 255, 255))
        d.line((3, 4, 19, 12), fill=(255, 90, 120, 255), width=1)
    elif kind == "portal":
        d.ellipse((3, 1, 20, 18), fill=(40, 10, 50, 255), outline=EGLOW)
        d.ellipse((7, 5, 16, 14), fill=(120, 40, 140, 255))
        d.ellipse((9, 7, 14, 12), fill=(250, 150, 240, 255))
    elif kind == "windmill":
        d.ellipse((9, 6, 14, 11), fill=(200, 180, 150, 255))
        for ang in (0.4, 2.0, 3.6, 5.2):
            d.polygon([(11.5, 8.5), (11.5 + math.cos(ang) * 10, 8.5 + math.sin(ang) * 10),
                       (11.5 + math.cos(ang + 0.5) * 9, 8.5 + math.sin(ang + 0.5) * 9)], fill=(230, 220, 240, 255))
    elif kind == "totem":
        for i, c in enumerate(((255, 120, 170), (255, 200, 90), (150, 220, 255))):
            y = 2 + i * 6
            d.rectangle((6, y, 17, y + 5), fill=c + (255,), outline=(70, 30, 60, 255))
            d.point((9, y + 2), fill=(30, 20, 30, 255)); d.point((14, y + 2), fill=(30, 20, 30, 255))
            d.line((9, y + 4, 14, y + 4), fill=(30, 20, 30, 255))
        d.polygon([(2, 4), (6, 3), (6, 7)], fill=(255, 220, 120, 255)); d.polygon([(21, 4), (17, 3), (17, 7)], fill=(255, 220, 120, 255))
    elif kind == "thigh_tower":
        for i, (x, y) in enumerate(((5, 4), (12, 2), (16, 7))):
            d.ellipse((x, y, x + 5, y + 6), fill=(190, 140, 230, 255), outline=(110, 60, 150, 255))
            d.line((x + 1, y + 1, x + 1, y - 2), fill=(190, 140, 230, 255))
        d.ellipse((8, 12, 15, 16), fill=EGLOW)
    elif kind == "catapult":
        d.line((4, 14, 19, 4), fill=(150, 100, 60, 255), width=2)                 # 投掷臂
        d.ellipse((15, 0, 22, 6), fill=(110, 90, 80, 255), outline=(60, 45, 40, 255))   # 兜里的石头
        d.rectangle((1, 12, 7, 18), fill=(80, 70, 90, 255), outline=(40, 30, 50, 255))  # 配重
        d.line((11, 9, 11, 14), fill=EWOOD_D, width=2)
        d.ellipse((9, 13, 13, 17), fill=EGLOW)
    else:  # sole_tower
        d.rectangle((5, 6, 18, 12), fill=(230, 200, 140, 255), outline=(140, 100, 60, 255))
        for x in range(6, 18, 2):
            d.line((x, 12, x, 16), fill=(250, 240, 200, 255))
        d.ellipse((1, 2, 6, 8), fill=(255, 190, 210, 255)); d.ellipse((17, 1, 22, 7), fill=(255, 190, 210, 255))
    return add_outline(img)


def snowman(f):
    img, d = canvas(14, 16)
    d.ellipse((2, 7, 11, 15), fill=(245, 250, 255, 255), outline=(170, 200, 230, 255))
    d.ellipse((3, 1 + f, 10, 8 + f), fill=(245, 250, 255, 255), outline=(170, 200, 230, 255))
    d.point((5, 4 + f), fill=(40, 40, 60, 255)); d.point((8, 4 + f), fill=(40, 40, 60, 255))
    d.point((7, 5 + f), fill=(255, 150, 60, 255))
    d.line((0, 9, 3, 10 - f), fill=WOOD_D); d.line((13, 9, 10, 10 - f), fill=WOOD_D)
    return add_outline(img)


def glue_puddle():
    img, d = canvas(32, 16)
    d.ellipse((1, 3, 31, 15), fill=(170, 220, 100, 170))
    d.ellipse((6, 5, 24, 12), fill=(200, 240, 130, 190))
    for (x, y) in ((9, 7), (20, 9)):
        d.ellipse((x, y, x + 3, y + 2), fill=(240, 255, 200, 220))
    return img


def hand_proj(col):
    img, d = canvas(10, 10)
    d.ellipse((2, 4, 8, 9), fill=col)
    for x in (2, 4, 6, 8):
        d.line((x, 4, x, 1), fill=col)
    return add_outline(img)


def brush_proj():
    img, d = canvas(12, 8)
    d.rectangle((1, 1, 8, 4), fill=(230, 200, 140, 255))
    for x in range(1, 9, 2):
        d.line((x, 4, x, 7), fill=(250, 240, 210, 255))
    d.ellipse((8, 0, 11, 4), fill=(255, 190, 210, 255))
    return add_outline(img)


def equip_proj():
    img, d = canvas(12, 12)
    d.ellipse((1, 1, 11, 11), fill=(255, 170, 220, 255), outline=(160, 60, 130, 255))
    d.line((4, 6, 8, 6), fill=(255, 255, 255, 255)); d.line((6, 4, 6, 8), fill=(255, 255, 255, 255))
    return add_outline(img)


def net_tile():
    img, d = canvas(20, 20)
    for i in range(0, 20, 4):
        d.line((i, 0, i, 19), fill=(235, 225, 200, 220))
        d.line((0, i, 19, i), fill=(235, 225, 200, 220))
    return img


def gen_towers():
    items = []
    for k in ("icicle", "snowman", "decoy", "mint", "frost", "repair"):
        for lvl in (1, 2):
            items.append(("tower_%s_%d" % (k, lvl), tower(k, lvl)))
        items.append(("tower_%s_3" % k, lvl3(tower(k, 2))))
    for k in ("campfire", "ballista", "cocoa"):
        for lvl in (1, 2):
            items.append(("tower_%s_%d" % (k, lvl), tower3(k, lvl)))
        items.append(("tower_%s_3" % k, lvl3(tower3(k, 2))))
    for k in ("mortar", "vortex", "resonance", "meteor", "hotspring", "lamp", "shield"):
        for lvl in (1, 2, 3):
            items.append(("tower_%s_%d" % (k, lvl), tower5(k, lvl)))
    items += [("proj_mortar", mortar_proj()), ("proj_meteor", meteor_proj()), ("proj_snowball", snowball_proj())]
    for k in ETOWERS:
        items.append(("etower_" + k, etower(k)))
    items += [("proj_bolt", bolt_proj()), ("banner_0", banner(0)), ("banner_1", banner(1))]
    items += [("snowman_0", snowman(0)), ("snowman_1", snowman(1)), ("glue", glue_puddle()),
              ("proj_hand", hand_proj((190, 140, 230, 255))), ("proj_brush", brush_proj()), ("proj_equip", equip_proj()),
              ("proj_icicle", icicle_proj()), ("net", net_tile()), ("proj_arrow", arrow_proj())]
    from puppet_art import tool
    for key in ("tool_finger", "tool_roller", "tool_pad", "tool_capsule"):
        items.append((key, tool(key)))
    pack(items, "towers")


def arrow_proj():
    img, d = canvas(4, 12)
    d.line((2, 2, 2, 11), fill=WOOD, width=1)
    d.polygon([(0, 3), (2, 0), (4, 3)], fill=(220, 220, 230, 255))
    d.line((1, 10, 3, 10), fill=(255, 255, 255, 255))
    return add_outline(img)


def icicle_proj():
    img, d = canvas(6, 10)
    d.polygon([(1, 0), (5, 0), (3, 9)], fill=ICE)
    d.line((3, 1, 3, 6), fill=ICE_L)
    return add_outline(img)


ETOWERS = ["vine_pull", "tailor", "glue", "net", "silence", "portal", "windmill", "totem", "thigh_tower", "sole_tower", "airdrop", "brush_battery", "resonance",
           "catapult"]


def pack(items, name):
    x = y = row_h = 0
    meta, placed = {}, []
    for key, img in items:
        w, h = img.size
        if x + w > 256:
            x, y, row_h = 0, y + row_h, 0
        placed.append((img, x, y))
        meta[key] = [x, y, w, h]
        x += w
        row_h = max(row_h, h)
    sheet = Image.new("RGBA", (256, y + row_h), (0, 0, 0, 0))
    for img, px, py in placed:
        sheet.alpha_composite(img, (px, py))
    sheet.save(DIR / (name + ".png"))
    (DIR / (name + ".json")).write_text(json.dumps(meta, ensure_ascii=False, indent="\t") + "\n")
    return meta


def gen_props():
    items = [("wall_%d" % i, wall_tile(i)) for i in range(3)]
    items += [("wall_shell", wall_shell()), ("ladder", ladder()), ("pad_0", pad(False)), ("pad_1", pad(True)),
              ("site_0", site()), ("hole", hole()), ("crystal", crystal()), ("horn", horn())]
    pack(items, "props")


# ================================================================ 攻城怪物（每种 2 帧：<名字>_0 / _1）
def m_cart(f):
    img, d = canvas(32, 26)
    d.rectangle((3, 6, 28, 18), fill=(140, 90, 60, 255), outline=(80, 50, 35, 255))
    d.polygon([(28, 9), (31, 12), (28, 15)], fill=(200, 200, 210, 255))          # 撞角
    for x in (9, 22):
        d.ellipse((x - 4, 16 + f, x + 4, 24 + f), fill=(70, 50, 40, 255), outline=(40, 30, 25, 255))
        d.line((x - 3, 20 + f, x + 3, 20 + f), fill=(150, 120, 90, 255))
    for i, x in enumerate((7, 13, 19)):   # 车上一排挥舞的小手 / 羽毛
        d.ellipse((x, 1 + (f + i) % 2, x + 4, 6 + (f + i) % 2), fill=(255, 180, 215, 255))
    d.line((5, 10, 26, 10), fill=(200, 140, 90, 255))
    return add_outline(img)


def m_hook(f):
    img, d = canvas(16, 18)
    d.ellipse((3, 6, 12, 16), fill=(120, 100, 150, 255))
    d.ellipse((4, 2, 11, 9), fill=(150, 130, 180, 255))
    d.point((6, 5), fill=(255, 255, 255, 255)); d.point((9, 5), fill=(255, 255, 255, 255))
    d.line((12, 8, 15, 3 + f), fill=(180, 180, 190, 255), width=1)
    d.arc((12, 0 + f, 16, 5 + f), 180, 360, fill=(200, 200, 210, 255))
    return add_outline(img)


def m_vine(f):
    img, d = canvas(16, 18)
    d.ellipse((3, 9, 13, 17), fill=(80, 150, 70, 255))
    for i, x in enumerate((2, 7, 12)):
        d.line((x + 1, 10, x + (1 if (f + i) % 2 else -1), 2), fill=(110, 190, 90, 255), width=2)
    d.ellipse((6, 11, 10, 14), fill=(255, 130, 190, 255))
    return add_outline(img)


def m_gecko(f):
    img, d = canvas(16, 14)
    d.ellipse((4, 4, 12, 11), fill=(130, 210, 140, 255))
    d.ellipse((5, 1, 11, 6), fill=(150, 230, 160, 255))
    d.point((6, 3), fill=(30, 30, 30, 255)); d.point((10, 3), fill=(30, 30, 30, 255))
    for (x, y) in ((2, 5 + f), (13, 5 - f), (2, 10 - f), (13, 10 + f)):
        d.line((8, 7, x, y), fill=(110, 180, 120, 255))
    d.line((8, 11, 8 + (2 if f else -2), 13), fill=(110, 180, 120, 255))
    return add_outline(img)


def m_shield_crab(f):
    img, d = canvas(22, 16)
    d.ellipse((5, 6, 17, 14), fill=(220, 100, 80, 255))
    d.rectangle((1, 1, 21, 6 - f), fill=(170, 170, 185, 255), outline=(100, 100, 115, 255))   # 举起的大钳子像盾
    d.line((3, 3, 19, 3), fill=(210, 210, 225, 255))
    for x in (6, 15):
        d.line((x, 13, x - 2 + f * 2, 15), fill=(200, 80, 60, 255))
    return add_outline(img)


def m_bat_swarm(f):
    img, d = canvas(24, 16)
    for (x, y) in ((2, 6), (10, 2), (16, 8)):
        y += f if x != 10 else -f
        d.polygon([(x, y + 3), (x + 3, y), (x + 4, y + 3), (x + 5, y), (x + 8, y + 3), (x + 4, y + 5)], fill=(170, 120, 200, 255))
        d.point((x + 3, y + 2), fill=(255, 255, 255, 255))
        d.line((x + 4, y + 5, x + 5, y + 8), fill=(255, 255, 255, 255))   # 羽毛
    return add_outline(img)


def m_carrier(f):
    img, d = canvas(26, 16)
    d.line((1, 4, 25, 4), fill=WOOD, width=2)   # 抬人的杆子
    for i, x in enumerate((2, 10, 18)):
        y = 6 + ((f + i) % 2)
        d.ellipse((x, y, x + 6, y + 8), fill=(120, 90, 130, 255))
        d.polygon([(x + 1, y + 1), (x + 2, y - 2), (x + 3, y + 1)], fill=(120, 90, 130, 255))
        d.point((x + 2, y + 3), fill=(255, 220, 90, 255)); d.point((x + 4, y + 3), fill=(255, 220, 90, 255))
    return add_outline(img)


def m_warm_slime(f):
    img, d = canvas(16, 14)
    h = 9 if f == 0 else 8
    d.ellipse((1, 13 - h, 15, 13), fill=(255, 140, 80, 255))
    d.ellipse((4, 14 - h, 10, 10 - h // 2), fill=(255, 210, 140, 255))
    d.point((5, 9), fill=(60, 30, 20, 255)); d.point((10, 9), fill=(60, 30, 20, 255))
    d.line((7, 1, 7, 3 - f), fill=(255, 220, 160, 200)); d.line((10, 2, 11, 0 + f), fill=(255, 220, 160, 200))   # 热气
    return add_outline(img)


def m_thigh_spider(f):
    img, d = canvas(18, 14)
    d.ellipse((5, 3, 13, 11), fill=(150, 90, 200, 255))
    d.ellipse((7, 1, 11, 5), fill=(190, 140, 230, 255))
    for i, (x, y) in enumerate(((1, 2), (1, 8), (16, 2), (16, 8), (2, 12), (15, 12))):
        d.line((9, 7, x, y + (f if i % 2 else -f)), fill=(120, 70, 170, 255))
    d.point((8, 3), fill=(255, 120, 200, 255)); d.point((10, 3), fill=(255, 120, 200, 255))
    return add_outline(img)


def m_hug_bear(f):
    img, d = canvas(18, 18)
    d.ellipse((3, 6, 15, 17), fill=(200, 150, 110, 255))
    d.ellipse((4, 1, 14, 10), fill=(210, 160, 120, 255))
    d.ellipse((3, 0, 7, 4), fill=(210, 160, 120, 255)); d.ellipse((11, 0, 15, 4), fill=(210, 160, 120, 255))
    d.point((7, 5), fill=(40, 30, 30, 255)); d.point((11, 5), fill=(40, 30, 30, 255))
    d.ellipse((8, 6, 10, 8), fill=(255, 150, 170, 255))
    d.line((3, 9, 0, 6 - f), fill=(190, 140, 100, 255), width=2); d.line((15, 9, 18, 6 - f), fill=(190, 140, 100, 255), width=2)
    d.ellipse((6, 10, 12, 15), fill=(240, 210, 180, 255))
    return add_outline(img)


def m_suck_jelly(f):
    img, d = canvas(16, 20)
    d.ellipse((1, 1 + f, 15, 11 + f), fill=(150, 200, 255, 200), outline=(90, 140, 220, 255))
    d.ellipse((4, 3 + f, 9, 7 + f), fill=(230, 245, 255, 220))
    for x in (3, 6, 9, 12):
        d.line((x, 10 + f, x + (1 if f else -1), 18), fill=(170, 210, 255, 230))
    d.ellipse((6, 6 + f, 10, 9 + f), fill=(220, 120, 255, 230))
    return add_outline(img)


def m_twin_ghost(f, col):
    img, d = canvas(16, 18)
    d.ellipse((2, 1 + f, 14, 13 + f), fill=col)
    d.polygon([(2, 8 + f), (14, 8 + f), (14, 16), (11, 13 + f), (8, 16), (5, 13 + f), (2, 16)], fill=col)
    d.point((6, 6 + f), fill=(30, 20, 40, 255)); d.point((10, 6 + f), fill=(30, 20, 40, 255))
    d.arc((6, 7 + f, 10, 10 + f), 0, 180, fill=(30, 20, 40, 255))
    return add_outline(img)


def m_engineer(f):
    img, d = canvas(16, 18)
    d.line((1, 4 + f, 15, 2 + f), fill=WOOD, width=3)          # 扛着的木料
    d.line((1, 4 + f, 15, 2 + f), fill=WOOD_D, width=1)
    d.ellipse((4, 7, 12, 17), fill=(110, 170, 90, 255))
    d.ellipse((4, 4, 12, 11), fill=(130, 190, 100, 255))
    d.polygon([(3, 7), (0, 5), (4, 9)], fill=(130, 190, 100, 255))
    d.polygon([(13, 7), (16, 5), (12, 9)], fill=(130, 190, 100, 255))
    d.rectangle((5, 3, 11, 5), fill=(230, 180, 60, 255))       # 安全帽
    d.point((6, 8), fill=(30, 30, 30, 255)); d.point((10, 8), fill=(30, 30, 30, 255))
    d.line((6, 16, 6 - f, 17), fill=(80, 120, 60, 255)); d.line((10, 16, 10 + f, 17), fill=(80, 120, 60, 255))
    return add_outline(img)


def m_bugler(f):
    """号手小鬼：紫色小鬼，举着铜号，背后插一面小红旗（f = 号口抬起 / 放下）。"""
    img, d = canvas(16, 18)
    d.line((3, 2, 3, 12), fill=WOOD_D, width=1)                              # 旗杆
    d.polygon([(4, 2), (9, 3 + f), (4, 6)], fill=(230, 70, 80, 255))          # 小红旗
    d.ellipse((4, 8, 12, 17), fill=(150, 100, 190, 255))
    d.ellipse((4, 5, 12, 12), fill=(170, 120, 210, 255))
    d.polygon([(4, 7), (2, 3), (6, 6)], fill=(170, 120, 210, 255)); d.polygon([(12, 7), (14, 3), (10, 6)], fill=(170, 120, 210, 255))  # 小角
    d.point((6, 9), fill=(30, 30, 30, 255)); d.point((10, 9), fill=(30, 30, 30, 255))
    d.line((10, 11, 14, 9 - f * 2), fill=(230, 190, 80, 255), width=2)       # 铜号
    d.polygon([(13, 8 - f * 2), (16, 6 - f * 2), (16, 11 - f * 2)], fill=(250, 210, 90, 255))
    d.line((6, 16, 6 - f, 17), fill=(110, 70, 140, 255)); d.line((10, 16, 10 + f, 17), fill=(110, 70, 140, 255))
    return add_outline(img)


MONSTERS = {
    "engineer": m_engineer,
    "bugler": m_bugler,
    "general": None,
    "cart": m_cart, "hook": m_hook, "vine": m_vine, "gecko": m_gecko, "shield_crab": m_shield_crab, "bat_swarm": m_bat_swarm,
    "carrier": m_carrier, "warm_slime": m_warm_slime, "thigh_spider": m_thigh_spider, "hug_bear": m_hug_bear,
    "suck_jelly": m_suck_jelly,
    "twin_ghost_a": lambda f: m_twin_ghost(f, (255, 190, 225, 230)), "twin_ghost_b": lambda f: m_twin_ghost(f, (180, 210, 255, 230)),
}


def m_gale_bear(frame):
    """读取直接生成的熊统领像素帧；import_gale_bear.py 只负责源图切帧与对齐。"""
    src = Path(__file__).resolve().parent / "src" / ("gale_bear_%d.png" % frame)
    return Image.open(src).convert("RGBA")


def gen_monsters():
    items = []
    for k, fn in MONSTERS.items():
        if k == "general":
            for f in range(5):
                items.append(("general_%d" % f, m_general(f)))
            continue
        for f in (0, 1):
            items.append(("%s_%d" % (k, f), fn(f)))
    for frame in range(8):
        items.append(("gale_bear_%d" % frame, m_gale_bear(frame)))
    from puppet_art import boss
    for frame in range(8):
        items.append(("puppet_master_%d" % frame, boss(frame)))
    pack(items, "monsters")


def fit_icon(img, size=16):
    """把一张图裁掉透明边、等比缩到 size×size 里（最近邻），居中。"""
    bb = img.getbbox()
    if bb:
        img = img.crop(bb)
    w, h = img.size
    k = min(size / w, size / h)
    img = img.resize((max(1, round(w * k)), max(1, round(h * k))), Image.NEAREST)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(img, ((size - img.size[0]) // 2, (size - img.size[1]) // 2))
    return out


def hazard_icon(kind):
    img, d = canvas(16, 16)
    if kind == "tornado":
        for i in range(4):
            d.arc((3 - i, 2 + i * 3, 13 + i, 7 + i * 3), 0, 360, fill=(220, 180, 255, 255))
    elif kind == "bubbles":
        for (x, y, r) in ((2, 6, 5), (8, 3, 4), (9, 9, 5)):
            d.ellipse((x, y, x + r * 1.4, y + r * 1.4), outline=(190, 230, 255, 255), fill=(170, 220, 255, 90))
    elif kind == "link_rune":
        d.polygon([(8, 1), (13, 6), (11, 14), (5, 14), (3, 6)], fill=(110, 80, 120, 255))
        d.ellipse((6, 6, 10, 10), outline=(255, 140, 210, 255))
    elif kind == "broom":
        d.line((2, 2, 9, 9), fill=(150, 100, 60, 255), width=2)
        for i in range(5):
            d.line((9, 9, 11 + i, 15 - i), fill=(255, 255, 255, 255))
    elif kind == "fog":
        for (x, y) in ((1, 6), (6, 3), (8, 8)):
            d.ellipse((x, y, x + 8, y + 6), fill=(255, 180, 220, 160))
    elif kind == "wall_vine":
        d.rectangle((1, 1, 15, 15), fill=(130, 120, 135, 255))
        d.line((4, 15, 7, 8), fill=(90, 170, 80, 255), width=2); d.line((7, 8, 11, 2), fill=(90, 170, 80, 255), width=2)
    elif kind == "sticky_net":
        for i in range(0, 16, 4):
            d.line((i, 0, i, 15), fill=(240, 230, 190, 255)); d.line((0, i, 15, i), fill=(240, 230, 190, 255))
    elif kind == "claw":
        d.line((8, 0, 8, 5), fill=(150, 145, 160, 255))
        d.rectangle((5, 5, 11, 7), fill=(200, 195, 210, 255))
        d.line((6, 8, 3, 12, 5, 15), fill=(220, 215, 230, 255), width=2)
        d.line((10, 8, 13, 12, 11, 15), fill=(220, 215, 230, 255), width=2)
        d.line((8, 8, 8, 13), fill=(255, 190, 215, 255), width=2)
    elif kind == "quicksand":
        d.ellipse((1, 5, 15, 14), fill=(200, 160, 95, 255))
        d.arc((3, 6, 13, 13), 200, 470, fill=(240, 210, 150, 255))
        d.ellipse((6, 8, 10, 11), fill=(120, 85, 50, 255))
        d.line((4, 6, 4, 3), fill=(255, 215, 195, 255)); d.line((12, 6, 12, 3), fill=(255, 215, 195, 255))
    elif kind == "mushrooms":
        for (x, y) in ((1, 9), (8, 4)):
            d.rectangle((x + 2, y + 3, x + 4, y + 6), fill=(250, 235, 215, 255))
            d.pieslice((x, y, x + 7, y + 6), 180, 360, fill=(240, 90, 125, 255))
            d.point((x + 2, y + 1), fill=(255, 235, 240, 255))
    elif kind == "portal_pair":
        d.ellipse((0, 3, 7, 14), outline=(180, 120, 255, 255), fill=(40, 15, 60, 255))
        d.ellipse((9, 3, 15, 14), outline=(255, 130, 200, 255), fill=(40, 15, 60, 255))
        d.arc((2, 6, 13, 11), 180, 360, fill=(255, 255, 255, 200))
    return add_outline(img)


def unknown_icon():
    img, d = canvas(16, 16)
    d.ellipse((1, 1, 14, 14), fill=(80, 50, 90, 255), outline=(200, 150, 220, 255))
    d.text((5, 2), "?", fill=(255, 220, 255, 255))
    return img


def gen_icons():
    """战场情报的图标（16x16）：按 data/siege/intel.json 的键，从各图集里找对应的图缩小；找不到画个问号。"""
    import os
    root = OUT.parent.parent
    intel_path = root / "data/siege/intel.json"
    keys = [k for k in json.loads(intel_path.read_text()) if k != "_说明"] if intel_path.exists() else []
    sheets = {}
    for name in ("towers", "monsters", "hazards", "props"):
        png, js = DIR / (name + ".png"), DIR / (name + ".json")
        if png.exists() and js.exists():
            sheets[name] = (Image.open(png).convert("RGBA"), json.loads(js.read_text()))
    equip_png = OUT / "equip_icons.png"
    equip_order = ["armpit_pad", "scarf", "wool_socks", "dance_shoes", "waist_sash", "mint_sachet", "chest_guard",
                   "training_wraps", "padded_shorts", "party_bow", "feather_anklet", "ice_hairpin", "thousand_pants",
                   "t_feather_socks", "t_toe_brush", "t_fluff_bra", "t_thigh_ring", "t_pinch_pad", "t_knead_tights",
                   "t_feather_shackles", "t_thigh_strap", "t_bell_anklet", "t_mark_patch"]
    eq = Image.open(equip_png).convert("RGBA") if equip_png.exists() else None
    items = []
    for k in keys:
        src = None
        for sheet, meta in sheets.values():
            alias = {"troll_general": "general_0", "controls": "horn"}.get(k, "")
            for cand in (k, k + "_1", k + "_0", k + "_a_0", "icon_" + k, alias):
                if cand in meta:
                    x, y, w, h = meta[cand]
                    src = sheet.crop((x, y, x + w, y + h))
                    break
            if src:
                break
        if src is None and eq is not None and k.startswith("equip_") and k[6:] in equip_order:
            i = equip_order.index(k[6:])
            src = eq.crop((i * 16, 0, i * 16 + 16, 16))
        if src is None and k.startswith("hazard_"):
            src = hazard_icon(k[7:])
        items.append((k, fit_icon(src) if src else unknown_icon()))
    pack(items, "icons")


# ================================================================ 第三轮：新友军塔、巨魔将军、军旗、士兵行走图、新粒子
def tower3(kind, lvl):
    img, d = canvas(24, 32)
    if kind == "campfire":
        d.ellipse((2, 25, 21, 31), fill=(110, 90, 80, 255))
        for i, x in enumerate((4, 8, 12, 16)):
            d.ellipse((x, 24 - (i % 2), x + 5, 29 - (i % 2)), fill=(130, 125, 135, 255), outline=(80, 74, 84, 255))
        d.line((5, 26, 18, 20), fill=WOOD_D, width=3); d.line((5, 20, 18, 26), fill=WOOD, width=3)
        d.polygon([(6, 22), (9, 9), (11, 15), (13, 5), (15, 14), (18, 22)], fill=(255, 140, 50, 255))
        d.polygon([(8, 22), (11, 12), (13, 16), (15, 22)], fill=(255, 220, 90, 255))
        d.polygon([(10, 22), (12, 16), (13, 22)], fill=(255, 250, 200, 255))
        if lvl > 1:
            d.rectangle((1, 6, 2, 27), fill=WOOD_D); d.rectangle((21, 6, 22, 27), fill=WOOD_D)
            d.line((1, 6, 22, 6), fill=WOOD, width=2)
            d.polygon([(10, 7), (13, 7), (12, 11)], fill=(120, 120, 130, 255))   # 吊锅
    elif kind == "ballista":
        ice_base(d, lvl)
        d.rectangle((9, 14, 14, 26), fill=WOOD_D)
        d.polygon([(2, 10), (11, 15), (21, 10), (21, 12), (11, 17), (2, 12)], fill=WOOD)       # 弩臂
        d.line((2, 11, 11, 7), fill=(230, 230, 240, 255)); d.line((21, 11, 11, 7), fill=(230, 230, 240, 255))  # 弦
        d.polygon([(11, 1), (13, 6), (12, 16), (10, 16), (9, 6)], fill=ICE)                    # 冰棱
        d.line((11, 3, 11, 14), fill=ICE_L)
        if lvl > 1:
            crystal_spire(d, 2, 16, 6, 26); crystal_spire(d, 17, 16, 21, 26)
    else:  # cocoa 热可可摊
        d.rectangle((2, 16, 21, 29), fill=(200, 140, 90, 255), outline=(120, 70, 40, 255))
        d.line((2, 20, 21, 20), fill=(240, 200, 150, 255))
        for i, x in enumerate(range(1, 22, 4)):
            d.polygon([(x, 6), (x + 4, 6), (x + 4, 11), (x + 2, 13), (x, 11)], fill=(255, 120, 150, 255) if i % 2 == 0 else (255, 245, 240, 255))
        d.line((2, 6, 2, 16), fill=WOOD_D); d.line((21, 6, 21, 16), fill=WOOD_D)
        d.rectangle((8, 11, 15, 16), fill=(250, 250, 255, 255), outline=(150, 110, 90, 255))     # 杯子
        d.rectangle((9, 11, 14, 12), fill=(120, 70, 40, 255))
        d.arc((14, 12, 18, 15), 270, 90, fill=(150, 110, 90, 255))
        for x in (10, 13):
            d.line((x, 9, x + 1, 5), fill=(255, 255, 255, 200))
        if lvl > 1:
            d.ellipse((17, 22, 21, 26), fill=(255, 220, 120, 255)); d.ellipse((3, 22, 7, 26), fill=(255, 220, 120, 255))
    return add_outline(img)


def bolt_proj():
    img, d = canvas(6, 16)
    d.polygon([(3, 0), (5, 4), (4, 15), (2, 15), (1, 4)], fill=ICE)
    d.line((3, 2, 3, 13), fill=ICE_L)
    return add_outline(img)


def banner(f):
    img, d = canvas(20, 34)
    d.line((3, 2, 3, 33), fill=WOOD_D, width=2)
    d.ellipse((1, 0, 5, 4), fill=(230, 190, 70, 255))
    wave = (0, 1, 2, 1) if f == 0 else (1, 2, 1, 0)
    pts = [(4, 4)]
    for i, w in enumerate(wave):
        pts.append((8 + i * 3, 4 + w))
    pts += [(19, 10 + wave[-1]), (16, 13), (19, 17 + wave[0])]
    for i, w in reversed(list(enumerate(wave))):
        pts.append((8 + i * 3, 18 + w))
    pts.append((4, 18))
    d.polygon(pts, fill=(200, 50, 70, 255))
    d.ellipse((7, 7, 14, 14), fill=(255, 200, 220, 255))        # 军旗上的痒痒手印
    for x in (8, 10, 12, 14):
        d.line((x, 7, x, 5), fill=(255, 200, 220, 255))
    return add_outline(img)


G_SKIN = (150, 205, 170, 255); G_SKIN_D = (100, 160, 130, 255); G_SKIN_L = (200, 238, 205, 255)
G_BELLY = (225, 245, 220, 255)
G_HELM = (240, 196, 80, 255); G_HELM_D = (196, 140, 50, 255); G_HELM_L = (255, 236, 160, 255)
G_PLUME = (255, 120, 160, 255); G_PLUME_L = (255, 190, 210, 255)
G_CAPE = (210, 70, 90, 255); G_CAPE_D = (150, 45, 70, 255)
G_GLOVE = (255, 252, 245, 255); G_GLOVE_D = (215, 205, 220, 255)
G_BELT = (120, 70, 50, 255); G_GOLD = (250, 210, 90, 255)
G_EYE = (50, 30, 50, 255); G_BLUSH = (255, 150, 170, 255)


def _g_glove(d, cx, cy, r=5):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=G_GLOVE)
    d.ellipse((cx - r + 1, cy, cx + r - 1, cy + r), fill=G_GLOVE_D)
    for k in (-3, 0, 3):    # 手指
        d.ellipse((cx + k - 1, cy - r - 2, cx + k + 1, cy - r + 1), fill=G_GLOVE)
    d.line((cx - r, cy + 1, cx + r, cy + 1), fill=(240, 150, 170, 255))   # 手套上的粉色条纹


def m_general(f):
    """攻防战小 Boss 攻城巨魔将军：用 tools/art/src/siege_general_<帧>.png（codex 生成的概念图像素化后的 81x88 帧：
    0/1 走路、2 举手蓄力、3 扛木桩冲锋、4 跳起）；没有的话退回下面手画的版本。"""
    src = Path(__file__).resolve().parent / "src" / ("siege_general_%d.png" % f)
    if src.exists():
        return Image.open(src).convert("RGBA")
    return _m_general_drawn(f)


def _m_general_drawn(f):
    """（后备的手画版）攻防战小 Boss 攻城巨魔将军（48x56）：金色圆盔 + 弯弯的粉羽毛、小红披风、
    一对挠痒用的白色大手套、腰挂号角。0/1 走路、2 举手蓄力、3 扛木桩冲锋、4 跳起（缩腿）。"""
    W, H = 48, 56
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bob = 1 if f == 1 else 0
    jump = f == 4
    oy = (-2 if jump else bob) + 6
    # 披风（身后）
    d.polygon([(12, 20 + oy), (36, 20 + oy), (40, 44 + oy), (8, 44 + oy)], fill=G_CAPE_D)
    d.polygon([(13, 20 + oy), (35, 20 + oy), (37, 42 + oy), (11, 42 + oy)], fill=G_CAPE)
    # 脚
    if jump:
        d.ellipse((14, 41 + oy, 22, 46 + oy), fill=G_SKIN_D); d.ellipse((26, 41 + oy, 34, 46 + oy), fill=G_SKIN_D)
    else:
        d.ellipse((13, 48 - bob, 22, 54 - bob), fill=G_SKIN_D); d.ellipse((26, 48 + bob, 35, 54 + bob), fill=G_SKIN_D)
        d.line((15, 52 - bob, 20, 52 - bob), fill=G_SKIN); d.line((28, 52 + bob, 33, 52 + bob), fill=G_SKIN)
    # 圆滚滚的身子
    d.ellipse((10, 18 + oy, 38, 46 + oy), fill=G_SKIN)
    d.ellipse((12, 19 + oy, 30, 36 + oy), fill=G_SKIN_L)
    d.ellipse((15, 26 + oy, 33, 44 + oy), fill=G_BELLY)
    d.ellipse((10, 30 + oy, 38, 46 + oy), outline=G_SKIN_D)
    # 腰带
    d.rectangle((11, 34 + oy, 37, 37 + oy), fill=G_BELT)
    d.rectangle((21, 33 + oy, 27, 38 + oy), fill=G_GOLD); d.rectangle((23, 35 + oy, 25, 36 + oy), fill=G_BELT)
    # 号角挂在腰上
    d.polygon([(34, 36 + oy), (40, 33 + oy), (41, 38 + oy), (35, 39 + oy)], fill=(245, 230, 190, 255))
    d.line((40, 33 + oy, 41, 38 + oy), fill=G_GOLD)
    # 头（大大的圆）
    hy = 2 + oy
    d.ellipse((11, hy + 6, 37, hy + 28), fill=G_SKIN)
    d.ellipse((13, hy + 7, 29, hy + 20), fill=G_SKIN_L)
    # 小耳朵
    d.polygon([(11, hy + 16), (5, hy + 12), (12, hy + 21)], fill=G_SKIN); d.polygon([(37, hy + 16), (43, hy + 12), (36, hy + 21)], fill=G_SKIN)
    # 眼睛（两只，弯弯坏笑）+ 腮红 + 大嘴笑 + 小獠牙
    d.ellipse((17, hy + 15, 21, hy + 19), fill=G_EYE); d.point((18, hy + 16), fill=(255, 255, 255, 255))
    d.ellipse((27, hy + 15, 31, hy + 19), fill=G_EYE); d.point((28, hy + 16), fill=(255, 255, 255, 255))
    d.line((16, hy + 13, 21, hy + 14), fill=G_SKIN_D); d.line((27, hy + 14, 32, hy + 13), fill=G_SKIN_D)   # 挑起的眉毛
    d.ellipse((13, hy + 19, 17, hy + 22), fill=G_BLUSH); d.ellipse((31, hy + 19, 35, hy + 22), fill=G_BLUSH)
    d.chord((19, hy + 18, 29, hy + 26), 0, 180, fill=(160, 50, 80, 255))
    d.chord((21, hy + 21, 27, hy + 26), 0, 180, fill=(255, 140, 160, 255))
    d.polygon([(20, hy + 22), (21, hy + 25), (22, hy + 22)], fill=(255, 255, 245, 255))
    d.polygon([(26, hy + 22), (27, hy + 25), (28, hy + 22)], fill=(255, 255, 245, 255))
    # 将军头盔（金色圆盔）+ 高高的羽毛
    d.chord((10, hy + 3, 38, hy + 22), 180, 360, fill=G_HELM)
    d.chord((12, hy + 4, 30, hy + 18), 180, 270, fill=G_HELM_L)
    d.rectangle((10, hy + 11, 38, hy + 13), fill=G_HELM_D)
    d.ellipse((22, hy + 9, 26, hy + 13), fill=(220, 60, 90, 255))     # 盔上的宝石
    d.ellipse((22, hy + 1, 26, hy + 5), fill=G_HELM_D)
    # 弯弯的大羽毛（挠痒将军的标志），走路时一晃一晃
    sway = f % 2
    pts = [(24, hy + 2), (26 + sway, hy - 2), (30 + sway, hy - 5), (34 + sway, hy - 5), (33 + sway, hy - 2), (29 + sway, hy + 1), (26, hy + 4)]
    d.polygon(pts, fill=G_PLUME)
    d.line((25, hy + 2, 28 + sway, hy - 2, 33 + sway, hy - 4), fill=G_PLUME_L)
    for k in range(3):
        x = 27 + k * 2 + sway
        d.line((x, hy - 1 - k, x + 1, hy + 1 - k), fill=(230, 80, 130, 255))
    # 手臂 + 大手套
    if f == 2:      # 举起双手
        d.line((12, 26 + oy, 5, 10 + oy), fill=G_SKIN, width=5); d.line((36, 26 + oy, 43, 10 + oy), fill=G_SKIN, width=5)
        _g_glove(d, 5, 8 + oy); _g_glove(d, 43, 8 + oy)
    elif f == 3:    # 扛木桩
        d.line((1, 21, 47, 27), fill=WOOD, width=7); d.line((1, 19, 47, 25), fill=(200, 140, 90, 255), width=1)
        d.ellipse((42, 21, 48, 29), fill=(215, 165, 110, 255)); d.ellipse((44, 23, 46, 27), fill=WOOD_D)
        _g_glove(d, 13, 26, 4); _g_glove(d, 35, 29, 4)
    else:
        sw = 1 if f == 1 else 0
        d.line((12, 26 + oy, 6, 34 + oy - sw), fill=G_SKIN, width=5); d.line((36, 26 + oy, 42, 34 + oy + sw), fill=G_SKIN, width=5)
        _g_glove(d, 6, 37 + oy - sw); _g_glove(d, 42, 37 + oy + sw)
    return add_outline(img)


SOLDIER_ROLES = {
    # 角色: (制服主色, 头盔色, 道具)
    "spear": (None, None, None),
    "archer": ((80, 140, 90), (120, 170, 100), "bow"),
    "shield": ((170, 70, 70), (200, 190, 120), "shield"),
    "medic": ((235, 235, 240), (250, 250, 255), "cross"),
    "artisan": ((170, 115, 60), (200, 160, 90), "hammer"),
    "mage": ((80, 140, 215), (200, 232, 255), "staff"),
}
UNIFORM = [(90, 110, 150), (62, 77, 105), (120, 132, 156), (45, 55, 75), (36, 44, 60)]


def _shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c) + (255,)


def gen_soldiers():
    src = Image.open(OUT / "npcs" / "guard.png").convert("RGBA")
    for role, (uni, helm, item) in SOLDIER_ROLES.items():
        img = src.copy()
        px = img.load()
        if uni:
            ks = [1.0, 0.72, 1.25, 0.55, 0.45]
            for y in range(img.height):
                for x in range(img.width):
                    c = px[x, y]
                    if c[3] and c[:3] in UNIFORM:
                        px[x, y] = _shade(uni, ks[UNIFORM.index(c[:3])])
                    elif c[3] and c[:3] == (196, 206, 222) and helm:
                        px[x, y] = helm + (255,)
        d = ImageDraw.Draw(img)
        for row in range(4):
            for col in range(4):
                ox, oy = col * 32, row * 32
                shaft = [(x, y) for y in range(oy, oy + 32) for x in range(ox, ox + 32) if src.getpixel((x, y))[:3] == (140, 90, 60)]
                sx = min(shaft)[0] if shaft else ox + 24
                top = min(y for _, y in shaft) if shaft else oy + 12
                if item == "shield" and row != 3:
                    cx = ox + (11 if row == 1 else 20 if row == 2 else 16)
                    d.rounded_rectangle((cx - 6, oy + 13, cx + 6, oy + 27), radius=3, fill=(190, 190, 205, 255), outline=(63, 38, 49, 255))
                    d.rectangle((cx - 4, oy + 15, cx + 4, oy + 25), fill=(170, 60, 60, 255))
                    d.line((cx, oy + 15, cx, oy + 25), fill=(240, 210, 90, 255)); d.line((cx - 4, oy + 19, cx + 4, oy + 19), fill=(240, 210, 90, 255))
                elif item == "shield":
                    d.rounded_rectangle((ox + 10, oy + 14, ox + 22, oy + 28), radius=3, fill=(150, 150, 165, 255), outline=(63, 38, 49, 255))
                elif item == "cross" and shaft:
                    d.rectangle((sx - 4, top - 1, sx + 4, top + 6), fill=(255, 255, 255, 255), outline=(63, 38, 49, 255))
                    d.line((sx, top, sx, top + 5), fill=(220, 50, 60, 255)); d.line((sx - 3, top + 2, sx + 3, top + 2), fill=(220, 50, 60, 255))
                    if row == 0:
                        d.line((ox + 16, oy + 18, ox + 16, oy + 22), fill=(220, 50, 60, 255)); d.line((ox + 14, oy + 20, ox + 18, oy + 20), fill=(220, 50, 60, 255))
                elif item == "hammer" and shaft:
                    d.rectangle((sx - 3, top - 2, sx + 3, top + 2), fill=(130, 130, 145, 255), outline=(63, 38, 49, 255))
                    if row == 0:
                        d.rectangle((ox + 11, oy + 22, ox + 20, oy + 26), fill=(120, 80, 45, 255))   # 工具包
                elif item == "staff" and shaft:
                    # 冰晶法杖：杖头一颗冰晶 + 亮点
                    d.polygon([(sx, top - 5), (sx + 3, top - 1), (sx, top + 3), (sx - 3, top - 1)], fill=(170, 225, 255, 255), outline=(63, 38, 49, 255))
                    d.point((sx - 1, top - 2), fill=(255, 255, 255, 255))
                    if row == 0:
                        d.line((ox + 12, oy + 21, ox + 20, oy + 21), fill=(200, 232, 255, 255))   # 袍子上的冰纹
                elif item == "bow" and shaft:
                    d.arc((sx - 5, top - 1, sx + 4, top + 16), 270, 90, fill=(120, 80, 45, 255), width=1)
                    d.line((sx - 1, top - 1, sx - 1, top + 16), fill=(240, 240, 230, 255))
        img.save(DIR / ("soldier_%s.png" % role))


def gen_particles():
    """新粒子（和 assets/generated/particle_*.png 同风格的几像素小图；Fx.PARTICLES 注册）。"""
    def save(name, w, h, draw):
        img, d = canvas(w, h)
        draw(d)
        img.save(OUT / ("particle_%s.png" % name))
    save("spark", 3, 3, lambda d: (d.point((1, 0), fill=(255, 255, 220, 255)), d.line((0, 1, 2, 1), fill=(255, 230, 140, 255)), d.point((1, 2), fill=(255, 255, 220, 255))))
    save("leaf", 5, 4, lambda d: (d.polygon([(0, 2), (2, 0), (4, 1), (2, 3)], fill=(120, 200, 90, 255)), d.line((0, 2, 4, 1), fill=(80, 150, 60, 255))))
    save("cloth", 4, 4, lambda d: d.polygon([(0, 0), (3, 1), (2, 3), (0, 2)], fill=(220, 60, 80, 255)))
    save("note", 4, 6, lambda d: (d.ellipse((0, 3, 2, 5), fill=(255, 255, 255, 255)), d.line((2, 0, 2, 4), fill=(255, 255, 255, 255)), d.point((3, 0), fill=(255, 255, 255, 255))))
    save("rock", 4, 4, lambda d: d.polygon([(0, 1), (2, 0), (3, 2), (2, 3), (0, 3)], fill=(140, 125, 115, 255), outline=(90, 78, 72, 255)))
    save("steam", 5, 5, lambda d: d.ellipse((0, 0, 4, 4), fill=(255, 255, 255, 170)))
    save("wood", 4, 2, lambda d: d.line((0, 0, 3, 1), fill=(180, 120, 70, 255)))
    save("flame", 3, 5, lambda d: (d.polygon([(1, 0), (2, 2), (2, 4), (0, 4), (0, 2)], fill=(255, 150, 50, 255)), d.point((1, 3), fill=(255, 240, 160, 255))))
    save("bubble", 5, 5, lambda d: (d.ellipse((0, 0, 4, 4), outline=(200, 235, 255, 230)), d.point((1, 1), fill=(255, 255, 255, 255))))
    save("thread", 5, 2, lambda d: d.line((0, 1, 2, 0, 4, 1), fill=(255, 170, 210, 255)))
    save("ring", 5, 5, lambda d: d.ellipse((0, 0, 4, 4), outline=(255, 255, 255, 255)))


# ================================================================ 第五轮：3 级塔、随波次解锁的新塔、新投射物
GOLD = (255, 214, 90, 255)
GOLD_D = (200, 150, 50, 255)


def lvl3(img):
    """在 2 级图上加 3 级的装饰：冰晶冠、金边、发光点。"""
    img = img.copy()
    d = ImageDraw.Draw(img)
    w, h = img.size
    cx = w // 2
    # 顶上的冰晶冠
    bb = img.getbbox() or (0, 0, w, h)
    top = bb[1]
    for dx, hh in ((-5, 4), (0, 7), (5, 4)):
        x = cx + dx
        d.polygon([(x - 2, top + 3), (x, top + 3 - hh), (x + 2, top + 3)], fill=ICE_L, outline=ICE_D)
    # 底座金边
    d.arc((2, h - 8, w - 3, h - 1), 0, 180, fill=GOLD, width=1)
    for x in (4, w - 5):
        d.point((x, h - 5), fill=GOLD)
    # 发光点
    for (x, y) in ((cx - 7, h // 2), (cx + 7, h // 2 - 4), (cx, h // 2 + 6)):
        if 0 <= x < w and 0 <= y < h and img.getpixel((x, y))[3]:
            d.point((x, y), fill=(255, 255, 255, 255))
    return add_outline(img)


def tower5(kind, lvl):
    img, d = canvas(24, 32)
    if kind == "mortar":
        d.rectangle((3, 22, 20, 30), fill=STONE, outline=STONE_D)
        d.line((3, 25, 20, 25), fill=STONE_L)
        d.polygon([(6, 22), (8, 10), (17, 8), (19, 20)], fill=(110, 130, 160, 255), outline=(60, 70, 95, 255))   # 炮身（斜着朝上）
        d.ellipse((7, 5, 18, 12), fill=(60, 70, 95, 255))
        d.ellipse((9, 6, 16, 10), fill=ICE)                      # 炮口里的冰弹
        d.line((10, 7, 12, 7), fill=ICE_L)
        for i in range(lvl):
            d.line((6 + i, 14 + i * 3, 18, 13 + i * 3), fill=(180, 190, 210, 255))
    elif kind == "vortex":
        ice_base(d, lvl)
        crystal_spire(d, 9, 6, 14, 27)
        for i in range(2 + lvl):
            y = 8 + i * 5
            d.arc((2, y, 21, y + 8), 200 + i * 30, 340 + i * 30, fill=ICE_L, width=1)
            d.arc((3, y + 1, 20, y + 7), 20 + i * 30, 160 + i * 30, fill=(200, 235, 255, 200), width=1)
    elif kind == "resonance":
        ice_base(d, lvl)
        d.polygon([(11, 2), (15, 10), (13, 26), (9, 26), (7, 10)], fill=(190, 160, 255, 255), outline=(110, 80, 190, 255))
        d.line((11, 4, 11, 24), fill=(235, 220, 255, 255))
        for i, (x, y) in enumerate(((2, 9), (19, 7), (3, 18), (19, 17))[:2 + lvl]):
            d.polygon([(x, y), (x + 2, y - 3), (x + 4, y), (x + 2, y + 3)], fill=(220, 200, 255, 255), outline=(110, 80, 190, 255))
    elif kind == "meteor":
        d.rectangle((5, 20, 18, 30), fill=STONE, outline=STONE_D)
        d.polygon([(3, 20), (20, 20), (17, 16), (6, 16)], fill=STONE_L, outline=STONE_D)
        d.ellipse((5, 1 - lvl, 18, 14 - lvl), fill=ICE, outline=ICE_D)       # 浮着的大冰晶球
        d.ellipse((8, 3 - lvl, 13, 8 - lvl), fill=ICE_L)
        for x in (3, 20):
            d.line((x, 18, x, 10), fill=GOLD_D)
            d.point((x, 9), fill=GOLD)
    elif kind == "hotspring":
        d.ellipse((1, 18, 22, 30), fill=(130, 125, 135, 255), outline=(80, 74, 84, 255))
        d.ellipse((4, 20, 19, 28), fill=(120, 200, 230, 255))
        d.ellipse((7, 22, 13, 25), fill=(190, 240, 255, 255))
        for i in range(2 + lvl):
            x = 5 + i * 4
            d.arc((x, 6 + (i % 2) * 2, x + 4, 16), 180, 360, fill=(255, 255, 255, 190))
        if lvl >= 2:
            d.rectangle((0, 22, 2, 28), fill=STONE_D); d.rectangle((21, 22, 23, 28), fill=STONE_D)
    elif kind == "lamp":
        d.line((11, 12, 11, 30), fill=(70, 80, 110, 255), width=3)
        d.rectangle((6, 28, 17, 31), fill=(70, 80, 110, 255))
        d.polygon([(6, 3), (17, 3), (16, 13), (7, 13)], fill=(60, 70, 100, 255))
        d.rectangle((8, 5, 15, 11), fill=(200, 240, 255, 255))           # 冷光
        d.rectangle((10, 6, 13, 10), fill=(255, 255, 255, 255))
        d.polygon([(5, 3), (11, 0), (18, 3)], fill=(90, 100, 140, 255))
        if lvl >= 2:
            d.line((4, 8, 6, 8), fill=ICE_L); d.line((17, 8, 19, 8), fill=ICE_L)
    else:  # shield 冰盾发生器
        ice_base(d, lvl)
        pts = [(11, 3), (19, 8), (19, 18), (11, 23), (3, 18), (3, 8)]
        d.polygon(pts, fill=(170, 225, 255, 200), outline=ICE_D)
        d.polygon([(11, 7), (15, 10), (15, 16), (11, 19), (7, 16), (7, 10)], fill=ICE_L)
        for i in range(lvl):
            d.arc((1 - i, 1 - i, 21 + i, 25 + i), 200, 340, fill=(220, 245, 255, 220))
    img = add_outline(img)
    return lvl3(img) if lvl == 3 else img


def mortar_proj():
    img, d = canvas(9, 9)
    d.ellipse((0, 0, 8, 8), fill=ICE, outline=ICE_D)
    d.ellipse((2, 1, 5, 4), fill=ICE_L)
    return add_outline(img)


def meteor_proj():
    img, d = canvas(18, 18)
    d.polygon([(9, 0), (15, 4), (17, 10), (12, 17), (5, 16), (1, 10), (3, 3)], fill=ICE, outline=ICE_D)
    d.polygon([(9, 3), (13, 6), (10, 9), (6, 7)], fill=ICE_L)
    d.line((4, 12, 8, 14), fill=ICE_D)
    return add_outline(img)


def snowball_proj():
    img, d = canvas(6, 6)
    d.ellipse((0, 0, 5, 5), fill=(250, 252, 255, 255), outline=(180, 205, 230, 255))
    d.point((2, 1), fill=(255, 255, 255, 255))
    return add_outline(img)


# ================================================================ 第六轮：每波特色机制的小图标（12x12，features.png 一排；顺序和 waves.json 的 features 一致）
def gen_features():
    S = 12
    order = ["bubbles", "airdrop", "trolls", "fog", "corps", "gale", "equip", "vines", "engineers", "raiders", "feathers", "carnival"]
    sheet = Image.new("RGBA", (S * len(order), S), (0, 0, 0, 0))
    W_ = (255, 255, 255, 255)

    def icon(k):
        img, d = canvas(S - 2, S - 2)
        if k == "bubbles":
            d.ellipse((0, 3, 5, 8), outline=(140, 215, 255, 255), fill=(90, 170, 230, 120))
            d.ellipse((5, 0, 9, 4), outline=(140, 215, 255, 255), fill=(90, 170, 230, 120))
            d.ellipse((6, 6, 9, 9), outline=(140, 215, 255, 255))
            d.point((2, 4), fill=W_)
            d.point((6, 1), fill=W_)
        elif k == "airdrop":
            d.polygon([(0, 2), (3, 0), (5, 2), (7, 0), (9, 2), (5, 5)], fill=(150, 110, 200, 255))
            d.line((5, 5, 5, 8), fill=(200, 200, 220, 255))
            d.rectangle((3, 8, 7, 9), fill=(120, 200, 110, 255))
        elif k == "trolls":
            d.ellipse((1, 1, 8, 8), fill=(130, 165, 95, 255))
            d.point((3, 4), fill=(40, 20, 20, 255))
            d.point((6, 4), fill=(40, 20, 20, 255))
            d.line((3, 6, 6, 6), fill=(60, 30, 30, 255))
            d.polygon([(1, 2), (0, 0), (3, 1)], fill=(230, 220, 200, 255))
            d.polygon([(8, 2), (9, 0), (6, 1)], fill=(230, 220, 200, 255))
        elif k == "fog":
            d.ellipse((5, 0, 9, 4), fill=(240, 230, 170, 255))
            d.ellipse((6, 0, 10, 3), fill=(0, 0, 0, 0))
            for y, c in ((4, 170), (6, 140), (8, 120)):
                d.line((0, y, 9, y), fill=(c, c - 20, c + 50, 220))
        elif k == "corps":
            d.rectangle((1, 3, 8, 7), fill=WOOD)
            d.rectangle((1, 3, 8, 3), fill=WOOD_D)
            d.polygon([(8, 4), (9, 5), (8, 6)], fill=(200, 200, 210, 255))
            d.ellipse((1, 7, 3, 9), fill=(60, 50, 50, 255))
            d.ellipse((6, 7, 8, 9), fill=(60, 50, 50, 255))
        elif k == "gale":
            d.arc((0, 0, 7, 5), 180, 360, fill=(170, 240, 225, 255))
            d.line((0, 3, 7, 3), fill=(170, 240, 225, 255))
            d.arc((2, 4, 9, 9), 0, 180, fill=(170, 240, 225, 255))
            d.line((0, 6, 6, 6), fill=(170, 240, 225, 255))
        elif k == "equip":
            d.polygon([(2, 0), (7, 0), (9, 3), (7, 3), (7, 9), (2, 9), (2, 3), (0, 3)], fill=(255, 140, 195, 255))
            d.line((4, 2, 5, 2), fill=W_)
            d.point((4, 5), fill=(255, 220, 240, 255))
        elif k == "vines":
            d.line((1, 9, 3, 6, 2, 3, 5, 0), fill=(90, 180, 80, 255))
            d.line((5, 9, 7, 6, 6, 3, 9, 1), fill=(90, 180, 80, 255))
            d.point((3, 4), fill=(150, 230, 120, 255))
            d.point((7, 4), fill=(150, 230, 120, 255))
        elif k == "engineers":
            d.pieslice((1, 1, 8, 8), 180, 360, fill=(255, 190, 70, 255))
            d.rectangle((0, 4, 9, 5), fill=(230, 150, 40, 255))
            d.line((4, 6, 4, 9), fill=WOOD_D)
            d.rectangle((2, 6, 6, 7), fill=(160, 160, 170, 255))
        elif k == "raiders":
            d.line((2, 0, 2, 9), fill=WOOD_D)
            d.polygon([(3, 0), (9, 2), (3, 4)], fill=(255, 70, 70, 255))
            d.line((5, 6, 9, 9), fill=(200, 200, 210, 255))
            d.line((9, 6, 5, 9), fill=(200, 200, 210, 255))
        elif k == "feathers":
            for x0, y0 in ((0, 1), (5, 0), (3, 5)):
                d.line((x0, y0 + 4, x0 + 4, y0), fill=(255, 245, 200, 255))
                d.point((x0 + 1, y0 + 2), fill=(255, 220, 150, 255))
                d.point((x0 + 3, y0 + 2), fill=(255, 220, 150, 255))
        elif k == "carnival":
            d.polygon([(4, 0), (9, 9), (0, 9)], fill=(255, 205, 60, 255))
            d.line((2, 6, 7, 6), fill=(255, 90, 120, 255))
            d.line((3, 4, 6, 4), fill=(90, 200, 255, 255))
            d.point((1, 1), fill=(255, 120, 160, 255))
            d.point((8, 2), fill=(120, 230, 140, 255))
        return add_outline(img)

    for i, k in enumerate(order):
        sheet.paste(icon(k), (i * S + 1, 1))
    sheet.save(DIR / "features.png")
    # 彩带粒子（白色，用 color 着色）
    img, d = canvas(3, 2)
    d.rectangle((0, 0, 2, 1), fill=W_)
    img.save(OUT / "particle_confetti.png")


# ================================================================ 第七轮：城墙上的灯（wall_lights.png：brazier 12x14 火盆 / lantern 8x14 挂灯，各 2 帧火焰）
def gen_wall_lights():
    IRON = (70, 62, 72, 255)
    IRON_L = (120, 110, 120, 255)
    FIRE = [(255, 120, 40, 255), (255, 190, 70, 255), (255, 245, 180, 255)]
    sheet = Image.new("RGBA", (12 * 2 + 8 * 2, 14), (0, 0, 0, 0))
    for f in range(2):
        img, d = canvas(12, 14)
        # 火盆：三脚架 + 盆 + 火
        d.line((2, 13, 4, 9), fill=IRON); d.line((9, 13, 7, 9), fill=IRON); d.line((6, 13, 6, 9), fill=IRON)
        d.polygon([(1, 7), (10, 7), (9, 10), (2, 10)], fill=IRON, outline=(40, 34, 44, 255))
        d.line((2, 8, 9, 8), fill=IRON_L)
        sway = 1 if f else 0
        d.polygon([(3, 7), (5 + sway, 1), (6, 4), (7 + sway, 0), (9, 7)], fill=FIRE[0])
        d.polygon([(4, 7), (6 + sway, 3), (8, 7)], fill=FIRE[1])
        d.point((6, 6), fill=FIRE[2])
        sheet.paste(add_outline(img), (f * 12, 0))
        img, d = canvas(8, 14)
        # 挂灯：钩子 + 灯罩 + 里面的火
        d.line((4, 0, 4, 2), fill=IRON)
        d.rectangle((1, 3, 6, 4), fill=IRON)
        d.rectangle((1, 5, 6, 11), fill=(255, 214, 130, 255), outline=IRON)
        d.line((1, 8, 6, 8), fill=IRON)
        d.rectangle((3, 6 + (0 if f else 1), 4, 9), fill=FIRE[1])
        d.point((3, 7), fill=FIRE[2])
        d.rectangle((2, 12, 5, 12), fill=IRON)
        sheet.paste(add_outline(img), (24 + f * 8, 0))
    sheet.save(DIR / "wall_lights.png")


def main():
    DIR.mkdir(parents=True, exist_ok=True)
    gen_props()
    gen_towers()
    gen_monsters()
    gen_soldiers()
    gen_particles()
    gen_icons()
    gen_features()
    gen_wall_lights()
    print("攻防战像素图已生成：", sorted(p.name for p in DIR.glob("*.png")))


if __name__ == "__main__":
    main()
