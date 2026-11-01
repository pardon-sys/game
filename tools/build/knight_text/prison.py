"""骑士篇·夜探地牢的牢房里那些奇怪的东西（PrisonOddities 在 TaskSneak 开始时摆上；用户要求）：
  挠痒鼠（第一间牢房）：求她放它出来——放了就钻进鞋里挠脚心（小剧场 prison_rat）；不放就吱吱叫把守卫引来（call: prison_alarm）。
  被没收的痒痒手套（第二间牢房的墙上）：「公主你也不想守卫知道你偷溜进来吧」→ 借口挠一阵（prison_glove），挠完告诉她巡逻的空档。
  坏掉的审讯椅（审问室）：坐上去自己启动挠脚心（prison_chair）；不坐就看旁边的纸条（守卫换班时间）。
  马凳（审问室角落，和第六层卧室里那张一样）：经过时触发（prison_saddle，长）——她说绝对不会再坐了 → 守卫的脚步声 → 慌忙中又坐了上去 →
    被刷子挠、还得憋住不让守卫发现 → 魔力疲倦满了释放 → 释放后更敏感被接着挠 → 守卫以为闹鬼跑掉了。
DIALOGUES：对话文件 floor_06/after_prison_<id>；THEATERS：小剧场。
"""
from after_text.common import A, N, P, L

RAT, GLOVE, GUARD = "挠痒鼠", "痒痒手套", "保卫队员"


