"""弥补任务「修补狂欢图腾柱」（第 7 天，早上开始一直做到傍晚；图腾柱废地 floor_06_after_totem）：data/after/totem.json（TaskTotem 读）+ 过场 + 失败小剧场。
三块封印石从采石角扛到图腾柱底座（扛着走得慢，不能攻击 / 冲刺 / 施法）。一块比一块难：
  第一块：零星的痒痒草（踩到缠腰）。
  第二块：痒痒草会慢慢往人这边蔓延（新长出来的草丛）。
  第三块：再加上千手痒痒裤因为图腾共振一阵阵失控——先发光预警，然后小手伸长挠粉色公主的脚心和腰；
          换成蓝色公主（C）按住 E「安抚」几秒，裤子的手转过来挠她自己（大腿 / 屁股），之后安静一阵，粉色公主趁机走过去。
闷笑满：石头摔在原地（重新扛）；同一块摔三次 = 失败（after_fail_totem）。每块之间歇一会儿：镇民送水，蓝色公主和她聊这七天。
  stones    每块：start 开扛前的几句、placed 放好以后、rest 歇脚时的对话
  grass     缠住时：caption 旁白、react 反应字（三档）
  surge     裤子失控：warn 预警、caption 挠粉色公主的旁白、pink 她的反应、soothe 蓝色公主安抚时（caption / blue 她的反应）、calm 安静下来
"""
from .common import A, BLUE, MAYOR, N, P, line

ENG = "工匠"
TOWN = "镇民们"
TOM, LILY = "小汤姆", "小莉莉"
CAP = "保卫队队长"

