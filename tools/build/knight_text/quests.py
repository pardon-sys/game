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
from knight_text import kq_blue, kq_fence, kq_host, kq_samples, kq_shoes, kq_spear
import quest_maps

KDAY, KNIGHT_N, DRILL, PHARMACY, CELLAR = "floor_06_knight_day", "floor_06_knight_night", "floor_06_after_drill", "floor_06_after_pharmacy", "floor_06_after_cellar"
ALLEY, HERBCAVE = "floor_06_knight_alley", "floor_06_after_herbcave"
WALL, CRACK, OLDHALL = "floor_06_knight_wall", "floor_06_after_crack", "floor_06_after_oldhall"
WAREHOUSE = "floor_06_after_warehouse"
STORAGE, BRIDGE = "floor_06_knight_storage", "floor_06_knight_bridge"
HOST = "派对主人"
RUN = "res://levels/floor_06/scripts/%s.gd"
GRANNY = "面包店奶奶"
TOM, LILY, PHARM, ENG = "小汤姆", "小莉莉", "药剂师奶奶", "工匠"
MORNING, AFTERNOON, NIGHT = 0, 1, 2
# 支线小地图的标记点（quest_maps.py）：目标指向这些点
QM = {fid: quest_maps.marks(fid) for fid in quest_maps.LAYOUTS}

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
            # 第四段：小巷里的「灯全灭了」（QuestHide，暗）；第五段：集市里追回小莉莉的宝贝盒（QuestBox，白天夜里都行）
            {"where": ALLEY, "cell": QM[ALLEY]["start"][0], "text": "【骑士救公主】小镇西边那条没有灯的小巷：玩「灯全灭了」（找出 6 个小孩）", "runner": RUN % "quest_hide"},
            {"where": "town", "cell": [10, 25], "text": "【骑士救公主】小莉莉的宝贝盒被手印搬走了——西边的集市", "runner": RUN % "quest_box"},
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
        # 第四段「那一天的躲猫猫」（QuestHide）
        "hide": {
            "intro_cut": "kq_shoes_hide_start", "end_cut": "kq_shoes_hide_end",
            "found": ["（灯光扫过木桶——后面缩着一个小孩！）", "（被照到了！小孩尖叫着扑上来）", "（箱子后面露出一双光脚丫）"],
            "pounce": ["抓到鬼的脚啦！", "嘿嘿，挠挠鬼！", "鬼不许笑！"],
            "pounce_cap": ["（小孩扑上来，抱住她的脚就挠脚心）", "（两只小手钻进她的脚趾缝里）"],
            "giggle": ["嘻……", "（黑暗里传来一声憋不住的笑）", "噗……"],
            "heard": ["（她笑出了声——黑暗里一阵窸窸窣窣，小孩们全换了地方）", "（「鬼笑啦！快跑！」小孩们四散开）"],
            "caught": "（她笑得蹲在地上——「鬼被抓走啦！」小孩们一拥而上……重新开始）",
            "dim": ["（灯芯「噗」地暗了一下）", "（灯晃了晃，差点灭掉）"],
            "shadow": ["（黑暗里伸出一只影子手，摸了摸她的脚背）", "（影子手从脚下的黑里冒出来，挠了一下）"],
            "status": "找到 %d / %d　灯光：%s",
        },
        # 第五段「小莉莉的宝贝盒」（QuestBox）
        "box": {
            "intro": [L("呜……莉莉的宝贝盒！被手印搬走啦！", LILY, None, "kid"), L("它们躲进集市的货摊里了！", TOM, None, "kid"),
                      L("（笑一笑，手印就会探出头。蓝色公主冻住它，过去按 E 拿回盒子的碎片）", N)],
            "peek": ["（货摊的布帘动了一下——一只搬着木片的手印探出头，朝她的笑声爬过来）"],
            "tickle": ["（手印扛着羽毛掸子，往她脚心上扫了一下就跑）", "（手印从摊位底下伸出来，挠了一下她的脚踝）"],
            "frozen": ["（冻住了！它怀里还抱着一块盒子的碎片）"],
            "got": ["（拿回了一块！）", "（又一块！）", "（还差一块！）", "（最后一块！）"],
            "status": "盒子的碎片 %d / %d",
            "end_cut": "kq_shoes_box_end",
        },
    },
    # ---------------------------------------------------------------- ② 手印样本
    "samples": {
        "name": "手印样本", "npc": "after_pharm", "opens_at": "afternoon", "closes_at": "chase", "slots": [MORNING, AFTERNOON],
        "offer": [L("……孩子，来得正好。"), L("那个骑士身上的手印，奶奶想配一味安神的药。"), L("可是没有样本。……你能帮奶奶去收几块吗？"),
                  L("收手印？……它们会跑吧。", P, "surprise"), L("会跑。所以要找对办法。……它们，好像喜欢笑声。")],
        "prompt": "帮奶奶收手印样本？", "yes": "交给我！", "no": "等一下",
        "busy": [L("担架走过的石板路、地牢入口的铁门……还有，奶奶的地窖里，昨晚好像也钻进去了一团。"),
                 L("（藏着手印的石头、木桶，靠近了会晃。按住 Y 笑一笑，它就会爬出来）", N)],
        "done_cut": "kq_samples_done", "reward": {"calm_incense": 1},
        "stages": [
            {"where": KDAY, "cell": [40, 14], "text": "【手印样本】担架走过的石板路：哪块石头在晃？"},
            {"where": KDAY, "cell": [52, 7], "text": "【手印样本】地牢入口的铁门边"},
            {"where": CELLAR, "cell": QM[CELLAR]["cluster"][0], "text": "【手印样本】药剂师工房的地窖（工房里的活板门）", "unlock": "kq_samples_cellar"},
            {"where": PHARMACY, "cell": [8, 5], "text": "【手印样本】把样本交给药剂师奶奶", "report": True},
            # 第五段：草药洞采三味药（QuestHerbs）；第六段：回工房熬药（QuestBrew → BrewShow）
            {"where": HERBCAVE, "cell": QM[HERBCAVE]["start"][0], "text": "【手印样本】地窖最里面的小门 → 草药洞：笑铃草、软须苔、哈欠花各 4 株", "runner": RUN % "quest_herbs", "unlock": "kq_samples_herbs"},
            {"where": PHARMACY, "cell": [8, 5], "text": "【手印样本】回工房，和奶奶一起熬药（走到药锅旁边）", "runner": RUN % "quest_brew"},
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
                   L("……盔甲那边。", P, "sad"),
                   L("要压住它们，得配安神香。……可是还缺三味药。"),
                   L("笑铃草、软须苔、哈欠花。……地窖最里面那道小门，通到矿道深处的草药洞。"),
                   L("奶奶腿脚不行了。……光着脚去，别怕痒。", None, None),
                   L("……为什么要光着脚？", P, "surprise"), L("那几味药，认人的脚。穿鞋的，它们不让摘。")],
        "helper": "孩子——奶奶的安神香，用笑声点燃它！",
        # 第五段 草药洞（QuestHerbs）
        "herbs": {
            "names": {"bell": "笑铃草", "moss": "软须苔", "yawn": "哈欠花"},
            "pick": "摘……", "status": "笑铃草 %d / 4　软须苔 %d / 4　哈欠花 %d / 4",
            "bell": ["（叮铃——笑铃草一碰就响，铃铛似的花瓣在脚心上直打转）", "（叮叮铃铃……脚底下一片铃声，痒得站不住）"],
            "moss": ["（软须苔一下子缠住了脚趾，细细的须钻进趾缝里）", "（脚陷进软绵绵的苔里，须子从脚趾缝里挠上来）"],
            "yawn": ["（哈欠花「噗」地喷出一团粉——哈……哈欠……打、打不完……）", "（花粉钻进鼻子，她张大嘴打了个哈欠——这一下，手印扑上来了）"],
            "react": ["哈哈……这、这是药草吗……！", "脚……脚趾缝不行……！", "嘻……铃、铃铛……别响了……！"],
            "spill": "（她笑得一屁股坐在地上——怀里的药草撒了一株）",
            "done": "（三味药都齐了。草药洞深处，好像有一点微弱的光在跳）",
        },
        # 第六段 熬药（BrewShow）
        "brew": {
            "name": "熬安神药", "hint": "跟着节拍按方向键搅药；冒出「阿嚏」或「好痒」的提示时，赶快按它给的方向键压住",
            "intro": [L("（药锅架在炉子上。奶奶把三味药一样一样放进去，又从药方本里翻出一页）", N),
                      L("（那本药方本里，夹着一页被撕掉的方子。残角上只剩几个字：「……退烧……殿……」）", N),
                      L("……老东西了。", PHARM, None, "pharmacist"),
                      L("搅吧。顺着拍子搅，别停。……药味冲上来的时候，憋住。", PHARM, None, "pharmacist"),
                      L("姐姐！我们来帮忙！（小汤姆和小莉莉拿着药草叶子，蹲到了她们脚边）", TOM, None, "kid")],
            "sections": ["第一锅：化开", "第二锅：熬浓", "第三锅：收汁"],
            "sneeze_pink": ["阿、阿嚏——！", "哈……哈欠……不、阿嚏！"], "sneeze_blue": ["……！……（憋）", "……阿、……嚏。"],
            "itch": ["（药草叶子扫过脚心——！）", "（小孩的叶子钻进了脚趾缝）", "（叶尖在大腿后面扫来扫去）"],
            "ok": ["（压住了！）", "（忍住了——勺子还在转）"],
            "spill": ["（一笑，手一抖——药溢出来了！）", "（锅里「咕嘟」一声，药汁漫过了锅沿）"],
            "fail": "（药溢了一地。奶奶叹了口气：「重来。」）",
            "panel": "%s\n溢锅 %d / %d　完美 %d　失误 %d",
            "lullaby": [L("……很多年前，奶奶也给一个发烧的小姑娘熬过这个。", PHARM, None, "pharmacist"),
                        L("她不肯喝，非要先听人哼那首摇篮曲。", PHARM, None, "pharmacist"),
                        L("那首歌……现在只有派对那个丫头，还会从头唱到尾了。", PHARM, None, "pharmacist"),
                        L("（粉色公主一边搅，一边随口哼了两句）", N),
                        L("（奶奶的勺子，停了一下）", N),
                        L("……搅吧。别停。", PHARM, None, "pharmacist")],
        },
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
        "stages": [{"where": DRILL, "cell": [10, 8], "text": "【队长的旧剑术】去西北角的训练室"},
                   # 第二段：城墙上守夜（QuestWatch）；第三段：二对一（QuestDuo，训练室）
                   {"where": WALL, "cell": QM[WALL]["tower"][0], "text": "【队长的旧剑术】南边城墙的梯子 → 和队长一起上城墙守夜", "runner": RUN % "quest_watch", "unlock": "kq_spear_wall"},
                   {"where": DRILL, "cell": [10, 8], "text": "【队长的旧剑术】回训练室：两个人一起，和队长练一场", "runner": RUN % "quest_duo"}],
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
        "watch_invite": [L("……还行。", CAP, None, "captain"), L("天快黑了。哨塔的灯坏了两盏。……跟我上城墙看看。", CAP, None, "captain"),
                         L("城墙？现在？", P, "surprise"), L("……南边城墙下面有梯子。我在上面等你。", CAP, None, "captain")],
        # 第二段 守夜（QuestWatch）
        "watch": {
            "intro": [L("（城墙上很黑，风从墙缝里钻过来。队长提着一盏没点的灯，站在哨塔下面）", N),
                      L("房檐上有手印。走路看脚下的影子。……到哨塔这边来。", CAP, None, "captain")],
            "blind_intro": [L("……站好。", CAP, None, "captain"), L("（队长解下护腕上的布条，蒙住了她的眼睛）", N),
                            L("骑士出招之前，矛杆会响。……听。从哪边响，就往另一边躲。", CAP, None, "captain"),
                            L("（屏幕一片黑。听声音、看边上一闪的提示——响在左边就按 →，响在右边就按 ←）", N)],
            "cue": {"left": "（左边——矛杆「嗡」地一响）", "right": "（右边——矛杆「嗡」地一响）"},
            "dodge": ["（躲开了！木矛擦着衣角过去）", "（脚下一错——躲开了）"],
            "hit": ["（没躲开！队长的手指钻进她的腰侧——保卫队的老办法）", "（「慢了。」他挠了一下她的腰）"],
            "hit_react": ["哈哈！看、看不见还挠——！", "噗……腰、腰不行……！"],
            "fail": "（挨了三下。队长把布条解开又系上：「再来。」）",
            "status": "躲开 %d / %d　挨打 %d / %d",
        },
        "watch_end": "kq_spear_watch_end",
        # 第三段 二对一（QuestDuo）
        "duo": {
            "intro": [L("（训练室里，队长把两根木矛都拿了出来）", N), L("……两个人。一起来。", CAP, None, "captain"),
                      L("躲开以后有一下空档——挠他！（攻击）蓝色公主可以冻住他的矛（J）", N),
                      L("……我不会笑的。", CAP, None, "captain"), L("嘿嘿，这可是你说的！", P, "happy")],
            "open": ["（空档！）", "（他收矛慢了半拍——现在！）"],
            "tickle": ["（她的手指钻进了队长的胳肢窝）", "（腰侧——正中！）", "（她一把抓住他的腰）"],
            "cap_react": ["……咳。", "……没、没笑。", "……！……犯规。", "……（他的嘴角抖了一下）"],
            "freeze": ["（冰顺着矛杆爬上去，木矛冻在了他手里）"],
            "status": "队长的忍笑 %d%%",
        },
        "duo_end": "kq_spear_duo_end",
    },
    # ---------------------------------------------------------------- ⑤ 没有名字的生日（派对主人）
    "host": {
        "name": "没有名字的生日", "npc": "after_k_host", "opens_at": "afternoon", "closes_at": "chase", "slots": [MORNING, AFTERNOON],
        "offer": [L("……今天，好像就是「那一天」。"), L("那一天？", P, "surprise"),
                  L("大家找到我的那一天。……我不知道自己是哪天生的，就把那一天当成生日。"),
                  L("可是每年一到这一天，大家都不说话。……我也不问。"),
                  L("今年，我想偷偷给自己办一场生日派对。……你们愿意帮我吗？")],
        "prompt": "帮派对主人准备生日？", "yes": "当然！", "no": "等一下",
        "busy": [L("彩带、点心、蜡烛……卖东西的大叔、女仆姐姐、工匠大叔那里都有。"), L("借的时候……他们大概会要你帮个忙。")],
        "done_cut": "kq_host_done", "reward": {},
        "stages": [
            {"where": "town", "cell": [8, 24], "text": "【没有名字的生日】借东西：彩带（商人）、点心（女仆）、蜡烛（工匠）——走到他们身边按 E", "runner": RUN % "quest_borrow"},
            {"where": "town", "cell": [34, 36], "text": "【没有名字的生日】派对主人的八音盒坏了——找工匠修",
             "talk": {"npc": "after_k_engineer", "lines": [L("八音盒？……我看看。"), L("（工匠转了转发条，里面「咔啦」一声）"),
                                                       L("里面掉了四个零件。……训练室后面那间旧仓库里，以前堆着好多旧玩具，拆下来就能用。"),
                                                       L("……那仓库里的东西，有点怪。音乐一停，它们就会动。小心点。")]}},
            {"where": WAREHOUSE, "cell": QM[WAREHOUSE]["start"][0], "text": "【没有名字的生日】训练室后面的旧仓库：找四个零件（音乐停的时候别乱跑）", "runner": RUN % "quest_warehouse", "unlock": "kq_host_warehouse"},
            {"where": "town", "cell": [46, 24], "text": "【没有名字的生日】把八音盒修好，还给派对主人",
             "talk": {"npc": "after_k_host", "lines": [L("……修好了？！"), L("（她小心地转了转发条）")], "cut": "kq_host_lullaby"}},
            {"where": "town", "cell": [44, 26], "text": "【没有名字的生日】篝火边：生日舞排练", "runner": RUN % "quest_party"},
            {"where": "town", "cell": [44, 26], "text": "【没有名字的生日】生日派对：吹蜡烛之前，忍笑许愿", "runner": RUN % "quest_party"},
        ],
        "borrow": {
            "spots": {"duster": "after_k_merchant", "taste": "after_k_maid", "wheel": "after_k_engineer"},
            "names": {"duster": "彩带", "taste": "点心", "wheel": "蜡烛"},
            "prompt": "按 E 借%s", "got": "（借到了%s！）", "status": "彩带 %s　点心 %s　蜡烛 %s",
            "broke_cut": "kq_host_box",
        },
        "shows": {
            "duster": {"name": "试新羽毛掸子", "hint": "冒出 A / S / D（脚趾 / 脚心 / 脚跟）时按它绷住那一处",
                       "intro": [L("彩带？可以啊。……先帮我试试这把新掸子。", "卖东西的大叔", None, "merchant"),
                                 L("站着别动。我看看它扫起来顺不顺。", "卖东西的大叔", None, "merchant"),
                                 L("扫……扫哪里？", P, "surprise"), L("……脚心。客人都是光着脚试鞋的嘛。", "卖东西的大叔", None, "merchant")],
                       "ok": ["（绷住了！）", "（脚趾一蜷，躲过了这一下）"],
                       "hit": ["（羽毛掸子从脚跟一路扫到脚趾）", "（软软的羽毛在脚心上打了个转）"],
                       "react": ["哈哈……掸子好软……！", "噗……别、别扫脚心……！", "这、这根本不是在试掸子……！"],
                       "fail": "（她笑得蹲了下去。大叔挠挠头：「……再试一次？」）",
                       "win": [L("……顺。很顺。彩带拿去吧。", "卖东西的大叔", None, "merchant")]},
            "taste": {"name": "不许笑的试吃", "hint": "按 E 吃一口；亮「！」的时候按 J 缩脚（这时候别吃，会呛笑）",
                      "intro": [L("点心？给派对主人？……那你先帮我试吃。", "女仆姐姐", None, "maid"),
                                L("规矩是——吃的时候不许笑。", "女仆姐姐", None, "maid"),
                                L("（她手里拿着一把小刷子，笑眯眯地蹲到了她脚边）", N)],
                      "tuck": ["（缩脚！小刷子扑了个空）"], "choke": "（一口点心呛在嗓子里——笑出来了！）",
                      "hit": ["（小刷子刷过脚心）", "（刷子尖在脚趾缝里转了一圈）"],
                      "react": ["噗——咳、咳……！", "嘻……点、点心要掉了……！"],
                      "fail": "（「笑了～重来～」女仆姐姐又端上一盘）",
                      "win": [L("……居然一口都没笑。点心拿去吧，派对主人最喜欢这个。", "女仆姐姐", None, "maid")]},
            "wheel": {"name": "脚底按摩器", "hint": "踩着转轮跟节拍按方向键", "intro": [
                          L("蜡烛？有。……不过我新做了个东西，你先踩踩看。", ENG, None, "miner"),
                          L("（一个带软刺的木转轮。光脚踩上去，它就跟着拍子转）", N)],
                      "hit": ["（踩空了——软刺从脚心上碾过去）"], "react": ["哈哈！刺、刺刺的……！", "这、这是按摩还是挠痒……！"],
                      "fail": "（「……再来。」工匠在小本子上记了一笔）",
                      "win": [L("……能用。蜡烛拿去。", ENG, None, "miner")]},
            "dance": {"name": "生日舞排练", "hint": "跟着节拍按方向键；三个人一起跳",
                      "intro": [L("生日舞！是我自己编的！你们跟着跳就好！", HOST, None, "bonfire_host"),
                                L("……我也要跳？", BLUE), L("当然！", HOST, None, "bonfire_host")],
                      "hit": ["（踩错一步——围观的小孩挠了一下她的脚心）"], "react": ["哈哈！别、别挠……我在跳舞……！"],
                      "fail": "（三个人笑成一团。「……再来一次！」）",
                      "win": [L("……好棒！就这样跳！", HOST, None, "bonfire_host")]},
            "wish": {"name": "忍笑许愿", "hint": "亮「！」时按 J 缩脚；撑到蓝色公主先笑出来",
                     "intro": [L("（篝火边摆好了蛋糕。镇民们围了过来——手里都拿着羽毛）", N),
                               L("派对的老规矩：吹蜡烛之前，大家挠寿星和她的朋友。最后一个笑出来的人许愿！", HOST, None, "bonfire_host"),
                               L("……那最后一个笑的，应该是寿星吧。", P),
                               L("……我明白了。先把那个冰块脸挠笑。", P, "happy"), L("……你说谁冰块脸。", BLUE)],
                     "tuck": ["（缩脚！羽毛扫了个空）"], "hit": ["（三根羽毛一起扫过她的脚心）"],
                     "react": ["哈、哈哈……我要撑住……！", "噗……蓝、蓝色的还没笑……！"],
                     "fail": "（她先笑出来了——「重来重来！」）",
                     "win": [L("（蓝色公主终于「噗」地笑出了声，捂住了嘴）", N), L("……好了。轮到寿星了！", P, "happy")]},
        },
        "helper": "八音盒——响起来吧！大家别慌！",
    },
    # ---------------------------------------------------------------- ⑥ 点灯笼的小姑娘（蓝色公主，夜里）
    "blue": {
        "name": "点灯笼的小姑娘", "npc": "after_kn_granny", "opens_at": "bait", "closes_at": "cell", "slots": [NIGHT],
        "offer": [L("……姑娘。和你一起的那孩子呢？"), L("……刚才，一个人往广场西南角那边走了。"),
                  L("那边有一盏很旧的石灯笼。……好多年没人点了。"), L("（地上，有一串淡淡的冰晶脚印）", N)],
        "prompt": "跟着冰晶脚印去找蓝色公主？", "yes": "去找她！", "no": "等一下",
        "busy": [L("……那孩子小时候，最喜欢那盏灯笼了。"), L("……我什么都没说。")],
        "done_cut": "kq_blue_done", "reward": {},
        "stages": [
            {"where": KNIGHT_N, "cell": [7, 31], "text": "【点灯笼的小姑娘】跟着地上的冰晶脚印走", "runner": RUN % "quest_footprints"},
            {"where": KNIGHT_N, "cell": [7, 31], "text": "【点灯笼的小姑娘】旧石灯笼：逗她笑", "runner": RUN % "quest_blue_lantern"},
            {"where": KNIGHT_N, "cell": [26, 14], "text": "【点灯笼的小姑娘】回忆①：井边的冰面（收 7 个笑声铃铛）", "runner": RUN % "quest_well"},
            {"where": STORAGE, "cell": QM[STORAGE]["doll"][0], "text": "【点灯笼的小姑娘】回忆②：西南角的储物间，找旧布偶", "runner": RUN % "quest_storage", "unlock": "kq_blue_storage"},
            {"where": BRIDGE, "cell": QM[BRIDGE]["end"][0], "text": "【点灯笼的小姑娘】回忆③：小桥——手拉着手走过去", "runner": RUN % "quest_bridge", "unlock": "kq_blue_bridge"},
            {"where": KNIGHT_N, "cell": [7, 31], "text": "【点灯笼的小姑娘】回到旧石灯笼：一起笑", "runner": RUN % "quest_blue_lantern"},
        ],
        "found_cut": "kq_blue_lantern",
        "tickle": {
            "name": "逗她笑", "hint": "A 大腿 / S 屁股 / D 腰（听她漏嘴的弱点）；亮「！」时按 J 把手缩回来，不然会被冻住",
            "intro": [L("……你干什么。", BLUE), L("逗你笑！灯笼要笑声才点得亮嘛！", P, "happy"), L("……我不会笑的。", BLUE)],
            "spots": ["大腿", "屁股", "腰"],
            "weak_hint": {"大腿": ["……腿……不、不要碰……", "……（她把腿并紧了）"], "屁股": ["……那里……不准……", "……！（她往后缩了缩）"],
                          "腰": ["……腰……没、没事……", "……（她的腰绷得紧紧的）"]},
            "hit": ["（正中！她「噗」地漏出一点声音，又咬住了嘴唇）", "（她整个人一缩——憋住了）"],
            "miss": ["（……她面无表情。）", "（「……不痒。」）"],
            "freeze": ["（她手一挥——冰顺着你的手指爬上来，冻住了！）"], "pull": ["（缩回来了！）"],
            "panel": "%s\n她的忍笑 %d%%",
            "short": [L("（她的嘴角动了动——灯笼亮了一下，又暗了下去）", N), L("……不够。……我笑不出来。", BLUE),
                      L("……以前，明明很会笑的。", BLUE), L("那我们去找「以前」！你小时候去过的地方！", P, "happy")],
        },
        "both": {
            "name": "一起笑", "hint": "轮到你挠：A / S / D 挠她的弱点；轮到她挠你：亮「！」时按 J 缩脚",
            "intro": [L("（回到石灯笼前。蓝色公主抱着那只旧布偶，坐在灯笼底下）", N), L("……这次，一起。", BLUE),
                      L("一起？", P, "surprise"), L("……我挠你。你挠我。……谁也不准忍。", BLUE)],
            "turn_attack": "轮到你挠她！", "turn_defend": "她挠回来了！",
            "pink_hit": ["（冰凉的手指在脚心上画圈）", "（她捏住你的脚趾，一根一根地挠）"],
            "panel": "%s\n你 %d%%　她 %d%%",
            "lit": [L("（两个人的笑声叠在一起——旧石灯笼「呼」地亮了）", N)],
        },
        "well": {
            "intro": [L("（井边的地面结了一层冰。……是她小时候练冰魔法冻的？）", N), L("……我在这里，一个人练了很多年。", BLUE),
                      L("（冰面上散着几个小铃铛。一滑过去，就会「叮铃」地笑一声）", N)],
            "bell": ["（叮铃——！）", "（铃铛笑了一声）"], "snow": ["（滑过头了——一头扎进雪堆，冰晶钻进了脚心！）"],
            "memory": [L("（铃铛的声音里，好像混着一个小女孩的笑声）", N), L("……那时候，有人在旁边看着我练。", BLUE),
                       L("每次冻歪了，她就笑。……笑得比我还大声。", BLUE), L("……她是谁？", P), L("……想不起来了。", BLUE)],
            "status": "笑声铃铛 %d / %d",
        },
        "storage": {
            "intro": [L("（一间很小的储物间，墙上挂满了旧刷子、旧扫帚）", N), L("……我小时候，躲在这里哭过。", BLUE)],
            "brush": ["（墙上的旧刷子「唰」地扫过大腿！）", "（刷子从脚心上蹭过去）"],
            "found": [L("（角落的箱子里，有一只缝补过很多次的旧布偶）", N), L("……还在。", BLUE),
                      L("哭的时候，有人塞给我这个。说——「抱着它，就不怕了」。", BLUE), L("（她把布偶抱得紧紧的）", N)],
        },
        "bridge": {
            "intro": [L("（排水渠上一座窄窄的小木桥）", N), L("……这里。我小时候，和谁手拉着手走过。", BLUE),
                      L("那就再走一次！手给我！", P, "happy"), L("（桥板缝里，有手印在动——别松手）", N)],
            "grab": ["（桥板缝里伸出一只手，挠了一下脚心！）", "（手印抓住了脚踝——！）"],
            "let_go": "（手一松——两个人都退回了桥头）",
            "done": [L("（走到了桥那头。蓝色公主低头看着两个人牵在一起的手）", N), L("……就是这样。", BLUE),
                     L("……那时候，她的手也是这么暖的。", BLUE)],
        },
        "helper": "……灯笼，我来守。",
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
            # 第四段：广场底下的裂缝（QuestCrack）；第五段：旧会堂（QuestOldHall）
            {"where": CRACK, "cell": QM[CRACK]["nails"][0], "text": "【夜里的栅栏】广场边的裂缝在漏紫光——爬进去，把封印钉敲回去", "runner": RUN % "quest_crack", "unlock": "kq_fence_crack"},
            {"where": OLDHALL, "cell": QM[OLDHALL]["cluster"][0], "text": "【夜里的栅栏】裂缝尽头：旧会堂。找到手印漏出来的地方", "runner": RUN % "quest_oldhall", "unlock": "kq_fence_hall"},
            {"where": KNIGHT_N, "cell": [48, 23], "text": "【夜里的栅栏】回去告诉工匠", "report": True},
        ],
        "lumber": [45, 40], "pick": "（扛起一捆木板。……好重。手腾不出来了）", "pick_hint": "按 E 扛起木板",
        "eave_drop": ["（头顶的房檐上，一只手印「啪嗒」掉了下来，正好抓住她的脚踝）", "（房檐的阴影里伸出一只手，一把攥住了她光着的脚）"],
        "eave_react": ["哈哈！脚、脚踝……放开……！", "噗哈哈……木板要掉了……！", "别挠脚心……我、我手上拿着东西……！"],
        "hammer": {"title": "钉栅栏门", "hint": "跟着节拍按方向键（↑↓←→）钉钉子", "ok": "（叮！钉进去了）", "miss": "（钉子歪了……）",
                   "done": "（栅栏门立起来了，「咔哒」一声扣上）"},
        # 三道门就是追逃里镇民拉上的那三道栅栏（TaskArmorChase.GATES，同一批格子）
        "report": [L("……你们，下去了？"), L("……旧会堂。我爷爷封的。「那件事」以后，就没人下去过。"), L("……算了。敲回去了就好。"),
                   L("三道门。……好。"), L("我再去把广场的灯笼架加固一下。……那东西要是真冲出来，至少灯笼不会倒。"),
                   L("谢谢你。……你的手怎么在抖？", P, "surprise"), L("……没什么。夜里冷。")],
        "helper": "灯笼架我加固过的——撑得住！笑吧！",
        "crack_cut": "kq_fence_crack",
        # 第四段 裂缝（QuestCrack）
        "crack": {
            "intro": [L("（裂缝窄得只能趴着爬。缝里很潮，墙上长着软乎乎的苔）", N), L("（前面有三根松掉的封印钉。爬过去，敲回去）", N)],
            "moss": ["（软苔小球「啪」地贴到了腿上，蹭来蹭去）", "（苔球贴在大腿后面，痒得直缩）"],
            "wipe": "擦掉……", "hand": ["（缝里伸出一只手印，挠了一下她的脚心）", "（墙缝里的手印抓住了她的脚踝）"],
            "nail_ok": "（「叮」——封印钉敲回去了）", "nail_miss": "（钉子歪了……再来）",
            "hammer": {"title": "敲封印钉", "hint": "跟着节拍按方向键（↑↓←→）"},
            "status": "封印钉 %d / 3", "done": "（三根都敲回去了。裂缝尽头，有一道门开了一条缝）",
        },
        # 第五段 旧会堂（QuestOldHall）
        "hall": {
            "intro": [L("（门后是一间塌了一半的大厅。长椅倒在地上，墙上挂着一幅很大的壁画——上面的人像全被刮花了）", N),
                      L("……旧会堂。", BLUE), L("（她手里的火把晃了晃。黑暗里，好几只手印在往这边爬）", N),
                      L("（火光照到的地方，手印会退开。火把会烧完——墙边的烛台能续上）", N)],
            "dim": ["（火把快烧完了……）"], "out": "（火灭了——黑暗里，手印一起扑了上来！）",
            "relit": "（续上了。火光一亮，手印缩回了黑暗里）",
            "cluster": "（大厅尽头的高台底下，一大团手印挤在一起——就是它们漏出来的地方）",
            "split": "（手印团裂开了，几块碎片四散逃开）",
            "status": "火把 %d%%　碎片 %d / %d",
        },
        "hall_end": "kq_fence_hall_end",
    },
}


