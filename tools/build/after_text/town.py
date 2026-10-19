"""战后小镇的人物对话（data/dialogues/floor_06/after_*.json）：每个人按第几天分支（day_is），没写到的天说 default。
第 1 天能说上话的只有宣判之后的下午（早上的开场是过场，晚上宵禁）；第 2 天起的内容之后几批补。
"""
from .common import BLUE, CAP, MAYOR, N, P, L, day_is

DONE_D1 = "after_done_d1_afternoon"


def by_day(name, npc_id, days, default, wait=None):
    """days: {天: 台词}；台词可以是 lines 列表，也可以是完整的节点 dict。
    wait：第 1 天宣判之前（下午在广场上等着）说的话。"""
    entries, nodes = [], {}
    if wait:
        entries.append({"if": dict(day_is(1), **{"not": DONE_D1}), "node": "d1_wait"})
        nodes["d1_wait"] = {"lines": wait}
    for d, body in days.items():
        nid = "d%d" % d
        entries.append({"if": day_is(d), "node": nid})
        nodes[nid] = body if isinstance(body, dict) else {"lines": body}
    entries.append({"node": "default"})
    nodes["default"] = default if isinstance(default, dict) else {"lines": default}
    d = {"name": name, "entries": entries, "nodes": nodes}
    if npc_id:
        d["npc"] = npc_id
    return d


D = {}

# —— 跟着的蓝色公主（不能换人：这一章是粉色公主在还债）
D["after_partner"] = {
    "name": BLUE, "npc": "blue_princess",
    "entries": [{"if": day_is(1), "node": "d1"}, {"node": "default"}],
    "nodes": {
        "d1": {"lines": [L("……搬砖，累吗。"), L("累死了……手臂都不是自己的了。", P, "sad"),
                         L("……明天，足枷。"), L("……我会去看。"),
                         L("不准来看！", P, "angry"), L("……嗯。……那就，最后一个去。")], "next": "menu"},
        "default": {"lines": [L("……嗯？"), L("……城墙，修得很快。")], "next": "menu"},
        "menu": {"prompt": "……还有事？", "choices": [
            {"text": "逗她笑一笑", "if": {"flag": "penance_book"}, "next": "play"},
            {"text": "没什么", "next": ""}]},
        "play": {"lines": [L("……又想干什么。")], "set": {"call": "after_play"}},
    },
}

# —— 队长：问钥匙的事，被岔开
D["after_captain"] = by_day(CAP, "captain", {
    1: {"lines": [L("工时的事，别想着讨价还价。……明天一早，广场。别迟到。")], "next": "d1_menu"},
}, [L("……有事？没事就去干活。")])
D["after_captain"]["nodes"].update({
    "d1_menu": {"prompt": "还有什么事？", "choices": [
        {"text": "她说的「钥匙」……是什么意思？", "next": "d1_key", "return": True},
        {"text": "早上那条裤子……", "next": "d1_pants", "return": True},
        {"text": "没有了", "next": ""}]},
    "d1_key": {"lines": [L("……殿下累糊涂了。打了一整晚的仗，谁都会说胡话。"),
                         L("别多想。你只要把工时还清就行。"),
                         L("（队长说完就转过身去了。……好像不太想让人看见他的脸）", N)]},
    "d1_pants": {"lines": [L("嘘——！"), L("……那件事，出了这个广场谁都不许提。你也一样。"),
                           L("……真是的。小时候是涂鸦，现在是裤子……"), L("……没什么。去干活。")]},
})

D["after_mayor"] = by_day(MAYOR, "mayor", {
    1: [L("七天，一百工时。听着多，其实镇上的大家都会帮你的……嗯，大概会吧。"),
        L("祭典的烟花我还留着呢。等到第七天晚上，一起放。")],
}, [L("哦哦，是你呀。今天的活干完了吗？")])

D["after_granny"] = by_day("面包店的奶奶", "granny", {
    1: [L("别怕，孩子。奶奶年轻的时候，也在那副足枷上坐过呢。"),
        L("最难熬的不是坐着……是那些小鬼头，专门挑脚心挠。呵呵呵。"),
        L("……奶、奶奶！这不是安慰吧？！", P, "surprise")],
}, [L("店还没盖好，饼干先欠着。")])

D["after_merchant"] = by_day("水果摊的商贩", "merchant", {
    1: [L("哼，摊子的账，我一笔一笔记着呢！"),
        L("……不过嘛，你拿锤子砸怪物的那几下，看着是挺解气的。")],
}, [L("今天的苹果……还是烂的。")])

D["after_supervisor"] = by_day("市场监督", "supervisor", {
    1: [L("赎罪簿是吧？很好，很好。账就该这样一笔一笔记清楚。"),
        L("哪天来我这里帮忙盘货，我也给你记上一笔。——前提是真的干活。")],
}, [L("账本，账本……今天也在重新抄账本。")])

