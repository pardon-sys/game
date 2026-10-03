"""新部位（肚子 / 屁股 / 胸）这一批的像素图。

输出到 assets/generated/：
  zone_fx.png   16x16 × 6 帧 × 8 行   部位专属挠痒特效（行 = ZONE_FX 的顺序，部位表 princess_ticklish.json 的 fx 字段指过来）
  supine.png 16x16×2 仰卧刑床（空着 / 皮带扣上）     cushion.png 16x16×2 痒痒坐垫（鼓着 / 压扁扣住）
  prone.png 16x16×2 俯卧刑凳（空着 / 皮带扣上）      pit.png 16x16 × 2 帧 × 4 行 落穴洞（行 = 挠脚鼠 / 刷尾松鼠 / 史莱姆 / 小触手；帧 = 洞里偷看 / 伸出来）
  spinwheel.png 32x32×2 张臂转盘（空着 / 扣着转）   vest.png 16x16×2 羽毛背心（叠着 / 羽毛抖动）
  chute.png 16x16×2 痒痒滑梯（刷毛两帧交替）       duster.png 16x16×3 掸子墙（墙上的槽 / 亮灯 / 鸡毛掸子头）
  frog.png 16x16×4 长舌蛙（蹲 / 跳 / 鼓嘴 / 张嘴）   squirrel.png 16x16×4 刷尾松鼠（跑 2 帧 / 甩尾刷 / 跳开）
  octopus.png 16x16×3 吸盘章鱼宝宝（游 2 帧 / 吸住） caterpillar.png 16x16×2 毛毛虫（爬 2 帧）
  barnacle.png 16x16×3 藤壶贝（合着 / 张开伸纤毛 2 帧）
  训练营的脚 / 大腿 / 屁股陷阱（16x16，帧 0 平时 / 1 困住 / 2 合上）：thigh_pincer、foot_thigh_rack、feather_swing、thigh_brush_ring、
  foot_bath、sitz_bath、spring_seat、saddle_bench、scissor_stand

用法：python tools/art/gen_zone_art.py
"""
import math

from gen_expansion import _strip, blank, canvas
from palette import OUT, add_outline

WHITE = (250, 250, 255, 255)
PINK = (255, 150, 205, 255)
PINK_D = (214, 86, 160, 255)
PINK_L = (255, 214, 236, 255)
GOLD = (255, 214, 72, 255)
GOLD_D = (214, 150, 36, 255)
DARK = (34, 22, 36, 255)
WOOD = (189, 108, 74, 255)
WOOD_D = (120, 64, 48, 255)
WOOD_L = (222, 150, 102, 255)
STONE = (139, 155, 180, 255)
STONE_D = (82, 96, 124, 255)
STONE_L = (192, 203, 220, 255)
STEEL = (200, 212, 228, 255)
STEEL_D = (120, 134, 160, 255)
BRASS = (230, 180, 70, 255)
BRASS_D = (170, 120, 40, 255)
LEATHER = (110, 60, 70, 255)
FEATHER = (250, 248, 255, 255)
BRISTLE = (240, 200, 120, 255)
SLIME = (110, 214, 120, 255)
SLIME_L = (190, 250, 190, 255)
TENT = (230, 120, 190, 255)
TENT_D = (170, 70, 140, 255)
RAT = (170, 160, 175, 255)
FUR = (214, 130, 70, 255)
FUR_D = (150, 80, 40, 255)
FUR_L = (250, 200, 150, 255)
FROG = (120, 196, 96, 255)
FROG_D = (66, 138, 70, 255)
FROG_L = (226, 236, 196, 255)
BLUSH = (255, 160, 170, 255)
OCTO = (190, 130, 230, 255)
OCTO_D = (130, 80, 180, 255)
OCTO_L = (225, 190, 250, 255)
CAT = (140, 210, 110, 255)
CAT_D = (80, 150, 70, 255)
CAT_L = (200, 240, 170, 255)
SHELL = (230, 220, 200, 255)
SHELL_D = (170, 150, 130, 255)
CILIA = (255, 180, 220, 255)


