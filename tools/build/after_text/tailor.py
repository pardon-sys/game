"""弥补任务「裁缝的试衣模特·找漏风」（第 5 天早上，裁缝铺里间）：data/after/tailor.json（TaskTailor 读）+ 过场 + 失败小剧场。
裁缝给保卫队做防痒棉衣的样品，要一个模特试穿：
  阶段一 量尺寸（暖场，不会失败）：软尺绕过腰、腋下、脚掌，每量一处痒一下。
  阶段二~四 腋下 / 腰 / 脚心（配套的棉袜）：每个部位四个点，裁缝拿羽毛一个点一个点地试——
    漏风的点「好痒！」，挨着漏风点的「有一点点」，别的「完全没感觉」；闷笑越高越敏感（没漏的点也可能觉得好痒）。
    在部位图上标出漏风的点 → 缝：标对了缝上；标错了裁缝在那个点上「仔细检查」（挠一阵、闷笑上涨）。
    可以「再试一遍」（再挠一轮）、「喝口茶歇一下」（闷笑下降，次数有限）。
  阶段五 验收：穿着走过三个「羽毛人台」（腋下 / 腰 / 脚心）。全补好 = 一点都不痒（好笑的演出）；漏补的部位被挠 → 回去重找那个部位。
  闷笑满 = 失败：after_fail_tailor（裁缝和学徒的「全身尺码复查」），罚工时，从头来（漏风点重新随机）。
做完：得到装备「防痒棉衣」。
  parts   部位：name、points 四个点、adj 相邻的点（下标对）、leaks 漏几个、intro / end 演的几句、
          test 裁缝试一个点时的话（%s = 点名）、react 公主的反应（strong 好痒 / weak 有一点点 / none 完全没感觉）、
          fixed 缝对了、check 缝错了的「仔细检查」（%s = 点名）
"""
from .common import A, N, P, line

TAILOR_N = "裁缝"
APP = "学徒"

