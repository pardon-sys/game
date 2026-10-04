"""生成第七层「升天回廊」：一座往上走的高塔（之字形的七层大厅，坡道左右交替），+ 本层的石碑对话 + 过场。

地图（levels/floor_07/map.txt，build_level.gd -- floor=floor_07 构建）：
  每层大厅被三道内墙切成四个房间（门洞上下错开、走之字形），有柱子和放宝箱的死胡同，像地牢而不是空场。
  第 0 层（最下）：起点、存档点（本层唯一）、蓝色公主到达点 blue_start；两组组合
  第 1 / 3 / 5 / 6 层的入口：检查点（共 4 个）
  20 组三来源组合（每组一个房间，design.json 的 combo_areas）：本层的 8 组 + 前面各层的 8 组 + 新的 4 组
  （吊环刑床、俯卧转轮、铐柱淋浴史莱姆、符文羽翼）；吊环刑床、夹腿痒刑、俯卧转轮带传送带连锁（中了一个被送进下一个）。
  第 2 / 5 层：锁门战斗房（arena）；第 6 层（最上）：封住的出口（以后接第八层）
  大厅之间的坡道 3 格宽，偶数层在右边、奇数层在左边。
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


# 每层大厅用三道内墙（x = 13 / 24 / 35）切成四个房间 A B C D，墙上留门洞（相邻两道墙的门洞上下错开，路线走之字形）；
# 房间里再加柱子、带宝箱的死胡同。坡道口：偶数层往上的坡道在右（D 房 x 41~43），奇数层在左（A 房 x 4~6）。
ROOMS = {"A": (2, 12), "B": (14, 23), "C": (25, 34), "D": (36, 45)}
PARTS = (13, 24, 35)
DOORS = {   # 每层三道内墙的门洞（相对大厅顶部的行）；第 0 层三个门洞对齐在第 3~5 行（粉色公主过场里直线跑过去）
    0: [(3, 5), (3, 5), (3, 5)],
    1: [(1, 3), (5, 7), (1, 3)],
    2: [(5, 7), None, (5, 7)],
    3: [(5, 7), (1, 3), (5, 7)],
    4: [(1, 3), (5, 7), (1, 3)],
    5: [(5, 7), None, None],
    6: [(1, 3), (5, 7), (1, 3)],
}
# 战斗房那两层的内墙位置不同（中间留开阔的场地）
ARENA_PARTS = {2: {13: (5, 7), 35: (5, 7)}, 5: {13: (5, 7), 22: (1, 3), 40: (4, 7)}}

for k in range(STOREYS):
    y0 = hall_top(k)
    m.room(2, y0, W - 3, y0 + HALL_H - 1)
    for x in (10, 19, 28, 37):                    # 火把避开两边的坡道口和内墙
        m.torch(x, y0 - 1)
    if k < STOREYS - 1:
        rx = W - 7 if k % 2 == 0 else 4          # 坡道：偶数层在右、奇数层在左
        m.room(rx, y0 - GAP, rx + 2, y0 - 1)
    parts = ARENA_PARTS.get(k) or {x: d for x, d in zip(PARTS, DOORS[k]) if d}
    for x, (d0, d1) in parts.items():
        for yy in range(HALL_H):
            if not d0 <= yy <= d1:
                m.g[y0 + yy][x] = "#"


def pillar(k, x, dy):
    y0 = hall_top(k)
    assert m.g[y0 + dy][x] == ".", (k, x, dy)
    m.g[y0 + dy][x] = "#"


def nook(k, x, item, top=True):
    """死胡同：贴着上墙（或下墙）的 1 格宽、2 格深的小凹槽，最里面放宝箱。凹槽两边是墙。"""
    y0 = hall_top(k)
    ys = (0, 1) if top else (HALL_H - 1, HALL_H - 2)
    for yy in ys:
        m.g[y0 + yy][x - 1] = "#"
        m.g[y0 + yy][x + 1] = "#"
    m.put(x, y0 + ys[0], "chest item=" + item)


def area(k, room):
    x0, x1 = ROOMS[room] if isinstance(room, str) else room
    y0 = hall_top(k)
    return [x0, y0 - 1, x1, y0 + HALL_H - 1]


design = []


def combo(cid, k, room, *items):
    """在 k 层的某个房间里放一组组合（items = (dx, dy, spec)，相对房间左上角）。"""
    x0 = (ROOMS[room] if isinstance(room, str) else room)[0]
    y0 = hall_top(k)
    for dx, dy, spec in items:
        m.put(x0 + dx, y0 + dy, spec)
    design.append({"combo": cid, "rect": area(k, room)})


def put_all(k, items):
    y0 = hall_top(k)
    for x, dy, spec in items:
        m.put(x, y0 + dy, spec)


# —— 第 0 层：起点（A），往右穿过三个房间到右边的坡道 ——
y = hall_top(0)
m.put(8, y + 6, "player")
m.put(7, y + 4, "savepoint place=升天回廊·塔底")
m.put(10, y + 6, "spawn id=blue_start")
m.put(11, y + 2, "sign dialogue=sign7_tower")
pillar(0, 18, 1); pillar(0, 18, 7); pillar(0, 30, 1); pillar(0, 30, 7)
put_all(0, ((16, 6, "monster type=slime"), (21, 2, "monster type=rat"), (20, 7, "trap type=feather")))
nook(0, 22, "heart", top=False)
combo("snare_sole_feast", 0, "C", (4, 6, "trap type=snare group=f7s"), (2, 2, "monster type=rat"), (7, 7, "monster type=crab"))
combo("mud_sink", 0, "D", (1, 6, "trap type=mud w=3 h=2"), (8, 6, "monster type=rat"), (3, 1, "monster type=slime"))
put_all(0, ((44, 2, "trap type=rune"),))

# —— 第 1 层：从右（D）进来，往左走到左边的坡道（A）——
y = hall_top(1)
m.put(42, y + 7, "checkpoint")
combo("octopus_vest", 1, "D", (2, 4, "trap type=vest"), (1, 1, "monster type=octopus"), (8, 2, "monster type=fairy"))
combo("thigh_torture", 1, "C", (4, 2, "trap type=teaser group=f7t"), (4, 4, "trap type=clamp group=f7t + trap type=conveyor dir=left len=3"),
      (5, 6, "trap type=wheel group=f7t"))
pillar(1, 26, 7); pillar(1, 33, 7)
combo("armpit_rain", 1, "B", (5, 3, "trap type=cuffs group=f7c + trap type=shower group=f7c"), (2, 7, "monster type=fairy"),
      (8, 6, "monster type=fairy"))
combo("spider_binding_brush", 1, "A", (6, 5, "trap type=binding"), (9, 3, "monster type=spider"), (9, 7, "monster type=hedgehog"))
nook(1, 8, "star_candy")

# —— 第 2 层：锁门战斗房（中间开阔），左右各一组组合 ——
y = hall_top(2)
combo("prone_full", 2, "A", (7, 2, "trap type=prone group=f7p"), (8, 3, "trap type=wheel group=f7p"), (9, 6, "monster type=squirrel"))
m.put(14, y + 1, "arena group=arena_f7a w=20 h=7")
for x in range(4, 7):
    m.put(x, y + HALL_H, "gate group=arena_f7a is_open=true")
for x in range(W - 7, W - 4):
    m.put(x, y - 1, "gate group=arena_f7a is_open=true")
pillar(2, 18, 2); pillar(2, 29, 2); pillar(2, 18, 6); pillar(2, 29, 6)
put_all(2, ((20, 3, "monster type=glove pair=g7a"), (27, 3, "monster type=glove pair=g7a"), (22, 6, "monster type=frog"),
            (26, 6, "monster type=squirrel"), (24, 4, "monster type=fairy"), (16, 4, "trap type=feather"), (31, 4, "trap type=feather")))
combo("one_leg_show", 2, "D", (2, 6, "trap type=legloop group=f7l"), (3, 7, "trap type=wheel group=f7l"), (7, 2, "monster type=rat"))

# —— 第 3 层：从右（D）进来，往左 ——
y = hall_top(3)
m.put(42, y + 7, "checkpoint")
combo("mud_frog_dance", 3, "D", (1, 2, "trap type=mud w=3 h=2"), (6, 2, "monster type=frog"), (4, 6, "monster type=caterpillar"))
combo("cuffs_shower_slime", 3, "C", (4, 4, "trap type=cuffs group=f7w + trap type=shower group=f7w"), (1, 7, "monster type=slime"),
      (8, 1, "monster type=split_slime"))
pillar(3, 16, 4); pillar(3, 21, 4)
put_all(3, ((18, 1, "nest type=fairy"), (19, 6, "trap type=vent idle_time=2.0 cloud_duration=1.2 offset=0.6"),
            (15, 7, "monster type=bubble_fish")))
nook(3, 22, "mint", top=False)
combo("wardrobe_ghost", 3, "A", (7, -1, "walltrap type=wardrobe"), (5, 3, "monster type=ghost"), (9, 3, "monster type=glove pair=g7b"),
      (9, 6, "monster type=glove pair=g7b"))

# —— 第 4 层：从左（A）进来，往右 ——
y = hall_top(4)
combo("supine_jelly", 4, "A", (6, 5, "trap type=supine"), (8, 2, "monster type=mana_jelly"), (9, 7, "monster type=bubble_fish"))
# 吊环刑床：被吊环吊住、挣脱后脚下的传送带把人送上刑床（连锁）
combo("loop_rack", 4, "B", (2, 4, "trap type=legloop group=f7r + trap type=conveyor dir=right len=3"), (5, 4, "trap type=supine group=f7r2"),
      (5, 3, "trap type=teaser group=f7r2"), (8, 7, "monster type=frog"))
combo("wardrobe_inout", 4, "C", (6, -1, "walltrap type=wardrobe"), (2, 5, "monster type=rat"), (8, 6, "monster type=slime"))
pillar(4, 27, 3); pillar(4, 32, 3)
combo("cushion_cage", 4, "D", (3, 5, "trap type=cushion + trap type=cage idle_time=2.4 offset=0.6"), (8, 7, "monster type=rat"),
      (1, 1, "nest type=rat"))
nook(4, 40, "heart")

# —— 第 5 层：从右（D 前厅）进来，穿过战斗房往左 ——
y = hall_top(5)
m.put(43, y + 7, "checkpoint")
m.put(24, y + 1, "arena group=arena_f7b w=16 h=7")
for x in range(W - 7, W - 4):
    m.put(x, y + HALL_H, "gate group=arena_f7b is_open=true")
for x in range(4, 7):
    m.put(x, y - 1, "gate group=arena_f7b is_open=true")
pillar(5, 27, 2); pillar(5, 36, 2); pillar(5, 27, 6); pillar(5, 36, 6)
put_all(5, ((29, 3, "monster type=hedgehog"), (34, 5, "monster type=imp"), (32, 2, "monster type=ghost"), (31, 7, "monster type=mini_tentacle")))
combo("rune_wings", 5, (14, 21), (3, 4, "trap type=rune"), (2, 1, "monster type=bat"), (6, 7, "monster type=fairy"))
combo("spin_barnacle", 5, "A", (6, 4, "trap type=spinwheel"), (9, 2, "monster type=barnacle"), (2, 6, "monster type=squirrel"))

# —— 第 6 层（最上）：从左（A）进来；C 房是封住的出口 ——
y = hall_top(6)
m.put(5, y + 7, "checkpoint")
combo("supine_navel", 6, "A", (8, 3, "trap type=teaser group=f7n"), (8, 4, "trap type=supine group=f7n"), (3, 1, "monster type=frog"))
combo("prone_wheel_crawl", 6, "B", (4, 6, "trap type=prone group=f7q + trap type=conveyor dir=left len=2"), (5, 7, "trap type=wheel group=f7q"),
      (8, 2, "monster type=caterpillar"))
m.put(29, y + 2, "sign dialogue=sign7_top")
m.g[y - 1][30] = "."
m.put(30, y - 1, "exit target=floor_07 locked=true dialogue=sign7_sealed")
pillar(6, 27, 5); pillar(6, 33, 5)
put_all(6, ((30, 6, "monster type=caterpillar"), (26, 3, "trap type=rune")))
combo("legloop_glove", 6, "D", (4, 4, "trap type=legloop"), (5, 4, "trap type=teaser"), (2, 2, "monster type=glove pair=g7c"),
      (8, 6, "monster type=glove pair=g7c"))
nook(6, 44, "star_candy")


def check_reachable():
    """从起点出发能走到每一格地板（不考虑陷阱 / 门）——内墙的门洞不会把房间关死。"""
    start = next((x, yy) for (x, yy), sp in m.cells.items() if "player" in sp)
    seen, todo = {start}, [start]
    while todo:
        x, yy = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, yy + dy)
            if n not in seen and 0 <= n[1] < H and 0 <= n[0] < W and m.g[n[1]][n[0]] != "#":
                seen.add(n)
                todo.append(n)
    floor = {(x, yy) for yy in range(H) for x in range(W) if m.g[yy][x] != "#"}
    lost = floor - seen
    assert not lost, "走不到的地板：%s" % sorted(lost)[:10]
    for (x, yy), sp in m.cells.items():
        on_wall = any(s.startswith(("walltrap", "torch", "exit")) for s in sp)
        assert on_wall or m.g[yy][x] != "#", ("东西放在墙里", x, yy, sp)


check_reachable()
m.write()
Path("levels/floor_07/design.json").write_text(json.dumps({
    "_说明": ["第七层（gen_floor07.py 生成）：combo_areas = 每组组合所在的房间（格，含上墙，左上 → 右下），level_design_test 检查区域里有组合需要的陷阱和怪物。",
             "checkpoints = 检查点数量（塔底的日记本是唯一的存档点）。"],
    "checkpoints": 4,
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
    {"actions": [A("move", who="princess", to=[8, y0 + 4], speed=110), A("camera", who="princess", time=0.6)]},
    {"actions": [A("move", who="princess", to=[W - 6, y0 + 4], speed=110)]},
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