def _say(sp, text, actions=None, emotion=None, act=None, portrait=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if emotion:
        s["emotion"] = emotion
    if act:
        s["act"] = act
    if portrait:
        s["portrait"] = portrait
    return s


def _tk(by, zone="sole", fx="hand", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


def _theater(name, cast, body):
    steps = [{"act": 1, "actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5}] + body + \
            [{"actions": [A("voice", state=""), A("fade_out", time=0.6)], "wait": 0.7}]
    return {"name": name, "cast": cast, "steps": steps}


PRINCESS = {"kind": "princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"}

# ---------------------------------------------------------------- 挠痒鼠
RAT_THEATER = _theater("牢房里的挠痒鼠", {
    "princess": dict(PRINCESS),
    "rat": {"kind": "monster:rat", "at": [26, 12], "dir": "left"},
}, [
    _say(N, "（她踮着脚拉开牢门的插销。门刚开一条缝，挠痒鼠「嗖」地一下钻了出来）", act=1),
    _say(RAT, "吱吱！自由啦！谢谢公主！……作为谢礼——"),
    _say(P, "谢、谢礼就不用了！你快走吧，小声点——", emotion="surprise"),
    _say(N, "（挠痒鼠没走。它顺着她的裙摆爬下去，一头钻进了她的鞋里）", [_tk("rat", n=5, iv=0.25)], act=2),
    _say(P, "呀——！？出、出来！鞋里不行——！", [A("pose", who="princess", visual="giggle"), A("shake", who="princess", time=0.4)]),
    _say(RAT, "吱吱～关了三天，爪子都痒了～", [_tk("rat", n=10, iv=0.16)]),
    _say(N, "（小爪子在鞋子里扒拉着，把她的袜子扒到脚踝，尾巴尖在光着的脚心上扫来扫去）", [_tk("rat", n=12, iv=0.15)], act=3),
    _say(P, "噗……嗯嗯嗯……！（她死死捂住嘴，蹲在牢门边上发抖）", [A("pose", who="princess", visual="helpless_1")], emotion="helpless_1"),
    _say(N, "（爪子钻进了脚趾缝，一道一道地刨。走廊尽头，守卫的脚步声近了又远）", [_tk("rat", n=12, iv=0.14)]),
    _say(P, "……求、求你了……出来……守卫会听见的……！", emotion="helpless_2"),
    _say(RAT, "吱～好吧好吧。谢礼送完啦！", act=4),
    _say(N, "（挠痒鼠从鞋口钻出来，抖了抖胡子，一溜烟跑进了墙缝。她靠着牢门喘了好一会儿）", [A("pose", who="princess", visual="normal")]),
    _say(P, "……再、再也不随便放东西出来了……", emotion="sad"),
])

# ---------------------------------------------------------------- 痒痒手套
GLOVE_THEATER = _theater("被没收的痒痒手套", {
    "princess": dict(PRINCESS),
    "glove": {"kind": "monster:glove", "at": [-24, 2], "dir": "right"},
}, [
    _say(GLOVE, "嘿嘿……公主殿下，大半夜的，偷偷溜进保卫队的地牢？", act=1),
    _say(P, "嘘——！小、小声点！", emotion="surprise"),
    _say(GLOVE, "公主你也不想守卫知道你偷溜进来吧？……那就让我挠一会儿。被没收以后，我好久没活动手指了。"),
    _say(P, "这、这是威胁吧……！", emotion="angry"),
    _say(N, "（手套从栏杆缝里伸出来，一把握住她的脚踝。五根软软的手指爬上脚背，钻进鞋口）", [_tk("glove", n=6, iv=0.22)], act=2),
    _say(P, "唔……！说、说好一会儿的……！", [A("pose", who="princess", visual="giggle")]),
    _say(N, "（手套熟练地褪下她的鞋，五根手指在脚心上排开，像弹琴一样一根接一根地落下）", [_tk("glove", n=12, iv=0.15)], act=3),
    _say(P, "噗……哈……不、不能出声……嗯嗯嗯嗯……！", [A("pose", who="princess", visual="helpless_1")], emotion="helpless_1"),
    _say(GLOVE, "嘘——守卫听见可就不好了哦～", [_tk("glove", n=12, iv=0.14)]),
    _say(P, "那、那你就停下啊……！哈……哈……", emotion="helpless_2"),
    _say(N, "（手套心满意足地松开手，把鞋子塞回她手里）", [A("pose", who="princess", visual="normal")], act=4),
    _say(GLOVE, "好啦，作为封口费的回礼——南边走廊那个守卫，走到东头会站一会儿。趁他背过身的时候过去。"),
    _say(P, "……谢、谢谢。……虽然一点都不想谢你。", emotion="angry"),
])

# ---------------------------------------------------------------- 坏掉的审讯椅
CHAIR_THEATER = _theater("坏掉的审讯椅", {
    "princess": dict(PRINCESS),
    "chair": {"kind": "trap:cushion", "at": [0, 10]},
}, [
    _say(N, "（她小心地在椅子上坐下来——椅子「咔哒」响了一声）", act=1),
    _say(P, "……坏掉的，对吧？标签上写着「坏掉了」。", emotion="surprise"),
    _say(N, "（扶手上的皮带「啪」地扣住了她的手腕，脚下弹出一对脚枷，把她的脚踝扣了进去）", [A("shake", who="princess", time=0.4)], act=2),
    _say(P, "一、一点都没坏啊——！"),
    _say(N, "（脚枷的内侧伸出一圈软刷，把鞋子顶掉，贴着光着的脚心转了起来）", [_tk("chair", fx="lines", n=10, iv=0.18), A("pose", who="princess", visual="giggle")], act=3),
    _say(P, "嘻嘻……！刷、刷子……！停下……我只是坐一下而已……！", emotion="giggle"),
    _say(N, "（刷子越转越快，从脚跟刷到脚尖，又在脚趾缝里一下一下地拨）", [_tk("chair", fx="lines", n=14, iv=0.14), A("pose", who="princess", visual="helpless_1")]),
    _say(P, "哈哈……哈……不、不行……会被听见的……嗯嗯嗯……！", emotion="helpless_1"),
    _say(N, "（「咔」——椅子里的齿轮卡住了。刷子慢慢停了下来，皮带和脚枷也松开了）", [A("pose", who="princess", visual="normal")], act=4),
    _say(P, "……它是「坏掉」的意思……原来是停不下来的时候才会坏……", emotion="sad"),
])

# ---------------------------------------------------------------- 马凳（长，含一次魔力释放）
SADDLE_THEATER = _theater("审问室角落的马凳", {
    "princess": dict(PRINCESS),
    "saddle": {"kind": "trap:saddle_bench", "at": [0, 12]},
    "guard": {"kind": "npc:guard", "at": [70, 6], "dir": "left", "hidden": True},
}, [
    _say(N, "（审问室的角落里，立着一张她见过的凳子——窄窄的凳面，两侧伸出一排软刷）", act=1),
    _say(P, "……这个。", emotion="surprise"),
    _say(P, "第六层的卧室里，也有一张一模一样的。……那次我坐上去，整整笑了一刻钟。"),
    _say(P, "绝对、绝对不会再坐了。看都不看。走了走了。", emotion="angry"),
    _say(N, "（她刚转过身——走廊里传来了脚步声。哒、哒、哒，越来越近）", [A("sfx", sound="step", volume=-4.0)]),
    _say(P, "守、守卫！？躲、躲哪里——！", [A("shake", who="princess", time=0.4)], emotion="surprise"),
    _say(N, "（审问室里没有木箱。她慌慌张张往后退，脚后跟一绊——整个人一屁股坐在了马凳上）", [A("move", who="princess", to=[0, 6], time=0.3)], act=2),
    _say(P, "……啊。", emotion="surprise"),
    _say(N, "（「咔哒」。凳子两侧的扣环合上，扣住了她的脚踝。两排软刷慢慢转了起来，先把鞋子顶了下去）", [_tk("saddle", fx="lines", n=6, iv=0.25)]),
    _say(GUARD, "……嗯？审问室里有动静？", [A("enter", who="guard", to=[44, 6], time=0.8)]),
    _say(N, "（守卫提着灯站在门口，往里照了照。她屏住呼吸，一动也不敢动——可是刷子不管这些）", [_tk("saddle", fx="lines", n=10, iv=0.18), A("pose", who="princess", visual="giggle")]),
    _say(P, "（……不、不能笑……不能笑……脚心……刷子在刷脚心……！）", emotion="giggle"),
    _say(N, "（软刷贴着光着的脚心一圈一圈地转，刷毛尖钻进脚趾缝里拨弄。她咬住嘴唇，十根脚趾蜷得紧紧的）", [_tk("saddle", fx="lines", n=12, iv=0.15)], act=3),
    _say(GUARD, "……奇怪。明明听见有人在哼哼。"),
    _say(P, "（……哼、哼哼是什么……我没有……嗯嗯嗯……！）", [A("pose", who="princess", visual="helpless_1")], emotion="helpless_1"),
    _say(N, "（刷子换了个方向，从脚跟一路刷到脚尖，再从脚尖刷回脚跟。憋住的笑声在身体里越积越多，魔力疲倦一点点涨满）", [_tk("saddle", fx="lines", n=14, iv=0.13)]),
    _say(GUARD, "……我再走近点看看。", [A("move", who="guard", to=[34, 6], time=0.6)]),
    _say(P, "（不行了……要、要满出来了……！）", emotion="helpless_2"),
    _say(N, "（星光从她身上炸开，扣环被冲得弹开，马凳的刷子全炸成了一团毛球，守卫手里的灯「啪」地灭了）",
         [A("flash", time=0.8), A("sfx", sound="star_burst", volume=-1.0), A("sfx", sound="water_release", volume=-2.0),
          A("shake", who="princess", time=0.5), A("bubble", who="princess", kind="surprise"), A("move", who="guard", to=[60, 4], time=0.25)], act="burst"),
    _say(P, "（哈啊……魔力……全放出去了……身体轻飘飘的……好舒服……）", emotion="happy"),
    _say(GUARD, "什、什么东西发光了！？……灯、灯灭了……！", [A("shake", who="guard", time=0.4)]),
    _say(N, "（可马凳还没有坏。炸成毛球的刷子抖了抖，又慢慢转了起来——这一次，贴上的是刚放完魔力、敏感得发烫的脚心）",
         [_tk("saddle", fx="feather", n=10, iv=0.16), A("pose", who="princess", visual="helpless_2")], act=4),
    _say(P, "（呀……！放、放完以后……轻轻刷一下……就……比刚才痒好几倍……！）", emotion="helpless_2"),
    _say(N, "（毛茸茸的刷子在脚心正中央打着圈，又钻进每一道趾缝里轻轻地挠。她整个人缩在凳子上抖，眼泪都憋出来了）", [_tk("saddle", fx="feather", n=14, iv=0.13)]),
    _say(P, "……噗……哈……哈哈……不、不行……！", [A("bubble", who="princess", kind="laugh")]),
    _say(GUARD, "……黑、黑暗里有人在笑……！？地牢里……闹、闹鬼了——！", [A("move", who="guard", to=[90, 4], time=0.5)]),
    _say(N, "（守卫丢下灯，头也不回地跑了。刷子又转了好一会儿，才「咔」地停住，扣环也松开了）", [A("pose", who="princess", visual="helpless_1")]),
    _say(P, "……哈……哈……我、我说过……绝对不会再坐的……", emotion="helpless_1"),
    _say(P, "……不过……守卫跑掉了。……就当是……作战成功吧……", emotion="sad"),
])

THEATERS = {"prison_rat": RAT_THEATER, "prison_glove": GLOVE_THEATER, "prison_chair": CHAIR_THEATER, "prison_saddle": SADDLE_THEATER}


def _file(npc_id, name, nodes):
    d = {"name": name, "entries": [{"node": "default"}], "nodes": nodes}
    if npc_id:
        d["npc"] = npc_id
    return d


DIALOGUES = {
    "after_prison_rat": _file("", RAT, {
        "default": {"lines": [L("（牢房里关着一只挠痒鼠。它扒着栏杆，眼睛亮晶晶地看着她）", N),
                              L("吱吱……公主，放我出去吧……我就关了三天，什么坏事都没干……", RAT)],
                    "prompt": "放它出来？", "choices": [
                        {"text": "……好吧，放你出来", "next": "free"},
                        {"text": "不行", "next": "refuse"}]},
        "free": {"lines": [L("……就这一次哦。小声点。", P)], "theater": "prison_rat"},
        "refuse": {"lines": [L("……不行。你出来一定会捣乱。", P), L("吱——！！吱吱吱吱——！！（它扯着嗓子尖叫起来）", RAT),
                             L("哇、哇啊！别叫——守卫要过来了！", P, "surprise")], "set": {"call": "prison_alarm"}},
    }),
    "after_prison_glove": _file("", GLOVE, {
        "default": {"lines": [L("（墙上挂着一只被没收的痒痒手套，贴着标签「没收品·勿碰」。……它的手指动了一下）", N)],
                    "theater": "prison_glove", "next": "after"},
        "after": {"lines": [L("（南边走廊的守卫走到东头会停一会儿……记住了）", N)]},
    }),
    "after_prison_chair": _file("", "审讯椅", {
        "default": {"lines": [L("（一把带皮带和脚枷的椅子，椅背上贴着一张纸：「坏掉了，勿用」）", N)],
                    "prompt": "坐上去试试？", "choices": [
                        {"text": "……坏掉的，坐一下应该没事吧", "next": "sit"},
                        {"text": "不坐，看看旁边的纸条", "next": "note"}]},
        "sit": {"lines": [L("……就坐一下。腿好酸。", P)], "theater": "prison_chair"},
        "note": {"lines": [L("（纸条上歪歪扭扭地写着：「换班——南走廊、东竖走廊，敲钟以后两个人一起去吃夜宵」）", N),
                           L("……敲钟以后，有一阵子没人。", P)]},
    }),
}
