"""蓝色公主的特训（队长的训练室 floor_06_after_drill）：data/after/drill.json（IceSitShow / PantsTameShow / TaskDrill 读）+ 过场 + 失败小剧场。
第 4 天下午：第一课「冰封静坐」、第二课「驯裤」；第 6 天下午：第三课「借手」+ 考核（下一批）。操控蓝色公主。
蓝色公主：寡言、短句、嘴硬；怕痒的是大腿和屁股（还有腰、膝盖窝）。队长：严厉、偶尔说漏嘴。粉色公主：在旁边围观起哄。
共同规则：魔力疲倦满 → 自动释放（release）→「释放后敏感」15 秒（挠痒加倍、表情掉得快；sensitive 反应字、队长加码 cap_sensitive）；
一节课释放超过 3 次 = 这节课重来（redo）。
  lessons.<id>   intro 开场 / tutorial 规则 / end 下课 / redo 重来 / break 破功（表情掉光）/ spots 部位（名字、键、部位 id）……
  react          蓝色公主的反应（light / mid / heavy / sensitive 四套）
  cap / pink     队长 / 粉色公主边挠边说的话
"""
from .common import A, BLUE, CAP, N, P, line

B = BLUE

DRILL = {
    "release": [
        [{"speaker": N, "text": "（憋了太久的魔力「嘭」地炸开——冰晶四散，训练室里下起了一阵小小的雪）"},
         {"speaker": B, "text": "……！"},
         {"speaker": CAP, "text": "……释放了。现在是最软的时候。"},
         {"speaker": P, "text": "诶？最软的时候？", "emotion": "surprise"},
         {"speaker": CAP, "text": "魔力刚放完，身子空空的，挠一下顶平时两下。……记住这个感觉，殿下。"},
         {"speaker": B, "text": "……别、过来……"}],
        [{"speaker": N, "text": "（又是一阵冰晶。她的肩膀一下子松了下来）"},
         {"speaker": CAP, "text": "第二次。……太快了。"},
         {"speaker": P, "text": "队长，你、你笑了吧？刚才嘴角动了吧！", "emotion": "surprise"},
         {"speaker": CAP, "text": "没有。"}],
        [{"speaker": N, "text": "（第三次。冰晶落在她的睫毛上，她咬着嘴唇，眼眶有点红）"},
         {"speaker": CAP, "text": "……再放一次，这节课就重来。"},
         {"speaker": B, "text": "……知、道。"}],
    ],
    "lessons": {
        "ice": {
            "name": "第一课：冰封静坐",
            "intro": [
                {"speaker": CAP, "text": "第一课。坐上去。"},
                {"speaker": N, "text": "（训练室正中间摆着一张冰台。冰面磨得光溜溜的，冒着白气）"},
                {"speaker": B, "text": "……冰的。"},
                {"speaker": CAP, "text": "冰的。你的魔法也是冰的。……坐。"},
                {"speaker": N, "text": "（她犹豫了一下，还是坐了上去。冰凉透过裙子一下子窜了上来，她的背一下子挺直了）"},
                {"speaker": P, "text": "哇……看着就好冷……", "emotion": "surprise"},
                {"speaker": CAP, "text": "殿下的问题，我看了七年了。"},
                {"speaker": B, "text": "……七年？"},
                {"speaker": CAP, "text": "……咳。看了「好几天」了。"},
                {"speaker": CAP, "text": "你怕痒，可你从来不承认。别人一挠，你就板着脸硬撑，撑到撑不住，「噗」地一下全漏出来。"},
                {"speaker": B, "text": "……没有。"},
                {"speaker": CAP, "text": "现在就有。……今天教你一个办法：别硬撑，把要被挠的地方，先冻住。"},
                {"speaker": B, "text": "……冻住？"},
                {"speaker": CAP, "text": "冰魔法，用在自己身上。冻麻了的地方，挠了也没感觉。"},
                {"speaker": CAP, "text": "……可是冻多了，你会冷。冷到发抖，脸一样绷不住。"},
                {"speaker": P, "text": "所以要冻在刚刚好的地方……？", "emotion": "surprise"},
                {"speaker": CAP, "text": "对。……你来当我的助手。拿着这根羽毛，站到那边去，给殿下加油。"},
                {"speaker": P, "text": "加油？用羽毛加油？", "emotion": "surprise"},
                {"speaker": CAP, "text": "……你会用得上的。"},
            ],
            "tutorial": [
                {"speaker": N, "text": "（我要挠哪里，那里就会先亮起来。按对应的键（Q 左腰 / W 屁股 / E 右腰 / A 左大腿 / S 膝盖窝 / D 右大腿）把那里冻住）"},
                {"speaker": N, "text": "（冻住的地方挠了没感觉。对已经冻住的地方再冻一次会冻太多、越来越冷，冷到发抖也会破功。表情绷不住三次，这节课重来。撑够时间就过关）"},
                {"speaker": CAP, "text": "……我有时候会骗你。看清楚了再冻。"},
            ],
            "spots": [
                {"id": "lwaist", "name": "左腰", "key": "Q", "zone": "waist"},
                {"id": "butt", "name": "屁股", "key": "W", "zone": "butt"},
                {"id": "rwaist", "name": "右腰", "key": "E", "zone": "waist"},
                {"id": "lthigh", "name": "左大腿", "key": "A", "zone": "thigh"},
                {"id": "knee", "name": "膝盖窝", "key": "S", "zone": "thigh"},
                {"id": "rthigh", "name": "右大腿", "key": "D", "zone": "thigh"},
            ],
            "hit": {
                "lwaist": ["（羽毛尖顺着左腰的曲线，从肋骨下面慢慢扫到胯骨）", "（两根手指在左腰上一戳一戳）"],
                "rwaist": ["（羽毛在右腰上画了一个大大的圈）", "（指尖顺着右腰一路往下划）"],
                "butt": ["（羽毛隔着裙子，在屁股上轻轻地拍了两下，又扫了一圈）", "（指尖在屁股侧面「咯吱」了一下）"],
                "lthigh": ["（羽毛贴着左大腿内侧，从膝盖往上扫）", "（五根手指在左大腿外侧轻轻地抓）"],
                "rthigh": ["（羽毛尖在右大腿内侧打转，越转越靠上）", "（指甲轻轻刮过右大腿）"],
                "knee": ["（羽毛钻进膝盖窝，左右一拧）", "（指尖在膝盖窝里一下一下地点）"],
            },
            "frozen": ["……没感觉。", "……冻住了。", "……哼。", "（面无表情）"],
            "shiver": [{"speaker": N, "text": "（冻得太多，她整个人打了个寒战——冻住的地方「咔嚓」一下全化开了）"},
                       {"speaker": B, "text": "……冷、冷……"},
                       {"speaker": CAP, "text": "冻太多了。……冻对地方，不是冻得多。"}],
            "feint": ["（队长的羽毛刚伸向一边——半路一转）", "（假动作！）", "（羽毛在空中晃了一下，换了个方向）"],
            "end": [
                {"speaker": CAP, "text": "……时间到。下来吧。"},
                {"speaker": N, "text": "（她从冰台上滑下来，腿有点软，扶住了旁边的柱子）"},
                {"speaker": B, "text": "……呼。"},
                {"speaker": P, "text": "好、好厉害……全程都板着脸……", "emotion": "surprise"},
                {"speaker": B, "text": "……脸，冻僵了。"},
                {"speaker": P, "text": "诶？", "emotion": "surprise"},
                {"speaker": B, "text": "……是真的冻僵了。……动不了。"},
                {"speaker": P, "text": "噗——哈哈哈哈！", "emotion": "happy"},
                {"speaker": CAP, "text": "……第一课，及格。"},
            ],
            "break": [{"speaker": N, "text": "（脸绷不住了——她的嘴角抽了一下，一声短短的笑从鼻子里漏了出来）"},
                      {"speaker": B, "text": "……噗。"},
                      {"speaker": CAP, "text": "记一笔。"},
                      {"speaker": P, "text": "笑、笑了！她刚才笑了！", "emotion": "happy"},
                      {"speaker": B, "text": "……没有。"}],
            "redo": [{"speaker": CAP, "text": "三笔了。……重来。"},
                     {"speaker": B, "text": "……再、来。"},
                     {"speaker": N, "text": "（她揉了揉冻得发红的大腿，重新坐回了冰台上）"}],
            "time": 55.0,
        },
        "tame": {
            "name": "第二课：驯裤",
            "intro": [
                {"speaker": CAP, "text": "第二课。……那条裤子。"},
                {"speaker": N, "text": "（千手痒痒裤上的小手们像是听懂了，齐刷刷地朝队长挥了挥）"},
                {"speaker": B, "text": "……它，不听话。"},
                {"speaker": CAP, "text": "它是千手的东西。千手被打败了，可它留下的这条裤子，还记着怎么挠人。"},
                {"speaker": CAP, "text": "脱不下来，砍不掉。……那就只能驯。"},
                {"speaker": P, "text": "驯、驯裤子？像驯小狗那样？", "emotion": "surprise"},
                {"speaker": CAP, "text": "差不多。……我观察了几天。这些小手要挠人之前，都会先比个手势。"},
                {"speaker": CAP, "text": "抖——是要挠大腿。并拢——是要掐屁股。张开——是要挠腰。打拍子——是要一起上。"},
                {"speaker": B, "text": "……我、知道。……每天，都被挠。"},
                {"speaker": CAP, "text": "知道还不够。看到手势，要先下指令。……抖，就按住它。并拢，就安抚它。张开，就冻住它。打拍子……"},
                {"speaker": B, "text": "……打拍子？"},
                {"speaker": CAP, "text": "……就随它去。让它挠一下，它就会安静一阵。"},
                {"speaker": P, "text": "随、随它去也算指令吗！", "emotion": "surprise"},
                {"speaker": CAP, "text": "算。驯东西，也得给它点甜头。"},
                {"speaker": CAP, "text": "指令对了，它就听话一点；错了，它当场挠你。……听话到底，就算出师。"},
            ],
            "tutorial": [
                {"speaker": N, "text": "（看手势下指令：W 按住（抖）/ A 安抚（并拢）/ S 冻住（张开）/ D 随它去（打拍子）。对了听话度涨，错了当场被挠）"},
                {"speaker": N, "text": "（越往后手势越快，还会有假手势——先比一个，半路换成另一个）"},
            ],
            "gestures": [
                {"id": "shake", "name": "抖", "key": "W", "zone": "thigh", "cmd": "按住", "show": "（小手们在大腿上抖了起来）",
                 "hit": ["（抖着的小手一齐扑上大腿，从膝盖一路挠到腿根）", "（大腿内侧被十几根手指同时挠了一下）"]},
                {"id": "close", "name": "并拢", "key": "A", "zone": "butt", "cmd": "安抚", "show": "（小手们并拢了，排成一排）",
                 "hit": ["（并拢的小手「啪」地一下掐在屁股上，左一下右一下）", "（小手在屁股上一捏一捏，打着拍子）"]},
                {"id": "open", "name": "张开", "key": "S", "zone": "waist", "cmd": "冻住", "show": "（小手们五指张开，朝着腰伸过去）",
                 "hit": ["（张开的手指一下子钻进腰侧，咯吱咯吱地挠）", "（腰两边同时被抓住，挠得她一缩）"]},
                {"id": "clap", "name": "打拍子", "key": "D", "zone": "thigh", "cmd": "随它去", "show": "（小手们「啪、啪、啪」地打起了拍子）",
                 "hit": ["（拍子打完，所有的小手一起扑了上来——大腿、屁股、腰）", "（全部的小手一齐动了起来）"]},
            ],
            "obey": ["……乖。", "……好。", "……别动。", "（小手们缩了回去）"],
            "wrong": ["（指令错了——小手们「咯吱咯吱」地造反了）", "（小手们不吃这一套）", "（反了！小手扑了上来）"],
            "let": ["（她闭上眼，任由小手挠了一下。……然后小手们真的安静了）", "（挠完一下，小手们心满意足地趴了回去）"],
            "end": [
                {"speaker": N, "text": "（最后一个手势——她抢先一步按住了裤子。小手们动了动，乖乖地趴平了）"},
                {"speaker": CAP, "text": "……够了。今天就到这里。"},
                {"speaker": B, "text": "……它，听话了？"},
                {"speaker": CAP, "text": "听话了一点。……一点而已。"},
                {"speaker": P, "text": "可是刚才那几下，它真的乖乖停了！好厉害！", "emotion": "happy"},
                {"speaker": N, "text": "（裤子上的一只小手偷偷伸出来，在她的大腿上戳了一下）"},
                {"speaker": B, "text": "……！"},
                {"speaker": CAP, "text": "……一点而已。"},
                {"speaker": B, "text": "……哼。"},
            ],
            "break": [{"speaker": N, "text": "（小手们一齐造反，她终于绷不住，弯下腰笑了出来）"},
                      {"speaker": B, "text": "……哈……哈……"},
                      {"speaker": P, "text": "笑、笑了！队长她笑了！", "emotion": "happy"},
                      {"speaker": CAP, "text": "……听话度归零了。重新驯。"}],
            "redo": [{"speaker": CAP, "text": "……重来。"},
                     {"speaker": B, "text": "……再、来。"}],
            "goal": 100,
        },
    },
    # 两节课之间（第 4 天）
    "between": [
        {"speaker": N, "text": "（休息的时候，粉色公主递过去一杯热水。蓝色公主捧着杯子，小口小口地喝）"},
        {"speaker": P, "text": "……你每天早上都来受这个？", "emotion": "surprise"},
        {"speaker": B, "text": "……嗯。"},
        {"speaker": P, "text": "为什么不告诉我？", "emotion": "sad"},
        {"speaker": B, "text": "……告诉你，你会来看。"},
        {"speaker": P, "text": "现在不也来看了嘛。", "emotion": "happy"},
        {"speaker": B, "text": "……所以，不想告诉你。"},
        {"speaker": CAP, "text": "……休息结束。第二课。"},
    ],
    "react": {
        "light": ["……", "……没事。", "……哼。", "……别。", "……唔。", "……一点、都不。", "……继续。", "……（咬住嘴唇）", "……嗯。", "……不痒。"],
        "mid": ["……唔……！", "……别、碰……", "……噗。……没、笑。", "……可、恶……", "……腿……别……", "……哈……不……",
                "……停……", "……（肩膀在抖）", "……不、算……", "……够、了……"],
        "heavy": ["……哈……哈……", "……不、行……", "……噗、哈……", "……停、下……哈……", "……（笑声从指缝里漏出来）",
                  "……别……看……", "……哈……认、输……不……", "……（整个人缩成一团）", "……哈哈……可、恶……", "……救……"],
        "sensitive": ["……哈、啊……！？", "……现、在……不……！", "……全、全身……都……", "……哈哈……为、为什么……这么……",
                      "……别、现在……挠……！", "……软、了……", "……噗哈……不、不公平……", "……（一碰就抖）", "……哈……刚放完……",
                      "……停、停一下……哈哈……"],
    },
    "cap": ["……", "左边。", "这里。", "……冻得不对。", "专心。", "……还早。", "呼吸。", "别看她。", "……再来。", "脸。"],
    "cap_sensitive": ["现在是最软的时候。", "……趁现在。", "放完魔力的人，挠一下顶两下。", "撑住。最软的时候也要撑住。"],
    "pink": ["加油加油！", "表情！表情！", "我的羽毛也想加油～", "冻住它冻住它！", "噗——刚才是不是笑了？", "好厉害！一动不动！",
             "啊，那里没冻！", "要不要我帮你一下？（晃羽毛）"],
}


