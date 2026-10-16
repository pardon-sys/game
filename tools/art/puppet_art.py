"""魔偶师 / 新敌塔 / 工具的程序像素画，复用攻防战图集入口与调色板。"""
import math
from PIL import Image, ImageDraw
from palette import add_outline

DARK = (57, 34, 68, 255)
PINK = (233, 113, 177, 255)
GOLD = (249, 204, 104, 255)
BLUE = (107, 198, 219, 255)
LIGHT = (255, 228, 217, 255)
WOOD = (151, 101, 88, 255)


def tool(key):
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    if key == "tool_finger":
        d.rectangle((4, 8, 12, 13), fill=BLUE)
        for x, y in ((4, 3), (7, 1), (10, 2)):
            d.rounded_rectangle((x, y, x + 2, 9), radius=1, fill=LIGHT)
        d.line((4, 11, 12, 11), fill=GOLD)
    elif key == "tool_roller":
        d.rectangle((2, 5, 13, 7), fill=WOOD)
        for y in (3, 9):
            d.rounded_rectangle((2, y, 13, y + 3), radius=1, fill=LIGHT)
            for x in range(3, 13, 2):
                d.point((x, y), fill=PINK)
        d.rectangle((6, 12, 8, 14), fill=BLUE)
    elif key == "tool_pad":
        for y in range(8, 14, 2):
            d.line((4, y, 11, y + 1), fill=GOLD)
        d.rounded_rectangle((2, 1, 13, 8), radius=3, fill=PINK)
        d.line((4, 3, 11, 3), fill=LIGHT)
        d.rectangle((3, 14, 12, 15), fill=BLUE)
    else:
        d.arc((0, 0, 15, 9), 180, 360, fill=LIGHT, width=2)
        d.line((1, 5, 5, 12), fill=PINK)
        d.line((14, 5, 10, 12), fill=PINK)
        d.rectangle((4, 10, 11, 15), fill=BLUE)
        d.line((4, 12, 11, 12), fill=GOLD)
    return add_outline(im)


def tower(kind):
    im = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(im)
    d.polygon([(3, 41), (9, 36), (23, 36), (29, 41), (26, 46), (6, 46)], fill=WOOD)
    d.rectangle((8, 20, 23, 40), fill=WOOD)
    d.rectangle((10, 22, 21, 38), fill=DARK)
    d.line((8, 20, 23, 20), fill=GOLD, width=2)
    if kind == "airdrop":
        d.rectangle((3, 12, 28, 22), fill=BLUE)
        d.polygon([(4, 12), (16, 3), (27, 12)], fill=PINK)
        im.alpha_composite(tool("tool_capsule"), (8, 23))
        d.line((16, 0, 16, 7), fill=GOLD, width=2)
        d.polygon([(17, 0), (27, 3), (17, 5)], fill=GOLD)
    elif kind == "brush_battery":
        d.rectangle((5, 10, 26, 22), fill=BLUE)
        for x in (6, 13, 20):
            d.rectangle((x, 5, x + 4, 17), fill=LIGHT)
            d.line((x, 5, x + 4, 5), fill=PINK, width=2)
        im.alpha_composite(tool("tool_roller"), (8, 23))
    else:
        d.line((4, 9, 16, 2, 28, 9), fill=PINK, width=3)
        d.rectangle((4, 9, 7, 22), fill=GOLD)
        d.rectangle((24, 9, 27, 22), fill=GOLD)
        d.polygon([(12, 7), (20, 7), (22, 20), (10, 20)], fill=GOLD)
        d.ellipse((10, 19, 22, 23), fill=LIGHT)
        d.rectangle((15, 22, 17, 26), fill=PINK)
        for x in (10, 20):
            d.line((x, 30, x, 35), fill=BLUE, width=2)
            d.ellipse((x - 2, 34, x + 2, 37), fill=BLUE)
    return add_outline(im)


def boss(frame):
    # 48x56 工作像素，最近邻放大；不产生平滑或半透明边缘。
    im = Image.new("RGBA", (48, 56))
    d = ImageDraw.Draw(im)
    dy = -1 if frame in (1, 3, 5) else 0
    d.rectangle((12, 25 + dy, 36, 43 + dy), fill=WOOD)
    d.rectangle((15, 27 + dy, 34, 41 + dy), fill=DARK)
    for x in (17, 30):
        d.ellipse((x - 3, 30 + dy, x + 3, 36 + dy), fill=GOLD)
        d.line((x, 30 + dy, x, 36 + dy), fill=WOOD)
    d.polygon([(17, 29 + dy), (26, 26 + dy), (32, 32 + dy), (30, 45 + dy), (17, 43 + dy)], fill=PINK)
    d.polygon([(24, 29 + dy), (31, 31 + dy), (29, 43 + dy), (24, 43 + dy)], fill=BLUE)
    for y in (32, 37, 42):
        d.ellipse((22, y + dy, 24, y + 2 + dy), fill=GOLD)
    d.polygon([(14, 28 + dy), (33, 28 + dy), (30, 32 + dy), (24, 29 + dy), (18, 32 + dy)], fill=LIGHT)
    d.ellipse((16, 13 + dy, 31, 28 + dy), fill=LIGHT)
    d.rectangle((19, 19 + dy, 21, 21 + dy), fill=DARK)
    d.rectangle((27, 19 + dy, 29, 21 + dy), fill=DARK)
    d.ellipse((22, 21 + dy, 25, 24 + dy), fill=PINK)
    d.line((21, 25 + dy, 27, 25 + dy), fill=DARK)
    d.polygon([(15, 17 + dy), (13, 7 + dy), (8, 9 + dy), (12, 3 + dy), (22, 6 + dy), (25, 14 + dy)], fill=PINK)
    d.polygon([(24, 14 + dy), (28, 4 + dy), (38, 5 + dy), (40, 11 + dy), (35, 9 + dy), (33, 17 + dy)], fill=BLUE)
    for x, y in ((9, 8), (39, 11), (28, 4)):
        d.ellipse((x - 1, y - 1 + dy, x + 1, y + 1 + dy), fill=GOLD)
    for side, x in ((-1, 10), (1, 35)):
        hand_y = (22 if frame in (4, 5, 6) else 33) + dy
        d.line((23 + side * 8, 31 + dy, x, hand_y), fill=BLUE if side > 0 else PINK, width=4)
        d.ellipse((x - 3, hand_y - 2, x + 3, hand_y + 3), fill=LIGHT)
        anchor = (max(0, x - 7), 10 if frame in (4, 6) else 36)
        d.line((x, hand_y, anchor[0] + 4, anchor[1]), fill=GOLD)
        tiny = tool("tool_finger" if side < 0 else ("tool_pad" if frame == 5 else "tool_roller")).resize((10, 10), Image.Resampling.NEAREST)
        im.alpha_composite(tiny, anchor)
    for x, off in ((18, frame % 2), (27, (frame + 1) % 2)):
        d.rectangle((x, 43 + dy, x + 4, 49 + off), fill=BLUE)
        d.rounded_rectangle((x - 2, 48 + off, x + 6, 53 + off), radius=1, fill=PINK)
        d.line((x - 1, 49 + off, x + 5, 49 + off), fill=LIGHT)
    if frame == 7:
        for i in range(4):
            x, y = ((3, 21), (42, 19), (4, 48), (40, 45))[i]
            d.line((x - 2, y, x + 2, y), fill=GOLD)
            d.line((x, y - 2, x, y + 2), fill=GOLD)
    return add_outline(im).resize((96, 112), Image.Resampling.NEAREST)