TOTEM = {
    "intro_lines": [
        {"speaker": N, "text": "（走到采石角，扛起封印石：E。扛着的时候不能攻击、冲刺、施法。闷笑满了石头会摔在地上）"},
    ],
    "stones": [
        {"start": [
            {"speaker": ENG, "text": "第一块！地上那些开粉花的草，是图腾漏出来的能量长出来的。踩上去会被缠住。"},
            {"speaker": P, "text": "又是那个草……捡苹果的时候被缠过好几次了。", "emotion": "sad"},
            {"speaker": ENG, "text": "绕着走就行。石头重，别急。"},
         ],
         "placed": [
            {"speaker": N, "text": "（「咚」的一声，封印石落进了图腾柱底座的第一个凹槽。图腾柱的裂缝里，淡紫色的光暗了一点）"},
            {"speaker": ENG, "text": "好！第一块，稳稳当当！"},
            {"speaker": TOWN, "text": "（围在废地外面的镇民们拍起了手）"},
         ],
         "rest": [
            {"speaker": LILY, "text": "姐姐，喝水！（小莉莉捧着一个比她脸还大的水瓢跑过来）"},
            {"speaker": P, "text": "谢谢莉莉～……咕嘟咕嘟……活过来了。", "emotion": "happy"},
            {"speaker": BLUE, "text": "……（坐在旁边的石头上，看着她喝水）"},
            {"speaker": P, "text": "……干嘛一直看着我。", "emotion": "surprise"},
            {"speaker": BLUE, "text": "……第一天。你搬砖的时候，也是这么喝水的。"},
            {"speaker": P, "text": "第一天……感觉已经是好久以前的事了。", "emotion": "sad"},
            {"speaker": BLUE, "text": "……六天前。"},
            {"speaker": P, "text": "我知道是六天前！我是说「感觉」！", "emotion": "angry"},
            {"speaker": BLUE, "text": "……嗯。（嘴角好像动了一下）"},
         ]},
        {"start": [
            {"speaker": ENG, "text": "第二块……哎呀，草长得更多了。"},
            {"speaker": N, "text": "（废地上的痒痒草像是闻到了什么，开始一点一点地往她这边蔓延，新的草丛一丛接一丛地冒出来）"},
            {"speaker": P, "text": "它、它们在动！？草是会动的吗！？", "emotion": "surprise"},
            {"speaker": ENG, "text": "图腾的能量越来越不稳了。快，趁它们还没长满！"},
         ],
         "placed": [
            {"speaker": N, "text": "（第二块封印石落进了凹槽。图腾柱「嗡」地震了一下，蔓延的草丛停了下来）"},
            {"speaker": ENG, "text": "两块了！还剩最后一块！"},
         ],
         "rest": [
            {"speaker": TOM, "text": "姐姐，给你扇扇子！（小汤姆拿着一片大叶子，呼哧呼哧地扇）"},
            {"speaker": P, "text": "呼……凉快……", "emotion": "happy"},
            {"speaker": BLUE, "text": "……第二天。示众。"},
            {"speaker": P, "text": "不、不准提那个！", "emotion": "angry"},
            {"speaker": BLUE, "text": "……你笑得，全镇都听得见。"},
            {"speaker": P, "text": "所以说不准提！", "emotion": "angry"},
            {"speaker": BLUE, "text": "……"},
            {"speaker": BLUE, "text": "……第三天，配药。第四天，梯子、羊、跳舞、按摩。第五天，棉衣、矿车。"},
            {"speaker": P, "text": "……你全都记得啊。", "emotion": "surprise"},
            {"speaker": BLUE, "text": "……都在旁边看着。"},
            {"speaker": P, "text": "……", "emotion": "shy"},
            {"speaker": P, "text": "……谢谢你，一直在旁边。", "emotion": "shy"},
            {"speaker": BLUE, "text": "……扛石头去。"},
            {"speaker": P, "text": "知道啦！", "emotion": "happy"},
         ]},
        {"start": [
            {"speaker": ENG, "text": "最后一块！这块最大，共振也最强——"},
            {"speaker": N, "text": "（话音未落，蓝色公主腿上的千手痒痒裤忽然一亮，裤子上的小手齐刷刷地伸长了，朝粉色公主的方向探过来）"},
            {"speaker": BLUE, "text": "……！裤子……不听话了。"},
            {"speaker": ENG, "text": "是图腾的共振！那条裤子是千手的东西，被图腾一震就失控了！"},
            {"speaker": P, "text": "那、那怎么办！它在往我这边伸！", "emotion": "surprise"},
            {"speaker": BLUE, "text": "……我按住它。（她把手按在了裤子上）……让它挠我。你，趁机走。"},
            {"speaker": P, "text": "让它挠你……？可是你最怕——", "emotion": "surprise"},
            {"speaker": BLUE, "text": "……少废话。"},
            {"speaker": N, "text": "（裤子发光的时候：C 换成蓝色公主，按住 E 安抚它几秒，再换回来扛石头）"},
         ],
         "placed": [
            {"speaker": N, "text": "（第三块封印石落进了最后一个凹槽——）"},
         ],
         "rest": []},
    ],
    "pick": ["嘿——咻！好、好重……！", "扛、扛起来了……！", "唔……这块比刚才还重……"],
    "drop": [
        [{"speaker": N, "text": "（笑得腿一软——封印石「咚」地一声砸在了地上）"},
         {"speaker": P, "text": "啊……石、石头……！", "emotion": "sad"},
         {"speaker": ENG, "text": "没事没事，石头摔不坏！捡起来接着走！"}],
        [{"speaker": N, "text": "（又摔了。封印石在草丛边上滚了半圈）"},
         {"speaker": P, "text": "呜……又要重新扛……", "emotion": "sad"},
         {"speaker": BLUE, "text": "……再摔一次，就不行了。"}],
    ],
    "grass": {
        "caption": ["（草茎「唰」地缠上了腰，一圈一圈地收紧，草叶在腰侧扫来扫去）",
                    "（藤蔓顺着脚踝爬上来，花穗钻进脚心，一边缠一边扫）",
                    "（缠在腰上的草叶在肋骨下面乱戳，扛着石头的手臂一抖一抖）",
                    "（草丛里伸出好几根细茎，同时挠着腰侧和脚底）"],
        "react": {"light": ["……又、又是这个草……", "唔……放开……", "……扛着石头呢……", "……别、别缠了……"],
                  "mid": ["哈、哈哈……腰、腰……！", "噗……石、石头要掉了……！", "脚心……花穗钻进来了……！", "哈哈……缠、缠得好紧……！"],
                  "heavy": ["哈哈哈……不、不行了……手、手软了……", "哈……石头……拿不住了……", "哈哈……求、求你了草……", "呜哈……全身都……"]},
    },
    "pulse": ["（图腾「嗡」地脉动了一下——地上看不见的草全都伸长了）", "（共振！紫光一圈圈扩散，草叶一下子竖了起来）",
              "（图腾又在脉动……趁它安静的时候快走）"],
    "hidden_first": [
        {"speaker": P, "text": "呀！？什、什么都没有的地方……怎么会缠上来！？", "emotion": "surprise"},
        {"speaker": ENG, "text": "那些草被图腾的能量泡久了，平时看不见！踩到一次才会显出来！"},
        {"speaker": ENG, "text": "还有——图腾每隔一会儿会「嗡」地脉动一下，那时候草会伸长！等它安静了再走！"},
        {"speaker": P, "text": "看、看不见的草，还会伸长……这也太欺负人了吧……！", "emotion": "helpless_1"},
    ],
    "spread": ["（又一丛痒痒草从地里冒了出来，离她更近了）", "（草丛在蔓延……）", "（新的粉色小花一朵接一朵地开）"],
    "surge": {
        "warn": ["（千手痒痒裤开始发光——小手在颤抖）", "（裤子又亮起来了！）", "（蓝色公主腿上的光越来越亮……）"],
        "caption": ["（裤子上的小手伸得老长，伸到粉色公主脚边，十几根手指一齐挠脚心）",
                    "（小手绕到她身后，在腰侧「咯吱咯吱」地挠，扛石头的手臂一下子软了）",
                    "（小手钻进她的裙摆下面，在膝盖窝和脚踝之间来回地挠）"],
        "pink": ["哈哈哈！裤、裤子的手……伸过来了——！", "呀哈！脚、脚心！放开！", "噗哈哈……腰、腰……石头要掉了……！", "哈哈……蓝、蓝色的！你的裤子——！"],
        "soothe_caption": ["（她按住发光的裤子。小手们犹豫一下，转过身，齐刷刷挠向她自己的大腿）",
                           "（小手们从大腿外侧挠到大腿内侧，又转去挠她的屁股，挠得她整个人一缩）",
                           "（她咬着嘴唇按住裤子，小手们在她的腿根上打着拍子，挠得她肩膀直抖）"],
        "blue": ["……唔……！", "……没、事……", "……快、走……", "……噗。……不、算……", "……别、看我……", "……（腿在发抖）"],
        "calm": ["（裤子的光暗了下去，小手们缩回去，安静了）", "（千手痒痒裤安静下来了）"],
    },
    "finish": [
        {"speaker": N, "text": "（——图腾柱发出一阵柔和的光。歪掉的柱身「咔、咔」地一节一节扶正，裂缝慢慢合拢）"},
        {"speaker": N, "text": "（三张彩色的笑脸亮了起来，顶上的羽毛「呼」地一下张开，在风里轻轻地抖）"},
        {"speaker": TOWN, "text": "哇——！图腾柱修好了！"},
        {"speaker": N, "text": "（废地上的痒痒草一丛丛地缩回了地里，只留下几朵粉色的小花）"},
        {"speaker": BLUE, "text": "……（裤子安静下来。她松开手，长长地出了一口气）"},
        {"speaker": P, "text": "……你没事吧？刚才被裤子挠了好多下……", "emotion": "surprise"},
        {"speaker": BLUE, "text": "……没事。"},
        {"speaker": P, "text": "你的脸好红。", "emotion": "surprise"},
        {"speaker": BLUE, "text": "……是图腾的光。"},
        {"speaker": P, "text": "……嘿嘿。", "emotion": "happy"},
    ],
}


