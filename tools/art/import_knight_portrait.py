"""骑士的对话立绘：tools/art/src/knight/knight_portrait_source.png（codex 内置 image_gen 生成，透明底，见同目录 prompts.md）
→ assets/generated/npc_portraits/knight.png（半身、像素化，228×304，和队长 / 市场监督 / 派对主人的立绘同一套处理）。
用法：python tools/art/import_knight_portrait.py
"""
import numpy as np
from PIL import Image

from import_princess2 import OUT, PORTRAIT_CELL, ROOT, Pixelizer, body_bbox

SRC = ROOT / "tools/art/src/knight/knight_portrait_source.png"
## 半身取到人物高度的多少（源图本来就是半身偏下一点）、取景中心（占原图宽度的比例：头盔偏左）
WAIST = 0.66
CX = 0.42


def main():
    cw, ch = PORTRAIT_CELL
    full = Image.open(SRC).convert("RGBA")
    a = np.asarray(full.getchannel("A"))
    full = Image.fromarray(np.dstack([np.asarray(full)[:, :, :3], np.where(a >= 128, 255, 0).astype(np.uint8)]), "RGBA")
    x0, y0, x1, y1 = body_bbox(full)
    bh = y1 - y0
    top, bottom = max(0, y0 - round(0.01 * bh)), y0 + round(WAIST * bh)
    w = round((bottom - top) * cw / ch)
    cx = round(CX * full.width)
    left = max(0, min(full.width - w, cx - w // 2))
    crop = full.crop((left, top, left + w, bottom))
    # 面罩挡着脸：不用脸部特征优先（空框），否则五官取色会取到盔甲的碎色块
    face = [0.0, 0.0, 0.0, 0.0]
    px = Pixelizer([crop], 96, [face])
    small = px(crop, min((ch - 4) / crop.height, (cw - 4) / crop.width), face, sharpen=(1.0, 60))
    cell = Image.new("RGBA", (cw, ch))
    cell.alpha_composite(small, ((cw - small.width) // 2, ch - small.height))
    (OUT / "npc_portraits").mkdir(exist_ok=True)
    cell.save(OUT / "npc_portraits" / "knight.png")
    print("骑士立绘：", OUT / "npc_portraits" / "knight.png", cell.size)


if __name__ == "__main__":
    main()
