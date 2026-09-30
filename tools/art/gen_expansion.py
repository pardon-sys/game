"""扩展内容的像素占位图（楼层扩充、第三层、魔法、组合技）。

输出到 assets/generated/：
  weapon_rack.png   16x16      可打碎的武器架（第一层兵器库）
  secret_crack.png  16x16      暗墙被火光照出的裂缝（叠在墙顶上）
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


def gen_floor_expansion():
    weapon_rack().save(OUT / "weapon_rack.png")
    secret_crack().save(OUT / "secret_crack.png")


def main():
    gen_floor_expansion()


if __name__ == "__main__":
    main()
