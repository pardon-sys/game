"""反省篇第四章·旧王宫的追加事件（第三批，跨图）：女仆长的发条钥匙（钟楼 → 回廊休息室的按摩椅）、失窃的小画像（衣帽间镜子迷宫 → 王座间）、
人偶舞会（训练场铜钟 + 婴儿房吊铃 + 前厅地砖 → 舞会战斗）、宝箱怪的逃亡（隧道 → 厨房冷藏库 → 图书馆 → 衣帽间）、人偶巡夜队、冷藏库。
只写痒、笑、友情；两位都是成年人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, line, pose, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo

HEADMAID = "女仆长"
DOLLS = "舞会人偶们"
SPRITES = "冰糕精灵们"
MIMIC = "宝箱怪"

TEXT = {
    "patrol_caught": ["被、被巡夜的人偶抓到了——！", "……巡夜的。……腋下。"],
    "cold_melt": ["融开了！好冷……里面是冷藏库？", "……门化了。……好冷。"],
    "ball_beat": ["脚、脚下的地板——羽毛！", "……拍子。……没躲开。"],
    "portrait_back_gibberish": ["……谁把我的小画像挂回来了？……它在打呼噜。", "……四幅变三幅。……三是个好数字，像三下敲门。"],
}

DIALOGUES = {
    # 回廊：女仆长的发条孔 / 休息室的按摩椅
    "servants_wind_maid": dfile("", "女仆长的背后", {
        "default": {"lines": [L("（女仆长人偶的背后有一个小小的发条孔，发条已经快停了。……她走路的样子，比别的人偶都累）", N)],
                    "prompt": "用发条钥匙给她上弦？", "choices": [{"text": "上弦", "next": "go"}, {"text": "算了", "next": "no"}]},
        "go": {"lines": [L("……慢慢转。", BLUE)], "set": {"call": "palace_wind_maid"}},
        "no": {"lines": [L("……先不惊动她。", P)]},
        "friend": {"lines": [L("……谢、谢。……很久，没有人，给我上弦了。", HEADMAID),
                             L("……休息室，请便。……按摩椅，很舒服。", HEADMAID)]},
    }, entries=[{"if": {"flag": "palace_headmaid_friend"}, "node": "friend"}, {"node": "default"}]),
    "servants_lounge_chair": dfile("", "人偶按摩椅", {
        "default": {"lines": [L("（休息室里并排放着两张紫色天鹅绒的按摩椅，扶手上折着两只戴白手套的小机械手）", N),
                              L("……这是，陛下和小殿下们，「按摩日」坐的椅子。", HEADMAID)],
                    "prompt": "坐上去试试？", "choices": [{"text": "……试试", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("……就坐一下。", P)], "theater": "servants_massage"},
        "no": {"lines": [L("……看起来不太对劲。", BLUE)]},
        "again": {"lines": [L("（按摩椅的小机械手礼貌地折了回去。……扶手上刻着三个名字，有两个被磨掉了，剩下一个：「陛下」）", N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:servants_massage"}, "node": "again"}, {"node": "default"}]),
    # 厨房冷藏库：冰块里的生日蛋糕
    "kitchen_ice_cake": dfile("", "冰块里的蛋糕", {
        "default": {"lines": [L("（一大块透明的冰里，冻着一个小小的粉色生日蛋糕，上面插着两根蜡烛）", N)],
                    "prompt": "用粉色公主的火把冰融开？", "choices": [{"text": "融开", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("……小心一点，别把蛋糕烤焦了。", BLUE)], "set": {"call": "palace_melt_cake"}, "next": "card"},
        "card": {"lines": [
            L("（冰化成了水。蛋糕底下压着一张小卡片，字迹很秀气）", N),
            L("「给两个小不点的第一个生日——一根蜡烛给爱笑的，一根蜡烛给爱哭的」", N),
            L("……两根蜡烛。", P, "sad"),
            L("……（盯着蛋糕看了很久）……", BLUE)]},
        "no": {"lines": [L("……先不碰。", P)]},
        "done": {"lines": [L("（蛋糕安安静静地放在盘子上。两根蜡烛，一根粉色，一根蓝色）", N)]},
    }, entries=[{"if": {"flag": "palace_ice_cake"}, "node": "done"}, {"node": "default"}]),
    # 宝箱怪的逃亡
    "mimic_hide": dfile("", "一口眼熟的宝箱", {
        "default": {"lines": [L("（角落里放着一口宝箱。……盖子好像在一起一伏地呼吸）", N)], "prompt": "打开？",
                    "choices": [{"text": "抓住它！", "next": "go"}, {"text": "先不碰", "next": "no"}]},
        "go": {"lines": [L("……就是你！", P, "angry")], "set": {"call": "palace_mimic_catch"}},
        "no": {"lines": [L("……等一下再抓。", BLUE)]},
    }),
    "mimic_done": dfile("", MIMIC, {"default": {"lines": [
        L("（宝箱怪「咔嗒」一声瘫在地上，张开嘴——吐出了一堆金币和一张折起来的纸）", N),
        L("……吱、吱嘎。……不、不跑了。", MIMIC),
        L("（纸上画着一张王宫的地图，钟楼顶上画了一个小小的月亮，旁边写着：「每年的那一天，三个人一起」）", N),
        L("……三个人。", P, "sad"),
        L("……又是三个。", BLUE)]}}),
    # 衣帽间：镜子迷宫里的「镜子」
    "wardrobe_fake_mirror": dfile("", "一面奇怪的镜子", {
        "default": {"lines": [L("（镜子迷宫里，这一面镜子特别小，镜框是椭圆形的。……镜子里映出来的不是你们，是一位戴着大假发的贵妇人）", N)],
                    "prompt": "伸手摸一摸？", "choices": [{"text": "摸一摸", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("（「哎呀！」——贵妇人睁开眼睛，伸出画里的小手，在她脖子上挠了一下，然后从墙上「啪」地掉了下来）", N),
                         L("……这是，王座间的小画像？……跑到这里来了。", BLUE)], "set": {"call": "palace_fake_mirror"}},
        "no": {"lines": [L("……先不惹它。", P)]},
        "done": {"lines": [L("（这一面现在是普通的镜子了）", N)]},
    }, entries=[{"if": {"flag": "palace_portrait_found"}, "node": "done"}, {"node": "default"}]),
}

# ================================================================ 回廊休息室：人偶按摩椅（CG）
MASSAGE = theater("仆人回廊：女仆长的按摩椅", _duo("normal", "normal", c1={"kind": "trap:feather_curtain", "at": [-20, -6]},
                                                c2={"kind": "trap:feather_curtain", "at": [20, -6]}), [
    say(HEADMAID, "……请坐。……今天，是按摩日。", act=1),
    say(N, "（两个人刚坐下，扶手上的小机械手就「咔哒咔哒」地展开了，一只捏肩，一只捶背——居然很舒服）", [pose("normal"), _bp("normal")]),
    say(P, "……哦？……还、还挺舒服的……", emotion="happy"),
    say(BLUE, "……嗯。……肩膀，松了。"),
    say(HEADMAID, "……接下来，是，脚底。（拧了一下椅背上的发条）", act=2),
    say(N, "（脚凳往上一抬，鞋被小机械手轻轻地脱了下来。一根羽毛从椅子底下伸出来，在脚心上「刷」地扫了一下）",
        [tk("c1", zone="sole", fx="feather", n=8, iv=0.16), _bt(6, 0.16, by="c2", zone="sole", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(P, "噫！？这、这也是按摩？！", emotion="surprise"),
    say(HEADMAID, "……陛下说，笑一笑，血液循环，会变好。"),
    cg(say(N, "（捏肩的手换成了挠腰的手，捶背的手换成了挠肋下的手，脚凳上的羽毛一根变成三根——两张椅子一起「嗡嗡」地运转起来）",
           [tk("c1", zone="waist", fx="hand", n=12, iv=0.11), _bt(12, 0.11, by="c2", zone="armpit", fx="hand"), pose("helpless_1"), _bp("helpless_1")], act=3)),
    say(P, "哈哈哈！循、循环——循环得太好了——停、停一下！", emotion="helpless_1"),
    say(BLUE, "……哈、哈哈……发条……发条拧得太紧了……"),
    say(HEADMAID, "……小殿下们，每次都说「再来一次」。"),
    say(N, "（两个人笑得在椅子上直扭，手拼命去够扶手上的停止拉杆，可是小机械手总是先一步挠在她们的手腕上）",
        [tk("c1", zone="sole", fx="lines", n=14, iv=0.09), _bt(14, 0.09, by="c2", zone="waist", fx="feather"), pose("helpless_2"), _bp("helpless_2")]),
    _burst_pink("（星光在休息室里炸开，按摩椅的发条「嘣」地弹开了……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，小机械手全冻成了冰雕……）"),
    say(N, "（冻住之前，最后一根羽毛还是不甘心地，在两人刚释放完、敏感得要命的脚心上轻轻划了一下）",
        [tk("c1", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……按、按摩日结束了吗……", emotion="helpless_1"),
    say(HEADMAID, "……结束了。……陛下也是，每次都笑到发条弹开。"),
    say(HEADMAID, "……陛下，和小殿下们，三个人，挤在一张椅子上。……那是，最热闹的一天。", [pose("normal"), _bp("normal")]),
    say(P, "……三个人。", emotion="sad"),
])

# ================================================================ 人偶舞会：输了（CG）
BALL_FAIL = theater("王座前厅：人偶舞会", _duo("helpless_1", "helpless_1", d1={"kind": "trap:feather_curtain", "at": [-24, -8]},
                                          d2={"kind": "trap:feather_curtain", "at": [24, -8]}), [
    say(DOLLS, "（咔哒、咔哒）……请、跳舞。……跳到、天亮。", act=1),
    say(N, "（舞会人偶们拉起两个人的手，转了一圈、又一圈。踩错一步，就有一把蕾丝扇子在腰上扇一下）",
        [tk("d1", zone="waist", fx="feather", n=8, iv=0.15), _bt(8, 0.15, by="d2", zone="waist", fx="feather"), pose("giggle"), _bp("giggle")]),
    say(P, "我、我不会跳这种舞——！", emotion="surprise"),
    say(BLUE, "……左、左脚……不对，右……哈……"),
    say(DOLLS, "……跳错了。……罚。", act=2),
    say(N, "（鞋在转圈的时候飞了出去。人偶们一个托住腰，一个蹲下去，用羽毛在光着的脚心上打起了拍子：一、二、三，一、二、三）",
        [tk("d1", zone="sole", fx="feather", n=10, iv=0.14), _bt(10, 0.14, by="d2", zone="sole", fx="feather"), pose("helpless_1"), _bp("helpless_1")]),
    cg(say(N, "（整个舞池跟着转了起来。两个人被转得晕头转向，互相抱住才没摔倒，人偶们的扇子和羽毛却从四面八方挠过来）",
           [tk("d1", zone="armpit", fx="hand", n=12, iv=0.1), _bt(12, 0.1, by="d2", zone="armpit", fx="hand")], act=3)),
    say(P, "哈哈哈！停、停下——转、转晕了——还挠——！", emotion="helpless_1"),
    say(BLUE, "……哈哈……拍子……跟不上……"),
    say(DOLLS, "……三拍子。……再来。……一、二、三。"),
    say(N, "（三拍子的最后一拍，总是落在脚心上）", [tk("d1", zone="sole", fx="lines", n=14, iv=0.09), pose("helpless_2"), _bp("helpless_2")]),
    _burst_blue("……哈……哈哈……（冰晶炸开，舞池变成了一整面滑溜溜的冰）"),
    _burst_pink("（星光跟着炸开，满地的人偶滑成了一圈……哈啊……放出去了……）"),
    say(N, "（一个人偶滑过来的时候，还是伸出扇子，在两人刚释放完的脚心上补了最后一拍）",
        [tk("d1", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……第、第三拍……", emotion="helpless_1"),
    say(DOLLS, "……舞会，暂停。……下次，再来。"),
    say(N, "（人偶们行了个屈膝礼，把两个人送到了前厅门口）", [pose("normal"), _bp("normal")]),
])

# ================================================================ 冷藏库：冰糕精灵（小剧场）
ICECREAM = theater("厨房冷藏库：冰糕精灵", _duo("normal", "normal", s1={"kind": "trap:feather_curtain", "at": [-22, -8]},
                                           s2={"kind": "trap:feather_curtain", "at": [22, -8]}), [
    say(N, "（冷藏库里白茫茫的，架子上摆满了冻得硬邦邦的点心。……一个冰淇淋球「啵」地睁开了眼睛）", act=1),
    say(SPRITES, "有人来了！有人来了！是来吃冰淇淋的吗！"),
    say(P, "冰、冰淇淋会说话？！", emotion="surprise"),
    say(SPRITES, "我们不给吃！但是可以——给你们冰一下！"),
    say(N, "（三个冰糕精灵扑了过来，冰凉凉的小手一下贴在脖子上，一下贴在脚踝上）",
        [tk("s1", zone="neck", fx="hand", n=8, iv=0.15), _bt(8, 0.15, by="s2", zone="neck", fx="hand"), pose("giggle"), _bp("giggle")], act=2),
    say(P, "冰——！好冰！嘻嘻……不、不要贴脖子！", emotion="giggle"),
    say(BLUE, "……这个，我习惯了。……哈……不对，它们在挠。"),
    say(N, "（冰糕精灵们钻进了鞋子里，冰凉的小羽毛在脚心上来回地扫——又冷又痒）",
        [tk("s1", zone="sole", fx="feather", n=12, iv=0.11), _bt(12, 0.11, by="s2", zone="sole", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=3),
    say(P, "哈哈哈！冷、冷的羽毛最痒了——！", emotion="helpless_1"),
    say(SPRITES, "冰一下！冰一下！冰一下就好吃了！"),
    say(BLUE, "……哈哈……我、我们不是点心……", [_bp("helpless_2")]),
    say(N, "（两个人缩成一团，冰糕精灵们在脖子、腰和脚心之间跳来跳去）", [tk("s1", zone="waist", fx="lines", n=14, iv=0.09), pose("helpless_2")]),
    _burst_pink("（星光一炸，冷藏库里一下子暖了起来——冰糕精灵们「呀」地叫着往外飞……哈啊……放出去了……）"),
    say(N, "（有一个飞得慢，临走前用最后一点冰凉，在她刚释放完、敏感得发烫的脚心上「啾」地贴了一下）",
        [tk("s1", zone="sole", fx="feather", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……又冷又热的……", emotion="helpless_1"),
    say(SPRITES, "不给吃不给吃！要打赢我们才行！"),
    say(N, "（冰糕精灵们在冷藏库里飘了起来，摆好了架势）", [pose("normal"), _bp("normal")]),
])

THEATERS = {"servants_massage": MASSAGE, "ante_ball_fail": BALL_FAIL, "kitchen_icecream": ICECREAM}


def ball_in():
    s = [
        {"actions": [A("sfx", sound="music_box", volume=-2.0)], "wait": 0.6},
        line(N, "（地砖的笑声、远处的钟声、吊铃的叮咚声——三段声音一下子合在了一起，变成了一首完整的摇篮曲）"),
        line(N, "（前厅的柱子后面，「咔哒咔哒」地走出了一排穿着舞会裙的人偶。它们提起裙摆，行了个屈膝礼）"),
        line(DOLLS, "……舞会，开始。……请跳到，最后一支舞。"),
        line(P, "……跳舞？跳舞我会——吧？", "surprise"),
        line(BLUE, "……地板。……红色的那一块，别站。", None),
        {"actions": [A("notify", text="人偶舞会：打倒三支舞的人偶；地板亮红的那一块，拍子落下前离开")], "wait": 0.3},
    ]
    return {"name": "人偶舞会", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"ante_ball_in": ball_in}