TAILOR = {
    "measure": [
        {"speaker": TAILOR_N, "text": "先量尺寸！站直，手抬起来～（她「唰」地一下抽出脖子上挂的软尺）"},
        {"speaker": N, "text": "（软尺绕过腰，在肚脐前面一勒——冰凉的尺子贴着腰侧滑了一圈）", "tickle": "waist"},
        {"speaker": P, "text": "唔……！尺、尺子好凉……", "emotion": "surprise"},
        {"speaker": TAILOR_N, "text": "腰围……嗯，比上次那个保卫队员细多了。下一个，腋下～"},
        {"speaker": N, "text": "（软尺从左腋下穿过去，在背后绕一圈，又从右腋下钻出来。尺子的边缘蹭着腋窝，一路刮过去）", "tickle": "armpit"},
        {"speaker": P, "text": "噗……哈、哈……尺子……刮到了……！", "emotion": "helpless_1"},
        {"speaker": TAILOR_N, "text": "别动别动～量歪了要重量的哦。"},
        {"speaker": APP, "text": "师傅，脚掌也要量吗？"},
        {"speaker": TAILOR_N, "text": "当然！棉袜也是一套的。来，鞋脱了，脚踩在这张纸上～"},
        {"speaker": N, "text": "（她光脚踩上画样子的纸。裁缝蹲下来，软尺贴着脚掌，从脚跟量到脚尖，又绕着脚背量了一圈）", "tickle": "sole"},
        {"speaker": P, "text": "哈、哈哈……脚、脚心那里……尺子……别贴着脚心滑……！", "emotion": "helpless_1"},
        {"speaker": TAILOR_N, "text": "二十二码半～小小的，好可爱的脚。"},
        {"speaker": P, "text": "量尺寸就量尺寸，不、不用加感想！", "emotion": "shy"},
        {"speaker": TAILOR_N, "text": "好啦，尺寸量完。接下来才是正题——试穿！"},
    ],
    "tutorial": [
        {"speaker": TAILOR_N, "text": "这件棉衣，里面缝了三层棉絮，羽毛隔着它是挠不进去的。理论上。"},
        {"speaker": P, "text": "……「理论上」。", "emotion": "sad"},
        {"speaker": TAILOR_N, "text": "针脚有地方没缝严实，会漏风。羽毛从漏风的地方钻进去，就痒。我拿羽毛一个点一个点地试，你告诉我痒不痒。"},
        {"speaker": APP, "text": "姐姐，漏风的地方会特别痒，挨着漏风的地方会有一点点痒，别的地方应该没感觉。"},
        {"speaker": TAILOR_N, "text": "然后你在这张图上标出来，我就缝哪里。标错了的话……我只好在那个地方「仔细检查」一下咯～"},
        {"speaker": APP, "text": "还有还有，笑得太厉害的话，人会变得特别敏感，没漏风的地方也会觉得痒。看不准的时候，喝口茶歇一歇再试比较好。"},
        {"speaker": N, "text": "（每个部位：听反应找出漏风的点，在部位图上标出来再缝。闷笑满了就失败）"},
    ],
    "parts": {
        "armpit": {
            "name": "腋下", "points": ["左肩缝", "左腋窝", "右腋窝", "右肩缝"], "adj": [[0, 1], [2, 3]], "leaks": 1, "zone": "armpit",
            "intro": [
                {"speaker": TAILOR_N, "text": "第一个部位，腋下！两只手举起来，抱在脑袋后面～"},
                {"speaker": P, "text": "……为、为什么要抱在脑袋后面？", "emotion": "surprise"},
                {"speaker": TAILOR_N, "text": "这样腋下的布料才会绷紧，漏风的地方才看得出来呀。"},
                {"speaker": APP, "text": "师傅，上次给保卫队长试的时候，她也是这个姿势。"},
                {"speaker": TAILOR_N, "text": "对对，队长忍得可好了，一声都没吭。……就是试完以后三天没跟我说话。"},
                {"speaker": P, "text": "（……队长也被这样试过啊……）", "emotion": "sad"},
            ],
            "end": [
                {"speaker": TAILOR_N, "text": "腋下缝好啦～手可以放下来了。"},
                {"speaker": P, "text": "呼……手、手都举酸了……", "emotion": "helpless_1"},
                {"speaker": APP, "text": "姐姐比队长笑得多。"},
                {"speaker": P, "text": "不、不用比较！", "emotion": "angry"},
            ],
            "test": ["（羽毛尖探进%s，隔着棉布轻轻转了两圈）", "（裁缝捏着羽毛，在%s上慢慢地来回扫）", "（羽毛贴着%s，一下一下地点）"],
            "react": {
                "strong": ["呀哈哈！？这、这里！这里好痒！羽毛直接钻进来了！", "哈哈哈哈！就、就是这里！手、手要放下来了——！",
                           "咿——！痒、痒痒痒！这里绝对漏风了！", "噗哈！不行不行，这里像是什么都没穿一样……！"],
                "weak": ["唔……有、有一点点……好像是旁边漏进来的风……", "……嗯？有一点点痒……但不是这里，是旁边……",
                         "嗯……痒痒的，可是隔着一层……", "……有一点点。像是风从旁边吹过来。"],
                "none": ["……完全没感觉。棉絮好厚。", "……嗯，没感觉。真的没感觉！", "这里……什么都感觉不到。", "……没、没感觉。（这件衣服其实挺好的嘛）"],
            },
            "fixed": [{"speaker": TAILOR_N, "text": "%s，记下了！针线——（「唰唰唰」，几针就缝得严严实实）"}],
            "check": [
                {"speaker": TAILOR_N, "text": "%s漏风？……嗯？我看着挺严实的啊。我再仔细检查检查——"},
                {"speaker": N, "text": "（裁缝把羽毛换成了指尖，隔着棉布在那里按了按，又顺着腋窝的弧线一路摸过去）", "tickle": "armpit"},
                {"speaker": P, "text": "哈、哈哈！那、那里没漏！是你的手指在挠——！", "emotion": "helpless_1"},
                {"speaker": TAILOR_N, "text": "嗯……确实没漏。那就是你标错啦～"},
            ],
        },
        "waist": {
            "name": "腰", "points": ["左腰侧", "后腰", "右腰侧", "肚脐边"], "adj": [[0, 1], [1, 2], [0, 3], [2, 3]], "leaks": 2, "zone": "waist",
            "intro": [
                {"speaker": TAILOR_N, "text": "第二个部位，腰！这里的针脚最多，最容易漏～"},
                {"speaker": APP, "text": "师傅，腰这里漏了两个地方吧？我昨天缝的时候走神了。"},
                {"speaker": TAILOR_N, "text": "两个！？……你昨天在想什么？"},
                {"speaker": APP, "text": "……在想晚饭吃什么。"},
                {"speaker": P, "text": "所以我要被多挠一个地方，是因为你在想晚饭吗！", "emotion": "angry"},
                {"speaker": TAILOR_N, "text": "好啦好啦，站好～腰挺直。"},
            ],
            "end": [
                {"speaker": TAILOR_N, "text": "腰也缝好啦！"},
                {"speaker": P, "text": "……腰、腰都笑酸了……", "emotion": "helpless_1"},
                {"speaker": APP, "text": "对不起姐姐……今晚我会想着针线的。"},
                {"speaker": TAILOR_N, "text": "今晚你给我在店里缝一百个扣子！"},
            ],
            "test": ["（羽毛顺着%s，从上往下慢慢扫了一道）", "（裁缝用羽毛在%s上画了个小圈）", "（羽毛杆轻轻戳了戳%s）"],
            "react": {
                "strong": ["哈哈哈！这里！腰、腰这里漏得好厉害！", "噗哈哈哈！羽毛直接扫在肉上了——！", "呀！？好、好痒！这里绝对是漏了！",
                           "哈哈……不、不行……腰扭起来了……这里！"],
                "weak": ["唔……有一点点……大概是旁边漏的……", "……嗯，痒痒的……不是很明显……", "有一点点……风好像是从别的地方钻过来的……",
                         "……一点点。隔着棉絮，有点感觉。"],
                "none": ["……没感觉。这块缝得好好的。", "完全没感觉！……学徒这里没走神。", "……嗯，什么都没有。", "这里没感觉，很厚实。"],
            },
            "fixed": [{"speaker": TAILOR_N, "text": "%s，缝上～（她咬断线头，在那里拍了拍）"}],
            "check": [
                {"speaker": TAILOR_N, "text": "%s？我摸摸看……（五根手指隔着棉布，在腰上一下一下地捏）"},
                {"speaker": N, "text": "（指尖一捏一松，从腰侧捏到后腰，又从后腰捏回来）", "tickle": "waist"},
                {"speaker": P, "text": "哈哈哈哈！捏、捏的不算！这里明明不漏——！", "emotion": "helpless_1"},
                {"speaker": TAILOR_N, "text": "对呀，不漏。所以你标错了嘛～"},
            ],
        },
        "sole": {
            "name": "脚心（棉袜）", "points": ["脚跟", "脚弓", "脚心", "脚趾缝"], "adj": [[0, 1], [1, 2], [2, 3]], "leaks": 2, "zone": "sole",
            "intro": [
                {"speaker": TAILOR_N, "text": "最后，配套的棉袜！坐到这张凳子上，脚伸出来～"},
                {"speaker": N, "text": "（学徒捧着一双厚厚的白棉袜过来，帮她套上。袜子软乎乎的，脚趾头在里面动来动去）"},
                {"speaker": P, "text": "……这个好暖和。", "emotion": "happy"},
                {"speaker": TAILOR_N, "text": "暖和吧？可是脚底的针脚最难缝，我缝了三遍都不满意。"},
                {"speaker": APP, "text": "师傅说，脚心是全身最怕痒的地方，漏一点点都不行。"},
                {"speaker": P, "text": "……为什么你们都知道脚心是最怕痒的地方……", "emotion": "sad"},
                {"speaker": TAILOR_N, "text": "常识嘛～来，脚抬起来，我一个地方一个地方地试。"},
            ],
            "end": [
                {"speaker": TAILOR_N, "text": "棉袜也缝好啦！"},
                {"speaker": P, "text": "呼……脚、脚趾头都抽筋了……", "emotion": "helpless_1"},
                {"speaker": APP, "text": "姐姐，你的脚趾隔着袜子都在动。"},
                {"speaker": P, "text": "那、那是因为痒啊！", "emotion": "angry"},
            ],
            "test": ["（羽毛隔着棉袜，在%s上轻轻地扫）", "（裁缝捏住她的脚踝，羽毛尖对准%s，一下一下地点）", "（羽毛顺着%s，慢悠悠地画了一道弧）"],
            "react": {
                "strong": ["呀哈哈哈！这、这里！袜子跟没穿一样——！", "哈哈哈哈！痒、痒痒痒！漏了漏了！", "咿呀！？脚、脚趾蜷起来了……就是这里！",
                           "噗哈哈！羽毛直接碰到皮肤了！这里！"],
                "weak": ["唔……有一点点……旁边好像有风……", "……嗯，有点痒……但不是正好这里……", "一、一点点……脚趾头想动……",
                         "……有一点点感觉，隔着袜子……"],
                "none": ["……没感觉，好厚的袜子。", "……完全没感觉！这里缝得真好。", "嗯……什么都没有。（暖暖的）", "……没感觉。"],
            },
            "fixed": [{"speaker": TAILOR_N, "text": "%s，缝好！（针线隔着袜子穿来穿去，痒得她脚趾又是一蜷）"}],
            "check": [
                {"speaker": TAILOR_N, "text": "%s漏了？……让我仔细检查一下。（她把袜子往下褪了一点）"},
                {"speaker": N, "text": "（裁缝的指甲隔着薄了一半的袜子，在那里来回刮——刮完一遍，又刮了一遍）", "tickle": "sole"},
                {"speaker": P, "text": "哈哈哈哈！你、你把袜子褪下来了啊！那当然痒——！", "emotion": "helpless_2"},
                {"speaker": TAILOR_N, "text": "嗯，穿好的时候不漏。是你标错啦～（把袜子拉了回去）"},
            ],
        },
    },
    "menu": {"prompt": "标出漏风的点（%s）", "retest": "再试一遍（再挠一轮）", "tea": "喝口茶歇一下（还能喝 %d 次）", "sew": "就缝这些！",
             "unknown": "还没试过", "mark": "【标记】"},
    "reaction_names": {"strong": "好痒！", "weak": "有一点点", "none": "完全没感觉"},
    "tea": [{"speaker": APP, "text": "姐姐，喝口茶～（学徒端来一杯温温的花茶）"}, {"speaker": P, "text": "……呼……活过来了……", "emotion": "happy"}],
    "no_tea": [{"speaker": APP, "text": "……茶喝完了。"}],
    "empty_mark": [{"speaker": TAILOR_N, "text": "一个都没标？那我缝哪里呀～至少标一个嘛。"}],
    "inspect_intro": [
        {"speaker": TAILOR_N, "text": "全部缝好了！最后是验收——穿着走过那边三个人台。"},
        {"speaker": N, "text": "（里间的另一头摆着三个人台。每个人台上都绑着几根长长的羽毛臂，「吱呀吱呀」地转着）"},
        {"speaker": P, "text": "……那、那是什么……", "emotion": "surprise"},
        {"speaker": TAILOR_N, "text": "我的得意之作，「羽毛人台」！第一个专挠腋下，第二个专挠腰，第三个专挠脚心。"},
        {"speaker": APP, "text": "上次队长走到第二个就……"},
        {"speaker": TAILOR_N, "text": "嘘——！好啦，走过去吧！缝好了的话，一点都不会痒的～"},
        {"speaker": N, "text": "（穿过三个羽毛人台，走到那头的镜子前）"},
    ],
    "inspect_pass": [
        {"speaker": N, "text": "（羽毛臂「呼呼」地扫过腋下、扫过腰、扫过脚心——）"},
        {"speaker": P, "text": "……"},
        {"speaker": P, "text": "…………咦？", "emotion": "surprise"},
        {"speaker": P, "text": "不痒？一、一点都不痒！？", "emotion": "happy"},
        {"speaker": N, "text": "（她不敢相信，又倒回去走了一遍。羽毛臂在腋下转了三圈，在腰上扫了五下，在脚心上刷了十几下——）"},
        {"speaker": P, "text": "哈哈！真的不痒！你看你看！我还可以在这里跳！", "emotion": "happy"},
        {"speaker": N, "text": "（她在第三个人台前面蹦了起来，任由羽毛臂扫来扫去，得意地叉着腰）"},
        {"speaker": APP, "text": "……姐姐好像在跟人台炫耀。"},
        {"speaker": TAILOR_N, "text": "成功啦！这件棉衣可以给保卫队做五十件了！"},
        {"speaker": N, "text": "（——话音刚落，第三个人台的羽毛臂一转，从袜口的缝隙里钻了进去，在脚踝上扫了一下）"},
        {"speaker": P, "text": "呀哈！？……袜、袜口……！", "emotion": "surprise"},
        {"speaker": TAILOR_N, "text": "……袜口不算！袜口不算！那是穿的时候没拉好！"},
    ],
    "inspect_leak": {
        "armpit": [{"speaker": N, "text": "（第一个人台的羽毛臂一扫，直接钻进了腋下——还有没缝上的地方！）", "tickle": "armpit"},
                   {"speaker": P, "text": "哈哈哈！腋、腋下还漏着——！", "emotion": "helpless_1"},
                   {"speaker": TAILOR_N, "text": "哎呀，腋下还有漏的地方没找到。回去重新试！"}],
        "waist": [{"speaker": N, "text": "（第二个人台的羽毛臂在腰上转了一圈——痒意从没缝的针脚里钻了进来）", "tickle": "waist"},
                  {"speaker": P, "text": "噗哈哈！腰、腰还是痒——！", "emotion": "helpless_1"},
                  {"speaker": TAILOR_N, "text": "腰还漏着！回来回来，再找一遍～"}],
        "sole": [{"speaker": N, "text": "（第三个人台的羽毛刷「唰」地刷过脚底，袜子里有地方根本挡不住）", "tickle": "sole"},
                 {"speaker": P, "text": "哈哈哈哈！脚、脚心！袜子还漏着——！", "emotion": "helpless_2"},
                 {"speaker": TAILOR_N, "text": "棉袜还有漏的！坐回凳子上～"}],
    },
}