# ---------------------------------------------------------------- 支线的过场（data/cutscenes/floor_06/kq_*.json）


def spear_start():
    s = [
        line(N, "（训练室里，队长拿着一根包了布的木矛。他脚下一错，矛尖压低，左肩在前——和那个骑士一模一样的起手式）"),
        line(CAP, "……这个起手式。", None, None, "captain"),
        line(CAP, "我从来没学过。……可是一拿起矛，身体就自己摆成这样。", None, None, "captain"),
        line(P, "……自己？", "surprise"),
        line(CAP, "……别问了。我也不知道。……站好。", None, None, "captain"),
    ]
    return {"name": "旧剑术", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"kq_spear_start": spear_start}


# ---------------------------------------------------------------- 委托人对话里的入口（gen 插到对话最前面）
def inject(files):
    """每个支线：开放时 offer（接下 → call: kq_start），进行中 busy（可以先放一放 → call: kq_abandon），
    最后一段要回去找委托人的（report）→ 说完 call: kq_report。"""
    for qid, q in QUESTS.items():
        d = files[q["npc"]]
        entries = []
        for i, st in enumerate(q["stages"]):
            cond = {"flag": "kq_%s_active" % qid, "eq": {"kq_%s_stage" % qid: i}}
            if st.get("report"):
                entries.append({"if": cond, "node": "kq_%s_report%d" % (qid, i)})
                d["nodes"]["kq_%s_report%d" % (qid, i)] = {"lines": q["report"], "set": {"vars": {"kq_req": qid}, "call": "kq_report"}}
            # 说话推进的一段：注入到那个人的对话最前面（call: kq_next）
            if st.get("talk"):
                t = st["talk"]
                td = files[t["npc"]]
                entry = {"if": cond, "node": "kq_%s_t%d" % (qid, i)}
                # 找委托人自己说话的那一段：排在「进行中」的闲话前面
                if t["npc"] == q["npc"]:
                    entries.append(entry)
                else:
                    td["entries"] = [entry] + td["entries"]
                td["nodes"]["kq_%s_t%d" % (qid, i)] = {"lines": t["lines"], "set": {"vars": {"kq_req": qid}, "call": "kq_next"}}
            # 这一段里找委托人：按段换的话（stages[].busy），没写的用通用的 busy
            if st.get("busy"):
                entries.append({"if": cond, "node": "kq_%s_busy%d" % (qid, i)})
                d["nodes"]["kq_%s_busy%d" % (qid, i)] = {"lines": st["busy"], "prompt": "（%s）" % q["name"], "choices": [
                    {"text": "知道了"},
                    {"text": "（先放一放）", "set": {"vars": {"kq_req": qid}, "call": "kq_abandon"}}]}
        entries.append({"if": {"flag": "kq_%s_active" % qid}, "node": "kq_%s_busy" % qid})
        entries.append({"if": {"flag": "kq_%s_open" % qid}, "node": "kq_%s_offer" % qid})
        d["nodes"]["kq_%s_busy" % qid] = {"lines": q["busy"], "prompt": "（%s）" % q["name"], "choices": [
            {"text": "知道了"},
            {"text": "（先放一放）", "set": {"vars": {"kq_req": qid}, "call": "kq_abandon"}}]}
        d["nodes"]["kq_%s_offer" % qid] = {"lines": q["offer"], "prompt": q["prompt"], "choices": [
            {"text": q["yes"], "set": {"vars": {"kq_req": qid}, "call": "kq_start"}},
            {"text": q["no"]}]}
        d["entries"] = entries + d["entries"]
    # 训练室里的队长（骑士篇训练室一直开着）：练剑进行中 → 准备；做完了 → 可以再练一次（不给奖励）；还没接 → 闲话
    d = files["after_drill_cap"]
    d["entries"] = [{"if": {"flag": "kq_spear_active"}, "node": "k_spear_ready"},
                    {"if": {"flag": "kq_spear_done"}, "node": "k_spear_again"},
                    {"if": {"flag": "knight_started"}, "node": "k_idle"}] + d["entries"]
    d["nodes"]["k_spear_ready"] = {"lines": [L("……站好。看矛尖。")]}
    d["nodes"]["k_spear_again"] = {"lines": [L("……又来了。"), L("那个起手式，我还没练够。")], "prompt": "再陪队长练一次？", "choices": [
        {"text": "再来一次！", "set": {"call": "kq_spear_replay"}},
        {"text": "下次吧"}]}
    d["nodes"]["k_idle"] = {"lines": [L("……门开着，是我开的。"), L("想练的时候，自己进来。")]}
    # 骑士篇的蓝色公主：平时在镇上闲逛，说话可以邀请一起走 / 先分开（不用先赢玩闹；AfterBlueRoutine.KNIGHT_FOLLOW）
    d = files["after_partner"]
    d["entries"] = [{"if": {"flag": "knight_started"}, "node": "k_talk"}] + d["entries"]
    d["nodes"]["k_talk"] = {"lines": [L("……嗯？"), L("……那个骑士。……我在想他的事。")], "prompt": "……有事？", "choices": [
        {"text": "一起走吧", "if": {"not": "after_blue_following"}, "next": "k_invite"},
        {"text": "你先去忙吧", "if": {"flag": "after_blue_following"}, "next": "k_dismiss"},
        {"text": "没什么", "next": ""}]}
    d["nodes"]["k_invite"] = {"lines": [L("……好。"), L("你一个人，会被手印抓走的。")], "set": {"call": "after_invite_blue"}}
    d["nodes"]["k_dismiss"] = {"lines": [L("……嗯。我在附近转转。……有事叫我。")], "set": {"call": "after_dismiss_blue"}}


