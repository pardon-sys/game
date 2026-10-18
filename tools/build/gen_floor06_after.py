"""生成第六层「地下小镇·战后」（七日赎罪）：三张地图 + 日程 + 对话 + 过场。台词在 tools/build/after_text/。
地图：
  floor_06_after           战后的小镇（和战时小镇同样的布局）：烧焦的房子搭上了脚手架、新木料、歪掉的狂欢图腾柱（待修）、
                           广场上的宣判台 / 告示板 / 足枷、庆功的彩旗；城门关着（打扫战场），矿道口钉死，营地在整修。
                           蓝色公主跟着（no_switch，不能换人），导演 f6after（AfterTown）按 DayClock 的日程摆镇民。
  floor_06_after_house     蓝色小屋楼下（粉色公主的房间）：进门时白天的事都做完了 → 天黑；夜里门锁上（宵禁）。
  floor_06_after_house_up  蓝色小屋楼上（蓝色公主的房间）：第一天夜里顺着手印上来之后才解锁。
日程：data/after/schedule.json（DayClock）——npcs 镇民日程、days 每天每个时段的事件 / 赎罪簿上的任务。
剧情：AfterStory（levels/floor_06/scripts/after_story.gd）。攻防战胜利的过场 siege_won 最后 goto 到这里的 from_siege。
用法：python tools/build/gen_floor06_after.py，然后 build_level.gd -- floor=floor_06_after（三张都要）
"""
import json
import os
import random
import sys
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
sys.path.insert(0, str(Path(__file__).resolve().parent))

from after_text import d1, house, town  # noqa: E402

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
TOWN, HOUSE, HOUSE_UP = "floor_06_after", "floor_06_after_house", "floor_06_after_house_up"