def d4_drill():
    s = [
        {"actions": [A("camera", to=[10, 7], zoom=1.0, time=0.4)], "wait": 0.4},
        line(CAP, "来了。"),
        line(B, "……嗯。"),
        line(P, "我、我也可以来看吗？", "surprise"),
        line(CAP, "可以。……而且你得帮忙。"),
        line(P, "帮忙？", "surprise"),
        line(CAP, "这几天，殿下每天早上都来这里。……成绩不太好。"),
        line(B, "……（别过脸去）"),
        line(CAP, "一个人练，总是差一口气。有个人在旁边看着，她才会真的用力。"),
        line(P, "……原来你每天早上不在，是来这里特训了啊。", "surprise"),
        line(B, "……别、说出来。"),
        line(CAP, "今天两节课。先冻，后驯。……开始。"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "蓝色公主的特训", "letterbox": True, "skippable": True, "steps": s}


def d4_drill_done():
    s = [
        {"actions": [A("camera", to=[10, 7], zoom=1.0, time=0.4)], "wait": 0.4},
        line(CAP, "今天到此为止。……后天下午，再来。第三课和考核。"),
        line(B, "……考核？"),
        line(CAP, "考核。……到时候，挠你的人是她。"),
        line(P, "诶？我？", "surprise"),
        line(B, "……"),
        line(P, "……嘿嘿嘿。", "happy"),
        line(B, "……不准，笑。"),
        line(N, "（走出训练室的时候，蓝色公主走得有点慢。粉色公主凑过去，挽住了她的胳膊）"),
        line(P, "累了吧？我扶你回去。", "happy"),
        line(B, "……不用。"),
        line(N, "（嘴上说着不用，却没有把胳膊抽回去）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "第一天的特训结束", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d4_drill": d4_drill, "after_d4_drill_done": d4_drill_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, who="blue", zone="thigh", fx="feather", n=8, iv=0.2):
    return A("tickle", who=who, by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_DRILL = {"name": "特训失败：补课", "cast": {
    "blue": {"kind": "npc:blue_princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "cap": {"kind": "npc:captain", "at": [-26, 6], "dir": "right"},
    "pink": {"kind": "npc:pink_princess", "at": [26, 6], "dir": "left"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(CAP, "……今天的课，没过。"),
    _say(B, "……再、来。"),
    _say(CAP, "再来之前——补课。"),
    _say(P, "补、补课？", emotion="surprise"),
    _say(CAP, "你。右边。我，左边。……殿下的问题是不知道自己哪里最怕痒。今天帮她记清楚。"),
    _say(B, "……！？"),
    _say(N, "（队长的羽毛贴上左大腿，粉色公主的手指戳上右腰。两边同时开始）", [_tk("cap"), _tk("pink", zone="waist", fx="hand")]),
    _say(B, "……唔、唔……！……两、两边……"),
    _say(CAP, "大腿内侧。……记住了？"),
    _say(P, "腰也很怕哦！你看你看，一戳就缩！", [_tk("pink", zone="waist", fx="hand", n=10, iv=0.16)], emotion="happy"),
    _say(B, "……噗。……哈……别、戳……"),
    _say(CAP, "膝盖窝。", [_tk("cap", zone="thigh", n=10, iv=0.16)]),
    _say(B, "……哈、哈……！"),
    _say(N, "（千手痒痒裤上的小手们也凑起了热闹，在屁股上「啪嗒啪嗒」地打起了拍子）", [_tk("pink", zone="butt", fx="hand", n=12, iv=0.14), A("pose", who="blue", visual="helpless_2")]),
    _say(B, "……哈哈……裤、裤子……也……叛、徒……"),
    _say(P, "她笑了！队长！她真的笑出声了！", emotion="happy"),
    _say(CAP, "……嗯。笑出来了。"),
    _say(CAP, "……能笑出来，比硬撑好。……歇一会儿，重新上课。"),
    _say(B, "……哈……哈……（瘫在冰台上，把脸埋进胳膊里）"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_drill": FAIL_DRILL}
DIALOGUES = {
    "after_drill_objects": {"name": "", "entries": [{"node": "ice"}], "nodes": {
        "ice": {"lines": [{"speaker": N, "text": "（冰台。冰面上有一个浅浅的、坐出来的印子）"}]}}},
    "after_drill_cap": {"name": CAP, "npc": "captain", "entries": [{"node": "default"}], "nodes": {
        "default": {"lines": [{"text": "……训练室不是玩的地方。"}]}}},
}
SIGNS = {"after_drill_locked": [{"speaker": N, "text": "（训练室的门关着。门上挂着一块牌子：「特训中，闲人勿入」）"}]}


# —— 第 6 天下午：第三课「借手」（训练室右边的障碍场，地图里实际走）+ 考核（DrillExamShow）
DRILL["lessons"]["hand"] = {
    "name": "第三课：借手",
    "intro": [
        {"speaker": CAP, "text": "第三课。……这两天，那条裤子听话了一点。"},
        {"speaker": B, "text": "……一点。"},
        {"speaker": CAP, "text": "一点就够了。……今天，让它干活。"},
        {"speaker": P, "text": "干活？裤子也要赎罪吗？", "emotion": "surprise"},
        {"speaker": CAP, "text": "……那些小手能伸得很长。千手打仗的时候，一伸就是半个战场。"},
        {"speaker": CAP, "text": "驯好了，它们就是你多出来的手。挡飞过来的东西、拉远处的拉杆、抓住背后偷袭的人。"},
        {"speaker": B, "text": "……让它，帮我？"},
        {"speaker": CAP, "text": "让它帮你。……可是它每帮一次，听话度就掉一截。掉得太低，它就会造反。"},
        {"speaker": CAP, "text": "站到台上去。我从两边丢东西过来。"},
        {"speaker": CAP, "text": "……你。（看向粉色公主）你绕到她背后去。"},
        {"speaker": P, "text": "我？我干什么？", "emotion": "surprise"},
        {"speaker": CAP, "text": "偷袭。"},
        {"speaker": P, "text": "……诶嘿嘿。", "emotion": "happy"},
        {"speaker": B, "text": "……（瞪）"},
    ],
    "tutorial": [
        {"speaker": N, "text": "（羽毛从左 / 右 / 上飞来：按 ← / → / ↑ 让小手挡掉。拉杆亮起：左边 A、右边 D 让小手去拉。粉色公主从背后偷袭：按 ↓ 抓住她）"},
        {"speaker": N, "text": "（每下一次指令听话度掉一截，慢慢会回来；听话度太低时下指令，小手会造反挠她自己。漏掉的状况会被挠）"},
    ],
    "events": {
        "feather_l": {"key": "LEFT", "show": "（左边飞来一把羽毛！）", "ok": "（小手「啪」地把羽毛拍飞了）",
                      "miss": ["（羽毛扫过左边大腿，一路扫到膝盖窝）", "（左边的羽毛钻进了大腿内侧）"], "zone": "thigh"},
        "feather_r": {"key": "RIGHT", "show": "（右边飞来一把羽毛！）", "ok": "（小手一挥，羽毛散了一地）",
                      "miss": ["（右边的羽毛扫过腰侧）", "（羽毛在右大腿上打了个转）"], "zone": "waist"},
        "feather_u": {"key": "UP", "show": "（羽毛从头顶落下来！）", "ok": "（小手撑开，像一把伞挡住了羽毛）",
                      "miss": ["（羽毛从领口落进去，一路滑到腰上）", "（一根羽毛落在后颈上，扫来扫去）"], "zone": "neck"},
        "lever_l": {"key": "A", "show": "（左边的拉杆亮了！）", "ok": "（小手伸得老长，「咔哒」拉下了拉杆）",
                    "miss": ["（拉杆没拉——机关一转，两把刷子刷了刷大腿）"], "zone": "thigh"},
        "lever_r": {"key": "D", "show": "（右边的拉杆亮了！）", "ok": "（小手一勾，右边的拉杆拉下来了）",
                    "miss": ["（没拉到——台子下面伸出一把刷子，刷了刷屁股）"], "zone": "butt"},
        "sneak": {"key": "DOWN", "show": "（背后……有脚步声。粉色公主在偷偷靠近！）", "ok": "（小手「嗖」地缠住了粉色公主的手腕）",
                  "miss": ["（粉色公主从背后扑上来，十根手指钻进腰侧咯吱咯吱地挠）", "（「抓到啦！」——粉色公主在她的膝盖窝里戳了好几下）"], "zone": "waist"},
    },
    "caught_pink": ["诶！？被、被抓住了！", "裤子好过分！", "放开放开～", "这次一定……！"],
    "sneak_ok_pink": ["嘿嘿……偷袭成功！", "抓到你啦～", "破绽！"],
    "rebel": ["（听话度太低——小手不理她，转过来挠她自己的大腿）", "（小手造反了！在屁股上一捏一捏）"],
    "end": [
        {"speaker": N, "text": "（最后一把羽毛被拍飞。小手们乖乖地缩回裤子上，趴得平平的）"},
        {"speaker": CAP, "text": "……及格。"},
        {"speaker": P, "text": "好厉害！我偷袭了那么多次，被抓住了好几次！", "emotion": "happy"},
        {"speaker": B, "text": "……它，帮我了。"},
        {"speaker": CAP, "text": "你帮它，它才帮你。……休息五分钟。考核。"},
    ],
    "redo": [{"speaker": CAP, "text": "……重来。"}, {"speaker": B, "text": "……再、来。"}],
    "goal": 12,
}
DRILL["lessons"]["exam"] = {
    "name": "考核：反过来的玩闹",
    "intro": [
        {"speaker": CAP, "text": "考核。"},
        {"speaker": CAP, "text": "前几天，她逗你笑，你被裤子按住，什么都做不了。"},
        {"speaker": B, "text": "……（别过脸）"},
        {"speaker": CAP, "text": "今天一样。她挠你。……不同的是，今天你有三样东西。"},
        {"speaker": CAP, "text": "冻住要被挠的地方。指挥小手去挡她的手。还有——忍。"},
        {"speaker": CAP, "text": "撑过时间，及格。笑出声三次，不及格。"},
        {"speaker": P, "text": "（搓搓手）……我、我会手下留情的！大概！", "emotion": "happy"},
        {"speaker": B, "text": "……不准，留情。"},
        {"speaker": P, "text": "诶？", "emotion": "surprise"},
        {"speaker": B, "text": "……留情，就不算考核。"},
        {"speaker": CAP, "text": "……开始。"},
    ],
    "tutorial": [
        {"speaker": N, "text": "（粉色公主要挠哪里，那里先亮——Q W E / A S D 冻住。J：指挥小手挡下她的下一下（要听话度）。U：千手解放（把她推开一会儿，但之后小手会挠自己）"},
        {"speaker": N, "text": "（表情掉光记一笔，三笔就是「笑出声」。魔力疲倦满了会释放，之后更敏感，还会加时）"},
    ],
    "pink": ["嘿嘿，这里！", "腰——！", "膝盖窝膝盖窝～", "大腿内侧！", "嘿，冻住了？那换这边！", "你脸红了哦～",
             "我可没有留情！", "再坚持一下下～", "这里冻得不对哦！", "认输吧～"],
    "hit": {
        "lwaist": ["（粉色公主的手指钻进左腰，咯吱咯吱地挠）"], "rwaist": ["（右腰被戳了好几下，一下比一下快）"],
        "butt": ["（她的手指在屁股侧面画圈）"], "lthigh": ["（指尖顺着左大腿内侧往上爬）"],
        "rthigh": ["（右大腿被五根手指轻轻地抓来抓去）"], "knee": ["（膝盖窝被戳了一下，又戳了一下）"],
    },
    "block": ["（小手「啪」地拍开了粉色公主的手）", "（小手交叉护住，她的手指扑了个空）"],
    "burst_skill": [{"speaker": N, "text": "（千手解放——小手们一齐伸长，一圈扫出去，把粉色公主推得连退好几步，愣在原地）"},
                    {"speaker": P, "text": "哇啊！？裤、裤子推我！？", "emotion": "surprise"},
                    {"speaker": N, "text": "（……然后，收不回来的小手们，转过头来）"},
                    {"speaker": B, "text": "……啊。"}],
    "pass": [
        {"speaker": CAP, "text": "……时间到。"},
        {"speaker": N, "text": "（蓝色公主的脸绷得紧紧的，肩膀还在微微发抖——可是一声都没有笑出来）"},
        {"speaker": P, "text": "撑、撑过去了！？我那么努力地挠……！", "emotion": "surprise"},
        {"speaker": B, "text": "……哼。"},
        {"speaker": CAP, "text": "……及格。"},
        {"speaker": CAP, "text": "……做得好，殿下。"},
        {"speaker": B, "text": "……"},
        {"speaker": N, "text": "（她别过脸去。可是耳朵尖，红得像熟透的苹果）"},
        {"speaker": P, "text": "……队长刚才叫她「殿下」的时候，声音好温柔哦。", "emotion": "happy"},
        {"speaker": CAP, "text": "……没有。"},
    ],
    "fail": [
        {"speaker": N, "text": "（第三次——她终于绷不住了，捂着肚子，笑得弯下了腰）"},
        {"speaker": B, "text": "……哈、哈哈……哈哈哈……"},
        {"speaker": P, "text": "笑了！笑出声了！我赢了——！", "emotion": "happy"},
        {"speaker": B, "text": "……哈……不、算……"},
        {"speaker": P, "text": "算！笑得这么大声！我从来没听过你笑这么大声！", "emotion": "happy"},
        {"speaker": N, "text": "（粉色公主笑嘻嘻地凑过去，戳了戳她的脸。蓝色公主红着脸，一把抓住了她的手——却没有甩开）"},
        {"speaker": CAP, "text": "……不及格。"},
        {"speaker": CAP, "text": "……不过，笑得出来，也是一种本事。"},
        {"speaker": B, "text": "……（把脸埋进膝盖里）"},
    ],
    "redo": [],
    "time": 45.0,
}
DRILL["skill"] = [
    {"speaker": CAP, "text": "……特训到此为止。"},
    {"speaker": CAP, "text": "这条裤子，你还是脱不下来。……可是它现在听你的了。至少，听一半。"},
    {"speaker": N, "text": "（得到被动技能「冰封自制」：蓝色公主的闷笑涨得慢一点，千手痒痒裤的减速和闷笑下限减轻）"},
    {"speaker": N, "text": "（得到主动技能「千手解放」（U）：小手一圈扫出去，附近的怪定身 3 秒、陷阱暂停；之后 5 秒小手收不回来，转过来挠她自己）"},
    {"speaker": B, "text": "……收不回来？"},
    {"speaker": CAP, "text": "……它帮你一次，你让它挠一次。公平。"},
    {"speaker": B, "text": "……不公平。"},
    {"speaker": P, "text": "噗——", "emotion": "happy"},
]


def d6_drill():
    s = [
        {"actions": [A("camera", to=[10, 7], zoom=1.0, time=0.4)], "wait": 0.4},
        line(CAP, "来了。……第三课，然后考核。"),
        line(B, "……嗯。"),
        line(P, "今天轮到我挠了吧！", "happy"),
        line(CAP, "……考核的时候。第三课，你先捣乱。"),
        line(P, "捣乱也行！", "happy"),
        line(B, "……（叹气）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "特训·第二天", "letterbox": True, "skippable": True, "steps": s}


def d6_drill_done():
    s = [
        {"actions": [A("camera", to=[10, 7], zoom=1.0, time=0.4)], "wait": 0.4},
        line(N, "（走出训练室的时候，天已经黑了。两个人并排走着）"),
        line(P, "……明天就是第七天了。", "sad"),
        line(B, "……嗯。"),
        line(P, "图腾柱修好，工时就清了。……然后呢？", "sad"),
        line(B, "……然后，庆功宴。"),
        line(P, "庆功宴之后呢？", "sad"),
        line(B, "……"),
        line(B, "……之后，再说。"),
        line(N, "（她没再说话。可是走到小屋门口的时候，她的小手——裤子上的小手——偷偷勾住了粉色公主的小指）"),
        line(P, "……诶？", "surprise"),
        line(B, "……不是我。是裤子。"),
        line(P, "……嘿嘿。", "happy"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "第七天的前夜", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES["after_d6_drill"] = d6_drill
CUTSCENES["after_d6_drill_done"] = d6_drill_done