# 门上的提示（signs.json）：骑士篇的训练室（队长的旧剑术进行中才开）、工房的地窖（手印样本收到地窖那一段才开）
SIGNS = {
    "after_kdrill_locked": [{"speaker": N, "text": "（训练室的门关着。……队长好像有话想说，去找他聊聊？）"}],
    "after_cellar_locked": [{"speaker": N, "text": "（地板上有一块活动的木板，底下是地窖。……奶奶说过，没事别下去）"}],
    "after_herb_locked": [{"speaker": N, "text": "（地窖最里面有一道小门，上了锁。门缝里飘出一股青草味）"}],
    "after_wall_locked": [{"speaker": N, "text": "（通往城墙上面的梯子。保卫队的人不让随便上去）"}],
    "after_crack_locked": [{"speaker": N, "text": "（石板缝里，偶尔漏出一点紫光。……缝太窄了，钻不进去）"}],
    "after_hall_locked": [{"speaker": N, "text": "（裂缝尽头是一道旧门，门上钉着封印钉）"}],
    "after_warehouse_locked": [{"speaker": N, "text": "（训练室后面的旧仓库，门锁着。里面好像堆满了旧玩具）"}],
    "after_storage_locked": [{"speaker": N, "text": "（一间很小的储物间，门关着）"}],
    "after_bridge_locked": [{"speaker": N, "text": "（通往排水渠的小路。黑漆漆的）"}],
}


