"""生成第五层「机关迷城」：levels/floor_05/map.txt、design.json 和 data/dialogues/floor_05/（signs.json、story.json）。

陷阱为主、怪物为辅；五段「环环相扣」的连锁（中了一个束缚陷阱，放开后被传送带 / 弹弹床 / 风扇 / 漩涡送进下一个），
每段连锁都留着一条不碰束缚陷阱的路（看准落笼影子、冲刺跳过绊线才能走过去）。
新部位（肚子 / 屁股 / 胸）的怪物和陷阱分散在各区，束缚工坊西边另有一段「滑梯坡道」（连锁⑥：滑梯 → 俯卧刑凳 → 滑梯 → 痒痒坐垫 → 滑梯 → 仰卧刑床）。
图例字符由 E(spec) 自动分配（同一个 spec 用同一个字符；同一格叠放多个实体用 " + " 连接）。
design.json 给 tests/level_design_test.gd 用：combo_areas（三来源组合的区域）、chains（连锁段）。
用法：python tools/build/gen_floor05.py，然后 build_level.gd -- floor=floor_05
"""
import json
import os
import random
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
W, H = 100, 90
g = [["#"] * W for _ in range(H)]
# 字符不够用时用希腊字母和汉字（构建器按字符索引地图，Unicode 也可以）
POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ") + list("甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
POOL += list("风花雪云雨雷电天人口手足心目耳鼻舌身春夏秋冬东南西北左右中多少高低长短")
FIXED = {"player": "P", "checkpoint": "x", "torch lit=true": "t", "barrel": "B"}
specs = {}


def E(spec):
    if spec in FIXED:
        return FIXED[spec]
    if spec not in specs:
        specs[spec] = POOL.pop(0)
    return specs[spec]


