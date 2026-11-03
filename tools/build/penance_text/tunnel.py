"""反省篇第二章·鼠洞（floor_06_rat_tunnel，等距；RatTunnel）：粉色公主穿着鼠鼠装（挠脚鼠住在短裤里）一路往里爬。
三段挠脚鼠的小剧场（纯小剧场，走到就演）：大腿根（tunnel_thigh）/ 脚心（tunnel_sole，缝外守卫走过）/ 上下窜（tunnel_shaft，本章章末大段 + CG）；
老鼠窝（tunnel_nest，按 E）、被橘猫追上（tunnel_cat_first / tunnel_cat）、刻字的死胡同（线索）。只写痒、笑、释放后的舒服；她是成年人。
"""
from .common import A, GUARD, L, N, P, PRINCESS, RAT, burst, cg, dfile, line, pose, say, theater, tk

CAT = "橘猫"
RATS = "小老鼠们"

# 玩法里的短台词（data/after/tunnel.json，RatTunnel 读）
TEXT = {
    "cat_start": ["那、那只猫！它跟进来了——！", "哇啊！猫！快跑！", "它闻到鼠味了……全是这条短裤的错！"],
    "drip": ["冰、冰的！……呀！它被吓得乱窜了！", "水滴……别滴了……它又醒了……！", "噫！一滴水，它就从腿上窜到脚底……！"],
}


def _rat(at=(12, 10)):
    return {"kind": "monster:rat", "at": list(at), "dir": "left"}


# ---------------------------------------------------------------- ① 低矮的缝：大腿根
THIGH = theater("鼠洞①：低矮的缝", {
    "princess": dict(PRINCESS, at=[0, 8], visual="normal"),
    "rat": _rat(),
}, [
    say(N, "（洞越走越矮。到这里，已经只能趴下来，用胳膊肘一点一点往前挪了）", act=1),
    say(P, "……好窄。头发都蹭到顶上了……", emotion="sad"),
    say(RAT, "（从短裤里探出头）吱吱。别停，再往前爬一段就宽了。"),
    say(P, "你、你给我老实待着。不许乱动。", emotion="angry"),
    say(RAT, "我很老实呀。……就是这里有点闷。我出来透透气。"),
    say(N, "（短裤里有什么东西拱了一下。毛茸茸的一团，从屁股这边慢慢挪到了大腿根）", [tk("rat", zone="thigh", fx="hand", n=4, iv=0.3), pose("giggle")]),
    say(P, "噫……！你说透气，为什么往那边跑！", emotion="giggle"),
    say(RAT, "这边比较凉快嘛。吱。"),
    say(N, "（她一下子僵住了。缝太矮，翻不了身，也伸不过手去——只能趴着，任由那团毛在腿根上转圈）", [tk("rat", zone="thigh", fx="feather", n=8, iv=0.2)], act=2),
    say(P, "（……别动……别动……一动就卡住了……）", emotion="giggle"),
    say(N, "（挠脚鼠的小爪子一下一下地踩，胡子尖扫过腿根最软的那一圈）", [tk("rat", zone="thigh", fx="feather", n=10, iv=0.16)]),
    say(P, "嘻……嘻嘻……胡、胡子……不要用胡子……！", emotion="giggle"),
    say(RAT, "不用胡子怎么认路呀。吱吱。"),
    say(P, "你在短裤里认什么路——！", emotion="angry"),
    say(N, "（她想往前爬快一点，膝盖一用力，腿一夹——那团毛被夹住了，吱地叫了一声，开始拼命往外挤）",
        [tk("rat", zone="thigh", fx="hand", n=12, iv=0.12), pose("helpless_1")], act=3),
    say(P, "哈……哈哈……别、别挤……越挤越……！", emotion="helpless_1"),
    say(RAT, "是你夹住我的！吱！松开松开！"),
    say(N, "（她一松腿，挠脚鼠就顺着腿根「嗖」地钻到了另一边，又从另一边钻回来，来回好几趟）",
        [tk("rat", zone="thigh", fx="feather", n=14, iv=0.11), A("tickle", who="princess", by="rat", zone="butt", fx="hand", repeat=8, interval=0.14)]),
    say(P, "哈哈哈哈！两边……两边来回跑……！趴着动不了……哈哈哈！", [pose("helpless_2")], emotion="helpless_2"),
    say(N, "（缝太矮了。她笑得直捶地，脑袋「咚」地撞到了顶上，又笑得更厉害了）", [A("shake", who="princess", time=0.4)]),
    say(P, "撞、撞到头了……哈哈……好痛……可是好痒……哈哈哈！", emotion="helpless_2"),
    say(RAT, "吱吱，别笑那么大声嘛，顶上的土要掉下来了。"),
    say(N, "（土簌簌地往下掉。魔力也跟着笑声一起，一点一点地满了上来）", [tk("rat", zone="thigh", fx="feather", n=12, iv=0.1)]),
    burst("（星光在窄窄的缝里炸开，照亮了整条洞……哈啊……放出去了……身体暖洋洋的……好舒服……）"),
    say(N, "（挠脚鼠被星光吓了一跳，一头钻回了短裤深处——正好贴着刚释放完、敏感得发烫的腿根）", [tk("rat", zone="thigh", fx="hand", n=8, iv=0.15), pose("helpless_2")], act=4),
    say(P, "呀……！现、现在不要动……一点点都不行……！", emotion="helpless_2"),
    say(RAT, "我在发抖嘛！你的魔法好可怕！吱吱吱！"),
    say(N, "（它一抖，小爪子就在腿根上抖出一串痒。她趴在地上，一边笑一边求饶）", [tk("rat", zone="thigh", fx="feather", n=12, iv=0.12)]),
    say(P, "……哈哈……别抖了……我、我不放魔法了……你也别抖了……", emotion="helpless_2"),
    say(N, "（好一会儿，那团毛才安静下来，在短裤里蜷成一个球。前面的缝也终于宽了一点）", [pose("helpless_1")]),
    say(P, "……哈……哈……出去以后……我第一件事就是把这条短裤扔掉……", emotion="helpless_1"),
    say(RAT, "吱。那我住哪里呀。"),
    say(P, "……爱住哪住哪！", emotion="angry"),
])

