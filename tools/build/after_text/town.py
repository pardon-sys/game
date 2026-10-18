"""战后小镇的人物对话（data/dialogues/floor_06/after_*.json）：每个人按第几天分支（day_is），没写到的天说 default。
第 1 天能说上话的只有宣判之后的下午（早上的开场是过场，晚上宵禁）；第 2 天起的内容之后几批补。
"""
from .common import BLUE, CAP, MAYOR, N, P, L, day_is

DONE_D1 = "after_done_d1_afternoon"


def by_day(name, npc_id, days, default):
    """days: {天: 台词}；台词可以是 lines 列表，也可以是完整的节点 dict。"""
    entries, nodes = [], {}
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
                         L("不准来看！", P, "angry"), L("……嗯。……那就，最后一个去。")]},
        "default": {"lines": [L("……嗯？"), L("……城墙，修得很快。")]},
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
}
