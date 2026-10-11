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
    for k in ETOWERS:
        items.append(("etower_" + k, etower(k)))
    items += [("snowman_0", snowman(0)), ("snowman_1", snowman(1)), ("glue", glue_puddle()),
              ("proj_hand", hand_proj((190, 140, 230, 255))), ("proj_brush", brush_proj()), ("proj_equip", equip_proj()),
              ("proj_icicle", icicle_proj()), ("net", net_tile())]
    pack(items, "towers")


def icicle_proj():
    img, d = canvas(6, 10)
    d.polygon([(1, 0), (5, 0), (3, 9)], fill=ICE)
    d.line((3, 1, 3, 6), fill=ICE_L)
    return add_outline(img)


ETOWERS = ["vine_pull", "tailor", "glue", "net", "silence", "portal", "windmill", "totem", "thigh_tower", "sole_tower"]


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
    for name in ("towers", "monsters", "hazards"):
        png, js = DIR / (name + ".png"), DIR / (name + ".json")
        if png.exists() and js.exists():
            sheets[name] = (Image.open(png).convert("RGBA"), json.loads(js.read_text()))
    equip_png = OUT / "equip_icons.png"
    items = []
    for k in keys:
        src = None
        for sheet, meta in sheets.values():
            for cand in (k, k + "_1", k.replace("tower_", "tower_") + "_1", "icon_" + k):
                if cand in meta:
                    x, y, w, h = meta[cand]
                    src = sheet.crop((x, y, x + w, y + h))
                    break
            if src:
                break
        items.append((k, fit_icon(src) if src else unknown_icon()))
    pack(items, "icons")


def main():
    DIR.mkdir(parents=True, exist_ok=True)
    gen_props()
    gen_towers()
    gen_icons()
    print("攻防战像素图已生成：", sorted(p.name for p in DIR.glob("*.png")))


if __name__ == "__main__":
    main()
