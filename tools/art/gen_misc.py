"""生成其它像素美术：表情气泡、道具、机关、特效、墙体自动拼接图集。

输出到 assets/generated/：
  emotes.png   16x16 x 8   (happy, laugh, sad, shy, angry, question, surprise, dots)
  items.png    16x16 x 8   (heart, coin, key_bronze, key_gold, letter, lock_bronze, lock_gold, prompt_e)
  hud.png      16x16 x 3   (heart_full, heart_half, heart_empty)
  props.png    16x16       行0: torch_unlit, torch_lit1..3；行1: lever_off, lever_on；行2: spikes_down, spikes_mid, spikes_up
  fx.png       32x32 x 4   挥击弧光；行1: 16x16 烟雾 x 4
  walls.png    16x16 x 256 墙顶自动拼接（mask = 8 方向"非墙顶"位）
  wall_faces.png 16x16     墙面：列 = 变体(0 普通,1 格栅窗,2 旗帜,3 铁板)，行 = 边缘标志(capN|endW<<1|endE<<2)
"""
import math
import random

from PIL import Image

from palette import OUT, OUTLINE, PAL, ROOT, add_outline, grid_to_image, mirror_rows

KENNEY = ROOT / "assets/third_party/kenney_tiny_dungeon/tilemap_packed.png"

VOID = (118, 59, 54, 255)
STONE_L = (192, 203, 220, 255)
STONE_M = (139, 155, 180, 255)
STONE_D = (82, 96, 124, 255)


def blank(w=16, h=16):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def sprite(rows, outline=True):
    img = grid_to_image(rows)
    return add_outline(img) if outline else img


def pad16(rows, top):
    """把若干 16 宽的行放到 16x16 画布的 top 行处。"""
    full = ["." * 16] * top + rows
    return full + ["." * 16] * (16 - len(full))


# ------------------------------------------------------------------ 表情气泡
BUBBLE = [
    "................",
    "...iiiiiiiiii...",
    "..iiiiiiiiiiii..",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    ".iiiiiiiiiiiiii.",
    "..iiiiiiiiiiii..",
    "...iiiiiiiiii...",
    ".....iii........",
    "......i.........",
    "................",
]
ICONS = {
    "happy": [".KKKKKK.", ".KKKKKK.", ".K....K.", ".K....K.", ".K....K.", "KK...KK.", "KK...KK.", "........"],
    "laugh": ["..cccc..", ".cccccc.", "cEccccEc", "cccccccc", "cMMMMMMc", "cMkkkkMc", ".cMMMMc.", "..cccc.."],
    "sad": ["...t....", "...t....", "..ttt...", "..tttt..", ".tittt..", ".ttttt..", "..ttt...", "........"],
    "shy": [".KK..KK.", "KiKKKKKK", "KKKKKKKK", "KKKKKKKK", ".KKKKKK.", "..KKKK..", "...KK...", "........"],
    "angry": [".a....a.", "aa....aa", ".aa..aa.", "........", "........", ".aa..aa.", "aa....aa", ".a....a."],
    "question": ["..EEEE..", ".EE..EE.", ".....EE.", "....EE..", "...EE...", "...EE...", "........", "...EE..."],
    "surprise": ["...aa...", "...aa...", "...aa...", "...aa...", "...aa...", "........", "...aa...", "........"],
    "dots": ["........", "........", "........", "........", "EE.EE.EE", "EE.EE.EE", "........", "........"],
}
EMOTE_ORDER = ["happy", "laugh", "sad", "shy", "angry", "question", "surprise", "dots"]


def gen_emotes():
    sheet = blank(16 * len(EMOTE_ORDER), 16)
    for i, name in enumerate(EMOTE_ORDER):
        rows = list(BUBBLE)
        for r, line in enumerate(ICONS[name]):
            row = list(rows[3 + r])
            for c, ch in enumerate(line):
                if ch != ".":
                    row[4 + c] = ch
            rows[3 + r] = "".join(row)
        sheet.alpha_composite(sprite(rows), (i * 16, 0))
    sheet.save(OUT / "emotes.png")


