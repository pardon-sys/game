"""弥补任务「陷阱验收」（第 6 天早上，保卫队训练营 floor_06_after_proving）：data/after/inspect.json（TaskInspect / InspectShow 读）+ 过场 + 失败小剧场。
保卫队给训练营做了一批针对脚的陷阱原型，请粉色公主来试：
  辅助（不评分，留下状态）：温水泡脚盆（舒服、闷笑降，留「泡软」）、精油喷雾踏板（留「滑溜」）、冷敷石板（清掉状态，留「冷敷」敏感降低）。
  挠痒（要评分）：羽毛帘 / 地洞挠挠手 / 脚趾分隔刷 / 单脚吊环架 / 跪台脚心朝天。每个走上去 → 小游戏画面（InspectShow）体验一遍 →
    屏幕给出「刚才闷笑涨了多少 + 身上的状态」→ 报「太强 / 刚好 / 太弱」（要报陷阱本身的强度，扣掉状态的影响）。
    评「太弱」（其实不弱）→ 队员加强它；评「太强」（其实不强）→ 削弱，但队长怀疑偷懒、追加体验一次。
  五个都评完 → 综合演练（按评分调整过强度，连着来、闷笑不清零）；闷笑满 = 失败（after_fail_inspect）。
  stations   每个陷阱：name、kind、strength 真实强度（weak / ok / strong）、mul 挠痒倍率、intro 第一次走上去时、
             cap 挠法描写（舞台上方）、react 公主的反应（三档）、escape 挣开时
  aux        辅助设施：name、status、enter 踩上去时的几句
  status     状态：name、mul（之后挠痒的倍率）、time 秒、desc
"""
from .common import A, CAP, N, P, line

G = "保卫队员"
G2 = "保卫队员小芬"

