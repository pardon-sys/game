"""七日赎罪晚上的弥补任务（镇民委托；宵禁前在镇上做，做完才能回小屋睡）：data/after/night.json（TaskSweep / MouseShow / TaskTag / LanternShow 读）+ 过场 + 失败小剧场。
  第 2 天晚上 面包店奶奶「羽毛大扫除」（小镇里，烤炉后院）
  第 3 天晚上 药剂师奶奶「逃跑的痒痒鼠」（药剂师工房，舞台小游戏）
  第 4 天晚上 小孩们「挠痒捉人」（小镇广场，三轮）
  第 6 天晚上 镇长「笑声灯笼」（广场，舞台小游戏）
反应字三档 light / mid / heavy。粉色公主写脚为主，也写腋下、腰、膝盖窝等，跟着情境走。
"""
from .common import A, MAYOR, N, P, line

GRANNY = "面包店奶奶"
PHARM = "药剂师奶奶"
TOM, LILY, FAT, SPROUT = "小汤姆", "小莉莉", "小胖", "小芽"
KIDS = "小孩们"

REACT_COMMON = {
    "light": ["……唔，还、还好……", "……一、一点点而已……", "……哼，才不痒……", "……别、别闹……", "唔……", "……忍、忍得住……"],
    "mid": ["哈、哈哈……别……！", "噗……好、好痒……！", "哈哈……等、等一下……！", "哈……求、求你了……！", "噗哈……！", "哈哈……不、不行……！"],
    "heavy": ["哈哈哈哈……不、不行了……", "哈……饶、饶了我……", "哈哈哈……站、站不住了……", "呜哈……投、投降……", "哈……哈……说、说不出话……", "哈哈哈……停、停……"],
}

