"""生成第六层「地下小镇」：四张地图 + 人物对话 + 过场 + 小剧场。

地图（levels/floor_06_<层>/map.txt，build_level.gd 构建）：
  floor_06_upper  集市层：集贸市场、篝火派对广场、居民区、存档点、封住的地牢入口、去营地的楼梯
  floor_06_camp   营地层：保卫队营地（帐篷、哨塔、训练场）、去集市 / 地牢 / 矿道的楼梯
  floor_06_prison 营地地牢：开场的刑具房（刑床 + 足枷 + 夹腿枷台 → 挠痒坐垫 + 举手铐柱）、牢房、上楼梯
  floor_06_mine   矿道层：矿道、矿车、矿工、封住的深层入口（以后通往新的地牢）
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
for (x, y) in ((12, 26), (22, 20), (30, 12), (40, 15), (14, 8)):
    prop(mine, x, y, "cart")
for (x, y) in ((16, 24), (25, 16), (34, 9), (20, 9)):
    prop(mine, x, y, "crate")
for (x, y) in ((10, 24), (22, 26), (28, 10), (38, 10), (16, 10)):
    prop(mine, x, y, "lamp")
prop(mine, 40, 7, "dungeon_gate")
mine.put(40, 8, "exit target=floor_06_upper locked=true dialogue=sign6_deep")
npc(mine, 30, 15, "miner", "miner_burr", 3)
npc(mine, 14, 26, "miner", "miner_dot", 2)
mine.write()


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
        "training": {"lines": [L("训练场在东南边，木头假人那里。"), L("想练就去找队员。……不过现在场地在整修。")],
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
D["guard_moss"] = chat([L("训练场在整修，别乱跑。")], name="保卫队员莫丝",
    choices=[{"text": "训练什么时候开？", "next": "when", "return": True}, {"text": "再见", "next": "bye"}],
    extra_nodes={"when": {"lines": [L("等假人都换新的。到时候忍痒、挣脱、闪避都能练。")], "set": {"call": "open_training"}},
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
    "sign6_training": [{"speaker": S, "text": "【训练场】在这里可以训练：忍痒、挣脱、闪避……（训练场正在整修）"}],
    "sign6_prison": [{"speaker": S, "text": "【营地地牢】关押违反规矩的人。刑具都收起来了……暂时。"}],
    "sign6_deep": [{"speaker": S, "text": "【矿道深处】封住的大门。门缝里吹出带着甜味的风……门后面好像还有机关在转动的声音。"}],
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
print("过场 2 段，小剧场 4 段")
