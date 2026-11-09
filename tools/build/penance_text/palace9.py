"""反省篇第四章·尾声「画里的记忆」：打完王座间的 Boss 以后，两半徽章合在一起（joined_badge），女王的画留在原地；
带着徽章在画前按 E → 被吸进画里（floor_06_palace_memory）。画里是女王封进去的记忆，一条路走过四段：
  ① 婴儿房的下午（人偶们把两人当成回来的小殿下，「哄睡」挠痒；一个摇篮的名牌被抹掉：「这一位，还没回来」）
  ② 画了一半的全家福（两个孩子的位置，谁站上去脸都会糊掉——骑士篇「两个殿下，其中一个是冒牌货」的矛盾摆出来）
  ③ 女王的牺牲（那天晚上，笑声失控、钟敲十三下；女王把整座王宫的笑声封进画里，自己也被画了进去，好让孩子被抱出去）
  ④ 交钥匙的回忆（女王把小钥匙交给系着蓝色发带的「守门的那个孩子」）→ 画布裂开，女王背对着她们：「……把门，关好。」
出来以后：画像的脸第一次干干净净、闭着眼睛 → 章末「第四章　旧王宫　完」。之后画像可以反复调查，蓝色公主多几段对话。
只给线索、不说破（剧情设定见 docs/private/剧情设定与伏笔.md）；抱走孩子的人只是黑色剪影。只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, line, pose, say, theater, tk
from . import palace10
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo

QUEEN = "女王"
DOLL = "画里的人偶"
MEMORY_FLAG = "palace_memory_done"

TEXT = {
    "memory_pencil": ["……这里只有铅笔线。……进不去。", "……没画完的地方。……她不想记得。"],
}

# ---------------------------------------------------------------- 王座间：打完以后的画像（进画前 / 出来以后）
PORTRAIT_ENTER = dfile("", "女王的画像", {
    "default": {"lines": [L("（烧穿的缺口已经慢慢合上了。画布上，女王的脸还是糊的，可是画框在轻轻地发烫）", N),
                          L("（合在一起的两半徽章，也跟着暖了起来。……画里，好像还有什么）", N)],
                "prompt": "把徽章贴到画布上？", "choices": [{"text": "贴上去", "next": "go"}, {"text": "再等等", "next": "no"}]},
    "go": {"lines": [L("……一起。", BLUE), L("嗯。一起。", P)], "set": {"call": "palace_memory_enter"}},
    "no": {"lines": [L("……等准备好了再来。", P)]},
})

# 出来以后：画像的四段调查（按进度依次出；看完一轮以后随机重看）
_INVEST = [
    ("eyes", [L("（画像里女王的脸干干净净，第一次看得清——眉眼很温柔。可是她闭着眼睛）", N),
              L("……她像在等什么人。", P, "sad"),
              L("……………", BLUE)]),
    ("paint", [L("（画布合上的那道缝里，还留着两种颜色的颜料。一种是粉色的）", N),
               L("……另一种呢？", P),
               L("……不是蓝。……说不出是什么颜色。……像是，还没调出来的颜色。", BLUE)]),
    ("plate", [L("（画框下面钉着一块小铜牌：「愿你们一直笑着」）", N),
               L("（铜牌背后夹着一片干掉的铃兰，花瓣一碰就碎了）", N),
               L("……「你们」。", P, "sad"),
               L("……陛下最喜欢的花。", BLUE)]),
    ("laugh", [L("（把耳朵贴到画布上——很远很远的地方，有很多很多笑声）", N),
               L("（笑声里，有一个大人的，和两个很小很小的孩子的）", N),
               L("……那是，陛下替我们收着的笑声吗。", P, "sad"),
               L("……总有一天，要还给她。", BLUE)]),
]


def _portrait_after():
    nodes, entries = {}, []
    for i, (k, lines) in enumerate(_INVEST):
        nodes[k] = {"lines": lines, "set": {"flags": ["palace_portrait_%s" % k]}}
        need = ["palace_portrait_%s" % _INVEST[j][0] for j in range(i)]
        entries.append({"if": {"flag": need, "not": "palace_portrait_%s" % k} if need else {"not": "palace_portrait_%s" % k}, "node": k})
    # 都看过了：按 vars.palace_portrait_pick 随机重看一段
    for i, (k, _lines) in enumerate(_INVEST):
        entries.append({"if": {"eq": {"palace_portrait_pick": i}}, "node": k})
    entries.append({"node": _INVEST[0][0]})
    return dfile("", "女王的画像", nodes, entries=entries)


# ---------------------------------------------------------------- 画里的四段记忆（调查点）
MEMORY_CRADLES = dfile("", "两个摇篮", {
    "default": {"lines": [
        L("（阳光从蕾丝窗帘里漏进来，婴儿房的颜色鲜得像刚画上去的一样。两个摇篮并排摆着，一个系粉丝带，一个系蓝丝带）", N),
        L("……小殿下们！小殿下们回来了！", DOLL),
        L("（人偶们一下子围了上来，扯着两个人的袖子，眼睛亮亮的）", N),
        L("诶？我、我们不是……", P, "surprise"),
        L("……回来了就好。……该睡午觉了。", DOLL),
        L("（蓝丝带的摇篮上，名牌写着一个小小的名字，被颜料糊住了。粉丝带的那个——名牌整个被抹掉了）", N),
        L("……这个摇篮的名牌呢？", P),
        L("……这一位。……还没回来。", DOLL),
        L("……可是，我们不是回来了吗。", P, "sad"),
        L("（人偶歪着头，没有回答。它只是轻轻地，把两个人往软垫那边推）", N)],
        "theater": "memory_nursery", "set": {"flags": ["palace_memory_1"]}},
    "again": {"lines": [L("（两个摇篮轻轻地晃。被抹掉的那块名牌，在阳光里白得刺眼）", N),
                        L("……这一位，还没回来。", DOLL)]},
}, entries=[{"if": {"flag": "palace_memory_1"}, "node": "again"}, {"node": "default"}])

MEMORY_EASEL = dfile("", "画了一半的全家福", {
    "default": {"lines": [L("（画室中间立着一个巨大的画架）", N)], "cutscene": "memory_portrait", "set": {"flags": ["palace_memory_2"]}},
    "again": {"lines": [L("（画架上，陛下身边的两个位置还是空着。一个糊掉，一个只有铅笔线）", N)]},
    "locked": {"lines": [L("（画室的门口浮着一层铅笔线，进不去。……也许要先去别的地方）", N)]},
}, entries=[{"if": {"flag": "palace_memory_2"}, "node": "again"}, {"if": {"not": "palace_memory_1"}, "node": "locked"}, {"node": "default"}])

MEMORY_BELL = dfile("", "钟楼上的大钟", {
    "default": {"lines": [L("（钟楼的顶上，一口大钟静静地挂着。钟身上全是裂纹，裂纹里透出金色的光）", N)],
                "cutscene": "memory_sacrifice", "set": {"flags": ["palace_memory_3"]}},
    "again": {"lines": [L("（大钟不再响了。裂纹里的金光，像是在轻轻地呼吸）", N),
                        L("……「我先替你们收着」。", P, "sad")]},
}, entries=[{"if": {"flag": "palace_memory_3"}, "node": "again"}, {"node": "default"}])

MEMORY_DOOR = dfile("", "走廊尽头的旧门", {
    "default": {"lines": [L("（走廊的尽头，是一扇很重很重的旧木门。门缝里漏着一线光）", N)],
                "cutscene": "memory_key", "set": {"flags": ["palace_memory_4"]}},
}, entries=[{"node": "default"}])

# ---------------------------------------------------------------- 蓝色公主的新对话（前厅 / 王座间，「想聊些什么」里多几条；画里的记忆走完以后才有）
BLUE_TALK = {
    "key": [L("……画里那个系蓝发带的孩子……", P),
            L("……不是我。", BLUE),
            L("可是——", P),
            L("……………", BLUE),
            L("……钥匙。……我弄丢过一次。", BLUE),
            L("……丢在哪里了？", P),
            L("……不记得了。……只记得，不该把门打开。", BLUE)],
    "fake": [L("……那个骑士说过。「那天晚上有两个殿下，其中一个是假的」。", BLUE),
             L("……画里的位置，我们两个，谁站上去都不对。", BLUE),
             L("……如果，假的那个是我呢。", BLUE),
             L("（粉色公主没说话，突然伸手戳了戳她的腰）", N),
             L("……！……哈、你干什么——", BLUE),
             L("你看，你会笑。假的才不会这么怕痒呢！", P, "happy"),
             L("……哈……哈哈……这、这算什么证据……", BLUE),
             L("（两个人闹成一团。闹完了，蓝色公主小声说了一句「……谢谢」）", N)],
    "song": [L("……那首摇篮曲。你能唱完吗。", BLUE),
             L("……只会第一段。第二段……怎么都想不起来。", P, "sad"),
             L("……我听过有人，从头唱到尾。", BLUE),
             L("是谁？", P),
             L("……不记得是谁了。……只记得，唱得很好听。", BLUE)],
    "queen": [L("……替我们收着的笑声。", BLUE),
              L("……什么时候，能还给她呢。", BLUE),
              L("……等我们找到「对的人」的时候吧。", P),
              L("……对的人。", BLUE)],
    "two": [L("……不管我们是谁。", BLUE),
            L("……现在，是两个人。", BLUE),
            L("（粉色公主什么也没说，只是拉住了她的手）", N),
            L("……嗯。两个人。", P, "happy")],
}

DIALOGUES = {
    "throne_portrait_enter": PORTRAIT_ENTER,
    "throne_portrait_after": _portrait_after(),
    "memory_cradles": MEMORY_CRADLES,
    "memory_easel": MEMORY_EASEL,
    "memory_bell": MEMORY_BELL,
    "memory_door": MEMORY_DOOR,
}
SIGNS = {
    "memory_pencil": [{"speaker": N, "text": "（铅笔线画出来的房间，只有轮廓，没有颜色。手伸过去，碰到的只是一张纸）"}],
}


# ================================================================ 婴儿房的下午（人偶们「哄睡」，挠痒；CG memory_nursery）
NURSERY = theater("画里的婴儿房：午睡时间", _duo("normal", "normal", d1={"kind": "trap:feather_curtain", "at": [-22, -8]},
                                              d2={"kind": "trap:feather_curtain", "at": [22, -8]}), [
    say(DOLL, "……午睡时间到了。……小殿下们，最不喜欢午睡了。", act=1),
    say(DOLL, "……所以。……要先，把她们，哄得笑累了。"),
    say(N, "（人偶们把两个人按在一张又大又软的绗缝垫子上，鞋子一只只被轻轻脱下来摆好，羽毛掸子在腰边试探地扫了一下）",
        [tk("d1", zone="waist", fx="feather", n=6, iv=0.2), _bt(6, 0.2, by="d2", zone="waist", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(P, "嘻……！等、等一下，我们不是小殿下——哈哈——", emotion="giggle"),
    say(BLUE, "……哈……解、解释没有用……它们不听……"),
    say(DOLL, "……陛下说过。……笑累了，就睡得香。", act=2),
    cg(say(N, "（软软的小刷子刷过脚心，羽毛掸子钻进腰侧和腋下，人偶们哼着那首摇篮曲，挠的节奏跟着曲子一拍一拍）",
           [tk("d1", zone="sole", fx="feather", n=14, iv=0.09), _bt(14, 0.09, by="d2", zone="sole", fx="feather"), pose("helpless_2"), _bp("helpless_2")], act=3)),
    say(P, "哈哈哈哈！这首歌——这首歌我知道——哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……哈哈……哈哈哈……不、不要跟着拍子……"),
    say(DOLL, palace10.NURSERY_DOLL),   # 第七轮：陛下改睡前故事的结局，讲到一半
    _burst_pink("（星光在婴儿房里炸开，吊铃上的星星一颗颗亮了起来……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，落在吊铃上，变成了一片片小雪花……）"),
    say(N, "（人偶们最后用羽毛在两人刚释放完、敏感得要命的脚心上，轻轻地拍了三下——像哄小孩那样）",
        [tk("d1", zone="sole", fx="feather", n=3, iv=0.3), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……这、这样根本睡不着啦……", emotion="helpless_1"),
    say(DOLL, "……嗯。……小殿下们，也总是这么说。", [pose("normal"), _bp("normal")]),
    say(BLUE, "……「总是」。……她们，以前真的在这里。"),
])

THEATERS = {"memory_nursery": NURSERY}


# ================================================================ 过场
def memory_enter():
    s = [
        line(N, "（徽章贴上画布的那一刻，画框里涌出了水彩的旋涡——粉的、淡紫的、金的、天蓝的）"),
        {"actions": [A("flash", time=0.6), A("sfx", sound="water_release", volume=-2.0), A("bg", img="memory_sucked")], "wait": 1.0},
        line(P, "……！抓紧我！", "surprise"),
        line(BLUE, "……嗯。……不会放开。", None),
        line(N, "（颜料卷着她们的裙摆和头发，像一阵很温柔的风。旋涡里，有一首很慢很慢的曲子）"),
        {"actions": [A("bg_clear"), A("flash", time=0.8)], "wait": 0.8},
    ]
    return {"name": "被吸进画里", "letterbox": True, "skippable": False, "steps": s}


def memory_in():
    s = [
        line(N, "（睁开眼睛。四周的一切都像是用水彩画出来的——颜色很淡，边缘晕开，像一场快要醒的梦）"),
        line(N, "（这是旧王宫。可是不旧——墙上的画框擦得发亮，窗外有阳光，远处有人在笑）"),
        line(P, "……这里……是那天之前的王宫？", "surprise"),
        line(BLUE, "……陛下的记忆。……她把这些，画了进来。", None),
        line(N, "（有些房间只有铅笔线画的轮廓，没有颜色。像是画的人，不愿意再想起来）"),
    ]
    return {"name": "画里的记忆", "letterbox": True, "skippable": True, "steps": s}


def memory_portrait():
    s = [
        {"actions": [A("bg", img="memory_portrait")], "wait": 0.8},
        line(N, "（画架上是一幅只画了一半的全家福。陛下坐在中间，脸是糊的。她的两边，是两个孩子的位置）"),
        line(N, "（一个孩子的脸，被一道颜料抹掉了。另一个位置，只有铅笔线）"),
        line(DOLL, "……陛下说，等两位小殿下都坐好了，才能画完。"),
        line(DOLL, "……请。……站到画里的位置上。"),
        line(N, "（粉色公主走到画前，指尖碰到了那张被抹掉的小脸——颜料在她指尖化开了，又慢慢地糊了回去）"),
        line(P, "……不对。……画里的不是我。", "sad"),
        line(N, "（蓝色公主站到另一个位置上。铅笔线晃了晃，没有变成颜色）"),
        line(BLUE, "……我也，不对。", None),
        line(DOLL, "……殿下，有两位。……可是那天晚上，回来的——", None),
        line(N, "（人偶的话没有说完。它的发条「咔」地停了一下，又重新转了起来，像是什么都没有发生）"),
        line(P, "……「两个殿下，其中一个是假的」。……骑士说过的话。", "sad"),
        line(BLUE, "……………", None),
        {"actions": [A("bg_clear")], "wait": 0.6},
    ]
    return {"name": "画了一半的全家福", "letterbox": True, "skippable": False, "steps": s}


def memory_sacrifice():
    s = [
        {"actions": [A("bg", img="memory_sacrifice"), A("sfx", sound="bell", volume=-6.0)], "wait": 1.0},
        line(N, "（那天晚上。王国里所有的笑声，都汇到了钟楼上）"),
        line(N, "（钟一下一下地敲。敲到第十三下的时候，笑声不再是笑声了——它变成了一阵会把一切都卷走的风）"),
        line(N, "（陛下站在钟下面。她没有跑）"),
        line(QUEEN, "……别怕。"),
        line(QUEEN, "……这些笑声，我先替你们收着。"),
        line(N, "（她张开双手。整座王宫的笑声，化成金色和粉色的光，一缕一缕地流进她身后的画布里）"),
        line(N, "（她的裙摆，从下往上，一点一点地变成了颜料）"),
        line(QUEEN, "……等你们长大了，再来拿。"),
        line(N, "（钟楼的楼梯下面，一个看不清的黑影，抱着两个裹在毯子里的孩子，走进了夜色里）"),
        line(QUEEN, "……要一直，一直笑着哦。"),
        line(N, "（她最后笑了一下。然后，就再也没有动过）"),
        line(DOLL, "……陛下，最后笑了一下。……然后，就再也没有动过。"),
        line(P, "…………", "sad"),
        line(N, "（粉色公主的脸上，不知道什么时候，全是眼泪）"),
        line(P, "……为什么……我会哭呢。……明明，一点都想不起来。", "sad"),
        line(BLUE, "……（轻轻地握住她的手）……我也是。", None),
        {"actions": [A("bg_clear")], "wait": 0.8},
    ]
    return {"name": "女王的牺牲", "letterbox": True, "skippable": False, "steps": s}


def memory_key():
    s = [
        {"actions": [A("bg", img="memory_key")], "wait": 1.2},
        line(N, "（门前的走廊上。陛下蹲下来，把一把小小的金钥匙，放进一个孩子的手心里）"),
        line(N, "（孩子背对着这边，看不清脸。只看得见她头发上，系着一条长长的蓝色发带）"),
        line(QUEEN, "……你是守门的那个孩子。"),
        line(QUEEN, "……这扇门，不可以打开。……答应我。"),
        line(N, "（孩子用力地点了点头）"),
        {"actions": [A("shake", who="blue", time=0.3)], "wait": 0.4},
        line(P, "……蓝色的发带。", "surprise"),
        line(BLUE, "……………", None),
        line(N, "（蓝色公主一句话也没说。她的手，下意识地按住了自己的发带）"),
        {"actions": [A("sfx", sound="ice_crack", volume=-4.0), A("shake", time=0.6), A("flash", time=0.4)], "wait": 0.8},
        line(N, "（画布，从中间裂开了一道缝。裂缝那边，陛下慢慢地站了起来，背对着她们）"),
        line(QUEEN, "……把门，关好。"),
        {"actions": [A("flash", time=1.0), A("sfx", sound="water_release", volume=-2.0), A("bg_clear")], "wait": 1.0},
    ]
    return {"name": "交钥匙的回忆", "letterbox": True, "skippable": False, "steps": s}


def memory_out():
    s = [
        line(N, "（回过神来，两个人又站在王座间里。画像静静地挂在墙上）"),
        line(N, "（画里陛下的脸，第一次干干净净的——很温柔的眉眼。可是，她闭着眼睛）"),
        line(P, "……她睡着了吗。", "sad"),
        line(BLUE, "……也许，是在等。", None),
        line(P, "……等什么？", None),
        line(BLUE, "……等我们，把门关好。", None),
        {"actions": [A("set_flag", flag="palace_chapter_done")], "wait": 0.0},   # 第五章从哪里接，之后再定（先留在王座间）
        {"actions": [A("chapter_end", title="第四章　旧王宫　完", subtitle="——两半徽章，一首摇篮曲，一扇要关好的门", next="stay")], "wait": 1.4},
    ]
    return {"name": "画里的记忆·完", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"palace_memory_enter": memory_enter, "palace_memory_in": memory_in, "memory_portrait": memory_portrait,
             "memory_sacrifice": memory_sacrifice, "memory_key": memory_key, "palace_memory_out": memory_out}
