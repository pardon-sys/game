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

from after_text import d1, d2, equip_kids, errand_dance, errand_goats, errand_ladder, errand_massage, errand_gate_chain, errand_shearing, errand_canopy, errand_sifting, errand_lamp_calibration, errands, house, mine, play, potion, punish, stocks, tailor, tasks, totem, town, drain, drill, inspect, tom, night, penalty, festival_night, festival_talk, stall_guess, stall_ring, stall_ice, stall_fish, stall_lick, done_folk  # noqa: E402
import quest_maps as qmaps  # noqa: E402
from knight_text import prison as knight_prison  # noqa: E402
from penance_text import argue as penance_argue, cell as penance_cell, tunnel as penance_tunnel, meet as penance_meet, waterway as penance_waterway, palace as penance_palace, palace2 as penance_palace2, palace3 as penance_palace3, palace4 as penance_palace4, palace5 as penance_palace5, palace6 as penance_palace6, palace7 as penance_palace7  # noqa: E402
from knight_text import finale as knight_finale, quests as knight_quests, story as knight_story, story_cg as knight_story_cg, tasks as knight_tasks, townsfolk as knight_townsfolk  # noqa: E402

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
    write_festival("data/dialogues/floor_06/after_bonfire_host.json", files["after_bonfire_host"])
    print("祭典专项生成：委托表、灯轮、补罚表、派对主人对话")
    sys.exit(0)

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
TOWN, HOUSE, HOUSE_UP = "floor_06_after", "floor_06_after_house", "floor_06_after_house_up"
PHARMACY, FIELD = "floor_06_after_pharmacy", "floor_06_after_field"
TAILOR, MINE, TOTEM = "floor_06_after_tailor", "floor_06_after_mine", "floor_06_after_totem"
DRAIN, DRILL, PROVING = "floor_06_after_drain", "floor_06_after_drill", "floor_06_after_proving"
CELLAR = "floor_06_after_cellar"
# 骑士篇支线的新图：小镇西边没有灯的小巷（① 灯全灭了）、矿道深处的草药洞（② 采药）
ALLEY, HERBCAVE = "floor_06_knight_alley", "floor_06_after_herbcave"
# ③ 城墙上（守夜）、④ 广场底下的裂缝、旧会堂
WALL, CRACK, OLDHALL = "floor_06_knight_wall", "floor_06_after_crack", "floor_06_after_oldhall"
# ⑤ 训练室后面的旧仓库（派对主人的八音盒零件）
WAREHOUSE = "floor_06_after_warehouse"
# ⑥ 西南角的储物间、排水渠上的小桥（蓝色公主的回忆）
STORAGE, BRIDGE = "floor_06_knight_storage", "floor_06_knight_bridge"
PRISON = "floor_06_after_prison"
FESTIVAL = "floor_06_festival"
KDAY, KNIGHT_N, KCHASE = "floor_06_knight_day", "floor_06_knight_night", "floor_06_knight_chase"
KFOG = "floor_06_knight_fog"
# 反省篇第一章（骑士篇之后）：营地医务帐篷（吵架）→ 反省牢房（docs/STORY_AFTER_KNIGHT.md）
PTENT, PCELL = "floor_06_penance_tent", "floor_06_penance_cell"
# 反省篇第二章：鼠洞（等距，quest_maps.py 的 _tunnel）
RTUNNEL = "floor_06_rat_tunnel"
# 反省篇第三章开场：废弃水道的出口（汇合；MeetExit）
WEXIT = "floor_06_waterway_exit"
# 反省篇第三章：废弃水道（等距 drain_water；quest_maps._waterway；WaterwayDirector + SluiceKeeper）
WATERWAY = "floor_06_waterway"
# 反省篇第四章（上）：旧王宫·旧浴场 / 仆人回廊 / 厨房（等距；quest_maps._palace_*；PalaceBath / PalaceServants / PalaceKitchen）
PBATH, PSERV, PKITCH = "floor_06_palace_bath", "floor_06_palace_servants", "floor_06_palace_kitchen"
# 第四章（中）：图书馆 / 衣帽间 / 骑士训练场
PLIB, PWARD, PTRAIN = "floor_06_palace_library", "floor_06_palace_wardrobe", "floor_06_palace_training"
# 第四章（下）：王座前厅 / 钟楼 / 隧道与密室 / 王座间
PANTE, PTUN, PTHRONE = "floor_06_palace_ante", "floor_06_palace_tunnels", "floor_06_palace_throne"
PGARDEN = "floor_06_palace_garden"
# 钟楼拆成五层（一层一张图，楼梯 / 梯子连起来）
PCLOCKS = ["floor_06_palace_clock_%d" % i for i in range(1, 6)]
PCLOCK = PCLOCKS[0]
# 各房间通往隧道的密道口（挂着一幅画；从隧道那一边走到过才打开）：房间 → (出口格, 回来的出生点格, 隧道里的出生点 id)
SECRET = {PBATH: ((46, 27), (44, 27), "bath"), PLIB: ((4, 13), (6, 13), "library"), PWARD: ((70, 26), (68, 26), "wardrobe"),
          PTRAIN: ((6, 18), (8, 18), "training")}


def _dress(m, fid, items):
    """往旧三张图里摆家具：只摆在空地上（不压住标记 / 机关）"""
    g = qmaps.grid(fid)
    for (x, y, kind) in items:
        if g[y][x] == ".":
            prop(m, x, y, kind)


def _secret_door(m, fid):
    (x, y), (sx, sy), key = SECRET[fid]
    m.put(x, y, "exit target=%s spawn=from_%s unlock_flag=palace_secret_%s locked_dialogue=palace_secret_closed" % (PTUN, key, key))
    m.put(sx, sy, "spawn id=from_tunnels")
    prop(m, x, y, "painting")


# 骑士篇支线小地图的标记点（quest_maps.py 画的图；写进 data/after/quest_maps.json，QuestMaps 读）
QMARKS = {}


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
KOBJ = "talk:floor_06/after_k_objects#"

