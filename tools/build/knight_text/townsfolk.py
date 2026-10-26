"""骑士篇三张小镇图上镇民的对话（data/dialogues/floor_06/after_k_*.json 白天、after_kn_*.json 夜里）和调查道具（after_k_objects）。身上不挂委托。
骑士篇的步骤（vars.knight_step = STEP_IDS 的下标，和 KnightStory.STEPS 一一对应，测试会核对）：
  第一天早上 found（和地牢入口的队员说话才开始）→ wake（工房）→ 下午 afternoon（自由活动，床上休息到晚上）
  → 夜里 bait（调查广场上暗掉的灯笼）→ sneak（调查营地楼梯的路障）→ cell（地牢里）→ sleep（回小屋睡觉）
  → 第二天早上 report（和营地楼梯口的队员说话）→ chase → boss。追逃那张图上没有镇民。
主线触发：这一步要说话的人 / 调查的道具，对话最前面插一句（条件 eq knight_step = 下标），set {call: knight_go}。
白天（floor_06_knight_day）：found 之前「东北角出事了」/ 抬回工房以后「那个骑士」/ 第二天早上「昨晚的灯笼」。
夜里（floor_06_knight_night）：以笑为饵之前「广场上怪怪的」/ 之后「笑声被偷走了」。
"""
from after_text.common import N, P, L, BLUE

STEP = "knight_step"
STEP_IDS = ["found", "wake", "afternoon", "bait", "sneak", "cell", "sleep", "report", "chase", "boss"]


def idx(step_id):
    return STEP_IDS.index(step_id)


def step_ge(n):
    return {"var": {STEP: [">=", n]}}


def step_is(step_id):
    return {"eq": {STEP: idx(step_id)}}


def talk(name, npc, *tiers):
    """tiers：(从哪一步起, 台词) 从晚到早排；最后一档是最早的话（从哪一步起写 None）。"""
    entries, nodes = [], {}
    for i, (at, lines) in enumerate(tiers):
        key = "t%d" % i
        entries.append({"if": step_ge(idx(at)), "node": key} if at else {"node": key})
        nodes[key] = {"lines": lines}
    return {"name": name, "npc": npc, "entries": entries, "nodes": nodes}


def trigger(d, step_id, lines):
    """主线触发：这一步和他说话时先说 lines，然后开演（KnightStory.go）。"""
    d["entries"].insert(0, {"if": step_is(step_id), "node": "go"})
    d["nodes"]["go"] = {"lines": lines, "set": {"call": "knight_go"}}
    return d


DAY = {
    "after_k_captain": talk("保卫队队长", "captain",
                            ("report", [L("……你们来了。"), L("昨晚的事，我听说了。……先别说，楼梯口那边有人在等你们。")]),
                            ("wake", [L("……那个骑士，在工房里。"), L("他醒来以后说的话——别往心里去。"), L("……也别一个人去找他。")]),
                            (None, [L("……来了。"), L("地牢入口那边。别磨蹭。")])),
    "after_k_guard_gate": talk("保卫队员", "guard",
                               ("report", [L("听说昨晚广场的灯笼全暗了，又全亮了？"), L("……我睡得太死，什么都没看见。")]),
                               ("wake", [L("听说那个骑士一醒过来就骂人了？"), L("……盔甲上还有手印在爬，我可不敢靠近。")]),
                               (None, [L("队长一早就去东北角了，脸色可难看了。")])),
    "after_k_guard_gate2": talk("保卫队员", "guard",
                                ("wake", [L("城门今天不开。队长的命令。")]),
                                (None, [L("东北角的地牢入口，好像出事了。……不是咱们镇上的事。")])),
    "after_k_granny": talk("面包店奶奶", "granny",
                           ("report", [L("昨晚……奶奶的笑声，是你们帮忙找回来的吧。"), L("拿着，刚烤好的。……路上小心。")]),
                           ("wake", [L("那个孩子……被抬过去的时候，奶奶看了一眼。"), L("盔甲上的花纹，奶奶年轻的时候好像在哪里见过。"),
                                     L("……是在哪里呢。老了，记不清了。")]),
                           (None, [L("昨晚的饼干还剩一些，要不要带着？"), L("东北角那边……吵吵嚷嚷的，出什么事了？")])),
    "after_k_merchant": talk("商人", "merchant",
                             ("wake", [L("一个骑士，从地牢里爬出来？"), L("……这种事，摊子上可不卖。")]),
                             (None, [L("一大早的，保卫队就跑来跑去。出什么事了？")])),
    "after_k_engineer": talk("工匠", "miner",
                             ("report", [L("营地底下……一整夜都有铁链在响。"), L("我躺在床上听了半宿。……那不是锁着的人能弄出来的声音。")]),
                             ("wake", [L("那套盔甲，做工是真的好。"), L("……可是我看了半天，看不出是哪里打的。不是这附近的手艺。")]),
                             (None, [L("地牢入口那边的门，昨天晚上还是钉死的。……今天早上，钉子掉了一地。")])),
    "after_k_maid": talk("女仆", "maid",
                         ("wake", [L("咕咕今天一直对着工房叫。"), L("……动物比人先知道不对劲。")]),
                         (None, [L("咕咕一直对着东北角叫，怎么都哄不好。")])),
    "after_k_mayor": talk("镇长", "mayor",
                          ("wake", [L("……骑士。"), L("这座镇子，很久很久没有见过骑士了。"), L("（镇长望着工房的方向，好久没有说话）", N)]),
                          (None, [L("庆功宴才刚过，东北角就……唉。"), L("你们要是闲着，去那边看看吧。")])),
    "after_k_kids": talk("小孩们", "kid",
                         ("wake", [L("姐姐！听说工房里有个骑士！会不会是来抓坏人的！"), L("……他好像把我当坏人了。", P, "sad")]),
                         (None, [L("姐姐！东北角好多保卫队的叔叔！")])),
    # 主线触发的两个人
    "after_k_guard_dungeon": trigger(talk("保卫队员", "guard",
                                          ("wake", [L("……担架上那些手印，到现在还在我眼前爬。")]),
                                          (None, [L("……")])), "found",
                                     [L("啊——你们来得正好！"), L("地牢入口那边……倒着一个人！穿着盔甲，怎么叫都叫不醒。"),
                                      L("队长让我守在这儿，看见你们就带过去。"), L("……一个人？在地牢门口？", P, "surprise")]),
    "after_k_guard_camp": trigger(talk("保卫队员", "guard",
                                       ("report", [L("……")]),
                                       (None, [L("营地的楼梯在整修，不能下去。"), L("……尤其是今天。队长特意交代的。")])), "report",
                                  [L("你们来找队长？他在下面巡查，一会儿就上来。"), L("……昨晚地牢里一直有声音。铁链响了一夜。"),
                                   L("我也有事要跟他说。……关于那个骑士。", P, "sad")]),
}

