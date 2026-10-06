"""检查点、存档点和第六层地下小镇的像素图。

输出到 assets/generated/：
  checkpoint.png   32x16 × 2 帧（地上的魔法阵：暗 / 亮）+ crystal.png 8x12 × 4 帧（漂浮的小水晶，旋转）
  save_point.png   16x16 × 2 帧（发光的日记本：合着 / 翻开发光）
  npcs/<id>.png    居民和关键人物的行走图：32x32 × 4 帧 × 4 行（行 = 下 / 左 / 右 / 上，帧 = 站 / 迈步 / 站 / 迈步）
  （关键人物的立绘由 tools/art/import_portraits_v2.py 从用户的插画生成）
  town_props.png + town_props.json  小镇道具图集（房屋、摊位、篝火、帐篷、哨塔、栅栏、训练假人、路灯、木箱、矿车、井、楼梯、封住的地牢门……）

用法：python tools/art/gen_town_art.py
"""
import math

from PIL import ImageDraw

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


# ------------------------------------------------------------------ 三个关键人物（按用户给的立绘重画）
SILVER, SILVER_D, SILVER_L = (205, 210, 222, 255), (140, 146, 165, 255), (240, 243, 250, 255)
GOLD, GOLD_D = (226, 186, 84, 255), (170, 128, 50, 255)
NAVY, NAVY_D = (44, 56, 120, 255), (28, 34, 82, 255)
CREAM = (238, 232, 214, 255)
ROSE, ROSE_D = (214, 122, 124, 255), (160, 82, 90, 255)
CRIMSON, CRIMSON_D = (150, 34, 44, 255), (100, 22, 34, 255)
AUBURN, AUBURN_D = (160, 64, 60, 255), (112, 40, 42, 255)
LEATHER = (110, 72, 46, 255)
PEACH, PEACH_D = (250, 178, 140, 255), (222, 130, 96, 255)
FLAME, FLAME_D, FLAME_L = (240, 108, 54, 255), (196, 56, 40, 255), (255, 196, 92, 255)


def _head(d, row, hy, hair, hair_d, eye=EYE, long_hair=False):
    """头和头发（row 0 下 / 1 左 / 2 右 / 3 上）。"""
    d.ellipse((11, hy - 5, 20, hy + 4), fill=SKIN)
    if row == 3:
        d.ellipse((10, hy - 6, 21, hy + 4), fill=hair)
        if long_hair:
            d.rectangle((10, hy, 21, hy + 10), fill=hair)
            d.line((15, hy + 1, 15, hy + 10), fill=hair_d)
        return
    d.chord((10, hy - 7, 21, hy + 3), 180, 360, fill=hair)
    if row == 0:
        d.rectangle((10, hy - 3, 11, hy + (8 if long_hair else 2)), fill=hair)
        d.rectangle((20, hy - 3, 21, hy + (8 if long_hair else 2)), fill=hair)
        d.point((13, hy), fill=eye)
        d.point((18, hy), fill=eye)
        d.point((12, hy + 2), fill=(255, 170, 170, 255))
        d.point((19, hy + 2), fill=(255, 170, 170, 255))
    else:
        back = (16, 21) if row == 1 else (10, 15)
        d.rectangle((back[0], hy - 4, back[1], hy + (9 if long_hair else 2)), fill=hair)
        d.point((12 if row == 1 else 19, hy), fill=eye)
    d.line((12, hy - 4, 19, hy - 4), fill=hair_d)


def _legs(d, row, swing, y0, y1, color):
    """腿：正面 / 背面抬脚的那条短 2 像素（脚离地），侧面前后迈开 ±2 像素。"""
    if row in (0, 3):
        d.rectangle((12, y0, 14, y1 - (2 if swing > 0 else 0)), fill=color)
        d.rectangle((17, y0, 19, y1 - (2 if swing < 0 else 0)), fill=color)
    else:
        d.rectangle((14 + swing * 2, y0, 16 + swing * 2, y1), fill=color)
        d.rectangle((15 - swing * 2, y0, 17 - swing * 2, y1 - (1 if swing else 0)), fill=_c(color[:3], 0.75))


