"""庆功宴广场（floor_06_festival）上每个人的对话：data/dialogues/floor_06/after_fest_<人>.json。身上不挂委托。
分支（entries 从上往下第一个满足的）：
  摊主（奶奶 / 商人 / 工匠 / 小汤姆 / 女仆）：摊位没通关 → 摊位入口（festival_night.inject 插在最前面）；通关了 → 摊位的纪念（stall_done）；
    领舞以后再来 → late（多聊几句）。
  其他人：领舞前 / 领舞后 / 五个摊位都通关了（all）。派对主人的领舞入口、镇长的放烟花入口也由 festival_night.inject 插在最前面。
装扮里会动的：戴彩色发绳跑来跑去的小孩（ribbon_kids）、戴铃铛的咕咕（gugu）。
蓝色公主同行时的搭话：PARTNER（插在 after_partner 最前面，庆功宴进行中才用）。
"""
from .common import BLUE, N, P, L

ON, DANCE = "after_festival_on", "festival_dance_done"
STALL_IDS = ["guess", "ring", "ice", "fish", "lick"]


def done(sid):
    return "stall_%s_done" % sid


ALL = {"flag": [ON] + [done(s) for s in STALL_IDS]}
AFTER = {"flag": [ON, DANCE]}
BEFORE = {"flag": ON, "not": DANCE}


def talk(name, npc, branches):
    """branches：[(条件, 节点名, 台词)]，按顺序；最后一条一般不带条件。"""
    entries, nodes = [], {}
    for cond, node, lines in branches:
        entries.append({"if": cond, "node": node} if cond else {"node": node})
        nodes[node] = {"lines": lines}
    return {"name": name, "npc": npc, "entries": entries, "nodes": nodes}


CAPTAIN = talk("保卫队队长", "captain", [
    (ALL, "all", [L("……五个摊子全玩遍了？"), L("……你这七天要是有这么勤快，工时早就还完了。"),
                  L("才不是！工时也是认真还的！", P, "angry"), L("……嗯。我知道。", None), L("（她别过头去，嘴角好像动了一下）", N)]),
    (AFTER, "after", [L("……跳得不错。"), L("赎罪簿我收起来了。往后你在镇上，就是客人。"),
                      L("……客人能不能不被挠脚心。", P, "sad"), L("……那要看你去不去那几个摊子。")]),
    (BEFORE, "before", [L("……领舞的人站在这里干什么。"), L("派对主人在篝火边等你。去。"),
                        L("队长不去跳吗？", P, "happy"), L("……我守夜。", None),
                        L("（她抱着手臂站在图腾柱下面，盔甲擦得锃亮，眼睛一直看着人群）", N)]),
    (None, "default", [L("……")]),
])

LILY = talk("小莉莉", "kid", [
    (ALL, "all", [L("姐姐全部都玩过啦！好厉害！"), L("莉莉也想玩脚底猜猜乐……可是奶奶说小孩子的脚太小，猜不出来。"),
                  L("……那是奶奶在保护你。", P, "sad")]),
    (AFTER, "after", [L("姐姐跳舞的时候，莉莉用狗尾巴草扫了好几下！"), L("姐姐笑得好大声～"),
                      L("莉莉……那个草，交出来。", P, "angry"), L("不要～（把草藏到了身后）", None)]),
    (BEFORE, "before", [L("姐姐要领舞了！莉莉要坐在最前面看！"), L("（她手里攥着一根狗尾巴草，眼睛亮晶晶地看着你的脚）", N),
                        L("……那根草是干什么用的。", P, "surprise"), L("帮姐姐找节奏用的！", None)]),
    (None, "default", [L("嘿嘿～")]),
])

SUPERVISOR = talk("市场监督", "supervisor", [
    (ALL, "all", [L("五个摊位全部通关……按规定，每个摊主只能给一份奖品。"), L("……算了，今晚不查账。"),
                  L("（他把记账本合上，塞进了外套口袋）", N)]),
    (AFTER, "after", [L("补罚的单子，我已经撕了。"), L("……七天里你一共被罚了多少次，我可是一笔一笔记着的。"),
                      L("那、那个本子也撕了吧！", P, "angry"), L("这个要留档。", None)]),
    (BEFORE, "before", [L("今晚不收补罚，摊位也不收钱。"), L("……我只负责看着那些摊主别玩得太过分。"),
                        L("（他看了一眼女仆那边正在给蘑菇羊抹盐的摊位，叹了口气）", N)]),
    (None, "default", [L("嗯。")]),
])

