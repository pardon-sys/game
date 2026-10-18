"""七日赎罪的弥补任务：过场（开场 / 收尾）和失败小剧场（data/theater/after/after_fail_*.json）。
  d2_equip   痒痒装备回收（第 2 天下午，补给站）：after_d2_equip / after_d2_equip_done，失败 after_fail_equip
  d3_cart    拆除哑火的攻城车（第 3 天下午，城门外的战场）：after_d3_cart / after_d3_cart_done（剧情碎片：队长的「花猫样」口误），失败 after_fail_cart
             队长那句口误是用户给定的台词，不要改。
"""
from .common import A, BLUE, BLUE_NODE as B, CAP, N, P, line

SUP = "市场监督"


# ---------------------------------------------------------------- 痒痒装备回收
def d2_equip():
    s = [
        {"actions": [A("face", who="after_supervisor", dir="right"), A("camera", to=[13, 25], zoom=1.0, time=0.5)], "wait": 0.5},
        line(SUP, "来了？正好。攻防战的时候，裁缝铺的痒痒装备被怪物撒得满镇都是。"),
        line(SUP, "一共八件。你去收回来，送到我这里。"),
        line(P, "捡起来送过来就行吧？这个简单！", "happy"),
        line(SUP, "……这些装备有个小毛病。被人拿起来，就会自己穿到身上去。"),
        line(P, "……什么？！", "surprise"),
        line(SUP, "而且同一个地方只能穿一件。脚上已经有一件，再捡一件脚上的，旧的那件就会掉下来。"),
        line(SUP, "所以——自己想好路线，多跑几趟。送到我这里，我帮你卸下来。"),
        line(P, "……这哪里简单了……", "sad"),
        line(SUP, "还有，那群小鬼头今天下午正闲着。你身上叮叮当当、扭来扭去的，他们准会凑过来。"),
        line(BLUE, "……小心。……那几个，很会挠。", None, [A("face", who=B, dir="left")]),
        line(N, "（笑得太厉害就去长椅上歇歇脚，或者到井边洗把脸。被小孩缠住了，按 J 挣扎、E 哄走、冲刺甩掉）"),
        {"actions": [A("camera", reset=True, time=0.5)], "wait": 0.5},
    ]
    return {"name": "痒痒装备回收", "letterbox": True, "skippable": True, "steps": s}


def d2_equip_done():
    s = [
        {"actions": [A("face", who="after_supervisor", dir="right"), A("camera", to=[13, 25], zoom=1.0, time=0.5)], "wait": 0.5},
        line(SUP, "……六、七、八。一件不少。"),
        line(SUP, "说实话，我以为你会在半路上笑倒呢。"),
        line(P, "……差、差一点……脚底板到现在还在痒……", "shy"),
        line(BLUE, "……刷套那件，……你穿着跳了三下。……我看见了。"),
        line(P, "看见了就当没看见！！", "angry"),
        line(SUP, "工时我记上了。……晚上早点回去休息吧。"),
        {"actions": [A("camera", reset=True, time=0.5)], "wait": 0.5},
    ]
    return {"name": "装备送回去了", "letterbox": True, "skippable": True, "steps": s}


