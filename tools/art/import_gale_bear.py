"""导入 imagegen 生成的 4×2 熊统领动作图；仅切帧、最近邻缩放、脚底对齐。

源图和生成提示保留在 src/，不重绘熊。使用 test_for_master 环境执行。
"""
from pathlib import Path
from collections import deque

from PIL import Image

ROOT = Path(__file__).resolve().parent / "src"
SOURCE = ROOT / "gale_bear_generated_sheet.png"
FRAME = (96, 112)


def sprite_bounds(sheet):
    """按实色连通轮廓找八个角色，避免生成图的盾沿跨过理论网格几像素而被裁掉。"""
    width, height = sheet.size
    mask = bytearray(sheet.getchannel("A").point(lambda alpha: 255 if alpha > 180 else 0).tobytes())
    parts = []
    for start in range(width * height):
        if not mask[start]:
            continue
        mask[start] = 0
        pending = deque([start])
        x0 = x1 = start % width
        y0 = y1 = start // width
        count = 0
        while pending:
            point = pending.popleft()
            x, y = point % width, point // width
            count += 1
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if 0 <= x + dx < width and 0 <= y + dy < height:
                        index = point + dy * width + dx
                        if mask[index]:
                            mask[index] = 0
                            pending.append(index)
        if count > 1000:
            box = (max(0, x0 - 2), max(0, y0 - 2), min(width, x1 + 3), min(height, y1 + 3))
            parts.append((count, box))
    if len(parts) != 8:
        raise ValueError("需要八个完整角色轮廓，实际找到 %d 个" % len(parts))
    return sorted((box for _, box in parts), key=lambda box: ((box[1] + box[3]) // height, box[0]))


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.width % 4 or sheet.height % 2:
        raise ValueError("源图必须是等格 4 列、2 行")
    bounds = sprite_bounds(sheet)
    scale = min((FRAME[0] - 4) / max(b[2] - b[0] for b in bounds),
                (FRAME[1] - 4) / max(b[3] - b[1] for b in bounds))
    for index, box in enumerate(bounds):
        sprite = sheet.crop(box)
        # 生成图的第二步行姿势面向右；统一朝向，游戏仍通过 flip_h 转身。
        if index == 3:
            sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
        sprite = sprite.resize(size, Image.Resampling.NEAREST)
        result = Image.new("RGBA", FRAME)
        result.alpha_composite(sprite, ((FRAME[0] - size[0]) // 2, FRAME[1] - 2 - size[1]))
        result.save(ROOT / ("gale_bear_%d.png" % index))
    print("熊统领：imagegen 源图导入 8 帧，96×112，保留透明 alpha")


if __name__ == "__main__":
    main()
