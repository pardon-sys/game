"""弥补任务「疏通排水管」（第 4 天早上，排水管 floor_06_after_drain）：data/after/drain.json（TaskDrain 读）+ 过场 + 失败小剧场。
镇上的排水管被攻防战的杂物堵住了，只有粉色公主钻得进去（呼应队长「小时候钻管道」的口误）。
趴着在一格宽的管道里爬：慢、转身慢。管道里的绒苔球（碰到就蹭腿和脚心，按住 E 擦掉）、老鼠。
脚露在外面：每爬过一段，管口外的小孩抓住她的脚挠——按 J 蹬腿挣扎。三处堵塞按住 E 擦洗，最后拉闸放水。
第二段管壁上有两个小女孩手拉手的旧涂鸦（伏笔，点到为止）。闷笑满 = 被小孩抓着脚拖出管子（after_fail_drain）。
  segments  三段：start 进这一段时演的几句、clog 擦堵塞时的几句、done 擦干净以后
  feet      管口外抓脚：grab 抓住时演的几句（按次数轮换）、caption 挠的描写、react 公主的反应（三档）、kid 小孩的话、kick 蹬开时
  moss      绒苔球：first 第一次碰到、caption、react
"""
from .common import A, CAP, N, P, back, burst, line

TOM, LILY, FAT = "小汤姆", "小莉莉", "小胖"
KIDS = "小孩们"
G = "保卫队员"

