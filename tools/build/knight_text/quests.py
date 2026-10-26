"""骑士篇的四个支线（KnightQuests 读 data/after/knight_quests.json）：彼此相连、和主线相连，最后在 Boss 战里汇集——
「被偷走的笑声」：诅咒手印偷的是笑声；每个支线做完，那个人会在 Boss 最后阶段来帮忙点亮一盏笑声灯笼。
  shoes   骑士救公主（小汤姆、小莉莉）：鞋被孩子们抢走，光着脚找三处 → 结尾小汤姆说地牢入口捡到「真骑士的红绳」（引向主线）
  samples 手印样本（药剂师奶奶）：收三块手印碎片 → 碎片是笑声做的，一直往盔甲那边爬；配出「安神香」，要用真心的笑声点燃（埋下灯笼）
  spear   队长的旧剑术（队长，训练室）：拿木矛练骑士那个起手式，让她当靶子 → Boss 招式的预演、完美闪避反击
  fence   夜里的栅栏（工匠，只在第一天夜里）：在营地通往小镇的路上装三道栅栏门 → 追逃里能挡盔甲
每个支线：npc 委托人（对话文件名）、opens_at / closes_at（KnightStory 步骤 id：下标 >= opens_at 且 < closes_at 时开放）、slots 能做的时段、
stages 每一段的目标（where 哪张图、cell 指哪一格、text 目标文字、unlock 这一段打开的门的标记、report 回去找委托人）、offer / accept / busy / done 台词、start_cut / done_cut 过场、reward 奖励、helper 最后一战的帮手台词。
"""
from after_text.common import A, BLUE, BLUE_NODE as B, CAP, N, P, L, line

KDAY, KNIGHT_N, DRILL, PHARMACY, CELLAR = "floor_06_knight_day", "floor_06_knight_night", "floor_06_after_drill", "floor_06_after_pharmacy", "floor_06_after_cellar"
TOM, LILY, PHARM, ENG = "小汤姆", "小莉莉", "药剂师奶奶", "工匠"
MORNING, AFTERNOON, NIGHT = 0, 1, 2

