"""第 1 天：战后开场（早）→ 广场宣判（午）→ 千手痒痒裤半夜梦游（夜）。
开场里队长的两句、蓝色公主拦住队长的那句、宣判时「……那扇门，钥匙是我的」是用户给定的台词，不要改。
过场里的镇民用导演改过的节点名（对话文件名：after_captain……），蓝色公主是 AfterBlue。
"""
from .common import A, BLUE, BLUE_NODE as B, CAP, MAYOR, N, P, line

GUARD = "保卫队员"
EXTRA = ["s1", "s2", "s3"]


# ---------------------------------------------------------------- 早：战后开场（城门里面，守城的队员们围过来）
def d1_open():
    steps = [
        {"actions": [A("fade_out", time=0.0), A("move", who="princess", to=[31, 37]), A("move", who=B, to=[33, 37]),
                     A("face", who="princess", dir="up"), A("face", who=B, dir="up"),
                     A("spawn", id="s1", kind="npc:guard", at=[27, 35], dir="right"),
                     A("spawn", id="s2", kind="npc:guard", at=[37, 35], dir="left"),
                     A("spawn", id="s3", kind="npc:guard", at=[26, 37], dir="right"),
                     A("camera", to=[32, 36.5], zoom=0.9, time=0.1)], "wait": 0.2},
        {"actions": [A("fade_in", time=1.0), A("sfx", sound="gate", volume=-6.0)], "wait": 1.0},
        line(N, "（城门在身后合上了。镇民们还在城外收拾战场，守城的队员们却一个接一个围了过来）"),
        line(GUARD, "回来了！两位都回来了！", None, [A("hop", who="s1")]),
        {"actions": [A("move", who="after_captain", to=[32, 35], speed=80)], "wait": 0.6},
        line(CAP, "让开让开——！", None, None, "captain"),
        line(CAP, "殿下！有没有受伤？刚才城墙塌下来那一下，我在下面看得清清楚楚——", None, [A("face", who="after_captain", dir="right")], "captain"),
        line(BLUE, "……没事。……一点擦伤。"),
        line(CAP, "擦伤也是伤！转过来，我看看——", None, None, "captain"),
        line(N, "（队长刚伸出手，蓝色公主的裤子忽然「沙沙」地动了一下）", None,
             [A("bubble", who=B, kind="surprise"), A("shake", time=0.2, strength=1.5)]),
        line(BLUE, "……？"),
        line(N, "（裤腿上的蓝白条纹一圈一圈亮了起来。也许是打了一整晚仗太兴奋，也许是图腾的余波还没散——"
                "一只只半透明的小手，从她的衣摆底下钻了出来）", None,
             [A("cover", who=B, zone="waist", add=2), A("sfx", sound="hand_grab", volume=-4.0)]),
        line(BLUE, "……等、等一下……现在不行……！", "shy", [A("cover", who=B, zone="thigh", add=2), A("pose", who=B, laugh=40)]),
        line(N, "（小手沿着她的腰侧一路往上爬，又顺着大腿根挠了回去）", None,
             [A("crack", long=False), A("shake", time=0.3, strength=2.0)]),
        line(BLUE, "噗……哈、哈哈……！不……不准……在这里……！", "shy",
             [A("cover", who=B, zone="butt", add=1), A("pose", who=B, laugh=75), A("crack", long=True)]),
        line(GUARD, "（小声）……队、队长……蓝色的那位……在笑？", None, [A("bubble", who="after_guard_plaza", kind="surprise")]),
        line(GUARD, "我在保卫队待了五年……第一次听见她笑出声……", None, [A("bubble", who="s2", kind="question")]),
        line(N, "（蓝色公主膝盖一软，当着全体队员的面，捂着腰笑得蹲了下去）", None,
             [A("move", who=B, to=[33, 37.4], time=0.3), A("bubble", who=B, kind="laugh")]),
        line(P, "你、你没事吧？！这些手……是那条裤子！", "surprise", [A("face", who="princess", dir="right")]),
        line(CAP, "……裤子？", None, [A("bubble", who="after_captain", kind="question")], "captain"),
        line(CAP, "……退后，殿下。我这就把这个邪物砍下来。", None, [A("sfx", sound="swish", volume=-2.0), A("shake", time=0.15)], "captain"),
        line(BLUE, "不、不准砍！哈哈……这是我输给它的……赌注！我答应过要陪它玩的！", "angry", [A("crack", long=False)]),
        line(N, "（全场一片安静。只有那些小手，还在她腰上挠个不停）"),
        line(CAP, "………………", None, None, "captain"),
        line(CAP, "殿下，您从小就是这样，每次从下面回来都要带点让人头疼的东西……上一次是满身的涂鸦，这一次干脆把惩罚道具穿在身上了！",
             None, None, "captain"),
        line(BLUE, "……哈、哈……不、不是惩罚道具……是……赌注……", "shy"),
        line(P, "（……上一次？满身的涂鸦？）", None, [A("bubble", who="princess", kind="question")]),
        line(CAP, "（长长地叹了一口气）……都听好了。今天看到的，一个字都不许往外说。", None, None, "captain"),
        line(GUARD, "是、是！", None, [A("hop", who="s1"), A("hop", who="s2"), A("hop", who="s3")]),
        line(CAP, "殿下，从明天起，每天到我的训练室报到。忍耐力——还有这条裤子，都得好好驯服。", None, None, "captain"),
        line(BLUE, "……特、特训……？哈……我不需要……"),
        line(CAP, "您需要。……全镇都需要。", None, None, "captain"),
        line(N, "（小手像是玩够了，一只接一只缩回了裤腿里。蓝色公主撑着膝盖喘气，耳朵红透了）", None,
             [A("uncover", who=B), A("pose", who=B, laugh=10), A("move", who=B, to=[33, 37], time=0.3)]),
        line(CAP, "然后——你。", None, [A("face", who="after_captain", dir="left")], "captain"),
        line(P, "诶？我？", "surprise"),
        line(CAP, "你的事，下午在广场上说清楚。镇长会来。", None, None, "captain"),
        line(P, "广场……？我、我做什么了吗……？", "sad"),
        line(CAP, "在那之前，跟着工匠去搬砖。城墙塌了三段，正缺人手。", None, None, "captain"),
        line(P, "欸——？才刚打完仗诶！", "angry"),
        line(CAP, "那就更不能闲着。", None, None, "captain"),
        line(BLUE, "……", None, [A("face", who=B, dir="left"), A("bubble", who=B, kind="dots")]),
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("despawn", who=s) for s in EXTRA] + [A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "战后的小镇", "letterbox": True, "skippable": True, "end_dark": True, "steps": steps}