# ------------------------------------------------------------------ 道具
HEART_L = ["........", "........", "........", "........", "....aa..", "...aaaa.", "...aaaaa", "...aaaaa",
           "....aaaa", ".....aaa", "......aa", ".......a", "........", "........", "........", "........"]
COIN = pad16(["......cccc......", ".....cyccCc.....", ".....cycCCc.....", ".....cccCCc.....",
              ".....ccCCCc.....", "......cccc......"], 5)
KEY = pad16(["..ppp...........", ".p...p..........", ".p...pppppppp...", ".p...p....p.p...",
             "..ppp..........."], 6)
LETTER = pad16(["..wwwwwwwwwwww..", "..wWwwwwwwwwWw..", "..wwWwwwwwwWww..", "..wwwWwwwwWwww..",
                "..wwwwWaaWwwww..", "..wwwwwaawwwww..", "..wwwwwwwwwwww..", "..WWWWWWWWWWWW.."], 5)
LOCK = pad16(["......XXXX......", ".....X....X.....", ".....X....X.....", "....pppppppp....",
              "....pppooppp....", "....pppooppp....", "....PPPPPPPP...."], 5)
MINT = pad16([".....gggggg.....", ".w..gwwggggg..w.", ".ww.gwgggGgg.ww.", ".wwwgggggGGgwww.",
              ".ww.ggggGGgg.ww.", ".w..gggGGggg..w.", ".....gggggg....."], 5)
PROMPT_E = pad16([".....wwwwwww....", ".....wwEEEww....", ".....wwEwwww....", ".....wwEEwww....",
                  ".....wwEwwww....", ".....wwEEEww....", ".....wwwwwww....", ".....WWWWWWW...."], 3)


def heart(fill="a"):
    rows = mirror_rows(HEART_L)
    rows = [r.replace("a", fill) for r in rows]
    if fill == "a":
        rows[6] = rows[6][:4] + "i" + rows[6][5:]
    return rows


def gold(rows):
    return [r.replace("p", "c").replace("P", "C") for r in rows]


def gen_items():
    frames = [heart(), COIN, KEY, gold(KEY), LETTER, LOCK, gold(LOCK), PROMPT_E]
    sheet = blank(16 * len(frames), 16)
    for i, rows in enumerate(frames):
        sheet.alpha_composite(sprite(rows), (i * 16, 0))
    sheet.save(OUT / "items.png")

    hud = blank(48, 16)
    full = heart()
    half = [r[:8] + r[8:].replace("a", "z") for r in heart()]
    empty = heart("z")
    for i, rows in enumerate([full, half, empty]):
        hud.alpha_composite(sprite(rows), (i * 16, 0))
    hud.save(OUT / "hud.png")
    sprite(MINT).save(OUT / "item_mint.png")


# ------------------------------------------------------------------ 机关：火把 / 拉杆 / 尖刺
TORCH_BASE = pad16([".......DD.......", ".......dD.......", ".......dD.......", "......xXXx......",
                    ".......dD.......", "......XxxX......", ".......XX......."], 6)
FLAMES = [
    ["................", ".......Y........", "......YfY.......", "......fYfF......", "......FffF......", ".......FF......."],
    ["................", "........Y.......", ".......fYY......", "......FYfF......", "......FfYF......", ".......FF......."],
    [".......Y........", "......YY........", "......fYfY......", ".....FfYfF......", "......FffF......", ".......FF......."],
]


def overlay(base_rows, top_rows, start):
    rows = list(base_rows)
    for i, line in enumerate(top_rows):
        row = list(rows[start + i])
        for c, ch in enumerate(line):
            if ch != ".":
                row[c] = ch
        rows[start + i] = "".join(row)
    return rows


LEVER_OFF = [
    "................", "................", "................", "....ra..........",
    "....aa..........", ".....D..........", "......D.........", ".......D........",
    "........D.......", ".....xxxxxx.....", "....xXXXXXXx....", "....XzzzzzzX....",
    ".....zzzzzz.....", "................", "................", "................",
]