QUESTS = {
    # ---------------------------------------------------------------- ① 骑士救公主
    "shoes": {
        "name": "骑士救公主", "npc": "after_k_kids", "opens_at": "found", "closes_at": "chase", "slots": [MORNING, AFTERNOON],
        "offer": [L("姐姐姐姐！我们在玩「骑士救公主」！"), L("你来当公主好不好！公主要被恶龙关起来，然后——"),
                  L("……然后？", P, "surprise"), L("然后公主的鞋要被恶龙抢走！")],
        "prompt": "陪孩子们玩「骑士救公主」？", "yes": "好呀，公主就公主！", "no": "等一下再玩",
        "busy": [L("公主！快去找你的鞋！"), L("（纸条上的谜语还记得吗？）", N)],
        "start_cut": "kq_shoes_start", "done_cut": "kq_shoes_done", "reward": {"knight_medal": 1},
        "stages": [
            {"where": KDAY, "cell": [51, 30], "text": "【骑士救公主】「草堆里扎扎的，羊咩咩睡觉的地方」——羊圈旁边的草垛（光着脚，小心草）"},
            {"where": KDAY, "cell": [37, 22], "text": "【骑士救公主】「彩带高高挂，羽毛软软堆」——广场的彩带下面"},
            {"where": KDAY, "cell": [6, 30], "text": "【骑士救公主】「圆圆石头路，走到头有公主守着」——西边鹅卵石小路的尽头"},
        ],
        "found": ["（草垛里摸到一只鞋！……还有一大把草叶扎在脚心上）", "（够到了！第二只鞋从彩带上掉下来，正砸在她头上）"],
        "search": "翻找……", "reach": "够……",
        "straw_react": ["呜、扎扎的……！", "草、草叶钻进脚心了……哈……", "别、别扎了……噗……"],
        "feather_react": ["哈哈！羽毛……脚底全是羽毛……！", "好软……好痒……别、别往脚趾缝里钻……！", "嘻……站不稳了……"],
        "pebble_react": ["嗯……这个……有点舒服……", "哈！这块尖尖的……！", "一会儿舒服一会儿痒……这条路是谁铺的啦……！"],
        "kid_lines": ["恶龙的长矛来啦！", "公主不许跑！", "嘿嘿，抓到公主的脚了！"],
        "kid_captions": ["（小孩举着羽毛「长矛」，冲上来就往她光着的脚底扫）", "（一根狗尾巴草从背后伸过来，钻进了她的脚趾缝）"],
        # 第三处：和小莉莉比「谁先笑」（LilyDuelShow）
        "duel": {
            "name": "谁先笑", "hint": "挠她：A 脚趾 / S 脚心 / D 脚跟（听她喊哪里不行）　忍住：她挠你的时候，亮「！」时按 J 缩脚",
            "panel": "第 %d 回合 · %s\n你的闷笑 %d%%　莉莉 %d%%", "turn_attack": "该你挠她了！", "turn_defend": "莉莉挠回来了！",
            "spots": ["脚趾", "脚心", "脚跟"],
            "weak_hint": {"脚趾": ["莉莉的脚趾……不、不许碰……！", "脚趾缝最怕了……啊，说漏了！"],
                          "脚心": ["脚心！脚心不行！", "嘻嘻……脚心是秘密……"],
                          "脚跟": ["脚跟……脚跟好奇怪……嘻嘻嘻……", "不要碰脚跟——！"]},
            "hit": ["（她的手指一碰上去，小莉莉整个人蜷成一团）", "（正中！小莉莉笑得在草地上打滚）"],
            "miss": ["（小莉莉眨眨眼：「一点都不痒～」）", "（挠错地方了，小莉莉朝她吐舌头）"],
            "tickle_desc": ["（小莉莉捧起她光着的脚，小手指在脚心上画圈圈）", "（小莉莉掰开她的脚趾，往缝里吹气）", "（小手指沿着足弓一路挠到脚跟）"],
            "tuck_ok": ["（一缩脚——小莉莉扑了个空）", "（脚缩回来了！）"],
            "pink_react": [["嘻……还、还好……", "这点程度……噗……"], ["哈哈……莉莉……你的手……！", "不、不许掰脚趾……哈哈……"],
                           ["哈哈哈哈！投降、投降啦——！", "要、要输了……哈哈哈……！"]],
            "lily_react": ["嘻嘻嘻……姐姐好坏……！", "哈哈哈哈！不、不行了……！", "莉莉才没有笑……噗……"],
            "lose": ["（她先笑得瘫在地上。小莉莉叉着腰：「再来一局！」）"], "win": ["（小莉莉笑得滚成一团：「莉莉输了……鞋还给公主……」）"],
            "intro": [L("（鹅卵石小路的尽头，小莉莉坐在石头上，两只手背在身后）", N), L("公主想要最后一只鞋，就要和守卫比赛！", LILY, None, "kid"),
                      L("比赛……比什么？", P, "surprise"), L("比谁先笑！我挠你，你挠我，先笑出来的输！", LILY, None, "kid"),
                      L("……你确定？我可是很能忍的哦。", P, "happy"), L("嘻嘻，莉莉也是！", LILY, None, "kid")],
        },
        "helper": "公主姐姐！我们来啦——一起笑，哈哈哈哈！",
    },
    # ---------------------------------------------------------------- ② 手印样本
    "samples": {
        "name": "手印样本", "npc": "after_pharm", "opens_at": "afternoon", "closes_at": "chase", "slots": [MORNING, AFTERNOON],
        "offer": [L("……孩子，来得正好。"), L("那个骑士身上的手印，奶奶想配一味安神的药。"), L("可是没有样本。……你能帮奶奶去收几块吗？"),
                  L("收手印？……它们会跑吧。", P, "surprise"), L("会跑。所以要找对办法。……它们，好像喜欢笑声。")],
        "prompt": "帮奶奶收手印样本？", "yes": "交给我！", "no": "等一下",
        "busy": [L("担架走过的石板路、地牢入口的铁门……还有，奶奶的地窖里，昨晚好像也钻进去了一团。"),
                 L("（藏着手印的石头、木桶，靠近了会晃。按住 E 笑一笑，它就会爬出来）", N)],
        "done_cut": "kq_samples_done", "reward": {"calm_incense": 1},
        "stages": [
            {"where": KDAY, "cell": [40, 14], "text": "【手印样本】担架走过的石板路：哪块石头在晃？"},
            {"where": KDAY, "cell": [52, 7], "text": "【手印样本】地牢入口的铁门边"},
            {"where": CELLAR, "cell": [7, 5], "text": "【手印样本】药剂师工房的地窖（工房里的活板门）", "unlock": "kq_samples_cellar"},
            {"where": PHARMACY, "cell": [8, 5], "text": "【手印样本】把样本交给药剂师奶奶", "report": True},
        ],
        "wobble": "（石头轻轻晃了一下……底下有东西）",
        "peek": ["（一只紫色的小手印从石头缝里探出头，朝她的笑声爬了过来）", "（木桶后面，小手印犹犹豫豫地伸出一根手指）"],
        "caught": ["（小手印爬到她脚边，轻轻拍了拍她的脚背——然后乖乖钻进了瓶子）", "（它在她脚心上画了个圈，像是在打招呼，然后「咕咚」掉进瓶子里）"],
        "flee": ["（蓝色公主一靠近，小手印「嗖」地缩回了石头底下）", "（它躲开了蓝色公主，躲得远远的）"],
        "corner": ["（被逼到墙角的小手印猛地扑上来，顺着蓝色公主的大腿一路挠了上去）", "（手印钻进了蓝色公主的裙摆底下，在大腿内侧乱挠）"],
        "blue_react": ["……！……放、开……", "……唔……！……这只……凶……", "……可恶……"],
        "cluster": "（地窖深处，一大团手印挤在一起，蠕动着——冻住它，或者拍散它）",
        "split": "（手印团「啪」地裂开了，三只小手印四散逃开）",
        "report": [L("……三块。好孩子。"), L("（奶奶把瓶子凑到灯下，眯着眼看了好久）", N), L("……这东西，是笑声做的。"),
                   L("笑声？", P, "surprise"), L("被偷走的笑声。挤在一起，就变成了手。……它们一直想往一个方向爬。"),
                   L("……盔甲那边。", P, "sad")],
        "helper": "孩子——奶奶的安神香，用笑声点燃它！",
    },
    # ---------------------------------------------------------------- ③ 队长的旧剑术
    "spear": {
        "name": "队长的旧剑术", "npc": "after_k_captain", "opens_at": "afternoon", "closes_at": "chase", "slots": [MORNING, AFTERNOON],
        "offer": [L("……你。过来。"), L("那个骑士的起手式……矛尖压低，左肩在前。"), L("……我想再练一遍。缺个靶子。"),
                  L("靶、靶子？", P, "surprise"), L("木矛，包了布。打中了不疼。……只是会挨我的老办法。")],
        "prompt": "去训练室陪队长练剑？", "yes": "……好吧！", "no": "下次吧",
        "busy": [L("训练室的门开着。……进去等我。")],
        # 开场过场（训练室里的起手式）由玩法节点在第一次进训练室时演（intro_cut），不在接下的时候演
        "intro_cut": "kq_spear_start", "done_cut": "kq_spear_done", "reward": {},
        "stages": [{"where": DRILL, "cell": [10, 8], "text": "【队长的旧剑术】去西北角的训练室"}],
        # TaskSpearDrill
        "drill": {
            "rounds": ["第一轮：刺击", "第二轮：扫腿", "第三轮：实战"],
            "round_tip": ["（矛尖指向哪里，地上就亮一道线——躲开那道线）", "（脚下亮起一圈——冲刺（K）从圈里穿出去，冲刺的时候不会被打中）",
                          "（什么都会来。在快打中的一瞬间冲刺，就是「完美闪避」，能反挠他一下）"],
            "thrust": ["（他脚下一错，木矛直直刺了过来）", "（矛尖压低，左肩在前——刺！）"],
            "sweep": ["（他矮身一扫，矛杆贴着地面横扫过来）"],
            "hit": ["（被打中了！队长丢下木矛，手指钻进她的腰侧——保卫队的老办法）", "（「笨。」他一把抓住她的脚踝，挠了两下脚心）"],
            "hit_react": ["哈哈！犯规！你、你说不疼的……！", "噗哈哈！老、老办法也太狠了……！", "不、不要挠脚心……哈哈……！"],
            "perfect": ["（完美闪避！她从矛下钻过去，反手在他腰上挠了一把）", "（躲开了！趁他收矛，她的手指戳进了他的胳肢窝）"],
            "cap_react": ["……咳。", "……！……不许，再来。", "……（他的嘴角动了一下）……没笑。"],
            "fail": "（这一轮挨了太多下……队长：「重来。」）",
            "panel": "%s\n躲开 %d / %d　挨打 %d / %d%s",
            "perfect_need": "　完美闪避 %d / %d",
        },
        "helper": "……我说过，到时候我会在。",
    },
    # ---------------------------------------------------------------- ④ 夜里的栅栏
    "fence": {
        "name": "夜里的栅栏", "npc": "after_kn_engineer", "opens_at": "sneak", "closes_at": "cell", "slots": [NIGHT],
        "offer": [L("……喂，你。抓了一晚上手印的那个。"), L("瓶子里那几只，一直在哐哐地撞。……我总觉得，今晚还没完。"),
                  L("营地那边过来的三条路，我想先装上栅栏门。木板在城墙脚下。……搭把手？")],
        "prompt": "帮工匠装栅栏门？", "yes": "好！", "no": "等一下",
        "busy": [L("木板在南边城墙脚下。扛起来走，扛到路口我帮你钉。"), L("……小心房檐。今晚房檐上，有东西。")],
        "done_cut": "kq_fence_done", "reward": {},
        "stages": [
            {"where": KNIGHT_N, "cell": [53, 34], "text": "【夜里的栅栏】去城墙脚下扛木板（%d / 3）→ 营地边的路口"},
            {"where": KNIGHT_N, "cell": [45, 35], "text": "【夜里的栅栏】去城墙脚下扛木板（%d / 3）→ 南边城墙下的路口"},
            {"where": KNIGHT_N, "cell": [36, 32], "text": "【夜里的栅栏】去城墙脚下扛木板（%d / 3）→ 广场东南的路口"},
            {"where": KNIGHT_N, "cell": [48, 23], "text": "【夜里的栅栏】回去告诉工匠", "report": True},
        ],
        "lumber": [48, 39], "pick": "（扛起一捆木板。……好重。手腾不出来了）", "pick_hint": "按 E 扛起木板",
        "eave_drop": ["（头顶的房檐上，一只手印「啪嗒」掉了下来，正好抓住她的脚踝）", "（房檐的阴影里伸出一只手，一把攥住了她光着的脚）"],
        "eave_react": ["哈哈！脚、脚踝……放开……！", "噗哈哈……木板要掉了……！", "别挠脚心……我、我手上拿着东西……！"],
        "hammer": {"title": "钉栅栏门", "hint": "跟着节拍按方向键（↑↓←→）钉钉子", "ok": "（叮！钉进去了）", "miss": "（钉子歪了……）",
                   "done": "（栅栏门立起来了，「咔哒」一声扣上）"},
        # 三道门就是追逃里镇民拉上的那三道栅栏（TaskArmorChase.GATES，同一批格子）
        "report": [L("三道。……好。"), L("我再去把广场的灯笼架加固一下。……那东西要是真冲出来，至少灯笼不会倒。"),
                   L("谢谢你。……你的手怎么在抖？", P, "surprise"), L("……没什么。夜里冷。")],
        "helper": "灯笼架我加固过的——撑得住！笑吧！",
    },
}