NIGHT = {
    # ================================================================ 第 2 天晚上：羽毛大扫除
    "sweep": {
        "intro": [
            {"speaker": GRANNY, "text": "哎呀，孩子，这么晚还在外面？……正好正好，帮奶奶一个忙。"},
            {"speaker": GRANNY, "text": "烤炉后院里，攻防战那几天飘进来好多羽毛，堆得到处都是。明天一早要烤面包，羽毛掉进面团里可不行。"},
            {"speaker": P, "text": "扫羽毛？这个简单！", "emotion": "happy"},
            {"speaker": GRANNY, "text": "简单是简单……就是今晚风大。一阵风过来，羽毛满天飞，到处钻。"},
            {"speaker": GRANNY, "text": "奶奶给你记三个工时。扫帚在墙角——鞋子嘛，脱了吧，后院的地是刚擦过的。"},
            {"speaker": P, "text": "……又、又要光脚……", "emotion": "sad"},
            {"speaker": N, "text": "（站在羽毛堆旁边按住 J 扫。起风的时候羽毛会钻进脚趾缝——按 K 抖脚、按住 E 抠出来）"},
        ],
        "gust_warn": ["（树梢「呜——」地响了起来……要起风了！）", "（远处的灯笼开始摇晃……）", "（风声越来越近——）"],
        "gust": ["（一阵大风！羽毛满天飞，好几根钻进了脚趾缝里）", "（风卷着羽毛扑过来，扫过脚背、钻进趾缝）",
                 "（呼——羽毛像雪一样落下来，落在脚心上，被风吹得来回扫）"],
        "feet": {"light": ["……趾缝里有东西……", "唔……羽毛钻进来了……", "……抖、抖一下就好……"],
                 "mid": ["哈、哈……趾缝里的羽毛在动……！", "噗……脚、脚心上也有……！", "哈哈……抠、抠不出来……！"],
                 "heavy": ["哈哈哈……全、全是羽毛……", "哈……脚、脚趾……合不上……", "哈哈……风、风停一停……"]},
        "shake": ["（使劲甩甩脚——几根羽毛飞了出去）", "（跺跺脚，羽毛抖掉了一些）"],
        "pick": ["（弯腰把趾缝里的羽毛一根根抠出来——抠的时候自己也痒得直缩）"],
        "granny": [
            [{"speaker": GRANNY, "text": "哎呀，身上沾了好多羽毛，奶奶帮你掸掸。（鸡毛掸子「啪啪」地掸了掸她的腰）", "tickle": "waist"},
             {"speaker": P, "text": "噗、哈哈……奶、奶奶，掸子也是羽毛做的啊……！", "emotion": "helpless_1"}],
            [{"speaker": GRANNY, "text": "胳膊抬起来，这里还有。（掸子在腋下来回掸）", "tickle": "armpit"},
             {"speaker": P, "text": "哈哈哈！腋、腋下没有羽毛啦——！", "emotion": "helpless_1"}],
            [{"speaker": GRANNY, "text": "脚背上也是……奶奶看看。（掸子顺着脚背扫到脚心）", "tickle": "sole"},
             {"speaker": P, "text": "呀哈！？奶奶你是故意的吧！", "emotion": "helpless_2"},
             {"speaker": GRANNY, "text": "呵呵，奶奶眼花，看不清嘛。"}],
        ],
        "pile_done": ["（这一堆扫干净了！）", "（又装满了一袋）"],
        "done": [
            {"speaker": N, "text": "（最后一堆羽毛扫进了麻袋。她靠着扫帚，长长地呼了口气）"},
            {"speaker": P, "text": "呼……扫、扫完了……", "emotion": "helpless_1"},
            {"speaker": GRANNY, "text": "辛苦啦。来，把麻袋扎起来——"},
            {"speaker": N, "text": "（——就在这时，最大的一阵风「呼」地刮了过来，麻袋口被吹开，满满一袋羽毛全扑在了她身上）"},
            {"speaker": P, "text": "哇啊啊——！？哈、哈哈哈哈！全、全身都是……！脖子里……腰里……脚趾缝……！", "emotion": "helpless_2"},
            {"speaker": GRANNY, "text": "……哎呀呀。……奶奶明天给你烤一盘羽毛形状的饼干，算赔礼。"},
            {"speaker": P, "text": "我、我才不要羽毛形状的……哈哈哈……", "emotion": "helpless_1"},
        ],
        "fail": "after_fail_sweep",
    },
    # ================================================================ 第 3 天晚上：逃跑的痒痒鼠
    "mice": {
        "intro": [
            {"speaker": PHARM, "text": "孩子！快来快来——笼子的门没关好，五只小白鼠全跑出来了！"},
            {"speaker": P, "text": "小白鼠？……那、那个不会咬人吧？", "emotion": "surprise"},
            {"speaker": PHARM, "text": "不咬人。可是它们白天偷喝了痒痒药，现在一身痒劲儿，见缝就钻……"},
            {"speaker": N, "text": "（话音刚落，一只小白鼠「嗖」地钻进了她的袖子）"},
            {"speaker": P, "text": "呀啊！？钻、钻进来了！", "emotion": "surprise"},
            {"speaker": N, "text": "（紧接着第二只、第三只……五只小白鼠一只接一只钻进了袖子、裙摆和鞋里）"},
            {"speaker": PHARM, "text": "别慌！它们在哪儿乱窜，就隔着衣服拍哪儿，一拍就抓住了！可别拍错了地方——"},
            {"speaker": N, "text": "（小鼠在身上的位置会移动：Q 袖子 / W 腋下 / E 腰 / A 大腿 / S 膝盖窝 / D 鞋里。拍对了抓住，拍错了拍到自己的痒处）"},
        ],
        "spots": [
            {"id": "sleeve", "name": "袖子", "key": "Q", "zone": "armpit", "desc": "（小鼠在袖子里来回钻，小爪子挠着手臂内侧）"},
            {"id": "armpit", "name": "腋下", "key": "W", "zone": "armpit", "desc": "（小鼠钻到了腋窝里，毛茸茸的身子蹭来蹭去）"},
            {"id": "waist", "name": "腰", "key": "E", "zone": "waist", "desc": "（小鼠顺着腰侧爬，尾巴扫过肋骨下面）"},
            {"id": "thigh", "name": "大腿", "key": "A", "zone": "thigh", "desc": "（裙摆里，小鼠沿着大腿往上爬，小爪子一步一挠）"},
            {"id": "knee", "name": "膝盖窝", "key": "S", "zone": "thigh", "desc": "（小鼠窝在膝盖窝里打转，胡子扫得痒痒的）"},
            {"id": "shoe", "name": "鞋里", "key": "D", "zone": "sole", "desc": "（鞋子里，小鼠在脚心上跑来跑去，小爪子挠着脚底）"},
        ],
        "links": {"sleeve": ["armpit"], "armpit": ["sleeve", "waist"], "waist": ["armpit", "thigh"], "thigh": ["waist", "knee"],
                  "knee": ["thigh", "shoe"], "shoe": ["knee"]},
        "caught": ["抓到了！", "逮住你了！", "进笼子去！", "呼……一只！"],
        "miss": ["（拍空了——正好拍在自己最怕痒的地方）", "（啪！拍错了，痒得自己一缩）"],
        "last": [
            {"speaker": N, "text": "（四只都抓住了。最后一只……从膝盖窝一路溜进了鞋子里，钻到了脚趾缝中间）"},
            {"speaker": P, "text": "哈、哈哈……最、最后一只在鞋里……！脚趾缝……！", "emotion": "helpless_1"},
            {"speaker": PHARM, "text": "脱鞋！快脱鞋！"},
            {"speaker": N, "text": "（连按 D 把鞋子里的小鼠抖出来）"},
        ],
        "done": [
            {"speaker": N, "text": "（「啪嗒」——最后一只小白鼠从鞋子里掉了出来，被奶奶一把捞进了笼子）"},
            {"speaker": PHARM, "text": "五只，一只不少。……辛苦你啦。"},
            {"speaker": P, "text": "呼……呼……全、全身都被爬遍了……", "emotion": "helpless_1"},
            {"speaker": PHARM, "text": "呵呵。喝了痒痒药的小鼠，比你还怕痒呢。你看——"},
            {"speaker": N, "text": "（奶奶拿羽毛碰了碰笼子里的一只小鼠，小鼠「吱吱吱」地在笼子里打滚）"},
            {"speaker": P, "text": "……噗。……原、原来痒痒药是这个效果啊……", "emotion": "happy"},
            {"speaker": PHARM, "text": "所以呀，白天那几碗药没配错，你可要谢谢奶奶。"},
            {"speaker": P, "text": "我、我才不要谢……", "emotion": "angry"},
        ],
        "fail": "after_fail_mice",
    },
    # ================================================================ 第 4 天晚上：挠痒捉人
    "tag": {
        "intro": [
            {"speaker": TOM, "text": "姐姐——！来玩捉人游戏！"},
            {"speaker": P, "text": "这么晚了……队长说宵禁……", "emotion": "surprise"},
            {"speaker": LILY, "text": "队长说，宵禁前在广场玩一会儿可以的……奶奶也同意了……"},
            {"speaker": FAT, "text": "而且我们的捉人游戏规则不一样哦！被抓到的人要被挠！"},
            {"speaker": SPROUT, "text": "……抓、抓到就挠。"},
            {"speaker": P, "text": "……总觉得这个游戏对我很不利……", "emotion": "sad"},
            {"speaker": TOM, "text": "姐姐帮我们修了好多东西，我们给姐姐记工时！三个工时！"},
            {"speaker": P, "text": "……工时是你们记的吗。……算了，玩就玩！", "emotion": "happy"},
        ],
        "rounds": [
            {"id": "seek", "name": "第一轮：姐姐当鬼", "time": 45.0,
             "start": [{"speaker": TOM, "text": "第一轮姐姐当鬼！追上我们，挠一下就算抓到！"},
                       {"speaker": N, "text": "（追上孩子按 J 挠他——笑倒了就算抓到。四个都抓到就过关）"}],
             "end": [{"speaker": KIDS, "text": "哈哈哈……被、被抓到了……姐姐好会挠……"},
                     {"speaker": P, "text": "嘿嘿，现在知道被挠是什么感觉了吧！", "emotion": "happy"}]},
            {"id": "run", "name": "第二轮：孩子们当鬼", "time": 35.0,
             "start": [{"speaker": TOM, "text": "第二轮！我和小胖当鬼！姐姐快跑！"},
                       {"speaker": N, "text": "（被摸到就会被按倒挠一阵。撑到时间结束，被抓不超过三次）"}],
             "end": [{"speaker": FAT, "text": "姐、姐姐跑得好快……"}, {"speaker": P, "text": "呼……呼……那、那是当然……", "emotion": "helpless_1"}]},
            {"id": "all", "name": "第三轮：大家一起当鬼", "time": 35.0,
             "start": [{"speaker": KIDS, "text": "最后一轮——所有人都是鬼！"},
                       {"speaker": P, "text": "等、等一下，这不就是大家一起抓我吗！", "emotion": "surprise"},
                       {"speaker": KIDS, "text": "对呀～"}],
             "end": [{"speaker": N, "text": "（最后一声「时间到」。四个孩子扑在她身上，笑成一团）"}]},
        ],
        "tickle_kid": ["（姐姐的手指钻进他的胳肢窝——「哈哈哈哈投降投降！」）", "（被姐姐抓住了腰，咯吱咯吱——笑得在地上打滚）"],
        "kid_laugh": ["哈哈哈哈！投降！", "姐姐好坏——哈哈！", "不、不要挠肚子！", "被抓到了啦——！"],
        "caught": {
            TOM: {"desc": "（小汤姆扑上来抱住她的腿，十根手指在脚心上咯吱咯吱地挠）", "zone": "sole"},
            LILY: {"desc": "（小莉莉蹲下来，狗尾巴草在脚趾缝里一道一道地扫）", "zone": "sole"},
            FAT: {"desc": "（小胖掏出小刷子，从脚跟刷到脚尖，刷了一遍又一遍）", "zone": "sole"},
            SPROUT: {"desc": "（小芽不好意思地戳了戳她的腰，戳一下，跑开，又回来戳一下）", "zone": "waist"},
        },
        "done": [
            {"speaker": N, "text": "（游戏结束了。五个人躺在广场的石板地上，看着地下小镇的「天空」——岩顶上的萤光石一闪一闪）"},
            {"speaker": TOM, "text": "……姐姐。"},
            {"speaker": P, "text": "嗯？", "emotion": "happy"},
            {"speaker": TOM, "text": "姐姐走了以后，还会回来玩吗？"},
            {"speaker": P, "text": "……", "emotion": "sad"},
            {"speaker": P, "text": "……会的。……大概。", "emotion": "shy"},
            {"speaker": LILY, "text": "那我们留着狗尾巴草等你。"},
            {"speaker": P, "text": "……那个就不用留了。", "emotion": "sad"},
        ],
        "fail": "after_fail_tag",
    },
    # ================================================================ 第 6 天晚上：笑声灯笼
    "lantern": {
        "intro": [
            {"speaker": MAYOR, "text": "来了，孩子。……明天就是庆功宴了。广场上要挂满灯笼。"},
            {"speaker": MAYOR, "text": "我们小镇的灯笼，点的不是火，是笑声。狂欢图腾的老规矩——笑声越真，灯越亮。"},
            {"speaker": P, "text": "笑、笑声点灯？", "emotion": "surprise"},
            {"speaker": MAYOR, "text": "以前每年都是镇民们围着篝火笑出来的。今年……大家都累了。所以要请一个「最会笑的人」帮忙。"},
            {"speaker": P, "text": "……为什么又是我。", "emotion": "sad"},
            {"speaker": MAYOR, "text": "（拍拍旁边一台木头机器——两个脚洞，里面一圈圈软毛刷）这是祖传的「欢笑踏板」。脚放进去，刷子一转……"},
            {"speaker": MAYOR, "text": "强弱你自己调。每盏灯要的笑声不一样——笑太小点不亮，笑太大灯泡会炸。"},
            {"speaker": N, "text": "（↑↓ 调刷子的强度，让闷笑停在灯笼要的范围里几秒就点亮。笑过头灯泡会炸；魔力疲倦满了释放，会吹灭一半的灯）"},
        ],
        "lanterns": [
            {"name": "第一盏：轻轻的笑", "lo": 0.15, "hi": 0.40},
            {"name": "第二盏：咯咯笑", "lo": 0.35, "hi": 0.60},
            {"name": "第三盏：哈哈大笑", "lo": 0.55, "hi": 0.80},
            {"name": "第四盏：忍住的笑", "lo": 0.25, "hi": 0.40},
            {"name": "第五盏：笑到停不下来", "lo": 0.72, "hi": 0.90},
        ],
        "levels": ["停", "轻轻地刷", "慢慢地转", "快快地刷", "全速！"],
        "brush": {1: ["（软毛刷轻轻地扫过脚心）"], 2: ["（刷子一圈圈地转，从脚跟刷到脚趾）"],
                  3: ["（刷子越转越快，刷毛钻进每一道趾缝）"], 4: ["（全速！刷子呼呼地转，两只脚心同时被刷得发烫）"]},
        "lit": ["（灯笼「噗」地亮了起来，暖黄色的光）", "（又一盏！围观的孩子们欢呼起来）"],
        "burst": ["（笑得太厉害——「啪」！灯泡炸了，碎成一团星光）", "（灯泡受不住，「嘭」地炸开了）"],
        "blown": ["（魔力「呼」地冒了出来——亮着的灯笼被吹灭了一半！）"],
        "crowd": ["再笑一点！", "太大声了太大声了！", "姐姐加油～", "这盏要轻轻笑哦！", "哇，亮了！"],
        "done": [
            {"speaker": N, "text": "（五盏灯笼全都亮了。广场上暖黄色的光一圈圈晕开，照在每个人的脸上）"},
            {"speaker": MAYOR, "text": "……好。好啊。这样明天的庆功宴，就有灯了。"},
            {"speaker": P, "text": "呼……呼……笑、笑得肚子都疼了……", "emotion": "helpless_1"},
            {"speaker": MAYOR, "text": "孩子，你知道吗？以前每年点灯笼的，都是一位很会笑的小姑娘。"},
            {"speaker": P, "text": "……很会笑的小姑娘？", "emotion": "surprise"},
            {"speaker": MAYOR, "text": "……很多年以前的事了。……回去睡吧，明天还要修图腾柱呢。"},
            {"speaker": N, "text": "（镇长转过身去，背影在灯笼的光里显得有点模糊）"},
        ],
        "fail": "",
    },
}


