"""反省篇第四章·旧王宫的追加事件（第一批：钟楼 / 王座前厅；鼠洞的在 tunnel.py）。
谜题连环链：钟面暗格（乐谱片①）→ 笑声地砖（三片乐谱）→ 地下小宝库（女王最喜欢的花）→ 石像问答 → 女王的八音盒（王座间 Boss 用）。
笑脸徽记（PalaceRoom.give_badge）：七枚集齐在前厅的徽记台换「女王的羽毛发饰」+ 庆祝小剧场（CG）。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, pose, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo

STATUE = "骑士石像"
SPRITES = "笑脸小精灵们"

# 地砖的正确顺序（行优先：0 左上 … 4 正中 … 8 右下），三片乐谱各写两步
TILE_SEQ = [0, 4, 8, 2, 4, 6]
TILE_NAMES = ["左上", "上中", "右上", "左中", "正中", "右中", "左下", "下中", "右下"]
SHEET_TEXT = {i: "「%s、%s」" % (TILE_NAMES[TILE_SEQ[2 * i - 2]], TILE_NAMES[TILE_SEQ[2 * i - 1]]) for i in (1, 2, 3)}

TEXT = {
    "beetle": ["齿、齿轮缝里爬出来好多小虫子！", "……发条虫。……打掉。"],
    "clockface_wrong": ["呀！钟面里弹出羽毛来了——！", "……不对。……被扫了。"],
    "armor_spot": ["铠、铠甲动了！它看见我们了！", "……空的铠甲。……在看这边。"],
    "armor_grab": ["放、放我下来——腋下不行——！", "……被举起来了。……腋下。"],
    "armor_push": ["从背后推——倒了！", "……散架了。"],
    "tiles_note": ["……地砖在笑？", "（踩上去，脚底下传来一声小小的笑声）"],
    "tiles_wrong": ["呀！地砖缝里伸出羽毛——！", "……踩错了。……脚心。"],
    "tiles_right": ["……对了。下一块。", "嗯，这一块！"],
    "statue_wrong": ["石、石头手在挠脚心——！", "……答错了。……好凉。"],
    "fountain_heal": ["……水凉凉的。好舒服。", "（喷泉的水花落在身上，笑意散掉了）"],
    "fountain_jet": ["呀！水柱喷到脚底了——！", "……喷泉。……喷脚心。"],
    "fountain_fish": ["小、小鱼在啄脚趾——！", "……鱼。……在啄。"],
}

_CLOCK_CHOICES = [("十二", "12"), ("三", "3"), ("六", "6"), ("九", "9")]


def _clock_face():
    nodes = {
        "default": {"lines": [L("（回廊尽头的墙上嵌着一面大钟。钟面落满了灰，两根指针都能用手拨动）", N),
                              L("（钟面底下有一道细细的缝——像是一个暗格）", N)],
                    "prompt": "把时针拨到……", "choices": [{"text": "指着「%s」" % t, "next": "m" if v == "3" else "wrong_h"} for t, v in _CLOCK_CHOICES]},
        "m": {"lines": [L("（「咔」）", N)], "prompt": "再把分针拨到……",
              "choices": [{"text": "指着「%s」" % t, "next": "ok" if v == "9" else "wrong"} for t, v in _CLOCK_CHOICES]},
        "wrong_h": {"lines": [L("（「咔」）", N)], "prompt": "再把分针拨到……",
                    "choices": [{"text": "指着「%s」" % t, "next": "wrong"} for t, _v in _CLOCK_CHOICES]},
        "wrong": {"lines": [L("（「嘣」——钟面里弹出一圈羽毛，扫过两个人的腰）", N)], "set": {"call": "palace_clockface_wrong"}},
        "ok": {"lines": [L("（「当——」钟面里响了一声。底下的暗格「咔哒」一声弹开了）", N),
                         L("（暗格里放着一片泛黄的乐谱，和一枚金色的笑脸徽记。乐谱上写着：%s）" % SHEET_TEXT[1], N),
                         L("……三点四十五分。……训练场的日志、婴儿房的刻痕。", BLUE),
                         L("说好了，这个时候一起去钟楼……", P, "sad")], "set": {"call": "palace_clockface_ok"}},
        "open": {"lines": [L("（钟面停在三点四十五分。暗格空了）", N)]},
    }
    return dfile("", "大钟面", nodes, entries=[{"if": {"flag": "palace_clockface_open"}, "node": "open"}, {"node": "default"}])


def _statue():
    q = {
        "q1": ("「问：那天晚上，钟楼的钟敲了几下？」", ["十二下", "十三下", "一下也没有"], 1),
        "q2": ("「问：两位小殿下的礼服，是几号？」", ["五号", "七号", "九号"], 1),
        "q3": ("「问：女王陛下最喜欢的花，是什么？」", ["玫瑰", "铃兰", "向日葵"], 1),
    }
    nodes = {
        "default": {"lines": [L("（一尊抱着剑的骑士石像。底座上刻着一行字）", N),
                              L("「钟楼的钟，敲十三下的时候，王座间的门就会打开。……那天晚上，它就是这样打开的」", N),
                              L("（石像的眼睛「咔」地亮了一下。底座上又浮出一行新的字：「答对三个问题，就把陛下的东西交给你们」）", N)],
                    "prompt": "回答石像的问题？", "choices": [{"text": "回答", "next": "q1"}, {"text": "等一下", "next": "no"}]},
        "no": {"lines": [L("……先去找找答案。", P)]},
        "wrong": {"lines": [L("（石像的底座里伸出一只石头手，抓住了答题人的脚踝——）", N)], "set": {"call": "palace_statue_wrong"}},
        "ok": {"lines": [L("（石像缓缓地低下头，把抱着的剑移开。剑柄后面藏着一只粉色的小八音盒，和一枚笑脸徽记）", N),
                         L("……八音盒。", BLUE),
                         L("（打开盖子，里面传出一段很轻很轻的笑声——像是一个大人，和两个很小很小的孩子）", N),
                         L("……这个声音。", P, "sad"),
                         L("……王座间的画像。……也许，会怕这个。", BLUE)], "set": {"call": "palace_statue_ok"}},
        "done": {"lines": [L("（石像抱着剑，安安静静地站着。底座上的字已经暗了）", N)]},
    }
    order = ["q1", "q2", "q3"]
    for i, k in enumerate(order):
        text, options, right = q[k]
        nxt = order[i + 1] if i + 1 < len(order) else "ok"
        nodes[k] = {"lines": [L(text, N)], "prompt": "回答……",
                    "choices": [{"text": o, "next": nxt if j == right else "wrong"} for j, o in enumerate(options)]}
    return dfile("", "骑士石像", nodes, entries=[{"if": {"flag": "palace_statue_done"}, "node": "done"}, {"node": "default"}])


DIALOGUES = {
    "clock_face": _clock_face(),
    "ante_statue": _statue(),
    "ante_fountain": dfile("", "许愿喷泉", {
        "default": {"lines": [L("（一座小小的大理石喷泉，池底躺着几枚旧金币。边上刻着：「投下心意，许一个愿」）", N)],
                    "prompt": "投点什么？", "choices": [{"text": "一颗薄荷糖", "next": "mint"}, {"text": "10 枚金币", "next": "coin"}, {"text": "算了", "next": "no"}]},
        "mint": {"lines": [L("……许个愿。", P)], "set": {"call": "palace_fountain_mint"}},
        "coin": {"lines": [L("……许个愿。", P)], "set": {"call": "palace_fountain_coin"}},
        "no": {"lines": [L("……下次再许。", P)]},
    }),
    "ante_pedestal": dfile("", "徽记台", {
        "default": {"lines": [L("（一座石台，台面上排着七个小小的圆形凹槽。最上面刻着一张咧嘴笑的脸）", N),
                              L("「七枚笑脸，换陛下的一件小礼物」", N)],
                    "prompt": "把笑脸徽记放上去？", "choices": [{"text": "放上去", "next": "go"}, {"text": "再找找", "next": "no"}]},
        "go": {"lines": [L("……放上去看看。", P)], "set": {"call": "palace_badges"}},
        "no": {"lines": [L("……还差几枚。", P)]},
        "done": {"lines": [L("（七个凹槽里都嵌着金色的笑脸。……它们好像还在偷偷地笑）", N)]},
    }, entries=[{"if": {"flag": "palace_badges_done"}, "node": "done"}, {"node": "default"}]),
    "ante_vault": dfile("", "地下小宝库", {"default": {"lines": [
        L("（地砖一块一块地沉下去，露出一道窄窄的台阶。底下是一间小小的宝库）", N),
        L("（宝库里没有金子。只有一个旧花瓶，插着一束早就干掉的白色小花——一串一串的小铃铛）", N),
        L("……铃兰。", BLUE),
        L("（花瓶底下压着一张卡片：「给最喜欢铃兰的陛下——两个小不点」。卡片旁边，放着一枚金色的笑脸徽记）", N),
        L("……陛下最喜欢的花。……石像也许会问这个。", P)], "set": {"call": "palace_vault"}}}),
}

SIGNS = {
    "palace_tiles_dim": [{"speaker": N, "text": "（地砖上刻着一个个小小的笑脸。踩上去，脚底下会传来一声笑）"}],
}

# ================================================================ 徽记台：庆祝（CG）
BADGE_PARTY = theater("王座前厅：笑脸徽记的庆祝", _duo("normal", "normal", s1={"kind": "trap:feather_curtain", "at": [-24, -10]},
                                                  s2={"kind": "trap:feather_curtain", "at": [24, -10]}), [
    say(N, "（七枚笑脸徽记一放进凹槽，石台「嗡」地亮了。台阶下面，传来一阵叮叮当当的笑声）", act=1),
    say(N, "（一群金色的笑脸小精灵从徽记里钻了出来，扑扇着小翅膀，把一支雪白的羽毛发饰递到粉色公主手里）"),
    say(P, "给、给我的？……好漂亮！", emotion="happy"),
    say(SPRITES, "恭喜恭喜！庆祝庆祝！"),
    say(BLUE, "……庆祝。……怎么庆祝。"),
    say(SPRITES, "当然是——一起笑！", act=2),
    say(N, "（小精灵们一拥而上，把两个人推倒在宝库里的大天鹅绒软垫上，羽毛小手在腰上、肋下一阵乱挠）",
        [tk("s1", fx="feather", n=10, iv=0.14), _bt(8, 0.14, by="s2", zone="waist", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(P, "嘻嘻……等、等一下……发饰——发饰要掉了——！", emotion="giggle"),
    say(BLUE, "……哈……不、不需要……这种庆祝……"),
    cg(say(N, "（两个人的鞋早被小精灵们扒到了一边。小精灵们排成一圈，有的挠脚心，有的挠脖子，五彩的纸屑哗哗地往下落）",
           [tk("s1", zone="sole", fx="lines", n=14, iv=0.1), _bt(12, 0.1, by="s2", zone="sole", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=3)),
    say(P, "哈哈哈！好、好多——！你们到底有几个——！", emotion="helpless_1"),
    say(SPRITES, "七个七个！一个徽记一个！再来再来！"),
    say(BLUE, "……哈、哈哈……数、数不过来……", [_bp("helpless_2")]),
    say(N, "（两个人笑得滚成一团，靠在一起，谁也扶不起谁）", [pose("helpless_2"), _bt(14, 0.09, by="s2", zone="armpit", fx="hand")]),
    _burst_blue("……哈……哈哈……（冰晶在宝库里炸开，纸屑全冻成了亮晶晶的小雪花……）"),
    _burst_pink("（星光跟着炸开，满屋子都是叮叮当当的小星星……哈啊……放出去了……）"),
    say(N, "（小精灵们在雪花和星星里转着圈——然后一个一个落下来，在两个人刚释放完、敏感得要命的脚心上各亲了一下似的蹭了一蹭）",
        [tk("s1", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……最、最后那一下是什么……", emotion="helpless_1"),
    say(SPRITES, "是祝福！陛下的祝福！"),
    say(N, "（小精灵们钻回了徽记里。宝库又安静了下来）", [pose("normal"), _bp("normal")]),
    say(BLUE, "……（把粉色公主歪掉的发饰扶正）……很适合你。"),
    say(P, "……嘿嘿。", emotion="happy"),
])

THEATERS = {"palace_badge_party": BADGE_PARTY}