# ---------------------------------------------------------------- 支线的过场（data/cutscenes/floor_06/kq_*.json）
def shoes_start():
    s = [
        line(TOM, "（从背后扑上来）恶龙来啦——！", None, None, "kid"),
        line(N, "（小汤姆一把抓住她的脚踝，小莉莉趁机扯下了她的鞋，两个人抱着鞋撒腿就跑）"),
        line(P, "等、等一下！我的鞋——！", "surprise"),
        line(LILY, "公主的鞋被恶龙抢走啦！想要回来，就照纸条找！", None, None, "kid"),
        line(N, "（一张皱巴巴的纸条飘到她脚边，上面用歪歪扭扭的字写着三句谜语）"),
        line(BLUE, "……光脚。……小心点。"),
        line(N, "（光着脚走路，稻草、羽毛、鹅卵石都会让脚底发痒。孩子们还会举着羽毛「长矛」偷袭）"),
    ]
    return {"name": "恶龙抢走了鞋", "letterbox": True, "skippable": True, "steps": s}


def shoes_done():
    s = [
        line(LILY, "……鞋、鞋还给公主……嘻嘻……", None, None, "kid"),
        line(TOM, "公主好厉害！这个给你——骑士勋章！我们自己做的！", None, None, "kid"),
        line(N, "（一枚用瓶盖和红布条做的「勋章」，歪歪扭扭地写着「勇者」）"),
        line(P, "……谢谢。我会好好收着的。", "happy"),
        line(TOM, "对了！我们今天早上在地牢入口那边，还捡到一根红绳子！", None, None, "kid"),
        line(TOM, "绑法好奇怪的——队长说，那是真骑士的东西！", None, None, "kid"),
        line(P, "……红绳。", "sad"),
        line(N, "（她想起了那把剑柄上缠着的红绳）"),
        line(LILY, "姐姐，以后还来玩好不好！下次莉莉当公主！", None, None, "kid"),
    ]
    return {"name": "骑士勋章", "letterbox": True, "skippable": True, "steps": s}


