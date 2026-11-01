"""弥补任务「药剂师的试药员·配药」（第 3 天早上，药剂师工房）：data/after/potion.json（TaskPotion 读）+ 过场 + 失败小剧场。
  herbs     六种药草：name、wrong（配方里没有它、却放进去喝下时的反应：奶奶的观察 + 公主的话，带挠的部位）
  recipes   三张配方（失败一次换下一张）：answer 正确的三种、blurred 被水渍盖住的配方字
"""
from .common import A, N, P, back, burst, line

PHARM = "药剂师奶奶"

T = "药剂师奶奶"


def say(sp, text, emotion=None, tickle=None):
    d = {"speaker": sp, "text": text}
    if emotion:
        d["emotion"] = emotion
    if tickle:
        d["tickle"] = tickle
    return d


# 每味药草配错时的「试药流程」（TaskPotion._trial）：
#   intro 开场几句（奶奶的观察 + 公主的反应，带 "tickle": 部位 时顺手挠一下）
#   kind  小游戏：timing 指针扫到绿区按 J（width 绿区、speed、times 几次）/ mash 限时连按 J（count、time）/
#         guess 猜下一下痒哪里（order 痒感转移的顺序，rounds 猜几轮）/ rhythm 跟着节拍按 J（beats）/ choice 三选一（options、good）
#   ok / bad 成功 / 失败的几句；note 记进配方本的话；zone 主要部位
POTION = {
    "herbs": {
        "mint": {"name": "薄荷叶", "zone": "sole", "note": "脚底凉飕飕，一吹风就缩脚",
            "intro": [say(T, "嗯……脸色有点发白呀。把脚伸过来，奶奶看看。"),
                      say(P, "脚、脚底好凉……像踩在雪地里……", "surprise"),
                      say(T, "薄荷放多了。凉过头的脚底，最怕风。（她凑近，对着脚心轻轻吹了一口气）", tickle="sole"),
                      say(P, "呀哈！？凉、凉风……！脚趾全缩起来了……！", "helpless_1"),
                      say(T, "奶奶再吹三下。忍住别缩脚，就说明药效散得差不多了。")],
            "kind": "timing", "width": 0.3, "speed": 1.0, "times": 3, "prompt": "奶奶要吹了——指针到绿区时按 J 忍住别缩脚",
            "ok": [say(P, "……呼……忍、忍住了……", "shy"), say(T, "好孩子。凉劲儿退下去了。")],
            "bad": [say(N, "（脚心被凉风一吹，整只脚「嗖」地缩了回去，又被奶奶捏着脚踝拉了回来）", tickle="sole"),
                    say(T, "缩脚了呀。……那奶奶就多吹几下。（呼——呼——）"),
                    say(P, "哈哈哈……！别、别吹了……！凉、凉得好痒……！", "helpless_2")]},
        "ice": {"name": "冰晶草", "zone": "sole", "note": "脚冻麻了，回暖时针扎一样地痒",
            "intro": [say(T, "牙齿在打颤呢。冰晶草放多啦。"),
                      say(P, "冷、冷、冷……脚、脚趾都没感觉了……", "sad"),
                      say(T, "冻麻了不要紧，回暖的时候才难受。快，自己搓搓脚，搓热了就好。"),
                      say(N, "（脚底开始回暖——像有一千根小针在脚心里同时扎，又麻又痒）", tickle="sole"),
                      say(P, "哇、哇啊……！回、回暖了……好痒……！", "helpless_1")],
            "kind": "mash", "count": 14, "time": 4.0, "prompt": "连按 J 搓脚！搓热了针扎的痒才会退",
            "ok": [say(P, "呼……呼……搓、搓热了……", "helpless_1"), say(T, "脸色也回来了。")],
            "bad": [say(N, "（没来得及搓热，针扎一样的痒一下子从脚心窜到了脚趾尖）", tickle="sole"),
                    say(P, "哈哈哈哈！扎、扎扎扎……！全、全脚都在扎——！", "helpless_2"),
                    say(T, "哎呀呀，奶奶帮你搓。（奶奶的手掌贴着脚心一阵乱搓——更痒了）", tickle="sole")]},
        "lavender": {"name": "薰衣草", "zone": "sole", "note": "困得眼皮打架，痒的反应慢半拍才来",
            "intro": [say(T, "（羽毛扫过脚心，过了好一会儿……）"),
                      say(P, "……嗯？……好困……………", "sad"),
                      say(T, "薰衣草多了，反应慢半拍。奶奶已经挠完了，痒劲儿还在路上呢。"),
                      say(P, "在、在路上……？是什么意思……", "surprise"),
                      say(T, "等它到了，你就知道了。……到的那一下，憋住别笑出来。")],
            "kind": "timing", "width": 0.2, "speed": 0.7, "times": 2, "prompt": "痒劲儿慢半拍才到——指针到绿区时按 J 憋住",
            "ok": [say(P, "……噗。……憋、憋住了……", "shy"), say(T, "呵呵，憋得脸都红了。")],
            "bad": [say(N, "（——「刚才」的痒，和「刚才的刚才」的痒，一起到了）", tickle="sole"),
                    say(P, "哈、哈哈哈哈！？反、反应慢半拍，一下子全来了——！", "helpless_2"),
                    say(T, "慢半拍的痒，攒起来是双倍的哦。")]},
        "mushroom": {"name": "痒痒菇粉", "zone": "waist", "note": "全身过敏，羽毛还没碰到就笑",
            "intro": [say(T, "（羽毛还没碰到）……哎？我还没挠呢。"),
                      say(P, "哈哈哈哈！羽、羽毛还没碰到就……好痒！全身都好痒——！", "helpless_2"),
                      say(T, "痒痒菇粉，全身过敏。奶奶得一处一处试，看看哪里先退。"),
                      say(T, "手心、腋下、腰、脚心——每一处都要忍住，过敏才会退。")],
            "kind": "timing", "width": 0.26, "speed": 1.2, "times": 4, "prompt": "四处依次试（手心 / 腋下 / 腰 / 脚心）：指针到绿区时按 J 忍住",
            "spots": ["armpit", "armpit", "waist", "sole"],
            "ok": [say(P, "呼……呼……四、四处都忍住了……", "helpless_1"), say(T, "过敏退了。下一碗可别再放菇粉了。")],
            "bad": [say(N, "（忍不住笑出声的那一处，过敏一下子扩散开来——腋下、腰、脚心，同时痒了起来）", tickle="waist"),
                    say(P, "哈哈哈哈哈！全、全身都……！奶奶别、别再试了——！", "helpless_2"),
                    say(T, "过敏的时候笑出来，会更严重的呀。")]},
        "feather": {"name": "羽毛花", "zone": "sole", "note": "痒的地方会转移：挠这里，痒的是下一处",
            "intro": [say(T, "（羽毛扫过手心）……你怎么在缩脚？"),
                      say(P, "奇、奇怪……你挠的是手心，可是痒的是脚心——哈、哈哈！", "surprise", tickle="sole"),
                      say(T, "羽毛花，痒感会「转移」。挠一处，痒的是下一处——而且是按顺序的。"),
                      say(T, "手心 → 脚心 → 腋下 → 腰 → 又回到手心。……奶奶再挠几下，你猜猜下一下会痒在哪里。"),
                      say(P, "猜、猜对了会怎样？", "surprise"),
                      say(T, "猜对了，你就能提前绷住。猜错了嘛……就是突然袭击咯。")],
            "kind": "guess", "order": ["手心", "脚心", "腋下", "腰"], "rounds": 3, "prompt": "奶奶挠了「%s」——下一下会痒在哪里？",
            "zones": {"手心": "armpit", "脚心": "sole", "腋下": "armpit", "腰": "waist"},
            "ok": [say(P, "……绷、绷住了！……猜对了吧！", "happy"), say(T, "聪明。转移的痒劲儿散了。")],
            "bad": [say(N, "（猜错了。痒意出其不意地出现在完全没防备的地方——）", tickle="waist"),
                    say(P, "呀哈哈！？那、那里！？明明应该是……哈哈哈！", "helpless_2"),
                    say(T, "按顺序来的呀，手心、脚心、腋下、腰。记住了吗？")]},
        "honey": {"name": "蜂蜜根", "zone": "sole", "note": "身上甜甜的……药房的猫会跑来舔",
            "intro": [say(T, "嗯……还是一样怕痒嘛，蜂蜜根没有止痒的效果。"),
                      say(P, "嘴里甜甜的……身、身上也甜甜的……", "surprise"),
                      say(N, "（「喵」——药柜顶上跳下来一只花猫，鼻子抽了抽，径直走向她光着的脚）"),
                      say(T, "哎呀，团子闻到蜂蜜味了。……它最喜欢甜的。"),
                      say(N, "（粗糙的小舌头，「沙」地舔上了脚心）", tickle="sole"),
                      say(P, "呀啊！？猫、猫舌头……！", "helpless_1")],
            "kind": "choice", "prompt": "花猫团子正在舔脚心——怎么办？",
            "options": ["（一动不动，等它舔够）", "把脚缩起来藏到椅子底下", "抱起猫，把它放回药柜上"], "good": 2,
            "ok": [say(N, "（她一把抱起团子。团子在她怀里打了个哈欠，舔了舔她的手心，就乖乖地被放回了药柜顶上）"),
                   say(T, "团子很喜欢你呀。")],
            "bad": [say(N, "（团子不依不饶地追着脚舔——缩起来的脚趾缝、脚弓、脚跟，哪里甜就舔哪里）", tickle="sole"),
                    say(P, "哈哈哈哈！团、团子！别舔脚趾缝……！", "helpless_2"),
                    say(T, "呵呵，它要把蜂蜜舔干净才肯走哦。")]},
        "ginger": {"name": "暖姜根", "zone": "sole", "note": "脚底发烫，比平时敏感一倍",
            "intro": [say(P, "……好、好热……脚底热乎乎的……", "surprise"),
                      say(T, "暖姜根，暖身子的。……可是放多了，脚底会比平时敏感一倍。"),
                      say(T, "奶奶轻轻扫一下试试——（羽毛尖只碰了一下脚心）", tickle="sole"),
                      say(P, "哈哈哈！？只、只碰了一下……！好、好敏感……！", "helpless_1"),
                      say(T, "那再轻一点。……忍住两下，热劲儿就散了。")],
            "kind": "timing", "width": 0.18, "speed": 1.3, "times": 2, "prompt": "脚底发烫、一碰就痒：指针到窄窄的绿区时按 J 忍住",
            "ok": [say(P, "……呼……热、热劲儿下去了……", "shy"), say(T, "暖姜还是少放点好。")],
            "bad": [say(N, "（发烫的脚心被羽毛一扫，痒得像被放大了一倍，脚趾一根根地翘了起来）", tickle="sole"),
                    say(P, "哈哈哈哈！烫、烫烫的……又痒……！双、双倍的——！", "helpless_2"),
                    say(T, "敏感成这样……奶奶都不敢挠了。……再挠一下下。")]},
        "sour": {"name": "酸果皮", "zone": "waist", "note": "一阵一阵打嗝，每打一个嗝就笑一下",
            "intro": [say(P, "嗝！……酸、酸……嗝！", "surprise"),
                      say(T, "酸果皮放多了，打嗝啦。……这种嗝很奇怪，每打一下，人就会跟着笑一下。"),
                      say(P, "嗝！……噗哈！？……真、真的……嗝！……哈哈！", "helpless_1", tickle="waist"),
                      say(T, "跟着嗝的节拍，深呼吸、憋住——憋过四下，就不打了。")],
            "kind": "rhythm", "beats": 4, "prompt": "跟着打嗝的节拍按 J 憋住（嗝！的那一下）",
            "ok": [say(P, "嗝……………………不打了。呼……", "shy"), say(T, "呵呵，憋得很好。")],
            "bad": [say(N, "（一个嗝没憋住，笑声和嗝声搅在一起，越笑越嗝、越嗝越笑）", tickle="waist"),
                    say(P, "嗝！哈哈！嗝！哈哈哈！停、停不下来——嗝！", "helpless_2"),
                    say(T, "哎呀呀，这下要打一下午了。……喝口水，喝口水。")]},
    },
    "order": ["mint", "ice", "lavender", "mushroom", "feather", "honey", "ginger", "sour"],
    "recipes": [
        {"answer": ["mint", "ice", "lavender"], "blurred": "「止痒药：薄荷▒、冰晶▒、▒▒草，文火慢熬……」（后半张被水渍晕开了）"},
        {"answer": ["mint", "ice", "honey"], "blurred": "「止痒药（甜口）：薄▒叶、▒晶草，再加一味▒▒根……」"},
        {"answer": ["ice", "lavender", "ginger"], "blurred": "「止痒药（暖身）：▒晶▒、▒衣草，佐以一味▒▒根……」（根？蜂蜜根还是暖姜根？）"},
        {"answer": ["mint", "lavender", "honey"], "blurred": "「止痒药（安神）：▒▒叶、薰▒▒，再加▒▒▒……」"},
    ],
    "success": [
        say(T, "（羽毛扫过手心、脚心、腰侧……）……嗯？"),
        say(P, "……咦？不痒？……一点都不痒！", "happy"),
        say(T, "呵呵，配对了。就是这个味道——奶奶年轻的时候，也是这么配出来的。"),
    ],
    # 配对了一张（还没配够三张）以后奶奶说的话：第 1 张 / 第 2 张
    "next": [
        [say(T, "好，这一锅成了。……可是一锅不够全镇用的。"),
         say(T, "这一张是「普通」的配方。奶奶还要熬「甜口」的和「安神」的——小孩子怕苦，睡不着的人要安神。"),
         say(P, "还、还要喝两锅……？", "sad"),
         say(T, "呵呵，下一张配方，水渍更多哦。")],
        [say(T, "第二锅也成了。最后一张——"),
         say(P, "最、最后一张……我的舌头已经尝不出味道了……", "helpless_1"),
         say(T, "尝不出味道正好，就不怕苦了。（翻开最后一张，被泡得最烂的那张）")],
    ],
    # 配对以后的成品测试（好笑的演出：一点都不痒）
    "final": [
        say(T, "配对了还不算完——成品要过奶奶的「三关」。"),
        say(T, "第一关，团子。（花猫团子被放到她脚边，舔了一下脚心）", tickle="sole"),
        say(P, "……………………不痒。", "surprise"),
        say(N, "（团子愣了一下，又舔了一下。又舔了一下。然后困惑地歪着头，看看她的脚，看看奶奶）"),
        say(T, "第二关，奶奶的羽毛。（羽毛在腋下、腰、脚心上来回扫了十几下）", tickle="armpit"),
        say(P, "……完全不痒！哈哈，你看你看，我可以自己拿羽毛挠自己！", "happy"),
        say(N, "（她抢过羽毛，在自己的脚心上使劲地扫——一点感觉都没有）"),
        say(T, "第三关——刷子。（一把硬毛刷，在两只脚心上「唰唰唰」地刷）", tickle="sole"),
        say(P, "……………………", "happy"),
        say(P, "……哈哈哈！不痒！太好了！我、我从来没有这样过！", "happy"),
        say(T, "……可是你在笑啊。"),
        say(P, "这是开心的笑！开心的！", "angry"),
        say(T, "呵呵，好好好。……药效十分钟。十分钟以后，可别怪奶奶哦。"),
    ],
    "miss": [
        say(T, "嗯……这一碗不对。记下来，下一碗再试。"),
    ],
}