# ================================================================ 战后的小镇
def town_layout(m, kind="town"):
    """战后小镇的布局（墙、房子、摊位、篝火、广场、城墙……）。kind = "town"：七日赎罪的小镇（所有出口、足枷、歪掉的图腾柱）；
    "knight"：骑士篇的三张小镇（只留小屋和工房的门，图腾柱已经修好，导演是 AfterRoom；人物各自摆）。"""
    m.room(2, 2, 61, 43)
    for x in (8, 20, 32, 44, 56):
        m.put(x, 1, "torch lit=true")
    m.put(3, 3, "f6after" if kind == "town" else "f6afterroom")
    # 东北角：通往矿道的门（平时钉死；第 5 天下午护送矿车时打开，通往受损的矿道）
    prop(m, 54, 4, "dungeon_gate")
    if kind == "town":
        m.put(54, 5, "exit target=%s spawn=from_town unlock_flag=after_mine_open locked_dialogue=after_mine_locked" % MINE)
    m.put(54, 6, "spawn id=from_mine")
    if kind == "knight":
        # 西边：没有灯的小巷（支线「骑士救公主」玩「灯全灭了」）
        m.put(2, 16, "exit target=%s spawn=from_town" % ALLEY)
        m.put(3, 16, "spawn id=from_alley")
        # 南边城墙下的梯子（支线「队长的旧剑术」守夜那一段才开）
        m.put(12, 40, "exit target=%s spawn=from_town unlock_flag=kq_spear_wall locked_dialogue=after_wall_locked" % WALL)
        m.put(12, 39, "spawn id=from_wall")
        # 广场边石板缝里的裂缝（支线「夜里的栅栏」裂缝那一段才开）
        m.put(38, 29, "exit target=%s spawn=from_town unlock_flag=kq_fence_crack locked_dialogue=after_crack_locked" % CRACK)
        m.put(38, 28, "spawn id=from_crack")
        # 训练室后面的旧仓库（支线「没有名字的生日」找零件那一段才开）
        m.put(4, 12, "exit target=%s spawn=from_town unlock_flag=kq_host_warehouse locked_dialogue=after_warehouse_locked" % WAREHOUSE)
        m.put(4, 13, "spawn id=from_warehouse")
        # 西南角：通往排水渠小桥的小路、储物间（支线「点灯笼的小姑娘」回忆那两段才开）
        m.put(2, 30, "exit target=%s spawn=from_town unlock_flag=kq_blue_bridge locked_dialogue=after_bridge_locked" % BRIDGE)
        m.put(3, 30, "spawn id=from_bridge")
        m.put(2, 34, "exit target=%s spawn=from_town unlock_flag=kq_blue_storage locked_dialogue=after_storage_locked" % STORAGE)
        m.put(3, 34, "spawn id=from_storage")
    # 居民区：烧焦的房子搭上了脚手架
    for i, x in enumerate((8, 16, 24, 32)):
        prop(m, x, 8, ("house_scaffold_%d" % (i // 2)) if i % 2 == 0 else "house_%d" % i)
    # 裁缝铺（北边最右边的房子；第 5 天早上试衣）
    if kind == "town":
        m.put(32, 9, "exit target=%s spawn=from_town" % TAILOR)
    m.put(32, 10, "spawn id=from_tailor")
    m.put(34, 10, "sign dialogue=after_tailor_sign")
    # 队长的训练室（西北角那座搭脚手架的房子；特训的时候开门）
    if kind == "town":
        m.put(8, 9, "exit target=%s spawn=from_town unlock_flag=after_drill_open locked_dialogue=after_drill_locked" % DRILL)
    else:
        # 骑士篇：一直开着（支线「队长的旧剑术」在里面练；做完以后找队长还能再练）
        m.put(8, 9, "exit target=%s spawn=from_town" % DRILL)
    m.put(8, 10, "spawn id=from_drill")
    # 东边的保卫队训练营（第 6 天早上验收陷阱）
    if kind == "town":
        m.put(61, 20, "exit target=%s spawn=from_town unlock_flag=after_proving_open locked_dialogue=after_proving_locked" % PROVING)
    m.put(60, 20, "spawn id=from_proving")
    # 南边的排水口（第 4 天早上通管）
    prop(m, 20, 39, "drain_grate")
    if kind == "town":
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
    # 篝火西边：庆功宴的入口（第 7 天晚上工时还清以后才开，平时走过去什么也不发生；AfterStory.sync_doors）
    if kind == "town":
        m.put(40, 24, "exit target=%s spawn=from_town unlock_flag=after_festival_open" % FESTIVAL)
    m.put(40, 26, "spawn id=from_festival")
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
    if kind == "town":
        m.put(23, 24, "trap type=stocks active=false")      # 第 2 天早上示众用（过场 hold 锁住）
    for (x, y) in ((25, 21), (36, 21)):
        prop(m, x, y, "bunting")
    m.put(30, 32, "savepoint place=战后的广场")
    # 歪掉的狂欢图腾柱（第七天修）
    prop(m, 18, 34, "totem_tilted" if kind == "town" else "totem_fixed", OBJ + "totem" if kind == "town" else "")
    # 西边的小路 → 图腾柱废地（第 7 天修图腾柱的时候才开）
    if kind == "town":
        m.put(2, 32, "exit target=%s spawn=from_town unlock_flag=after_totem_open locked_dialogue=after_totem_locked" % TOTEM)
    m.put(3, 32, "spawn id=from_totem")
    # 通往营地的楼梯：整修中
    prop(m, 59, 40, "stairs_down")
    # 骑士篇：路障可以调查（第一天夜里调查它 → 通风口 → 夜探地牢，knight_text/townsfolk.py 的 OBJECTS）
    prop(m, 58, 38, "barricade", KOBJ + "vent" if kind == "knight" else "")
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
    if kind == "town":
        m.put(32, 39, "exit target=%s spawn=from_town unlock_flag=after_field_open locked_dialogue=after_gate_closed" % FIELD)
    m.put(33, 36, "spawn id=from_field")


def scatter(m, seed, count):
    """地面：剩下的焦痕、灰烬、泥脚印、碎木。"""
    rnd = random.Random(seed)
    kinds = ["decal_footprints_0", "decal_straw_0", "decal_puddle_0", "decal_ash_1", "decal_scorch_1", "decal_splinters_0"]

    def free(x, y):
        if not (3 <= x <= 60 and 3 <= y <= 39) or m.g[y][x] != ".":
            return False
        return all((x + dx, y + dy) not in m.cells for dx in (-1, 0, 1) for dy in (-1, 0, 1))

    placed = tries = 0
    while placed < count and tries < 4000:
        tries += 1
        x, y = rnd.randint(3, 60), rnd.randint(3, 39)
        if free(x, y):
            prop(m, x, y, rnd.choice(kinds))
            placed += 1


m = Map(TOWN, 64, 46, "intro =\nambient = 0.66,0.56,0.5\nnight_ambient = 0.3,0.3,0.5\nno_switch = true")
town_layout(m)
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
scatter(m, 616, 55)
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
# 骑士篇：通往地窖的活板门（支线「手印样本」收到地窖那一段才开）
prop(ph, 12, 8, "trapdoor")
ph.put(12, 8, "exit target=%s spawn=from_pharmacy unlock_flag=kq_samples_cellar locked_dialogue=after_cellar_locked" % CELLAR)
ph.put(11, 8, "spawn id=from_cellar")
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

# ================================================================ 药剂师工房的地窖（骑士篇支线「手印样本」：药架隔出来的小过道，一团手印缩在最里面；布局见 quest_maps.py）
# ---------------------------------------------------------------- 支线地图里放之前的怪物 / 陷阱（每张 4~6 个，用户要求）
# 不放在：机关 / 出口 / 起点等标记点 3 格以内、已经有东西的格子、一格宽的走廊（周围地面少于 5 格，免得挡路）；彼此隔开 5 格；位置固定（种子）
QUEST_FOES = {
    CELLAR: ["monster type=rat", "monster type=spider", "trap type=brush", "monster type=rat"],
    ALLEY: ["monster type=rat", "monster type=bat", "monster type=rat", "trap type=feather", "monster type=bat"],
    HERBCAVE: ["monster type=caterpillar", "monster type=frog", "monster type=hedgehog", "trap type=vent idle_time=2.2 cloud_duration=1.2 offset=0.6"],
    WALL: ["monster type=imp", "trap type=brush", "monster type=glove", "monster type=imp", "trap type=feather"],
    CRACK: ["monster type=spider", "monster type=caterpillar", "monster type=spider", "trap type=vent idle_time=2.4 cloud_duration=1.2 offset=1.1"],
    OLDHALL: ["monster type=ghost", "monster type=ghost", "monster type=spider", "trap type=feather", "monster type=caterpillar"],
    WAREHOUSE: ["monster type=squirrel", "trap type=brush", "monster type=squirrel", "trap type=teaser"],
    STORAGE: ["monster type=glove", "trap type=brush", "monster type=glove", "trap type=teaser", "monster type=squirrel"],
    BRIDGE: ["monster type=slime", "monster type=bubble_fish", "monster type=frog", "monster type=slime", "monster type=crab"],
}


def scatter_foes(m, marks, specs, seed):
    import random
    rnd = random.Random(seed)
    near = [tuple(c) for cells in marks.values() for c in cells]
    def floor(x, y):
        return 0 <= y < m.h and 0 <= x < m.w and m.g[y][x] == "."
    def open_cell(x, y, need):
        return sum(1 for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy) and floor(x + dx, y + dy)) >= need
    picked = []
    # 先挑宽的地方；窄的地图（暗巷、小桥）一档一档放宽：离标记点的距离、周围地面格数、彼此间隔
    for mark_d, need, gap in ((3, 5, 5), (3, 3, 5), (2, 3, 4)):
        cand = [(x, y) for y in range(m.h) for x in range(m.w) if floor(x, y) and (x, y) not in m.cells
                and all(abs(x - a) + abs(y - b) > mark_d for a, b in near)]
        rnd.shuffle(cand)
        for c in cand:
            if len(picked) >= len(specs):
                break
            if c not in picked and open_cell(c[0], c[1], need) and all(abs(c[0] - a) + abs(c[1] - b) >= gap for a, b in picked):
                picked.append(c)
    print("  %s：放了 %d / %d 个怪物 / 陷阱" % (m.fid, len(picked), len(specs)))
    for (x, y), spec in zip(picked, specs):
        m.put(x, y, spec)
    return len(picked)


ce, cm = qmaps.build(Map, CELLAR, "intro =\nambient = 0.42,0.42,0.52\nno_switch = false", prop, "torch lit=true", 7)
QMARKS[CELLAR] = cm
ce.put(*cm["blue"][0], "f6afterroom")
ce.put(*cm["exit"][0], "exit target=%s spawn=from_cellar" % PHARMACY)
# 最里面的小门：通往草药洞（支线「手印样本」采药那一段才开）
hx, hy = cm["herb_door"][0]
ce.put(hx, hy, "exit target=%s spawn=from_cellar unlock_flag=kq_samples_herbs locked_dialogue=after_herb_locked" % HERBCAVE)
ce.put(hx - 1, hy, "spawn id=from_herbcave")
ce.put(*cm["start"][0], "spawn id=from_pharmacy")
ce.put(*cm["start"][0], "player")
ce.put(*cm["blue"][0], "blue_princess follow=true ai=false")
scatter_foes(ce, cm, QUEST_FOES[CELLAR], 557)
ce.write()

# ================================================================ 没有灯的小巷（骑士篇支线「骑士救公主」第四段：灯全灭了；一格宽的主巷子 + 窄道、死胡同、小院、环路）
# 等距画面（暖褐砖墙主题 alley_brick），不挂冷光：只靠 QuestHide 给的手提灯照明
# 骑士篇夜里支线的专属图都是等距：城墙 rampart、裂缝 crack_cave、旧会堂 old_hall（手提火把，不挂冷光）、储物间 storage_wood、小桥 drain_water
al, am = qmaps.build(Map, ALLEY, "intro =\nambient = 0.1,0.09,0.15\nno_switch = false\nstyle = iso\niso_theme = alley_brick\ncarry_light = false", prop)
QMARKS[ALLEY] = am
al.put(*am["blue"][0], "f6afterroom")
al.put(*am["exit"][0], "exit target=%s spawn=from_alley" % TOWN)
al.put(*am["start"][0], "spawn id=from_town")
al.put(*am["start"][0], "player")
al.put(*am["blue"][0], "blue_princess follow=true ai=false")
scatter_foes(al, am, QUEST_FOES[ALLEY], 51)
al.write()

# ================================================================ 矿道深处的草药洞（骑士篇支线「手印样本」第五段：三个洞室连着窄道；药草由 QuestHerbs 按标记点摆）
hc, hm = qmaps.build(Map, HERBCAVE, "intro =\nambient = 0.46,0.6,0.5\nno_switch = false", prop, "torch lit=true", 8)
QMARKS[HERBCAVE] = hm
hc.put(*hm["blue"][0], "f6afterroom")
hc.put(*hm["exit"][0], "exit target=%s spawn=from_herbcave" % CELLAR)
hc.put(*hm["start"][0], "spawn id=from_cellar")
hc.put(*hm["start"][0], "player")
hc.put(*hm["blue"][0], "blue_princess follow=true ai=false")
scatter_foes(hc, hm, QUEST_FOES[HERBCAVE], 738)
hc.write()

# ================================================================ 城墙上（骑士篇支线「队长的旧剑术」守夜：绕着小镇南边的城墙，拐弯、台阶，尽头是哨塔）
wl, wm = qmaps.build(Map, WALL, "intro =\nambient = 0.26,0.27,0.42\nno_switch = false\nstyle = iso\niso_theme = rampart", prop, "torch lit=false", 12)
QMARKS[WALL] = wm
wl.put(*wm["blue"][0], "f6afterroom")
wl.put(*wm["exit"][0], "exit target=%s spawn=from_wall" % TOWN)
wl.put(*wm["start"][0], "spawn id=from_town")
wl.put(*wm["start"][0], "player")
wl.put(*wm["blue"][0], "blue_princess follow=true ai=false")
scatter_foes(wl, wm, QUEST_FOES[WALL], 703)
wl.write()

# ================================================================ 广场底下的裂缝（骑士篇支线「夜里的栅栏」：趴着爬的窄缝，左右拐、有死角；软苔小球、三根封印钉）
ck, km = qmaps.build(Map, CRACK, "intro =\nambient = 0.3,0.22,0.36\nno_switch = false\nstyle = iso\niso_theme = crack_cave", prop)
QMARKS[CRACK] = km
ck.put(*km["exit"][0], "exit target=%s spawn=from_crack" % TOWN)
ck.put(*km["start"][0], "spawn id=from_town")
ck.put(*km["start"][0], "player")
ck.put(*km["blue"][0], "blue_princess follow=true ai=false")
ck.put(*km["blue"][0], "f6afterroom")
dx, dy = km["hall_door"][0]
ck.put(dx, dy, "exit target=%s spawn=from_crack unlock_flag=kq_fence_hall locked_dialogue=after_hall_locked" % OLDHALL)
ck.put(dx - 1, dy, "spawn id=from_hall")
scatter_foes(ck, km, QUEST_FOES[CRACK], 962)
ck.write()

# ================================================================ 旧会堂（骑士篇支线「夜里的栅栏」：塌了一半的大厅，两排柱子、耳房、倒下的长椅；壁画上的人像全被刮花了）
oh, om = qmaps.build(Map, OLDHALL, "intro =\nambient = 0.1,0.08,0.13\nno_switch = false\nstyle = iso\niso_theme = old_hall\ncarry_light = false", prop)
QMARKS[OLDHALL] = om
oh.put(*om["exit"][0], "exit target=%s spawn=from_hall" % CRACK)
oh.put(*om["start"][0], "spawn id=from_crack")
oh.put(*om["start"][0], "player")
oh.put(*om["blue"][0], "blue_princess follow=true ai=false")
oh.put(*om["blue"][0], "f6afterroom")
scatter_foes(oh, om, QUEST_FOES[OLDHALL], 195)
oh.write()

# ================================================================ 训练室后面的旧仓库（骑士篇支线「没有名字的生日」：货架隔出的过道、发条小手、零件；零件和小手由 QuestWarehouse 按标记点摆）
wh, whm = qmaps.build(Map, WAREHOUSE, "intro =\nambient = 0.4,0.36,0.42\nno_switch = false", prop, "torch lit=true", 9)
QMARKS[WAREHOUSE] = whm
wh.put(*whm["exit"][0], "exit target=%s spawn=from_warehouse" % TOWN)
wh.put(*whm["start"][0], "spawn id=from_town")
wh.put(*whm["start"][0], "player")
wh.put(*whm["blue"][0], "blue_princess follow=true ai=false")
wh.put(*whm["blue"][0], "f6afterroom")
scatter_foes(wh, whm, QUEST_FOES[WAREHOUSE], 457)
wh.write()

# ================================================================ 西南角的储物间（骑士篇支线「点灯笼的小姑娘」：上下两条储物走道，墙上的旧痒痒刷、尽头的旧布偶）
sr, srm = qmaps.build(Map, STORAGE, "intro =\nambient = 0.3,0.28,0.4\nno_switch = false\nstyle = iso\niso_theme = storage_wood", prop)
QMARKS[STORAGE] = srm
sr.put(*srm["exit"][0], "exit target=%s spawn=from_storage" % TOWN)
sr.put(*srm["start"][0], "spawn id=from_town")
sr.put(*srm["start"][0], "player")
sr.put(*srm["blue"][0], "blue_princess follow=true ai=false")
sr.put(*srm["blue"][0], "f6afterroom")
scatter_foes(sr, srm, QUEST_FOES[STORAGE], 201)
sr.write()

# ================================================================ 排水渠上的小桥（骑士篇支线「点灯笼的小姑娘」：一格宽的木桥，中间拐一个弯，桥下的手印）
bg, bgm = qmaps.build(Map, BRIDGE, "intro =\nambient = 0.28,0.3,0.45\nno_switch = false\nstyle = iso\niso_theme = drain_water", prop)
QMARKS[BRIDGE] = bgm
bg.put(*bgm["exit"][0], "exit target=%s spawn=from_bridge" % TOWN)
bg.put(*bgm["start"][0], "spawn id=from_town")
bg.put(*bgm["start"][0], "player")
bg.put(*bgm["blue"][0], "blue_princess follow=true ai=false")
bg.put(*bgm["blue"][0], "f6afterroom")
scatter_foes(bg, bgm, QUEST_FOES[BRIDGE], 263)
bg.write()

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
pz.put(4, 16, "stealth alert_rate=1.6 alert_decay=0.6")   # 骑士篇的地牢：比别的潜入关卡松一点（警觉涨得慢、退得快）
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
):
    # 视野短一点、窄一点、走得慢一点，路过木箱很少去翻（审问室不再有人绕圈）
    pz.put(int(path.split(";")[0].split(",")[0]), int(path.split(";")[0].split(",")[1]),
           "guard_patrol path=" + path + extra + " view_range=64 view_angle=55 speed=26 investigate_speed=44 check_chance=0.12")
pz.write()

# ================================================================ 反省篇第一章：营地医务帐篷 / 反省牢房（文本在 tools/build/penance_text/）
# 医务帐篷：骑士昏迷躺在行军床上；进图就演吵架（penance_argue），演完被关进反省牢房。
pt = Map(PTENT, 18, 12, "intro =\nintro_cutscene = penance_argue\nambient = 0.62,0.55,0.55\nno_switch = true")
pt.room(2, 2, 15, 9)
pt.put(8, 7, "player")
pt.put(9, 7, "spawn id=from_cell")
prop(pt, 4, 3, "princess_bed")
for (x, y) in ((13, 3), (14, 3)):
    prop(pt, x, y, "crate")
prop(pt, 3, 8, "barrel")
for x in (5, 12):
    pt.put(x, 1, "torch lit=true")
pt.write()

# 反省牢房：一个单屏的小房间，只有粉色公主。六件道具（PenanceCell 摆演员 + 调查点；格子在 penance_cell.gd 的 SPOTS 里），
# 六件都玩过以后东北角的墙缝里冒出挠脚鼠。南墙一道锁着的牢门（调查：门锁着）。
pc = Map(PCELL, 20, 14, "intro =\nintro_cutscene = penance_cell_in\nambient = 0.46,0.42,0.52\nno_switch = true")
pc.room(2, 2, 17, 11)
pc.put(10, 10, "player")
pc.put(10, 9, "spawn id=from_tent")
pc.put(3, 3, "penancecell")
prop(pc, 10, 12, "dungeon_gate", "talk:floor_06/penance_objects#gate")
for x in (6, 14):
    pc.put(x, 1, "torch lit=true")
pc.write()

# 鼠洞：等距（crack_cave），不挂冷光、靠火把；RatTunnel 按标记点摆滴水管、检查点、猫咪追逐、三段小剧场的触发点。
rt, rm = qmaps.build(Map, RTUNNEL, "intro =\nintro_cutscene = tunnel_in\nambient = 0.55,0.48,0.46\nno_switch = true\nstyle = iso\niso_theme = crack_cave", prop)
QMARKS[RTUNNEL] = rm
rt.put(*rm["start"][0], "player")
rt.put(*rm["start"][0], "spawn id=from_cell")
rt.put(2, 2, "rattunnel")
for (x, y) in rm["rats"]:
    rt.put(x, y, "monster type=rat")
rt.write()

# 废弃水道的出口：一个小小的等距平台，两边是水（drain_water）；进图 MeetExit 放汇合的过场和小剧场
we = Map(WEXIT, 22, 14, "intro =\nambient = 0.6,0.62,0.7\nno_switch = true\nstyle = iso\niso_theme = drain_water")
we.room(2, 3, 19, 10)
we.put(4, 7, "player")
we.put(4, 7, "spawn id=from_tunnel")
we.put(3, 4, "meetexit")
we.write()

# 废弃水道：两人同行（蓝色公主在玩家旁边，WaterwayDirector 开 Duo）；进图演 waterway_in
ww, wm = qmaps.build(Map, WATERWAY, "intro =\nintro_cutscene = waterway_in\nambient = 0.55,0.6,0.68\nno_switch = false\nstyle = iso\niso_theme = drain_water", prop)
QMARKS[WATERWAY] = wm
ww.put(*wm["start"][0], "player")
ww.put(*wm["start"][0], "spawn id=from_exit")
ww.put(4, 4, "blue_princess follow=true ai=false")
ww.put(2, 3, "waterwaydir")
for (x, y), foe in zip(wm["foes"], ["monster type=bubble_fish", "monster type=crab"]):
    ww.put(x, y, foe)
# 多放一些水边的怪（不放进守门人的场地）
_wg = qmaps.grid(WATERWAY)
for (x, y, kind) in ((20, 5, "frog"), (36, 4, "crab"), (42, 6, "slime"), (62, 10, "bubble_fish"), (54, 12, "frog"), (69, 13, "crab"),
                     (74, 7, "barnacle")):
    if _wg[y][x] in ".S":
        ww.put(x, y, "monster type=" + kind)
ww.write()

# ---------------------------------------------------------------- 第四章（上）：旧王宫（三张连在一起，来回都能走）
def _free(g, x, y):
    """布局里是空地、又不是标记字母（摆装饰用，不压住机关）"""
    return 0 <= y < len(g) and 0 <= x < len(g[0]) and g[y][x] == "."


def _dress_library(m, g, mk):
    """图书馆的书架：每排「书架墙」南面贴一排书架（隔一格一个），伸手的书架 / 能读的书也是书架"""
    for y in range(1, len(g)):
        for x in range(len(g[0])):
            if g[y - 1][x] == "#" and _free(g, x, y) and x % 2 == 0 and 5 < x < len(g[0]) - 6:
                prop(m, x, y, "bookshelf")
    for key in ("shelf_hands", "books"):
        for (x, y) in mk[key]:
            prop(m, x, y, "bookshelf")
    prop(m, *mk["golden_book"][0], "desk")
    sx, sy = mk["study"][0]
    prop(m, sx, sy, "desk")
    prop(m, sx - 2, sy, "candle")
    prop(m, sx + 1, sy - 1, "painting")
    prop(m, sx + 3, sy + 1, "chair")
    for (x, y) in ((6, 7), (79, 7), (6, 33), (79, 33), (30, 9), (58, 23)):
        if _free(g, x, y):
            prop(m, x, y, "cobweb")
    # 南边阅览区：几张书桌 + 椅子 + 蜡烛；柱子旁边的盆栽；禁书区的书架
    for (x, y) in ((12, 33), (20, 33), (38, 30), (48, 30), (62, 33), (72, 33)):
        if _free(g, x, y) and _free(g, x + 1, y):
            prop(m, x, y, "desk")
            prop(m, x + 1, y, "chair")
    for (x, y) in ((10, 31), (36, 30), (52, 31), (68, 30), (78, 31)):
        if _free(g, x, y):
            prop(m, x, y, "candle")
    for (x, y) in ((10, 8), (32, 8), (56, 8), (18, 31), (65, 33)):
        if _free(g, x, y):
            prop(m, x, y, "plant")
    for x in range(65, 80, 3):
        if _free(g, x, 8):
            prop(m, x, 8, "bookshelf")


def _dress_wardrobe(m, g, mk):
    for (x, y) in mk["racks"]:
        prop(m, x, y, "fabric")
    for key in ("mannequins", "favorite"):
        for (x, y) in mk[key]:
            prop(m, x, y, "dress_form")
    cx, cy = mk["dresses"][0]
    prop(m, cx, cy, "dress_form")
    if _free(g, cx + 1, cy):
        prop(m, cx + 1, cy, "dress_form")
    for (x, y) in mk["mirror_hands"]:
        prop(m, x, y, "mirror")
    prop(m, *mk["trap_wardrobe"][0], "wardrobe")
    prop(m, *mk["socks"][0], "music_box")
    keys = mk["keys"]
    for (x, y), kind in zip(keys, ("old_dresser", "ribbon_line", "dresser")):
        prop(m, x, y, kind)
    prop(m, *mk["fragment"][0], "ribbon_line")
    # 北墙一排穿衣镜和衣柜、南墙一排梳妆台（隔几格一个）
    for x in range(8, len(g[0]) - 4, 5):
        if _free(g, x, 4) and g[3][x] == "#":
            prop(m, x, 4, "mirror" if x % 10 < 5 else "wardrobe")
        if _free(g, x, 32) and g[33][x] == "#":
            prop(m, x, 32, "dresser" if x % 10 < 5 else "ribbon_line")
    # 试衣隔间里的椅子和镜子、东边的茶桌、多几具人台、盆栽和蜡烛
    for (x, y, kind) in ((18, 31, "chair"), (23, 31, "mirror"), (28, 31, "chair"), (54, 30, "tea_table"), (55, 31, "chair"),
                         (8, 6, "dress_form"), (8, 30, "dress_form"), (69, 30, "dress_form"), (62, 14, "ribbon_line"), (62, 22, "fabric"),
                         (48, 6, "plant"), (69, 10, "plant"), (8, 12, "plant"), (52, 12, "candle"), (52, 24, "candle"), (14, 18, "chair")):
        if _free(g, x, y):
            prop(m, x, y, kind)


def _dress_training(m, g, mk):
    prop(m, *mk["sign"][0], "notice_board")
    prop(m, *mk["carvings"][0], "height_marks")
    prop(m, *mk["stocks"][0], "stocks_plaza")
    prop(m, *mk["diary"][0], "old_dresser")
    prop(m, *mk["fragment"][0], "crate")
    for (x, y) in mk["dummies"]:
        prop(m, x, y + 1, "straw_mat")
    ax, ay = mk["ring"][0]
    for dx in (-2, 0, 2):
        for dy in (-1, 1):
            prop(m, ax + dx, ay + dy, "straw_mat")
    for x in range(9, len(g[0]) - 8, 6):
        if _free(g, x, 4) and g[3][x] == "#":
            prop(m, x, 4, "banner")
    for (x, y) in ((8, 20), (8, 26), (70, 30), (40, 33), (20, 33), (70, 24)):
        if _free(g, x, y):
            prop(m, x, y, "hay")
    # 西墙边一排旧稻草人（摆设）、角落的木箱和羽毛堆、兵器架旁边的长凳
    for y in range(16, 27, 3):
        if _free(g, 7, y):
            prop(m, 7, y, "dummy")
    for (x, y, kind) in ((68, 6, "crate"), (71, 8, "crate"), (66, 33, "crate"), (27, 33, "bench"), (49, 33, "bench"),
                         (36, 30, "feather_pile"), (60, 28, "feather_pile"), (12, 32, "candle"), (16, 30, "chair"), (70, 13, "banner"), (50, 13, "banner")):
        if _free(g, x, y):
            prop(m, x, y, kind)


PAL_HEAD = "ambient = 0.6,0.55,0.62\nno_switch = false\nstyle = iso\niso_theme = old_hall"
pb, pbm = qmaps.build(Map, PBATH, "intro =\nintro_cutscene = palace_bath_in\n" + PAL_HEAD, prop)
QMARKS[PBATH] = pbm
pb.put(*pbm["start"][0], "player")
pb.put(*pbm["start"][0], "spawn id=from_waterway")
pb.put(4, 4, "blue_princess follow=true ai=false")
pb.put(2, 2, "palacebath")
pb.put(*pbm["east"][0], "exit target=%s spawn=from_bath unlock_flag=palace_bath_key locked_dialogue=palace_bath_door" % PSERV)
pb.put(66, 11, "spawn id=from_servants")
_secret_door(pb, PBATH)
prop(pb, pbm["mirror"][0][0], pbm["mirror"][0][1] - 1, "mirror")   # 起雾的镜子（以前只有调查点，没有图）
_dress(pb, PBATH, ((28, 8, "plant"), (28, 26, "plant"), (33, 7, "bench"), (40, 7, "bench"), (46, 15, "candle"), (46, 22, "candle"),
                   (51, 16, "plant"), (65, 16, "plant"), (53, 29, "candle"), (63, 29, "candle"), (35, 27, "feather_pile"), (64, 7, "barrel")))
pb.write()

ps, psm = qmaps.build(Map, PSERV, "intro =\nintro_cutscene = palace_servants_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.42,0.4,0.5"), prop)
QMARKS[PSERV] = psm
ps.put(*psm["start"][0], "player")
ps.put(*psm["start"][0], "spawn id=from_bath")
ps.put(4, 16, "blue_princess follow=true ai=false")
ps.put(2, 15, "palaceservants")
ps.put(3, 15, "stealth on_caught=palace alert_rate=1.8 alert_decay=0.5")
ps.put(*psm["west"][0], "exit target=%s spawn=from_servants" % PBATH)
ps.put(*psm["east"][0], "exit target=%s spawn=from_servants unlock_flag=palace_servants_key locked_dialogue=palace_servants_door" % PKITCH)
ps.put(76, 17, "spawn id=from_kitchen")
# 事件点补素材：两张排班表钉在告示板上；女仆长房间的小茶桌（送点心）
for (_x, _y) in psm["clues"]:
    prop(ps, _x, _y - 1, "notice_board")