def _a(c, f, n=6):
    """第 f 帧的淡出颜色。"""
    return c[:3] + (max(50, int(c[3] * (1.0 - f / (n + 1)))),)


# ------------------------------------------------------------------ 部位专属特效
def fx_sole(f):
    """脚心：三颗脚趾一蜷一蜷 + 小星星往上冒。"""
    img, d = canvas()
    curl = (0, 1, 2, 1, 0, 1)[f]
    for i, x in enumerate((4, 7, 10)):
        y = 9 + curl + (1 if i == 1 else 0)
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=_a(PINK_L, f))
    sy = 7 - f
    d.point((12, sy), fill=_a(GOLD, f))
    d.point((11, sy + 1), fill=_a(GOLD, f))
    d.point((13, sy + 1), fill=_a(GOLD, f))
    d.point((12, sy + 2), fill=_a(GOLD, f))
    return img


def fx_armpit(f):
    """腋下：一圈螺旋，越转越开。"""
    img, d = canvas()
    for i in range(18):
        t = i / 17
        r = 1 + t * (3 + f)
        a = t * 3.5 * math.pi + f * 0.9
        d.point((7.5 + math.cos(a) * r, 7.5 + math.sin(a) * r), fill=_a(PINK if t > 0.5 else PINK_L, f))
    return img


def fx_waist(f):
    """腰：两侧扭动的波浪线。"""
    img, d = canvas()
    for side in (2, 13):
        pts = [(side + math.sin(y * 0.9 + f * 1.4) * 1.5, y) for y in range(3, 13)]
        d.line(pts, fill=_a(PINK_L, f))
    return img


def fx_neck(f):
    """脖子：发抖的小折线 + 鸡皮疙瘩小点。"""
    img, d = canvas()
    k = 1 if f % 2 else -1
    d.line([(3, 4), (4 + k, 6), (3, 8), (4 + k, 10)], fill=_a(WHITE, f))
    d.line([(12, 4), (11 - k, 6), (12, 8), (11 - k, 10)], fill=_a(WHITE, f))
    for i, (x, y) in enumerate(((7, 5), (9, 8), (6, 10), (8, 12))):
        if (i + f) % 3 != 0:
            d.point((x, y), fill=_a(PINK_L, f))
    return img


def fx_thigh(f):
    """大腿：左右晃动的弧线。"""
    img, d = canvas()
    off = (0, 1, 2, 1, 0, -1)[f]
    d.arc((1 + off, 3, 7 + off, 13), 100, 260, fill=_a(PINK_L, f))
    d.arc((8 + off, 3, 14 + off, 13), -80, 80, fill=_a(PINK_L, f))
    return img


def fx_belly(f):
    """肚子：从肚脐一圈圈扩开的波纹。"""
    img, d = canvas()
    d.point((7, 8), fill=_a(PINK_D, f))
    for k in range(2):
        r = 1 + f * 1.1 + k * 2.5
        if r < 8:
            d.ellipse((7.5 - r, 8 - r * 0.7, 7.5 + r, 8 + r * 0.7), outline=_a(PINK_L if k else PINK, f))
    return img


def fx_butt(f):
    """屁股：两颗一弹一弹的小星星。"""
    img, d = canvas()
    for i, x in enumerate((4, 11)):
        h = abs(math.sin((f + i * 2) * 0.9)) * 5
        y = 11 - int(h)
        c = _a(GOLD if i == 0 else PINK_L, f)
        d.point((x, y), fill=c)
        d.point((x - 1, y + 1), fill=c)
        d.point((x + 1, y + 1), fill=c)
        d.point((x, y + 2), fill=c)
    d.line((3, 14, 12, 14), fill=_a(PINK, f))
    return img