def _walk_fx(img, col, hem_y0, hem_y1, leg_y0):
    """走路的整体动作（三个关键人物共用）：迈步的两帧（1、3）身体往上起伏 1 像素，下摆（裙子 / 披风）左右晃 1 像素。"""
    from PIL import Image
    if col not in (1, 3):
        return img
    out = Image.new("RGBA", img.size)
    w, h = img.size
    # 腿以上整体上移 1 像素（头发、手里的东西跟着一起动）
    out.alpha_composite(img.crop((0, 0, w, leg_y0)), (0, -1))
    out.alpha_composite(img.crop((0, leg_y0, w, h)), (0, leg_y0))
    # 下摆晃动：迈左脚往右晃，迈右脚往左晃
    dx = 1 if col == 1 else -1
    band = out.crop((0, hem_y0 - 1, w, hem_y1))
    clear = Image.new("RGBA", (w, hem_y1 - hem_y0 + 1))
    out.paste(clear, (0, hem_y0 - 1))
    out.alpha_composite(band, (dx, hem_y0 - 1))
    return out


def captain_frame(row, col):
    """保卫队队长：银白铠甲 + 金边，深蓝披风（米白里衬、金边），粉红短发低马尾，手按长剑。"""
    img, d = canvas(32, 32)
    swing = (1 if col == 1 else -1) if col in (1, 3) else 0
    hy = 8
    # 披风（身后）
    if row == 3:
        d.polygon([(8, 14), (23, 14), (25, 29), (6, 29)], fill=NAVY)
        d.line((6, 29, 25, 29), fill=GOLD)
        d.line((15, 15, 15, 28), fill=NAVY_D)
    else:
        d.polygon([(8, 14), (23, 14), (24, 28), (7, 28)], fill=NAVY_D)
        d.line((7, 28, 24, 28), fill=GOLD_D)
    _legs(d, row, swing, 24, 29, SILVER_D)
    # 铠甲
    d.rectangle((11, 14, 20, 24), fill=SILVER)
    d.line((11, 18, 20, 18), fill=GOLD)
    d.rectangle((11, 21, 20, 22), fill=LEATHER)
    if row == 0:
        d.point((15, 16), fill=GOLD)
        d.point((16, 16), fill=GOLD)
        d.line((13, 15, 13, 17), fill=SILVER_L)
        # 披风前襟（米白里衬）
        d.line((10, 14, 10, 25), fill=CREAM)
        d.line((21, 14, 21, 25), fill=CREAM)
    # 肩甲
    d.ellipse((8, 13, 13, 17), fill=SILVER)
    d.ellipse((18, 13, 23, 17), fill=SILVER)
    d.point((10, 14), fill=GOLD)
    d.point((21, 14), fill=GOLD)
    # 手臂 + 长剑（剑尖朝下，在身侧）
    if row != 3:
        sx = 24 if row in (0, 2) else 7
        sy = swing if row == 0 else 0           # 正面走路时剑跟着手上下晃
        sx += swing if row in (1, 2) else 0     # 侧面走路时剑前后摆
        d.line((sx, 15 + sy, sx, 29), fill=SILVER_L)
        d.line((sx - 1, 16 + sy, sx + 1, 16 + sy), fill=GOLD)
        d.point((sx, 14 + sy), fill=GOLD_D)
        d.rectangle((sx - 2 if sx > 15 else sx + 1, 16 + sy, sx - 1 if sx > 15 else sx + 2, 20 + sy), fill=SILVER_D)
        # 另一只手（空着）前后摆
        hx = 8 if sx > 15 else 23
        d.rectangle((hx, 19 - swing, hx + 1, 21 - swing), fill=SILVER_D)
    _head(d, row, hy, ROSE, ROSE_D)
    if row != 0:
        tail = 21 if row == 1 else 10
        d.rectangle((tail - 1 if row == 1 else tail, hy + 1, tail if row == 1 else tail + 1, hy + 6), fill=ROSE)
    else:
        d.line((12, hy - 1, 14, hy - 2), fill=ROSE_D)   # 皱着的眉
        d.line((17, hy - 2, 19, hy - 1), fill=ROSE_D)
    return add_outline(_walk_fx(img, col, 25, 29, 24))


