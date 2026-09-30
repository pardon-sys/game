"""共享调色板与像素绘制工具。

公主形象：粉色头发、白皮肤、蓝色眼睛、金色小皇冠；白裙+淡蓝点缀。
改色只需修改 PAL。轮廓色与 Kenney Tiny Dungeon 保持一致。
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated"

OUTLINE = (63, 38, 49, 255)

PAL = {
    ".": None,
    "o": OUTLINE,
    # 头发（粉）
    "h": (244, 143, 186, 255),
    "H": (204, 92, 146, 255),
    "l": (255, 204, 226, 255),
    "n": (160, 60, 110, 255),   # 眉毛/深粉
    # 皮肤（白皙）
    "s": (255, 242, 234, 255),
    "S": (240, 208, 200, 255),
    "k": (255, 158, 178, 255),  # 腮红
    "K": (240, 110, 140, 255),  # 深腮红
    # 眼睛（蓝）
    "e": (72, 142, 238, 255),
    "E": (32, 58, 128, 255),
    "u": (150, 205, 255, 255),
    "i": (255, 255, 255, 255),
    # 嘴
    "m": (206, 92, 108, 255),
    "M": (150, 40, 60, 255),
    # 皇冠（金）
    "c": (255, 214, 72, 255),
    "C": (214, 150, 36, 255),
    "r": (232, 60, 92, 255),    # 红宝石
    # 裙子
    "w": (248, 248, 255, 255),
    "W": (200, 208, 234, 255),
    "b": (130, 188, 255, 255),
    "B": (76, 124, 212, 255),
    # 其它
    "t": (140, 205, 255, 255),  # 泪滴
    "a": (236, 52, 64, 255),    # 怒
    "y": (255, 240, 150, 255),  # 高光黄
    "g": (80, 200, 120, 255),   # 绿
    "G": (40, 140, 80, 255),
    "f": (255, 150, 50, 255),   # 火焰橙
    "F": (255, 90, 40, 255),    # 火焰红
    "Y": (255, 230, 90, 255),   # 火焰黄
    "d": (189, 108, 74, 255),   # 木
    "D": (120, 64, 48, 255),    # 深木
    "x": (192, 203, 220, 255),  # 石亮
    "X": (139, 155, 180, 255),  # 石中
    "z": (82, 96, 124, 255),    # 石暗
    "p": (205, 127, 50, 255),   # 铜
    "P": (150, 85, 30, 255),
}


def grid_to_image(rows, pal=PAL):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == w, f"行长度不一致: {y} {row!r} ({len(row)} != {w})"
        for x, ch in enumerate(row):
            col = pal[ch]
            if col:
                img.putpixel((x, y), col)
    return img


def add_outline(img, color=OUTLINE):
    """给不透明像素外侧加 1px 四邻域轮廓。"""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] and src[nx, ny] != color:
                    dst[x, y] = color
                    break
    return out


def mirror_rows(left_rows, swap=None):
    """左半边 -> 左右对称整行。"""
    swap = swap or {}
    return [r + "".join(swap.get(c, c) for c in reversed(r)) for r in left_rows]


def put(rows, r, c, s):
    """在字符网格 rows 的 (r,c) 位置覆盖字符串 s（'_' 表示保持原样）。"""
    row = list(rows[r])
    for i, ch in enumerate(s):
        if ch != "_":
            row[c + i] = ch
    rows[r] = "".join(row)
