"""生成第六层「地下小镇」：四张地图 + 人物对话 + 过场 + 小剧场。

地图（levels/floor_06_<层>/map.txt，build_level.gd 构建）：
  floor_06_upper  集市层：集贸市场、篝火派对广场、居民区、存档点、封住的地牢入口、去营地的楼梯
  floor_06_camp   营地层：保卫队营地（帐篷、哨塔、训练场）、去集市 / 地牢 / 矿道的楼梯
  floor_06_prison 营地地牢：开场的刑具房（刑床 + 足枷 + 夹腿枷台 → 挠痒坐垫 + 举手铐柱）、牢房、上楼梯
  floor_06_mine   矿道层：矿道、矿车、矿工、封住的深层入口（以后通往新的地牢）
  floor_06_training 训练迷宫（魔力疲倦释放训练，scripts/training/maze_release.gd）：12 个带门的房间各放一组脚 / 大腿 / 屁股的三来源组合，
                  走廊里有几段堵住的死路；起点和出口都在南边的大厅（levels/floor_06_training/design.json 记录每个房间的组合区域）
对话：data/dialogues/floor_06/<人物>.json（每个人物一个文件）+ signs.json / story.json
过场：data/cutscenes/floor_06/；小剧场：data/theater/floor_06/
选择记忆：开场队长审问时的态度写进变量 f6_attitude（honest 老实解释 / defiant 顶嘴反驳 / beg 笑着求饶），
          之后队长、蓝色公主、市场监督、篝火派对的主人和居民的台词、选项都按它变化。
用法：python tools/build/gen_floor06.py，然后 build_level.gd -- floor=floor_06_upper（等四张）
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
        self.g[y][x] = self.E(spec)

    def torch(self, x, y):
        assert self.g[y][x] == "#", (self.fid, x, y)
        self.put(x, y, "torch lit=true")

    def write(self):
        out = Path("levels") / self.fid
        out.mkdir(parents=True, exist_ok=True)
        legend = "".join("%s = %s\n" % (c, s) for s, c in self.specs.items())
        head = "[level]\n# 第六层·地下小镇（tools/build/gen_floor06.py 生成，不要直接改）\n" + self.header + "\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n"
        (out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in self.g) + "\n")
        print("%s：%dx%d，图例 %d 种" % (self.fid, self.w, self.h, len(self.specs)))


def npc(m, x, y, nid, file, wander=2, extra=""):
    m.put(x, y, ("npc id=%s dialogue=floor_06/%s wander=%s %s" % (nid, file, wander, extra)).strip())


def prop(m, x, y, kind, action=""):
    m.put(x, y, "prop type=%s%s" % (kind, (" action=" + action) if action else ""))


AFTER = "show_flag=f6_opening_done"

# ================================================================ 集市层
up = Map("floor_06_upper", 64, 46, "intro =\nambient = 0.62,0.5,0.44")
up.room(2, 2, 61, 43)
for x in (8, 20, 32, 44, 56):
    up.torch(x, 1)
up.put(57, 38, "player")
up.put(56, 40, "spawn id=from_camp")
up.put(59, 40, "stairs target=floor_06_camp spawn=from_upper down=true")
up.put(54, 37, "sign dialogue=sign6_town")
# 居民区（北边一排房子）
for i, x in enumerate((8, 16, 24, 32)):
    prop(up, x, 8, "house_%d" % i)
    prop(up, x - 2, 10, "flowers")
for x in (12, 20, 28):
    prop(up, x, 11, "lamp")
# 蓝色公主的小屋（居民区东头）：参观小镇的最后一站，进去之后是主角住的楼下
prop(up, 42, 8, "house_blue")
prop(up, 40, 10, "flowers")
prop(up, 44, 10, "flowers")
up.put(42, 9, "exit target=floor_06_house spawn=from_upper unlock_flag=f6_house_open locked_dialogue=sign6_house_locked")
up.put(42, 10, "spawn id=from_house")
# 集贸市场（西边两排摊位）
for row, y in enumerate((19, 26)):
    for i, x in enumerate((7, 11, 15)):
        prop(up, x, y, "stall_%d" % ((i + row) % 3), "shop:market")
for y in (22, 23):
    prop(up, 4, y, "crate")
prop(up, 19, 22, "banner")
up.put(11, 23, "sign dialogue=sign6_market")
# 篝火派对广场（东边）
prop(up, 44, 24, "bonfire_0", "heal")
for (x, y) in ((40, 21), (48, 21), (40, 27), (48, 27)):
    prop(up, x, y, "bench")
for (x, y) in ((37, 24), (51, 24), (44, 19), (44, 30)):
    prop(up, x, y, "lamp")
prop(up, 30, 18, "well")
# 存档点（广场西南）
up.put(30, 30, "savepoint place=集市广场")
# 封住的地牢入口（东北角）
prop(up, 54, 4, "dungeon_gate")
up.put(54, 5, "exit target=floor_06_mine locked=true dialogue=sign6_gate")
for x in (51, 57):
    prop(up, x, 6, "lamp")
# 关键人物
npc(up, 12, 23, "supervisor", "supervisor", 0, AFTER + " dir=down")
npc(up, 46, 24, "bonfire_host", "bonfire_host", 1)
# 蓝色的公主：可操作角色（平时 AI 在下面这些点之间溜达），开场之后才出现
up.put(32, 27, "blue_princess dialogue=floor_06/blue_princess show_flag=f6_opening_done")
for (x, y) in ((30, 25), (14, 22), (44, 28), (33, 18), (20, 12), (40, 36), (26, 33)):
    up.put(x, y, "spot")
# 居民
npc(up, 24, 14, "granny", "granny", 2)
npc(up, 36, 18, "kid", "kid_tom", 4)
npc(up, 38, 33, "kid", "kid_lily", 3)
npc(up, 8, 23, "merchant", "merchant_fruit", 1)
npc(up, 16, 30, "merchant", "merchant_cloth", 2)
npc(up, 26, 37, "maid", "maid", 3)
npc(up, 50, 36, "miner", "miner_old", 2)
npc(up, 40, 12, "guard", "guard_patrol", 6)
npc(up, 20, 33, "granny", "granny_knit", 1)
for (x, y) in ((22, 40), (34, 40), (46, 40)):
    prop(up, x, y, "flowers")
up.write()

# ================================================================ 营地层
camp = Map("floor_06_camp", 50, 34, "intro =\nambient = 0.55,0.48,0.46")
camp.room(2, 2, 47, 31)
for x in (8, 18, 30, 40):
    camp.torch(x, 1)
camp.put(25, 6, "player")
camp.put(25, 4, "spawn id=from_upper")
camp.put(25, 3, "stairs target=floor_06_upper spawn=from_camp down=false")
camp.put(8, 28, "spawn id=from_prison")
camp.put(5, 28, "stairs target=floor_06_prison spawn=from_camp down=true")
camp.put(42, 29, "spawn id=from_mine")
# 训练迷宫的入口（训练场东边；魔力疲倦释放训练的过场走到这里）
prop(camp, 46, 18, "dungeon_gate")
camp.put(46, 20, "spawn id=from_training")
camp.put(45, 29, "stairs target=floor_06_mine spawn=from_camp down=true")
camp.put(23, 8, "sign dialogue=sign6_camp")
for i, x in enumerate((8, 14, 20)):
    prop(camp, x, 7, "tent")
prop(camp, 40, 8, "tower")
prop(camp, 34, 7, "banner")
prop(camp, 16, 7, "banner")
# 指挥帐篷：队长
prop(camp, 26, 13, "tent")
npc(camp, 26, 15, "captain", "captain", 0, AFTER + " dir=down")
# 训练场（东南，栅栏围起来）
for x in range(30, 45):
    prop(camp, x, 17, "fence")
for (x, y) in ((34, 21), (38, 21), (41, 24), (35, 25)):
    prop(camp, x, y, "dummy")
prop(camp, 32, 19, "dummy", "training")
camp.put(31, 21, "sign dialogue=sign6_training")
for (x, y) in ((12, 16), (20, 22), (12, 26), (30, 28)):
    prop(camp, x, y, "crate")
for (x, y) in ((6, 12), (18, 12), (6, 20), (44, 12), (28, 22)):
    prop(camp, x, y, "lamp")
npc(camp, 14, 12, "guard", "guard_rook", 3)
npc(camp, 36, 22, "guard", "guard_moss", 3)
npc(camp, 10, 24, "guard", "guard_fern", 2)
camp.write()

# ================================================================ 营地地牢（开场）
pr = Map("floor_06_prison", 36, 26, "intro =\nintro_cutscene = f6_wake\nambient = 0.42,0.36,0.44")
pr.room(10, 8, 25, 18)      # 刑具房
pr.room(2, 12, 9, 14)       # 去楼梯的走廊
pr.room(4, 2, 31, 5)        # 牢房走廊
pr.room(16, 6, 18, 7)       # 刑具房 ↔ 牢房走廊
for x in (13, 22):
    pr.torch(x, 7)
for x in (6, 15, 24):
    pr.torch(x, 1)
# 牢房走廊两侧的铁栅（关着）
for x in (8, 12, 20, 24, 28):
    pr.put(x, 4, "gate group=cells is_open=false")
pr.put(19, 13, "player")
pr.put(5, 13, "spawn id=from_camp")
pr.put(3, 13, "stairs target=floor_06_camp spawn=from_prison down=false")
# 刑具（只做演出：active=false，不会真的困人）
pr.put(16, 12, "trap type=supine active=false")
pr.put(17, 12, "trap type=stocks active=false")
pr.put(16, 13, "trap type=clamp active=false")
pr.put(21, 15, "trap type=cushion active=false")
pr.put(21, 14, "trap type=cuffs active=false")
pr.put(17, 11, "trap type=teaser active=false")
pr.put(24, 10, "trap type=wheel active=false")
for (x, y) in ((11, 9), (24, 17), (11, 17)):
    pr.put(x, y, "barrel")
pr.put(12, 16, "sign dialogue=sign6_prison")
npc(pr, 22, 9, "guard", "guard_jailer", 1, AFTER)
pr.write()

# ================================================================ 矿道层
mine = Map("floor_06_mine", 48, 32, "intro =\nambient = 0.4,0.36,0.4")
mine.room(2, 22, 20, 29)
mine.room(18, 14, 26, 29)
mine.room(24, 6, 45, 18)
mine.room(6, 6, 22, 12)
mine.room(8, 12, 10, 22)
for x in (6, 14):
    mine.torch(x, 21)
for x in (28, 36, 42):
    mine.torch(x, 5)
mine.put(6, 27, "player")
mine.put(6, 26, "spawn id=from_camp")
mine.put(3, 27, "stairs target=floor_06_camp spawn=from_mine down=false")
# 矿车和木箱：潜入模式里可以躲进去（action=hide，平时按 E 只提示「没必要躲」）
for (x, y) in ((12, 26), (22, 20), (30, 12), (40, 15), (14, 8)):
    prop(mine, x, y, "cart", "hide")
for (x, y) in ((16, 24), (25, 16), (34, 9), (20, 9)):
    prop(mine, x, y, "crate", "hide")
for (x, y) in ((10, 24), (22, 26), (28, 10), (38, 10), (16, 10)):
    prop(mine, x, y, "lamp")
prop(mine, 40, 7, "dungeon_gate")
# 最深处的门：有神秘的钥匙才打开，通往第七层
mine.put(40, 8, "exit target=floor_07 unlock_flag=f6_key locked_dialogue=sign6_deep open_dialogue=f6_gate_open")
npc(mine, 30, 15, "miner", "miner_burr", 3, "hidden_flag=f6_escape")
npc(mine, 14, 26, "miner", "miner_dot", 2, "hidden_flag=f6_escape")
# —— 潜入模式（第二天早上 f6_escape 之后）：巡逻的保卫队员，被看见警觉值就涨，满了被抓（scripts/stealth/）——
mine.put(4, 24, "stealth active_flag=f6_escape on_caught=f6")
for path, extra in (
        ("8,23;17,23", ""),                      # 入口大厅上排来回
        ("15,28;15,25", " wait=1.6"),            # 入口大厅竖着来回
        ("22,28;22,15", ""),                     # 中间竖走廊
        ("26,11;43,11", ""),                     # 北大厅横着来回
        ("33,7;33,17", " wait=1.0"),             # 北大厅竖着来回
        ("38,14;44,14;44,17;38,17", " loop=true"),  # 大门前绕圈
        ("8,8;20,8", ""),                        # 西北的储藏间
        ("30,16;30,15", " wait=3.0"),            # 北大厅入口站岗张望
):
    mine.put(int(path.split(";")[0].split(",")[0]), int(path.split(";")[0].split(",")[1]), "guard_patrol path=" + path + extra)
mine.write()

# ================================================================ 训练迷宫
# 4 列 × 3 行房间（内部 9×8），房间之间是 2 格宽的走廊；每个房间的门在下墙正中，通向下面的横走廊。
# 门一开始关着（按 E 打开）。横 / 竖走廊有几段堵死，走起来要绕。南边的大厅是起点，出口（回营地的楼梯）就在起点旁边。
MAZE_W, MAZE_H = 51, 43
COL_X = [2 + i * 13 for i in range(4)]
ROW_Y = [2 + j * 12 for j in range(3)]
# 每个房间：组合 id、内容 [(相对房间左上角的 dx, dy, 图例)]（dy = -1 是房间的上墙，装墙上的夹腿羽毛钳）
MAZE_ROOMS = [
    ("boots_clamp_crawl", [(4, 5, "trap type=boots"), (4, 3, "trap type=clamp"), (2, 2, "monster type=caterpillar")]),
    ("legloop_lick", [(4, 3, "trap type=legloop"), (2, 2, "monster type=frog"), (6, 2, "monster type=rat")]),
    ("foot_thigh_lock", [(4, 3, "trap type=stocks"), (5, 3, "trap type=clamp"), (2, 2, "monster type=squirrel")]),
    ("pincer_stocks", [(4, -1, "walltrap type=thigh_pincer"), (4, 1, "trap type=stocks"), (2, 3, "monster type=hedgehog")]),
    ("rack_crawl", [(4, -1, "walltrap type=thigh_pincer"), (4, 1, "trap type=foot_thigh_rack"), (6, 3, "monster type=caterpillar")]),
    ("swing_frenzy", [(4, 3, "trap type=feather_swing"), (2, 2, "monster type=squirrel"), (6, 2, "monster type=rat")]),
    ("ring_binding", [(4, 5, "trap type=binding"), (4, 3, "trap type=thigh_brush_ring"), (2, 2, "monster type=fairy")]),
    ("foot_bubble", [(4, 3, "trap type=foot_bath"), (2, 2, "monster type=bubble_fish"), (6, 2, "monster type=slime")]),
    ("bath_trio", [(4, 3, "trap type=sitz_bath"), (2, 2, "monster type=bubble_fish"), (6, 2, "monster type=fairy")]),
    ("spring_feather", [(4, 3, "trap type=spring_seat group=sf1"), (5, 3, "trap type=teaser group=sf1"), (2, 2, "monster type=rat")]),
    ("saddle_brush", [(4, 3, "trap type=saddle_bench"), (2, 2, "monster type=squirrel"), (6, 2, "monster type=caterpillar")]),
    ("scissor_brush", [(4, 3, "trap type=scissor_stand"), (5, 3, "trap type=cushion"), (2, 5, "monster type=hedgehog")]),
]
LEG_TRAP_SIGNS = ["thigh_pincer", "foot_thigh_rack", "feather_swing", "thigh_brush_ring", "foot_bath", "sitz_bath", "spring_seat",
                  "saddle_bench", "scissor_stand"]
maze = Map("floor_06_training", MAZE_W, MAZE_H, "intro =\nambient = 0.45,0.4,0.5")
for j, y0 in enumerate(ROW_Y):
    for i, x0 in enumerate(COL_X):
        maze.room(x0, y0, x0 + 8, y0 + 7)
    maze.room(2, y0 + 9, 49, y0 + 10)            # 横走廊（房间下面）
for x0 in COL_X[:3]:
    maze.room(x0 + 10, 2, x0 + 11, ROW_Y[2] + 10)  # 竖走廊（两列房间之间）
maze.room(2, 38, 49, 41)                           # 南边的大厅
for x in (12, 13, 38, 39):
    maze.g[37][x] = "."                            # 大厅通向迷宫的两个口
# 堵住的走廊段（死路）
for (x, y) in ((16, 11), (16, 12), (29, 23), (29, 24), (22, 35), (22, 36), (25, 30), (26, 30)):
    maze.g[y][x] = "#"
design_areas = []
for n, (combo, items) in enumerate(MAZE_ROOMS):
    x0, y0 = COL_X[n % 4], ROW_Y[n // 4]
    maze.put(x0 + 4, y0 + 8, "door")
    for dx, dy, spec in items:
        maze.put(x0 + dx, y0 + dy, spec)
    maze.torch(x0 + 1, y0 - 1)
    maze.torch(x0 + 7, y0 - 1)
    design_areas.append({"combo": combo, "rect": [x0, y0 - 1, x0 + 8, y0 + 7]})
maze.put(25, 40, "player")
maze.put(25, 39, "spawn id=maze_start")
maze.put(19, 40, "spawn id=maze_exit")
maze.put(18, 40, "stairs target=floor_06_camp spawn=from_training down=false")
maze.put(23, 38, "sign dialogue=sign6_maze")
for k, x in enumerate((3, 5, 7, 9, 41, 43, 45, 47, 30)):
    maze.put(x, 38, "sign dialogue=sign6_trap_" + LEG_TRAP_SIGNS[k])
for x in (6, 20, 32, 45):
    maze.torch(x, 42)


def _maze_reachable(g, start):
    seen, todo = {start}, [start]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c = (x + dx, y + dy)
            if 0 <= c[0] < MAZE_W and 0 <= c[1] < MAZE_H and c not in seen and g[c[1]][c[0]] != "#":
                seen.add(c)
                todo.append(c)
    return seen


_reach = _maze_reachable(maze.g, (25, 40))
for a in design_areas:
    x0, y0 = a["rect"][0], a["rect"][1] + 1
    assert (x0 + 4, y0 + 4) in _reach, ("迷宫房间走不到", a["combo"])
maze.write()
Path("levels/floor_06_training/design.json").write_text(json.dumps({
    "_说明": ["训练迷宫（gen_floor06.py 生成）：combo_areas = 每个房间的三来源组合区域（格，含上墙，左上 → 右下）。",
              "level_design_test 检查区域里有组合需要的陷阱和怪物；training_test 检查 12 个房间都走得到、门都关着。"],
    "combo_areas": design_areas}, ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 人物对话
P = "公主"
ATT = ("honest", "defiant", "beg")


def L(text, who=None, emotion=None):
    """一句台词：who 省略 = 这个人物自己；"P" = 公主；"N" = 旁白；其它字符串 = 那个名字的人。"""
    line = {"text": text}
    if who == "P":
        line["speaker"] = P
    elif who == "N":
        line["speaker"] = ""
    elif who:
        line["speaker"] = who
    if emotion:
        line["emotion"] = emotion
    return line


def by_attitude(prefix):
    """按开场的态度跳到 <prefix>_honest / _defiant / _beg（还没选过 = 老实解释那条）。"""
    return [{"if": {"eq": {"f6_attitude": a}}, "node": "%s_%s" % (prefix, a)} for a in ATT] + [{"node": prefix + "_honest"}]


def att_entries(prefix="hello"):
    return [{"if": {"eq": {"f6_attitude": a}}, "node": "%s_%s" % (prefix, a)} for a in ATT] + [{"node": prefix + "_honest"}]


D = {}

D["captain"] = {
    "name": "保卫队队长", "npc": "captain",
    "entries": [{"if": {"not": "f6_opening_done"}, "node": "opening_question"}] + att_entries(),
    "nodes": {
        # —— 开场：审问（过场 f6_wake 里调用）——
        "opening_question": {"lines": [L("说吧。为什么一个人跑到外面去？")], "prompt": "怎么回答？", "choices": [
            {"text": "老老实实解释：我真的什么都不记得了", "next": "ans_honest", "set": {"vars": {"f6_attitude": "honest"}}},
            {"text": "顶嘴：凭什么一上来就把人锁起来！", "next": "ans_defiant", "set": {"vars": {"f6_attitude": "defiant"}}},
            {"text": "笑着求饶：先、先把羽毛停下来好不好……", "next": "ans_beg", "set": {"vars": {"f6_attitude": "beg"}}}]},
        "ans_honest": {"lines": [
            L("我、我是真的不记得……一睁眼就在一个到处是机关的城里，后来好像被一个黑影带走了……", "P", "sad"),
            L("……黑影？"),
            L("编得倒挺像。矿道口离这儿可不近，你一个人是怎么过去的？")]},
        "ans_defiant": {"lines": [
            L("你们凭什么把人锁起来！我可是公主！放、放开我——哈哈哈！", "P", "angry"),
            L("公主？在这座镇子里，规矩比头衔管用。"),
            L("嘴这么硬……看来得多挠一会儿，你才肯说实话。")]},
        "ans_beg": {"lines": [
            L("哈、哈哈……好啦好啦，我错了还不行嘛……先把羽毛停下来……", "P", "shy"),
            L("……"),
            L("（叹气）笑成这样，倒不像会骗人的样子。——可规矩还是规矩。")]},
        "punish": {"goto": by_attitude("punish")},
        "punish_honest": {"lines": [L("我不信什么突然出现。来人——把她换到坐垫上，让她好好想想，下次还敢不敢一个人乱跑。")]},
        "punish_defiant": {"lines": [L("把她换到坐垫上，手铐起来。你们几个，一起来——挠到她不顶嘴为止。")]},
        "punish_beg": {"lines": [L("……既然这么爱笑，那就让她笑个够。把她换到坐垫上，来人，轻一点——但别停。")]},
        "punish_scene": {"goto": by_attitude("punish_scene")},
        "punish_scene_honest": {"theater": "f6_punish_honest"},
        "punish_scene_defiant": {"theater": "f6_punish_defiant"},
        "punish_scene_beg": {"theater": "f6_punish_beg"},
        # —— 之后在营地 ——
        "hello_honest": {"lines": [L("是你啊。……矿道口的事，我后来又想了想。"), L("你说的那个黑影——要是真的，就不是小事。")], "next": "hub"},
        "hello_defiant": {"lines": [L("……又是你。这回不顶嘴了？"), L("营地里的事别乱碰，有话就说。")], "next": "hub"},
        "hello_beg": {"lines": [L("哦，是那个很爱笑的公主。"), L("别紧张，今天不挠你。……有事吗？")], "next": "hub"},
        "hub": {"prompt": "要聊什么？", "choices": [
            {"text": "营地是做什么的？", "next": "camp", "return": True},
            {"text": "我想变强一点（训练）", "next": "training", "return": True},
            {"text": "那个黑影，你知道些什么？", "next": "shadow", "return": True, "if": {"eq": {"f6_attitude": "honest"}}},
            {"text": "……你还在生气吗？", "next": "still_angry", "return": True, "if": {"eq": {"f6_attitude": "defiant"}}, "once": True},
            {"text": "你好像没那么凶了？", "next": "softer", "return": True, "if": {"eq": {"f6_attitude": "beg"}}, "once": True},
            {"text": "没事了，再见", "next": "bye"}]},
        "camp": {"lines": [L("保卫队守着整座小镇。地面上的东西进不来，下面的东西也上不去——都是我们挡着。"),
                           L("跟我来，带你看一圈。")], "cutscene": "f6_camp_tour"},
        "training": {"lines": [L("训练场在东南边，木头假人旁边的训练台。"), L("每轮五个金币。忍痒、耐笑、练敏感……练出来的本事会一直跟着你。")],
                     "set": {"call": "open_training"}},
        "shadow": {"lines": [L("矿道深处这阵子不太平。有人说看到过影子一样的东西，可谁也没追上过。"),
                             L("……你要是再想起什么，第一个告诉我。")], "set": {"vars": {"captain_trust": 1}}},
        "still_angry": {"lines": [L("生气？我是保卫队长，不是小孩子。"), L("……不过你那天确实挺能笑的。队员们到现在还拿这个开玩笑。")]},
        "softer": {"lines": [L("你笑成那样，谁还凶得起来。"), L("……别告诉别人我这么说过。")]},
        "bye": {"lines": [L("别再一个人往矿道跑了。")]},
    },
}

D["blue_princess"] = {
    "name": "蓝色的公主", "npc": "blue_princess",
    "entries": [{"if": {"not": "f6_opening_done"}, "node": "rescue"}, {"if": {"not": "dlg_floor_06/blue_princess_first"}, "node": "first"}]
               + att_entries(),
    "nodes": {
        # —— 开场：叫停（过场 f6_wake 里调用）——
        "rescue": {"goto": by_attitude("rescue")},
        "rescue_honest": {"lines": [L("住手。她说的是真的——至少，她自己是这么相信的。"),
                                    L("……您说了算。", "保卫队队长"), L("把她放下来吧。她不是你们要找的人。")]},
        "rescue_defiant": {"lines": [L("够了。她再顶嘴，你们也挠不出别的答案来。"),
                                     L("……哼。看在您的面子上。", "保卫队队长"), L("放开她。嘴硬的人，我见得多了。")]},
        "rescue_beg": {"lines": [L("好了好了，她都笑成这样了。"),
                                 L("……您总是心软。", "保卫队队长"), L("放了她吧。笑成这样的人，能坏到哪里去呢。")]},
        # —— 之后在集市广场 ——
        "first": {"lines": [L("你上来了。……这里就是地下小镇。"), L("我第一次见到长得和自己这么像的人呢。")], "next": "hub_att"},
        "hub_att": {"goto": by_attitude("hello")},
        "hello_honest": {"lines": [L("你那天说的黑影……我相信你。")], "next": "hub"},
        "hello_defiant": {"lines": [L("被锁着还敢跟队长顶嘴的人，你是第一个。"), L("我挺喜欢的。")], "next": "hub"},
        "hello_beg": {"lines": [L("你笑起来的声音，整个地牢都听得到呢。"), L("……我没有取笑你的意思。")], "next": "hub"},
        "hub": {"prompt": "要问她什么？", "choices": [
            {"text": "你是谁？", "next": "who", "return": True},
            {"text": "谢谢你救了我", "next": "thanks", "return": True, "once": True},
            {"text": "这里是哪里？", "next": "where", "return": True},
            {"text": "你为什么要帮我？", "next": "why", "return": True},
            {"text": "我要怎么回去？", "next": "home", "return": True},
            {"text": "先这样吧", "next": "bye"}]},
        "who": {"lines": [L("我？……一个住在这里的人。"), L("名字的话——等你再信任我一点，我再告诉你。")]},
        "thanks": {"lines": [L("不用谢。……我也有我的理由。")], "set": {"vars": {"blue_thanked": 1}}},
        "where": {"lines": [L("地面下面的小镇。上面是集市，下面是保卫队的营地，再往下是矿道。"),
                            L("矿道最深处的门一直封着。……听说门后面，和你醒来之前待过的地方很像。")]},
        "why": {"goto": by_attitude("why")},
        "why_honest": {"lines": [L("因为你说的黑影——我也见过。")]},
        "why_defiant": {"lines": [L("因为你不肯低头。这样的人，不该被锁在那种地方。")]},
        "why_beg": {"lines": [L("因为……你笑的时候，看起来一点都不害怕。我很羡慕。")]},
        "home": {"lines": [L("回去的路……我也在找。"), L("等矿道深处的门打开，也许就有答案了。")]},
        "bye": {"lines": [L("有事就来广场找我。")]},
    },
}

D["supervisor"] = {
    "name": "市场监督", "npc": "supervisor",
    "entries": att_entries(),
    "nodes": {
        "hello_honest": {"lines": [L("欢迎来到集贸市场。……你就是那个从地牢出来的姑娘？"), L("听说你挺老实的。在这儿守规矩就好。")], "next": "hub"},
        "hello_defiant": {"lines": [L("哦——就是你啊，那个跟队长顶嘴的。"), L("在我的市场里可别闹事。")], "next": "hub"},
        "hello_beg": {"lines": [L("啊，「爱笑的公主」。整个集市都在说你呢。"), L("别害羞，大家都没有恶意。")], "next": "hub"},
        "hub": {"prompt": "要做什么？", "choices": [
            {"text": "看看商品", "next": "shop", "return": True},
            {"text": "市场有什么规矩？", "next": "rules", "return": True},
            {"text": "我的事……传开了吗？", "next": "rumor", "return": True},
            {"text": "「爱笑的公主」……是在说我吗？", "next": "laughing", "return": True, "if": {"eq": {"f6_attitude": "beg"}}, "once": True},
            {"text": "队长说我坏话了吗？", "next": "badword", "return": True, "if": {"eq": {"f6_attitude": "defiant"}}, "once": True},
            {"text": "再见", "next": "bye"}]},
        "shop": {"set": {"call": "open_shop"}},
        "rules": {"lines": [L("一手交钱，一手交货。金币就行。"), L("矿道里挖出来的、地面上偷偷运下来的，我都管。")]},
        "rumor": {"goto": by_attitude("rumor")},
        "rumor_honest": {"lines": [L("传开了一点。说你什么都不记得，又说你提到了「黑影」。"), L("矿工们听到黑影，脸色都变了。")]},
        "rumor_defiant": {"lines": [L("传得可厉害了。说你被锁着还冲队长喊「我可是公主」。"), L("队员们学你学得可像了。")]},
        "rumor_beg": {"lines": [L("说你被挠得笑个不停，还一边笑一边求饶。"), L("小孩子们都在学你笑呢。")]},
        "laughing": {"lines": [L("哈哈，是啊。不过这在小镇里是夸人的话——笑得出来的人，运气都不会太差。")]},
        "badword": {"lines": [L("坏话？他说你「嘴硬，但骨头也硬」。"), L("从他嘴里说出来，这算是夸奖了。")]},
        "bye": {"lines": [L("缺什么就回来买。")]},
    },
}

D["bonfire_host"] = {
    "name": "篝火派对的主人", "npc": "bonfire_host",
    "entries": att_entries(),
    "nodes": {
        "hello_honest": {"lines": [L("哎呀，新面孔！来来来，烤烤火——在地底下，篝火就是太阳。")], "next": "hub"},
        "hello_defiant": {"lines": [L("哟，是那个跟队长吵架的小公主！胆子真大，我喜欢。"), L("来烤烤火，消消气。")], "next": "hub"},
        "hello_beg": {"lines": [L("啊！是那个笑声特别好听的公主！"), L("今晚派对你一定要来，大家都想听你笑。")], "next": "hub"},
        "hub": {"prompt": "要做什么？", "choices": [
            {"text": "在篝火旁休息一下", "next": "rest", "return": True},
            {"text": "篝火派对是什么？", "next": "party", "return": True},
            {"text": "大家是不是在议论我？", "next": "gossip", "return": True},
            {"text": "（求饶后）……大家真的想听我笑？", "next": "laugh_party", "return": True, "if": {"eq": {"f6_attitude": "beg"}}, "once": True},
            {"text": "再见", "next": "bye"}]},
        "rest": {"lines": [L("坐吧，坐吧。")], "set": {"call": "rest"}},
        "party": {"lines": [L("每天收工以后，大家都来这里唱歌、跳舞、讲故事。"), L("来，我教你！")], "theater": "f6_dance"},
        "gossip": {"goto": by_attitude("gossip")},
        "gossip_honest": {"lines": [L("议论？大家只是好奇你从哪来的。"), L("……还有那个黑影。矿工们讲得可吓人了。")]},
        "gossip_defiant": {"lines": [L("是啊！大家都说，好久没看到有人敢跟队长顶嘴了。"), L("年轻的队员们都偷偷佩服你呢。")]},
        "gossip_beg": {"lines": [L("说你笑起来像小铃铛一样。"), L("嘿嘿，我也想听听。")]},
        "laugh_party": {"lines": [L("当然啦！下次派对的「挠痒大赛」，你来当嘉宾吧！"), L("……开玩笑的。大概。")]},
        "bye": {"lines": [L("冷了就回来烤火！")]},
    },
}


def chat(name_lines_default, variants=None, extra_nodes=None, choices=None, name=None, npc_id=None):
    """普通居民：hello 按态度分（variants 给了的话），可以带一个小选项菜单。"""
    nodes = {}
    if variants:
        nodes["hello"] = {"goto": by_attitude("hello")}
        for a in ATT:
            nodes["hello_" + a] = {"lines": name_lines_default + variants[a]}
            if choices:
                nodes["hello_" + a]["next"] = "hub"
    else:
        nodes["hello"] = {"lines": name_lines_default}
        if choices:
            nodes["hello"]["next"] = "hub"
    if choices:
        nodes["hub"] = {"choices": choices}
    nodes.update(extra_nodes or {})
    out = {"name": name, "entries": [{"node": "hello"}], "nodes": nodes}
    if npc_id:
        out["npc"] = npc_id
    return out


D["granny"] = chat([L("哎呀，是新来的孩子。")], {
    "honest": [L("听说你什么都不记得了？可怜的孩子……来，奶奶的点心分你一块。")],
    "defiant": [L("呵呵，跟队长顶嘴的就是你吧？奶奶年轻的时候也这样。")],
    "beg": [L("哎哟，就是你呀，笑得整条街都听得见。年轻真好。")]}, name="面包店的奶奶",
    choices=[{"text": "小镇的事", "next": "town", "return": True}, {"text": "再见", "next": "bye"}],
    extra_nodes={"town": {"lines": [L("这镇子啊，建在地底下好几十年了。"), L("太阳是没有的，可大家心里都暖和。")]},
                 "bye": {"lines": [L("饿了就来找奶奶。")]}})
D["kid_tom"] = chat([L("你就是那个公主？")], {
    "honest": [L("你真的不记得自己从哪来的吗？好酷！像故事书里一样！")],
    "defiant": [L("你敢跟队长吵架！我们都在学你喊「我可是公主」！")],
    "beg": [L("嘻嘻……我学给你听——「哈哈哈，先把羽毛停下来嘛」！")]}, name="小汤姆")
D["kid_lily"] = chat([L("姐姐，你的头发是粉色的！")], {
    "honest": [L("蓝色的姐姐说，你是好人。")],
    "defiant": [L("姐姐好凶……可是也好帅。")],
    "beg": [L("姐姐笑起来好可爱！再笑一次给我听嘛！")]}, name="小莉莉")
D["guard_patrol"] = chat([L("小镇巡逻中。")], {
    "honest": [L("黑影的事，队长让我们巡逻时多留意。你也小心。")],
    "defiant": [L("在镇上可别跟人吵架啊，「我可是公主」。")],
    "beg": [L("哈，是你。今天心情不错吧？笑一个？")]}, name="巡逻的队员")
D["granny_knit"] = chat([L("哎，坐下歇歇吧，孩子。")], {
    "honest": [L("记不得过去也没关系，在这儿重新开始就好。")],
    "defiant": [L("脾气倔的孩子啊，心眼都不坏。")],
    "beg": [L("笑得出来的孩子有福气。婆婆给你织条围巾吧。")]}, name="织毛衣的婆婆")
D["merchant_fruit"] = {"name": "水果摊的商贩", "entries": [{"node": "hello"}], "nodes": {
    "hello": {"lines": [L("新鲜的地底蘑菇果！甜得很！")], "choices": [
        {"text": "看看商品", "next": "shop", "return": True}, {"text": "再见", "next": "bye"}]},
    "shop": {"set": {"call": "open_shop"}}, "bye": {"lines": [L("慢走！")]}}}
D["merchant_cloth"] = chat([L("要不要看看布料？矿道里的蚕吐的丝，可软了。")], {
    "honest": [L("公主殿下，您的裙子……是地面上的料子吧？真好看。")],
    "defiant": [L("哟，顶嘴公主。放心，我卖东西不看脾气。")],
    "beg": [L("爱笑的公主！给你做件笑起来更好看的裙子吧！")]}, name="布店的商贩")
D["maid"] = chat([L("……您好。")], {
    "honest": [L("蓝色的大人吩咐过，要好好照顾您。有什么需要请告诉我。")],
    "defiant": [L("队长回营地时一直在叹气……是因为您吧。")],
    "beg": [L("那、那天地牢里的笑声……原来是您呀。")]}, name="女仆")
D["miner_old"] = chat([L("咳咳……年轻人，别往矿道深处走。")], {
    "honest": [L("你也见过那个黑影？……唉，我就说不是我眼花。")],
    "defiant": [L("嘴硬没用。矿道深处的东西，可不听你讲道理。")],
    "beg": [L("爱笑好啊。在矿道里，笑声能把害怕赶跑。")]}, name="老矿工")
D["miner_burr"] = chat([L("矿车别乱推啊！")], name="矿工伯尔",
    choices=[{"text": "深处那扇门是什么？", "next": "door", "return": True}, {"text": "再见", "next": "bye"}],
    extra_nodes={"door": {"lines": [L("那扇门？我爷爷那辈就封着了。"), L("偶尔能听到门后面有……笑声？不知道是不是听错了。")]},
                 "bye": {"lines": [L("小心脚下。")]}})
D["miner_dot"] = chat([L("哈啊……今天的矿石真沉。")], {
    "honest": [L("你说的黑影，是不是穿着斗篷，走路没有声音？……我好像也见过。")],
    "defiant": [L("听说你跟队长吵架了？哈哈，干得好，他早该被人顶一顶了。")],
    "beg": [L("你就是那个「爱笑的公主」？嘿嘿，笑一个嘛。")]}, name="矿工朵特")
D["guard_rook"] = chat([L("站住。……哦，是你。")], {
    "honest": [L("队长说你可能没撒谎。我们这几天在矿道口加了岗。")],
    "defiant": [L("哟，「我可是公主」来了！……开玩笑的，别生气。")],
    "beg": [L("那天挠你的人里有我……抱歉啦，命令就是命令。你笑得真的很厉害。")]}, name="保卫队员鲁克")
D["guard_moss"] = chat([L("训练场开张啦！我负责带训练——想练就跟我说。")], name="保卫队员莫丝",
    choices=[{"text": "我想训练", "next": "when", "return": True}, {"text": "再见", "next": "bye"}],
    extra_nodes={"when": {"lines": [L("好！每轮五个金币。挑一项吧——放心，我们下手有分寸的。")], "set": {"call": "open_training"}},
                 "bye": {"lines": [L("嗯。")]}})
D["guard_fern"] = chat([L("……")], {
    "honest": [L("你说的话，我信一半。")],
    "defiant": [L("下次再顶嘴，可就不只是坐垫了。")],
    "beg": [L("……那天你笑得我都不忍心了。")]}, name="保卫队员芬")
D["guard_jailer"] = chat([L("地牢现在空着。……你别再进来了。")], {
    "honest": [L("刑具我都收拾好了。坐垫的刷毛也换了新的……放心，不是给你准备的。"), L("你说的黑影，我会留意的。")],
    "defiant": [L("坐垫我还留着呢。想再来试试吗？")],
    "beg": [L("那天的羽毛，到现在还沾着你的笑声。……开玩笑的。")]}, name="看守")

DLG = Path("data/dialogues/floor_06")
DLG.mkdir(parents=True, exist_ok=True)
for name, d in D.items():
    (DLG / (name + ".json")).write_text(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")

S = "石碑"
SIGNS = {
    "sign6_town": [{"speaker": S, "text": "【地下小镇】欢迎来到地下小镇。上面是集贸市场和篝火广场，往下是保卫队营地。\n广场上的日记本可以存档（只有这一个存档点）。"}],
    "sign6_market": [{"speaker": S, "text": "【集贸市场】用金币买东西。摊位、市场监督都可以交易。"}],
    "sign6_gate": [{"speaker": S, "text": "【地牢入口】厚重的铁门锁着。门上刻着一行字：「通往地面的路，暂时封闭」。"}],
    "sign6_camp": [{"speaker": S, "text": "【保卫队营地】守护小镇的保卫队驻扎在这里。东南边是训练场，北边楼梯上去是集市。"}],
    "sign6_training": [{"speaker": S, "text": "【训练场】在训练台报名（每轮 5 金币）：魔力疲倦忍耐、魔力疲倦释放、耐笑部位、敏感部位强化。练出来的数值会一直保留。"}],
    "sign6_prison": [{"speaker": S, "text": "【营地地牢】关押违反规矩的人。刑具都收起来了……暂时。"}],
    "sign6_deep": [{"speaker": S, "text": "【矿道深处】封住的大门。门缝里吹出带着甜味的风……门后面好像还有机关在转动的声音。"}],
    "f6_gate_open": [{"speaker": P, "text": "钥匙插进锁孔……咔哒。开、开了！门后面是往下的楼梯……"}],
    "sign6_house_locked": [{"speaker": S, "text": "【蓝色的小屋】门锁着。门牌上写着一个蓝色的花体字母。"}],
    "sign6_house_up": [{"speaker": P, "text": "楼上是她的房间……不好随便上去。"}],
    "f6_house_door_night": [{"speaker": P, "text": "外面已经黑透了……门也锁上了，出不去。还是在房间里待着吧。"}],
    "sign6_maze": [{"speaker": S, "text": "【训练迷宫】十二个房间，每间都有一组脚 / 大腿 / 屁股的机关。主动去触发它们——"
                                             "身体会忍不住想逃回出口，连按空格拖住自己。逃到出口，这一轮就结束了。"}],
    "sign6_trap_thigh_pincer": [{"speaker": S, "text": "【夹腿羽毛钳】装在墙上，按节奏伸出带羽毛的钳臂夹住大腿，钳口的羽毛扫大腿内侧。看准它缩回去的时候再过。"}],
    "sign6_trap_foot_thigh_rack": [{"speaker": S, "text": "【足腿刑架】锁住脚踝、分开大腿，两组刷子轮流刷脚心和大腿内侧。越挣扎刷子换得越快，还会多困一会儿。"}],
    "sign6_trap_feather_swing": [{"speaker": S, "text": "【羽毛秋千】把人吊起来坐上秋千：往前荡羽毛扫脚心，往回荡刷子刷大腿。挣扎会荡得更高、挠得更重。"}],
    "sign6_trap_thigh_brush_ring": [{"speaker": S, "text": "【大腿刷环】踩到中心时刷环升起套住双腿，边转边刷大腿内侧——困得越久转得越快。"}],
    "sign6_trap_foot_bath": [{"speaker": S, "text": "【泡泡足浴盆】踩进去双脚就被吸住，泡泡和水流一直挠脚心。"}],
    "sign6_trap_sitz_bath": [{"speaker": S, "text": "【泡泡坐浴】被按坐进泡泡浴缸，水泡从底下一串串挠屁股和大腿。"}],
    "sign6_trap_spring_seat": [{"speaker": S, "text": "【弹簧刷座】地上的翻板一弹，矮凳把人「坐」住、双脚悬空，凳面的刷毛上下弹着刷屁股。"}],
    "sign6_trap_saddle_bench": [{"speaker": S, "text": "【骑马刷凳】跨坐在马鞍凳上、双腿分开，刷条来回推，同时刷屁股和大腿内侧。挣扎会让凳子晃、刷得更快。"}],
    "sign6_trap_scissor_stand": [{"speaker": S, "text": "【剪刀刷台】两块刷毛台板一开一合，夹住大腿内侧，下面的刷杆来回扫屁股。合上的那半拍不抓人。"}],
}
(DLG / "signs.json").write_text(json.dumps(SIGNS, ensure_ascii=False, indent="\t") + "\n")
print("对话：%d 个人物文件" % len(D))


# ================================================================ 过场 / 小剧场
def A(do, **kw):
    kw["do"] = do
    return kw


def line(speaker, text, emotion=None, actions=None, **kw):
    s = {"speaker": speaker, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    s.update(kw)
    return s


CAP, BLUE, NARR = "保卫队队长", "蓝色的公主", ""
BED, STOCKS, CLAMP, CUSHION, CUFFS, TEASER = "Supine_16_12", "Stocks_17_12", "Clamp_16_13", "Cushion_21_15", "Cuffs_21_14", "Teaser_17_11"

WAKE = {"name": "第六层开场：营地地牢里被痒醒", "letterbox": True, "skippable": False, "steps": [
    {"actions": [A("fade_out", time=0), A("hold", who=BED), A("hold", who=STOCKS, place=False), A("hold", who=CLAMP, place=False),
                 A("pose", emotion="sad", laugh=10), A("camera", to=[17, 12], time=0)], "wait": 0.6},
    line(NARR, "（……黑暗里，脚心传来一阵一阵的痒……）", actions=[A("tickle", who="princess", repeat=4, interval=0.4, fx="feather", zone="sole"),
                                                    A("trap", who=TEASER, time=1.6)]),
    {"actions": [A("fade_in", time=1.2), A("trap", who=TEASER, time=2.0),
                 A("tickle", who="princess", repeat=5, interval=0.3, fx="feather", add=20, zone="sole"), A("voice", state="giggle")], "wait": 1.2},
    line(P, "唔……哈、哈哈……谁、谁在挠我的脚心……", "giggle", [A("bubble", who="princess", kind="surprise"), A("shake", time=0.3)]),
    line(P, "这、这里是哪里？我被绑在一张床上……脚扣在床尾的足枷里，旁边的羽毛一下一下扫着脚心……", "surprise",
         [A("trap", who=TEASER, time=1.6), A("tickle", who="princess", repeat=4, interval=0.3, fx="feather", add=10, zone="sole")]),
    line(P, "哈、哈哈……床板上的羽毛还在挠肚子……肚脐那里不行……！", "giggle",
         [A("tickle", who="princess", repeat=5, interval=0.28, fx="feather", add=10, zone="belly")]),
    line(P, "大、大腿也被两块木板夹住了……木板上的绒毛蹭着大腿内侧……哈哈哈哈！", "helpless_1",
         [A("tickle", who="princess", repeat=5, interval=0.28, fx="brush", add=10, zone="thigh")]),
    line(P, "别、别挠了！我记得……我在那座机关城里笑晕过去，然后……", "helpless_1",
         [A("trap", who=TEASER, time=1.8), A("tickle", who="princess", repeat=6, interval=0.25, fx="feather", add=10, zone="sole")]),
    {"actions": [A("sfx", sound="door", pitch=0.8), A("spawn", id="captain", kind="npc:captain", at=[3, 13], dir="right"),
                 A("spawn", id="guard_a", kind="npc:guard", at=[2, 12], dir="right"), A("spawn", id="guard_b", kind="npc:guard", at=[2, 14], dir="right"),
                 A("camera", to=[13, 12], time=0.8)], "wait": 0.4},
    {"actions": [A("move", who="captain", to=[14, 13], speed=40), A("move", who="guard_a", to=[13, 11], speed=40),
                 A("move", who="guard_b", to=[13, 15], speed=40), A("voice", state="")], "wait": 2.8},
    line(CAP, "醒了？刑床挠肚子、足枷挠脚心、夹腿枷台蹭大腿——一样不落，还笑得挺精神嘛。", actions=[A("face", who="captain", dir="right")]),
    line(CAP, "你知道矿道口外面有多危险吗？保卫队找了你一整夜——居然一个人跑到外面去！", actions=[A("bubble", who="captain", kind="angry")]),
    line(P, "外、外面？我不知道你在说什么……我是突然出现在这里的！", "surprise"),
    line(CAP, "突然出现？……每个乱跑被抓回来的人，都是这么说的。"),
    {"talk": {"file": "floor_06/captain", "node": "opening_question"}},
    {"talk": {"file": "floor_06/captain", "node": "punish"}},
    # 换刑具：刑床 + 足枷 + 夹腿 → 挠痒坐垫 + 举手铐柱
    {"actions": [A("move", who="guard_a", to=[16, 11], time=0.6), A("move", who="guard_b", to=[17, 13], time=0.6)], "wait": 0.6},
    {"actions": [A("hold", who=BED, on=False), A("hold", who=STOCKS, on=False), A("hold", who=CLAMP, on=False), A("sfx", sound="stocks"),
                 A("fade_out", time=0.4)], "wait": 0.5},
    {"actions": [A("hold", who=CUSHION), A("hold", who=CUFFS, place=False), A("move", who="guard_a", to=[20, 15], time=0),
                 A("move", who="guard_b", to=[22, 15], time=0), A("face", who="guard_a", dir="right"), A("face", who="guard_b", dir="left"),
                 A("move", who="captain", to=[19, 13], time=0), A("camera", to=[21, 14], time=0), A("fade_in", time=0.5)], "wait": 0.6},
    line(P, "等、等一下！为什么要换到这个坐垫上……", "shy", [A("bubble", who="princess", kind="surprise")]),
    line(P, "呀啊！坐垫里的刷毛……在屁股底下来回刷……哈哈哈，好痒！", "helpless_1",
         [A("tickle", who="princess", repeat=6, interval=0.25, fx="brush", add=10, zone="butt")]),
    line(P, "手、手也被铐在柱子上举起来了……腋下全都露出来了……不、不要碰那里……", "shy",
         [A("move", who="guard_a", to=[20, 14], time=0.4), A("move", who="guard_b", to=[22, 14], time=0.4),
          A("tickle", who="princess", repeat=3, interval=0.35, fx="brush", zone="butt")]),
    {"talk": {"file": "floor_06/captain", "node": "punish_scene"}},
    # 小剧场后：回到地牢，队员们还在挠
    {"actions": [A("tickle", who="princess", by="guard_a", repeat=6, interval=0.22, fx="hand", add=15, zone="armpit"), A("voice", state="laugh"),
                 A("pose", emotion="helpless_2", laugh=85)], "wait": 0.6},
    line(P, "哈哈哈哈哈！腋下、腰……屁股底下的刷子也不停……真、真的不知道啊哈哈哈！", "helpless_2",
         [A("tickle", who="princess", by="guard_b", repeat=6, interval=0.22, fx="hand", zone="waist"),
          A("shake", time=0.4)]),
    # 蓝色公主
    {"actions": [A("spawn", id="blue", kind="npc:blue_princess", at=[3, 13], dir="right"), A("sfx", sound="door", pitch=1.1)], "wait": 0.2},
    line(BLUE, "——住手。", actions=[A("camera", to=[12, 13], time=0.8), A("voice", state="giggle")]),
    {"actions": [A("move", who="blue", to=[17, 14], speed=45), A("face", who="captain", dir="left"), A("face", who="guard_a", dir="left"),
                 A("bubble", who="captain", kind="surprise")], "wait": 3.0},
    line(P, "……诶？她、她和我……长得好像……只是是蓝色的……", "surprise", [A("bubble", who="princess", kind="surprise")]),
    {"talk": {"file": "floor_06/blue_princess", "node": "rescue"}},
    {"actions": [A("hold", who=CUSHION, on=False), A("hold", who=CUFFS, on=False), A("sfx", sound="stocks"), A("pose", emotion="sad", laugh=30),
                 A("move", who="princess", to=[20, 13], time=0.4), A("voice", state="")], "wait": 0.6},
    line(CAP, "……放了她。你们几个，回岗位去。", actions=[A("move", who="guard_a", to=[3, 13], speed=50), A("move", who="guard_b", to=[3, 14], speed=50)]),
    line(CAP, "下次别让我在矿道口再看到你。", actions=[A("face", who="captain", dir="right")]),
    {"actions": [A("move", who="captain", to=[3, 13], speed=45), A("despawn", who="guard_a"), A("despawn", who="guard_b")], "wait": 1.2},
    line(BLUE, "没事了。……这里是地下小镇，保卫队营地的地牢。", actions=[A("face", who="blue", dir="right")]),
    line(BLUE, "上去看看吧。我在楼上的广场等你——有很多话想问你。"),
    {"actions": [A("move", who="blue", to=[3, 13], speed=50), A("despawn", who="captain"), A("camera", who="princess", time=0.8)], "wait": 1.6},
    {"actions": [A("despawn", who="blue"), A("pose", emotion="happy", laugh=0), A("set_flag", flag="f6_opening_done"),
                 A("notify", text="可以自由活动了：沿走廊的楼梯上到保卫队营地")], "wait": 0.3},
    line(P, "……好不容易才喘过气来。先上去看看吧。", "sad"),
]}

CAMP_TOUR = {"name": "队长带公主看营地", "letterbox": True, "steps": [
    {"actions": [A("camera", to=[14, 9], time=1.0)], "wait": 1.0},
    line(CAP, "北边这排帐篷是队员们睡觉的地方。夜里轮流在哨塔上守着。"),
    {"actions": [A("camera", to=[38, 21], time=1.2)], "wait": 1.2},
    line(CAP, "东南边是训练场。木头假人、训练用的刑具……练忍痒、练挣脱，都在这里。"),
    {"actions": [A("camera", to=[6, 27], time=1.2)], "wait": 1.2},
    line(CAP, "西南角的楼梯下去，是地牢——你应该很熟了。"),
    {"actions": [A("camera", to=[44, 28], time=1.0)], "wait": 1.0},
    line(CAP, "东南角下去是矿道。最深处那扇门……任何人都不许靠近。"),
    {"actions": [A("camera", who="princess", time=1.0)], "wait": 1.0},
    line(CAP, "就这些。有事来指挥帐篷找我。"),
]}

CUT = Path("data/cutscenes/floor_06")
CUT.mkdir(parents=True, exist_ok=True)
for name, c in (("f6_wake", WAKE), ("f6_camp_tour", CAMP_TOUR)):
    (CUT / (name + ".json")).write_text(json.dumps(c, ensure_ascii=False, indent="\t") + "\n")

# —— 小剧场：坐垫 + 举手铐柱上，队员们一起挠（台词随态度不同）——
PUNISH_CAST = {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "cushion": {"kind": "trap:cushion", "at": [0, 11]},
    "cuffs": {"kind": "trap:cuffs", "at": [0, -2]},
    "g1": {"kind": "npc:guard", "at": [-30, 4], "dir": "right"},
    "g2": {"kind": "npc:guard", "at": [30, 4], "dir": "left"},
    "g3": {"kind": "npc:guard", "at": [-60, 6], "dir": "right", "hidden": True},
    "cap": {"kind": "npc:captain", "at": [62, 0], "dir": "left"},
}
PUNISH_LINES = {
    "honest": [
        line(CAP, "既然什么都不记得，那就好好笑一笑，看能不能笑出点记忆来。"),
        line(P, "哈哈哈……我说的都是真的！腋、腋下不行……坐垫的刷子也在刷屁股……！", portrait="defeat_1"),
        line("保卫队员", "队长，她好像真的什么都不知道……"),
        line(CAP, "……继续。腋下和腰，别停。"),
    ],
    "defiant": [
        line(CAP, "不是很能说吗？再说一句「我可是公主」听听。"),
        line(P, "我、我就是公主哈哈哈哈！你们……等着——腰、腰不行！屁股底下的刷子也……哈哈哈！", portrait="defeat_1"),
        line("保卫队员", "队长，她还在嘴硬！"),
        line(CAP, "第三个人也上。把她的鞋脱了——脚心、腋下、腰，一起来。"),
    ],
    "beg": [
        line(CAP, "这么爱笑，就让你笑个够。……轻点挠，别弄伤了她。"),
        line(P, "哈哈哈哈……我错了我错了！轻、轻点也很痒啊……腋下、腋下被羽毛扫……！", portrait="defeat_1"),
        line("保卫队员", "噗……队长，她笑得好开心啊。坐垫都把她刷得扭来扭去的。"),
        line(CAP, "……别笑。继续挠。"),
    ],
}


def punish(att):
    ls = PUNISH_LINES[att]
    steps = [
        {"actions": [A("fade_in", time=0.6), A("voice", state="giggle")], "wait": 0.7},
        dict(ls[0], actions=[A("face", who="cap", dir="left")]),
        dict(ls[1], actions=[A("tickle", who="princess", by="g1", repeat=6, interval=0.25, fx="hand", zone="armpit"),
                             A("tickle", who="princess", by="cushion", repeat=6, interval=0.3, fx="lines", zone="butt"),
                             A("bubble", who="princess", kind="laugh"), A("voice", state="laugh")]),
        dict(ls[2], actions=[A("hop", who="g1", count=1)]),
    ]
    if att == "defiant":
        steps.append({"actions": [A("enter", who="g3", at=[-44, 12], time=0.4)], "wait": 0.4})
    steps += [
        dict(ls[3], actions=[A("tickle", who="princess", by="g1", repeat=8, interval=0.2, fx="hand", zone="armpit"),
                             A("tickle", who="princess", by="g2", repeat=8, interval=0.22, fx="hand", zone="waist")]
             + ([A("tickle", who="princess", by="g3", repeat=8, interval=0.24, fx="feather", zone="sole")] if att == "defiant" else [])),
        {"portrait": "defeat_2", "speaker": P, "text": {"honest": "哈哈哈哈哈……腋下、腰、屁股……全、全都好痒……我真的什么都……哈哈哈哈！",
                                                         "defiant": "哈哈哈哈哈！脚、脚心也……三、三个人太犯规了……不行了不行了哈哈哈！",
                                                         "beg": "哈哈哈哈哈……屁股底下的刷子还在刷……我会乖乖的……再也不乱跑了哈哈哈哈！"}[att],
         "actions": [A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.6),
                     A("tickle", who="princess", by="g1", repeat=8, interval=0.18, fx="hand", zone="armpit"),
                     A("tickle", who="princess", by="cushion", repeat=8, interval=0.2, fx="lines", zone="butt")]},
        {"speaker": NARR, "text": "（坐垫里的刷毛一刻不停地刷着屁股，举在柱子上的双手放不下来，队员们轮流挠着腋下和腰——地牢里只剩下公主断断续续的笑声）",
         "actions": [A("tickle", who="princess", by="g2", repeat=6, interval=0.3, fx="hand", zone="waist"),
                     A("tickle", who="princess", by="cushion", repeat=6, interval=0.3, fx="lines", zone="butt"), A("bubble", who="princess", kind="dots")]},
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]
    return {"name": "营地地牢的惩罚（%s）" % {"honest": "老实解释", "defiant": "顶嘴反驳", "beg": "笑着求饶"}[att], "cast": PUNISH_CAST, "steps": steps}


DANCE = {"name": "篝火派对的舞", "cast": {
    "princess": {"kind": "princess", "at": [-14, 6], "visual": "happy", "anim": "idle", "dir": "down"},
    "host": {"kind": "npc:bonfire_host", "at": [14, 6], "dir": "down"},
    "kid": {"kind": "npc:kid", "at": [-46, 2], "dir": "right"},
    "granny": {"kind": "npc:granny", "at": [46, 2], "dir": "left"}},
    "steps": [
        {"actions": [A("fade_in", time=0.5)], "wait": 0.5},
        line("篝火派对的主人", "跟着我——左脚、右脚、转一圈！", actions=[A("hop", who="host", count=2)]),
        line(P, "左、左脚……右脚……哇，转、转晕了……", "happy", [A("hop", who="princess", count=2), A("face", who="princess", dir="left")]),
        line("小孩", "姐姐跳得好好笑！", actions=[A("hop", who="kid", count=3), A("bubble", who="kid", kind="laugh")]),
        line("篝火派对的主人", "哈哈，第一次就跳成这样，很不错啦！", actions=[A("hop", who="host", count=1), A("hop", who="granny", count=1)]),
        line(P, "……嘿嘿。好久没这么开心过了。", "happy", [A("face", who="princess", dir="down"), A("bubble", who="princess", kind="happy")]),
        {"actions": [A("fade_out", time=0.5)], "wait": 0.5},
    ]}

TH = Path("data/theater/floor_06")
TH.mkdir(parents=True, exist_ok=True)
for att in ATT:
    (TH / ("f6_punish_%s.json" % att)).write_text(json.dumps(punish(att), ensure_ascii=False, indent="\t") + "\n")
(TH / "f6_dance.json").write_text(json.dumps(DANCE, ensure_ascii=False, indent="\t") + "\n")

# —— 训练营的惩罚小剧场（scripts/training/training_stage.gd 播放）——
# 训练一（魔力疲倦忍耐）：疲倦满了释放之后，卫兵们趁着身体最敏感的时候一起挠脚心和大腿内侧
G = "保卫队员"
ENDURE_CAST = {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "supine": {"kind": "trap:supine", "at": [0, 18]},
    "cushion": {"kind": "trap:cushion", "at": [0, 14]},
    "clamp": {"kind": "trap:clamp", "at": [0, 17]},
    "stocks": {"kind": "trap:stocks", "at": [0, 23]},
    "g1": {"kind": "npc:guard", "at": [-34, 10], "dir": "right"},
    "g2": {"kind": "npc:guard", "at": [34, 10], "dir": "left"},
    "g3": {"kind": "npc:guard", "at": [-64, 6], "dir": "right", "hidden": True},
}
# 每段分阶段：魔力释放 → 趁敏感加练 / 换工具（刷子 → 羽毛 → 手指）→ 加人 → 刑具全开 → 笑到迷糊收尾。{successes} = 这一轮成功抵抗的次数
CAPN = "保卫队队长"


def T(by, zone, fx="hand", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, repeat=n, interval=iv, fx=fx, zone=zone)


def burst_open(text):
    return [{"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5},
            {"portrait": "fatigue_burst", "speaker": P, "text": text,
             "actions": [A("flash", time=0.5), A("sfx", sound="water_release"), A("shake", who="princess", time=0.6)]}]


ENDURE = [
    ("趁热加练", [], burst_open("魔、魔力……冲出来了——！哈啊……全身一下子松开了……") + [
        line(G, "放出来了！——就是现在。放完魔力的身体最敏感，趁热加练！", actions=[A("hop", who="g1", count=1), A("hop", who="g2", count=1)]),
        line(P, "等、等一下！刚放完……一碰就……哈哈哈哈！脚心、脚心不行！", portrait="defeat_1", actions=[T("g1", "sole", "lines", 8, 0.2), A("bubble", who="princess", kind="laugh")]),
        line(G, "先用刷子。刚才抵抗了 {successes} 次，不错——那这一轮就从脚心刷起。", actions=[T("g1", "sole", "lines", 8, 0.22), T("stocks", "sole", "lines", 6, 0.3)]),
        line(P, "哈哈哈哈！刷、刷毛钻进脚趾缝了……左边右边都……哈哈哈！", actions=[T("g2", "sole", "lines", 8, 0.2)]),
        line(G, "换羽毛。大腿内侧，慢慢地、一下一下地扫。", actions=[T("g2", "thigh", "feather", 8, 0.28), A("face", who="g2", dir="left")]),
        line(P, "呜哈哈……羽、羽毛最坏了……慢慢扫比快的还痒——！", actions=[T("g2", "thigh", "feather", 8, 0.3), T("clamp", "thigh", "lines", 6, 0.3)]),
        line(G, "最后用手。……膝盖窝也算大腿哦。", actions=[T("g1", "thigh", "hand", 10, 0.18), T("g2", "sole", "hand", 10, 0.18)]),
        line(P, "哈哈哈哈哈！手、手指最不行了！膝盖窝不算大腿啦哈哈哈哈！", portrait="defeat_2", actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.5)]),
        line(G, "刑具也开到最大。坐垫、刑床、足枷——一起来。", actions=[T("cushion", "butt", "lines", 10, 0.2), T("supine", "waist", "feather", 10, 0.22), T("stocks", "sole", "lines", 10, 0.2)]),
        line(P, "哈哈哈哈哈哈！屁、屁股底下和腰也……全身都在被挠——哈哈哈哈！", actions=[T("g1", "sole", "hand", 10, 0.16), T("g2", "thigh", "hand", 10, 0.17)]),
        line(NARR, "（刷子、羽毛、手指轮番上阵，刑具嗡嗡地转——公主的笑声一阵高过一阵，渐渐变得断断续续）", actions=[T("cushion", "butt", "lines", 6, 0.3), A("bubble", who="princess", kind="dots")]),
        line(P, "……哈……哈……刷子……羽毛……手指……排、排好队了……嘿嘿……"),
        line(G, "……好像笑迷糊了。今天先到这儿——魔力也安静下来了。"),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]),
    ("规矩：三人轮流", ["g3"], burst_open("魔力……满出来了——！呼啊……") + [
        line(G, "疲倦撑满了啊。按规矩，撑不住的要多挨一轮。"),
        line(P, "规、规矩？！什么时候有这种规矩的……", "surprise"),
        line(G, "现在有了。——喂，过来帮忙！", actions=[A("enter", who="g3", at=[-56, 14], time=0.4)]),
        line("保卫队员（第三位）", "来了来了。我负责哪儿？", actions=[A("hop", who="g3", count=1)]),
        line(G, "三个人轮流：一个脚心、一个大腿、一个腰。喊「换」就换位置。", actions=[T("g1", "sole", "hand", 8, 0.2), T("g2", "thigh", "hand", 8, 0.2), T("g3", "waist", "hand", 8, 0.2)]),
        line(P, "哈哈哈哈哈！三、三个地方一起——哪、哪儿都躲不开哈哈哈！", portrait="defeat_1", actions=[A("bubble", who="princess", kind="laugh")]),
        line(G, "换！", actions=[T("g1", "thigh", "hand", 8, 0.18), T("g2", "waist", "hand", 8, 0.18), T("g3", "sole", "feather", 8, 0.2)]),
        line(P, "噫哈哈哈！换了手更痒——刚、刚适应一点又换了哈哈哈哈！"),
        line(G, "再换！这次坐垫也开到最大。", actions=[T("g1", "waist", "hand", 10, 0.16), T("g2", "sole", "lines", 10, 0.16), T("g3", "thigh", "hand", 10, 0.17), T("cushion", "butt", "lines", 10, 0.2)]),
        line(P, "哈哈哈哈哈哈！屁股底下也……四、四个地方了——不公平哈哈哈哈！", portrait="defeat_2", actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.6)]),
        line("保卫队员（第三位）", "她脚趾缩成一团了。……脚趾缝要不要也刷一下？", actions=[T("g3", "sole", "lines", 10, 0.16)]),
        line(P, "不要问啊哈哈哈哈！脚趾缝、脚趾缝不行——！", actions=[T("stocks", "sole", "lines", 8, 0.2)]),
        line(NARR, "（三个人一圈一圈地换位置，每换一次都正好挠在她刚放松的地方——直到她连「换」都听不清了）", actions=[A("bubble", who="princess", kind="dots")]),
        line(P, "……换……换到哪儿了……嘿……哪儿都……是手……"),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]),
    ("两只脚心同时", [], burst_open("脚、脚底……魔力从脚底冲出去了——！") + [
        line(G, "魔力是从脚底放出去的？那脚心现在一定最敏感。"),
        line(P, "别、别分析了……脚底还麻麻的……", "shy"),
        line(G, "两只脚一起。我左边，你右边——数到三。一、二……", actions=[A("face", who="g1", dir="right"), A("face", who="g2", dir="left")]),
        line(P, "等一下等一下——哈哈哈哈哈哈！三还没数呢哈哈哈！", portrait="defeat_1", actions=[T("g1", "sole", "hand", 10, 0.16), T("g2", "sole", "hand", 10, 0.16), A("bubble", who="princess", kind="laugh")]),
        line(G, "足枷锁着，脚趾张开一点……对，就这样。", actions=[T("stocks", "sole", "lines", 8, 0.22), T("g1", "sole", "feather", 8, 0.22)]),
        line(P, "哈哈哈哈！脚、脚趾被扒开了……羽毛从中间穿过去——哈哈哈哈！"),
        line(P, "大、大腿也可以！换、换大腿吧……脚心真的不行了哈哈哈！"),
        line(G, "大腿？好啊。——夹板，开。", actions=[T("clamp", "thigh", "lines", 10, 0.2), T("g2", "sole", "hand", 10, 0.18)]),
        line(P, "不是「也」啊哈哈哈哈！大腿和脚心一起——比刚才还痒哈哈哈哈！", portrait="defeat_2", actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.6)]),
        line(G, "左边脚跟、右边脚弓、中间脚趾——一个都不放过。", actions=[T("g1", "sole", "hand", 10, 0.15), T("g2", "sole", "lines", 10, 0.16), T("stocks", "sole", "lines", 10, 0.2)]),
        line(P, "哈哈哈哈哈哈！脚、脚要化掉了……左右都、都分不清了——！"),
        line(NARR, "（两只被锁住的脚心同时被挠，脚趾张开又蜷起来，蜷起来又被扒开——笑声里渐渐带上了哭腔）", actions=[T("g1", "sole", "hand", 6, 0.3), A("bubble", who="princess", kind="dots")]),
        line(P, "……左……右……哪只是我的脚……嘿嘿……都、都不是了……"),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]),
    ("队长亲自示范", ["cap"], burst_open("魔力……忍、忍不住了——！呼……放出来了……") + [
        line(CAPN, "……让开。挠痒也是有技巧的，我示范一次。", actions=[A("enter", who="cap", at=[60, 2], time=0.5), A("face", who="cap", dir="left")]),
        line(P, "队、队长？！不、不用亲自来的……", "surprise"),
        line(CAPN, "刚才抵抗了 {successes} 次……还差得远。看好了——不是用力，是轻。", actions=[A("move", who="cap", to=[24, 6], time=0.6)]),
        line(P, "……噗、噗哈哈……只、只是指尖碰了一下……为什么会这么痒……", portrait="defeat_1", actions=[T("cap", "sole", "feather", 6, 0.4)]),
        line(CAPN, "沿着脚弓画圈。快了她会绷紧，慢了她才会笑出来。", actions=[T("cap", "sole", "hand", 8, 0.35)]),
        line(P, "哈哈哈……慢、慢慢地画圈……好坏……哈哈哈哈！"),
        line(G, "原来如此……那大腿内侧呢，队长？", actions=[A("hop", who="g1", count=1)]),
        line(CAPN, "膝盖往上一掌的地方。你们试试。", actions=[T("g1", "thigh", "hand", 8, 0.3), T("g2", "thigh", "hand", 8, 0.32)]),
        line(P, "哈哈哈哈哈！就、就是那里——队长不要教他们啊哈哈哈哈！", portrait="defeat_2", actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.5)]),
        line(CAPN, "学会了就一起来。刑具也开着——让她记住这个感觉，下次才忍得住。", actions=[T("cap", "sole", "hand", 10, 0.2), T("g1", "thigh", "hand", 10, 0.18), T("g2", "thigh", "hand", 10, 0.2), T("cushion", "butt", "lines", 10, 0.2)]),
        line(P, "哈哈哈哈哈哈！一、一下子全学会了——三个人都好会挠哈哈哈哈！"),
        line(NARR, "（队长的「技巧」一传十，十传百——训练场上，三双手都学会了最痒的挠法）", actions=[A("bubble", who="princess", kind="dots")]),
        line(P, "……画、画圈……一圈……两圈……嘿嘿……队长的手……好轻……"),
        line(CAPN, "……今天就到这里。让她缓一缓。"),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]),
    ("数数惩罚", [], burst_open("魔力……又满了——！哈啊……放、放完了……") + [
        line(G, "撑不住的人要受「数数」惩罚：挠一下，你就报一个数。报错了从头来。"),
        line(P, "报数……？好、好吧，这个我可以……", "shy"),
        line(G, "开始。", actions=[T("g1", "sole", "hand", 1, 0.2)]),
        line(P, "一！……噗。", actions=[T("g2", "thigh", "hand", 1, 0.2)]),
        line(P, "二！……三——哈哈！四、四……", portrait="defeat_1", actions=[T("g1", "sole", "hand", 4, 0.3)]),
        line(G, "你刚才报了两次「四」。重来。", actions=[A("hop", who="g1", count=1)]),
        line(P, "诶？！我、我没有……一！二！三哈哈哈……", actions=[T("g1", "sole", "hand", 6, 0.25), T("g2", "thigh", "hand", 6, 0.25)]),
        line(G, "这次加快一点。坐垫也一起，它挠一下也要算一个数。", actions=[T("cushion", "butt", "lines", 8, 0.2), T("g1", "sole", "hand", 8, 0.18)]),
        line(P, "七、八——九哈哈哈哈！十、十——坐垫那下算不算——哈哈哈哈！", portrait="defeat_2", actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.5)]),
        line(G, "算。所以你又数错了。重来。", actions=[T("g2", "thigh", "hand", 10, 0.16), T("stocks", "sole", "lines", 10, 0.18)]),
        line(P, "哈哈哈哈哈哈！一、一……一后面是什么来着……哈哈哈哈！"),
        line(NARR, "（每次快数到二十，总会有一下挠在意想不到的地方——数字一个接一个地从她嘴里滑走）", actions=[T("g1", "sole", "hand", 8, 0.25), T("cushion", "butt", "lines", 8, 0.25), A("bubble", who="princess", kind="dots")]),
        line(P, "……一……一百……嘿嘿……数、数完了吧……可以……可以睡了吗……"),
        line(G, "……她从一直接跳到一百了。好吧，这次算你过。"),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]),
]


def endure_punish(i):
    name, extra, steps = ENDURE[i]
    cast = dict(ENDURE_CAST)
    if "cap" in extra:
        cast["cap"] = {"kind": "npc:captain", "at": [90, 2], "dir": "left", "hidden": True}
    return {"name": "魔力疲倦忍耐训练的惩罚（%s）" % name, "cast": cast, "steps": steps}


# 训练三、四（部位训练）：闷笑满了笑倒之后的加练。{zone} / {zone_name} / {device} / {device_x} / {device_y} 由训练小游戏换成本轮的
ZONE_CAST = {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "device": {"kind": "trap:{device}", "at": ["{device_x}", "{device_y}"]},
    "g1": {"kind": "npc:guard", "at": [-30, 6], "dir": "right"},
    "g2": {"kind": "npc:guard", "at": [30, 6], "dir": "left", "hidden": True},
}
ZONE_LINES = [
    [line(G, "笑倒了？那就再来一轮——{zone_name}还没练够呢。"),
     line(P, "哈哈哈哈……{zone_name}、{zone_name}已经不行了……！", portrait="defeat_1"),
     line(G, "刑具也别停。专挠{zone_name}，一下都不许躲。"),
     line(P, "哈哈哈哈哈！只、只挠这一个地方……更、更痒了哈哈哈哈！", portrait="defeat_2"),
     line(NARR, "（刑具和工具都对准了{zone_name}，一下接一下——直到公主连笑声都变得断断续续）")],
    [line(G, "叫人来帮忙。两个人一起挠{zone_name}，看她还憋不憋得住。"),
     line(P, "两、两个人？！哈哈哈……{zone_name}要坏掉了……！", portrait="defeat_1"),
     line(G, "这就是训练。笑够了，身体才记得住。"),
     line(P, "哈哈哈哈哈！记、记住了……真的记住了哈哈哈哈——！", portrait="defeat_2"),
     line(NARR, "（两个卫兵一左一右，专挑{zone_name}挠个不停——训练场上的笑声好久才停下来）")],
]


def zone_punish(i):
    ls = ZONE_LINES[i]
    steps = [
        {"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5},
        dict(ls[0], actions=[A("hop", who="g1", count=1)]),
        dict(ls[1], actions=[A("tickle", who="princess", by="g1", repeat=8, interval=0.2, fx="hand", zone="{zone}"),
                             A("bubble", who="princess", kind="laugh")]),
    ]
    if i == 1:
        steps.append({"actions": [A("enter", who="g2", at=[30, 6], time=0.4)], "wait": 0.4})
    steps += [
        dict(ls[2], actions=[A("tickle", who="princess", by="device", repeat=8, interval=0.25, fx="lines", zone="{zone}")]
             + ([A("tickle", who="princess", by="g2", repeat=8, interval=0.22, fx="hand", zone="{zone}")] if i == 1 else [])),
        dict(ls[3], actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.6),
                             A("tickle", who="princess", by="g1", repeat=10, interval=0.16, fx="hand", zone="{zone}"),
                             A("tickle", who="princess", by="device", repeat=8, interval=0.2, fx="lines", zone="{zone}")]),
        dict(ls[4], actions=[A("tickle", who="princess", by="g1", repeat=6, interval=0.3, fx="hand", zone="{zone}"),
                             A("bubble", who="princess", kind="dots")]),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]
    return {"name": "部位训练的惩罚（%d）" % (i + 1), "cast": ZONE_CAST, "steps": steps}


def _theater_json(d):
    # 文件本身要是合法的 JSON（编辑器会解析 .json）：占位的坐标写成字符串 "{device_x}"，
    # 播放时 CG.play_theater_subst 把整个 "{键}" 换成数字
    return json.dumps(d, ensure_ascii=False, indent="\t") + "\n"


# 训练二（魔力疲倦释放）：在组合里疲倦满了释放之后，公主没有逃——为了训练留在机关里（每个组合一段）
STAGE_AT = {"boots": [0, 18], "clamp": [0, 18], "legloop": [0, 18], "stocks": [0, 19], "thigh_pincer": [0, 2], "foot_thigh_rack": [0, 18],
            "feather_swing": [0, 16], "binding": [0, 17], "thigh_brush_ring": [0, 17], "foot_bath": [0, 18], "sitz_bath": [0, 18],
            "spring_seat": [0, 18], "teaser": [22, 14], "saddle_bench": [0, 18], "scissor_stand": [0, 18], "cushion": [0, 18]}
SRC_ZONE = {"boots": "sole", "clamp": "thigh", "legloop": "sole", "stocks": "sole", "thigh_pincer": "thigh", "foot_thigh_rack": "sole",
            "feather_swing": "sole", "binding": "thigh", "thigh_brush_ring": "thigh", "foot_bath": "sole", "sitz_bath": "butt",
            "spring_seat": "butt", "teaser": "sole", "saddle_bench": "butt", "scissor_stand": "thigh", "cushion": "butt",
            "caterpillar": "thigh", "frog": "sole", "rat": "sole", "squirrel": "thigh", "hedgehog": "sole", "fairy": "thigh",
            "bubble_fish": "sole", "slime": "sole"}
MONSTER_KEYS = {"caterpillar", "frog", "rat", "squirrel", "hedgehog", "fairy", "bubble_fish", "slime"}
# (组合 id, 三个来源, 组合名, 第一句, 高潮那句)
DEVOTION = [
    ("boots_clamp_crawl", ["boots", "clamp", "caterpillar"], "长靴夹腿毛毛虫",
     "哈哈哈……靴、靴子里还在扫……毛毛虫又爬上来了……可、可是我不脱……！", "从脚心一路爬到大腿……哈哈哈哈！再爬一遍也、也没关系……！"),
    ("legloop_lick", ["legloop", "frog", "rat"], "吊环舔脚",
     "吊着的脚又被舔了……哈哈哈……站着的那只也……我、我不跑……！", "两只脚都……哈哈哈哈！舌头和爪子……再来几下我也撑得住！"),
    ("foot_thigh_lock", ["stocks", "clamp", "squirrel"], "脚腿双锁",
     "锁着就锁着……哈哈哈……尾巴扫脚心的时候……我、我不挣了……！", "脚心、大腿、脚心……哈哈哈哈！就、就这样一直练……！"),
    ("pincer_stocks", ["thigh_pincer", "stocks", "hedgehog"], "羽毛钳足枷",
     "钳子又夹上来了……哈哈哈……刺猬也……我会好好待在这里的……！", "大腿和脚底一起……哈哈哈哈！魔力……魔力在变顺……！"),
    ("rack_crawl", ["foot_thigh_rack", "thigh_pincer", "caterpillar"], "刑架爬腿",
     "刷子换得好快……哈哈哈……越挣扎越快，那我就……不挣扎……！", "毛毛虫爬到钳子中间了……哈哈哈哈！好、好痒……可是我要坚持！"),
    ("swing_frenzy", ["feather_swing", "squirrel", "rat"], "秋千乱挠",
     "又、又荡起来了……哈哈哈……荡过去荡回来都痒……我不下来……！", "荡、荡高一点也可以……哈哈哈哈！为了训练……再荡几下……！"),
    ("ring_binding", ["thigh_brush_ring", "binding", "fairy"], "刷环绑腿",
     "刷环还在转……哈哈哈……绑着的腿也……我、我站在这里不动……！", "越转越快了……哈哈哈哈！精灵也一起……全、全都接下来……！"),
    ("foot_bubble", ["foot_bath", "bubble_fish", "slime"], "足浴泡泡",
     "脚还泡在盆里……哈哈哈……泡泡又冲上来了……我不拔出来……！", "泡泡、鱼、黏黏的……哈哈哈哈！脚心都……都交给训练了……！"),
    ("bath_trio", ["sitz_bath", "bubble_fish", "fairy"], "泡浴三重奏",
     "坐着……哈哈哈……水泡又从底下冒……我、我不起来……！", "屁股底下全是泡泡……哈哈哈哈！再泡一会儿……我能忍……！"),
    ("spring_feather", ["spring_seat", "teaser", "rat"], "弹座羽脚",
     "凳子又弹了……哈哈哈……悬着的脚也被扫……我不下去……！", "一弹一扫……哈哈哈哈！好、好痒……可是这是训练……！"),
    ("saddle_brush", ["saddle_bench", "squirrel", "caterpillar"], "骑凳三刷",
     "刷条又推过来了……哈哈哈……腿分开也没关系……我、我骑稳……！", "三层刷……哈哈哈哈！凳子晃就晃吧……我不会下来的……！"),
    ("scissor_brush", ["scissor_stand", "cushion", "hedgehog"], "剪刀刷",
     "台板又合上了……哈哈哈……下面也在刷……我、我站着不躲……！", "上上下下全是刷毛……哈哈哈哈！再、再夹几下……我撑得住……！"),
]


def devotion(cid, srcs, name, l1, l3):
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"}}
    mx = [-32, 32]
    for s in srcs:
        if s in MONSTER_KEYS:
            x = mx.pop(0)
            cast[s] = {"kind": "monster:" + s, "at": [x, 8], "dir": "right" if x < 0 else "left"}
        else:
            cast[s] = {"kind": "trap:" + s, "at": STAGE_AT.get(s, [0, 18])}
    cast["g1"] = {"kind": "npc:guard", "at": [-66, 2], "dir": "right"}
    tk = lambda s, n, iv: A("tickle", who="princess", by=s, repeat=n, interval=iv, fx="hand" if s in MONSTER_KEYS else "lines", zone=SRC_ZONE.get(s, "sole"))
    steps = [
        {"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5},
        line(NARR, "（魔力释放之后，「%s」并没有停下——身体比刚才敏感得多，可公主没有往出口跑）" % name),
        line(P, l1, actions=[tk(srcs[0], 6, 0.3), tk(srcs[1], 6, 0.32), A("bubble", who="princess", kind="laugh")], portrait="defeat_1"),
        line(G, "公主殿下……不跑吗？刚放完魔力，现在是最痒的时候哦。", actions=[A("hop", who="g1", count=1)]),
        line(P, "不、不跑……哈哈……保卫队的大家每天都这么练……我、我也要变强……！", actions=[tk(srcs[2], 6, 0.3)]),
        line(P, l3, actions=[A("pose", who="princess", visual="helpless_2"), A("shake", who="princess", time=0.6),
                             tk(srcs[0], 10, 0.16), tk(srcs[1], 10, 0.17), tk(srcs[2], 10, 0.18)], portrait="defeat_2"),
        line(P, "哈哈哈……魔力……放出来的感觉……越来越清楚了……这、这就是训练的成果……！", actions=[tk(srcs[2], 6, 0.3)]),
        line(NARR, "（她咬着牙留在机关里，一边笑一边感受魔力流过全身——这一次的训练效果，是平时的五倍）",
             actions=[tk(srcs[0], 6, 0.3), A("bubble", who="princess", kind="dots")]),
        {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
    ]
    return {"name": "训练迷宫的坚持（%s）" % name, "cast": cast, "steps": steps}


for cid, srcs, name, l1, l3 in DEVOTION:
    (TH / ("train_release_%s.json" % cid)).write_text(_theater_json(devotion(cid, srcs, name, l1, l3)))
for i in range(len(ENDURE)):
    (TH / ("train_endure_punish_%d.json" % (i + 1))).write_text(_theater_json(endure_punish(i)))
for i in range(2):
    (TH / ("train_zone_punish_%d.json" % (i + 1))).write_text(_theater_json(zone_punish(i)))
print("过场 2 段，小剧场 %d 段" % (6 + len(ENDURE) + len(DEVOTION)))


# ================================================================ 第六层后续剧情：参观小镇 → 蓝色小屋 → 夜晚 → 钥匙 → 第二天
# 剧情脚本见 levels/floor_06/scripts/f6_story.gd；睡觉组件 scripts/story/sleep.gd。
class Stack:
    """一格叠放多个实体（木地板铺满房间，上面再放家具）：最后用 " + " 连起来写进地图。"""

    def __init__(self, m):
        self.m, self.cells = m, {}

    def add(self, x, y, spec):
        self.cells.setdefault((x, y), []).append(spec)

    def write(self):
        for (x, y), specs in self.cells.items():
            self.m.put(x, y, " + ".join(specs))
        self.m.write()


HOUSE_OBJ = "talk:floor_06/house_objects#"
house = Map("floor_06_house", 20, 14, "intro =\nambient = 0.9,0.82,0.76\nnight_ambient = 0.36,0.34,0.56")
house.room(2, 2, 17, 11)
hs = Stack(house)
for y in range(2, 12):
    for x in range(2, 18):
        hs.add(x, y, "prop type=wood_floor")
for x in (5, 14):
    house.torch(x, 1)
hs.add(6, 2, "prop type=window action=" + HOUSE_OBJ + "window")
hs.add(13, 2, "prop type=window action=" + HOUSE_OBJ + "window")
hs.add(10, 2, "prop type=painting action=" + HOUSE_OBJ + "painting")
hs.add(16, 2, "prop type=stairs_up")
hs.add(16, 3, "exit target=floor_06_house_up spawn=from_down unlock_flag=blue_is_hero locked_dialogue=sign6_house_up")
hs.add(15, 4, "spawn id=from_up")
hs.add(4, 4, "prop type=princess_bed action=" + HOUSE_OBJ + "bed")
hs.add(8, 3, "prop type=wardrobe action=" + HOUSE_OBJ + "wardrobe")
hs.add(12, 3, "prop type=bookshelf action=" + HOUSE_OBJ + "bookshelf")
hs.add(14, 5, "prop type=dresser action=" + HOUSE_OBJ + "dresser")
hs.add(9, 7, "prop type=rug")
hs.add(9, 7, "prop type=tea_table action=" + HOUSE_OBJ + "tea")
hs.add(8, 7, "prop type=chair")
hs.add(10, 7, "prop type=chair")
hs.add(3, 10, "prop type=plant action=" + HOUSE_OBJ + "plant")
hs.add(16, 10, "prop type=plant action=" + HOUSE_OBJ + "plant")
hs.add(6, 6, "prop type=candle")
hs.add(13, 9, "prop type=candle")
hs.add(15, 8, "trap type=saddle_bench active=false")
hs.add(15, 8, "prop type=hotspot action=" + HOUSE_OBJ + "saddle")
hs.add(9, 11, "exit target=floor_06_upper spawn=from_house lock_flag=night locked_dialogue=f6_house_door_night")
hs.add(9, 10, "spawn id=from_upper")
hs.add(9, 9, "player")
hs.write()

# —— 家具的调查对话（一个文件，每件家具一个节点；Prop 的 talk:<文件>#<节点>）——
HO = {"name": "", "entries": [{"node": "bed"}], "nodes": {
    "bed": {"goto": [{"if": {"flag": "f6_key"}, "node": "bed_sleep"}, {"if": {"flag": "night"}, "node": "bed_not_yet"}, {"node": "bed_day"}]},
    "bed_day": {"lines": [L("带帷幔的公主床，被子软乎乎的。现在还不困。", "P", "happy")]},
    "bed_not_yet": {"lines": [L("……还睡不着。房间里好像还有什么在意的东西……", "P", "shy")]},
    "bed_sleep": {"lines": [L("……呼啊。好困……今天就睡吧。", "P", "shy")], "set": {"call": "sleep"}},
    "wardrobe": {"lines": [L("衣柜里挂着几件洗得干干净净的裙子……尺寸刚好是我的？她连这个都准备好了。", "P", "surprise")]},
    "bookshelf": {"lines": [L("《地下小镇的历史》《矿道安全守则》《保卫队训练手册》……还有一本《地面上的童话》。", "P"),
                            L("……童话书的书角都翻卷了。她经常看吧。", "P", "shy")]},
    "dresser": {"lines": [L("梳妆台的镜子擦得亮亮的。……头发乱糟糟的，今天被挠了好多次。", "P", "shy")]},
    "tea": {"lines": [L("小圆桌上放着还温热的茶和一碟饼干。", "P", "happy"), L("……好吃！她泡的茶，有一点点花香。", "P", "happy")]},
    "plant": {"lines": [L("盆栽的叶子绿油油的。地底下也能长得这么好啊。", "P")]},
    "window": {"goto": [{"if": {"flag": "night"}, "node": "window_night"}, {"node": "window_day"}]},
    "window_night": {"lines": [L("窗外是小镇的夜色。……地底下也有月亮？原来是矿道顶上发光的石头。", "P", "surprise")]},
    "window_day": {"lines": [L("窗外，小镇已经醒了。远处的矿道口有队员在站岗。", "P")]},
    "painting": {"lines": [L("画里是一片开满花的草地，天空蓝蓝的。……是地面上的风景。", "P", "sad")]},
    # 骑马刷凳：第一次 → 长的小剧场 → 蓝色公主下楼 → 掉出钥匙
    "saddle": {"goto": [{"if": {"flag": "f6_key"}, "node": "saddle_after"}],
               "lines": [L("……房间角落里，怎么会有一张骑马的凳子？凳面上全是刷毛……", "P", "surprise"),
                         L("好像有点像训练营里的那个……只是坐一下的话，应该没关系吧？", "P", "shy")],
               "theater": "f6_house_saddle", "next": "saddle_blue"},
    "saddle_blue": {"cutscene": "f6_blue_quiet", "perform_before": True,
                    "set": {"give_item": {"mystery_key": 1}, "flags": ["f6_key"]},
                    "lines": [L("（获得了「神秘的钥匙」）", "N")]},
    "saddle_after": {"lines": [L("……再也不坐了。绝对不坐了。", "P", "angry")]},
}}
# 蓝色公主当主角时调查楼下的东西：她自己的口吻（剧情标记 blue_is_hero → <家具>_blue）
HO_BLUE = {
    "bed": [L("……她睡过的床。被子没叠。", BLUE), L("……枕头上还有一根粉色的头发。", BLUE)],
    "wardrobe": [L("……给她准备的裙子。只穿了一件。", BLUE)],
    "bookshelf": [L("……《地面上的童话》不在书架上。", BLUE), L("……她带走了。", BLUE)],
    "dresser": [L("……镜子里只有我。", BLUE)],
    "tea": [L("……茶凉了。", BLUE), L("……她说过，很好喝。", BLUE)],
    "plant": [L("……要记得浇水。", BLUE)],
    "window": [L("……矿道口的方向。", BLUE)],
    "painting": [L("……地面上的草地。……她想回去的地方。", BLUE)],
    "saddle": [L("……那张凳子。", BLUE), L("……不坐。", BLUE)],
}
for k, lines in HO_BLUE.items():
    HO["nodes"][k + "_as_blue"] = {"lines": lines}
    HO["nodes"][k]["goto"] = [{"if": {"flag": "blue_is_hero"}, "node": k + "_as_blue"}] + HO["nodes"][k].get("goto", [])
(DLG / "house_objects.json").write_text(json.dumps(HO, ensure_ascii=False, indent="\t") + "\n")

# —— 剧情过场 ——
BLUE_HELLO = "……都问完了？……那，我带你转转。"
TOUR_UPPER = {"name": "参观小镇：集市层", "letterbox": True, "steps": [
    {"actions": [A("fade_out", time=0.4)], "wait": 0.4},
    {"actions": [A("move", who="princess", to=[30, 25]), A("spawn", id="blue", kind="npc:blue_princess", at=[32, 25], dir="left"),
                 A("face", who="princess", dir="right"), A("camera", to=[31, 25]), A("fade_in", time=0.5)], "wait": 0.5},
    line(BLUE, BLUE_HELLO),
    {"actions": [A("camera", to=[11, 23], time=1.0)], "wait": 1.0},
    line(BLUE, "集贸市场。摊位和市场监督那里，可以用金币买东西。……薄荷糖很好用。"),
    {"actions": [A("camera", to=[44, 24], time=1.0)], "wait": 1.0},
    line(BLUE, "篝火广场。在火边坐一会儿，伤会好，笑也会停下来。……主人很爱跳舞，别被拉进去。"),
    {"actions": [A("camera", to=[30, 30], time=0.8)], "wait": 0.8},
    line(BLUE, "那本日记本可以记下你走到哪里了。……整个小镇只有那一本。"),
    {"actions": [A("camera", to=[54, 5], time=1.0)], "wait": 1.0},
    line(BLUE, "北边的铁门通往地面。……一直锁着。"),
    line(P, "通往地面……！", "surprise", [A("bubble", who="princess", kind="surprise")]),
    {"actions": [A("camera", who="princess", time=0.8)], "wait": 0.8},
    line(BLUE, "……下面是保卫队营地。走吧。", actions=[A("face", who="blue", dir="down")]),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.5},
]}
TOUR_CAMP = {"name": "参观小镇：营地层", "letterbox": True, "steps": [
    {"actions": [A("spawn", id="blue", kind="npc:blue_princess", at=[26, 6], dir="left"), A("fade_in", time=0.5)], "wait": 0.5},
    {"actions": [A("camera", to=[26, 13], time=1.0)], "wait": 1.0},
    line(BLUE, "指挥帐篷。队长在那里。……他嘴上凶，人不坏。"),
    {"actions": [A("camera", to=[37, 20], time=1.0)], "wait": 1.0},
    line(BLUE, "训练营。花五个金币就能练——忍痒、耐笑……练出来的本事会一直跟着你。东边那扇门后面是训练迷宫。"),
    line(P, "练、练忍痒……听起来好可怕。", "shy"),
    {"actions": [A("camera", to=[5, 28], time=1.0)], "wait": 1.0},
    line(BLUE, "西南角的楼梯下去是地牢。……你醒来的地方。"),
    {"actions": [A("camera", to=[45, 29], time=1.0)], "wait": 1.0},
    line(BLUE, "东南角下去是矿道。……再往下看看。"),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.5},
]}
TOUR_MINE = {"name": "参观小镇：矿道层", "letterbox": True, "steps": [
    {"actions": [A("spawn", id="blue", kind="npc:blue_princess", at=[7, 27], dir="left"), A("fade_in", time=0.5)], "wait": 0.5},
    {"actions": [A("camera", to=[13, 26], time=1.0)], "wait": 1.0},
    line(BLUE, "矿道。小镇的灯、矿车、……你吃的饼干，都靠这里。"),
    {"actions": [A("camera", to=[40, 8], time=1.4)], "wait": 1.4},
    line(BLUE, "……最深处那扇门。谁也打不开。", actions=[A("face", who="blue", dir="up")]),
    line(P, "那扇门后面有什么？", "question"),
    line(BLUE, "……别靠近它。", actions=[A("bubble", who="blue", kind="dots")]),
    {"actions": [A("camera", who="princess", time=0.8)], "wait": 0.8},
    line(BLUE, "……最后一个地方。跟我来。"),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.5},
]}
TOUR_HOME = {"name": "参观小镇：她的小屋", "letterbox": True, "steps": [
    {"actions": [A("move", who="princess", to=[41, 11]), A("spawn", id="blue", kind="npc:blue_princess", at=[43, 11], dir="up"),
                 A("face", who="princess", dir="up"), A("camera", to=[42, 9]), A("fade_in", time=0.5)], "wait": 0.5},
    line(BLUE, "……到了。我住的地方。"),
    line(P, "好可爱的房子！蓝色的屋顶……和你一样。", "happy", [A("bubble", who="princess", kind="happy")]),
    line(BLUE, "……楼下空着。今晚开始，你住那里。", actions=[A("face", who="blue", dir="left")]),
    line(P, "诶？可、可以吗？", "surprise"),
    line(BLUE, "……嗯。进来吧。", actions=[A("move", who="blue", to=[42, 9], speed=40)]),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.6},
]}
HOUSE_ENTER = {"name": "蓝色小屋：第一个晚上", "letterbox": True, "steps": [
    {"actions": [A("spawn", id="blue", kind="npc:blue_princess", at=[10, 9], dir="left"), A("face", who="princess", dir="right"),
                 A("fade_in", time=0.6)], "wait": 0.6},
    line(P, "哇……帷幔的床、梳妆台、还有书架……这里真的是给我住的？", "surprise", [A("bubble", who="princess", kind="surprise")]),
    line(BLUE, "……以前也有人住过。收拾了一下。"),
    line(P, "……谢谢你。救了我，带我逛了小镇，还给我地方住……", "sad"),
    line(P, "我、我一定会报答你的！等我回到地面上——", "happy"),
    line(BLUE, "……不用。", actions=[A("face", who="blue", dir="up")]),
    line(BLUE, "楼上是我的房间。……别上来。早点睡。"),
    {"actions": [A("move", who="blue", to=[16, 3], speed=40)], "wait": 1.0},
    {"actions": [A("despawn", who="blue"), A("sfx", sound="door_close"), A("set_flag", flag="night")], "wait": 1.4},
    line(P, "……天黑了。外面一下子安静下来。", "sad"),
    line(P, "还睡不着……先在房间里看看吧。", "shy",
         [A("notify", text="夜晚：门锁上了。可以调查房间里的东西（靠近按 E），床可以睡觉。")]),
]}
BLUE_QUIET = {"name": "蓝色小屋：小点声", "letterbox": True, "steps": [
    {"actions": [A("pose", emotion="helpless_1", laugh=60), A("spawn", id="blue", kind="npc:blue_princess", at=[16, 3], dir="down"),
                 A("sfx", sound="door")], "wait": 0.6},
    line(BLUE, "……小点声。", actions=[A("move", who="blue", to=[14, 7], speed=40)]),
    line(P, "呀啊！？对、对不起……我只是好奇坐了一下，它就把我锁住了……", "surprise", [A("bubble", who="princess", kind="surprise")]),
    line(BLUE, "……整栋楼都听见了。", actions=[A("face", who="blue", dir="right")]),
    line(P, "呜……", "shy", [A("pose", emotion="shy", laugh=20)]),
    line(BLUE, "……那张凳子。原来还在这里。", actions=[A("bubble", who="blue", kind="dots")]),
    {"actions": [A("sfx", sound="unlock"), A("shake", time=0.2, strength=1.0), A("bubble", who="princess", kind="question")], "wait": 0.6},
    line(P, "咦？凳子底下的暗格……掉出来一把钥匙。上面刻着……矿道的标记？", "question"),
    line(BLUE, "……", actions=[A("face", who="blue", dir="down")]),
    line(BLUE, "……没什么。早点睡吧。", actions=[A("move", who="blue", to=[16, 3], speed=45)]),
    {"actions": [A("despawn", who="blue")], "wait": 0.8},
    line(P, "……她刚才的表情，好像知道这把钥匙是什么。", "sad"),
]}
MORNING_ESCAPE = {"name": "第二天早上：我要逃离这里", "letterbox": True, "steps": [
    {"actions": [A("pose", emotion="normal", laugh=0)], "wait": 0.3},
    line(P, "……嗯——睡得好香。被子软软的……", "happy"),
    line(P, "……她已经出门了啊。桌上留着早饭。", "shy"),
    line(P, "……", "sad", [A("bubble", who="princess", kind="dots")]),
    line(P, "大家都对我很好。可是……我是公主，我要回到地面上去。", "sad"),
    line(P, "这把钥匙一定能打开矿道最深处那扇门。只要趁巡逻的队员不注意……", "angry"),
    line(P, "……决定了。我要逃离这里！", "angry", [A("set_flag", flag="f6_escape"),
         A("notify", text="目标：去矿道层，避开巡逻队员的视线，用钥匙打开最深处的门")]),
]}
for name, c in (("f6_tour_upper", TOUR_UPPER), ("f6_tour_camp", TOUR_CAMP), ("f6_tour_mine", TOUR_MINE), ("f6_tour_home", TOUR_HOME),
                ("f6_house_enter", HOUSE_ENTER), ("f6_blue_quiet", BLUE_QUIET), ("f6_morning_escape", MORNING_ESCAPE)):
    (CUT / (name + ".json")).write_text(json.dumps(c, ensure_ascii=False, indent="\t") + "\n")

# —— 小剧场：骑马刷凳（主角一个人，长）——
SADDLE_CAST = {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"},
    "saddle": {"kind": "trap:saddle_bench", "at": [0, 18]},
}


def T2(zone, n=6, iv=0.3, fx="lines"):
    return A("tickle", who="princess", by="saddle", repeat=n, interval=iv, fx=fx, zone=zone)


SADDLE = {"name": "蓝色小屋：骑马刷凳", "cast": SADDLE_CAST, "steps": [
    {"actions": [A("fade_in", time=0.6)], "wait": 0.6},
    line(P, "嘿咻……跨上来了。像骑小马一样……有一点点好玩。", "happy", [A("hop", who="princess", count=1)]),
    {"actions": [A("sfx", sound="stocks"), A("shake", who="princess", time=0.3), A("pose", who="princess", visual="surprise")], "wait": 0.5},
    line(P, "……咔哒？诶、诶？腿两边的板子合上了……下、下不来了！", "surprise", [A("bubble", who="princess", kind="surprise")]),
    line(P, "没关系没关系，冷静……找找有没有开关……", "shy"),
    {"actions": [T2("butt", 3, 0.5), A("sfx", sound="swish")], "wait": 1.4},
    line(P, "噗！？刷、刷条动起来了……从屁股底下推过去……", "giggle", [A("pose", who="princess", visual="giggle")]),
    line(P, "不行不行，这里是别人家……而且已经是晚上了，要小声……", "shy", [T2("butt", 4, 0.45)]),
    line(P, "……嗯、嗯唔……忍住……只要不出声就好……", "giggle", [T2("thigh", 4, 0.45)]),
    line(NARR, "（刷条一来一回，慢慢地推过屁股，再从两边扫过分开的大腿内侧）", actions=[T2("butt", 6, 0.35), T2("thigh", 6, 0.38)]),
    line(P, "噗、噗呼……大、大腿里面也……唔嗯嗯……", "giggle", [A("shake", who="princess", time=0.3)]),
    line(P, "（捂住嘴）……嗯——！嗯嗯——！", "giggle", [T2("thigh", 6, 0.3)]),
    line(P, "……刷、刷毛钻到裙子底下了……嗯唔……腿合不上……夹板把大腿分得开开的……", "giggle", [T2("thigh", 6, 0.32)]),
    {"actions": [T2("butt", 8, 0.25), T2("thigh", 8, 0.27), A("pose", who="princess", visual="helpless_1")], "wait": 2.0},
    line(P, "噗哈……！不、不行……越来越快了……哈、哈哈……", "helpless_1", [A("bubble", who="princess", kind="laugh"), A("voice", state="giggle")]),
    line(P, "一挣扎凳子就晃……一晃刷得更快……哈哈……这、这是什么坏凳子啊……！", "helpless_1", [T2("butt", 8, 0.22)]),
    line(P, "小声……要小声……哈、哈哈哈……小声不了啦……！", "helpless_1", [T2("thigh", 8, 0.22), A("shake", who="princess", time=0.4)]),
    line(P, "楼、楼上……会不会被听见……哈哈……要是被她看到这个样子……哈哈哈……", "helpless_1", [T2("butt", 8, 0.22)]),
    line(NARR, "（安静的夜里，只剩下刷条吱呀吱呀的声音，和努力压低却越来越大的笑声）", actions=[T2("butt", 8, 0.25), T2("thigh", 8, 0.25)]),
    {"actions": [A("pose", who="princess", visual="helpless_2"), A("voice", state="laugh"), T2("butt", 10, 0.18), T2("thigh", 10, 0.2)], "wait": 2.0},
    line(P, "哈哈哈哈哈！屁、屁股和大腿一起……放、放我下来哈哈哈哈！", "helpless_2", [A("shake", who="princess", time=0.6)]),
    line(P, "开关在哪里啊哈哈哈哈——！救、救命……不对，不能叫……哈哈哈哈！", "helpless_2", [T2("thigh", 10, 0.18)]),
    line(P, "屁、屁股要被刷平了哈哈哈哈！大腿里面也……一来一回……数、数不清了哈哈哈！", "helpless_2", [T2("butt", 10, 0.18), T2("thigh", 10, 0.2)]),
    line(P, "哈哈……哈……刷条……一来一回……一来……一回……", "helpless_2", [T2("butt", 8, 0.3)]),
    line(NARR, "（不知道过了多久，刷条终于慢了下来。公主伏在凳子上，肩膀还在一抖一抖）", actions=[A("bubble", who="princess", kind="dots"), A("voice", state="")]),
    line(P, "……嘿嘿……小马……跑完了吗……下一站……是哪儿……", "helpless_1"),
    {"actions": [A("fade_out", time=0.8)], "wait": 0.9},
]}
(TH / "f6_house_saddle.json").write_text(_theater_json(SADDLE))
print("第六层后续剧情：小屋地图、家具对话、7 段过场、骑马刷凳小剧场")


# —— 潜入失败：营地地牢的惩罚小剧场（按被抓次数 3 种，越来越重）、蓝色公主来领人、回小屋 ——
def caught_theater(n):
    G1 = G2 = G3 = "保卫队员"
    if n == 1:
        cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
                "cushion": {"kind": "trap:cushion", "at": [0, 18]}, "cuffs": {"kind": "trap:cuffs", "at": [0, 12]},
                "g1": {"kind": "npc:guard", "at": [-30, 6], "dir": "right"}, "g2": {"kind": "npc:guard", "at": [30, 6], "dir": "left"},
                "cap": {"kind": "npc:captain", "at": [64, 0], "dir": "left"}}
        devs = ("cushion", "butt", "cuffs", "armpit")
        lines = [
            line(G1, "队长，矿道最深处抓到的。躲在矿车里，脚还露在外面。"),
            line(CAP, "……露在外面。"),
            line(P, "那、那是因为矿车太小了！不是我躲得不好！", "angry"),
            line(CAP, "嗯。那就从露在外面的地方开始。……先把手铐上。"),
            line(P, "等一下等一下——噗哈哈！腋、腋下……举着手放不下来……！", portrait="defeat_1"),
            line(G1, "坐垫也开了。屁股底下的刷子会一直刷哦。"),
            line(P, "哈哈哈哈！我、我说！我只是想看看那扇门后面……！", portrait="defeat_1"),
            line(CAP, "……那扇门后面不是地面。是比这里更深的地方。"),
            line(P, "更、更深……？哈哈哈……那、那也要去……！"),
            line(G2, "队长，她好像越挠越有精神了。"),
            line(CAP, "……那就挠到没精神为止。"),
            line(P, "哈哈哈哈哈——！不、不是那个意思啊哈哈哈哈！", portrait="defeat_2"),
            line(NARR, "（举手铐柱把双手吊在头顶，坐垫的刷毛不停地刷，两个队员一左一右挠着腋下和腰——地牢里的笑声持续了很久）"),
            line(P, "……哈……哈……下次……下次一定躲好……"),
        ]
    elif n == 2:
        cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
                "stocks": {"kind": "trap:stocks", "at": [0, 19]}, "clamp": {"kind": "trap:clamp", "at": [0, 18]},
                "g1": {"kind": "npc:guard", "at": [-30, 6], "dir": "right"}, "g2": {"kind": "npc:guard", "at": [30, 6], "dir": "left"},
                "g3": {"kind": "npc:guard", "at": [-60, 4], "dir": "right"}, "cap": {"kind": "npc:captain", "at": [64, 0], "dir": "left"}}
        devs = ("stocks", "sole", "clamp", "thigh")
        lines = [
            line(G1, "……又是你啊。这次是在木箱里找到的。"),
            line(G2, "箱子里还有半块面包。她是打算在里面住下吗？"),
            line(P, "那、那是储备粮！潜入是很辛苦的！", "shy"),
            line(CAP, "……足枷。脚心朝外，鞋脱掉。"),
            line(P, "脚、脚心不行！哪里都可以，脚心不——噗哈哈哈哈！", portrait="defeat_1"),
            line(G2, "夹腿枷台也夹上。大腿内侧刚好够得着。"),
            line(P, "哈哈哈哈！大腿也——上、上下一起太过分了哈哈哈哈！", portrait="defeat_1"),
            line(CAP, "钥匙，还在你身上吧。"),
            line(P, "哈哈哈……不、不给……这是我的……哈哈哈！"),
            line(G3, "队长，第三个人也来了。脚趾缝我负责。", actions=[A("enter", who="g3", at=[-44, 12], time=0.4)]),
            line(P, "哈哈哈哈哈！脚、脚趾缝不行——三、三个人……！", portrait="defeat_2"),
            line(CAP, "……钥匙先让你拿着。过了那扇门，就不是我们能保护的地方了。"),
            line(P, "哈哈哈……保、保护……？我才不要被保护……我要回家……哈哈哈哈！", portrait="defeat_2"),
            line(NARR, "（脚心被羽毛和手指来回扫，大腿内侧被夹板的绒毛蹭着——公主的脚趾一会儿蜷起来、一会儿张开，笑声越来越哑）"),
            line(P, "……哈……面、面包……还在箱子里……"),
        ]
    else:
        cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
                "supine": {"kind": "trap:supine", "at": [0, 18]}, "stocks": {"kind": "trap:stocks", "at": [0, 23]},
                "cushion": {"kind": "trap:cushion", "at": [0, 14]},
                "g1": {"kind": "npc:guard", "at": [-30, 6], "dir": "right"}, "g2": {"kind": "npc:guard", "at": [30, 6], "dir": "left"},
                "g3": {"kind": "npc:guard", "at": [-60, 4], "dir": "right"}, "cap": {"kind": "npc:captain", "at": [64, 0], "dir": "left"}}
        devs = ("stocks", "sole", "supine", "waist")
        lines = [
            line(CAP, "第三次了。……巡逻的人都认得你的脚步声了。"),
            line(P, "这、这次只差一点点了！再有一点点就……", "angry"),
            line(G1, "她每次都差一点点。"),
            line(CAP, "刑床、足枷、坐垫，全部用上。……今天我亲自来。"),
            line(P, "队、队长亲自……？等一下，我们可以谈谈——噗哈哈哈哈！", portrait="defeat_1"),
            line(CAP, "腰。……这里最怕吧。", actions=[A("move", who="cap", to=[24, 6], time=0.6)]),
            line(P, "哈哈哈哈哈！最、最怕的地方……为什么会知道啊哈哈哈哈！", portrait="defeat_1"),
            line(G2, "坐垫开到最大。"),
            line(P, "哈哈哈哈哈哈！全、全部一起——不行了不行了不行了哈哈哈哈！", portrait="defeat_2"),
            line(CAP, "……为什么非要出去不可？在这里不好吗？"),
            line(P, "哈哈哈……因、因为……我是公主……哈哈……外面……有在等我的人……哈哈哈哈！", portrait="defeat_2"),
            line(CAP, "……"),
            line(CAP, "……停一下。", actions=[A("face", who="cap", dir="left")]),
            line(G3, "队长？"),
            line(CAP, "……以后再被抓到，就直接放回矿道。……我们也挠累了。"),
            line(NARR, "（刷子停了下来。公主瘫在刑床上大口喘气，眼角还挂着笑出来的泪）"),
            line(P, "……哈……哈……挠、挠累了……嘿嘿……"),
        ]
    d1, z1, d2, z2 = devs
    steps = [{"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5}]
    for i, ln in enumerate(lines):
        acts = list(ln.get("actions", []))
        if ln.get("speaker") == P and i < len(lines) - 1:
            acts += [A("tickle", who="princess", by="g1", repeat=8, interval=0.2, fx="hand", zone=z1 if i % 2 else z2),
                     A("tickle", who="princess", by=d1 if i % 2 else d2, repeat=6, interval=0.28, fx="lines", zone=z1 if i % 2 else z2)]
            if i > len(lines) // 2:
                acts.append(A("tickle", who="princess", by="g2", repeat=8, interval=0.18, fx="hand", zone="waist"))
                acts.append(A("pose", who="princess", visual="helpless_2"))
        steps.append(dict(ln, actions=acts) if acts else ln)
    steps.append({"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7})
    return {"name": "潜入失败的惩罚（第 %d 次）" % n, "cast": cast, "steps": steps}


for n in (1, 2, 3):
    (TH / ("f6_caught_%d.json" % n)).write_text(_theater_json(caught_theater(n)))

# 惩罚之后：公主关在保卫处下面的大牢房里（第六章开头她醒来的那间，摆着刑具），蓝色公主从楼梯下来领人
CELL = [19, 13]
AFTER = {
    1: [("保卫队员", "……你家的。在里面关着呢。"), (BLUE, "……我来接她。"), ("保卫队员", "队长说，下次再跑出去，就加量。"),
        (BLUE, "……知道了。"), (P, "（小声）……加、加量……", "sad")],
    2: [("保卫队员", "啊，又是您。……她刚笑完，腿还软着。"), (BLUE, "……又来接她了。"), (P, "……我、我还能走……", "shy"),
        ("保卫队员", "钥匙队长没收，说让她拿着。……您劝劝她吧。"), (BLUE, "……劝不动。")],
    3: [("保卫队员", "……队长说，以后抓到她就直接放回矿道，不用送来这里了。"), (BLUE, "……最后一次。我来接她。"),
        (P, "最、最后一次……是说他们放弃了吗？", "surprise"), (BLUE, "……是说他们挠累了。")],
}
for n in (1, 2, 3):
    steps = [{"actions": [A("move", who="princess", to=CELL, time=0.0), A("face", who="princess", dir="down"), A("fade_in", time=0.4)], "wait": 0.4},
             {"theater": "f6_caught_%d" % n},
             {"actions": [A("move", who="princess", to=CELL, time=0.0), A("pose", emotion="sad", laugh=30),
                          A("spawn", id="blue", kind="npc:blue_princess", at=[5, 13], dir="right"), A("sfx", sound="door")], "wait": 0.4},
             {"actions": [A("move", who="blue", to=[16, 13], speed=55)]},
             {"actions": [A("face", who="blue", dir="right"), A("face", who="princess", dir="left")], "wait": 0.3}]
    for ln in AFTER[n]:
        steps.append(line(ln[0], ln[1], ln[2] if len(ln) > 2 else None))
    steps += [{"actions": [A("move", who="princess", to=[17, 13], speed=40)]},
              {"actions": [A("fade_out", time=0.6)], "wait": 0.6}]
    cs = {"name": "营地地牢：被抓之后（第 %d 次）" % n, "letterbox": True, "skippable": True, "steps": steps}
    (CUT / ("f6_caught_prison_%d.json" % n)).write_text(json.dumps(cs, ensure_ascii=False, indent="\t") + "\n")

# 第 4 次起：不再关进地牢，士兵象征性地挠一下，直接放回矿道入口（F6Story.on_caught）
CAUGHT_AGAIN = {"name": "矿道：又被抓到了", "letterbox": True, "skippable": True, "steps": [
    line("保卫队员", "……又是你。"),
    line(P, "呜……这次真的只差一点点……", "sad"),
    line("保卫队员", "队长说了，抓到你就放回去。……不过规矩是规矩。", actions=[A("tickle", who="princess", repeat=8, interval=0.2, fx="hand", zone="waist")]),
    line(P, "噗哈哈！腰、腰——好啦好啦我回去就是了哈哈哈！", "giggle", [A("tickle", who="princess", repeat=6, interval=0.2, fx="hand", zone="armpit")]),
    line("保卫队员", "……从入口重新来吧。别再被我看到了。"),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.5},
    # 围上来的两个士兵（f6_caught_grab 生成的 cg1 / cg2）离场
    {"actions": [A("despawn", who="cg1"), A("despawn", who="cg2")], "wait": 0.1},
]}
(CUT / "f6_caught_again.json").write_text(json.dumps(CAUGHT_AGAIN, ensure_ascii=False, indent="\t") + "\n")

CAUGHT_HOME = {"name": "被领回小屋", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("set_flag", flag="night"), A("spawn", id="blue", kind="npc:blue_princess", at=[10, 9], dir="left"),
                 A("face", who="princess", dir="right"), A("fade_in", time=0.6)], "wait": 0.6},
    line(P, "……对不起。又给你添麻烦了。", "sad"),
    line(BLUE, "……"),
    line(BLUE, "……矿道里，灯照不到的地方，他们看不太清。", actions=[A("face", who="blue", dir="up")]),
    line(P, "诶？", "surprise", [A("bubble", who="princess", kind="question")]),
    line(BLUE, "……矿车和木箱里，也能躲。……我什么都没说。早点睡。", actions=[A("move", who="blue", to=[16, 3], speed=45)]),
    {"actions": [A("despawn", who="blue")], "wait": 0.6},
    line(P, "……她是在帮我吗？", "shy"),
]}
MORNING_RETRY = {"name": "第二天早上：再试一次", "letterbox": True, "steps": [
    {"actions": [A("pose", emotion="normal", laugh=0)], "wait": 0.3},
    line(P, "……身上还有点痒痒的。昨天被挠得好惨……", "shy"),
    line(P, "不过——躲在暗处、躲进矿车、丢石子引开他们……这次一定行！", "angry",
         [A("notify", text="目标：去矿道层，避开巡逻队员的视线，用钥匙打开最深处的门（F 丢石子，木箱 / 矿车按 E 躲进去）")]),
]}
for name, c in (("f6_caught_home", CAUGHT_HOME), ("f6_morning_retry", MORNING_RETRY)):
    (CUT / (name + ".json")).write_text(json.dumps(c, ensure_ascii=False, indent="\t") + "\n")
print("潜入失败：惩罚小剧场 3 段、地牢过场 3 段、回小屋、再试一次")


# ================================================================ 第七层前奏：蓝色公主的房间（楼上）、她醒来、出门和队长争吵
# 剧情：粉色公主进了第七层（f7_pink_run）→ 主角换成蓝色公主（blue_is_hero）→ 楼上醒来（f7_blue_wake）→ 出门（f7_blue_argue）→ 第七层
HOUSE_UP_OBJ = "talk:floor_06/house_up_objects#"
hu = Map("floor_06_house_up", 16, 12, "intro =\nintro_cutscene = f7_blue_wake\nambient = 0.82,0.84,0.95\nnight_ambient = 0.34,0.34,0.58")
hu.room(2, 2, 13, 9)
hus = Stack(hu)
for y in range(2, 10):
    for x in range(2, 14):
        hus.add(x, y, "prop type=wood_floor")
hu.torch(8, 1)
hus.add(5, 2, "prop type=window action=" + HOUSE_UP_OBJ + "window")
hus.add(4, 4, "prop type=blue_bed action=" + HOUSE_UP_OBJ + "bed")
hus.add(9, 3, "prop type=bookshelf action=" + HOUSE_UP_OBJ + "bookshelf")
hus.add(8, 7, "prop type=rug")
hus.add(11, 8, "prop type=desk action=" + HOUSE_UP_OBJ + "desk")
hus.add(3, 9, "prop type=plant")
hus.add(7, 5, "prop type=candle")
hus.add(13, 2, "prop type=stairs_down")
hus.add(13, 3, "exit target=floor_06_house spawn=from_up")
hus.add(12, 4, "spawn id=from_down")
hus.add(6, 6, "spawn id=start")
hus.add(6, 6, "player")
hus.write()

HUO = {"name": "", "entries": [{"node": "bed"}], "nodes": {
    "bed": {"lines": [L("……蓝色的被子。叠好了。", BLUE)]},
    "window": {"lines": [L("……矿道口。守门的队员换岗了。", BLUE)]},
    "bookshelf": {"lines": [L("……《地面上的童话》。", BLUE), L("……她也读过这本吗。", BLUE)]},
    "desk": {"lines": [L("……写了一半的信。……不寄了。", BLUE)]},
}}
(DLG / "house_up_objects.json").write_text(json.dumps(HUO, ensure_ascii=False, indent="\t") + "\n")

BLUE_WAKE = {"name": "蓝色公主：楼下没有人", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("pose", emotion="normal", laugh=0), A("fade_in", time=0.6)], "wait": 0.6},
    line(BLUE, "……天亮了。"),
    line(BLUE, "……楼下，太安静了。", actions=[A("face", who="princess", dir="right")]),
    {"actions": [A("fade_out", time=0.5)], "wait": 0.6},
    line(NARR, "（楼下的茶桌上压着一张纸条——「谢谢你这几天的照顾。茶很好喝。我要回地面上去了。——粉色的公主」）"),
    {"actions": [A("fade_in", time=0.5)], "wait": 0.5},
    line(BLUE, "……", actions=[A("bubble", who="princess", kind="dots")]),
    line(BLUE, "……笨蛋。那扇门后面，不是地面。"),
    line(BLUE, "……去找她。", actions=[A("set_flag", flag="f7_blue_awake"),
         A("notify", text="现在操控：蓝色的公主。目标：出门，去矿道最深处")]),
]}
BLUE_ARGUE = {"name": "蓝色公主和队长", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("spawn", id="cap", kind="npc:captain", at=[42, 17], dir="up"), A("camera", to=[42, 12], time=0.6)], "wait": 0.6},
    {"actions": [A("move", who="cap", to=[42, 12], speed=70)]},
    line(CAP, "……您在这里。矿道深处的门被打开了。守门的队员说，看见那个粉色的姑娘往下去了。"),
    line(BLUE, "……我知道。"),
    line(CAP, "您要去？那下面不是您该去的地方。上一次您从那里回来的时候——"),
    line(BLUE, "……队长。"),
    line(CAP, "我是保卫队的队长。保护这个小镇，也包括保护您。……我不能让您下去。", actions=[A("face", who="cap", dir="up")]),
    line(BLUE, "……她一个人。", actions=[A("bubble", who="princess", kind="angry")]),
    line(CAP, "她是自己选择离开的！"),
    line(BLUE, "……所以，我也自己选择。……让开。", actions=[A("move", who="princess", to=[43, 13], time=0.5)]),
    line(CAP, "……", actions=[A("bubble", who="cap", kind="dots")]),
    line(CAP, "……您从小就是这样。说一不二。", actions=[A("face", who="cap", dir="left")]),
    line(CAP, "至少……答应我，一定要回来。两个人一起。"),
    line(BLUE, "……嗯。", actions=[A("move", who="princess", to=[43, 20], speed=60)]),
    {"actions": [A("fade_out", time=0.8), A("set_flag", flag="f7_argue_done")], "wait": 0.9},
]}
for name, c in (("f7_blue_wake", BLUE_WAKE), ("f7_blue_argue", BLUE_ARGUE)):
    (CUT / (name + ".json")).write_text(json.dumps(c, ensure_ascii=False, indent="\t") + "\n")
print("第七层前奏：蓝色公主的房间、醒来、和队长争吵")

