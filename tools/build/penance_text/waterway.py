"""反省篇第三章·废弃水道（floor_06_waterway，WaterwayDirector / SluiceKeeper）和蓝色公主视角的过场（blue_pov，MeetExit 先放它）。
两人同行；粉色公主还穿着鼠鼠装（挠脚鼠住在短裤里），蓝色公主穿着千手痒痒裤。章末：水闸守门人（三个阀门）。
只写痒、笑、释放后的舒服；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, PRINCESS, RAT, cg, line, pose, release, say, theater, tk

HOST = "篝火派对的主人"
GUARD = "保卫队员"
KEEPER = "水闸守门人"

# 玩法里的短台词（data/after/waterway.json，WaterwayDirector / SluiceKeeper 读）
TEXT = {
    "water_high": ["水、水涨上来了！浮木浮起来了！", "……水位，高了。木头能踩了。"],
    "water_low": ["水退下去了！格栅那边露出来了！", "……水位，低了。下面的路，能走了。"],
    "log": ["呀！木头翻了——水草扫到脚底了！", "……木头，在转……脚底……", "噫！下面全是水草！"],
    "trapped": ["泡、泡泡里面……好痒！快戳破它！", "……泡泡。……戳。快。", "被裹住了——脚底下全是小泡泡！"],
    "valve": ["关掉一个了！还有两个！", "……第二个。还剩一个。", "最后一个——关上了！"],
    "flood": ["它在放水！快站到石头上去！", "……水。上石头。"],
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


DUO = {
    "princess": dict(PRINCESS, at=[-14, 8], visual="helpless_1", anim="helpless", dir="right"),
    "blue": {"kind": "npc:blue_princess", "at": [14, 8], "visual": "helpless_1", "anim": "helpless", "dir": "left"},
    "pants": {"kind": "trap:hand", "at": [20, 10]},
    "rat": {"kind": "monster:rat", "at": [-26, 12], "dir": "right"},
}

# ---------------------------------------------------------------- 两个都倒下（关卡里）
DOWN_FIRST = theater("水道里双双笑倒", dict(DUO, fish={"kind": "monster:bubble_fish", "at": [0, 14], "dir": "up"}), [
    say(N, "（两个人一起笑倒在浅水里。小鱼群一下子围了上来，绕着四只脚踝打转）", act=1),
    say(P, "哈……哈哈……起、起不来了……", emotion="helpless_1"),
    say(BLUE, "……我、也……"),
    say(N, "（小鱼啃着粉色公主的脚趾，千手痒痒裤趁机揉着蓝色公主的大腿根——谁也腾不出手去扶谁）",
        [tk("fish", fx="lines", n=10, iv=0.14), _bt(10, 0.14)], act=2),
    say(RAT, "（从短裤里探出头）吱吱，小鱼也来抢生意了？不行不行——", [tk("rat", zone="thigh", fx="hand", n=8, iv=0.14), pose("helpless_2"), _bp("helpless_2")]),
    say(P, "你、你别凑热闹——哈哈哈！", emotion="helpless_2"),
    say(BLUE, "……哈、哈哈……水……好凉……可是……"),
    _burst_pink("（星光在水面上炸开，小鱼一哄而散……哈啊……放出去了……）"),
    say(N, "（等两个人终于能坐起来，已经被水冲回了刚才那个路口）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(BLUE, "……刚才那里。……再走一次。"),
    say(P, "……嗯。这次一个笑倒了，另一个要赶快去扶。", emotion="sad"),
    say(BLUE, "……按住 E。……我记住了。"),
])

DOWN_AGAIN = theater("又双双笑倒了", dict(DUO), [
    say(N, "（又一起笑倒了。挠脚鼠和千手痒痒裤像是商量好了似的，趁机各挠了一通）", [tk("rat", zone="sole", fx="lines", n=8, iv=0.14), _bt(8, 0.14)], act=1),
    say(P, "哈哈……你们……能不能……分个时候……！", emotion="helpless_2"),
    say(BLUE, "……哈……哈……", [_bp("helpless_2")]),
    _burst_pink("（星光一闪……哈啊……又放出去了……）"),
    say(N, "（两个人互相扶着站起来，回到了刚才的路口）", [pose("helpless_1"), _bp("helpless_1")], act=4),
    say(BLUE, "……再来。"),
])

# ---------------------------------------------------------------- 水闸守门人：输了（四幕 + CG）
KEEPER_FAIL = theater("水闸守门人：笑声水闸", dict(DUO, keeper={"kind": "trap:wheel", "at": [0, -6]}, fish={"kind": "monster:bubble_fish", "at": [6, 14], "dir": "up"}), [
    say(N, "（守门人的刷子臂「咔哒」一声，把两个人一左一右揽了过去，按在了闸门前的浅水里）", act=1),
    say(KEEPER, "（齿轮咯吱咯吱地转）……检查……闯入者……清洗……程序……开始……"),
    say(P, "清、清洗！？我们不脏——！", emotion="surprise"),
    say(BLUE, "……它听不懂。"),
    say(N, "（闸门底下的格栅打开了。温温的水漫上来，刚好没过脚踝）", [A("sfx", sound="water_release", volume=-4.0)]),
    say(P, "……还好，只是水……", emotion="sad"),
    say(N, "（……水里冒出了一串串小泡泡。泡泡贴着脚底往上浮，一颗一颗在脚心上破掉）", [tk("keeper", fx="lines", n=8, iv=0.18), pose("giggle"), _bp("giggle")], act=2),
    say(P, "嘻……嘻嘻……泡泡……！", emotion="giggle"),
    say(BLUE, "……忍、得住……"),
    say(N, "（刷子臂慢慢放了下来。一把软刷贴上粉色公主的脚心，另一把贴上蓝色公主的大腿外侧，开始一下一下地「清洗」）",
        [tk("keeper", fx="lines", n=10, iv=0.16), _bt(10, 0.16, by="keeper", fx="feather")]),
    say(P, "哈、哈哈……这不是洗……这是挠……！", emotion="giggle"),
    say(BLUE, "……刷……刷子……往里面……来了……", [_bp("helpless_1")]),
    say(N, "（千手痒痒裤也被刷子惊动了，裤子里的手跟着刷子的节奏一起揉——蓝色公主的膝盖一下子并紧了）", [_bt(12, 0.13), _bt(6, 0.2, zone="butt", fx="pinch")], act=3),
    cg(say(BLUE, "……哈……哈哈……两、两边……一起……不行……", [_bp("helpless_2")])),
    say(N, "（粉色公主那边，小鱼群从格栅里涌了出来，绕着脚趾啃——挠脚鼠在短裤里听见了，吱吱叫着不甘示弱地从腿根窜到脚底）",
        [tk("fish", fx="lines", n=12, iv=0.12), tk("rat", zone="thigh", fx="hand", n=8, iv=0.14), pose("helpless_2")]),
    say(P, "哈哈哈哈！小鱼……老鼠……刷子……全都来了——！", emotion="helpless_2"),
    say(RAT, "吱吱！这里是我的地盘！小鱼一边去！"),
    say(N, "（两个人笑得东倒西歪，肩膀撞在一起，谁也扶不住谁。水声、泡泡声、笑声在闸门前一圈圈回荡）",
        [tk("keeper", fx="lines", n=14, iv=0.1), _bt(14, 0.1, by="keeper", fx="feather")]),
    say(BLUE, "……哈哈……你……笑得……太吵了……"),
    say(P, "你、你才是……哈哈哈……你今天笑了好多……！", emotion="helpless_2"),
    say(KEEPER, "……清洗度……百分之五十……继续……"),
    say(N, "（刷子的速度又快了一档。魔力在两个人身体里一起往上涌——）", [tk("keeper", fx="lines", n=12, iv=0.1), _bt(12, 0.1)]),
    _burst_blue("……哈……哈哈……不、不行了……（冰晶炸开，水面一下子结了一层薄冰……）……身体……轻飘飘的……"),
    _burst_pink("（星光跟着炸开，薄冰碎成了一闪一闪的冰屑……哈啊……放出去了……好舒服……）"),
    say(N, "（冰屑落进水里，很快又化开了。刷子臂停了一下——然后又慢慢地贴了上来，贴上两个人刚释放完、敏感得发烫的身体）",
        [tk("keeper", fx="feather", n=8, iv=0.16), _bt(8, 0.16, by="keeper", fx="feather"), pose("helpless_2"), _bp("helpless_2")], act=4),
    say(P, "呀……！放完以后……轻轻一下就……哈哈哈……！", emotion="helpless_2"),
    say(BLUE, "……现、现在……别碰……哈……哈哈……"),
    say(N, "（一只小鱼在粉色公主的小脚趾缝里轻轻啃了一口，裤子里的一只手在蓝色公主的腿根上轻轻点了一下——两个人同时弹了起来）",
        [tk("fish", fx="lines", n=6, iv=0.18), _bt(6, 0.18), A("shake", who="princess", time=0.4), A("shake", who="blue", time=0.4)]),
    say(KEEPER, "……清洗度……百分之百……程序……结束……放行……回到……入口……"),
    say(N, "（刷子臂松开了，闸门前的水也慢慢退了下去。两个人背靠着背坐在湿漉漉的地上，喘了好半天）", [pose("helpless_1"), _bp("helpless_1")]),
    say(BLUE, "……阀门。……三个。……这次分开去关。"),
    say(P, "……嗯。刷子扫过来的时候冲刺，放水的时候上石头……我记住了。", emotion="sad"),
    say(RAT, "吱……我也记住了。下次那群小鱼来，我先挠它们。"),
])

# ---------------------------------------------------------------- 水闸守门人：赢了（被困住）
KEEPER_WIN = theater("闸门落下", dict(DUO, princess=dict(PRINCESS, at=[-14, 8], visual="normal", dir="right"),
                                    blue={"kind": "npc:blue_princess", "at": [14, 8], "visual": "normal", "anim": "idle", "dir": "left"}), [
    say(N, "（最后一个阀门关上，守门人的齿轮发出一声长长的叹息，停了下来）", act=1),
    say(KEEPER, "……阀门……全部……关闭……守门……结束……"),
    say(P, "……赢、赢了？", emotion="happy"),
    say(BLUE, "……嗯。"),
    say(N, "（「轰」——身后的闸门突然落了下来，把来路堵得严严实实。脚下的水开始慢慢往上涨）", [A("shake", who="princess", time=0.5), A("sfx", sound="rumble", volume=-2.0)], act=2),
    say(P, "诶！？堵、堵住了！？水在涨！", emotion="surprise"),
    say(BLUE, "……出口。……在上面。"),
    say(N, "（闸门上方很高的地方，有一道窄窄的缝，透出一点点光。光里飘着一股很旧很旧的、像是花香的味道）"),
    say(RAT, "（从短裤里探出头）吱吱！那上面！我闻到了，是很老很老的石头的味道——还有地毯！"),
    say(P, "地毯？……这底下哪来的地毯？", emotion="question"),
    say(N, "（水已经没过了膝盖。蓝色公主看了看那道缝，又看了看粉色公主）", act=3),
    say(BLUE, "……踩我。……上去。"),
    say(P, "诶？踩、踩你？", emotion="surprise"),
    say(BLUE, "……快。"),
    say(N, "（粉色公主踩着蓝色公主的肩膀往上爬。鼠爪鞋的肉垫软软地踩在肩上，挠脚鼠在短裤里一激动，又窜了一下）",
        [tk("rat", zone="thigh", fx="hand", n=6, iv=0.15), pose("giggle"), _bp("giggle")]),
    say(P, "噫——！别、别在这时候——会掉下去的！", emotion="giggle"),
    say(BLUE, "……肩、肩膀……肉垫……好痒……别乱动……"),
    say(N, "（千手痒痒裤听见「痒」字，也跟着揉了一下。底下的人一抖，上面的人一晃——两个人笑着，一点一点地挪到了缝口）", [_bt(6, 0.15)]),
    say(P, "……抓、抓到了！来，手给我！", emotion="happy", act=4),
    say(N, "（粉色公主趴在缝口，把蓝色公主拉了上来。两个人一起滚进了缝的另一头——）", [pose("normal"), _bp("normal")]),
    say(N, "（……是一条长长的走廊。褪了色的红地毯一直铺到看不见的地方，墙上挂着落满灰的金色画框，画里的人都没有脸）"),
    say(BLUE, "……这里是。"),
    say(P, "……旧王宫。", emotion="surprise"),
])

THEATERS = {"waterway_down_first": DOWN_FIRST, "waterway_down": DOWN_AGAIN, "keeper_fail": KEEPER_FAIL, "keeper_win": KEEPER_WIN}


def waterway_in():
    s = [
        {"actions": [A("camera", to=[5, 5], zoom=1.0, time=0.4)], "wait": 0.4},
        line(N, "（废弃水道比想象中的宽。墙上嵌着生锈的狮子头出水口，远处传来哗哗的水声）"),
        line(BLUE, "……这里，以前是王宫的水道。派对主人说的。"),
        line(P, "王宫……就在前面？", "surprise"),
        line(RAT, "（从短裤里探出头）吱吱。水道的机关都还活着。狮子头会吐泡泡，轮盘一转水就涨落，浅水里有小鱼，还有黏糊糊的黑泥小人。"),
        line(P, "……你怎么什么都知道。", "question"),
        line(RAT, "我是本地鼠嘛。"),
        line(BLUE, "……两个人。……一个笑倒了，另一个去扶。"),
        line(P, "嗯！按 C 可以换人，我们互相照应！", "happy"),
        {"actions": [A("camera", reset=True, time=0.4),
                     A("notify", text="穿过废弃水道（按 C 换人；被泡泡裹住让搭档戳破；两个人一起站轮盘转得快）")], "wait": 0.4},
    ]
    return {"name": "废弃水道", "letterbox": True, "skippable": True, "steps": s}


def keeper_intro():
    s = [
        {"actions": [A("camera", to=[99, 6], zoom=0.9, time=0.6)], "wait": 0.6},
        line(N, "（场地尽头，立着一扇巨大的生锈水闸。闸门上的狮子头「咔」地亮起了两只眼睛）"),
        line(KEEPER, "……闯入者……确认……守门……程序……启动……"),
        line(N, "（闸门两侧伸出了两只长长的刷子臂，地上三个红色的阀门同时转了起来，水开始哗哗地往场地里涌）"),
        line(P, "那、那三个阀门！把它们关掉，它就停了吧！", "surprise"),
        line(BLUE, "……刷子扫过来，冲刺跳过去。放水的时候，上石头。"),
        line(RAT, "吱吱！还有泡泡和黑泥！小心！"),
        {"actions": [A("camera", reset=True, time=0.4), A("notify", text="关掉三个阀门（站上去；两个人一起关得快）")], "wait": 0.4},
    ]
    return {"name": "水闸守门人", "letterbox": True, "skippable": True, "steps": s}


def waterway_end():
    s = [
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("chapter_end", title="第三章　废弃水道　完", subtitle="——褪色的红地毯，一直铺到看不见的地方", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "旧王宫", "letterbox": True, "skippable": False, "steps": s}


def blue_pov():
    """蓝色公主视角（纯过场）：粉色公主被关起来以后，她去问派对主人、再溜进营地拿回鞋。背景大图 blue_pov_host / blue_pov_shoes。"""
    s = [
        {"actions": [A("bg", img="blue_pov_host")], "wait": 0.6},
        line(N, "（——时间往回倒一点。粉色公主被关进反省室的那天夜里）"),
        line(N, "（蓝色公主在篝火边站了很久，才走到派对主人面前）"),
        line(BLUE, "……反省室。……有没有，别的出口。"),
        line(HOST, "哟，难得你主动来找我。……想救她？"),
        line(BLUE, "……", None),
        line(HOST, "哈哈，不说话就是想。……我小时候在地牢里躲过猫猫，那里的墙缝里有一条老鼠洞，一直通到旧水道。"),
        line(HOST, "（她在一张纸上画了几笔）喏，从牢房墙缝进去，出口在这里——水道的尽头。你去那里等，就能等到她。"),
        line(BLUE, "……谢谢。"),
        line(HOST, "别谢我。……对了，她的鞋被队长收走了，放在营地的储物间里。光着脚走水道，可是会被小鱼啃的哦～"),
        {"actions": [A("bg", img="blue_pov_shoes")], "wait": 0.6},
        line(N, "（营地的储物间。月光从小窗照进来，架子上全是贴着纸条的「没收品」）"),
        line(N, "（蓝色公主踮着脚，一个箱子一个箱子地找。……找到了。一双粉色的小鞋，鞋带上还系着蝴蝶结）"),
        line(BLUE, "……", None),
        line(N, "（就在这时候，千手痒痒裤动了一下。裤子里的手像是闻到了什么好玩的事，慢慢地揉起了她的大腿）"),
        line(BLUE, "（……别……现在别……）"),
        line(GUARD, "（门外）……嗯？储物间里有动静？……啊——哈——（打了个大大的呵欠）……老鼠吧。"),
        line(N, "（她咬着嘴唇，憋得脸都红了，一动不动地等着脚步声走远——然后抱着鞋，一溜烟跑出了营地）"),
        line(BLUE, "……等我。"),
        {"actions": [A("bg_clear")], "wait": 0.6},
    ]
    return {"name": "蓝色公主的那一夜", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"waterway_in": waterway_in, "keeper_intro": keeper_intro, "waterway_end": waterway_end, "blue_pov": blue_pov}