class Map:
    def __init__(self, fid, w, h, header):
        self.fid, self.w, self.h, self.header = fid, w, h, header
        self.g = [["#"] * w for _ in range(h)]
        self.cells = {}

    def room(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = "."

    def put(self, x, y, spec):
        self.cells.setdefault((x, y), []).append(spec)

    def write(self):
        specs, pool = {}, list(POOL)
        fixed = {"player": "P", "torch lit=true": "t"}
        g = [r[:] for r in self.g]
        for (x, y), sp in self.cells.items():
            spec = " + ".join(sp)
            ch = fixed.get(spec) or specs.get(spec)
            if ch is None:
                ch = specs[spec] = pool.pop(0)
            g[y][x] = ch
        out = Path("levels") / self.fid
        out.mkdir(parents=True, exist_ok=True)
        legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
        head = ("[level]\n# 第六层·地下小镇·战后（tools/build/gen_floor06_after.py 生成，不要直接改）\n" + self.header +
                "\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n")
        (out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
        print("%s：%dx%d，图例 %d 种" % (self.fid, self.w, self.h, len(specs)))


def prop(m, x, y, kind, action=""):
    m.put(x, y, "prop type=%s%s" % (kind, (" action=" + action) if action else ""))


def npc(m, x, y, nid, file, wander=0, extra=""):
    m.put(x, y, ("npc id=%s dialogue=floor_06/%s wander=%s %s" % (nid, file, wander, extra)).strip())


OBJ = "talk:floor_06/after_objects#"

# ================================================================ 战后的小镇
m = Map(TOWN, 64, 46, "intro =\nambient = 0.66,0.56,0.5\nnight_ambient = 0.3,0.3,0.5\nno_switch = true")
m.room(2, 2, 61, 43)
for x in (8, 20, 32, 44, 56):
    m.put(x, 1, "torch lit=true")
m.put(3, 3, "f6after")
# 东北角：通往矿道的门钉死了
prop(m, 54, 4, "dungeon_gate")
m.put(54, 5, "exit target=floor_06_mine locked=true dialogue=after_mine_locked")
# 居民区：烧焦的房子搭上了脚手架
for i, x in enumerate((8, 16, 24, 32)):
    prop(m, x, 8, ("house_scaffold_%d" % (i // 2)) if i % 2 == 0 else "house_%d" % i)
for (x, y) in ((12, 11), (28, 11)):
    prop(m, x, y, "lumber", OBJ + "lumber")
prop(m, 20, 12, "rubble")
prop(m, 42, 8, "house_blue")
m.put(42, 9, "exit target=%s spawn=from_town" % HOUSE)
m.put(42, 10, "spawn id=from_house")
# 集贸市场：补好了一个摊位，另一个还塌着
for row, y in enumerate((19, 26)):
    for i, x in enumerate((7, 11, 15)):
        if (row, i) == (1, 2):
            prop(m, x, y, "stall_broken")
        else:
            prop(m, x, y, "stall_%d" % ((i + row) % 3), "shop:war_market")
for y in (22, 23):
    prop(m, 4, y, "crate")
# 篝火
prop(m, 44, 24, "bonfire_0", "heal")
for (x, y) in ((40, 21), (48, 21), (40, 27), (48, 27)):
    prop(m, x, y, "bench")
for (x, y) in ((37, 24), (51, 24)):
    prop(m, x, y, "lamp")
prop(m, 30, 18, "well")
# 广场：宣判台、告示板、足枷、庆功的彩旗
prop(m, 30, 25, "podium", OBJ + "podium")
prop(m, 35, 23, "notice_board", OBJ + "notice")
prop(m, 23, 24, "stocks_plaza", OBJ + "stocks")
for (x, y) in ((25, 21), (36, 21)):
    prop(m, x, y, "bunting")
m.put(30, 32, "savepoint place=战后的广场")
# 歪掉的狂欢图腾柱（第七天修）
prop(m, 18, 34, "totem_tilted", OBJ + "totem")
# 通往营地的楼梯：整修中
prop(m, 59, 40, "stairs_down")
prop(m, 58, 38, "barricade")
m.put(57, 40, "sign dialogue=after_camp_blocked")
# 南边城墙：在补的地方堆着木料
for x in range(2, 62):
    m.g[41][x] = "#"
for x in (8, 56):
    prop(m, x, 39, "sandbag")
for x in (16, 48):
    prop(m, x, 39, "lumber", OBJ + "lumber")
for (x, y) in ((12, 37), (22, 37), (42, 37), (52, 37)):
    prop(m, x, y, "tower_base")
for (x, y) in ((27, 38), (37, 38)):
    prop(m, x, y, "tower")
prop(m, 32, 40, "dungeon_gate", OBJ + "gate")
for x in (29, 35):
    prop(m, x, 40, "lamp")
m.put(32, 38, "spawn id=from_siege")
m.put(32, 37, "player")
m.put(33, 37, "blue_princess follow=true ai=false")

# 镇民：地图上的位置 = 默认位置；导演按日程再摆（节点改名成对话文件名，过场里用）
RESIDENTS = {   # 对话文件 -> (人物图, 默认格)
    "after_captain": ("captain", (34, 29)), "after_mayor": ("mayor", (31, 29)),
    "after_granny": ("granny", (42, 25)), "after_merchant": ("merchant", (8, 24)),
    "after_supervisor": ("supervisor", (12, 23)), "after_bonfire_host": ("bonfire_host", (46, 24)),
    "after_kid_tom": ("kid", (46, 27)), "after_kid_lily": ("kid", (42, 22)),
    "after_maid": ("maid", (48, 25)), "after_engineer": ("miner", (34, 36)),
    "after_guard_gate": ("guard", (29, 38)), "after_guard_gate2": ("guard", (35, 38)),
    "after_guard_plaza": ("guard", (28, 31)), "after_guard_wall": ("guard", (52, 38)),
    "after_guard_house": ("guard", (40, 10)),
}
for f, (nid, (x, y)) in RESIDENTS.items():
    npc(m, x, y, nid, f)

# 地面：剩下的焦痕、灰烬、泥脚印、碎木（比战时少一半）
rnd = random.Random(616)
ANY = ["decal_footprints_0", "decal_straw_0", "decal_puddle_0", "decal_ash_1", "decal_scorch_1", "decal_splinters_0"]


def free(x, y):
    if not (3 <= x <= 60 and 3 <= y <= 39) or m.g[y][x] != ".":
        return False
    return all((x + dx, y + dy) not in m.cells for dx in (-1, 0, 1) for dy in (-1, 0, 1))


placed = tries = 0
while placed < 55 and tries < 4000:
    tries += 1
    x, y = rnd.randint(3, 60), rnd.randint(3, 39)
    if free(x, y):
        prop(m, x, y, rnd.choice(ANY))
        placed += 1
m.write()

# ================================================================ 蓝色小屋（楼下 / 楼上）
HOBJ = "talk:floor_06/after_house_objects#"
h = Map(HOUSE, 20, 14, "intro =\nambient = 0.9,0.82,0.76\nnight_ambient = 0.36,0.34,0.56\nno_switch = true")
h.room(2, 2, 17, 11)
for y in range(2, 12):
    for x in range(2, 18):
        h.put(x, y, "prop type=wood_floor")
for x in (5, 14):
    h.put(x, 1, "torch lit=true")
h.put(3, 2, "f6afterhouse")
prop(h, 6, 2, "window", HOBJ + "window")
prop(h, 13, 2, "window", HOBJ + "window")
prop(h, 10, 2, "painting", HOBJ + "painting")
prop(h, 16, 2, "stairs_up")
h.put(16, 3, "exit target=%s spawn=from_down unlock_flag=after_house_up_open locked_dialogue=after_house_up_locked" % HOUSE_UP)
h.put(15, 4, "spawn id=from_up")
prop(h, 4, 4, "princess_bed", HOBJ + "bed")
h.put(5, 6, "spawn id=bed")
prop(h, 8, 3, "wardrobe", HOBJ + "wardrobe")
prop(h, 12, 3, "bookshelf", HOBJ + "bookshelf")
prop(h, 14, 5, "dresser", HOBJ + "dresser")
prop(h, 9, 7, "rug")
prop(h, 9, 7, "tea_table", HOBJ + "tea")
prop(h, 8, 7, "chair")
prop(h, 10, 7, "chair")
prop(h, 3, 10, "plant", HOBJ + "plant")
prop(h, 16, 10, "plant", HOBJ + "plant")
prop(h, 6, 6, "candle")
prop(h, 13, 9, "candle")
h.put(9, 11, "exit target=%s spawn=from_house lock_flag=night locked_dialogue=after_curfew" % TOWN)
h.put(9, 10, "spawn id=from_town")
h.put(9, 9, "player")
h.write()

UOBJ = "talk:floor_06/after_house_up_objects#"
u = Map(HOUSE_UP, 16, 12, "intro =\nambient = 0.82,0.84,0.95\nnight_ambient = 0.34,0.34,0.58\nno_switch = true")
u.room(2, 2, 13, 9)
for y in range(2, 10):
    for x in range(2, 14):
        u.put(x, y, "prop type=wood_floor")
u.put(8, 1, "torch lit=true")
u.put(2, 2, "f6afterhouse")
prop(u, 5, 2, "window", UOBJ + "window")
prop(u, 4, 4, "blue_bed", UOBJ + "bed")
prop(u, 9, 3, "bookshelf", UOBJ + "bookshelf")
prop(u, 8, 7, "rug")
prop(u, 11, 8, "desk", UOBJ + "desk")
prop(u, 3, 9, "plant")
prop(u, 7, 5, "candle")
prop(u, 13, 2, "stairs_down")
u.put(13, 3, "exit target=%s spawn=from_up" % HOUSE)
u.put(12, 4, "spawn id=from_down")
u.put(6, 7, "blue_princess ai=false dialogue=floor_06/after_blue_room")
u.put(11, 5, "player")
u.write()

# ================================================================ 日程（DayClock）
HIDE = {"hidden": True}


def crowd(at, d="up"):
    return {"at": list(at), "dir": d, "wander": 0, "hidden": False}


NPCS = {}
for f, (nid, (x, y)) in RESIDENTS.items():
    NPCS[f] = {"default": {"at": [x, y], "dir": "down", "wander": 0 if "guard" in f or f == "after_captain" else 1, "hidden": False},
               "night": HIDE}
# 夜里还在外面的：宵禁巡逻
for f in ("after_guard_gate", "after_guard_house"):
    NPCS[f]["night"] = {"hidden": False}
# 第 1 天早上：城门口只有队长和守城的队员；下午：宣判时围在台子下面，宣判完散回默认位置
D1_MORNING = {"after_captain": {"at": [32, 31], "dir": "down", "wander": 0},
              "after_guard_gate": {"at": [28, 37], "dir": "right"}, "after_guard_gate2": {"at": [36, 37], "dir": "left"},
              "after_guard_plaza": {"at": [29, 34], "dir": "down"}, "after_guard_wall": {"at": [35, 34], "dir": "down"}}
D1_VERDICT = {"after_captain": crowd((33, 25.5), "down"), "after_mayor": crowd((30, 24), "down"),
              "after_granny": crowd((26, 28)), "after_merchant": crowd((28, 29.5)), "after_supervisor": crowd((37, 28.5)),
              "after_bonfire_host": crowd((39, 29.5)), "after_kid_tom": crowd((24.5, 29)), "after_kid_lily": crowd((25.5, 30)),
              "after_maid": crowd((35, 30)), "after_engineer": crowd((22, 28)), "after_guard_plaza": crowd((27, 26), "down"),
              "after_guard_wall": crowd((40, 27), "left")}
for f in NPCS:
    NPCS[f]["d1"] = {"morning": D1_MORNING.get(f, HIDE), "afternoon": D1_VERDICT.get(f, {})}
    if f in D1_VERDICT:
        NPCS[f]["d1"]["afternoon_done"] = dict(NPCS[f]["default"])
DAYS = {
    "d1": {"morning": {"event": "d1_open", "task": "战后集合"},
           "afternoon": {"event": "d1_verdict", "task": "广场听候宣判"},
           "night": {"event": "d1_sleepwalk", "task": "回小屋睡觉"}},
}
Path("data/after").mkdir(parents=True, exist_ok=True)
Path("data/after/schedule.json").write_text(json.dumps({
    "_说明": ["七日赎罪的日程（tools/build/gen_floor06_after.py 生成，DayClock 读）。",
             "npcs：镇民（对话文件名）→ default / 时段 / d<N>.{all, 时段, 时段_done} 逐层覆盖的 {at 格, dir, wander, hidden, dialogue}。",
             "days：d<N>.<时段> → {event 事件 id（AfterStory.EVENTS）, task 赎罪簿上的任务名, hours 做完减几工时}。"],
    "npcs": NPCS, "days": DAYS}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 对话 / 过场 / 楼层表
dlg = Path("data/dialogues/floor_06")
files = dict(town.D)
files["after_house_objects"] = house.HOUSE
files["after_house_up_objects"] = house.HOUSE_UP
files["after_blue_room"] = house.BLUE_ROOM
for name, d in files.items():
    (dlg / (name + ".json")).write_text(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")
signs_path = dlg / "signs.json"
signs = json.loads(signs_path.read_text())
signs.update(town.SIGNS)
signs_path.write_text(json.dumps(signs, ensure_ascii=False, indent="\t") + "\n")

cut = Path("data/cutscenes/floor_06")
for cid, fn in d1.CUTSCENES.items():
    (cut / (cid + ".json")).write_text(json.dumps(fn(), ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
NEW = [(TOWN, "地下小镇·战后", "town"), (HOUSE, "蓝色小屋·战后", "town"), (HOUSE_UP, "蓝色小屋·战后（楼上）", "night_room")]
at = next(i for i, f in enumerate(lst) if f["id"] == "floor_06_siege") + 1
for fid, name, music in NEW:
    if not any(f["id"] == fid for f in lst):
        lst.insert(at, {"id": fid, "name": name, "scene": "res://levels/%s/floor.tscn" % fid, "group": "floor_06", "music": music})
    at += 1
Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("对话 %d 个文件、过场 %d 段" % (len(files), len(d1.CUTSCENES)))