# ---------------------------------------------------------------- 拆除哑火的攻城车
def d3_cart():
    s = [
        {"actions": [A("fade_out", time=0.0), A("move", who="princess", to=[21, 5]), A("move", who=B, to=[22.5, 5]),
                     A("spawn", id="cap", kind="npc:captain", at=[19.5, 6], dir="right"), A("camera", to=[21, 8], zoom=0.9, time=0.1)], "wait": 0.2},
        {"actions": [A("fade_in", time=0.8), A("sfx", sound="wind", volume=-10.0)], "wait": 0.8},
        line(N, "（城门外的战场。泡泡、羽毛、倒下的敌塔……收拾到一半的残骸还堆得到处都是）"),
        line(CAP, "看见那三辆攻城车了吗。打到最后没油了，就停在那儿——睡着了。", None, None, "captain"),
        line(P, "睡、睡着了……？车也会睡觉吗？", "surprise"),
        line(CAP, "这些家伙会。车灯还在一下一下地扫，一被照到、或者脚步太响，就会醒。", None, None, "captain"),
        line(CAP, "醒了会怎么样，你在攻防战上见过。……车斗里是什么，你也知道。", None, None, "captain"),
        line(P, "……刷、刷子……", "sad"),
        line(CAP, "从车尾绕过去，把车轴拆下来，它就再也动不了。别冲刺，别进车灯里。", None, None, "captain"),
        line(BLUE, "……我可以冻住车轮。……冻着的时候，车灯不扫。"),
        line(CAP, "……殿下，冻太久的话，那条裤子会——", None, None, "captain"),
        line(BLUE, "……知道。……我会小心。", None, [A("bubble", who=B, kind="dots")]),
        line(N, "（按 C 换成蓝色公主，靠近车按住技能键冻住车轮。冻得越久，千手痒痒裤的反弹条越满）"),
        {"actions": [A("move", who="cap", to=[19.5, 3], speed=50), A("camera", reset=True, time=0.5)], "wait": 0.6},
        {"actions": [A("despawn", who="cap")], "wait": 0.1},
    ]
    return {"name": "拆除哑火的攻城车", "letterbox": True, "skippable": True, "steps": s}


