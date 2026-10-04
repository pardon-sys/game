"""第八层「千手之间」的像素美术（Python 绘制，确定性随机）：

  thousand_hand.png      千手痒痒魔本体 128x96 × 6 帧：待机 0/1、受击、被锁链拽下、恼怒 0/1
  thousand_hand_arm.png  手臂零件 24x24 × 8 格：臂段、臂段（亮）、空手 0/1、羽毛手 0/1、刷子手 0/1
  thousand_hand_portrait.png  对话立绘 114x152（本体缩小 + 垂下的手）
  boulder.png            巨石 32x32 × 4 帧（滚动）
  duo_plate.png          双人压力板 24x24 × 2（暗 / 亮）
  sacrifice_circle.png   献祭光圈 64x32 × 2 帧（脉动）
  chain_link.png         锁链环 8x8 × 2（竖 / 横）
用法：cd tools/art && python gen_floor08_art.py
"""
import math
import random

from PIL import Image, ImageDraw

from gen_expansion import _strip, blank, canvas
from palette import OUT, add_outline

PLUM = (92, 52, 110, 255)
PLUM_D = (60, 32, 78, 255)
PLUM_DD = (40, 20, 54, 255)
PLUM_L = (128, 80, 150, 255)
PLUM_LL = (170, 122, 192, 255)
EYE = (255, 214, 90, 255)
EYE_D = (210, 150, 40, 255)
EYE_R = (255, 80, 70, 255)
TOOTH = (250, 246, 236, 255)
MOUTH = (34, 10, 30, 255)
TONGUE = (230, 110, 140, 255)
RIBBON = (150, 184, 236, 255)
RIBBON_D = (86, 116, 196, 255)
HAND = (214, 184, 232, 255)
HAND_D = (160, 120, 190, 255)
CHAIN = (176, 180, 196, 255)
CHAIN_D = (96, 100, 120, 255)


def _blob_mask(w, h, seed, squish=0.0):
    """本体的轮廓：一大团毛茸茸的身体（下面宽、上面圆顶），边缘有一簇簇的毛。"""
    rnd = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    cy = 60 + squish * 6
    d.ellipse((8, cy - 30 + squish * 4, w - 8, cy + 32), fill=255)
    d.ellipse((24, 10 + squish * 10, w - 24, 72 + squish * 6), fill=255)
    for i in range(34):
        a = math.pi * (0.95 + 1.1 * i / 33.0)
        r = 1.0 + rnd.uniform(-0.03, 0.08)
        x = w / 2 + math.cos(a) * (w / 2 - 10) * r
        y = cy - 6 + math.sin(a) * (44 - squish * 8) * r
        s = rnd.randint(4, 7)
        d.polygon([(x - s, y + 2), (x + s, y + 2), (x + rnd.uniform(-3, 3), y - s - 3)], fill=255)
    return m