prop(ps, psm["deliver"][0][0], psm["deliver"][0][1] - 1, "tea_table")
for (x, y) in psm["hides"] + psm["hide_event"]:
    prop(ps, x, y, "crate", "hide")
for (x, y) in ((20, 16), (44, 18), (62, 17)):
    prop(ps, x, y, "crate", "hide")
MAID_SHEET = "res://assets/generated/npcs/doll_maid.png" if os.path.exists("assets/generated/npcs/doll_maid.png") else "res://assets/generated/npcs/maid.png"
MAID = " sheet=" + MAID_SHEET + " doll=true view_range=70 view_angle=60 speed=28 investigate_speed=46 check_chance=0.2"
for path, extra in (("8,17;30,17", ""), ("32,16;56,16", " wait=1.4"), ("58,18;72,18", ""), ("13,7;13,11", " wait=1.6"), ("31,23;31,27", " wait=1.6")):
    ps.put(*[int(v) for v in path.split(";")[0].split(",")], "guard_patrol path=" + path + extra + MAID)
hx, hy = psm["head_maid"][0]
HEAD_SHEET = "res://assets/generated/npcs/head_maid.png" if os.path.exists("assets/generated/npcs/head_maid.png") else MAID_SHEET
ps.put(hx, hy, ("guard_patrol path=%d,%d;%d,%d wait=3.0 sheet=" % (hx, hy, hx + 1, hy)) + HEAD_SHEET + " doll=true view_range=96 view_angle=80 speed=24 investigate_speed=40 check_chance=0.4")
for (x, y) in ((8, 15), (30, 15), (54, 19), (66, 9)):
    prop(ps, x, y, "lamp")