def d3_cart_done():
    s = [
        {"actions": [A("camera", to=[21, 8], zoom=1.0, time=0.5), A("spawn", id="cap", kind="npc:captain", at=[21, 3], dir="down"),
                     A("move", who="cap", to=[21, 6.5], speed=50)], "wait": 1.0},
        line(N, "（最后一根车轴「哐当」一声掉在地上。她从车底下爬出来，脸上、手上全是黑乎乎的车油）"),
        line(P, "呼……三辆……全拆完了……", "happy"),
        line(CAP, "……干得不错。", None, [A("face", who="cap", dir="down")], "captain"),
        line(N, "（队长从怀里掏出一块手帕，很自然地递了过来）"),
        line(CAP, "擦擦吧，你小时候只要一赌气去钻管道，出来也是这副花猫样……", None, None, "captain"),
        {"actions": [A("bubble", who="cap", kind="dots")], "wait": 0.9},
        line(N, "（话说到一半，队长愣住了）"),
        line(P, "……小时候？", "surprise", [A("bubble", who="princess", kind="question")]),
        line(N, "（队长看了她一眼——那眼神很复杂，像是想说什么，又硬生生咽了回去）"),
        line(CAP, "……认错人了。手帕不用还。", None, [A("face", who="cap", dir="up")], "captain"),
        {"actions": [A("move", who="cap", to=[21, 2.5], speed=60)], "wait": 1.4},
        {"actions": [A("despawn", who="cap")], "wait": 0.1},
        line(P, "……管道……？", "sad"),
        line(BLUE, "……", None, [A("face", who=B, dir="up"), A("bubble", who=B, kind="dots")]),
        line(P, "你知道他在说什么吗？", "surprise", [A("face", who="princess", dir="right")]),
        line(BLUE, "……不知道。……脸，擦一擦。……真的很像花猫。"),
        line(P, "连你也说！", "angry"),
        {"actions": [A("camera", reset=True, time=0.5)], "wait": 0.5},
    ]
    return {"name": "花猫样", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d2_equip": d2_equip, "after_d2_equip_done": d2_equip_done, "after_d3_cart": d3_cart, "after_d3_cart_done": d3_cart_done}


# ---------------------------------------------------------------- 失败小剧场
def say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def tk(by, zone="sole", fx="hand", n=8, iv=0.22):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


def theater(name, cast, body):
    steps = [{"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5}] + body + \
            [{"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7}]
    return {"name": name, "cast": cast, "steps": steps}


FAIL_EQUIP = theater("装备回收失败：小孩们的「装备大会」", {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "k1": {"kind": "npc:kid", "at": [-26, 12], "dir": "right"},
    "k2": {"kind": "npc:kid", "at": [26, 12], "dir": "left"},
    "k3": {"kind": "npc:kid", "at": [0, 26], "dir": "up"},
    "sup": {"kind": "npc:supervisor", "at": [62, 4], "dir": "left", "hidden": True},
}, [
    say(N, "（再也走不动了。她笑得腿一软，一屁股坐在了集市的石板路上）"),
    say("小孩", "姐姐坐下了！姐姐身上全是好玩的东西！", [A("hop", who="k1")]),
    say(P, "等、等一下……这些不是玩具……哈、哈……", emotion="helpless_1"),
    say("小孩", "这个袜子里有羽毛！我来搓！", [tk("k1", fx="feather", n=8, iv=0.2)], portrait="defeat_1"),
    say("小孩", "那我扳这个刷刷的套子！", [tk("k2", fx="lines", n=8, iv=0.2)]),
    say(P, "哈哈哈哈！脚心、脚趾缝……一起来不行——！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)]),
    say("小孩", "叮铃叮铃～我摇铃铛，你们跟着节奏挠！", [tk("k3", fx="hand", n=10, iv=0.18), tk("k1", fx="feather", n=10, iv=0.18)]),
    say(P, "什、什么节奏啊哈哈哈！铃铛一响脚心就……哈哈哈哈！", [A("pose", who="princess", visual="helpless_2")], portrait="defeat_2"),
    say(N, "（三个小孩把她身上的装备当成了乐器——一个摇铃，一个搓袜，一个扳刷套。她的笑声成了最响的那一件）"),
    say("小孩", "再来一遍！这次从脚跟开始！", [tk("k2", fx="lines", n=10, iv=0.16), tk("k3", fx="feather", n=10, iv=0.16)]),
    say(P, "哈哈哈……投、投降……我投降……装备……谁来帮我卸下来……", emotion="helpless_2"),
    say(SUP, "……（叹气）都散了都散了。装备我收走了，放回原处。", [A("enter", who="sup", to=[34, 6])]),
    say(SUP, "你——喘口气，再来一遍。这次走快点。"),
])

FAIL_CART = theater("拆车失败：车斗里的刷子", {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "bucket": {"kind": "trap:conveyor", "at": [0, 16]},
    "cart": {"kind": "monster:cart", "at": [-30, 10], "dir": "right"},
}, [
    say(N, "（攻城车的车斗「哐」地合上了。她整个人陷在一堆软刷子里，只露出两只脚丫在车斗外面乱蹬）"),
    say(P, "放、放我出去……！刷子……刷子在动……！", emotion="helpless_1"),
    say(N, "（车斗里的刷子一齐转了起来——从脚跟刷到脚趾，从脚趾刷回脚心）", [tk("bucket", fx="lines", n=8, iv=0.2)], portrait="defeat_1"),
    say(P, "哈哈哈哈！脚、脚底！刷子一圈一圈地——哈哈哈哈！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)]),
    say(N, "（车轮咕噜咕噜地开始转，攻城车载着她在战场上绕起了圈。每颠一下，刷子就往脚心里钻得更深）",
        [tk("bucket", fx="lines", n=10, iv=0.16)]),
    say(P, "停、停车！这、这不是兜风——哈哈哈！脚趾缝也、也刷进来了——！", [A("pose", who="princess", visual="helpless_2")], portrait="defeat_2"),
    say(N, "（绕到第三圈，车灯得意地闪了闪。刷子换成了更细的那一排，专挑脚弓最软的地方来回扫）", [tk("bucket", fx="feather", n=10, iv=0.16)]),
    say(P, "哈哈哈……我、我投降……车、车先生……我再也不拆你了……", emotion="helpless_2"),
    say(N, "（车轮终于慢了下来。攻城车打了个响亮的饱嗝，把她「噗」地吐回了战场入口——然后又心满意足地睡着了）"),
    say(P, "……呜……鞋、鞋子里全是刷毛……再、再来一次……这次一定……", emotion="helpless_1"),
])

THEATERS = {"after_fail_equip": FAIL_EQUIP, "after_fail_cart": FAIL_CART}
