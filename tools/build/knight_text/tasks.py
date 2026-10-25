"""骑士篇的玩法文本：data/after/knight.json（TaskStretcher 读 stretcher、TaskBait 读 bait、InterrogationChairShow 读 chair）+ 失败小剧场。
  stretcher  A 抬担架：手印碰到粉色公主（pat：很温和——伏笔「手印认得她」）/ 碰到队员（drop：他笑倒、担架一歪）
  bait       C 以笑为饵：手印贴在粉色公主身上（很轻、反而舒服）/ 蓝色公主身上（狠挠大腿）/ 镇民身上（偷走笑声）；冻住 / 收瓶 / 笑过头一群扑过来
  chair      D 夜探地牢被抓：挠痒审问椅（ErrandWorkStage 格式：phases / feedback / release / sensitive / done）
"""
from after_text.common import A, BLUE, N, P, L, event

GUARD = "保卫队员"

STRETCHER = {
    "pat": ["（一只手印爬到她脚边，停了一下——然后只是轻轻地拍了拍她的脚背，像在安慰她，就散成了一缕紫烟）",
            "（手印贴上她的脚踝，没有挠，只是用小小的手指碰了碰脚背，然后慢慢消失了）",
            "（手印绕着她的脚转了一圈，轻轻蹭了蹭脚心，很痒，又有点暖，然后散掉了）",
            "（那只手印碰到她，像认出了什么似的停住了，在脚背上拍了两下，化成了紫色的光点）"],
    "pat_react": ["……诶？不、不痒……？", "……它在……拍我？", "……有点痒……还、还有点舒服……", "……好奇怪……"],
    "drop": ["（手印扑上了前面队员的腰——他「噗」地笑出声，手一软，担架歪向了一边）",
             "（手印钻进了队员的护腿缝里，他笑得直跺脚，担架差点翻了）",
             "（队员被手印挠中了腋下，笑得整个人蹲了下去，担架「咚」地一声搁在了地上）"],
    "guard_laugh": ["哈、哈哈哈！痒——！", "噗哈！什、什么东西——！", "哈哈哈……抬、抬不动了……！"],
    "wait": ["你那头慢点……不对，快点跟上！", "后面的，跟上！", "别离太远，担架要掉了！"],
}

BAIT = {
    "pink_tick": ["（手印贴在她的脚心上，一下一下地挠——很轻，轻得像羽毛，挠得她脚趾慢慢松开了）",
                  "（手印在脚背上画着小圈，痒是痒，可是暖暖的，一点都不凶）",
                  "（手印钻进趾缝，轻轻地挠——比镇民们被挠的样子温柔得多）"],
    "pink_react": ["……哈……好、好轻……", "……为什么……这么舒服……", "唔……别、别这么温柔……", "……嘿嘿……痒……"],
    "blue_tick": ["（手印扑上蓝色公主的大腿，狠狠地挠——和挠粉色公主的时候完全不一样）",
                  "（手印在她的大腿内侧飞快地抓，一点都不手下留情）"],
    "blue_react": ["……唔！……凶……", "……对我……就这么……！", "……哈……不……公平……"],
    "npc_tick": ["（镇民张大了嘴想笑，却一点声音都发不出来——笑声被手印吸走了）"],
    "calm": ["（手印们躲着人走。……要让它们自己过来，就得笑）", "（得先笑起来——踩进痒痒草，或者踩上那些紫色的地纹）"],
    "mark": ["（地纹一亮——附近的一只手印像闻到了笑声，转身朝她爬了过来）", "（踩到诅咒地纹了！手印被招过来了）"],
    "swarm": ["（笑得太厉害了——整个广场的手印都转过身，朝她扑了过来！）", "（笑过头了！所有的手印都闻到了，一齐涌过来！）"],
    "freeze": ["（蓝色公主一挥手，一层薄冰「咔」地裹住了手印）", "（冻住了！紫色的手印变成了一块小小的冰）"],
    "bottled": "收进瓶子：%d / %d",
}


def ck(tool, caption, *replies, zone="sole"):
    return event(0, tool, caption, *replies, zone=zone)