# ---------------------------------------------------------------- ② 窄缝：脚心（缝外守卫走过，要憋住）
SOLE = theater("鼠洞②：卡住的脚", {
    "princess": dict(PRINCESS, at=[-6, 8], visual="normal"),
    "rat": _rat((14, 12)),
    "guard": {"kind": "npc:guard", "at": [70, 2], "dir": "left", "hidden": True},
}, [
    say(N, "（前面是一道窄窄的石缝。她侧着身子挤过去——挤到一半，后面那只脚卡住了）", act=1),
    say(P, "……拔、拔不出来……鼠爪鞋太大了……", emotion="surprise"),
    say(RAT, "吱吱，别急，我去帮你看看。"),
    say(N, "（「嗖」。毛茸茸的一团顺着腿一路滑下去，钻进了卡在缝里的那只鼠爪鞋）", [tk("rat", zone="sole", fx="hand", n=4, iv=0.25), pose("giggle")]),
    say(P, "你、你下去干什么——！我是让你……不对，我没让你下去！", emotion="surprise"),
    say(RAT, "（在鞋里）嗯……这只脚卡得好紧。我得找找哪里松一点。"),
    say(N, "（小鼻子贴着脚心，一路嗅过去。嗅到脚趾那里，停住了）", [tk("rat", zone="sole", fx="feather", n=6, iv=0.25)], act=2),
    say(RAT, "……嗯？这里有面包的香味。"),
    say(P, "早、早上吃的面包……掉了点渣……别、别闻了……！", emotion="giggle"),
    say(RAT, "哪个缝里最香呢……吱吱。我一个一个找。"),
    say(N, "（它开始挨个舔脚趾缝。从大脚趾和第二根中间开始，慢慢地、认真地舔过去）", [tk("rat", zone="sole", fx="lines", n=10, iv=0.18)]),
    say(P, "嘻嘻嘻……！不、不要一个一个……！", emotion="giggle"),
    say(N, "（这时候，缝的另一头传来了脚步声。哒、哒、哒——是营地夜里巡逻的保卫队员）",
        [A("sfx", sound="step", volume=-4.0), A("enter", who="guard", to=[40, 2], time=0.8)], act=3),
    say(GUARD, "……嗯？墙里面是不是有什么声音？"),
    say(P, "（……！不、不能出声……被发现就要被抓回反省室……！）", [pose("helpless_1")], emotion="helpless_1"),
    say(N, "（她捂住嘴，憋得满脸通红。鞋里的挠脚鼠一点都不知道外面有人——它舔到了第三个缝）", [tk("rat", zone="sole", fx="lines", n=12, iv=0.14)]),
    say(RAT, "（小声）这个缝……嗯，不对，还不是最香的。"),
    say(P, "（……呜……呜呜……求你了……先、先别舔了……）", emotion="helpless_1"),
    say(GUARD, "……老鼠吧。墙里面老鼠多。", [A("move", who="guard", to=[30, 2], time=0.6)]),
    say(N, "（守卫没有走。他在墙外面停下来，靠着墙，打了个大大的呵欠——就隔着一道石缝，离她的脚只有一臂远）"),
    say(N, "（挠脚鼠舔完了趾缝，开始在脚心正中央画圈。小爪子踩上去，一下，一下，又一下）", [tk("rat", zone="sole", fx="feather", n=14, iv=0.12), pose("helpless_2")]),
    say(P, "（……脚、脚心……！不行了……要、要笑出来了……！）", emotion="helpless_2"),
    say(RAT, "找到了！最香的是小脚趾那个缝！吱吱！"),
    say(N, "（它高兴地在小脚趾缝里舔了好几口——憋着的笑一下子冲到了嗓子眼，连同魔力一起）", [tk("rat", zone="sole", fx="lines", n=14, iv=0.1)]),
    burst("（「噗——」……星光从石缝里一下子喷了出去……哈啊……全、全放出去了……好舒服……）"),
    say(GUARD, "什、什么！？墙里在发光！？……闹、闹鬼了——！", [A("shake", who="guard", time=0.4), A("move", who="guard", to=[90, 2], time=0.5)]),
    say(N, "（守卫跑远了。可鞋里的挠脚鼠还在——它舔得正起劲，对着刚释放完、敏感得发烫的脚心又舔了一口）", [tk("rat", zone="sole", fx="lines", n=8, iv=0.15), pose("helpless_2")], act=4),
    say(P, "哈哈哈哈！不用憋了……可是……可是现在一碰就……哈哈哈！", emotion="helpless_2"),
    say(N, "（她终于能放开笑了。笑得整个人在缝里抖，那只卡住的脚一抖一抖地——「啵」地一声，从缝里拔了出来）", [tk("rat", zone="sole", fx="feather", n=10, iv=0.13), A("shake", who="princess", time=0.5)]),
    say(P, "……出、出来了……原来要笑着抖才拔得出来……", emotion="helpless_1"),
    say(RAT, "（从鞋里钻出来，舔舔嘴巴）吱。面包很好吃。谢谢招待。"),
    say(P, "……下次再敢舔……我就把你和面包一起……！", [pose("helpless_1")], emotion="angry"),
    say(RAT, "吱吱，下次你记得多掉一点渣。"),
])

