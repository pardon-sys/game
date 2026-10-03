"""第二版精灵图导入：用户重画的公主 / 蓝色公主精灵图（白底、没有表格线）→ 游戏用像素图集。

源图（保持不动）：
  additional_princess/new_princess2.png  公主 6 种基础状态（普通 开心 哭泣 惊讶 生气 害羞）：3 大行 x 2 块，
                                         每块上行 = 正面 4 + 朝左 5，下行 = 朝右 4 + 背面 5
  additional_princess/new_princess3.png  战损 / 普通憋笑 / 战损憋笑（正面 4 + 侧面 4 + 背面 5）、失控一（7 帧）、失控二（8 帧）
  additional_princess/new_princess4.png  魔法 5 行 x 6 帧（普通吟诵 普通释放 战损吟诵 战损憋笑吟诵 战损释放），只有正面
  blue_princess/princess_blue1.png       蓝色公主：第 1 行 6 个表情（各 1 帧），正面 5 / 背面 5 / 朝左 4 / 朝右 4 帧走路
  blue_princess/princess_blue2.png       战损 11 / 憋笑 11（各方向混在一行）/ 战损憋笑 7 / 失控一 7 / 失控二 6
  blue_princess/princess_blue3.png       战损魔法 5 行：战损吟诵 9 / 战损释放 8 / 战损憋笑吟诵 9 / 战损释放（第二种）9 / 战损憋笑释放 7
输出（assets/generated/，格式和第一版一样）：
  princess.png / princess_blue.png              32px 一帧，11 行（princess_visuals.json 的 order）x 16 列（下 / 左 / 右 / 上 各 4 帧）
  princess_magic.png / princess_blue_magic.png  48px 一帧，6 行（magic_order）x 6 列（只有正面，不分方向）
切帧：去白底后按「已知的行数 / 每行帧数」均分，切线挪到附近最空的那一列 / 行（人物的头发互相挨着时投影切不开）；
每个格子只留最大的人物块和挨着它的特效（爱心、汗滴），伸进格子的邻居碎片去掉。
哪一帧当哪个状态、哪个方向写在下面的 PINK / BLUE 映射里；没有的方向用另一侧镜像（"L3m" = 左边第 3 帧镜像）。
用法：python tools/art/import_sprites_v2.py [--preview]（检查图在 tools/.cache/sprites_v2/）
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps
from scipy import ndimage

from import_princess2 import (EMOTIONS, FRAME, MAGIC, OUT, ROOT, SPRITE_FIT, SpritePixelizer, _clean_magic_source,
                              _face_box_from_body, body_bbox, classify, finish_magic, key_background)

PREVIEW = ROOT / "tools/.cache/sprites_v2"
MAGIC_FRAME = 48
MAGIC_FRAMES = 6
WALK_DIRS = ["down", "left", "right", "up"]

# —— 源图的格子：每行 [帧数, ...]（同一行里分几组时写成列表的列表：每组占的宽度比例按组内帧数） ——
SHEETS = {
    "np2": {"path": "additional_princess/new_princess2.png", "rows": [[4, 5, 4, 5]] * 6},
    "np3": {"path": "additional_princess/new_princess3.png", "rows": [[13], [13], [13], [7], [8]]},
    "np4": {"path": "additional_princess/new_princess4.png", "rows": [[6]] * 5},
    "b1": {"path": "blue_princess/princess_blue1.png", "rows": [[6], [5], [5], [4], [4]]},
    "b2": {"path": "blue_princess/princess_blue2.png", "rows": [[11], [11], [7], [7], [6]]},
    "b3": {"path": "blue_princess/princess_blue3.png", "rows": [[9], [8], [9], [9], [7]]},
}


def _np2(state):
    """new_princess2 的第 state 块（0..5）：块的上行 = 正面 4 + 朝左 5，下行 = 朝右 4 + 背面 5。"""
    big, col = divmod(state, 2)
    top, bot = big * 2, big * 2 + 1
    g = col * 2   # 这一块在行里是第 g、g+1 组
    return {"down": [("np2", top, g, i) for i in range(4)],
            "left": [("np2", top, g + 1, i) for i in (0, 1, 2, 3)],
            "right": [("np2", bot, g, i) for i in range(4)],
            "up": [("np2", bot, g + 1, i) for i in (0, 1, 2, 3)]}


def _np3(row):
    """new_princess3 前三行：正面 0-3、侧面 4-7（4-6 朝左，7 朝右）、背面 8-12。右边用左边镜像。"""
    left = [("np3", row, 0, i) for i in (4, 5, 6, 5)]
    return {"down": [("np3", row, 0, i) for i in range(4)], "left": left,
            "right": [k + ("m",) for k in left], "up": [("np3", row, 0, i) for i in (8, 9, 10, 11)]}


def _same(frames):
    return {d: frames for d in WALK_DIRS}


# 公主：基础 6 种（new_princess2 的块顺序 普通 开心 哭泣 惊讶 生气 害羞 → EMOTIONS 顺序）
NP2_ORDER = {"normal": 0, "happy": 1, "sad": 2, "surprise": 3, "angry": 4, "shy": 5}
PINK = {name: _np2(i) for name, i in NP2_ORDER.items()}
PINK.update({"damaged": _np3(0), "giggle": _np3(1), "damaged_giggle": _np3(2),
             "helpless_1": _same([("np3", 3, 0, i) for i in (0, 2, 4, 6)]),
             "helpless_2": _same([("np3", 4, 0, i) for i in (1, 3, 5, 7)])})
PINK_MAGIC = {"chant": 0, "burst": 1, "damaged_chant": 2, "damaged_giggle_chant": 3, "damaged_burst": 4, "damaged_giggle_burst": 4}

# 蓝色公主：基础走路来自 princess_blue1（正面 第 2 行、背面 第 3 行、朝左 第 4 行、朝右 第 5 行）；
# 6 种基础表情：正面第 0 帧（站着时显示）换成第 1 行对应的表情帧
B1_EXPR = {"normal": 0, "happy": 1, "sad": 2, "surprise": 3, "shy": 4, "angry": 5}
B_WALK = {"down": [("b1", 1, 0, i) for i in (0, 1, 2, 3)], "up": [("b1", 2, 0, i) for i in (0, 1, 2, 3)],
          "left": [("b1", 3, 0, i) for i in range(4)], "right": [("b1", 4, 0, i) for i in range(4)]}


def _blue_base(name):
    d = {k: list(v) for k, v in B_WALK.items()}
    d["down"][0] = ("b1", 0, 0, B1_EXPR[name])
    return d


def _b2(row):
    """princess_blue2 前两行（11 帧）：0-1 正面、2-4 侧身（3/4）、5 背面、6-10 朝左走。右边用朝左的镜像。"""
    left = [("b2", row, 0, i) for i in (6, 7, 8, 9)]
    return {"down": [("b2", row, 0, i) for i in (0, 1, 0, 1)], "left": left,
            "right": [k + ("m",) for k in left], "up": [("b2", row, 0, 5)] * 4}


BLUE = {name: _blue_base(name) for name in B1_EXPR}
BLUE.update({"damaged": _b2(0), "giggle": _b2(1),
             "damaged_giggle": _same([("b2", 2, 0, i) for i in (0, 2, 4, 6)]),
             "helpless_1": _same([("b2", 3, 0, i) for i in (0, 2, 4, 6)]),
             "helpless_2": _same([("b2", 4, 0, i) for i in (1, 2, 3, 4)])})
# 战损魔法（princess_blue3）：普通吟诵 / 释放没有素材，用战损吟诵 / 第二种战损释放；
# 吟诵那一行最后两帧是笑倒在地，不用（值写成 (行, 只用前几帧)）
BLUE_MAGIC = {"chant": (0, 7), "burst": 3, "damaged_chant": (0, 7), "damaged_burst": 1, "damaged_giggle_chant": 2,
              "damaged_giggle_burst": 4}


# ------------------------------------------------------------------ 切帧
def _refine(occ, nominal, lo, hi):
    """在 [lo, hi) 里找离 nominal 不远、占用最少的位置。"""
    lo, hi = max(lo, 0), min(hi, len(occ))
    seg = occ[lo:hi].astype(float) + np.abs(np.arange(lo, hi) - nominal) * 1e-3
    return lo + int(np.argmin(seg))


def _even_cuts(occ, start, end, weights, window=0.35):
    total = sum(weights)
    cuts, acc = [start], 0
    for w in weights[:-1]:
        acc += w
        nominal = start + (end - start) * acc / total
        slot = (end - start) * w / total
        cuts.append(_refine(occ, nominal, int(nominal - slot * window), int(nominal + slot * window) + 1))
    cuts.append(end)
    return cuts


class Sheet:
    def __init__(self, key):
        spec = SHEETS[key]
        self.key = key
        self.img = Image.open(OUT / spec["path"]).convert("RGB")
        self.rgb = np.asarray(self.img).astype(np.int32)
        mask = self.rgb.min(2) < 225
        self.mask = ndimage.binary_opening(mask, iterations=1)
        rows = spec["rows"]
        occ_y = self.mask.sum(1)
        ys = np.where(occ_y > 2)[0]
        self.row_edges = _even_cuts(occ_y, int(ys[0]), int(ys[-1]) + 1, [1] * len(rows))
        self.boxes = {}   # (row, group, i) -> (x0, y0, x1, y1)
        for r, groups in enumerate(rows):
            y0, y1 = self.row_edges[r], self.row_edges[r + 1]
            occ_x = self.mask[y0:y1].sum(0)
            if len(groups) > 1:
                # 分组的行（new_princess2）：每组占整张图宽度的一份（按帧数），组内再均分
                W = self.mask.shape[1]
                gcuts = [0]
                for g in range(1, len(groups)):
                    nominal = W * g / len(groups)
                    gcuts.append(_refine(occ_x, nominal, int(nominal - 40), int(nominal + 40)))
                gcuts.append(W)
            else:
                xs = np.where(occ_x > 1)[0]
                gcuts = [int(xs[0]), int(xs[-1]) + 1]
            for g, n in enumerate(groups):
                gx0, gx1 = gcuts[g], gcuts[g + 1]
                sub = occ_x[gx0:gx1]
                nz = np.where(sub > 1)[0]
                fx0, fx1 = gx0 + int(nz[0]), gx0 + int(nz[-1]) + 1
                cuts = _even_cuts(occ_x, fx0, fx1, [1] * n)
                for i in range(n):
                    self.boxes[r, g, i] = (cuts[i], y0, cuts[i + 1], y1)

    def frame(self, r, g, i):
        x0, y0, x1, y1 = self.boxes[r, g, i]
        rgb = self.rgb[y0:y1, x0:x1]
        alpha = key_background(rgb, rgb.min(2) > 225)
        lab, n = ndimage.label(alpha > 0, structure=np.ones((3, 3)))
        if n == 0:
            raise ValueError("空格子 %s %s" % (self.key, (r, g, i)))
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        main = int(np.argmax(sizes)) + 1
        ys, xs = np.where(lab == main)
        mx0, mx1, my0, my1 = xs.min(), xs.max(), ys.min(), ys.max()
        pad_x = 0.15 * (mx1 - mx0)
        keep = np.zeros_like(alpha, bool)
        objs = ndimage.find_objects(lab)
        for k, sl in enumerate(objs, 1):
            if sizes[k - 1] < 30:
                continue
            cy = (sl[0].start + sl[0].stop) / 2
            cx = (sl[1].start + sl[1].stop) / 2
            touches = sl[1].start == 0 or sl[1].stop == alpha.shape[1]
            near = mx0 - pad_x <= cx <= mx1 + pad_x and my0 - 0.2 * (my1 - my0) <= cy <= my1 + 0.1 * (my1 - my0)
            if k == main or (near and not touches):
                keep |= lab == k
        rgba = np.dstack([rgb, np.where(keep, 255, 0)]).astype(np.uint8)
        im = Image.fromarray(rgba, "RGBA")
        return im.crop(im.getbbox())


_SHEETS = {}


def sheet(key):
    if key not in _SHEETS:
        _SHEETS[key] = Sheet(key)
    return _SHEETS[key]


def get_frame(ref):
    key, r, g, i = ref[:4]
    img = sheet(key).frame(r, g, i)
    return ImageOps.mirror(img) if len(ref) > 4 and ref[4] == "m" else img


# ------------------------------------------------------------------ 图集
class V2Pixelizer(SpritePixelizer):
    """新画风的眼睛相对人物更小：眼睛特征的覆盖阈值放低；睁着的眼睛另外「盖章」成清楚的 2x2 像素眼
    （上一行深色睫毛、下一行蓝色虹膜），32px 下也一眼看得出眼睛。闭着的眼睛（笑眯眯）、侧面的小眼睛不盖。"""
    EYE_THRESHOLD = {1: 0.045, 2: 0.06}
    # 固定的眼睛颜色（加进调色板，量化时不会被并掉）：近黑的睫毛、亮蓝的虹膜——和第一版精灵图一样对比强
    LASH = (34, 20, 40)
    IRIS = (70, 140, 235)
    MIN_IRIS = 8          # 源图里虹膜块至少这么多像素才算睁眼（正面）
    MIN_IRIS_SIDE = 2     # 只有一只眼（侧脸）时的下限

    def downscale(self, img, scale, face_box):
        small = super().downscale(img, scale, face_box)
        if not face_box:
            return small
        rgb = np.asarray(img.convert("RGB")).astype(np.int32)
        h, w = rgb.shape[:2]
        # 找眼睛的范围：横向放宽到整个头（侧脸的眼睛靠边），纵向只看眼睛那一条（避开头顶的蓝色发饰）
        bx0, by0, bx1, by1 = body_bbox(img)
        bh = by1 - by0
        x0, x1 = bx0 + round(0.04 * (bx1 - bx0)), bx1 - round(0.04 * (bx1 - bx0))
        y0, y1 = by0 + round(0.25 * bh), by0 + round(0.5 * bh)
        iris = np.zeros((h, w), bool)
        iris[y0:y1, x0:x1] = classify(rgb[y0:y1, x0:x1]) == 2
        lab, n = ndimage.label(iris, structure=np.ones((3, 3)))
        if n == 0:
            return small
        sizes = ndimage.sum(iris, lab, range(1, n + 1))
        sizes = np.where(sizes > 90, 0, sizes)   # 太大的蓝色块是发饰 / 衣服，不是眼睛
        order = np.argsort(sizes)[::-1]
        eyes = [i + 1 for i in order[:2] if sizes[i] >= self.MIN_IRIS]
        if not eyes and sizes[order[0]] >= self.MIN_IRIS_SIDE:
            eyes = [order[0] + 1]   # 侧脸：一只小眼睛
        if not eyes:
            return small
        arr = np.asarray(small).copy()
        th, tw = arr.shape[:2]
        centers = [ndimage.center_of_mass(iris, lab, e) for e in eyes]
        colors = [np.median(rgb[lab == e], axis=0) for e in eyes]
        pts = [(cx * scale, cy * scale) for cy, cx in centers]
        # 两只眼在小图里挨得太近（侧脸）就只画 1 像素宽
        wide = len(pts) < 2 or abs(pts[0][0] - pts[1][0]) >= 3.5
        for (fx, fy), col in zip(pts, colors):
            c = self.IRIS
            ty = int(round(fy))
            txs = [int(fx) - (1 if fx - int(fx) < 0.5 else 0), int(fx) + (0 if fx - int(fx) < 0.5 else 1)] if wide else [int(round(fx))]
            for tx in txs:
                if 0 <= tx < tw:
                    if 0 <= ty < th and arr[ty, tx, 3]:
                        arr[ty, tx, :3] = c
                    if 0 <= ty - 1 < th and arr[ty - 1, tx, 3]:
                        arr[ty - 1, tx, :3] = self.LASH
        return Image.fromarray(arr, "RGBA")

    def build_palette(self, smalls):
        super().build_palette(smalls)
        flat = self.pal_img.getpalette()[:3 * (self.colors + self.eye_colors)] + list(self.LASH) + list(self.IRIS)
        self.pal_img.putpalette(flat + [0] * (768 - len(flat)))


def prepare(img):
    """新画风花纹很密：先中值滤波去掉细碎的高光和花边，再略提对比度，缩小后不会一片片发花。"""
    a = img.getchannel("A")
    rgb = img.convert("RGB").filter(ImageFilter.MedianFilter(5))
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def build_walk(mapping, out_name):
    cells = {}
    for name in EMOTIONS:
        for d, frames in enumerate(WALK_DIRS):
            for f, ref in enumerate(mapping[name][frames]):
                cells[name, d * 4 + f] = prepare(get_frame(ref))
    faces = {k: (None if k[1] >= 12 else _face_box_from_body(img, body_bbox(img))) for k, img in cells.items()}
    px = V2Pixelizer(cells, colors=56, face_boxes={k: (v or [0, 0, 1, 1]) for k, v in faces.items()})
    # 同一方向里来源不同的帧（蓝色公主正面第 0 帧是第 1 行的表情帧，画得更大）：缩放到同方向其它帧的高度
    for name in EMOTIONS:
        for d in range(4):
            refs = mapping[name][WALK_DIRS[d]]
            srcs = [r[:2] for r in refs]
            major = max(set(srcs), key=srcs.count)
            heights = sorted(cells[name, d * 4 + f].height for f in range(4) if srcs[f] == major)
            for f in range(4):
                if srcs[f] != major:
                    img = cells[name, d * 4 + f]
                    h = heights[len(heights) // 2]
                    cells[name, d * 4 + f] = img.resize((max(1, round(img.width * h / img.height)), h), Image.LANCZOS)
    # 同一种状态统一缩放（帧之间不忽大忽小）：最高的一帧刚好 SPRITE_FIT 高；太宽的（蓝色公主的发髻）允许略超出、两边裁掉
    smalls = {}
    for name in EMOTIONS:
        group = [cells[name, c] for c in range(16)]
        scale = min(SPRITE_FIT / max(p.height for p in group), (FRAME + 6) / max(p.width for p in group))
        for c in range(16):
            smalls[name, c] = px.downscale(cells[name, c], scale, faces[name, c])
    px.build_palette(list(smalls.values()))
    out = Image.new("RGBA", (FRAME * 16, FRAME * len(EMOTIONS)))
    for row, name in enumerate(EMOTIONS):
        for c in range(16):
            small = px.finish(smalls[name, c])
            if small.width > FRAME or small.height > FRAME:
                small = small.crop((max(0, (small.width - FRAME) // 2), max(0, small.height - FRAME),
                                    max(0, (small.width - FRAME) // 2) + min(FRAME, small.width), small.height))
            out.alpha_composite(small, (c * FRAME + (FRAME - small.width) // 2, row * FRAME + FRAME - small.height))
    out.save(OUT / out_name)
    return out, cells


def build_magic(sheet_key, rows, walk, out_name):
    """魔法：每种状态 6 帧（帧多的均匀挑 6 帧），所有帧同一缩放：第一种状态第 1 帧的人物本体 = 行走帧人物高度。"""
    cells = {}
    for name in MAGIC:
        r = rows[name]
        n = SHEETS[sheet_key]["rows"][r if isinstance(r, int) else r[0]][0]
        if not isinstance(r, int):
            r, n = r
        picks = [round(k * (n - 1) / (MAGIC_FRAMES - 1)) for k in range(MAGIC_FRAMES)]
        for c, i in enumerate(picks):
            cells[name, c] = sheet(sheet_key).frame(r, 0, i)
    alpha = np.asarray(walk.crop((0, 0, FRAME, FRAME)).getchannel("A"))
    ys = np.where(alpha.any(1))[0]
    target = ys[-1] - ys[0] + 1 - 2
    ref = body_bbox(cells[MAGIC[0], 0])
    scale = target / (ref[3] - ref[1])
    bodies = {k: body_bbox(img) for k, img in cells.items()}
    faces = {k: _face_box_from_body(img, bodies[k]) for k, img in cells.items()}
    cells = {k: _clean_magic_source(img) for k, img in cells.items()}
    px = SpritePixelizer(cells, colors=48, face_boxes=faces)
    smalls = {k: px.downscale(img, scale, faces[k]) for k, img in cells.items()}
    px.build_palette(list(smalls.values()))
    out = Image.new("RGBA", (MAGIC_FRAME * MAGIC_FRAMES, MAGIC_FRAME * len(MAGIC)))
    for row, name in enumerate(MAGIC):
        for c in range(MAGIC_FRAMES):
            small = finish_magic(px, smalls[name, c])
            x0, y0, x1, y1 = bodies[name, c]
            cx = round((x0 + x1) / 2 * scale) + 1
            bottom = round(y1 * scale) + 2
            cell = Image.new("RGBA", (MAGIC_FRAME, MAGIC_FRAME))
            cell.paste(small, (MAGIC_FRAME // 2 - cx, MAGIC_FRAME - bottom), small)
            out.alpha_composite(cell, (c * MAGIC_FRAME, row * MAGIC_FRAME))
    out.save(OUT / out_name)
    return out


# ------------------------------------------------------------------ 检查图
def preview():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for key in SHEETS:
        s = sheet(key)
        im = s.img.copy()
        d = ImageDraw.Draw(im)
        for (r, g, i), (x0, y0, x1, y1) in s.boxes.items():
            d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(255, 0, 0), width=2)
            d.text((x0 + 3, y0 + 2), "%d.%d.%d" % (r, g, i), fill=(0, 0, 200))
        im.save(PREVIEW / ("cuts_%s.png" % key))
    for name in ("princess.png", "princess_blue.png"):
        im = Image.open(OUT / name)
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", (big.width + 160, big.height), (110, 120, 130, 255))
        bg.alpha_composite(big, (160, 0))
        d = ImageDraw.Draw(bg)
        for r, n in enumerate(EMOTIONS):
            d.text((6, r * 128 + 56), n, fill=(255, 255, 255))
        for c, dn in enumerate(WALK_DIRS):
            d.text((160 + c * 512 + 4, 2), dn, fill=(255, 255, 0))
        bg.save(PREVIEW / ("sheet_" + name))
    for name in ("princess_magic.png", "princess_blue_magic.png"):
        im = Image.open(OUT / name)
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (110, 120, 130, 255))
        bg.alpha_composite(big)
        bg.save(PREVIEW / ("sheet_" + name))


def main():
    walk, _ = build_walk(PINK, "princess.png")
    build_magic("np4", PINK_MAGIC, walk, "princess_magic.png")
    bwalk, _ = build_walk(BLUE, "princess_blue.png")
    build_magic("b3", BLUE_MAGIC, bwalk, "princess_blue_magic.png")
    if "--preview" in sys.argv:
        preview()
    print("精灵图：公主 / 蓝色公主各 %d 种状态 x 16 帧，魔法 %d 种 x %d 帧" % (len(EMOTIONS), len(MAGIC), MAGIC_FRAMES))


if __name__ == "__main__":
    main()
