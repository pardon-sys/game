"""检查点、存档点和第六层地下小镇的像素图。

输出到 assets/generated/：
  checkpoint.png   32x16 × 2 帧（地上的魔法阵：暗 / 亮）+ crystal.png 8x12 × 4 帧（漂浮的小水晶，旋转）
  save_point.png   16x16 × 2 帧（发光的日记本：合着 / 翻开发光）
  npcs/<id>.png    居民和关键人物的行走图：32x32 × 4 帧 × 4 行（行 = 下 / 左 / 右 / 上，帧 = 站 / 迈步 / 站 / 迈步）
  npc_portraits/<id>.png  关键人物的半身立绘（228x304，2 倍密度，和公主立绘一样大）
  princess_blue.png / portraits_blue.png / portrait_heads_blue.png  蓝色公主：公主的行走图、立绘、头像换成蓝色调
  town_props.png + town_props.json  小镇道具图集（房屋、摊位、篝火、帐篷、哨塔、栅栏、训练假人、路灯、木箱、矿车、井、楼梯、封住的地牢门……）

用法：python tools/art/gen_town_art.py
"""
import math

from gen_expansion import _strip, blank, canvas
from palette import OUT, add_outline

PINK = (255, 150, 205, 255)
PINK_D = (180, 70, 140, 255)
PINK_L = (255, 220, 240, 255)
DIM = (120, 80, 120, 200)
DIM_D = (80, 55, 85, 200)
CRYSTAL = (150, 230, 255, 255)
CRYSTAL_D = (70, 150, 220, 255)
CRYSTAL_L = (235, 255, 255, 255)
GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
BOOK = (150, 70, 110, 255)
BOOK_D = (100, 40, 75, 255)
PAPER = (250, 240, 220, 255)


# ------------------------------------------------------------------ 检查点
def checkpoint_circle(lit):
    """地上的椭圆魔法阵：外圈 + 内圈 + 六角星 + 四个小符点。"""
    img, d = canvas(32, 16)
    c, cd = (PINK, PINK_D) if lit else (DIM, DIM_D)
    d.ellipse((1, 1, 30, 14), outline=cd)
    d.ellipse((3, 2, 28, 13), outline=c)
    d.ellipse((9, 5, 22, 10), outline=cd)
    cx, cy = 15.5, 7.5
    for k in range(6):
        a1 = math.radians(k * 60)
        a2 = math.radians(k * 60 + 120)
        d.line((cx + math.cos(a1) * 11, cy + math.sin(a1) * 5, cx + math.cos(a2) * 11, cy + math.sin(a2) * 5), fill=c)
    for k in range(4):
        a = math.radians(45 + k * 90)
        d.point((cx + math.cos(a) * 13, cy + math.sin(a) * 6), fill=PINK_L if lit else c)
    return img


def crystal(f):
    """漂浮的菱形小水晶，四帧转动（亮面左右移动）。"""
    img, d = canvas(8, 12)
    d.polygon([(4, 0), (7, 5), (4, 11), (1, 5)], fill=CRYSTAL_D)
    w = (2, 3, 2, 1)[f]
    d.polygon([(4, 0), (4 + w, 5), (4, 11), (4 - (3 - w), 5)], fill=CRYSTAL)
    d.line((4, 1, 4 + (1 if f < 2 else -1), 5), fill=CRYSTAL_L)
    return add_outline(img)


# ------------------------------------------------------------------ 存档点
def save_point(f):
    """台座上的日记本：0 合着，1 翻开、书页发光。"""
    img, d = canvas()
    d.rectangle((3, 11, 12, 15), fill=GOLD_D)
    d.rectangle((4, 11, 11, 13), fill=GOLD)
    if f == 0:
        d.rectangle((3, 5, 12, 10), fill=BOOK)
        d.line((3, 10, 12, 10), fill=BOOK_D)
        d.rectangle((7, 6, 8, 9), fill=GOLD)
    else:
        d.polygon([(1, 7), (7, 5), (7, 10), (1, 10)], fill=PAPER)
        d.polygon([(14, 7), (8, 5), (8, 10), (14, 10)], fill=PAPER)
        d.line((7, 5, 7, 10), fill=BOOK_D)
        for y in (7, 8):
            d.line((2, y, 5, y - 1), fill=(200, 180, 160, 255))
            d.line((10, y - 1, 13, y), fill=(200, 180, 160, 255))
        d.point((7, 2), fill=PINK_L)
        d.point((5, 3), fill=PINK)
        d.point((10, 3), fill=PINK)
    return add_outline(img)


