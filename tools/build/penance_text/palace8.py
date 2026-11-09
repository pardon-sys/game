"""反省篇第四章·旧王宫的追加事件（第五批，和剧情有关的跨图事件）：
乳母的日记（浴场 / 厨房 / 婴儿房三页 → 后花园秋千上哼那首歌）、女王的首饰盒（隧道寝室；浴场池底 / 衣帽间礼服领口 / 后花园喷泉三颗宝石）、
人偶们的记忆（发条钥匙给糕点师 / 守钟人偶 / 搓澡人偶上弦 → 三段互相矛盾的「那天晚上」）、
女王的生日宴（前厅西南的小宴会厅：蛋糕 / 花束 / 八音盒 / 茶具 → 人偶们的庆祝派对，CG）。
只给线索、不说破：不暗示派对主人；不碰时间能力、怀表、钟停。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, line, pose, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo
from . import palace6, palace7

HEADMAID = "女仆长"
CHEF = "糕点师人偶"
KEEPER_DOLL = "守钟人偶"
SCRUB = "搓澡人偶"
DOLLS = "人偶们"

TEXT = {
    "gem_bubble": ["泡、泡泡钻进衣服里了——！", "……泡泡。……托着宝石。……好痒。"],
    "gem_gown": ["人、人台抓住手腕了——！", "……人台。……在挠。"],
    "gem_spray": ["水又喷到脚底了——！", "……喷泉。……宝石在水里。"],
    "doll_spring": ["发、发条弹到腰上了！", "……发条。……弹了一下。"],
}

# ---------------------------------------------------------------- 乳母的日记
DIARY = {
    1: ("婴儿房摇篮底下的日记", "「……两个小殿下今天又抢同一个摇篮。爱哭的那个怕黑，夜里一定要留一盏灯……」"),
    2: ("浴场柜子里的日记", "「……洗澡的时候，爱笑的那个总把泡泡吹到爱哭的那个脸上。然后两个人一起笑……」"),
    3: ("厨房碗柜里的日记", "「……只有爱笑的那个唱那首歌，爱哭的那个才睡得着。我唱不行，陛下唱也不行。……真奇怪」"),
}


def _diary(i):
    name, text = DIARY[i]
    return dfile("", name, {
        "default": {"lines": [L("（一页从日记本上撕下来的纸，字迹很温柔。署名是「乳母」）", N), L(text, N)],
                    "set": {"flags": ["palace_diary_%d" % i], "call": "palace_diary_page"}, "next": "check"},
        # 三页齐了：拼起来读一遍
        "check": {"goto": [{"if": {"flag": ["palace_diary_1", "palace_diary_2", "palace_diary_3"], "not": "palace_diary_done"}, "node": "all"}]},
        "all": {"lines": DIARY_ALL, "set": {"flags": ["palace_diary_done"]}},
        "done": {"lines": [L("（这里已经没有别的了）", N)]},
    }, entries=[{"if": {"flag": "palace_diary_%d" % i}, "node": "done"}, {"node": "default"}])


DIARY_ALL = [L("（三页日记拼在一起——）", N)] + [L(DIARY[i][1], N) for i in (1, 2, 3)] + [
    L("……爱笑的那个，唱那首歌。", P, "sad"),
    L("……婴儿房吊铃的那首。……你，会哼吧。", BLUE),
    L("……嗯。不知道为什么……一听就会。", P),
    L("……后花园的秋千。……乳母说，她们总在那里睡午觉。", BLUE),
]

# ---------------------------------------------------------------- 女王的首饰盒
JEWEL_BOX = dfile("", "女王的首饰盒", {
    "default": {"lines": [L("（梳妆台上放着一只玫瑰木的首饰盒。盒盖上有三个空着的小圆槽——红的、蓝的、黄的）", N),
                          L("……少了三颗宝石。……一颗在水里，一颗在衣服上，一颗在花里。", BLUE)]},
    "open": {"lines": [L("（三颗宝石嵌进盒盖，「咔哒」——首饰盒自己打开了）", N),
                       L("（天鹅绒的内衬上，压着一个钥匙形状的空位。钥匙已经不在了。空位旁边，有一张折起来的小纸条）", N),
                       L("「交给能守住门的那个孩子」", N),
                       L("……钥匙。", P, "surprise"),
                       L("……………", BLUE),
                       L("……你怎么了？", P),
                       L("……没什么。……只是，好像在哪里，听过这句话。", BLUE)], "set": {"call": "palace_jewel_open"}},
    "done": {"lines": [L("（首饰盒开着。钥匙形状的空位，还是空的）", N)]},
}, entries=[{"if": {"flag": "palace_jewel_done"}, "node": "done"},
            {"if": {"flag": ["palace_gem_ruby", "palace_gem_sapphire", "palace_gem_topaz"]}, "node": "open"}, {"node": "default"}])


def _gem(key, name, look, grab, call):
    return dfile("", name, {
        "default": {"lines": [L(look, N)], "prompt": "伸手去拿？", "choices": [{"text": "拿", "next": "go"}, {"text": "算了", "next": "no"}]},
        "go": {"lines": [L(grab, N)], "set": {"call": call}},
        "no": {"lines": [L("……等一下。", P)]},
        "done": {"lines": [L("（这里已经空了）", N)]},
    }, entries=[{"if": {"flag": "palace_gem_" + key}, "node": "done"}, {"node": "default"}])


# ---------------------------------------------------------------- 人偶们的记忆（发条钥匙上弦）
MEMORY = {
    "chef": (CHEF, "（糕点台边上，那个举着打蛋器的糕点师人偶停住了。背后的发条孔，和女仆长的一模一样）",
             ["……那天晚上。……两个小殿下，溜进厨房，偷蛋糕。", "……一个笑，一个哭。……笑的那个，把蛋糕分了一半，给哭的那个。",
              "……然后，钟响了。……我就，停了。"]),
    "keeper": (KEEPER_DOLL, "（钟顶的角落里，守钟人偶靠着墙一动不动。背后的发条孔里积满了灰）",
               ["……那天晚上，钟，敲了十三下。", "……有一个人，从钟楼上，下来了。……抱着，什么东西。……很小，很小。",
                "……我看不清，是谁。……天太黑了。"]),
    "scrub": (SCRUB, "（浴场里，那个被打倒的搓澡人偶坐在泡泡桶边上，发条孔朝着天）",
              ["……那天晚上？……浴室，没有人来。", "……一个都，没有。……泡泡，凉了一整夜。",
               "……真奇怪。……小殿下们，每天晚上，都要来洗澡的。"]),
}


def _memory(key):
    who, look, words = MEMORY[key]
    return dfile("", who, {
        "default": {"lines": [L(look, N)], "prompt": "用女仆长借给你们的发条钥匙给它上弦？",
                    "choices": [{"text": "上弦", "next": "go", "if": {"flag": "palace_headmaid_friend"}}, {"text": "算了", "next": "no"}]},
        "go": {"lines": [L("……慢慢转。", BLUE)], "set": {"call": "palace_wind_" + key}, "next": "talk"},
        "talk": {"lines": [L(w, who) for w in words] + [L("（说完，它又慢慢地停了下来）", N)]},
        "no": {"lines": [L("……发条孔，和女仆长背后的一模一样。……先和她打好关系，也许能借到钥匙。", BLUE)]},
        "done": {"lines": [L("（%s安安静静地停着。发条已经松了）" % who, N)]},
    }, entries=[{"if": {"flag": "palace_memory_" + key}, "node": "done"}, {"node": "default"}])


# ---------------------------------------------------------------- 女王的生日宴
BANQUET_KEYS = ["cake", "flower", "box", "tea"]
BANQUET = dfile("", "小宴会厅的长桌", {
    "default": {"lines": [L("（一张铺着蕾丝桌布的长桌。主位是一张高高的椅子，两边各一张小小的椅子）", N),
                          L("（小椅子前面的名牌，字都被磨掉了。主位的名牌上写着：「陛下」）", N),
                          L("（桌上压着一张发黄的布置清单：「蛋糕 · 花 · 八音盒 · 茶具——陛下的生日，要瞒着陛下准备好」）", N)],
                "next": "place"},
    "place": {"set": {"call": "palace_banquet_place"}, "next": "check"},
    "check": {"goto": [{"if": {"flag": ["palace_banquet_" + k for k in BANQUET_KEYS]}, "node": "ready"}]},
    "ready": {"lines": [L("（蛋糕、花束、八音盒、茶具——四样东西都摆好了。烛台自己亮了起来）", N),
                        L("……都齐了。", P, "happy"),
                        L("……门外。……有脚步声。……很多。", BLUE)], "theater": "queen_birthday", "next": "reward"},
    "reward": {"set": {"call": "palace_banquet_done"},
               "lines": [L("（女仆长留下的生日缎带，绣着「给陛下」三个字。……系在身上，暖暖的）", N)]},
    "done": {"lines": [L("（长桌上的蜡烛还亮着。三张椅子，一张高，两张小，都空着）", N)]},
}, entries=[{"if": {"flag": "palace_banquet_done"}, "node": "done"}, {"node": "default"}])


DIALOGUES = {
    "diary_1": _diary(1), "diary_2": _diary(2), "diary_3": _diary(3),
    "tunnel_jewel_box": JEWEL_BOX,
    "gem_ruby": _gem("ruby", "泡泡池底的红宝石", "（泡泡池的池底，一颗红宝石被一串泡泡托着，在水里一闪一闪）",
                     "（手刚伸进池子，一大串泡泡就「咕噜咕噜」地顺着胳膊钻进了袖子里——）", "palace_gem_ruby"),
    "gem_sapphire": _gem("sapphire", "礼服领口的蓝宝石", "（一件蓝色的小礼服领口上，别着一颗蓝宝石。穿着礼服的人台，手里攥着软尺）",
                         "（手指刚碰到宝石，人台的两只手就「咔」地抱了上来，软尺在腰上缠了一圈——）", "palace_gem_sapphire"),
    "gem_topaz": _gem("topaz", "喷泉里的黄宝石", "（水流进喷泉以后，池底露出了一颗黄宝石，被小天使的水柱冲得一闪一闪）",
                      "（伸手去捞的时候，三尊小天使的水柱一起转了过来——）", "palace_gem_topaz"),
    "memory_chef": _memory("chef"), "memory_keeper": _memory("keeper"), "memory_scrub": _memory("scrub"),
    "headmaid_memories": dfile("", HEADMAID, {"default": {"lines": [
        L("……三个人偶，说的，都不一样。", HEADMAID),
        L("……一个说，小殿下们在厨房。……一个说，有人从钟楼下来。……一个说，谁都没有来。", HEADMAID),
        L("……………", HEADMAID),
        L("……那天晚上。……我，在哪里呢。", HEADMAID),
        L("……女仆长？", P),
        L("……我想不起来。……发条，只记得，转到那一下为止的事。", HEADMAID)]}}),
    "banquet_table": BANQUET,
    "servants_tea_set": dfile("", "休息室的茶具", {
        "default": {"lines": [L("（休息室的小柜子里收着一套瓷茶具：一把茶壶，三只茶杯。茶托上贴着女仆长的字条：「陛下的生日用」）", N),
                              L("……三只杯子。……借走了。", BLUE)], "set": {"give_item": {"tea_set": 1}, "flags": ["palace_tea_taken"]}},
        "done": {"lines": [L("（柜子空了）", N)]},
    }, entries=[{"if": {"flag": "palace_tea_taken"}, "node": "done"}, {"node": "default"}]),
}

# ================================================================ 乳母的歌（后花园秋千上哼那首歌）
SONG = theater("后花园：秋千上的摇篮曲", _duo("normal", "normal", v1={"kind": "trap:feather_curtain", "at": [-20, -10]},
                                          v2={"kind": "trap:feather_curtain", "at": [20, -10]}), [
    say(N, "（两个人并排坐在秋千上。粉色公主轻轻地哼起了那首歌——婴儿房吊铃的曲子）", act=1),
    say(P, "……啦……啦啦……"),
    say(N, "（没有人推，秋千自己慢慢地荡了起来。一下，又一下，像有人在后面轻轻地推）"),
    say(BLUE, "……秋千。……自己在动。"),
    say(N, "（藤蔓也跟着曲子的拍子垂下来，叶尖一下、一下地，扫过两个人晃在半空的脚心）",
        [tk("v1", zone="sole", fx="leaf", n=8, iv=0.18), _bt(8, 0.18, by="v2", zone="sole", fx="leaf"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "嘻……！不、不要跟着拍子挠……我要唱不下去了……", emotion="giggle"),
    say(BLUE, "……继续唱。……停下来，它挠得更厉害。"),
    cg(say(N, "（歌声断断续续，夹着越来越大的笑声。秋千越荡越高，藤蔓卷着叶子钻进脚趾缝、爬上小腿，在膝盖后面打转）",
           [tk("v1", zone="sole", fx="leaf", n=14, iv=0.09), _bt(14, 0.09, by="v2", zone="knee", fx="leaf"), pose("helpless_2"), _bp("helpless_2")], act=3)),
    say(P, "啦、啦——哈哈哈！啦啦——哈哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……哈、哈哈……这首歌……原来，是这样唱的……"),
    _burst_pink("（星光跟着最后一个音符炸开，藤蔓「哗」地缩回了架子上……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，秋千的绳子结了一层薄霜……）"),
    say(N, "（秋千慢慢停下来。最后一片叶子，在两人刚释放完、敏感得要命的脚心上，轻轻地、像哄睡一样地拍了两下）",
        [tk("v1", zone="sole", fx="leaf", n=4, iv=0.25), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……", emotion="helpless_1"),
    say(BLUE, "……睡着了吗。……那个，怕黑的孩子。", [pose("normal"), _bp("normal")]),
    say(P, "……嗯。一定睡着了。", emotion="sad"),
])

# ================================================================ 女王的生日宴（CG：queen_birthday）
BIRTHDAY = theater("小宴会厅：陛下的生日宴", _duo("normal", "normal", d1={"kind": "trap:feather_curtain", "at": [-24, -8]},
                                             d2={"kind": "trap:feather_curtain", "at": [24, -8]}), [
    say(N, "（宴会厅的门「吱呀」一声开了。女仆长、糕点师、守钟人偶、搓澡人偶、舞会人偶、还有花园的小店主——一个接一个地走了进来）", act=1),
    say(HEADMAID, "……陛下的生日。……准备好了。……谢谢。"),
    say(DOLLS, "（齐声）……生日，快乐。"),
    say(P, "……可是，陛下不在这里……", emotion="sad"),
    say(HEADMAID, "……所以。……今天，请两位，坐在小殿下们的位置上。"),
    say(N, "（人偶们把两个人按在长凳上，脚搁到天鹅绒的脚凳上，鞋子被小心地脱下来摆好——）", [pose("normal"), _bp("normal")], act=2),
    say(HEADMAID, "……陛下的生日，规矩是。……大家一起，笑。"),
    say(N, "（羽毛掸子从左右两边伸过来，在腰和腋下轻轻地挠；脚凳边上，两个女仆人偶拿着软毛刷，一下一下地刷着脚心）",
        [tk("d1", zone="waist", fx="feather", n=8, iv=0.16), _bt(8, 0.16, by="d2", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(P, "嘻嘻……！这、这个规矩……哈哈……", emotion="giggle"),
    say(BLUE, "……哈……人、人太多了……"),
    cg(say(N, "（糕点师举着蛋糕在旁边转圈，花精撒着花瓣，舞会人偶戴着尖尖的派对帽——所有人偶都围了上来，羽毛、刷子、小手，一起挠）",
           [tk("d1", zone="sole", fx="hand", n=16, iv=0.08), _bt(16, 0.08, by="d2", zone="waist", fx="hand"), pose("helpless_2"), _bp("helpless_2")], act=3)),
    say(P, "哈哈哈哈！生、生日快乐——生日快乐啦——哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……哈哈……哈哈哈……生日……快乐……"),
    say(HEADMAID, "……对。……就是这个声音。……陛下，最喜欢的。"),
    _burst_pink("（星光在宴会厅里炸开，烛火一下子全亮了起来……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，落在蛋糕上，变成了糖霜一样的小雪花……）"),
    say(N, "（人偶们安静下来。最后，小花精踮着脚，用一片花瓣在两人刚释放完、敏感得要命的脚心上，轻轻地写了一个「谢」字）",
        [tk("d1", zone="sole", fx="leaf", n=5, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……谢、谢什么呀……", emotion="helpless_1"),
    say(HEADMAID, "……谢谢，让这张桌子，再热闹一次。", [pose("normal"), _bp("normal")]),
    say(N, "（女仆长把一条缎带放到两个人手里。那是一条很旧的生日缎带，绣着「给陛下」三个字）"),
    say(BLUE, "……三张椅子。……一张高的，两张小的。"),
    say(P, "……嗯。", emotion="sad"),
])

THEATERS = {"garden_swing_song": SONG, "queen_birthday": BIRTHDAY}
CUTSCENES = {}


# ================================================================ 给前几批对话接上新线（import 时直接改它们的字典）
# 冷藏库的生日蛋糕：融开以后可以带走（宴会要用）
_cake = palace6.DIALOGUES["kitchen_ice_cake"]
_cake["nodes"]["card"]["next"] = "take"
_cake["nodes"]["take"] = {"lines": [L("……这个蛋糕。……带上吧。也许，有人在等它。", BLUE)],
                          "set": {"give_item": {"birthday_cake": 1}, "flags": ["palace_cake_taken"]}}
_cake["entries"].insert(0, {"if": {"flag": "palace_ice_cake", "not": "palace_cake_taken"}, "node": "take"})
# 女仆长：三个人偶的话都听完了 → 她想起来（又想不起来）
_maid = palace6.DIALOGUES["servants_wind_maid"]
_maid["nodes"]["memories"] = {"lines": [
    L("……三个人偶，说的，都不一样。", HEADMAID),
    L("……一个说，小殿下们在厨房。……一个说，有人从钟楼下来。……一个说，谁都没有来。", HEADMAID),
    L("……………", HEADMAID),
    L("……那天晚上。……我，在哪里呢。", HEADMAID),
    L("……女仆长？", P),
    L("……我想不起来。……发条，只记得，转到那一下为止的事。", HEADMAID)], "set": {"flags": ["palace_headmaid_memories"]}}
_maid["entries"].insert(0, {"if": {"flag": "palace_memories_done", "not": "palace_headmaid_memories"}, "node": "memories"})
# 花园小店主：浇过花以后送一束花（宴会要用）
_keeper = palace7.DIALOGUES["garden_keeper"]
_keeper["nodes"]["bouquet"] = {"lines": [L("对了对了！这个送给你们——前厅那边的小宴会厅，以前每年都要摆花的！", "花园小店主"),
                                         L("（一束铃兰和蔷薇，系着粉色的缎带）", N)],
                               "set": {"give_item": {"bouquet": 1}, "flags": ["palace_bouquet_taken"]}}
_keeper["nodes"]["clue"]["next"] = "bouquet"
_keeper["entries"][0] = {"if": {"flag": ["palace_keeper_done", "palace_bouquet_taken"]}, "node": "done"}
_keeper["entries"].insert(1, {"if": {"flag": "palace_keeper_done"}, "node": "bouquet"})
# 双人秋千：日记三页齐了 → 可以「哼那首歌」
_swing = palace7.DIALOGUES["garden_swing"]
_song = {"text": "哼那首歌", "next": "song", "if": {"flag": "palace_diary_done", "not": "cg_seen_theater:garden_swing_song"}}
_swing["nodes"]["default"]["choices"].insert(0, _song)
_swing["nodes"]["song"] = {"lines": [L("……乳母日记里的那首。……我们一起坐上去吧。", P)], "theater": "garden_swing_song"}
_swing["nodes"]["again"]["prompt"] = "……"
_swing["nodes"]["again"]["choices"] = [_song, {"text": "走开", "next": ""}]
