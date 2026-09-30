"""扩展内容的像素占位图（楼层扩充、第三层、魔法、组合技）。

输出到 assets/generated/：
  weapon_rack.png   16x16      可打碎的武器架（第一层兵器库）
  secret_crack.png  16x16      暗墙被火光照出的裂缝（叠在墙顶上）
  magic_circle.png  80x40 x 4帧 x 4行   吟唱魔法阵（行 = 蓄力档 0~3，越高越大越亮）
  star_burst.png    152x152 x 6帧 x 3行 星光爆发冲击环（行 = 档位 1~3，半径 36/52/72）
  sparkle.png       7x7 x 2    星光粒子
  magic_icon.png    16x16 x 2  HUD 魔法图标（可用 / 冷却中）
其余第三层素材见本文件后续函数。

用法：python tools/art/gen_expansion.py
"""
from PIL import Image, ImageDraw

from palette import OUT, ROOT, add_outline

KENNEY = ROOT / "assets/third_party/kenney_tiny_dungeon/tilemap_packed.png"

WOOD = (189, 108, 74, 255)
WOOD_D = (120, 64, 48, 255)
WOOD_L = (222, 150, 102, 255)
CRACK = (255, 214, 150, 255)
CRACK_D = (40, 26, 30, 255)


def blank(w=16, h=16):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def canvas(w=16, h=16):
    img = blank(w, h)
    return img, ImageDraw.Draw(img)


def kenney(idx):
    sheet = Image.open(KENNEY).convert("RGBA")
    x, y = idx % 12 * 16, idx // 12 * 16
    return sheet.crop((x, y, x + 16, y + 16))


STEEL = (200, 212, 228, 255)
STEEL_D = (120, 134, 160, 255)


def weapon_rack():
    """木架上竖着一把剑、一支长矛、一把斧头。"""
    img, d = canvas()
    # 架子：两根立柱 + 底座 + 上横杆
    d.rectangle((1, 3, 2, 15), fill=WOOD_D)
    d.rectangle((13, 3, 14, 15), fill=WOOD_D)
    d.rectangle((1, 13, 14, 14), fill=WOOD)
    d.line((1, 13, 14, 13), fill=WOOD_L)
    # 剑
    d.line((4, 2, 4, 9), fill=STEEL)
    d.line((5, 3, 5, 9), fill=STEEL_D)
    d.line((3, 10, 6, 10), fill=WOOD_D)
    d.line((4, 11, 4, 12), fill=WOOD)
    # 长矛
    d.line((8, 3, 8, 12), fill=WOOD)
    d.polygon([(8, 0), (6, 3), (10, 3)], fill=STEEL)
    d.point((8, 1), fill=STEEL_D)
    # 斧头
    d.line((11, 3, 11, 12), fill=WOOD)
    d.rectangle((9, 3, 12, 6), fill=STEEL_D)
    d.rectangle((10, 3, 12, 5), fill=STEEL)
    # 上横杆压在武器前面
    d.rectangle((1, 7, 14, 7), fill=WOOD)
    return add_outline(img)


def secret_crack():
    img, d = canvas()
    pts = [(8, 1), (7, 4), (9, 6), (6, 9), (8, 11), (7, 14)]
    d.line(pts, fill=CRACK_D, width=2)
    d.line(pts, fill=CRACK, width=1)
    d.line([(9, 6), (12, 7), (13, 10)], fill=CRACK, width=1)
    d.line([(6, 9), (3, 10)], fill=CRACK, width=1)
    return img


# ------------------------------------------------------------------ 星光爆发魔法
STAR = (255, 236, 150, 255)
STAR_L = (255, 255, 228, 255)
STAR_D = (232, 170, 70, 255)
MAGIC_P = (255, 150, 214, 255)
MAGIC_B = (150, 206, 255, 255)
CIRCLE_RX = [12, 18, 26, 36]
BURST_R = [36, 52, 72]


def _ellipse_points(cx, cy, rx, ry, n, phase=0.0):
    import math
    return [(cx + rx * math.cos(phase + i * 2 * math.pi / n), cy + ry * math.sin(phase + i * 2 * math.pi / n))
            for i in range(n)]


def _px(d, x, y, c):
    d.point((round(x), round(y)), fill=c)


