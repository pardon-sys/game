"""弥补任务「矿车护送·双人轨道」（第 5 天下午，受损的矿道）：data/after/mine.json（TaskMine 读）+ 过场 + 失败小剧场。
粉色公主推着补给矿车，蓝色公主坐在车上。一条横向的长轨道，五段：
  装车（矿工教推车）→ 喷口段（挠痒粉喷口）→ 刷子段（旋转羽毛刷）→ 上坡（连按 → 推车，残党小鬼跳上车挠蓝色公主的大腿）→ 矿工营地。
按住 → 推车（闷笑越高越没力）；C 换成蓝色公主（车刹住）：J 冻住前方的陷阱几秒，再按 C 换回来推车。
上坡时小鬼跳上车：J 把它们拍下去（车上有小鬼推得更慢，蓝色公主被挠、千手痒痒裤跟着起哄）。
闷笑满：车往回溜到上一个检查点；溜回去三次 = 失败（after_fail_mine）。
  stages   每段：id、name、start / end 演的几句（两人在车上车下聊天）
  imp      小鬼：caption 挠蓝色公主的旁白、blue 她的反应、pants 裤子起哄、swat 拍下去时的字
"""
from .common import A, BLUE, N, P, line

MINER = "老矿工"
MINER2 = "矿工"