def fx_chest(f):
    """胸：被戳的小凹痕（一圈收缩）+ 往上飘的小音符。"""
    img, d = canvas()
    r = max(1, 4 - f)
    d.ellipse((4 - r, 10 - r, 4 + r, 10 + r), outline=_a(PINK_L, f))
    nx, ny = 10, 9 - f
    d.line((nx + 1, ny - 4, nx + 1, ny), fill=_a(WHITE, f))
    d.ellipse((nx - 1, ny - 1, nx + 1, ny + 1), fill=_a(WHITE, f))
    d.line((nx + 1, ny - 4, nx + 3, ny - 3), fill=_a(WHITE, f))
    return img


ZONE_FX = [fx_sole, fx_armpit, fx_waist, fx_neck, fx_thigh, fx_belly, fx_butt, fx_chest]


def gen_zone_fx():
    sheet = blank(16 * 6, 16 * len(ZONE_FX))
    for row, fn in enumerate(ZONE_FX):
        for f in range(6):
            sheet.alpha_composite(fn(f), (f * 16, row * 16))
    sheet.save(OUT / "zone_fx.png")


# ------------------------------------------------------------------ 陷阱
def supine(frame):
    """仰卧刑床：带粉垫的木台，两条皮带（扣上时横过台面），床头一根羽毛。"""
    img, d = canvas()
    d.rectangle((1, 5, 14, 13), fill=WOOD_D)
    d.rectangle((2, 5, 13, 12), fill=WOOD)
    d.rectangle((3, 6, 12, 11), fill=PINK_L)
    d.line((1, 14, 1, 15), fill=WOOD_D)
    d.line((14, 14, 14, 15), fill=WOOD_D)
    if frame:
        for x in (5, 10):
            d.rectangle((x, 4, x + 1, 13), fill=LEATHER)
            d.point((x, 8), fill=BRASS)
    else:
        for x in (5, 10):
            d.line((x, 4, x, 5), fill=LEATHER)
            d.line((x, 12, x, 13), fill=LEATHER)
    d.polygon([(14, 4), (12, 1), (13, 0), (15, 3)], fill=FEATHER)
    return add_outline(img)


def cushion(frame):
    """痒痒坐垫：鼓鼓的粉色软垫，边上一圈刷毛；扣住时压扁、两边弹出扣环。"""
    img, d = canvas()
    top = 6 if frame == 0 else 8
    d.ellipse((1, top, 14, 14), fill=PINK_D)
    d.ellipse((1, top - 1, 14, 12), fill=PINK)
    d.line((4, top + 1, 8, top + 1), fill=PINK_L)
    for x in range(2, 14, 2):
        d.point((x, 14), fill=BRISTLE)
    if frame:
        d.arc((0, 6, 4, 12), 90, 270, fill=STEEL)
        d.arc((11, 6, 15, 12), -90, 90, fill=STEEL)
    return add_outline(img)


def prone(frame):
    """俯卧刑凳：长条木凳 + 一个小枕头；扣上时两条皮带。"""
    img, d = canvas()
    d.rectangle((0, 6, 15, 10), fill=WOOD_D)
    d.rectangle((0, 6, 15, 9), fill=WOOD)
    d.line((0, 6, 15, 6), fill=WOOD_L)
    for x in (1, 14):
        d.line((x, 11, x, 15), fill=WOOD_D)
    d.ellipse((1, 4, 5, 8), fill=PINK_L)
    if frame:
        for x in (7, 11):
            d.rectangle((x, 5, x + 1, 10), fill=LEATHER)
            d.point((x, 7), fill=BRASS)
    return add_outline(img)


PIT_CONTENT = ["rat", "squirrel", "slime", "tentacle"]