def supervisor_frame(row, col):
    """市场监督：深红长外套（金色花纹）、白色荷叶边衬衫、棕色束腰，红棕色长卷发，左手抱厚书、右手拿羽毛笔。"""
    img, d = canvas(32, 32)
    swing = (1 if col == 1 else -1) if col in (1, 3) else 0
    hy = 9
    _legs(d, row, swing, 26, 29, (70, 50, 46, 255))
    # 长外套 + 白裙
    d.polygon([(10, 15), (21, 15), (23, 27), (8, 27)], fill=CRIMSON)
    d.line((8, 27, 23, 27), fill=GOLD_D)
    if row == 0:
        d.polygon([(13, 15), (18, 15), (19, 27), (12, 27)], fill=CREAM)
        d.rectangle((13, 19, 18, 21), fill=LEATHER)
        d.point((15, 16), fill=GOLD)
        d.point((16, 16), fill=GOLD)
        d.line((12, 15, 13, 15), fill=WHITE)
        d.line((18, 15, 19, 15), fill=WHITE)
    elif row in (1, 2):
        fx = 18 if row == 2 else 11
        d.line((fx, 16, fx, 27), fill=CREAM)
        d.rectangle((12, 19, 19, 20), fill=LEATHER)
    else:
        d.line((15, 16, 15, 27), fill=CRIMSON_D)
    # 袖口荷叶边
    d.point((9, 22), fill=WHITE)
    d.point((22, 22), fill=WHITE)
    # 书和羽毛笔
    by = swing if row == 0 else 0
    bx = -swing if row == 1 else 0
    if row in (0, 1):
        d.rectangle((6 + bx, 17 + by, 10 + bx, 22 + by), fill=(110, 66, 40, 255), outline=(70, 40, 26, 255))
        d.line((7 + bx, 19 + by, 9 + bx, 19 + by), fill=GOLD)
    if row in (0, 2):
        qx = swing if row == 2 else 0
        d.line((23 + qx, 11 - by, 21 + qx, 17 - by), fill=CREAM)
        d.point((24 + qx, 10 - by), fill=CREAM)
        d.point((22 + qx, 12 - by), fill=(210, 200, 180, 255))
    if row == 3:
        # 背面：两只袖子前后摆
        d.rectangle((8, 19 + swing, 9, 22 + swing), fill=CRIMSON_D)
        d.rectangle((22, 19 - swing, 23, 22 - swing), fill=CRIMSON_D)
    _head(d, row, hy, AUBURN, AUBURN_D, eye=(120, 70, 40, 255), long_hair=True)
    # 发饰（深蓝丝带）
    d.point((19 if row != 2 else 12, hy - 5), fill=NAVY)
    return add_outline(_walk_fx(img, col, 23, 28, 26))


def host_frame(row, col):
    """篝火派对的主人：桃橙色长发 + 红金花冠，橙红火焰裙（白色荷叶边），举着发光的灯笼杖。"""
    img, d = canvas(32, 32)
    swing = (1 if col == 1 else -1) if col in (1, 3) else 0
    hy = 9
    _legs(d, row, swing, 25, 29, SKIN)
    d.point((12 + (1 if row else 0), 29), fill=FLAME_D)
    d.point((18, 29), fill=FLAME_D)
    # 火焰裙
    d.polygon([(11, 15), (20, 15), (24, 26), (7, 26)], fill=FLAME)
    for x in range(8, 24, 3):
        d.polygon([(x, 26), (x + 2, 26), (x + 1, 23)], fill=FLAME_L)
    d.line((8, 26, 23, 26), fill=WHITE)
    if row != 3:
        d.rectangle((12, 15, 19, 17), fill=FLAME_D)
        d.point((15, 16), fill=FLAME_L)
        d.point((16, 16), fill=FLAME_L)
    # 灯笼杖（右手举高）
    ly = -abs(swing)          # 迈步时灯笼杖跟着一抬一抬
    if row != 1:
        lx = (25 if row != 3 else 6) + (swing if row == 2 else 0)
        d.line((lx, 9 + ly, lx, 24 + ly), fill=GOLD_D)
        d.rectangle((lx - 2, 4 + ly, lx + 2, 9 + ly), fill=GOLD)
        d.rectangle((lx - 1, 5 + ly, lx + 1, 8 + ly), fill=(255, 240, 150, 255))
        d.point((lx + swing, 3 + ly), fill=FLAME_D)     # 火苗往后飘
    else:
        # 朝左：灯笼杖在身后，露出杖尖和灯笼的一角
        d.rectangle((21 - swing, 6, 23 - swing, 10), fill=GOLD)
        d.point((22 - swing, 8), fill=(255, 240, 150, 255))
    # 空着的手前后摆
    if row in (0, 3):
        d.rectangle((8, 18 + swing, 9, 20 + swing), fill=SKIN)
    _head(d, row, hy, PEACH, PEACH_D, eye=(200, 70, 50, 255), long_hair=True)
    # 花冠
    for i, x in enumerate(range(11, 21, 2)):
        d.point((x, hy - 6), fill=(230, 50, 60, 255) if i % 2 == 0 else GOLD)
    return add_outline(_walk_fx(img, col, 22, 27, 25))