NIGHT = {
    "after_kn_captain": talk("保卫队队长", "captain",
                             ("sneak", [L("……收进瓶子里的手印，我会锁起来。"), L("回去睡觉。今晚别再出门了。")]),
                             (None, [L("……广场上的手印，你也看见了。"), L("别逞强。")])),
    "after_kn_mayor": talk("镇长", "mayor",
                           ("sneak", [L("笑声……回来了。"), L("谢谢你们。……可是那些手印，到底是从哪里来的呢。")]),
                           (None, [L("……大家都不笑了。笑声像是被什么偷走了一样。"), L("那边那盏灯笼……刚才还亮着的。")])),
    "after_kn_granny": talk("面包店奶奶", "granny",
                            ("sneak", [L("哈……奶奶刚才想笑，笑不出来。现在好了，好了。")]),
                            (None, [L("……奶奶刚才明明想笑，嘴巴张开了，可是一点声音都没有。")])),
    "after_kn_merchant": talk("商人", "merchant",
                              ("sneak", [L("我的笑声回来了！哈哈！哈哈哈！……咳，太久没笑，嗓子有点哑。")]),
                              (None, [L("……（他张着嘴，像是在笑，却一点声音都没有）")])),
    "after_kn_engineer": talk("工匠", "miner",
                              ("sneak", [L("那些手印……是从工房那个方向爬过来的。"), L("……我什么都没说。")]),
                              (None, [L("别过来！你脚边……有手印在爬！")])),
    "after_kn_maid": talk("女仆", "maid",
                          ("sneak", [L("……多谢。"), L("（她轻轻地笑了一下，好像在确认自己的声音还在）", N)]),
                          (None, [L("……我的声音。……我刚才笑了，可是听不见。")])),
    "after_kn_supervisor": talk("市场监督", "supervisor",
                                ("sneak", [L("宵禁之后还在外面晃……算了，今晚记你们一功。")]),
                                (None, [L("夜里不许在广场上聚集。……可是大家都吓得不敢回家。")])),
    "after_kn_tom": talk("小汤姆", "kid",
                         ("sneak", [L("姐姐好厉害！一下子就把手印全抓住了！"), L("……被手印挠的样子也好好笑。")]),
                         (None, [L("姐姐……我刚才笑了，可是没有声音……好可怕……")])),
    "after_kn_lily": talk("小莉莉", "kid",
                          ("sneak", [L("莉莉的笑声回来了～嘿嘿～")]),
                          (None, [L("（小莉莉紧紧抓着你的裙角，一句话也不说）", N)])),
}

# 调查道具（小镇图上 prop action=talk:floor_06/after_k_objects#<节点>）：这一步要调查它时开演，平时只是看一眼
OBJECTS = {
    "name": "", "entries": [{"node": "lantern"}],
    "nodes": {
        "lantern": {"goto": [{"if": step_is("bait"), "node": "lantern_go"}], "lines": [L("（一盏笑声灯笼，静静地亮着）", N)]},
        "lantern_go": {"lines": [L("（灯笼里的光一点一点暗了下去。灯罩上，贴着一个紫色的小手印——它在吸灯里的笑声）", N),
                                 L("……这是什么？", P, "surprise"), L("……别碰。", BLUE)],
                       "set": {"call": "knight_go"}},
        "vent": {"goto": [{"if": step_is("sneak"), "node": "vent_go"}], "lines": [L("（营地楼梯的路障。……木板后面好像有一道缝，有风吹出来）", N)]},
        "vent_go": {"lines": [L("（蓝色公主蹲下来，摸到路障最下面那块木板，轻轻一推——木板松了，后面露出一道窄窄的通风口）", N)],
                    "set": {"call": "knight_go"}},
    },
}

DIALOGUES = dict(DAY, **NIGHT, after_k_objects=OBJECTS)