def room(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "."


def put(x, y, spec):
    g[y][x] = E(spec)


def wall(x, y):
    g[y][x] = "#"


def sign(x, y, sid):
    put(x, y, "sign dialogue=" + sid)


def torch(x, y):
    assert g[y][x] == "#", (x, y)
    put(x, y, "torch lit=true")


CAGE = "trap type=cage idle_time=2.4 offset=%s"
combo_areas = []
chains = []

# ================================================================ R1 落脚点
room(3, 77, 16, 87)
put(9, 85, "player")
put(6, 80, "checkpoint")
for x in (6, 12):
    torch(x, 76)
put(3, 87, "barrel")
put(16, 87, "barrel")
put(15, 86, "item id=mint")
sign(5, 78, "sign5_zones")
sign(15, 79, "sign5_cage")
room(17, 80, 19, 82)

# ================================================================ R2 落笼回廊（节奏段 + 绊线 + 小工匠 + 果冻囚笼）
room(20, 79, 56, 85)
for x in (24, 32, 40, 48):
    torch(x, 78)
for (x, y, off) in ((23, 80, 0.0), (26, 81, 0.6), (29, 84, 1.8)):  # Cage_23_80 / Cage_26_81 在开场过场里
    put(x, y, CAGE % off)
# 落笼之间的空档换成羽毛陷阱和粉雾
put(23, 83, "trap type=feather")
put(26, 84, "trap type=vent idle_time=2.0 cloud_duration=1.2 offset=0.6")
put(29, 81, "trap type=feather")
sign(31, 81, "sign5_tripwire")
put(33, 79, "trap type=tripwire tiles_w=7 vertical=true targets=c2a")
put(36, 82, "trap type=cage group=c2a aim=true")
put(38, 80, "trap type=cage group=c2a aim=true")
sign(37, 84, "sign5_imp")
put(43, 82, "monster type=imp")
put(42, 79, "plate target=c2a by_monsters=true")
put(45, 84, "trap type=cage group=c2a aim=true")
# 果冻囚笼：绊线 → 对准公主的史莱姆笼，地上的诅咒符文（下面两行留空）
put(47, 79, "trap type=tripwire tiles_w=7 vertical=true targets=c2b")
put(49, 82, "trap type=cage group=c2b aim=true content=slime")
put(52, 80, "trap type=cage group=c2b aim=true content=slime")
for y in range(79, 84):
    put(50, y, "trap type=rune")
put(54, 80, "nest type=slime")
put(53, 84, "monster type=slime")
combo_areas.append({"combo": "jelly_cage", "rect": [46, 79, 56, 85]})
# 新部位：藤壶贝（吸附）、下墙的掸子墙、洞里住着挠脚鼠的落穴洞
sign(21, 79, "sign5_barnacle")
put(31, 79, "monster type=barnacle")
put(41, 84, "monster type=barnacle")
sign(20, 85, "sign5_duster")
put(28, 86, "walltrap type=duster dir=up len=4")
sign(35, 85, "sign5_pit")
put(39, 84, "trap type=pit content=rat")
room(57, 81, 59, 83)

# ================================================================ R3 检查点
room(60, 78, 70, 86)
put(64, 84, "checkpoint")
for x in (61, 69):
    torch(x, 77)
put(69, 85, "item id=heart")
put(60, 86, "barrel")
room(64, 74, 66, 77)

# ================================================================ R4 束缚工坊（迷宫，见下面的 maze_room）
room(52, 52, 82, 73)
for x in (56, 64, 72, 80):
    torch(x, 51)
room(78, 48, 80, 51)

# ================================================================ R4b 滑梯坡道（迷宫支线，从束缚工坊西墙进去，尽头是宝箱）
room(48, 66, 51, 67)
room(20, 54, 47, 71)
for x in (26, 36, 44):
    torch(x, 53)

# ================================================================ R5 检查点
room(76, 40, 88, 47)
put(82, 45, "checkpoint")
for x in (79, 85):
    torch(x, 39)
put(88, 47, "barrel")
put(87, 41, "item id=mint")
room(68, 42, 75, 44)
sign(72, 42, "sign5_clamp")

# ================================================================ R6 腿刑长廊（迷宫）
room(44, 34, 67, 48)
for x in (48, 56, 64):
    torch(x, 33)
room(40, 40, 43, 42)

# ================================================================ R7 小精灵温室（锁门战斗房①）
room(22, 34, 39, 48)
for x in (26, 34):
    torch(x, 33)
for y in (40, 41, 42):
    put(40, y, "gate group=arena_f5a is_open=true")
put(30, 41, "arena group=arena_f5a w=14 h=11")
put(28, 37, "trap type=cuffs group=a1 + trap type=shower group=a1")
put(29, 37, "trap type=teaser group=a1")
put(25, 40, "monster type=glove pair=g51")
put(31, 40, "monster type=glove pair=g51")
put(27, 44, "monster type=fairy")
put(35, 45, "nest type=fairy")
put(34, 38, "trap type=snare group=a2")
put(36, 36, "nest type=rat")
put(33, 42, "monster type=crab")
put(24, 46, "monster type=crab")
put(38, 47, "item id=heart")
# 蛙舌松尾（刷尾松鼠 + 长舌蛙 + 小精灵）、背心毛毛虫（羽毛背心 + 毛毛虫 + 小精灵）
put(37, 41, "monster type=squirrel")
put(24, 43, "monster type=frog")
put(37, 43, "trap type=vest")
put(29, 47, "monster type=caterpillar")
for x in (28, 29, 30):
    put(x, 33, "gate group=arena_f5a is_open=true")
room(28, 30, 30, 32)

# ================================================================ R8 检查点
room(24, 25, 34, 29)
put(29, 27, "checkpoint")
for x in (26, 32):
    torch(x, 24)
put(24, 29, "barrel")
room(35, 26, 36, 28)

# ================================================================ R9 转轮工坊（迷宫）
room(37, 16, 57, 30)
for x in (41, 49):
    torch(x, 15)
room(58, 22, 60, 24)

# ================================================================ R10 泥沼地窖（迷宫）
room(61, 14, 79, 30)
for x in (65, 75):
    torch(x, 13)
room(80, 21, 80, 23)

# ================================================================ R11 检查点
room(81, 18, 90, 26)
put(85, 22, "checkpoint")
for x in (83, 88):
    torch(x, 17)
put(90, 26, "barrel")
put(89, 25, "item id=mint")
room(84, 12, 86, 17)
sign(84, 16, "sign5_boots")

# ================================================================ R12 工匠车间（锁门战斗房②）
room(60, 2, 92, 11)
for x in (66, 76, 88):
    torch(x, 1)
for x in (84, 85, 86):
    put(x, 12, "gate group=arena_f5b is_open=true")
put(76, 6, "arena group=arena_f5b w=30 h=8")
sign(87, 10, "sign5_binding")
put(82, 9, "trap type=boots group=b1")
put(83, 8, "trap type=teaser group=b1")
put(79, 9, "trap type=binding group=bd1 + trap type=shower group=bd1")
put(76, 10, "monster type=fairy")
put(80, 4, "monster type=fairy")
put(90, 3, "nest type=fairy")
for (x, y) in ((70, 8), (78, 4), (88, 8)):
    put(x, y, "monster type=imp")
put(73, 3, "plate target=sh12 by_monsters=true")
put(68, 6, "trap type=shower group=sh12 aim=true")
put(84, 4, "trap type=shower group=sh12 aim=true content=brush")
put(64, 9, "chest item=heart")
# 吸附大集合：章鱼宝宝 + 毛毛虫 + 藤壶贝；刷尾松鼠
put(74, 7, "monster type=octopus")
put(86, 6, "monster type=caterpillar")
put(62, 4, "monster type=barnacle")
put(70, 4, "monster type=squirrel")
for y in (6, 7, 8):
    put(59, y, "gate group=arena_f5b is_open=true")

# ================================================================ R13 最终连锁长廊（连锁⑤：倒吊 → 夹腿 → 泥沼 → 吊环）
room(24, 4, 58, 9)
for x in (30, 42, 52):
    torch(x, 3)
put(56, 7, "trap type=snare group=f1 + trap type=conveyor dir=left len=6")
put(56, 3, "walltrap type=arm dir=down len=4")
put(55, 8, "trap type=brush speed=1.6")
put(50, 7, "trap type=bounce dir=left len=5")
put(45, 7, "trap type=clamp group=f2 + trap type=conveyor dir=left len=4")
put(41, 7, "trap type=fan dir=left len=6 push_speed=60.0")
put(45, 5, "trap type=teaser group=f2")
put(46, 9, "trap type=wheel group=f2")
put(37, 5, "trap type=mud w=4 h=4")
put(38, 9, "nest type=rat")
put(34, 9, "monster type=slime")
put(35, 7, "trap type=legloop group=f3")
put(32, 9, "trap type=wheel group=f3")
# 张臂大转盘：张臂转盘（甩进下面的夹腿枷台）+ 上墙的羽毛臂 + 章鱼宝宝；洞里住着小触手的落穴洞
sign(57, 4, "sign5_spinwheel")
put(45, 4, "trap type=spinwheel dir=down fling=3")
put(45, 3, "walltrap type=arm dir=down len=2")
put(48, 5, "monster type=octopus")
combo_areas.append({"combo": "spin_suction", "rect": [43, 3, 50, 8]})
put(27, 4, "trap type=pit content=tentacle")
chains.append({"name": "最终连锁长廊", "start": [58, 4], "goal": [23, 7], "links": [[56, 7], [45, 7], [40, 7], [35, 7]]})
room(20, 6, 23, 8)

# ================================================================ R14 准备间（自动获得被动）
room(14, 3, 19, 11)
put(16, 9, "checkpoint")
torch(16, 2)
put(17, 7, "trigger dialogue=prep_passive w=3 h=3")
sign(18, 4, "sign5_trap_room")
put(19, 11, "barrel")

# ================================================================ R15 无解陷阱房（三来源组合房）
# 进门的上半部分是一簇簇三来源组合（结局过场用到的 Snare_10_7 / Cuffs_10_5 / Legloop_8_7 / Teaser_9_6 / Wheel_9_8 / Cage_6_6 位置不变），
# 束缚陷阱下面的传送带把人一个接一个往下送：铐柱 → 绳套 → 吊环 → 夹腿枷台也送进吊环 → 往下进滑梯圈；
# 下半部分是一圈首尾相接的滑梯，四个拐角各一个束缚陷阱：放开后接着滑进下一个，一圈一圈停不下来。
room(12, 6, 13, 8)
for y in (6, 7, 8):
    put(13, y, "gate group=trap_room is_open=true")
room(2, 2, 11, 22)
for x in (5, 9):
    torch(x, 1)
for y in (12, 18):
    torch(12, y)
put(6, 12, "traproom group=trap_room w=10 h=21 cutscene=f5_ending")
ROOM_TRAPS = [
    # 倒吊扫荡：倒吊绳套 + 上墙羽毛臂 + 旋转刷
    (10, 7, "trap type=snare group=tr1 + trap type=conveyor dir=left len=2"), (10, 1, "walltrap type=arm dir=down len=6"),
    (11, 8, "trap type=brush speed=1.5"),
    # 腋下羽毛雨：举手铐柱 + 喷口 + 小精灵（精灵花）
    (10, 5, "trap type=cuffs group=tr2 + trap type=shower group=tr2 + trap type=conveyor dir=down len=2"), (9, 6, "trap type=teaser group=tr2"),
    (8, 3, "monster type=fairy"),
    # 单脚示众：单腿吊环（漩涡中心）+ 转轮 + 挠脚鼠
    (8, 7, "trap type=legloop group=tr4 + trap type=conveyor dir=down len=6"), (9, 8, "trap type=wheel group=tr4"), (6, 10, "monster type=rat"), (7, 11, "monster type=rat"),
    (6, 6, "trap type=cage idle_time=2.6 offset=0.4"),
    # 张臂大转盘：张臂转盘（甩下去）+ 上墙羽毛臂 + 章鱼宝宝
    (6, 2, "trap type=spinwheel dir=down fling=3"), (6, 1, "walltrap type=arm dir=down len=2"), (4, 4, "monster type=octopus"),
    # 夹腿痒刑：夹腿枷台 + 逗弄器 + 转轮
    (4, 7, "trap type=clamp group=tr7 + trap type=conveyor dir=right len=4"), (5, 8, "trap type=wheel group=tr7"), (4, 6, "trap type=teaser group=tr7"),
    # 泥沼深陷：泥沼 + 挠脚鼠 + 史莱姆（房里不放巢穴：免得被拖进巢穴）
    (3, 9, "trap type=mud w=3 h=2"), (2, 11, "monster type=slime"),
    (3, 4, "trap type=snare group=tr8"), (10, 10, "trap type=pit content=rat"),
    # 下半部分：一圈滑梯（上边往右 → 右边往下 → 下边往左 → 左边往上），拐角的束缚陷阱
    (3, 13, "trap type=chute w=7 dir=right"),
    (9, 13, "trap type=supine group=tr6"), (9, 12, "trap type=teaser group=tr6 content=drill"), (7, 15, "monster type=frog"),
    (10, 13, "trap type=chute h=8 dir=down"),
    (10, 20, "trap type=cuffs group=tr9"), (11, 20, "trap type=wheel group=tr9"), (8, 18, "monster type=octopus"),
    (4, 21, "trap type=prone group=tr11 + trap type=chute w=7 dir=left"), (4, 22, "trap type=wheel group=tr11"), (7, 20, "monster type=squirrel"),
    (3, 14, "trap type=clamp group=tr12 + trap type=chute h=8 dir=up"), (2, 14, "trap type=teaser group=tr12"), (2, 16, "trap type=wheel group=tr12"),
    # 圈里：吸附大集合（章鱼宝宝 + 毛毛虫 + 藤壶贝）、落穴洞
    (6, 16, "monster type=caterpillar"), (6, 14, "monster type=barnacle"), (5, 18, "trap type=pit content=tentacle"),
    (9, 16, "monster type=frog"),
    (6, 19, "trap type=feather"), (2, 19, "trap type=binding group=tr10"),
]
for (x, y, spec) in ROOM_TRAPS:
    if spec.startswith("walltrap"):
        assert g[y][x] == "#", (x, y)
    put(x, y, spec)
TRAP_ROOM_COMBOS = [
    ("snare_sweep", [9, 1, 12, 9]), ("armpit_rain", [7, 2, 11, 7]), ("one_leg_show", [5, 5, 10, 11]),
    ("spin_suction", [3, 1, 8, 5]), ("thigh_torture", [2, 5, 6, 8]), ("mud_sink", [2, 8, 8, 12]),
    ("supine_navel", [6, 11, 11, 16]), ("cuffs_suction", [7, 16, 11, 21]), ("prone_full", [2, 17, 9, 22]),
    ("latch_party", [4, 13, 9, 20]),
]
trap_room = {"combos": [{"combo": c, "rect": r} for c, r in TRAP_ROOM_COMBOS],
             "loop": [[10, 5], [10, 7], [8, 7], [9, 13], [10, 20], [4, 21], [3, 14], [9, 13]],
             "feeds": [[4, 7], [8, 7]]}


# ================================================================ 五个大房间：树形迷宫 + 必经连锁小厅
# 每个房间铺满墙，在 3 格网格上挖 2 格宽的走廊迷宫，迷宫是一棵树：从入口到出口只有一条主路（主干）。
# 主干中间是一串「连锁小厅」（5x5，每间一组三来源组合）：小厅的出口角上是束缚陷阱（多一格触发范围，2 格宽的出口一定会中，
# 躲不开），束缚陷阱上的传送带在放开后把人送到下一个小厅的束缚陷阱旁边——一个接一个连着触发。
# 其余的格子长成挂在主干上的死胡同（最深的尽头放宝箱）；主干上零散放单个陷阱和怪物；有的房间主干上还有一组走廊组合。
MAZE_ROOMS = []
HALL_CELLS = set()      # 连锁小厅的「车道」格（主路那 2 格宽，石碑不放这里；小厅里侧可以放）
GROUP_N = [0]


def _gid(prefix):
    GROUP_N[0] += 1
    return "%s%d" % (prefix, GROUP_N[0])


DIRS = {(1, 0): "right", (-1, 0): "left", (0, 1): "down", (0, -1): "up"}


# 小厅模板（小厅自己的坐标：lx 沿着流向 0..4，ly 0..1 是主路那 2 格宽的「车道」，2..4 是里侧；ly = -1 是车道外侧的墙）。
# 束缚陷阱固定在出口角 (4, 0)；返回 [(lx, ly, spec)]，"{F}" 换成流向、"{S}" 换成从墙指向小厅里面的方向。
def hall_specs(kind, G):
    R = (4, 0)
    if kind == "thigh_torture":
        return [(4, 0, "trap type=clamp group=%s" % G), (3, 2, "trap type=teaser group=%s" % G), (4, 2, "trap type=wheel group=%s" % G)]
    if kind == "mud_sink":
        return [("rect", 3, 0, 2, 2, "trap type=mud w={W} h={H}"), (0, 4, "nest type=rat"), (2, 3, "monster type=slime")]
    if kind == "one_leg_show":
        return [(4, 0, "trap type=legloop group=%s" % G), (3, 2, "trap type=wheel group=%s" % G), (1, 3, "monster type=rat"), (2, 4, "monster type=rat")]
    if kind == "supine_navel":
        return [(4, 0, "trap type=supine group=%s" % G), (3, 2, "trap type=teaser group=%s content=drill" % G), (1, 3, "monster type=frog")]
    if kind == "wardrobe_inout":
        return [(4, -1, "walltrap type=wardrobe"), (0, 4, "nest type=rat"), (2, 3, "monster type=slime")]
    if kind == "machine_armpit":
        return [(4, 0, "trap type=cuffs group=%s + plate target=h%s" % (G, G)), (4, -1, "walltrap type=hand group=h%s" % G),
                (2, -1, "walltrap type=arm dir={S} len=2")]
    if kind == "armpit_rain":
        return [(4, 0, "trap type=cuffs group=%s + trap type=shower group=%s" % (G, G)), (1, 3, "monster type=fairy")]
    if kind == "prone_full":
        return [(4, 0, "trap type=prone group=%s" % G), (3, 2, "trap type=wheel group=%s" % G), (1, 3, "monster type=squirrel")]
    if kind == "sticky_belt":
        return [("rect", 3, 0, 2, 2, "trap type=carpet w={W} h={H}"), (1, 0, "trap type=conveyor dir={F} len=2"), (1, 3, "monster type=crab")]
    raise KeyError(kind)


RESTRAINT_WORDS = ("type=clamp", "type=mud", "type=legloop", "type=supine", "type=wardrobe", "type=cuffs", "type=prone", "type=snare")


def maze_room(name, rect, door_in, door_out, combos, seed, side_doors=(), corridor_combo=None, singles=(), monsters=(),
              chests=("item=heart",), axis="x", lane=0, side=1, start=0, flow=1, keep=()):
    """rect：房间矩形；door_in / door_out：门口的格子（door_out = None 表示支线，主路尽头放宝箱）；
    combos：连锁小厅的组合（2~3 个，按流向排）；axis / lane / side / start / flow：小厅串的摆法
    （axis 沿 x 或 y 排；lane 主路所在的网格行 / 列；side = ±1 小厅里侧在哪边；start 入口节点的序号；flow = ±1 流向）。"""
    x0, y0, x1, y1 = rect
    rng = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "#"
    ni = [i for i in range(0, 99) if x0 + 3 * i + 1 <= x1]
    nj = [j for j in range(0, 99) if y0 + 3 * j + 1 <= y1]
    nodes = {(i, j) for i in ni for j in nj}

    def cell(n):
        return (x0 + 3 * n[0], y0 + 3 * n[1])

    def carve_node(n):
        x, y = cell(n)
        for a in (0, 1):
            for b in (0, 1):
                g[y + b][x + a] = "."

    def link(a, b):
        carve_node(a)
        carve_node(b)
        (ax, ay), (bx, by) = cell(a), cell(b)
        if ay == by:
            for k in (0, 1):
                g[ay + k][min(ax, bx) + 2] = "."
        else:
            for k in (0, 1):
                g[min(ay, by) + 2][ax + k] = "."

    def nbrs(n):
        return [m for m in ((n[0] + 1, n[1]), (n[0] - 1, n[1]), (n[0], n[1] + 1), (n[0], n[1] - 1)) if m in nodes]

    def node_of(c):
        return min(nodes, key=lambda n: abs(cell(n)[0] + 0.5 - c[0]) + abs(cell(n)[1] + 0.5 - c[1]))

    def touches(n, cells):
        nx, ny = cell(n)
        return any(abs(cx - (nx + a)) + abs(cy - (ny + b)) <= 1 for (cx, cy) in cells for a in (0, 1) for b in (0, 1))

    def door_node(cells, toward=None):
        # 小厅串两头的节点挨着门口就用它（门直接接上主路）；否则在挨着门口的节点里挑离 toward 最近的
        for n in (E, X):
            if touches(n, cells):
                return n
        cand = [n for n in nodes if touches(n, cells)]
        if cand and toward is not None:
            tx, ty = cell(toward)
            return min(cand, key=lambda n: abs(cell(n)[0] - tx) + abs(cell(n)[1] - ty))
        cx = sum(c[0] for c in cells) / len(cells)
        cy = sum(c[1] for c in cells) / len(cells)
        return min(cand or nodes, key=lambda n: abs(cell(n)[0] + 0.5 - cx) + abs(cell(n)[1] + 0.5 - cy))

    def N(along, across):
        return (along, across) if axis == "x" else (across, along)

    # —— 连锁小厅 ——
    K = len(combos)
    E = N(start, lane)
    X = N(start + flow * (1 + 2 * K), lane)
    halls = []
    reserved = set()
    for k in range(K):
        a1 = start + flow * (1 + 2 * k)
        a2 = a1 + flow
        hn = [N(a1, lane), N(a2, lane), N(a1, lane + side), N(a2, lane + side)]
        assert all(h in nodes for h in hn), (name, k, hn)
        reserved.update(hn)
        halls.append(hn)
    assert E in nodes and X in nodes, (name, E, X)
    F = (1, 0) if axis == "x" else (0, 1)
    F = (F[0] * flow, F[1] * flow)
    S = (0, side) if axis == "x" else (side, 0)
    hall_rects = []
    links = []
    acc = {}

    def add(c, spec):
        acc.setdefault(c, []).append(spec)

    for k, hn in enumerate(halls):
        for a, b in ((hn[0], hn[1]), (hn[2], hn[3]), (hn[0], hn[2]), (hn[1], hn[3])):
            link(a, b)
        xs = [cell(h)[0] + d for h in hn for d in (0, 1)]
        ys = [cell(h)[1] + d for h in hn for d in (0, 1)]
        hx0, hx1, hy0, hy1 = min(xs), max(xs), min(ys), max(ys)
        for y in range(hy0, hy1 + 1):
            for x in range(hx0, hx1 + 1):
                g[y][x] = "."
        hall_rects.append([hx0, hy0, hx1, hy1])
        lx_c, ly_c = cell(hn[0])
        ox = lx_c if F[0] >= 0 else lx_c + 1
        oy = ly_c if F[1] >= 0 else ly_c + 1
        if axis == "x":
            oy = ly_c if side > 0 else ly_c + 1
        else:
            ox = lx_c if side > 0 else lx_c + 1

        def W(lx, ly):
            return (ox + lx * F[0] + ly * S[0], oy + lx * F[1] + ly * S[1])

        for lx in range(-1, 6):
            for ly in (0, 1):
                HALL_CELLS.add(W(lx, ly))
        G = _gid("m")
        for item in hall_specs(combos[k], G):
            if item[0] == "rect":
                _, lx, ly, lw, lh, spec = item
                cs = [W(lx + a, ly + b) for a in range(lw) for b in range(lh)]
                tx, ty = min(c[0] for c in cs), min(c[1] for c in cs)
                w = max(c[0] for c in cs) - tx + 1
                h = max(c[1] for c in cs) - ty + 1
                add((tx, ty), spec.replace("{W}", str(w)).replace("{H}", str(h)))
            else:
                lx, ly, spec = item
                add(W(lx, ly), spec.replace("{F}", DIRS[F]).replace("{S}", DIRS[S]))
        rc = W(4, 0)
        if k < K - 1:
            add(rc, "trap type=conveyor dir=%s len=6" % DIRS[F])  # 放开后送到下一个小厅的束缚陷阱旁边
        links.append(list(rc))
        combo_areas.append({"combo": combos[k], "rect": [hx0 - 1, hy0 - 1, hx1 + 1, hy1 + 1]})
    link(E, halls[0][0])
    for k in range(K - 1):
        link(halls[k][1], halls[k + 1][0])
    link(halls[-1][1], X)

    # —— 主干：入口 → E，X → 出口（或支线尽头） ——
    def bfs(src, dst_set, avoid):
        from collections import deque
        prev = {src: None}
        q = deque([src])
        while q:
            c = q.popleft()
            if c in dst_set:
                path = []
                while c is not None:
                    path.append(c)
                    c = prev[c]
                return path[::-1]
            opts = nbrs(c)
            rng.shuffle(opts)
            for m in opts:
                if m not in prev and m not in avoid:
                    prev[m] = c
                    q.append(m)
        return None

    # 门口的格子只能挨着自己那个节点：挨着的其它节点不挖（否则门口会把两条路连成环，绕开小厅）
    door_nodes = {}
    door_nodes[door_node(door_in, E)] = door_in
    if door_out:
        door_nodes[door_node(door_out, X)] = door_out
    for d in side_doors:
        door_nodes[door_node(list(d))] = list(d)
    banned = set()
    for dn, cells in door_nodes.items():
        for n in nodes:
            if n == dn or n in door_nodes:
                continue
            if touches(n, cells):
                banned.add(n)
    assert not (banned & (reserved | {E, X})), (name, "门口挨着小厅")
    n_in = door_node(door_in, E)
    p1 = bfs(n_in, {E}, reserved | {X} | banned)
    assert p1, (name, "入口到小厅")
    used = set(p1) | reserved | {X}
    if door_out:
        n_out = door_node(door_out, X)
        p2 = bfs(X, {n_out}, (used - {X}) | banned)
        assert p2, (name, "小厅到出口")
    else:
        # 支线：从 X 走到离它最远的格子，尽头放宝箱
        from collections import deque
        dist = {X: 0}
        q = deque([X])
        while q:
            c = q.popleft()
            for m in nbrs(c):
                if m not in dist and m not in used and m not in banned:
                    dist[m] = dist[c] + 1
                    q.append(m)
        far = max(dist, key=lambda c: dist[c])
        p2 = bfs(X, {far}, (used - {X}) | banned)
    for path in (p1, p2):
        for a, b in zip(path, path[1:]):
            link(a, b)
    spine = p1 + p2
    seen = set(spine) | reserved | banned

    # —— 分支：挂在主干上的死胡同（树，不连回去） ——
    parent = {}
    stack = list(spine)
    rng.shuffle(stack)
    for s0 in list(stack):
        st = [s0]
        while st:
            c = st[-1]
            opts = [m for m in nbrs(c) if m not in seen]
            if not opts:
                st.pop()
                continue
            m = rng.choice(opts)
            link(c, m)
            parent[m] = c
            seen.add(m)
            st.append(m)

    # —— 门口 ——
    def open_door(cells):
        n = next(dn for dn, cs in door_nodes.items() if cs == list(cells))
        nx, ny = cell(n)
        for (x, y) in cells:
            g[y][x] = "."
            tx = min(max(x, nx), nx + 1)
            ty = min(max(y, ny), ny + 1)
            cx, cy = x, y
            while (cx, cy) != (tx, ty):
                if cx != tx:
                    cx += 1 if tx > cx else -1
                elif cy != ty:
                    cy += 1 if ty > cy else -1
                g[cy][cx] = "."
    open_door(door_in)
    if door_out:
        open_door(door_out)
    for d in side_doors:
        assert next(dn for dn, cs in door_nodes.items() if cs == list(d)) in seen, (name, "侧门没接上")
        open_door(d)

    # —— 宝箱：最深的死胡同尽头（支线的主路尽头也是一个） ——
    depth = {}
    for n in parent:
        d, c = 0, n
        while c in parent:
            c = parent[c]
            d += 1
        depth[n] = d
    leaves = [n for n in parent if not any(parent.get(m) == n for m in parent)]
    leaves.sort(key=lambda n: -depth[n])
    chest_nodes = [] if door_out else [spine[-1]]
    for n in leaves:
        if len(chest_nodes) >= len(chests):
            break
        if n not in chest_nodes:
            chest_nodes.append(n)
    for n, item in zip(chest_nodes, chests):
        x, y = cell(n)
        add((x, y), "chest " + item)

    # —— 主干上的单个陷阱 / 怪物、走廊组合 ——
    body = [n for n in spine if n not in (E, X) and n not in reserved]
    body = body[2:-1] if len(body) > 4 else body
    cc_node = None
    if corridor_combo and body:
        cc_node = body[len(body) // 2]
        x, y = cell(cc_node)
        G = _gid("mc")
        if corridor_combo == "tentacle_cage":
            add((x, y), "trap type=snare group=%s + trap type=cage content=tentacle idle_time=3.0" % G)
            add((x + 1, y + 1), "monster type=rat")
        combo_areas.append({"combo": corridor_combo, "rect": [x - 2, y - 2, x + 3, y + 3]})
    pool = list(singles) + list(monsters)
    for idx, n in enumerate(body):
        if n == cc_node or idx % 2 or not pool:
            continue
        x, y = cell(n)
        add((x + rng.randint(0, 1), y + rng.randint(0, 1)), pool[(idx // 2) % len(pool)])
    for (c, spec) in keep:
        assert g[c[1]][c[0]] == ".", (name, "keep 格没挖开", c)
        add(c, spec)
    for c, sp in acc.items():
        if not sp[0].startswith("walltrap"):
            assert g[c[1]][c[0]] == ".", (name, c, sp)
        put(c[0], c[1], " + ".join(sp))
    MAZE_ROOMS.append({"name": name, "rect": list(rect), "halls": hall_rects, "door_in": list(door_in[0]),
                       "goal": list(door_out[0]) if door_out else list(cell(spine[-1])),
                       "corridor_combo": cc_node is not None})
    chains.append({"name": name, "start": list(door_in[0]), "goal": list(door_out[0]) if door_out else list(cell(spine[-1])),
                   "links": links, "unavoidable": True})
    return {"halls": hall_rects, "links": links, "spine": [cell(n) for n in spine], "branches": [cell(n) for n in parent]}


OLD_SINGLES = ["trap type=feather", "trap type=vent idle_time=2.2 cloud_duration=1.2 offset=0.6", "trap type=cage idle_time=2.4 offset=0.8"]
# 束缚工坊：机关腰腋刑 → 衣柜里外 → 仰卧肚脐刑（小厅串在中间一行，往右流）；从下面的门进、上面的门出；西墙的侧门通滑梯坡道
R4 = maze_room("束缚工坊", (52, 52, 82, 73), door_in=[(64, 73), (65, 73), (66, 73)], door_out=[(78, 52), (79, 52), (80, 52)],
               side_doors=[[(52, 66), (52, 67)]], combos=["machine_armpit", "wardrobe_inout", "supine_navel"],
               axis="x", lane=2, side=1, start=1, flow=1, seed=61,
               singles=OLD_SINGLES, monsters=["monster type=barnacle", "monster type=rat"], chests=("item=heart", "item=mint"))
# 开场过场里的小工匠：放在离第一个小厅最近的分支上
imp_cell = min(R4["branches"], key=lambda c: abs(c[0] - R4["halls"][0][0]) + abs(c[1] - R4["halls"][0][3]))
put(imp_cell[0] + 1, imp_cell[1], "monster type=imp")
# 滑梯坡道（支线）：俯卧全套 → 黏黏输送带（往左流），尽头是宝箱
R4B = maze_room("滑梯坡道", (20, 54, 47, 71), door_in=[(47, 66), (47, 67)], door_out=None,
                combos=["prone_full", "sticky_belt"], axis="x", lane=4, side=-1, start=8, flow=-1, seed=62,
                singles=["trap type=cushion"] + OLD_SINGLES, monsters=["monster type=rat"], chests=("item=heart", "item=mint"))
# 腿刑长廊：夹腿痒刑 → 泥沼深陷 → 单脚示众（往左流，横贯整个房间）
R6 = maze_room("腿刑长廊", (44, 34, 67, 48), door_in=[(67, 42), (67, 43), (67, 44)], door_out=[(44, 40), (44, 41), (44, 42)],
               combos=["thigh_torture", "mud_sink", "one_leg_show"], axis="x", lane=3, side=-1, start=7, flow=-1, seed=63,
               singles=OLD_SINGLES, monsters=["monster type=frog"], chests=("item=mint",))
# 转轮工坊：夹腿痒刑 → 腋下羽毛雨（往右流）
R9 = maze_room("转轮工坊", (37, 16, 57, 30), door_in=[(37, 26), (37, 27), (37, 28)], door_out=[(57, 22), (57, 23), (57, 24)],
               combos=["thigh_torture", "armpit_rain"], axis="x", lane=2, side=1, start=0, flow=1, seed=64,
               singles=OLD_SINGLES + ["trap type=teaser"], monsters=["monster type=caterpillar", "monster type=octopus"],
               chests=("item=heart",))
# 泥沼地窖：泥沼深陷 → 单脚示众（竖着往下流）；主干上还有一组走廊组合「触手囚笼」
R10 = maze_room("泥沼地窖", (61, 14, 79, 30), door_in=[(61, 22), (61, 23), (61, 24)], door_out=[(79, 21), (79, 22), (79, 23)],
                combos=["mud_sink", "one_leg_show"], axis="y", lane=2, side=1, start=0, flow=1, seed=65,
                corridor_combo="tentacle_cage", singles=OLD_SINGLES + ["trap type=wheel"], monsters=["monster type=slime", "monster type=barnacle"],
                chests=("item=heart",))

# 开场过场 f5_intro：镜头扫过落笼回廊、束缚工坊的连锁小厅和小工匠（演员名随迷宫生成）
_h0 = R4["halls"][0]
_imp = "Imp_%d_%d" % (imp_cell[0] + 1, imp_cell[1])
INTRO = {"name": "机关迷城", "skippable": True, "hide_hud": True, "steps": [
    {"actions": [{"do": "camera", "to": [12, 82], "time": 0.6}, {"do": "pose", "emotion": "surprise"}], "wait": 0.6},
    {"speaker": "公主", "emotion": "surprise", "text": "楼梯尽头……又是一层？这里的空气里全是齿轮的声音……"},
    {"actions": [{"do": "camera", "to": [30, 82], "time": 1.4}], "wait": 1.4},
    {"actions": [{"do": "trap", "who": "Cage_23_80", "time": 0.8}, {"do": "trap", "who": "Cage_26_81", "time": 0.8}, {"do": "sfx", "sound": "gate", "pitch": 1.3}],
     "speaker": "公主", "emotion": "sad", "text": "笼、笼子从天花板上掉下来了……地上全是影子……"},
    {"actions": [{"do": "camera", "to": [(_h0[0] + _h0[2]) // 2 + 3, (_h0[1] + _h0[3]) // 2], "time": 1.6}], "wait": 1.6},
    {"actions": [{"do": "trap", "who": "Cuffs_%d_%d" % tuple(R4["links"][0]), "time": 1.0}, {"do": "trap", "who": "Supine_%d_%d" % tuple(R4["links"][2]), "time": 1.0}],
     "speaker": "", "text": "（铐柱、传送带、衣柜、刑床……迷宫的必经之路上，一个机关的出口，正好是下一个机关的入口）"},
    {"actions": [{"do": "camera", "to": [imp_cell[0] + 1, imp_cell[1]], "time": 0.6}, {"do": "say", "who": _imp, "text": "嘿嘿，新客人～"}],
     "speaker": "公主", "emotion": "angry", "text": "那些戴护目镜的小家伙……就是它们在开机关吗！"},
    {"actions": [{"do": "camera", "reset": True, "time": 1.0}], "wait": 1.0},
    {"speaker": "公主", "emotion": "angry", "text": "中了一个就会被一路送下去……可那些小厅是绕不过去的路……只能硬着头皮挣脱了！"},
]}
Path("data/cutscenes/floor_05/f5_intro.json").write_text(json.dumps(INTRO, ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 填满空地
def _free(x, y, r=1):
    return all(0 <= y + j < H and 0 <= x + i < W and g[y + j][x + i] == "." for i in range(-r, r + 1) for j in range(-r, r + 1))


def fill(x0, y0, x1, y1, specs, step=4):
    """在矩形里按交错网格（每 step 格）把空地放上陷阱：周围一格都是空地才放（不贴墙、不挤着别的东西）。"""
    i = 0
    for row, y in enumerate(range(y0, y1 + 1, step)):
        for x in range(x0 + (row % 2) * (step // 2), x1 + 1, step):
            if _free(x, y):
                put(x, y, specs[i % len(specs)])
                i += 1


FEATHER = "trap type=feather"
VENT = "trap type=vent idle_time=2.2 cloud_duration=1.2 offset=%s"
BRUSH = "trap type=brush speed=%s"
OLD = [FEATHER, VENT % "0.0", BRUSH % "1.2", FEATHER, VENT % "1.1", BRUSH % "-1.3"]
# 各区域按第一次出现的顺序只放已经介绍过的机关
fill(23, 35, 38, 47, OLD + ["trap type=wheel", "trap type=teaser"], step=3)              # 小精灵温室
fill(61, 3, 91, 10, OLD + ["trap type=boots", "trap type=wheel"], step=3)                # 工匠车间
fill(21, 79, 55, 85, OLD)                                                        # 落笼回廊


# ================================================================ 新机制石碑自动摆放
# 迷宫让路线变长：每种新机制的石碑放在「从起点到它第一次出现的最短路」上、离它 SIGN_GAP 步的空地上（先拿掉原来的石碑）。
SIGN_MECH = {
    "sign5_cage": ["type=cage"], "sign5_tripwire": ["type=tripwire"], "sign5_imp": ["type=imp"], "sign5_snare": ["type=snare"],
    "sign5_teaser": ["type=teaser", "type=wheel", "type=shower"], "sign5_cuffs": ["type=cuffs"], "sign5_wardrobe": ["type=wardrobe"],
    "sign5_clamp": ["type=clamp"], "sign5_mud": ["type=mud"], "sign5_legloop": ["type=legloop"], "sign5_boots": ["type=boots"],
    "sign5_binding": ["type=binding"], "sign5_barnacle": ["type=barnacle"], "sign5_duster": ["type=duster"], "sign5_pit": ["type=pit"],
    "sign5_supine": ["type=supine"], "sign5_drill": ["content=drill"], "sign5_frog": ["type=frog"], "sign5_octopus": ["type=octopus"],
    "sign5_chute": ["type=chute"], "sign5_prone": ["type=prone"], "sign5_squirrel": ["type=squirrel"], "sign5_cushion": ["type=cushion"],
    "sign5_caterpillar": ["type=caterpillar"], "sign5_vest": ["type=vest"], "sign5_spinwheel": ["type=spinwheel"],
}
SIGN_GAP = (5, 4, 6, 3, 7, 8, 9, 10, 11, 12)


def _spec_of(c):
    for spec, ch in specs.items():
        if ch == c:
            return spec
    return ""


def _blocked(x, y):
    c = g[y][x]
    return c == "#" or c in ("t",) or _spec_of(c).startswith(("walltrap", "torch", "barrel", "sign", "chest", "nest"))


def _bfs(start):
    from collections import deque
    dist, prev = {start: 0}, {start: None}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in dist and g[n[1]][n[0]] != "#":
                dist[n] = dist[(x, y)] + 1
                prev[n] = (x, y)
                q.append(n)
    return dist, prev


def _mech_cells(keys):
    out = []
    for y in range(H):
        for x in range(W):
            spec = _spec_of(g[y][x])
            if not spec:
                continue
            for part in spec.split(" + "):
                if any(k in part for k in keys) and ("walltrap" in part or "trap" in part or "monster" in part):
                    if part.startswith("walltrap"):
                        d = dict(kv.split("=") for kv in part.split()[1:] if "=" in kv)
                        lane = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}[d.get("dir", "down")]
                        out.append((x + lane[0], y + lane[1]))
                    else:
                        d = dict(kv.split("=") for kv in part.split()[1:] if "=" in kv)
                        for i in range(int(d.get("w", 1))):
                            for j in range(int(d.get("h", 1))):
                                out.append((x + i, y + j))
    return out


RESTRAINT_TYPES = ("clamp", "mud", "legloop", "supine", "wardrobe", "cuffs", "prone", "snare", "boots", "binding", "pit", "cushion",
                   "vest", "spinwheel", "stocks")
STEP = {"right": (1, 0), "left": (-1, 0), "down": (0, 1), "up": (0, -1)}


def _hazard_cells():
    """石碑（实心）不能放的格子：陷阱覆盖格、传送带 / 滑梯 / 风扇 / 弹弹床的通道和落点、漩涡范围、束缚陷阱外扩一格的拉人范围。"""
    out = set()
    for y in range(H):
        for x in range(W):
            spec = _spec_of(g[y][x])
            if not spec:
                continue
            for part in spec.split(" + "):
                words = part.split()
                if not words or words[0] not in ("trap", "walltrap"):
                    continue
                d = dict(kv.split("=", 1) for kv in words[1:] if "=" in kv)
                t = d.get("type", "")
                step = STEP.get(d.get("dir", ""), (0, 0))
                cells = set()
                w, h = int(d.get("w", d.get("tiles_w", 1))), int(d.get("h", d.get("tiles_h", 1)))
                if words[0] == "walltrap":
                    sx, sy = step if step != (0, 0) else (0, 1)
                    for i in range(1, int(d.get("len", 1)) + 1):
                        cells.add((x + sx * i, y + sy * i))
                elif t in ("conveyor", "fan"):
                    n = int(d.get("len", 1))
                    for i in range(n + 1):
                        for k in ((-1, 0, 1) if t == "fan" else (0,)):
                            cells.add((x + step[0] * i + step[1] * k, y + step[1] * i + step[0] * k))
                elif t == "bounce":
                    cells.add((x, y))
                    n = int(d.get("len", 1))
                    cells.add((x + step[0] * n, y + step[1] * n))
                elif t == "vortex":
                    r = int(d.get("radius", 2))
                    cells.update((x + i, y + j) for i in range(-r, r + 1) for j in range(-r, r + 1))
                elif t == "tripwire":
                    vertical = d.get("vertical", "false") == "true"
                    for i in range(int(d.get("tiles_w", 1))):
                        cells.add((x, y + i) if vertical else (x + i, y))
                else:
                    cells.update((x + i, y + j) for i in range(w) for j in range(h))
                    if t == "chute":
                        cells.update((cx + step[0], cy + step[1]) for (cx, cy) in list(cells))
                if t in RESTRAINT_TYPES:
                    base = {(x, y + 1)} if words[0] == "walltrap" else set(cells)
                    for (cx, cy) in base:
                        cells.update((cx + i, cy + j) for i in (-1, 0, 1) for j in (-1, 0, 1))
                out |= cells
    return out


def place_signs():
    start = next((x, y) for y in range(H) for x in range(W) if g[y][x] == "P")
    for sid, keys in SIGN_MECH.items():
        ch = specs.get("sign dialogue=" + sid)
        if ch:
            for y in range(H):
                for x in range(W):
                    if g[y][x] == ch:
                        g[y][x] = "."
    haz = _hazard_cells() | HALL_CELLS
    for sid, keys in SIGN_MECH.items():
        dist, prev = _bfs(start)
        cells = [c for c in _mech_cells(keys) if c in dist]
        if not cells:
            continue
        target = min(cells, key=lambda c: dist[c])
        path = []
        c = target
        while c is not None:
            path.append(c)
            c = prev[c]
        done = False
        for gap in SIGN_GAP:
            if gap >= len(path) or done:
                continue
            px, py = path[gap]
            # 路上那一格不行（车道、陷阱上）就试附近两格内的格子（比如连锁小厅的里侧）
            near = sorted(((px + dx, py + dy) for dx in range(-2, 3) for dy in range(-2, 3)), key=lambda c: abs(c[0] - px) + abs(c[1] - py))
            for (x, y) in near:
                if not (0 < x < W - 1 and 0 < y < H - 1) or (x, y) not in dist or dist[(x, y)] >= dist[target]:
                    continue
                # 石碑是实心的：只放在周围至少 3 格是空地的地方（不堵 1 格宽的路）
                open_n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[y + dy][x + dx] == ".")
                if g[y][x] == "." and (x, y) not in haz and open_n >= 3 and not any(g[y + j][x + i] in ("P",) for i in (-1, 0, 1) for j in (-1, 0, 1)):
                    put(x, y, "sign dialogue=" + sid)
                    done = True
                    break


place_signs()


LEVEL = """[level]
# 第五层：机关迷城（tools/build/gen_floor05.py 生成，不要直接改）
intro_cutscene = f5_intro
ambient = 0.36,0.3,0.44

[legend]
# 每行: 字符 = 类型 参数=值 ...（同一格叠放多个实体用 " + " 连接）
# = wall
. = floor
P = player
x = checkpoint
t = torch lit=true
B = barrel
"""
legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
out = Path("levels/floor_05")
out.mkdir(parents=True, exist_ok=True)
(out / "map.txt").write_text(LEVEL + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
(out / "design.json").write_text(json.dumps({
    "_说明": ["第五层的关卡设计数据（tools/build/gen_floor05.py 生成），tests/level_design_test.gd 读取：",
              "combo_areas：三来源组合的区域 [x0, y0, x1, y1]（陷阱覆盖格和怪物 / 巢穴 / 落笼放出的怪物都在区域里）；",
              "chains：连锁段——links 依次是束缚陷阱的格子，从前一个放开后按强制位移（传送带、弹弹床、风扇、漩涡）会被送进下一个；unavoidable = true 的（迷宫里的必经连锁）从 start 到 goal 的每条路都经过束缚陷阱的触发范围（躲不开），其余的存在不碰静态束缚 / 位移陷阱的路（可躲）。",
              "maze_rooms：迷宫房间——树形迷宫，halls 是主路上的连锁小厅（必经），door_in → goal 是主路的两头。",
              "trap_room：无解房间里的三来源组合区域（combos，同 combo_areas）和滑梯圈（loop：拐角的束缚陷阱，前一个放开后会被送进下一个）。",
              "safe_rooms / min_trap_density：除了这些安全房间和迷宫房间，地面格里离陷阱 ≤ 2 格的比例至少 min_trap_density（堆满陷阱）。",
              ],
    "combo_areas": combo_areas,
    "chains": chains,
    "trap_room": trap_room,
    # 检查点房间、落脚点和准备间（不要求堆满陷阱）
    "safe_rooms": [[3, 77, 16, 87], [60, 78, 70, 86], [76, 40, 88, 47], [24, 25, 34, 29], [81, 18, 90, 26], [14, 3, 19, 11]],
    # 改成迷宫的房间（不算陷阱密度；level_design_test 检查墙的比例、小厅里的组合数）
    "maze_rooms": MAZE_ROOMS,
    "min_trap_density": 0.75,
}, ensure_ascii=False, indent="\t") + "\n")

S, G = "石碑", "公主"
D = {
    "sign5_zones": [
        {"speaker": S, "text": "【机关迷城】这一层几乎全是机关。机关小工匠们把每个机关都连在一起——中了一个，就会被送进下一个。"},
        {"speaker": S, "text": "【部位与弱点】每一下挠痒都会落在某个部位：脚心、腋下、腰、脖子、大腿、肚子、屁股、胸，各部位敏感程度不同。\n被束缚机关困住时，露出来的部位挠起来更痒（头上会跳「弱点！」），同一个部位被连续挠也会越来越敏感。"},
        {"speaker": G, "emotion": "sad", "text": "……本公主的脚心，今天一定会很辛苦吧……"},
    ],
    "sign5_cage": [
        {"speaker": S, "text": "【落笼】地上出现影子，过一会儿天花板就会落下笼子罩住那一格。被关住要连按挣脱。\n有的笼子里装着史莱姆、小触手——它们会留在外面继续挠。"},
    ],
    "sign5_tripwire": [
        {"speaker": S, "text": "【绊线】横过走廊的细线。碰到就会让连着的机关对准你发动——怪物碰到也一样！\n冲刺可以直接跳过去。"},
    ],
    "sign5_imp": [
        {"speaker": S, "text": "【机关小工匠】戴护目镜的小家伙。它们自己挠得不重，但会专门跑去踩压力板、碰绊线，还会把你关掉的机关拨回来。\n被打一下就会逃去拉拉杆。看到它们，先打倒！"},
    ],
    "sign5_snare": [
        {"speaker": S, "text": "【倒吊绳套】踩中地上的绳圈会被倒吊起来，脚心朝天（脚心 ×1.5）。\n放开的时候脚下就是传送带……这里的机关都是一个接一个的。"},
    ],
    "sign5_teaser": [
        {"speaker": S, "text": "【配套挠痒机关】羽毛逗弄器、痒痒转轮、羽毛雨喷口会和旁边的束缚机关连在一起：\n有人被困住，逗弄器就专挠露出的部位，转轮一面一面换着挠，喷口落下羽毛雨。不被困住就不会被它们挠。"},
    ],
    "sign5_cuffs": [
        {"speaker": S, "text": "【举手铐柱】走到石柱前会被铐住手腕举过头顶（腋下 ×1.5）。墙上还装着机关手和羽毛臂。"},
    ],
    "sign5_wardrobe": [
        {"speaker": S, "text": "【挠痒衣柜】从衣柜门口走过会被拉进去，只露出两只脚（脚心 ×1.3）。柜里的手挠腰，外面的脚……谁都能挠。"},
    ],
    "sign5_clamp": [
        {"speaker": S, "text": "【夹腿枷台】踩上去两块木板会夹住大腿（大腿 ×1.5），绒毛一直蹭着。\n前面的长廊：夹腿 → 泥沼 → 吊环，一环扣一环。"},
    ],
    "sign5_mud": [
        {"speaker": S, "text": "【痒痒泥沼】走进去会越陷越慢，陷到膝盖就动不了（脚心、大腿 ×1.3）。踩进去马上退出来！"},
    ],
    "sign5_legloop": [
        {"speaker": S, "text": "【单腿吊环】一条腿被吊起来只能单脚跳（脚心、大腿 ×1.3）。这里的吊环下面还有吸痒漩涡……"},
    ],
    "sign5_boots": [
        {"speaker": S, "text": "【痒痒长靴】会动的长靴，走近就自己套到脚上：走不快、不能冲刺，靴子里的羽毛一直挠脚心（脚心 ×1.3）。\n前面是小工匠们的车间。"},
    ],
    "sign5_binding": [
        {"speaker": S, "text": "【羽毛绑腿】一碰就把两条腿缠在一起，只能一蹦一蹦（大腿 ×1.3）。连按攻击键可以挣开。"},
    ],
    "sign5_trap_room": [
        {"speaker": S, "text": "【最后的房间】……门后面的房间，石碑上什么也没写。只有一行被划掉的字：「从来没有人走出来过」。"},
        {"speaker": G, "emotion": "sad", "text": "……都、都到这里了。本公主一定要过去！"},
    ],
    "prep_passive": [
        {"speaker": G, "emotion": "surprise", "text": "……一路被挠过来，好像……身体记住了怎么挣扎了？"},
        {"speaker": "", "text": "【获得被动技能：挣脱强化】连按 J / E 挣扎时，闷笑值会多降一些。（背包「被动技能」页可以查看）", "grant_passive": "struggle_plus"},
        {"speaker": G, "emotion": "angry", "text": "好！最后一个房间——本公主来了！"},
    ],
    "intro": [{"speaker": G, "emotion": "surprise", "text": "这里是……到处都是机关的城……"}],
    "sign5_barnacle": [
        {"speaker": S, "text": "【藤壶贝】地上的小贝壳不会走，但从它旁边经过就会弹到身上粘住，伸出纤毛挠肋骨。\n有东西吸在身上时连按攻击键抖掉，冲刺有机会甩开，满蓄力星光爆发能全部震飞。"},
    ],
    "sign5_duster": [
        {"speaker": S, "text": "【掸子墙】墙里藏着一排鸡毛掸子。贴着墙走过，掸子会从你进来的那一端一个接一个扫过来（屁股、大腿）。\n掸子比走路快，看准它缩回去再冲过去。"},
    ],
    "sign5_pit": [
        {"speaker": S, "text": "【落穴洞】地上的洞。踩中会一屁股坐进去卡住，两条腿翘在外面（屁股 ×1.5、脚心 ×1.3）。\n洞里住着小怪物，会从下面挠——看到洞里的眼睛就绕开。"},
    ],
    "sign5_supine": [
        {"speaker": S, "text": "【仰卧刑床】踩上去会被放倒仰躺、皮带扣住，肚子整个朝上（肚子 ×1.5）。"},
    ],
    "sign5_drill": [
        {"speaker": S, "text": "【肚脐羽毛钻】装在刑床旁边的逗弄器，转着圈的羽毛尖只钻肚子——露出肚子的时候钻肚脐，没露出就挠腰。"},
    ],
    "sign5_frog": [
        {"speaker": S, "text": "【长舌蛙】脸颊红红的绿青蛙。嘴巴鼓起来就是要吐舌头了：舌头直直地伸过来舔肚子，还会把人拉过去。\n看到它鼓嘴就往旁边躲。"},
    ],
    "sign5_octopus": [
        {"speaker": S, "text": "【吸盘章鱼宝宝】会扑上来吸在胸口，小腕绕到肋骨和腋下挠，吸着时走得慢。\n连按攻击键抖 4 下才掉；被铐住的时候它最喜欢凑过来。"},
    ],
    "sign5_chute": [
        {"speaker": S, "text": "【痒痒滑梯】前面的房间里是一段段滑梯：踩上去就会坐着沿箭头一直滑，刷毛一路刷屁股。\n滑梯尽头接着下一个机关，放开后脚下又是滑梯……绕着箭头走！"},
    ],
    "sign5_prone": [
        {"speaker": S, "text": "【俯卧刑凳】被按趴在长凳上、双脚翘起，看不见后面（屁股、脚心 ×1.3）。"},
    ],
    "sign5_squirrel": [
        {"speaker": S, "text": "【刷尾松鼠】跑得很快，专门绕到背后用大尾巴刷屁股，刷完就跳开。\n转身面对它，它就不好下手。"},
    ],
    "sign5_cushion": [
        {"speaker": S, "text": "【痒痒坐垫】软软的坐垫，踩上去会被拉坐下扣住，刷毛在下面来回刷（屁股 ×1.5）。"},
    ],
    "sign5_caterpillar": [
        {"speaker": S, "text": "【毛毛虫】吸在脚上以后会一路往上爬：脚心 → 大腿 → 肋骨 → 锁骨，越往上越痒。\n趁它还在脚上赶快抖下来（3 下）。"},
    ],
    "sign5_vest": [
        {"speaker": S, "text": "【羽毛背心】前面房里地上叠着小背心，一碰就套到身上：走不快、不能冲刺，羽毛一直挠肋骨和锁骨（胸 ×1.3）。\n连按攻击键脱掉。"},
    ],
    "sign5_spinwheel": [
        {"speaker": S, "text": "【张臂转盘】走到转盘前会被扣住手腕、双臂张开（胸 ×1.5、腋下 ×1.3），每转一圈刷子扫一次肋骨。\n放开的时候会被甩出去——下面就是夹腿枷台。"},
    ],
}
# 对话：data/dialogues/floor_05/（石碑 signs.json，其余剧情 story.json）
dlg_dir = Path("data/dialogues/floor_05")
dlg_dir.mkdir(parents=True, exist_ok=True)
(dlg_dir / "signs.json").write_text(json.dumps({k: v for k, v in D.items() if k.startswith("sign")}, ensure_ascii=False, indent="\t") + "\n")
(dlg_dir / "story.json").write_text(json.dumps({k: v for k, v in D.items() if not k.startswith("sign")}, ensure_ascii=False, indent="\t") + "\n")
print("第五层：%dx%d，图例 %d 种，组合区域 %d，连锁 %d" % (W, H, len(specs), len(combo_areas), len(chains)))
for y, r in enumerate(g):
    print("%2d %s" % (y, "".join(r)))
