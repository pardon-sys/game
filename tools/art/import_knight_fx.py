"""把 codex 生成的特效图（tools/art/src/fx/<名字>.png：1536×1024，3 列 × 2 行、每格 512×512、洋红底 #FF00FF，提示词见同目录 prompts.md）
导成游戏里用的一排帧（assets/generated/fx/<名字>.png：6 帧横排，每帧 SIZE[名字] 像素见方，KnightFx 播）。
做法：洋红底抠成透明（边缘的洋红晕去掉）→ 六帧取同一个外框（动画不跳）→ 补成正方形 → 缩小 → 透明度二值化、减色（像素风）。
用法：python tools/art/import_knight_fx.py [名字 ...]（不写就全部）
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "art" / "src" / "fx"
OUT = ROOT / "assets" / "generated" / "fx"
COLS, ROWS = 3, 2
SIZE = {
    "spear_thrust": 96, "spear_sweep": 64, "spear_impact": 48,
    "curse_burst": 96, "shockwave": 96, "dust_land": 64, "part_break": 64,
    "laugh_drain": 64, "tentacle": 64, "lantern_pillar": 64, "purify": 128,
    "throw_trail": 48, "beacon_light": 64, "trap_land": 64,
}
COLORS = 32


def key_magenta(img):
    """洋红底 → 透明：按离纯洋红 #FF00FF 的距离给透明度（粉色、紫色的光效离得够远，不会被抠掉），
    半透明的边把混进来的洋红减掉"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = ((255 - r) ** 2 + g * g + (255 - b) ** 2) ** 0.5
            if d < 45:
                px[x, y] = (0, 0, 0, 0)
            elif d < 110:
                k = max(0.02, (d - 45) / 65.0)   # 0 = 洋红，1 = 本色
                r2 = (r - 255 * (1 - k)) / k
                b2 = (b - 255 * (1 - k)) / k
                g2 = g / k
                px[x, y] = (max(0, min(255, int(r2))), max(0, min(255, int(g2))), max(0, min(255, int(b2))), int(a * k))
    return img


def frames_of(sheet):
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    out = []
    for r in range(ROWS):
        for c in range(COLS):
            out.append(sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)))
    return out


def union_box(frames):
    box = None
    for f in frames:
        b = f.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if not b:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box


def to_square(box, w, h):
    x0, y0, x1, y1 = box
    side = max(x1 - x0, y1 - y0) + 8
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    x0, y0 = int(cx - side / 2), int(cy - side / 2)
    return (x0, y0, x0 + side, y0 + side)


def pixelate(frame, size):
    small = frame.resize((size, size), Image.BOX)
    px = small.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            if a < 70:
                px[x, y] = (0, 0, 0, 0)
            else:
                # 半透明的保留一点（光效），太淡的直接去掉；颜色按透明度提亮回来
                k = 255.0 / a
                px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255 if a > 170 else 200)
    return small


def quantize(strip):
    alpha = strip.getchannel("A")
    rgb = strip.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def import_one(name):
    src = SRC / (name + ".png")
    if not src.exists():
        print("没有", src)
        return
    size = SIZE.get(name, 64)
    frames = [key_magenta(f) for f in frames_of(Image.open(src))]
    box = union_box(frames)
    if box is None:
        print("全是空的：", name)
        return
    sq = to_square(box, *frames[0].size)
    strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        cell = Image.new("RGBA", (sq[2] - sq[0], sq[3] - sq[1]), (0, 0, 0, 0))
        cell.alpha_composite(f.crop((max(0, sq[0]), max(0, sq[1]), min(f.width, sq[2]), min(f.height, sq[3]))),
                             (max(0, -sq[0]), max(0, -sq[1])))
        strip.alpha_composite(pixelate(cell, size), (i * size, 0))
    OUT.mkdir(parents=True, exist_ok=True)
    quantize(strip).save(OUT / (name + ".png"))
    print("导入", name, "→", size, "px ×", len(frames))


def main():
    names = sys.argv[1:] or sorted(n for n in SIZE if (SRC / (n + ".png")).exists())
    for n in names:
        import_one(n)


if __name__ == "__main__":
    main()
