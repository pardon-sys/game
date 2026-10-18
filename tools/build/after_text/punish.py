"""训练营的受罚转盘（PenanceRoulette）：四种刑具各一段短小剧场（data/theater/after/after_roulette_<刑具>.json）。
舞台演员用现有的训练营刑具（trap:supine 刑床 / trap:stocks 足枷 / trap:spinwheel 转轮 / trap:saddle_bench 刷子凳）和保卫队员。
粉色公主写脚：脱鞋、扳脚趾、刮脚心、刷脚弓；开朗嘴硬、边笑边求饶。
"""
from .common import A, N, P

TRAINER = "训练营的教官"
GUARD = "保卫队员"


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


def cast(device_key, device_at):
    return {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
            "dev": {"kind": "trap:" + device_key, "at": device_at},
            "t": {"kind": "npc:guard", "at": [-34, 10], "dir": "right"},
            "g": {"kind": "npc:guard", "at": [34, 10], "dir": "left"}}


def theater(name, device_key, device_at, body):
    steps = [{"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5}] + body + \
            [{"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7}]
    return {"name": name, "cast": cast(device_key, device_at), "steps": steps}


RACK = theater("受罚转盘：刑床", "supine", [0, 18], [
    say(TRAINER, "转到刑床了。躺上去，手脚各一个扣环。", [A("face", who="t", dir="right")]),
    say(P, "躺、躺就躺……先说好，只是躺着对吧？", emotion="shy"),
    say(TRAINER, "躺着，然后把鞋脱了。", [A("sfx", sound="cloth")]),
    say(P, "我就知道！！", emotion="angry"),
    say(N, "（扣环「咔哒」一声扣紧。整个人被拉成一条直线，光着的脚底正对着教官）", [A("sfx", sound="stocks")]),
    say(TRAINER, "脚趾张开。……我数到十，你忍到十就放你下来。一——", [tk("t", fx="feather", n=6, iv=0.3)]),
    say(P, "唔……嗯……二、二呢？二怎么还不数——", emotion="shy"),
    say(TRAINER, "二……", [tk("t", fx="feather", n=10, iv=0.2), tk("g", zone="waist", n=6)], portrait="defeat_1"),
    say(P, "哈哈哈哈哈！数、数得太慢了！腰也、腰也不行哈哈哈！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)]),
    say(GUARD, "教官，她脚跟那里最怕。"),
    say(TRAINER, "记下了。三……", [tk("t", n=10, iv=0.18), tk("g", n=8, iv=0.2)], portrait="defeat_2"),
    say(P, "不要告诉他啊哈哈哈哈！脚跟、脚跟要被刮掉了哈哈哈哈——！", [A("pose", who="princess", visual="helpless_2")]),
    say(N, "（「十」最后也没有数到。等教官想起来的时候，她已经笑得只剩下喘气声了）"),
    say(P, "……下、下次……我自己数……", emotion="helpless_2"),
])

STOCKS = theater("受罚转盘：足枷", "stocks", [0, 23], [
    say(TRAINER, "足枷。早上不是刚坐过吗？熟门熟路了吧。", [A("face", who="t", dir="right")]),
    say(P, "才不熟！一点都不想熟！", emotion="angry"),
    say(N, "（木枷合上，两只脚踝被牢牢夹住。底下的羽毛滚轮慢慢转了起来）", [A("sfx", sound="stocks"), tk("dev", fx="lines", n=6, iv=0.3)]),
    say(P, "滚、滚轮……从脚跟一直滚到脚趾……唔唔……", emotion="shy"),
    say(TRAINER, "滚轮只是热身。——扳脚趾。", [A("face", who="g", dir="left")]),
    say(GUARD, "是。左边五个，右边五个。", [tk("g", fx="hand", n=6, iv=0.25)]),
    say(P, "别扳——扳开就合不上了——哈、哈哈哈！", [tk("t", fx="feather", n=10, iv=0.18), tk("dev", fx="lines", n=10, iv=0.2)], portrait="defeat_1"),
    say(TRAINER, "羽毛从脚趾缝中间穿过去……一根，两根……"),
    say(P, "哈哈哈哈哈！缝、缝里不行！我、我认输——认输还不行吗哈哈哈！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.6)]),
    say(TRAINER, "认输是你的事，时间是转盘的事。", [tk("t", n=10, iv=0.16), tk("g", n=10, iv=0.17)], portrait="defeat_2"),
    say(P, "什、什么歪理哈哈哈哈！脚心、两只脚心都——哈哈哈哈哈！", [A("pose", who="princess", visual="helpless_2")]),
    say(N, "（滚轮、羽毛、扳开的脚趾——被锁住的两只脚，一刻也没能缩回去）"),
    say(P, "……早上……加现在……今天的脚……已经不是我的了……", emotion="helpless_2"),
])

WHEEL = theater("受罚转盘：转轮", "spinwheel", [0, 14], [
    say(TRAINER, "转轮。手腕、脚踝绑好，轮子转一圈，刷子刷一遍。", [A("face", who="t", dir="right")]),
    say(P, "一、一圈多久？", emotion="surprise"),
    say(TRAINER, "看它心情。", [A("sfx", sound="roll")]),
    say(N, "（轮子吱呀吱呀地转起来。每转到最底下，脚底就从一排软刷子上擦过去）", [tk("dev", fx="lines", n=6, iv=0.35)]),
    say(P, "唔、唔……一下……又一下……转到底的时候……噗……", emotion="shy"),
    say(GUARD, "教官，要加速吗？"),
    say(TRAINER, "加。", [A("sfx", sound="roll", pitch=1.3), tk("dev", fx="lines", n=12, iv=0.15)], portrait="defeat_1"),
    say(P, "哈哈哈哈！太、太快了！刷子刷得、刷得连成一片了哈哈哈！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)]),
    say(TRAINER, "转到最底下的时候，你再用羽毛补一下脚心。", [A("face", who="g", dir="left")]),
    say(GUARD, "明白。", [tk("g", fx="feather", n=10, iv=0.18), tk("dev", fx="lines", n=10, iv=0.16)], portrait="defeat_2"),
    say(P, "补什么补啊哈哈哈哈！头、头好晕——脚好痒——分不清哪个更难受了哈哈哈哈！", [A("pose", who="princess", visual="helpless_2")]),
    say(N, "（轮子停下来的时候，她已经分不清上下了，只记得脚底还在一阵一阵地发痒）"),
    say(P, "……天、天花板……在转……脚底板……也在转……", emotion="helpless_2"),
])

BRUSH = theater("受罚转盘：刷子凳", "saddle_bench", [0, 14], [
    say(TRAINER, "刷子凳。坐上去，脚放到前面的踏板上，绑好。", [A("face", who="t", dir="right")]),
    say(P, "凳子底下那一排……是刷子吧？绝对是刷子吧？", emotion="shy"),
    say(TRAINER, "踏板上也有。", [A("sfx", sound="brush_spin")]),
    say(N, "（凳子里的刷子转了起来，踏板上的细刷也跟着顺着脚弓来回刷）", [tk("dev", zone="butt", fx="lines", n=6, iv=0.3), tk("dev", fx="lines", n=6, iv=0.3)]),
    say(P, "呜……底、底下……还有脚弓……两边一起……噗、噗……", emotion="shy"),
    say(TRAINER, "坐直。别扭。扭一下多刷十秒。"),
    say(P, "你这么说我更想扭了啊——哈、哈哈！", [tk("t", fx="feather", n=8, iv=0.2), tk("dev", fx="lines", n=8, iv=0.22)], portrait="defeat_1"),
    say(GUARD, "教官，她扭了。三下。"),
    say(TRAINER, "三十秒。……我来帮她数。", [tk("t", n=10, iv=0.17), tk("g", fx="feather", n=10, iv=0.18), tk("dev", zone="butt", fx="lines", n=8, iv=0.2)], portrait="defeat_2"),
    say(P, "哈哈哈哈哈！帮、帮我数为什么要挠脚心啊哈哈哈哈！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.6)]),
    say(TRAINER, "……二十九。二十八。……又扭了，加十秒。", [A("pose", who="princess", visual="helpless_2")]),
    say(N, "（三十秒最后变成了三分钟。教官数数的声音，和她的笑声一起，在训练营里回荡）"),
    say(P, "……以、以后……再也不坐凳子了……站着……一辈子站着……", emotion="helpless_2"),
])

THEATERS = {"after_roulette_rack": RACK, "after_roulette_stocks": STOCKS, "after_roulette_wheel": WHEEL, "after_roulette_brush": BRUSH}