def gen_markers():
    _strip([checkpoint_circle(False), checkpoint_circle(True)], 32, 16).save(OUT / "checkpoint.png")
    _strip([crystal(f) for f in range(4)], 8, 12).save(OUT / "crystal.png")
    _strip([save_point(f) for f in range(2)], 16, 16).save(OUT / "save_point.png")


# ------------------------------------------------------------------ 居民 / 关键人物
OUTLINE = (63, 38, 49, 255)
SKIN = (255, 228, 210, 255)
SKIN_D = (235, 190, 170, 255)
EYE = (60, 40, 60, 255)
WHITE = (250, 250, 255, 255)
STEEL = (196, 206, 222, 255)
STEEL_D = (120, 132, 156, 255)

# id -> 外观：hair / outfit / accent 颜色，style 决定配件
LOOKS = {
    "granny": {"hair": (205, 205, 215), "outfit": (150, 110, 160), "accent": (240, 220, 180), "style": "granny"},
    "kid": {"hair": (170, 110, 60), "outfit": (110, 180, 230), "accent": (255, 220, 90), "style": "kid"},
    "merchant": {"hair": (90, 60, 40), "outfit": (200, 130, 70), "accent": (240, 235, 210), "style": "merchant"},
    "miner": {"hair": (60, 50, 50), "outfit": (110, 100, 90), "accent": (255, 210, 80), "style": "miner"},
    "maid": {"hair": (60, 40, 70), "outfit": (60, 50, 80), "accent": (250, 250, 255), "style": "maid"},
    "guard": {"hair": (120, 80, 50), "outfit": (90, 110, 150), "accent": (196, 206, 222), "style": "guard"},
    "captain": {"hair": (230, 200, 120), "outfit": (150, 40, 60), "accent": (220, 180, 70), "style": "captain"},
    "supervisor": {"hair": (110, 70, 140), "outfit": (70, 120, 90), "accent": (240, 230, 200), "style": "supervisor"},
    "bonfire_host": {"hair": (240, 120, 60), "outfit": (230, 90, 120), "accent": (255, 220, 100), "style": "host"},
}


def _c(rgb, k=1.0, a=255):
    return tuple(max(0, min(255, int(v * k))) for v in rgb) + (a,)