# ---------------------------------------------------------------- 加长的剧情（每个支线一个文件 kq_<id>.py）：按段的 busy / chat / enter、替换的过场、加长的台词
def _merge_more():
    for qid, mod in (("shoes", kq_shoes), ("samples", kq_samples), ("spear", kq_spear), ("fence", kq_fence), ("host", kq_host), ("blue", kq_blue)):
        q = QUESTS[qid]
        for i, extra in mod.STAGES.items():
            q["stages"][i].update(extra)
        CUTSCENES.update(mod.CUTS)
        for key in ("OFFER", "REPORT"):
            if hasattr(mod, key):
                q[key.lower()] = getattr(mod, key)
    intro = QUESTS["samples"]["brew"]["intro"]
    QUESTS["samples"]["brew"]["intro"] = intro[:3] + kq_samples.BREW_INTRO + intro[3:]
    QUESTS["spear"]["drill"]["between"] = kq_spear.BETWEEN
    QUESTS["spear"]["watch_invite"] = kq_spear.WATCH_INVITE
    QUESTS["spear"]["watch"]["blind_intro"] = kq_spear.WATCH_BLIND
    host = QUESTS["host"]
    for k, more in kq_host.SHOWS.items():
        show = host["shows"][k]
        if k in ("dance", "wish", "taste"):
            show["intro"] = show["intro"] + more.get("intro_more", [])
        else:
            show["intro"] = more.get("intro_more", []) + show["intro"]
        if "win" in show:
            show["win"] = show["win"] + more.get("win_more", [])
    host["stages"][1]["talk"]["lines"] = kq_host.ENGINEER
    host["warehouse_intro"] = kq_host.WAREHOUSE_INTRO
    blue = QUESTS["blue"]
    blue["well"]["memory"] = kq_blue.WELL_MEMORY
    blue["storage"]["found"] = kq_blue.STORAGE_FOUND
    blue["bridge"]["done"] = kq_blue.BRIDGE_DONE


_merge_more()


# ---------------------------------------------------------------- 转阶段的过场：stages[i]["enter"]（返回过场数据的函数）→ 过场 kq_<id>_to<i>、stages[i]["enter_cut"]
def _register_enter_cuts():
    for qid, q in QUESTS.items():
        for i, st in enumerate(q["stages"]):
            fn = st.pop("enter", None)
            if fn:
                cid = "kq_%s_to%d" % (qid, i)
                st["enter_cut"] = cid
                CUTSCENES[cid] = fn


_register_enter_cuts()

