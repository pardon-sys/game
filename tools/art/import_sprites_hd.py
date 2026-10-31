"""高清（非像素）精灵图：粉色 / 蓝色公主的行走图、魔法图（派对主人的在 import_bonfire_host.py --hd）。原像素图一张都不动，只多写一份 *_hd.png。

和像素版（import_sprites_v2.py）用同一批手绘源图、同一套切帧和「哪一帧当哪个状态」映射（PINK / BLUE / *_MAGIC），区别：
  - 不做像素化：平滑缩小（预乘 alpha 的 LANCZOS，边缘不发白），保留原画的柔和上色；
  - 格子放大 HD 倍：行走 32 → 96、魔法 48 → 144（游戏里 Sprite 缩到 1/HD 显示，显示大小和像素版一样，像立绘一样多倍像素密度）；
  - 粉色公主的正常行走也用新源表（像素版那几行沿用第一版小人）；普通憋笑用平常装束的「开心」那组；战损 / 战损憋笑两行按立绘重画（tools/art/src/hd_sprites/pink_damaged.png，
    codex 生成，提示词同目录 prompts.md；没有这张图时退回 new_princess3.png 的那两行）。
输出（assets/generated/）：princess_hd.png / princess_blue_hd.png（96 格，11 行 × 16 列），princess_magic_hd.png / princess_blue_magic_hd.png（144 格，6 × 6）。
游戏里的切换：SpriteSheetAnimator 按 UserSettings.art_style 找同名的 *_hd.png（P 键菜单「角色画风」），缺图时用像素版。
用法：python tools/art/import_sprites_hd.py [--preview]（检查图在 tools/.cache/sprites_hd/）
"""
import sys

import numpy as np
from PIL import Image

import import_sprites_v2 as v2
from import_princess2 import EMOTIONS, FRAME, MAGIC, OUT, ROOT, SPRITE_FIT, body_bbox

HD = 3
CELL = FRAME * HD
FIT = SPRITE_FIT * HD
MAGIC_CELL = v2.MAGIC_FRAME * HD
PREVIEW = ROOT / "tools/.cache/sprites_hd"
PINK_DAMAGED = ROOT / "tools/art/src/hd_sprites/pink_damaged.png"


def smooth(img, scale):
    """预乘 alpha 再缩放，透明边不会混进白底色。"""
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    return img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")


def _pink_mapping():
    m = dict(v2.PINK)
    # 普通憋笑：new_princess3 那一行穿的是战损的衣服，高清版换成平常装束的「开心」那组（闭眼笑）
    m["giggle"] = v2.PINK["happy"]
    if PINK_DAMAGED.exists():
        v2.SHEETS["pd"] = {"path": str(PINK_DAMAGED),
                           "rows": [[13], [13]]}
        for name, row in (("damaged", 0), ("damaged_giggle", 1)):
            left = [("pd", row, 0, i) for i in (4, 5, 6, 5)]
            m[name] = {"down": [("pd", row, 0, i) for i in range(4)], "left": left,
                       "right": [k + ("m",) for k in left], "up": [("pd", row, 0, i) for i in (8, 9, 10, 11)]}
    return m


