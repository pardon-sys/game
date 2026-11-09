"""反省篇第四章·旧王宫的追加事件（第四批）：后花园（前厅东北角柱子后面的暗门）——
双人秋千（一个坐一个推，藤蔓挠脚心）、天使喷泉的水路（三尊小天使转向，水流进喷泉 → 凉亭宝箱）、
花园小店主（小花精玩偶，想浇花 → 厨房的小水壶 → 花瓣挠痒谢礼 + 线索）、花丛里的小精灵。
只写痒、笑、友情；两位都是成年人。误导点到为止（星星和雪花），不碰派对主人。
"""
from .common import A, BLUE, L, N, P, cg, dfile, line, pose, say, theater, tk
from .palace2 import _bp, _bt, _burst_blue, _burst_pink, _duo
from . import palace10

KEEPER = "花园小店主"

TEXT = {
    "garden_spray": ["呀！水、水喷到脚底了——！", "……转错了。……脚底，好凉。"],
    "garden_flow": ["水流过去了！", "……三股水。……汇到喷泉里了。"],
    "garden_fairy": ["小、小精灵在挠脖子——！", "……花丛里的小东西。……别靠太近。"],
    "garden_turn": ["转一下……", "……转。"],
}

# 秋千板上的刻字：两个名字的缩写早就磨掉了，只剩一颗星星和一片雪花
SWING_LOOK = [L("（爬满蔷薇的白色秋千架，两块秋千板并排挂着，一边高一边低。藤蔓从架子上垂下来，轻轻地晃）", N),
              L("（秋千板上刻着两个名字的缩写，早就磨掉了。只剩下两个小小的图案：一颗星星，和一片雪花）", N),
              L("……星星，和雪花。", P, "surprise"),
              L("……婴儿房的刻痕旁边。……好像，也有这样的小图案。", BLUE)]

SIGNS = {
    "palace_garden_closed": [{"speaker": N, "text": "（东北角的柱子后面……有一点点风吹进来，带着花的味道。可是墙是实的）"},
                             {"speaker": BLUE, "text": "……墙后面，有东西。……石像，也许知道怎么开。"}],
}