def npc_frame(look, row, col):
    """32x32：row 0 下 / 1 左 / 2 右 / 3 上；col 1、3 迈步。"""
    img, d = canvas(32, 32)
    st = look["style"]
    small = st == "kid"
    hair, hair_d = _c(look["hair"]), _c(look["hair"], 0.7)
    out, out_d = _c(look["outfit"]), _c(look["outfit"], 0.7)
    acc = _c(look["accent"])
    hy = 13 if small else 10          # 头的中心 y
    hr = 6 if small else 6
    by0, by1 = (19, 26) if small else (17, 26)
    step = col in (1, 3)
    swing = (1 if col == 1 else -1) if step else 0
    # 腿
    leg = _c(look["outfit"], 0.5)
    if row in (0, 3):
        d.rectangle((12, by1, 14, 29 - (1 if swing > 0 else 0)), fill=leg)
        d.rectangle((17, by1, 19, 29 - (1 if swing < 0 else 0)), fill=leg)
    else:
        d.rectangle((14 + swing, by1, 16 + swing, 29), fill=leg)
        d.rectangle((15 - swing, by1, 17 - swing, 29), fill=_c(look["outfit"], 0.4))
    # 身体（裙子 / 衣服）
    if st in ("maid", "host", "granny"):
        d.polygon([(11, by0), (20, by0), (22, by1 + 1), (9, by1 + 1)], fill=out)
        d.line((9, by1 + 1, 22, by1 + 1), fill=out_d)
    else:
        d.rectangle((11, by0, 20, by1), fill=out)
        d.line((11, by1, 20, by1), fill=out_d)
    if st == "maid" and row != 3:
        d.rectangle((13, by0 + 2, 18, by1), fill=WHITE)
    if st == "merchant" and row != 3:
        d.rectangle((12, by0 + 3, 19, by1), fill=acc)
    if st in ("guard", "captain"):
        d.rectangle((11, by0, 20, by0 + 4), fill=STEEL)
        d.line((11, by0 + 4, 20, by0 + 4), fill=STEEL_D)
    if st == "captain" and row != 0:
        d.polygon([(10, by0), (21, by0), (23, by1 + 2), (8, by1 + 2)], fill=_c(look["outfit"], 0.8))
    if st == "supervisor" and row != 3:
        d.rectangle((13, by0, 18, by1), fill=acc)
        d.line((15, by0, 15, by1), fill=out_d)
    # 手臂
    arm = SKIN
    if row in (0, 3):
        d.rectangle((9, by0 + 1, 10, by0 + 6 + swing), fill=out_d)
        d.rectangle((21, by0 + 1, 22, by0 + 6 - swing), fill=out_d)
        d.point((9, by0 + 7 + swing), fill=arm)
        d.point((22, by0 + 7 - swing), fill=arm)
    else:
        ax = 15 + swing * 2
        d.rectangle((ax, by0 + 1, ax + 1, by0 + 6), fill=out_d)
        d.point((ax, by0 + 7), fill=arm)
    # 头
    d.ellipse((16 - hr, hy - hr, 16 + hr - 1, hy + hr - 1), fill=SKIN)
    # 头发
    if row == 3:
        d.ellipse((16 - hr, hy - hr, 16 + hr - 1, hy + hr - 1), fill=hair)
    else:
        d.chord((16 - hr, hy - hr - 1, 16 + hr - 1, hy + hr - 2), 180, 360, fill=hair)
        if row == 0:
            d.rectangle((16 - hr, hy - 2, 16 - hr + 1, hy + 2), fill=hair)
            d.rectangle((16 + hr - 2, hy - 2, 16 + hr - 1, hy + 2), fill=hair)
        elif row == 1:
            d.rectangle((16, hy - 3, 16 + hr - 1, hy + 2), fill=hair)
        else:
            d.rectangle((16 - hr, hy - 3, 15, hy + 2), fill=hair)
    if st == "granny" and row != 0:
        d.ellipse((13, hy - hr - 4, 18, hy - hr + 1), fill=hair)
    if st == "granny" and row == 0:
        d.ellipse((13, hy - hr - 4, 18, hy - hr + 1), fill=hair)
    # 眼睛
    if row == 0:
        d.point((14, hy + 1), fill=EYE)
        d.point((18, hy + 1), fill=EYE)
        d.point((13, hy + 3), fill=(255, 170, 170, 255))
        d.point((19, hy + 3), fill=(255, 170, 170, 255))
    elif row == 1:
        d.point((12, hy + 1), fill=EYE)
    elif row == 2:
        d.point((19, hy + 1), fill=EYE)
    # 帽子 / 头盔 / 配件
    if st in ("guard", "captain"):
        d.chord((16 - hr - 1, hy - hr - 2, 16 + hr, hy + 2), 180, 360, fill=STEEL)
        d.line((16 - hr - 1, hy, 16 + hr, hy), fill=STEEL_D)
        if st == "captain":
            d.polygon([(16, hy - hr - 2), (19, hy - hr - 6), (21, hy - hr - 4), (17, hy - hr - 1)], fill=(220, 50, 70, 255))
    if st == "miner":
        d.chord((16 - hr - 1, hy - hr - 2, 16 + hr, hy + 1), 180, 360, fill=(230, 180, 60, 255))
        if row == 0:
            d.rectangle((15, hy - hr - 1, 16, hy - hr), fill=(255, 250, 200, 255))
    if st == "merchant":
        d.rectangle((16 - hr - 1, hy - hr - 1, 16 + hr, hy - hr + 1), fill=_c(look["accent"], 0.6))
        d.rectangle((16 - hr + 2, hy - hr - 4, 16 + hr - 3, hy - hr - 1), fill=_c(look["accent"], 0.6))
    if st == "maid" and row != 3:
        d.line((16 - hr + 1, hy - hr + 1, 16 + hr - 2, hy - hr + 1), fill=WHITE)
    if st == "host":
        for x in range(16 - hr, 16 + hr, 3):
            d.point((x, hy - hr), fill=(255, 220, 100, 255))
            d.point((x + 1, hy - hr), fill=(255, 140, 180, 255))
    if st == "supervisor" and row == 0:
        d.rectangle((13, hy, 15, hy + 2), outline=(80, 80, 90, 255))
        d.rectangle((17, hy, 19, hy + 2), outline=(80, 80, 90, 255))
    # 手持物
    if st == "granny" and row != 3:
        d.line((23, by0 + 2, 23, 29), fill=(140, 90, 60, 255))
    if st == "miner" and row != 3:
        d.line((22, by0, 25, by0 + 7), fill=(140, 90, 60, 255))
        d.line((23, by0 - 1, 26, by0 + 1), fill=STEEL)
    if st == "guard" and row != 3:
        d.line((24, by0 - 6, 24, 29), fill=(140, 90, 60, 255))
        d.polygon([(23, by0 - 6), (25, by0 - 6), (24, by0 - 10)], fill=STEEL)
    if st == "supervisor" and row in (0, 2):
        d.rectangle((20, by0 + 3, 23, by0 + 7), fill=(240, 230, 200, 255))
    return add_outline(img)