# ---------------------------------------------------------------- ③ 竖井：上下窜（本章章末大段 + CG）
SHAFT = theater("鼠洞③：竖井", {
    "princess": dict(PRINCESS, at=[0, 6], visual="normal"),
    "rat": _rat((12, 4)),
}, [
    say(N, "（洞的尽头是一口竖井。抬头看上去，很高很高的地方，有一点点光）", act=1),
    say(RAT, "吱吱。爬上去就到了。最后一段啦。"),
    say(P, "……终于。再忍一会儿，就能把这条短裤扔掉了。", emotion="happy"),
    say(RAT, "可是我舍不得你呀。吱。……最后一段，我们好好告个别吧。"),
    say(P, "……你说的「告别」，我怎么听着这么不对劲。", emotion="question"),
    say(N, "（她踩着井壁上的凹坑往上爬。爬到一半，两只手两只脚都撑在井壁上——一点都腾不出来）", act=2),
    say(N, "（短裤里，那团毛动了。它从屁股出发，「嗖」地一路窜到了大腿根）", [A("tickle", who="princess", by="rat", zone="thigh", fx="hand", repeat=6, interval=0.15), pose("giggle")]),
    say(P, "呀！现、现在不行！我两只手都……！", emotion="giggle"),
    say(RAT, "所以才是现在呀。吱吱。"),
    say(N, "（它没有停。顺着腿一路滑下去，钻进鼠爪鞋里，在脚心上踩了两圈——又顺着腿一路窜回腰上）",
        [tk("rat", zone="sole", fx="lines", n=6, iv=0.14), A("tickle", who="princess", by="rat", zone="waist", fx="hand", repeat=6, interval=0.14)]),
    say(P, "噫——！下、下去又上来……你在我身上跑来跑去……！", emotion="giggle"),
    say(N, "（腰、腿根、膝盖窝、脚心。再从脚心、膝盖窝、腿根、腰。一趟，两趟，三趟）",
        [A("tickle", who="princess", by="rat", zone="waist", fx="hand", repeat=8, interval=0.12), A("tickle", who="princess", by="rat", zone="thigh", fx="feather", repeat=8, interval=0.12), tk("rat", zone="sole", fx="lines", n=8, iv=0.12)], act=3),
    cg(say(P, "哈哈哈哈！上上下下的——停、停一下！我要掉下去了——哈哈哈！", [pose("helpless_2")], emotion="helpless_2")),
    say(RAT, "掉不下去的，你抓得可紧了。吱吱。"),
    say(N, "（她笑得脚下一滑——只剩两只手死死抓着一根树根，整个人吊在了井的半中间，两条腿在半空里乱蹬，一只鼠爪鞋也蹬掉了）", [A("shake", who="princess", time=0.4)]),
    say(P, "哈……哈哈……吊、吊着了……这一路……我就没有不狼狈的时候……！", emotion="helpless_2"),
    say(N, "（挠脚鼠趁机扒在了那只光着的脚上。胡子贴着脚心扫来扫去，两只小前爪捧着她的脚趾，一根一根地掰开，在每一道缝里轻轻地挠）", [tk("rat", zone="sole", fx="lines", n=16, iv=0.1)]),
    say(P, "哈哈哈哈！脚趾……一根一根……不要……！", emotion="helpless_2"),
    say(RAT, "这是告别的仪式。吱。挠脚鼠一族，送别人的时候，要把每个脚趾缝都挠一遍。"),
    say(P, "哪、哪有这种仪式——哈哈哈！你现编的吧——！", emotion="helpless_2"),
    say(N, "（挠完脚趾，它又「嗖」地窜回大腿根，在那里转了好几圈，尾巴扫来扫去）", [A("tickle", who="princess", by="rat", zone="thigh", fx="feather", repeat=14, interval=0.1)]),
    say(P, "我、我认输……挠脚鼠大人……我认输……哈哈哈……眼泪都……！", emotion="helpless_2"),
    say(N, "（笑声在竖井里一圈一圈地回荡，越来越响。魔力也跟着一圈一圈往上涨——）", [tk("rat", zone="sole", fx="lines", n=12, iv=0.1)]),
    burst("（星光从井底一直冲到井口，把整口竖井照得亮堂堂的……哈啊……哈……好、好舒服……身体轻飘飘的……）"),
    say(N, "（星光托着她往上一送，她终于够到了井口的边。……可挠脚鼠还在。它爬到她刚释放完、敏感得发烫的腰上，轻轻地挠了一下）",
        [A("tickle", who="princess", by="rat", zone="waist", fx="hand", repeat=6, interval=0.15), pose("helpless_2")], act=4),
    say(P, "呀啊……！不、不要……释放完以后……一下都……！", emotion="helpless_2"),
    say(RAT, "最后一下，最后一下。吱。"),
    say(N, "（「最后一下」变成了最后十下。腰侧、腿根、脚心，它把这一路走过的地方又挨个告别了一遍）",
        [A("tickle", who="princess", by="rat", zone="waist", fx="hand", repeat=8, interval=0.12), A("tickle", who="princess", by="rat", zone="thigh", fx="feather", repeat=8, interval=0.12),
         tk("rat", zone="sole", fx="lines", n=8, iv=0.12)]),
    say(P, "哈哈哈……骗子……你这个……哈哈哈……小骗子……！", emotion="helpless_2"),
    say(N, "（她扒着井口的边，笑得一点力气都没有，好半天才一点一点地翻了上去，仰面躺在地上）", [pose("helpless_1")]),
    say(P, "……哈……哈……爬、爬出来了……", emotion="helpless_1"),
    say(RAT, "（从短裤里探出头，舔了舔鼻子）吱吱。你笑起来很好听。……和以前那个小姑娘一模一样。"),
    say(P, "……以前那个？", emotion="question"),
    say(RAT, "挖这条洞的小姑娘。她也是一边爬一边笑，说要去找她的姐姐。……吱。走吧，外面就是了。"),
])