MINE = {
    "stages": [
        {"id": "load", "name": "装车",
         "start": [
             {"speaker": MINER, "text": "补给都在这儿了——药、面包、绷带，还有一桶热汤。营地的人等了一上午了。"},
             {"speaker": MINER, "text": "推车的诀窍：站在车屁股后面，往前一直推。别停，一停就得重新使劲。"},
             {"speaker": MINER2, "text": "蓝色的那位坐车上吧。前面的陷阱，得靠你冻住。"},
             {"speaker": BLUE, "text": "……坐车上？"},
             {"speaker": MINER2, "text": "车上视野好，能看清前面。冻住了，粉色的那位才推得过去。"},
             {"speaker": BLUE, "text": "……嗯。（她抱着膝盖，坐在了补给箱的上面）"},
             {"speaker": P, "text": "……为什么推车的是我，坐车的是你啊。", "emotion": "sad"},
             {"speaker": BLUE, "text": "……赎罪的是你。"},
             {"speaker": P, "text": "唔……无法反驳……", "emotion": "sad"},
             {"speaker": N, "text": "（按住 → 推车。C 换成蓝色公主（车刹住），J 冻住前方的陷阱，再按 C 换回来）"},
         ],
         "end": []},
        {"id": "vents", "name": "喷口段",
         "start": [
             {"speaker": N, "text": "（轨道两边的岩壁上，一排粉色的喷口「噗、噗」地冒着泡）"},
             {"speaker": MINER, "text": "（远远地喊）那些是攻防战的时候敌人装的痒痒粉喷口！拆了一半，剩下的还在喷！"},
             {"speaker": P, "text": "痒痒粉……是那种沾上就全身痒的粉吗……", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……我冻住它。你推。"},
             {"speaker": P, "text": "嗯！配合好哦！", "emotion": "happy"},
         ],
         "end": [
             {"speaker": N, "text": "（最后一个喷口被甩在了身后。粉色的雾气慢慢散开）"},
             {"speaker": P, "text": "呼……鼻子里还是痒痒的……哈、哈啾！", "emotion": "helpless_1"},
             {"speaker": BLUE, "text": "……粉，沾在你头发上了。"},
             {"speaker": P, "text": "诶？哪里哪里？", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……不告诉你。"},
             {"speaker": P, "text": "你、你这个人……！", "emotion": "angry"},
             {"speaker": BLUE, "text": "……（小声）……这条矿道，我以前走过。"},
             {"speaker": P, "text": "诶？什么时候？", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……很小的时候。……记不太清了。推车吧。"},
         ]},
        {"id": "brushes", "name": "刷子段",
         "start": [
             {"speaker": N, "text": "（前面的轨道上横着几根巨大的羽毛刷，「呼呼」地转着圈，刷毛扫过轨道，扬起一阵灰）"},
             {"speaker": P, "text": "……那个，扫过来的时候正好是脚的高度……", "emotion": "sad"},
             {"speaker": BLUE, "text": "……看准了再推。或者，等我冻住。"},
             {"speaker": P, "text": "冻住！冻住比较好！", "emotion": "surprise"},
         ],
         "end": [
             {"speaker": N, "text": "（羽毛刷的声音渐渐远了。矿道里安静下来，只剩车轮「咯噔咯噔」的声音）"},
             {"speaker": P, "text": "……你刚才说，小时候走过这条矿道？", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……嗯。"},
             {"speaker": P, "text": "跟谁？", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……"},
             {"speaker": BLUE, "text": "……一个，很吵的人。"},
             {"speaker": BLUE, "text": "……走在前面，一直说话。说矿道深处有宝藏。"},
             {"speaker": P, "text": "宝藏？那后来找到了吗？", "emotion": "happy"},
             {"speaker": BLUE, "text": "……没有。那个人在矿车上睡着了。……我推着车，把她推回去的。"},
             {"speaker": P, "text": "……诶？所以那时候推车的是你？", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……所以，这次轮到你推。"},
             {"speaker": P, "text": "这是什么道理啊！", "emotion": "angry"},
             {"speaker": N, "text": "（蓝色公主没有回答，转过头去看前面。车轮咯噔咯噔地响着）"},
         ]},
        {"id": "slope", "name": "上坡",
         "start": [
             {"speaker": N, "text": "（轨道开始往上爬。坡很陡，车轮一下子沉了下去）"},
             {"speaker": MINER2, "text": "（营地方向传来喊声）上坡要一下一下地使劲推！不然车会溜下来！"},
             {"speaker": N, "text": "（连按 → 推车上坡）"},
             {"speaker": N, "text": "（——坡道两边的矿石堆后面，探出了几个小小的脑袋。尖耳朵，红眼睛，手里攥着羽毛）"},
             {"speaker": "残党小鬼", "text": "嘻嘻！是那两个公主！"},
             {"speaker": "残党小鬼", "text": "车上的那个，腿上缠着千手大人的裤子！"},
             {"speaker": BLUE, "text": "……攻防战的残党。"},
             {"speaker": "残党小鬼", "text": "千手大人说过——蓝色的那个，大腿最怕痒！"},
             {"speaker": BLUE, "text": "……！"},
             {"speaker": N, "text": "（小鬼跳上车，J 把它们拍下去。车上的小鬼越多，推得越慢）"},
         ],
         "end": [
             {"speaker": N, "text": "（最后一个小鬼「哇呀」一声被拍飞了。矿车「咯噔」一声，翻过了坡顶）"},
             {"speaker": P, "text": "呼……呼……推、推上来了……", "emotion": "helpless_1"},
             {"speaker": BLUE, "text": "……"},
             {"speaker": P, "text": "……你没事吧？刚才被挠了好多下……", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……没事。"},
             {"speaker": P, "text": "可是你的腿在抖。", "emotion": "surprise"},
             {"speaker": BLUE, "text": "……是车在抖。"},
             {"speaker": N, "text": "（裤子上的小手「啪嗒」拍了一下她的大腿，像是在拆穿她）"},
             {"speaker": BLUE, "text": "……闭嘴。"},
         ]},
    ],
    "freeze": {
        "on": ["……冻住。", "……别动。", "……冰。", "……停下。"],
        "mode_on": "（换成蓝色公主：车刹住了。J 冻住前方的陷阱，C 换回去推车）",
        "mode_off": "（换回粉色公主推车）",
        "cooldown": "……还没好。",
        "nothing": "……前面没有东西可冻。",
    },
    "push_react": {
        "light": ["嘿、咻……！", "推、推得动！", "……车好重……", "加油加油……！"],
        "mid": ["哈……推、推不动了……笑得没力气……", "噗……手、手在抖……", "呜……别、别溜……"],
        "heavy": ["哈、哈……完、完全使不上劲……", "车、车要溜了……哈哈……", "不、不行了……手软了……"],
    },
    "slip": [
        {"speaker": N, "text": "（笑得手一软——矿车「咕噜噜」地往回溜了下去）"},
        {"speaker": P, "text": "啊啊啊！车、车——！", "emotion": "surprise"},
        {"speaker": BLUE, "text": "……抓紧。……（矿车一路溜回了刚才的地方）"},
        {"speaker": P, "text": "呜……白推了……", "emotion": "sad"},
    ],
    "imp": {
        "caption": ["（小鬼趴在补给箱上，伸手在蓝色公主的大腿上一下一下地挠）",
                    "（小鬼的羽毛顺着大腿外侧扫下去，又扫上来）",
                    "（两个小鬼一左一右，戳着她的腿根「嘻嘻」地笑）",
                    "（小鬼揪着裤子上的小手，让它们一起挠她的大腿）"],
        "blue": ["……！", "……别、碰……", "……唔……", "……下、去……", "……（腿缩了起来）", "……噗。……没、没笑。", "……可恶……"],
        "pants": ["（裤子上的小手跟着小鬼一起挠了起来）", "（千手痒痒裤「咯吱咯吱」地起哄）", "（裤子的手指在腿根上打着拍子）"],
        "swat": ["拍飞！", "下去！", "啪！", "走开！"],
        "jump": ["嘻嘻！上车咯！", "大腿！大腿！", "千手大人说的！", "让我挠一下！"],
    },
}


def d5_mine():
    s = [
        {"actions": [A("camera", to=[8, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(MINER, "来啦，赎罪的姑娘们。……今天这活儿，可不轻松。"),
        line(MINER, "攻防战的时候，敌人从矿道后面摸进来过。他们留下了一堆机关，把矿道弄得一团糟。"),
        line(MINER, "矿道深处有个矿工营地，十几个弟兄被困在那儿好几天了。路一通，就得赶紧把补给送过去。"),
        line(P, "所以要推着这辆矿车，一路推到最里面？", "surprise"),
        line(MINER, "对。轨道是我们连夜修好的，可两边的机关没拆干净。"),
        line(MINER2, "队长说，你们两个配合起来，什么机关都过得去。"),
        line(BLUE, "……队长说的？"),
        line(MINER2, "原话是：「一个笑得欢，一个冻得快，正好凑一对。」"),
        line(P, "那、那个「笑得欢」是什么意思啊！", "angry"),
        line(BLUE, "……说的是你。"),
        line(P, "我知道是我！", "angry"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "矿车护送", "letterbox": True, "skippable": True, "steps": s}


def d5_mine_done():
    s = [
        {"actions": [A("camera", to=[90, 6], zoom=1.0, time=0.5)], "wait": 0.5},
        line(N, "（矿车「咣当」一声停在了营地门口。几个灰头土脸的矿工围了上来）"),
        line(MINER2, "补给！补给到了！"),
        line(MINER2, "还有热汤！老天，好几天没喝到热的了……"),
        line(P, "呼……呼……送、送到了……", "helpless_1"),
        line(BLUE, "……（从车上跳下来，拍了拍裤子上的灰）"),
        line(MINER, "辛苦了，辛苦了。一路上的机关没少吃苦头吧？"),
        line(P, "吃了好多……苦头……", "sad"),
        line(MINER2, "说起来，矿道再往里走，有一扇很旧的门。上面刻着花纹，我们挖了几十年都没打开过。"),
        line(MINER2, "攻防战那几天，门缝里一直往外漏淡紫色的光。……跟广场上那根图腾柱的光一模一样。"),
        line(BLUE, "……"),
        line(P, "……旧门？", "surprise"),
        line(MINER, "嗐，别听他瞎说。那门几百年没人动过了。……姑娘们，喝口汤再回去吧。"),
        line(N, "（蓝色公主盯着矿道深处看了一会儿，什么都没说）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "补给送到了", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d5_mine": d5_mine, "after_d5_mine_done": d5_mine_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, who="princess", zone="sole", fx="brush", n=8, iv=0.22):
    return A("tickle", who=who, by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_MINE = {"name": "护送失败：翻车进刷子堆", "cast": {
    "princess": {"kind": "princess", "at": [-8, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "blue": {"kind": "npc:blue_princess", "at": [10, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "brush": {"kind": "trap:brush", "at": [0, 16]},
    "imp": {"kind": "monster:imp", "at": [30, 6]},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（矿车第三次往回溜——这一次没停住。车轮一歪，「咣当」一声翻倒在轨道边上）"),
    _say(P, "哇啊啊啊——！", emotion="surprise"),
    _say(N, "（两人连同一箱面包，一起滚进了轨道边上那堆废弃的羽毛刷里）"),
    _say(BLUE, "……！"),
    _say(N, "（刷子堆被一撞，残留的机关「咔哒」一声又转了起来。十几根刷毛同时扫向两个人）", [_tk("brush", zone="sole", n=10, iv=0.2), _tk("brush", who="blue", zone="thigh", n=10, iv=0.2)]),
    _say(P, "哈哈哈哈！刷、刷子又动了——！脚、脚心——！", portrait="defeat_1"),
    _say(BLUE, "……唔……！……大、大腿……"),
    _say(N, "（她们想爬出去，可是刷子堆太软，手一撑就陷进去。越挣扎，刷毛扫得越欢）"),
    _say(P, "哈哈……你、你别乱动……你一动我这边的刷子就转起来了……！", emotion="helpless_2"),
    _say(BLUE, "……是你……先动的……唔……"),
    _say(N, "（一个残党小鬼从矿石堆后面探出头来，看到这一幕，拍着手跳了出来）", [A("bubble", who="imp", kind="laugh")]),
    _say("残党小鬼", "嘻嘻嘻！两个都掉进刷子堆了！我来帮刷子一把！"),
    _say(N, "（小鬼扑上来，一手抓住粉色公主的脚踝，一手揪起蓝色公主裤子上的小手——让它们一起挠了起来）", [_tk("imp", zone="sole", fx="hand", n=12, iv=0.16), _tk("imp", who="blue", zone="thigh", fx="hand", n=12, iv=0.16)]),
    _say(P, "哈哈哈哈哈！不、不要抓脚踝——！", portrait="defeat_2"),
    _say(BLUE, "……噗。……哈……", [A("pose", who="blue", visual="helpless_2")]),
    _say(P, "……你、你刚才笑了吧！？哈哈哈……我听到了！", emotion="helpless_2"),
    _say(BLUE, "……没、有……哈……"),
    _say(N, "（直到老矿工举着镐头赶过来，把小鬼赶跑，两人才被一个一个地从刷子堆里拔了出来）"),
    _say(MINER, "……哎呀呀。补给还在，人也还在。……从头再推一遍吧。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_mine": FAIL_MINE}


DIALOGUES = {
    "after_mine_miner": {"name": MINER, "npc": "miner", "entries": [{"node": "default"}], "nodes": {
        "default": {"lines": [{"text": "站在车屁股后面推！冻陷阱的时候车会刹住，别慌。"}]}}},
    "after_mine_camp": {"name": MINER2, "npc": "miner", "entries": [{"node": "default"}], "nodes": {
        "default": {"lines": [{"text": "往里还有一扇旧门……攻防战那几天一直在漏光。我们谁都不敢靠近。"}]}}},
}
