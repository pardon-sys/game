"""生成第六层「地下小镇·战时」（levels/floor_06_war）：从第七层归途跑回来时，小镇正被大量怪物袭击。
（和原来的集市广场 floor_06_upper 布局相同、单独一张图；原来的小镇不动。）
  样子：一半房子烧焦冒烟、摊位倒塌、地上零星的小火堆和碎石、路障和沙袋、站岗的守卫；篝火还在，是镇民的避难点。
  出口：从矿洞那边回来的地方（from_ruins，东北角）；通往营地的楼梯被路障封住；蓝色公主的家锁着；
        广场正下方、南边城墙正中间的城门 = 攻防战入口（问「准备好了吗？」→ 出发 → 攻防战 floor_06_siege；回来时到 from_siege）。
  城墙边：冰塔地基（发淡蓝光）、箭塔、路障——调查时有说明（开打时蓝色公主在城墙上造冰塔，粉色公主在前线近战）。
  剧情：进来时的过场 f6w_arrive（有千手痒痒裤时 f6w_arrive_pants，蓝色公主的台词夹着「哈哈哈」，大家觉得奇怪）
        ——队长带着一队士兵过来，关心两人、交代怪物突然变多了、分配任务。
  之后自由操作：
    · 和跟着的那个人说话 → 「换我来」切换操控（data/dialogues/floor_06/war_partner.json，call switch_hero）；地图 no_switch。
    · 镇民 / 守卫的对话按现在操控的人分支（条件 hero: pink / blue），蓝色公主那套有千手痒痒裤的版本。
    · 篝火派对的主人：解锁装备系统（剧情标记 equip_unlocked），送派对彩带蝴蝶结；之后可以在篝火旁休息。
    · 面包店奶奶送冰晶发夹（蓝色公主小时候落下的）、小莉莉送羽毛脚环（装备解锁后）。
    · 市场监督：战时补给站（补给 + 辅助装备，data/shop/war_market.json，call open_war_shop）。
  导演：f6war（levels/floor_06/scripts/war_town.gd）：两个人都设成可以跟随 / 对话切换，进来时放过场。
用法：python tools/build/gen_floor06_war.py，然后 build_level.gd -- floor=floor_06_war
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
FID = "floor_06_war"
P, BLUE, CAP, N = "公主", "蓝色的公主", "保卫队队长", ""
PANTS = "blue_tickle_pants"


class Map:
    def __init__(self, w, h, header):
        self.w, self.h, self.header = w, h, header
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
        out = Path("levels") / FID
        out.mkdir(parents=True, exist_ok=True)
        legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
        head = ("[level]\n# 第六层·地下小镇·战时（tools/build/gen_floor06_war.py 生成，不要直接改）\n" + self.header +
                "\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n")
        (out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
        print("%s：%dx%d，图例 %d 种" % (FID, self.w, self.h, len(specs)))


def npc(m, x, y, nid, file, wander=0, extra=""):
    m.put(x, y, ("npc id=%s dialogue=floor_06/%s wander=%s %s" % (nid, file, wander, extra)).strip())


def prop(m, x, y, kind, action=""):
    m.put(x, y, "prop type=%s%s" % (kind, (" action=" + action) if action else ""))


OBJ = "talk:floor_06/war_objects#"

# ================================================================ 地图（和集市广场一样大、一样的布局）
m = Map(64, 46, "intro =\nambient = 0.5,0.38,0.36\nno_switch = true")
m.room(2, 2, 61, 43)
for x in (8, 20, 32, 44, 56):
    m.put(x, 1, "torch lit=true")
# 从矿洞那边跑回来的地方（东北角，地牢入口开着）
prop(m, 54, 4, "dungeon_gate")
m.put(54, 5, "exit target=floor_06_mine locked=true dialogue=f6w_gate_back")
m.put(54, 7, "spawn id=from_ruins")
m.put(54, 8, "player")
m.put(55, 8, "blue_princess follow=true ai=false")
m.put(52, 9, "f6war")
# 居民区：一半烧焦
for i, x in enumerate((8, 16, 24, 32)):
    prop(m, x, 8, ("house_burnt_%d" % (i // 2)) if i % 2 == 0 else "house_%d" % i)
for (x, y) in ((12, 11), (20, 12), (28, 11)):
    prop(m, x, y, "rubble")
prop(m, 42, 8, "house_blue")
m.put(42, 9, "exit target=floor_06_house locked=true dialogue=f6w_house_locked")
# 集贸市场：两个摊位塌了，剩下的是补给站
for row, y in enumerate((19, 26)):
    for i, x in enumerate((7, 11, 15)):
        if (row, i) in ((0, 1), (1, 2)):
            prop(m, x, y, "stall_broken")
        else:
            prop(m, x, y, "stall_%d" % ((i + row) % 3), "shop:war_market")
for y in (22, 23):
    prop(m, 4, y, "crate")
# 篝火：镇民的避难点
prop(m, 44, 24, "bonfire_0", "heal")
for (x, y) in ((40, 21), (48, 21), (40, 27), (48, 27)):
    prop(m, x, y, "bench")
for (x, y) in ((37, 24), (51, 24)):
    prop(m, x, y, "lamp")
prop(m, 30, 18, "well")
m.put(30, 30, "savepoint place=战时的广场")
# 零星的小火堆
for (x, y) in ((20, 15), (10, 30), (35, 13), (52, 33), (17, 37), (58, 18), (26, 22)):
    prop(m, x, y, "fire_small")
# 通往营地的楼梯被路障封住
prop(m, 59, 40, "stairs_down")
prop(m, 58, 38, "barricade")
prop(m, 60, 37, "sandbag")
m.put(57, 40, "sign dialogue=f6w_camp_blocked")
# 南边城墙：路障、沙袋、冰塔地基、箭塔；正中间是城门（攻防战入口）
for x in range(2, 62):
    m.g[41][x] = "#"          # 南边城墙（整面封死；城门在墙前正中间）
for x in (8, 16, 24, 40, 48, 56):
    prop(m, x, 39, "barricade" if x % 16 == 8 else "sandbag")
for (x, y) in ((12, 37), (22, 37), (42, 37), (52, 37)):
    prop(m, x, y, "tower_base", OBJ + "tower_base")
for (x, y) in ((27, 38), (37, 38)):
    prop(m, x, y, "tower", OBJ + "arrow_tower")
prop(m, 32, 40, "dungeon_gate", "talk:floor_06/war_gate#gate")
m.put(32, 38, "spawn id=from_siege")
for x in (29, 35):
    prop(m, x, 40, "lamp")
# 人物（队长在过场之后才出现）
npc(m, 34, 29, "captain", "war_captain", 0, "show_flag=f6w_arrived dir=down")
npc(m, 12, 23, "supervisor", "war_supervisor", 0, "dir=down")
npc(m, 46, 24, "bonfire_host", "war_bonfire_host", 0)
npc(m, 42, 25, "granny", "war_granny", 0, "dir=right")
npc(m, 46, 27, "kid", "war_kid_tom", 1)
npc(m, 42, 22, "kid", "war_kid_lily", 1)
npc(m, 48, 25, "maid", "war_maid", 0, "dir=left")
npc(m, 8, 24, "merchant", "war_merchant", 1)
npc(m, 32, 36, "miner", "war_engineer", 1)
# 站岗的守卫（10 个）
GUARDS = [(29, 38, "war_guard_gate", "down"), (35, 38, "war_guard_gate2", "down"), (10, 38, "war_guard_wall_w", "down"),
          (54, 38, "war_guard_wall_e", "down"), (56, 39, "war_guard_camp", "right"), (52, 6, "war_guard_ruins", "up"),
          (40, 10, "war_guard_house", "down"), (18, 24, "war_guard_market", "left"), (28, 30, "war_guard_plaza", "right"),
          (44, 31, "war_guard_bonfire", "up")]
for (x, y, f, d) in GUARDS:
    npc(m, x, y, "guard", f, 0, "dir=" + d)
# 脏乱的地面：焦痕、灰烬、泥脚印、碎木、稻草、积水、碎瓷片、破布（地面贴花，不挡路）；火堆和烧焦的房子周围更密
import random
rnd = random.Random(606)
HOT = [(20, 15), (10, 30), (35, 13), (52, 33), (17, 37), (58, 18), (26, 22), (8, 9), (24, 9), (11, 19), (15, 26)]
NEAR_HOT = ["decal_scorch_0", "decal_scorch_1", "decal_ash_0", "decal_ash_1", "decal_splinters_0"]
ANY = ["decal_footprints_0", "decal_straw_0", "decal_puddle_0", "decal_shards_0", "decal_rag_0", "decal_ash_1", "decal_scorch_1",
       "decal_splinters_0"]


def free(x, y):
    if not (3 <= x <= 60 and 3 <= y <= 39) or m.g[y][x] != ".":
        return False
    return all((x + dx, y + dy) not in m.cells for dx in (-1, 0, 1) for dy in (-1, 0, 1))


placed = 0
for (hx, hy) in HOT:
    for _ in range(5):
        x, y = hx + rnd.randint(-3, 3), hy + rnd.randint(-2, 3)
        if free(x, y):
            prop(m, x, y, rnd.choice(NEAR_HOT))
            placed += 1
tries = 0
while placed < 120 and tries < 4000:
    tries += 1
    x, y = rnd.randint(3, 60), rnd.randint(3, 39)
    if free(x, y):
        prop(m, x, y, rnd.choice(ANY))
        placed += 1
m.write()
Path("levels/%s/design.json" % FID).write_text(json.dumps({"_说明": [
    "地下小镇·战时（gen_floor06_war.py 生成）：防卫战的准备阶段。城门（32,42）是攻防战入口（地图之后再做）。"]},
    ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 对话
def L(text, speaker=None, emotion=None, npc_id=None):
    d = {"text": text}
    if speaker is not None:
        d["speaker"] = speaker
    if emotion:
        d["emotion"] = emotion
    if npc_id:
        d["npc"] = npc_id
    return d


def split(name, npc_id, pink, blue, blue_pants=None, extra_nodes=None, hub=None):
    """一个人物：按现在操控的人分支（pink / blue；蓝色公主有千手痒痒裤时 blue_pants）。"""
    entries = []
    nodes = {}
    if blue_pants:
        entries.append({"if": {"hero": "blue", "flag": PANTS}, "node": "blue_pants"})
        nodes["blue_pants"] = {"lines": blue_pants}
    entries += [{"if": {"hero": "blue"}, "node": "blue"}, {"node": "pink"}]
    nodes["blue"] = {"lines": blue}
    nodes["pink"] = {"lines": pink}
    if hub:
        for k in ("blue", "pink", "blue_pants"):
            if k in nodes:
                nodes[k]["next"] = hub
    if extra_nodes:
        nodes.update(extra_nodes)
    d = {"name": name, "entries": entries, "nodes": nodes}
    if npc_id:
        d["npc"] = npc_id
    return d


D = {}
# —— 和跟着的那个人说话：换人 / 聊两句
D["war_partner"] = {
    "name": "", "entries": [{"if": {"hero": "pink"}, "node": "to_blue"}, {"node": "to_pink"}],
    "nodes": {
        "to_blue": {"lines": [L("……嗯？", BLUE)], "goto": [{"if": {"flag": PANTS}, "node": "to_blue_pants"}], "next": "blue_menu"},
        "to_blue_pants": {"lines": [L("……嗯？……哈、哈……没事。", BLUE, "shy")], "next": "blue_menu"},
        "blue_menu": {"prompt": "……要换我来吗？", "choices": [
            {"text": "换你来（操控蓝色的公主）", "next": "swap_to_blue"},
            {"text": "聊两句", "next": "chat_blue", "return": True},
            {"text": "没什么", "next": ""}]},
        "swap_to_blue": {"lines": [L("……交给我。城墙那边，我去看看。", BLUE)], "set": {"call": "switch_hero"}},
        "chat_blue": {"goto": [{"if": {"flag": PANTS}, "node": "chat_blue_pants"}],
                      "lines": [L("……怪物变多了。……感觉，和我有关。", BLUE, "sad"),
                                L("和你有关？怎么会！", P, "surprise"),
                                L("……没什么。……别担心。", BLUE)]},
        "chat_blue_pants": {"lines": [L("……怪物变多了。……感觉，和我有关。……哈、哈……", BLUE, "sad"),
                                      L("你、你又在笑……到底怎么了嘛？", P, "surprise"),
                                      L("……腿……不、没事。……别看。", BLUE, "shy")]},
        "to_pink": {"lines": [L("嗯？怎么啦？", P, "happy")], "next": "pink_menu"},
        "pink_menu": {"prompt": "要换我来吗？", "choices": [
            {"text": "换你来（操控公主）", "next": "swap_to_pink"},
            {"text": "聊两句", "next": "chat_pink", "return": True},
            {"text": "没什么", "next": ""}]},
        "swap_to_pink": {"lines": [L("交给我吧！前线那边我去转一圈！", P, "happy")], "set": {"call": "switch_hero"}},
        "chat_pink": {"goto": [{"if": {"flag": PANTS}, "node": "chat_pink_pants"}],
                      "lines": [L("你说，那些怪物到底在找什么呢？", P),
                                L("……不知道。", BLUE),
                                L("不管找什么，我们一起把它们赶回去！", P, "happy")]},
        "chat_pink_pants": {"lines": [L("你说，那些怪物到底在找什么呢？", P),
                                      L("……不、不知道。……哈。", BLUE, "shy"),
                                      L("……你的腿是不是不舒服？一直在抖。", P, "surprise"),
                                      L("……没有。……走路，走多了。", BLUE)]},
    },
}
# —— 队长
D["war_captain"] = split(CAP, "captain",
    pink=[L("你负责前线。怪物从城门外涌进来的时候，帮我们把它们打散。"),
          L("别逞强。被缠住了就喊人，队员们会去拉你。")],
    blue=[L("城墙上交给你了。冰塔的地基已经打好，开打的时候就在那里造塔。"),
          L("攻击用的冰塔、拖慢它们的冰塔……你比我清楚怎么用。")],
    blue_pants=[L("城墙上交给你了。冰塔的地基已经打好——"),
                L("……哈、哈哈……知、知道了。", BLUE, "shy"),
                L("……你今天怎么回事？从刚才开始就一直在笑。"),
                L("……没有。……继续说。", BLUE, "angry"),
                L("……咳。攻击用的冰塔、拖慢它们的冰塔，你自己看着造。")],
    hub="hub",
    extra_nodes={"hub": {"prompt": "还有什么要问的？", "choices": [
        {"text": "怪物从哪里来的？", "next": "where", "return": True},
        {"text": "镇上的人都还好吗？", "next": "people", "return": True},
        {"text": "没有了", "next": "bye"}]},
        "where": {"lines": [L("从下面的矿道、还有远处的裂缝里一起涌上来。"),
                            L("怪的是……它们不抢东西，也不追人。好像在找什么。")]},
        "people": {"lines": [L("能跑的都躲到篝火那边了。烧掉的房子以后再盖。"),
                             L("人没事就好。")]},
        "bye": {"lines": [L("准备好了就去南边的城门。")]}})
# —— 市场监督：补给站
D["war_supervisor"] = split("市场监督", "supervisor",
    pink=[L("账本都烧掉一半了……算了，先顾眼前。"), L("补给、护具，要什么自己挑，打完再算钱。……不对，钱还是要收的。")],
    blue=[L("城墙上的？你要补给的话，薄荷糖和清心花露都有。"), L("……护具也有几件，看你需不需要。")],
    blue_pants=[L("城墙上的？你要补给的话——"), L("……噗。", BLUE, "shy"), L("……你笑什么？我账本算错了吗？"),
                L("……没有。……买东西。", BLUE)],
    hub="shop",
    extra_nodes={"shop": {"lines": [L("看看吧。")], "set": {"call": "open_war_shop"}}})
# —— 篝火派对的主人：解锁装备
D["war_bonfire_host"] = {
    "name": "篝火派对的主人", "npc": "bonfire_host",
    "entries": [{"if": {"not": "equip_unlocked"}, "node": "unlock"}, {"node": "hub"}],
    "nodes": {
        "unlock": {"lines": [L("哎呀，你们回来啦！派对是开不成了，篝火倒是还烧着。"),
                             L("对了对了——我本来在准备下次派对的「挠痒大赛」，做了好多比赛用的护具和小装饰。"),
                             L("护腋的垫子、厚袜子、舞鞋……有的能挡挠痒，有的让人跑得快，代价嘛……穿上就知道啦。"),
                             L("都挂到补给站卖了。这个送你们——派对的彩带蝴蝶结，系在腰上，戴着心情就好！"),
                             L("……就是上面的小铃铛有点吵。嘿嘿。"),
                             L("（之后可以在背包的「装备」页给两个人换装备）", N)],
                   "set": {"flags": ["equip_unlocked"], "give_item": {"equip_party_bow": 1}}, "next": "hub_after_unlock"},
        "hub_after_unlock": {"lines": [L("每个怕痒的地方都能穿一件。两个人各穿各的哦！")], "next": "hub"},
        "hub": {"prompt": "要做什么？", "choices": [
            {"text": "在篝火旁休息一下（护具的次数也会恢复）", "next": "rest", "return": True},
            {"text": "装备是怎么回事？", "next": "about", "return": True},
            {"text": "再见", "next": "bye"}]},
        "rest": {"lines": [L("坐吧，坐吧。护垫我帮你拍蓬一点。")], "set": {"call": "rest"}},
        "about": {"lines": [L("脚心、腋下、腰、脖子、肚子、胸、大腿、屁股——每个地方都能穿一件。"),
                            L("有的能挡几下挠痒，用完了在篝火这儿休息一下就恢复。"),
                            L("有的让人更敏感，但是跑得快、打得狠……挑适合自己的吧！")]},
        "bye": {"lines": [L("冷了就回来烤火！")]},
    },
}
# —— 面包店奶奶：冰晶发夹
D["war_granny"] = split("面包店的奶奶", None,
    pink=[L("孩子，你们回来就好。店烧了，饼干也没了……"), L("等打完了，奶奶再给你烤。")],
    blue=[L("……是你呀。长这么大了。"), L("等一下……奶奶有样东西，一直替你收着。")],
    blue_pants=[L("……是你呀。长这么大了。"), L("……哈、哈……奶、奶奶好。", BLUE, "shy"),
                L("怎么了？笑得这么开心？"), L("……没、没有。", BLUE), L("等一下……奶奶有样东西，一直替你收着。")],
    extra_nodes={
        "hairpin": {"lines": [L("你小时候落在店里的雪花发夹。别在头发上，冻冻的，你最喜欢了。"),
                              L("……", BLUE, "sad"), L("……谢谢。", BLUE, "shy"),
                              L("（得到了冰晶发夹——蓝色的公主专用的装备）", N)],
                    "set": {"flags": ["f6w_hairpin"], "give_item": {"equip_ice_hairpin": 1}}},
    })
# 装备解锁后、蓝色公主第一次来：先寒暄，再送发夹
D["war_granny"]["nodes"]["hairpin"]["lines"] = [L("……是你呀。长这么大了。"), L("等一下……奶奶有样东西，一直替你收着。")] + \
    D["war_granny"]["nodes"]["hairpin"]["lines"]
D["war_granny"]["entries"].insert(0, {"if": {"hero": "blue", "not": "f6w_hairpin", "flag": "equip_unlocked"}, "node": "hairpin"})
# —— 小孩
D["war_kid_tom"] = split("小汤姆", None,
    pink=[L("姐姐！我刚才看到怪物了！好大一只，被队员叔叔打跑了！"), L("姐姐你要去打怪物吗？加油！")],
    blue=[L("冰的姐姐！可以变冰给我看吗？"), L("……现在不行。……打完了，变一个大的。", BLUE)],
    blue_pants=[L("冰的姐姐！可以变冰给我看吗？"), L("……现在不、不行……哈……", BLUE, "shy"),
                L("姐姐你在笑！姐姐笑起来好奇怪！"), L("……不准说。", BLUE, "angry")])
D["war_kid_lily"] = split("小莉莉", None,
    pink=[L("姐姐……怪物会不会打进来？"), L("……嗯！我相信姐姐！")],
    blue=[L("冰的姐姐……怪物好可怕。"), L("……我会守住。", BLUE)],
    blue_pants=[L("冰的姐姐……怪物好可怕。"), L("……我、我会守住。……噗。", BLUE, "shy"), L("……姐姐？")],
    extra_nodes={
        "anklet": {"lines": [L("这个给你！我和汤姆用羽毛编的脚环，戴上就能跑得像风一样快！"),
                             L("……就是羽毛会蹭到脚心，有一点点痒。嘻嘻。"),
                             L("（得到了羽毛脚环）", N)],
                   "set": {"flags": ["f6w_anklet"], "give_item": {"equip_feather_anklet": 1}}},
    })
# 装备解锁后第一次来：送羽毛脚环
D["war_kid_lily"]["entries"].insert(0, {"if": {"not": "f6w_anklet", "flag": "equip_unlocked"}, "node": "anklet"})
D["war_maid"] = split("女仆", None,
    pink=[L("公主殿下！您没事真是太好了。"), L("前线危险，请务必小心……被抓住了的话，那些怪物可是会一直挠的。")],
    blue=[L("……您是城墙上的那位吧。"), L("我在这里帮忙照顾受伤的队员。冰塔的光，从这里也能看到呢。")],
    blue_pants=[L("……您是城墙上的那位吧。"), L("……哈。……嗯。", BLUE, "shy"),
                L("……您的脸好红。是不是发烧了？要不要躺一下？"), L("……不用。……没事。", BLUE)])
D["war_merchant"] = split("水果摊的商贩", None,
    pink=[L("摊子还剩一半！今天的水果……都被怪物踩烂啦。"), L("等打完了，请你吃最甜的苹果！")],
    blue=[L("城墙上冷吧？等打完了，给你留最冰的西瓜。"), L("……嗯。", BLUE)],
    blue_pants=[L("城墙上冷吧？等打完了——"), L("……哈、哈哈……", BLUE, "shy"), L("我、我还没说笑话呢？")])
D["war_engineer"] = split("工匠", None,
    pink=[L("前线的路障是我钉的，结实着呢！"), L("怪物冲过来的时候，你就站在路障后面打。被围住了就往回退。")],
    blue=[L("冰塔的地基打好了四座。开打的时候，你往上面放冰就行。"), L("攻击的那种、减速的那种……你自己搭配。")],
    blue_pants=[L("冰塔的地基打好了四座——"), L("……噗。", BLUE, "shy"), L("……我说错什么了吗？"),
                L("……没有。……继续。", BLUE)])
GUARD_LINES = {
    "war_guard_gate": ("守城门的队员", ["城门后面就是前线。准备好了再出去。"], ["城墙的楼梯在城门两边。冰塔的位置，工匠会告诉你。"]),
    "war_guard_gate2": ("守城门的队员", ["第一波怪物就是从这道门冲进来的。差一点就守不住了。"], ["上次第一波，城墙上没人……这次有你在，就不一样了。"]),
    "war_guard_wall_w": ("城墙上的队员", ["墙外面全是爪印。它们还会回来的。"], ["西边的冰塔地基离城门最近。先在那里造塔吧。"]),
    "war_guard_wall_e": ("城墙上的队员", ["东边的路障快撑不住了，前线的人要多注意。"], ["东边的冰塔地基能看到整条前线。"]),
    "war_guard_camp": ("守路障的队员", ["营地那边的路被封住了，现在出不去。"], ["营地的楼梯封住了。……有事去找队长。"]),
    "war_guard_ruins": ("守矿道口的队员", ["你们就是从矿道那边跑回来的吧？那边暂时安全。"], ["矿道里也有怪物的脚印……一直通到很深的地方。"]),
    "war_guard_house": ("守民居的队员", ["这一排房子烧掉了两间。还好人都跑出来了。"], ["……那是你家吧？门我替你锁好了，没被烧到。"]),
    "war_guard_market": ("守集市的队员", ["补给站还开着，去看看吧。"], ["补给站有薄荷糖。城墙上冷，多带几颗。"]),
    "war_guard_plaza": ("巡逻的队员", ["队长在广场中间。有不懂的就去问他。"], ["队长说城墙交给你。……我们都很放心。"]),
    "war_guard_bonfire": ("守篝火的队员", ["大家都躲在篝火边。有我在，怪物过不来。"], ["派对的主人在给大家分热汤。你也去喝一口吧。"]),
}
for f, (name, pink, blue) in GUARD_LINES.items():
    D[f] = split(name, None, pink=[L(t) for t in pink], blue=[L(t) for t in blue],
                 blue_pants=[L(blue[0]), L("……哈、哈……知、知道了。", BLUE, "shy"), L("……？你没事吧？")])
# —— 城门：攻防战入口
D["war_gate"] = {"name": "城门", "entries": [{"node": "gate"}], "nodes": {
    "gate": {"lines": [L("（城门外就是前线。怪物的叫声从远处传过来）", N)], "prompt": "准备好了吗？",
             "choices": [{"text": "出发！", "next": "go"}, {"text": "再准备一下", "next": ""}]},
    "go": {"lines": [L("（两个人推开城门——）", N)], "set": {"flags": ["f6w_ready"], "call": "go_siege"}},
}}
# —— 可以调查的东西
D["war_objects"] = {"name": "", "entries": [{"node": "tower_base"}], "nodes": {
    "tower_base": {"lines": [L("（打好的冰塔地基。石头圈里嵌着一块淡蓝色的冰晶，摸上去凉凉的）", N),
                             L("（等开打的时候，蓝色的公主会在这里造冰塔：攻击用的、拖慢怪物用的……）", N)]},
    "arrow_tower": {"lines": [L("（木头搭的箭塔。上面堆着一捆捆的箭）", N),
                              L("（开打的时候，队员们会在上面放箭。前线的人要注意别站在箭雨下面）", N)]},
}}
dlg = Path("data/dialogues/floor_06")
for name, d in D.items():
    (dlg / (name + ".json")).write_text(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")
# 招牌 / 门的台词（signs.json 里追加）
signs_path = dlg / "signs.json"
signs = json.loads(signs_path.read_text())
signs.update({
    "f6w_gate_back": [{"speaker": N, "text": "（矿道里黑漆漆的。现在不是回去的时候）"}],
    "f6w_house_locked": [{"speaker": N, "text": "（门锁着。守卫的队员替她锁好的）"}],
    "f6w_camp_blocked": [{"speaker": "告示", "text": "【封锁】通往营地的路暂时封住。有事请找保卫队队长。"}],
})
signs_path.write_text(json.dumps(signs, ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 过场：队长带着士兵过来
def A(do, **kw):
    kw["do"] = do
    return kw


def line(sp, text, emotion=None, actions=None, npc_id=None):
    s = {"speaker": sp, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    if npc_id:
        s["npc"] = npc_id
    return s


BLUE_NPC = "BluePrincess_55_8"
SOLDIERS = ["s1", "s2", "s3", "s4", "s5"]


def arrive(pants):
    steps = [
        {"actions": [A("fade_out", time=0.0), A("move", who="princess", to=[42, 30]), A("move", who=BLUE_NPC, to=[44, 30]),
                     A("face", who="princess", dir="left"), A("face", who=BLUE_NPC, dir="left"),
                     A("camera", to=[38, 30], zoom=1.25, time=0.1)], "wait": 0.2},
        {"actions": [A("fade_in", time=1.0), A("sfx", sound="rumble", volume=-6.0)], "wait": 0.8},
        line(N, "（跑回广场的时候，小镇已经变了样：房子烧掉了好几间，到处是碎石和还没熄灭的小火堆）"),
        line(P, "怎么会……这样……", "sad"),
        {"actions": [A("spawn", id="cap", kind="npc:captain", at=[24, 30], dir="right")]
         + [A("spawn", id=s, kind="npc:guard", at=[22 - (i % 2) * 2, 28 + i], dir="right") for i, s in enumerate(SOLDIERS)]
         + [A("move", who="cap", to=[37, 30], speed=60)]
         + [A("move", who=s, to=[34 - (i % 2) * 2, 28 + i], speed=60) for i, s in enumerate(SOLDIERS)], "wait": 2.0},
        line(CAP, "找到了！你们两个——可算回来了！", None, None, "captain"),
        line(CAP, "去哪儿了？一整晚都没见人影。没受伤吧？", None, None, "captain"),
        {"actions": [A("face", who="princess", dir="right"), A("bubble", who="princess", kind="shy")], "wait": 0.5},
        line(P, "没……没发生什么……", "shy"),
        line(P, "……真的，什么都没有……", "shy"),
    ]
    if pants:
        steps += [
            line(BLUE, "……说正事。……哈。", None, [A("bubble", who=BLUE_NPC, kind="sweat")]),
            line(CAP, "……？你刚才是不是笑了？", None, None, "captain"),
            line("保卫队员", "（小声）……蓝色的那位，在笑？"),
            line(BLUE, "……没有。……继续说。", "angry"),
        ]
    else:
        steps += [line(BLUE, "……说正事。", "angry")]
    steps += [
        line(CAP, "……好。", None, None, "captain"),
        line(CAP, "不知道怎么回事，昨天夜里，怪物突然变多了。", None, None, "captain"),
        {"actions": [A("bubble", who=BLUE_NPC, kind="dots")], "wait": 0.6},
        line(BLUE, "……", "sad"),
        line(CAP, "从矿道、从远处的裂缝……一起涌上来，直接冲到了镇上。", None, None, "captain"),
        line(CAP, "怪的是，它们不抢东西，也不追人——好像在找什么。", None, None, "captain"),
        line(CAP, "第一波已经挡下来了。可是看样子，后面还会有更多。", None, None, "captain"),
    ]
    if pants:
        steps += [
            line(BLUE, "……更、更多……哈、哈哈……", "shy", [A("shake", time=0.3)]),
            line(CAP, "……你到底在笑什么？", None, None, "captain"),
            line(P, "她、她今天一直这样……", "surprise"),
            line(BLUE, "……腿……不。……没事。……说下去。", "angry"),
        ]
    steps += [
        line(CAP, "所以我需要你们两个帮忙。", None, None, "captain"),
        line(CAP, "蓝色的——你上城墙。冰塔的地基已经打好了，开打的时候在上面造塔，从远处打。", None, None, "captain"),
        line(CAP, "粉色的——你在前线。怪物冲进来的时候，帮队员们把它们打散。", None, None, "captain"),
        line(P, "交给我吧！", "happy"),
        line(BLUE, "……嗯。", None),
        line(CAP, "趁现在，去补给站补点东西，跟大家说说话。准备好了，就去南边的城门。", None, None, "captain"),
        line(CAP, "……还有。你们两个，别分开。", None, None, "captain"),
        {"actions": [A("despawn", who="cap")] + [A("despawn", who=s) for s in SOLDIERS] + [A("set_flag", flag="f6w_arrived"),
                     A("camera", reset=True, time=0.6), A("hint", text="和跟着的那个人说话，可以换人操控")], "wait": 0.7},
    ]
    return {"name": "地下小镇·战时", "letterbox": True, "skippable": True, "steps": steps}


cut = Path("data/cutscenes/floor_06")
for cid, pants in {"f6w_arrive": False, "f6w_arrive_pants": True}.items():
    (cut / (cid + ".json")).write_text(json.dumps(arrive(pants), ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
if not any(f["id"] == FID for f in lst):
    i = next(i for i, f in enumerate(lst) if f["id"] == "floor_07_return") + 1
    lst.insert(i, {"id": FID, "name": "地下小镇·战时", "scene": "res://levels/%s/floor.tscn" % FID, "group": "floor_06", "music": "town"})
    Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("对话 %d 个文件、过场 2 段" % len(D))