KEY_NPCS = {"captain": captain_frame, "supervisor": supervisor_frame, "bonfire_host": host_frame}


def key_npc_sheet(nid):
    sheet = blank(32 * 4, 32 * 4)
    for row in range(4):
        for col in range(4):
            sheet.alpha_composite(KEY_NPCS[nid](row, col), (col * 32, row * 32))
    return sheet


def npc_sheet(look):
    sheet = blank(32 * 4, 32 * 4)
    for row in range(4):
        for col in range(4):
            sheet.alpha_composite(npc_frame(look, row, col), (col * 32, row * 32))
    return sheet


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


# ------------------------------------------------------------------ 蓝色小屋（第六层后续剧情）：外观 + 室内家具
BLUE = (110, 150, 220, 255)
BLUE_D = (60, 90, 160, 255)
BLUE_L = (190, 215, 250, 255)
CLOTH = (255, 200, 225, 255)
CLOTH_D = (220, 140, 185, 255)
LEAF = (90, 160, 100, 255)
LEAF_D = (55, 110, 70, 255)
GLASS = (120, 150, 210, 255)


def p_house_blue():
    """蓝色小屋：蓝屋顶两层小楼，二楼有小阳台窗，门边挂一盏灯笼。"""
    img, d = canvas(48, 48)
    d.rectangle((5, 14, 42, 46), fill=(225, 232, 245, 255))
    d.line((5, 46, 42, 46), fill=STONE_D)
    d.line((5, 30, 42, 30), fill=(190, 200, 225, 255))
    d.polygon([(1, 16), (24, 1), (46, 16)], fill=BLUE)
    for y in range(5, 16, 3):
        d.line((24 - (y - 1) * 23 // 15, y, 24 + (y - 1) * 23 // 15, y), fill=BLUE_D)
    # 二楼窗户 + 小阳台
    d.rectangle((18, 18, 29, 26), fill=(255, 225, 150, 255))
    d.line((23, 18, 23, 26), fill=WOOD_D)
    d.rectangle((16, 27, 31, 28), fill=WOOD_D)
    for x in range(17, 31, 3):
        d.line((x, 25, x, 27), fill=WOOD_D)
    # 一楼窗户和门
    for wx in (8, 34):
        d.rectangle((wx, 33, wx + 5, 39), fill=(255, 225, 150, 255))
        d.line((wx, 36, wx + 5, 36), fill=WOOD_D)
    d.rectangle((19, 34, 28, 46), fill=BLUE_D)
    d.rectangle((20, 35, 27, 46), fill=BLUE)
    d.point((26, 40), fill=GOLD)
    # 灯笼
    d.line((31, 32, 31, 35), fill=WOOD_D)
    d.rectangle((30, 35, 32, 38), fill=(255, 200, 110, 255))
    return add_outline(img)


def p_interior(kind):
    if kind == "wood_floor":
        img, d = canvas(16, 16)
        d.rectangle((0, 0, 15, 15), fill=(176, 120, 82, 255))
        for y in (3, 7, 11, 15):
            d.line((0, y, 15, y), fill=(140, 92, 62, 255))
        for x, y in ((5, 0), (12, 4), (3, 8), (10, 12)):
            d.line((x, y, x, y + 3), fill=(140, 92, 62, 255))
        d.point((8, 2), fill=(196, 140, 98, 255))
        return img
    if kind == "rug":
        img, d = canvas(48, 32)
        d.rounded_rectangle((0, 0, 47, 31), 6, fill=CLOTH_D)
        d.rounded_rectangle((3, 3, 44, 28), 4, fill=CLOTH)
        d.ellipse((16, 8, 31, 23), outline=CLOTH_D, width=2)
        d.ellipse((21, 13, 26, 18), fill=(255, 235, 245, 255))
        for x in range(4, 46, 4):
            d.point((x, 0), fill=GOLD)
            d.point((x, 31), fill=GOLD)
        return img
    if kind in ("princess_bed", "blue_bed"):
        cloth, cloth_d = (CLOTH, CLOTH_D) if kind == "princess_bed" else (BLUE_L, BLUE)
        img, d = canvas(32, 32)
        d.rectangle((2, 2, 3, 31), fill=WOOD_D)
        d.rectangle((28, 2, 29, 31), fill=WOOD_D)
        d.polygon([(1, 2), (30, 2), (27, 9), (4, 9)], fill=cloth_d)       # 帷幔顶
        d.rectangle((4, 9, 6, 22), fill=cloth)                              # 两边垂下的帷幔
        d.rectangle((25, 9, 27, 22), fill=cloth)
        d.rectangle((5, 12, 26, 15), fill=(255, 255, 255, 255))            # 枕头
        d.rectangle((4, 16, 27, 29), fill=cloth)                            # 被子
        d.line((4, 20, 27, 20), fill=cloth_d)
        d.rectangle((3, 28, 28, 31), fill=WOOD)
        return add_outline(img)
    if kind == "wardrobe":
        img, d = canvas(16, 32)
        d.rectangle((1, 2, 14, 31), fill=WOOD)
        d.rectangle((1, 2, 14, 4), fill=WOOD_D)
        d.line((7, 5, 7, 30), fill=WOOD_D)
        d.point((6, 17), fill=GOLD)
        d.point((9, 17), fill=GOLD)
        d.rectangle((3, 7, 5, 12), fill=WOOD_L)
        d.rectangle((10, 7, 12, 12), fill=WOOD_L)
        return add_outline(img)
    if kind == "dresser":
        img, d = canvas(32, 32)
        d.ellipse((9, 1, 22, 16), fill=GOLD_D)
        d.ellipse((11, 3, 20, 14), fill=(200, 225, 245, 255))             # 镜子
        d.line((13, 5, 15, 8), fill=(255, 255, 255, 255))
        d.rectangle((3, 16, 28, 29), fill=(250, 240, 245, 255))
        d.rectangle((3, 16, 28, 17), fill=CLOTH_D)
        for y in (21, 25):
            d.line((5, y, 26, y), fill=(220, 200, 210, 255))
            d.point((15, y + 2), fill=GOLD)
        d.rectangle((6, 13, 8, 16), fill=PINK)                              # 小香水瓶
        d.rectangle((23, 14, 25, 16), fill=CRYSTAL)
        d.line((4, 30, 4, 31), fill=WOOD_D)
        d.line((27, 30, 27, 31), fill=WOOD_D)
        return add_outline(img)
    if kind == "bookshelf":
        img, d = canvas(32, 32)
        d.rectangle((1, 1, 30, 31), fill=WOOD_D)
        d.rectangle((3, 3, 28, 29), fill=(90, 58, 40, 255))
        cols = [(200, 80, 90), (90, 130, 190), (110, 160, 100), (220, 180, 80), (170, 110, 190), (240, 240, 230)]
        for row, y in enumerate((4, 13, 22)):
            d.line((3, y + 8, 28, y + 8), fill=WOOD)
            x = 4
            i = row
            while x < 27:
                w = 2 + (i * 7) % 3
                d.rectangle((x, y + 1 + (i % 2), x + w - 1, y + 7), fill=cols[i % len(cols)] + (255,))
                x += w + 1
                i += 1
        return add_outline(img)
    if kind == "tea_table":
        img, d = canvas(16, 16)
        d.ellipse((1, 3, 14, 10), fill=(250, 245, 240, 255))
        d.ellipse((1, 3, 14, 10), outline=(210, 190, 190, 255))
        d.line((7, 10, 7, 15), fill=WOOD_D)
        d.line((4, 15, 11, 15), fill=WOOD_D)
        d.rectangle((4, 4, 6, 6), fill=PINK)                                # 茶杯
        d.rectangle((9, 3, 11, 6), fill=(255, 255, 255, 255))               # 茶壶
        d.point((12, 4), fill=(255, 255, 255, 255))
        return add_outline(img)
    if kind == "chair":
        img, d = canvas(16, 16)
        d.rectangle((4, 1, 11, 7), fill=WOOD)
        d.rectangle((5, 2, 10, 6), fill=CLOTH)
        d.rectangle((3, 8, 12, 10), fill=CLOTH_D)
        for x in (4, 11):
            d.line((x, 10, x, 15), fill=WOOD_D)
        return add_outline(img)
    if kind == "window":
        img, d = canvas(32, 24)
        d.rectangle((2, 0, 29, 21), fill=WOOD_D)
        d.rectangle((4, 2, 27, 19), fill=(40, 50, 100, 255))
        for x, y in ((8, 5), (20, 4), (14, 9), (24, 12)):
            d.point((x, y), fill=(255, 250, 200, 255))
        d.ellipse((17, 6, 22, 11), fill=(250, 240, 190, 255))               # 月亮
        d.line((15, 2, 15, 19), fill=WOOD_D)
        d.line((4, 10, 27, 10), fill=WOOD_D)
        d.polygon([(0, 0), (6, 0), (4, 22), (0, 23)], fill=CLOTH)           # 窗帘
        d.polygon([(31, 0), (25, 0), (27, 22), (31, 23)], fill=CLOTH)
        return add_outline(img)
    if kind == "painting":
        img, d = canvas(16, 16)
        d.rectangle((1, 1, 14, 13), fill=GOLD_D)
        d.rectangle((3, 3, 12, 11), fill=(170, 210, 240, 255))
        d.polygon([(3, 11), (7, 6), (10, 9), (12, 7), (12, 11)], fill=LEAF)
        d.ellipse((9, 4, 11, 6), fill=(255, 230, 120, 255))
        return add_outline(img)
    if kind == "plant":
        img, d = canvas(16, 24)
        d.polygon([(4, 16), (11, 16), (10, 23), (5, 23)], fill=(200, 120, 90, 255))
        for (x0, y0, x1, y1) in ((7, 16, 2, 6), (8, 16, 13, 4), (7, 16, 7, 1), (8, 16, 11, 9), (7, 16, 4, 10)):
            d.line((x0, y0, x1, y1), fill=LEAF_D)
            d.ellipse((x1 - 2, y1 - 2, x1 + 2, y1 + 2), fill=LEAF)
        return add_outline(img)
    if kind == "candle":
        img, d = canvas(16, 16)
        d.rectangle((5, 12, 10, 15), fill=GOLD_D)
        d.rectangle((7, 6, 8, 12), fill=(250, 245, 230, 255))
        d.ellipse((6, 2, 9, 6), fill=(255, 200, 90, 255))
        d.point((7, 3), fill=(255, 250, 220, 255))
        return add_outline(img)
    if kind == "desk":
        img, d = canvas(32, 24)
        d.rectangle((1, 8, 30, 12), fill=WOOD)
        d.line((1, 8, 30, 8), fill=WOOD_L)
        for x in (3, 28):
            d.line((x, 12, x, 23), fill=WOOD_D)
        d.rectangle((8, 5, 15, 8), fill=PAPER)                              # 纸条
        d.line((9, 6, 14, 6), fill=(150, 140, 150, 255))
        d.rectangle((20, 3, 23, 8), fill=BLUE)                              # 墨水瓶
        d.line((24, 1, 22, 6), fill=(255, 255, 255, 255))                    # 羽毛笔
        return add_outline(img)
    if kind in OLD_ROOM:
        return p_old_room(kind)
    # hotspot：看不见的调查点（和陷阱 / 别的东西放在同一格，让它也能按 E 调查）
    img, d = canvas(16, 16)
    return img


# —— 第八层的小房间：很久没人住的、小女孩的房间（落灰、蛛网、褪色）——
OLD_ROOM = ("old_bed", "old_dresser", "old_tea", "music_box", "crayon_drawing", "height_marks", "cobweb")
DUST = (150, 140, 150, 255)
DUST_L = (200, 192, 196, 255)


def _dusty(img, k=0.45, seed=3):
    """褪色 + 积灰：往灰色混一点，再撒些灰点。"""
    import random
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            gray = (r + g + b) // 3
            px[x, y] = (int(r + (gray - r) * k), int(g + (gray - g) * k), int(b + (gray - b) * k), a)
            if rnd.random() < 0.05:
                px[x, y] = DUST_L[:3] + (a,)
    return img


def p_old_room(kind):
    if kind == "old_bed":
        img = _dusty(p_interior("blue_bed").copy(), 0.5)
        d = ImageDraw.Draw(img)
        # 床角的蛛网
        for i in range(4):
            d.line((26 - i * 2, 2, 30, 2 + i * 2), fill=DUST_L)
        d.line((26, 2, 30, 8), fill=DUST_L)
        return img
    if kind == "old_dresser":
        img = _dusty(p_interior("dresser").copy(), 0.5, 5)
        d = ImageDraw.Draw(img)
        d.line((12, 5, 18, 12), fill=(90, 100, 120, 255))                  # 镜子的裂纹
        d.line((15, 8, 19, 6), fill=(90, 100, 120, 255))
        # 雪花发夹
        cx, cy = 15, 14
        for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0), (-1, -1), (1, 1), (-1, 1), (1, -1)):
            d.point((cx + dx, cy + dy), fill=CRYSTAL)
        d.point((cx, cy), fill=CRYSTAL_L)
        return img
    if kind == "old_tea":
        img, d = canvas(16, 16)
        d.ellipse((1, 3, 14, 10), fill=(225, 220, 215, 255))
        d.line((7, 10, 7, 15), fill=WOOD_D)
        d.line((4, 15, 11, 15), fill=WOOD_D)
        d.rectangle((3, 4, 5, 6), fill=(150, 175, 205, 255))                # 两只小茶杯（蓝 / 白）
        d.rectangle((10, 4, 12, 6), fill=(235, 235, 240, 255))
        d.point((7, 5), fill=DUST)
        d.point((9, 7), fill=DUST)
        return _dusty(add_outline(img), 0.35, 7)
    if kind == "music_box":
        img, d = canvas(16, 16)
        d.rectangle((2, 7, 13, 14), fill=(110, 140, 200, 255))              # 蓝色的盒子
        d.rectangle((2, 7, 13, 8), fill=GOLD_D)
        d.rectangle((2, 13, 13, 14), fill=GOLD_D)
        d.point((7, 11), fill=GOLD)
        d.line((14, 10, 15, 10), fill=GOLD_D)                                # 发条把手
        d.line((15, 9, 15, 11), fill=GOLD_D)
        d.line((7, 3, 7, 6), fill=GOLD_D)                                    # 盒盖上转圈的小人
        d.ellipse((6, 1, 8, 3), fill=(235, 240, 255, 255))
        d.polygon([(5, 6), (9, 6), (7, 4)], fill=CRYSTAL)
        return _dusty(add_outline(img), 0.3, 9)
    if kind == "crayon_drawing":
        img, d = canvas(16, 16)
        d.rectangle((1, 1, 14, 13), fill=(235, 228, 210, 255))              # 发黄的纸
        d.point((1, 1), fill=(0, 0, 0, 0))
        d.point((14, 13), fill=(0, 0, 0, 0))
        d.ellipse((10, 2, 12, 4), fill=(240, 200, 90, 255))                 # 太阳
        d.ellipse((3, 5, 5, 7), fill=(240, 220, 200, 255))                  # 小女孩的头
        d.line((3, 5, 2, 9), fill=(110, 150, 230, 255))                      # 蓝头发
        d.line((5, 5, 6, 9), fill=(110, 150, 230, 255))
        d.polygon([(3, 8), (5, 8), (6, 11), (2, 11)], fill=(120, 160, 230, 255))
        for hx, hy in ((8, 7), (10, 6), (12, 7), (9, 10), (12, 10)):         # 好多只紫色的手
            d.line((hx, hy, hx, hy + 2), fill=(170, 120, 200, 255))
            d.point((hx - 1, hy), fill=(170, 120, 200, 255))
            d.point((hx + 1, hy), fill=(170, 120, 200, 255))
        d.point((4, 6), fill=(200, 80, 90, 255))                             # 笑着的嘴
        return _dusty(add_outline(img), 0.35, 11)
    if kind == "height_marks":
        img, d = canvas(16, 24)
        d.rectangle((6, 0, 9, 23), fill=WOOD)                                # 门框的一段
        d.line((6, 0, 6, 23), fill=WOOD_D)
        for i, y in enumerate((20, 17, 15, 12)):                             # 一道道刻痕，刻到小孩的高度就停了
            d.line((7, y, 10 + (i % 2), y), fill=(90, 50, 35, 255))
        d.point((11, 12), fill=(90, 50, 35, 255))
        return add_outline(img)
    if kind == "cobweb":
        img, d = canvas(16, 16)
        for i in range(0, 15, 3):
            d.line((0, i, 15 - i, 0), fill=(220, 215, 225, 170))
        d.line((0, 0, 15, 15), fill=(220, 215, 225, 140))
        d.line((0, 0, 7, 15), fill=(220, 215, 225, 140))
        d.line((0, 0, 15, 7), fill=(220, 215, 225, 140))
        return img
    img, d = canvas(16, 16)
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
    # 蓝色小屋（外观 + 室内家具）——加在最后，前面道具的图集位置不变
    items.append(("house_blue", p_house_blue(), {"body": [40, 16], "body_y": -8}))
    items.append(("wood_floor", p_interior("wood_floor"), {"floor": True, "under": True}))
    items.append(("rug", p_interior("rug"), {"floor": True}))
    items.append(("princess_bed", p_interior("princess_bed"), {"body": [28, 12], "body_y": -6}))
    items.append(("blue_bed", p_interior("blue_bed"), {"body": [28, 12], "body_y": -6}))
    items.append(("wardrobe", p_interior("wardrobe"), {"body": [14, 8], "body_y": -4}))
    items.append(("dresser", p_interior("dresser"), {"body": [26, 8], "body_y": -4}))
    items.append(("bookshelf", p_interior("bookshelf"), {"body": [30, 8], "body_y": -4}))
    items.append(("tea_table", p_interior("tea_table"), {"body": [12, 6], "body_y": -3}))
    items.append(("chair", p_interior("chair"), {}))
    items.append(("window", p_interior("window"), {"lift": 10}))
    items.append(("painting", p_interior("painting"), {"lift": 12}))
    items.append(("plant", p_interior("plant"), {"body": [10, 6], "body_y": -3}))
    items.append(("candle", p_interior("candle"), {"light": [1.0, 0.8, 0.5]}))
    items.append(("desk", p_interior("desk"), {"body": [28, 8], "body_y": -4}))
    items.append(("hotspot", p_interior("hotspot"), {}))
    # 第八层的小房间（加在最后，前面道具的图集位置不变）
    items.append(("old_bed", p_interior("old_bed"), {"body": [28, 12], "body_y": -6}))
    items.append(("old_dresser", p_interior("old_dresser"), {"body": [26, 8], "body_y": -4}))
    items.append(("old_tea", p_interior("old_tea"), {"body": [12, 6], "body_y": -3}))
    items.append(("music_box", p_interior("music_box"), {}))
    items.append(("crayon_drawing", p_interior("crayon_drawing"), {"lift": 12}))
    items.append(("height_marks", p_interior("height_marks"), {"lift": 8}))
    items.append(("cobweb", p_interior("cobweb"), {"lift": 12}))
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
    """普通居民用程序外观；三个关键人物按立绘单独画（立绘由 import_portraits_v2.py 从用户的插画生成）。"""
    (OUT / "npcs").mkdir(exist_ok=True)
    for nid, look in LOOKS.items():
        sheet = key_npc_sheet(nid) if nid in KEY_NPCS else npc_sheet(look)
        sheet.save(OUT / "npcs" / (nid + ".png"))


def main():
    gen_markers()
    gen_npcs()
    gen_props()
    print("检查点 / 存档点 / 居民 / 小镇道具像素图已生成")


if __name__ == "__main__":
    main()