def spikes(stage):
    img = blank()
    rnd = [(3, 6), (8, 6), (13, 6), (5, 13), (11, 13)]
    px = img.load()
    for cx, cy in rnd:
        # 孔
        px[cx - 1, cy + 1] = STONE_D
        px[cx, cy + 1] = STONE_D
        if stage >= 1:
            px[cx - 1, cy] = STONE_L
            px[cx, cy] = STONE_M
        if stage >= 2:
            for dy in range(1, 3):
                px[cx - 1, cy - dy] = STONE_L
                px[cx, cy - dy] = STONE_M
            px[cx - 1, cy - 3] = (240, 244, 250, 255)
    return add_outline(img) if stage >= 1 else img


FEATHER_PLATE = pad16([
    "...xxxxxxxxxx...",
    "..xXXXXXXXXXXz..",
    "..xXXXXXXXXXXz..",
    "..xXXzzXXzzXXz..",
    "..xXXXXXXXXXXz..",
    "..xXXXXzzXXXXz..",
    "..xXXXXXXXXXXz..",
    "..xXXXXXXXXXXz..",
    "...zzzzzzzzzz...",
], 4)
FEATHER_SLITS = [(5, 7), (9, 7), (7, 9)]


def feather_trap(stage):
    """羽毛陷阱：0 平时，1 预警（羽毛尖露出），2 羽毛弹出。"""
    rows = [list(r) for r in FEATHER_PLATE]
    for c, r in FEATHER_SLITS:
        if stage == 1:
            rows[r - 1][c] = rows[r - 1][c + 1] = "w"
        elif stage == 2:
            for dy in range(1, 6):
                rows[r - dy][c] = "w"
                if dy < 5:
                    rows[r - dy][c + 1] = "w" if dy > 1 else "k"
            rows[r - 5][c + 1] = "W"
    return sprite(["".join(r) for r in rows])


def gen_props():
    sheet = blank(16 * 4, 16 * 4)
    sheet.alpha_composite(sprite(TORCH_BASE), (0, 0))
    for i, fl in enumerate(FLAMES):
        sheet.alpha_composite(sprite(overlay(TORCH_BASE, fl, 0)), (16 * (i + 1), 0))
    sheet.alpha_composite(sprite(LEVER_OFF), (0, 16))
    lever_on = [r[::-1] for r in LEVER_OFF]
    lever_on = [r.replace("a", "g").replace("r", "g") for r in lever_on]
    sheet.alpha_composite(sprite(lever_on), (16, 16))
    for i in range(3):
        sheet.alpha_composite(spikes(i), (16 * i, 32))
    for i in range(3):
        sheet.alpha_composite(feather_trap(i), (16 * i, 48))
    sheet.save(OUT / "props.png")


# ------------------------------------------------------------------ 特效
def gen_fx():
    sheet = blank(32 * 4, 48)
    # 挥击弧光：以 (6,16) 为圆心、朝右的弧，4 帧依次展开并淡出
    spans = [(-80, -20), (-80, 40), (-60, 80), (0, 80)]
    colors = [(255, 255, 255, 255), (255, 244, 170, 255), (255, 214, 72, 255)]
    for f, (a0, a1) in enumerate(spans):
        img = blank(32, 32)
        px = img.load()
        for y in range(32):
            for x in range(32):
                dx, dy = x - 6, y - 16
                r = math.hypot(dx, dy)
                ang = math.degrees(math.atan2(dy, dx))
                if a0 <= ang <= a1 and 11 <= r <= 16:
                    band = 16 - r
                    if f == 3 and band > 2:
                        continue
                    px[x, y] = colors[0 if band < 1.5 else (1 if band < 3 else 2)]
        sheet.alpha_composite(img, (32 * f, 0))
    # 烟雾 16x16 x 4
    rnd = random.Random(3)
    blobs = [(rnd.uniform(-3, 3), rnd.uniform(-3, 3), rnd.uniform(2, 3.5)) for _ in range(6)]
    for f in range(4):
        img = blank()
        px = img.load()
        grow = 1 + f * 0.9
        for bx, by, br in blobs:
            for y in range(16):
                for x in range(16):
                    if math.hypot(x - (8 + bx * grow), y - (8 + by * grow)) <= br * (1.2 - f * 0.25):
                        px[x, y] = (230, 226, 240, 255) if f < 2 else (190, 186, 205, 255)
        sheet.alpha_composite(img, (16 * f, 32))
    sheet.save(OUT / "fx.png")


