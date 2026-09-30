"""扩展内容的像素占位图（楼层扩充、第三层、魔法、组合技）。

输出到 assets/generated/：
  weapon_rack.png   16x16      可打碎的武器架（第一层兵器库）
  secret_crack.png  16x16      暗墙被火光照出的裂缝（叠在墙顶上）
  magic_circle.png  80x40 x 4帧 x 4行   吟唱魔法阵（行 = 蓄力档 0~3，越高越大越亮）
  star_burst.png    152x152 x 6帧 x 3行 星光爆发冲击环（行 = 档位 1~3，半径 36/52/72）
  sparkle.png       7x7 x 2    星光粒子
  magic_icon.png    16x16 x 2  HUD 魔法图标（可用 / 冷却中）
  pink_slime.png    16x16      分裂史莱姆（Kenney #108 色相旋转成粉色）
  fairy.png         8x8 x 2帧  羽毛小精灵（翅膀扇动）
  tentacle_boss.png 32x32 x 2帧 痒痒触手怪本体（放大 2 倍显示）
  tentacle.png      8x8 x 3    触手：节、尖端（带小羽毛）、吸盘节
  strike_mark.png   16x8 x 2   触手落点预警
  vine.png          16x16 x 3  痒痒藤蔓：潜伏 / 缠绕 / 被砍断
  fan.png           16x16 x 2  羽毛风扇（叶片转动）
  wind_feather.png  5x5        风里的小羽毛粒子
  conveyor.png      16x16 x 4  传送带（向右，箭头滚动 4 帧；其它方向旋转显示）

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


# ------------------------------------------------------------------ 第三层怪物
FAIRY_SKIN = (255, 226, 214, 255)
FAIRY_HAIR = (140, 230, 190, 255)
FAIRY_WING = (190, 236, 255, 200)
FAIRY_DRESS = (120, 200, 255, 255)
TENT = (176, 96, 196, 255)
TENT_L = (214, 140, 226, 255)
TENT_D = (112, 56, 140, 255)
SUCKER = (255, 180, 214, 255)
EYE_W = (250, 248, 255, 255)
EYE_P = (40, 24, 60, 255)


def fairy(frame):
    img, d = canvas(8, 8)
    # 翅膀（两帧：张开 / 收拢）
    if frame == 0:
        d.polygon([(3, 3), (0, 1), (0, 4)], fill=FAIRY_WING)
        d.polygon([(4, 3), (7, 1), (7, 4)], fill=FAIRY_WING)
    else:
        d.polygon([(3, 3), (1, 5), (2, 2)], fill=FAIRY_WING)
        d.polygon([(4, 3), (6, 5), (5, 2)], fill=FAIRY_WING)
    d.rectangle((3, 1, 4, 2), fill=FAIRY_SKIN)     # 头
    d.point((3, 0), fill=FAIRY_HAIR)
    d.point((4, 0), fill=FAIRY_HAIR)
    d.rectangle((3, 3, 4, 5), fill=FAIRY_DRESS)    # 身体
    d.point((3, 6), fill=FAIRY_SKIN)
    d.point((4, 6), fill=FAIRY_SKIN)
    return img


def tentacle_boss(frame):
    img, d = canvas(32, 32)
    squash = 1 if frame else 0
    # 身体：圆顶软体
    d.ellipse((4, 4 + squash, 27, 27), fill=TENT)
    d.ellipse((7, 6 + squash, 20, 15 + squash), fill=TENT_L)
    # 底部短触手
    for x in (5, 11, 17, 23):
        d.ellipse((x, 23, x + 5, 30 - squash), fill=TENT_D)
        d.point((x + 2, 27 - squash), fill=SUCKER)
    # 眼睛
    for ex in (10, 18):
        d.ellipse((ex, 12 + squash, ex + 4, 17 + squash), fill=EYE_W)
        d.rectangle((ex + 1 + frame, 14 + squash, ex + 2 + frame, 16 + squash), fill=EYE_P)
    # 坏笑的嘴
    d.arc((11, 16 + squash, 21, 23 + squash), 20, 160, fill=EYE_P)
    # 吸盘斑点
    for x, y in ((6, 19), (25, 17), (22, 8)):
        d.point((x, y), fill=SUCKER)
    return add_outline(img)


def tentacle_parts():
    img = blank(24, 8)
    seg, d = canvas(8, 8)
    d.ellipse((1, 1, 6, 6), fill=TENT)
    d.point((3, 2), fill=TENT_L)
    img.alpha_composite(add_outline(seg), (0, 0))
    tip, d = canvas(8, 8)
    d.ellipse((2, 2, 5, 5), fill=TENT_L)
    d.line((4, 3, 7, 0), fill=WHITE_F)       # 尖端的小羽毛
    d.point((6, 0), fill=SUCKER)
    img.alpha_composite(add_outline(tip), (8, 0))
    suck, d = canvas(8, 8)
    d.ellipse((1, 1, 6, 6), fill=TENT_D)
    d.point((3, 3), fill=SUCKER)
    d.point((4, 4), fill=SUCKER)
    img.alpha_composite(add_outline(suck), (16, 0))
    return img


def strike_mark(frame):
    img, d = canvas(16, 8)
    c = SUCKER if frame == 0 else (255, 110, 170, 255)
    d.ellipse((0, 0, 15, 7), outline=c)
    d.ellipse((4, 2, 11, 5), outline=c if frame else (255, 220, 236, 255))
    return img


WHITE_F = (250, 248, 255, 255)


def pink_slime():
    import colorsys
    src = kenney(108)
    px = src.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if sat > 0.15:
                h = 0.92          # 粉色
                l = min(1.0, l * 1.12 + 0.05)
            r2, g2, b2 = colorsys.hls_to_rgb(h, l, sat)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return src


def gen_monsters():
    pink_slime().save(OUT / "pink_slime.png")
    sheet = blank(16, 8)
    for f in range(2):
        sheet.alpha_composite(fairy(f), (f * 8, 0))
    sheet.save(OUT / "fairy.png")
    sheet = blank(64, 32)
    for f in range(2):
        sheet.alpha_composite(tentacle_boss(f), (f * 32, 0))
    sheet.save(OUT / "tentacle_boss.png")
    tentacle_parts().save(OUT / "tentacle.png")
    sheet = blank(32, 8)
    for f in range(2):
        sheet.alpha_composite(strike_mark(f), (f * 16, 0))
    sheet.save(OUT / "strike_mark.png")


# ------------------------------------------------------------------ 第三层陷阱
LEAF = (110, 190, 90, 255)
LEAF_L = (160, 220, 120, 255)
LEAF_D = (60, 120, 60, 255)
STONE = (139, 155, 180, 255)
STONE_DK = (82, 96, 124, 255)
BELT = (70, 64, 80, 255)
BELT_L = (104, 96, 118, 255)
ARROW = (255, 200, 120, 255)


def vine(frame):
    img, d = canvas()
    if frame == 0:      # 潜伏：地上几片叶子
        for x, y in ((3, 12), (8, 13), (12, 11)):
            d.line((x, y + 2, x + 1, y), fill=LEAF_D)
            d.point((x + 2, y), fill=LEAF)
            d.point((x, y), fill=LEAF_L)
    elif frame == 1:    # 缠绕：藤蔓卷起
        d.arc((2, 3, 13, 15), 180, 360, fill=LEAF)
        d.arc((3, 6, 12, 15), 0, 180, fill=LEAF_D)
        d.line((4, 15, 6, 4), fill=LEAF)
        d.line((11, 15, 9, 5), fill=LEAF)
        for x, y in ((5, 5), (10, 6), (3, 9), (12, 10), (7, 3)):
            d.point((x, y), fill=LEAF_L)
            d.point((x + 1, y), fill=LEAF)
    else:               # 被砍断：残桩
        for x in (4, 8, 11):
            d.line((x, 15, x, 13), fill=LEAF_D)
            d.point((x, 12), fill=(210, 190, 120, 255))
    return add_outline(img) if frame else img


def fan(frame):
    img, d = canvas()
    d.rectangle((3, 10, 12, 15), fill=STONE_DK)           # 底座
    d.rectangle((4, 10, 11, 11), fill=STONE)
    d.ellipse((2, 1, 13, 12), fill=STONE)                 # 外框
    d.ellipse((3, 2, 12, 11), fill=(60, 52, 72, 255))
    c = (7.5, 6.5)
    import math
    for i in range(3):
        a = i * 2 * math.pi / 3 + frame * math.pi / 3
        x = c[0] + math.cos(a) * 4
        y = c[1] + math.sin(a) * 4
        d.line((round(c[0]), round(c[1]), round(x), round(y)), fill=PINK_F)
        d.point((round(x), round(y)), fill=WHITE_F)
    d.point((7, 6), fill=STAR)
    return add_outline(img)


PINK_F = (255, 170, 214, 255)


def wind_feather():
    img, d = canvas(5, 5)
    d.line((0, 4, 4, 0), fill=WHITE_F)
    d.point((1, 2), fill=PINK_F)
    d.point((2, 3), fill=PINK_F)
    return img


def conveyor(frame):
    img, d = canvas()
    d.rectangle((0, 1, 15, 14), fill=BELT)
    d.line((0, 1, 15, 1), fill=BELT_L)
    d.line((0, 14, 15, 14), fill=STONE_DK)
    for y in (3, 12):                                   # 滚轮边
        for x in range(0, 16, 4):
            d.point(((x + frame) % 16, y), fill=BELT_L)
    for k in range(2):                                  # 滚动的箭头
        x = (k * 8 + frame * 2) % 16
        d.line((x, 5, x + 2, 7), fill=ARROW)
        d.line((x + 2, 8, x, 10), fill=ARROW)
    return img


def gen_traps():
    sheet = blank(48, 16)
    for f in range(3):
        sheet.alpha_composite(vine(f), (f * 16, 0))
    sheet.save(OUT / "vine.png")
    sheet = blank(32, 16)
    for f in range(2):
        sheet.alpha_composite(fan(f), (f * 16, 0))
    sheet.save(OUT / "fan.png")
    wind_feather().save(OUT / "wind_feather.png")
    sheet = blank(64, 16)
    for f in range(4):
        sheet.alpha_composite(conveyor(f), (f * 16, 0))
    sheet.save(OUT / "conveyor.png")


# ------------------------------------------------------------------ 笑倒 CG 特效
def tickle_lines(frame):
    """挠痒的"咯吱"线条：三道弯折短线，逐帧张开。"""
    img, d = canvas()
    spread = [2, 3, 4][frame]
    for i, (x, y) in enumerate(((3, 4), (8, 2), (12, 5))):
        pts = [(x, y + spread), (x - 1, y + spread - 2), (x + 1, y + spread - 4), (x, y + spread - 6)]
        d.line(pts, fill=WHITE_F if i != 1 else PINK_F)
    return img


def cg_feather():
    img, d = canvas()
    d.line((3, 13, 12, 3), fill=WHITE_F)
    for t in range(5, 12, 2):
        d.point((t, 15 - t), fill=PINK_F)
        d.point((t + 1, 14 - t - 1), fill=PINK_F)
    d.point((12, 3), fill=PINK_F)
    return add_outline(img)


def cg_hand():
    img, d = canvas()
    d.rounded_rectangle((4, 7, 11, 13), radius=2, fill=WHITE_F)
    for x in (4, 6, 8, 10):
        d.line((x, 3 + (x % 4 == 0), x, 7), fill=WHITE_F)
    d.line((12, 9, 13, 8), fill=WHITE_F)
    return add_outline(img)


def cg_heart():
    img, d = canvas()
    d.polygon([(8, 13), (3, 8), (3, 5), (5, 3), (8, 5), (11, 3), (13, 5), (13, 8)], fill=PINK_F)
    d.point((5, 5), fill=WHITE_F)
    return add_outline(img)


def gen_cg_fx():
    sheet = blank(96, 16)
    frames = [tickle_lines(0), tickle_lines(1), tickle_lines(2), cg_feather(), cg_hand(), cg_heart()]
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * 16, 0))
    sheet.save(OUT / "cg_fx.png")


# ------------------------------------------------------------------ 增益 / 减益图标
def buff_icon(kind):
    img, d = canvas(12, 12)
    good = kind in (0, 1)
    d.rounded_rectangle((0, 0, 11, 11), radius=2, fill=(40, 90, 60, 255) if good else (100, 40, 60, 255))
    d.rounded_rectangle((0, 0, 11, 11), radius=2, outline=(120, 230, 150, 255) if good else (255, 120, 150, 255))
    if kind == 0:      # 力量：向上的箭头
        d.polygon([(6, 2), (9, 6), (7, 6), (7, 9), (5, 9), (5, 6), (3, 6)], fill=(255, 220, 120, 255))
    elif kind == 1:    # 狂热：火焰
        d.polygon([(6, 2), (9, 7), (8, 9), (4, 9), (3, 7), (5, 5)], fill=(255, 140, 60, 255))
        d.polygon([(6, 5), (7, 8), (5, 8)], fill=(255, 230, 120, 255))
    elif kind == 2:    # 易痒诅咒：羽毛 + 叹号
        d.line((3, 9, 7, 3), fill=WHITE_F)
        d.point((5, 5), fill=PINK_F)
        d.point((4, 7), fill=PINK_F)
        d.line((9, 2, 9, 6), fill=(255, 230, 120, 255))
        d.point((9, 8), fill=(255, 230, 120, 255))
    elif kind == 3:    # 黏黏：粘液滴
        d.ellipse((3, 4, 8, 9), fill=(250, 140, 200, 255))
        d.point((5, 3), fill=(250, 140, 200, 255))
        d.point((4, 5), fill=WHITE_F)
    elif kind == 4:    # 封魔：星星被划掉
        d.polygon([(6, 2), (7, 5), (10, 5), (7, 7), (8, 10), (6, 8), (4, 10), (5, 7), (2, 5), (5, 5)], fill=STAR)
        d.line((2, 2, 10, 10), fill=(255, 80, 100, 255))
    else:              # 疲倦印记：紫色水滴
        d.polygon([(6, 2), (9, 7), (6, 10), (3, 7)], fill=(170, 120, 255, 255))
        d.point((5, 6), fill=(230, 210, 255, 255))
    return img


def gen_buff_icons():
    sheet = blank(72, 12)
    for i in range(6):
        sheet.alpha_composite(buff_icon(i), (i * 12, 0))
    sheet.save(OUT / "buff_icons.png")


# ------------------------------------------------------------------ 魔力疲倦
PURPLE = (150, 100, 230, 200)
PURPLE_L = (200, 170, 255, 220)
PURPLE_D = (90, 60, 160, 210)


def fatigue_puddle(frame):
    img, d = canvas(48, 24)
    d.ellipse((1, 3, 46, 21), fill=PURPLE_D)
    d.ellipse((4, 5, 43, 19), fill=PURPLE)
    d.ellipse((10, 7, 30, 13), fill=PURPLE_L)
    for i, (x, y) in enumerate(((14, 9), (30, 14), (22, 16), (36, 10))):
        if (i + frame) % 3 == 0:
            d.point((x, y), fill=(255, 255, 255, 255))
            d.point((x + 1, y), fill=(230, 220, 255, 255))
    return img


def clear_dew():
    img, d = canvas()
    d.rectangle((6, 1, 9, 3), fill=(200, 170, 120, 255))     # 瓶塞
    d.rectangle((6, 4, 9, 5), fill=(210, 240, 255, 255))     # 瓶颈
    d.ellipse((3, 5, 12, 14), fill=(150, 210, 255, 255))     # 瓶身
    d.ellipse((4, 8, 11, 14), fill=(110, 180, 250, 255))
    d.point((5, 7), fill=(255, 255, 255, 255))
    d.point((8, 10), fill=(255, 170, 214, 255))               # 花
    d.point((7, 10), fill=(255, 220, 240, 255))
    d.point((9, 10), fill=(255, 220, 240, 255))
    d.point((8, 9), fill=(255, 220, 240, 255))
    d.point((8, 11), fill=(255, 220, 240, 255))
    return add_outline(img)


def gen_fatigue_art():
    sheet = blank(144, 24)
    for f in range(3):
        sheet.alpha_composite(fatigue_puddle(f), (f * 48, 0))
    sheet.save(OUT / "fatigue_puddle.png")
    clear_dew().save(OUT / "item_clear_dew.png")


def gen_floor_expansion():
    weapon_rack().save(OUT / "weapon_rack.png")
    secret_crack().save(OUT / "secret_crack.png")


def main():
    gen_floor_expansion()
    gen_magic()
    gen_monsters()
    gen_traps()
    gen_cg_fx()
    gen_buff_icons()
    gen_fatigue_art()


if __name__ == "__main__":
    main()
