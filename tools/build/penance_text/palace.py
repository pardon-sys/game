"""反省篇第四章（上）·被遗弃的旧王宫：旧浴场 → 仆人回廊 → 厨房（PalaceBath / PalaceServants / PalaceKitchen，共同的 PalaceRoom）。
两人同行（Duo）；粉色公主穿着鼠鼠装，挠脚鼠在厨房告别。只写痒、笑、释放后的舒服、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, PRINCESS, RAT, cg, dfile, line, pose, release, say, theater, tk

MAID = "人偶女仆"
HEAD = "女仆长人偶"
CHEF = "糕点师人偶"
MICE = "小老鼠们"

# 玩法里的短台词（data/after/palace.json）
TEXT = {
    "steam": ["好、好大的雾……什么都看不见……", "……雾里，有人在笑。"],
    "laugh": ["嘻嘻……", "哈哈……这边……", "嘻嘻嘻……来呀……"],
    "slide": ["呀——停、停不下来——！", "……滑。"],
    "towel": ["毛、毛巾缠上来了！", "……毛巾，在挠……"],
    "statue": ["雕像弯腰了——脚、脚底！", "……雕像，在刷。"],
    "key": ["钥匙！雕像肚子里掉出来的！", "……钥匙。门，能开了。"],
    "sneeze": ["哈……哈……哈啾！", "……啾。"],
    "broom": ["扫、扫帚追过来了！", "……扫帚，在扫脚。"],
    "lure": ["挠脚鼠，去！", "吱吱！看我的！"],
    "bell": ["叮铃铃——！女仆长往铃那边去了！", "……铃响了。快。"],
    "cream": ["脚底黏黏的……甜甜的……老鼠们闻到了！", "……奶油。……老鼠来了。"],
    "wash": ["洗、洗干净了……", "……干净了。"],
    "fan": ["羽毛扇——脚底——！", "……扇子。……躲。"],
    "door_wait": ["……先去储藏间看看吧。挠脚鼠好像闻到了什么。"],
}


def _bt(n=8, iv=0.18, zone="thigh", fx="hand", by="pants"):
    return A("tickle", who="blue", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


def _bp(v):
    return A("pose", who="blue", visual=v)


def _burst_blue(text):
    acts = [A("flash", time=0.5), A("sfx", sound="ice_crack", volume=-2.0), A("sfx", sound="water_release", volume=-2.0),
            A("shake", who="blue", time=0.4), A("voice", state="laugh")]
    return dict(say(BLUE, text, acts), act="burst", wait=1.0)


def _burst_pink(text):
    return dict(say(P, text, release()), act="burst", wait=1.0)


def _duo(pv="normal", bv="normal", **extra):
    c = {"princess": dict(PRINCESS, at=[-14, 8], visual=pv, anim="helpless" if pv.startswith("helpless") else "idle", dir="right"),
         "blue": {"kind": "npc:blue_princess", "at": [14, 8], "visual": bv, "anim": "helpless" if bv.startswith("helpless") else "idle", "dir": "left"},
         "pants": {"kind": "trap:hand", "at": [20, 10]},
         "rat": {"kind": "monster:rat", "at": [-26, 12], "dir": "right"}}
    c.update(extra)
    return c


# ---------------------------------------------------------------- 两个都倒下（王宫里通用）
DOWN = theater("王宫里双双笑倒", _duo("helpless_1", "helpless_1"), [
    say(N, "（两个人一起笑倒在冰凉的大理石地上。挠脚鼠和千手痒痒裤像是约好了似的，趁机各挠了一通）",
        [tk("rat", zone="sole", fx="lines", n=8, iv=0.14), _bt(8, 0.14)], act=1),
    say(P, "哈哈……这个王宫……到处都是挠人的东西……", emotion="helpless_2"),
    say(BLUE, "……哈……哈……", [_bp("helpless_2")]),
    _burst_pink("（星光在空荡荡的大厅里炸开……哈啊……放出去了……）"),
    say(N, "（两个人互相扶着站起来，回到了刚才经过的地方）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(BLUE, "……再来。"),
])

# ---------------------------------------------------------------- 旧浴场：滑进泡泡浴池
BATH_POOL = theater("旧浴场：滑进泡泡浴池", _duo("helpless_1", "normal", pool={"kind": "trap:sitz_bath", "at": [-10, 12]}), [
    say(N, "（肥皂泡地板一路滑到底——「扑通」一声，粉色公主整个人栽进了旁边的泡泡浴池）", [A("sfx", sound="puddle", volume=-2.0), A("shake", who="princess", time=0.4)], act=1),
    say(P, "噗哈——！泡、泡泡！全是泡泡！", emotion="surprise"),
    say(BLUE, "……（蹲在池边）……没事吧。"),
    say(N, "（池底「咕嘟咕嘟」地冒起了泡。几百年没人用过的浴池，机关还活着——一圈软刷贴着池底转了起来）", [tk("pool", fx="lines", n=8, iv=0.18), pose("giggle")], act=2),
    say(P, "嘻……嘻嘻……池底有刷子……！脚底被刷了……！", emotion="giggle"),
    say(N, "（泡泡一颗一颗在脚心、脚趾缝、小腿上破掉。她想爬出来，扶着池边的手一滑，又坐了回去）", [tk("pool", fx="lines", n=12, iv=0.13), pose("helpless_1")]),
    say(RAT, "（从短裤里探出头，浑身湿透）吱吱！我、我不会游泳——！", [tk("rat", zone="thigh", fx="hand", n=8, iv=0.14)]),
    say(P, "哈哈哈！你别在里面乱扑腾——腿根——哈哈哈！", emotion="helpless_1", act=3),
    say(BLUE, "……手。给我。"),
    say(N, "（蓝色公主伸手去拉——池边的肥皂泡一滑，她也「扑通」一声栽了进去）", [A("sfx", sound="puddle", volume=-2.0), A("shake", who="blue", time=0.4), _bp("helpless_1")]),
    say(BLUE, "……", [_bt(10, 0.14), _bt(6, 0.18, by="pool", zone="sole", fx="lines")]),
    say(BLUE, "……泡、泡泡……裤子……都……哈、哈哈……", [_bp("helpless_2")]),
    say(N, "（两个人在泡泡里笑成一团，刷子和泡泡一点都不客气）", [tk("pool", fx="lines", n=14, iv=0.1), _bt(12, 0.1), pose("helpless_2")]),
    _burst_pink("（星光把一池子泡泡全炸飞了……哈啊……放出去了……）"),
    say(N, "（等泡泡落下来，两个人湿淋淋地爬出浴池，坐在池边喘了好一会儿）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "……这地板，绕着走。", emotion="sad"),
    say(BLUE, "……嗯。"),
])

# ---------------------------------------------------------------- 旧浴场：两个人一起泡温泉（CG）
BATH_FRIEND = theater("旧浴场：温泉", _duo("normal", "normal", pool={"kind": "trap:foot_bath", "at": [0, 14]}), [
    say(N, "（浴场最里面，一口圆圆的温泉还在冒着热气。狮子头出水口里，温水「哗哗」地流着）", act=1),
    say(P, "……温泉！还是热的！", emotion="happy"),
    say(BLUE, "……（闻了闻自己的袖子）……水道的味道。"),
    say(P, "……我也是。……从鼠洞到水道，我身上全是泥和老鼠的味道……", emotion="sad"),
    say(RAT, "（探出头）吱？老鼠的味道怎么了。"),
    say(P, "……洗一洗吧。就一会儿。", emotion="shy"),
    say(N, "（池边的架子上叠着一摞旧浴巾，居然还是软软的。两个人各裹了一条，坐到池边，把腿伸进了温水里）", act=2),
    cg(say(N, "（温水一下子漫过了脚踝，暖意顺着腿一点一点往上爬。两个人同时长长地呼了一口气）")),
    say(P, "……呼……好舒服……", emotion="happy"),
    say(BLUE, "……嗯。"),
    say(P, "……我说。……你一直在出口等我，等了多久？", emotion="shy"),
    say(BLUE, "……不知道。……水声，响了很多遍。"),
    say(P, "……笨蛋。", emotion="shy"),
    say(BLUE, "……你才是。……被关起来，还钻老鼠洞。"),
    say(P, "……嘿嘿。", emotion="happy"),
    say(N, "（粉色公主把头靠在了蓝色公主的肩膀上。蓝色公主僵了一下，没有躲开）"),
    say(BLUE, "……小时候。……好像，也这样泡过。"),
    say(P, "……诶？", emotion="surprise"),
    say(BLUE, "……不记得了。……只是觉得。"),
    say(P, "……我也是。……总觉得，好像很久以前，也有人这样让我靠着。", emotion="sad"),
    say(N, "（两个人都没再说话。温泉的水声里，只有偶尔一两声狮子头的「咕嘟」）"),
    say(N, "（……然后，粉色公主泡在水里的脚边，冒出了一个湿漉漉的小脑袋）", act=3),
    say(RAT, "吱吱！我也要洗！"),
    say(P, "你、你什么时候跳下去的——呀！", [tk("rat", zone="sole", fx="lines", n=8, iv=0.14), pose("giggle")], emotion="giggle"),
    say(N, "（挠脚鼠扒着她的脚，用湿漉漉的胡子在脚心上扫来扫去——「洗脚」洗得特别认真）", [tk("rat", zone="sole", fx="lines", n=12, iv=0.12), pose("helpless_1")]),
    say(P, "哈哈哈！不、不要这样洗——脚心——哈哈哈！", emotion="helpless_1"),
    say(N, "（她一蹬腿，「哗」地溅起一大片水花，全泼在了蓝色公主脸上）", [A("sfx", sound="puddle", volume=-2.0), A("shake", who="blue", time=0.3)]),
    say(BLUE, "……", [_bp("normal")]),
    say(BLUE, "……噗。", [_bp("giggle")]),
    say(P, "你笑了！你刚才又笑了！", emotion="happy"),
    say(BLUE, "……没有。……哈、哈哈……", [_bt(6, 0.18), _bp("helpless_1")]),
    say(N, "（千手痒痒裤听见笑声也凑起了热闹，裤子里的手在浴巾底下揉了揉她的大腿——这下她再也绷不住了）", [_bt(10, 0.14), _bp("helpless_2")]),
    say(N, "（两个人裹着浴巾，在温泉边笑得东倒西歪，水花溅得到处都是）", [tk("rat", zone="sole", fx="lines", n=10, iv=0.12), _bt(10, 0.12), pose("helpless_2")]),
    _burst_pink("（星光「噗」地一下在温泉上炸开，把满池的热气都染成了粉色……哈啊……放出去了……泡着热水，好舒服……）"),
    say(N, "（挠脚鼠被星光吹得翻了个跟头，又湿漉漉地爬回来，在刚释放完、软乎乎的脚心上最后扫了一下——她「呀」地缩成了一团）",
        [tk("rat", zone="sole", fx="lines", n=6, iv=0.15), A("shake", who="princess", time=0.4)]),
    say(RAT, "吱吱！洗得真干净！", act=4),
    say(P, "……哈……哈……洗是洗干净了……可是笑得好累……", [pose("helpless_1"), _bp("helpless_1")], emotion="helpless_1"),
    say(BLUE, "……下次。……不带老鼠。"),
    say(P, "……嗯。下次只有我们两个。", emotion="happy"),
])

# ---------------------------------------------------------------- 仆人回廊：被人偶女仆发现
CAUGHT_FIRST = theater("仆人回廊：被发现了", _duo("helpless_1", "helpless_1", maid={"kind": "npc:doll_maid", "at": [0, -4], "dir": "down"}), [
    say(MAID, "（玻璃眼珠「咔」地转了过来）……发现……灰尘……两、粒。", act=1),
    say(P, "我、我们不是灰尘——！", emotion="surprise"),
    say(MAID, "……打扫……开始。"),
    say(N, "（人偶女仆的力气大得吓人。她一手一个，把两个人按在了地毯上，举起了手里的鸡毛掸子）", [A("shake", who="princess", time=0.4)], act=2),
    say(N, "（掸子从粉色公主的脚底一路掸上去，又在蓝色公主的膝盖窝里掸了掸——一下一下，打扫得一丝不苟）",
        [tk("maid", fx="feather", n=10, iv=0.15), _bt(8, 0.15, by="maid", fx="feather"), pose("helpless_2"), _bp("helpless_2")]),
    say(P, "哈哈哈！鸡、鸡毛掸子——脚底——哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……膝……膝盖窝……哈、哈哈……"),
    say(MAID, "……灰尘……很、顽固。……加、强。", act=3),
    say(N, "（掸子换成了软毛刷，刷子换成了羽毛——人偶女仆一样一样地试，直到两个人笑得说不出话）",
        [tk("maid", fx="feather", n=14, iv=0.1), _bt(12, 0.1, by="maid", fx="feather"), tk("rat", zone="thigh", fx="hand", n=6, iv=0.15)]),
    _burst_pink("（星光炸开，人偶女仆被吹得转了三圈……哈啊……放出去了……）"),
    say(MAID, "……打扫……完毕。……垃、圾……送回……入口。", act=4),
    say(N, "（她把两个人一手一个拎起来，送回了回廊的入口，鞠了一躬，咔哒咔哒地走了）", [pose("helpless_1"), _bp("helpless_1")]),
    say(BLUE, "……慢一点走。……躲进箱子。"),
    say(P, "……还有，按 F，让挠脚鼠跑出去引开她们。", emotion="sad"),
    say(RAT, "吱吱！包在我身上！"),
])

CAUGHT_AGAIN = theater("又被人偶女仆发现了", _duo("helpless_1", "helpless_1", maid={"kind": "npc:doll_maid", "at": [0, -4], "dir": "down"}), [
    say(MAID, "……又是……灰尘。……打扫。", act=1),
    say(N, "（鸡毛掸子熟门熟路地掸过两个人的脚底和膝盖窝）", [tk("maid", fx="feather", n=10, iv=0.12), _bt(8, 0.12, by="maid", fx="feather"), pose("helpless_2"), _bp("helpless_2")]),
    say(P, "哈哈哈！又、又来——！", emotion="helpless_2"),
    _burst_pink("（星光一闪……哈啊……）"),
    say(N, "（又被拎回了入口）", [pose("helpless_1"), _bp("helpless_1")], act=4),
])

# ---------------------------------------------------------------- 仆人回廊：躲藏点（千手裤发作，粉色公主去引开；CG）
HIDE = theater("仆人回廊：帘子后面", _duo("normal", "normal", maid={"kind": "npc:doll_maid", "at": [40, -6], "dir": "left", "hidden": True}), [
    say(N, "（两个人挤进了一面厚厚的丝绒帘子后面。帘子外，人偶女仆咔哒、咔哒地走了过来）", act=1),
    say(P, "（……别出声……等她走过去……）", emotion="sad"),
    say(MAID, "……巡、逻。……巡、逻。", [A("enter", who="maid", to=[24, -6], time=1.0)]),
    say(N, "（就在这时候，蓝色公主腿上的千手痒痒裤，「蠕」地动了一下）", [_bt(4, 0.25)], act=2),
    say(BLUE, "（……！……不、不是现在……）", [_bp("giggle")]),
    say(N, "（裤子里的手像是知道现在不能出声，偏偏挑这个时候，在大腿内侧一圈一圈地揉）", [_bt(10, 0.15)]),
    cg(say(BLUE, "（……唔……唔唔……）", [_bp("helpless_1")])),
    say(N, "（她两只手死死捂着嘴，眼泪都憋出来了，肩膀一抖一抖。帘子跟着她一起，轻轻地晃）"),
    say(MAID, "……帘、子……在动？", [A("move", who="maid", to=[18, -6], time=0.6)]),
    say(P, "（……糟了……再这样下去，两个人都会被发现……）", emotion="sad"),
    say(P, "（小声）……你在这里待着。我去把她引开。", emotion="angry", act=3),
    say(BLUE, "（……！……可是……）"),
    say(P, "（小声）放心。……我有挠脚鼠。", emotion="happy"),
    say(RAT, "（小声）吱。……终于轮到我上场了。"),
    say(N, "（粉色公主从帘子另一头悄悄钻出去，故意踢了一下墙角的铁桶——「哐当」）", [A("sfx", sound="gate", volume=-2.0)]),
    say(MAID, "……那、边。……灰尘。", [A("move", who="maid", to=[60, -6], time=0.8)]),
    say(N, "（人偶女仆咔哒咔哒地追了过去。粉色公主一边跑一边回头冲她做鬼脸，鼠爪鞋踩得啪嗒啪嗒响）"),
    say(N, "（帘子后面，蓝色公主终于松开手，捂着肚子，无声地笑了好一会儿）", [_bt(8, 0.15), _bp("helpless_2")]),
    say(BLUE, "……哈……哈……（小声）……笨蛋。……跑那么快。"),
    say(N, "（过了好一阵，帘子外传来啪嗒啪嗒的脚步声。粉色公主喘着气钻了回来，头发上还沾着一根鸡毛）", [_bp("helpless_1")], act=4),
    say(P, "……甩、甩掉了。……她在储藏间里转圈呢。", emotion="happy"),
    say(BLUE, "……", [_bp("normal")]),
    say(BLUE, "……谢谢。"),
    say(P, "……嘿嘿。下次换你引开，我来憋笑。", emotion="happy"),
    say(BLUE, "……（小声）……好。"),
])

# ---------------------------------------------------------------- 厨房：糕点师人偶「试吃」
CHEF_T = theater("厨房：糕点师的试吃", _duo("normal", "normal", chef={"kind": "npc:doll_maid", "at": [0, -6], "dir": "down"},
                                      mice={"kind": "monster:rat", "at": [-20, 14], "dir": "right"}), [
    say(CHEF, "（戴着高高厨师帽的人偶慢慢转过头）……客人。……试、吃。", act=1),
    say(P, "试吃？……有吃的？", emotion="happy"),
    say(CHEF, "……新品。……奶油。……请、躺下。"),
    say(BLUE, "……躺下？"),
    say(N, "（人偶不由分说，把两个人一左一右按在了长桌上，两双脚并排搁在桌边。她拿起一把裱花袋）", [A("shake", who="princess", time=0.3)], act=2),
    say(N, "（「噗」——一圈雪白的奶油挤在了粉色公主光着的脚心上。凉凉的，滑滑的）", [tk("chef", fx="lines", n=4, iv=0.25), pose("giggle")]),
    say(P, "呀！凉、凉的！为什么挤在脚上——！", emotion="giggle"),
    say(CHEF, "……请、品尝。", [_bt(4, 0.25, by="chef", zone="sole", fx="lines"), _bp("giggle")]),
    say(N, "（「品尝」的不是她们。桌子底下钻出来一群小老鼠，闻着奶油的香味，一只一只爬上桌——开始舔）",
        [tk("mice", fx="lines", n=10, iv=0.14), _bt(8, 0.15, by="mice", zone="sole", fx="lines")], act=3),
    say(P, "哈哈哈！老、老鼠在舔——脚心——趾缝——哈哈哈！", [pose("helpless_1")], emotion="helpless_1"),
    say(BLUE, "……舌、舌头……好小……好痒……哈、哈哈……", [_bp("helpless_1")]),
    say(RAT, "（从短裤里冲出来）吱吱！那是我的奶油！"),
    say(N, "（挠脚鼠也加入了「品尝」。小老鼠们舔得更起劲了，奶油舔完了，人偶又补上一圈）",
        [tk("mice", fx="lines", n=14, iv=0.1), tk("rat", zone="sole", fx="lines", n=10, iv=0.12), _bt(12, 0.1, by="mice", zone="sole", fx="lines"), pose("helpless_2"), _bp("helpless_2")]),
    say(CHEF, "……反、应……很好。……再、来一份。"),
    _burst_blue("……哈……哈哈……不、不要再来一份了……（冰晶炸开，奶油都冻成了冰淇淋……）"),
    _burst_pink("（星光跟着炸开……哈啊……放出去了……脚底甜甜的……）"),
    say(N, "（冻成冰淇淋的奶油，小老鼠们舔得更开心了——刚释放完的脚心敏感得发烫，每一口都让两个人在桌上弹一下）",
        [tk("mice", fx="lines", n=8, iv=0.15), _bt(8, 0.15, by="mice", zone="sole", fx="lines"), pose("helpless_2"), _bp("helpless_2")], act=4),
    say(CHEF, "……试吃……结、束。……谢谢、惠顾。"),
    say(N, "（两个人从桌上滑下来，脚底还是黏黏的、甜甜的）", [pose("helpless_1"), _bp("helpless_1")]),
    say(P, "……去水槽把脚洗了吧。……不然老鼠会一直跟着我们。", emotion="sad"),
])

# ---------------------------------------------------------------- 厨房：试吃推销员（换薄荷糖）
PROMOTER = theater("厨房：试吃推销员", _duo("normal", "normal", mice={"kind": "monster:rat", "at": [-20, 14], "dir": "right"},
                                         cat={"kind": "trap:cat_guard", "at": [22, 14]}), [
    say(N, "（小摊的木牌上写着褪色的字：「试吃推销员招募中。报酬：薄荷糖一罐」）", act=1),
    say(P, "薄荷糖！含着就能憋住笑的那种！", emotion="happy"),
    say(BLUE, "……推销员。……要做什么。"),
    say(N, "（摊子后面的人偶递来两条围裙，还有一托盘小点心：饼干屑、奶酪丁、小鱼干、蜂蜜）"),
    say(CHEF, "……把、试吃品……放在、身上。……让客人……品尝。"),
    say(P, "……客人是谁？", emotion="question"),
    say(N, "（客人来了。厨房各个角落里，小老鼠、一只肥猫、还有几只不知道从哪里冒出来的小鸟，齐刷刷地看着她们）", act=2),
    say(N, "（饼干屑撒在粉色公主的脚背上，奶酪丁放在脚趾缝里；小鱼干搁在蓝色公主的膝盖上，蜂蜜抹了一点点在脚心）",
        [tk("mice", fx="lines", n=6, iv=0.2), pose("giggle"), _bp("giggle")]),
    say(P, "嘻……好、好多客人……一起来……", emotion="giggle"),
    say(N, "（小老鼠们抢着啃脚趾缝里的奶酪，小鸟啄着脚背上的饼干屑；肥猫跳上蓝色公主的膝盖，叼走小鱼干，顺便舔了一口脚心上的蜂蜜）",
        [tk("mice", fx="lines", n=12, iv=0.12), _bt(10, 0.12, by="cat", zone="sole", fx="lines")], act=3),
    say(BLUE, "……猫、猫舌头……粗……哈、哈哈……", [_bp("helpless_1")]),
    say(P, "哈哈哈！小鸟啄——老鼠啃——不、不要一起——！", [pose("helpless_1")], emotion="helpless_1"),
    say(CHEF, "……推销、口号。……「好吃、请买」。"),
    say(P, "好、好吃……请买……哈哈哈……！", emotion="helpless_2"),
    say(BLUE, "……好……吃……请……哈哈……买……", [_bp("helpless_2")]),
    say(N, "（客人越来越多。等托盘上的试吃品全被吃完，两个人已经笑得瘫在了摊子上）", [tk("mice", fx="lines", n=12, iv=0.1), _bt(12, 0.1, by="cat", zone="sole", fx="lines"), pose("helpless_2")]),
    _burst_pink("（星光一闪，客人们一哄而散……哈啊……放出去了……）"),
    say(CHEF, "……推销、成功。……报、酬。", act=4),
    say(N, "（人偶递过来一个小罐子。打开一看，里面是一颗颗凉丝丝的薄荷糖）", [pose("helpless_1"), _bp("helpless_1")]),
    say(P, "……薄荷糖……拿到了……用笑换来的……", emotion="helpless_1"),
    say(BLUE, "……省着用。"),
])

# ---------------------------------------------------------------- 厨房：挠脚鼠告别（脱下鼠鼠装）
FAREWELL = theater("厨房：挠脚鼠的告别", _duo("normal", "normal", cheese={"kind": "trap:trophy_chest", "at": [0, -8]}), [
    say(N, "（储藏间的最里面，有一块比人还大的奶酪。几百年了，居然还香喷喷的）", act=1),
    say(RAT, "（从短裤里窜出来，扑到奶酪上）吱——！！！奶酪！！！这么大的奶酪！！！"),
    say(P, "……你的眼睛在发光。", emotion="question"),
    say(RAT, "……公主。我决定了。我要住在这里。"),
    say(P, "……诶？", emotion="surprise"),
    say(RAT, "这块奶酪，够我吃一辈子了。……而且，这里是王宫。挖那条洞的小姑娘，说不定以前就住在这里。"),
    say(P, "……这样啊。……那，鼠鼠短裤和鼠爪鞋……", emotion="sad"),
    say(RAT, "吱。报酬付清了。还给你原来的样子。……不过走之前——", act=2),
    say(P, "……「不过走之前」……我有不好的预感……", emotion="sad"),
    say(RAT, "告别仪式！挠脚鼠一族送别人，要把一路走过的地方都再挠一遍！"),
    say(N, "（它「嗖」地钻回短裤里——先是大腿根，那是鼠洞里那道低矮的缝）", [tk("rat", zone="thigh", fx="hand", n=8, iv=0.14), pose("giggle")]),
    say(P, "噫——！又、又来——！", emotion="giggle"),
    say(N, "（然后是脚心和趾缝，那是卡住的窄缝，一个缝一个缝地闻过去）", [tk("rat", zone="sole", fx="lines", n=10, iv=0.13), pose("helpless_1")]),
    say(RAT, "小脚趾那个缝，还是最香。吱吱。"),
    say(P, "哈哈哈！别、别闻了——！", emotion="helpless_1", act=3),
    say(N, "（再然后，从脚底一路窜到腰上，又从腰上窜回脚底——那是竖井。一趟，两趟，三趟）",
        [tk("rat", zone="sole", fx="lines", n=8, iv=0.12), A("tickle", who="princess", by="rat", zone="waist", fx="hand", repeat=8, interval=0.12), pose("helpless_2")]),
    say(P, "哈哈哈哈！上上下下——又来了——哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……（在旁边看着）……噗。", [_bp("giggle")]),
    say(N, "（听见蓝色公主的笑声，千手痒痒裤也来凑热闹——这下两个人一起笑倒在了奶酪旁边）", [_bt(10, 0.12), _bp("helpless_2")]),
    _burst_pink("（星光炸开，奶酪上落了一层亮晶晶的星屑……哈啊……放出去了……）"),
    say(N, "（星光散去的时候，鼠鼠短裤和鼠爪鞋化成一阵白烟，不见了。粉色公主又穿回了原来的裙子和袜子）", [A("flash", time=0.4), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(BLUE, "……（把一双粉色的小鞋放在她面前）……一直替你拿着。"),
    say(P, "……谢谢。", emotion="happy"),
    say(N, "（她穿上鞋，站起来，跺了跺脚。……好久没有这么踏实的感觉了）"),
    say(RAT, "（坐在奶酪顶上）吱。公主，你笑起来很好听。……别忘了，还有人在等你。"),
    say(P, "……嗯。谢谢你，挠脚鼠。……虽然你挠了我一路。", emotion="happy"),
    say(RAT, "吱吱。那是谢礼呀。"),
])

THEATERS = {"palace_down": DOWN, "bath_pool": BATH_POOL, "bath_friendship": BATH_FRIEND, "servants_caught_first": CAUGHT_FIRST,
            "servants_caught": CAUGHT_AGAIN, "servants_hide": HIDE, "kitchen_chef": CHEF_T, "kitchen_promoter": PROMOTER, "kitchen_farewell": FAREWELL}


def _spot(name, look, prompt, yes, theater_id, again):
    return dfile("", name, {
        "default": {"lines": [L(look, N)], "prompt": prompt, "choices": [{"text": yes, "next": "go"}, {"text": "……先不了", "next": "no"}]},
        "go": {"lines": [L(yes, P)], "theater": theater_id},
        "no": {"lines": [L("……等一下再说。", P)]},
        "again": {"lines": [L(again, N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:" + theater_id}, "node": "again"}, {"node": "default"}])


DIALOGUES = {
    "palace_mirror": dfile("", "起雾的镜子", {"default": {"lines": [
        L("（一面落满水汽的大镜子。她用袖子擦了擦——镜面上有一行用手指写的字，被水汽留了下来）", N),
        L("（「姐姐，泡好了吗？——小不点」）", N),
        L("……小不点。又是这个名字。", P, "surprise"),
        L("……短裤里面，也绣着这三个字。", BLUE),
        L("……这个王宫里，以前住着一个「小不点」，还有她的姐姐。", P, "sad")]}}),
    "palace_schedule_1": dfile("", "旧排班表", {"default": {"lines": [
        L("（墙上钉着一张发黄的排班表）", N),
        L("（「早：两位小殿下的洗脚水（温，加薄荷）。晚：给小殿下读故事，读到她们睡着为止」）", N),
        L("……两位小殿下。", P, "surprise"),
        L("……两位。", BLUE)]}}),
    "palace_schedule_2": dfile("", "女仆的日记", {"default": {"lines": [
        L("（一本翻开的日记，字迹很工整）", N),
        L("（「今天两位小殿下又把洗脚盆打翻了，笑得满走廊都是。女王陛下说，笑声是王宫最好的装饰」）", N),
        L("（「……可是那天晚上以后，王宫里就再也没有笑声了」）", N),
        L("……那天晚上。", P, "sad")]}}),
    "palace_bell": dfile("", "唤人铃", {"default": {"lines": [L("（墙上挂着一根拉绳，连着走廊里的铃铛。拉一下，女仆们就会过来）", N)],
                                                       "prompt": "拉铃？", "choices": [{"text": "拉一下", "next": "ring"}, {"text": "不拉", "next": "no"}]},
                                           "ring": {"lines": [L("（叮铃铃——！）", N)], "set": {"call": "palace_bell"}},
                                           "no": {"lines": [L("……再等等。", P)]}}),
    "palace_key": dfile("", "钥匙", {"default": {"lines": [L("（女仆长的腰带上原来挂着的钥匙，现在就在桌上）", N)], "set": {"call": "palace_key"}}}),
    "kitchen_chef": _spot("糕点师人偶", "（一个戴着高高厨师帽的人偶，站在长桌前，手里拿着裱花袋）", "答应「试吃」？", "……试吃就试吃。", "kitchen_chef",
                          "（糕点师人偶冲她们鞠了一躬：「……欢迎、再来」）"),
    "kitchen_booth": _spot("试吃推销员的小摊", "（「试吃推销员招募中。报酬：薄荷糖一罐」）", "当一次试吃推销员？", "……为了薄荷糖。", "kitchen_promoter",
                           "（小摊收起来了。木牌上多了一行字：「今日推销已结束」）"),
    "kitchen_sink": dfile("", "水槽", {"default": {"lines": [L("（水龙头还能出水。哗啦啦——脚底的奶油洗掉了）", N)], "set": {"call": "palace_wash"}}}),
}

SIGNS = {
    "palace_bath_door": [{"speaker": N, "text": "（门锁着。锁孔的形状……和雕像手里的东西很像）"}],
    "palace_servants_door": [{"speaker": N, "text": "（通往厨房的门锁着。钥匙……大概在女仆长那里）"}],
    "palace_kitchen_north": [{"speaker": N, "text": "（北门后面是一条长长的走廊，堆满了倒下的书架。……要先把这里的事办完）"}],
}


def bath_in():
    s = [
        {"actions": [A("camera", to=[4, 4], zoom=1.0, time=0.4)], "wait": 0.4},
        line(N, "（缝的另一头，是一间又高又大的屋子。大理石的地板，金色的柱子，到处都是白茫茫的蒸汽）"),
        line(P, "……这里是……浴场？王宫的浴场？", "surprise"),
        line(BLUE, "……好大。"),
        line(RAT, "（探出头，嗅了嗅）吱吱。热水的味道。还有肥皂。还有……很多很多年没有人来过的味道。"),
        line(N, "（蒸汽深处，远远地传来一阵小孩的笑声。……嘻嘻嘻……）"),
        line(P, "……有人在笑？", "surprise"),
        line(BLUE, "……跟着声音走。"),
        {"actions": [A("camera", reset=True, time=0.4), A("notify", text="穿过旧浴场（雾里跟着笑声走；肥皂泡地板会一直滑）")], "wait": 0.4},
    ]
    return {"name": "旧浴场", "letterbox": True, "skippable": True, "steps": s}


def servants_in():
    s = [
        line(N, "（一条长长的回廊。两边一扇扇小门，是从前仆人们住的房间。回廊里，有什么东西在咔哒、咔哒地走）"),
        line(N, "（是人偶。穿着女仆装、拿着鸡毛掸子的人偶，玻璃眼珠在昏暗里一闪一闪）"),
        line(P, "……女仆？……人偶？", "surprise"),
        line(BLUE, "……别被看见。……躲进箱子、帘子后面。"),
        line(RAT, "吱吱。被看见了，按 F，我跑出去把她们引开。"),
        {"actions": [A("notify", text="潜入仆人回廊（躲进箱子：E；让挠脚鼠引开人偶：F）")], "wait": 0.3},
    ]
    return {"name": "仆人回廊", "letterbox": True, "skippable": True, "steps": s}


def kitchen_in():
    s = [
        line(N, "（推开门，一股甜甜的香味扑面而来。巨大的厨房里，灶台上的锅还在冒着若有若无的热气）"),
        line(RAT, "（从短裤里窜出半个身子）吱——！！奶酪！我闻到了奶酪！在那边——储藏间！"),
        line(P, "……你冷静一点。", "question"),
        line(BLUE, "……人偶。……还有猫。……还有老鼠。"),
        {"actions": [A("notify", text="探索厨房（踩到奶油会被老鼠追，去水槽洗脚）")], "wait": 0.3},
    ]
    return {"name": "厨房", "letterbox": True, "skippable": True, "steps": s}


def part1_end():
    s = [
        line(N, "（北门后面，倒下的书架堆成了一座小山。书页从缝里散出来，落了一地）"),
        line(P, "……图书馆？", "surprise"),
        line(BLUE, "……王国的书。……说不定，有那天晚上的事。"),
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("chapter_end", title="第四章　旧王宫（上）", subtitle="——（待续）书页上，写着两个小殿下的名字", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "图书馆的门", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"palace_bath_in": bath_in, "palace_servants_in": servants_in, "palace_kitchen_in": kitchen_in, "palace_part1_end": part1_end}