def samples_done():
    s = [
        line(PHARM, "……奶奶熬一锅药。你在旁边等着。", None, None, "pharmacist"),
        line(N, "（锅里的药咕嘟咕嘟地冒泡。瓶子里的三只小手印贴着玻璃，一直朝着营地的方向）"),
        line(PHARM, "……好了。安神香。", None, None, "pharmacist"),
        line(PHARM, "点上它，那些手印会安静一会儿。可是普通的火点不着它。", None, None, "pharmacist"),
        line(P, "那要用什么点？", "surprise"),
        line(PHARM, "……真心的笑声。被偷走的笑声做成的东西，只有真的笑声压得住。", None, None, "pharmacist"),
        line(BLUE, "……笑声。……像灯笼一样。"),
        line(PHARM, "对。就像镇上的笑声灯笼。……带着吧。用得上的时候，你会知道的。", None, None, "pharmacist"),
    ]
    return {"name": "安神香", "letterbox": True, "skippable": True, "steps": s}


def spear_start():
    s = [
        line(N, "（训练室里，队长拿着一根包了布的木矛。他脚下一错，矛尖压低，左肩在前——和那个骑士一模一样的起手式）"),
        line(CAP, "……这个起手式。", None, None, "captain"),
        line(CAP, "我从来没学过。……可是一拿起矛，身体就自己摆成这样。", None, None, "captain"),
        line(P, "……自己？", "surprise"),
        line(CAP, "……别问了。我也不知道。……站好。", None, None, "captain"),
    ]
    return {"name": "旧剑术", "letterbox": True, "skippable": True, "steps": s}


