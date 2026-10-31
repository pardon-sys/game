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
  待机眨眼：图集多两列（第 16 列半闭眼、第 17 列闭眼）；走路眨眼：正面 / 左 / 右走的 4 帧闭眼版在第 18-29 列；直接在每行正面待机帧上合上眼睛（close_eyes），SpriteSheetAnimator 在正面待机时隔几秒插一下。
笑雾之中的骑士：knight_possessed.png（2×4：浮空 / 落地被解脱）→ npcs/knight_possessed.png（80 格）。
用法：python tools/art/import_sprites_px64.py [pink] [blue] [host] [knight] [--preview]（检查图在 tools/.cache/px64/）
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
LAYOUT = {"possessed": [4] * 2, "walk": [4] * 4, "expr": [4] * 2, "damaged": [4] * 5, "helpless": [4] * 2, "magic1": [6] * 3, "magic2": [6] * 3, "attack": [3] * 4}
# 待机眨眼 → 图集第 16 / 17 列：半闭眼 / 闭眼（只有正面待机用）。直接在每行正面待机帧上合上眼睛（close_eyes），和走路图一模一样不跳画风；
# 找不到两只眼睛的行（本来就闭着眼、失控……）复制待机帧（不眨）
BLINK_HALF_COL = 16
BLINK_SHUT_COL = 17
# 走路也眨眼：正面 / 左 / 右走的 4 帧各有一张闭眼版，排在第 18 列以后（下 18-21、左 22-25、右 26-29）；侧面只有一只眼睛
WALK_SHUT_BASE = 18
WALK_BLINK_DIRS = 3
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


def find_eyes(a, need=2):
    """正面待机帧里两只眼睛的瞳孔框 (y0, y1, x0, x1)：头部那一段里、蓝色饱和、不大、颜色深的连通块，中线左右各取最大的一块。"""
    from scipy import ndimage
    al = a[..., 3] > 128
    ys, xs = np.where(al)
    if len(ys) == 0:
        return []
    top, bot = ys.min(), ys.max()
    h = bot - top
    cx = (xs.min() + xs.max()) / 2
    rgb = a[..., :3].astype(float) / 255
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    blue = (rgb[..., 2] > rgb[..., 0] + 0.15) & (rgb[..., 2] >= rgb[..., 1]) & (sat > 0.45) & (mx > 0.3) & al
    band = np.zeros_like(blue)
    band[int(top + h * 0.12):int(top + h * 0.42), :] = True
    lab, n = ndimage.label(blue & band)
    comps = []
    for i in range(1, n + 1):
        yy, xx = np.where(lab == i)
        if len(yy) < 12:
            continue
        if yy.max() - yy.min() + 1 > 30 or xx.max() - xx.min() + 1 > 26 or mx[yy, xx].mean() > 0.8:
            continue
        comps.append((len(yy), yy.min(), yy.max(), xx.min(), xx.max()))
    if need == 1:
        # 侧面：只看得见一只眼睛，取最大的一块
        if not comps:
            return []
        c = max(comps)
        return [(c[1], c[2], c[3], c[4])]
    out = []
    for side in ([c for c in comps if 0 < cx - (c[3] + c[4]) / 2 < 60], [c for c in comps if 0 <= (c[3] + c[4]) / 2 - cx < 60]):
        if side:
            c = max(side)
            out.append((c[1], c[2], c[3], c[4]))
    return out if len(out) == 2 else []