GUARD_A = talk("保卫队员", "guard", [
    (AFTER, "after", [L("队长说今晚可以喝一杯……可是她自己一口都没喝。"), L("从攻防战那天起，她夜里就没睡过一个整觉。")]),
    (None, "before", [L("站岗站了七天，今晚总算能看看篝火了。"), L("……你跳舞的时候，我能不能也去圈边上帮忙「找节奏」？"),
                      L("不能！", P, "angry")]),
])

GUARD_B = talk("保卫队员", "guard", [
    (AFTER, "after", [L("南边那段墙，明天接着补。"), L("……不过今晚，谁也别跟我提砖头。")]),
    (None, "before", [L("这面墙，是咱们七天前一块砖一块砖垒起来的。"), L("你那几天搬的砖，也在里面。"),
                      L("……嗯。", P, "shy")]),
])

HOST_LATE = talk("篝火派对的主人", "bonfire_host", [
    (None, "default", [L("今晚的篝火最旺～"), L("领舞的人，就是今晚的主角哦～")]),
])

MAYOR_LATE = talk("镇长", "mayor", [
    (None, "default", [L("……能看到大家这样笑，真好。")]),
])

# 摊主：通关以后、领舞以后再来聊（late）；没写 late 的就一直是摊位的纪念（stall_done）
STALL_LATE = {
    "after_fest_granny": ("面包店奶奶", "granny", [
        L("饼干还够吗？不够奶奶再去烤～"), L("七天前，奶奶的烤炉被攻城车撞塌了一半。"),
        L("是你和那位蓝头发的姑娘，把砖一块一块搬开的。"), L("……所以今晚的饼干，管够。")]),
    "after_fest_merchant": ("商人", "merchant", [
        L("那只木头小羊，我削了整整三个晚上。"), L("本来想挂在摊子上当招牌……送你了，送你了！"),
        L("……可是套圈的时候，你让小孩们挠我的脚。", P, "angry"), L("那叫「增加难度」，是规矩！")]),
    "after_fest_engineer": ("工匠", "miner", [
        L("冰雕摆在那边了，一晚上都化不了——蓝色的那位冻得太结实了。"), L("……对了，城门的链子转得很顺。"),
        L("不许提链子！不许提墙！", P, "angry"), L("哈哈哈！好好好，今晚不提。")]),
    "after_fest_tom": ("小汤姆", "kid", [
        L("姐姐，那条最爱啄脚心的鱼，你要好好养哦！"), L("它叫「啄啄」！我起的名字！"),
        L("……为什么要我养啊。", P, "sad"), L("因为它最喜欢姐姐的脚～", None)]),
    "after_fest_maid": ("女仆", "maid", [
        L("咕咕今晚舔了两个人的脚，已经心满意足地去散步了。"), L("……铃铛是我给它挑的。很衬它，对吧。"),
        L("（她的眼神，比平时温柔了一点点）", N)]),
}

RIBBON_KIDS = talk("小孩们", "kid", [
    (None, "default", [L("姐姐你看！商人叔叔送的发绳！"), L("红的绿的黄的，一人一根！"),
                       L("（小孩们头上扎着五颜六色的发绳，绕着篝火跑来跑去）", N)]),
])

GUGU = talk("咕咕", "goat_bell", [
    (None, "default", [L("咩～（脖子上的铃铛叮当一响）"), L("（它闻了闻你的脚，又舔了舔嘴巴）", N),
                       L("……不、不准再舔了！比赛已经结束了！", P, "angry"), L("咩～", None)]),
])