def body_frame(kind, t=0):
    w, h = 128, 96
    squish = {"idle": 0.15 * t, "hurt": 0.1, "pulled": 1.0, "rage": 0.0}[kind]
    mask = _blob_mask(w, h, 8, squish)
    img = blank(w, h)
    rnd = random.Random(77 + t)
    px = img.load()
    mk = mask.load()
    for y in range(h):
        for x in range(w):
            if mk[x, y] < 128:
                continue
            # 上亮下暗 + 毛的纹理
            g = y / h
            # 毛的纹理：按斜向条纹成簇，而不是零散的噪点
            n = (math.sin(x * 0.9 + y * 0.35) + math.sin(x * 0.31 - y * 0.8 + 1.7)) * 0.5 + rnd.uniform(-0.25, 0.25)
            c = PLUM_L if g < 0.35 else (PLUM if g < 0.7 else PLUM_D)
            if n > 0.72:
                c = PLUM_LL if g < 0.35 else PLUM_L
            elif n < -0.78:
                c = PLUM_D if g < 0.7 else PLUM_DD
            px[x, y] = c
    d = ImageDraw.Draw(img)
    oy = int(squish * 8)
    rage = kind == "rage"
    # 手臂根（下沿一圈）
    for i in range(9):
        x = 18 + i * 11.5
        y = 84 + (i % 2) * 3 - oy // 3
        d.ellipse((x - 5, y - 4, x + 5, y + 5), fill=PLUM_D, outline=PLUM_DD)
        d.ellipse((x - 2, y - 1, x + 2, y + 2), fill=HAND_D)
    # 褪色的蓝丝带（头顶左边，系成蝴蝶结）
    rx, ry = 40, 18 + oy
    d.polygon([(rx, ry), (rx - 9, ry - 6), (rx - 9, ry + 5)], fill=RIBBON, outline=RIBBON_D)
    d.polygon([(rx, ry), (rx + 9, ry - 6), (rx + 9, ry + 5)], fill=RIBBON, outline=RIBBON_D)
    d.rectangle((rx - 2, ry - 2, rx + 2, ry + 2), fill=RIBBON_D)
    d.line((rx - 1, ry + 3, rx - 4, ry + 11), fill=RIBBON_D)
    d.line((rx + 1, ry + 3, rx + 5, ry + 10), fill=RIBBON_D)
    # 眼睛：中间一大对，旁边几只小的
    eye = EYE_R if rage else EYE
    blink = kind == "idle" and t == 1
    for (ex, ey, r) in ((50, 40, 9), (78, 40, 9), (30, 52, 4), (98, 52, 4), (64, 24, 4), (22, 36, 3), (106, 36, 3)):
        ey += oy
        if kind == "hurt":
            d.line((ex - r + 2, ey - r + 2, ex + r - 2, ey + r - 2), fill=MOUTH, width=2)
            d.line((ex - r + 2, ey + r - 2, ex + r - 2, ey - r + 2), fill=MOUTH, width=2)
            continue
        if blink and r > 5:
            d.line((ex - r, ey, ex + r, ey), fill=MOUTH, width=2)
            continue
        d.ellipse((ex - r, ey - r, ex + r, ey + r), fill=eye, outline=MOUTH)
        d.ellipse((ex - r + 2, ey - r + 1, ex + r - 3, ey - 1), fill=(255, 240, 170, 255) if not rage else (255, 150, 140, 255))
        d.rectangle((ex - max(1, r // 4), ey - r + 2, ex + max(1, r // 4), ey + r - 2), fill=MOUTH)   # 竖瞳
        if rage and r > 5:   # 怒眉
            d.line((ex - r - 1, ey - r - 4 + (2 if ex < 64 else -2), ex + r + 1, ey - r - 4 + (-2 if ex < 64 else 2)), fill=PLUM_DD, width=3)
    # 嘴：裂开的笑（恼怒时张大吼）
    my = 64 + oy
    if rage:
        d.ellipse((40, my - 6, 88, my + 16 + t * 2), fill=MOUTH)
        d.ellipse((52, my + 6, 76, my + 16 + t * 2), fill=TONGUE)
    else:
        d.chord((36, my - 14, 92, my + 12), 10, 170, fill=MOUTH)
        d.chord((52, my, 76, my + 11), 10, 170, fill=TONGUE)
    for i in range(7):
        x = 42 + i * 7
        d.polygon([(x, my - 1), (x + 5, my - 1), (x + 2.5, my + 4)], fill=TOOTH)
    # 被锁链拽下：两条锁链从上面斜着勒住
    if kind == "pulled":
        for sx, ex2 in ((10, 70), (118, 58)):
            for i in range(10):
                f = i / 9.0
                x, y = sx + (ex2 - sx) * f, 2 + 70 * f
                d.ellipse((x - 3, y - 3, x + 3, y + 3), outline=CHAIN, width=2)
                d.point((x, y), fill=CHAIN_D)
    if kind == "hurt":
        img = Image.blend(img, Image.new("RGBA", img.size, (255, 255, 255, 0)), 0.0)
        img = _tint(img, (255, 230, 240), 0.22)
    if rage and t == 1:
        img = img.transform(img.size, Image.AFFINE, (1, 0, -2, 0, 1, 0))
    return add_outline(img, (24, 10, 30, 255))


def _tint(img, rgb, k):
    out = img.copy()
    p = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = p[x, y]
            if a:
                p[x, y] = (int(r + (rgb[0] - r) * k), int(g + (rgb[1] - g) * k), int(b + (rgb[2] - b) * k), a)
    return out


def arm_seg(lit=False):
    img, d = canvas(24, 24)
    c, cd = (PLUM_L, PLUM) if lit else (PLUM, PLUM_D)
    d.ellipse((5, 5, 18, 18), fill=c, outline=PLUM_DD)
    d.arc((7, 7, 16, 16), 200, 320, fill=PLUM_LL)
    d.line((7, 14, 16, 14), fill=cd)
    return img


def hand(kind, t):
    img, d = canvas(24, 24)
    # 手掌
    d.ellipse((6, 9, 17, 20), fill=HAND, outline=HAND_D)
    wig = (-1, 1)[t]
    for i, fx in enumerate((6, 9, 12, 15, 18)):
        tip = 3 + (i % 2) + (wig if i % 2 == 0 else -wig)
        d.line((fx - (1 if i == 4 else 0), 11, fx + (2 if i == 4 else 0) - (i == 0) * 2, tip + (6 if i in (0, 4) else 0)), fill=HAND, width=2)
        d.point((fx, tip + (6 if i in (0, 4) else 0)), fill=HAND_D)
    if kind == "feather":
        d.line((14, 4 + t, 21, 20 - t), fill=(250, 250, 255, 255), width=2)
        for k in range(5):
            y = 6 + k * 3 + t
            d.line((16 + k, y, 20 + k // 2, y - 2), fill=(255, 190, 220, 255))
    elif kind == "brush":
        d.rectangle((15, 6, 18, 20), fill=(150, 100, 60, 255), outline=(90, 56, 34, 255))
        for k in range(4):
            d.line((19, 8 + k * 3 + t, 22, 8 + k * 3 + t), fill=(240, 230, 200, 255))
    return add_outline(img, (24, 10, 30, 255))


def portrait():
    img = blank(114, 152)
    b = body_frame("idle", 0).resize((110, 82), Image.NEAREST)
    img.alpha_composite(b, (2, 10))
    # 垂下的手
    for i, x in enumerate((16, 44, 72, 98)):
        for k in range(4):
            seg = arm_seg(k % 2 == 1).resize((14, 14), Image.NEAREST)
            img.alpha_composite(seg, (x - 7 + (k % 2) * 2 * (1 if i % 2 else -1), 84 + k * 12))
        h = hand(("open", "feather", "brush", "open")[i], i % 2).resize((22, 22), Image.NEAREST)
        img.alpha_composite(h, (x - 11, 128))
    return img


def boulder(frame):
    base, d = canvas(32, 32)
    d.ellipse((2, 3, 29, 30), fill=(132, 124, 134, 255), outline=(60, 54, 66, 255))
    d.ellipse((5, 5, 20, 16), fill=(164, 158, 168, 255))
    d.line((9, 20, 15, 15, 22, 18), fill=(84, 78, 92, 255), width=1)
    d.line((15, 15, 14, 8), fill=(84, 78, 92, 255))
    d.ellipse((20, 22, 25, 26), fill=(100, 94, 106, 255))
    d.ellipse((8, 23, 11, 26), fill=(100, 94, 106, 255))
    img = base.rotate(-90 * frame, resample=Image.NEAREST)
    # 底下的影子不跟着转
    out, d2 = canvas(32, 32)
    d2.ellipse((4, 26, 28, 31), fill=(20, 12, 24, 110))
    out.alpha_composite(img)
    return out


def plate(lit):
    img, d = canvas(24, 24)
    d.rounded_rectangle((1, 3, 22, 22), radius=3, fill=(96, 92, 110, 255), outline=(48, 44, 60, 255))
    d.rounded_rectangle((3, 4, 20, 19), radius=2, fill=(126, 122, 140, 255))
    c = (255, 220, 110, 255) if lit else (70, 66, 84, 255)
    d.ellipse((6, 6, 17, 17), outline=c)
    d.line((11, 7, 11, 16), fill=c)
    d.line((7, 11, 16, 11), fill=c)
    if lit:
        d.ellipse((9, 9, 13, 13), fill=(255, 250, 200, 255))
    return img


def circle(t):
    img, d = canvas(64, 32)
    a = 200 + t * 55
    d.ellipse((2, 4, 61, 29), outline=(255, 90, 170, a), width=2)
    d.ellipse((10, 8, 53, 25), outline=(200, 120, 255, a - 60), width=1)
    for i in range(8):
        ang = i * math.pi / 4 + t * 0.2
        x, y = 32 + math.cos(ang) * 25, 16 + math.sin(ang) * 10
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=(255, 200, 240, a))
    return img


def chain_link(horizontal):
    img, d = canvas(8, 8)
    if horizontal:
        d.ellipse((0, 2, 7, 5), outline=CHAIN)
        d.point((2, 3), fill=CHAIN_D)
    else:
        d.ellipse((2, 0, 5, 7), outline=CHAIN)
        d.point((3, 2), fill=CHAIN_D)
    return img


def main():
    frames = [body_frame("idle", 0), body_frame("idle", 1), body_frame("hurt"), body_frame("pulled"), body_frame("rage", 0), body_frame("rage", 1)]
    _strip(frames, 128, 96).save(OUT / "thousand_hand.png")
    parts = [arm_seg(False), arm_seg(True), hand("open", 0), hand("open", 1), hand("feather", 0), hand("feather", 1), hand("brush", 0), hand("brush", 1)]
    _strip(parts, 24, 24).save(OUT / "thousand_hand_arm.png")
    portrait().save(OUT / "thousand_hand_portrait.png")
    _strip([boulder(i) for i in range(4)], 32, 32).save(OUT / "boulder.png")
    _strip([plate(False), plate(True)], 24, 24).save(OUT / "duo_plate.png")
    _strip([circle(0), circle(1)], 64, 32).save(OUT / "sacrifice_circle.png")
    _strip([chain_link(False), chain_link(True)], 8, 8).save(OUT / "chain_link.png")
    print("第八层美术：本体 6 帧、手臂零件 8 格、立绘、巨石 4 帧、压力板、光圈、锁链")


if __name__ == "__main__":
    main()
