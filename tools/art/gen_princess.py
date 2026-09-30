"""（旧版程序绘制，已被 import_princess2.py 取代）生成 princess_procedural.png

布局：每帧 16x16；每一行是一种表情（EMOTIONS 顺序），每一列是一帧。
朝向：down / up / side（side 朝右，朝左在 Godot 中水平翻转）。
"""
import json

from PIL import Image

from palette import OUT, add_outline, grid_to_image, put

EMOTIONS = ["normal", "happy", "laugh", "sad", "shy", "angry"]

# ---------------------------------------------------------------- 头部（行 0-10）
HEAD = {
    "down": [
        "................",
        ".....c.cc.c.....",
        ".....ccrrcc.....",
        "...hhhhhhhhhh...",
        "..hhlhhhhhhhhh..",
        "..hlhhhhhhhhhh..",
        "..hhhHssssHhhh..",
        "..hhsiEssiEshh..",
        "..hhseesseeshh..",
        "..hHsssmmsssHh..",
        "..hhHSssssSHhh..",
    ],
    "up": [
        "................",
        ".....c.cc.c.....",
        ".....cccccc.....",
        "...hhhhhhhhhh...",
        "..hhhhhhlhhhhh..",
        "..hhhhhlhhhhhh..",
        "..hhhhhhhhhhhh..",
        "..hhhhhhhhhhhh..",
        "..hhhHhhhhHhhh..",
        "..hHhhhbbhhhHh..",
        "..hhHhhhhhhHhh..",
    ],
    "side": [
        "................",
        "......c.cc.c....",
        "......ccrrcc....",
        "....hhhhhhhhh...",
        "...hhlhhhhhhhh..",
        "...hlhhhhhhhhh..",
        "..hhhhhhHsssss..",
        "..hhhhhHssiEss..",
        "..hhhhhHsseess..",
        "..hhhhhhssssms..",
        "...hhhhhHSsss...",
    ],
}

# 表情脸部补丁：(行, 列, [3 行字符串])
FACE_POS = {"down": (7, 4), "side": (7, 8)}
FACES = {
    "down": {
        "normal": ["siEssiEs", "seessees", "sssmmsss"],
        "happy":  ["sEssssEs", "EsEssEsE", "kssmmssk"],
        "laugh":  ["sEssssEs", "EsEssEsE", "ksMMMMsk"],
        "sad":    ["ssssssss", "sEEssEEs", "stsmmsts"],
        "shy":    ["ssssssss", "sEEssEEs", "KKsmmsKK"],
        "angry":  ["ssEssEss", "sEessEEs", "sssMMsss"],
        "hurt":   ["sEssssEs", "ssEssEss", "sssMMsss"],
    },
    "side": {
        "normal": ["ssiEss", "sseess", "ssssms"],
        "happy":  ["sssEss", "ssEsEs", "sskskm"],
        "laugh":  ["sssEss", "ssEsEs", "sskMMs"],
        "sad":    ["ssssss", "ssEEss", "ssstms"],
        "shy":    ["ssssss", "ssEEss", "sKKsms"],
        "angry":  ["ssEsss", "sseEss", "ssssMs"],
        "hurt":   ["ssEsss", "sssEss", "ssssMs"],
    },
}