_dress(ps, PSERV, tuple((x0 + 1, 7, "old_bed") for x0 in (10, 22, 34, 46)) + tuple((x0 + 6, 7, "old_dresser") for x0 in (10, 22, 34, 46))
       + tuple((x0 + 1, 27, "old_bed") for x0 in (16, 28, 40, 52)) + tuple((x0 + 6, 27, "chair") for x0 in (16, 28, 40, 52))
       + ((70, 8, "desk"), (71, 9, "chair"), (62, 5, "bookshelf"), (73, 6, "wardrobe"), (25, 19, "plant"), (37, 19, "candle"), (49, 19, "plant")))
ps.write()

pk, pkm = qmaps.build(Map, PKITCH, "intro =\nintro_cutscene = palace_kitchen_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.66,0.6,0.55"), prop)
QMARKS[PKITCH] = pkm
pk.put(*pkm["start"][0], "player")
pk.put(*pkm["start"][0], "spawn id=from_servants")
pk.put(4, 5, "blue_princess follow=true ai=false")
pk.put(2, 4, "palacekitchen")
pk.put(*pkm["west"][0], "exit target=%s spawn=from_kitchen" % PSERV)
pk.put(*pkm["north"][0], "exit target=%s spawn=from_kitchen unlock_flag=palace_mouse_farewell locked_dialogue=palace_kitchen_north" % PLIB)
pk.put(25, 2, "spawn id=from_library")
prop(pk, pkm["booth"][0][0], pkm["booth"][0][1] - 1, "stall_0")   # 试吃推销员的小摊
for (x, y) in pkm["rats"]:
    pk.put(x, y, "monster type=rat")
_dress(pk, PKITCH, ((11, 8, "cauldron"), (23, 7, "cauldron"), (47, 9, "barrel"), (49, 13, "barrel"), (58, 9, "barrel"), (52, 13, "crate"),
                    (55, 9, "crate"), (34, 13, "tea_table"), (35, 14, "chair"), (42, 4, "herb_rack"), (18, 19, "crate"), (42, 19, "barrel")))
pk.write()

pl, plm = qmaps.build(Map, PLIB, "intro =\nintro_cutscene = palace_library_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.55,0.5,0.45"), prop)
QMARKS[PLIB] = plm
pl.put(*plm["start"][0], "player")
pl.put(*plm["start"][0], "spawn id=from_kitchen")
pl.put(44, 32, "blue_princess follow=true ai=false")
pl.put(5, 7, "palacelibrary")
pl.put(*plm["south"][0], "exit target=%s spawn=from_library" % PKITCH)
pl.put(*plm["west"][0], "exit target=%s spawn=from_library" % PTRAIN)
pl.put(3, 19, "spawn id=from_training")
pl.put(*plm["east"][0], "exit target=%s spawn=from_library" % PWARD)
pl.put(82, 19, "spawn id=from_wardrobe")
for (x, y) in ((10, 7), (40, 7), (70, 33), (20, 33)):
    prop(pl, x, y, "lamp")
