"""队长出招的精灵图（assets/generated/npcs/captain_cast.png，4×4 格 48×48）：
行 = 下 / 左 / 右 / 上（和行走图一样），列 = 0 蓄力（木矛往后收、身子后仰）/ 1 刺（矛尖往前送出去、身子前倾，矛尖后面几道速度线）
/ 2 扫（矮身，矛杆贴地横着扫出去）/ 3 收招（矛竖在身侧）。
身子用 gen_town_art.captain_frame（不画剑），木矛是训练用的：褐色矛杆、矛尖包着米白的布。
用法：python tools/art/gen_captain_cast.py（训练室「队长的旧剑术」QuestSpear 出招时换上这张图）
"""
from PIL import ImageDraw

from gen_expansion import blank
from gen_town_art import captain_frame, CREAM, GOLD_D, LEATHER
from palette import OUT, add_outline

CELL = 48
SHAFT, SHAFT_D = (150, 104, 62, 255), (104, 70, 42, 255)
CLOTH, CLOTH_D = CREAM, (200, 190, 168, 255)
SPEED = (255, 246, 214, 170)
DUST = (214, 196, 168, 200)
# 朝向：行 → (前方向量)
FACING = {0: (0, 1), 1: (-1, 0), 2: (1, 0), 3: (0, -1)}


def _spear(d, butt, tip):
    """矛杆从 butt 到 tip，矛尖一团包布"""
    d.line((*butt, *tip), fill=SHAFT, width=2)
    d.line((butt[0], butt[1], tip[0], tip[1]), fill=SHAFT_D, width=1)
    tx, ty = tip
    d.ellipse((tx - 2, ty - 2, tx + 2, ty + 2), fill=CLOTH)
    d.point((tx + 1, ty - 1), fill=CLOTH_D)
    # 绑布的绳
    bx, by = tx - (tip[0] - butt[0]) * 0.12, ty - (tip[1] - butt[1]) * 0.12
    d.point((round(bx), round(by)), fill=GOLD_D)


def cast_frame(row, pose):
    img = blank(CELL, CELL)
    d = ImageDraw.Draw(img)
    fx, fy = FACING[row]
    # 身子的偏移：蓄力往后仰、刺往前探、扫矮下去
    off = {0: (-fx, -fy), 1: (fx * 2, fy * 2), 2: (fx, 2), 3: (0, 0)}[pose]
    body = captain_frame(row, 0, sword=False, outline=False)
    if pose == 2:
        # 矮身：腿收短（把下半身往上挤 2 像素）
        body = body.crop((0, 0, 32, 30)).resize((32, 30))
    hand = (24 + off[0] + (fx * 4 if fx else 6), 27 + off[1] + (fy * 3 if fy else 0))
    behind = row == 3       # 背面：矛在身子前面挡住的那边，先画矛再画身子
    spear_lines = []
    if pose == 0:
        spear_lines.append(((hand[0] - fx * 14 - (0 if fx else 0), hand[1] - fy * 12 + (0 if fy else -2)), (hand[0] + fx * 6, hand[1] + fy * 6)))
    elif pose == 1:
        tip = (hand[0] + fx * 21, hand[1] + fy * 18)
        spear_lines.append(((hand[0] - fx * 6, hand[1] - fy * 6), tip))
    elif pose == 2:
        # 矛杆贴地横扫：正面 / 背面横在脚前，侧面贴着地面往前扫出去
        if fy:
            low = (hand[0], hand[1] + 6 + fy * 4)
            spear_lines.append(((low[0] - 16, low[1]), (low[0] + 16, low[1])))
        else:
            spear_lines.append(((hand[0] - fx * 8, hand[1] + 6), (hand[0] + fx * 18, 43)))
    else:
        side = 33 if row != 1 else 15
        spear_lines.append(((side, 40), (side, 12)))
    if behind:
        for b, t in spear_lines:
            _spear(d, b, t)
    img.alpha_composite(body, (8 + off[0], 8 + off[1] + (2 if pose == 2 else 0)))
    d = ImageDraw.Draw(img)
    if not behind:
        for b, t in spear_lines:
            _spear(d, b, t)
    # 握矛的手
    if pose != 3:
        d.rectangle((hand[0] - 1, hand[1] - 1, hand[0], hand[1]), fill=LEATHER)
    out = add_outline(img)
    od = ImageDraw.Draw(out)
    if pose == 1:
        # 刺：矛尖后面几道速度线
        b, t = spear_lines[0]
        for k in (-3, 0, 3):
            px, py = (k, 0) if fy else (0, k)
            od.line((t[0] - fx * 10 + px, t[1] - fy * 10 + py, t[0] - fx * 18 + px, t[1] - fy * 18 + py), fill=SPEED)
    elif pose == 2:
        # 扫：地上一小团尘土
        b, t = spear_lines[0]
        for (x, y) in (b, t):
            od.ellipse((x - 2, y + 1, x + 2, y + 3), fill=DUST)
    return out


def main():
    sheet = blank(CELL * 4, CELL * 4)
    for row in range(4):
        for pose in range(4):
            sheet.alpha_composite(cast_frame(row, pose), (pose * CELL, row * CELL))
    (OUT / "npcs").mkdir(exist_ok=True)
    sheet.save(OUT / "npcs" / "captain_cast.png")
    print("队长出招图已生成：", OUT / "npcs" / "captain_cast.png")


if __name__ == "__main__":
    main()