def close_eyes(a, mode, need=2):
    """合上眼睛（mode = half 半闭 / shut 闭眼）：眼睛那一块「像眼睛」的像素（深色描边、蓝色、眼白）盖成下面的皮肤色，再画一道睫毛线（闭眼往下弯）。"""
    a = a.copy()
    for (y0, y1, x0, x1) in find_eyes(a, need):
        reg_s = a[y1 + 2:y1 + 10, x0:x1 + 1, :3].reshape(-1, 3).astype(int)
        ok = reg_s[(reg_s[:, 0] > 190) & (reg_s[:, 0] > reg_s[:, 2] + 10) & (reg_s[:, 1] > 140)]
        skin = np.median(ok, 0).astype(int) if len(ok) else np.array([255, 224, 210])
        by, bx = y0 - 5, x0 - 3
        reg = a[by:y1 + 2, bx:x1 + 4].copy()
        rgb = reg[..., :3].astype(int)
        eyeish = ((rgb.sum(-1) < 330) | (rgb[..., 2] > rgb[..., 0] + 10) | ((rgb.min(-1) > 215) & (rgb[..., 2] >= rgb[..., 0] - 5))) & (reg[..., 3] > 128)
        lash = rgb.reshape(-1, 3)[rgb.sum(-1).argmin()]
        ys, xs = np.where(eyeish)
        if len(ys) == 0:
            continue
        ey0, hgt = ys.min(), ys.max() - ys.min() + 1
        cut = ey0 + (hgt if mode == "shut" else int(hgt * 0.5))
        for yy, xx in zip(ys, xs):
            if yy < cut:
                a[by + yy, bx + xx, :3] = skin
        th = max(2, hgt // 8)
        xl, w = xs.min(), max(1, xs.max() - xs.min())
        ly = ey0 + int(hgt * (0.6 if mode == "shut" else 0.5))
        for x in range(xl, xs.max() + 1):
            t = (x - xl) / w
            dy = int(round((1 - (2 * t - 1) ** 2) * th)) if mode == "shut" else 0
            for k in range(th):
                yy, xx = by + ly + dy + k - th // 2, bx + x
                if a[yy, xx, 3] > 128:
                    a[yy, xx, :3] = lash
    return a


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
    cols = WALK_SHUT_BASE + WALK_BLINK_DIRS * 4
    sheet = Image.new("RGBA", (CELL * cols, CELL * len(EMOTIONS)))
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
        idle = np.asarray(sheet.crop((0, r * CELL, CELL, (r + 1) * CELL)))
        for col, mode in ((BLINK_HALF_COL, "half"), (BLINK_SHUT_COL, "shut")):
            sheet.alpha_composite(Image.fromarray(close_eyes(idle, mode)), (col * CELL, r * CELL))
        for d in range(WALK_BLINK_DIRS):
            for f in range(4):
                src_col = d * 4 + f
                cell = np.asarray(sheet.crop((src_col * CELL, r * CELL, (src_col + 1) * CELL, (r + 1) * CELL)))
                sheet.alpha_composite(Image.fromarray(close_eyes(cell, "shut", 2 if d == 0 else 1)), ((WALK_SHUT_BASE + src_col) * CELL, r * CELL))
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


## 笑雾之中的骑士（源图 knight_possessed.png：上排浮空 4 帧、下排落地被解脱 4 帧）→ npcs/knight_possessed.png，4×2 格 KNIGHT_CELL
KNIGHT_CELL = 80
KNIGHT_H = 72


def build_knight():
    raw = frames("knight", "possessed")
    allf = [f for row in raw for f in row]
    s = float(np.median([f.height for f in raw[0]])) / KNIGHT_H
    out = Image.new("RGBA", (KNIGHT_CELL * 4, KNIGHT_CELL * 2))
    for r, row in enumerate(raw):
        for c, f in enumerate(row):
            out.alpha_composite(place(snap(f, s), KNIGHT_CELL), (c * KNIGHT_CELL, r * KNIGHT_CELL))
    (OUT / "npcs").mkdir(exist_ok=True)
    out.save(OUT / "npcs" / "knight_possessed.png")
    print("骑士（笑雾之中）：像素块 %.2f，npcs/knight_possessed.png" % s)


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
    if "knight" in want:
        build_knight()
        want.remove("knight")
    for c in want:
        if (SRC / ("%s_walk.png" % CHARS[c][0])).exists():
            build(c)
            if "--preview" in sys.argv:
                preview(c)
        else:
            print("没有源图：", c)


if __name__ == "__main__":
    main()
