"""第 2 天早上：广场足枷示众。
  after_d2_stocks        开场：锁上足枷、镇民围着夸她的脚（羞耻）、队长讲规矩 → 接着进小游戏（StocksShow）
  after_d2_stocks_end    撑过了时间：蓝色公主最后一个来，千手痒痒裤的小手偷戳脚心（「不算」），放人；按笑出声的次数结算
  after_d2_stocks_faint  魔力释放超过 5 次笑晕了：醒来在长椅上，蓝色公主绘声绘色地描述她昏过去以后孩子们怎么挠她的脚心，她脸红
变量：stocks_bursts（笑出声的次数，AfterStory 在结局过场前写好）。笑出声 3 次以上 → 训练营受罚转盘。
"""
from .common import A, BLUE, BLUE_NODE, CAP, N, P, line

STOCKS = "Stocks_23_24"
SUP, GRANNY, TOWN, TOM, KIDS = "市场监督", "面包店的奶奶", "镇民", "小汤姆", "小孩们"


def d2_stocks():
    s = [
        # 跟着的蓝色公主一早去训练室了：先挪到地图角落（结局再放回她身边）
        {"actions": [A("fade_out", time=0.0), A("move", who=BLUE_NODE, to=[60, 4]), A("hold", who=STOCKS), A("pose", emotion="shy", laugh=10),
                     A("spawn", id="v1", kind="npc:merchant", at=[27, 28], dir="left"),
                     A("spawn", id="v2", kind="npc:maid", at=[28, 27.5], dir="left"),
                     A("camera", to=[23, 26], zoom=1.0, time=0.1)], "wait": 0.3},
        {"actions": [A("fade_in", time=1.0), A("sfx", sound="stocks", volume=-4.0)], "wait": 1.0},
        line(N, "（第二天早上。广场正中间的足枷上，锁着一双光脚丫）"),
        line(P, "（为、为什么非要光着脚啊……！鞋子一早就被女仆小姐收走了……）", "shy"),
        {"actions": [A("move", who="v1", to=[24.6, 26.0], speed=50), A("move", who="v2", to=[25.4, 25.4], speed=50)], "wait": 1.2},
        line(TOWN, "哎呀，原来公主的脚这么小巧……白白嫩嫩的，像刚出炉的奶油小面包。", None, [A("bubble", who="v1", kind="happy")]),
        line(TOWN, "你看你看，脚趾头还会缩起来呢！一被看就缩一下，好可爱～", None, [A("hop", who="v2")]),
        line(P, "不、不准看！也不准评价！！", "angry", [A("shake", time=0.3)]),
        line(N, "（越是被盯着看，脚趾越是不听话地蜷成一团。脸烫得快要冒烟了）", None, [A("pose", emotion="shy")]),
        line(CAP, "示众到时辰为止。按老规矩：笑出声一次，加两工时。", None, [A("face", who="after_captain", dir="right")], "captain"),
        line(CAP, "还有——挣扎可以，乱放魔法不行。放一次，加时。", None, None, "captain"),
        line(SUP, "我来记。……账本、记号笔，都准备好了。", None, [A("hop", who="after_supervisor")]),
        {"actions": [A("move", who="after_kid_tom", to=[23, 25.6], speed=70)], "wait": 1.4},
        line(TOM, "姐姐！我说过要拿羽毛来的！后面还有好多人排队哦！", None, [A("hop", who="after_kid_tom")]),
        line(P, "排、排队……？！", "surprise"),
        {"actions": [A("despawn", who="v1"), A("despawn", who="v2")], "wait": 0.2},
    ]
    return {"name": "广场足枷示众", "letterbox": True, "skippable": True, "steps": s}