def magic_circle(stage, frame):
    import math
    img, d = canvas(80, 40)
    cx, cy = 40, 20
    rx = CIRCLE_RX[stage]
    ry = rx / 2
    outer = STAR if stage < 3 else STAR_L
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=outer)
    if stage >= 1:
        d.ellipse((cx - rx * 0.7, cy - ry * 0.7, cx + rx * 0.7, cy + ry * 0.7), outline=MAGIC_P)
    if stage >= 2:
        # 五芒星（随帧旋转）
        pts = _ellipse_points(cx, cy, rx * 0.7, ry * 0.7, 5, -math.pi / 2 + frame * math.pi / 10)
        order = [pts[i * 2 % 5] for i in range(6)]
        d.line([(round(x), round(y)) for x, y in order], fill=MAGIC_B)
    if stage >= 3:
        d.ellipse((cx - rx - 3, cy - ry - 2, cx + rx + 3, cy + ry + 2), outline=MAGIC_P)
    # 符文点：沿外圈旋转
    for i, (x, y) in enumerate(_ellipse_points(cx, cy, rx, ry, 6 + stage * 2, frame * math.pi / (6 + stage * 2) / 2)):
        c = STAR_L if i % 2 == 0 else MAGIC_B
        _px(d, x, y, c)
        if stage >= 2:
            _px(d, x + 1, y, c)
    return img


def star_shape(d, x, y, r, c):
    d.line((x - r, y, x + r, y), fill=c)
    d.line((x, y - r, x, y + r), fill=c)
    if r >= 2:
        d.point((x, y), fill=STAR_L)


def star_burst(tier, frame):
    import math
    size = 152
    img, d = canvas(size, size)
    c = size // 2
    r_full = BURST_R[tier - 1]
    t = frame / 5
    r = r_full * (0.3 + 0.7 * t)
    colors = [STAR_L, STAR, STAR, MAGIC_P, MAGIC_P, MAGIC_B]
    col = colors[frame]
    d.ellipse((c - r, c - r, c + r, c + r), outline=col, width=2 if frame < 4 else 1)
    if frame < 3:
        ri = r * 0.6
        d.ellipse((c - ri, c - ri, c + ri, c + ri), outline=MAGIC_P)
    n = 6 + tier * 2
    for i in range(n):
        a = i * 2 * math.pi / n + tier * 0.3
        x = round(c + math.cos(a) * r)
        y = round(c + math.sin(a) * r)
        star_shape(d, x, y, 3 if frame < 3 else 2 if frame < 5 else 1, STAR if i % 2 else MAGIC_B)
    if frame < 2:
        star_shape(d, c, c, 6 - frame * 2, STAR_L)
    return img


def sparkle(big):
    img, d = canvas(7, 7)
    star_shape(d, 3, 3, 3 if big else 2, STAR)
    if big:
        d.point((3, 3), fill=STAR_L)
    return img


def magic_icon(ready):
    img, d = canvas()
    # 权杖 + 星星
    d.line((4, 14, 9, 7), fill=WOOD_D if ready else (90, 80, 90, 255))
    d.line((5, 14, 10, 7), fill=WOOD if ready else (120, 110, 120, 255))
    col = STAR if ready else (140, 136, 150, 255)
    colL = STAR_L if ready else (170, 166, 180, 255)
    d.polygon([(11, 1), (12, 4), (15, 5), (12, 6), (11, 9), (10, 6), (7, 5), (10, 4)], fill=col)
    d.point((11, 5), fill=colL)
    if ready:
        d.point((3, 3), fill=MAGIC_P)
        d.point((14, 11), fill=MAGIC_B)
    return add_outline(img)


def gen_magic():
    sheet = blank(80 * 4, 40 * 4)
    for stage in range(4):
        for f in range(4):
            sheet.alpha_composite(magic_circle(stage, f), (f * 80, stage * 40))
    sheet.save(OUT / "magic_circle.png")
    sheet = blank(152 * 6, 152 * 3)
    for tier in range(1, 4):
        for f in range(6):
            sheet.alpha_composite(star_burst(tier, f), (f * 152, (tier - 1) * 152))
    sheet.save(OUT / "star_burst.png")
    sp = blank(14, 7)
    sp.alpha_composite(sparkle(True), (0, 0))
    sp.alpha_composite(sparkle(False), (7, 0))
    sp.save(OUT / "sparkle.png")
    ic = blank(32, 16)
    ic.alpha_composite(magic_icon(True), (0, 0))
    ic.alpha_composite(magic_icon(False), (16, 0))
    ic.save(OUT / "magic_icon.png")


def gen_floor_expansion():
    weapon_rack().save(OUT / "weapon_rack.png")
    secret_crack().save(OUT / "secret_crack.png")


def main():
    gen_floor_expansion()
    gen_magic()


if __name__ == "__main__":
    main()