_dress_library(pl, qmaps.grid(PLIB), plm)
_secret_door(pl, PLIB)
# 追加事件：禁书区的书架暗门（抽出夹着衣架书签的书才开）→ 衣帽间的大衣柜后面；没走过之前不显示标志（secret）
_sx, _sy = plm["shelf_door"][0]
pl.put(_sx, _sy, "exit target=%s spawn=from_library_shelf unlock_flag=palace_shelf_door locked_dialogue=palace_shelf_closed secret=true" % PWARD)
pl.put(_sx - 2, _sy, "spawn id=from_wardrobe_shelf")
prop(pl, _sx, _sy - 1, "bookshelf")
pl.write()

pw, pwm = qmaps.build(Map, PWARD, "intro =\nintro_cutscene = palace_wardrobe_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.62,0.55,0.6"), prop)
QMARKS[PWARD] = pwm
pw.put(*pwm["start"][0], "player")
pw.put(*pwm["start"][0], "spawn id=from_library")
pw.put(4, 17, "blue_princess follow=true ai=false")
pw.put(7, 5, "palacewardrobe")
pw.put(*pwm["west"][0], "exit target=%s spawn=from_wardrobe" % PLIB)
_dress_wardrobe(pw, qmaps.grid(PWARD), pwm)
_secret_door(pw, PWARD)
_sx, _sy = pwm["shelf_door"][0]
pw.put(_sx, _sy, "exit target=%s spawn=from_wardrobe_shelf unlock_flag=palace_shelf_door locked_dialogue=palace_shelf_closed_w secret=true" % PLIB)
pw.put(_sx - 2, _sy, "spawn id=from_library_shelf")
prop(pw, _sx, _sy - 1, "dresser")
# 追加事件：旧鞋军团（把它们引到鞋柜 shoe_closet 旁边关门）
for (_x, _y) in pwm["shoes"]:
    pw.put(_x, _y, "monster type=old_shoe")
prop(pw, pwm["shoe_closet"][0][0], pwm["shoe_closet"][0][1] - 1, "wardrobe")   # 鞋柜
pw.write()

pt2, ptm = qmaps.build(Map, PTRAIN, "intro =\nintro_cutscene = palace_training_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.6,0.58,0.55"), prop)
QMARKS[PTRAIN] = ptm
pt2.put(*ptm["start"][0], "player")
pt2.put(*ptm["start"][0], "spawn id=from_library")
pt2.put(75, 17, "blue_princess follow=true ai=false")
pt2.put(7, 5, "palacetraining")
pt2.put(*ptm["east"][0], "exit target=%s spawn=from_training" % PLIB)
pt2.put(*ptm["north"][0], "exit target=%s spawn=from_training" % PANTE)
pt2.put(38, 4, "spawn id=from_ante")
prop(pt2, ptm["fragment"][0][0], ptm["fragment"][0][1] - 1, "crate")   # 锁着的旧箱子
_secret_door(pt2, PTRAIN)
_dress_training(pt2, qmaps.grid(PTRAIN), ptm)
pt2.write()

# ---------------------------------------------------------------- 第四章（下）
pa, pam = qmaps.build(Map, PANTE, "intro =\nintro_cutscene = palace_ante_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.55,0.5,0.6"), prop)
QMARKS[PANTE] = pam
pa.put(*pam["start"][0], "player")
pa.put(*pam["start"][0], "spawn id=from_training")
pa.put(32, 35, "blue_princess follow=true ai=false")
pa.put(30, 34, "palaceante")
pa.put(*pam["south"][0], "exit target=%s spawn=from_ante" % PTRAIN)
pa.put(4, 20, "exit target=%s spawn=from_ante" % PCLOCK)
pa.put(8, 20, "spawn id=from_clock")
pa.put(*pam["throne_door"][0], "exit target=%s spawn=from_ante unlock_flag=palace_bells_done locked_dialogue=palace_throne_sealed" % PTHRONE)
pa.put(30, 6, "spawn id=from_throne")
pa.put(54, 20, "exit target=%s spawn=from_ante" % PTUN)
# 第四轮：东北角柱子后面的暗门 → 后花园（石像三问全对以后才知道；没走过之前不显示标志）
pa.put(*pam["garden_door"][0], "exit target=%s spawn=from_ante unlock_flag=palace_garden_clue locked_dialogue=palace_garden_closed secret=true" % PGARDEN)
pa.put(41, 11, "spawn id=from_garden")
pa.put(51, 20, "spawn id=from_tunnels")
for (x, y) in ((22, 12), (38, 12), (22, 28), (38, 28)):
    prop(pa, x, y, "lamp")
for (x, y, kind) in ((28, 3, "banner"), (32, 3, "banner"), (17, 20, "plant"), (43, 20, "plant"), (25, 33, "candle"), (35, 33, "candle")):
    prop(pa, x, y, kind)
prop(pa, 53, 19, "painting")
pa.write()

CLOCK_NAMES = ["一层·齿轮间", "二层·钟摆厅", "三层·风箱台", "四层·回廊", "钟顶"]
for i, fid in enumerate(PCLOCKS):
    head = "intro =\n" + ("intro_cutscene = palace_clock_in\n" if i == 0 else "") + PAL_HEAD.replace("0.6,0.55,0.62", "0.5,0.48,0.52")
    cm, cmm = qmaps.build(Map, fid, head, prop)
    QMARKS[fid] = cmm
    sx, sy = cmm["start"][0]
    cm.put(sx, sy, "player")
    cm.put(sx, sy, "spawn id=" + ("from_ante" if i == 0 else "from_below"))
    cm.put(sx + 2, sy, "blue_princess follow=true ai=false")
    cm.put(sx, sy - 1, "palaceclock map=" + fid)
    zx, zy = cmm["south"][0]
    below = PANTE if i == 0 else PCLOCKS[i - 1]
    cm.put(zx, zy, "exit target=%s spawn=%s" % (below, "from_clock" if i == 0 else "from_above"))
    up = cmm.get("up") or cmm.get("ladder")
    if up:
        ux, uy = up[0]
        lock = ""
        if i == 2:
            lock = " unlock_flag=palace_ladder_down locked_dialogue=palace_ladder_up"
        elif i == 3:
            lock = " unlock_flag=palace_keeper_done locked_dialogue=palace_keeper_block"
        cm.put(ux, uy, "exit target=%s spawn=from_below%s" % (PCLOCKS[i + 1], lock))
        cm.put(ux, uy + 2, "spawn id=from_above")
    _cg = qmaps.grid(fid)
    for (x, y, kind) in ((8, 8, "lamp"), (len(_cg[0]) - 8, 8, "lamp"), (8, len(_cg) - 10, "lamp"), (len(_cg[0]) - 8, len(_cg) - 10, "lamp"),
                         (10, 10, "cobweb"), (len(_cg[0]) - 10, 12, "crate"), (12, len(_cg) - 12, "plank_bundle")):
        if 0 < y < len(_cg) and 0 < x < len(_cg[0]) and _cg[y][x] == ".":
            prop(cm, x, y, kind)
    cm.write()

pu, pum = qmaps.build(Map, PTUN, "intro =\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.36,0.34,0.42"), prop)
QMARKS[PTUN] = pum
pu.put(88, 29, "player")
pu.put(88, 29, "spawn id=from_ante")
pu.put(89, 30, "blue_princess follow=true ai=false")
pu.put(89, 30, "palacetunnels")
pu.put(91, 29, "exit target=%s spawn=from_tunnels" % PANTE)
for key, (ex, ey), (sx, sy), target in (("to_bath", (4, 29), (7, 29), PBATH), ("to_library", (11, 8), (11, 11), PLIB),
                                         ("to_wardrobe", (84, 8), (83, 11), PWARD), ("to_training", (47, 6), (47, 9), PTRAIN)):
    pu.put(ex, ey, "exit target=%s spawn=from_tunnels" % target)
    pu.put(sx, sy, "spawn id=from_" + key[3:])
for (x, y) in ((20, 29), (40, 29), (60, 29), (80, 29), (11, 20), (47, 20), (71, 40), (83, 20), (30, 41), (11, 49)):   # 黑暗区（x 10..12, y 32..46）里不放灯
    prop(pu, x, y, "lamp")
for (x, y, kind) in ((pum["quilt"][0][0], pum["quilt"][0][1] - 1, "princess_bed"), (pum["vanity"][0][0], pum["vanity"][0][1] - 1, "dresser"),
                     (pum["diary"][0][0], pum["diary"][0][1] - 1, "old_dresser"), (pum["height_marks"][0][0], pum["height_marks"][0][1] - 1, "height_marks"),
                     (pum["lost_board"][0][0] - 1, pum["lost_board"][0][1] + 1, "notice_board"), (80, 12, "wardrobe"), (66, 6, "candle"),
                     (20, 47, "plant"), (16, 52, "blue_bed"), (30, 49, "crate"), (60, 46, "cobweb"), (35, 28, "cobweb")):
    if qmaps.grid(PTUN)[y][x] == ".":
        prop(pu, x, y, kind)
pu.write()

pth, pthm = qmaps.build(Map, PTHRONE, "intro =\nintro_cutscene = palace_throne_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.5,0.42,0.52"), prop)
QMARKS[PTHRONE] = pthm
pth.put(*pthm["start"][0], "player")
pth.put(*pthm["start"][0], "spawn id=from_ante")
pth.put(37, 44, "blue_princess follow=true ai=false")
pth.put(35, 43, "palacethrone")
pth.put(*pthm["south"][0], "exit target=%s spawn=from_throne" % PANTE)
for (x, y) in ((20, 14), (50, 14), (20, 34), (50, 34)):
    prop(pth, x, y, "lamp")
for (x, y, kind) in ((30, 12, "banner"), (40, 12, "banner"), (5, 47, "feather_pile"), (20, 52, "feather_pile")):
    prop(pth, x, y, kind)
pth.write()

# ---------------------------------------------------------------- 第四章·后花园（第四轮追加事件：前厅东北角的暗门）
pgd, pgdm = qmaps.build(Map, PGARDEN, "intro =\nintro_cutscene = palace_garden_in\n" + PAL_HEAD.replace("0.6,0.55,0.62", "0.74,0.72,0.68").replace("iso_theme = old_hall", "iso_theme = palace_garden"), prop)
QMARKS[PGARDEN] = pgdm
pgd.put(*pgdm["start"][0], "player")
pgd.put(*pgdm["start"][0], "spawn id=from_ante")
pgd.put(pgdm["start"][0][0] + 2, pgdm["start"][0][1], "blue_princess follow=true ai=false")
pgd.put(pgdm["start"][0][0] - 2, pgdm["start"][0][1], "palacegarden")
pgd.put(*pgdm["south"][0], "exit target=%s spawn=from_garden" % PANTE)
for (x, y) in pgdm["fairies"]:
    pgd.put(x, y, "monster type=fairy")
