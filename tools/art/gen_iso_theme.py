"""等距主题美术（可复用；scripts/iso/ 的 IsoTerrain 用）：按一套参数画像素图，写出 assets/iso_themes/<名>.tres。

一套主题 = 地面图块（四个视角）+ 地面装饰（四个视角）+ 方块墙（几种变体 + 法线）+ 栅栏门块 + 活墙块 + 活墙裂纹。
  逻辑格 16x16 → 等距菱形 32x16（x' = gx − gy，y' = (gx + gy) / 2）；墙块 32x(16+墙高)，正面高 wall_h 像素。
  地面：先在格子空间画一张 PERIOD x PERIOD 格循环的无缝石面（不规则石块，没有格线），每个视角把它转 k×90° 再逐像素
        映射成菱形——相邻格子的图案连续，转了视角也没有接缝。图集：列 = j*PERIOD + i（格子坐标取余），行 = 视角 k。
  装饰：格子空间 32x32（2x2 格）的贴片（裂纹 / 苔藓 / 碎石 / 积灰），同样按四个视角投影成 64x32。行 = 贴片，列 = 视角。
  法线：RGB = (x 右, y 下, z 朝外)，和 tools/art/gen_normal_maps.py 一致；墙块按面直接给（顶面朝上、左面朝左下、右面朝右下）。
用法：python tools/art/gen_iso_theme.py [主题名 ...]（默认全部）
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CELL = 16
TW, TH = 32, 16          # 菱形大小
PERIOD = 4               # 地面图案循环的格数

THEMES = {
    # 夜迷宫：深色旧石地 + 蓝灰石砖墙（1.5 格高）
    "blue_stone": {
        "seed": 8,
        "wall_h": 24,
        "fade_alpha": 0.35,
        "light_squash": 0.5,
        "stone": [(64, 66, 78), (72, 72, 82), (58, 62, 74), (78, 76, 84), (66, 70, 80)],
        "mortar": (40, 41, 52),
        "stones": 15,
        "wall_top": (128, 144, 172),
        "wall_rim": (184, 200, 224),
        "wall_left": (84, 98, 128),
        "wall_right": (60, 70, 96),
        "wall_mortar": (42, 48, 66),
        "moss": (62, 104, 92),
        "gate_iron": (70, 78, 96),
        "gate_glow": (150, 190, 230),
        "gate_purple": (120, 70, 160),
        "vein": (190, 110, 255),
        "living_base": (70, 56, 96),
    },
    # 骑士篇「没有灯的小巷」：暖褐色旧石板地 + 红褐砖墙（夜里、只有手里的小灯照着）
    "alley_brick": {
        "seed": 21,
        "wall_h": 24,
        "fade_alpha": 0.35,
        "light_squash": 0.5,
        "stone": [(78, 64, 56), (86, 70, 60), (70, 58, 52), (92, 76, 64), (80, 68, 60)],
        "mortar": (46, 36, 34),
        "stones": 18,
        "wall_top": (150, 104, 84),
        "wall_rim": (196, 150, 118),
        "wall_left": (122, 74, 60),
        "wall_right": (92, 54, 46),
        "wall_mortar": (58, 38, 34),
        "moss": (84, 96, 62),
        "gate_iron": (78, 70, 66),
        "gate_glow": (230, 190, 130),
        "gate_purple": (120, 70, 160),
        "vein": (190, 110, 255),
        "living_base": (80, 56, 60),
    },
}


# ------------------------------------------------------------------ 等距换算
def rot(v, k):
    """格子空间里转 k×90°（顺时针看：x 右、y 下）。"""
    x, y = v
    for _ in range(k % 4):
        x, y = -y, x
    return x, y


def unrot(v, k):
    return rot(v, (4 - k % 4) % 4)


def iso_to_grid(sx, sy):
    """屏幕偏移 → 格子空间偏移（像素）。x' = gx − gy、y' = (gx + gy)/2 的逆。"""
    return sy + sx / 2.0, sy - sx / 2.0


def project_patch(src, k, out_w, out_h, cx, cy, wrap=False):
    """把格子空间的图 src（中心 cx, cy）按视角 k 投影成 out_w x out_h 的等距图（中心在图正中）。
    wrap = True 时按 src 大小循环取样（地面无缝），否则超出的地方透明。只填菱形以内的像素（按像素中心判断，相邻菱形不重不漏）。"""
    h, w = src.shape[:2]
    out = np.zeros((out_h, out_w, src.shape[2]), src.dtype)
    hw, hh = out_w / 2.0, out_h / 2.0
    for py in range(out_h):
        for px in range(out_w):
            sx, sy = px + 0.5 - hw, py + 0.5 - hh
            if abs(sx) / hw + abs(sy) / hh > 1.0:
                continue
            rx, ry = iso_to_grid(sx, sy)
            gx, gy = unrot((rx, ry), k)
            x, y = cx + gx, cy + gy
            if wrap:
                out[py, px] = src[int(math.floor(y)) % h, int(math.floor(x)) % w]
            else:
                xi, yi = int(math.floor(x)), int(math.floor(y))
                if 0 <= xi < w and 0 <= yi < h:
                    out[py, px] = src[yi, xi]
    return out


# ------------------------------------------------------------------ 地面
def stone_floor(t, rng):
    """格子空间里 PERIOD 格循环的不规则石面（RGBA + 高度）。"""
    n = PERIOD * CELL
    pts = [(rng.uniform(0, n), rng.uniform(0, n)) for _ in range(t["stones"])]
    cols = [t["stone"][rng.randrange(len(t["stone"]))] for _ in pts]
    jit = [rng.uniform(-6, 6) for _ in pts]
    img = np.zeros((n, n, 4), np.uint8)
    height = np.zeros((n, n), np.float32)
    nrng = np.random.default_rng(t["seed"])
    noise = nrng.integers(-5, 6, (n, n))
    for y in range(n):
        for x in range(n):
            ds = []
            for i, (qx, qy) in enumerate(pts):
                dx = min(abs(x + 0.5 - qx), n - abs(x + 0.5 - qx))
                dy = min(abs(y + 0.5 - qy), n - abs(y + 0.5 - qy))
                ds.append((dx * dx * 1.0 + dy * dy * 1.15, i))
            ds.sort()
            d1, i1 = math.sqrt(ds[0][0]), ds[0][1]
            d2 = math.sqrt(ds[1][0])
            edge = d2 - d1
            if edge < 1.1:
                c = np.array(t["mortar"], np.float32) + noise[y, x] * 0.5
                h = 0.0
            else:
                c = np.array(cols[i1], np.float32) + jit[i1] + noise[y, x]
                # 石块边缘一圈微暗、中间微亮（像磨圆的旧石头）
                c = c * (0.9 + 0.1 * min(edge / 4.0, 1.0))
                h = min(edge / 3.0, 1.0)
            img[y, x, :3] = np.clip(c, 0, 255)
            img[y, x, 3] = 255
            height[y, x] = h
    return img, height


def normals_from_height(height, strength=1.2, wrap=True):
    p = np.pad(height, 1, mode="wrap" if wrap else "edge")
    gx = p[1:-1, 2:] - p[1:-1, :-2]
    gy = p[2:, 1:-1] - p[:-2, 1:-1]
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def grid_normals_to_iso(n, k):
    """格子空间的地面法线（x, y 在地面上）→ 等距画面里的法线：地面方向按投影换算、再压一半 y。"""
    out = n.copy()
    gx, gy = rot((n[..., 0], n[..., 1]), k)
    out[..., 0] = gx - gy
    out[..., 1] = (gx + gy) * 0.5
    out /= np.linalg.norm(out, axis=-1, keepdims=True)
    return out


def encode_normals(n, alpha):
    rgb = ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    return np.dstack([rgb, alpha.astype(np.uint8)])


def make_floor(t, rng):
    tex, height = stone_floor(t, rng)
    nrm = normals_from_height(height)
    nrm_img = ((nrm * 0.5 + 0.5) * 255).astype(np.uint8)
    nrm_img = np.dstack([nrm_img, np.full(height.shape, 255, np.uint8)])
    cols = PERIOD * PERIOD
    atlas = np.zeros((4 * TH, cols * TW, 4), np.uint8)
    natlas = np.zeros_like(atlas)
    for k in range(4):
        for j in range(PERIOD):
            for i in range(PERIOD):
                cx, cy = i * CELL + CELL / 2.0, j * CELL + CELL / 2.0
                tile = project_patch(tex, k, TW, TH, cx, cy, wrap=True)
                ntile = project_patch(nrm_img, k, TW, TH, cx, cy, wrap=True)
                # 法线方向跟着视角换算
                a = ntile[..., 3]
                nv = ntile[..., :3].astype(np.float32) / 255.0 * 2.0 - 1.0
                nv = grid_normals_to_iso(nv, k)
                ntile = encode_normals(nv, a)
                c = j * PERIOD + i
                atlas[k * TH:(k + 1) * TH, c * TW:(c + 1) * TW] = tile
                natlas[k * TH:(k + 1) * TH, c * TW:(c + 1) * TW] = ntile
    return atlas, natlas


# ------------------------------------------------------------------ 地面装饰（格子空间 32x32 → 等距 64x32）
def make_decals(t, rng):
    patches = []
    S = 32
    # 1) 大裂纹
    p = np.zeros((S, S, 4), np.uint8)
    x, y = 3.0, rng.uniform(8, 24)
    for _ in range(40):
        x += rng.uniform(0.5, 1.0)
        y += rng.uniform(-0.9, 0.9)
        if 0 <= int(x) < S and 0 <= int(y) < S:
            p[int(y), int(x)] = (30, 30, 40, 230)
            if rng.random() < 0.15 and int(y) + 1 < S:
                p[int(y) + 1, int(x)] = (30, 30, 40, 200)
    patches.append(p)
    # 2) 苔藓
    p = np.zeros((S, S, 4), np.uint8)
    for _ in range(6):
        cx, cy, r = rng.uniform(8, 24), rng.uniform(8, 24), rng.uniform(3, 7)
        for yy in range(S):
            for xx in range(S):
                d = math.hypot(xx - cx, yy - cy)
                if d < r and rng.random() < 0.85 - d / r * 0.5:
                    m = t["moss"]
                    v = rng.uniform(-10, 10)
                    p[yy, xx] = (int(m[0] + v), int(m[1] + v), int(m[2] + v), 200)
    patches.append(p)
    # 3) 碎石
    p = np.zeros((S, S, 4), np.uint8)
    for _ in range(9):
        cx, cy = rng.randrange(3, S - 3), rng.randrange(3, S - 3)
        c = t["stone"][rng.randrange(len(t["stone"]))]
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)][:rng.randrange(2, 5)]:
            p[cy + dy, cx + dx] = (min(c[0] + 24, 255), min(c[1] + 24, 255), min(c[2] + 24, 255), 255)
        p[cy + 2, cx] = (25, 25, 32, 140)
    patches.append(p)
    # 4) 积灰 / 水渍
    p = np.zeros((S, S, 4), np.uint8)
    cx, cy = 16, 16
    for yy in range(S):
        for xx in range(S):
            d = math.hypot((xx - cx) / 12.0, (yy - cy) / 9.0)
            if d < 1.0 and rng.random() < 0.7:
                p[yy, xx] = (20, 22, 34, int(90 * (1.0 - d)))
    patches.append(p)
    atlas = np.zeros((len(patches) * TH * 2, 4 * TW * 2, 4), np.uint8)
    for r, src in enumerate(patches):
        for k in range(4):
            out = project_patch(src, k, TW * 2, TH * 2, S / 2.0, S / 2.0)
            atlas[r * TH * 2:(r + 1) * TH * 2, k * TW * 2:(k + 1) * TW * 2] = out
    return atlas, len(patches)


# ------------------------------------------------------------------ 方块（墙 / 门 / 活墙）
def cube_masks(wall_h):
    """32x(16+wall_h) 的方块：返回 (面编号图 0=空 1=顶 2=左 3=右, 面内坐标 u, v)。"""
    H = TH + wall_h
    face = np.zeros((H, TW), np.uint8)
    u = np.zeros((H, TW), np.float32)
    v = np.zeros((H, TW), np.float32)
    for py in range(H):
        for px in range(TW):
            x, y = px + 0.5, py + 0.5
            if abs(x - 16) / 16 + abs(y - 8) / 8 <= 1.0:
                face[py, px] = 1
                u[py, px], v[py, px] = iso_to_grid(x - 16, y - 8)
            elif x < 16:
                top = 8 + x / 2.0
                if top <= y < top + wall_h:
                    face[py, px] = 2
                    u[py, px], v[py, px] = x, y - top
            else:
                top = 16 - (x - 16) / 2.0
                if top <= y < top + wall_h:
                    face[py, px] = 3
                    u[py, px], v[py, px] = x - 16, y - top
    return face, u, v


FACE_NORMALS = {1: (0.0, -0.45, 0.89), 2: (-0.62, 0.25, 0.74), 3: (0.62, 0.25, 0.74)}


def cube_normal_map(face, bump=None):
    H, W = face.shape
    out = np.zeros((H, W, 4), np.uint8)
    for f, n in FACE_NORMALS.items():
        m = face == f
        nv = np.array(n, np.float32)
        out[m, :3] = ((nv * 0.5 + 0.5) * 255).astype(np.uint8)
        out[m, 3] = 255
    if bump is not None:
        # 砖缝处法线往里压一点（更有凹凸）
        m = (bump > 0) & (face > 0)
        out[m, 2] = (out[m, 2] * 0.85).astype(np.uint8)
    return out


def shade(c, k):
    return tuple(int(max(0, min(255, x * k))) for x in c)


def make_wall(t, rng, variant, face, u, v):
    H, W = face.shape
    img = np.zeros((H, W, 4), np.uint8)
    mortar = np.zeros((H, W), np.uint8)
    wall_h = H - TH
    brick_jit = {}
    top_noise = np.array([[rng.choice([0, 0, 0, -6, 4, -10]) for _ in range(W)] for _ in range(H)], np.float32)
    for py in range(H):
        for px in range(W):
            f = face[py, px]
            if f == 0:
                continue
            if f == 1:
                # 顶面：整片石面（相连的墙顶连成一片，不画每格的边，否则一排墙顶看起来是格子）
                c = np.array(t["wall_top"], np.float32) + top_noise[py, px]
            else:
                base = t["wall_left"] if f == 2 else t["wall_right"]
                row = int(v[py, px] // 6)
                off = 4 if row % 2 else 0
                bu = u[py, px] + off
                key = (f, row, int(bu // 8))
                if key not in brick_jit:
                    brick_jit[key] = rng.uniform(-8, 8)
                c = np.array(base, np.float32) + brick_jit[key] + rng.uniform(-3, 3)
                if v[py, px] % 6 < 1.0 or bu % 8 < 1.0:
                    c = np.array(t["wall_mortar"], np.float32)
                    mortar[py, px] = 1
                # 底部一行暗一点（墙脚）
                if v[py, px] > wall_h - 1.5:
                    c = c * 0.7
                # 面和面相交的竖棱：左面最右一列亮一点
                if f == 2 and u[py, px] > 15:
                    c = c * 1.12
            img[py, px, :3] = np.clip(c, 0, 255)
            img[py, px, 3] = 255
    if variant == 1:     # 裂缝
        x, y = rng.randrange(3, 13), rng.randrange(TH + 2, TH + 8)
        for _ in range(14):
            if 0 <= x < W and 0 <= y < H and face[y, x] in (2, 3):
                img[y, x, :3] = (26, 28, 40)
                mortar[y, x] = 1
            x += rng.choice([0, 1])
            y += 1
    elif variant == 2:   # 苔藓：顶面一两团 + 往侧面垂几条
        for _ in range(2):
            cu, cv, r = rng.uniform(-5, 5), rng.uniform(-5, 5), rng.uniform(2.5, 4.5)
            for py in range(H):
                for px in range(W):
                    if face[py, px] == 1 and math.hypot(u[py, px] - cu, v[py, px] - cv) < r and rng.random() < 0.8:
                        img[py, px, :3] = shade(t["moss"], rng.uniform(0.9, 1.25))
        for _ in range(4):
            px = rng.randrange(1, W - 1)
            top = 8 + px / 2.0 if px < 16 else 16 - (px - 16) / 2.0
            for dy in range(rng.randrange(2, 7)):
                py = int(top) + dy
                if 0 <= py < H and face[py, px] in (2, 3):
                    img[py, px, :3] = shade(t["moss"], 0.9)
    return img, mortar


def make_gate(t, face, u, v, color):
    """栅栏门块：和墙一样大小的铁栅栏方块（栏杆之间透明，能看到后面）。"""
    H, W = face.shape
    img = np.zeros((H, W, 4), np.uint8)
    wall_h = H - TH
    for py in range(H):
        for px in range(W):
            f = face[py, px]
            if f == 0:
                continue
            if f == 1:
                # 顶上一圈框
                edge = 1.0 - (abs(px + 0.5 - 16) / 16 + abs(py + 0.5 - 8) / 8)
                if edge < 0.18:
                    img[py, px, :3] = shade(color, 1.25 if py < 8 else 0.9)
                    img[py, px, 3] = 255
                continue
            k = 1.0 if f == 2 else 0.75
            bar = u[py, px] % 5 < 1.6
            rail = v[py, px] < 2 or v[py, px] > wall_h - 3 or abs(v[py, px] - wall_h / 2) < 1
            if bar or rail:
                img[py, px, :3] = shade(color, k * (1.2 if bar and u[py, px] % 5 < 0.8 else 1.0))
                img[py, px, 3] = 255
    return img


def make_living(t, rng, face, u, v, frame):
    """活墙：紫黑色、带会起伏的紫色脉络（frame 0/1 起伏，2 = 心跳前发亮）。"""
    H, W = face.shape
    img = np.zeros((H, W, 4), np.uint8)
    r2 = random.Random(77)
    veins = set()
    for _ in range(5):
        f = r2.choice([2, 3])
        x, y = r2.uniform(1, 15), r2.uniform(0, 4)
        for _ in range(26):
            veins.add((f, int(x), int(y)))
            x = min(15.5, max(0.5, x + r2.uniform(-1, 1)))
            y += r2.uniform(0.6, 1.2)
    glow = [0.55, 0.8, 1.25][frame]
    for py in range(H):
        for px in range(W):
            f = face[py, px]
            if f == 0:
                continue
            base = np.array(t["living_base"], np.float32)
            if f == 1:
                c = base * 1.35
            else:
                c = base * (1.0 if f == 2 else 0.78)
                if (f, int(u[py, px]), int(v[py, px])) in veins:
                    c = np.array(t["vein"], np.float32) * glow
                # 一层层的肉质横纹
                elif int(v[py, px]) % 5 == 0:
                    c = c * 0.82
            c = c + rng.uniform(-4, 4)
            img[py, px, :3] = np.clip(c, 0, 255)
            img[py, px, 3] = 255
    return img


def make_living_crack(t):
    out = np.zeros((TH, TW * 2, 4), np.uint8)
    r2 = random.Random(5)
    lines = []
    for _ in range(4):
        x, y = 8.0, 8.0
        pts = []
        a = r2.uniform(0, math.tau)
        for _ in range(7):
            pts.append((x, y))
            a += r2.uniform(-0.6, 0.6)
            x += math.cos(a)
            y += math.sin(a)
        lines.append(pts)
    src = np.zeros((16, 16, 4), np.uint8)
    for pts in lines:
        for (x, y) in pts:
            if 0 <= int(x) < 16 and 0 <= int(y) < 16:
                src[int(y), int(x)] = (*t["vein"], 255)
    for fr, k in enumerate([0.6, 1.3]):
        s = src.copy()
        s[..., :3] = np.clip(s[..., :3].astype(np.float32) * k, 0, 255).astype(np.uint8)
        out[:, fr * TW:(fr + 1) * TW] = project_patch(s, 0, TW, TH, 8, 8)
    return out


# ------------------------------------------------------------------ 主题文件
def write_theme(name, t, n_decals):
    rel = "res://assets/generated/iso/%s/" % name
    files = ["floor.png", "floor_n.png", "decals.png", "walls.png", "walls_n.png", "gate.png", "gate_n.png",
             "living.png", "living_n.png", "living_crack.png"]
    lines = ['[gd_resource type="Resource" script_class="IsoTheme" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/iso/iso_theme.gd" id="s"]']
    for i, f in enumerate(files):
        lines.append('[ext_resource type="Texture2D" path="%s%s" id="t%d"]' % (rel, f, i))
    lines += ["", "[resource]", 'script = ExtResource("s")', 'theme_name = "%s"' % name]
    keys = ["floor", "floor_normal", "decals", "walls", "walls_normal", "gate", "gate_normal", "living", "living_normal", "living_crack"]
    for i, k in enumerate(keys):
        lines.append('%s = ExtResource("t%d")' % (k, i))
    lines += ["floor_period = %d" % PERIOD, "decal_count = %d" % n_decals, "wall_variants = 4",
              "wall_height = %d" % t["wall_h"], "fade_alpha = %s" % t["fade_alpha"], "light_squash = %s" % t["light_squash"], ""]
    out = ROOT / "assets/iso_themes" / (name + ".tres")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines))


def save(arr, path):
    Image.fromarray(arr, "RGBA").save(path)


def build(name):
    t = THEMES[name]
    rng = random.Random(t["seed"])
    out = ROOT / "assets/generated/iso" / name
    out.mkdir(parents=True, exist_ok=True)
    floor, floor_n = make_floor(t, rng)
    save(floor, out / "floor.png")
    save(floor_n, out / "floor_n.png")
    decals, n_decals = make_decals(t, rng)
    save(decals, out / "decals.png")
    face, u, v = cube_masks(t["wall_h"])
    H = face.shape[0]
    walls = np.zeros((H, TW * 4, 4), np.uint8)
    walls_n = np.zeros_like(walls)
    for var in range(4):
        img, mortar = make_wall(t, rng, var, face, u, v)
        walls[:, var * TW:(var + 1) * TW] = img
        walls_n[:, var * TW:(var + 1) * TW] = cube_normal_map(face, mortar)
    save(walls, out / "walls.png")
    save(walls_n, out / "walls_n.png")
    gate = np.zeros((H, TW * 2, 4), np.uint8)
    gate[:, :TW] = make_gate(t, face, u, v, t["gate_iron"])
    gate[:, TW:] = make_gate(t, face, u, v, t["gate_purple"])
    gate_n = np.zeros_like(gate)
    for i in range(2):
        m = cube_normal_map(face)
        m[..., 3] = gate[:, i * TW:(i + 1) * TW, 3]
        gate_n[:, i * TW:(i + 1) * TW] = m
    save(gate, out / "gate.png")
    save(gate_n, out / "gate_n.png")
    living = np.zeros((H, TW * 3, 4), np.uint8)
    for fr in range(3):
        living[:, fr * TW:(fr + 1) * TW] = make_living(t, rng, face, u, v, fr)
    save(living, out / "living.png")
    save(np.concatenate([cube_normal_map(face)] * 3, axis=1), out / "living_n.png")
    save(make_living_crack(t), out / "living_crack.png")
    write_theme(name, t, n_decals)
    print("等距主题：", name, "墙高", t["wall_h"])


if __name__ == "__main__":
    for n in (sys.argv[1:] or list(THEMES)):
        build(n)