def spear_done():
    s = [
        line(CAP, "……够了。", None, None, "captain"),
        line(N, "（他放下木矛，从怀里摸出一根旧旧的护手绳，递给她）"),
        line(CAP, "缠在手腕上。……闪的时候，手不会抖。", None, None, "captain"),
        line(P, "……谢谢队长。", "happy"),
        line(CAP, "那个骑士……要是哪天真冲出来了。", None, None, "captain"),
        line(CAP, "……到时候，我会在。", None, None, "captain"),
        line(N, "（学会了「完美闪避」：在快被打中的一瞬间冲刺，躲开以后能反挠对方一下。和骑士打的时候，会让他露出破绽）"),
    ]
    return {"name": "到时候我会在", "letterbox": True, "skippable": True, "steps": s}


def fence_done():
    s = [
        line(N, "（三道栅栏门都立起来了。工匠拍了拍最后一道门，又抬头看了看广场上的灯笼架）"),
        line(ENG, "……行了。剩下的，我自己来。", None, None, "miner"),
        line(BLUE, "……那些手印。……房檐上，越来越多了。"),
        line(P, "……嗯。像是……在等什么。", "sad"),
    ]
    return {"name": "栅栏门", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"kq_shoes_start": shoes_start, "kq_shoes_done": shoes_done, "kq_samples_done": samples_done,
             "kq_spear_start": spear_start, "kq_spear_done": spear_done, "kq_fence_done": fence_done}