for (x, y) in ((12, 18), (44, 18), (12, 30), (20, 36), (36, 36)):
    if qmaps.grid(PGARDEN)[y][x] == ".":
        prop(pgd, x, y, "plant")
pgd.write()


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

# ================================================================ 骑士篇的三张小镇（布局同战后小镇 town_layout；人物各自摆，不挂委托，导演 AfterRoom）
# 白天（发现骑士、抬担架、去工房）：保卫队和各家门口的人；夜里（以笑为饵）：镇民都在广场上；追逃 / Boss：一个镇民都没有。
KTOWN_HEAD = "intro =\nambient = 0.66,0.56,0.5\nnight_ambient = 0.3,0.3,0.5\nno_switch = true"
K_DAY_NPCS = {   # 对话文件 -> (人物图, 格, 朝向, 闲逛)
    "after_k_captain": ("captain", (51, 9), "right", 0), "after_k_guard_gate": ("guard", (29, 38), "down", 0),
    "after_k_guard_gate2": ("guard", (35, 38), "down", 0), "after_k_granny": ("granny", (45, 12), "down", 1),
    "after_k_merchant": ("merchant", (8, 24), "down", 1), "after_k_engineer": ("miner", (34, 36), "down", 1),
    "after_k_maid": ("maid", (57, 33), "left", 1), "after_k_mayor": ("mayor", (31, 29), "down", 0),
    "after_k_kids": ("kid", (30, 31), "down", 2),
    "after_k_host": ("bonfire_host", (46, 24), "left", 0),
    # 主线触发：和他们说话才开始（第一天早上发现骑士、第二天早上诅咒失控）
    "after_k_guard_dungeon": ("guard", (54, 10), "left", 0), "after_k_guard_camp": ("guard", (55, 38), "right", 0),
}
K_NIGHT_NPCS = {
    "after_kn_mayor": ("mayor", (42, 21), "down", 0), "after_kn_captain": ("captain", (39, 24), "right", 0),
    "after_kn_granny": ("granny", (37, 22), "down", 0), "after_kn_merchant": ("merchant", (36, 27), "right", 0),
    "after_kn_engineer": ("miner", (48, 22), "down", 0), "after_kn_tom": ("kid", (49, 27), "left", 0),
    "after_kn_lily": ("kid", (44, 23), "down", 0), "after_kn_maid": ("maid", (51, 25), "left", 0),
    "after_kn_supervisor": ("supervisor", (33, 24), "right", 0),
}
for _fid, _npcs, _seed in ((KDAY, K_DAY_NPCS, 801), (KNIGHT_N, K_NIGHT_NPCS, 802), (KCHASE, {}, 803)):
    km = Map(_fid, 64, 46, KTOWN_HEAD)
    town_layout(km, "knight")
    km.put(42, 11, "player")
    km.put(43, 11, "blue_princess follow=true ai=false")
    for _f, (_nid, (_x, _y), _d, _w) in _npcs.items():
        npc(km, _x, _y, _nid, _f, _w, "dir=" + _d)
    if _fid == KNIGHT_N:
        # 广场上暗掉的那盏笑声灯笼：调查它 → 以笑为饵
        prop(km, 34, 26, "lamp", KOBJ + "lantern")
    scatter(km, _seed, 55)
    km.write()

# ================================================================ 笑雾之中（骑士 Boss 最后阶段）：广场的倒影——和诅咒失控的小镇同一个格局，等距画面、黑雾主题
# TaskKnightBoss 在这张图上从第 3 阶段接着打（坐标和广场一样：骑士 CENTER、灯笼、掩体都沿用）；不挂冷光，灯笼就是光
kf = Map(KFOG, 64, 46, "intro =\nambient = 0.2,0.14,0.28\nno_switch = true\nstyle = iso\niso_theme = laugh_fog\niso_rotate = false\ncarry_light = false")
town_layout(kf, "knight")
# 雾里没有门：出口全去掉（只是倒影）
for _c in list(kf.cells):
    kf.cells[_c] = [sp for sp in kf.cells[_c] if not sp.startswith("exit ")]
    if not kf.cells[_c]:
        del kf.cells[_c]
kf.put(41, 29, "player")
kf.put(43, 29, "blue_princess follow=true ai=false")
kf.put(41, 29, "spawn id=start")
kf.write()

# ================================================================ 庆功宴的广场（第 7 天晚上，工时还清以后从小镇广场中间的入口过来）
# 战后百废待兴：补了一半的城墙和脚手架、打着补丁的帐篷、碎石堆上插着笑声灯笼、木箱拼的临时摊位；中间是篝火和修好的图腾柱。
# 摊位通关以后的装扮（show_flag = stall_<id>_done）：饼干串灯、彩色发绳 + 跑来跑去的小孩、三座冰雕、足疗鱼盆、戴铃铛的咕咕。
FOBJ = "talk:floor_06/after_fest_objects#"
fe = Map(FESTIVAL, 44, 32, "intro =\nambient = 0.66,0.56,0.5\nnight_ambient = 0.42,0.36,0.52\nno_switch = true")
fe.room(2, 2, 41, 29)
for x in (6, 14, 30, 38):
    fe.put(x, 1, "torch lit=true")
fe.put(3, 3, "f6afterroom")
# 北边：补了一半的城墙（脚手架上挂着灯笼）、修好的图腾柱、伤员帐篷改成的歇脚棚
prop(fe, 7, 5, "wall_half", FOBJ + "wall")
prop(fe, 13, 5, "house_scaffold_1")
prop(fe, 22, 7, "totem_fixed", FOBJ + "totem")
prop(fe, 31, 5, "tent_patched", FOBJ + "tent")
prop(fe, 37, 5, "wall_half", FOBJ + "wall")
for (x, y) in ((17, 4), (27, 4), (3, 9), (40, 9)):
    prop(fe, x, y, "lantern_rubble")
prop(fe, 26, 6, "lumber", FOBJ + "lumber")
prop(fe, 18, 6, "rubble")
# 广场中间：篝火、长椅、头顶的灯笼串
prop(fe, 22, 15, "bonfire_0", "heal")
for (x, y) in ((18, 13), (26, 13), (18, 18), (26, 18)):
    prop(fe, x, y, "bench")
for (x, y) in ((12, 10), (32, 10), (12, 23), (32, 23)):
    prop(fe, x, y, "lantern_string")
for (x, y) in ((17, 22), (27, 22)):
    prop(fe, x, y, "bunting")
prop(fe, 22, 24, "well")
# 西边：奶奶的脚底猜猜乐、商人的忍笑套圈（木箱拼的临时摊位）
prop(fe, 6, 13, "crate_stall")
fe.put(6, 11, "prop type=cookie_lights show_flag=stall_guess_done")
prop(fe, 6, 20, "stall_1")
fe.put(9, 22, "prop type=ribbon_line show_flag=stall_ring_done")
for y in (16, 17):
    prop(fe, 3, y, "crate")
# 东边：工匠的冰雕摊（三块冰 → 通关以后三座冰雕）、小汤姆的捞痒痒鱼
prop(fe, 37, 12, "crate_stall")
for x, kind in ((34, "ice_sheep"), (37, "ice_lantern"), (40, "ice_girls")):
    fe.put(x, 15, "prop type=ice_raw hidden_flag=stall_ice_done")
    fe.put(x, 15, "prop type=%s show_flag=stall_ice_done action=%sice_%s" % (kind, FOBJ, kind.split("_")[1]))
prop(fe, 37, 20, "crate_stall")
fe.put(24, 17, "prop type=fish_basin show_flag=stall_fish_done action=%sfish_basin" % FOBJ)
# 南边：女仆的舔盐耐力赛（帐篷旁边的干草堆）、还没修完的南墙（沙袋、木料）
prop(fe, 31, 25, "tent")
prop(fe, 34, 26, "hay")
for (x, y) in ((6, 27), (14, 27)):
    prop(fe, x, y, "sandbag")
prop(fe, 10, 27, "lumber", FOBJ + "lumber")
prop(fe, 36, 27, "wall_half", FOBJ + "wall")
prop(fe, 40, 25, "lantern_rubble")
fe.put(22, 29, "exit target=%s spawn=from_festival" % TOWN)
fe.put(22, 27, "spawn id=from_town")
fe.put(22, 26, "player")
fe.put(23, 26, "blue_princess follow=true ai=false")
# 庆功宴上的人：每人一个庆功宴专属的对话文件（after_text/festival_talk.py），身上不挂委托
FEST_NPCS = {   # 对话文件 -> (人物图, 格, 朝向, 闲逛)
    "after_fest_host": ("bonfire_host", (24, 14), "left", 0), "after_fest_mayor": ("mayor", (22, 11), "down", 0),
    "after_fest_captain": ("captain", (19, 11), "down", 0), "after_fest_granny": ("granny", (6, 15), "down", 0),
    "after_fest_merchant": ("merchant", (8, 21), "down", 0), "after_fest_engineer": ("miner", (37, 14), "down", 0),
    "after_fest_tom": ("kid", (37, 22), "down", 0), "after_fest_maid": ("maid", (33, 26), "left", 0),
    "after_fest_lily": ("kid", (20, 19), "up", 1), "after_fest_supervisor": ("supervisor", (14, 15), "right", 1),
    "after_fest_guard_a": ("guard", (29, 9), "down", 0), "after_fest_guard_b": ("guard", (12, 26), "up", 1),
}
for f, (nid, (x, y), d, wander) in FEST_NPCS.items():
    npc(fe, x, y, nid, f, wander, "dir=" + d)
