"""骑士篇 E~G：诅咒失控·镇中追逃（TaskArmorChase）、Boss「痒铠骑士」（KnightBoss）、尾声。data/after/knight_finale.json + 过场 + 失败小剧场。
  chase  盔甲被诅咒附身冲出地牢，在镇上追粉色公主；点亮三座笑声灯笼信标，把它引到广场图腾柱下。
         被抓住：抱住轻挠——闷笑涨得慢、疲倦涨得快，越来越舒服（手印认得她），连按挣脱。
  boss   三个阶段：铁手套（扑抓 / 扫腿）→ 护腿（跺地痒波 / 召手印）→ 头盔笑面（笑气，骑士的声音冲出来）→ 两人站进图腾前的符文圈共鸣，光柱净化笑面。
         只能打诅咒部件，骑士本人不掉血。粉色公主贴近时诅咒变慢变温和，蓝色公主趁机冻住、打碎。
  尾声   骑士清醒了，只对蓝色公主说话，留下半枚王国徽章「交给真正的殿下」。粉色公主：「……难道我才是那个『另一个』？」
"""
from after_text.common import A, BLUE, BLUE_NODE as B, CAP, MAYOR, N, P, L, line, event

KNIGHT = "骑士"
GUARD = "保卫队员"
K = "knight"


# ---------------------------------------------------------------- E 诅咒失控（第二天早上）
def erupt():
    s = [
        {"actions": [A("fade_in", time=0.6)], "wait": 0.6},
        line(N, "（天刚亮，营地方向传来「轰」的一声闷响，整个小镇都晃了一下）"),
        line(GUARD, "（撞开小屋的门）不、不好了！地牢的那个人——盔甲自己动起来了！"),
        line(P, "盔甲自己……？", "surprise"),
        line(GUARD, "紫色的手印把他整个人都裹住了！牢门被撞开了，他……它正往镇上来！"),
        line(GUARD, "队长说——它在找你。"),
        line(BLUE, "……走。"),
    ]
    return {"name": "诅咒失控", "letterbox": True, "skippable": True, "steps": s}