# ---------------------------------------------------------------- 老鼠窝（岔路，按 E）
NEST = theater("鼠洞的老鼠窝", {
    "princess": dict(PRINCESS, at=[0, 8], visual="normal"),
    "r1": {"kind": "monster:rat", "at": [-16, 12], "dir": "right"},
    "r2": {"kind": "monster:rat", "at": [16, 12], "dir": "left"},
    "r3": {"kind": "monster:rat", "at": [0, 16], "dir": "up"},
}, [
    say(N, "（岔路的尽头是一个小小的窝，铺满了碎布和面包渣。十几只小老鼠抬起头，齐刷刷地看着她）", act=1),
    say(RATS, "吱？吱吱？……吱吱吱！"),
    say(RAT, "（从短裤里探出头）它们说，你身上有我的味道。它们以为你是新来的老大。"),
    say(P, "老、老大？我才不是老鼠……", emotion="surprise"),
    say(N, "（小老鼠们一拥而上，围着她的鼠爪鞋转圈，一边转一边用小脑袋蹭她的脚趾）", [tk("r1", fx="lines", n=6, iv=0.2), tk("r2", fx="lines", n=6, iv=0.2), pose("giggle")], act=2),
    say(P, "嘻……嘻嘻……不、不要蹭……我不当老大……！", emotion="giggle"),
    say(RAT, "吱吱，老大要被挠一挠脚心，这是规矩。"),
    say(P, "又、又是规矩！你们老鼠的规矩怎么都是挠人！", emotion="angry"),
    say(N, "（小老鼠们排好队。一只一只地钻进鼠爪鞋，在脚心上踩一圈，再钻出来换下一只）",
        [tk("r1", fx="lines", n=8, iv=0.16), tk("r3", fx="feather", n=8, iv=0.16), pose("helpless_1")], act=3),
    say(P, "哈哈……排、排队挠……一只一只来……哈哈哈！", emotion="helpless_1"),
    say(N, "（排在后面的等不及了，干脆三四只一起钻进去，在脚心上挤成一团）", [tk("r1", fx="lines", n=12, iv=0.11), tk("r2", fx="lines", n=12, iv=0.11), tk("r3", fx="feather", n=12, iv=0.11), pose("helpless_2")]),
    say(P, "哈哈哈哈！一起来不行——脚心——要满了——！", emotion="helpless_2"),
    burst("（星光一下子在窝里炸开，碎布和面包渣飞得满天都是……哈啊……好舒服……）"),
    say(N, "（小老鼠们被吓得四散——过了一会儿，又一只一只地探出头来，凑过去蹭她刚释放完、敏感得发烫的脚趾）", [tk("r2", fx="feather", n=8, iv=0.16), pose("helpless_2")], act=4),
    say(P, "……哈哈……轻、轻一点……现在轻轻一下都……！", emotion="helpless_2"),
    say(RATS, "吱吱！吱吱吱！（它们把一块面包渣恭恭敬敬地推到了她面前）"),
    say(RAT, "它们说，欢迎老大。这是见面礼。"),
    say(P, "……谢、谢谢……不过我真的不是老大……", emotion="helpless_1"),
    say(N, "（她捡起那块面包渣，揉着发麻的脚心站了起来。小老鼠们一直把她送到了岔路口）", [pose("helpless_1")]),
])

