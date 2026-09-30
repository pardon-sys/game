"""生成公主表情头像 assets/generated/portraits.png（32x32 每格，横向 6 种表情）。

底图用左半边 + 镜像构成，再按表情覆盖眉/眼/嘴/腮红等区域。
"""
from PIL import Image

from palette import OUT, add_outline, grid_to_image, mirror_rows, put
from gen_princess import EMOTIONS

LEFT = [
    "................",  # 0
    "...........c...c",  # 1
    "...........cc..c",  # 2
    "...........ccccr",  # 3
    "........hhhCCCCC",  # 4
    "......hhhhhhhhhh",  # 5
    ".....hhhhhhhhhhh",  # 6
    "....hhhhhhhhhhhh",  # 7
    "....hhhhhhhhhhhh",  # 8
    "...hhhhhhhhhhhhh",  # 9
    "...hhhhhhHhhhhhH",  # 10
    "...hhhhhHsHhhhHs",  # 11
    "..hhhhhHsssHHsss",  # 12
    "..hhhhHsssnnnsss",  # 13 眉
    "..hhhhHsssEEEEss",  # 14 眼
    "..hhhhHssEEieess",  # 15
    "..hhhhHsssEeuess",  # 16
    "..hhhhHsssseEess",  # 17
    "..hhhhHsssssssss",  # 18
    "..hhhhHsssssssss",  # 19
    "..hhhhhHssssssss",  # 20
    "..hhhhhHSsssssmm",  # 21 嘴
    "..hhhhhhHSssssss",  # 22
    "..hhhhhhhHSSssss",  # 23
    "..hhhhhhhhhhHSSs",  # 24
    "..hhhhhhhhhhhHSS",  # 25
    ".hhhhhhhhhwwwbSS",  # 26
    ".hhhhhhhwwwwwwbb",  # 27
    ".hhhhhhwwwwwwwwc",  # 28
    "hhhhhhwwwWwwwwwc",  # 29
    "hhhhhwwwwWwwwwwr",  # 30
    "hhhhwwwwWwwwwwwW",  # 31
]


def base():
    rows = mirror_rows(LEFT)
    # 不对称细节：头发高光、宝石只一颗
    put(rows, 6, 7, "ll")
    put(rows, 7, 6, "ll")
    put(rows, 8, 6, "l")
    put(rows, 3, 15, "rr")
    put(rows, 28, 15, "cc")
    put(rows, 29, 15, "cc")
    put(rows, 30, 15, "rr")
    # 右眼高光与左眼保持同侧
    put(rows, 15, 18, "eeiEE")
    return rows


def set_eyes(rows, left, right=None):
    """left: 4 行 x 5 列（列 9-13），right 默认镜像（列 18-22）。"""
    for i, s in enumerate(left):
        put(rows, 14 + i, 9, s)
        put(rows, 14 + i, 18, right[i] if right else s[::-1])


def set_brows(rows, left):
    """left: 2 行 x 4 列（行 12-13，列 10-13），右侧镜像。"""
    for i, s in enumerate(left):
        put(rows, 12 + i, 10, s)
        put(rows, 12 + i, 18, s[::-1])


def set_mouth(rows, lines, top=20):
    """lines: 若干行 x 6 列（列 13-18）。"""
    for i, s in enumerate(lines):
        put(rows, top + i, 13, s)


def blush(rows, ch="k", wide=False):
    for r in (18, 19):
        put(rows, r, 8, ch * (4 if wide else 3))
        put(rows, r, 20 if not wide else 20, ch * (4 if wide else 3))


CLOSED_HAPPY = ["sssss", "ssEEs", "sEssE", "sssss"]


def emotion(rows, emo):
    if emo == "normal":
        return
    if emo == "happy":
        set_brows(rows, ["ssss", "snnn"])
        put(rows, 17, 10, "EEEE")
        put(rows, 17, 18, "EEEE")
        set_mouth(rows, ["mssssm", "smmmms"], top=20)
        blush(rows)
    elif emo == "laugh":
        set_eyes(rows, CLOSED_HAPPY)
        set_brows(rows, ["ssss", "snnn"])
        set_mouth(rows, ["sMMMMs", "sMkkMs", "ssMMss"], top=20)
        blush(rows)
    elif emo == "sad":
        set_brows(rows, ["sssn", "nnns"])
        set_eyes(rows, ["sssss", "sEEEE", "sEeue", "tseEe"])
        put(rows, 18, 9, "t")
        put(rows, 19, 9, "t")
        put(rows, 18, 22, "t")
        set_mouth(rows, ["ssssss", "ssmmss", "smssms"], top=20)
    elif emo == "shy":
        set_brows(rows, ["sssn", "nnns"])
        blush(rows, "K", wide=True)
        put(rows, 18, 9, "k_k")
        put(rows, 18, 20, "k_k")
        set_mouth(rows, ["ssssss", "smsmss", "ssssss"], top=20)
        # 汗滴
        put(rows, 11, 24, "t")
        put(rows, 12, 24, "t")
    elif emo == "angry":
        set_brows(rows, ["nsss", "snnn"])
        put(rows, 14, 12, "nn")
        put(rows, 14, 18, "nn")
        set_eyes(rows, ["sssss", "sEEEE", "sEeue", "sseEs"])
        set_mouth(rows, ["ssssss", "ssMMss", "sMssMs"], top=20)
        # 怒筋 💢
        for i, line in enumerate(["_a_a_", "aa_aa", "_____", "aa_aa", "_a_a_"]):
            put(rows, 5 + i, 25, line)

def main():
    sheet = Image.new("RGBA", (32 * len(EMOTIONS), 32), (0, 0, 0, 0))
    for i, emo in enumerate(EMOTIONS):
        rows = base()
        emotion(rows, emo)
        sheet.alpha_composite(add_outline(grid_to_image(rows)), (i * 32, 0))
    sheet.save(OUT / "portraits_procedural.png")
    print("portraits_procedural.png", sheet.size)


if __name__ == "__main__":
    main()