def chase_open():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight_cursed", at=[58, 36], dir="left"),
                     A("camera", to=[56, 34], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（营地的楼梯口，一具银灰色的盔甲慢慢走了出来。盔甲上爬满了紫色的手印，一圈一圈地发着光，每一步都踩得石板咯吱作响）"),
        line(KNIGHT, "……殿……下……", None, [A("bubble", who=K, kind="angry")]),
        line(N, "（面罩的缝里透出紫光。它转过头，看向了她）"),
        line(CAP, "（拔剑挡在前面）别过来！……那已经不是他自己在走了。", None, None, "captain"),
        line(MAYOR, "（远远地喊）广场的图腾柱！把它引到图腾柱下面——图腾的光能压住诅咒！"),
        line(CAP, "路上有三座笑声灯笼，点亮了，图腾的光才连得过去。……我们拦不住它，只能靠你引。", None, None, "captain"),
        line(P, "……引它？那它不是会一直追着我——", "surprise"),
        line(BLUE, "……追的是你。所以只有你能引。"),
        line(P, "……好吧！追就追！", "angry"),
        line(N, "（往三座信标跑，站在信标旁按住 E 几秒点亮。盔甲直线快、转弯慢，绕着房子和摊位甩开它；它甩出铁手横扫小巷之前地上有预警线。C 换蓝色公主能冻住它一会儿，冷却很长。被抓住了连按 J 挣脱，抓三次要重来）"),
        {"actions": [A("despawn", who=K), A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "镇中追逃", "letterbox": True, "skippable": True, "steps": s}


CHASE = {
    "beacon_lit": ["（灯笼「呼」地亮了！一道暖光朝广场的方向连了过去）", "（第二座信标亮了，光带又往图腾柱延伸了一截）",
                   "（最后一座！三道光在广场上空汇在了一起）"],
    "beacon_hold": "点亮信标……",
    "warn": ["（地上亮起一道紫色的线——铁手要横扫过来了！）", "（盔甲抬起了手臂……小巷里亮起预警线！）"],
    "sweep": ["（铁手从盔甲上飞出去，贴着地面横扫过小巷）", "（呼——！铁手扫过，扫到的地方一阵发痒）"],
    "caught": ["（盔甲一把把她抱住了。紫色的手印从盔甲上爬到她身上——却只是轻轻地、慢慢地挠她的脚心）",
               "（被抱住了！手印贴着她的脚底一下一下地挠，轻得像在哄她睡觉）",
               "（盔甲把她搂在怀里。手印顺着她的脚踝爬上来，在脚心画着圈，一点都不凶）"],
    "caught_react": ["……哈……为什么……这么轻……", "……唔……好、好舒服……不对！", "……放、放开我……哈……", "……别……别这么温柔……"],
    "escape": ["（她拼命一挣——从盔甲的怀里滑了出来！）", "（挣开了！快跑！）"],
    "freeze": ["（蓝色公主一挥手，冰从盔甲的脚下爬上来，把它冻在了原地）"],
    "freeze_cool": "冰封还在冷却……",
    "townsfolk": ["（面包店奶奶「砰」地关上了小巷的栅栏——盔甲被挡在了外面！）", "（工匠推开了路边的栅栏：「这边！快！」）",
                  "（小汤姆和小莉莉在巷口挥手：「姐姐，这边能绕过去！」）"],
    "near": ["殿……下……", "……为……什……么……", "……别……跑……"],
    "fail_hint": "被抓了三次……从营地楼梯口重来",
}


# ---------------------------------------------------------------- F Boss「痒铠骑士」
def boss_open():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight_cursed", at=[41, 21], dir="down"),
                     A("camera", to=[41, 23], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（三道光在图腾柱上方汇成一圈。盔甲被光罩住，停下了脚步——下一秒，它仰起头，发出一声刺耳的笑声）"),
        line(N, "（盔甲上的手印全都亮了。铁手套、护腿、头盔上的面罩，一件一件地「活」了过来）"),
        line(CAP, "……诅咒附在了盔甲上。打碎盔甲上的诅咒——别伤到他本人！", None, None, "captain"),
        line(BLUE, "……铁手套。护腿。……还有那张脸。"),
        line(P, "那张脸……在笑……", "surprise"),
        line(MAYOR, "最后把它引到图腾柱前的符文圈！两个人一起，像修图腾柱那天一样——用笑声把它净化掉！"),
        line(P, "……又是一起笑。", "helpless_1"),
        line(BLUE, "……这次，我不会裂。"),
        line(N, "（粉色公主贴近的时候诅咒会变慢变温和——趁这时换蓝色公主冻住部件、打碎它。被抓住了连按挣脱）"),
        {"actions": [A("despawn", who=K), A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "痒铠骑士", "letterbox": True, "skippable": True, "steps": s}


def be(phase, tool, caption, *replies, zone="sole"):
    return event(phase, tool, caption, *replies, zone=zone)


BOSS = {
    "name": "痒铠骑士",
    "parts": {"gauntlet_l": "左铁手套", "gauntlet_r": "右铁手套", "greave_l": "左护腿", "greave_r": "右护腿", "mask": "笑面"},
    "phase_intro": [
        ["（铁手套「咔」地张开五指，朝她扑了过来！）"],
        ["（两只铁手套碎了。盔甲的护腿亮了起来——它重重地跺了一下地，一圈紫色的痒波扩散开来）",
         "……殿……下……快……", "……是他的声音！他还在里面！"],
        ["（护腿也碎了。盔甲跪在地上，头盔的面罩却「咔哒」一声打开——里面是一张紫色的、咧着嘴笑的脸）",
         "……殿下……快走……！", "……他在叫我们走……可是我们不能走！"],
    ],
    "grab": ["（铁手套抓住了她，把她拎起来——手指钻进腋下和腰侧，挠得飞快）", "（被铁手套攥住了！五根铁指头在腰上来回地抓）"],
    "grab_soft": ["（铁手套抓住了她——可是一碰到她，手指就慢了下来，只是轻轻地、一下一下地挠）"],
    "sweep": ["（扫腿！一整行的地面亮起紫光——被扫中的人会被绊倒）", "（盔甲压低身子，铁腿横扫过来！）"],
    "trip": ["（被扫倒了！她一屁股坐在地上，铁手套立刻按住她的脚踝，挠她的脚心）"],
    "stomp": ["（跺地！一圈痒波扩散开来——碰到的人从脚底一路痒到腰）", "（「咚」——痒波！快跳开！）"],
    "stuck": ["（跺完一下，护腿卡在了地里——现在！）"],
    "gas": ["（笑面张开嘴，吐出一团粉紫色的笑气，飘到哪里，哪里的人就忍不住想笑）"],
    "soft": ["（她贴近的时候，诅咒的光慢了下来，变得很温和——像认得她一样）"],
    "break": ["（「咔嚓」——%s碎了！）"],
    "voice": ["……殿下……快走……", "……别……管我……", "……对……不……起……", "……殿……下……"],
    "resonance": [
        "两个人，站进符文圈！",
        "（她们一左一右站进了图腾前的两个符文圈。和修图腾柱那天一样——足印符文缠住脚踝，腿环符文唤醒了裤子）",
        "……一起笑。……别裂。",
    ],
    "purge": ["（两道笑声对上了。图腾柱「嗡」地一亮，一道光柱从天而降，罩住了那张笑面）",
              "（笑面发出一声尖笑，然后——碎成了千百个紫色的光点，像雪一样飘散了）"],
    "feedback": [
        be(0, "gauntlet", "（铁手套的指尖贴着她的脚心刮过去，刮完又刮回来）",
           "……铁、铁的……！", "……冰凉凉的……", "哈……刮、刮……！", "噗……铁指头……！", "哈哈哈……放开……！", "哈哈……脚心……！"),
        be(1, "wave", "（痒波从脚底漫上来，一路痒到膝盖窝，又痒回脚趾）",
           "……波、波过来了……", "……从脚底……", "哈……一路……上来了……！", "噗哈……膝盖窝……！", "哈哈哈……躲不开……！", "哈哈……全身都……！"),
        be(2, "gas", "（笑气钻进鼻子，明明没人挠，却从心里痒出来）",
           "……什么味道……", "……甜甜的……", "噗……好、好想笑……！", "哈……没人挠也……！", "哈哈哈……停不下来……！", "哈哈……笑、笑气……！"),
    ],
    "fail": [L("（盔甲把她牢牢地抱在怀里，手印爬满了她的脚。……这一次，她挣不开了）", N)],
}


def epilogue():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight", at=[41, 22], dir="down"),
                     A("camera", to=[41, 23], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（紫光散尽。盔甲「哐」地一声跪倒在图腾柱下。面罩合上了，手印一个都不剩）"),
        line(KNIGHT, "……我……"),
        line(P, "……你醒了？没事了！诅咒已经——", "happy"),
        line(KNIGHT, "……", None, [A("face", who=K, dir="right")]),
        line(N, "（他没有看她。他撑着剑站起来，走到了蓝色公主面前）"),
        line(KNIGHT, "……殿下。……给您添麻烦了。"),
        line(BLUE, "……我不是你的殿下。"),
        line(KNIGHT, "……我知道。"),
        line(N, "（他从胸甲里取出一样东西，放进蓝色公主的手心——半枚王国的徽章，断口很新）"),
        line(KNIGHT, "……交给真正的殿下。"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="question")]),
        line(KNIGHT, "……我要找的人，不是她。"),
        line(N, "（他转过身，经过粉色公主身边的时候，脚步停了一下）"),
        line(KNIGHT, "……谢谢。……可是我不会原谅你。"),
        line(N, "（他走向了营地的方向。队长跟在他后面，什么都没说）"),
        line(P, "……", "sad"),
        line(BLUE, "……", None, [A("face", who=B, dir="left")]),
        line(P, "……他把徽章给了你。他叫你殿下。", "sad"),
        line(P, "……那天晚上，钟楼上一个殿下，广场上一个殿下。……一个是真的，一个是冒牌货。", "sad"),
        line(P, "……难道我才是那个『另一个』？", "sad"),
        line(BLUE, "……"),
        line(N, "（蓝色公主低头看着手心里的半枚徽章，很久很久。然后，她把它攥紧了）"),
        line(BLUE, "……不知道。"),
        line(BLUE, "……可是，你笑起来的声音。……我认得。"),
        line(P, "……诶？", "surprise"),
        line(BLUE, "……走吧。回家。"),
        {"actions": [A("fade_out", time=1.2)], "wait": 1.2},
        {"actions": [A("chapter_end", title="骑士篇　完", subtitle="——半枚徽章的另一半，在谁手里？", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "半枚徽章", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"knight_erupt": erupt, "knight_chase_open": chase_open, "knight_boss_open": boss_open, "knight_epilogue": epilogue}
FINALE = {"chase": CHASE, "boss": BOSS}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, who="princess", zone="sole", fx="hand", n=8, iv=0.22):
    return A("tickle", who=who, by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_CHASE = {"name": "镇中追逃失败：被盔甲抱住", "cast": {
    "princess": {"kind": "princess", "at": [-4, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "armor": {"kind": "npc:knight_cursed", "at": [8, 4], "dir": "left"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（第三次被抱住的时候，盔甲没有再松手。它把她搂在怀里，像抱着一件很重要的东西）"),
    _say(N, "（手印一只一只爬到她的脚上，在脚心、脚背、趾缝里慢慢地挠。很轻，很慢，一刻都不停）", [_tk("armor", fx="feather", n=14, iv=0.3)]),
    _say(P, "哈……哈哈……别、别这么轻……这样更、更受不了……", portrait="defeat_1"),
    _say(N, "（痒意一点一点漫上来，暖洋洋的，她的脚趾一根一根地松开了——魔力差点就这么化开）"),
    _say(KNIGHT, "……殿……下……"),
    _say(N, "（「哗啦」——蓝色公主的冰从脚下爬上盔甲，把它冻在了原地。粉色公主从它的怀里滑了出来）"),
    _say(BLUE, "……起来。再引一次。"),
    _say(P, "哈……哈……好、好……", emotion="helpless_1"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

FAIL_BOSS = {"name": "痒铠骑士失败：铁手套和手印", "cast": {
    "princess": {"kind": "princess", "at": [-12, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "blue": {"kind": "npc:blue_princess", "at": [12, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "armor": {"kind": "npc:knight_cursed", "at": [0, -6], "dir": "down"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（铁手套一左一右，同时抓住了两个人）"),
    _say(N, "（抓着蓝色公主的那只，在她大腿内侧飞快地挠；抓着粉色公主的那只，却只是一下一下地轻轻挠她的脚心）",
         [_tk("armor", who="blue", zone="thigh", n=12, iv=0.16), _tk("armor", zone="sole", fx="feather", n=8, iv=0.32)]),
    _say(BLUE, "……哈……！对我……就……这么凶……！"),
    _say(P, "哈哈……我、我这边好轻……对不起……哈哈……！", portrait="defeat_1"),
    _say(BLUE, "……不准……道歉……哈……"),
    _say(N, "（图腾柱的光闪了一下，铁手套被震开了。两个人跌坐在地上喘气）"),
    _say(CAP, "（举剑挡在前面）……歇一口气！再来！"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"knight_fail_chase": FAIL_CHASE, "knight_fail_boss": FAIL_BOSS}
