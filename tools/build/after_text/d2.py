"""第 2 天早上：广场足枷示众（一整段过场，四轮忍笑选择）。
每轮被挠的时候弹出三个应对（装没事 calm / 求饶 beg / 顶嘴 sass），忍笑条满之前没选 = 笑出声（burst，每次 +2 工时）。
上一轮怎么应对，决定下一个人怎么来（endure 的 time_by：求饶了下一个手下留情，顶嘴了下一个加码）。
镇民夸她的脚、小孩轮番拿不同的东西挠脚心（羽毛 → 狗尾巴草 → 刷子 + 扳脚趾 → 一群小孩），蓝色公主最后一个来。
变量：stocks_last（上一轮的结果）、stocks_bursts（笑出声的次数）。笑出声 3 次以上 → 下午之前去训练营转一次受罚转盘（AfterStory）。
"""
from .common import A, BLUE, BLUE_NODE, CAP, N, P, line

STOCKS = "Stocks_23_24"
VAR, BURSTS = "stocks_last", "stocks_bursts"
SUP, GRANNY, HOST, MERCH = "市场监督", "面包店的奶奶", "篝火派对的主人", "水果摊的商贩"
TOM, LILY, KIDS, TOWN = "小汤姆", "小莉莉", "小孩们", "镇民"
FEET = [23, 25.6]     # 站在她脚边的位置


def when(result):
    return {"eq": {VAR: result}}


def br(result, *steps):
    """这一轮结果是 result 时才演的几步。"""
    out = []
    for st in steps:
        st = dict(st)
        st["if"] = when(result)
        out.append(st)
    return out


def tk(by, fx, n=4, iv=0.25):
    return A("tickle", who="princess", by=by, zone="sole", fx=fx, repeat=n, interval=iv)


def endure(prompt, options, by, fx, time_by, time=4.5):
    return {"endure": {"time": time, "time_by": dict({"var": VAR}, **time_by), "prompt": prompt, "options": options,
                       "var": VAR, "burst_var": BURSTS, "delay": 0.7,
                       "tickle": {"who": "princess", "by": by, "zone": "sole", "fx": fx}}, "wait": 0.1}


def burst_line(text):
    return line(P, text, "helpless_2", [A("pose", laugh=95), A("shake", time=0.4), A("bubble", who="princess", kind="laugh")])