D["after_bonfire_host"] = by_day("篝火派对的主人", "bonfire_host", {
    1: [L("足枷示众？那可是小镇的传统节目！明天我带热饮去给你加油！"),
        L("不、不用来！谁都不要来！", P, "angry"),
        L("哈哈哈，来的人只会更多哦～")],
}, [L("篝火还烧着。累了就过来坐坐！")])

D["after_kid_tom"] = by_day("小汤姆", "kid", {
    1: [L("姐姐明天要被锁在广场上？"), L("那、那我可以拿羽毛去吗？"),
        L("不可以！！", P, "angry"), L("嘿嘿，我去问问莉莉要不要一起～")],
}, [L("姐姐！今天陪我玩吗？")])

D["after_kid_lily"] = by_day("小莉莉", "kid", {
    1: [L("姐姐……我相信，你不是故意打开那扇门的。"), L("……汤姆说明天要拿羽毛去。我、我会拦着他的！……大概。")],
}, [L("姐姐，加油还债哦。")])

D["after_maid"] = by_day("女仆", "maid", {
    1: [L("明天要光着脚坐一上午呢……今晚好好泡个脚，把脚底泡软一点吧。"),
        L("……泡软了不是更怕痒吗？", P, "surprise"), L("啊。……说、说得也是。")],
}, [L("受伤的队员都好多了。谢谢关心。")])

D["after_engineer"] = by_day("工匠", "miner", {
    1: [L("上午的砖搬得不错嘛！虽然一半掉在了自己脚上。"),
        L("城墙还差两段。往后几天，有的是活给你干。")],
}, [L("锤子、钉子、木料……今天也是修城墙的一天。")])

GUARDS = {
    "after_guard_gate": ("守城门的队员", [L("城门今天不开。外面在清理战场，满地都是泡泡和羽毛。")]),
    "after_guard_gate2": ("守城门的队员", [L("……（瞄了一眼蓝色公主的裤子）"), L("没、没什么！我什么都没看见！")]),
    "after_guard_plaza": ("巡逻的队员", [L("队长交代了：早上那件事，谁说出去，就去刷一个月的马桶。"),
                                       L("……什么事？我什么都没看见。")]),
    "after_guard_wall": ("城墙上的队员", [L("东边的城墙塌得最厉害，明天开始重砌。"), L("你力气大，到时候多搬几块。")]),
    "after_guard_house": ("守民居的队员", [L("天黑以后就是宵禁。被我们抓到在外面晃，可是要记一笔的。")]),
}
for f, (name, d1) in GUARDS.items():
    D[f] = by_day(name, "guard", {1: d1}, [L("站岗中。")])

# —— 第 1 天下午、宣判之前（大家在广场上等着）说的话
WAITS = {
    "after_partner": [L("……广场。……要宣判了。"), L("……别怕。"), L("说得好像要被宣判的是你一样……", P, "sad"), L("……嗯。")],
    "after_captain": [L("……还没到时候。去台子前面站好，镇长马上就来。")],
    "after_mayor": [L("咳、咳……宣判词我背了一上午……"), L("你、你先去台子前面站好。")],
    "after_granny": [L("孩子，别怕。大家都看见你在城门外守了一整晚。")],
    "after_merchant": [L("哼，等着吧。我的摊子可不能白被踩烂。")],
    "after_supervisor": [L("账本带来了。……今天要记的账，可不少。")],
    "after_bonfire_host": [L("宣判完了我请你喝热汤！……要是你还喝得下的话。")],
    "after_kid_tom": [L("姐姐要被宣判了？宣判是什么？好吃吗？")],
    "after_kid_lily": [L("姐姐……会被关起来吗？")],
    "after_maid": [L("广场上人好多……您的脸色不太好，先喝口水吧。")],
    "after_engineer": [L("宣判台是我早上钉的！结实着呢，你随便站。")],
    "after_guard_gate": [L("广场那边要宣判了。快去吧。")],
    "after_guard_gate2": [L("……（瞄了一眼蓝色公主的裤子）……广、广场在那边！")],
    "after_guard_plaza": [L("宣判台前面给你留了位置。")],
    "after_guard_wall": [L("城墙的事先放一放，大家都去广场了。")],
    "after_guard_house": [L("下午广场宣判。……别想着溜回屋里。")],
}
for f, w in WAITS.items():
    D[f]["entries"].insert(0, {"if": dict(day_is(1), **{"not": DONE_D1}), "node": "d1_wait"})
    D[f]["nodes"]["d1_wait"] = {"lines": w}

