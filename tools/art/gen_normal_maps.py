"""2.5D 楼层用的图块法线贴图 / 高光贴图（tools/build/build_level.gd 在 [level] style = 2.5d 时用）。

每张图集按 16x16 一格单独算（不跨格采样，接缝不会串）：
  高度 = 亮度（砖缝、裂纹暗 → 低）+ 每格边缘一圈轻微的倒角（墙顶、墙面的砖块像有厚度）
  法线 = 高度的梯度（Sobel），存成 RGB（x 右、y 下、z 朝外）
  高光 = 地砖偏亮（像微湿的石头）、墙偏哑；透明处为 0
输出 assets/generated/normal/<图集名>_n.png、<图集名>_s.png。
用法：python tools/art/gen_normal_maps.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/generated/normal"
TILE = 16
# 图集 → (高度里亮度的权重, 倒角强度, 高光亮度)
ATLASES = {
    "tilemap_packed": (ROOT / "assets/third_party/kenney_tiny_dungeon/tilemap_packed.png", 1.0, 0.25, 0.42),
    "walls": (ROOT / "assets/generated/walls.png", 0.8, 0.6, 0.18),
    "wall_faces": (ROOT / "assets/generated/wall_faces.png", 1.0, 0.45, 0.22),
}
STRENGTH = 2.2


def tile_normals(rgba: np.ndarray, lum_w: float, bevel: float) -> np.ndarray:
    a = rgba[..., 3] / 255.0
    lum = (rgba[..., 0] * 0.299 + rgba[..., 1] * 0.587 + rgba[..., 2] * 0.114) / 255.0
    h = lum * lum_w * a
    # 每格边缘的倒角：离格子边越近越低
    yy, xx = np.mgrid[0:TILE, 0:TILE]
    edge = np.minimum(np.minimum(xx, TILE - 1 - xx), np.minimum(yy, TILE - 1 - yy))
    h = h + np.clip(edge / 2.0, 0.0, 1.0) * bevel * a
    p = np.pad(h, 1, mode="edge")
    gx = (p[1:-1, 2:] - p[1:-1, :-2]) + 0.5 * ((p[:-2, 2:] - p[:-2, :-2]) + (p[2:, 2:] - p[2:, :-2]))
    gy = (p[2:, 1:-1] - p[:-2, 1:-1]) + 0.5 * ((p[2:, :-2] - p[:-2, :-2]) + (p[2:, 2:] - p[:-2, 2:]))
    n = np.stack([-gx * STRENGTH, -gy * STRENGTH, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (path, lum_w, bevel, spec) in ATLASES.items():
        img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
        h, w = img.shape[:2]
        normal = np.zeros((h, w, 3), np.float32)
        normal[..., 2] = 1.0
        for ty in range(0, h - h % TILE, TILE):
            for tx in range(0, w - w % TILE, TILE):
                normal[ty:ty + TILE, tx:tx + TILE] = tile_normals(img[ty:ty + TILE, tx:tx + TILE], lum_w, bevel)
        nrgb = ((normal * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
        alpha = img[..., 3].astype(np.uint8)
        Image.fromarray(np.dstack([nrgb, np.full_like(alpha, 255)]), "RGBA").save(OUT / f"{name}_n.png")
        lum = (img[..., 0] * 0.299 + img[..., 1] * 0.587 + img[..., 2] * 0.114) / 255.0
        s = (spec * (0.6 + 0.4 * lum) * 255 * (alpha / 255.0)).clip(0, 255).astype(np.uint8)
        Image.fromarray(np.dstack([s, s, s, np.full_like(s, 255)]), "RGBA").save(OUT / f"{name}_s.png")
        print("法线贴图：", name, w, "x", h)


if __name__ == "__main__":
    main()