# ------------------------------------------------------------------ 墙体
N, E, S, W, NE, SE, SW, NW = 1, 2, 4, 8, 16, 32, 64, 128
# 从贴地边往内：轮廓、中石、亮石、亮石、轮廓
SIDE_BAND = [OUTLINE, STONE_M, STONE_L, STONE_L, OUTLINE]
# 南边（下方是墙面）：石檐
CAP_BAND = [STONE_D, STONE_M, STONE_L, STONE_L, OUTLINE]


def wall_top(mask):
    img = Image.new("RGBA", (16, 16), VOID)
    px = img.load()
    for y in range(16):
        for x in range(16):
            best = None
            feats = []
            if mask & N: feats.append((y, SIDE_BAND))
            if mask & S: feats.append((15 - y, CAP_BAND))
            if mask & W: feats.append((x, SIDE_BAND))
            if mask & E: feats.append((15 - x, SIDE_BAND))
            if mask & NE and not mask & (N | E): feats.append((max(y, 15 - x), SIDE_BAND))
            if mask & NW and not mask & (N | W): feats.append((max(y, x), SIDE_BAND))
            if mask & SE and not mask & (S | E): feats.append((max(15 - y, 15 - x), CAP_BAND))
            if mask & SW and not mask & (S | W): feats.append((max(15 - y, x), CAP_BAND))
            for d, band in feats:
                if d < len(band) and (best is None or d < best[0]):
                    best = (d, band)
            if best:
                px[x, y] = best[1][best[0]]
    return img


def kenney_tile(sheet, idx):
    tx, ty = idx % 12, idx // 12
    return sheet.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16))


def wall_face(base, flags):
    img = base.copy()
    px = img.load()
    if flags & 1:  # 上方不是墙：加石檐
        for x in range(16):
            px[x, 0] = OUTLINE
            px[x, 1] = STONE_L
            px[x, 2] = STONE_M
            px[x, 3] = STONE_D
    for bit, xs in ((2, (0, 1, 2)), (4, (15, 14, 13))):
        if flags & bit:  # 端头立柱
            for y in range(16):
                px[xs[0], y] = OUTLINE
                px[xs[1], y] = STONE_L
                px[xs[2], y] = STONE_M
    return img