def _say(sp, text, actions=None, portrait=None, emotion=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if portrait:
        s["portrait"] = portrait
    if emotion:
        s["emotion"] = emotion
    return s


def _tk(by, zone="sole", fx="feather", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


def _cast(extra):
    c = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    c.update(extra)
    return c


FAIL_SWEEP = {"name": "扫除失败：掉进羽毛堆", "cast": _cast({"g": {"kind": "npc:granny", "at": [-26, 6], "dir": "right"},
                                                         "f": {"kind": "trap:feather", "at": [0, 14]}}), "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（笑得腿一软，她一屁股坐进了最大的那堆羽毛里——羽毛「哗」地淹到了腰）"),
    _say(P, "哇啊——！？", emotion="surprise"),
    _say(N, "（又一阵风。羽毛堆整个转了起来，像一个羽毛旋涡，把她裹在中间）", [_tk("f", zone="sole", n=10), _tk("f", zone="waist", n=10)]),
    _say(P, "哈哈哈哈！脚、脚底下的羽毛在转——！腰、腰上也……！", portrait="defeat_1"),
    _say(GRANNY, "哎呀呀，孩子掉进去了！奶奶来拉你——（伸出鸡毛掸子）"),
    _say(P, "不、不要掸子——哈哈哈！那、那也是羽毛啊！", [_tk("g", zone="armpit", n=10, iv=0.16)], portrait="defeat_2"),
    _say(N, "（羽毛钻进领口、钻进袖子、钻进每一道脚趾缝。她在羽毛堆里笑得直打滚）", [A("pose", who="princess", visual="helpless_2")]),
    _say(GRANNY, "……好啦好啦，风停了。出来吧，歇一会儿再扫。"),
    _say(P, "哈……哈……羽、羽毛……全在衣服里……", emotion="helpless_1"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

FAIL_MICE = {"name": "抓鼠失败：五只一起", "cast": _cast({"ph": {"kind": "npc:pharmacist", "at": [-26, 6], "dir": "right"},
                                                       "r": {"kind": "monster:rat", "at": [14, 12]}}), "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（笑得手软，一只也拍不中了。五只小白鼠像是开起了派对，在她身上来回乱窜）"),
    _say(N, "（袖子里一只、腋下一只、腰上一只、膝盖窝一只，还有一只在鞋子里打转）", [_tk("r", zone="armpit", fx="hand", n=10), _tk("r", zone="sole", fx="hand", n=10)]),
    _say(P, "哈哈哈哈哈！五、五只一起——！全、全身都……！", portrait="defeat_1"),
    _say(PHARM, "哎呀呀，它们把你当成游乐场了。"),
    _say(P, "奶、奶奶快帮忙——哈哈哈！", portrait="defeat_2"),
    _say(PHARM, "好好好……（拿出一块奶酪，在地上一放）"),
    _say(N, "（五只小鼠「吱」地一声，一齐从衣服里钻了出来，扑向了奶酪）", [A("pose", who="princess", visual="helpless_2")]),
    _say(P, "……早、早有奶酪的话……为什么不早拿出来……", emotion="helpless_1"),
    _say(PHARM, "呵呵，奶奶刚刚才想起来嘛。……歇一会儿，再来一次。"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

FAIL_TAG = {"name": "捉人失败：被大家压在下面", "cast": _cast({"k1": {"kind": "npc:kid", "at": [-20, 20], "dir": "right"},
                                                           "k2": {"kind": "npc:kid", "at": [20, 20], "dir": "left"},
                                                           "k3": {"kind": "npc:kid", "at": [0, 26], "dir": "up"}}), "steps": [
    {"actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5},
    _say(N, "（被抓了太多次，她笑得爬不起来。四个孩子一拥而上，把她压在了广场的石板上）"),
    _say(KIDS, "抓到啦——！大家一起挠！"),
    _say(N, "（汤姆挠脚心、莉莉扫趾缝、小胖刷脚弓、小芽戳腰——四个人分工明确）", [_tk("k1", fx="hand", n=10), _tk("k2", n=10), _tk("k3", zone="waist", fx="hand", n=10)]),
    _say(P, "哈哈哈哈哈！犯、犯规！四、四个人一起犯规——！", portrait="defeat_1"),
    _say(TOM, "游戏规则就是被抓到就要挠嘛！"),
    _say(P, "规、规则是谁定的啊——哈哈哈哈！", portrait="defeat_2"),
    _say(LILY, "……是汤姆定的。"),
    _say(N, "（直到巡夜的保卫队员路过，才把四个小鬼一个个拎走）", [A("pose", who="princess", visual="helpless_2")]),
    _say(P, "哈……哈……再、再来一局……这次我一定……", emotion="helpless_1"),
    {"actions": [A("fade_out", time=0.6), A("voice", state="")], "wait": 0.7},
]}

THEATERS = {"after_fail_sweep": FAIL_SWEEP, "after_fail_mice": FAIL_MICE, "after_fail_tag": FAIL_TAG}
