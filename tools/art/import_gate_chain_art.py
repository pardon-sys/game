"""穿链委托的图片：tools/art/src/gate_chain/（codex 内置 image_gen 生成，见同目录 prompts.md）→ assets/generated/after/。
  gate_chain_soles.png  槽口外的两只光脚（童趣像素风；转 90°：脚趾朝右；SOLE_SIZE + 一圈描边）。源图只有描边 / 白皮肤 / 粉脚垫三种颜色：
                        每个源像素先归类，再按格子里哪类多缩小（不取平均，形状不会糊），用固定的三色输出，最后补描边。
  gate_wall_full / half / broken.png  失败小剧场里倒塌的墙，底下露出一双童趣小白脚（WALL_SIZE，小剧场的道具演员 rubble_*）
处理：去掉低透明度的光晕（alpha < ALPHA_CUT 透明）→ 按不透明部分裁边 → 缩小（BOX 取平均）→ 减色 → 透明度二值化。
用法：python tools/art/import_gate_chain_art.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/art/src/gate_chain"
OUT = ROOT / "assets/generated/after"
ALPHA_CUT = 200
COLORS = 24
SOLE_SIZE = (20, 28)
## 墙：脚趾豆的粉色要留住，尺寸和颜色数都比一般道具多
WALL_SIZE = (80, 80)
WALL_COLORS = 64
PINK_WEIGHT = 1.6
## 三色调色板：描边、白皮肤、粉脚垫（和源图一致）
SOLE_PALETTE = [(70, 30, 34, 255), (255, 240, 236, 255), (246, 160, 176, 255)]


def clean(path):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= ALPHA_CUT else 0)
    im.putalpha(a)
    return im.crop(a.getbbox())


def shrink(im, size, colors=COLORS):
    """等比缩到 size 以内，居中放进 size 的透明画布；颜色减到 colors 种，透明度只留全透 / 不透。"""
    w, h = im.size
    k = min(size[0] / w, size[1] / h)
    small = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.BOX)
    alpha = small.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    rgb = small.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE).convert("RGB")
    rgb.putalpha(alpha)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(rgb, ((size[0] - rgb.width) // 2, size[1] - rgb.height))
    return canvas


def outline(im, col=(70, 34, 34, 255)):
    """不透明部分外面补一圈 1 像素的描边（缩小以后原图的描边会被平均掉）。"""
    out = im.copy()
    src, dst = im.load(), out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = col
    return out


def sole_class(px):
    """源像素归类：0 描边（深）、1 白皮肤、2 粉脚垫；-1 透明。"""
    r, g, b, a = px
    if a < ALPHA_CUT:
        return -1
    if r + g + b < 260:
        return 0
    return 1 if g > 200 else 2


def shrink_classes(im, size):
    """缩小：源图的描边先当白皮肤（脚趾之间的粗描边缩小后会把脚趾糊成一团），每格比白 / 粉谁多（粉色乘 PINK_WEIGHT，
    脚趾豆才留得住）；透明超过一半就透明。描边最后由 outline 沿轮廓补。"""
    src = im.load()
    w, h = im.size
    out = Image.new("RGBA", size)
    dst = out.load()
    for ty in range(size[1]):
        for tx in range(size[0]):
            counts = [0, 0, 0]  # 透明 / 白 / 粉
            for y in range(ty * h // size[1], (ty + 1) * h // size[1], 3):
                for x in range(tx * w // size[0], (tx + 1) * w // size[0], 3):
                    k = sole_class(src[x, y])
                    counts[0 if k < 0 else (2 if k == 2 else 1)] += 1
            if counts[0] * 2 >= sum(counts):
                continue
            dst[tx, ty] = SOLE_PALETTE[2] if counts[2] * PINK_WEIGHT >= counts[1] else SOLE_PALETTE[1]
    return out


def outline(im, col=(70, 34, 34, 255)):
    """不透明部分外面补一圈 1 像素的描边（缩小以后原图的描边会被平均掉）。"""
    out = im.copy()
    src, dst = im.load(), out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = col
    return out


def sole_class(px):
    """源像素归类：0 描边（深）、1 白皮肤、2 粉脚垫；-1 透明。"""
    r, g, b, a = px
    if a < ALPHA_CUT:
        return -1
    if r + g + b < 260:
        return 0
    return 1 if g > 200 else 2


def shrink_classes(im, size):
    """按格子里最多的那一类缩小（透明格超过一半就透明）。"""
    src = im.load()
    w, h = im.size
    out = Image.new("RGBA", size)
    dst = out.load()
    for ty in range(size[1]):
        for tx in range(size[0]):
            x0, x1 = tx * w // size[0], max(tx * w // size[0] + 1, (tx + 1) * w // size[0])
            y0, y1 = ty * h // size[1], max(ty * h // size[1] + 1, (ty + 1) * h // size[1])
            counts = [0, 0, 0, 0]
            for y in range(y0, y1, max(1, (y1 - y0) // 8)):
                for x in range(x0, x1, max(1, (x1 - x0) // 8)):
                    counts[sole_class(src[x, y]) + 1] += 1
            best = max(range(4), key=lambda i: counts[i])
            if best > 0 or counts[0] * 2 < sum(counts):
                dst[tx, ty] = SOLE_PALETTE[max(range(1, 4), key=lambda i: counts[i]) - 1]
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    soles = clean(SRC / "soles.png").rotate(-90, expand=True)
    outline(shrink_classes(soles, SOLE_SIZE).crop((-1, -1, SOLE_SIZE[0] + 1, SOLE_SIZE[1] + 1)), SOLE_PALETTE[0]).save(OUT / "gate_chain_soles.png")
    # 三张墙用同一个裁剪框（三张的并集）：缩放一致，压在底下的脚不会在三张之间跳
    walls = {n: Image.open(SRC / ("wall_%s.png" % n)).convert("RGBA") for n in ("full", "half", "broken")}
    for im in walls.values():
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= ALPHA_CUT else 0))
    boxes = [im.getchannel("A").getbbox() for im in walls.values()]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    for n, im in walls.items():
        shrink(im.crop(box), WALL_SIZE, WALL_COLORS).save(OUT / ("gate_wall_%s.png" % n))
    print("穿链的脚底 / 倒塌的墙：", OUT)


if __name__ == "__main__":
    main()