def gen_walls():
    atlas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for mask in range(256):
        atlas.alpha_composite(wall_top(mask), ((mask % 16) * 16, (mask // 16) * 16))
    atlas.save(OUT / "walls.png")

    ken = Image.open(KENNEY).convert("RGBA")
    variants = [kenney_tile(ken, i) for i in (40, 28, 29, 41)]
    faces = Image.new("RGBA", (16 * len(variants), 16 * 8), (0, 0, 0, 0))
    for v, base in enumerate(variants):
        for flags in range(8):
            faces.alpha_composite(wall_face(base, flags), (v * 16, flags * 16))
    faces.save(OUT / "wall_faces.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    gen_emotes()
    gen_items()
    gen_props()
    gen_fx()
    gen_walls()
    print("misc done")


if __name__ == "__main__":
    main()


# ------------------------------------------------------------------ 第二层机关占位图
PINK = (255, 150, 200, 255)
PINK_L = (255, 205, 228, 255)
PINK_D = (214, 92, 150, 255)
WHITE = (250, 248, 255, 255)
WOOD = (189, 108, 74, 255)
WOOD_D = (120, 64, 48, 255)


def _canvas(w=16, h=16):
    from PIL import ImageDraw
    img = blank(w, h)
    return img, ImageDraw.Draw(img)


def plate(down):
    img, d = _canvas()
    top = 7 if down else 6
    d.rectangle((3, top, 12, 12), fill=STONE_D)
    d.rectangle((3, top, 12, 11), fill=STONE_M if down else STONE_L)
    d.rectangle((5, top + 2, 10, top + 3 if not down else top + 2), fill=STONE_D)
    return add_outline(img)


def vent(stage):
    img, d = _canvas()
    d.ellipse((2, 6, 13, 13), fill=STONE_M)
    d.ellipse((4, 8, 11, 12), fill=OUTLINE)
    d.line((5, 10, 10, 10), fill=PINK_D)
    if stage >= 1:
        for x, y in ((6, 6), (9, 5), (8, 3)):
            d.point((x, y), fill=PINK_L)
    if stage == 2:
        d.ellipse((3, 0, 12, 8), fill=PINK)
        d.ellipse((5, 1, 10, 5), fill=PINK_L)
    return add_outline(img)


def web_shot():
    img, d = _canvas()
    for a in range(0, 360, 45):
        import math as _m
        d.line((8, 8, 8 + round(5 * _m.cos(_m.radians(a))), 8 + round(5 * _m.sin(_m.radians(a)))), fill=WHITE)
    d.ellipse((5, 5, 11, 11), outline=(220, 220, 235, 255))
    return img


def hand(stage):
    """墙上机关手（16x32，上半格是墙面上的缝，下半格伸出到地面）。0 缩回 1 伸出 2 抓紧。"""
    img, d = _canvas(16, 32)
    d.rectangle((4, 10, 11, 14), fill=OUTLINE)            # 墙缝
    if stage >= 1:
        reach = 24 if stage == 2 else 22
        d.rectangle((6, 12, 9, reach - 4), fill=STONE_M)  # 金属臂
        d.line((6, 12, 6, reach - 4), fill=STONE_L)
        if stage == 1:                                     # 张开的手套
            d.rectangle((3, reach - 4, 12, reach), fill=WHITE)
            for x in (3, 6, 9, 12):
                d.line((x, reach, x, reach + 3), fill=WHITE)
            d.point((12, reach - 2), fill=PINK)
        else:                                              # 抓紧
            d.ellipse((3, reach - 4, 12, reach + 3), fill=WHITE)
            d.line((5, reach, 10, reach), fill=PINK_D)
    return add_outline(img)


def brush():
    """旋转羽毛刷：中心轴在 (8,8)，刷臂向右 44px，总尺寸 56x16。"""
    img, d = _canvas(56, 16)
    d.rounded_rectangle((13, 3, 53, 12), radius=3, fill=PINK_L)   # 羽毛簇
    for x in range(15, 53, 4):
        d.line((x, 4, x + 2, 11), fill=PINK)
    for x in range(14, 53, 2):
        d.point((x, 3 if x % 4 else 12), fill=WHITE)
    d.rectangle((8, 7, 50, 8), fill=WOOD)                          # 木杆
    d.line((8, 8, 50, 8), fill=WOOD_D)
    d.ellipse((3, 3, 13, 13), fill=STONE_M)                        # 轴
    d.ellipse((6, 6, 10, 10), fill=STONE_D)
    return add_outline(img)


def gen_floor2_props():
    sheet = blank(64, 64)
    sheet.alpha_composite(plate(False), (0, 0))
    sheet.alpha_composite(plate(True), (16, 0))
    for i in range(3):
        sheet.alpha_composite(vent(i), (16 * i, 16))
    sheet.alpha_composite(web_shot(), (0, 48))
    sheet.save(OUT / "new_props.png")
    hands = blank(48, 32)
    for i in range(3):
        hands.alpha_composite(hand(i), (16 * i, 0))
    hands.save(OUT / "grab_hand.png")
    brush().save(OUT / "feather_brush.png")


if __name__ == "__main__":
    gen_floor2_props()
