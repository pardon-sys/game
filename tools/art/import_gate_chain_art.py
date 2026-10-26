"""穿链委托的图片（小游戏里不另画脚底图，道具直接挠趴着的公主人物图）：tools/art/src/gate_chain/（codex 内置 image_gen 生成，见同目录 prompts.md）→ assets/generated/after/。
  gate_wall_full / half / broken.png  失败小剧场里倒塌的墙，底下露出一双童趣小白脚（WALL_SIZE，小剧场的道具演员 rubble_*）
处理：去掉低透明度的光晕（alpha < ALPHA_CUT 透明）→ 三张按同一个框裁边 → 缩小（BOX 取平均）→ 减色 → 透明度二值化。
用法：python tools/art/import_gate_chain_art.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/art/src/gate_chain"
OUT = ROOT / "assets/generated/after"
ALPHA_CUT = 200
COLORS = 24
## 墙：脚趾豆的粉色要留住，尺寸和颜色数都比一般道具多
WALL_SIZE = (80, 80)
WALL_COLORS = 64


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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 三张墙用同一个裁剪框（三张的并集）：缩放一致，压在底下的脚不会在三张之间跳
    walls = {n: Image.open(SRC / ("wall_%s.png" % n)).convert("RGBA") for n in ("full", "half", "broken")}
    for im in walls.values():
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= ALPHA_CUT else 0))
    boxes = [im.getchannel("A").getbbox() for im in walls.values()]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    for n, im in walls.items():
        shrink(im.crop(box), WALL_SIZE, WALL_COLORS).save(OUT / ("gate_wall_%s.png" % n))
    print("倒塌的墙：", OUT)


if __name__ == "__main__":
    main()