# —— 第 2 天：早上示众之前（围在足枷边上等着）/ 示众之后（下午起）/ 示众时笑晕了的版本
DONE_D2 = "after_done_d2_morning"
FAINTED = "after_d2_fainted"
D2 = {
    "after_partner": (None,
        [L("……示众，还疼吗。"), L("不疼！就是……脚底到现在还麻麻的……", P, "sad"), L("……嗯。……下次，我早点来。")],
        [L("……醒了就好。"), L("你、你不准再提那件事！", P, "angry"), L("……哪件。……脚趾打招呼的那件？"), L("——！！", P, "shy")]),
    "after_captain": ([L("足枷就在广场正中间。自己过去，别让我派人押你。"), L("……按规矩来，不会太为难你。")],
        [L("……示众结束了。规矩就是规矩，你也守了。"), L("……下午的活，别耽误。")],
        [L("……晕过去的事，不会写进记录。"), L("……我也没看见。什么都没看见。")]),
    "after_mayor": ([L("咳……示众是小镇的老传统了。忍一忍，很快就过去。"), L("……大概吧。")],
        [L("辛苦啦辛苦啦！示众一结束，大家对你的气也消了一半。")],
        [L("听说你笑晕过去了？哎呀呀……是不是规矩定得太严了……")]),
    "after_granny": ([L("孩子，脚底板放松。越绷得紧，越痒。"), L("……奶奶，这个建议好像没什么用……", P, "sad")],
        [L("来，泡泡脚。奶奶熬了薄荷水，脚底就不麻了。")],
        [L("可怜的孩子，笑得都晕过去了……那几个小鬼头，奶奶替你骂过了。")]),
    "after_merchant": ([L("嘿，今天可有好戏看了！我把摊子都挪到广场边上了。")],
        [L("哈哈，那几声笑得可真响！……不过你也算是挺住了，佩服佩服。")],
        [L("笑晕过去了？……咳，那、那我摊子的账，就先少记一笔吧。")]),
    "after_supervisor": ([L("记号笔准备好了。每笑一声，我就在账本上画一道。")],
        [L("账记好了。笑出声几次，一次两工时——你自己翻赎罪簿看。")],
        [L("……晕过去以后的那些，我没记。不算你的。")]),
    "after_bonfire_host": ([L("示众要开始啦！我带了热饮来给你加油～还有派对用的小刷子～"), L("小刷子是用来干什么的？！", P, "surprise")],
        [L("刷子祝福送到啦～感觉怎么样？是不是神清气爽？"), L("一点都不！！", P, "angry")],
        [L("哎呀呀，祝福过头了……下次刷子我换软一点的！"), L("没有下次了！！", P, "angry")]),
    "after_kid_tom": ([L("姐姐！羽毛我带来啦！最长最软的那根！"), L("……收起来！", P, "angry")],
        [L("姐姐的脚好怕痒哦！比我还怕！"), L("……不准说出去。", P, "shy")],
        [L("姐姐睡着了还在笑！我们都看见了！"), L("我、我那是晕过去了！不是睡着了！", P, "angry")]),
    "after_kid_lily": ([L("姐姐……我、我是来拦着汤姆的。……真的。"), L("……那你手里的狗尾巴草是什么？", P)],
        [L("姐姐……对不起。狗尾巴草……是我忍不住……")],
        [L("姐姐晕过去的时候，我、我一直在旁边扇风！……真的！")]),
    "after_maid": ([L("鞋子先放我这里保管。……示众完了来拿。"), L("……为什么连鞋都要收走啊……", P, "sad")],
        [L("鞋子拿好。……脚底红红的，回去用凉水敷一下吧。")],
        [L("您醒了？鞋子刚才蓝色的那位来拿走了。……她好像很担心您。")]),
    "after_engineer": ([L("足枷是我昨晚连夜修的。结实着呢……啊，这么说好像不太好。")],
        [L("示众完了？那下午来帮我搬木料！城墙还差一段。")],
        [L("听说你笑晕了……木料今天就算了，明天再搬。")]),
    "after_guard_gate": ([L("今天广场上有示众。……我在城门这里，什么都看不见。……可惜。")],
        [L("示众结束了？……听说笑声传到城门这里来了。")], None),
    "after_guard_gate2": ([L("……（瞄了一眼你的光脚）……没、没什么！")], [L("……脚、脚还好吗？……我是说，执勤辛苦了！")], None),
    "after_guard_plaza": ([L("足枷前面给你留了位置。……队长交代的。")], [L("……今天的事，我也什么都没看见。")], None),
    "after_guard_wall": ([L("城墙上都听得见广场那边的动静。……加油。")], [L("你笑起来，声音挺响的。……啊，失礼了。")], None),
    "after_guard_house": ([L("蓝色的那位一大早就去训练室了。……说是不想看。")], [L("……其实她示众快结束的时候就站在广场边上了。")], None),
}
for f, (wait, after, faint) in D2.items():
    d = D[f]
    if wait:
        d["entries"].insert(0, {"if": dict(day_is(2), **{"not": DONE_D2}), "node": "d2_wait"})
        d["nodes"]["d2_wait"] = {"lines": wait}
    pos = 1 if wait else 0
    d["nodes"]["d2"] = {"lines": after}
    if faint:
        d["entries"].insert(pos, {"if": dict(day_is(2), **{"flag": [DONE_D2, FAINTED]}), "node": "d2_faint"})
        d["nodes"]["d2_faint"] = {"lines": faint}
        pos += 1
    d["entries"].insert(pos, {"if": dict(day_is(2), **{"flag": DONE_D2}), "node": "d2"})
    if f == "after_partner":
        for k in ("d2", "d2_faint"):
            if k in d["nodes"]:
                d["nodes"][k]["next"] = "menu"