def d5_tailor():
    s = [
        {"actions": [A("face", who="after_tailor", dir="down"), A("camera", to=[9, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(TAILOR_N, "来啦来啦！赎罪簿上写的「试衣模特」，就是你吧？"),
        line(P, "试衣模特……？我还以为是帮忙搬布料……", "surprise"),
        line(TAILOR_N, "搬布料那种粗活，学徒干就好啦。你的活儿可重要多了～"),
        line(APP, "师傅在给保卫队做防痒棉衣。攻防战的时候，好多队员被敌人的羽毛挠得站都站不稳。"),
        line(TAILOR_N, "所以！我做了一件「绝对挠不进去」的棉衣样品！"),
        line(P, "绝对挠不进去……那很好啊。", "happy"),
        line(TAILOR_N, "就是还没试过。要找一个最怕痒的人来试——怕痒的人穿着都不痒，那就是真的成功了。"),
        line(P, "……为什么是我？", "sad"),
        line(TAILOR_N, "队长推荐的～她说你是全镇最怕痒的。"),
        line(P, "队、队长……！", "angry"),
        line(APP, "队长还说，你的脚心特别……"),
        line(TAILOR_N, "咳咳！那个不用说出来！"),
        line(P, "（……队长到底跟多少人说过了……）", "shy"),
        line(TAILOR_N, "好啦，先量尺寸！站到镜子前面来～"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "裁缝的试衣模特", "letterbox": True, "skippable": True, "steps": s}


def d5_tailor_done():
    s = [
        {"actions": [A("face", who="after_tailor", dir="down"), A("camera", to=[9, 6], zoom=1.0, time=0.4)], "wait": 0.4},
        line(TAILOR_N, "辛苦啦，模特小姐！样品完全成功～"),
        line(TAILOR_N, "这一件就送你了。（她把棉衣叠好，塞进她怀里）"),
        line(N, "（得到了「防痒棉衣」：腋下、腰、脚心各挡下几次挠痒；在篝火 / 存档点休息时恢复）", None, [A("item", id="equip_tailor_coat"), A("sfx", sound="pickup")]),
        line(P, "……送、送我？", "surprise"),
        line(TAILOR_N, "你帮我找出了五个漏风的地方，这件是你的功劳。以后再遇到那些羽毛怪，就不怕啦～"),
        line(APP, "姐姐穿着它，就算去示众……"),
        line(P, "不会再去示众了！！", "angry"),
        line(TAILOR_N, "呵呵。……说起来，你量尺寸的时候，我总觉得在哪里见过这个尺码。"),
        line(P, "尺码？", "surprise"),
        line(TAILOR_N, "很多年以前，有人来我这里订过一双小小的棉袜……也是二十二码半。……哎，记不清了，大概是我记错了。"),
        line(P, "……", "sad"),
        line(TAILOR_N, "好啦好啦，下午还有活儿吧？快去吧～"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "防痒棉衣", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"after_d5_tailor": d5_tailor, "after_d5_tailor_done": d5_tailor_done}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, zone="sole", fx="feather", n=8, iv=0.22):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


FAIL_TAILOR = {"name": "试衣失败：全身尺码复查", "cast": {
    "princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
    "tl": {"kind": "npc:tailor", "at": [-28, 8], "dir": "right"},
    "ap": {"kind": "npc:apprentice", "at": [28, 8], "dir": "left"},
}, "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(TAILOR_N, "哎呀呀，笑成这样，量好的尺寸全乱了。"),
    _say(P, "乱、乱了……？那、那要怎么办……", emotion="surprise"),
    _say(TAILOR_N, "只好——「全身尺码复查」！学徒，拿软尺来～"),
    _say(APP, "来了！（两根软尺，一人一根）"),
    _say(N, "（裁缝的软尺绕上了腰，学徒的软尺穿过了腋下。两根尺子同时一拉——）", [_tk("tl", zone="waist", n=8, iv=0.22), _tk("ap", zone="armpit", n=8, iv=0.22)]),
    _say(P, "哈哈哈哈！一、一起拉是犯规的——！", [A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.5)], portrait="defeat_1"),
    _say(TAILOR_N, "腰围……哎呀，你一直在扭，量不准。学徒，按住她的手。"),
    _say(APP, "是！（学徒把她的两只手举过头顶，按在了人台上）"),
    _say(TAILOR_N, "腋下的尺寸也重新量～（软尺贴着腋窝，一寸一寸地往里挪）", [_tk("tl", zone="armpit", n=12, iv=0.18)]),
    _say(P, "呀哈哈！胳、胳肢窝……！一寸一寸的……更痒了——！", emotion="helpless_2"),
    _say(APP, "师傅，还有脚。"),
    _say(TAILOR_N, "对对，脚掌！刚才的数字被她笑得抖掉了。（她蹲下来，捏住一只光着的脚丫）"),
    _say(N, "（软尺从脚跟慢慢滑到脚尖，又从脚尖滑回来。尺子的边缘刮过脚心，刮过脚弓，在每一道脚趾缝里都停一下「对刻度」）", [_tk("tl", zone="sole", n=16, iv=0.16)]),
    _say(P, "哈哈哈哈哈！对、对什么刻度啊！脚趾缝里没有刻度——！", portrait="defeat_2"),
    _say(APP, "师傅，她的脚趾一直在动，量不准。"),
    _say(TAILOR_N, "那你帮我扳开～一根一根地量。", [_tk("ap", zone="sole", n=12, iv=0.18), A("pose", who="princess", visual="helpless_2")]),
    _say(P, "不、不要扳——哈哈哈哈！一根……一根地……呜哈哈哈……！", emotion="helpless_2"),
    _say(TAILOR_N, "好～啦。腰围、腋下、脚掌，全部重新量好了。"),
    _say(TAILOR_N, "数字嘛……跟第一次量的一模一样。"),
    _say(P, "那、那刚才那些是干什么的啊……！", emotion="angry"),
    _say(TAILOR_N, "复查嘛～休息一下，从头再试一遍！"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_tailor": FAIL_TAILOR}


# —— 裁缝 / 学徒 / 里间的东西 / 招牌（gen_floor06_after 写进 data/dialogues/floor_06/）
def _by_day(name, npc_id, days, default):
    entries, nodes = [], {}
    for d, body in days.items():
        entries.append({"if": {"var": {"after_day": ["==", d]}}, "node": "d%d" % d})
        nodes["d%d" % d] = {"lines": body}
    entries.append({"node": "default"})
    nodes["default"] = {"lines": default}
    return {"name": name, "npc": npc_id, "entries": entries, "nodes": nodes}


DIALOGUES = {
    "after_tailor": _by_day(TAILOR_N, "tailor", {
        5: [{"text": "模特小姐～今天的活儿就靠你啦！"}],
    }, [{"text": "防痒棉衣在给保卫队赶工呢。五十件！……学徒，你的扣子缝完了没？"}]),
    "after_apprentice": _by_day(APP, "apprentice", {
        5: [{"text": "姐姐……腰那里漏的两个地方，是我缝的。对不起……"}],
    }, [{"text": "（学徒埋头缝扣子，嘴里数着：「三十七、三十八……」）"}]),
    "after_tailor_objects": {"name": "", "entries": [{"node": "fabric"}], "nodes": {
        "fabric": {"lines": [{"speaker": N, "text": "（一卷卷彩色的布料，粉的、蓝的、黄的……最下面压着一卷厚厚的白棉布）"}]},
        "form": {"lines": [{"speaker": N, "text": "（人台上套着一件还没缝完的棉衣，插着好几根针）"},
                           {"speaker": P, "text": "……这个人台的腰，跟我差不多细。", "emotion": "surprise"}]},
        "mirror": {"lines": [{"speaker": N, "text": "（落地镜。镜子里的自己头发有点乱）"}]},
        "desk": {"lines": [{"speaker": N, "text": "（工作台上摊着一本尺码簿。最旧的一页上写着：「二十二码半，小棉袜一双，记账——」后面的字被墨水晕开了）"}]},
    }},
}
SIGNS = {"after_tailor_sign": [{"speaker": "招牌", "text": "【裁缝铺】量体裁衣、缝补、改尺寸。……现招试衣模特一名（要怕痒的）。"}]}

# 图像不烘焙数字：点位与既有四个选项顺序一致，腰部图左为正面、右为背面。
TAILOR["chart_legend"] = "红：明显　黄：轻微　绿×：已缝"
for _key, _points in {
    "armpit": [[0.72, 0.23], [0.70, 0.50], [0.30, 0.50], [0.28, 0.23]],
    "waist": [[0.43, 0.50], [0.74, 0.50], [0.10, 0.50], [0.27, 0.50]],
    "sole": [[0.50, 0.84], [0.48, 0.58], [0.50, 0.34], [0.50, 0.14]],
}.items():
    TAILOR["parts"][_key]["chart"] = {
        "texture": "res://assets/generated/after/tailor_%s.png" % _key,
        "points_uv": _points,
    }