INSPECT = {
    "status": {
        "soaked": {"name": "泡软", "mul": 1.5, "time": 40.0, "desc": "泡过温水，脚底软软的，更怕痒"},
        "oiled": {"name": "滑溜", "mul": 1.3, "time": 40.0, "desc": "脚底抹了精油，被刷、被挠都更痒"},
        "cooled": {"name": "冷敷", "mul": 0.7, "time": 30.0, "desc": "冷敷过，脚底麻麻的，没那么怕痒"},
    },
    "aux": {
        "soak": {"name": "温水泡脚盆", "status": "soaked", "laugh": -0.25,
                 "enter": [{"speaker": N, "text": "（木盆里的温水刚好没过脚踝，暖洋洋的。脚底一下子就放松了）"},
                           {"speaker": P, "text": "呼……好舒服……这个是奖励吗？", "emotion": "happy"},
                           {"speaker": G, "text": "这是「辅助设施」。泡软了的脚，测出来的数据……嗯，会更有参考价值。"},
                           {"speaker": P, "text": "……「更有参考价值」是什么意思啊。", "emotion": "surprise"}]},
        "oil": {"name": "精油喷雾踏板", "status": "oiled", "laugh": 0.0,
                "enter": [{"speaker": N, "text": "（一踩上去，「噗嗤」一声，一股带着花香的精油喷满了脚底）"},
                          {"speaker": P, "text": "哇！？滑、滑溜溜的……！", "emotion": "surprise"},
                          {"speaker": G, "text": "精油能让刷毛更顺滑。……当然，被刷的人也会更「顺滑」地笑出来。"}]},
        "cool": {"name": "冷敷石板", "status": "cooled", "laugh": -0.1, "clears": True,
                 "enter": [{"speaker": N, "text": "（冰凉的石板贴着脚底，刚才的温热、油腻一下子都没了，脚底麻麻的）"},
                           {"speaker": P, "text": "嘶……好冰……可是好像……没那么敏感了。", "emotion": "surprise"},
                           {"speaker": G, "text": "这是给测试员「重置」用的。……队长说，你可以随便用。"}]},
    },
    "stations": {
        "curtain": {"name": "羽毛帘", "kind": "curtain", "strength": "weak", "mul": 0.8, "trap": "feather_curtain",
            "intro": [{"speaker": G, "text": "第一号：羽毛帘。门口挂一排，入侵者穿过的时候，底下的长羽毛会扫脚。"},
                      {"speaker": G, "text": "旁边有台风扇，吹起来的时候帘子会掀开——那时候过去就不会被扫到。"},
                      {"speaker": N, "text": "（风扇吹起帘子的时候按 J 冲过去。帘子垂着的时候过去，会被扫脚踝和脚心）"}],
            "cap": ["（长长的羽毛从脚踝一路扫到脚心，帘子一晃一晃地拂过去）", "（帘子底下的羽毛缠住了脚趾，扫了好几下才松开）",
                    "（一整排羽毛同时扫过两只脚底）"],
            "escape": ["（趁帘子掀起来，一下子冲了过去！）"]},
        "holes": {"name": "地洞挠挠手", "kind": "holes", "strength": "ok", "mul": 1.0, "trap": "hand",
            "intro": [{"speaker": G, "text": "第二号：地洞挠挠手。地板上一排小洞，踩到的时候……里面会伸出手来。"},
                      {"speaker": P, "text": "手、手！？", "emotion": "surprise"},
                      {"speaker": G, "text": "冒泡的那个洞就是要伸手了。被抓住的话，蹬开就行。"},
                      {"speaker": N, "text": "（洞口冒泡时那个洞要伸手——按 J 把脚抽开。被抓住了连按 J 蹬开）"}],
            "cap": ["（洞里伸出一只小手，抓住脚踝，另一只手在脚趾上一根一根地挠）", "（小手的指尖在脚心上画圈，越画越快）",
                    "（两个洞同时伸出手，一只抓脚跟，一只挠脚趾缝）"],
            "escape": ["（一蹬腿，小手缩回了洞里）"]},
        "toes": {"name": "脚趾分隔刷", "kind": "toes", "strength": "strong", "mul": 1.4, "trap": "brush",
            "intro": [{"speaker": G, "text": "第三号：脚趾分隔刷。踩上踏板，夹子会把脚趾一根根撑开，然后……细刷子从趾缝里刷过去。"},
                      {"speaker": P, "text": "这、这个光听着就……", "emotion": "sad"},
                      {"speaker": G, "text": "挣开得越晚，刷子刷得越快。……加油。"},
                      {"speaker": N, "text": "（连按 J 挣开夹子。越晚挣开，刷得越快）"}],
            "cap": ["（夹子把脚趾一根根撑开，细细的刷毛钻进每一道趾缝，左右来回地刷）", "（刷子越转越快，十道趾缝同时被刷得发烫）",
                    "（脚趾想蜷起来，却被夹子撑得开开的——刷毛一下下扫过最嫩的趾根）"],
            "escape": ["（「咔」——夹子被挣开了，脚趾一下子蜷成一团）"]},
        "hoist": {"name": "单脚吊环架", "kind": "hoist", "strength": "strong", "mul": 1.3, "trap": "legloop",
            "intro": [{"speaker": G, "text": "第四号：单脚吊环架。这个……是小芬设计的。"},
                      {"speaker": G2, "text": "嘿嘿！一只脚踝套进吊环，「嗖」地吊起来，脚趾用夹子往后扳——脚心绷得平平的，羽毛扫起来最痒！"},
                      {"speaker": G2, "text": "另一只脚就只能踮着脚尖站。脚跟一落地，下面的刷子就刷脚跟！"},
                      {"speaker": P, "text": "你、你设计这个的时候在想什么啊！", "emotion": "angry"},
                      {"speaker": G2, "text": "在想入侵者的表情！"},
                      {"speaker": N, "text": "（按住 W 踮脚（踮脚体力会掉），脚跟落地会被刷。同时连按 J 挣开吊环）"}],
            "cap": ["（吊起来的那只脚，脚趾被扳得往后弯，脚心绷得平平的——羽毛从脚跟一路扫到脚掌）",
                    "（踮着的那只脚一软，脚跟落了地——下面的刷子立刻「唰唰」地刷了上来）",
                    "（羽毛在绷紧的脚心正中间打转，脚趾被扳着，想蜷都蜷不了）"],
            "escape": ["（吊环「啪」地松开，她单脚跳了两下才站稳）"]},
        "kneel": {"name": "跪台脚心朝天", "kind": "kneel", "strength": "ok", "mul": 1.1, "trap": "prone",
            "intro": [{"speaker": G, "text": "第五号：跪台。踩上去，软垫会把人压成跪着的姿势，两只脚心朝天锁住。"},
                      {"speaker": G, "text": "然后两把刷子，一左一右，轮流刷。……左右交替用力，就能挣开。"},
                      {"speaker": N, "text": "（按提示左右交替按 A / D 挣扎，挣开前会被刷几轮）"}],
            "cap": ["（两只脚心朝着天，左边的刷子刷一下，右边的刷子刷一下，一下一下地轮流）",
                    "（刷子从脚跟刷到脚趾，又从脚趾刷回脚跟，跪着的身子跟着一抖一抖）",
                    "（两把刷子忽然同时刷了起来）"],
            "escape": ["（左一下、右一下——「咔哒」，锁扣松开了）"]},
    },
    "react": {
        "light": ["……唔，还、还好……", "这个……还能忍。", "……哼，就这点程度？", "嗯……有点痒……", "……没事没事。", "……记、记下来……"],
        "mid": ["哈、哈哈……这个痒……！", "噗……脚、脚心……！", "哈哈……别、别刷了……！", "唔哈……记、记不了数据了……！",
                "哈哈……脚趾……！", "这、这个到底算强还是……哈哈……！"],
        "heavy": ["哈哈哈哈……太、太强了……！", "哈……不、不行……", "哈哈哈……饶了我……", "呜哈……脚……没、没感觉了……",
                  "哈哈……停、停一下……", "……哈……哈……数、数据……"],
    },
    "rate": {
        "prompt": "「%s」：刚才闷笑涨了 %d%%（身上：%s）。这个陷阱本身——",
        "options": ["太强了", "刚刚好", "太弱了"],
        "ids": ["strong", "ok", "weak"],
        "right": [[{"speaker": G, "text": "嗯嗯，和我们测的差不多。记下来了！"}],
                  [{"speaker": G, "text": "准确！不愧是专业的……被挠的人。"}, {"speaker": P, "text": "我才不是专业的！", "emotion": "angry"}]],
        "too_weak": [{"speaker": G, "text": "太弱了？……好，那我们再加强一点！"},
                     {"speaker": N, "text": "（队员们在陷阱上拧了拧螺丝，又加了几根羽毛）"},
                     {"speaker": P, "text": "（……等、等一下，其实刚才是因为……）", "emotion": "sad"}],
        "too_strong": [{"speaker": G, "text": "太强了？……嗯，那就削弱一点。"},
                       {"speaker": CAP, "text": "（不知什么时候站在了旁边）……太强？我看你刚才还挺能忍的。"},
                       {"speaker": CAP, "text": "……再体验一次。"},
                       {"speaker": P, "text": "诶——！？", "emotion": "surprise"}],
    },
    "drill_intro": [
        {"speaker": CAP, "text": "五个都评完了。……最后，综合演练。"},
        {"speaker": CAP, "text": "按你的评分调整过的五个陷阱，连成一条道。从头走到尾。"},
        {"speaker": P, "text": "连、连着来？中间不能歇？", "emotion": "surprise"},
        {"speaker": CAP, "text": "入侵者会给你歇吗？"},
        {"speaker": G2, "text": "加油——！我的吊环架等着你哦！"},
        {"speaker": N, "text": "（综合演练：五个陷阱依次来，闷笑不会清零。笑满就失败）"},
    ],
    "drill_between": ["（下一个！）", "（还有三个……）", "（还剩两个！）", "（最后一个——）"],
    "drill_done": [
        {"speaker": N, "text": "（最后一个跪台的锁扣「咔哒」松开。她从台子上滑下来，坐在地上直喘气）"},
        {"speaker": P, "text": "呼……呼……走、走完了……", "emotion": "helpless_1"},
        {"speaker": CAP, "text": "……嗯。"},
        {"speaker": G2, "text": "队长队长！数据很完整！"},
        {"speaker": CAP, "text": "……这批陷阱，下个月装到城墙底下。入侵者来了，就让他们也尝尝。"},
        {"speaker": P, "text": "入侵者……会光着脚来吗？", "emotion": "surprise"},
        {"speaker": CAP, "text": "……"},
        {"speaker": G, "text": "……队长，这个问题我们没想过。"},
        {"speaker": CAP, "text": "……先装上再说。"},
    ],
}