# ---------------------------------------------------------------- 委托人对话里的入口（gen 插到对话最前面）
def inject(files):
    """每个支线：开放时 offer（接下 → call: kq_start），进行中 busy（可以先放一放 → call: kq_abandon），
    最后一段要回去找委托人的（report）→ 说完 call: kq_report。"""
    for qid, q in QUESTS.items():
        d = files[q["npc"]]
        last = len(q["stages"]) - 1
        entries = []
        if q["stages"][last].get("report"):
            entries.append({"if": {"flag": "kq_%s_active" % qid, "eq": {"kq_%s_stage" % qid: last}}, "node": "kq_%s_report" % qid})
            d["nodes"]["kq_%s_report" % qid] = {"lines": q["report"], "set": {"vars": {"kq_req": qid}, "call": "kq_report"}}
        entries.append({"if": {"flag": "kq_%s_active" % qid}, "node": "kq_%s_busy" % qid})
        entries.append({"if": {"flag": "kq_%s_open" % qid}, "node": "kq_%s_offer" % qid})
        d["nodes"]["kq_%s_busy" % qid] = {"lines": q["busy"], "prompt": "（%s）" % q["name"], "choices": [
            {"text": "知道了"},
            {"text": "（先放一放）", "set": {"vars": {"kq_req": qid}, "call": "kq_abandon"}}]}
        d["nodes"]["kq_%s_offer" % qid] = {"lines": q["offer"], "prompt": q["prompt"], "choices": [
            {"text": q["yes"], "set": {"vars": {"kq_req": qid}, "call": "kq_start"}},
            {"text": q["no"]}]}
        d["entries"] = entries + d["entries"]


# 门上的提示（signs.json）：骑士篇的训练室（队长的旧剑术进行中才开）、工房的地窖（手印样本收到地窖那一段才开）
SIGNS = {
    "after_kdrill_locked": [{"speaker": N, "text": "（训练室的门关着。……队长好像有话想说，去找他聊聊？）"}],
    "after_cellar_locked": [{"speaker": N, "text": "（地板上有一块活动的木板，底下是地窖。……奶奶说过，没事别下去）"}],
}