def d7_totem():
    s = [
        {"actions": [A("camera", to=[30, 12], zoom=1.0, time=0.5)], "wait": 0.5},
        line(MAYOR, "七天了。……最后一天，最后一件事。"),
        line(MAYOR, "狂欢图腾柱，是我们小镇的守护。它被敌人撞歪以后，能量一直从裂缝里往外漏——那些开粉花的草，就是漏出来的能量长出来的。"),
        line(ENG, "要把它扶正，得在底座上嵌三块封印石。石头在那边的采石角，一块比一块重。"),
        line(ENG, "我示范一下怎么扛——（他弯腰抱起一块小石头，憋红了脸，走了三步就放下了）……就、就是这样。"),
        line(P, "……你连那块小的都扛不动吗。", "sad"),
        line(ENG, "我、我这是示范！示范！"),
        line(MAYOR, "图腾柱里的能量，会和千手留下的东西共振。……蓝色的那位，你腿上的裤子，可能会不太安分。"),
        line(BLUE, "……知道了。"),
        line(CAP, "修好图腾柱，七天的工时就清了。今晚——庆功宴。"),
        line(P, "庆功宴……！", "happy"),
        line(CAP, "……前提是修得好。"),
        line(P, "修得好！一定修得好！", "angry"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "修补狂欢图腾柱", "letterbox": True, "skippable": True, "steps": s}


def d7_totem_done():
    s = [
        {"actions": [A("camera", to=[30, 12], zoom=1.0, time=0.5)], "wait": 0.5},
        line(MAYOR, "……好，好啊。图腾柱，七年没这么亮过了。"),
        line(CAP, "（看着赎罪簿，在最后一行上画了一笔）……一百个工时。还清了。"),
        line(P, "……还、还清了？真的？", "surprise"),
        line(CAP, "真的。"),
        line(P, "太、太好了——！", "happy"),
        line(N, "（她一下子坐倒在地上，长长地呼了一口气。镇民们欢呼着围了上来）"),
        line(TOM, "姐姐好厉害！"),
        line(LILY, "姐姐今晚要领舞哦！"),
        line(CAP, "……今晚的庆功宴，主角是你们两个。……好好准备。"),
        line(BLUE, "……主角？"),
        line(CAP, "你也是。……这七天，你一直在旁边。我都看见了。"),
        line(BLUE, "……"),
        line(N, "（天色暗了下来。广场那边，篝火已经点起来了）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "图腾柱亮了", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d7_totem": d7_totem, "after_d7_totem_done": d7_totem_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, who="princess", zone="waist", fx="feather", n=8, iv=0.22):
    return A("tickle", who=who, by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_TOTEM = {"name": "修图腾失败：被痒痒草缠在一起", "cast": {
    "princess": {"kind": "princess", "at": [-8, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "blue": {"kind": "npc:blue_princess", "at": [10, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "vine": {"kind": "trap:vine", "at": [0, 14]},
    "hands": {"kind": "monster:thousand_hand", "at": [0, -16], "scale": 0.4},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（封印石第三次砸在地上。这一次，周围的痒痒草像是等了很久一样，一下子全都扑了上来）"),
    _say(P, "哇啊——！草、草——！", emotion="surprise"),
    _say(N, "（蓝色公主冲过来想拉她，结果两个人一起被草茎缠住，背靠背地捆在了一起）"),
    _say(BLUE, "……！"),
    _say(N, "（草叶钻进腰侧，花穗扫过脚心——两个人被捆得紧紧的，谁动一下，另一个人身上的草就缠得更紧）",
         [_tk("vine", zone="waist", n=10, iv=0.2), _tk("vine", who="blue", zone="thigh", n=10, iv=0.2)]),
    _say(P, "哈哈哈哈！你、你别动！你一动我这边就——哈哈哈！", portrait="defeat_1"),
    _say(BLUE, "……是你……在动……唔……"),
    _say(N, "（就在这时，千手痒痒裤被图腾的共振一震，小手们一齐亮了起来）", [A("bubble", who="hands", kind="laugh")]),
    _say(BLUE, "……糟了。"),
    _say(N, "（小手们一半挠向蓝色公主自己的大腿，一半伸长了，越过她的肩膀，挠向背后粉色公主的胳肢窝）",
         [_tk("hands", who="blue", zone="butt", fx="hand", n=12, iv=0.16), _tk("hands", zone="armpit", fx="hand", n=12, iv=0.16)]),
    _say(P, "哈哈哈哈哈！胳、胳肢窝！你的裤子在挠我胳肢窝——！", portrait="defeat_2"),
    _say(BLUE, "……噗。……哈……哈……", [A("pose", who="blue", visual="helpless_2")]),
    _say(P, "你、你笑了！你又笑了！哈哈哈……我都听见了！", emotion="helpless_2"),
    _say(BLUE, "……没……哈……没有……"),
    _say(N, "（草茎、花穗、小手，从腰到脚心，从大腿到胳肢窝。两个人背靠背地笑成一团，笑声在废地上回荡了好久）"),
    _say(ENG, "（终于拿着镰刀赶过来，一根一根割断草茎）……哎呀呀。石头还在原地呢。"),
    _say(ENG, "……歇一会儿，从这一块重新扛吧。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_totem": FAIL_TOTEM}

DIALOGUES = {
    "after_totem_eng": {"name": ENG, "npc": "miner", "entries": [{"node": "default"}], "nodes": {
        "default": {"lines": [{"text": "石头在采石角！扛到图腾柱底座上！……慢点，别被草缠住。"}]}}},
}
DIALOGUES["after_totem_objects"] = {"name": "", "entries": [{"node": "totem"}], "nodes": {
    "totem": {"lines": [{"speaker": N, "text": "（歪掉的狂欢图腾柱。底座上有三个凹槽，等着封印石嵌进去）"}]}}}
SIGNS = {"after_totem_locked": [{"speaker": N, "text": "（西边的小路通往图腾柱废地。牌子上写着：「危险——第七天之前不得入内」）"}]}
