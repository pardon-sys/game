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


def main():
    DIR.mkdir(parents=True, exist_ok=True)
    gen_props()
    print("攻防战像素图已生成：", sorted(p.name for p in DIR.glob("*.png")))


if __name__ == "__main__":
    main()