# 装扮里会动的：套圈通关以后戴着彩色发绳跑来跑去的小孩、舔盐通关以后戴着铃铛闲逛的咕咕
npc(fe, 15, 20, "kid", "after_fest_ribbon_kids", 3, "show_flag=stall_ring_done")
npc(fe, 28, 19, "kid", "after_fest_ribbon_kids", 3, "show_flag=stall_ring_done")
npc(fe, 29, 16, "goat_bell", "after_fest_gugu", 3, "show_flag=stall_lick_done")
frnd = random.Random(707)
FANY = ["decal_footprints_0", "decal_straw_0", "decal_ash_1", "decal_splinters_0", "decal_scorch_1"]
fplaced = 0
for _ in range(1500):
    x, y = frnd.randint(3, 40), frnd.randint(3, 28)
    if fe.g[y][x] == "." and all((x + dx, y + dy) not in fe.cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
        prop(fe, x, y, frnd.choice(FANY))
        fplaced += 1
        if fplaced >= 26:
            break
fe.write()
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
# 第 7 天晚上：工时没还清时市场监督和派对主人在广场接补罚；其他人去庆功宴的广场了（骑士篇夜里沿用这些位置）
D7_NIGHT = {"after_bonfire_host": (45, 26, "left"), "after_mayor": (42, 21, "down"), "after_captain": (39, 24, "right"),
            "after_granny": (37, 22, "down"), "after_merchant": (36, 27, "right"), "after_engineer": (48, 22, "down"),
            "after_kid_tom": (49, 27, "left"), "after_kid_lily": (44, 23, "down"), "after_maid": (51, 25, "left"),
            "after_supervisor": (33, 24, "right")}
for _f, (_x, _y, _d) in D7_NIGHT.items():
    # 庆功宴在单独的广场图上开（floor_06_festival）：小镇上只留接补罚的市场监督和派对主人，庆功宴一开始也走（AfterTown.apply_schedule）
    NPCS[_f].setdefault("d7", {})["night"] = ({"at": [_x, _y], "dir": _d, "wander": 0, "hidden": False}
                                             if _f in ("after_supervisor", "after_bonfire_host") else HIDE)
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
    **festival_night.FESTIVAL, reward_lines={m.__name__.rsplit("_", 1)[1]: m.REWARD for m in (stall_guess, stall_ring, stall_ice, stall_fish, stall_lick)}),
    ensure_ascii=False, indent="\t") + "\n")
STALLS = {"after_granny": ("guess", stall_guess, "GUESS", "StallGuessShow"), "after_merchant": ("ring", stall_ring, "RING", "StallRingShow"),
          "after_engineer": ("ice", stall_ice, "ICE", "StallIceShow"), "after_kid_tom": ("fish", stall_fish, "FISH", "StallFishShow"),
          "after_maid": ("lick", stall_lick, "LICK", "StallLickShow")}
# 摊主在庆功宴广场上的对话文件
STALL_FILES = {"after_granny": "after_fest_granny", "after_merchant": "after_fest_merchant", "after_engineer": "after_fest_engineer",
               "after_kid_tom": "after_fest_tom", "after_maid": "after_fest_maid"}
for _sid, _mod, _key, _cls in STALLS.values():
    _st = dict(getattr(_mod, _key))
    _st.setdefault("success_react", _st.get("right", []))
    Path("data/after/stall_%s.json" % _sid).write_text(json.dumps(dict({"_说明": "庆功宴摊位（after_text/stall_%s.py 生成，%s 读）。" % (_sid, _cls)}, **_st),
        ensure_ascii=False, indent="\t") + "\n")
Path("data/after/knight.json").write_text(json.dumps(dict({"_说明": "骑士篇 A~D 的玩法文本（knight_text/tasks.py 生成，TaskStretcher / TaskBait / InterrogationChairShow 读）。"},
    **knight_tasks.KNIGHT), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/palace.json").write_text(json.dumps(dict({"_说明": "反省篇第四章·旧王宫玩法里的短台词（penance_text/palace.py 生成，PalaceRoom 读）。"},
    **penance_palace.TEXT, **penance_palace2.TEXT, **penance_palace3.TEXT, **penance_palace4.TEXT, **penance_palace5.TEXT, **penance_palace6.TEXT, **penance_palace7.TEXT), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/waterway.json").write_text(json.dumps(dict({"_说明": "反省篇第三章·废弃水道玩法里的短台词（penance_text/waterway.py 生成，WaterwayDirector / SluiceKeeper 读）。"},
    **penance_waterway.TEXT), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/tunnel.json").write_text(json.dumps(dict({"_说明": "反省篇第二章·鼠洞玩法里的短台词（penance_text/tunnel.py 生成，RatTunnel 读）。"},
    **penance_tunnel.TEXT), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/quest_maps.json").write_text(json.dumps(dict({"_说明": "骑士篇支线小地图的标记点（tools/build/quest_maps.py 画的图，gen_floor06_after.py 生成，QuestMaps 读）。"}, **QMARKS), ensure_ascii=False) + "\n")
Path("data/after/knight_quests.json").write_text(json.dumps(dict({"_说明": "骑士篇的四个支线（knight_text/quests.py 生成，KnightQuests 和支线的玩法节点读）。"},
    quests=knight_quests.QUESTS), ensure_ascii=False, indent="\t") + "\n")
Path("data/after/knight_finale.json").write_text(json.dumps(dict({"_说明": "骑士篇 E~G 的玩法文本（knight_text/finale.py 生成，TaskArmorChase / TaskKnightBoss 读）。"},
    **knight_finale.FINALE), ensure_ascii=False, indent="\t") + "\n")
# 人物表：骑士（行走图 / 立绘由 tools/art/gen_knight_art.py、import_knight_portrait.py 生成）
_npcs = json.loads(Path("data/actors/npcs.json").read_text())
_npcs["npcs"]["knight"] = {"name": knight_story.KNIGHT, "sprite": "res://assets/generated/npcs/knight.png", "portrait": "res://assets/generated/npc_portraits/knight.png"}
_npcs["npcs"]["knight_cursed"] = {"name": knight_story.KNIGHT, "sprite": "res://assets/generated/npcs/knight_cursed.png", "portrait": "res://assets/generated/npc_portraits/knight.png"}
# 笑雾之中：被黑雾操控、浮在半空的骑士（精灵图 4×2 格 80 像素：上排浮空、下排落地被解脱；立绘被黑雾缠着）
_npcs["npcs"]["knight_possessed"] = {"name": knight_story.KNIGHT, "sprite": "res://assets/generated/npcs/knight_cursed.png", "portrait": "res://assets/generated/npc_portraits/knight_possessed.png"}
# 庆功宴：舔盐耐力赛通关以后戴着铃铛闲逛的咕咕（tools/art/gen_festival_art.py）
_npcs["npcs"]["goat_bell"] = {"name": "咕咕", "sprite": "res://assets/generated/npcs/goat_bell.png"}
# 反省篇第四章：旧王宫的人偶女仆（tools/art/gen_palace_sprites.py），小剧场里用 npc:doll_maid
_npcs["npcs"]["doll_maid"] = {"name": "人偶女仆", "sprite": "res://assets/generated/npcs/doll_maid.png"}
_npcs["npcs"]["clock_keeper"] = {"name": "守钟人偶", "sprite": "res://assets/generated/npcs/clock_keeper.png" if os.path.exists("assets/generated/npcs/clock_keeper.png") else "res://assets/generated/npcs/doll_maid.png"}
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
festival_talk.inject(files)
festival_night.inject(files, {STALL_FILES[f]: (sid, mod.NODE) for f, (sid, mod, _k, _c) in STALLS.items()})
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
files.update(knight_townsfolk.DIALOGUES)
files.update(knight_prison.DIALOGUES)
files.update(penance_cell.DIALOGUES)
files.update(penance_tunnel.DIALOGUES)
files.update(penance_palace.DIALOGUES)
files.update(penance_palace2.DIALOGUES)
files.update(penance_palace3.DIALOGUES)
files.update(penance_palace4.DIALOGUES)
files.update(penance_palace5.DIALOGUES)
files.update(penance_palace6.DIALOGUES)
files.update(penance_palace7.DIALOGUES)
knight_quests.inject(files)
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
signs.update(penance_palace.SIGNS)
signs.update(penance_palace2.SIGNS)
signs.update(penance_palace3.SIGNS)
signs.update(penance_palace4.SIGNS)
signs.update(penance_palace5.SIGNS)
signs.update(penance_palace7.SIGNS)
signs.update(drain.SIGNS)
signs.update(drill.SIGNS)
signs.update(inspect.SIGNS)
signs.update(knight_quests.SIGNS)
signs_path.write_text(json.dumps(signs, ensure_ascii=False, indent="\t") + "\n")

# 七日赎罪主线委托的 CG（tools/art/import_cg.py --after 生成 assets/cg/portraits/after_<任务>_ok / _fail.png；gen_cgs.py 登记立绘 id）：
#   失败小剧场：最后一次换上 defeat_2 的那一步（高潮）改成这张大图（没写 defeat_2 的取六成处）；
#   收尾过场：六成处的台词前用 cg 动作换上大图（横版大框，挠痒贴片 / 抖动跟着），最后一步收回。
AFTER_CG_FAIL = {"after_fail_equip": "after_equip_fail", "after_fail_potion": "after_potion_fail", "after_fail_cart": "after_cart_fail",
                 "after_fail_drain": "after_drain_fail", "after_fail_drill": "after_drill_fail", "after_fail_tailor": "after_tailor_fail",
                 "after_fail_mine": "after_mine_fail", "after_fail_inspect": "after_inspect_fail", "after_fail_totem": "after_totem_fail",
                 # 骑士 Boss 的战败 CG（KNIGHT_CG，import_cg.py --knight）
                 "knight_fail_boss": "knight_fail_1", "knight_fail_boss_2": "knight_fail_2", "knight_fail_boss_3": "knight_fail_3", "knight_fail_fog": "knight_fail_fog",
                 # 反省篇第一章：反省牢房·功能拘束挠痒床（PENANCE_CG，import_cg.py --penance）
                 "penance_bed": "penance_bed",
                 # 反省篇第二章：鼠洞的竖井（PENANCE_CG）
                 "tunnel_shaft": "tunnel_shaft", "tunnel_revenge": "tunnel_revenge", "tunnel_rat_king_fail": "rat_king_fail", "palace_badge_party": "badge_party",
                 "bath_scrub_grab": "scrub_grab", "servants_tasting": "tasting_punish", "training_shade": "shade_training",
                 "servants_massage": "massage_chair", "ante_ball_fail": "ball_fail",
                 # 反省篇第三章：水闸守门人（PENANCE_CG）
                 "keeper_fail": "keeper_fail",
                 # 反省篇第四章（上）：温泉 / 帘子后面（PENANCE_CG）
                 "bath_friendship": "bath_friendship", "servants_hide": "servants_hide",
                 # 第四章（中）：衣帽间的两张
                 "wardrobe_tryon": "wardrobe_tryon", "wardrobe_trap_in": "wardrobe_trap",
                 # 第四章（下）
                 "clock_gear_ride": "gear_ride", "tunnel_toll": "toll_pay", "tunnel_quilt": "bedroom_quilt",
                 "throne_painting_trapped": "painting_trapped", "throne_fail": "boss_fail",
                 "throne_fail_paint": "boss_fail_paint", "throne_fail_tea": "boss_fail_tea", "throne_fail_frame": "boss_fail_frame"}