OBJECTS = {"name": "庆功宴的广场", "entries": [{"node": "wall"}], "nodes": {
    "wall": {"lines": [L("（补了一半的城墙。下半截是新砌的砖，颜色浅浅的；上半截还搭着脚手架，脚手架上挂着一盏笑声灯笼）", N)]},
    "totem": {"lines": [L("（修好的狂欢图腾柱。裂缝用木板缠了一圈又一圈，三张笑脸又端端正正地叠在一起了）", N),
                        L("（底下摆着一圈小灯笼。……柱子里面，好像有一点暖暖的光在跳）", N)]},
    "tent": {"lines": [L("（打满补丁的帐篷。攻防战那几天，这里是伤员的帐篷——现在门帘卷起来了，里面堆着庆功宴的酒桶）", N)]},
    "lumber": {"lines": [L("（明天补墙要用的木料。上面坐着两个偷懒的保卫队员，正在分一块饼干）", N)]},
    "ice_sheep": {"lines": [L("（冰雕：蘑菇羊。蘑菇伞上的白点，是蓝色公主一个一个点出来的）", N)]},
    "ice_lantern": {"lines": [L("（冰雕：一盏笑脸灯笼。篝火的光照进去，整盏灯都在发亮）", N)]},
    "ice_girls": {"lines": [L("（冰雕：手拉手的两个小女孩，一个长卷发，一个短头发）", N),
                            L("……这个，是谁刻的？", P, "surprise"), L("……", BLUE)]},
    "fish_basin": {"lines": [L("（足疗鱼的木盆，从小汤姆的摊子搬到了篝火边。好几个镇民正坐在盆边，把脚伸进去泡）", N),
                             L("（……其中一条鱼，一直游到盆边，盯着你的脚看）", N)]},
}}


def _stall_late(file, name, npc, lines):
    return file, {"name": name, "npc": npc, "entries": [{"node": "default"}], "nodes": {"late": {"lines": lines}, "default": {"lines": [L("……")]}}}


FILES = {"after_fest_captain": CAPTAIN, "after_fest_lily": LILY, "after_fest_supervisor": SUPERVISOR,
         "after_fest_guard_a": GUARD_A, "after_fest_guard_b": GUARD_B, "after_fest_host": HOST_LATE, "after_fest_mayor": MAYOR_LATE,
         "after_fest_ribbon_kids": RIBBON_KIDS, "after_fest_gugu": GUGU, "after_fest_objects": OBJECTS}
for _f, (_name, _npc, _lines) in STALL_LATE.items():
    FILES[_f] = dict(_stall_late(_f, _name, _npc, _lines)[1])
# 摊主的 late：通关了 + 领舞了（festival_night.inject 插的摊位入口在它前面，所以没通关时轮不到它）
STALL_LATE_ENTRY = {"if": AFTER, "node": "late"}

# 蓝色公主同行时的搭话（插在 after_partner 最前面）
PARTNER_NODES = {
    "fest_all": {"lines": [L("……五个，全玩了。", BLUE), L("嗯！冰雕也刻了，鱼也捞了，羊也舔了……", P, "happy"),
                           L("……被舔的是你。", BLUE), L("……", P, "shy")]},
    "fest_ice": {"lines": [L("……那两个小女孩。", BLUE), L("嗯？冰雕吗？好可爱的！是你刻的吧？", P, "happy"),
                           L("……手滑了。", BLUE), L("手滑能滑出两个手拉手的小女孩？", P, "surprise"), L("……嗯。", BLUE)]},
    "fest_after": {"lines": [L("……裤子，还在跳。", BLUE), L("（千手痒痒裤的小手们，还在跟着篝火的鼓点一下一下地晃）", N),
                             L("嘿嘿，它们比你喜欢跳舞。", P, "happy"), L("……没有。", BLUE)]},
    "fest_before": {"lines": [L("……主人在等。", BLUE), L("你会来看吗？", P, "happy"), L("……顺便。", BLUE)]},
}
PARTNER_ENTRIES = [{"if": ALL, "node": "fest_all"},
                   {"if": {"flag": [ON, DANCE, done("ice")]}, "node": "fest_ice"},
                   {"if": AFTER, "node": "fest_after"},
                   {"if": BEFORE, "node": "fest_before"}]


def inject(dialogues):
    """庆功宴的对话文件 + 摊主的 late 分支 + 蓝色公主的搭话。摊位 / 领舞 / 烟花的入口由 festival_night.inject 再插到最前面。"""
    dialogues.update({k: dict(v, entries=list(v["entries"]), nodes=dict(v["nodes"])) for k, v in FILES.items()})
    for f in STALL_LATE:
        dialogues[f]["entries"].insert(0, dict(STALL_LATE_ENTRY))
    partner = dialogues["after_partner"]
    partner["nodes"].update(PARTNER_NODES)
    partner["entries"][0:0] = [dict(e) for e in PARTNER_ENTRIES]