# ---------------------------------------------------------------- 午：广场宣判
CROWD_REACT = [A("bubble", who="after_merchant", kind="angry"), A("bubble", who="after_supervisor", kind="dots"),
               A("bubble", who="after_kid_tom", kind="surprise"), A("bubble", who="after_maid", kind="surprise")]


def d1_verdict():
    steps = [
        {"actions": [A("fade_out", time=0.0), A("move", who="princess", to=[30, 27]), A("move", who=B, to=[35, 27.5]),
                     A("face", who="princess", dir="up"), A("face", who=B, dir="up"),
                     A("camera", to=[31, 28], zoom=0.8, time=0.1)], "wait": 0.2},
        {"actions": [A("fade_in", time=1.0), A("sfx", sound="bell_jingle", volume=-8.0)], "wait": 1.0},
        line(N, "（下午。广场上围满了人。宣判台是早上刚用新木料搭起来的，钉子还亮闪闪的）"),
        line(P, "（……搬了一上午的砖，手都抬不起来了……为什么还要站在台子底下……）", "shy"),
        line(MAYOR, "安静，安静——咳咳。", None, [A("hop", who="after_mayor")], "mayor"),
        line(MAYOR, "首先，谢谢大家。小镇守住了，一个人都没少。祭典……本来今晚就该开的。", None, None, "mayor"),
        line(MAYOR, "可是有件事，得先弄清楚。——队长。", None, None, "mayor"),
        line(CAP, "是。", None, [A("move", who="after_captain", to=[32, 25.5], speed=50), A("face", who="after_captain", dir="down")], "captain"),
        line(CAP, "昨天夜里，怪物最先涌上来的地方，是矿道最深处那扇封了很多年的旧门。", None, None, "captain"),
        line(CAP, "门被打开了。门口的泥地上，留着一串小小的鞋印。", None, None, "captain"),
        line(CAP, "……和你脚上的鞋子，一模一样。", None, None, "captain"),
        line(N, "（人群「哗」地一下骚动起来）", None, CROWD_REACT + [A("sfx", sound="rumble", volume=-14.0)]),
        line("水果摊的商贩", "是她？！我的摊子就是那天晚上被踩烂的！", None, [A("hop", who="after_merchant")]),
        line("市场监督", "账本烧了一半……这笔账，该记在谁头上？"),
        line(P, "我……我只是想回家！那扇门后面……我以为是往上走的路……！", "sad"),
        line("面包店的奶奶", "大家别这么凶嘛。昨天夜里，她也在城门外面守了一整晚呀。"),
        line("篝火派对的主人", "就是就是！冲在最前面的可是她！"),
        line("小莉莉", "姐姐……真的打开了那扇门吗？"),
        line(P, "……", "sad"),
        line(N, "（蓝色公主一直站在人群边上，一句话也没说。她攥着衣角，攥得指节发白）", None, [A("camera", to=[33, 28], time=0.6)]),
        line(BLUE, "……那扇门，钥匙是我的——", None, [A("move", who=B, to=[34, 27], time=0.4)]),
        line(CAP, "——殿下累了。请先回去休息。", None, [A("face", who="after_captain", dir="right"), A("shake", time=0.12)], "captain"),
        line(BLUE, "……可是——"),
        line(CAP, "门是谁推开的，大家都看见了。", None, None, "captain"),
        line(N, "（队长没有再看她，只是握着剑柄的那只手，紧了一紧）", None, [A("face", who="after_captain", dir="down")]),
        line(P, "（……钥匙？她刚才说……钥匙？）", None, [A("bubble", who="princess", kind="question"), A("camera", to=[31, 28], time=0.6)]),
        line(MAYOR, "……咳。那么，判决。", None, None, "mayor"),
        line(MAYOR, "我们小镇，不讲关牢房那一套。讲的是——欠了多少，一笔一笔还回来。", None, None, "mayor"),
        line(MAYOR, "修城墙、收装备、帮大家干活……一件一件做，七天之内，把欠小镇的「工时」还清。", None, None, "mayor"),
        line(CAP, "一共一百工时。做完一件事，减；犯了错——偷懒、宵禁以后还在外面晃——加。", None, None, "captain"),
        line(P, "一、一百……？！", "surprise"),
        line(MAYOR, "当然，小镇的老规矩，也少不了。", None, None, "mayor"),
        line("镇民们", "——挠痒惩罚！", None, [A("hop", who="after_kid_tom"), A("hop", who="after_bonfire_host"), A("hop", who="after_granny")]),
        line(P, "果、果然有这个……！", "shy"),
        line(MAYOR, "明天一早，在广场的足枷上示众半天。往后哪件事办砸了，也照老规矩来。", None, None, "mayor"),
        line(N, "（镇长把一本皮面的小册子递给队长，队长走下台，把它塞进粉色公主手里）",
             None, [A("move", who="after_captain", to=[30, 26], speed=50)]),
        line(CAP, "赎罪簿。还剩多少工时、每天要做的事、受过的罚，都记在上面。自己每天看。", None, [A("sfx", sound="book")], "captain"),
        line(P, "……知道了。", "sad"),
        line(MAYOR, "祭典嘛——等城墙修好、债也还清的那天晚上，全镇再一起开！散会！", None, [A("hop", who="after_mayor")], "mayor"),
        line(N, "（人群慢慢散开了。有人冲她叹了口气，也有人走过来，拍了拍她的肩膀）", None,
             [A("move", who="after_captain", to=[33, 25.5], speed=50)]),
        line(BLUE, "……", None, [A("move", who=B, to=[31.5, 27], time=0.8), A("face", who=B, dir="left")]),
        line(BLUE, "……对不起。"),
        line(P, "诶？你道什么歉呀？", "surprise", [A("face", who="princess", dir="right")]),
        line(BLUE, "……没什么。……天快黑了，回家吧。"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        {"actions": [A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "广场宣判", "letterbox": True, "skippable": True, "end_dark": True, "steps": steps}


# ---------------------------------------------------------------- 夜：千手痒痒裤半夜梦游（楼下 → 楼上）
BED = [4, 4.25]
HANDS = ["h1", "h2", "h3"]
TRAIL = [[15, 4], [13, 6], [10, 8], [7, 7], [5, 6]]


def d1_night():
    steps = [
        {"actions": [A("fade_out", time=0.0), A("lie", who="princess", at=BED, sleep=False),
                     A("camera", to=[8, 6], zoom=1.0, time=0.1)], "wait": 0.3},
        {"actions": [A("fade_in", time=1.2)], "wait": 1.2},
        line(N, "（夜里。蓝色公主早早上了楼，一句话都没说）"),
        line(P, "（一百工时……七天……明天一早，还要被锁在广场上……）", "sad"),
        line(P, "（……她说的钥匙，到底是什么意思……）", "sad"),
        {"actions": [A("lie", who="princess", sleep=True)], "wait": 1.0},
        line(N, "（夜深了。楼梯上传来「沙……沙……」的声音）", None, [A("sfx", sound="cloth", volume=-8.0)]),
        {"actions": [A("spawn", id=h, kind="prop:pants_hand", at=[16, 3], z=2) for h in HANDS]
         + [A("move", who="h1", to=[5, 5], time=2.4), A("move", who="h2", to=[4, 5.4], time=2.8),
            A("move", who="h3", to=[6, 5.2], time=3.2)], "wait": 3.2},
        line(N, "（几只半透明的小手，顺着楼梯一节一节爬下来，钻进了被子的另一头）"),
        line(P, "唔……嗯……", "shy", [A("tickle", who="princess", by="h1", zone="sole", repeat=5, interval=0.35, add=8),
                                    A("cover", who="princess", zone="sole", add=2)]),
        line(P, "哈……别……那里……嘻……（梦话）", "shy", [A("tickle", who="princess", by="h2", zone="sole", repeat=6, interval=0.3, add=10),
                                                  A("lie", who="princess", laugh="helpless_2")]),
        line(N, "（小手们一左一右扳住她的脚趾，另一只顺着脚心慢慢地画圈）", None,
             [A("tickle", who="princess", by="h3", zone="sole", repeat=8, interval=0.25, add=12), A("shake", time=0.3)]),
        line(P, "哈、哈哈哈……！谁、谁在挠我的脚心——！", "surprise", [A("lie", who="princess", sleep=False, laugh="surprise"),
                                                         A("pose", laugh=55)]),
        {"actions": [A("lie", who="princess", on=False), A("move", who="princess", to=[5, 6], time=0.2),
                     A("bubble", who="princess", kind="surprise"), A("uncover", who="princess")]
         + [A("move", who=h, to=[16, 3], time=1.0 + 0.2 * i) for i, h in enumerate(HANDS)], "wait": 1.4},
        {"actions": [A("despawn", who=h) for h in HANDS]
         + [A("spawn", id="tr%d" % i, kind="prop:handprint", at=c) for i, c in enumerate(TRAIL)], "wait": 0.4},
        line(P, "刚才那是……手？", "surprise"),
        line(P, "……蓝白条纹的袖口……是那条裤子的手！", "angry"),
        line(N, "（地板上留下了一串湿漉漉的、发着淡蓝光的小手印）"),
        line(P, "……它跑到哪里去了？……跟过去看看。", None, [A("pose", laugh=0)]),
        {"actions": [A("camera", reset=True, time=0.6)], "wait": 0.6},
    ]
    return {"name": "半夜的手印", "letterbox": True, "skippable": True, "steps": steps}


UP_BED = [4, 4.25]


def d1_night_end():
    steps = [
        {"actions": [A("fade_out", time=0.0), A("lie", who=B, at=UP_BED, sleep=True), A("move", who="princess", to=[12, 4]),
                     A("face", who="princess", dir="left"),
                     A("spawn", id="u1", kind="prop:pants_hand", at=[5, 5], z=2), A("spawn", id="u2", kind="prop:pants_hand", at=[3, 5.2], z=2),
                     A("cover", who=B, zone="thigh", add=1), A("camera", to=[7, 5], zoom=1.0, time=0.1)], "wait": 0.3},
        {"actions": [A("fade_in", time=1.0)], "wait": 1.0},
        line(N, "（蓝色公主睡得很沉。被子底下，那些小手正懒洋洋地晃来晃去，像在等谁陪它们玩）", None,
             [A("move", who="u1", to=[5.6, 5.4], time=0.8), A("move", who="u2", to=[2.6, 5.5], time=0.8)]),
        line(P, "……原来你在这里。", None, [A("move", who="princess", to=[6.5, 5], time=1.2)]),
        line(BLUE, "……唔……不准……砍……（梦话）"),
        line(P, "……噗。梦里还在护着你呢。", "happy"),
        {"actions": [A("move", who="u1", to=[6.3, 5], time=0.5)], "wait": 0.5},
        line(P, "哇、等等……！别、别挠我啊……！她会被吵醒的……！", "shy",
             [A("tickle", who="princess", by="u1", zone="waist", repeat=4, interval=0.3, add=6), A("cover", who="princess", zone="waist", add=1)]),
        line(N, "（小手挠了两下，见她不躲，反而乖乖地停了下来，绕着她的手腕转了一圈——像一只撒娇的猫）", None,
             [A("uncover", who="princess"), A("move", who="u1", to=[6.8, 5.2], time=0.6)]),
        line(P, "……你是不是……只是想找人玩？"),
        line(N, "（小手轻轻点了点——如果手也会点头的话）", None, [A("hop", who="u1")]),
        line(P, "好啦……明天。明天陪你玩。……今晚先让她好好睡，好不好？", "happy"),
        {"actions": [A("move", who="u1", to=[4, 4.4], time=1.0), A("move", who="u2", to=[4, 4.4], time=1.2)], "wait": 1.2},
        {"actions": [A("despawn", who="u1"), A("despawn", who="u2"), A("uncover", who=B)], "wait": 0.4},
        line(N, "（小手一只接一只缩回了被子里。裤脚最后晃了一下，安静了）"),
        line(BLUE, "……小时候……也是……这样……（梦话）"),
        line(P, "……小时候？", None, [A("bubble", who="princess", kind="question")]),
        line(N, "（蓝色公主翻了个身，没有再说话）"),
        line(P, "…………晚安。", "happy"),
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("camera", reset=True, time=0.0)], "wait": 0.1},
    ]
    return {"name": "裤子的梦游", "letterbox": True, "skippable": True, "end_dark": True, "steps": steps}


CUTSCENES = {"after_d1_open": d1_open, "after_d1_verdict": d1_verdict, "after_d1_night": d1_night, "after_d1_night_end": d1_night_end}
