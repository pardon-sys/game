"""生成第五层「机关迷城」：levels/floor_05/map.txt、dialogues.json、design.json。

陷阱为主、怪物为辅；五段「环环相扣」的连锁（中了一个束缚陷阱，放开后被传送带 / 弹弹床 / 风扇 / 漩涡送进下一个），
每段连锁都留着一条不碰束缚陷阱的路（看准落笼影子、冲刺跳过绊线才能走过去）。
图例字符由 E(spec) 自动分配（同一个 spec 用同一个字符；同一格叠放多个实体用 " + " 连接）。
design.json 给 tests/level_design_test.gd 用：combo_areas（三来源组合的区域）、chains（连锁段）。
用法：python tools/build/gen_floor05.py，然后 build_level.gd -- floor=floor_05
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
W, H = 100, 90
g = [["#"] * W for _ in range(H)]
# 字符不够用时用希腊字母和汉字（构建器按字符索引地图，Unicode 也可以）
POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ") + list("甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
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
for (x, y, off) in ((23, 80, 0.0), (23, 83, 1.2), (26, 81, 0.6), (26, 84, 1.8), (29, 79, 0.3), (29, 82, 1.5)):
    put(x, y, CAGE % off)
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
put(58, 70, "trap type=snare group=w0 + trap type=conveyor dir=left len=5")
put(53, 70, "trap type=bounce dir=up len=8")
sign(57, 66, "sign5_cuffs")
put(53, 62, "trap type=cuffs group=w1 + plate target=hw1 + trap type=conveyor dir=right len=6")
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
room(78, 48, 80, 51)

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
chains.append({"name": "最终连锁长廊", "start": [58, 4], "goal": [23, 7], "links": [[56, 7], [45, 7], [40, 7], [35, 7]]})
room(20, 6, 23, 8)

# ================================================================ R14 准备间（自动获得被动）
room(14, 3, 19, 11)
put(16, 9, "checkpoint")
torch(16, 2)
put(17, 7, "trigger dialogue=prep_passive w=3 h=3")
sign(18, 4, "sign5_trap_room")
put(19, 11, "barrel")

# ================================================================ R15 无解陷阱房
room(12, 6, 13, 8)
for y in (6, 7, 8):
    put(13, y, "gate group=trap_room is_open=true")
room(2, 2, 11, 12)
for x in (5, 9):
    torch(x, 1)
put(6, 7, "traproom group=trap_room w=8 h=9 cutscene=f5_ending")
ROOM_TRAPS = [
    (10, 7, "trap type=snare group=tr1"), (10, 5, "trap type=cuffs group=tr2 + trap type=shower group=tr2"),
    (10, 9, "trap type=clamp group=tr3"), (9, 6, "trap type=teaser group=tr2"), (9, 8, "trap type=wheel group=tr3"),
    (8, 7, "trap type=legloop group=tr4 + trap type=vortex radius=3"), (8, 4, "trap type=cuffs group=tr5"),
    (8, 10, "trap type=snare group=tr6"), (7, 5, "trap type=teaser group=tr5 content=tentacle"),
    (7, 9, "trap type=teaser group=tr6 content=slime"), (5, 3, "trap type=mud w=3 h=2"), (5, 11, "trap type=mud w=3 h=2"),
    (4, 7, "trap type=clamp group=tr7"), (5, 7, "trap type=wheel group=tr7"), (3, 5, "trap type=snare group=tr8"),
    (3, 9, "trap type=cuffs group=tr9"), (6, 6, "trap type=cage idle_time=2.0 offset=0.4"),
    (6, 8, "trap type=cage idle_time=2.2 offset=1.3 content=tentacle"), (2, 7, "trap type=binding group=tr10"),
]
for (x, y, spec) in ROOM_TRAPS:
    put(x, y, spec)

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
              "chains：连锁段——start→goal 存在不碰静态束缚 / 位移陷阱的路（可躲）；links 依次是束缚陷阱的格子，从前一个放开后按强制位移（传送带、弹弹床、风扇、漩涡）会被送进下一个。"],
    "combo_areas": combo_areas,
    "chains": chains,
}, ensure_ascii=False, indent="\t") + "\n")

S, G = "石碑", "公主"
D = {
    "sign5_zones": [
        {"speaker": S, "text": "【机关迷城】这一层几乎全是机关。机关小工匠们把每个机关都连在一起——中了一个，就会被送进下一个。"},
        {"speaker": S, "text": "【部位与弱点】每一下挠痒都会落在某个部位：脚心、腋下、腰、脖子、大腿，各部位敏感程度不同。\n被束缚机关困住时，露出来的部位挠起来更痒（头上会跳「弱点！」），同一个部位被连续挠也会越来越敏感。"},
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
}
(out / "dialogues.json").write_text(json.dumps(D, ensure_ascii=False, indent="\t") + "\n")
print("第五层：%dx%d，图例 %d 种，组合区域 %d，连锁 %d" % (W, H, len(specs), len(combo_areas), len(chains)))
for y, r in enumerate(g):
    print("%2d %s" % (y, "".join(r)))