DRAIN = {
    "intro_lines": [
        {"speaker": N, "text": "（趴着往前爬：方向键。碰到绒苔球按住 E 擦掉。脚被抓住时按 J 蹬腿挣扎）"},
    ],
    "segments": [
        {"start": [
            {"speaker": N, "text": "（管道里又黑又窄，只能趴着往前爬。手肘和膝盖贴着冰凉的管壁，一点一点往前挪）"},
            {"speaker": P, "text": "……好窄。转个身都转不了……", "emotion": "sad"},
            {"speaker": N, "text": "（——身后传来窸窸窣窣的声音。她的两只光脚丫，正好露在管口外面）"},
            {"speaker": TOM, "text": "姐姐的脚在外面！"},
            {"speaker": P, "text": "汤、汤姆！？你们怎么跟过来了！", "emotion": "surprise"},
            {"speaker": LILY, "text": "……保卫队的哥哥说，让我们在外面「看着姐姐」。"},
            {"speaker": P, "text": "「看着」是用眼睛看！不准用手！", "emotion": "angry"},
         ],
         "clog": [
            {"speaker": N, "text": "（前面堵着一大团湿漉漉的东西——破布、羽毛、还有攻防战留下的痒痒粉泡沫，结成了一大坨）"},
            {"speaker": P, "text": "呜……好恶心……只能用手擦了……", "emotion": "sad"},
         ],
         "done": [
            {"speaker": N, "text": "（最后一团破布被扯了下来。管道深处「咕噜」一声，有一股凉风吹了过来）"},
            {"speaker": P, "text": "第一处……通了！", "emotion": "happy"},
         ]},
        {"start": [
            {"speaker": N, "text": "（第二段管道更旧了。管壁上长着一层软软的绿苔，摸上去毛茸茸的）"},
            {"speaker": N, "text": "（爬到一个拐角的时候，她的手停住了。管壁上，有一幅用石子划出来的旧涂鸦）"},
            {"speaker": N, "text": "（两个小小的女孩，手拉着手。一个画着长长的卷发，一个画着短短的直发。旁边歪歪扭扭地写着两个字，已经被苔藓盖住了）"},
            {"speaker": P, "text": "……", "emotion": "surprise"},
            {"speaker": P, "text": "……这个……好像在哪里见过……", "emotion": "sad"},
            {"speaker": N, "text": "（心里有什么东西轻轻地动了一下。可是想去抓住它的时候，它又不见了）"},
            {"speaker": TOM, "text": "姐姐？怎么不动了？脚丫都停了！"},
            {"speaker": P, "text": "……没、没什么。继续爬。", "emotion": "sad"},
         ],
         "clog": [
            {"speaker": N, "text": "（第二处堵塞：一窝攻防战逃进来的绒苔球挤在一起，把管道塞得满满的）"},
            {"speaker": P, "text": "毛、毛团……一碰就蹭过来……", "emotion": "surprise"},
         ],
         "done": [
            {"speaker": N, "text": "（毛团被一个一个擦散了。管道里又「咕噜」一声）"},
            {"speaker": P, "text": "第二处……！还剩最后一处！", "emotion": "happy"},
         ]},
        {"start": [
            {"speaker": N, "text": "（最后一段。管道开始往下斜，水声越来越近）"},
            {"speaker": G, "text": "（管口外面远远地喊）公主——！最后一处在总闸前面！擦干净了就拉闸！"},
            {"speaker": FAT, "text": "姐姐快到了！最后一下！大家一起挠！"},
            {"speaker": P, "text": "最、最后一下是什么意思啊！", "emotion": "angry"},
         ],
         "clog": [
            {"speaker": N, "text": "（总闸前面卡着一整块被冲进来的木板，上面缠满了攻防战的羽毛彩带）"},
            {"speaker": P, "text": "唔……好重……一点一点地拽……", "emotion": "sad"},
         ],
         "done": [
            {"speaker": N, "text": "（木板「咔」地一声被拽开了。总闸的拉杆就在眼前）"},
         ]},
    ],
    "feet": {
        "grab": [
            [{"speaker": N, "text": "（脚踝忽然被两只小手抓住了）"},
             {"speaker": TOM, "text": "抓住啦！姐姐的脚丫！"},
             {"speaker": N, "text": "（十根小手指在脚心上「咯吱咯吱」地挠——她趴在管道里，回头都回不了）"},
             {"speaker": P, "text": "哈、哈哈哈……！汤姆！我、我在里面动不了……！", "emotion": "helpless_1"}],
            [{"speaker": LILY, "text": "这次换我……（一根狗尾巴草，从脚跟慢慢地扫到脚趾尖）"},
             {"speaker": P, "text": "莉、莉莉……！哈哈……草、草穗……！", "emotion": "helpless_1"},
             {"speaker": N, "text": "（管道里的回声把她的笑声放大了好几倍，「哈哈哈」地一路传到深处）"}],
            [{"speaker": FAT, "text": "我带了刷子！（硬硬的刷毛，从脚心刷到脚趾缝）"},
             {"speaker": P, "text": "哈哈哈哈！刷、刷子不行——！管、管道里全是回声——！", "emotion": "helpless_2"},
             {"speaker": KIDS, "text": "姐姐的笑声变成三个了！"}],
            [{"speaker": N, "text": "（三个小孩一人一只脚趾，掰开——草穗、羽毛、手指一齐钻进了脚趾缝）"},
             {"speaker": P, "text": "哈哈哈……！一、一起来……犯规……！我、我要卡在里面了——！", "emotion": "helpless_2"}],
        ],
        "caption": ["（管口外的小手抓着脚踝，在脚心上来回地挠）", "（草穗从脚跟扫到脚尖，又扫回来）",
                    "（刷子一下一下地刷脚弓，管道里全是笑声的回音）", "（脚趾被一根根掰开，有东西在趾缝里钻）"],
        "react": {"light": ["……放、放开……", "唔……我在干活……", "……汤姆！", "别、别抓脚……"],
                  "mid": ["哈、哈哈……脚心……！", "噗……回、回声好大……！", "哈哈……蹬、蹬不开……！", "别、别挠了……我出不去……！"],
                  "heavy": ["哈哈哈……不、不行了……", "哈……卡、卡住了……", "哈哈……饶、饶了我……", "呜哈……脚、脚……"]},
        "kid": ["抓住啦！", "脚丫脚丫～", "姐姐踢我！", "再挠一下！", "别跑别跑！"],
        "kick": ["（一蹬腿，把小手蹬开了）", "（脚一缩，从小手里溜了出来）", "（蹬！小孩们「哇」地散开了）"],
    },
    "moss": {
        "first": [
            {"speaker": N, "text": "（前面的管壁上趴着一团绿茸茸的东西。她爬过去的时候，那团东西「扑」地一下贴了上来——）"},
            {"speaker": P, "text": "呀啊！？什、什么东西……毛茸茸的……！", "emotion": "surprise"},
            {"speaker": N, "text": "（绒苔球顺着她的小腿往下滚，一路滚到脚心，在脚底蹭来蹭去）"},
            {"speaker": P, "text": "哈、哈哈哈……！蹭、蹭脚心……！好、好痒——！", "emotion": "helpless_1"},
            {"speaker": N, "text": "（按住 E 把它擦掉）"},
        ],
        "caption": ["（绒苔球贴着小腿滚来滚去）", "（毛团钻到脚心，一圈一圈地蹭）", "（绿茸茸的苔毛扫过膝盖窝）"],
        "react": ["毛、毛团……！", "哈哈……别蹭……！", "痒、痒……擦掉擦掉……！", "噗……钻、钻到脚底了……！"],
        "wipe": ["擦掉了！", "走开走开！", "呼……"],
    },
    "flush": [
        {"speaker": N, "text": "（她伸手握住总闸的拉杆，使出全身的力气往下一拉——）"},
        {"speaker": N, "text": "（「轰隆隆隆——」积了好几天的水，一下子从头顶的管道里冲了下来）"},
        {"speaker": P, "text": "哇啊啊啊——！？", "emotion": "surprise"},
        {"speaker": N, "text": "（水流裹着她，从管道里一路滑了出去，「噗通」一声，冲进了管口外面的水沟里）"},
        {"speaker": KIDS, "text": "姐姐出来啦——！"},
        {"speaker": N, "text": "（她从泥水里爬起来，头发上挂着苔藓，脸上一道一道的黑泥）"},
        {"speaker": TOM, "text": "姐姐变成花猫了！"},
        {"speaker": P, "text": "花、花猫……", "emotion": "sad"},
    ],
}