def d6_inspect():
    s = [
        {"actions": [A("camera", to=[12, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(G, "来了来了！今天的测试员！"),
        line(P, "测试员……又是这种名字……", "sad"),
        line(G, "攻防战以后，队长说城墙底下要加一批新陷阱。我们连夜做了几个原型——专门对付入侵者的脚。"),
        line(P, "为什么是脚！？", "surprise"),
        line(G2, "因为入侵者都是爬城墙的嘛！脚在下面！"),
        line(G, "……是这个道理。总之，需要有人亲自走一遍，告诉我们每个陷阱是太强、刚好、还是太弱。"),
        line(G, "旁边还有几个「辅助设施」——泡脚盆、精油踏板、冷敷石板。用不用随你。"),
        line(G, "不过……泡过脚、抹过油以后，人会更怕痒。评分的时候，要想清楚是陷阱厉害，还是你自己变敏感了。"),
        line(P, "……为什么要特意准备会让人变敏感的设施啊。", "sad"),
        line(G2, "因为真实的战场上，入侵者可能刚从水沟里爬出来！"),
        line(P, "……好、好有道理……", "sad"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "陷阱验收", "letterbox": True, "skippable": True, "steps": s}


def d6_inspect_done():
    s = [
        {"actions": [A("camera", to=[12, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(G, "辛苦了！数据全都记下来了！"),
        line(G2, "我的吊环架评了什么？评了什么？"),
        line(P, "……评了「太强」。", "angry"),
        line(G2, "太好了！", None),
        line(P, "那不是夸你！", "angry"),
        line(CAP, "……下午，训练室。别忘了。"),
        line(P, "啊，对了，今天下午是……考核！", "surprise"),
        line(CAP, "……你挠她。"),
        line(P, "……嘿嘿。", "happy"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "验收结束", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d6_inspect": d6_inspect, "after_d6_inspect_done": d6_inspect_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, zone="sole", fx="brush", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_INSPECT = {"name": "验收失败：全套陷阱一起来", "cast": {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "rack": {"kind": "trap:foot_thigh_rack", "at": [0, 10]},
    "brush": {"kind": "trap:brush", "at": [-22, 14]},
    "feather": {"kind": "trap:feather", "at": [22, 14]},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（笑得腿一软，她一屁股坐在了跪台和吊环架中间——两个陷阱同时「咔哒」一声启动了）"),
    _say(P, "等、等一下！我还没——", emotion="surprise"),
    _say(N, "（一只脚踝被吊环套住拉了起来，另一只脚被跪台的锁扣扣住。两只脚心，一高一低，全都朝着外面）"),
    _say(G2, "哇！两个陷阱的联动！我都没想到可以这样！"),
    _say(N, "（羽毛扫过吊起来的脚心，刷子刷过锁住的脚底，脚趾分隔刷的夹子也「嗖」地伸了过来）", [_tk("feather", fx="feather", n=10), _tk("brush", n=10)]),
    _say(P, "哈哈哈哈！三、三个一起——！数、数据不准了啦——！", portrait="defeat_1"),
    _say(G, "小芬！快关掉！"),
    _say(G2, "可是……这个联动的数据好珍贵……我记一下……就一下……", [_tk("brush", n=12, iv=0.15)]),
    _say(P, "记什么记啊——哈哈哈哈！脚趾缝……全部……！", portrait="defeat_2"),
    _say(N, "（夹子把脚趾一根根撑开，细刷子在趾缝里来回地刷。吊起来的那只脚被扳着脚趾，脚心绷得平平的，羽毛一圈一圈地画）", [_tk("rack", fx="feather", n=14, iv=0.14), A("pose", who="princess", visual="helpless_2")]),
    _say(P, "哈……哈……投、投降……我投降……全部都太强了……！", emotion="helpless_2"),
    _say(CAP, "……关掉。"),
    _say(N, "（陷阱终于停了下来。她瘫在台子上，两只脚还在一抽一抽的）"),
    _say(CAP, "……歇一会儿。综合演练，从头再走。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_inspect": FAIL_INSPECT}
DIALOGUES = {"after_proving_guard": {"name": G, "npc": "guard", "entries": [{"node": "default"}], "nodes": {
    "default": {"lines": [{"text": "发光的垫子就是陷阱的踏板。蓝色的是辅助设施。……评分要公道哦。"}]}}}}
SIGNS = {"after_proving_locked": [{"speaker": N, "text": "（训练营的门关着。里面传来「咔哒咔哒」的机关声）"}]}
