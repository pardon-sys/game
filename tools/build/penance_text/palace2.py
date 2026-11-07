"""反省篇第四章（中）·旧王宫：图书馆 → 衣帽间 / 骑士训练场（PalaceLibrary / PalaceWardrobe / PalaceTraining）。
跨房间的解密：图书馆深处的密码门（四位数字 2-5-7-3）。每一位藏在一张图里——浴场镜子的水汽字（2）、仆人回廊排班表的日子（5）、
衣帽间小礼服的尺码（7）、训练场墙上的刻痕（3）；图书馆的「书房管理记录」被打了码，三张残页（图书馆书山下 / 衣帽间大衣口袋 / 训练场的箱子）
每找到一张，就多看清一行（哪一位对应哪个房间）。挠脚鼠已经在厨房告别，粉色公主穿回了原来的衣服。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, PRINCESS, cg, dfile, line, pose, release, say, theater, tk

CODE = ["2", "5", "7", "3"]
DIGITS = ["2", "3", "5", "7"]
BOOKMON = "恶作剧书怪"
MANNEQUIN = "礼服人台"
SOCKS = "穿袜机"
CAPTAIN_YOUNG = "年轻的队长（日记）"

TEXT = {
    "hands": ["呀！书架里伸出手来了——脚踝！", "……书架。……抓脚。"],
    "pile": ["书、书山塌了——埋住了！快来挖我！", "……埋住了。……挖。"],
    "dig": ["挖、挖出来了……", "……出来了。"],
    "worm": ["书虫钻进袜子里了——！", "……虫。……袜子里。"],
    "quill": ["羽毛笔在脚底写字——！", "……笔。……在写。"],
    "mirror": ["镜子里的人伸手了！", "……镜子。……假的。"],
    "shawl": ["披肩缠上来了——脖子！", "……披肩。……冻住它。"],
    "shawl_freeze": ["……冻住了。", "冻住啦！变成普通的披肩了！"],
    "trap_wait": ["快、快一点……脚底……要笑死了……！", "……等我。"],
    "key_none": ["……这里没有。", "这个口袋是空的……"],
    "key_found": ["……钥匙。找到了。", "钥匙！快回去救她！"],
    "dummy_ok": ["……对了。", "顺序对了！"],
    "dummy_bad": ["呀！稻草人反击了——！", "……打错了。……被挠了。"],
    "sword": ["羽毛剑扫过来了！", "……剑。……躲。"],
    "wave": ["第一波！稻草人兵！", "第二波……羽毛剑幽灵。", "最后一个——大稻草人教官！"],
}

# 训练场对练擂台：沿用「点灯笼」的找痒点小游戏，换成擂台的台词（PalaceTraining.SparShow）
TEXT["spar_show"] = {
    "name": "骑士对练", "hint": "A / D 在她身上移动光标，光点闪得越快越接近她最怕痒的地方；S 挠。亮「！」时按 J 护住——先笑满的人输",
    "intro": [L("（两个人背靠背坐在擂台中央。木牌上写着：先笑出声的人输）", N), L("……开始。", BLUE), L("看招！", P, "angry")],
    "spots": ["膝盖窝", "大腿内侧", "腿根", "屁股", "腰"],
    "hit": ["（正中！她「噗」地漏出一点声音，又咬住了嘴唇）", "（她整个人一缩——憋住了，可耳朵红了）", "（就是这里！她的腿抖了一下）"],
    "near": ["（她的呼吸乱了一下……就在旁边！）", "（「……嗯。」她的声音有点抖）"],
    "miss": ["（……她面无表情。）", "（「……不痒。」）", "（她连眼睛都没眨）"],
    "moved": ["……那里，已经不怕了。", "……（她挪了挪，换了个姿势）"],
    "poke": ["（冰凉的手指从背后伸过来，在你脚心上画了一个圈）", "（她反手捏住你的脚趾，一根一根地挠）"],
    "pull": ["（护住了！她的手指扑了个空）"],
    "fail": "（你先笑倒在擂台上——她拍拍你的脚背：「……我赢了。」）",
    "panel": "%s\n你 %d%%　她 %d%%\n光标：%s",
    "short": [L("（擂台边的木牌「咔哒」翻了一面：胜负已分）", N)],
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
         "pants": {"kind": "trap:hand", "at": [20, 10]}}
    c.update(extra)
    return c


# ================================================================ 图书馆
BOOKMONSTER = theater("图书馆：恶作剧书怪", _duo("normal", "normal", book={"kind": "monster:mimic", "at": [0, -4], "dir": "down"}), [
    say(N, "（投影里的走廊、月光、两个小小的背影慢慢淡去。金色大书「啪」地合上了——然后，自己长出了两排纸做的牙）", act=1),
    say(BOOKMON, "（哗啦啦地翻页）嘻嘻嘻！偷看的人！偷看禁书的人！要罚！"),
    say(P, "书、书说话了！？", emotion="surprise"),
    say(BLUE, "……罚什么。"),
    say(BOOKMON, "罚——读书会！嘻嘻嘻，一页一页地读给你们的脚底听！"),
    say(N, "（书页像舌头一样卷过来，缠住了两个人的脚踝，把她们拖倒在书堆上。一页一页的纸，轻轻地刷过脚心）",
        [tk("book", fx="feather", n=8, iv=0.18), _bt(6, 0.2, by="book", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "嘻……纸、纸好薄……蹭得好痒……！", emotion="giggle"),
    say(BOOKMON, "第一章：脚心！第二章：趾缝！第三章：膝盖窝！嘻嘻嘻！"),
    say(N, "（它真的按章节来。书页钻进趾缝里翻过去，又卷成小筒在膝盖窝里滚）",
        [tk("book", fx="lines", n=12, iv=0.13), _bt(10, 0.14, by="book", zone="thigh", fx="feather"), pose("helpless_1"), _bp("helpless_1")]),
    say(BLUE, "……第、第三章……跳过……哈、哈……"),
    say(BOOKMON, "不准跳！好书要一字一字地读！", act=3),
    say(N, "（千手痒痒裤也凑了过来——书页刷外侧，裤子的手揉里侧，蓝色公主一下子并紧了膝盖）", [_bt(12, 0.11), _bp("helpless_2")]),
    say(P, "哈哈哈！第、第四章是什么——不要第四章——！", [tk("book", fx="feather", n=14, iv=0.1), pose("helpless_2")], emotion="helpless_2"),
    say(BOOKMON, "第四章：全文朗读！"),
    say(N, "（一整本书的书页同时翻了起来，哗啦啦啦——几百页纸一起刷过脚底、腿弯、腰侧）", [tk("book", fx="lines", n=16, iv=0.09), _bt(14, 0.09, by="book", zone="sole", fx="lines")]),
    _burst_blue("……哈……哈哈……不、不读了……（冰晶炸开，书页全冻成了薄薄的冰片……）"),
    _burst_pink("（星光跟着炸开，冰片碎成了一地闪闪的纸屑……哈啊……放出去了……）"),
    say(BOOKMON, "（冻得直哆嗦）嘻、嘻嘻……附、附录……还有附录……", act=4),
    say(N, "（剩下的几页书页软软地蹭了蹭两个人刚释放完、敏感得发烫的脚心——两个人一起缩成一团，笑着把它踢开了）",
        [tk("book", fx="feather", n=6, iv=0.18), _bt(6, 0.18, by="book", zone="sole", fx="feather"), A("shake", who="princess", time=0.3), A("shake", who="blue", time=0.3)]),
    say(BOOKMON, "……读、读书会结束……下次再来……（变回了一本普通的金色大书）"),
    say(P, "……哈……哈……刚才那个投影……那两个小女孩……", [pose("helpless_1"), _bp("helpless_1")], emotion="sad"),
    say(BLUE, "……一个粉色头发。……一个蓝色头发。"),
    say(P, "……", emotion="sad"),
])

# ================================================================ 衣帽间
MEASURE = theater("衣帽间：量尺寸", _duo("normal", "normal", m={"kind": "trap:binding", "at": [0, -2]}), [
    say(N, "（一具穿着半成品礼服的人台「咔」地转过身来，手里的软尺一甩一甩）", act=1),
    say(MANNEQUIN, "……客人。……量、尺寸。……请站好。"),
    say(P, "不、不用了，我们只是路过——", emotion="surprise"),
    say(N, "（软尺「唰」地缠上了粉色公主的腰，把她拉到了人台跟前）", [A("shake", who="princess", time=0.3)], act=2),
    say(MANNEQUIN, "……腰围。"),
    say(N, "（软尺在腰上绕了一圈，又松开，又绕一圈——每绕一圈，都在腰侧轻轻勒一下）", [A("tickle", who="princess", by="m", zone="waist", fx="hand", repeat=8, interval=0.18), pose("giggle")]),
    say(P, "嘻……嘻嘻……量、量一次就够了……！", emotion="giggle"),
    say(MANNEQUIN, "……腿长。"),
    say(N, "（软尺从脚踝一路往上量，量到大腿根，又从大腿根量回脚踝）", [A("tickle", who="princess", by="m", zone="thigh", fx="hand", repeat=10, interval=0.15), pose("helpless_1")]),
    say(P, "哈哈……腿、腿根那里不用量……！", emotion="helpless_1"),
    say(BLUE, "……（在旁边看着）……我来帮你。", act=3),
    say(N, "（蓝色公主刚伸手去扯软尺——人台的另一只手也伸了出来，把她一起拉了过去）", [_bp("giggle")]),
    say(MANNEQUIN, "……两位客人。……一起量。……脚长。"),
    say(N, "（软尺把两个人的脚并在一起，从脚跟量到脚尖，在脚心正中央停住、来回地蹭）",
        [tk("m", fx="lines", n=12, iv=0.12), _bt(10, 0.12, by="m", zone="sole", fx="lines"), pose("helpless_2"), _bp("helpless_2")]),
    say(BLUE, "……脚、脚心……没有必要……量……哈、哈哈……"),
    say(P, "哈哈哈！它、它根本不是在量——！", emotion="helpless_2"),
    _burst_pink("（星光炸开，软尺被弹得缠成了一团……哈啊……放出去了……）"),
    say(MANNEQUIN, "……尺寸……记、下了。……小殿下……长大了。", act=4),
    say(N, "（人台慢慢转了回去，安静下来。两个人对视了一眼）", [pose("helpless_1"), _bp("helpless_1")]),
    say(P, "……小殿下，长大了？", emotion="question"),
    say(BLUE, "……它，在说谁。"),
])

TRY = {}
for i, (item, name, look, tickle_zone, words) in enumerate([
        ("equip_palace_ribbon", "小殿下的发带", "（一条粉蓝两色的小发带。系上的时候，流苏扫过了后颈）", "neck", "后、后颈……流苏……嘻嘻……"),
        ("equip_palace_corset", "女仆长的束腰", "（一条深蓝色的束腰。系紧的时候，系带在腰侧一下一下地勒）", "waist", "勒、勒得好痒……腰……！"),
        ("equip_palace_boots", "宫廷长靴", "（一双白色的高筒靴。穿进去的时候，靴子里的绒毛蹭过脚心）", "sole", "靴、靴子里面有毛……脚心……！")], 1):
    TRY["wardrobe_try_%d" % i] = theater("衣帽间：试穿%s" % name, _duo("normal", "normal", rack={"kind": "trap:wardrobe", "at": [0, -2]}), [
        say(N, look, act=1),
        say(N, "（……刚穿好，它就像活过来似的，在身上蹭了好几下）", [A("tickle", who="princess", by="rack", zone=tickle_zone, fx="feather", repeat=10, interval=0.15), pose("giggle")], act=2),
        say(P, words, emotion="giggle"),
        say(BLUE, "……合适吗。"),
        say(N, "（又蹭了一下。她红着脸，硬是忍住了）", [A("tickle", who="princess", by="rack", zone=tickle_zone, fx="feather", repeat=6, interval=0.18), pose("helpless_1")], act=3),
        say(P, "……合、合适！挺好的！……可以带走！", emotion="shy"),
        say(N, "（「%s」放进了背包）" % name, [pose("normal")], act=4),
        say(BLUE, "……嗯。……很好看。"),
    ])

SOCKS_T = theater("衣帽间：自动穿袜机", _duo("normal", "normal", sock={"kind": "trap:foot_bath", "at": [-10, 12]}), [
    say(N, "（墙角有一台黄铜做的老机器，前面两个圆洞，牌子上写着：「自动穿袜机——请把脚放进来」）", act=1),
    say(P, "……自动穿袜子？好方便！", emotion="happy"),
    say(BLUE, "……看起来，不太对劲。"),
    say(P, "试一下嘛。……脱鞋，放进去——", emotion="happy"),
    say(N, "（「咔哒」。两个圆洞一收，轻轻卡住了她的脚踝。机器「嗡」地响了起来）", [A("sfx", sound="conveyor", volume=-4.0)], act=2),
    say(SOCKS, "（机械的声音）……穿袜前、清洁程序。……开始。"),
    say(P, "清、清洁！？", emotion="surprise"),
    say(N, "（一排小软刷从洞里伸出来，贴着光着的脚心刷了起来。先是脚跟，然后是脚心，然后是每一道趾缝）", [tk("sock", fx="lines", n=10, iv=0.15), pose("giggle")]),
    say(P, "嘻嘻……刷、刷子……只是穿袜子而已……！", emotion="giggle"),
    say(SOCKS, "……清洁度、不足。……加强。"),
    say(N, "（软刷换成了打着泡泡的海绵，海绵换成了羽毛掸子——每换一种，都在脚心上来来回回地「清洁」好久）",
        [tk("sock", fx="feather", n=14, iv=0.11), pose("helpless_1")], act=3),
    say(P, "哈哈哈！泡泡——羽毛——全都来——！", emotion="helpless_1"),
    say(BLUE, "……（蹲下来看了看机器）……停止键。……这个？"),
    say(N, "（蓝色公主按了一下。……机器「叮」地一声——清洁速度提高到了最高档）", [tk("sock", fx="lines", n=16, iv=0.09), pose("helpless_2")]),
    say(P, "哈哈哈哈！那、那是加速——！这个王宫的按钮为什么都是反的——！", emotion="helpless_2"),
    _burst_pink("（星光炸开，机器冒出一股白烟……哈啊……放出去了……）"),
    say(SOCKS, "……清洁、完成。……穿袜。", act=4),
    say(N, "（一双淡紫色的丝袜被轻轻地套了上来，滑滑的、凉凉的，刚刚被刷得发烫的脚心一下子舒服多了）", [pose("helpless_1")]),
    say(P, "……哈……哈……袜子……倒是很舒服……", emotion="helpless_1"),
    say(BLUE, "……（小声）……按钮，我下次会看清楚。"),
])

TRYON = theater("衣帽间：喜欢的礼服", _duo("normal", "normal"), [
    say(N, "（衣帽间最里面的衣架上，挂着一件玫瑰色的舞会礼服。层层叠叠的薄纱，金线绣的小花，落满了灰也遮不住它的漂亮）", act=1),
    say(P, "……好漂亮。", emotion="happy"),
    say(BLUE, "……喜欢？"),
    say(P, "……嗯。很喜欢。……总觉得，好像以前很想穿这样的裙子。", emotion="shy"),
    say(BLUE, "……试试。……我在外面等。"),
    say(N, "（粉色公主抱着礼服钻到了屏风后面。过了好一会儿——）", act=2),
    say(P, "……怎、怎么样？", emotion="shy"),
    cg(say(N, "（她提着裙摆从屏风后面走出来，在镜子前转了一圈。玫瑰色的薄纱散开，像一朵慢慢开放的花）")),
    say(BLUE, "……", [_bp("normal")]),
    say(BLUE, "……好看。"),
    say(P, "……嘿嘿。", emotion="happy"),
    say(BLUE, "……腰，有点松。……我帮你量一下。"),
    say(N, "（蓝色公主拿起架子上的软尺，绕到她身后，把软尺围上了她的腰——）"),
    say(N, "（……然后，手指「不小心」在她的腰侧点了一下）", [A("tickle", who="princess", by="blue", zone="waist", fx="hand", repeat=4, interval=0.2), pose("giggle")], act=3),
    say(P, "呀！你、你干什么！", emotion="giggle"),
    say(BLUE, "……量尺寸。"),
    say(N, "（又点了一下。再一下。手指顺着腰侧往上爬，又爬回来——蓝色公主的脸还是一本正经的，嘴角却悄悄翘起了一点）",
        [A("tickle", who="princess", by="blue", zone="waist", fx="hand", repeat=10, interval=0.14), pose("helpless_1")]),
    say(P, "哈哈哈！你明明就是在挠我——！", emotion="helpless_1"),
    say(BLUE, "……腰围。……还要再量。"),
    say(N, "（粉色公主笑着想躲，可是长长的裙摆绊住了脚，整个人往后一倒——正好倒进蓝色公主怀里）", [A("shake", who="princess", time=0.3)]),
    say(N, "（蓝色公主顺势把她圈住，十根手指在腰侧、肋下一起动了起来）", [A("tickle", who="princess", by="blue", zone="waist", fx="hand", repeat=14, interval=0.1),
                                                     A("tickle", who="princess", by="blue", zone="armpit", fx="hand", repeat=10, interval=0.12), pose("helpless_2")]),
    say(P, "哈哈哈哈！投降——投降——裙子会皱的——！", emotion="helpless_2"),
    say(BLUE, "……（小声）……这是报仇。……之前，你在帘子外面笑我。"),
    say(P, "那、那是你自己憋笑憋的——哈哈哈！", emotion="helpless_2"),
    _burst_pink("（星光一下子在镜子前炸开，玫瑰色的裙摆被吹得飞了起来……哈啊……放出去了……）"),
    say(N, "（两个人一起摔在了软软的地毯上。蓝色公主还想再点一下——粉色公主一把抓住她的手，反过来挠她的手心）",
        [A("tickle", who="blue", by="princess", zone="armpit", fx="hand", repeat=6, interval=0.15), _bp("giggle")], act=4),
    say(BLUE, "……噗。……哈、哈哈……不准……", [_bt(6, 0.15), _bp("helpless_1")]),
    say(N, "（千手痒痒裤听见笑声也凑起了热闹。两个人在地毯上笑成一团，礼服的薄纱铺了一地）", [pose("helpless_1")]),
    say(P, "……哈……哈……这件裙子……我要带走。", emotion="happy"),
    say(BLUE, "……嗯。……很适合你。"),
])

TRAP_IN = theater("衣帽间：衣柜陷阱", _duo("normal", "normal", wd={"kind": "trap:wardrobe", "at": [-8, 4]},
                                         imp={"kind": "monster:imp", "at": [-18, 14], "dir": "right"},
                                         glove={"kind": "monster:glove", "at": [4, 14], "dir": "left"}), [
    say(N, "（一个雕着花的大衣柜。柜门上挂着一张泛黄的纸条：「捉迷藏专用——请勿关门」）", act=1),
    say(P, "……捉迷藏专用？……我看看里面。", emotion="question"),
    say(N, "（她刚钻进去，「砰」——柜门在身后自己关上了。锁孔里亮起一圈紫光，「咔哒」锁死了）", [A("sfx", sound="gate", volume=-2.0), A("shake", who="princess", time=0.4)]),
    say(P, "诶！？锁、锁上了！？", emotion="surprise"),
    say(N, "（柜子里黑漆漆的，挂满了旧大衣。……大衣后面，有什么东西「咯咯」地笑了一声）", act=2),
    say(N, "（一只只小怪物从大衣堆里探出了头：拿着鸡毛掸子的小鬼、浮在半空的手套、还有一只趴在挂衣杆上的毛毛虫——这个柜子，是它们的家）"),
    say(P, "……你、你们好？……我只是路过……", [pose("helpless_1")], emotion="surprise"),
    say(N, "（它们你看看我、我看看你——然后一起扑了上来。掸子扫腰，手套挠肋下，毛毛虫吊着一根羽毛在脖子上晃）",
        [tk("imp", fx="feather", n=10, iv=0.14), A("tickle", who="princess", by="glove", zone="armpit", fx="hand", repeat=10, interval=0.14), pose("helpless_2")], act=3),
    cg(say(P, "哈哈哈！掸、掸子——手套——脖子——这里好挤，躲都没地方躲——！", emotion="helpless_2")),
    say(N, "（她缩成一团捂住嘴，可是小怪物们发现了更好玩的地方：她的脚。手套把白袜子往下一捋，掸子贴着脚心来回地扫）",
        [tk("imp", fx="feather", n=12, iv=0.12), tk("glove", fx="hand", n=12, iv=0.12)]),
    say(P, "脚、脚心不行——哈哈哈哈！救命——！", emotion="helpless_2"),
    say(BLUE, "……！……等我。……钥匙，我去找。", [_bp("normal")]),
    say(P, "快、快一点——哈哈哈——它们越来越多了——！", emotion="helpless_2"),
    say(N, "（蓝色公主转身跑进了衣帽间深处。柜子里，笑声一阵比一阵大）"),
])

TRAP_OUT = theater("衣帽间：打开衣柜", _duo("helpless_2", "normal", wd={"kind": "trap:wardrobe", "at": [-8, 4]},
                                          imp={"kind": "monster:imp", "at": [-18, 14], "dir": "right"},
                                          glove={"kind": "monster:glove", "at": [4, 14], "dir": "left"}), [
    say(N, "（蓝色公主喘着气跑回来，手里攥着一把小小的铜钥匙）", act=1),
    say(BLUE, "……找到了。……在大衣口袋里。……（柜子里的笑声一点都没小）……"),
    say(P, "（柜子里）哈哈……快……快开门……！", emotion="helpless_2"),
    say(N, "（小怪物们看见她，一哄而散——那只毛毛虫跑得最慢，被蓝色公主一指冻在了原地）", [A("sfx", sound="ice_crack", volume=-4.0)], act=2),
    say(N, "（钥匙插进锁孔，紫光「噗」地灭了。柜门打开，粉色公主整个人软软地倒了出来）", [A("sfx", sound="unlock", volume=-2.0), pose("helpless_1")]),
    say(P, "……哈……哈……得、得救了……", emotion="helpless_1"),
    say(BLUE, "……（扶住她）……脚。……还好吗。"),
    say(P, "……一点都不好……从脚跟到趾缝……全被挠了一遍……", emotion="sad"),
    say(BLUE, "……", act=3),
    say(N, "（蓝色公主低头看着她红通通的脚心，伸出一根手指——在脚心正中央，轻轻戳了一下）", [tk("blue", fx="hand", n=2, iv=0.2), A("shake", who="princess", time=0.4)]),
    say(P, "呀——！！你、你——！", emotion="surprise"),
    say(BLUE, "……（转过头）……检查一下。……还痒不痒。"),
    say(P, "你绝对是故意的！", emotion="angry"),
    say(N, "（粉色公主扑过去要报仇。蓝色公主往后一躲，千手痒痒裤正好在这时候发作——两个人一起滚倒在衣服堆里，笑作一团）",
        [_bt(8, 0.15), _bp("helpless_1"), pose("giggle")], act=4),
    say(BLUE, "……哈、哈哈……裤子……不是我……"),
    say(P, "……哈哈……报应！这就是报应！", emotion="happy"),
])

# ================================================================ 骑士训练场
SPAR_IN = theater("训练场：对练", _duo("normal", "normal"), [
    say(N, "（擂台边的木牌上写着：「骑士对练规则：背靠背坐下，先笑出声的人输。输的人，要被赢的人挠一刻钟」）", act=1),
    say(P, "……一刻钟。", emotion="surprise"),
    say(BLUE, "……比吗。"),
    say(P, "……比就比！我才不会输给你！", emotion="angry"),
    say(BLUE, "……（小声）……我也不会。"),
])

SPAR_WIN = theater("训练场：对练赢了", _duo("normal", "helpless_1"), [
    say(N, "（蓝色公主先笑出了声。她捂着嘴，耳朵红到了脖子根）", act=1),
    say(P, "赢了！我赢了！……按规则，一刻钟哦～", emotion="happy"),
    say(BLUE, "……规则，是谁定的。"),
    say(P, "是骑士定的！来，躺好～", emotion="happy"),
    say(N, "（粉色公主把她按在擂台的软垫上，从膝盖窝开始，一点一点地往上挠）", [A("tickle", who="blue", by="princess", zone="thigh", fx="hand", repeat=10, interval=0.15), _bp("giggle")], act=2),
    say(BLUE, "……唔……唔……"),
    say(P, "还忍？那这里呢——腰～", emotion="happy"),
    say(N, "（手指滑到了腰侧。千手痒痒裤听见了，也跟着「帮忙」——裤子里的手和粉色公主的手一起动）",
        [A("tickle", who="blue", by="princess", zone="waist", fx="hand", repeat=12, interval=0.12), _bt(10, 0.12), _bp("helpless_2")], act=3),
    say(BLUE, "……哈、哈哈……裤子……犯规……哈哈哈……"),
    say(P, "裤子也是你的嘛！", emotion="happy"),
    _burst_blue("……哈……哈哈……认、认输……（冰晶在擂台上炸开，一圈雪花慢慢落下来……）"),
    say(N, "（粉色公主停了手，在她旁边躺下。两个人看着训练场高高的天花板，喘着气）", [_bp("helpless_1")], act=4),
    say(P, "……你今天笑了好多。", emotion="happy"),
    say(BLUE, "……嗯。……好像，以前也这样笑过。"),
])

SPAR_LOSE = theater("训练场：对练输了", _duo("helpless_1", "normal"), [
    say(N, "（粉色公主先笑出了声。……她早就知道，自己根本忍不住）", act=1),
    say(BLUE, "……输了。"),
    say(P, "……再、再来一局！三局两胜！", emotion="angry"),
    say(BLUE, "……规则。……一刻钟。"),
    say(N, "（蓝色公主把她的鞋袜放到一边，握住了一只脚踝。指尖在脚心上慢慢地画圈）", [tk("blue", fx="hand", n=10, iv=0.15), pose("giggle")], act=2),
    say(P, "嘻……嘻嘻……你、你明明不爱笑，挠人倒是很会……！", emotion="giggle"),
    say(BLUE, "……学的。……你挠我的时候。"),
    say(N, "（画圈变成了轻轻地抓，抓完脚心，又一根一根地挠脚趾缝）", [tk("blue", fx="lines", n=14, iv=0.11), pose("helpless_2")], act=3),
    say(P, "哈哈哈！趾缝——不行——哈哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……还有十分钟。"),
    _burst_pink("（星光在擂台上炸开……哈啊……放出去了……）"),
    say(N, "（蓝色公主停下手，替她把袜子套了回去）", [pose("helpless_1")], act=4),
    say(BLUE, "……下次。……让你赢。"),
    say(P, "……不用让！下次我自己赢回来！", emotion="angry"),
])

STOCKS_T = theater("训练场：耐痒训练台", _duo("normal", "normal", st={"kind": "trap:stocks", "at": [0, 12]}), [
    say(N, "（墙角一张磨得发亮的足枷台。牌子上写着：「骑士耐痒训练——坚持一刻钟不笑出声者，可称骑士」）", act=1),
    say(P, "……骑士的训练？……试试！", emotion="happy"),
    say(BLUE, "……我陪你。"),
    say(N, "（两个人并排坐上训练台，四只脚踝被枷板扣住。台子底下伸出两排羽毛刷，慢慢地、慢慢地扫了起来）",
        [tk("st", fx="feather", n=8, iv=0.2), _bt(6, 0.22, by="st", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "（……忍住……骑士都忍得住……）", emotion="giggle"),
    say(BLUE, "（……数数。……一、二、三……）"),
    say(N, "（羽毛扫得越来越快，又越来越慢。快的时候还好，慢的时候简直要命）", [tk("st", fx="feather", n=12, iv=0.14), _bt(10, 0.14, by="st", zone="sole", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=3),
    say(P, "（……慢、慢慢扫……比快的还……）", emotion="helpless_1"),
    say(BLUE, "（……二十七……二十……八……）"),
    say(N, "（两个人咬着嘴唇，互相看了一眼——都憋得满脸通红。……就在这时候，两个人同时「噗」地笑了出来）", [pose("helpless_2"), _bp("helpless_2")]),
    say(P, "哈哈哈！你、你的脸——太好笑了——！", emotion="helpless_2"),
    say(BLUE, "……你、你才是……哈哈哈……"),
    _burst_pink("（星光炸开，羽毛刷被吹得四处乱飞……哈啊……放出去了……）"),
    say(N, "（训练台「咔」地松开了枷板。牌子底下，一行小字慢慢亮了起来：「笑着坚持到最后的人，也是骑士」）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "……笑着坚持到最后。……这个规则我喜欢。", emotion="happy"),
    say(N, "（两个人都觉得，身体里有什么东西变得结实了一点）"),
])

TRAINING_LOSE = theater("训练场：遭遇战输了", _duo("helpless_1", "helpless_1", straw={"kind": "monster:troll", "at": [0, -4], "dir": "down"}), [
    say(N, "（大稻草人教官把两个人一手一个拎了起来，搁在了训练用的木马上）", act=1),
    say(N, "（「训练不合格。补课。」——稻草做的手指在两个人的脚心、膝盖窝上一下一下地戳）",
        [tk("straw", fx="hand", n=12, iv=0.13), _bt(10, 0.13, by="straw", zone="thigh", fx="hand"), pose("helpless_2"), _bp("helpless_2")], act=2),
    say(P, "哈哈哈！稻草——扎扎的——好痒——！", emotion="helpless_2"),
    say(BLUE, "……补、补课……哈哈……不要……"),
    _burst_pink("（星光炸开，稻草飞了满场……哈啊……放出去了……）"),
    say(N, "（等两个人回过神来，鸣钟又挂回了原处，稻草人们也站回了墙边）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(BLUE, "……再敲一次。"),
])

THEATERS = dict({"library_bookmonster": BOOKMONSTER, "wardrobe_measure": MEASURE, "wardrobe_socks": SOCKS_T, "wardrobe_tryon": TRYON,
                 "wardrobe_trap_in": TRAP_IN, "wardrobe_trap_out": TRAP_OUT, "training_spar_in": SPAR_IN, "training_spar_win": SPAR_WIN,
                 "training_spar_lose": SPAR_LOSE, "training_stocks": STOCKS_T, "training_lose": TRAINING_LOSE}, **TRY)


# ================================================================ 对话（书、残页、密码门、线索……）
def _book(title, lines):
    return dfile("", title, {"default": {"lines": [L("（%s）" % title, N)] + lines}})


def _cipher_doc():
    """书房管理记录：残页越多看得越清楚（palace_frags = 找到的残页数）"""
    rows = [("第一位：浴场的镜子上，□□□□□□□□。", "第一位：浴场的镜子上，水汽写下的数字。"),
            ("第二位：□□□□□□□□□□的日子。", "第二位：两位小殿下洗脚水的日子（排班表）。"),
            ("第三位：□□□□□□□的尺码。", "第三位：衣帽间里，小殿下礼服的尺码。"),
            ("第四位：□□□□□□□□。", "第四位：训练场墙上，骑士刻下的划痕。")]
    nodes, entries = {}, []
    for n in (3, 2, 1, 0):
        lines = [L("（一本厚厚的记录簿。最后一页写着书房的开门方法，可是被人用墨水涂掉了大半）", N),
                 L("「书房的门：四位数字。」", N)]
        for i, (hidden, shown) in enumerate(rows):
            lines.append(L("「%s」" % (shown if i == 0 or i <= n else hidden), N))
        if n < 3:
            lines.append(L("……被涂掉的地方，好像能和别的纸拼起来。（残页：%d / 3）" % n, P, "question"))
        else:
            lines.append(L("……全拼起来了。四个数字，就藏在我们走过的四个房间里。", P, "surprise"))
        nodes["frag%d" % n] = {"lines": lines}
        entries.append({"if": {"var": {"palace_frags": [">=", n]}}, "node": "frag%d" % n} if n > 0 else {"node": "frag0"})
    return dfile("", "书房管理记录", nodes, entries=entries)


def _fragment(name, look, flag):
    return dfile("", name, {
        "default": {"lines": [L(look, N), L("……是记录簿上撕下来的那一页！", P, "surprise")], "set": {"flags": [flag], "add": {"palace_frags": 1}}},
        "again": {"lines": [L("（残页已经拿走了）", N)]},
    }, entries=[{"if": {"flag": flag}, "node": "again"}, {"node": "default"}])


def _cipher_door():
    nodes = {"default": {"lines": [L("（一扇沉重的木门，门上嵌着四个能转动的铜轮，每个轮子上刻着 2、3、5、7）", N)],
                         "prompt": "转第一个轮子？", "choices": [{"text": d, "next": ("d2" if d == CODE[0] else "wrong")} for d in DIGITS]},
             "wrong": {"lines": [L("（「咔哒」……门没有动。四个铜轮自己转回了原位）", N), L("……不对。再想想。", BLUE)]},
             "open": {"lines": [L("（门开着。里面是一间小小的书房）", N)]}}
    for i in (2, 3, 4):
        nodes["d%d" % i] = {"lines": [L("（「咔」）", N)], "prompt": "转第 %d 个轮子？" % i,
                            "choices": [{"text": d, "next": (("d%d" % (i + 1)) if i < 4 else "ok") if d == CODE[i - 1] else "wrong"} for d in DIGITS]}
    nodes["ok"] = {"lines": [L("（四个铜轮同时「咔哒」一声——门，慢慢地开了）", N)], "set": {"call": "palace_cipher_ok"}}
    return dfile("", "密码门", nodes, entries=[{"if": {"flag": "palace_cipher_open"}, "node": "open"}, {"node": "default"}])


def _spot(name, look, prompt, yes, theater_id, again, extra=None):
    go = {"lines": [L(yes, P)], "theater": theater_id}
    if extra:
        go["set"] = extra
    return dfile("", name, {
        "default": {"lines": [L(look, N)], "prompt": prompt, "choices": [{"text": yes, "next": "go"}, {"text": "……先不了", "next": "no"}]},
        "go": go,
        "no": {"lines": [L("……等一下再说。", P)]},
        "again": {"lines": [L(again, N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:" + theater_id}, "node": "again"}, {"node": "default"}])


DIALOGUES = {
    "library_book_1": _book("《笑之王国简史》残卷", [L("「……每逢□□节，全国的人一起笑。笑声汇到王宫的钟楼上，钟就会自己响起来……」", N),
                                                L("「……直到那一夜，钟敲了十三下。从那以后，王国里再也没有□□……」", N),
                                                L("……钟敲了十三下。", BLUE)]),
    "library_book_2": _book("《女仆守则》", [L("「第七条：两位小殿下的洗脚水要温，加一点薄荷。每月的那一天，要换新的薄荷。」", N),
                                          L("「……那一天是几号，排班表上写着。」", N)]),
    "library_book_3": _book("《宫廷礼服尺码册》", [L("「小殿下的礼服：□号。」（尺码被墨水涂掉了）", N),
                                              L("（旁边有一行小字：「两件一模一样。去衣帽间看吧」）", N)]),
    "library_book_4": _book("《骑士训练手册》", [L("「骑士每打完一场对练，要在训练场的墙上刻一道。刻痕就是骑士的勋章。」", N),
                                              L("「……那位骑士，最喜欢和小殿下们比赛谁先笑。」", N)]),
    "library_book_5": _book("《封笑之书》（残本）", [L("「……以笑为钥，以□□为锁。被封住的笑声，要两个人一起，才能唤醒……」", N),
                                               L("……两个人一起。", P, "sad")]),
    "library_book_6": _cipher_doc(),
    "library_fragment": _fragment("书山下的残页", "（倒下的书山底下，压着一张撕破的纸）", "palace_frag_1"),
    "library_door": _cipher_door(),
    "library_golden": dfile("", "金色大书", {
        "default": {"lines": [L("（禁书区的书架上，一本金色的大书微微发着光。封面上没有字）", N)], "prompt": "翻开它？",
                    "choices": [{"text": "翻开", "next": "go"}, {"text": "不翻", "next": "no"}]},
        "go": {"lines": [L("……就看一眼。", P)], "set": {"call": "palace_golden"}},
        "no": {"lines": [L("……禁书区的书。……还是算了。", P)]},
        "again": {"lines": [L("（金色大书安安静静地合着。……书脊上的纸牙，好像动了一下）", N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:library_bookmonster"}, "node": "again"}, {"node": "default"}]),
    "wardrobe_dresses": dfile("", "一大一小两件礼服", {"default": {"lines": [
        L("（衣柜最深处，并排挂着两件小小的礼服。一件粉色，一件蓝色，样式一模一样）", N),
        L("（衣架上本来挂着名牌，被人扯掉了。领口里缝着尺码标签：「7」）", N),
        L("……两件一样的小礼服。粉色的，和蓝色的。", P, "surprise"),
        L("……小殿下的礼服。……尺码，七。", BLUE)]}}),
    "wardrobe_fragment": _fragment("大衣口袋里的残页", "（一件旧大衣的口袋里，叠着一张撕下来的纸）", "palace_frag_2"),
    "wardrobe_mannequin": _spot("礼服人台", "（一具穿着半成品礼服的人台，手里攥着软尺）", "走近看看？", "……就看一眼。", "wardrobe_measure",
                                "（人台安安静静地站着。软尺上的刻度停在「小殿下」那一格）"),
    "wardrobe_rack_1": _spot("旧衣架", "（衣架上挂着一条粉蓝两色的小发带）", "试试？", "……系上看看。", "wardrobe_try_1",
                             "（衣架空了）", {"give_item": {"equip_palace_ribbon": 1}}),
    "wardrobe_rack_2": _spot("旧衣架", "（衣架上挂着一条深蓝色的束腰）", "试试？", "……系上看看。", "wardrobe_try_2",
                             "（衣架空了）", {"give_item": {"equip_palace_corset": 1}}),
    "wardrobe_rack_3": _spot("旧衣架", "（衣架底下放着一双白色的高筒靴）", "试试？", "……穿上看看。", "wardrobe_try_3",
                             "（衣架空了）", {"give_item": {"equip_palace_boots": 1}}),
    "wardrobe_socks": _spot("自动穿袜机", "（一台黄铜做的老机器：「自动穿袜机——请把脚放进来」）", "把脚放进去？", "……试一下。", "wardrobe_socks",
                            "（穿袜机「嗡」地响了一声，冒出一股白烟。……还是别再试了）", {"give_item": {"equip_palace_stockings": 1}}),
    "wardrobe_favorite": _spot("玫瑰色的礼服", "（一件玫瑰色的舞会礼服，层层叠叠的薄纱，金线绣的小花）", "试穿？", "……试一下。", "wardrobe_tryon",
                               "（礼服叠好放进了背包。……下次找个机会再穿）"),
    "wardrobe_trap": dfile("", "雕花的大衣柜", {
        "default": {"lines": [L("（一个雕着花的大衣柜。柜门上挂着一张泛黄的纸条：「捉迷藏专用——请勿关门」）", N)], "prompt": "打开看看？",
                    "choices": [{"text": "钻进去看看", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("……里面会不会有好东西。", P)], "set": {"call": "palace_trap"}},
        "no": {"lines": [L("……「请勿关门」。……不碰它。", P)]},
        "locked": {"lines": [L("（柜门锁着。柜子里传来一阵阵笑声）", N), L("……钥匙。……要去找钥匙。", BLUE)], "set": {"call": "palace_trap_open"}},
        "done": {"lines": [L("（柜门开着，里面空空的。……再也不想碰它了）", N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:wardrobe_trap_out"}, "node": "done"}, {"if": {"flag": "palace_trap_active"}, "node": "locked"}, {"node": "default"}]),
    **{"wardrobe_key_%d" % i: dfile("", place, {
        "default": {"lines": [L("（%s。……没什么特别的）" % look, N)]},
        "search": {"lines": [L("（翻了翻%s——）" % place, N)], "set": {"call": "palace_search_%d" % i}},
    }, entries=[{"if": {"flag": "palace_trap_active"}, "node": "search"}, {"node": "default"}])
        for i, place, look in ((1, "进门的旧斗柜", "一个落满灰的旧斗柜"), (2, "挂满大衣的衣架", "一排挂着旧大衣的衣架"), (3, "首饰盒", "梳妆台上的首饰盒"))},
    "training_sign": dfile("", "木牌", {"default": {"lines": [
        L("（木牌上刻着：「对练稻草人：先打最左边的，再打最右边的，然后从右往左打中间两个。打错了，稻草人会还手」）", N)]}}),
    "training_carvings": dfile("", "墙上的刻痕", {"default": {"lines": [
        L("（墙上刻着两个名字。一个是骑士的名字——另一个，是保卫队队长的名字。两个名字下面，各有几道深深的划痕）", N),
        L("（骑士的名字下面，是三道。……旁边还有一行小小的字：「输给小殿下们，三次」）", N),
        L("……队长和骑士，以前在这里一起训练过。", P, "surprise"),
        L("……三道。", BLUE)]}}),
    "training_diary": dfile("", "旧训练日志", {"default": {"lines": [
        L("（柜子里有一本旧日志。字迹很年轻，可是——是队长的字）", N),
        L("「今天又被小殿下们挠得练不了剑。骑士笑我，结果他自己也被挠倒了。」", CAPTAIN_YOUNG),
        L("「女王陛下说，等小殿下们长大了，要让她们两个都学剑。」", CAPTAIN_YOUNG),
        L("「每天下午，钟楼的时针一走到『三』，小殿下们就溜出来找我——那是点心的时间。」", CAPTAIN_YOUNG),
        L("「……我要好好练。等那一天来了，我要护住她们两个。」", CAPTAIN_YOUNG),
        L("……队长的日记。……「她们两个」。", P, "sad"),
        L("……和那张照片。……一样的人。", BLUE)]}}),
    "training_ring": dfile("", "对练擂台", {
        "default": {"lines": [L("（擂台边的木牌：「骑士对练——背靠背坐下，先笑出声的人输」）", N)], "prompt": "和蓝色公主比一场？",
                    "choices": [{"text": "比！", "next": "go"}, {"text": "下次", "next": "no"}]},
        "go": {"lines": [L("……来比！", P, "angry")], "set": {"call": "palace_spar"}},
        "no": {"lines": [L("……下次。", P)]},
    }),
    "training_bell": dfile("", "习武鸣钟", {
        "default": {"lines": [L("（训练场中央挂着一口铜钟。钟下的牌子：「敲钟者，接受考验」）", N)], "prompt": "敲钟？",
                    "choices": [{"text": "敲！", "next": "go"}, {"text": "不敲", "next": "no"}]},
        "go": {"lines": [L("（「铛——」）", N)], "set": {"call": "palace_bell_fight"}},
        "no": {"lines": [L("……先准备一下。", P)]},
        "done": {"lines": [L("（铜钟静静地挂着。考验已经过了）", N)]},
    }, entries=[{"if": {"flag": "palace_training_cleared"}, "node": "done"}, {"node": "default"}]),
    "training_stocks": _spot("耐痒训练台", "（「骑士耐痒训练——坚持一刻钟不笑出声者，可称骑士」）", "坐上去试试？", "……试试看。", "training_stocks",
                             "（训练台空着。牌子底下那行小字还亮着：「笑着坚持到最后的人，也是骑士」）", {"passive": "knight_endurance"}),
    "training_chest": dfile("", "旧箱子", {
        "default": {"lines": [L("（一口上了锁的旧箱子。锁上刻着一口小钟的图案）", N), L("……要先通过钟的考验？", P, "question")]},
        "open": {"lines": [L("（箱子的锁「咔」地弹开了。里面放着一张撕破的纸）", N), L("……最后一张残页！", P, "surprise")],
                 "set": {"flags": ["palace_frag_3"], "add": {"palace_frags": 1}}},
        "again": {"lines": [L("（箱子空了）", N)]},
    }, entries=[{"if": {"flag": "palace_frag_3"}, "node": "again"}, {"if": {"flag": "palace_training_cleared"}, "node": "open"}, {"node": "default"}]),
}

SIGNS = {
    "palace_training_north": [{"speaker": N, "text": "（通往王座间的回廊。门上缠着一圈紫色的封印，推不开）"}],
}


def library_in():
    s = [
        line(N, "（北门后面是一座巨大的图书馆。一排排书架一直伸到看不见的地方，有的倒了，书散了一地）"),
        line(P, "……好多书。", "surprise"),
        line(BLUE, "……王国的书。……那天晚上的事，说不定写在哪里。"),
        line(N, "（书架的影子里，有什么东西「沙沙」地动了一下）"),
        {"actions": [A("notify", text="调查图书馆的书（有的被打了码，残页能拼回来）")], "wait": 0.3},
    ]
    return {"name": "图书馆", "letterbox": True, "skippable": True, "steps": s}


def wardrobe_in():
    s = [
        line(N, "（东门后面是衣帽间。一排排衣架挂满了旧礼服，墙上是一人高的穿衣镜，镜子里映出无数个她们）"),
        line(P, "……哇。好多漂亮的衣服……", "happy"),
        line(BLUE, "……镜子。……有点多。"),
        {"actions": [A("notify", text="调查衣帽间")], "wait": 0.3},
    ]
    return {"name": "衣帽间", "letterbox": True, "skippable": True, "steps": s}


def training_in():
    s = [
        line(N, "（西门后面是一座宽敞的训练场。地上铺着磨旧的软垫，墙边立着一排排稻草人和木人桩，中央挂着一口铜钟）"),
        line(BLUE, "……骑士的训练场。"),
        line(P, "……那个骑士，以前在这里训练过吗？", "question"),
        {"actions": [A("notify", text="调查骑士训练场")], "wait": 0.3},
    ]
    return {"name": "骑士训练场", "letterbox": True, "skippable": True, "steps": s}


def flashback():
    s = [
        {"actions": [A("bg", img="library_flashback")], "wait": 0.6},
        line(N, "（书页里涌出一片金光。金光里，是很久很久以前的一个夜晚）"),
        line(N, "（王宫的走廊。月光从高高的窗户照进来。两个小小的女孩，手拉着手，光着脚在走廊里跑）"),
        line(N, "（一个是粉色的头发，一个是蓝色的头发。蓝色头发的那个，紧紧地拉着粉色头发的那个）"),
        line(N, "（身后，一个穿着银色盔甲的骑士，用背顶住了一扇门。远处，钟楼的钟在响——一下、两下……十三下）"),
        line(P, "……这是……", "surprise"),
        line(BLUE, "……", None),
        {"actions": [A("bg_clear")], "wait": 0.6},
    ]
    return {"name": "那天晚上", "letterbox": True, "skippable": True, "steps": s}


def study():
    s = [
        {"actions": [A("bg", img="library_study")], "wait": 0.6},
        line(N, "（密码门后面，是一间小小的书房。桌上点着一根蜡烛——不知道是谁点的，烧了多久）"),
        line(N, "（墙上挂着一幅画。画里的女王抱着两个襁褓，脸已经褪色得看不清了）"),
        line(N, "（桌上有一封没写完的信，字迹被水渍晕开了，只看得清开头几个字：「给我的——」）"),
        line(N, "（信旁边，是一个雕花的木托盘。托盘上有两个半圆形的凹槽，像是用来放两块合在一起的东西）"),
        line(BLUE, "……（从怀里拿出那半枚徽章，放进其中一个凹槽）……刚好。", None),
        line(P, "……另一个凹槽，是空的。", "sad"),
        line(N, "（桌角放着一个裂了缝的八音盒，发条钥匙还插在上面。拧一下——只响了两个音，就卡住了）"),
        line(N, "（墙角钉着一张小孩的画：两个手拉手的小人。……和手帕上、布偶上、鼠洞里的，一模一样）"),
        line(P, "……", "sad"),
        line(BLUE, "……另一半。……在哪里。"),
        {"actions": [A("bg_clear")], "wait": 0.6},
    ]
    return {"name": "私人书房", "letterbox": True, "skippable": True, "steps": s}


def bell_fight():
    s = [
        line(N, "（钟声在训练场里回荡。四面的门「砰砰」地关上了，墙边的稻草人一个接一个地动了起来）"),
        line(BLUE, "……考验。"),
        line(P, "来吧！", "angry"),
    ]
    return {"name": "习武鸣钟", "letterbox": True, "skippable": True, "steps": s}


def bell_clear():
    s = [
        line(N, "（大稻草人教官「哗啦」一声散成了一地稻草。四面的门又打开了）"),
        line(P, "……通、通过了！", "happy"),
        line(BLUE, "……嗯。……箱子的锁，应该开了。"),
    ]
    return {"name": "考验通过", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"palace_library_in": library_in, "palace_wardrobe_in": wardrobe_in, "palace_training_in": training_in, "library_flashback": flashback,
             "library_study": study, "training_bell_fight": bell_fight, "training_bell_clear": bell_clear}