def pit(row, frame):
    """落穴洞：石圈里的黑洞；第 0 帧洞里偷看（眼睛），第 1 帧伸出尾巴 / 史莱姆 / 小触手。"""
    img, d = canvas()
    d.ellipse((0, 4, 15, 15), fill=STONE_D)
    d.ellipse((1, 4, 14, 13), fill=STONE)
    d.point((3, 6), fill=STONE_L)
    d.ellipse((3, 7, 12, 13), fill=DARK)
    kind = PIT_CONTENT[row]
    eye = {"rat": (255, 120, 150, 255), "squirrel": GOLD, "slime": SLIME_L, "tentacle": TENT}[kind]
    if frame == 0:
        d.point((6, 10), fill=eye)
        d.point((9, 10), fill=eye)
        return img
    if kind == "rat":
        d.line((7, 11, 9, 4), fill=RAT)
        d.line((9, 4, 11, 2), fill=RAT)
        d.point((5, 11), fill=RAT)
        d.point((4, 10), fill=RAT)
    elif kind == "squirrel":
        d.ellipse((6, 2, 12, 11), fill=FUR)
        d.ellipse((7, 3, 10, 7), fill=FUR_L)
    elif kind == "slime":
        d.ellipse((4, 6, 11, 12), fill=SLIME)
        d.point((6, 8), fill=SLIME_L)
    else:
        d.line((6, 11, 5, 5), fill=TENT, width=2)
        d.line((10, 11, 11, 4), fill=TENT, width=2)
        d.point((5, 4), fill=PINK_L)
        d.point((11, 3), fill=PINK_L)
    return add_outline(img)


def spinwheel(frame):
    """张臂转盘：竖着的黄铜大轮，上面两只铐环；扣着时轮辐错开（转动）、旁边伸出刷子。"""
    img, d = canvas(32, 32)
    d.rectangle((14, 24, 17, 31), fill=STEEL_D)
    d.ellipse((2, 2, 29, 29), fill=BRASS_D)
    d.ellipse((4, 4, 27, 27), fill=BRASS)
    d.ellipse((7, 7, 24, 24), fill=PINK_L)
    a0 = 0.4 if frame else 0.0
    for k in range(6):
        a = a0 + k * math.pi / 3
        d.line((16 + math.cos(a) * 3, 16 + math.sin(a) * 3, 16 + math.cos(a) * 11, 16 + math.sin(a) * 11), fill=BRASS_D)
    d.ellipse((13, 13, 18, 18), fill=BRASS_D)
    for x in (5, 23):
        d.ellipse((x, 6, x + 3, 9), outline=STEEL)
    if frame:
        d.rectangle((27, 12, 31, 14), fill=WOOD)
        for y in (10, 12, 14, 16):
            d.point((26, y), fill=BRISTLE)
    return add_outline(img)


def vest(frame):
    """羽毛背心：粉色小背心，下摆一圈羽毛；第 1 帧羽毛抖起来。"""
    img, d = canvas()
    d.polygon([(3, 3), (6, 3), (8, 6), (10, 3), (13, 3), (13, 12), (3, 12)], fill=PINK)
    d.line((8, 6, 8, 12), fill=PINK_D)
    d.point((7, 8), fill=GOLD)
    d.point((7, 10), fill=GOLD)
    for i, x in enumerate(range(3, 14, 2)):
        dy = (1 if (i + frame) % 2 else 0)
        d.line((x, 12, x - 1 + dy, 14 + dy), fill=FEATHER)
    return add_outline(img)


def chute(frame):
    """痒痒滑梯的一格：浅色滑板，两边一排刷毛（两帧交替；方向箭头在游戏里画）。"""
    img, d = canvas()
    d.rectangle((0, 0, 15, 15), fill=(232, 190, 150, 255))
    d.rectangle((0, 0, 15, 1), fill=WOOD_L)
    d.rectangle((0, 14, 15, 15), fill=WOOD_D)
    for x in range(0, 16, 3):
        d.line((x + frame, 2, x + frame, 3), fill=BRISTLE)
        d.line((x + 1 - frame, 12, x + 1 - frame, 13), fill=BRISTLE)
    d.line((2, 7, 13, 7), fill=(250, 220, 190, 255))
    return img


