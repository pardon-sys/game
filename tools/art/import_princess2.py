"""把手绘表格 princess2/3 与立绘 portraits2/3 转成游戏用像素素材（原图保持不动）。

输出（assets/generated/）：
  princess.png        32x32 每帧，11 行（状态，顺序见 data/actors/princess_visuals.json）x 16 列（下/左/右/上 各 4 帧）
  portraits.png       对话立绘，2 倍像素密度（每格 228x304，显示为 114x152）
  portrait_heads.png  HUD 头像，2 倍像素密度（每格 64x64，显示为 32x32）
  portraits.json      {"cell": [...], "head": 64, "density": 2, "order": [...]}
  princess_magic.png  魔法姿态，48x48 每帧，6 行（magic_order）x 32 列（下/左/右/上 各 8 帧），
                      源图 additional_princess/princess4.png（普通版）、princess5.png（战损版 + 战损闷笑版），
                      立绘源图 portraits4.png（吟诵、释放）、portraits5.png（战损吟诵、战损闷笑吟诵、战损释放）

用法：python tools/art/import_princess2.py [--preview]
  --preview 在 tools/.cache/p2/ 输出带标签的检查图（切格边界 + 结果）。

表格位置自动检测：用表格的粉色格线找方向/状态分块和行，块内的帧用空白间隙切分；
重画素材时保持"表头 + 左侧标签列 + 格线"的表格形式即可，不需要改代码。

缩图算法（尽量保住脸部细节）：
  行走精灵：面积平均缩小（保持粉色发色）+ 眼睛特征优先 + 统一调色板（SpritePixelizer）
  立绘：
  1. 源图轻度锐化
  2. 在"脸部区域"内把眼睛深色、虹膜蓝、泪滴浅蓝、嘴等像素归为特征类，这些颜色固定进调色板
  3. 每个目标像素：脸部区域内特征类占比达到阈值就取特征色（优先级 眼 > 虹膜 > 嘴 > 泪），否则取加权众数色
"""
import colorsys
import json
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from scipy import ndimage

from palette import OUT, OUTLINE, ROOT, add_outline

META_PATH = ROOT / "data/actors/princess_visuals.json"
META = json.loads(META_PATH.read_text())
EMOTIONS = META["order"]
BASE_STATES = EMOTIONS[:6]     # princess2 / portraits2 的行（普通 开心 生气 难过 惊讶 害羞）
EXTRA_STATES = EMOTIONS[6:]    # princess3 / portraits3 的列（战损 憋笑 战损憋笑 失控1 失控2）
MAGIC = META.get("magic_order", [])   # 魔法姿态（吟诵 / 释放 × 普通 / 战损 / 战损闷笑）
VISUALS = EMOTIONS + MAGIC            # 立绘、头像的顺序
PORTRAIT2_ORDER = ["normal", "happy", "sad", "surprise", "angry", "shy"]  # portraits2.png 从左到右
FRAME = 32
SPRITE_FIT = 28                # 精灵在 32 帧内的最大尺寸
DENSITY = 2                    # 立绘像素密度
PORTRAIT_CELL = (114 * DENSITY, 152 * DENSITY)
HEAD = 32 * DENSITY
DEFAULT_HEAD_BOX = [0.2, 0.0, 0.8, 0.48]
PREVIEW = ROOT / "tools/.cache/p2"

# 固定布局（仅在自动检测失败时使用）
FALLBACK = {
    "princess2": {"xs": [83, 187, 279, 373, 466, 556, 647, 736, 827, 917, 1007, 1097, 1180, 1275, 1368, 1455, 1531],
                  "ys": [92, 247, 399, 551, 703, 854, 1004]},
    "princess3": {"xs": [71, 366, 637, 903, 1179, 1445], "ys": [390, 525, 667, 812, 954]},
    "portraits2": [0, 365, 739, 1073, 1442, 1805, 2172],
    "portraits3": [0, 362, 764, 1148, 1643, 2172],
    # 魔法表格：每张表 (帧边界 [吟诵块, 释放块], 行边界 下/左/右/上)
    "princess4": [([[111, 243, 369, 491, 612, 732, 852, 970, 1102],
                    [1102, 1242, 1370, 1494, 1617, 1747, 1882, 2018, 2160]], [57, 134, 208, 281, 357])],
    "princess5": [([[118, 238, 358, 478, 599, 719, 839, 958, 1092],
                    [1092, 1228, 1356, 1484, 1616, 1750, 1885, 2022, 2167]], [57, 135, 207, 278, 355]),
                  ([[118, 238, 358, 478, 599, 719, 839, 958, 1092],
                    [1092, 1228, 1356, 1484, 1616, 1750, 1885, 2022, 2167]], [417, 493, 562, 632, 718])],
    "portraits4": [0, 836, 1672],
    "portraits5": [0, 404, 800, 1293],
}