CHAIR = {
    "name": "挠痒审问椅",
    "hint": "J 挣扎（手腕扣着，用处不大）\n撑过时间就放你走",
    "panel": "还剩 %d 秒\n笑出声 %d 次",
    "count": "还剩 %d 秒",
    "phases": [{"name": "审问", "tools": ["brush", "finger", "feather"]}],
    "question": ["谁让你来的？", "说！来见那个人干什么？", "队长说了不准靠近——你没听见？", "还不说？那就接着挠。"],
    "extra": ["笑出声了？还没问完呢——加时！", "笑了就是不老实。再来几下。"],
    "struggle": ["唔……！", "放、放开……！", "扣得好紧……！"],
    "feedback": [
        ck("brush", "（队员拿着一把小刷子，在她光着的脚心上「唰唰」地来回刷，一边刷一边问话）",
           "……我、我什么都不会说……", "……刷就刷……", "哈……别刷了……！", "噗……我说、我说……不对，我不说！",
           "哈哈哈……脚心……！", "哈哈……求你了……！"),
        ck("brush", "（刷子沿着足弓刷上去，刷到脚趾根又停下来，在趾缝里一下一下地戳）",
           "……趾缝……", "……不说……", "噗哈……戳、戳什么……！", "哈哈……那里不行……！",
           "哈哈哈……我投降……！", "哈哈……说、说什么都行……！"),
        ck("finger", "（另一个队员的手指在她腰侧飞快地抓，椅子被她扭得咯吱咯吱响）",
           "……腰、腰……", "……忍住……", "哈哈……别抓……！", "噗……椅、椅子要散了……！",
           "哈哈哈……投降……投降……！", "哈哈……腰……不行……！", zone="waist"),
        ck("finger", "（队员掰开她的脚趾，指甲在每一道趾缝里刮一下）",
           "……掰……", "……别掰……", "哈……刮、刮……！", "噗哈哈……一道一道的……！",
           "哈哈哈……脚趾……！", "哈哈……我、我只是迷路了……！"),
        ck("feather", "（一根长羽毛从脚跟扫到脚尖，扫完一只换另一只）",
           "……羽毛……", "……我、我不怕羽毛……", "噗……扫、扫过来了……！", "哈哈……换、换脚了……！",
           "哈哈哈……两只都……！", "哈哈……放、放我走……！"),
        ck("feather", "（羽毛尖在脚心正中间画圈，越画越小、越画越慢）",
           "……画、画圈……", "……别慢……", "噗……越、越来越……！", "哈哈……中间……！",
           "哈哈哈……停……！", "哈哈……我说……我说就是了……！"),
    ],
    "full": {"desc": "（她终于憋不住，「噗哈哈哈」地笑出了声，整张椅子都在抖）",
             "react": ["哈哈哈……我、我笑了……", "哈……不、不算……！"]},
    "release": {"desc": ["（魔力从脚底漫上来，暖暖的——被刷了半天的脚心一下子松快了，她靠在椅背上喘了口气）"],
                "react": ["……呼……舒服……", "……等等，我还被扣着！"], "tickler": ["……舒服了？那就接着问。"]},
    "sensitive": {"light": ["刚释放完……别碰！"], "mid": ["哈哈……现在不行……！"], "heavy": ["哈哈哈……太敏感了……！"]},
    "intro": [L("（被发现了！两个队员一左一右把她按在了审问椅上，手腕和脚踝「咔哒」一声扣住）", N),
              L("……又是你。这么晚了，跑到地牢来干什么？", GUARD),
              L("我、我只是……路过……", P, "sad"),
              L("路过通风口？……鞋脱了。", GUARD),
              L("（撑过时间就会被送回通风口。J 挣扎，笑出声会加时）", N)],
    "done": [L("……行了。嘴还挺硬。", GUARD), L("送回去。下次再让我看见，挠到天亮。", GUARD),
             L("（她被拎起来，塞回了通风口）", N)],
    "success_react": [],
}

KNIGHT = {"stretcher": STRETCHER, "bait": BAIT, "chair": CHAIR}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, who="princess", zone="sole", fx="hand", n=8, iv=0.22):
    return A("tickle", who=who, by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_STRETCHER = {"name": "抬担架失败：手印爬满了担架", "cast": {
    "princess": {"kind": "princess", "at": [-14, 8], "visual": "helpless_1", "anim": "helpless", "dir": "right"},
    "guard": {"kind": "npc:guard", "at": [14, 8], "dir": "left"},
    "hands": {"kind": "trap:maze_hand", "at": [0, -2]},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（担架第三次歪倒的时候，骑士盔甲上的手印像决了堤一样，一下子全涌了出来）"),
    _say(GUARD, "哇——！好、好多——！"),
    _say(N, "（手印爬满了队员的全身，钻进护腿、钻进袖口，挠得他在地上直打滚）", [_tk("hands", who="guard", zone="waist", n=10)]),
    _say(GUARD, "哈哈哈哈哈！救、救命——！"),
    _say(N, "（爬到她身上的那些，却只是轻轻地挠她的脚心——一点都不凶，挠得她浑身发软）", [_tk("hands", zone="sole", fx="feather", n=10, iv=0.3)]),
    _say(P, "哈……哈……为、为什么对我就这么轻……", emotion="helpless_1"),
    _say(N, "（好一会儿，手印才一只一只缩回了盔甲里。队员瘫在地上喘气）"),
    _say(GUARD, "……呼……呼……从、从头再抬一次吧……"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

FAIL_BAIT = {"name": "以笑为饵失败：被手印淹没", "cast": {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_2", "anim": "helpless", "dir": "down"},
    "blue": {"kind": "npc:blue_princess", "at": [22, 8], "visual": "normal", "anim": "idle", "dir": "left"},
    "hands": {"kind": "trap:maze_hand", "at": [0, -2]},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（笑声太响了——广场上所有的手印都扑到了她身上，脚心、脚背、趾缝、脚踝，一只叠着一只）"),
    _say(N, "（每一只都挠得很轻，可是一起挠，就一点都不轻了）", [_tk("hands", zone="sole", fx="feather", n=14, iv=0.18)]),
    _say(P, "哈哈哈哈！好、好多！太多了！轻、轻的也受不了啦——！", portrait="defeat_2"),
    _say(BLUE, "……！（冲过来，一挥手，一大片冰雾罩住了她的脚）"),
    _say(N, "（手印们「嗖」地一下全散开了，躲回了阴影里。……瓶子里抓到的，还在）"),
    _say(BLUE, "……饵，不是这么当的。"),
    _say(P, "哈……哈……下、下次……笑得小声一点……", emotion="helpless_1"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"knight_fail_stretcher": FAIL_STRETCHER, "knight_fail_bait": FAIL_BAIT}
