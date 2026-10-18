"""弥补任务「药剂师的试药员·配药」（第 3 天早上，药剂师工房）：data/after/potion.json（TaskPotion 读）+ 过场 + 失败小剧场。
  herbs     六种药草：name、wrong（配方里没有它、却放进去喝下时的反应：奶奶的观察 + 公主的话，带挠的部位）
  recipes   三张配方（失败一次换下一张）：answer 正确的三种、blurred 被水渍盖住的配方字
"""
from .common import A, N, P, line

PHARM = "药剂师奶奶"

POTION = {
    "herbs": {
        "mint": {"name": "薄荷叶", "wrong": [
            {"speaker": PHARM, "text": "（羽毛轻轻碰了一下脚底）哎呀，脚底冰得发白了。"},
            {"speaker": P, "text": "好、好冰！凉过头了……一碰就想跳起来——哈、哈哈！", "emotion": "surprise"}], "zone": "sole",
            "note": "脚底冰得发麻，一碰就跳"},
        "ice": {"name": "冰晶草", "wrong": [
            {"speaker": PHARM, "text": "（羽毛扫过手心）怎么牙齿在打颤呀？"},
            {"speaker": P, "text": "冷、冷、冷……笑、笑声都一、一抖一抖的……哈、哈……", "emotion": "helpless_1"}], "zone": "armpit",
            "note": "冻得打哆嗦，笑声一抖一抖"},
        "lavender": {"name": "薰衣草", "wrong": [
            {"speaker": PHARM, "text": "（羽毛扫过脚心，过了好一会儿……）"},
            {"speaker": P, "text": "……嗯？……好困……………哈、哈哈哈哈！？反应慢、慢半拍——！", "emotion": "helpless_1"}], "zone": "sole",
            "note": "困得眼皮打架，痒的反应慢半拍然后一下子笑出来"},
        "mushroom": {"name": "痒痒菇粉", "wrong": [
            {"speaker": PHARM, "text": "（羽毛还没碰到）……哎？我还没挠呢。"},
            {"speaker": P, "text": "哈哈哈哈！羽毛、羽毛还没碰到就……好痒！全身都好痒——！", "emotion": "helpless_2"}], "zone": "waist",
            "note": "更怕痒，羽毛还没碰到就笑出来"},
        "feather": {"name": "羽毛花", "wrong": [
            {"speaker": PHARM, "text": "（羽毛扫过手心）……你怎么在缩脚？"},
            {"speaker": P, "text": "奇、奇怪……你挠的是手心，可是痒的是脚心——哈、哈哈！", "emotion": "surprise"}], "zone": "sole",
            "note": "痒的地方转移：挠手心，脚心在痒"},
        "honey": {"name": "蜂蜜根", "wrong": [
            {"speaker": PHARM, "text": "（羽毛扫过脚心）……还是一样怕痒嘛。"},
            {"speaker": P, "text": "嘴里甜甜的……可是脚心、脚心还是一样痒——哈哈哈！一点用都没有！", "emotion": "helpless_1"}], "zone": "sole",
            "note": "嘴里甜甜的，可是一点止痒的效果都没有"},
    },
    "order": ["mint", "ice", "lavender", "mushroom", "feather", "honey"],
    "recipes": [
        {"answer": ["mint", "ice", "lavender"], "blurred": "「止痒药：薄荷▒、冰晶▒、▒▒草，文火慢熬……」（后半张被水渍晕开了）"},
        {"answer": ["mint", "ice", "honey"], "blurred": "「止痒药（甜口）：薄▒叶、▒晶草，再加一味▒▒根……」"},
        {"answer": ["ice", "lavender", "honey"], "blurred": "「止痒药（安神）：▒晶草、薰▒▒，佐以蜂▒▒……」"},
    ],
    "success": [
        {"speaker": PHARM, "text": "（羽毛扫过手心、脚心、腰侧……）……嗯？"},
        {"speaker": P, "text": "……咦？不痒？……一点都不痒！", "emotion": "happy"},
        {"speaker": PHARM, "text": "呵呵，配对了。就是这个味道——奶奶年轻的时候，也是这么配出来的。"},
    ],
    "miss": [
        {"speaker": PHARM, "text": "嗯……这一碗不对。记下来，下一碗再试。"},
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
        line(PHARM, "架子上一共六味药草，每次挑三味。错三次的话……奶奶就要换一张配方，从头试咯。"),
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
    _say(P, "脚、脚心肯定没散啊！不用试了——哈哈哈哈！", [_tk("ph", zone="sole", n=12, iv=0.16)], portrait="defeat_2"),
    _say(N, "（羽毛顺着脚弓慢慢扫到前脚掌，又在脚趾缝里轻轻转了一圈。三碗药的药效一起发作，痒得她连脚趾都不知道该往哪边蜷）"),
    _say(PHARM, "嗯……全身都没散。那就只好等它自己散啦。……要等一个时辰哦。", [A("pose", who="princess", visual="helpless_2")]),
    _say(P, "一、一个时辰……！？哈哈……奶奶你在笑吧……你绝对在偷笑吧……！", emotion="helpless_2"),
    _say(PHARM, "呵呵呵。……散了以后，换一张配方，重新来。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_potion": FAIL_POTION}