def duster(frame):
    """掸子墙：0 墙上的槽，1 槽上亮红灯，2 鸡毛掸子头（朝右画，游戏里按方向旋转）。"""
    img, d = canvas()
    if frame < 2:
        d.rectangle((3, 5, 12, 10), fill=STONE_D)
        d.rectangle((4, 6, 11, 9), fill=DARK)
        d.point((7, 4), fill=(255, 80, 90, 255) if frame else STONE_L)
        d.point((8, 4), fill=(255, 80, 90, 255) if frame else STONE_L)
        return img
    d.line((0, 8, 6, 8), fill=WOOD)
    d.ellipse((5, 3, 15, 13), fill=PINK)
    for a in range(0, 360, 45):
        x, y = 10 + math.cos(math.radians(a)) * 5, 8 + math.sin(math.radians(a)) * 5
        d.point((x, y), fill=FEATHER)
    d.ellipse((8, 6, 11, 9), fill=PINK_L)
    return add_outline(img)


# ------------------------------------------------------------------ 怪物
def frog(frame):
    """长舌蛙：绿色的小青蛙，脸颊红红的（和 CG 图一致）。0 蹲 / 1 跳（拉长）/ 2 鼓嘴（预警）/ 3 张嘴（吐舌）。"""
    img, d = canvas()
    y = -2 if frame == 1 else 0
    d.ellipse((2, 7 + y, 13, 15 + y), fill=FROG_D)
    d.ellipse((2, 6 + y, 13, 14 + y), fill=FROG)
    d.ellipse((3, 4 + y, 7, 8 + y), fill=FROG)
    d.ellipse((8, 4 + y, 12, 8 + y), fill=FROG)
    d.point((5, 6 + y), fill=DARK)
    d.point((10, 6 + y), fill=DARK)
    d.point((3, 10 + y), fill=BLUSH)
    d.point((12, 10 + y), fill=BLUSH)
    if frame == 2:
        d.ellipse((5, 10, 10, 15), fill=FROG_L)
    elif frame == 3:
        d.rectangle((5, 10, 10, 12), fill=DARK)
        d.rectangle((6, 11, 9, 12), fill=(255, 100, 140, 255))
    else:
        d.line((5, 11 + y, 10, 11 + y), fill=FROG_D)
    if frame == 1:
        d.line((2, 14, 0, 15), fill=FROG_D)
        d.line((13, 14, 15, 15), fill=FROG_D)
    return add_outline(img)


def squirrel(frame):
    """刷尾松鼠：橘色小松鼠 + 比身体还大的蓬松尾巴。0/1 跑，2 甩尾刷（尾巴扫到前面），3 跳开。"""
    img, d = canvas()
    y = -2 if frame == 3 else (0 if frame != 1 else -1)
    if frame == 2:
        d.ellipse((7, 3, 15, 12), fill=FUR_D)
        d.ellipse((8, 4, 14, 10), fill=FUR_L)
    else:
        d.ellipse((0, 1 + y, 8, 12 + y), fill=FUR_D)
        d.ellipse((1, 2 + y, 7, 10 + y), fill=FUR_L)
    d.ellipse((5, 7 + y, 12, 14 + y), fill=FUR)
    d.ellipse((8, 4 + y, 13, 9 + y), fill=FUR)
    d.point((9, 4 + y), fill=FUR_D)
    d.point((11, 6 + y), fill=DARK)
    d.point((13, 7 + y), fill=PINK)
    step = frame % 2
    d.line((6, 14 + y, 6 - step, 15), fill=FUR_D)
    d.line((10, 14 + y, 10 + step, 15), fill=FUR_D)
    return add_outline(img)


def octopus(frame):
    """吸盘章鱼宝宝：紫色圆脑袋，八条小腕（两帧摆动）；吸住时小腕张开、吸盘朝外。"""
    img, d = canvas()
    if frame == 2:
        for k in range(8):
            a = math.radians(k * 45 + 22)
            d.line((8 + math.cos(a) * 3, 9 + math.sin(a) * 3, 8 + math.cos(a) * 7, 9 + math.sin(a) * 6), fill=OCTO_D)
            d.point((8 + math.cos(a) * 6, 9 + math.sin(a) * 5), fill=PINK_L)
        d.ellipse((4, 4, 12, 12), fill=OCTO)
    else:
        sway = 1 if frame else -1
        for x in (4, 6, 8, 10, 12):
            d.line((x, 10, x + sway, 13), fill=OCTO_D)
            d.point((x + sway, 14), fill=OCTO_L)
        d.ellipse((3, 2, 13, 11), fill=OCTO)
    d.point((6, 6), fill=DARK)
    d.point((10, 6), fill=DARK)
    d.line((7, 8, 9, 8), fill=OCTO_D)
    d.point((5, 4), fill=OCTO_L)
    return add_outline(img)


