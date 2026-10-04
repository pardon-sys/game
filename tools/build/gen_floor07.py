"""生成第七层「升天回廊」：一座往上走的高塔（之字形的七层大厅，坡道左右交替），+ 本层的石碑对话 + 过场。

地图（levels/floor_07/map.txt，build_level.gd -- floor=floor_07 构建）：
  第 0 层（最下）：起点、存档点（本层唯一）、蓝色公主到达点 blue_start
  第 1 / 3 / 4 层：各两组新的三来源组合（design.json 的 combo_areas）
  第 2 / 5 层：锁门战斗房（arena）；第 5 层另有一组组合
  第 6 层（最上）：一组组合 + 封住的出口（以后接第八层）
  大厅之间的坡道 3 格宽，偶数层在右边、奇数层在左边。沿路放已有的怪物 / 陷阱 / 巢穴，密度高。
过场：data/cutscenes/floor_07/f7_pink_run（粉色公主进塔后往上冲）、f7_blue_arrive（蓝色公主到达）。
用法：python tools/build/gen_floor07.py，然后 build_level.gd -- floor=floor_07
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")


class Map:
    def __init__(self, fid, w, h, header):
        self.fid, self.w, self.h, self.header = fid, w, h, header
        self.g = [["#"] * w for _ in range(h)]
        self.specs = {}
        self.pool = list(POOL)
        self.cells = {}

    def E(self, spec):
        fixed = {"player": "P", "torch lit=true": "t"}
        if spec in fixed:
            return fixed[spec]
        if spec not in self.specs:
            self.specs[spec] = self.pool.pop(0)
        return self.specs[spec]

    def room(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = "."

    def put(self, x, y, spec):
        """同一格可以放多个（最后用 " + " 连起来）。"""
        self.cells.setdefault((x, y), []).append(spec)

    def torch(self, x, y):
        assert self.g[y][x] == "#", (x, y)
        self.cells[(x, y)] = ["torch lit=true"]

    def write(self):
        for (x, y), specs in self.cells.items():
            self.g[y][x] = self.E(" + ".join(specs))
        out = Path("levels") / self.fid
        out.mkdir(parents=True, exist_ok=True)
        legend = "".join("%s = %s\n" % (c, s) for s, c in self.specs.items())
        head = "[level]\n# 第七层·升天回廊（tools/build/gen_floor07.py 生成，不要直接改）\n" + self.header + "\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n"
        (out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in self.g) + "\n")
        print("%s：%dx%d，图例 %d 种" % (self.fid, self.w, self.h, len(self.specs)))


W, STOREYS, HALL_H, GAP = 48, 7, 9, 4
PITCH = HALL_H + GAP
H = 4 + STOREYS * PITCH
m = Map("floor_07", W, H, "intro =\nintro_cutscene = f7_pink_run\nambient = 0.5,0.46,0.62")


def hall_top(k):
    """第 k 层大厅最上面一行（k = 0 是最下面）。"""
    return H - 2 - HALL_H - k * PITCH


for k in range(STOREYS):
    y0 = hall_top(k)
    m.room(2, y0, W - 3, y0 + HALL_H - 1)
    for x in (10, 19, 28, 37):                    # 火把避开两边的坡道口
        m.torch(x, y0 - 1)
    if k < STOREYS - 1:
        rx = W - 7 if k % 2 == 0 else 4          # 坡道：偶数层在右、奇数层在左
        m.room(rx, y0 - GAP, rx + 2, y0 - 1)


def area(k, x0, x1):
    y0 = hall_top(k)
    return [x0, y0 - 1, x1, y0 + HALL_H - 1]


design = []

# —— 第 0 层：起点 ——
y = hall_top(0)
m.put(8, y + 6, "player")
m.put(6, y + 3, "savepoint place=升天回廊·塔底")
m.put(10, y + 6, "spawn id=blue_start")
m.put(12, y + 2, "sign dialogue=sign7_tower")
for (x, yy, t) in ((22, y + 4, "slime"), (30, y + 6, "slime"), (36, y + 3, "rat"), (40, y + 6, "bat")):
    m.put(x, yy, "monster type=" + t)
m.put(26, y + 5, "trap type=feather")
m.put(33, y + 2, "trap type=rune")

# —— 第 1 层：蜘蛛绑腿刷（左）、章鱼背心（右）——
y = hall_top(1)
m.put(8, y + 5, "trap type=binding")
m.put(6, y + 3, "monster type=spider")
m.put(11, y + 3, "monster type=hedgehog")
design.append({"combo": "spider_binding_brush", "rect": area(1, 3, 14)})
m.put(38, y + 4, "trap type=vest")
m.put(36, y + 2, "monster type=octopus")
m.put(41, y + 2, "monster type=fairy")
design.append({"combo": "octopus_vest", "rect": area(1, 33, 44)})
for (x, yy, sp) in ((20, y + 2, "trap type=feather"), (24, y + 6, "trap type=cage idle_time=2.4 offset=0.0"), (28, y + 3, "nest type=rat"),
                    (22, y + 7, "monster type=crab"), (30, y + 6, "monster type=caterpillar")):
    m.put(x, yy, sp)

# —— 第 2 层：锁门战斗房 ——
y = hall_top(2)
m.put(14, y + 1, "arena group=arena_f7a w=20 h=7")
# 第 2 层：从下面的左坡道上来、从右坡道往上去
for x in range(4, 7):
    m.put(x, y + HALL_H, "gate group=arena_f7a is_open=true")
for x in range(W - 7, W - 4):
    m.put(x, y - 1, "gate group=arena_f7a is_open=true")
for (x, yy, t) in ((18, y + 3, "monster type=glove pair=g7a"), (28, y + 3, "monster type=glove pair=g7a"), (22, y + 6, "monster type=frog"),
                   (26, y + 6, "monster type=squirrel"), (30, y + 4, "monster type=fairy")):
    m.put(x, yy, t)

# —— 第 3 层：衣柜幽灵手（左，衣柜装在上面的墙上）、泥沼蛙舞（右）——
y = hall_top(3)
m.put(9, y - 1, "walltrap type=wardrobe")
m.put(7, y + 3, "monster type=ghost")
m.put(12, y + 3, "monster type=glove pair=g7b")
m.put(13, y + 5, "monster type=glove pair=g7b")
design.append({"combo": "wardrobe_ghost", "rect": area(3, 3, 15)})
m.put(38, y + 4, "trap type=mud")
m.put(35, y + 3, "monster type=frog")
m.put(41, y + 5, "monster type=caterpillar")
design.append({"combo": "mud_frog_dance", "rect": area(3, 33, 44)})
for (x, yy, sp) in ((20, y + 4, "trap type=vent idle_time=2.0 cloud_duration=1.2 offset=0.6"), (25, y + 2, "nest type=fairy"),
                    (28, y + 6, "trap type=feather"), (23, y + 7, "monster type=bubble_fish")):
    m.put(x, yy, sp)

# —— 第 4 层：刑床水母（左）、坐垫落笼（右）——
y = hall_top(4)
m.put(8, y + 4, "trap type=supine")
m.put(6, y + 2, "monster type=mana_jelly")
m.put(11, y + 6, "monster type=bubble_fish")
design.append({"combo": "supine_jelly", "rect": area(4, 3, 14)})
m.put(38, y + 4, "trap type=cushion")
m.put(38, y + 4, "trap type=cage idle_time=2.4 offset=0.6")
m.put(41, y + 6, "monster type=rat")
m.put(35, y + 2, "nest type=rat")
design.append({"combo": "cushion_cage", "rect": area(4, 33, 44)})
for (x, yy, sp) in ((20, y + 3, "trap type=rune"), (24, y + 6, "nest type=slime"), (28, y + 2, "monster type=octopus"),
                    (30, y + 6, "monster type=split_slime")):
    m.put(x, yy, sp)

# —— 第 5 层：转盘藤壶（左）+ 锁门战斗房（右半边）——
y = hall_top(5)
m.put(8, y + 4, "trap type=spinwheel")
m.put(11, y + 2, "monster type=barnacle")
m.put(6, y + 6, "monster type=squirrel")
design.append({"combo": "spin_barnacle", "rect": area(5, 3, 14)})
m.put(24, y + 1, "arena group=arena_f7b w=16 h=7")
# 第 5 层：从下面的右坡道上来、从左坡道往上去
for x in range(W - 7, W - 4):
    m.put(x, y + HALL_H, "gate group=arena_f7b is_open=true")
for x in range(4, 7):
    m.put(x, y - 1, "gate group=arena_f7b is_open=true")
for (x, yy, t) in ((28, y + 3, "monster type=hedgehog"), (34, y + 5, "monster type=imp"), (32, y + 2, "monster type=ghost"),
                   (36, y + 6, "monster type=mini_tentacle")):
    m.put(x, yy, t)
m.put(18, y + 4, "trap type=feather")

# —— 第 6 层（最上）：吊环手套 + 封住的出口 ——
y = hall_top(6)
m.put(36, y + 4, "trap type=legloop")
m.put(37, y + 4, "trap type=teaser")
m.put(34, y + 2, "monster type=glove pair=g7c")
m.put(40, y + 6, "monster type=glove pair=g7c")
design.append({"combo": "legloop_glove", "rect": area(6, 31, 44)})
m.put(14, y + 2, "sign dialogue=sign7_top")
m.g[y - 1][24] = "."
m.put(24, y - 1, "exit target=floor_07 locked=true dialogue=sign7_sealed")
for (x, yy, t) in ((18, y + 5, "monster type=caterpillar"), (22, y + 3, "monster type=fairy"), (28, y + 6, "trap type=rune")):
    m.put(x, yy, t)
m.write()
Path("levels/floor_07/design.json").write_text(json.dumps({
    "_说明": ["第七层（gen_floor07.py 生成）：combo_areas = 每组新组合所在的区域（格，含上墙，左上 → 右下），level_design_test 检查区域里有组合需要的陷阱和怪物。"],
    "combo_areas": design}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 对话 / 过场
P, BLUE, N, S = "公主", "蓝色的公主", "", "石碑"
DLG = Path("data/dialogues/floor_07")
DLG.mkdir(parents=True, exist_ok=True)
SIGNS = {
    "sign7_tower": [{"speaker": S, "text": "【升天回廊】一层一层往上盘的高塔。坡道左右交替，越往上机关和怪物越多。\n塔底的日记本是这一层唯一能存档的地方。"}],
    "sign7_top": [{"speaker": S, "text": "【回廊顶层】再往上，是封住的门。"}],
    "sign7_sealed": [{"speaker": BLUE, "text": "……门封住了。门那边……有她的气息。"}],
}
(DLG / "signs.json").write_text(json.dumps(SIGNS, ensure_ascii=False, indent="\t") + "\n")


def A(do, **kw):
    kw["do"] = do
    return kw


def line(speaker, text, emotion=None, actions=None):
    s = {"speaker": speaker, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    return s


y0 = hall_top(0)
PINK_RUN = {"name": "第七层：一路向上", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("pose", emotion="normal", laugh=0)], "wait": 0.5},
    line(P, "……终于下来了。门后面……是一座往上的塔？", "surprise", [A("bubble", who="princess", kind="surprise")]),
    line(P, "往上……一直往上，就能回到地面了吧。", "sad"),
    line(P, "小镇的大家、队长……还有她。……对不起。", "sad", [A("bubble", who="princess", kind="dots")]),
    line(P, "可是我不会再被抓回去了。……我一定要逃出去！", "angry"),
    {"actions": [A("move", who="princess", to=[W - 6, y0 + 4], speed=110), A("camera", who="princess", time=0.6)]},
    {"actions": [A("move", who="princess", to=[W - 6, y0 - GAP], speed=110)]},
    {"actions": [A("fade_out", time=0.8), A("set_flag", flag="f7_pink_ran")], "wait": 0.9},
]}
BLUE_ARRIVE = {"name": "第七层：她往上去了", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("fade_in", time=0.5)], "wait": 0.5},
    line(BLUE, "……塔。"),
    line(BLUE, "……地上有她的脚印。往上去了。", actions=[A("camera", to=[W - 6, y0 + 2], time=1.0)]),
    line(BLUE, "……等我。", actions=[A("camera", who="princess", time=0.6),
         A("notify", text="目标：在升天回廊里寻找粉色的公主（塔底的日记本可以存档）")]),
]}
CUT = Path("data/cutscenes/floor_07")
CUT.mkdir(parents=True, exist_ok=True)
for name, c in (("f7_pink_run", PINK_RUN), ("f7_blue_arrive", BLUE_ARRIVE)):
    (CUT / (name + ".json")).write_text(json.dumps(c, ensure_ascii=False, indent="\t") + "\n")
print("第七层：%d 组组合区域、2 个战斗房、2 段过场" % len(design))