# —— 药剂师奶奶 / 工房里的东西
D["after_pharm"] = by_day("药剂师奶奶", "pharmacist", {
    3: {"lines": [L("试药员来啦？药锅已经热好了。")]},
}, [L("止痒药、薄荷糖、清心花露……需要的话，奶奶这里都有。"), L("……不过，都要拿工时来换哦。呵呵。")])
D["after_pharm_objects"] = {"name": "", "entries": [{"node": "rack"}], "nodes": {
    "rack": {"lines": [L("（药草架。薄荷叶、冰晶草、薰衣草、痒痒菇粉、羽毛花、蜂蜜根、暖姜根、酸果皮……一束束挂着晾干）", N)]},
    "book": {"lines": [L("（一排旧配方本。最上面那本被水泡过，书页皱成一团）", N)]},
    "cauldron": {"lines": [L("（药锅咕嘟咕嘟地冒着泡。闻起来凉凉的，又有点甜）", N)]},
    "desk": {"lines": [L("（桌上摊着一张写满小字的纸：「试药员须知：一、配错了不许哭……」）", N), L("……第一条就不太对劲啊。", P, "sad")]},
}}

# —— 告示板 / 图腾柱 / 足枷 / 宣判台 / 城门（after_objects 一个文件，每样东西一个节点）
D["after_objects"] = {"name": "", "entries": [{"node": "notice"}], "nodes": {
    "notice": {"goto": [{"if": {"flag": "penance_book"}, "node": "notice_book"}],
               "lines": [L("（告示板。新贴的告示上写着：「下午，广场集合」）", N)]},
    "notice_book": {"lines": [L("（告示板上新贴了一张判决书：）", N),
                              L("（「……应于七日之内，以劳动偿还小镇工时一百。逾期未清，照老规矩补罚。」）", N),
                              L("（下面还有一行小字：「明早，广场足枷示众。欢迎围观」）", N),
                              L("……欢迎围观是什么意思啊！", P, "angry")]},
    "totem": {"lines": [L("（狂欢图腾柱歪在一边，裂缝里还在往外漏淡紫色的光）", N),
                        L("（旁边立着一块牌子：「危险——待修」）", N),
                        L("……靠近一点，脚底板就痒痒的。离远点吧。", P, "shy")]},
    "stocks": {"lines": [L("（广场正中间的足枷。木头被太阳晒得发白，两个脚孔磨得光溜溜的）", N),
                         L("……明天早上，就是这里了……", P, "sad")]},
    "podium": {"lines": [L("（宣判台。新木料的味道还没散）", N)]},
    "gate": {"lines": [L("（城门关着。外面传来队员们清理战场的声音）", N),
                       L("（……今天不是出去的时候）", N)]},
    "lumber": {"lines": [L("（一摞新木料。上午搬的就是这个……）", N), L("……光是看着，手臂就酸了。", P, "sad")]},
}}

SIGNS = {
    "after_curfew": [{"speaker": N, "text": "（宵禁了。……今晚就别出去了）"}],
    "after_mine_locked": [{"speaker": N, "text": "（通往矿道的门被木板钉死了。上面贴着封条）"}],
    "after_camp_blocked": [{"speaker": "告示", "text": "【整修中】营地正在清点伤员和装备，暂时不对外开放。"}],
    "after_house_up_locked": [{"speaker": N, "text": "（楼上是蓝色公主的房间。……没事别上去打扰她）"}],
    "after_task_locked": [{"speaker": N, "text": "（活还没干完……现在回屋，市场监督会追过来的）"}],
    "after_gate_closed": [{"speaker": N, "text": "（城门关着。外面在清理战场，现在不让出去）"}],
    "after_pharmacy_sign": [{"speaker": "招牌", "text": "【药剂师工房】止痒药、薄荷糖、清心花露。……试药员招募中。"}],
}
