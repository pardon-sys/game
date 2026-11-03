"""反省篇第三章·开场：废弃水道的出口（floor_06_waterway_exit，等距 drain_water；MeetExit 依次放 meet_in → 小剧场 meet_pants → meet_out）。
粉色公主从鼠洞的竖井爬出来，蓝色公主提着她的鞋在出口等着。两个人一见面就互相调侃裤子：
蓝色公主笑粉色公主的鼠鼠短裤 → 粉色公主回嘴提到蓝色公主的千手痒痒裤 → 裤子听见了，手开始揉她的大腿 →
粉色公主短裤里的挠脚鼠听见笑声，不甘示弱，也挠起了粉色公主。两个人各释放一次。只写痒、笑、释放后的舒服；两位都是成年人。
"""
from .common import A, BLUE, N, P, PRINCESS, RAT, line, pose, release, say, theater, tk

B = "MtBlue"


def _pants(n=8, iv=0.18, zone="thigh", fx="hand"):
    return A("tickle", who="blue", by="pants", zone=zone, fx=fx, repeat=n, interval=iv)


def _bpose(v):
    return A("pose", who="blue", visual=v)


def _burst_blue(text):
    acts = [A("flash", time=0.5), A("sfx", sound="ice_crack", volume=-2.0), A("sfx", sound="water_release", volume=-2.0),
            A("shake", who="blue", time=0.4), A("voice", state="laugh")]
    return dict(say(BLUE, text, acts), act="burst", wait=1.0)


def _burst_pink(text):
    return dict(say(P, text, release()), act="burst", wait=1.0)