# ---------------------------------------------------------------- 身体（行 11-14）+ 脚（行 15）
BODY = {
    "down": {
        "stand":  ["..hHwwbbbbwwHh..", "...swwwbbwwws...", "...wwwwbbwwww...", "..WwwbwwwwbwwW.."],
        "hold":   ["..hHwwbbbbwwHh..", "...wwwsbbswww...", "...wwwwbbwwww...", "..WwwbwwwwbwwW.."],
        "swing":  ["..hHwwbbbbwwHh..", "..swwwwbbwwwws..", "...wwwwbbwwww...", "..WwwbwwwwbwwW.."],
    },
    "up": {
        "stand":  ["..hHwwhhhhwwHh..", "...swwhhhhwws...", "...wwwwHHwwww...", "..WwwwwwwwwwwW.."],
        "hold":   ["..hHwwhhhhwwHh..", "...wwwhhhhwww...", "...wwwwHHwwww...", "..WwwwwwwwwwwW.."],
        "swing":  ["..hHwwhhhhwwHh..", "..swwwhhhhwwws..", "...wwwwHHwwww...", "..WwwwwwwwwwwW.."],
    },
    "side": {
        "stand":  ["...hhhhwwbbw....", "....hhwwbbwws...", ".....wwwbbwww...", "....Wwwwwwwwww.."],
        "hold":   ["...hhhhwwbbw....", "....hhwwbbww....", ".....wwwbbwwss..", "....Wwwwwwwwww.."],
        "swing":  ["...hhhhwwbbwss..", "....hhwwbbww....", ".....wwwbbwww...", "....Wwwwwwwwww.."],
    },
}
FEET = {
    "down": {"stand": ".....BB..BB.....", "a": ".....BB.........", "b": ".........BB....."},
    "up":   {"stand": ".....BB..BB.....", "a": ".....BB.........", "b": ".........BB....."},
    "side": {"stand": "......BBBB......", "a": ".....BB...BB....", "b": "......BB.BB....."},
}
# 抬起时（整体上移 1px）第 14 行露出的腿
LEGS = {
    "down": {"a": ".....ss..W......", "b": "......W..ss....."},
    "up":   {"a": ".....ss..W......", "b": "......W..ss....."},
    "side": {"a": "......s...s.....", "b": ".......s.s......"},
}


def head_rows(direction, emotion):
    rows = list(HEAD[direction])
    if direction in FACES:
        r, c = FACE_POS[direction]
        for i, s in enumerate(FACES[direction][emotion]):
            put(rows, r + i, c, s)
    return rows


def frame(direction, emotion, body="stand", feet="stand", head_dy=0, lift=False):
    """合成一帧。lift=True 时头身整体上移 1px 并露出腿。"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    dy = -1 if lift else 0
    body_img = grid_to_image(BODY[direction][body])
    img.alpha_composite(body_img, (0, 11 + dy))
    head_img = grid_to_image(head_rows(direction, emotion))
    img.alpha_composite(head_img, (0, dy + head_dy))
    if lift and feet in LEGS[direction]:
        img.alpha_composite(grid_to_image([LEGS[direction][feet]]), (0, 14))
    img.alpha_composite(grid_to_image([FEET[direction][feet]]), (0, 15))
    return add_outline(img)


# 每个朝向的帧序列：(动画名, [(body, feet, head_dy, lift, face_override)])
SEQ = [
    ("idle", [("stand", "stand", 0, False, None), ("stand", "stand", 1, False, None)]),
    ("walk", [("stand", "a", 0, True, None), ("stand", "stand", 0, False, None),
              ("stand", "b", 0, True, None), ("stand", "stand", 0, False, None)]),
    ("attack", [("hold", "stand", 0, False, None), ("swing", "stand", 0, False, None),
                ("stand", "stand", 0, False, None)]),
    ("dash", [("stand", "a", 0, True, None), ("stand", "b", 0, True, None)]),
    ("hurt", [("stand", "stand", 0, False, "hurt")]),
]
DIRECTIONS = ["down", "up", "side"]


def main():
    columns = []  # (direction, anim, idx, spec)
    anims = {}
    for d in DIRECTIONS:
        for name, frames in SEQ:
            key = f"{name}_{d}"
            anims[key] = []
            for spec in frames:
                anims[key].append(len(columns))
                columns.append((d, spec))
    sheet = Image.new("RGBA", (16 * len(columns), 16 * len(EMOTIONS)), (0, 0, 0, 0))
    for row, emo in enumerate(EMOTIONS):
        for col, (d, (body, feet, hdy, lift, face)) in enumerate(columns):
            f = frame(d, face or emo, body, feet, hdy, lift)
            sheet.alpha_composite(f, (col * 16, row * 16))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "princess_procedural.png")
    meta = {
        "frame_size": 16,
        "hframes": len(columns),
        "emotions": EMOTIONS,
        "animations": anims,
        "fps": {"idle": 2, "walk": 8, "attack": 14, "dash": 12, "hurt": 1},
    }
    (OUT / "princess_procedural.json").write_text(json.dumps(meta, indent=1, ensure_ascii=False))
    print("princess_procedural.png", sheet.size)


if __name__ == "__main__":
    main()