def d2_stocks():
    s = [
        # 跟着的蓝色公主一早去训练室了：先挪到地图角落（最后再放回她身边）
        {"actions": [A("fade_out", time=0.0), A("move", who=BLUE_NODE, to=[60, 4]), A("hold", who=STOCKS), A("pose", emotion="shy", laugh=10),
                     A("spawn", id="v1", kind="npc:merchant", at=[27, 28], dir="left"),
                     A("spawn", id="v2", kind="npc:maid", at=[28, 27.5], dir="left"),
                     A("camera", to=[23, 26], zoom=1.0, time=0.1)], "wait": 0.3},
        {"actions": [A("fade_in", time=1.0), A("sfx", sound="stocks", volume=-4.0)], "wait": 1.0},
        line(N, "（第二天早上。广场正中间的足枷上，锁着一双光脚丫）"),
        line(P, "（为、为什么非要光着脚啊……！鞋子一早就被女仆小姐收走了……）", "shy"),
        line(CAP, "示众半天。按老规矩——每笑出声一次，加两工时。", None, [A("face", who="after_captain", dir="right")], "captain"),
        line(SUP, "我来记。……账本、记号笔，都准备好了。", None, [A("hop", who="after_supervisor")]),
        line(P, "记号笔是要记在哪里啊！", "angry"),
        {"actions": [A("move", who="after_granny", to=[21.6, 25.4], speed=40)], "wait": 1.0},
        line(GRANNY, "孩子，先喝口水。太阳晒着呢，脚底板都晒红了。"),
        line(P, "谢谢奶奶……呜……大家都在看……", "sad"),
        {"actions": [A("move", who="v1", to=[24.6, 26.0], speed=50), A("move", who="v2", to=[25.4, 25.4], speed=50)], "wait": 1.2},
        line(TOWN, "哎呀，原来公主的脚这么小巧……白白嫩嫩的，像刚出炉的奶油小面包。", None, [A("bubble", who="v1", kind="happy")]),
        line(TOWN, "你看你看，脚趾头还会缩起来呢！一被看就缩一下，好可爱～", None, [A("hop", who="v2")]),
        line(P, "不、不准看！也不准评价！！", "angry", [A("shake", time=0.3)]),
        line(N, "（越是被盯着看，脚趾越是不听话地蜷成一团。脸烫得快要冒烟了）", None, [A("pose", emotion="shy")]),
        # ---------------- 第一轮：小汤姆的羽毛
        {"actions": [A("move", who="after_kid_tom", to=FEET, speed=70)], "wait": 1.6},
        line(TOM, "姐姐！我说过要拿羽毛来的！", None, [A("hop", who="after_kid_tom")]),
        line(P, "汤、汤姆？！说好了不可以的——", "surprise"),
        line(N, "（小汤姆蹲下来，捏着羽毛，从脚跟慢慢扫到脚趾尖）", None, [tk("after_kid_tom", "feather")]),
        endure("羽毛在脚心上扫来扫去……要怎么办？",
               [["calm", "（咬住嘴唇，装作没事）"], ["beg", "汤姆，求你了，别扫了……！"], ["sass", "哼，一、一点都不痒！"]],
               "after_kid_tom", "feather", {}, 5.0),
    ]
    s += br("calm", line(TOM, "诶？不痒吗？……那我换脚趾缝！", None, [tk("after_kid_tom", "feather", 3)]),
            line(P, "（……忍、忍住……脸绷得好酸……）", "shy"),
            line(TOWN, "她装得好辛苦哦～脚趾都抠紧了。", None, [A("bubble", who="v2", kind="happy")]))
    s += br("beg", line(GRANNY, "汤姆，轻一点。姐姐在受罚，不是在陪你玩。"),
            line(TOM, "好嘛……那我轻轻地扫。"),
            line("镇民们", "噗——求饶了求饶了。", None, [A("bubble", who="v1", kind="laugh")]),
            line(P, "（……更丢脸了……）", "sad"))
    s += br("sass", line(TOM, "一点都不痒？那我去叫莉莉来！", None, [A("hop", who="after_kid_tom")]),
            line(P, "不、不是那个意思——！", "surprise"))
    s += br("burst", burst_line("噗——哈、哈哈哈！痒、痒死了！羽毛别转圈——！"),
            line(SUP, "笑出声了。记一笔。", None, [A("sfx", sound="book")]),
            line(P, "呜……第一笔……", "sad"))
    # ---------------- 第二轮：狗尾巴草（小莉莉也来了）
    s += [
        {"actions": [A("move", who="after_kid_lily", to=[22, 25.7], speed=70)], "wait": 1.4},
    ]
    s += br("sass", line(LILY, "汤姆说姐姐一点都不痒～我带了狗尾巴草！"))
    s += [
        {"if": {"any": [when("calm"), when("beg"), when("burst")]}, **line(LILY, "我、我是来拦着汤姆的……可是这根狗尾巴草，毛茸茸的……")},
        line(P, "莉莉你不是说要拦着他吗！", "angry"),
        line(N, "（两根狗尾巴草一左一右，绕着脚心画圈，又钻进脚趾缝里）", None,
             [tk("after_kid_lily", "feather"), tk("after_kid_tom", "feather")]),
        endure("毛茸茸的草穗钻进了脚趾缝……",
               [["calm", "（把脚趾蜷紧，一动不动）"], ["beg", "莉、莉莉也停下……拜托……！"], ["sass", "两根草而已……才、才不怕！"]],
               "after_kid_lily", "feather", {"beg": 6.0, "calm": 4.5, "sass": 4.0, "burst": 4.5}),
    ]
    s += br("calm", line(LILY, "哇……姐姐好厉害，一动都不动……脚趾都抠成一团了。"),
            line(TOWN, "那双小脚丫绷得跟小石头似的～", None, [A("bubble", who="v1", kind="happy")]),
            line(P, "（……别、别再说脚了……）", "shy"))
    s += br("beg", line(LILY, "对、对不起姐姐！", None, [A("move", who="after_kid_lily", to=[21, 26.4], time=0.4)]),
            line(TOM, "莉莉你怎么停了！"),
            line(CAP, "……小孩子到此为止。", None, None, "captain"))
    s += br("sass", line(TOM, "哦——姐姐说不怕！那下一个用刷子！", None, [A("hop", who="after_kid_tom")]),
            line(P, "我、我的嘴怎么就这么硬……！", "sad"))
    s += br("burst", burst_line("哈哈哈哈！草、草钻进脚趾缝了——不行不行不行！"),
            line(SUP, "又一笔。", None, [A("sfx", sound="book")]),
            line("镇民们", "哈哈哈哈……", None, [A("bubble", who="v1", kind="laugh"), A("bubble", who="v2", kind="laugh")]))
    # ---------------- 第三轮：篝火派对的主人的刷子 + 扳脚趾
    s += [
        {"actions": [A("move", who="after_bonfire_host", to=[24, 25.7], speed=60)], "wait": 1.4},
        line(HOST, "加油热饮来啦～顺便，派对的老规矩：示众的人要接受「刷子祝福」！", None, [A("hop", who="after_bonfire_host")]),
        line(P, "哪有这种规矩！！", "angry"),
    ]
    s += br("sass", line(MERCH, "嘴还挺硬嘛！摊子被踩烂的账，就用这双脚慢慢还吧！", None, [A("bubble", who="after_merchant", kind="angry")]))
    s += [
        {"if": {"any": [when("calm"), when("beg"), when("burst")]}, **line(MERCH, "嘿，看不出来，还挺能忍的。")},
        line(N, "（小汤姆扳开她的脚趾，派对主人的小刷子顺着脚趾缝，一根一根地刷进去）", None,
             [tk("after_bonfire_host", "brush"), tk("after_kid_tom", "hand", 3)]),
        endure("脚趾被扳开了，刷毛一根一根地刷进去……",
               [["calm", "（深呼吸……想想别的……想想蛋糕……）"], ["beg", "我错了我错了！刷子不行……！"], ["sass", "刷、刷吧！刷完我也不会笑！"]],
               "after_bonfire_host", "brush", {"beg": 5.0, "calm": 3.8, "sass": 3.2, "burst": 3.8}),
    ]
    s += br("calm", line(HOST, "哎呀，真能忍！那这个祝福就算你过关啦～"),
            line(TOWN, "脚心都被刷红了……好可怜，又好可爱。", None, [A("bubble", who="v2", kind="shy")]),
            line(P, "（……蛋糕……草莓蛋糕……）", "shy"))
    s += br("beg", line(HOST, "好好好，祝福到此为止～来，热饮。"),
            line(P, "谢、谢谢……（为什么我要道谢啊……）", "shy"))
    s += br("sass", line(HOST, "有骨气！那再刷三下～", None, [tk("after_bonfire_host", "brush", 6, 0.2)]),
            line(P, "哈……唔……！（……差、差一点……）", "shy", [A("pose", laugh=85)]))
    s += br("burst", burst_line("哈哈哈哈哈！脚、脚趾缝里——刷子进来了哈哈哈哈！"),
            line(SUP, "第……几笔了？我数数。", None, [A("sfx", sound="book")]))
    # ---------------- 第四轮：一群小孩
    s += [
        {"actions": [A("spawn", id="k1", kind="npc:kid", at=[30, 27], dir="left"), A("spawn", id="k2", kind="npc:kid", at=[31, 26], dir="left"),
                     A("spawn", id="k3", kind="npc:kid", at=[30, 25], dir="left"),
                     A("move", who="k1", to=[22.4, 26.2], speed=90), A("move", who="k2", to=[23.6, 26.3], speed=90),
                     A("move", who="k3", to=[24.6, 26.0], speed=90),
                     A("move", who="after_bonfire_host", to=[26, 24], speed=60)], "wait": 1.6},
        line(KIDS, "听说这里有人一点都不怕痒！", None, [A("hop", who="k1"), A("hop", who="k3")]),
        line(KIDS, "我们来比赛，看谁先让她笑出来！", None, [A("hop", who="k2")]),
        line(P, "一、一群……？！队长！队长管管啊！", "surprise"),
        line(CAP, "……示众还剩一刻钟。", None, [A("face", who="after_captain", dir="up")], "captain"),
        line(N, "（六只小手、六根羽毛，同时落在两只被锁住的脚心上）", None,
             [tk("k1", "feather"), tk("k2", "feather"), tk("k3", "feather")]),
        endure("两只脚心同时被一群小孩挠……！",
               [["calm", "（闭上眼睛……什么都感觉不到……）"], ["beg", "大家饶了我吧……我以后再也不乱开门了……！"],
                ["sass", "来、来啊！我才不会输给小孩子！"]],
               "k2", "feather", {"beg": 4.2, "calm": 3.0, "sass": 2.6, "burst": 3.0}),
    ]
    s += br("calm", line(KIDS, "好无聊，她都不笑～走啦走啦。"),
            line(P, "（……赢、赢了……？脚底板已经没有知觉了……）", "shy"))
    s += br("beg", line(GRANNY, "好了好了，孩子们，回家吃早饭了。"),
            line(KIDS, "是——！"),
            line(P, "（……「再也不乱开门了」……我刚才说了什么啊……）", "sad"))
    s += br("sass", line(KIDS, "哇——她不服！大家一起上！", None, [tk("k1", "feather", 5, 0.18), tk("k3", "feather", 5, 0.18)]),
            line(P, "哈……哈……（嘴、嘴角在抖……再、再一下就……）", "shy", [A("pose", laugh=90)]),
            line(GRANNY, "好了好了，孩子们，回家吃早饭了。"))
    s += br("burst", burst_line("哈哈哈哈哈哈！我输了我输了！小孩子好可怕哈哈哈哈！"),
            line(KIDS, "我们赢啦——！", None, [A("hop", who="k1"), A("hop", who="k2"), A("hop", who="k3")]))
    # ---------------- 蓝色公主最后一个来
    s += [
        {"actions": [A("despawn", who="k1"), A("despawn", who="k2"), A("despawn", who="k3"), A("despawn", who="v1"), A("despawn", who="v2"),
                     A("move", who="after_kid_tom", to=[40, 26], speed=80), A("move", who="after_kid_lily", to=[40, 25], speed=80),
                     A("move", who="after_granny", to=[20, 27], speed=40), A("pose", laugh=20)], "wait": 0.8},
        {"actions": [A("spawn", id="b", kind="npc:blue_princess", at=[31, 24], dir="left"), A("move", who="b", to=[24.8, 24.6], speed=40)],
         "wait": 2.2},
        line(N, "（人群散开的时候，一个蓝色的身影从训练室那边走了过来。头发乱糟糟的，走路有点晃）"),
        line(BLUE, "……还活着吗。"),
        line(P, "你、你来干什么啦……！说好了不准来看的！", "angry"),
        line(BLUE, "……说好了，最后一个来。……我是最后一个。"),
        line(P, "……那你的头发怎么了？", "surprise"),
        line(BLUE, "……特训。……别问。"),
        line(N, "（蓝色公主在足枷旁边坐了下来。裤腿上的蓝白条纹，一闪一闪地亮了起来）", None, [A("bubble", who="b", kind="dots")]),
        {"actions": [A("spawn", id="ph", kind="prop:pants_hand", at=[24.6, 24.8], z=2), A("move", who="ph", to=[23.3, 25.4], time=0.9)],
         "wait": 0.9},
        line(P, "呀啊！？谁、谁在挠——", "surprise", [tk("ph", "hand", 4, 0.22)]),
        line(BLUE, "……不是我。……是它。"),
        line(N, "（裤子里伸出来的小手，正用指尖戳她的脚心——戳一下，缩回去，再戳一下，像在打招呼）", None, [tk("ph", "hand", 3, 0.35)]),
        line(P, "哈、哈……你、你管管它啊……！", "giggle", [A("pose", laugh=60)]),
        line(SUP, "这、这一下算不算？"),
        line(CAP, "……不算。", None, [A("face", who="after_captain", dir="left")], "captain"),
        line(BLUE, "……乖。回来。", None, [A("move", who="ph", to=[24.8, 24.6], time=0.6)]),
        {"actions": [A("despawn", who="ph")], "wait": 0.3},
        line(CAP, "时间到。放人。", None, [A("hold", who=STOCKS, on=False), A("sfx", sound="stocks"), A("pose", laugh=0)], "captain"),
    ]
    # ---------------- 结算
    s += [
        {"if": {"var": {BURSTS: ["==", 0]}}, **line(SUP, "一次都没笑出声……记号笔都没用上。")},
        {"if": {"var": {BURSTS: ["==", 0]}}, **line(P, "哼哼……（脚、脚底板还在发抖……）", "happy")},
        {"if": {"var": {BURSTS: [">=", 1]}}, **line(SUP, "笑出声的次数都记下来了。按老规矩，一次两工时。", None, [A("sfx", sound="book")])},
        {"if": {"var": {BURSTS: [">=", 3]}}, **line(CAP, "……笑得太多了。下午之前，去训练营转一次受罚转盘。", None, None, "captain")},
        {"if": {"var": {BURSTS: [">=", 3]}}, **line(P, "还、还有转盘——？！", "surprise")},
        {"if": {"var": {BURSTS: [">=", 3]}}, **line(BLUE, "……我陪你去。……看着。")},
        line(BLUE, "……鞋。", None, [A("bubble", who="b", kind="dots")]),
        line(P, "……谢谢。（……原来她是来送鞋的……）", "shy"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        {"actions": [A("despawn", who="b"), A("move", who=BLUE_NODE, to=[24.8, 24.6]), A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "广场足枷示众", "letterbox": True, "skippable": True, "end_dark": True, "steps": s}


CUTSCENES = {"after_d2_stocks": d2_stocks}