# ---------------------------------------------------------------- 被橘猫追上
CAT_FIRST = theater("鼠洞里的橘猫", {
    "princess": dict(PRINCESS, at=[0, 8], visual="helpless_1", anim="helpless"),
    "cat": {"kind": "trap:cat_guard", "at": [12, 10]},
}, [
    say(N, "（橘猫一个飞扑，把她压在了地上。它不是来抓她的——它是来抓短裤里那只老鼠的）", [A("shake", who="princess", time=0.4)], act=1),
    say(CAT, "喵！喵喵！"),
    say(RAT, "（在短裤里）吱吱吱！别让它进来！别让它进来！"),
    say(N, "（猫爪子扒着短裤，扒不进去，就在大腿根上扒来扒去；尾巴扫着膝盖窝）", [A("tickle", who="princess", by="cat", zone="thigh", fx="feather", repeat=10, interval=0.15), pose("helpless_1")], act=2),
    say(P, "哈哈……别、别扒那里……老鼠在里面……不对，你也别抓老鼠……哈哈！", emotion="helpless_1"),
    say(N, "（挠脚鼠吓得一路逃到了鼠爪鞋里。橘猫立刻追过去，对着鞋——连着鞋里的脚心——一口一口地舔）", [tk("cat", fx="lines", n=12, iv=0.12), pose("helpless_2")], act=3),
    say(P, "哈哈哈哈！舌头……舌头好粗——脚心——哈哈哈！", emotion="helpless_2"),
    say(RAT, "吱吱吱！我在这里……不对，我不在这里！"),
    burst("（星光「砰」地炸开，橘猫被吓得毛全竖了起来……哈啊……放出去了……好舒服……）"),
    say(N, "（猫跳开了，又迈着步子走回来，在刚释放完、敏感得发烫的脚心上慢悠悠地舔了一口，才心满意足地走了）", [tk("cat", fx="lines", n=6, iv=0.18), pose("helpless_2")], act=4),
    say(P, "……哈……哈……这只猫……从牢房一路追到这里……", emotion="helpless_1"),
    say(RAT, "吱……它会在前面等着的。下次跑快点——冲刺！"),
    say(P, "……知道了。……回刚才那里重新跑。", emotion="angry"),
])

