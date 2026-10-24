"""生成第六层「地下小镇·战后」（七日赎罪）：三张地图 + 日程 + 对话 + 过场。台词在 tools/build/after_text/。
地图：
  floor_06_after           战后的小镇（和战时小镇同样的布局）：烧焦的房子搭上了脚手架、新木料、歪掉的狂欢图腾柱（待修）、
                           广场上的宣判台 / 告示板 / 足枷、庆功的彩旗；城门关着（打扫战场），矿道口钉死，营地在整修。
                           蓝色公主自由活动／当日邀请同行（no_switch，不能换人），导演 f6after（AfterTown）按 DayClock 日程摆镇民。
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

from after_text import d1, d2, equip_kids, errand_dance, errand_goats, errand_ladder, errand_massage, errand_gate_chain, errand_shearing, errand_canopy, errand_sifting, errand_lamp_calibration, errands, house, mine, play, potion, punish, stocks, tailor, tasks, totem, town, drain, drill, inspect, tom, night, penalty, festival_night, stall_guess, stall_ring, stall_ice, stall_fish, stall_lick  # noqa: E402
from knight_text import story as knight_story, tasks as knight_tasks  # noqa: E402

# 只生成灯轮 / 报幕的文本（委托表、灯轮、补罚表、派对主人对话），不重新写地图、其他任务或别的镇民对白。
if "--festival-only" in sys.argv:
    from copy import deepcopy
    def write_festival(path, data):
        Path(path).write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    write_festival("data/after/errands.json", {"_说明": "七日赎罪的镇民委托（gen_floor06_after.py 从 after_text/errands.py 生成，AfterErrands 读）。", "errands": errands.ERRANDS})
    write_festival("data/after/errand_lamp_calibration.json", errand_lamp_calibration.LAMP)
    write_festival("data/after/penalty.json", dict({"_说明": "补罚任务（after_text/penalty.py 生成）。"}, **penalty.PENALTY))
    files = deepcopy(town.D)
    errands.inject(files)
    penalty.inject(files)
    festival_night.inject(files, {})
    write_festival("data/dialogues/floor_06/after_bonfire_host.json", files["after_bonfire_host"])
    print("祭典专项生成：委托表、灯轮、补罚表、派对主人对话")
    sys.exit(0)

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
TOWN, HOUSE, HOUSE_UP = "floor_06_after", "floor_06_after_house", "floor_06_after_house_up"
PHARMACY, FIELD = "floor_06_after_pharmacy", "floor_06_after_field"
TAILOR, MINE, TOTEM = "floor_06_after_tailor", "floor_06_after_mine", "floor_06_after_totem"
DRAIN, DRILL, PROVING = "floor_06_after_drain", "floor_06_after_drill", "floor_06_after_proving"
PRISON = "floor_06_after_prison"


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
    kind = "bonfire_host" if nid == "bonfire_host" else "npc id=" + nid
    m.put(x, y, ("%s dialogue=floor_06/%s wander=%s %s" % (kind, file, wander, extra)).strip())


OBJ = "talk:floor_06/after_objects#"

# ================================================================ 战后的小镇
m = Map(TOWN, 64, 46, "intro =\nambient = 0.66,0.56,0.5\nnight_ambient = 0.3,0.3,0.5\nno_switch = true")
m.room(2, 2, 61, 43)
for x in (8, 20, 32, 44, 56):
    m.put(x, 1, "torch lit=true")
m.put(3, 3, "f6after")
# 东北角：通往矿道的门（平时钉死；第 5 天下午护送矿车时打开，通往受损的矿道）
prop(m, 54, 4, "dungeon_gate")
m.put(54, 5, "exit target=%s spawn=from_town unlock_flag=after_mine_open locked_dialogue=after_mine_locked" % MINE)
m.put(54, 6, "spawn id=from_mine")
# 居民区：烧焦的房子搭上了脚手架
for i, x in enumerate((8, 16, 24, 32)):
    prop(m, x, 8, ("house_scaffold_%d" % (i // 2)) if i % 2 == 0 else "house_%d" % i)
# 裁缝铺（北边最右边的房子；第 5 天早上试衣）
m.put(32, 9, "exit target=%s spawn=from_town" % TAILOR)
m.put(32, 10, "spawn id=from_tailor")
m.put(34, 10, "sign dialogue=after_tailor_sign")
# 队长的训练室（西北角那座搭脚手架的房子；特训的时候开门）
m.put(8, 9, "exit target=%s spawn=from_town unlock_flag=after_drill_open locked_dialogue=after_drill_locked" % DRILL)
m.put(8, 10, "spawn id=from_drill")
# 东边的保卫队训练营（第 6 天早上验收陷阱）
m.put(61, 20, "exit target=%s spawn=from_town unlock_flag=after_proving_open locked_dialogue=after_proving_locked" % PROVING)
m.put(60, 20, "spawn id=from_proving")
# 南边的排水口（第 4 天早上通管）
prop(m, 20, 39, "drain_grate")
m.put(20, 39, "exit target=%s spawn=from_town unlock_flag=after_drain_open locked_dialogue=after_drain_locked" % DRAIN)
m.put(20, 38, "spawn id=from_drain")
# 药剂师工房（北边第二座房子）
m.put(16, 9, "exit target=%s spawn=from_town" % PHARMACY)
m.put(16, 10, "spawn id=from_pharmacy")
m.put(18, 10, "sign dialogue=after_pharmacy_sign")
for (x, y) in ((12, 11), (28, 11)):
    prop(m, x, y, "lumber", OBJ + "lumber")
prop(m, 20, 12, "rubble")
prop(m, 42, 8, "house_blue")
m.put(42, 9, "exit target=%s spawn=from_town lock_flag=after_task_active locked_dialogue=after_task_locked" % HOUSE)
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
# 脚手架房子底下的梯子（委托「扶梯子」）
prop(m, 25, 9, "ladder")
# 女仆照看的蘑菇羊的羊圈（委托「赶蘑菇羊回圈」；门在 (57, 32)）
for x in range(55, 60):
    prop(m, x, 28, "fence")
for y in (29, 30, 31):
    prop(m, 55, y, "fence")
    prop(m, 59, y, "fence")
for x in (55, 56, 58, 59):
    prop(m, x, 32, "fence")
prop(m, 60, 30, "hay")
# 广场：宣判台、告示板、足枷、庆功的彩旗
prop(m, 30, 25, "podium", OBJ + "podium")
prop(m, 35, 23, "notice_board", OBJ + "notice")
m.put(23, 24, "trap type=stocks active=false")      # 第 2 天早上示众用（过场 hold 锁住）
for (x, y) in ((25, 21), (36, 21)):
    prop(m, x, y, "bunting")
m.put(30, 32, "savepoint place=战后的广场")
# 歪掉的狂欢图腾柱（第七天修）
prop(m, 18, 34, "totem_tilted", OBJ + "totem")
# 西边的小路 → 图腾柱废地（第 7 天修图腾柱的时候才开）
m.put(2, 32, "exit target=%s spawn=from_town unlock_flag=after_totem_open locked_dialogue=after_totem_locked" % TOTEM)
m.put(3, 32, "spawn id=from_totem")
# 通往营地的楼梯：整修中
prop(m, 59, 40, "stairs_down")
prop(m, 58, 38, "barricade")
m.put(57, 40, "sign dialogue=after_camp_blocked")
# 骑士篇：从地牢的通风口回来的地方（夜探地牢走的是路障后面的通风口，由 KnightStory 转场）
m.put(57, 38, "spawn id=from_prison")
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
# 城门 → 城外的战场（第 3 天下午拆攻城车的时候才开）
m.put(32, 39, "exit target=%s spawn=from_town unlock_flag=after_field_open locked_dialogue=after_gate_closed" % FIELD)
m.put(33, 36, "spawn id=from_field")
m.put(32, 37, "player")
m.put(33, 37, "blue_princess ai=true dialogue=floor_06/after_partner")

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
h.put(9, 11, "exit target=%s spawn=from_house lock_flag=after_curfew locked_dialogue=after_curfew" % TOWN)
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

# ================================================================ 药剂师工房
PH = "talk:floor_06/after_pharm_objects#"
ph = Map(PHARMACY, 16, 12, "intro =\nambient = 0.86,0.9,0.8\nno_switch = true")
ph.room(2, 2, 13, 9)
for y in range(2, 10):
    for x in range(2, 14):
        ph.put(x, y, "prop type=wood_floor")
for x in (5, 11):
    ph.put(x, 1, "torch lit=true")
ph.put(2, 2, "f6afterroom")
prop(ph, 4, 3, "herb_rack", PH + "rack")
prop(ph, 7, 3, "herb_rack", PH + "rack")
prop(ph, 11, 3, "bookshelf", PH + "book")
prop(ph, 11, 6, "cauldron", PH + "cauldron")
prop(ph, 4, 7, "desk", PH + "desk")
prop(ph, 13, 9, "plant")
prop(ph, 2, 9, "plant")
prop(ph, 9, 7, "candle")
npc(ph, 8, 5, "pharmacist", "after_pharm", 0, "dir=down")
ph.put(8, 9, "exit target=%s spawn=from_pharmacy" % TOWN)
ph.put(8, 8, "spawn id=from_town")
ph.put(7, 8, "player")
ph.write()

# ================================================================ 裁缝铺里间
TL = "talk:floor_06/after_tailor_objects#"
tl = Map(TAILOR, 18, 13, "intro =\nambient = 0.92,0.86,0.84\nno_switch = true")
tl.room(2, 2, 15, 10)
for y in range(2, 11):
    for x in range(2, 16):
        tl.put(x, y, "prop type=wood_floor")
for x in (5, 12):
    tl.put(x, 1, "torch lit=true")
tl.put(2, 2, "f6afterroom")
prop(tl, 4, 3, "fabric", TL + "fabric")
prop(tl, 8, 3, "fabric", TL + "fabric")
prop(tl, 12, 3, "dress_form", TL + "form")
prop(tl, 14, 3, "dress_form", TL + "form")
prop(tl, 15, 8, "mirror", TL + "mirror")
prop(tl, 3, 6, "desk", TL + "desk")
prop(tl, 2, 10, "plant")
prop(tl, 6, 7, "rug")
npc(tl, 9, 5, "tailor", "after_tailor", 0, "dir=down")
npc(tl, 11, 5, "apprentice", "after_apprentice", 0, "dir=down")
tl.put(8, 11, "exit target=%s spawn=from_tailor" % TOWN)
tl.put(8, 10, "spawn id=from_town")
tl.put(8, 9, "player")
tl.write()

# ================================================================ 受损的矿道（矿车护送）
mn = Map(MINE, 96, 12, "intro =\nambient = 0.5,0.46,0.54\nno_switch = true")
mn.room(2, 3, 93, 9)
for x in range(6, 92, 8):
    mn.put(x, 2, "torch lit=true")
mn.put(3, 3, "f6afterroom")
mn.put(2, 6, "exit target=%s spawn=from_mine" % TOWN)
mn.put(4, 7, "spawn id=from_town")
mn.put(5, 7, "player")
mn.put(9, 6, "blue_princess ai=false")
for x in range(4, 93):
    mn.put(x, 6, "prop type=rail" if x < 66 else "prop type=rail_slope")
# 装车处：补给箱、矿工
for (x, y) in ((6, 4), (8, 4), (11, 8)):
    prop(mn, x, y, "crate")
npc(mn, 12, 4, "miner", "after_mine_miner", 0, "dir=down")
# 喷口段（格 14~39）：轨道上下两边交错的痒痒粉喷口
for i, (x, y) in enumerate(((18, 5), (22, 7), (26, 5), (30, 7), (34, 5), (37, 7))):
    mn.put(x, y, "trap type=vent idle_time=2.0 cloud_duration=1.6 offset=%.1f" % (i * 0.55 % 2.0))
# 刷子段（格 40~65）：轨道上下两边转着的羽毛刷，刷臂扫过轨道
for i, (x, y) in enumerate(((45, 4), (51, 8), (57, 4), (62, 8))):
    mn.put(x, y, "trap type=brush speed=%.1f" % ((1.4 + i * 0.15) * (1 if i % 2 == 0 else -1)))
# 上坡（格 66~87）：两边的矿石堆（小鬼藏在后面）
for (x, y) in ((68, 4), (73, 8), (78, 4), (83, 8)):
    prop(mn, x, y, "rubble")
for x in (20, 44, 70):
    prop(mn, x, 9, "lamp")
# 矿工营地（格 88~）
for (x, y) in ((90, 4), (92, 8)):
    prop(mn, x, y, "tent")
prop(mn, 89, 8, "bonfire_0")
npc(mn, 91, 5, "miner", "after_mine_camp", 0, "dir=left")
mn.write()

# ================================================================ 图腾柱废地（修补狂欢图腾柱）
tt = Map(TOTEM, 42, 24, "intro =\nambient = 0.62,0.54,0.66")
tt.room(2, 3, 39, 20)
for x in (8, 18, 28, 36):
    tt.put(x, 2, "torch lit=true")
tt.put(3, 3, "f6afterroom")
tt.put(2, 12, "exit target=%s spawn=from_totem" % TOWN)
tt.put(4, 12, "spawn id=from_town")
tt.put(5, 13, "player")
tt.put(5, 11, "blue_princess follow=true ai=false")
# 采石角：碎石、木料
for (x, y) in ((4, 6), (4, 18), (8, 5), (8, 19)):
    prop(tt, x, y, "rubble")
prop(tt, 9, 10, "lumber")
# 图腾柱（底座在 34,11 附近）
prop(tt, 34, 9, "totem_tilted", "talk:floor_06/after_totem_objects#totem")
for (x, y) in ((31, 13), (37, 13)):
    prop(tt, x, y, "lamp")
npc(tt, 30, 16, "miner", "after_totem_eng", 0, "dir=left")
# 围观的镇民
for (x, y, nid) in ((14, 4, "granny"), (20, 4, "merchant"), (26, 4, "kid"), (14, 19, "maid"), (24, 19, "guard")):
    tt.put(x, y, "npc id=%s wander=0 dir=%s" % (nid, "down" if y < 10 else "up"))
for (x, y) in ((11, 6), (19, 19), (27, 5), (33, 18)):
    prop(tt, x, y, "decal_scorch_1")
tt.write()

# ================================================================ 排水管（俯视的管道迷宫，一格宽）
dr = Map(DRAIN, 40, 22, "intro =\nambient = 0.36,0.4,0.42")
dr.room(2, 11, 4, 13)
for (x0, y0, x1, y1) in ((3, 12, 14, 12), (14, 6, 14, 12), (14, 6, 26, 6), (26, 6, 26, 17), (26, 17, 36, 17), (36, 12, 36, 17)):
    dr.room(x0, y0, x1, y1)
dr.room(35, 11, 37, 12)
for (x, y) in ((8, 11), (14, 5), (20, 5), (27, 10), (27, 15), (31, 16), (37, 10)):
    dr.put(x, y, "torch lit=true")
dr.put(3, 13, "f6afterroom")
dr.put(2, 12, "exit target=%s spawn=from_drain" % TOWN)
dr.put(4, 12, "spawn id=from_town")
dr.put(4, 11, "player")
prop(dr, 17, 5, "graffiti", "talk:floor_06/after_drain_objects#graffiti")
prop(dr, 37, 11, "drain_lever")
for (x, y) in ((6, 12), (16, 6), (26, 11), (30, 17)):
    prop(dr, x, y, "decal_puddle_0")
for (x, y) in ((22, 6), (28, 17)):
    dr.put(x, y, "monster type=rat")
dr.write()

# ================================================================ 队长的训练室（蓝色公主的特训）
dl = Map(DRILL, 20, 14, "intro =\nambient = 0.82,0.86,0.96\nno_switch = true")
dl.room(2, 2, 17, 11)
for y in range(2, 12):
    for x in range(2, 18):
        dl.put(x, y, "prop type=wood_floor")
for x in (5, 14):
    dl.put(x, 1, "torch lit=true")
dl.put(2, 2, "f6afterroom")
prop(dl, 10, 7, "ice_block", "talk:floor_06/after_drill_objects#ice")
for (x, y) in ((4, 4), (15, 4)):
    prop(dl, x, y, "dummy")
prop(dl, 4, 9, "bench")
prop(dl, 15, 9, "bench")
prop(dl, 9, 2, "banner")
npc(dl, 10, 4, "captain", "after_drill_cap", 0, "dir=down")
dl.put(10, 12, "exit target=%s spawn=from_drill" % TOWN)
dl.put(10, 11, "spawn id=from_town")
dl.put(10, 10, "player")
dl.put(11, 10, "blue_princess follow=true ai=false")
dl.write()

# ================================================================ 保卫队训练营（陷阱验收；踏板由任务摆）
pv = Map(PROVING, 44, 10, "intro =\nambient = 0.78,0.74,0.7")
# 一条走廊（第 3~6 行）：辅助设施的踏板整条宽，躲不开；陷阱的踏板在路中间
pv.room(2, 3, 41, 6)
for x in (6, 14, 22, 30, 38):
    pv.put(x, 2, "torch lit=true")
pv.put(3, 3, "f6afterroom")
pv.put(2, 4, "exit target=%s spawn=from_proving" % TOWN)
pv.put(3, 4, "spawn id=from_town")
pv.put(4, 4, "player")
pv.put(4, 5, "blue_princess follow=true ai=false")
for (x, y) in ((5, 3), (40, 3)):
    npc(pv, x, y, "guard", "after_proving_guard", 0, "dir=down")
prop(pv, 40, 6, "banner")
pv.write()

# ================================================================ 骑士篇：保卫队的地牢（夜探地牢，潜入）
# 西边通风口进来（vent），南边长走廊 → 中间两条竖走廊 → 北边的牢房走廊；最里面（东北）那间关着骑士。
# 巡逻的队员（guard_patrol）、木箱（躲）、灯（亮处看得远）；StealthDirector 一直开着（被抓交给 TaskSneak）。
pz = Map(PRISON, 42, 22, "intro =\nambient = 0.34,0.32,0.42\nno_switch = true")
for (x0, y0, x1, y1) in ((2, 16, 38, 19), (10, 7, 12, 16), (24, 7, 26, 16), (10, 5, 39, 7), (34, 2, 38, 3), (16, 10, 20, 14), (12, 11, 16, 12)):
    pz.room(x0, y0, x1, y1)
pz.put(3, 17, "f6afterroom")
pz.put(4, 16, "stealth")
pz.put(2, 18, "exit target=%s spawn=from_prison" % TOWN)
pz.put(3, 18, "spawn id=vent")
pz.put(4, 18, "player")
for x in (8, 18, 30):
    pz.put(x, 15, "torch lit=true")
for x in (14, 28, 36):
    pz.put(x, 4, "torch lit=true")
for (x, y) in ((7, 17), (15, 19), (22, 16), (31, 19), (11, 9), (25, 12), (17, 11), (19, 13), (30, 5)):
    prop(pz, x, y, "crate", "hide")
for (x, y) in ((13, 18), (27, 18), (11, 12), (32, 6)):
    prop(pz, x, y, "lamp")
# 牢房：东北角那间关着骑士（铁栅关着），其余空着
for x in (14, 20, 26):
    pz.put(x, 4, "gate group=cells is_open=false")
pz.room(13, 2, 15, 3)
pz.room(19, 2, 21, 3)
pz.room(25, 2, 27, 3)
pz.put(36, 4, "gate group=knight_cell is_open=false")
npc(pz, 36, 3, "knight", "after_knight", 0, "dir=down")
# 审问椅（只做摆设）
pz.put(18, 12, "trap type=cushion active=false")
for path, extra in (
        ("6,17;20,17", ""),                       # 南走廊西段来回
        ("22,18;36,18", " wait=1.4"),              # 南走廊东段来回
        ("11,15;11,8", ""),                       # 西竖走廊
        ("25,8;25,15", " wait=1.0"),              # 东竖走廊
        ("14,6;32,6", ""),                        # 牢房走廊
        ("16,10;20,10;20,14;16,14", " loop=true"),  # 审问室绕圈
):
    pz.put(int(path.split(";")[0].split(",")[0]), int(path.split(";")[0].split(",")[1]), "guard_patrol path=" + path + extra)
pz.write()

# ================================================================ 城门外的战场
fd = Map(FIELD, 44, 30, "intro =\nambient = 0.72,0.66,0.62\nnight_ambient = 0.3,0.3,0.5")
fd.room(2, 2, 41, 27)
for x in (8, 16, 26, 34):
    fd.put(x, 1, "torch lit=true")
fd.put(3, 3, "f6afterroom")
fd.put(21, 2, "exit target=%s spawn=from_field" % TOWN)
fd.put(21, 4, "spawn id=from_town")
fd.put(21, 5, "player")
fd.put(22, 5, "blue_princess follow=true ai=false")
# 三辆睡着的攻城车（一辆比一辆难：扫得更宽、更快、车灯更远）
fd.put(10, 15, "f6cart index=0 dir=right sweep=40 speed=0.9 range_px=90")
fd.put(30, 10, "f6cart index=1 dir=down sweep=55 speed=1.2 range_px=100")
fd.put(32, 22, "f6cart index=2 dir=left sweep=70 speed=1.5 range_px=112")
frnd = random.Random(626)
WRECK = ["flag_broken", "feather_pile", "bubble_frozen", "rubble", "feather_pile", "decal_scorch_0", "decal_ash_1", "decal_splinters_0"]
for (x, y) in ((6, 8), (15, 6), (26, 5), (36, 7), (5, 21), (14, 24), (24, 26), (38, 26), (19, 14), (24, 18), (38, 15), (8, 26)):
    prop(fd, x, y, frnd.choice(WRECK))
for (x, y) in ((17, 10), (25, 13), (20, 20)):
    prop(fd, x, y, "barricade")
for (x, y) in ((12, 11), (35, 18)):
    prop(fd, x, y, "sandbag")
fd.write()

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
# 第 2 天早上：足枷示众，大家围在足枷周围
D2_STOCKS = {"after_captain": crowd((21, 23), "right"), "after_supervisor": crowd((25, 23), "left"), "after_granny": crowd((20, 27)),
             "after_merchant": crowd((26.5, 27.5), "left"), "after_kid_tom": crowd((32, 26), "left"), "after_kid_lily": crowd((33, 25), "left"),
             "after_bonfire_host": crowd((28, 24), "left"), "after_maid": crowd((19, 25), "right"), "after_mayor": crowd((21, 21.5), "down"),
             "after_guard_plaza": crowd((26, 21.5), "down")}
for f in NPCS:
    NPCS[f].setdefault("d2", {})["morning"] = D2_STOCKS.get(f, {})
    if f in D2_STOCKS:
        NPCS[f]["d2"]["morning_done"] = dict(NPCS[f]["default"])
# 晚上的弥补任务：委托人那天晚上留在外面
for _f, _d, _at in (("after_granny", "d2", (45, 12)), ("after_kid_tom", "d4", (30, 30)), ("after_kid_lily", "d4", (32, 30)), ("after_mayor", "d6", (31, 26))):
    NPCS[_f].setdefault(_d, {})["night"] = {"at": list(_at), "dir": "down", "wander": 0, "hidden": False}
# 第 7 天晚上：庆功宴（工时没还清时也在外面——市场监督和派对主人接补罚），摊主守在自己的摊位
D7_NIGHT = {"after_bonfire_host": (45, 26, "left"), "after_mayor": (42, 21, "down"), "after_captain": (39, 24, "right"),
            "after_granny": (37, 22, "down"), "after_merchant": (36, 27, "right"), "after_engineer": (48, 22, "down"),
            "after_kid_tom": (49, 27, "left"), "after_kid_lily": (44, 23, "down"), "after_maid": (51, 25, "left"),
            "after_supervisor": (33, 24, "right")}
for _f, (_x, _y, _d) in D7_NIGHT.items():
    NPCS[_f].setdefault("d7", {})["night"] = {"at": [_x, _y], "dir": _d, "wander": 0, "hidden": False}
    # 骑士篇（第 8 天起）的夜里：诅咒漏出来时镇民还在广场上（以笑为饵的手印贴着他们偷笑声）
    if _f != "after_bonfire_host":
        NPCS[_f].setdefault("d8", {})["night"] = {"at": [_x, _y], "dir": _d, "wander": 0, "hidden": False}
NPCS["after_blue"] = {
    "default": {"at": [12, 14], "dir": "down", "wander": 2, "hidden": False},
    "morning": {"at": [12, 14], "dir": "left"},
    "afternoon": {"at": [33, 18], "dir": "left"},
    "night": {"at": [41, 25], "dir": "right"},
}
DAYS = {
    "d2": {"morning": {"event": "d2_stocks", "task": "广场足枷示众", "hours": 12},
           "afternoon": {"event": "d2_equip", "task": "回收痒痒装备", "hours": 10},
           "night": {"event": "d2_sweep", "task": "羽毛大扫除", "hours": 3}},
    "d3": {"morning": {"event": "d3_potion", "task": "药剂师的试药员", "hours": 10},
           "afternoon": {"event": "d3_cart", "task": "拆除哑火的攻城车", "hours": 12},
           "night": {"event": "d3_mice", "task": "逃跑的痒痒鼠", "hours": 3}},
    "d4": {"morning": {"event": "d4_drain", "task": "疏通排水管", "hours": 10},
           "afternoon": {"event": "d4_drill", "task": "陪蓝色公主特训", "hours": 6},
           "night": {"event": "d4_tag", "task": "挠痒捉人", "hours": 3}},
    "d6": {"morning": {"event": "d6_inspect", "task": "陷阱验收", "hours": 10},
           "afternoon": {"event": "d6_drill", "task": "陪蓝色公主特训（考核）", "hours": 6},
           "night": {"event": "d6_lantern", "task": "笑声灯笼", "hours": 3}},
    "d5": {"morning": {"event": "d5_tailor", "task": "裁缝的试衣模特", "hours": 10},
           "afternoon": {"event": "d5_mine", "task": "矿车护送", "hours": 12},
           "night": {"event": "d5_tom", "task": "回小屋睡觉"}},
    "d7": {"morning": {"event": "d7_totem", "task": "修补狂欢图腾柱", "hours": 20},
           "night": {"event": "d7_festival", "task": "庆功宴"}},
    "d1": {"morning": {"event": "d1_open", "task": "战后集合"},
           "afternoon": {"event": "d1_verdict", "task": "广场听候宣判"},
           "night": {"event": "d1_sleepwalk", "task": "回小屋睡觉"}},
}
Path("data/after").mkdir(parents=True, exist_ok=True)
Path("data/after/errands.json").write_text(json.dumps({
    "_说明": "七日赎罪的镇民委托（gen_floor06_after.py 从 after_text/errands.py 生成，AfterErrands 读）。", "errands": errands.ERRANDS},
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/stocks.json").write_text(json.dumps(dict({"_说明": "足枷示众小游戏的台词（after_text/stocks.py 生成，StocksShow 读）。"}, **stocks.STOCKS),
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/equip_kids.json").write_text(json.dumps(dict({"_说明": "装备回收里小孩的配合挠法（after_text/equip_kids.py 生成，EquipKids 读）。"}, **equip_kids.EQUIP_KIDS),
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/potion.json").write_text(json.dumps(dict({"_说明": "配药解谜（after_text/potion.py 生成，TaskPotion 读）。"}, **potion.POTION),
    ensure_ascii=False, indent="\t") + "\n")
for _name, _mod, _key, _cls in (("ladder", errand_ladder, "LADDER", "LadderShow"), ("goats", errand_goats, "GOATS", "ErrandGoats"),
                                 ("dance", errand_dance, "DANCE", "DanceShow"), ("massage", errand_massage, "MASSAGE", "MassageShow"),
                                 ("gate_chain", errand_gate_chain, "GATE_CHAIN", "GateChainShow"),
                                 ("shearing", errand_shearing, "SHEARING", "ShearingShow"),
                                 ("canopy", errand_canopy, "CANOPY", "CanopyShow"),
                                 ("sifting", errand_sifting, "SIFTING", "SiftingShow"),
                                 ("lamp_calibration", errand_lamp_calibration, "LAMP", "LampCalibrationShow")):
    Path("data/after/errand_%s.json" % _name).write_text(json.dumps(dict({"_说明": "委托的台词（after_text/errand_%s.py 生成，%s 读）。" % (_name, _cls)},
        **getattr(_mod, _key)), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/tailor.json").write_text(json.dumps(dict({"_说明": "找漏风（after_text/tailor.py 生成，TaskTailor 读）。"}, **tailor.TAILOR),
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/mine.json").write_text(json.dumps(dict({"_说明": "矿车护送（after_text/mine.py 生成，TaskMine 读）。"}, **mine.MINE),
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/totem.json").write_text(json.dumps(dict({"_说明": "修补图腾柱（after_text/totem.py 生成，TotemResonanceShow 读）。"}, **totem.TOTEM),
    ensure_ascii=False, indent="\t") + "\n")
night.NIGHT["react"] = night.REACT_COMMON
for _n, _m, _k in (("drain", drain, "DRAIN"), ("drill", drill, "DRILL"), ("inspect", inspect, "INSPECT"), ("tom", tom, "TOM_PRANK"), ("night", night, "NIGHT"), ("penalty", penalty, "PENALTY")):
    Path("data/after/%s.json" % _n).write_text(json.dumps(dict({"_说明": "after_text/%s.py 生成。" % _n}, **getattr(_m, _k)),
        ensure_ascii=False, indent="\t") + "\n")
Path("data/after/festival_night.json").write_text(json.dumps(dict({"_说明": "庆功宴（after_text/festival_night.py 生成，AfterFestival / FestivalDanceShow 读）。"},
    **festival_night.FESTIVAL), ensure_ascii=False, indent="\t") + "\n")
STALLS = {"after_granny": ("guess", stall_guess, "GUESS", "StallGuessShow"), "after_merchant": ("ring", stall_ring, "RING", "StallRingShow"),
          "after_engineer": ("ice", stall_ice, "ICE", "StallIceShow"), "after_kid_tom": ("fish", stall_fish, "FISH", "StallFishShow"),
          "after_maid": ("lick", stall_lick, "LICK", "StallLickShow")}
for _sid, _mod, _key, _cls in STALLS.values():
    _st = dict(getattr(_mod, _key))
    _st.setdefault("success_react", _st.get("right", []))
    Path("data/after/stall_%s.json" % _sid).write_text(json.dumps(dict({"_说明": "庆功宴摊位（after_text/stall_%s.py 生成，%s 读）。" % (_sid, _cls)}, **_st),
        ensure_ascii=False, indent="\t") + "\n")
Path("data/after/knight.json").write_text(json.dumps(dict({"_说明": "骑士篇 A~D 的玩法文本（knight_text/tasks.py 生成，TaskStretcher / TaskBait / InterrogationChairShow 读）。"},
    **knight_tasks.KNIGHT), ensure_ascii=False, indent="\t") + "\n")
# 人物表：骑士（行走图 / 立绘由 tools/art/gen_knight_art.py、import_knight_portrait.py 生成）
_npcs = json.loads(Path("data/actors/npcs.json").read_text())
_npcs["npcs"]["knight"] = {"name": knight_story.KNIGHT, "sprite": "res://assets/generated/npcs/knight.png", "portrait": "res://assets/generated/npc_portraits/knight.png"}
Path("data/actors/npcs.json").write_text(json.dumps(_npcs, ensure_ascii=False, indent="\t") + "\n")
Path("data/after/play.json").write_text(json.dumps(dict({"_说明": "两位公主的玩闹（after_text/play.py 生成，AfterPlay 读）。"}, **play.PLAY),
    ensure_ascii=False, indent="\t") + "\n")
Path("data/after/schedule.json").write_text(json.dumps({
    "_说明": ["七日赎罪的日程（tools/build/gen_floor06_after.py 生成，DayClock 读）。",
             "npcs：镇民（对话文件名）→ default / 时段 / d<N>.{all, 时段, 时段_done} 逐层覆盖的 {at 格, dir, wander, hidden, dialogue}。",
             "days：d<N>.<时段> → {event 事件 id（AfterStory.EVENTS）, task 赎罪簿上的任务名, hours 做完减几工时}。"],
    "npcs": NPCS, "days": DAYS}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 对话 / 过场 / 楼层表
dlg = Path("data/dialogues/floor_06")
files = dict(town.D)
errands.inject(files)
penalty.inject(files)
festival_night.inject(files, {f: (sid, mod.NODE) for f, (sid, mod, _k, _c) in STALLS.items()})
files["after_house_objects"] = house.HOUSE
files["after_house_up_objects"] = house.HOUSE_UP
files["after_blue_room"] = house.BLUE_ROOM
files.update(tailor.DIALOGUES)
files.update(mine.DIALOGUES)
files.update(totem.DIALOGUES)
files.update(drain.DIALOGUES)
files.update(drill.DIALOGUES)
files.update(inspect.DIALOGUES)
files["after_knight"] = knight_story.CELL
# 第 6 天小汤姆的话：按昨晚恶作剧的结局（只在第 6 天）
for _r, _lines in tom.TOM_NEXT_DAY.items():
    _d = files["after_kid_tom"]
    _d["nodes"]["tom_prank_" + _r] = {"lines": _lines}
    _d["entries"].insert(0, {"if": {"flag": "tom_prank_" + _r, "var": {"after_day": ["==", 6]}}, "node": "tom_prank_" + _r})
for name, d in files.items():
    (dlg / (name + ".json")).write_text(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")
signs_path = dlg / "signs.json"
signs = json.loads(signs_path.read_text())
signs.update(town.SIGNS)
signs.update(tailor.SIGNS)
signs.update(totem.SIGNS)
signs.update(drain.SIGNS)
signs.update(drill.SIGNS)
signs.update(inspect.SIGNS)
signs_path.write_text(json.dumps(signs, ensure_ascii=False, indent="\t") + "\n")

cut = Path("data/cutscenes/floor_06")
CUTS = dict(d1.CUTSCENES, **d2.CUTSCENES, **tasks.CUTSCENES, **potion.CUTSCENES, **tailor.CUTSCENES, **mine.CUTSCENES, **totem.CUTSCENES, **drain.CUTSCENES, **drill.CUTSCENES, **inspect.CUTSCENES, **festival_night.CUTSCENES, **knight_story.CUTSCENES)
for cid, fn in CUTS.items():
    (cut / (cid + ".json")).write_text(json.dumps(fn(), ensure_ascii=False, indent="\t") + "\n")
th = Path("data/theater/after")
th.mkdir(parents=True, exist_ok=True)
for tid, data in dict(punish.THEATERS, **tasks.THEATERS, **potion.THEATERS, **tailor.THEATERS, **mine.THEATERS, **totem.THEATERS, **drain.THEATERS, **drill.THEATERS, **inspect.THEATERS, **night.THEATERS, **knight_tasks.THEATERS).items():
    (th / (tid + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
NEW = [(TOWN, "地下小镇·战后", "town"), (HOUSE, "蓝色小屋·战后", "town"), (HOUSE_UP, "蓝色小屋·战后（楼上）", "night_room"),
       (PHARMACY, "药剂师工房", "town"), (FIELD, "城门外的战场", "town"), (TAILOR, "裁缝铺", "town"), (MINE, "受损的矿道", "town"), (TOTEM, "图腾柱废地", "town"), (DRAIN, "排水管", "town"), (DRILL, "队长的训练室", "town"), (PROVING, "保卫队训练营", "town"),
       (PRISON, "保卫队的地牢", "night_room")]
at = next(i for i, f in enumerate(lst) if f["id"] == "floor_06_siege") + 1
for fid, name, music in NEW:
    if not any(f["id"] == fid for f in lst):
        lst.insert(at, {"id": fid, "name": name, "scene": "res://levels/%s/floor.tscn" % fid, "group": "floor_06", "music": music})
    at += 1
Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("对话 %d 个文件、过场 %d 段、小剧场 %d 段" % (len(files), len(CUTS), len(punish.THEATERS)))