DIALOGUES = {
    "garden_swing": dfile("", "双人秋千", {
        "default": {"lines": SWING_LOOK, "prompt": "坐上去荡一荡？",
                    "choices": [{"text": "一个坐，一个推", "next": "go"}, {"text": "先不了", "next": "no"}]},
        "go": {"lines": [L("我先坐！你推我——要推得高高的！", P, "happy")], "theater": "garden_swing"},
        "no": {"lines": [L("……等一下再玩。", P)]},
        "again": {"lines": [L("（秋千还在轻轻地晃。藤蔓垂下来，好像在等下一个人坐上去）", N),
                            L("（板子上的星星和雪花，挨得很近很近）", N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:garden_swing"}, "node": "again"}, {"node": "default"}]),
    "garden_gazebo": dfile("", "凉亭里的宝箱", {
        "default": {"lines": [L("（白色的小凉亭里放着一只宝箱。锁孔是一个小小的水车——要有水流过来，才转得动）", N),
                              L("……喷泉是干的。……水，从哪里来。", BLUE)]},
        "open": {"lines": [L("（喷泉里的水漫过石槽，流进凉亭，小水车「咕噜咕噜」地转了起来——宝箱「咔哒」一声开了）", N),
                           L("（宝箱里有两颗薄荷糖、一小袋金币，还有一张卡片：「陛下的花园，三个人一起的时候最热闹」）", N),
                           L("……三个人。", P, "sad")], "set": {"call": "palace_gazebo_open"}},
        "done": {"lines": [L("（宝箱空了。水车还在慢慢地转）", N)]},
    }, entries=[{"if": {"flag": "palace_gazebo_done"}, "node": "done"}, {"if": {"flag": "palace_fountain_flow"}, "node": "open"}, {"node": "default"}]),
    "garden_keeper": dfile("", KEEPER, {
        "default": {"lines": [L("（花坛边上，一个戴着雏菊帽子的小花精人偶正对着一朵蔫掉的郁金香叹气）", N),
                              L("……蔫了，全都蔫了！……要浇花！要浇花！", KEEPER),
                              L("可是我的小水壶……被厨房的人拿去装汤了！我、我不敢去厨房，厨师长好凶的！", KEEPER),
                              L("……厨房。……水槽那边，也许有。", BLUE)], "set": {"flags": ["palace_keeper_asked"]}},
        "wait": {"lines": [L("小水壶！小水壶在厨房！拜托啦！", KEEPER)]},
        "water": {"lines": [L("啊——！我的小水壶！", KEEPER),
                            L("（两个人帮她把花坛一个一个浇过去。蔫掉的郁金香慢慢地抬起头来）", N),
                            L("谢谢！谢谢！……要好好地谢谢你们才行！", KEEPER)], "theater": "garden_petals",
                  "set": {"call": "palace_keeper_water"}, "next": "clue"},
        "clue": {"lines": palace10.KEEPER_CLUE},   # 第七轮：编了一半的花环
        "done": {"lines": [L("花都抬起头了！下次再来玩呀！", KEEPER)]},
    }, entries=[{"if": {"flag": "palace_keeper_done"}, "node": "done"},
                {"if": {"flag": ["palace_keeper_asked", "palace_can_taken"]}, "node": "water"},
                {"if": {"flag": "palace_keeper_asked"}, "node": "wait"}, {"node": "default"}]),
    "kitchen_watering_can": dfile("", "水槽边的小水壶", {
        "default": {"lines": [L("（水槽边上倒扣着一把小小的水壶，壶身上画着一朵花。里面……装过汤）", N),
                              L("……花园小店主的水壶。……洗干净，带回去。", BLUE)], "set": {"give_item": {"watering_can": 1}, "flags": ["palace_can_taken"]}},
        "done": {"lines": [L("（水槽边空了）", N)]},
    }, entries=[{"if": {"flag": "palace_can_taken"}, "node": "done"}, {"node": "default"}]),
}

# ================================================================ 双人秋千（藤蔓挠脚心）
SWING = theater("后花园：双人秋千", _duo("normal", "normal", v1={"kind": "trap:feather_curtain", "at": [-20, -10]},
                                        v2={"kind": "trap:feather_curtain", "at": [20, -10]}), [
    say(N, "（粉色公主坐上秋千，蓝色公主在后面一推——秋千「呼」地荡了出去）", act=1),
    say(P, "哇——！好高！再高一点！", emotion="happy"),
    say(BLUE, "……好。……抓紧。"),
    say(N, "（荡到最高的时候，秋千架上的藤蔓「沙沙」地垂下来，叶尖正好扫过她悬在半空、晃来晃去的光脚）",
        [tk("v1", zone="sole", fx="leaf", n=6, iv=0.2), pose("giggle")], act=2),
    say(P, "嘻……！叶、叶子……扫到脚心了……", emotion="giggle"),
    say(BLUE, "……（又推了一下）……再高一点？"),
    say(P, "不、不要再高了——越高藤蔓越多——哈哈哈！", emotion="helpless_1"),
    say(N, "（藤蔓好像认得这架秋千。每荡一次，就多垂下来几根，卷着叶子在她的脚心、脚趾缝里来回地刷）",
        [tk("v1", zone="sole", fx="leaf", n=12, iv=0.11), pose("helpless_1")]),
    say(P, "换、换人！换你坐！", emotion="helpless_1"),
    say(N, "（换蓝色公主坐上去。粉色公主揉着脚，坏笑着把秋千推得比刚才还高）", [pose("normal"), _bp("normal")], act=3),
    say(BLUE, "……等、等一下……太高……"),
    cg(say(N, "（藤蔓一下子缠上了两块秋千板——连站在后面推秋千的粉色公主也被卷了上去，两个人并排挂在秋千上，脚底被叶子一起刷着）",
           [tk("v1", zone="sole", fx="leaf", n=14, iv=0.09), _bt(14, 0.09, by="v2", zone="sole", fx="leaf"), pose("helpless_2"), _bp("helpless_2")])),
    say(P, "哈哈哈哈！我、我只是在推——为什么我也——！", emotion="helpless_2"),
    say(BLUE, "……哈、哈哈……秋千……停不下来……"),
    _burst_pink("（星光在花园里炸开，藤蔓「哗」地缩回了架子上……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，秋千的绳子结了一层薄薄的霜……）"),
    say(N, "（秋千慢慢地停下来。最后一根藤蔓缩回去之前，叶尖还是在两人刚释放完、敏感得要命的脚心上轻轻勾了一下）",
        [tk("v1", zone="sole", fx="leaf", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……哈……这架秋千……一定是故意的……", emotion="helpless_1"),
    say(BLUE, "……嗯。……以前，一定也有人，在这里笑成这样。", [pose("normal"), _bp("normal")]),
])

# ================================================================ 花园小店主的谢礼（花瓣挠痒）
PETALS = theater("后花园：花瓣谢礼", _duo("normal", "normal", f1={"kind": "trap:feather_curtain", "at": [-20, -8]},
                                       f2={"kind": "trap:feather_curtain", "at": [20, -8]}), [
    say(KEEPER, "谢礼！花精的谢礼，是——花瓣按摩！", act=1),
    say(N, "（小店主往篮子里一抓，一大把花瓣「呼」地飘起来，像小小的粉色手指一样，在两个人的脖子边上打转）",
        [tk("f1", zone="neck", fx="leaf", n=6, iv=0.2), _bt(6, 0.2, by="f2", zone="neck", fx="leaf"), pose("giggle"), _bp("giggle")]),
    say(P, "嘻……！脖、脖子……好痒……", emotion="giggle"),
    say(BLUE, "……花瓣。……钻进领口了。"),
    say(KEEPER, "还有还有！浇花浇了那么久，脚一定累了吧！", act=2),
    cg(say(N, "（花瓣一片一片地落到两个人的脚心上，小店主踮着脚，用一朵蒲公英在上面轻轻地扫来扫去）",
           [tk("f1", zone="sole", fx="feather", n=12, iv=0.11), _bt(12, 0.11, by="f2", zone="sole", fx="feather"), pose("helpless_1"), _bp("helpless_1")], act=3)),
    say(P, "哈哈哈！这、这不是按摩——这是挠痒啦！", emotion="helpless_1"),
    say(KEEPER, "陛下也是这么说的！然后笑得比谁都大声！"),
    say(N, "（花瓣越落越多，把两个人的腰、肋下、脚心都盖住了。每一片都在轻轻地动）",
        [tk("f1", zone="waist", fx="leaf", n=14, iv=0.09), _bt(14, 0.09, by="f2", zone="armpit", fx="leaf"), pose("helpless_2"), _bp("helpless_2")]),
    _burst_pink("（星光炸开，花瓣「哗」地一下飘满了整个花园……哈啊……放出去了……）"),
    _burst_blue("……哈……哈哈……（冰晶跟着炸开，飘在半空的花瓣全结成了小小的冰花……）"),
    say(N, "（冰花落下来，最后一片，正好落在两人刚释放完、敏感得要命的脚心上，凉丝丝地滑了过去）",
        [tk("f1", zone="sole", fx="leaf", n=4, iv=0.2), A("shake", who="princess", time=0.3), pose("helpless_1"), _bp("helpless_1")], act=4),
    say(P, "呀……！……哈……谢、谢礼收到了……", emotion="helpless_1"),
    say(KEEPER, "嘿嘿！", [pose("normal"), _bp("normal")]),
])

THEATERS = {"garden_swing": SWING, "garden_petals": PETALS}


def garden_in():
    s = [
        line(N, "（柱子后面的墙「咔」地往里一缩，露出一道窄窄的石阶。石阶尽头，是一片没有人打理的花园）"),
        line(N, "（蔷薇爬满了秋千架，喷泉早就干了，三尊抱着水瓶的小天使朝着三个不同的方向）"),
        line(P, "……后花园。好漂亮……", "surprise"),
        line(BLUE, "……可是，好安静。", None),
    ]
    return {"name": "后花园", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"palace_garden_in": garden_in}