# ------------------------------------------------------------------ 抠图
def key_background(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """从边缘泛洪，与边缘连通的背景像素设为透明，返回 alpha。"""
    h, w = bg.shape
    alpha = np.full((h, w), 255, np.uint8)
    seen = np.zeros((h, w), bool)
    q = deque()
    for y in range(h):
        for x in range(w):
            if (y in (0, h - 1) or x in (0, w - 1)) and bg[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        alpha[y, x] = 0
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and bg[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return alpha


def _drop_small_blobs(rgba: np.ndarray, min_size: int) -> None:
    """去掉小于 min_size 像素的孤立碎块。"""
    a = rgba[..., 3] > 0
    h, w = a.shape
    seen = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            if not a[y, x] or seen[y, x]:
                continue
            comp, q = [], deque([(y, x)])
            seen[y, x] = True
            while q:
                cy, cx = q.popleft()
                comp.append((cy, cx))
                for ny in range(cy - 1, cy + 2):
                    for nx in range(cx - 1, cx + 2):
                        if 0 <= ny < h and 0 <= nx < w and a[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            if len(comp) < min_size:
                for cy, cx in comp:
                    rgba[cy, cx] = 0


def cut(image, box):
    rgb = np.asarray(image.crop(box).convert("RGB")).astype(np.int32)
    # 只去掉与边缘连通的白底：保留眼白、白袜、裙子高光
    alpha = key_background(rgb, rgb.min(2) > 225)
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    _drop_small_blobs(rgba, 10)
    result = Image.fromarray(rgba, "RGBA")
    assert result.getbbox(), box
    return result.crop(result.getbbox())


# ------------------------------------------------------------------ 表格布局检测
def _line_mask(a):
    mn, mx = a.min(2), a.max(2)
    return (mn < 246) & (mn > 170) & ((mx - mn) < 60) & (a[..., 0] >= a[..., 2])


def _runs(frac, thr):
    idx = np.where(frac > thr)[0]
    runs = []
    for i in idx:
        if runs and i - runs[-1][1] <= 2:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    return runs


def _occupancy(a, axis):
    """每列（axis=0）或每行（axis=1）的非背景、非格线像素数。"""
    content = (a.min(2) < 235) & ~_line_mask(a)
    return content.sum(axis)


def _snap_gap(occ, guess, radius):
    """在 guess±radius 内找内容最少的位置（取最长的最小值区间中点）。"""
    lo, hi = max(0, guess - radius), min(len(occ) - 1, guess + radius)
    seg = occ[lo:hi + 1]
    m = seg.min()
    best, cur, start = (0, guess), 0, None
    for i, v in enumerate(seg):
        if v <= m:
            start = i if start is None else start
            cur = i - start + 1
            if cur > best[0]:
                best = (cur, lo + start + cur // 2)
        else:
            start = None
    return best[1]


def detect_table(path, n_blocks, n_rows):
    """返回 (块边界 xs, 行边界 ys)。块 = 方向组（princess2）或状态列（princess3）。"""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    lm = _line_mask(a)
    col_runs = _runs(lm.mean(0), 0.7)
    row_runs = _runs(lm.mean(1), 0.7)
    # 左侧标签列是一整段宽的粉色区域：取它的右端作为第一块的左边界
    wide = [r for r in col_runs if r[1] - r[0] > 20]
    thin = [(r[0] + r[1]) // 2 for r in col_runs if r[1] - r[0] <= 20]
    left = wide[0][1] + 1 if wide else thin.pop(0)
    xs = [left] + [x for x in thin if x > left + 40]
    if len(xs) == n_blocks:  # 缺最右边界：按平均宽度补
        xs.append(xs[-1] + int(np.median(np.diff(xs))))
    rows = [(r[0] + r[1]) // 2 for r in row_runs if r[1] - r[0] <= 20]
    ys = rows[-n_rows:]
    step = int(np.median(np.diff(ys))) if len(ys) > 1 else 0
    occ_y = _occupancy(a[:, xs[0]:xs[-1]], 1)
    ys = [_snap_gap(occ_y, ys[0] - step, step // 5)] + ys
    return xs[: n_blocks + 1], ys


def split_block(a, x0, x1, y0, y1, n):
    """把一个格子横向切成 n 帧：在等分位置附近找空白间隙。"""
    occ = _occupancy(a[y0:y1, x0:x1], 0)
    w = x1 - x0
    edges = [0]
    for i in range(1, n):
        edges.append(_snap_gap(occ, round(w * i / n), max(4, w // (n * 4))))
    edges.append(w)
    return [x0 + e for e in edges]


def extract_cells():
    result, boxes = {}, []
    src = OUT / "princess2.png"
    base = Image.open(src)
    a = np.asarray(base.convert("RGB")).astype(np.int32)
    try:
        gxs, ys = detect_table(src, 4, len(BASE_STATES))
        assert len(gxs) == 5 and len(ys) == len(BASE_STATES) + 1, (gxs, ys)
        xs_per_row = None
    except (AssertionError, ValueError, IndexError) as e:
        print("princess2 自动检测失败，使用固定坐标：", e)
        gxs, ys = None, FALLBACK["princess2"]["ys"]
    for r, name in enumerate(BASE_STATES):
        y0, y1 = ys[r] + 3, ys[r + 1] - 3
        if gxs:
            xs = []
            for g in range(4):
                xs += split_block(a, gxs[g] + 3, gxs[g + 1] - 3, y0, y1, 4)[:-1]
            xs.append(gxs[4] - 3)
        else:
            xs = FALLBACK["princess2"]["xs"]
        for c in range(16):
            box = (xs[c] + 1, y0, xs[c + 1] - 1, y1)
            boxes.append(("princess2", box))
            result[name, c] = cut(base, box)

    src = OUT / "princess3.png"
    extra = Image.open(src)
    a = np.asarray(extra.convert("RGB")).astype(np.int32)
    try:
        xs, ys = detect_table(src, len(EXTRA_STATES), 4)
        assert len(xs) == len(EXTRA_STATES) + 1 and len(ys) == 5, (xs, ys)
    except (AssertionError, ValueError, IndexError) as e:
        print("princess3 自动检测失败，使用固定坐标：", e)
        xs, ys = FALLBACK["princess3"]["xs"], FALLBACK["princess3"]["ys"]
    for state, name in enumerate(EXTRA_STATES):
        # 最后一种（失控 2）是两个宽姿势，循环成 4 帧
        count = 2 if name == "helpless_2" else 4
        for direction in range(4):
            y0, y1 = ys[direction] + 3, ys[direction + 1] - 3
            edges = split_block(a, xs[state] + 3, xs[state + 1] - 3, y0, y1, count)
            poses = []
            for i in range(count):
                box = (edges[i] + 1, y0, edges[i + 1] - 1, y1)
                boxes.append(("princess3", box))
                poses.append(cut(extra, box))
            for frame in range(4):
                result[name, direction * 4 + frame] = poses[frame % count]
    return result, boxes


# ------------------------------------------------------------------ 战损行走帧派生
# 原表格里"战损"的行走帧只有脸不同（还穿着红鞋），与战损立绘（portraits3.png：赤脚、破损的裙子）不一致。
# 这里用 Python 派生：下/左/右 = 原战损帧（哭脸，Q 版比例与其它方向一致）把红鞋改成赤脚；
# 上 = 破损憋笑的背面帧（本来就是赤脚、看不到脸）。
# （直接缩小战损立绘试过：写实比例在 28px 下脸只剩几个像素，和其它方向不像同一个人。）
DERIVE_DAMAGED = True


def barefoot(img: Image.Image, foot_zone=0.2) -> Image.Image:
    """把图像底部 foot_zone 范围内的红鞋颜色换成肤色（按明暗保留阴影）。"""
    arr = np.asarray(img.convert("RGBA")).astype(np.float32)
    h = arr.shape[0]
    y0 = int(h * (1 - foot_zone))
    rgb = arr[y0:, :, :3] / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    red = (r > g * 1.35) & (r > b * 1.15) & (sat > 0.45) & (mx > 0.45) & (arr[y0:, :, 3] > 0)
    skin = np.array([255.0, 226.0, 212.0])
    shade = np.clip(mx / 0.95, 0.72, 1.0)[..., None]
    region = arr[y0:, :, :3]
    region[red] = (skin * shade)[red]
    arr[y0:, :, :3] = region
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def derive_damaged(cells):
    for c in range(12):
        cells["damaged", c] = barefoot(cells["damaged", c])
    for c in range(12, 16):
        cells["damaged", c] = cells["damaged_giggle", c]


def split_figures(path, n, fallback):
    """立绘表：按空白列把 n 个人物分开（取最宽的 n-1 段空白）。"""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    occ = (a.min(2) < 225).sum(0)
    gaps, start = [], None
    for x, v in enumerate(occ):
        if v <= 2:
            start = x if start is None else start
        elif start is not None:
            gaps.append((x - start, start, x))
            start = None
    inner = sorted([g for g in gaps if g[1] > 0 and g[2] < len(occ) - 1], reverse=True)[: n - 1]
    if len(inner) != n - 1:
        print(path.name, "自动切分失败，使用固定坐标")
        return fallback
    cuts = sorted((s + e) // 2 for _, s, e in inner)
    return [0] + cuts + [a.shape[1]]


# ------------------------------------------------------------------ 特征保护像素化
# 特征类：1 睫毛/瞳孔深色  2 虹膜蓝  3 嘴  4 泪滴浅蓝
PRIORITY = [1, 2, 3, 4]
THRESHOLD = {1: 0.10, 2: 0.12, 3: 0.14, 4: 0.18}


def classify(rgb: np.ndarray) -> np.ndarray:
    f = rgb.astype(np.float32) / 255.0
    mx, mn = f.max(2), f.min(2)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    hue = np.zeros_like(v)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, ((g - b) / d) % 6, hue)
    hue = np.where(mx == g, (b - r) / d + 2, hue)
    hue = np.where(mx == b, (r - g) / d + 4, hue)
    hue = hue * 60.0
    cls = np.zeros(rgb.shape[:2], np.int8)
    dark = (v < 0.55) & ((s < 0.35) | ((hue > 200) & (hue < 330)))
    iris = (hue > 195) & (hue < 250) & (s > 0.35) & (v > 0.4) & ~dark
    mouth = ((hue > 330) | (hue < 15)) & (s > 0.35) & (v > 0.5) & (v < 0.9)
    tear = (hue > 175) & (hue <= 215) & (s > 0.12) & (s < 0.6) & (v > 0.8)
    cls[tear] = 4
    cls[mouth] = 3
    cls[iris] = 2
    cls[dark] = 1
    return cls


class Pixelizer:
    """共享调色板（含固定的五官颜色）+ 脸部特征优先 + 加权众数。"""

    def __init__(self, images, colors, face_boxes):
        strip_w = sum(i.width for i in images)
        strip = Image.new("RGB", (strip_w, max(i.height for i in images)), (255, 0, 255))
        x = 0
        feats = {k: [] for k in PRIORITY}
        for img, fb in zip(images, face_boxes):
            strip.paste(img, (x, 0), img)
            x += img.width
            rgb = np.asarray(img.convert("RGB"))
            cls = classify(rgb) * self._face_mask(img, fb)
            for k in PRIORITY:
                feats[k].append(rgb[cls == k])
        pinned = []
        for k, n in ((1, 3), (2, 4), (3, 2), (4, 2)):
            px = np.concatenate(feats[k]) if feats[k] else np.zeros((0, 3), np.uint8)
            if len(px) >= n:
                q = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8)).quantize(n, method=Image.Quantize.MEDIANCUT)
                pinned += [tuple(q.getpalette()[i * 3:i * 3 + 3]) for i in range(n)]
        base = strip.quantize(colors - len(pinned), method=Image.Quantize.FASTOCTREE, kmeans=2)
        pal = [tuple(base.getpalette()[i * 3:i * 3 + 3]) for i in range(colors - len(pinned))] + pinned
        self.pal = np.array(pal, np.int32)
        self.pal_img = Image.new("P", (1, 1))
        flat = [c for rgb in pal for c in rgb]
        self.pal_img.putpalette(flat + [0] * (768 - len(flat)))
        lum = (self.pal * [0.3, 0.59, 0.11]).sum(1) / 255
        sat = (self.pal.max(1) - self.pal.min(1)) / 255
        self.weight = 1 + 2.0 * (1 - lum) + 1.0 * sat

    @staticmethod
    def _face_mask(img, box):
        m = np.zeros((img.height, img.width), np.int8)
        if box:
            x0, y0, x1, y1 = (round(box[0] * img.width), round(box[1] * img.height),
                              round(box[2] * img.width), round(box[3] * img.height))
            m[y0:y1, x0:x1] = 1
        return m

    def _nearest(self, color):
        return self.pal[int(((self.pal - color) ** 2).sum(1).argmin())]

    def __call__(self, img, scale, face_box=None, sharpen=(1.2, 70), min_blob=1):
        rgb_img = Image.new("RGB", img.size, (255, 0, 255))
        rgb_img.paste(img, (0, 0), img)
        if sharpen:
            rgb_img = rgb_img.filter(ImageFilter.UnsharpMask(radius=sharpen[0], percent=sharpen[1], threshold=2))
        rgb = np.asarray(rgb_img).astype(np.int32)
        idx = np.asarray(rgb_img.quantize(palette=self.pal_img, dither=Image.Dither.NONE))
        cls = classify(rgb) * self._face_mask(img, face_box)
        a = np.asarray(img.getchannel("A")) > 0
        h, w = idx.shape
        th, tw = max(1, round(h * scale)), max(1, round(w * scale))
        out = np.zeros((th, tw, 4), np.uint8)
        n = len(self.pal)
        for ty in range(th):
            y0 = int(ty / scale)
            y1 = max(int((ty + 1) / scale), y0 + 1)
            for tx in range(tw):
                x0 = int(tx / scale)
                x1 = max(int((tx + 1) / scale), x0 + 1)
                am = a[y0:y1, x0:x1]
                total = am.sum()
                if total == 0 or total < am.size * 0.5:
                    continue
                c = cls[y0:y1, x0:x1][am]
                picked = None
                if c.any():
                    for k in PRIORITY:
                        share = (c == k).sum() / total
                        if share >= THRESHOLD[k]:
                            picked = self._nearest(rgb[y0:y1, x0:x1][am][c == k].mean(0))
                            break
                if picked is None:
                    cnt = np.bincount(idx[y0:y1, x0:x1][am], minlength=n)[:n] * self.weight
                    picked = self.pal[int(cnt.argmax())]
                out[ty, tx] = [*picked, 255]
        _drop_small_blobs(out, min_blob)
        small = Image.fromarray(out, "RGBA")
        big = Image.new("RGBA", (small.width + 2, small.height + 2), (0, 0, 0, 0))
        big.paste(small, (1, 1))
        return add_outline(big, OUTLINE)


def head_box(name):
    return META.get("head_boxes", {}).get(name, DEFAULT_HEAD_BOX)


# ------------------------------------------------------------------ 生成
class SpritePixelizer:
    """行走精灵（32px）专用：面积平均缩小保持发色（粉色不会被暗红描线"吃掉"），
    再只对眼睛（睫毛深色、虹膜蓝）做特征优先，最后统一调色板 + 轻度锐化 + 描边。
    （加权众数法会偏向深色/高饱和，32px 下头发会被丝带和暗部描线染成红色。）"""

    EYE_THRESHOLD = {1: 0.08, 2: 0.10}

    def __init__(self, cells, colors=48, eye_colors=8, face_boxes=None):
        eyes = []
        for key, img in cells.items():
            src = np.asarray(img.convert("RGB")).astype(np.int32)
            box = face_boxes[key] if face_boxes is not None else head_box(key[0])
            cls = classify(src) * Pixelizer._face_mask(img, box)
            eyes.append(src[(cls == 1) | (cls == 2)])
        self.colors = colors
        self.eye_px = np.concatenate(eyes).reshape(1, -1, 3).astype(np.uint8)
        self.eye_colors = eye_colors
        self.pal_img = None

    def downscale(self, img, scale, face_box):
        w, h = img.size
        tw, th = max(1, round(w * scale)), max(1, round(h * scale))
        arr = np.asarray(img).astype(np.float32) / 255
        prem = arr.copy()
        prem[..., :3] *= prem[..., 3:4]
        small = np.asarray(Image.fromarray((prem * 255).astype(np.uint8), "RGBA").resize((tw, th), Image.BOX)).astype(np.float32) / 255
        a = small[..., 3]
        rgb = np.where(a[..., None] > 0, small[..., :3] / np.maximum(a[..., None], 1e-6), 0)
        out = np.zeros((th, tw, 4), np.uint8)
        out[..., :3] = np.clip(rgb * 255, 0, 255)
        out[..., 3] = np.where(a > 0.5, 255, 0)
        im = Image.fromarray(out, "RGBA")
        sharp = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1, percent=45, threshold=3))
        out = np.dstack([np.asarray(sharp), out[..., 3]]).astype(np.uint8)
        if face_box:
            src = np.asarray(img.convert("RGB")).astype(np.int32)
            sa = np.asarray(img.getchannel("A")) > 0
            cls = classify(src) * Pixelizer._face_mask(img, face_box)
            for ty in range(th):
                y0 = int(ty / scale)
                y1 = max(int((ty + 1) / scale), y0 + 1)
                for tx in range(tw):
                    if out[ty, tx, 3] == 0:
                        continue
                    x0 = int(tx / scale)
                    x1 = max(int((tx + 1) / scale), x0 + 1)
                    m = sa[y0:y1, x0:x1]
                    c = cls[y0:y1, x0:x1][m]
                    if c.size == 0:
                        continue
                    for k, thr in self.EYE_THRESHOLD.items():
                        if (c == k).sum() / c.size >= thr:
                            out[ty, tx, :3] = src[y0:y1, x0:x1][m][c == k].mean(0)
                            break
        return Image.fromarray(out, "RGBA")

    def build_palette(self, smalls):
        strip = Image.new("RGB", (sum(i.width for i in smalls), max(i.height for i in smalls)), (255, 0, 255))
        x = 0
        for i in smalls:
            strip.paste(i, (x, 0), i)
            x += i.width
        base = strip.quantize(self.colors, method=Image.Quantize.MEDIANCUT)
        eq = Image.fromarray(self.eye_px).quantize(self.eye_colors, method=Image.Quantize.MEDIANCUT)
        cols = [tuple(base.getpalette()[i * 3:i * 3 + 3]) for i in range(self.colors)]
        cols += [tuple(eq.getpalette()[i * 3:i * 3 + 3]) for i in range(self.eye_colors)]
        self.pal_img = Image.new("P", (1, 1))
        flat = [v for c in cols for v in c]
        self.pal_img.putpalette(flat + [0] * (768 - len(flat)))

    def finish(self, small):
        rgb = Image.new("RGB", small.size, (255, 0, 255))
        rgb.paste(small, (0, 0), small)
        q = rgb.quantize(palette=self.pal_img, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(small.getchannel("A"))
        big = Image.new("RGBA", (q.width + 2, q.height + 2), (0, 0, 0, 0))
        big.paste(q, (1, 1))
        return add_outline(big, OUTLINE)


def build_sheet(cells):
    px = SpritePixelizer(cells)
    smalls = {}
    for name in EMOTIONS:
        poses = [cells[name, c] for c in range(16)]
        # 每种状态统一缩放比例，避免动画帧之间忽大忽小；派生的战损帧来源不同，按方向分别缩放
        groups = [range(c, c + 4) for c in range(0, 16, 4)] if (name == "damaged" and DERIVE_DAMAGED) else [range(16)]
        scales = {}
        for g in groups:
            gp = [poses[c] for c in g]
            sc = min(SPRITE_FIT / max(p.height for p in gp), SPRITE_FIT / max(p.width for p in gp))
            for c in g:
                scales[c] = sc
        for c, pose in enumerate(poses):
            scale = scales[c]
            face = head_box(name) if c < 12 or name in ("helpless_1", "helpless_2") else None  # 背面没有脸
            smalls[name, c] = px.downscale(pose, scale, face)
    px.build_palette(list(smalls.values()))
    sheet = Image.new("RGBA", (FRAME * 16, FRAME * len(EMOTIONS)))
    for row, name in enumerate(EMOTIONS):
        for c in range(16):
            small = px.finish(smalls[name, c])
            assert small.width <= FRAME and small.height <= FRAME, (name, c, small.size)
            sheet.alpha_composite(small, (c * FRAME + (FRAME - small.width) // 2, row * FRAME + FRAME - small.height))
    sheet.save(OUT / "princess.png")
    return sheet


# ------------------------------------------------------------------ 魔法姿态
MAGIC_DIR = OUT / "additional_princess"
# (文件, 从上到下每张表的 (吟诵状态, 释放状态))；每张表 = 吟诵块 + 释放块，各 8 列 x 4 行（下/左/右/上）
MAGIC_TABLES = [("princess4.png", [("chant", "burst")]),
                ("princess5.png", [("damaged_chant", "damaged_burst"), ("damaged_giggle_chant", "damaged_giggle_burst")])]
MAGIC_PORTRAITS = [("portraits4.png", ["chant", "burst"]),
                   ("portraits5.png", ["damaged_chant", "damaged_giggle_chant", "damaged_burst"])]
# 没有单独立绘的魔法姿态借用另一张（战损闷笑释放 → 战损释放）
MAGIC_PORTRAIT_ALIAS = META.get("magic_portrait_alias", {})
MAGIC_FRAMES = 8
MAGIC_FRAME = 48


def detect_magic_tables(path, n_tables):
    """魔法表格：表头的粉色底里，帧编号数字是格线色的"空隙"，数字中心 = 帧中心；
    块分隔线也是一个空隙，但它离两侧数字都只有半格，据此剔除。返回 [(帧边界 [块0, 块1], 行边界)]。"""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    runs = _runs(_line_mask(a).mean(1), 0.5)
    heads = [r for r in runs if r[1] - r[0] > 20][:n_tables]
    lines = [(r[0] + r[1]) // 2 for r in runs if r[1] - r[0] <= 20]
    tables = []
    for h0, h1 in heads:
        ys = [int(h1)] + [int(y) for y in lines if y > h1][:4]
        band = a[h0 + (h1 - h0) * 11 // 20: h1 - 2]     # 表头下半部分 = 帧编号行
        cruns = [r for r in _runs(_line_mask(band).mean(0), 0.8) if r[1] - r[0] >= 3]
        label_end, right = int(cruns[0][0]), int(cruns[-1][1])
        gaps = [(int(cruns[i][1]) + int(cruns[i + 1][0])) / 2 for i in range(len(cruns) - 1)]
        d = np.diff(gaps)
        med = np.median(d)
        div = [k for k in range(1, len(gaps) - 1) if d[k - 1] < 0.75 * med and d[k] < 0.75 * med]
        assert len(div) == 1 and len(gaps) == 2 * MAGIC_FRAMES + 1 and len(ys) == 5, (len(gaps), div, ys)
        k = div[0]
        blocks = []
        for centers, lo, hi in ((gaps[:k], label_end, gaps[k]), (gaps[k + 1:], gaps[k], right)):
            edges = [lo] + [(centers[i] + centers[i + 1]) / 2 for i in range(len(centers) - 1)] + [hi]
            blocks.append([int(round(e)) for e in edges])
        tables.append((blocks, ys))
    return tables


def extract_magic_cells():
    cells, boxes = {}, []
    for filename, variants in MAGIC_TABLES:
        path = MAGIC_DIR / filename
        try:
            tables = detect_magic_tables(path, len(variants))
        except (AssertionError, ValueError, IndexError) as e:
            print(filename, "自动检测失败，使用固定坐标：", e)
            tables = FALLBACK[path.stem]
        image = Image.open(path)
        for (blocks, ys), names in zip(tables, variants):
            for name, edges in zip(names, blocks):
                for direction in range(4):
                    y0, y1 = ys[direction] + 3, ys[direction + 1] - 3
                    for f in range(MAGIC_FRAMES):
                        box = (edges[f] + 3, y0, edges[f + 1] - 3, y1)
                        boxes.append((path.stem, box))
                        cells[name, direction * MAGIC_FRAMES + f] = cut(image, box)
    return cells, boxes


def body_bbox(img):
    """人物本体 = 最大的连通块（花瓣、光点这些分离的特效不算）。返回 (x0, y0, x1, y1)。"""
    lab, n = ndimage.label(np.asarray(img.getchannel("A")) > 0, structure=np.ones((3, 3)))
    if n == 0:
        return (0, 0, img.width, img.height)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    ys, xs = np.where(lab == int(np.argmax(sizes)) + 1)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def _face_box_from_body(img, body):
    x0, y0, x1, y1 = body
    bw, bh = x1 - x0, y1 - y0
    return [(x0 + 0.2 * bw) / img.width, y0 / img.height, (x0 + 0.8 * bw) / img.width, (y0 + 0.45 * bh) / img.height]


def finish_magic(px, small):
    """统一调色板；只给人物本体描边，花瓣、光点等特效不描边（否则缩小后全是带黑边的碎点），1 像素的碎点去掉。"""
    rgb = Image.new("RGB", small.size, (255, 0, 255))
    rgb.paste(small, (0, 0), small)
    q = rgb.quantize(palette=px.pal_img, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(small.getchannel("A"))
    arr = np.asarray(q).copy()
    lab, n = ndimage.label(arr[..., 3] > 0, structure=np.ones((3, 3)))
    body = np.zeros(arr.shape[:2], bool)
    if n:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        body = lab == int(np.argmax(sizes)) + 1
        for i, size in enumerate(sizes, 1):
            if size < 2:
                arr[lab == i] = 0
    body_img = arr.copy()
    body_img[~body] = 0
    fx = arr.copy()
    fx[body] = 0
    big = Image.new("RGBA", (q.width + 2, q.height + 2), (0, 0, 0, 0))
    big.paste(Image.fromarray(body_img, "RGBA"), (1, 1))
    out = add_outline(big, OUTLINE)
    fx_img = Image.new("RGBA", big.size, (0, 0, 0, 0))
    fx_img.paste(Image.fromarray(fx, "RGBA"), (1, 1))
    out.alpha_composite(fx_img)
    return out


def _clean_magic_source(img):
    """魔法帧源图光效多：先中值滤波去掉细碎高光，再略提饱和度和对比度，缩小后不会发白、发糊，眼睛也更清楚。"""
    a = img.getchannel("A")
    rgb = img.convert("RGB").filter(ImageFilter.MedianFilter(3))
    rgb = ImageEnhance.Contrast(ImageEnhance.Color(rgb).enhance(1.25)).enhance(1.1)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def build_magic_sheet(cells, walk_sheet):
    """所有魔法帧用同一缩放：普通吟诵正面第 1 帧的人物本体 = 行走帧人物高度；跪姿自然更矮。
    人物本体底边对齐格子底边、水平居中（和 32 格行走帧脚底一致），格子外的特效裁掉。"""
    alpha = np.asarray(walk_sheet.crop((0, 0, FRAME, FRAME)).getchannel("A"))
    rows = np.where(alpha.any(1))[0]
    target = rows[-1] - rows[0] + 1 - 2          # 去掉上下 1px 描边
    ref = body_bbox(cells[MAGIC[0], 0])
    scale = target / (ref[3] - ref[1])
    bodies = {k: body_bbox(img) for k, img in cells.items()}
    faces = {k: _face_box_from_body(img, bodies[k]) for k, img in cells.items()}
    cells = {k: _clean_magic_source(img) for k, img in cells.items()}
    px = SpritePixelizer(cells, colors=48, face_boxes=faces)
    back = range(3 * MAGIC_FRAMES, 4 * MAGIC_FRAMES)  # 背面没有脸
    smalls = {k: px.downscale(img, scale, None if k[1] in back else faces[k]) for k, img in cells.items()}
    px.build_palette(list(smalls.values()))
    sheet = Image.new("RGBA", (MAGIC_FRAME * 4 * MAGIC_FRAMES, MAGIC_FRAME * len(MAGIC)))
    for row, name in enumerate(MAGIC):
        for c in range(4 * MAGIC_FRAMES):
            small = finish_magic(px, smalls[name, c])
            x0, y0, x1, y1 = bodies[name, c]
            cx = round((x0 + x1) / 2 * scale) + 1
            bottom = round(y1 * scale) + 2
            cell = Image.new("RGBA", (MAGIC_FRAME, MAGIC_FRAME))
            cell.paste(small, (MAGIC_FRAME // 2 - cx, MAGIC_FRAME - bottom), small)  # 超出格子的部分自动裁掉
            sheet.alpha_composite(cell, (c * MAGIC_FRAME, row * MAGIC_FRAME))
    sheet.save(OUT / "princess_magic.png")
    return sheet


def _drop_border_fragments(img):
    """裁切后被切断的特效碎片（碰到裁切边、又不是人物本体的连通块）去掉，避免立绘出现笔直的切边。"""
    arr = np.asarray(img).copy()
    lab, n = ndimage.label(arr[..., 3] > 0, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        body = int(np.argmax(sizes)) + 1
        edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0, body}
        for i in edge:
            arr[lab == i] = 0
    out = Image.fromarray(arr, "RGBA")
    return out.crop(out.getbbox())


def magic_portrait_figures():
    """魔法立绘：只保留人物本体附近（外扩一圈），四散的花瓣不参与缩放，人物大小和其它立绘一致。
    魔法阵、光带和人物连在一起的（吟诵、释放）在 princess_visuals.json 的 portrait_crops 里手动指定取景（相对原人物图）。"""
    figures = {}
    for filename, names in MAGIC_PORTRAITS:
        path = MAGIC_DIR / filename
        edges = split_figures(path, len(names), FALLBACK[path.stem])
        source = Image.open(path)
        for i, name in enumerate(names):
            f = cut(source, (edges[i], 0, edges[i + 1], source.height))
            crop = META.get("portrait_crops", {}).get(name)
            if crop:
                f = f.crop(tuple(round(v * (f.width if j % 2 == 0 else f.height)) for j, v in enumerate(crop)))
                figures[name] = _drop_border_fragments(f)
                continue
            x0, y0, x1, y1 = body_bbox(f)
            m = round(0.04 * (y1 - y0))
            figures[name] = f.crop((max(0, x0 - m), max(0, y0 - m), min(f.width, x1 + m), min(f.height, y1 + m)))
    for name, src in MAGIC_PORTRAIT_ALIAS.items():
        figures[name] = figures[src]
    return figures


def build_portraits():
    figures = {}
    for filename, names, key in (("portraits2.png", PORTRAIT2_ORDER, "portraits2"),
                                 ("portraits3.png", EXTRA_STATES, "portraits3")):
        path = OUT / filename
        edges = split_figures(path, len(names), FALLBACK[key])
        source = Image.open(path)
        for i, name in enumerate(names):
            figures[name] = cut(source, (edges[i], 0, edges[i + 1], source.height))
    figures.update(magic_portrait_figures())
    names = list(VISUALS)
    heads_src = {}
    for name in names:
        f = figures[name]
        hb = head_box(name)
        heads_src[name] = f.crop(tuple(round(v * (f.width if j % 2 == 0 else f.height)) for j, v in enumerate(hb)))
    # 原有 11 种与魔法姿态各用一套调色板：新增素材不会改变已有立绘的颜色
    groups = [list(EMOTIONS), list(MAGIC)]
    pxs = {}
    for group in groups:
        if not group:
            continue
        px = Pixelizer([figures[n] for n in group] + [heads_src[n] for n in group], 128,
                       [head_box(n) for n in group] + [[0, 0, 1, 1]] * len(group))
        for n in group:
            pxs[n] = px
    cw, ch = PORTRAIT_CELL
    sheet = Image.new("RGBA", (cw * len(names), ch))
    heads = Image.new("RGBA", (HEAD * len(names), HEAD))
    for i, name in enumerate(names):
        px = pxs[name]
        f = figures[name]
        small = px(f, min((ch - 4) / f.height, (cw - 4) / f.width), head_box(name), sharpen=(1.0, 60))
        sheet.alpha_composite(small, (i * cw + (cw - small.width) // 2, ch - small.height))
        hs = heads_src[name]
        h = px(hs, min((HEAD - 4) / hs.width, (HEAD - 4) / hs.height), [0, 0, 1, 1], sharpen=(1.0, 60))
        heads.alpha_composite(h, (i * HEAD + (HEAD - h.width) // 2, (HEAD - h.height) // 2))
    sheet.save(OUT / "portraits.png")
    heads.save(OUT / "portrait_heads.png")
    (OUT / "portraits.json").write_text(json.dumps(
        {"cell": [cw, ch], "head": HEAD, "density": DENSITY, "order": names}))
    return sheet, heads


def preview_magic(sheet, boxes):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    n = 4 * MAGIC_FRAMES
    out = Image.new("RGB", (n * 104 + 180, len(MAGIC) * 124 + 10), "#73818c")
    draw = ImageDraw.Draw(out)
    for row, name in enumerate(MAGIC):
        draw.text((4, row * 124 + 50), name, fill="white")
        for col in range(n):
            x, y = 180 + col * 104, row * 124
            frame = sheet.crop((col * MAGIC_FRAME, row * MAGIC_FRAME, (col + 1) * MAGIC_FRAME, (row + 1) * MAGIC_FRAME))
            frame = frame.resize((96, 96), Image.Resampling.NEAREST)
            draw.rectangle((x, y + 24, x + 95, y + 119), outline="#5c6a75")
            out.paste(frame, (x, y + 24), frame)
            draw.text((x, y + 5), f"{['down', 'left', 'right', 'up'][col // MAGIC_FRAMES]} {col % MAGIC_FRAMES + 1}", fill="white")
    out.save(PREVIEW / "magic48.png")
    for filename, _ in MAGIC_TABLES:
        stem = filename[:-4]
        img = Image.open(MAGIC_DIR / filename).convert("RGB")
        d = ImageDraw.Draw(img)
        for src, b in boxes:
            if src == stem:
                d.rectangle(b, outline=(0, 160, 255))
        img.save(PREVIEW / f"grid_{stem}.png")


def preview(sheet, portraits, heads, boxes):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGB", (16 * 100 + 140, len(EMOTIONS) * 124), "#73818c")
    draw = ImageDraw.Draw(out)
    for row, name in enumerate(EMOTIONS):
        draw.text((4, row * 124 + 50), name, fill="white")
        for col in range(16):
            x, y = 140 + col * 100, row * 124
            frame = sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32)).resize((96, 96), Image.Resampling.NEAREST)
            out.paste(frame, (x, y + 24), frame)
            draw.text((x, y + 5), f"{['down', 'left', 'right', 'up'][col // 4]} {col % 4 + 1}", fill="white")
    out.save(PREVIEW / "cells32.png")
    cw, ch = PORTRAIT_CELL
    out = Image.new("RGB", (cw * len(VISUALS), ch + 20 + HEAD + 10), "#73818c")
    out.paste(portraits, (0, 20), portraits)
    draw = ImageDraw.Draw(out)
    for i, name in enumerate(VISUALS):
        draw.text((i * cw + 4, 3), name, fill="white")
        h = heads.crop((i * HEAD, 0, (i + 1) * HEAD, HEAD))
        out.paste(h, (i * cw + (cw - HEAD) // 2, ch + 25), h)
    out.save(PREVIEW / "portraits.png")
    for name in ("princess2", "princess3"):
        img = Image.open(OUT / f"{name}.png").convert("RGB")
        d = ImageDraw.Draw(img)
        for src, b in boxes:
            if src == name:
                d.rectangle(b, outline=(0, 160, 255))
        img.save(PREVIEW / f"grid_{name}.png")
    print("预览：", PREVIEW)


def main():
    cells, boxes = extract_cells()
    if DERIVE_DAMAGED:
        derive_damaged(cells)
    sheet = build_sheet(cells)
    magic_cells, magic_boxes = extract_magic_cells()
    magic_sheet = build_magic_sheet(magic_cells, sheet)
    portraits, heads = build_portraits()
    if "--preview" in sys.argv:
        preview(sheet, portraits, heads, boxes)
        preview_magic(magic_sheet, magic_boxes)
    print("生成", len(EMOTIONS), "种状态 /", len(cells), "帧；魔法姿态", len(MAGIC), "种 /", len(magic_cells), "帧；立绘",
          len(VISUALS), "张，密度", DENSITY)


if __name__ == "__main__":
    main()