def build_walk(mapping, out_name):
    cells = {}
    for name in EMOTIONS:
        for d, dn in enumerate(v2.WALK_DIRS):
            for f, ref in enumerate(mapping[name][dn]):
                cells[name, d * 4 + f] = v2.get_frame(ref)
    # 同一方向里来源不同的帧（蓝色公主正面第 0 帧是表情帧）：缩到同方向其它帧的高度
    for name in EMOTIONS:
        for d in range(4):
            srcs = [r[:2] for r in mapping[name][v2.WALK_DIRS[d]]]
            major = max(set(srcs), key=srcs.count)
            hs = sorted(cells[name, d * 4 + f].height for f in range(4) if srcs[f] == major)
            for f in range(4):
                if srcs[f] != major:
                    img = cells[name, d * 4 + f]
                    h = hs[len(hs) // 2]
                    cells[name, d * 4 + f] = img.resize((max(1, round(img.width * h / img.height)), h), Image.LANCZOS)
    out = Image.new("RGBA", (CELL * 16, CELL * len(EMOTIONS)))
    for row, name in enumerate(EMOTIONS):
        group = [cells[name, c] for c in range(16)]
        max_w = (CELL - 6 * HD) if name in v2.NO_CROP else (CELL + 6 * HD)
        scale = min(FIT / max(p.height for p in group), max_w / max(p.width for p in group))
        for c in range(16):
            small = smooth(cells[name, c], scale)
            if small.width > CELL or small.height > CELL:
                small = small.crop((max(0, (small.width - CELL) // 2), max(0, small.height - CELL),
                                    max(0, (small.width - CELL) // 2) + min(CELL, small.width), small.height))
            out.alpha_composite(small, (c * CELL + (CELL - small.width) // 2, row * CELL + CELL - small.height - HD))
    out.save(OUT / out_name)
    return out


def build_magic(sheet_key, rows, walk, out_name):
    """魔法：每种状态 6 帧，所有帧同一缩放（第一种状态第 1 帧的人物本体 = 行走帧人物高度），脚底对齐格子底边。"""
    cells = {}
    for name in MAGIC:
        r = rows[name]
        n = v2.SHEETS[sheet_key]["rows"][r if isinstance(r, int) else r[0]][0]
        if not isinstance(r, int):
            r, n = r
        picks = [round(k * (n - 1) / (v2.MAGIC_FRAMES - 1)) for k in range(v2.MAGIC_FRAMES)]
        for c, i in enumerate(picks):
            cells[name, c] = v2.sheet(sheet_key).frame(r, 0, i)
    alpha = np.asarray(walk.crop((0, 0, CELL, CELL)).getchannel("A"))
    ys = np.where(alpha.any(1))[0]
    target = ys[-1] - ys[0] + 1 - 2 * HD
    ref = body_bbox(cells[MAGIC[0], 0])
    scale = target / (ref[3] - ref[1])
    out = Image.new("RGBA", (MAGIC_CELL * v2.MAGIC_FRAMES, MAGIC_CELL * len(MAGIC)))
    for row, name in enumerate(MAGIC):
        for c in range(v2.MAGIC_FRAMES):
            img = cells[name, c]
            x0, y0, x1, y1 = body_bbox(img)
            small = smooth(img, scale)
            cx = round((x0 + x1) / 2 * scale)
            bottom = round(y1 * scale) + HD
            cell = Image.new("RGBA", (MAGIC_CELL, MAGIC_CELL))
            cell.paste(small, (MAGIC_CELL // 2 - cx, MAGIC_CELL - bottom), small)
            out.alpha_composite(cell, (c * MAGIC_CELL, row * MAGIC_CELL))
    out.save(OUT / out_name)
    return out


def preview():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for name in ("princess_hd.png", "princess_blue_hd.png", "princess_magic_hd.png", "princess_blue_magic_hd.png"):
        im = Image.open(OUT / name)
        bg = Image.new("RGBA", im.size, (110, 120, 130, 255))
        bg.alpha_composite(im)
        bg.save(PREVIEW / name)


def main():
    walk = build_walk(_pink_mapping(), "princess_hd.png")
    build_magic("np4", v2.PINK_MAGIC, walk, "princess_magic_hd.png")
    bwalk = build_walk(v2.BLUE, "princess_blue_hd.png")
    build_magic("b3", v2.BLUE_MAGIC, bwalk, "princess_blue_magic_hd.png")
    if "--preview" in sys.argv:
        preview()
    print("高清精灵图：公主 / 蓝色公主各 %d 种状态 x 16 帧（%d 格），魔法 %d 种 x %d 帧（%d 格）%s"
          % (len(EMOTIONS), CELL, len(MAGIC), v2.MAGIC_FRAMES, MAGIC_CELL, "；粉色战损用重画的源表" if PINK_DAMAGED.exists() else ""))


if __name__ == "__main__":
    main()