def caterpillar(frame):
    """毛毛虫：一节一节的绿色身体，背上一排软毛；两帧一拱一伸。"""
    img, d = canvas()
    hump = (0, -2)[frame]
    xs = (2, 5, 8, 11) if frame == 0 else (3, 6, 8, 11)
    for i, x in enumerate(xs):
        y = 10 + (hump if i in (1, 2) else 0)
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=CAT)
        d.point((x, y - 3), fill=CAT_L)
        d.point((x - 1, y + 2), fill=CAT_D)
    d.ellipse((11, 6, 15, 11), fill=CAT)
    d.point((13, 8), fill=DARK)
    d.line((13, 6, 14, 3), fill=CAT_D)
    return add_outline(img)


def barnacle(frame):
    """藤壶贝：一个小贝壳；张开时壳里伸出一圈粉色纤毛（两帧摆动）。"""
    img, d = canvas()
    if frame == 0:
        d.ellipse((2, 6, 13, 14), fill=SHELL_D)
        d.ellipse((2, 5, 13, 12), fill=SHELL)
        for x in (5, 8, 11):
            d.line((x, 6, x - 1, 11), fill=SHELL_D)
        return add_outline(img)
    d.ellipse((2, 9, 13, 15), fill=SHELL_D)
    d.ellipse((2, 2, 13, 8), fill=SHELL)
    d.ellipse((4, 7, 11, 11), fill=PINK_D)
    sway = 1 if frame == 1 else -1
    for x in (4, 6, 8, 10, 12):
        d.line((x, 8, x + sway, 5), fill=CILIA)
    return add_outline(img)


def gen_traps():
    _strip([supine(f) for f in range(2)], 16, 16).save(OUT / "supine.png")
    _strip([cushion(f) for f in range(2)], 16, 16).save(OUT / "cushion.png")
    _strip([prone(f) for f in range(2)], 16, 16).save(OUT / "prone.png")
    p = blank(32, 64)
    for row in range(4):
        for f in range(2):
            p.alpha_composite(pit(row, f), (f * 16, row * 16))
    p.save(OUT / "pit.png")
    _strip([spinwheel(f) for f in range(2)], 32, 32).save(OUT / "spinwheel.png")
    _strip([vest(f) for f in range(2)], 16, 16).save(OUT / "vest.png")
    _strip([chute(f) for f in range(2)], 16, 16).save(OUT / "chute.png")
    _strip([duster(f) for f in range(3)], 16, 16).save(OUT / "duster.png")


# ------------------------------------------------------------------ 训练营的脚 / 大腿 / 屁股陷阱（scripts/traps/leg_trap.gd 的子类）
WATER = (120, 190, 240, 255)
WATER_L = (200, 236, 255, 255)
PORCELAIN = (236, 236, 244, 255)
PORCELAIN_D = (170, 172, 190, 255)
PINK_WATER = (250, 170, 210, 255)


def thigh_pincer(frame):
    """墙上的夹腿羽毛钳：墙上的铜板 + 两条钳臂（帧 0 张开等着、1 夹住、2 缩回合上）。"""
    img, d = canvas()
    d.rectangle((3, 0, 12, 4), fill=BRASS_D)
    d.rectangle((4, 1, 11, 3), fill=BRASS)
    d.point((7, 2), fill=(255, 90, 110, 255) if frame == 0 else DARK)
    if frame == 2:
        d.rectangle((5, 4, 10, 6), fill=STEEL_D)
        return add_outline(img)
    spread = 4 if frame == 0 else 1
    for side in (-1, 1):
        x = 8 + side * spread
        d.line((8 + side, 4, x, 10), fill=STEEL)
        d.line((x, 10, x - side, 13), fill=STEEL_D)
        d.polygon([(x - 1, 12), (x + 1, 12), (x, 15)], fill=FEATHER)
    return add_outline(img)