def d4_drain():
    s = [
        {"actions": [A("camera", to=[6, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(G, "公主，这边！……就是这个排水口。"),
        line(G, "攻防战那几天，镇上的排水管被冲进去一堆杂物，全堵死了。昨晚下面的水沟都漫出来了。"),
        line(P, "那、那要怎么通？", "surprise"),
        line(G, "管子太窄，我们大人钻不进去。……队长说，你钻得进去。"),
        line(P, "队长说的……？", "surprise"),
        line(G, "原话是：「她钻得进去。她以前……」……后面的我没听清，队长自己咳嗽了一声就走了。"),
        line(P, "（……「以前」？……管道……前天队长递手帕的时候也说过……）", "sad"),
        line(G, "管子里有三处堵着的地方，擦干净以后，最里面有个总闸，拉下来就行。"),
        line(G, "……对了，攻防战的时候有一窝绒苔球钻进去了。那东西毛茸茸的，碰到人就蹭。小心点。"),
        line(P, "……为什么每次都要「对了」最后才说重要的事啊……", "sad"),
        line(N, "（她脱下鞋，趴下来，钻进了黑漆漆的管口。两只光脚丫留在了外面）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "疏通排水管", "letterbox": True, "skippable": True, "steps": s}


def d4_drain_done():
    s = [
        {"actions": [A("camera", to=[6, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(CAP, "（不知什么时候站在了水沟边上）……通了？"),
        line(P, "通、通了……（从泥水里坐起来，满脸都是泥）", "sad"),
        line(CAP, "……"),
        line(CAP, "（掏出手帕，递了过来）……又是这副样子。"),
        line(P, "……「又」？", "surprise"),
        line(CAP, "……擦擦吧。下午还有活。"),
        line(N, "（队长转过身走了。她拿着手帕，愣了一会儿）"),
        line(P, "……管壁上那幅画……还有队长说的「又」……", "sad"),
        line(TOM, "姐姐！手帕上绣着字！"),
        line(N, "（手帕的角落里，用褪了色的线绣着一个小小的、歪歪扭扭的图案——两个手拉手的小人）"),
        line(P, "……", "surprise"),
        line(N, "（她把手帕叠好，收进了口袋里）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
        {"actions": [A("goto", to="floor_06_after", spawn="from_drain")], "wait": 0.2},
    ]
    return {"name": "排水管通了", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d4_drain": d4_drain, "after_d4_drain_done": d4_drain_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, zone="sole", fx="hand", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_DRAIN = {"name": "通管失败：被拖出管子", "cast": {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "k1": {"kind": "npc:kid", "at": [-20, 22], "dir": "right"},
    "k2": {"kind": "npc:kid", "at": [0, 26], "dir": "up"},
    "k3": {"kind": "npc:kid", "at": [20, 22], "dir": "left"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（笑得浑身发软，再也爬不动了。管口外面的小孩们一人抓住一只脚踝——）"),
    _say(KIDS, "一、二、三——拔萝卜！"),
    _say(N, "（「哧溜」一声，她被整个儿从管道里拖了出来，仰面躺在了管口外的石板上）"),
    _say(P, "哇啊——！？", emotion="surprise"),
    _say(TOM, "拔出来啦！姐姐是大萝卜！"),
    _say(N, "（还没来得及爬起来，三个小孩已经扑了上来——一人抱住一只脚，一人骑在腿上）", [_tk("k1", n=10), _tk("k3", n=10)]),
    _say(P, "哈哈哈哈！不、不要一起——！我、我刚从管子里出来——！", portrait="defeat_1"),
    _say(LILY, "姐姐的脚底黑黑的……我帮你擦干净！（用袖子在脚心上来回地擦）", [_tk("k2", fx="brush", n=12, iv=0.16)]),
    _say(P, "那、那不是擦！那是挠——哈哈哈哈！", emotion="helpless_2"),
    _say(N, "（小胖蹲到她脚边，盯着她蜷成一团的脚趾看了半天，慢慢伸出了一根小手指）"),
    dict(_say(FAT, "脚趾缝里也有泥！（小手指一根一根地抠进脚趾缝）", [_tk("k3", n=12, iv=0.16)], portrait="defeat_2"), cg=True),
    _say(P, "哈哈哈哈哈！脚、脚趾缝不用擦——那里没有泥——真的没有——！", [A("bubble", who="princess", kind="laugh")]),
    _say(TOM, "脚弓也要擦！脚跟也要擦！", [_tk("k1", fx="feather", n=12, iv=0.16), A("pose", who="princess", visual="helpless_2")]),
    _say(N, "（汤姆用一根捡来的羽毛顺着她的脚弓来回扫，莉莉的袖子在脚心上画圈，小胖的手指还卡在趾缝里，一道一道地抠）",
         [_tk("k1", fx="feather", n=10, iv=0.16), _tk("k3", n=10, iv=0.16)]),
    _say(P, "哈哈哈！三、三个人分工——不公平——我只有两只脚——！"),
    _say(LILY, "那正好！一只脚一个半人！", [_tk("k2", fx="brush", n=10, iv=0.16)]),
    _say(P, "一、一个半人是什么啊哈哈哈！小胖你——你的手指别在里面转——！", [A("shake", who="princess", time=0.5)]),
    _say(N, "（「擦干净」变成了「挠一遍」，「挠一遍」又变成了「再挠一遍」。钻管子时攒下的魔力疲倦被一点点挠满，她的身体开始发光）",
         [_tk("k1", n=8, iv=0.18), _tk("k3", n=8, iv=0.18)]),
    _say(P, "等、等等……魔力……要出来了……你们快退开——！"),
    dict(_say(N, "（星光从她身上炸开，三个小孩被冲得一屁股坐倒，羽毛和袖子上的泥点飞了一地）",
              burst("princess", [("k1", [-20, 22]), ("k2", [0, 26]), ("k3", [20, 22])])), act="burst", wait=1.0),
    _say(P, "哈啊……魔力……一口气全放出去了……躺在石板上……凉凉的……好舒服……", emotion="happy"),
    _say(TOM, "哇——！姐姐会发光！再发一次！", back([("k1", [-20, 22]), ("k2", [0, 26]), ("k3", [20, 22])]) + [A("hop", who="k1")]),
    _say(P, "不、不会再发了……呀啊——！只、只是碰一下脚心……怎么痒成这样——！", [_tk("k1", n=6, iv=0.2)], emotion="helpless_2"),
    _say(FAT, "姐姐变得更怕痒了！刚才要挠十下，现在一下就够！", [_tk("k3", n=6, iv=0.2)]),
    _say(N, "（放空魔力的身体敏感得要命。小孩们发现了新玩法：轻轻一碰，她就弹起来——碰一下脚跟，碰一下脚趾，碰一下足弓，像在弹一架会笑的琴）",
         [_tk("k1", n=10, iv=0.15), _tk("k2", fx="feather", n=10, iv=0.15), _tk("k3", n=10, iv=0.15)]),
    _say(P, "哈哈哈哈！别、别弹琴——我不是琴——求求你们——姐姐认输了——！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.6)]),
    _say(LILY, "认输就要唱歌！唱完才放你！", [_tk("k2", fx="brush", n=8, iv=0.18)]),
    _say(P, "唱、唱什么啊……哈哈……啦、啦啦……哈哈哈唱不下去——！"),
    _say(G, "（远远地跑过来）喂喂喂！小鬼们！让公主歇一会儿！"),
    _say(KIDS, "……是——"),
    _say(P, "哈……哈……我、我歇好了……从、从头再钻……", emotion="helpless_1"),
    _say(G, "……先喘口气吧。管子又不会跑。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_drain": FAIL_DRAIN}
DIALOGUES = {"after_drain_objects": {"name": "", "entries": [{"node": "graffiti"}], "nodes": {
    "graffiti": {"lines": [{"speaker": N, "text": "（两个手拉手的小女孩。一个卷发，一个直发。旁边的字被苔藓盖住了）"},
                           {"speaker": P, "text": "……", "emotion": "sad"}]}}}}
SIGNS = {"after_drain_locked": [{"speaker": N, "text": "（排水口的铁栅栏锁着。里面黑漆漆的，传出一股潮湿的味道）"}]}