def npc_sheet(look):
    sheet = blank(32 * 4, 32 * 4)
    for row in range(4):
        for col in range(4):
            sheet.alpha_composite(npc_frame(look, row, col), (col * 32, row * 32))
    return sheet


def npc_portrait(look):
    """半身立绘（先画 114x152，再放大 2 倍成 228x304）。"""
    from PIL import ImageDraw
    img = blank(114, 152)
    d = ImageDraw.Draw(img)
    st = look["style"]
    hair, hair_d = _c(look["hair"]), _c(look["hair"], 0.72)
    out, out_d = _c(look["outfit"]), _c(look["outfit"], 0.7)
    acc = _c(look["accent"])
    # 身体
    d.polygon([(22, 152), (30, 108), (84, 108), (92, 152)], fill=out)
    d.line((57, 112, 57, 152), fill=out_d)
    if st in ("guard", "captain"):
        d.polygon([(26, 112), (88, 112), (86, 126), (28, 126)], fill=STEEL)
        d.line((28, 126, 86, 126), fill=STEEL_D)
        if st == "captain":
            d.polygon([(18, 152), (24, 110), (30, 108), (30, 152)], fill=_c(look["outfit"], 0.8))
            d.polygon([(96, 152), (90, 110), (84, 108), (84, 152)], fill=_c(look["outfit"], 0.8))
            d.ellipse((50, 116, 64, 128), fill=acc)
    if st == "supervisor":
        d.polygon([(46, 108), (68, 108), (66, 152), (48, 152)], fill=acc)
        d.rectangle((70, 124, 90, 150), fill=(245, 236, 210, 255), outline=(150, 120, 90, 255))
        for y in range(130, 148, 4):
            d.line((73, y, 87, y), fill=(160, 150, 140, 255))
    if st == "host":
        d.ellipse((40, 112, 52, 124), fill=(255, 200, 90, 255))
        d.ellipse((62, 114, 74, 126), fill=(255, 150, 190, 255))
    # 脖子和头
    d.rectangle((50, 96, 64, 110), fill=SKIN_D)
    d.ellipse((25, 24, 89, 98), fill=SKIN)
    # 头发
    d.chord((21, 18, 93, 84), 180, 360, fill=hair)
    d.polygon([(21, 52), (30, 40), (34, 78), (24, 86)], fill=hair)
    d.polygon([(93, 52), (84, 40), (80, 78), (90, 86)], fill=hair)
    for x in range(34, 82, 12):
        d.polygon([(x, 44), (x + 12, 44), (x + 6, 58)], fill=hair)
    d.arc((21, 18, 93, 84), 200, 340, fill=hair_d)
    if st in ("granny",):
        d.ellipse((44, 4, 70, 26), fill=hair)
    if st == "host":
        for i, x in enumerate(range(26, 92, 9)):
            d.ellipse((x, 20 + (i % 2) * 3, x + 8, 28 + (i % 2) * 3), fill=(255, 220, 100, 255) if i % 2 else (255, 140, 180, 255))
    # 头盔 / 帽子
    if st in ("guard", "captain"):
        d.chord((18, 12, 96, 70), 180, 360, fill=STEEL)
        d.line((18, 41, 96, 41), fill=STEEL_D)
        if st == "captain":
            d.polygon([(57, 12), (70, 0), (80, 4), (62, 16)], fill=(220, 50, 70, 255))
    if st == "merchant":
        d.rectangle((18, 30, 96, 36), fill=_c(look["accent"], 0.55))
        d.rectangle((32, 10, 82, 32), fill=_c(look["accent"], 0.55))
    if st == "miner":
        d.chord((18, 14, 96, 68), 180, 360, fill=(230, 180, 60, 255))
        d.ellipse((50, 18, 64, 30), fill=(255, 250, 200, 255))
    if st == "maid":
        d.rectangle((30, 38, 84, 44), fill=WHITE)
    # 眼睛
    for ex in (42, 72):
        d.ellipse((ex - 7, 60, ex + 7, 76), fill=WHITE)
        d.ellipse((ex - 5, 62, ex + 5, 76), fill=_c(look["hair"], 0.5))
        d.ellipse((ex - 2, 66, ex + 2, 72), fill=EYE)
        d.point((ex - 3, 64), fill=WHITE)
        d.line((ex - 8, 58, ex + 6, 56 if ex < 57 else 58), fill=hair_d)
    if st == "supervisor":
        d.rectangle((33, 59, 51, 77), outline=(70, 70, 80, 255))
        d.rectangle((63, 59, 81, 77), outline=(70, 70, 80, 255))
        d.line((51, 66, 63, 66), fill=(70, 70, 80, 255))
    if st == "captain":
        d.line((34, 54, 50, 58), fill=hair_d, width=2)
        d.line((80, 54, 64, 58), fill=hair_d, width=2)
    # 嘴和腮红
    d.arc((50, 80, 64, 90), 20, 160, fill=(190, 90, 100, 255))
    d.ellipse((30, 78, 40, 84), fill=(255, 180, 180, 160))
    d.ellipse((74, 78, 84, 84), fill=(255, 180, 180, 160))
    img = add_outline(img)
    return img.resize((228, 304), resample=0)


