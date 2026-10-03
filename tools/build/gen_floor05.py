"""生成第五层「机关迷城」：levels/floor_05/map.txt、dialogues.json、design.json。

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

# ================================================================ R4 束缚工坊（连锁①）
room(52, 52, 82, 73)
for x in (56, 64, 72, 80):
    torch(x, 51)
sign(64, 72, "sign5_snare")
sign(66, 72, "sign5_teaser")
# 倒吊绳套 + 往左的传送带 → 弹弹床 → 举手铐柱（机关腰腋刑：左墙羽毛臂 + 上方机关手 + 逗弄器）
put(58, 70, "trap type=snare group=w0")
put(53, 70, "trap type=bounce dir=up len=8")
sign(57, 66, "sign5_cuffs")
put(53, 62, "trap type=cuffs group=w1 + plate target=hw1")
put(51, 62, "walltrap type=arm dir=right len=2")
wall(53, 61)
put(53, 61, "walltrap type=hand group=hw1")
put(54, 64, "trap type=teaser group=w1")
combo_areas.append({"combo": "machine_armpit", "rect": [51, 60, 56, 64]})
# → 传送带往右 → 弹弹床往上 → 挠痒衣柜（衣柜里外：鼠洞 + 史莱姆）
put(59, 62, "trap type=bounce dir=up len=10")
sign(61, 55, "sign5_wardrobe")
put(59, 51, "walltrap type=wardrobe")
put(56, 54, "nest type=rat")
put(62, 53, "monster type=slime")
combo_areas.append({"combo": "wardrobe_inout", "rect": [54, 51, 64, 57]})
chains.append({"name": "束缚工坊", "start": [65, 73], "goal": [79, 49], "links": [[58, 70], [53, 62], [59, 52]]})
# 触手囚笼：倒吊绳套上定时落下触手笼
put(70, 58, "trap type=snare group=w2 + trap type=cage content=tentacle idle_time=3.0")
combo_areas.append({"combo": "tentacle_cage", "rect": [66, 55, 74, 61]})
# 倒吊扫荡：右墙羽毛臂 + 旋转刷
put(81, 66, "trap type=snare group=w3")
put(83, 66, "walltrap type=arm dir=left len=2")
put(80, 67, "trap type=brush speed=1.5")
combo_areas.append({"combo": "snare_sweep", "rect": [78, 63, 82, 69]})
# 小工匠踩怪物压力板，对准公主的羽毛雨
put(68, 64, "monster type=imp")
put(72, 62, "plate target=w4 by_monsters=true")
put(66, 60, "trap type=shower group=w4 aim=true")
put(75, 70, "monster type=rat")
# 仰卧肚脐刑：仰卧刑床 + 肚脐羽毛钻（同组）+ 长舌蛙
sign(74, 63, "sign5_supine")
sign(75, 63, "sign5_drill")
sign(76, 63, "sign5_frog")
put(77, 56, "trap type=supine group=s1")
put(78, 55, "trap type=teaser group=s1 content=drill")
put(79, 58, "monster type=frog")
combo_areas.append({"combo": "supine_navel", "rect": [75, 53, 81, 60]})
# 铐柱吸盘：举手铐柱旁的转轮（同组 w1）+ 吸盘章鱼宝宝
sign(58, 66, "sign5_octopus")
put(55, 61, "trap type=wheel group=w1")
put(56, 59, "monster type=octopus")
combo_areas.append({"combo": "cuffs_suction", "rect": [51, 58, 57, 64]})
room(78, 48, 80, 51)

# ================================================================ R4b 滑梯坡道（连锁⑥，从束缚工坊西墙进去）
room(48, 66, 51, 67)
room(20, 54, 47, 71)
for x in (26, 36, 44):
    torch(x, 53)
sign(52, 65, "sign5_chute")
sign(46, 63, "sign5_prone")
sign(46, 70, "sign5_squirrel")
sign(44, 61, "sign5_cushion")
# 往左的滑梯 → 俯卧刑凳（转轮 + 刷尾松鼠：俯卧全套）→ 往上的滑梯 → 痒痒坐垫 → 往左的滑梯 → 仰卧刑床（+ 肚脐羽毛钻）
put(41, 66, "trap type=prone group=p1 + trap type=chute w=4 dir=left")
put(42, 68, "trap type=wheel group=p1")
put(38, 69, "monster type=squirrel")
combo_areas.append({"combo": "prone_full", "rect": [36, 63, 45, 70]})
put(40, 60, "trap type=cushion + trap type=chute h=7 dir=up")
put(34, 59, "trap type=supine group=s2 + trap type=chute w=7 dir=left")
put(34, 58, "trap type=teaser group=s2 content=drill")
chains.append({"name": "滑梯坡道", "start": [47, 66], "goal": [22, 57], "links": [[41, 66], [40, 60], [34, 59]]})
put(28, 64, "trap type=chute w=5 dir=right")
put(21, 56, "chest item=heart")
put(20, 71, "item id=mint")
put(47, 54, "barrel")

# ================================================================ R5 检查点
room(76, 40, 88, 47)
put(82, 45, "checkpoint")
for x in (79, 85):
    torch(x, 39)
put(88, 47, "barrel")
put(87, 41, "item id=mint")
room(68, 42, 75, 44)
sign(72, 42, "sign5_clamp")

# ================================================================ R6 腿刑长廊（连锁②）
room(44, 34, 67, 48)
for x in (48, 56, 64):
    torch(x, 33)
# 夹腿枷台 + 往左的传送带 → 痒痒泥沼 → 吸痒漩涡（中心是单腿吊环）
put(63, 41, "trap type=clamp group=k1 + trap type=conveyor dir=left len=6")
put(63, 39, "trap type=teaser group=k1")
put(64, 43, "trap type=wheel group=k1")
combo_areas.append({"combo": "thigh_torture", "rect": [58, 38, 67, 46]})
sign(61, 46, "sign5_mud")
put(55, 39, "trap type=mud w=3 h=5")
put(52, 36, "nest type=rat")
put(52, 47, "monster type=slime")
combo_areas.append({"combo": "mud_sink", "rect": [48, 34, 60, 48]})
sign(58, 47, "sign5_legloop")
put(53, 41, "trap type=legloop group=l1 + trap type=vortex radius=4")
put(53, 44, "trap type=wheel group=l1")
put(48, 38, "nest type=rat")
combo_areas.append({"combo": "one_leg_show", "rect": [47, 36, 58, 46]})
# 新部位：毛毛虫、上墙的掸子墙、痒痒坐垫
sign(66, 40, "sign5_caterpillar")
put(60, 36, "monster type=caterpillar")
put(58, 33, "walltrap type=duster dir=down len=4")
put(47, 46, "trap type=cushion")
sign(44, 39, "sign5_vest")
chains.append({"name": "腿刑长廊", "start": [67, 43], "goal": [43, 41], "links": [[63, 41], [57, 41], [53, 41]]})
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

# ================================================================ R9 转轮工坊（连锁③）
room(37, 16, 57, 30)
for x in (41, 49):
    torch(x, 15)
# 夹腿枷台（转轮 + 逗弄器）+ 往右的传送带 → 弹弹床 → 举手铐柱（羽毛雨 + 小精灵：腋下羽毛雨）
put(40, 28, "trap type=clamp group=k2 + trap type=conveyor dir=right len=7")
put(40, 26, "trap type=wheel group=k2")
put(41, 30, "trap type=teaser group=k2 content=brush")
put(47, 28, "trap type=bounce dir=up len=8")
put(47, 20, "trap type=cuffs group=c3 + trap type=shower group=c3")
put(49, 22, "monster type=fairy")
chains.append({"name": "转轮工坊", "start": [37, 27], "goal": [58, 23], "links": [[40, 28], [47, 20]]})
# 绊线 + 对准公主的史莱姆笼（整高，冲刺跳过）
put(52, 16, "trap type=tripwire tiles_w=15 vertical=true targets=c9")
put(54, 21, "trap type=cage group=c9 aim=true content=slime")
put(55, 27, "trap type=cage group=c9 aim=true")
put(44, 17, "monster type=imp")
put(45, 16, "plate target=c9 by_monsters=true")
room(58, 22, 60, 24)

# ================================================================ R10 泥沼地窖（连锁④）
room(61, 14, 79, 30)
for x in (65, 75):
    torch(x, 13)
# 痒痒泥沼（风扇吹过）→ 单腿吊环 + 往上的传送带 → 挠痒衣柜
put(62, 22, "trap type=fan dir=right len=8 push_speed=60.0")
put(63, 20, "trap type=mud w=4 h=5")
put(71, 22, "trap type=legloop group=l2 + trap type=conveyor dir=up len=8")
put(73, 23, "trap type=wheel group=l2")
put(71, 13, "walltrap type=wardrobe")
put(75, 25, "nest type=rat")
put(66, 28, "monster type=slime")
put(77, 17, "monster type=rat")
put(76, 28, "trap type=pit content=slime")
put(68, 16, "monster type=barnacle")
chains.append({"name": "泥沼地窖", "start": [61, 27], "goal": [80, 22], "links": [[64, 22], [71, 22], [71, 14]]})
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


# ================================================================ 五个大房间改成迷宫
# 房间里只留 2–3 个「小厅」（三来源组合陷阱），其余铺满墙，再用固定种子挖出 2 格宽的走廊迷宫（有岔路、死胡同、少量回环）；
# 石碑、门口和单独留下的机关格保持畅通，挖完后把和入口不连通的空地接到迷宫上。
MAZE_ROOMS = []


def _flood(start, x0, y0, x1, y1):
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in seen and x0 <= n[0] <= x1 and y0 <= n[1] <= y1 and g[n[1]][n[0]] != "#":
                seen.add(n)
                stack.append(n)
    return seen


def maze_room(name, x0, y0, x1, y1, halls, keep, doors, seed):
    saved = [row[:] for row in g]
    rng = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "#"
    nodes = [(x, y) for y in range(y0, y1, 3) for x in range(x0, x1, 3) if x + 1 <= x1 and y + 1 <= y1]
    nset = set(nodes)
    for (x, y) in nodes:
        for i in (0, 1):
            for j in (0, 1):
                g[y + j][x + i] = "."

    def link(a, b):
        (ax, ay), (bx, by) = a, b
        if ay == by:
            for j in (0, 1):
                g[ay + j][min(ax, bx) + 2] = "."
        else:
            for i in (0, 1):
                g[min(ay, by) + 2][ax + i] = "."

    def nbrs(n):
        return [m for m in ((n[0] + 3, n[1]), (n[0] - 3, n[1]), (n[0], n[1] + 3), (n[0], n[1] - 3)) if m in nset]

    start = nodes[rng.randrange(len(nodes))]
    seen = {start}
    stack = [start]
    while stack:
        cur = stack[-1]
        options = [m for m in nbrs(cur) if m not in seen]
        if not options:
            stack.pop()
            continue
        nxt = rng.choice(options)
        link(cur, nxt)
        seen.add(nxt)
        stack.append(nxt)
    for n in nodes:  # 少量回环
        if rng.random() < 0.12:
            link(n, rng.choice(nbrs(n)))
    # 小厅、单独留下的格子、门口：恢复原样
    for (a, b, c, d) in halls:
        for y in range(b, d + 1):
            for x in range(a, c + 1):
                g[y][x] = saved[y][x]
    for (x, y) in list(keep) + list(doors):
        g[y][x] = saved[y][x] if saved[y][x] != "#" else "."
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if x0 <= nx <= x1 and y0 <= ny <= y1 and g[ny][nx] == "#" and saved[ny][nx] == ".":
                g[ny][nx] = "."
    # 不连通的空地接到入口所在的连通块上
    for _ in range(200):
        reach = _flood(doors[0], x0, y0, x1, y1)
        lost = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if g[y][x] != "#" and (x, y) not in reach]
        if not lost:
            break
        c = lost[0]
        r = min(reach, key=lambda p: abs(p[0] - c[0]) + abs(p[1] - c[1]))
        x, y = c
        while x != r[0]:
            x += 1 if r[0] > x else -1
            if g[y][x] == "#":
                g[y][x] = "."
        while y != r[1]:
            y += 1 if r[1] > y else -1
            if g[y][x] == "#":
                g[y][x] = "."
    MAZE_ROOMS.append({"name": name, "rect": [x0, y0, x1, y1], "halls": [list(h) for h in halls]})


# 束缚工坊：铐柱小厅（机关腰腋刑）、衣柜小厅（衣柜里外）、刑床小厅（仰卧肚脐刑）；入口旁留一个倒吊绳套，开场过场里的小工匠留在原处
maze_room("束缚工坊", 52, 52, 82, 73,
          halls=[(52, 59, 57, 64), (55, 52, 63, 56), (75, 54, 80, 59)],
          keep=[(58, 70), (64, 72), (66, 72), (57, 66), (58, 66), (61, 55), (74, 63), (75, 63), (76, 63), (52, 65), (68, 64)],
          doors=[(65, 73), (64, 73), (66, 73), (79, 52), (78, 52), (80, 52), (52, 66), (52, 67)], seed=51)
# 滑梯坡道：滑梯连锁小厅（俯卧全套）、宝箱小厅（黏黏输送带）
maze_room("滑梯坡道", 20, 54, 47, 71,
          halls=[(40, 65, 45, 69), (39, 58, 41, 66), (33, 57, 41, 60), (37, 68, 39, 70), (20, 54, 26, 59)],
          keep=[(46, 63), (46, 70), (44, 61)],
          doors=[(47, 66), (47, 67)], seed=52)
put(25, 57, "trap type=conveyor dir=left len=3")
put(22, 57, "trap type=carpet w=1 h=2")
put(24, 59, "monster type=crab")
combo_areas.append({"combo": "sticky_belt", "rect": [20, 54, 27, 60]})
# 腿刑长廊：夹腿枷台小厅（夹腿痒刑）、泥沼和吊环的大厅（泥沼深陷 + 单脚示众）
maze_room("腿刑长廊", 44, 34, 67, 48,
          halls=[(58, 40, 64, 43), (52, 38, 57, 44)],
          keep=[(61, 46), (58, 47), (66, 40), (60, 36), (44, 39), (52, 47), (48, 38), (52, 36), (63, 39), (64, 43)],
          doors=[(67, 42), (67, 43), (67, 44), (44, 40), (44, 41), (44, 42)], seed=53)
# 转轮工坊：夹腿枷台小厅（夹腿痒刑）、铐柱小厅（腋下羽毛雨）；绊线和落笼留在原处
maze_room("转轮工坊", 37, 16, 57, 30,
          halls=[(39, 26, 46, 30), (44, 17, 50, 22)],
          keep=[(52, 16), (54, 21), (55, 27), (45, 16)],
          doors=[(37, 26), (37, 27), (37, 28), (57, 22), (57, 23), (57, 24)], seed=54)
combo_areas.append({"combo": "thigh_torture", "rect": [38, 25, 46, 30]})
combo_areas.append({"combo": "armpit_rain", "rect": [43, 16, 51, 23]})
# 泥沼地窖：泥沼小厅（泥沼深陷）、吊环小厅（单脚示众，传送带往上送进衣柜）、触手笼小厅（触手囚笼）
maze_room("泥沼地窖", 61, 14, 79, 30,
          halls=[(62, 20, 67, 24), (70, 15, 73, 24), (73, 26, 77, 29)],
          keep=[(75, 25), (62, 25), (67, 25)],
          doors=[(61, 22), (61, 23), (61, 24), (79, 21), (79, 22), (79, 23)], seed=55)
put(62, 26, "monster type=rat")
put(67, 26, "monster type=slime")
put(73, 27, "trap type=pit content=slime")
put(75, 28, "trap type=snare group=t10 + trap type=cage content=tentacle idle_time=3.0")
combo_areas.append({"combo": "mud_sink", "rect": [61, 19, 68, 27]})
combo_areas.append({"combo": "one_leg_show", "rect": [69, 14, 75, 26]})
combo_areas.append({"combo": "tentacle_cage", "rect": [72, 26, 78, 29]})
# 迷宫房间里原来的连锁和组合区域：只留还在小厅里的
combo_areas[:] = [a for a in combo_areas if a["combo"] not in ("tentacle_cage", "snare_sweep", "cuffs_suction") or a["rect"] == [72, 26, 78, 29]]
chains[:] = [c for c in chains if c["name"] in ("最终连锁长廊", "滑梯坡道")]
for c in chains:
    if c["name"] == "滑梯坡道":
        c["goal"] = [24, 55]


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


def place_signs():
    start = next((x, y) for y in range(H) for x in range(W) if g[y][x] == "P")
    for sid, keys in SIGN_MECH.items():
        ch = specs.get("sign dialogue=" + sid)
        if ch:
            for y in range(H):
                for x in range(W):
                    if g[y][x] == ch:
                        g[y][x] = "."
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
        for gap in SIGN_GAP:
            if gap >= len(path):
                continue
            x, y = path[gap]
            # 石碑是实心的：只放在周围至少 3 格是空地的地方（不堵 1 格宽的路）
            open_n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[y + dy][x + dx] == ".")
            if g[y][x] == "." and open_n >= 3 and not any(g[y + j][x + i] in ("P",) for i in (-1, 0, 1) for j in (-1, 0, 1)):
                put(x, y, "sign dialogue=" + sid)
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
              "chains：连锁段——start→goal 存在不碰静态束缚 / 位移陷阱的路（可躲）；links 依次是束缚陷阱的格子，从前一个放开后按强制位移（传送带、弹弹床、风扇、漩涡）会被送进下一个。",
              "trap_room：无解房间里的三来源组合区域（combos，同 combo_areas）和滑梯圈（loop：拐角的束缚陷阱，前一个放开后会被送进下一个）。",
              "safe_rooms / min_trap_density：除了这些安全房间和迷宫房间，地面格里离陷阱 ≤ 2 格的比例至少 min_trap_density（堆满陷阱）。",
              "maze_rooms：改成迷宫的房间 {name, rect, halls}：halls 是放三来源组合的小厅，其余是 2 格宽的走廊迷宫。"],
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
(out / "dialogues.json").write_text(json.dumps(D, ensure_ascii=False, indent="\t") + "\n")
print("第五层：%dx%d，图例 %d 种，组合区域 %d，连锁 %d" % (W, H, len(specs), len(combo_areas), len(chains)))
for y, r in enumerate(g):
    print("%2d %s" % (y, "".join(r)))