def d2_stocks_end():
    s = [
        {"actions": [A("hold", who=STOCKS), A("pose", emotion="helpless_1", laugh=40), A("camera", to=[23, 26], zoom=1.0, time=0.1),
                     A("move", who="after_kid_tom", to=[40, 26], speed=80)], "wait": 0.6},
        line(CAP, "……时间到。", None, None, "captain"),
        line(N, "（围观的人慢慢散了。她瘫在足枷上，脚趾还在一抽一抽地发抖）"),
        {"actions": [A("spawn", id="b", kind="npc:blue_princess", at=[31, 24], dir="left"), A("move", who="b", to=[24.8, 24.6], speed=40)],
         "wait": 2.2},
        line(N, "（一个蓝色的身影从训练室那边走了过来。头发乱糟糟的，走路有点晃）"),
        line(BLUE, "……还活着吗。"),
        line(P, "你、你来干什么啦……！说好了不准来看的！", "angry"),
        line(BLUE, "……说好了，最后一个来。……我是最后一个。"),
        line(P, "……那你的头发怎么了？", "surprise"),
        line(BLUE, "……特训。……别问。"),
        {"actions": [A("spawn", id="ph", kind="prop:pants_hand", at=[24.6, 24.8], z=2), A("move", who="ph", to=[23.3, 25.4], time=0.9)],
         "wait": 0.9},
        line(P, "呀啊！？谁、谁在挠——", "surprise", [A("tickle", who="princess", by="ph", zone="sole", fx="hand", repeat=4, interval=0.22)]),
        line(BLUE, "……不是我。……是它。"),
        line(N, "（裤子里伸出来的小手，正用指尖戳她的脚心——戳一下，缩回去，再戳一下，像在打招呼）"),
        line(SUP, "这、这一下算不算？"),
        line(CAP, "……不算。", None, [A("face", who="after_captain", dir="left")], "captain"),
        line(BLUE, "……乖。回来。", None, [A("move", who="ph", to=[24.8, 24.6], time=0.6)]),
        {"actions": [A("despawn", who="ph"), A("hold", who=STOCKS, on=False), A("sfx", sound="stocks"), A("pose", laugh=0)], "wait": 0.4},
        {"if": {"var": {"stocks_bursts": ["==", 0]}}, **line(SUP, "一次都没笑出声……记号笔都没用上。")},
        {"if": {"var": {"stocks_bursts": ["==", 0]}}, **line(P, "哼哼……（脚、脚底板还在发抖……）", "happy")},
        {"if": {"var": {"stocks_bursts": [">=", 1]}}, **line(SUP, "笑出声的次数都记下来了。按老规矩，一次两工时。", None, [A("sfx", sound="book")])},
        {"if": {"var": {"stocks_bursts": [">=", 3]}}, **line(CAP, "……笑得太多了。下午之前，去训练营转一次受罚转盘。", None, None, "captain")},
        {"if": {"var": {"stocks_bursts": [">=", 3]}}, **line(P, "还、还有转盘——？！", "surprise")},
        line(BLUE, "……鞋。", None, [A("bubble", who="b", kind="dots")]),
        line(P, "……谢谢。（……原来她是来送鞋的……）", "shy"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        {"actions": [A("despawn", who="b"), A("move", who=BLUE_NODE, to=[24.8, 25.6]), A("move", who="princess", to=[23, 26]),
                     A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "示众结束", "letterbox": True, "skippable": True, "end_dark": True, "steps": s}


def d2_stocks_faint():
    s = [
        {"actions": [A("fade_out", time=0.0), A("hold", who=STOCKS, on=False), A("move", who="princess", to=[21, 27.4]),
                     A("move", who="after_kid_tom", to=[40, 26]), A("spawn", id="b", kind="npc:blue_princess", at=[22.4, 27.6], dir="left"),
                     A("camera", to=[22, 28], zoom=1.0, time=0.1), A("pose", emotion="helpless_2", laugh=0)], "wait": 1.2},
        line(N, "（…………）"),
        line(N, "（……………………）"),
        {"actions": [A("fade_in", time=1.4)], "wait": 1.4},
        line(P, "……唔……这里是……", "helpless_1"),
        line(BLUE, "……醒了。"),
        line(P, "我……我怎么了……？足枷呢……？", "surprise"),
        line(BLUE, "……笑晕了。……第六次放魔法的时候。", None, [A("face", who="b", dir="left")]),
        line(BLUE, "……队长说，晕了的人不算示众。……放下来了。"),
        line(P, "笑、笑晕……？！我……我什么都不记得了……", "shy"),
        line(BLUE, "……我记得。……全部。"),
        line(P, "……全部？", "surprise"),
        line(BLUE, "……你晕过去以后，小孩们以为你在装睡。"),
        line(BLUE, "……汤姆扳开你的脚趾，莉莉拿狗尾巴草，一根一根地，从脚趾缝里穿过去。"),
        line(P, "等、等一下……", "shy"),
        line(BLUE, "……你的脚趾，就这样……一张一合。……像在跟草打招呼。"),
        line(BLUE, "……然后刷子。从脚跟，顺着脚弓，慢慢刷到前脚掌。……刷到前脚掌的时候，你在梦里笑出了声。"),
        line(P, "不、不要说了……！", "shy", [A("bubble", who="princess", kind="shy")]),
        line(BLUE, "……最后是羽毛。……在脚心画圈。顺时针三圈，逆时针三圈。……汤姆说，这样「最公平」。"),
        line(BLUE, "……你一边睡一边说「再来一次」。"),
        line(P, "我、我才没说！！绝对没说！！", "angry", [A("shake", time=0.3)]),
        line(BLUE, "……说了。……三次。"),
        line(N, "（她把脸埋进手心里，耳朵红得快要滴出血来）", None, [A("bubble", who="princess", kind="shy")]),
        line(BLUE, "……鞋。……给。", None, [A("bubble", who="b", kind="dots")]),
        line(P, "……呜……谢谢……", "shy"),
        line(BLUE, "……还有。……脚，很白。……镇上的人说的。"),
        line(P, "你也不准评价——！！", "angry"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        {"actions": [A("despawn", who="b"), A("move", who=BLUE_NODE, to=[22.4, 27.6]), A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "笑晕以后", "letterbox": True, "skippable": True, "end_dark": True, "steps": s}


CUTSCENES = {"after_d2_stocks": d2_stocks, "after_d2_stocks_end": d2_stocks_end, "after_d2_stocks_faint": d2_stocks_faint}