# ------------------------------------------------------------------ 蓝色公主
def _blue(img):
    """粉色 / 红色系（色相 300°~20°、饱和度够高）换成蓝色系；皮肤、白裙、金色不动。"""
    import colorsys
    px = img.load()
    w, h = img.size
    out = img.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = hh * 360
            if ss > 0.22 and (deg >= 290 or deg <= 18):
                nh = (deg + 230) % 360 / 360  # 粉 (~335°) → 蓝 (~205°)
                nr, ng, nb = colorsys.hsv_to_rgb(nh, min(ss * 1.05, 1.0), vv)
                po[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def gen_blue_princess():
    from PIL import Image
    for name in ("princess", "portraits", "portrait_heads", "princess_magic"):
        src = OUT / (name + ".png")
        if src.exists():
            _blue(Image.open(src).convert("RGBA")).save(OUT / (name + "_blue.png"))


# ------------------------------------------------------------------ 小镇道具
WOOD = (170, 110, 70, 255)
WOOD_D = (110, 70, 45, 255)
WOOD_L = (210, 150, 100, 255)
STONE = (150, 140, 150, 255)
STONE_D = (100, 92, 104, 255)
ROOF = [(200, 80, 90, 255), (90, 130, 190, 255), (110, 160, 100, 255), (190, 140, 70, 255)]


def p_house(v):
    img, d = canvas(48, 48)
    roof = ROOF[v % len(ROOF)]
    roof_d = _c(roof[:3], 0.72)
    d.rectangle((4, 20, 43, 46), fill=(230, 210, 180, 255) if v % 2 == 0 else (200, 190, 200, 255))
    d.line((4, 46, 43, 46), fill=STONE_D)
    d.polygon([(0, 22), (24, 3), (47, 22)], fill=roof)
    for y in range(8, 22, 4):
        d.line((24 - (y - 3) * 24 // 19, y, 24 + (y - 3) * 24 // 19, y), fill=roof_d)
    d.rectangle((34, 4, 39, 14), fill=STONE)
    d.rectangle((19, 31, 28, 46), fill=WOOD)
    d.point((26, 39), fill=(255, 214, 72, 255))
    for wx in (8, 33):
        d.rectangle((wx, 27, wx + 7, 34), fill=(255, 220, 140, 255))
        d.line((wx + 3, 27, wx + 3, 34), fill=WOOD_D)
        d.line((wx, 30, wx + 7, 30), fill=WOOD_D)
    return add_outline(img)


def p_stall(v):
    img, d = canvas(32, 32)
    stripe = [(230, 80, 100, 255), (80, 150, 220, 255), (240, 190, 70, 255)][v % 3]
    d.rectangle((3, 10, 4, 30), fill=WOOD_D)
    d.rectangle((27, 10, 28, 30), fill=WOOD_D)
    for i, x in enumerate(range(1, 31, 5)):
        d.polygon([(x, 6), (x + 5, 6), (x + 5, 12), (x, 13)], fill=stripe if i % 2 == 0 else (250, 245, 235, 255))
    d.rectangle((1, 4, 30, 6), fill=_c(stripe[:3], 0.7))
    d.rectangle((2, 20, 29, 26), fill=WOOD)
    d.line((2, 20, 29, 20), fill=WOOD_L)
    goods = [[(255, 120, 120), (255, 200, 90), (140, 220, 120)], [(200, 160, 230), (150, 220, 230), (250, 250, 250)],
             [(255, 150, 200), (150, 230, 255), (255, 230, 120)]][v % 3]
    for i, col in enumerate(goods):
        d.ellipse((5 + i * 8, 16, 10 + i * 8, 20), fill=col + (255,))
    return add_outline(img)


def p_bonfire(f):
    img, d = canvas(24, 24)
    for x0, y0, x1, y1 in ((3, 19, 20, 22), (5, 18, 18, 23)):
        d.line((x0, y0, x1, y1), fill=WOOD_D, width=2)
    for i, a in enumerate(range(0, 360, 45)):
        x, y = 12 + math.cos(math.radians(a)) * 9, 20 + math.sin(math.radians(a)) * 3
        d.ellipse((x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=STONE)
    sway = 1 if f else -1
    d.polygon([(6, 19), (12, 4 + sway), (18, 19)], fill=(255, 130, 60, 255))
    d.polygon([(8, 19), (12 + sway, 8), (16, 19)], fill=(255, 200, 80, 255))
    d.polygon([(10, 19), (12, 12 - sway), (14, 19)], fill=(255, 245, 190, 255))
    return img


def p_tent():
    img, d = canvas(32, 32)
    d.polygon([(1, 30), (16, 4), (31, 30)], fill=(150, 160, 120, 255))
    d.polygon([(16, 4), (31, 30), (22, 30)], fill=(120, 130, 95, 255))
    d.polygon([(12, 30), (16, 18), (20, 30)], fill=(60, 50, 50, 255))
    d.line((16, 1, 16, 5), fill=WOOD_D)
    d.polygon([(16, 1), (22, 3), (16, 5)], fill=(90, 110, 160, 255))
    return add_outline(img)


def p_tower():
    img, d = canvas(24, 48)
    for x in (4, 19):
        d.rectangle((x, 14, x + 1, 47), fill=WOOD_D)
    for y in (24, 34, 44):
        d.line((4, y, 20, y - 6), fill=WOOD)
    d.rectangle((1, 10, 22, 16), fill=WOOD)
    d.line((1, 10, 22, 10), fill=WOOD_L)
    d.polygon([(0, 10), (12, 0), (23, 10)], fill=(90, 110, 160, 255))
    return add_outline(img)


def p_simple(kind, f=0):
    img, d = canvas()
    if kind == "fence":
        for x in (2, 13):
            d.rectangle((x, 4, x + 1, 15), fill=WOOD_D)
        d.rectangle((0, 7, 15, 8), fill=WOOD)
        d.rectangle((0, 11, 15, 12), fill=WOOD)
    elif kind == "dummy":
        d.line((8, 6, 8, 15), fill=WOOD_D, width=2)
        d.line((3, 9, 13, 9), fill=WOOD_D, width=2)
        d.ellipse((4, 0, 11, 7), fill=(220, 200, 150, 255))
        d.rectangle((5, 8, 11, 13), fill=(200, 170, 120, 255))
    elif kind == "lamp":
        d.line((7, 4, 7, 15), fill=(60, 60, 70, 255))
        d.rectangle((5, 0, 9, 4), fill=(255, 230, 140, 255))
        d.rectangle((5, 0, 9, 0), fill=(60, 60, 70, 255))
    elif kind == "crate":
        d.rectangle((1, 4, 14, 15), fill=WOOD)
        d.rectangle((1, 4, 14, 15), outline=WOOD_D)
        d.line((1, 4, 14, 15), fill=WOOD_D)
    elif kind == "cart":
        d.polygon([(1, 5), (14, 5), (12, 12), (3, 12)], fill=STONE_D)
        d.rectangle((2, 3, 13, 5), fill=(120, 110, 100, 255))
        d.ellipse((2, 11, 6, 15), fill=(60, 60, 70, 255))
        d.ellipse((9, 11, 13, 15), fill=(60, 60, 70, 255))
    elif kind == "well":
        d.ellipse((1, 6, 14, 15), fill=STONE)
        d.ellipse((3, 7, 12, 12), fill=(40, 60, 90, 255))
        d.line((2, 0, 2, 8), fill=WOOD_D)
        d.line((13, 0, 13, 8), fill=WOOD_D)
        d.line((1, 1, 14, 1), fill=WOOD)
    elif kind == "stairs_down":
        d.rectangle((0, 0, 15, 15), fill=STONE_D)
        for i, y in enumerate(range(2, 15, 3)):
            d.rectangle((1 + i, y, 14 - i, y + 1), fill=_c((150, 140, 150), 1.0 - i * 0.15))
    elif kind == "stairs_up":
        d.rectangle((0, 0, 15, 15), fill=STONE_D)
        for i, y in enumerate(range(13, 0, -3)):
            d.rectangle((1 + i, y, 14 - i, y + 1), fill=_c((190, 180, 190), 1.0 - i * 0.12))
    elif kind == "banner":
        d.line((2, 0, 2, 15), fill=WOOD_D)
        d.polygon([(3, 1), (14, 1), (14, 11), (8, 9), (3, 11)], fill=(90, 110, 160, 255))
        d.ellipse((6, 3, 11, 7), fill=(220, 180, 70, 255))
    elif kind == "bench":
        d.rectangle((1, 7, 14, 9), fill=WOOD)
        d.line((2, 9, 2, 14), fill=WOOD_D)
        d.line((13, 9, 13, 14), fill=WOOD_D)
    elif kind == "flowers":
        for i, (x, y) in enumerate(((3, 10), (8, 8), (12, 11), (6, 13))):
            d.line((x, y, x, 15), fill=(90, 160, 90, 255))
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=[(255, 140, 180), (255, 220, 100), (150, 200, 255), (255, 255, 255)][i] + (255,))
    return add_outline(img) if kind not in ("stairs_down", "stairs_up") else img


def p_gate():
    img, d = canvas(32, 32)
    d.rectangle((0, 0, 31, 31), fill=STONE_D)
    d.rectangle((4, 4, 27, 31), fill=(30, 20, 34, 255))
    d.chord((4, 0, 27, 12), 180, 360, fill=(30, 20, 34, 255))
    for x in range(6, 27, 4):
        d.line((x, 4, x, 31), fill=STEEL_D)
    d.line((4, 16, 27, 16), fill=STEEL_D)
    d.rectangle((12, 14, 19, 20), fill=(220, 180, 70, 255))
    return img


PROPS = {}


def gen_props():
    """道具图集：每个道具一格（大小不同），town_props.json 记录区域、碰撞和发光。"""
    from PIL import Image
    items = []
    for v in range(4):
        items.append(("house_%d" % v, p_house(v), {"body": [40, 16], "body_y": -8}))
    for v in range(3):
        items.append(("stall_%d" % v, p_stall(v), {"body": [28, 8], "body_y": -6}))
    items.append(("bonfire_0", p_bonfire(0), {"body": [16, 6], "light": [1.0, 0.6, 0.3], "anim": "bonfire_1"}))
    items.append(("bonfire_1", p_bonfire(1), {}))
    items.append(("tent", p_tent(), {"body": [28, 10], "body_y": -5}))
    items.append(("tower", p_tower(), {"body": [20, 8], "body_y": -4}))
    for k in ("fence", "dummy", "lamp", "crate", "cart", "well", "banner", "bench", "flowers"):
        info = {"body": [14, 6], "body_y": -3}
        if k == "lamp":
            info["light"] = [1.0, 0.85, 0.55]
        if k in ("flowers",):
            info = {}
        items.append((k, p_simple(k), info))
    items.append(("stairs_down", p_simple("stairs_down"), {"floor": True}))
    items.append(("stairs_up", p_simple("stairs_up"), {"floor": True}))
    items.append(("dungeon_gate", p_gate(), {"body": [32, 12], "body_y": -6}))
    # 简单地按行排进 256 宽的图集
    x = y = row_h = 0
    meta = {}
    placed = []
    for name, img, info in items:
        w, h = img.size
        if x + w > 256:
            x, y, row_h = 0, y + row_h, 0
        placed.append((img, x, y))
        meta[name] = dict(info, region=[x, y, w, h])
        x += w
        row_h = max(row_h, h)
    sheet = Image.new("RGBA", (256, y + row_h), (0, 0, 0, 0))
    for img, px, py in placed:
        sheet.alpha_composite(img, (px, py))
    sheet.save(OUT / "town_props.png")
    import json
    (OUT / "town_props.json").write_text(json.dumps(meta, ensure_ascii=False, indent="\t") + "\n")


def gen_npcs():
    (OUT / "npcs").mkdir(exist_ok=True)
    (OUT / "npc_portraits").mkdir(exist_ok=True)
    for nid, look in LOOKS.items():
        npc_sheet(look).save(OUT / "npcs" / (nid + ".png"))
        if nid in ("captain", "supervisor", "bonfire_host"):
            npc_portrait(look).save(OUT / "npc_portraits" / (nid + ".png"))


def main():
    gen_markers()
    gen_npcs()
    gen_blue_princess()
    gen_props()
    print("检查点 / 存档点 / 居民 / 蓝色公主 / 小镇道具像素图已生成")


if __name__ == "__main__":
    main()