CAT_AGAIN = theater("又被橘猫追上了", {
    "princess": dict(PRINCESS, at=[0, 8], visual="helpless_1", anim="helpless"),
    "cat": {"kind": "trap:cat_guard", "at": [12, 10]},
}, [
    say(N, "（又被扑倒了。橘猫熟门熟路地扒掉一只鼠爪鞋，开始舔脚心）", [tk("cat", fx="lines", n=8, iv=0.14), pose("helpless_1")], act=1),
    say(P, "哈哈……又、又来……！", emotion="helpless_1"),
    say(RAT, "吱吱吱！冲刺！冲刺呀！"),
    say(N, "（舌头一下一下地刷过脚心，尾巴扫着腿根。她笑得一点力气都没有）", [tk("cat", fx="lines", n=12, iv=0.11), A("tickle", who="princess", by="cat", zone="thigh", fx="feather", repeat=8, interval=0.13), pose("helpless_2")], act=3),
    say(P, "哈哈哈！投降……我投降……！", emotion="helpless_2"),
    burst("（星光一闪，猫「喵嗷」一声跳开了……哈啊……又放出去了……）"),
    say(N, "（猫舔了舔嘴巴，慢悠悠地走开了。她揉着脚心，回到刚才的地方）", [tk("cat", fx="lines", n=4, iv=0.2), pose("helpless_1")], act=4),
    say(P, "……下次一定跑得掉。", emotion="angry"),
])

THEATERS = {"tunnel_thigh": THIGH, "tunnel_sole": SOLE, "tunnel_shaft": SHAFT, "tunnel_nest": NEST,
            "tunnel_cat_first": CAT_FIRST, "tunnel_cat": CAT_AGAIN}

