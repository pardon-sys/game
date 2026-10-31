"""精细像素精灵图（64 格）：codex 直接画的像素风源图（tools/art/src/px64/，提示词同目录 prompts.md）→ 游戏用图集。不做程序像素化：
  1. 切帧：沿用 import_sprites_v2.Sheet（白底，按「行数 × 每行帧数」均分，切线挪到最空的列 / 行，每格只留人物和贴着的特效）；
  2. 直接导入：源图本身就是像素风，不再压成「一个色块一个像素」——只按人物身体高度把各张源表统一到 BODY_H（缩放比接近 1，最近邻，
     不平滑、不重新量化调色板），透明度按一半二值化；
  3. 排进图集：脚底居中贴着格子底边（留 1 像素），比格子还大时按最近邻缩小（一般用不到）。
输出（assets/generated/）：<角色>_hd.png（行走 256 格，11 行 × 16 列，状态顺序 princess_visuals.json，方向 下 / 左 / 右 / 上 各 4 帧）、
  <角色>_magic_hd.png（384 格，6 × 6）、派对主人另有 bonfire_host_attack_hd.png（256 格，11 行 × 12 列，每行同一套攻击帧）。
游戏里 SpriteSheetAnimator 在「角色画风：精细像素」时换上这些图（Sprite 缩到 1/8 再放大 HD_ENLARGE 倍、线性过滤），缺图用原来的 32 格像素图。
源图（每个角色）：<p>_walk 4×4（下 / 左 / 右 / 上走路）、<p>_expr 2×4（站着的表情：普通 开心 生气 难过 / 惊讶 害羞 憋笑 大笑）、
  <p>_damaged 5×4（战损走路四向 + 第 5 行战损憋笑正面）、<p>_helpless 2×4（失控一 坐地笑 / 失控二 躺地蹬脚）、<p>_magic1 / _magic2 3×6（魔法姿态）。
用法：python tools/art/import_sprites_px64.py [pink] [blue] [host] [--preview]（检查图在 tools/.cache/px64/）
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import import_sprites_v2 as v2
from import_princess2 import EMOTIONS, MAGIC, OUT, ROOT, body_bbox

SRC = ROOT / "tools/art/src/px64"
PREVIEW = ROOT / "tools/.cache/px64"
CELL = 256
MAGIC_CELL = 384
## 站着 / 施法时身体的高度（像素，256 格里脚底留 4 像素，头顶留给发饰）；失控（坐 / 躺）放进的宽高。
## 源图里人物本来就是两百多像素高的像素画：按这个高度统一（缩放比接近 1），不把一个色块压成一个像素
BODY_H = 216
HELPLESS_W = 248
HELPLESS_H = 200
WALK_DIRS = ["down", "left", "right", "up"]
# 每种源表：行数 × 每行帧数
LAYOUT = {"walk": [4] * 4, "expr": [4] * 2, "damaged": [4] * 5, "helpless": [4] * 2, "magic1": [6] * 3, "magic2": [6] * 3, "attack": [3] * 4}
# 站着的表情（expr 表的格子）→ 状态
EXPR = {"normal": 0, "happy": 1, "angry": 2, "sad": 3, "surprise": 4, "shy": 5, "giggle": 6}
# 魔法：magic1 三行 + magic2 三行 = magic_order
MAGIC_ROWS = [("magic1", 0), ("magic1", 1), ("magic1", 2), ("magic2", 0), ("magic2", 1), ("magic2", 2)]
# 角色 → 源图前缀、输出文件名
CHARS = {"pink": ("pink", "princess"), "blue": ("blue", "princess_blue"), "host": ("host", "bonfire_host")}


def _sheet(prefix, kind):
    key = "px_%s_%s" % (prefix, kind)
    v2.SHEETS[key] = {"path": str(SRC / ("%s_%s.png" % (prefix, kind))), "rows": [[n] for n in LAYOUT[kind]]}
    return key


def frames(prefix, kind):
    """[[行的每一帧 RGBA]]"""
    key = _sheet(prefix, kind)
    s = v2.sheet(key)
    return [[s.frame(r, 0, i) for i in range(n)] for r, n in enumerate(LAYOUT[kind])]


def sheet_scale(kind, imgs):
    """这张源表一个「像素」有多大（屏幕像素，可以带小数）：生成图的像素块带细小噪点，没法逐块量，
    按人物身体高度换算——站着 / 施法的身体高 BODY_H 像素；失控（坐 / 躺）的放得进 HELPLESS_W × HELPLESS_H。"""
    if kind == "helpless":
        return max(float(np.median([im.width for im in imgs])) / HELPLESS_W, float(np.median([im.height for im in imgs])) / HELPLESS_H)
    # 人物本体（最大连通块）的高度：表情图的特效 / 爱心不算进去；用较高的那一半取中位数（个别帧被特效切开时不算矮）
    hs = sorted(b[3] - b[1] for b in (body_bbox(im) for im in imgs))
    return float(np.median(hs[len(hs) // 2:])) / BODY_H


def snap(im, s):
    """按块中心取样（最近邻缩小：每个目标像素取它那一块正中间的颜色），不平滑、不重新量化；透明度按一半二值化。"""
    out = im.resize((max(1, round(im.width / s)), max(1, round(im.height / s))), Image.NEAREST)
    a = np.asarray(out).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    out = Image.fromarray(a, "RGBA")
    return out.crop(out.getbbox()) if out.getbbox() else out


def place(im, cell, margin=4):
    if im.height > cell - margin or im.width > cell:
        k = min((cell - margin) / im.height, cell / im.width)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
    c = Image.new("RGBA", (cell, cell))
    c.alpha_composite(im, ((cell - im.width) // 2, cell - im.height - margin))
    return c


def build(char):
    prefix, out_name = CHARS[char]
    src = {k: frames(prefix, k) for k in ("walk", "expr", "damaged", "helpless", "magic1", "magic2") if (SRC / ("%s_%s.png" % (prefix, k))).exists()}
    scales = {k: sheet_scale(k, [f for row in rows for f in row]) for k, rows in src.items()}
    snapped = {k: [[snap(f, scales[k]) for f in row] for row in rows] for k, rows in src.items()}
    s = scales["walk"]
    W, E, D, H = snapped["walk"], snapped["expr"], snapped["damaged"], snapped["helpless"]
    sheet = Image.new("RGBA", (CELL * 16, CELL * len(EMOTIONS)))
    for r, name in enumerate(EMOTIONS):
        for d in range(4):
            for f in range(4):
                if name in EXPR or name == "giggle":
                    img = E[EXPR[name] // 4][EXPR[name] % 4] if (d == 0 and f == 0) else W[d][f]
                elif name == "damaged":
                    img = D[d][f]
                elif name == "damaged_giggle":
                    img = D[4][f] if d == 0 else D[d][f]
                elif name == "helpless_1":
                    img = H[0][f]
                else:
                    img = H[1][f]
                sheet.alpha_composite(place(img, CELL), ((d * 4 + f) * CELL, r * CELL))
    sheet.save(OUT / ("%s_hd.png" % out_name))
    if "magic1" in snapped and "magic2" in snapped:
        magic = Image.new("RGBA", (MAGIC_CELL * 6, MAGIC_CELL * len(MAGIC)))
        for r, (k, row) in enumerate(MAGIC_ROWS):
            for c in range(6):
                magic.alpha_composite(place(snapped[k][row][c], MAGIC_CELL), (c * MAGIC_CELL, r * MAGIC_CELL))
        magic.save(OUT / ("%s_magic_hd.png" % out_name))
    if char == "host" and (SRC / "host_attack.png").exists():
        araw = frames(prefix, "attack")
        sa = sheet_scale("attack", [f for row in araw for f in row])
        att = [[snap(f, sa) for f in row] for row in araw]
        sheet_a = Image.new("RGBA", (CELL * 12, CELL * len(EMOTIONS)))
        for r in range(len(EMOTIONS)):
            for d in range(4):
                for f in range(3):
                    sheet_a.alpha_composite(place(att[d][f], CELL), ((d * 3 + f) * CELL, r * CELL))
        sheet_a.save(OUT / "bonfire_host_attack_hd.png")
    print("%s：每张源表的像素块 %s，%s_hd.png%s" % (char, {k: round(v, 2) for k, v in scales.items()}, out_name, "、magic" if "magic1" in snapped else ""))


def preview(char):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    out_name = CHARS[char][1]
    for n in ("%s_hd.png" % out_name, "%s_magic_hd.png" % out_name):
        p = OUT / n
        if p.exists():
            im = Image.open(p)
            bg = Image.new("RGBA", im.size, (110, 120, 130, 255))
            bg.alpha_composite(im)
            bg.resize((im.width * 2, im.height * 2), Image.NEAREST).save(PREVIEW / n)


def main():
    want = [a for a in sys.argv[1:] if not a.startswith("--")] or list(CHARS)
    for c in want:
        if (SRC / ("%s_walk.png" % CHARS[c][0])).exists():
            build(c)
            if "--preview" in sys.argv:
                preview(c)
        else:
            print("没有源图：", c)


if __name__ == "__main__":
    main()