AFTER_CG_DONE = {"after_d2_equip_done": "after_equip_ok", "after_d3_potion_done": "after_potion_ok", "after_d3_cart_done": "after_cart_ok",
                 "after_d4_drain_done": "after_drain_ok", "after_d4_drill_done": "after_drill_ok", "after_d5_tailor_done": "after_tailor_ok",
                 "after_d5_mine_done": "after_mine_ok", "after_d6_inspect_done": "after_inspect_ok", "after_d6_drill_done": "after_exam_ok",
                 "after_d7_totem_done": "after_totem_ok"}


def _with_h2(data):
    """小剧场的精灵进入失控二（POLISH_RULES）：CG 大图那一步（portrait 换成 CG / 标了 cg）台上公主都换 helpless_2；
    魔力释放（act = burst，被抖的那位换战损憋笑魔力释放）以后，那位下一次被挠时换回 helpless_2。这一步自己写了 pose 的不动。"""
    cast = data.get("cast", {})
    princesses = [w for w, c in cast.items() if str(c.get("kind", "")) == "princess" or str(c.get("kind", "")) in ("npc:blue_princess", "npc:pink_princess")]
    if not princesses:
        return data
    pending = set()
    for st in data.get("steps", []):
        acts = st.setdefault("actions", [])
        posed = {a.get("who") for a in acts if a.get("do") == "pose"}
        pt = str(st.get("portrait", ""))
        if st.get("cg") or pt.startswith(("knight_fail", "after_", "siege_fail")):
            for w in princesses:
                if w not in posed:
                    acts.append({"do": "pose", "who": w, "visual": "helpless_2"})
                    posed.add(w)
        if st.get("act") == "burst":
            for a in acts:
                if a.get("do") == "shake" and a.get("who") in princesses:
                    pending.add(a.get("who"))
            continue
        for a in list(acts):
            w = a.get("who")
            if a.get("do") == "tickle" and w in pending and w not in posed:
                acts.append({"do": "pose", "who": w, "visual": "helpless_2"})
                posed.add(w)
                pending.discard(w)
        if not acts:
            st.pop("actions")
    return data


def _with_voice(data):
    """小剧场的笑声（POLISH_RULES）：换成失控一 / 失控二的那一步补 voice laugh、换成憋笑的补 voice giggle（这一步自己写了 voice 就不动）；
    魔力释放那一步（act = burst）也是大笑。只往上切，结尾的 voice "" 照旧。运行时 CGPlayer._auto_voice 是同样规则的兜底。"""
    rank = {"": 0, "giggle": 1, "laugh": 2}
    cur = ""
    for st in data.get("steps", []):
        acts = st.get("actions", [])
        if any(a.get("do") == "voice" for a in acts):
            cur = next(str(a.get("state", "")) for a in acts if a.get("do") == "voice")
            continue
        want = ""
        for a in acts:
            if a.get("do") == "pose":
                v = str(a.get("visual", ""))
                if v.startswith("helpless"):
                    want = "laugh"
                elif v in ("giggle", "damaged_giggle") and want == "":
                    want = "giggle"
        if st.get("act") == "burst":
            want = "laugh"
        if rank.get(want, 0) > rank.get(cur, 0):
            st.setdefault("actions", []).append({"do": "voice", "state": want})
            cur = want
    return data


def _with_fail_cg(tid, data):
    key = AFTER_CG_FAIL.get(tid)
    if not key:
        return data
    steps = data["steps"]
    # 文本里标了 "cg": True 的那步优先（加长版：CG 前约 10 句、CG 后约 20 句，释放后立绘不再换回 defeat_2）
    marked = [i for i, st in enumerate(steps) if st.pop("cg", False)]
    hits = [i for i, st in enumerate(steps) if st.get("portrait") == "defeat_2"]
    if marked:
        steps[marked[0]]["portrait"] = key
    elif hits:
        steps[hits[-1]]["portrait"] = key
    else:
        texts = [i for i, st in enumerate(steps) if st.get("text")]
        steps[texts[int(len(texts) * 0.6)]]["portrait"] = key
    return data


def _with_done_cg(cid, data):
    key = AFTER_CG_DONE.get(cid)
    if not key:
        return data
    steps = data["steps"]
    texts = [i for i, st in enumerate(steps) if st.get("text")]
    at = texts[min(len(texts) - 1, int(len(texts) * 0.6))]
    steps[at].setdefault("actions", []).insert(0, {"do": "cg", "key": key})
    steps.append({"actions": [{"do": "cg", "key": ""}], "wait": 0.1})
    return data


cut = Path("data/cutscenes/floor_06")
CUTS = dict(d1.CUTSCENES, **d2.CUTSCENES, **tasks.CUTSCENES, **potion.CUTSCENES, **tailor.CUTSCENES, **mine.CUTSCENES, **totem.CUTSCENES, **drain.CUTSCENES, **drill.CUTSCENES, **inspect.CUTSCENES, **festival_night.CUTSCENES, **knight_story.CUTSCENES, **knight_finale.CUTSCENES, **knight_quests.CUTSCENES, **knight_story_cg.CUTSCENES, **penance_argue.CUTSCENES, **penance_cell.CUTSCENES, **penance_tunnel.CUTSCENES, **penance_meet.CUTSCENES, **penance_waterway.CUTSCENES, **penance_palace.CUTSCENES, **penance_palace2.CUTSCENES, **penance_palace3.CUTSCENES, **penance_palace5.CUTSCENES, **penance_palace6.CUTSCENES, **penance_palace7.CUTSCENES)
for cid, fn in CUTS.items():
    (cut / (cid + ".json")).write_text(json.dumps(_with_done_cg(cid, done_folk.apply(cid, fn())), ensure_ascii=False, indent="\t") + "\n")
th = Path("data/theater/after")
th.mkdir(parents=True, exist_ok=True)
for tid, data in dict(punish.THEATERS, **tasks.THEATERS, **potion.THEATERS, **tailor.THEATERS, **mine.THEATERS, **totem.THEATERS, **drain.THEATERS, **drill.THEATERS, **inspect.THEATERS, **night.THEATERS, **knight_tasks.THEATERS, **knight_finale.THEATERS, **errand_gate_chain.THEATERS, **knight_prison.THEATERS, **penance_cell.THEATERS, **penance_tunnel.THEATERS, **penance_meet.THEATERS, **penance_waterway.THEATERS, **penance_palace.THEATERS, **penance_palace2.THEATERS, **penance_palace3.THEATERS, **penance_palace4.THEATERS, **penance_palace5.THEATERS, **penance_palace6.THEATERS, **penance_palace7.THEATERS).items():
    (th / (tid + ".json")).write_text(json.dumps(_with_voice(_with_h2(_with_fail_cg(tid, data))), ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
NEW = [(TOWN, "地下小镇·战后", "town"), (FESTIVAL, "庆功宴的广场", "town"), (KDAY, "地下小镇·骑士篇（白天）", "town"),
       (KNIGHT_N, "地下小镇·骑士篇（夜里）", "town"), (KCHASE, "地下小镇·骑士篇（诅咒失控）", "town"), (KFOG, "笑雾之中", "knight_fog"), (HOUSE, "蓝色小屋·战后", "town"), (HOUSE_UP, "蓝色小屋·战后（楼上）", "night_room"),
       (PHARMACY, "药剂师工房", "town"), (FIELD, "城门外的战场", "town"), (TAILOR, "裁缝铺", "town"), (MINE, "受损的矿道", "town"), (TOTEM, "图腾柱废地", "town"), (DRAIN, "排水管", "town"), (DRILL, "队长的训练室", "town"), (PROVING, "保卫队训练营", "town"),
       (PRISON, "保卫队的地牢", "night_room"), (CELLAR, "药剂师工房的地窖", "night_room"),
       (ALLEY, "没有灯的小巷", "night_room"), (HERBCAVE, "草药洞", "night_room"),
       (WALL, "城墙上", "night_room"), (CRACK, "广场底下的裂缝", "night_room"), (OLDHALL, "旧会堂", "night_room"),
       (WAREHOUSE, "旧仓库", "night_room"), (STORAGE, "储物间", "night_room"), (BRIDGE, "排水渠上的小桥", "night_room"),
       (PTENT, "保卫队营地·医务帐篷", "night_room"), (PCELL, "反省牢房", "dungeon"),
       (RTUNNEL, "鼠洞", "dungeon"), (WEXIT, "废弃水道的出口", "dungeon"), (WATERWAY, "废弃水道", "dungeon"),
       (PBATH, "旧王宫·旧浴场", "old_palace"), (PSERV, "旧王宫·仆人回廊", "old_palace"), (PKITCH, "旧王宫·厨房", "old_palace"),
       (PLIB, "旧王宫·图书馆", "old_palace"), (PWARD, "旧王宫·衣帽间", "old_palace"), (PTRAIN, "旧王宫·骑士训练场", "old_palace"),
       (PANTE, "旧王宫·王座前厅", "old_palace"),
       *[(f, "旧王宫·钟楼" + n, "old_palace") for f, n in zip(PCLOCKS, ["一层", "二层", "三层", "四层", "钟顶"])], (PTUN, "旧王宫·隧道与密室", "old_palace"),
       (PTHRONE, "旧王宫·王座间", "palace_boss"), (PGARDEN, "旧王宫·后花园", "old_palace")]
# 已经拆掉的地图（单张钟楼 → 五层）从楼层表里删掉
GONE = ["floor_06_palace_clock"]
lst[:] = [f for f in lst if f["id"] not in GONE]
at = next(i for i, f in enumerate(lst) if f["id"] == "floor_06_siege") + 1
for fid, name, music in NEW:
    old = next((f for f in lst if f["id"] == fid), None)
    if old is None:
        lst.insert(at, {"id": fid, "name": name, "scene": "res://levels/%s/floor.tscn" % fid, "group": "floor_06", "music": music})
    else:
        old["name"] = name     # 已有的条目也跟着改（以前只加不改：换配乐没生效）
        old["music"] = music
    at += 1
Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("对话 %d 个文件、过场 %d 段、小剧场 %d 段" % (len(files), len(CUTS), len(punish.THEATERS)))