DIALOGUES = {
    "tunnel_nest": dfile("", "老鼠窝", {
        "default": {"lines": [L("（岔路尽头有一个小窝，里面传来一大片「吱吱」声）", N)], "prompt": "进去看看？", "choices": [
            {"text": "……看一眼", "next": "go"}, {"text": "不了", "next": "no"}]},
        "go": {"lines": [L("……就看一眼。", P)], "theater": "tunnel_nest"},
        "no": {"lines": [L("……里面的声音太多了，不去。", P)]},
        "again": {"lines": [L("（小老鼠们探出头，冲她「吱吱」地打招呼。……老大好。）", N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:tunnel_nest"}, "node": "again"}, {"node": "default"}]),
    "tunnel_clue": dfile("", "刻字的死胡同", {
        "default": {"lines": [
            L("（死胡同的墙上，有人用小石头刻了几个歪歪扭扭的字，还有一幅画）", N),
            L("（画上是两个手拉手的小人。字是：「去找姐姐。」）", N),
            L("……又是这两个小人。手帕上、布偶上……还有这里。", P, "surprise"),
            L("吱。这条洞，就是很久很久以前一个小姑娘挖的。", RAT),
            L("她每天夜里偷偷挖一点，一边挖一边小声说，要出去找她的姐姐。", RAT),
            L("……后来呢？她找到了吗？", P, "sad"),
            L("吱……后来，洞挖通了。可是那天晚上，外面在打仗。……再后来，我就不知道了。", RAT),
            L("……", P, "sad"),
            L("（她用手指摸了摸那两个小人。刻痕很浅，像是很小很小的手刻出来的）", N)]},
    }),
}


def tunnel_in():
    s = [
        {"actions": [A("camera", to=[5, 3], zoom=1.0, time=0.4)], "wait": 0.4},
        line(N, "（墙缝的另一头，是一条又黑又窄的土洞。空气里有一股潮湿的泥土味）"),
        line(RAT, "（从短裤里探出头）吱吱。欢迎来到我的家。"),
        line(P, "……你的家也太窄了吧。", "sad"),
        line(RAT, "先说好三件事。第一，我住在你身上，偶尔会跑一跑。"),
        line(P, "「偶尔」……", "angry"),
        line(RAT, "第二，洞顶的水管会漏水。滴到身上，我会被吓到——被吓到就会乱窜。"),
        line(RAT, "第三……那只橘猫，它闻得到我的味道。它会追进来的。"),
        line(P, "……全是你的问题吧！？", "angry"),
        line(RAT, "吱吱。所以要快点爬呀。看见猫就冲刺，钻进小洞它就进不来了。"),
        line(P, "……走就走。", "angry"),
        {"actions": [A("camera", reset=True, time=0.4), A("notify", text="穿过鼠洞（滴水的地方看准了再走；被猫追就冲刺）")], "wait": 0.4},
    ]
    return {"name": "鼠洞", "letterbox": True, "skippable": True, "steps": s}


def tunnel_out():
    s = [
        {"actions": [A("fade_out", time=0.4)], "wait": 0.4},
        line(N, "（井口外面，是一条很宽很宽的旧水道。水声哗哗地响，远处有一点点灯光）"),
        line(P, "……出来了。", "happy"),
        line(RAT, "吱。这里就是外面了——至少，是离外面近一点的地方。"),
        line(P, "……谢谢你，挠脚鼠。虽然你挠了我一路。", "shy"),
        line(RAT, "吱吱。不客气。……不过短裤还不能还我。前面的路，我还要带你走一段。"),
        line(P, "还、还要穿着！？", "surprise"),
        line(N, "（灯光那边，水道的出口处，好像站着一个人影。那个人影手里，提着一双鞋）"),
        line(P, "……那是……", "surprise"),
        {"actions": [A("chapter_end", title="第二章　鼠洞　完", subtitle="——出口的灯光里，站着一个熟悉的身影", next="floor_06_waterway_exit")], "wait": 1.4},
    ]
    return {"name": "出口", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"tunnel_in": tunnel_in, "tunnel_out": tunnel_out}