def foot_thigh_rack(frame):
    """足腿刑架：木架，底下横板上两个脚洞，上面软垫杆；两侧羽毛刷（帧 1 锁上，刷子换位置）。"""
    img, d = canvas()
    d.rectangle((1, 3, 2, 15), fill=WOOD_D)
    d.rectangle((13, 3, 14, 15), fill=WOOD_D)
    d.rectangle((1, 3, 14, 5), fill=PINK_L)
    d.line((1, 5, 14, 5), fill=PINK_D)
    d.rectangle((1, 11, 14, 13), fill=WOOD)
    d.line((1, 11, 14, 11), fill=WOOD_L)
    for x in (5, 10):
        d.ellipse((x - 1, 11, x + 1, 13), fill=DARK if frame == 0 else PINK)
    by = 13 if frame == 0 else 6
    for x in (0, 15):
        d.line((x, by - 2, x, by + 1), fill=BRISTLE)
    return add_outline(img)


def feather_swing(frame):
    """羽毛秋千：两根绳吊着的木座板，座板下面一簇羽毛（帧 1 坐着往前摆）。"""
    img, d = canvas()
    tilt = 1 if frame else 0
    d.line((3, 0, 3 + tilt, 9), fill=WOOD_L)
    d.line((12, 0, 12 + tilt, 9), fill=WOOD_L)
    d.rectangle((2 + tilt, 9, 13 + tilt, 11), fill=WOOD)
    d.line((2 + tilt, 9, 13 + tilt, 9), fill=WOOD_L)
    for x in range(4, 13, 3):
        d.polygon([(x + tilt, 12), (x + 2 + tilt, 12), (x + 1 + tilt, 15)], fill=FEATHER)
    return add_outline(img)


def thigh_brush_ring(frame):
    """大腿刷环：地上一圈带刷毛的圆环（帧 1、2 升起来转，刷毛位置交替）。"""
    img, d = canvas()
    top = 9 if frame == 0 else 5
    d.ellipse((1, top, 14, top + 6), outline=BRASS, width=2)
    for i in range(8):
        ang = math.radians(i * 45 + (22 if frame == 2 else 0))
        x = 7.5 + math.cos(ang) * 6
        y = top + 3 + math.sin(ang) * 2.5
        d.point((round(x), round(y) - 1), fill=BRISTLE)
    if frame:
        d.line((1, top + 3, 1, 15), fill=BRASS_D)
        d.line((14, top + 3, 14, 15), fill=BRASS_D)
    return add_outline(img)


def foot_bath(frame):
    """泡泡足浴盆：木桶里一盆冒泡的水（帧 1 泡泡更多）。"""
    img, d = canvas()
    d.ellipse((1, 6, 14, 15), fill=WOOD_D)
    d.ellipse((2, 6, 13, 13), fill=WOOD)
    d.ellipse((3, 7, 12, 11), fill=WATER)
    for (x, y) in ((5, 8), (9, 9), (7, 7)) + (((4, 6), (11, 7), (8, 5)) if frame else ()):
        d.point((x, y), fill=WATER_L)
    return add_outline(img)


def sitz_bath(frame):
    """泡泡坐浴：白瓷浴缸里粉色的泡泡水（帧 1 泡泡冒得更高）。"""
    img, d = canvas()
    d.rounded_rectangle((0, 6, 15, 14), 3, fill=PORCELAIN_D)
    d.rounded_rectangle((0, 6, 15, 12), 3, fill=PORCELAIN)
    d.rectangle((2, 7, 13, 10), fill=PINK_WATER)
    for (x, y) in ((4, 7), (8, 6), (12, 7)) + (((3, 4), (7, 3), (11, 4), (9, 5)) if frame else ()):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=WATER_L)
    d.line((2, 15, 3, 15), fill=BRASS)
    d.line((12, 15, 13, 15), fill=BRASS)
    return add_outline(img)


