"""反省篇第四章·旧王宫的追加事件（第二批）：浴场搓澡人偶 / 送餐潜行 / 飞书群与书架暗门 / 旧鞋军团 / 年轻队长的幽影 /
隧道的失物招领与黑暗区 / 王座间的八音盒 / 女王的回忆（徽记 + 王座间都完成以后）。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, line, pose, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo, CAPTAIN_YOUNG

SCRUB = "搓澡人偶"
MAIDS = "人偶女仆们"
IMP = "收路费的小鬼"
SHADE = "年轻队长的幽影"

TEXT = {
    "scrub_meet": ["那、那个大人偶拿着刷子过来了！", "……搓澡的人偶。……身上挂着海绵。"],
    "scrub_brush": ["刷、刷子扫到腰了——！", "……长刷子。……腰。"],
    "scrub_grab": ["被、被抓住了——要被按进泡泡里了！", "……放开。……脚底。"],
    "scrub_rescue": ["松手了！快跑！", "……打它背后。……松了。"],
    "scrub_sponge": ["海绵掉下来了！", "……打掉一块。"],
    "scrub_stick": ["海、海绵吸住脚了——！", "……海绵。……黏着脚。"],
    "books_start": ["书、书全飞起来了——！", "……飞书。……一群。"],
    "shoes_done": ["全关进去了！", "……鞋柜。……关好了。"],
    "shade_round_1": ["……来。……让我看看你们练得怎么样。", "拔剑。……用羽毛剑也算剑。"],
    "shade_round_2": ["……两个人一起上？那我也分成两个。", "这一招……是跟小殿下们学的。"],
    "shade_round_3": ["……最后一招。我的绝招。", "看好了——这一招，我练了很多年。"],
    "shade_wave": ["羽、羽毛风暴——！", "……全场。……冲刺躲开。"],
    "dark_hand": ["黑、黑暗里伸出手来了——！别离开冰光！", "……好黑。……有手。"],
    "box_gibberish": ["……这个声音……好像……在哪里……", "……嘘……别吵醒她们……", "……是……陛下的笑声……", "……画框……画框里好暖……"],
}


def _lost(key, name, look):
    return dfile("", name, {
        "default": {"lines": [L(look, N), L("……这是隧道里那个小鬼说丢了的东西。收着吧。", P)],
                    "set": {"flags": ["palace_lost_" + key]}},
        "done": {"lines": [L("（东西已经收起来了）", N)]},
    }, entries=[{"if": {"flag": "palace_lost_" + key}, "node": "done"}, {"node": "default"}])


DIALOGUES = {
    # 失物（五张图）
    "lost_quill": _lost("quill", "羽毛笔", "（书架底下躺着一支白羽毛笔，笔杆上刻着一个小小的「鬼」字）"),
    "lost_bell": _lost("bell", "小铃铛", "（柜子缝里卡着一只系粉丝带的银色小铃铛，一晃就「叮铃」一声）"),
    "lost_sock": _lost("sock", "一只袜子", "（衣架底下掉着一只条纹袜子……只有一只。袜口绣着「鬼」）"),
    "lost_cheese": _lost("cheese", "一块奶酪", "（灶台边放着一块被啃过一口的奶酪，上面插着一面小旗子：「鬼的！」）"),
    "lost_spring": _lost("spring", "钟发条", "（地板缝里卡着一圈小小的铜发条，还在轻轻地弹）"),
    "tunnel_lost": dfile("", "收路费的小鬼（失物招领）", {
        "default": {"lines": [L("呜呜……我的宝贝都丢了。羽毛笔、小铃铛、袜子、奶酪、钟发条——五样！帮我找回来，我就送你们一张免路费的通行证！", IMP)],
                    "prompt": "交还找到的东西？", "choices": [{"text": "交还", "next": "go"}, {"text": "再找找", "next": "no"}]},
        "go": {"lines": [L("……看看这些是不是你的。", P)], "set": {"call": "palace_lost_return"}},
        "no": {"lines": [L("……还在找。", P)]},
        "done": {"lines": [L("嘻嘻！宝贝都回来了！通行证拿好，以后随便走！", IMP)]},
    }, entries=[{"if": {"flag": "palace_lost_done"}, "node": "done"}, {"node": "default"}]),
    # 送餐潜行
    "kitchen_tray": dfile("", "糕点台的托盘", {
        "default": {"lines": [L("（糕点台边放着一只银托盘，上面是刚「做好」的小蛋糕和茶。托盘边夹着一张纸条：「送去女仆长的房间——别被女仆们看见，她们会偷吃」）", N)],
                    "prompt": "端去仆人回廊？", "choices": [{"text": "端起来", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("……端稳。不能跑。", BLUE)], "set": {"call": "palace_tray_take"}},
        "no": {"lines": [L("……等一下再送。", P)]},
        "carrying": {"lines": [L("（手里已经端着一盘了）", N)]},
        "done": {"lines": [L("（托盘空了。女仆长房间的纸条上画了一个笑脸）", N)]},
    }, entries=[{"if": {"flag": "palace_sheet_2"}, "node": "done"}, {"if": {"flag": "palace_tray_carry"}, "node": "carrying"}, {"node": "default"}]),
    "servants_deliver": dfile("", "女仆长的房间", {
        "default": {"lines": [L("（女仆长房间的小桌上，摆着一张空空的茶托。茶托下面压着什么东西）", N)]},
        "carry": {"lines": [L("（把托盘放在小桌上。茶托下面压着的，是一张泛黄的乐谱——旁边写着：「右下、右上」）", N),
                            L("……第二片乐谱。", BLUE), L("女仆长……原来是在等点心。", P, "happy")], "set": {"call": "palace_tray_deliver"}},
        "done": {"lines": [L("（小桌上的点心一口没动。……人偶本来就吃不了吧）", N)]},
    }, entries=[{"if": {"flag": "palace_sheet_2"}, "node": "done"}, {"if": {"flag": "palace_tray_carry"}, "node": "carry"}, {"node": "default"}]),
    # 图书馆的衣架书签 / 衣帽间的鞋柜
    "library_hanger_book": dfile("", "夹着书签的书", {
        "default": {"lines": [L("（书架上有一本书夹着金色的书签——书签是一只小小的衣架形状）", N)], "prompt": "抽出来？",
                    "choices": [{"text": "抽出来", "next": "go"}, {"text": "不碰", "next": "no"}]},
        "go": {"lines": [L("（「咔哒」——远远的，禁书区那边传来书架转动的声音）", N), L("……书架后面。……有路。", BLUE)], "set": {"flags": ["palace_shelf_door"]}},
        "no": {"lines": [L("……先不碰。", P)]},
        "done": {"lines": [L("（书签已经抽出来了。禁书区的书架开着一道缝）", N)]},
    }, entries=[{"if": {"flag": "palace_shelf_door"}, "node": "done"}, {"node": "default"}]),
    "wardrobe_shoe_closet": dfile("", "鞋柜", {
        "default": {"lines": [L("（一个大鞋柜，柜门上写着：「乱跑的鞋子，一律关进来」）", N)], "prompt": "关上柜门？",
                    "choices": [{"text": "关门！", "next": "go"}, {"text": "等一下", "next": "no"}]},
        "go": {"lines": [L("……关门！", P, "angry")], "set": {"call": "palace_shoe_closet"}},
        "no": {"lines": [L("……先把旧鞋引过来。", BLUE)]},
        "done": {"lines": [L("（鞋柜里传来「咚咚」的声音。……还是别打开了）", N)]},
    }, entries=[{"if": {"flag": "palace_shoes_done"}, "node": "done"}, {"node": "default"}]),
    # 年轻队长的幽影
    "training_shade": dfile("", "插着羽毛剑的木桩", {
        "default": {"lines": [L("（木桩上插着一把羽毛训练剑，剑柄上缠着褪色的紫色布条。四周的空气凉飕飕的）", N),
                              L("……谁在那里？", CAPTAIN_YOUNG), L("（一个半透明的年轻骑士，从木桩旁边慢慢浮了出来）", N)],
                    "prompt": "和他对练？", "choices": [{"text": "对练！", "next": "go"}, {"text": "下次", "next": "no"}]},
        "go": {"lines": [L("……三回合。先倒下的输。输了——耐痒训练。", SHADE)], "set": {"call": "palace_shade_start"}},
        "no": {"lines": [L("……我会一直在这里练剑。", SHADE)]},
        "done": {"lines": [L("（木桩上的羽毛剑安安静静地插着。……好像有人轻轻地笑了一下）", N)]},
    }, entries=[{"if": {"flag": "palace_shade_done"}, "node": "done"}, {"node": "default"}]),
    "training_shade_win": dfile("", SHADE, {"default": {"lines": [
        L("……好剑法。", SHADE),
        L("（幽影把羽毛剑插回木桩上，看着粉色公主，又看看蓝色公主）", N),
        L("……你们两个，让我想起两个小女孩。一个爱笑，一个爱哭。……她们总是偷偷跑来，挠我的脚心，害我练不成剑。", SHADE),
        L("……那两个小女孩，后来呢？", P, "surprise"),
        L("……我答应过要护住她们。……我还在找。", SHADE),
        L("（幽影的身影慢慢淡了下去，木桩旁边留下一枚金色的笑脸徽记）", N)]}}),
}

SIGNS = {
    "palace_shelf_closed": [{"speaker": N, "text": "（书架后面好像有风……可是推不动。图书馆里也许有什么机关）"}],
    "palace_shelf_closed_w": [{"speaker": N, "text": "（衣柜后面是空的……可是从这一边打不开）"}],
}

# ================================================================ 搓澡人偶：被抓住（CG）
SCRUB_GRAB = theater("旧浴场：搓澡人偶的泡泡桶", _duo("normal", "normal", tub={"kind": "trap:sitz_bath", "at": [-14, 2]},
                                                   brush={"kind": "trap:brush", "at": [-26, -4]}), [
    say(SCRUB, "……洗、洗澡的时间……到了……（咔哒、咔哒）", act=1),
    say(N, "（搓澡人偶一把把粉色公主拎了起来，「扑通」一声放进了冒着泡泡的大木桶里，两只脚被搁在桶沿上）", [A("shake", who="princess", time=0.4), pose("normal")]),
    say(P, "等、等一下！我、我自己会洗——！", emotion="surprise"),
    say(SCRUB, "……脚底……最脏……要好好刷……"),
    say(N, "（鞋被人偶随手放到了一边。长柄刷蘸满泡泡，从脚跟一路刷到脚趾缝）", [tk("brush", fx="feather", n=10, iv=0.14), pose("giggle")], act=2),
    say(P, "嘻……嘻嘻……不、不脏——不要刷了——哈哈！", emotion="giggle"),
    say(BLUE, "……放开她。", [_bp("normal")]),
    cg(say(N, "（蓝色公主抓起一条毛巾，「啪啪」地抽人偶的后背——可是飘过来的泡泡一个劲地往她脖子上蹭）",
           [tk("brush", fx="lines", n=14, iv=0.1), _bt(8, 0.14, by="tub", zone="neck", fx="feather"), pose("helpless_1"), _bp("giggle")], act=3)),
    say(P, "哈哈哈！脚、脚趾缝也——你、你快一点——！", emotion="helpless_1"),
    say(BLUE, "……哈……泡泡……脖子……不、不许笑……"),
    say(SCRUB, "……另、另一位客人……也要洗……"),
    say(N, "（人偶的另一只手抓起一块海绵，往蓝色公主的腰上一按——海绵吸饱了温水，一挤一放，一挤一放）",
        [_bt(12, 0.1, by="tub", zone="waist", fx="hand"), tk("brush", zone="sole", fx="feather", n=12, iv=0.1), pose("helpless_2"), _bp("helpless_1")]),
    say(P, "哈哈哈哈！两、两个人都——！", emotion="helpless_2"),
    _burst_pink("（星光在泡泡桶里炸开，泡泡全飞上了天花板……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，满屋子的泡泡都冻成了亮晶晶的小球……）"),
    say(N, "（人偶被冻得一动不动。……只有那把刷子，还在她刚释放完、敏感得发烫的脚心上，轻轻地、最后刷了一下）",
        [tk("brush", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……最、最后那一下……", emotion="helpless_1"),
    say(BLUE, "……出来。……趁它冻着。"),
    say(N, "（两个人从桶边爬了出来，湿漉漉地站好。人偶身上的冰开始「咔咔」地裂）", [pose("normal"), _bp("normal")]),
    say(P, "……先把它身上的海绵打掉！", emotion="angry"),
])

# ================================================================ 送餐被发现：试吃惩罚（CG）
TASTING = theater("仆人回廊：试吃惩罚", _duo("normal", "normal", m1={"kind": "trap:feather_curtain", "at": [-26, -8]},
                                          m2={"kind": "trap:feather_curtain", "at": [26, -8]}), [
    say(MAIDS, "（咔哒、咔哒）……发现……偷、送、点、心、的……人。", act=1),
    say(N, "（三个人偶女仆围了上来。一个接过托盘，两个一左一右，把两个人「请」到了餐厅的长桌边上坐好）", [A("shake", who="princess", time=0.3)]),
    say(P, "我、我们是来送点心的！不是偷！", emotion="surprise"),
    say(MAIDS, "……送点心的人……要先、试、吃。……这是规矩。"),
    say(N, "（一个女仆用小勺舀了一块奶油蛋糕，送到粉色公主嘴边。另外两个，悄悄地脱掉了她们的鞋，把脚搁在天鹅绒的脚凳上）",
        [pose("normal"), _bp("normal")], act=2),
    say(BLUE, "……为什么试吃要脱鞋。"),
    say(MAIDS, "……试吃的时候……要、笑。……笑了，才知道、好吃。"),
    cg(say(N, "（鸡毛掸子和打蛋器一起上阵：一个刷脚心，一个在肋下转圈。张嘴要笑的时候，勺子正好塞进来一口奶油）",
           [tk("m1", fx="feather", n=12, iv=0.12), _bt(10, 0.12, by="m2", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")], act=3)),
    say(P, "唔唔……哈哈……好、好吃——但是好痒——唔！", emotion="giggle"),
    say(BLUE, "……哈……奶油……沾到脸上了……哈哈……"),
    say(MAIDS, "……好吃？……再来一口。……再刷一下。"),
    say(N, "（一口蛋糕，一下掸子；一口茶，一下打蛋器。两个人笑得靠在一起，脸上全是奶油）",
        [tk("m2", zone="waist", fx="hand", n=14, iv=0.1), _bt(14, 0.1, by="m1", zone="armpit", fx="hand"), pose("helpless_1"), _bp("helpless_1")]),
    say(P, "哈哈哈！不、不吃了——饱了——真的饱了——！", [pose("helpless_2")], emotion="helpless_2"),
    _burst_blue("……哈……哈哈……（冰晶炸开，桌上的奶油全冻成了冰淇淋……）"),
    _burst_pink("（星光跟着炸开，女仆们的发条被震得「咔」地停了一拍……哈啊……放出去了……）"),
    say(N, "（发条重新转起来。最后一个女仆不紧不慢地，在两个人刚释放完的脚心上，各用打蛋器转了一圈）",
        [tk("m1", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……这、这也是规矩吗……", emotion="helpless_1"),
    say(MAIDS, "……试吃、完毕。……点心、没收。……请、回厨房、重拿。"),
    say(N, "（两个人被客客气气地送回了回廊的入口。鞋也被摆得整整齐齐地还了回来）", [pose("normal"), _bp("normal")]),
    say(BLUE, "……下次。……绕开她们。"),
])

# ================================================================ 年轻队长的幽影：耐痒训练（CG）
SHADE_TRAINING = theater("骑士训练场：幽影的耐痒训练", _duo("normal", "normal", stocks={"kind": "trap:stocks", "at": [0, 4]},
                                                     sword={"kind": "trap:feather_curtain", "at": [0, -14]}), [
    say(SHADE, "……输了。……按规矩，输的人要做耐痒训练。", act=1),
    say(N, "（幽影把两个人请到训练台边的长凳上坐下，两双脚被轻轻地套进了软垫足枷里。鞋被整整齐齐地摆在了一边）", [A("sfx", sound="stocks", volume=-4.0), pose("normal"), _bp("normal")]),
    say(P, "耐、耐痒训练？！我们又不是骑士！", emotion="surprise"),
    say(SHADE, "……小殿下们以前也这么说。……然后每次都坚持不到十下。"),
    say(BLUE, "……几下。……要坚持几下。"),
    say(SHADE, "……一百下。"),
    say(N, "（羽毛剑在两人的脚心上轻轻地、一板一眼地划了下去，像在练剑的基本功：一、二、三……）",
        [tk("sword", fx="feather", n=10, iv=0.16), _bt(10, 0.16, by="sword", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "嘻……嘻嘻……四、五……不、不行——六——", emotion="giggle"),
    cg(say(N, "（两把小一点的幽影羽毛剑也飘了过来，在两人的腰侧来回地挑。正中那把大的，还在脚心上一丝不苟地数着拍子）",
           [tk("sword", zone="sole", fx="lines", n=14, iv=0.1), _bt(12, 0.1, by="sword", zone="waist", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=3)),
    say(SHADE, "……二十一、二十二……腿不要乱动。骑士的脚，要稳。"),
    say(P, "哈哈哈！谁、谁能稳啊——！", emotion="helpless_1"),
    say(BLUE, "……哈、哈哈……数、数错了……刚才那下……是二十……"),
    say(SHADE, "……数错了。……从头来。"),
    say(N, "（「从头来」三个字一出，两个人一起笑倒在了长凳上，靠着彼此直喘气）", [pose("helpless_2"), _bp("helpless_2"), _bt(14, 0.09, by="sword", zone="armpit", fx="hand")]),
    _burst_pink("（星光在训练场里炸开，木人桩被吹得转了好几圈……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，羽毛剑全被冻在了半空中……）"),
    say(N, "（只有幽影手里那一把还能动。他低头看了看，在两人刚释放完、敏感得要命的脚心上，轻轻补完了最后一下）",
        [tk("sword", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……这、这是第几下……", emotion="helpless_1"),
    say(SHADE, "……第一百下。……合格。"),
    say(N, "（足枷「咔哒」一声松开了。幽影背过身去，肩膀好像在轻轻地抖——是在笑）", [pose("normal"), _bp("normal")]),
    say(SHADE, "……再来对练吧。下次，别那么快倒下。"),
])

THEATERS = {"bath_scrub_grab": SCRUB_GRAB, "servants_tasting": TASTING, "training_shade": SHADE_TRAINING}


# ================================================================ 女王的回忆（背景大图；徽记台 + 王座间都完成以后）
def queen_memory():
    s = [
        {"actions": [A("bg", img="queen_memory")], "wait": 0.8},
        line(N, "（发饰上的羽毛，轻轻地亮了一下。眼前的王座前厅，像水面一样晃了晃——）"),
        line(N, "（……很久很久以前的一个晚上。钟楼的顶上，月亮又大又圆）"),
        line("温柔的声音", "……你们看，那就是月亮。钟修好了，我们就每天上来看。"),
        line("小小的声音", "……要、要挠痒痒才看！"),
        line("另一个小小的声音", "……（笑得说不出话）"),
        line(N, "（一个大人，两个小小的影子，挤在一张毯子上。笑声被风吹散，飘过整座王宫）"),
        line(N, "（……回忆像来的时候一样，慢慢地退了下去）"),
        {"actions": [A("bg_clear")], "wait": 0.8},
        line(P, "……刚才那个，是……", "sad"),
        line(BLUE, "……不知道。……可是。……很暖和。", None),
        line(P, "……嗯。", "sad"),
    ]
    return {"name": "女王的回忆", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"palace_queen_memory": queen_memory}