def d3_potion():
    s = [
        {"actions": [A("face", who="after_pharm", dir="down"), A("camera", to=[8, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(PHARM, "哎呀，赎罪簿上写的试药员，就是你呀。"),
        line(PHARM, "奶奶想重新熬一锅止痒药——攻防战那几天，用掉太多了。"),
        line(PHARM, "可是配方本前几天被泡了水，字都花了。……只好请你帮忙试药。"),
        line(P, "试、试药……是喝下去的那种吗？", "surprise"),
        line(PHARM, "对呀。喝完奶奶拿羽毛试一试，不痒就是配对了。"),
        line(PHARM, "配错了嘛……会有一点点小反应。看清楚是什么反应，下一碗就知道该换哪味药了。"),
        line(P, "（……「一点点小反应」，绝对不只一点点吧……）", "sad"),
        line(PHARM, "架子上一共八味药草，每次挑三味。错三次的话……奶奶就要换一张配方，从头试咯。"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "药剂师的试药员", "letterbox": True, "skippable": True, "steps": s}


def d3_potion_done():
    s = [
        {"actions": [A("face", who="after_pharm", dir="down"), A("camera", to=[8, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(PHARM, "好啦，一大锅止痒药熬好了。这一瓶送你——辛苦的试药员。"),
        line(N, "（得到了「薄荷止痒药」：喝下后 10 秒内怎么挠都不会涨闷笑）", None, [A("item", id="mint_potion"), A("sfx", sound="pickup")]),
        line(P, "谢谢奶奶！……舌头到现在还是怪怪的……", "shy"),
        line(PHARM, "呵呵。你和小时候的那孩子一样，喝药的时候总皱着鼻子。"),
        line(P, "……小时候的那孩子？", "surprise"),
        line(PHARM, "……啊，年纪大了，记性不好。去吧去吧，下午还有活呢。"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "止痒药熬好了", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d3_potion": d3_potion, "after_d3_potion_done": d3_potion_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, zone="sole", fx="feather", n=8, iv=0.22):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_POTION = {"name": "试药失败：全身羽毛测试", "cast": {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "chair": {"kind": "trap:cushion", "at": [0, 10]},
    "ph": {"kind": "npc:pharmacist", "at": [-30, 10], "dir": "right"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(PHARM, "三碗都不对……哎呀呀，药效全混在一起了。"),
    _say(P, "全、全混在一起……是什么意思……？", emotion="surprise"),
    _say(PHARM, "意思是——现在你全身上下，哪里都比平时怕痒。奶奶得一处一处试，看看药效散了没有。"),
    _say(N, "（奶奶拿出一根长长的白羽毛，先从手心开始）", [_tk("ph", zone="armpit", n=6, iv=0.3)]),
    _say(P, "噗……哈、哈……手心……！", emotion="helpless_1"),
    _say(PHARM, "手心还没散。那，脖子。", [_tk("ph", zone="neck", n=8, iv=0.22)], portrait="defeat_1"),
    _say(P, "哈哈哈！脖子不行！缩、缩不起来——！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)]),
    _say(PHARM, "腰也没散。……脚心呢？把鞋脱了，奶奶看看。", [_tk("ph", zone="waist", n=6, iv=0.25)]),
    _say(P, "不、不用试了……脚心肯定没散……我自己知道的……", emotion="shy"),
    _say(N, "（奶奶笑眯眯地握住她的脚踝，把光着的脚丫按在软垫上。十根脚趾不安地缩成一团，脚心却露得明明白白）"),
    dict(_say(P, "呀啊——！脚、脚心肯定没散啊——哈哈哈哈！", [_tk("ph", zone="sole", n=12, iv=0.16)], portrait="defeat_2"), cg=True),
    _say(N, "（羽毛顺着脚弓慢慢扫到前脚掌，又在脚趾缝里轻轻转了一圈。三碗药的药效一起发作，痒得她连脚趾都不知道该往哪边蜷）",
         [_tk("ph", zone="sole", n=10, iv=0.18), A("pose", who="princess", visual="helpless_2")]),
    _say(P, "哈哈哈哈！奶、奶奶——趾缝里不行——那里是第二碗药——！", [A("bubble", who="princess", kind="laugh")]),
    _say(PHARM, "哦？第二碗是在趾缝里发作的呀。奶奶记下来。……再试一次，看看记得对不对。", [_tk("ph", zone="sole", n=8, iv=0.2)]),
    _say(P, "记、记什么啊——不要拿我的脚做笔记哈哈哈！", [A("shake", who="princess", time=0.5)]),
    _say(N, "（奶奶换了一把小刷子，一手握着她的脚踝，一手用刷子尖在每一道趾缝里点一下，点一下就在本子上画一个勾）", [_tk("ph", zone="sole", fx="lines", n=10, iv=0.2)]),
    _say(P, "一、一个勾……又一个勾……奶奶你画得好慢……哈哈哈……我、我要……", emotion="helpless_2"),
    _say(N, "（三碗药的药效被挠得在身体里翻腾，魔力疲倦一下子涨满了，她的身体开始一闪一闪地发光）", [_tk("ph", zone="sole", n=6, iv=0.2)]),
    _say(P, "魔、魔力……要满出来了……奶奶快躲开——！"),
    dict(_say(N, "（星光从她身上炸开，椅垫被冲得飞了起来，奶奶的老花镜歪到了一边，羽毛和小刷子撒了一地）", burst("princess", [("ph", [-30, 10])])), act="burst", wait=1.0),
    _say(P, "哈啊……魔力……全放出去了……身体轻飘飘的……好舒服……", emotion="happy"),
    _say(PHARM, "哎哟哟，药效被冲出来一点了呢。……不过，放完魔力的身子最敏感了，正好接着试。", back([("ph", [-30, 10])])),
    _say(P, "等、等一下……我刚刚……呀啊——！羽毛只碰了一下脚跟——怎么这么痒——！", [_tk("ph", zone="sole", n=10, iv=0.16)], emotion="helpless_2"),
    _say(PHARM, "看吧。放完魔力以后呀，一根羽毛顶得上平时三根。", [_tk("ph", zone="sole", n=8, iv=0.18)]),
    _say(N, "（奶奶把三根羽毛并成一把，从脚跟慢慢刷到脚尖，再刷回来。她的脚背绷得笔直，十根脚趾张开又蜷起，敏感得一碰就抖）", [_tk("ph", zone="sole", n=12, iv=0.15)]),
    _say(P, "哈哈哈哈！敏、敏感得要命——全身都——求求你奶奶——我认输——配方我重新抄——！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.6)]),
    _say(PHARM, "认输可不行，药效还没散呢。……腋下也再试一下。", [_tk("ph", zone="armpit", n=8, iv=0.2)]),
    _say(P, "腋、腋下也……哈哈哈哈……奶奶……你绝对在偷笑……你的肩膀在抖……！"),
    _say(N, "（羽毛在腋下和脚心之间来回换，换一下她就跳一下。小屋里只剩下她停不下来的笑声，和奶奶慢悠悠的哼歌声）",
         [_tk("ph", zone="sole", n=8, iv=0.18), _tk("ph", zone="armpit", n=6, iv=0.2)]),
    _say(PHARM, "嗯……全身都没散。那就只好等它自己散啦。……要等一个时辰哦。"),
    _say(P, "一、一个时辰……！？哈哈……一个时辰……我会笑到飞走的……", emotion="helpless_2"),
    _say(PHARM, "呵呵呵。……散了以后，换一张配方，重新来。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_potion": FAIL_POTION}
