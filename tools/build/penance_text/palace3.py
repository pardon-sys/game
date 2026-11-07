"""反省篇第四章（下）·旧王宫：王座前厅 → 钟楼 / 隧道与密室 → 王座间 Boss「封笑的女王画像」（PalaceAnte / PalaceClock / PalaceTunnels / PalaceThrone）。
钟顶敲十三下 → 王座间的封印松开；三层画布（颜料泼洒 + 画像小手 → 小画像分身 → 拉进画里 + 两人各释放一次），每破一层画像说一句胡话；
画布烧穿的缺口后面掉出另半枚徽章 → 两半合在一起、听见有人哼摇篮曲（不揭露身份）→ 章末「第四章　旧王宫　完」。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, PRINCESS, cg, dfile, line, pose, release, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo, _spot

KEEPER = "守钟人偶"
PORTRAIT = "女王画像"
IMP = "收路费的小鬼"
QUEEN_DIARY = "日记（字迹很秀气）"

# 画像的胡话（第 5.3 节）：每破一层说一句，战斗中随机冒一句
GIBBERISH = [
    "今天的汤是蓝色的。蓝色的汤不能用勺子喝，要用耳朵听。",
    "左边的鞋子比右边的鞋子早出生三天，所以它总是先走。",
    "我数过天花板上的星星，一共有十三颗半。那半颗被谁借走了？",
    "摇篮在唱歌，歌在找摇篮。……它们说好了，下雨的时候见面。",
    "不要相信生日蛋糕。蛋糕上的蜡烛，都是别人的名字。",
    "钟敲了十三下以后，所有的猫都会忘记自己是猫。",
    "二十二码半的袜子，是给云穿的。云的脚很怕痒，所以一直在跑。",
    "半个月亮掉进了井里，另外半个还在天上找它。",
]
LAST_WORDS = "……嘘。画框后面，有人在睡觉。"

TEXT = {
    "gear": ["齿、齿轮夹住脚踝了——！", "……卡住了。……齿轮。"],
    "brake": ["……我按住刹车。快过。", "我拉住了！快过去！"],
    "pendulum": ["钟摆的羽毛扫过来了——！", "……钟摆。……被扫了。"],
    "wind": ["风、风好大——羽毛全吹过来了！", "……逆风。……走不动。"],
    "keeper_wake": ["……那个人偶，动了。", "它、它醒了！快跑！"],
    "gate": ["拉下闸门了！", "……闸门。……挡一会儿。"],
    "web": ["粘、粘住了！小蜘蛛爬上来了——！", "……蛛网。……粘住了。"],
    "burn": ["烧掉了！", "……烧开了。"],
    "mimic": ["呀！宝箱咬住脚了——！", "……这个是宝箱怪。"],
    "chest_ok": ["这个是真的宝箱！", "……真的。"],
    "paint": ["颜料！脚底沾上颜料了——画笔追过来了！", "……颜料。……画笔在追。"],
    "hand": ["画里伸出手来了！", "……画里的手。"],
    "pulled": ["被、被拉进去了——！", "……她被拉进画里了。"],
    "inside": ["这里是……画里面？", "画笔……画笔追过来了！"],
    "escape": ["出来了！", "……回来了。"],
    "small_up": ["墙上的小画像全醒了！", "……小画像。……先打它们。"],
    "weak": ["画布露出破绽了！打它！", "……破绽。……现在。"],
    "gibberish": GIBBERISH,
}


# ================================================================ 钟楼
GEAR_RIDE = theater("钟楼：挂在齿轮上", _duo("normal", "normal", gear={"kind": "trap:spinwheel", "at": [-10, -6]}), [
    say(N, "（三层的东北角，一个比人还高的大铜齿轮慢慢地转着。齿轮的一边连着上一层，另一边连着地上的一根转轴）", act=1),
    say(BLUE, "……楼梯断了。……只能坐齿轮上去。"),
    say(P, "一个人坐齿轮，一个人在下面转轴？……那我坐！你力气比我大！", emotion="happy"),
    say(BLUE, "……好。……抓紧。"),
    say(N, "（粉色公主爬上齿轮的边，蓝色公主握住转轴，一圈、两圈——齿轮「嘎吱嘎吱」地带着她往上升）", [A("sfx", sound="conveyor", volume=-4.0)], act=2),
    say(P, "升、升起来了！好高——", emotion="surprise"),
    say(N, "（升到一半，齿轮「咔」地卡住了。齿缝里伸出一簇簇积了灰的羽毛——那是以前给齿轮掸灰用的——正好贴着她的腰）",
        [A("shake", who="princess", time=0.4), tk("gear", fx="feather", n=8, iv=0.16), pose("giggle")]),
    say(P, "嘻……羽、羽毛……腰……不要在这个时候……！", emotion="giggle"),
    cg(say(BLUE, "……（咬着牙转转轴）……卡住了。……再坚持一下。")),
    say(N, "（蓝色公主每使一次劲，齿轮就抖一下，齿缝里的羽毛就跟着在她腰侧、肋下来回地刷）",
        [tk("gear", fx="feather", n=12, iv=0.12), A("tickle", who="princess", by="gear", zone="armpit", fx="feather", repeat=8, interval=0.15), pose("helpless_1")], act=3),
    say(P, "哈哈哈！你、你一转它就刷——不要转了——不对，要转——哈哈哈！", emotion="helpless_1"),
    say(BLUE, "……到底转不转。"),
    say(P, "转！转！快转——哈哈哈哈！", [pose("helpless_2")], emotion="helpless_2"),
    say(N, "（齿轮又卡了一下。她两条腿在半空中乱蹬，羽毛顺着腰一路刷到了脖子）", [tk("gear", fx="lines", n=14, iv=0.1)]),
    _burst_pink("（星光在半空中炸开，齿轮被震得「哐」地一声转了过去……哈啊……放出去了……）"),
    say(N, "（齿轮一口气把她送到了上一层。她趴在平台边上，喘着气。……齿缝里最后一根羽毛，又在她刚释放完、敏感得要命的腰上蹭了一下）",
        [tk("gear", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1")], act=4),
    say(P, "呀！……哈……哈……上来了……梯子……我放梯子下来……", emotion="helpless_1"),
    say(BLUE, "……辛苦了。"),
])

CLOCK_CAUGHT = theater("钟楼：被守钟人偶抓住", _duo("helpless_1", "helpless_1", keeper={"kind": "npc:clock_keeper", "at": [0, -6], "dir": "down"}), [
    say(KEEPER, "（咔哒、咔哒）……钟楼……不准……乱跑。……打扫。", act=1),
    say(N, "（守钟人偶一手拎起一个，像挂钟摆一样把两个人倒挂在钟楼的横梁上，羽毛掸子「唰唰」地掸了起来）",
        [tk("keeper", fx="feather", n=10, iv=0.14), _bt(8, 0.14, by="keeper", zone="waist", fx="feather"), pose("helpless_2"), _bp("helpless_2")], act=2),
    say(P, "哈哈哈！掸、掸灰不是这样掸的——！", emotion="helpless_2"),
    say(KEEPER, "……这里。……灰尘。……很多。"),
    say(N, "（掸子从腰侧掸到肋下，又从肋下掸回膝盖窝。它掸得一丝不苟，就像在擦一口很贵的钟）",
        [tk("keeper", fx="lines", n=14, iv=0.1), _bt(12, 0.1, by="keeper", zone="thigh", fx="feather")], act=3),
    say(BLUE, "……哈、哈哈……干、干净了……已经很干净了……"),
    _burst_blue("……哈……哈哈……（冰晶炸开，横梁上挂了一排冰柱……）"),
    _burst_pink("（星光跟着炸开，守钟人偶的发条被震得停了一下……哈啊……放出去了……）"),
    say(N, "（发条重新「咔哒咔哒」地转起来。它把两个人放回了楼梯口，鞠了一躬，又慢吞吞地走回了原处）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(KEEPER, "……下次……走慢一点。"),
    say(P, "……下次跑快一点……", emotion="sad"),
])

# ================================================================ 隧道与密室
TOLL = theater("隧道：用痒付路费", _duo("normal", "normal", imp1={"kind": "monster:imp", "at": [-20, -4], "dir": "right"},
                                         imp2={"kind": "monster:imp", "at": [20, -4], "dir": "left"},
                                         imp3={"kind": "monster:imp", "at": [0, 14], "dir": "up"}), [
    say(IMP, "嘻嘻！此路是我开！此树是我栽！要从这里过，留下买路——", act=1),
    say(P, "……我们没有钱。", emotion="sad"),
    say(IMP, "没钱？没钱也行！我们收别的！"),
    say(BLUE, "……收什么。"),
    say(IMP, "收——笑声！一个人一百声！我们来数！"),
    say(N, "（小鬼们「呼啦」一下围了上来。一只拿羽毛、一只拿小刷子、一只什么也不拿——它用的是手）", act=2),
    say(N, "（羽毛钻进了腰侧，小刷子刷过膝盖窝，小手在肋下一下一下地点）",
        [tk("imp1", fx="feather", n=10, iv=0.14), _bt(8, 0.15, by="imp2", zone="thigh", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(IMP, "一、二、三……太慢了！大声点！"),
    say(P, "嘻……嘻嘻……数、数得这么认真……", emotion="giggle"),
    cg(say(N, "（两个人背靠背坐在地上，被小鬼们团团围住。一只小鬼拿着羽毛笔，认认真真地在账本上画正字）")),
    say(IMP, "四十七、四十八……蓝色的那个！你一声都没笑！不算！"),
    say(BLUE, "……我在笑。……心里。"),
    say(IMP, "心里的不算！伙计们，蓝色的加收！", act=3),
    say(N, "（三只小鬼一起扑向蓝色公主。千手痒痒裤听见了「加收」，也很配合地动了起来）",
        [_bt(14, 0.1), A("tickle", who="blue", by="imp3", zone="waist", fx="hand", repeat=10, interval=0.12), _bp("helpless_2")]),
    say(BLUE, "……噗……哈、哈哈……裤子……你别帮它们……哈哈哈……"),
    say(P, "哈哈哈！一起付！我也算上——", [tk("imp1", fx="lines", n=12, iv=0.11), pose("helpless_2")], emotion="helpless_2"),
    _burst_blue("……哈……哈哈……（冰晶炸开，账本冻成了一块冰砖……）"),
    _burst_pink("（星光跟着炸开，冰砖上的正字闪闪发亮……哈啊……放出去了……）"),
    say(IMP, "（翻账本）……一百零三、一百零四……够了够了！还多了！找零！", act=4),
    say(N, "（「找零」是一只小鬼在两个人刚释放完、敏感得发烫的脚心上，一人戳了一下）",
        [tk("imp3", fx="hand", n=3, iv=0.2), _bt(3, 0.2, by="imp3", zone="sole", fx="hand"), A("shake", who="princess", time=0.3), A("shake", who="blue", time=0.3)]),
    say(P, "呀！……那、那不叫找零！", emotion="angry"),
    say(IMP, "嘻嘻！欢迎下次光临！"),
])

QUILT = theater("密室：女王寝室的羽毛被子", _duo("normal", "normal", bed={"kind": "trap:supine", "at": [0, 0]}), [
    say(N, "（暗道尽头是一间寝室。一张挂着褪色玫瑰帐子的大床，床上铺着一条又厚又软的白羽毛被子）", act=1),
    say(P, "……好软的被子。……躺一下，就一下。", emotion="happy"),
    say(BLUE, "……我也。……走了好久。"),
    say(N, "（两个人刚躺上去，被子就「呼」地卷了起来——像包春卷一样，把两个人一起裹了进去，只剩两颗脑袋露在外面）",
        [A("shake", who="princess", time=0.4), A("shake", who="blue", time=0.4)], act=2),
    say(P, "诶！？被、被子卷起来了！", emotion="surprise"),
    say(N, "（被子里的羽毛一根根竖了起来，开始在两个人身上慢慢地蹭。腰、肋下、膝盖窝、脚心——被子里哪里都是）",
        [tk("bed", fx="feather", n=10, iv=0.15), _bt(8, 0.15, by="bed", zone="waist", fx="feather"), pose("giggle"), _bp("giggle")]),
    cg(say(P, "嘻嘻……被、被子里面……全是羽毛……！", emotion="giggle")),
    say(BLUE, "……（脸贴着脸）……你、别动……你一动，羽毛就……"),
    say(P, "是、是你先动的——哈哈……！", [pose("helpless_1"), _bp("helpless_1")], emotion="helpless_1", act=3),
    say(N, "（两个人越挣扎，被子裹得越紧；被子裹得越紧，羽毛蹭得越快）",
        [tk("bed", fx="lines", n=14, iv=0.1), _bt(14, 0.1, by="bed", zone="thigh", fx="feather"), pose("helpless_2"), _bp("helpless_2")]),
    say(P, "哈哈哈！脚、脚底也有——这条被子到底有多少羽毛——！", emotion="helpless_2"),
    say(BLUE, "……哈、哈哈……不、不行了……"),
    _burst_blue("……哈……哈哈……（冰晶炸开，被子冻得硬邦邦的……）"),
    _burst_pink("（星光跟着炸开，冻住的被子「啪」地裂开了一条缝……哈啊……放出去了……）"),
    say(N, "（两个人从被子的缝里滚了出来，摔在地毯上。……被子里最后一根羽毛飘出来，落在粉色公主的脚心上，轻轻地转了一圈）",
        [tk("bed", fx="feather", n=3, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……这、这床是给谁睡的啊……", emotion="helpless_1"),
    say(BLUE, "……被子上绣着字。……「给怕冷的小不点」。"),
    say(P, "……又是小不点。", emotion="sad"),
])

CRADLE = theater("密室：婴儿房的摇篮", _duo("normal", "normal", c1={"kind": "trap:cradle_bench", "at": [-14, 2]}, c2={"kind": "trap:cradle_bench", "at": [14, 2]}), [
    say(N, "（两个一模一样的小摇篮并排放着，一个系着粉色的丝带，一个系着蓝色的丝带）", act=1),
    say(P, "……两个摇篮。", emotion="surprise"),
    say(BLUE, "……（蹲下来，摸了摸蓝色的那个）……好小。"),
    say(N, "（摇篮自己轻轻地摇了起来。摇篮边上缝着的小布偶伸出了软软的小手，一把抓住了两个人蹲着的脚踝）",
        [A("shake", who="princess", time=0.3), A("shake", who="blue", time=0.3)], act=2),
    say(P, "诶！？布、布偶的手——", emotion="surprise"),
    say(N, "（小手隔着袜子在脚心上「咿呀咿呀」地抓——就像小婴儿抓东西那样，没轻没重的）",
        [tk("c1", fx="hand", n=10, iv=0.15), _bt(8, 0.15, by="c2", zone="sole", fx="hand"), pose("giggle"), _bp("giggle")]),
    say(P, "嘻嘻……好、好痒……它力气还挺大……！", emotion="giggle"),
    say(BLUE, "……唔……放、放手……", act=3),
    say(N, "（摇篮摇得越快，小手抓得越欢。一只抓脚心，一只挠趾缝，还有一只摸到了膝盖窝）",
        [tk("c1", fx="lines", n=14, iv=0.1), _bt(12, 0.1, by="c2", zone="thigh", fx="hand"), pose("helpless_2"), _bp("helpless_2")]),
    say(P, "哈哈哈！趾缝——它怎么知道趾缝——！", emotion="helpless_2"),
    _burst_pink("（星光在婴儿房里炸开，两个摇篮被吹得摇到了最高……哈啊……放出去了……）"),
    say(N, "（摇篮慢慢停了下来，小手也松开了。……蓝色的那个摇篮里，小布偶的手又在蓝色公主的脚心上挠了一下，像是在说「再玩一会儿」）",
        [_bt(4, 0.2, by="c2", zone="sole", fx="hand"), _bp("helpless_1"), pose("helpless_1")], act=4),
    say(BLUE, "……噗。……（小声）……调皮。"),
    say(P, "……你刚才，笑得好温柔。", emotion="happy"),
])

# ================================================================ 王座间
PAINT_TRAPPED = theater("王座间：被困在画里", _duo("helpless_1", "normal", frame={"kind": "trap:feather_curtain", "at": [-6, -8]}), [
    say(N, "（画里的世界慢慢合拢了。她跑不出去，整个人变成了画布上的一幅小画——颜料一笔一笔地涂在她身上）", act=1),
    say(PORTRAIT, "（画像的声音从四面八方传过来）……别动。……画歪了。"),
    say(N, "（三支画笔围着她转，在手臂上画花，在腰上画波浪，在膝盖窝里画小圈）",
        [tk("frame", fx="feather", n=10, iv=0.14), pose("helpless_1")], act=2),
    say(P, "嘻嘻……画、画笔……好凉……好痒……！", emotion="giggle"),
    cg(say(BLUE, "……（双手贴着画布）……我在这里。……等我。", [_bp("normal")])),
    say(N, "（画布在蓝色公主手掌底下像水面一样晃。她看得见里面，可是怎么也伸不进去）"),
    say(PORTRAIT, "……这一幅，要画很久很久。……先画脚心。", act=3),
    say(N, "（画笔蘸满了颜料，在她的脚心上慢慢地画起了一朵很复杂、很复杂的花）",
        [tk("frame", fx="lines", n=14, iv=0.1), pose("helpless_2")]),
    say(P, "哈哈哈！花、花瓣太多了——画简单一点——哈哈哈！", emotion="helpless_2"),
    _burst_pink("（星光在画里炸开，可是画布把光吞了进去——画像的画框一下子亮了起来……）"),
    say(PORTRAIT, "……好亮的笑声。……再多一点。", act=4),
    say(N, "（画框四周涨起了一圈紫色的光。……画像变强了。画笔又凑了上来，在她刚释放完、敏感得要命的脚心上点了一下）",
        [tk("frame", fx="hand", n=3, iv=0.2), A("shake", who="princess", time=0.3)]),
    say(BLUE, "……（转过身，面对画框）……还给我。"),
])

BOSS_FAIL = theater("王座间：被画像抓住", _duo("helpless_1", "helpless_1", frame={"kind": "trap:feather_curtain", "at": [0, -10]}), [
    say(PORTRAIT, "……累了吗。……那就……留下来。……当画。", act=1),
    say(N, "（画框里伸出了几十只画出来的小手，拖着长长的颜料尾巴，把两个人按在了王座的台阶上）",
        [A("shake", who="princess", time=0.4), A("shake", who="blue", time=0.4)], act=2),
    cg(say(N, "（小手们在腰上、肋下、腋窝里一起动了起来。每一只都沾着颜料，挠过的地方留下一道道彩色的印子）",
           [tk("frame", fx="hand", n=12, iv=0.12), _bt(10, 0.12, by="frame", zone="waist", fx="hand"), pose("helpless_2"), _bp("helpless_2")])),
    say(P, "哈哈哈！颜、颜料——身上全是颜料——！", emotion="helpless_2"),
    say(BLUE, "……哈、哈哈……裙子……画、画花了……"),
    say(PORTRAIT, "……好看。……这样好看。……今天的汤是蓝色的。", act=3),
    say(N, "（画像说着谁也听不懂的话，小手越来越多，挠得越来越快）",
        [tk("frame", fx="lines", n=16, iv=0.09), _bt(14, 0.09, by="frame", zone="armpit", fx="hand")]),
    _burst_blue("……哈……哈哈……（冰晶炸开，一排小手冻在了半空中……）"),
    _burst_pink("（星光跟着炸开，冻住的小手碎成了一地彩色的冰渣……哈啊……放出去了……）"),
    say(N, "（剩下的几只小手在两个人刚释放完的脚心上画了一个笑脸，才慢吞吞地缩回画框里）",
        [tk("frame", fx="hand", n=4, iv=0.2), _bt(4, 0.2, by="frame", zone="sole", fx="hand"), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(PORTRAIT, "……还要再来吗。……我等你们。"),
    say(P, "……当然要来！", emotion="angry"),
])

SMALL = "小画像们"

FAIL_PAINT = theater("王座间：被涂成画", _duo("helpless_1", "helpless_1", frame={"kind": "trap:feather_curtain", "at": [0, -12]},
                                         b1={"kind": "trap:brush", "at": [-16, 10]}, b2={"kind": "trap:brush", "at": [16, 10]}), [
    say(N, "（两个人脚下一滑，一起坐进了一大滩彩色的颜料里。颜料黏黏的，站不起来）", act=1),
    say(PORTRAIT, "……好。……画布准备好了。……开始作画。"),
    say(N, "（四支画笔「嗖」地飞了过来。一支在粉色公主的腿上画小花，一支在蓝色公主的腰上画波浪线）",
        [tk("b1", fx="feather", n=10, iv=0.14), _bt(8, 0.15, by="b2", zone="waist", fx="feather"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "嘻……嘻嘻……画、画笔好凉……！", emotion="giggle"),
    cg(say(PORTRAIT, "（举起一块画出来的小牌子）……七分。……花瓣不够圆。……重画。")),
    say(BLUE, "……打、打分……？……哈、哈……"),
    say(N, "（画笔把刚画好的花擦掉，又重新画了一遍。这一遍画得更慢、更仔细，一笔一笔地描过膝盖窝）",
        [tk("b1", fx="lines", n=14, iv=0.1), _bt(12, 0.11, by="b2", zone="thigh", fx="feather"), pose("helpless_2"), _bp("helpless_2")], act=3),
    say(P, "哈哈哈！重、重画也不用画在同一个地方——！", emotion="helpless_2"),
    say(PORTRAIT, "……九分。……左边的鞋子先笑的。……扣一分。"),
    _burst_blue("……哈……哈哈……（冰晶炸开，颜料冻成了一块块彩色的糖片……）"),
    _burst_pink("（星光跟着炸开，彩色的糖片碎了一地……哈啊……放出去了……）"),
    say(N, "（最后一支画笔在两个人刚释放完、敏感得发烫的脚心上，一人签了一个名字）",
        [tk("b1", fx="hand", n=4, iv=0.2), _bt(4, 0.2, by="b2", zone="sole", fx="hand"), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(PORTRAIT, "……满分。……装裱起来。……下次。"),
    say(P, "……签、签名就不用了……", emotion="sad"),
])

FAIL_TEA = theater("王座间：小画像的茶会", _duo("helpless_1", "helpless_1", s1={"kind": "trap:feather_curtain", "at": [-20, -10]},
                                           s2={"kind": "trap:feather_curtain", "at": [20, -10]}), [
    say(N, "（四幅小画像从墙上飘了下来，围着一张不知道从哪里冒出来的小圆桌。两个人被按在了椅子上）", act=1),
    say(SMALL, "（叽叽喳喳）客人！客人来喝茶！今天的茶是蓝色的！"),
    say(P, "……蓝、蓝色的茶？", emotion="question"),
    say(SMALL, "蓝色的茶不能用嘴喝！要用胳肢窝喝！"),
    say(N, "（画里的贵妇人们伸出拿着羽毛扇的手，一边往杯子里倒茶，一边往两个人的腋窝里扇）",
        [A("tickle", who="princess", by="s1", zone="armpit", fx="feather", repeat=10, interval=0.14), _bt(8, 0.15, by="s2", zone="armpit", fx="feather"),
         pose("giggle"), _bp("giggle")], act=2),
    cg(say(P, "嘻嘻……哈哈……茶、茶要洒了——！", emotion="giggle")),
    say(SMALL, "洒了要罚！罚一块方糖！方糖放在脚心上！"),
    say(BLUE, "……这、这是什么规矩……哈、哈……"),
    say(N, "（方糖放在了脚心上，羽毛扇一下一下地扇，扇得方糖在脚心上滚来滚去）",
        [tk("s1", fx="feather", n=14, iv=0.1), _bt(12, 0.1, by="s2", zone="sole", fx="feather"), pose("helpless_2"), _bp("helpless_2")], act=3),
    say(P, "哈哈哈！方糖——滚、滚到脚趾缝里去了——！", emotion="helpless_2"),
    say(SMALL, "好喝吗？好喝吗？再来一杯！"),
    _burst_blue("……哈……哈哈……（冰晶炸开，茶杯里的茶全冻成了冰块……）"),
    _burst_pink("（星光跟着炸开，冰块叮叮当当地掉了一桌……哈啊……放出去了……）"),
    say(N, "（贵妇人们不满地「哼」了一声，又在两个人刚释放完的腰上扇了最后一下，才慢慢飘回墙上）",
        [A("tickle", who="princess", by="s1", zone="waist", fx="feather", repeat=4, interval=0.2), _bt(4, 0.2, by="s2", zone="waist", fx="feather"),
         pose("helpless_1"), _bp("helpless_1")], act=4),
    say(SMALL, "下次再来喝茶！下次喝粉色的！"),
    say(BLUE, "……不、不想喝了。"),
])

FAIL_FRAME = theater("王座间：两个人都被画进画里", _duo("helpless_2", "helpless_2", frame={"kind": "trap:feather_curtain", "at": [0, -8]}), [
    say(N, "（变强的画框发出刺眼的紫光。外面的那个人也被拉了进去——两个人一起，变成了画布上的一幅画）", act=1),
    say(PORTRAIT, "……两个人。……一起。……这幅画，叫做「笑着的公主」。"),
    say(N, "（五支画笔围着她们转。从头发画到肩膀，从肩膀画到腰，从腰画到膝盖，一直画到脚尖）",
        [tk("frame", fx="feather", n=12, iv=0.12), _bt(10, 0.12, by="frame", zone="waist", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=2),
    cg(say(P, "哈哈哈！一起被画……画、画得好痒……！", emotion="helpless_2")),
    say(BLUE, "……哈、哈哈……画、画笔……数量……犯规……"),
    say(PORTRAIT, "……还没画完。……要画到她们真的在笑。……一直笑。", act=3),
    say(N, "（画笔越画越快。腰侧、腋窝、膝盖窝、脚心——每一笔都蘸着亮晶晶的颜料，每一笔都痒到骨头里）",
        [tk("frame", fx="lines", n=16, iv=0.09), _bt(14, 0.09, by="frame", zone="sole", fx="feather"), pose("helpless_2"), _bp("helpless_2")]),
    _burst_blue("……哈……哈哈……（冰晶在画里炸开，画布上结了一层霜……）"),
    _burst_pink("（星光跟着炸开，霜化成了亮晶晶的水珠，画布「哗啦」一下变得透明……哈啊……放出去了……）"),
    say(N, "（两个人的光把画布撑开了一道缝，一起从画框里滚了出来。……一支画笔追出来，在两个人的脚心上补了最后一笔）",
        [tk("frame", fx="hand", n=4, iv=0.2), _bt(4, 0.2, by="frame", zone="sole", fx="hand"), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(PORTRAIT, "……画坏了。……重新画。……我等你们。"),
    say(P, "……下次一定把你烧穿！", emotion="angry"),
])

ESCAPE = theater("王座间：逃出画", _duo("helpless_1", "normal"), [
    say(N, "（她一头撞进画框出口的光里——「噗」地一声，从大画像的画框里摔了出来）", act=1),
    say(BLUE, "……！……（伸手接住）……抓到了。"),
    say(P, "……哈……哈……出、出来了……身上全是颜料……", [pose("helpless_1")], emotion="helpless_1"),
    say(N, "（她的胳膊上还留着一朵画了一半的小花，腰上一道歪歪扭扭的波浪线）", act=2),
    say(BLUE, "……（用手指蹭了蹭那朵小花）……擦不掉。"),
    say(P, "呀——！别、别蹭腰……还痒着呢……！", [A("tickle", who="princess", by="blue", zone="waist", fx="hand", repeat=4, interval=0.2), pose("giggle")], emotion="giggle"),
    say(PORTRAIT, "……跑掉了。……笑声……跑掉了。", act=3),
    say(BLUE, "……现在。……一起。", [_bp("normal")]),
])

THEATERS = {"clock_gear_ride": GEAR_RIDE, "throne_fail_paint": FAIL_PAINT, "throne_fail_tea": FAIL_TEA, "throne_fail_frame": FAIL_FRAME,
            "throne_escape": ESCAPE, "clock_caught": CLOCK_CAUGHT, "tunnel_toll": TOLL, "tunnel_quilt": QUILT, "tunnel_cradle": CRADLE,
            "throne_painting_trapped": PAINT_TRAPPED, "throne_fail": BOSS_FAIL}


# ================================================================ 对话
def _chest(i, real_item, real_n):
    return dfile("", "旧宝箱", {
        "default": {"lines": [L("（一口落满灰的旧宝箱）", N)], "prompt": "打开？", "choices": [{"text": "打开", "next": "go"}, {"text": "不开", "next": "no"}]},
        "go": {"lines": [L("……打开看看。", P)], "set": {"call": "palace_chest_%d" % i}},
        "no": {"lines": [L("……先不碰。", P)]},
        "done": {"lines": [L("（宝箱空了）", N)]},
    }, entries=[{"if": {"flag": "palace_tchest_%d" % i}, "node": "done"}, {"node": "default"}])


DIALOGUES = {
    # 前厅的石像：改成问答，见 palace4.py
    # 钟楼
    "clock_axle": dfile("", "转轴", {
        "default": {"lines": [L("（一根连着大齿轮的转轴。大齿轮的边上，刚好能坐一个人）", N)], "prompt": "一个人坐齿轮，一个人转轴？",
                    "choices": [{"text": "好", "next": "go"}, {"text": "等一下", "next": "no"}]},
        "go": {"lines": [L("……抓紧。", BLUE)], "set": {"call": "palace_gear_ride"}},
        "no": {"lines": [L("……准备好再说。", P)]},
        "done": {"lines": [L("（梯子已经放下来了）", N)]},
    }, entries=[{"if": {"flag": "palace_ladder_down"}, "node": "done"}, {"node": "default"}]),
    "clock_rope": dfile("", "钟绳", {
        "default": {"lines": [L("（一根粗粗的钟绳，从大钟上垂下来）", N), L("……一起拉。……十三下。", BLUE)], "prompt": "拉钟绳？",
                    "choices": [{"text": "一起拉！", "next": "go"}, {"text": "再等等", "next": "no"}]},
        "go": {"lines": [L("……一、二——", P)], "set": {"call": "palace_ring_bells"}},
        "no": {"lines": [L("……先喘口气。", P)]},
        "done": {"lines": [L("（大钟安安静静地挂着。王座间的门，已经开了）", N)]},
    }, entries=[{"if": {"flag": "palace_bells_done"}, "node": "done"}, {"node": "default"}]),
    "clock_bell": dfile("", "大钟", {"default": {"lines": [
        L("（一口巨大的铜钟。钟口里卡着一个小小的东西——半个铃铛，系着褪色的粉色丝带）", N),
        L("……半个铃铛。……另外半个呢。", BLUE),
        L("（铃铛上刻着两个很小很小的字，被磨得看不清了）", N)]}}),
    **{"clock_chest_%d" % i: _chest(i, "", 0) for i in (1, 2, 3, 4)},
    # 隧道
    "tunnel_toll": dfile("", "收路费的小鬼", {
        "default": {"lines": [L("嘻嘻！此路是我开！要从这里过，留下买路钱！", IMP)], "prompt": "付什么？",
                    "choices": [{"text": "给一颗薄荷糖", "next": "mint"}, {"text": "给 30 枚金币", "next": "coin"}, {"text": "……没钱", "next": "tickle"}]},
        "mint": {"lines": [L("……给你。", P)], "set": {"call": "palace_toll_mint"}},
        "coin": {"lines": [L("……给你。", P)], "set": {"call": "palace_toll_coin"}},
        "tickle": {"lines": [L("……我们没有钱。", P, "sad")], "set": {"call": "palace_toll_tickle"}},
        "paid": {"lines": [L("嘻嘻！付过了付过了！随便走！", IMP)]},
    }, entries=[{"if": {"flag": "palace_toll_paid"}, "node": "paid"}, {"node": "default"}]),
    **{"tunnel_chest_%d" % i: dfile("", "宝箱", {
        "default": {"lines": [L("（一排四口一模一样的宝箱。……其中有几口，好像在呼吸）", N)], "prompt": "打开这一口？",
                    "choices": [{"text": "打开", "next": "go"}, {"text": "不开", "next": "no"}]},
        "go": {"lines": [L("……就这口。", P)], "set": {"call": "palace_tunnel_chest_%d" % i}},
        "no": {"lines": [L("……再看看。", P)]},
        "done": {"lines": [L("（宝箱已经打开过了）", N)]},
    }, entries=[{"if": {"flag": "palace_tunnel_chest_%d" % i}, "node": "done"}, {"node": "default"}]) for i in (1, 2, 3, 4)},
    "tunnel_quilt": _spot("羽毛被子", "（一张挂着褪色玫瑰帐子的大床，床上铺着一条又厚又软的白羽毛被子）", "躺一下？", "……就躺一下。", "tunnel_quilt",
                          "（被子安安静静地铺着。……被角上绣着「给怕冷的小不点」）"),
    "tunnel_vanity": dfile("", "梳妆台", {"default": {"lines": [
        L("（梳妆台上放着两把一模一样的小梳子。一把缠着粉色的头发，一把缠着蓝色的头发）", N),
        L("……两把小梳子。", P, "surprise"),
        L("……（拿起蓝色的那把，又放下）……", BLUE)]}}),
    "tunnel_diary": dfile("", "床头的日记", {"default": {"lines": [
        L("（床头柜里有一本日记，大部分的字都褪了色。只有一页还看得清）", N),
        L("「两个孩子。一个像我，一个像他。一个爱笑，一个爱哭——爱哭的那个，一被挠就笑得最大声」", QUEEN_DIARY),
        L("「等钟楼的钟修好了，要带她们上去看月亮」", QUEEN_DIARY),
        L("……一个爱笑，一个爱哭。", P, "sad"),
        L("……", BLUE)]}}),
    "tunnel_cradle": _spot("两个摇篮", "（两个一模一样的小摇篮，一个系着粉色的丝带，一个系着蓝色的丝带）", "走近看看？", "……看看。", "tunnel_cradle",
                           "（摇篮轻轻地晃着。……布偶的小手朝你们挥了挥）"),
    "tunnel_mobile": dfile("", "旋转吊铃", {"default": {"lines": [
        L("（摇篮上方挂着一个旋转吊铃：月亮、星星、两只小兔子）", N),
        L("（轻轻一碰，它就叮叮咚咚地转了起来，放出一段很慢很慢的曲子）", N),
        L("……这首歌。……我好像听过。", P, "surprise"),
        L("……（小声地，跟着哼了两句）……", BLUE),
        L("……你也会？", P, "surprise"),
        L("……不知道。……嘴巴自己会。", BLUE)], "set": {"flags": ["palace_lullaby_heard"]}}}),
    "tunnel_marks": dfile("", "墙上的刻痕", {"default": {"lines": [
        L("（门框上有两道量身高的刻痕，挨得很近。旁边画着两个小小的记号：一颗星星、一片雪花）", N),
        L("（刻痕底下还画着一只歪歪扭扭的小钟：分针指着「九」。旁边一行小字：「说好了，这个时候一起去钟楼」）", N),
        L("……星星，和雪花。", P, "sad"),
        L("……星光。……冰。", BLUE)]}}),
}

SIGNS = {
    "palace_throne_sealed": [{"speaker": N, "text": "（王座间的大门上缠着一圈紫色的封印。门上刻着一口钟——钟下面有十三道刻痕）"}],
    "palace_ladder_up": [{"speaker": N, "text": "（梯子收在上面一层……够不着。东北角那个大齿轮，好像能把人带上去）"}],
    "palace_keeper_block": [{"speaker": N, "text": "（楼梯口被一道铁栅栏拦着。……身后传来「咔哒、咔哒」的发条声）"}],
    "palace_secret_closed": [{"speaker": N, "text": "（墙后面好像是空的……可是从这一边打不开。也许要从另一边过来）"}],
}


def ante_in():
    s = [
        line(N, "（训练场的北门后面，是一座圆形的大厅。八根大理石柱子围成一圈，柱子上爬满了枯掉的玫瑰藤）"),
        line(N, "（北边是一扇比人高三倍的大门，门上缠着紫色的封印。西边，一道旋转楼梯一直通到看不见的地方）"),
        line(P, "……王座间。", "surprise"),
        line(BLUE, "……封着。……楼梯上面，是钟楼。"),
        {"actions": [A("notify", text="调查王座前厅")], "wait": 0.3},
    ]
    return {"name": "王座前厅", "letterbox": True, "skippable": True, "steps": s}


def clock_in():
    s = [
        line(N, "（钟楼里面全是齿轮。大大小小的铜齿轮咬在一起，一层一层地往上转，一直转到看不见的顶上）"),
        line(P, "……好高。", "surprise"),
        line(BLUE, "……钟在最上面。……爬上去。"),
        {"actions": [A("notify", text="爬上钟楼（齿轮缝会夹住脚踝：站在刹车上，齿轮就停）")], "wait": 0.3},
    ]
    return {"name": "钟楼", "letterbox": True, "skippable": True, "steps": s}


def keeper_wake():
    s = [
        line(N, "（回廊的尽头，一个穿着燕尾服的大人偶靠墙站着，胸口嵌着一个停了的钟面）"),
        line(N, "（「咔哒」。钟面上的指针动了一格。人偶慢慢地抬起头，眼睛亮了起来）"),
        line(KEEPER, "……有人……在钟楼里……乱跑。"),
        line(P, "……跑！", "surprise"),
        {"actions": [A("notify", text="快跑！经过闸门的时候闸门会落下来挡它一会儿")], "wait": 0.2},
    ]
    return {"name": "守钟人偶", "letterbox": True, "skippable": False, "steps": s}


def bells():
    s = [
        {"actions": [A("bg", img="clock_bells")], "wait": 0.6},
        line(N, "（两个人握住钟绳，一起往下拉）"),
        {"actions": [A("sfx", sound="chime", volume=0.0)], "wait": 0.4},
        line(N, "（「铛——」。一下、两下、三下……钟声一圈一圈地荡开，荡过整座沉睡的王宫）"),
        {"actions": [A("sfx", sound="chime", volume=-2.0)], "wait": 0.4},
        line(N, "（……十一、十二……十三）"),
        line(P, "……十三下。", "surprise"),
        line(BLUE, "……好像，以前也有人带我上来过。……看月亮。", None),
        line(N, "（远远的，王座间的方向，传来了「咔」的一声——像是一把很旧的锁，松开了）"),
        {"actions": [A("bg_clear")], "wait": 0.6},
    ]
    return {"name": "十三下", "letterbox": True, "skippable": True, "steps": s}


def throne_in():
    s = [
        line(N, "（王座间。空荡荡的王座后面，挂着一幅比门还大的画像。画里的女王穿着玫瑰色的长裙——可是她的脸，糊成了一片）"),
        line(PORTRAIT, "……有客人。……客人的鞋子，是左边先进来的。"),
        line(P, "……画、画在说话。", "surprise"),
        line(BLUE, "……它在说胡话。"),
        line(PORTRAIT, "……笑声。……我闻到了笑声。……留下来。……全部留下来。"),
        {"actions": [A("notify", text="Boss：封笑的女王画像——打它露出的破绽")], "wait": 0.3},
    ]
    return {"name": "王座间", "letterbox": True, "skippable": True, "steps": s}


def layer(i):
    def f():
        s = [line(PORTRAIT, GIBBERISH[i]), line(N, "（画布「嘶啦」一声裂开了一层）")]
        if i == 0:
            s.append(line(N, "（墙上的四幅小画像一起睁开了眼睛）"))
            s.append({"actions": [A("notify", text="小画像醒了：先打掉它们，大画像才会露出破绽")], "wait": 0.2})
        elif i == 1:
            s.append(line(N, "（画框的边缘开始发光。画里伸出了一只很大很大的手）"))
            s.append({"actions": [A("notify", text="小心：画像会把人拉进画里！在画里自己找到出口")], "wait": 0.2})
        return {"name": "画布的第 %d 层" % (i + 1), "letterbox": True, "skippable": True, "steps": s}
    return f


def burst_finale():
    s = [
        line(N, "（画布只剩最后一层了。画像把两个人的笑声都收了进去，画框亮得刺眼）"),
        line(PORTRAIT, GIBBERISH[2]),
        line(P, "……笑声被它吸走了……身体里……满满的……", "helpless_1"),
        line(BLUE, "……那就……还给它。……一起。", None),
        {"actions": [A("flash", time=0.6), A("sfx", sound="ice_crack", volume=0.0), A("shake", who="blue", time=0.5)], "wait": 0.6},
        line(N, "（蓝色公主的冰晶和粉色公主的星光一起炸开，像两道光一样撞在画布上——）"),
        {"actions": [A("flash", time=0.8), A("sfx", sound="water_release", volume=0.0), A("shake", who="princess", time=0.5)], "wait": 0.8},
        line(N, "（画布正中央，被烧出了一个圆圆的缺口。缺口的边缘闪着金色的光）"),
        line(PORTRAIT, LAST_WORDS),
        line(N, "（画像不再说话了。画里女王那张糊掉的脸，好像——轻轻地笑了一下）"),
    ]
    return {"name": "两个人的光", "letterbox": True, "skippable": False, "steps": s}


def palace_end():
    s = [
        line(N, "（缺口后面，掉出来一个小小的东西，「叮」地落在王座的台阶上）"),
        line(P, "……半枚徽章。", "surprise"),
        line(BLUE, "……（从怀里拿出自己的那半枚）……", None),
        {"actions": [A("bg", img="palace_badges")], "wait": 0.6},
        line(N, "（两半合在一起，严丝合缝。徽章亮了起来——暖暖的、金色的光）"),
        line(N, "（光里，好像有一个女人在哼歌。很慢很慢的曲子，和婴儿房的吊铃一样）"),
        line(P, "……这首歌……", "sad"),
        line(BLUE, "……（跟着哼了一句，又停下来）……", None),
        line(N, "（歌声停了。徽章的光暗了下去，只剩一点余温）"),
        line(P, "……我们，到底是谁呢。", "sad"),
        line(BLUE, "……不知道。……可是。……是两个人。", None),
        {"actions": [A("bg_clear")], "wait": 0.6},
        {"actions": [A("chapter_end", title="第四章　旧王宫　完", subtitle="——两半徽章，一首摇篮曲", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "两半徽章", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"palace_ante_in": ante_in, "palace_clock_in": clock_in, "clock_keeper_wake": keeper_wake, "clock_bells": bells,
             "palace_throne_in": throne_in, "throne_layer_1": layer(0), "throne_layer_2": layer(1), "throne_finale": burst_finale,
             "palace_end": palace_end}