MEET = theater("汇合：两条奇怪的裤子", {
    "princess": dict(PRINCESS, at=[-14, 8], visual="normal", dir="right"),
    "blue": {"kind": "npc:blue_princess", "at": [14, 8], "visual": "normal", "anim": "idle", "dir": "left"},
    "rat": {"kind": "monster:rat", "at": [-26, 12], "dir": "right"},
    "pants": {"kind": "trap:hand", "at": [20, 10]},
}, [
    say(N, "（水道出口的灯下，蓝色公主手里提着一双粉色的小鞋，一动不动地站着）", act=1),
    say(P, "……你！你怎么在这里！？", emotion="surprise"),
    say(BLUE, "……派对主人说，地牢的鼠洞，通到这里。……等了很久。"),
    say(P, "……你一直在等我？", emotion="happy"),
    say(BLUE, "……", [A("face", who="blue", dir="down")]),
    say(N, "（蓝色公主的目光慢慢往下移——落在了那条灰色的毛绒短裤上，又落在了后面那条一甩一甩的粉色尾巴上）"),
    say(BLUE, "……那是什么。"),
    say(P, "……裤、裤子。", emotion="shy"),
    say(BLUE, "……有尾巴。"),
    say(BLUE, "……还有鞋。……有耳朵。"),
    say(BLUE, "……很合适。……噗。", [_bpose("giggle")]),
    say(P, "你、你笑了！？你刚才是不是笑了！？", emotion="angry"),
    say(BLUE, "……没有。", [_bpose("normal")]),
    say(P, "你还好意思说我！你自己那条裤子呢！那条紫色的、紧紧的、会动的、里面有一千只手的——", emotion="angry", act=2),
    say(N, "（话音刚落，蓝色公主腿上那条紫色的千手痒痒裤，「蠕」地动了一下）", [_pants(4, 0.25)]),
    say(BLUE, "……别、别提它。……它听得见。"),
    say(P, "……诶？听、听得见？", emotion="surprise"),
    say(N, "（像是被叫到了名字，裤子里的手一只接一只地醒了过来。先是轻轻地揉了揉大腿外侧，又慢慢地往里面爬）", [_pants(8, 0.18), _bpose("giggle")]),
    say(BLUE, "……嗯……没、没事……"),
    say(N, "（「没事」的时候，十几只手正一圈一圈地揉着她的大腿根。她的膝盖并得紧紧的，肩膀一抖一抖）", [_pants(10, 0.15), _pants(6, 0.2, "butt", "pinch")]),
    say(P, "……嘿嘿嘿。你看你看，你的裤子也很「合适」嘛～", emotion="happy"),
    say(BLUE, "……不准……看……", [_bpose("helpless_1")]),
    say(P, "千手裤～千手裤～再揉一揉～", emotion="happy"),
    say(N, "（裤子听话得要命。手们从大腿根一路揉到屁股，又从屁股一路揉回大腿根）", [_pants(12, 0.12), _pants(8, 0.15, "butt", "pinch")]),
    say(BLUE, "……哈……你……你别……唱……哈、哈哈……"),
    say(N, "（蓝色公主难得地笑出了声。笑声在水道里回荡——然后，粉色公主的短裤里，有什么东西竖起了耳朵）", act=3),
    say(RAT, "（从短裤里探出头）……吱！？笑声！？"),
    say(RAT, "几只手就想在我面前抢风头？吱吱！挠脚鼠一族，可不能输给一条裤子！"),
    say(P, "等、等等！你要比赛就去挠她啊！为什么是——呀！", [tk("rat", zone="thigh", fx="hand", n=8, iv=0.14), pose("giggle")], emotion="giggle"),
    say(N, "（挠脚鼠「嗖」地从大腿根窜下去，钻进鼠爪鞋，在脚心上转起了圈）", [tk("rat", zone="sole", fx="lines", n=10, iv=0.13), pose("helpless_1")]),
    say(P, "哈哈哈！脚心！刚爬完竖井……还没缓过来……！", emotion="helpless_1"),
    say(BLUE, "……哈、哈哈……你……你也……", [_pants(10, 0.13)]),
    say(N, "（一个大腿根，一个脚心。一条裤子，一只老鼠。两个人笑着靠在一起，谁也扶不住谁）",
        [tk("rat", zone="sole", fx="lines", n=12, iv=0.11), _pants(12, 0.11), pose("helpless_2"), _bpose("helpless_2")]),
    say(RAT, "吱吱！比比看谁的笑声大！"),
    say(N, "（千手痒痒裤像是听懂了，手们也一下子勤快起来——两边越比越凶）", [_pants(14, 0.1), _pants(8, 0.12, "butt", "pinch"), tk("rat", zone="sole", fx="lines", n=14, iv=0.1)]),
    _burst_blue("……哈……哈哈……不、不行了……（冰晶「叮」地炸开，雪花落了一地……）……身、身体……轻飘飘的……"),
    _burst_pink("（星光跟着炸开，和雪花混在一起……哈啊……放出去了……好舒服……）"),
    say(N, "（星光和雪花慢慢落下来。可是裤子里的手、短裤里的老鼠，一个都没有停——它们贴上的，是两个人刚释放完、敏感得发烫的身体）",
        [_pants(8, 0.15), tk("rat", zone="sole", fx="feather", n=8, iv=0.15), pose("helpless_2"), _bpose("helpless_2")], act=4),
    say(BLUE, "……现、现在……一下都……别……哈哈……"),
    say(P, "呀……！轻一点……一下就……哈哈哈……！", emotion="helpless_2"),
    say(N, "（一只手在蓝色公主的大腿内侧轻轻点了一下，挠脚鼠在粉色公主的小脚趾缝里舔了一口——两个人同时弹了起来，又同时笑倒在对方身上）",
        [_pants(6, 0.18), tk("rat", zone="sole", fx="lines", n=6, iv=0.18), A("shake", who="princess", time=0.4), A("shake", who="blue", time=0.4)]),
    say(RAT, "吱……平、平手。……今天就算平手。", [pose("helpless_1"), _bpose("helpless_1")]),
    say(N, "（老鼠钻回了短裤里，裤子里的手也一只一只安静下来。两个人背靠着背坐在水道边，喘了好半天）"),
    say(BLUE, "……你笑起来……还是那么吵。"),
    say(P, "……你才是。笑那么小声，憋得脸都红了。", emotion="shy"),
    say(BLUE, "……", [_bpose("normal")]),
    say(BLUE, "……鞋。给你带来了。"),
    say(RAT, "（探出头）吱。鞋子先收着，出了水道才能换回来哦。"),
    say(BLUE, "……那，我替你拿着。"),
    say(P, "……嗯。谢谢你。", emotion="happy"),
])

THEATERS = {"meet_pants": MEET}


def meet_in():
    s = [
        {"actions": [A("spawn", id=B, kind="npc:blue_princess", at=[14, 6], dir="left"), A("camera", to=[11, 7], zoom=1.0, time=0.5)], "wait": 0.5},
        line(N, "（竖井的出口外，是一条很宽的旧水道。哗哗的水声里，混着一点点灯光）"),
        line(P, "……灯？有人？", "surprise", [A("move", who="princess", to=[11, 7], time=0.8)]),
        line(N, "（灯下站着一个熟悉的身影。她手里提着一双粉色的小鞋）", None, [A("move", who=B, to=[13, 7], time=0.6)]),
        {"actions": [A("camera", reset=True, time=0.3)], "wait": 0.3},
    ]
    return {"name": "水道的出口", "letterbox": True, "skippable": True, "steps": s}


def meet_out():
    s = [
        line(N, "（两个人并肩站起来，看向水道的深处。很远很远的地方，好像有什么东西在发着微弱的光）"),
        line(BLUE, "……走吧。"),
        line(P, "……嗯！一起走。", "happy"),
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("chapter_end", title="第三章　汇合", subtitle="——（待续）废弃水道的深处，传来了哗哗的水声", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "一起走", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"meet_in": meet_in, "meet_out": meet_out}