def spring_seat(frame):
    """弹簧刷座：帧 0 地上的翻板；帧 1 弹出带刷毛凳面的矮凳（下面露出弹簧）。"""
    img, d = canvas()
    if frame == 0:
        d.rectangle((2, 10, 13, 13), fill=WOOD_D)
        d.rectangle((3, 10, 12, 12), fill=WOOD)
        d.line((3, 11, 12, 11), fill=WOOD_L)
        return add_outline(img)
    for y in range(9, 15, 2):
        d.line((6, y, 9, y + 1), fill=STEEL)
    d.rectangle((2, 5, 13, 8), fill=PINK_D)
    d.rectangle((2, 5, 13, 7), fill=PINK)
    for x in range(3, 13, 2):
        d.point((x, 4), fill=BRISTLE)
    return add_outline(img)


def saddle_bench(frame):
    """骑马刷凳：长木凳中间一个马鞍形皮垫，两侧刷条（帧 1 刷条推出来）。"""
    img, d = canvas()
    for x in (1, 14):
        d.line((x, 10, x, 15), fill=WOOD_D)
    d.rectangle((0, 8, 15, 10), fill=WOOD)
    d.line((0, 8, 15, 8), fill=WOOD_L)
    d.chord((4, 4, 11, 12), 180, 360, fill=LEATHER)
    d.point((7, 5), fill=(170, 100, 110, 255))
    off = 2 if frame else 0
    d.line((2 - off // 2, 11, 5, 11 + off), fill=BRISTLE)
    d.line((13 + off // 2, 11, 10, 11 + off), fill=BRISTLE)
    return add_outline(img)


def scissor_stand(frame):
    """剪刀刷台：底座 + 两块带刷毛的台板（帧 0 张开、1 合拢夹住、2 缩回），中间下方一根刷杆。"""
    img, d = canvas()
    d.rectangle((1, 13, 14, 15), fill=STONE_D)
    d.rectangle((1, 13, 14, 14), fill=STONE)
    gap = {0: 6, 1: 2, 2: 7}[frame]
    h = 4 if frame == 2 else 0
    for side in (-1, 1):
        x0 = 8 + side * gap
        xa, xb = (x0 - 3, x0) if side < 0 else (x0, x0 + 3)
        d.rectangle((xa, 5 + h, xb, 12), fill=WOOD)
        bx = xb if side < 0 else xa
        for y in range(6 + h, 12, 2):
            d.point((bx, y), fill=BRISTLE)
    d.line((5, 12, 10, 12), fill=BRASS)
    return add_outline(img)


def gen_leg_traps():
    for name, fn, n in (("thigh_pincer", thigh_pincer, 3), ("foot_thigh_rack", foot_thigh_rack, 2), ("feather_swing", feather_swing, 2),
                        ("thigh_brush_ring", thigh_brush_ring, 3), ("foot_bath", foot_bath, 2), ("sitz_bath", sitz_bath, 2),
                        ("spring_seat", spring_seat, 2), ("saddle_bench", saddle_bench, 2), ("scissor_stand", scissor_stand, 3)):
        _strip([fn(f) for f in range(n)], 16, 16).save(OUT / (name + ".png"))


def gen_monsters():
    _strip([frog(f) for f in range(4)], 16, 16).save(OUT / "frog.png")
    _strip([squirrel(f) for f in range(4)], 16, 16).save(OUT / "squirrel.png")
    _strip([octopus(f) for f in range(3)], 16, 16).save(OUT / "octopus.png")
    _strip([caterpillar(f) for f in range(2)], 16, 16).save(OUT / "caterpillar.png")
    _strip([barnacle(f) for f in range(3)], 16, 16).save(OUT / "barnacle.png")


def main():
    gen_zone_fx()
    gen_traps()
    gen_leg_traps()
    gen_monsters()
    print("新部位像素图已生成")


if __name__ == "__main__":
    main()
