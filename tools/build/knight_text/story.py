"""骑士篇的过场（data/cutscenes/floor_06/knight_*.json）和地牢里骑士的对话（after_knight）。
这一章是序章：只埋线索，不揭开。玩家能看到的「答案」都是误导——「那天晚上有两个殿下，其中一个是冒牌货」。
真线索（埋得很轻）：
  骑士 = 队长：骑士怀里的褪色手帕（两个手拉手的小女孩，和队长那块一样）、他骂她「又是这副花猫样」、他的剑术起手式让队长沉默。
  手印认得她：诅咒手印碰到粉色公主就变温和。
骑士对粉色公主：面对灭国凶手的态度——冷嘲、戒备、不配合，有问也只给带指控的半句。
蓝色公主走进牢房时，他是懵的：不知道为什么会有两个一样的公主，以为是幻术（误导：「那天晚上也是两个」），不下跪、不叫她殿下。
"""
from after_text.common import A, BLUE, BLUE_NODE as B, CAP, MAYOR, N, P, L, line

KNIGHT = "骑士"
GUARD = "保卫队员"
PHARM = "药剂师奶奶"
K = "knight"    # 过场里生成的骑士演员 id


# ---------------------------------------------------------------- 庆功宴的第二天早上：醒来（不再有人敲门，自由活动）
def morning():
    s = [
        {"actions": [A("fade_in", time=0.8)], "wait": 0.8},
        line(N, "（庆功宴的第二天早上。窗外还飘着烟花留下的一点火药味）"),
        line(P, "唔……脚底……还有沙子……", "sad"),
        line(BLUE, "……醒了。"),
        line(P, "早……昨晚跳得腿都软了……", "helpless_1"),
        line(BLUE, "……外面，吵吵嚷嚷的。"),
        line(P, "庆功宴的东西还没收完吧？出去走走！", "happy"),
        line(N, "（可以在镇上自由走走。东北角那边好像有人在喊）"),
    ]
    return {"name": "庆功宴的第二天", "letterbox": True, "skippable": True, "steps": s}


def found():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight", at=[54, 6], dir="down"),
                     A("spawn", id="g1", kind="npc:guard", at=[52, 6], dir="right"),
                     A("spawn", id="g2", kind="npc:guard", at=[56, 6], dir="left"),
                     A("camera", to=[54, 6], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（地牢入口的铁门前，围着一圈保卫队员。地上躺着一个人——银灰色的盔甲，面罩拉下来遮住了脸，身上披着一件破破烂烂的披风）"),
        line(CAP, "……来了。", None, None, "captain"),
        line(CAP, "巡逻的队员天亮时发现的。人就倒在门口。……可是封条，一条都没破。", None, None, "captain"),
        line(P, "没破？那他是从哪里——", "surprise"),
        line(CAP, "不知道。门是从里面封的，钥匙在我身上。……他不可能从这扇门进来。", None, None, "captain"),
        line(N, "（盔甲的缝隙里，透出一点淡淡的紫光。仔细看，那是一个个小小的手印，印在胸甲和护腿上，像是被谁一把一把抓过）"),
        line(GUARD, "队长……这些手印，在动。"),
        line(N, "（她走近了一步，目光落在那件破披风上——磨损的布料上，绣着半个褪了色的纹章）"),
        line(P, "……这个纹章……", "surprise"),
        line(N, "（她蹲下来，看向他腰间的佩剑。剑柄上缠着的红绳，绑法很特别）"),
        line(P, "……这把剑……我、我认得……", "surprise"),
        line(P, "……是我的骑士。", "sad"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="surprise")]),
        line(CAP, "……你的骑士？", None, [A("bubble", who="after_k_captain", kind="question")], "captain"),
        line(P, "王国里的……从小就跟在我身边的骑士。我在地牢第一层，还看到过他留下的信……", "sad"),
        line(P, "他说，不管多深的地牢，都会来找我……", "sad"),
        line(CAP, "……先抬去药剂师那里。这些手印不对劲。", None, None, "captain"),
        line(CAP, "你，抬后面。担架前面让队员抬。……别让那些手印碰到别人。", None, None, "captain"),
        line(N, "（抬着担架，走得慢，不能攻击、冲刺。手印会时不时从盔甲上爬出来，往前面抬担架的队员身上扑——挡在队员和手印之间，别让它碰到队员）"),
        {"actions": [A("despawn", who=K), A("despawn", who="g1"), A("despawn", who="g2"), A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "地牢入口的骑士", "letterbox": True, "skippable": True, "steps": s}


def carry_done():
    s = [
        line(N, "（担架终于抬进了药剂师工房的门。药剂师奶奶已经在里面等着了）"),
        line(GUARD, "呼……到了……刚才那些手……", None),
        line(P, "……刚才那些手印碰到我的时候，一点都不痒。", "surprise"),
        line(GUARD, "啊？我被碰到的时候差点笑得把担架扔了！"),
        line(P, "……就像，在摸摸我的脚背。", "sad"),
    ]
    return {"name": "抬到工房", "letterbox": True, "skippable": True, "steps": s, "end_dark": False}


# ---------------------------------------------------------------- 醒来：「你这个害王国破灭的凶手！」
def wake():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight", at=[11, 6], dir="down"),
                     A("camera", to=[9, 6], zoom=1.0, time=0.5)], "wait": 0.5},
        line(PHARM, "……身上没伤。累坏了，又被这些手印折腾了不知道多久。", None),
        line(PHARM, "这种手印……奶奶活了这么久，只见过一次。……印在那条裤子上。", None),
        line(N, "（药剂师奶奶看了一眼蓝色公主的腿。千手痒痒裤上的小手，忽然全都缩了起来，一动不动）"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="surprise")]),
        line(P, "……一样的手？", "surprise"),
        line(BLUE, "……形状。……一样。"),
        line(N, "（话还没说完，担架上的人动了一下）", None, [A("hop", who=K)]),
        line(KNIGHT, "……唔……"),
        line(P, "……醒了！你醒了！", "happy", [A("move", who="princess", to=[10, 6], time=0.3)]),
        line(N, "（面罩后面，那双眼睛慢慢睁开，对上了她的脸）"),
        line(KNIGHT, "……殿……下……？"),
        line(P, "是我！是我啊！你还记得我对不对！我在第一层看到你的信了，你说——", "happy"),
        line(N, "（下一秒，他的眼神变了）", None, [A("shake", time=0.3, strength=2.0)]),
        line(KNIGHT, "……是你。"),
        line(KNIGHT, "你这个害王国破灭的凶手！", None, [A("move", who=K, to=[10.4, 6], time=0.15), A("shake", time=0.4, strength=3.0)]),
        line(P, "——！？", "surprise", [A("move", who="princess", to=[8.5, 6.5], time=0.2)]),
        line(N, "（他一把抓起靠在墙边的长矛，脚下一错，摆出了一个起手式——矛尖压低，左肩在前）"),
        line(CAP, "……", None, [A("bubble", who="after_captain", kind="surprise")], "captain"),
        line(N, "（队长的手停在了剑柄上。他盯着那个起手式，好一会儿没有动）"),
        line(GUARD, "队长！？"),
        line(CAP, "……按住他。老办法。", None, None, "captain"),
        line(N, "（三个队员一拥而上，一个夺下长矛，两个按住他的胳膊——保卫队的「老办法」：手指钻进盔甲的缝隙，在腰侧和腋下飞快地挠）"),
        line(KNIGHT, "放、放开……！唔……！你们……卑鄙……！"),
        line(N, "（他咬着牙憋了好几秒，终于从面罩后面漏出一声闷笑，手脚一软，被按倒在担架上）"),
        line(N, "（挣扎中，一块旧手帕从他的胸甲里掉了出来，落在她的脚边。帕角上绣着两个手拉手的小人，已经褪成了灰色）"),
        line(P, "……", "sad"),
        line(N, "（她捡起手帕，下意识地攥在了手里）"),
        line(KNIGHT, "……那天晚上……我都看见了……你还要装作什么都不记得……"),
        line(CAP, "带去营地的地牢。看好他，面罩不用摘。……他不让摘，就别摘。", None, None, "captain"),
        line(GUARD, "是！"),
        {"actions": [A("despawn", who=K)], "wait": 0.3},
        line(P, "……王国……破灭了？", "sad"),
        line(P, "……我是……凶手……？", "sad"),
        line(BLUE, "……", None, [A("face", who=B, dir="left")]),
        line(N, "（蓝色公主看着她，什么都没说。只是伸手，轻轻碰了碰她攥着手帕的手）"),
        line(CAP, "……这几天，你不准靠近地牢。", None, None, "captain"),
        line(P, "可是——！", "angry"),
        line(CAP, "这是命令。", None, None, "captain"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
        line(N, "（队长走了。窗外，太阳已经偏西——不知不觉，已经下午了）"),
        line(BLUE, "……先回去。……天黑了，再说。"),
        line(N, "（下午可以在镇上走走；回小屋的床上，能休息到晚上）"),
    ]
    return {"name": "醒来", "letterbox": True, "skippable": True, "steps": s}


# ---------------------------------------------------------------- 夜里：诅咒漏出来了（以笑为饵）
def bait_open():
    s = [
        {"actions": [A("camera", to=[33, 26], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（夜里，广场上的笑声灯笼，一盏接一盏地暗了下去）"),
        line(MAYOR, "……怎么回事？灯笼里的笑声……被什么东西吸走了。"),
        line(N, "（地上，一个个紫黑色的小手印，正贴着石板飞快地爬。它们从营地的方向来，钻进墙角，爬上镇民的脚背）"),
        line("面包店奶奶", "哎呀，有什么东西……嗯？……奇怪……想笑，却笑不出来……"),
        line("小汤姆", "奶奶的脸好奇怪！明明在笑，却没有声音！"),
        line(MAYOR, "……是地牢那边漏出来的。那个人身上的东西。"),
        line(P, "那些手印……在偷大家的笑声？", "surprise"),
        line(BLUE, "……它们，怕人。……一靠近，就跑。"),
        line(N, "（她试着走过去。手印「嗖」地一下全散开了，躲进了阴影里）"),
        line(P, "……可是早上抬担架的时候，它们一直往人身上扑。", "sad"),
        line(BLUE, "……扑的是，在笑的人。"),
        line(P, "……在笑的人。", "surprise"),
        line(P, "……那就让它们来找我。我来笑——你来抓！", "angry"),
        line(BLUE, "……你，是饵。"),
        line(P, "饵就饵！早上它们碰我的时候，又不痒！", "angry"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="question")]),
        line(N, "（让自己笑起来，手印就会被笑声引过来：按住 E 捂着嘴偷偷笑（按得越久笑得越响，松开慢慢停下）；也可以踩进痒痒草、站到诅咒的地纹上）"),
        line(N, "（按 C 换成蓝色公主：手印贴上来以后按 J 冻住，身边没有手印时在粉色公主身边按 J 挠她一下帮她笑；U 千手解放能一下子扒下一圈手印。冻住的手印走过去按 E 收进瓶子，两个人都能收。抓够六只）"),
        line(N, "（别笑过头——太响的话，全广场的手印会一下子扑过来）"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "被偷走的笑声", "letterbox": True, "skippable": True, "steps": s}


def bait_done():
    s = [
        line(N, "（最后一只手印被冻成一块紫色的冰，「咕咚」一声掉进了瓶子里。广场上的灯笼，一盏一盏重新亮了起来）"),
        line("面包店奶奶", "……哈、哈哈……能笑了！奶奶能笑出声了！"),
        line(P, "呼……呼……六只……", "helpless_1"),
        line(BLUE, "……你的脸。"),
        line(P, "嗯？", "surprise"),
        line(BLUE, "……被手印碰的时候。……很舒服的样子。"),
        line(P, "……嗯。就是……好奇怪。它们碰别人的时候那么凶，碰我的时候……", "sad"),
        line(P, "……像是认得我一样。", "sad"),
        line(BLUE, "……", None, [A("face", who=B, dir="down")]),
        line(CAP, "（举着火把走过来）……你们抓了一晚上？", None, None, "captain"),
        line(P, "队长！让我去见他！手印是从他身上漏出来的，只要问清楚——", "angry"),
        line(CAP, "不行。", None, None, "captain"),
        line(P, "为什么！", "angry"),
        line(CAP, "……他今天看你的眼神。你自己也看见了。", None, None, "captain"),
        line(N, "（队长转身走了。火把的光越来越远）"),
        line(P, "……", "sad"),
        line(BLUE, "……地牢。……我知道一条路。"),
        line(P, "……诶？", "surprise"),
        line(BLUE, "……小时候。钻过。"),
        line(BLUE, "……营地楼梯，路障后面。"),
    ]
    return {"name": "灯笼重新亮了", "letterbox": True, "skippable": True, "steps": s}


# ---------------------------------------------------------------- 夜探地牢
def sneak_open():
    s = [
        line(N, "（营地楼梯的路障后面，有一道窄窄的通风口。蓝色公主拨开了挡在前面的木板）"),
        line(BLUE, "……从这里下去。走廊里有巡逻的。……别被看见。"),
        line(P, "被看见了会怎么样？", "surprise"),
        line(BLUE, "……审问椅。"),
        line(P, "……审问椅？", "helpless_1"),
        line(BLUE, "……你第一天，坐过的那种。"),
        line(P, "……我不要再坐了！！", "angry"),
        line(N, "（躲开巡逻队员的视线，躲进木箱，丢石子引开他们，一直走到最里面那间牢房。被抓到会被按上审问椅挠一阵，再从入口重新来）"),
    ]
    return {"name": "夜探地牢", "letterbox": True, "skippable": True, "steps": s}


def cell_end():
    shown = {"flag": "knight_asked_hanky"}
    hidden = {"not": "knight_asked_hanky"}
    s = [
        line(N, "（走廊尽头亮起了火把的光，脚步声越来越近——守卫被他喊过来了）"),
        line(BLUE, "……走！"),
        line(N, "（她转身要跑，又停下来，回头看了他一眼。通风管里的灰，在她鼻尖上蹭了一道黑）"),
        line(KNIGHT, "……又是这副花猫样。"),
        line(N, "（话一出口，他自己先愣住了）"),
        line(P, "……诶？", "surprise"),
        line(KNIGHT, "……滚。别让我再看见你。"),
        dict(line(N, "（她把那块旧手帕从栏杆缝里塞了进去。他一把夺了过去）"), **{"if": hidden}),
        dict(line(KNIGHT, "……别用你的手碰它。"), **{"if": hidden}),
        line(N, "（他攥着那块手帕，背过身去，再也没有看她）"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="surprise")]),
        line(N, "（蓝色公主盯着他手里那块手帕看了一眼——帕角上两个手拉手的小人，和队长那天递过来的那块，一模一样）"),
        line(N, "（她什么都没说，拉着粉色公主钻回了通风口）"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        line(N, "（两个人沿着通风管爬出营地，摸黑溜回了蓝色小屋门口。……已经很晚了，回床上睡吧）"),
    ]
    return {"name": "花猫样", "letterbox": True, "skippable": True, "steps": s, "end_dark": True}


CUTSCENES = {"knight_morning": morning, "knight_found": found, "knight_carry_done": carry_done, "knight_wake": wake,
             "knight_bait_open": bait_open, "knight_bait_done": bait_done, "knight_sneak_open": sneak_open, "knight_cell_end": cell_end}


# ---------------------------------------------------------------- 地牢里隔着栏杆和骑士说话（夜探地牢的终点，TaskSneak 走到牢房门口触发）
# 他把她当灭国的凶手：三个问题最多回答一个（knight_answered），而且只给带指控的半句；之后再问一律拒绝。
# 拿出手帕（醒来时她捡到的）他会失态、一把抢回去，说漏一句。拿出过手帕或者回答过一个问题以后，身后才有脚步声：
# 蓝色公主走出来 → 他懵了（两个一样的脸），以为是幻术，喊守卫 → 过场 knight_cell_end。
def _question(key, lines):
    """一个问题：已经回答过一个了 → 拒绝；不然回答（记 knight_answered）。问过的都记 knight_asked_<key>。"""
    return {
        key: {"goto": [{"if": {"flag": "knight_answered"}, "node": key + "_no"}], "lines": lines,
              "set": {"flags": ["knight_asked_" + key, "knight_answered"]}},
        key + "_no": {"lines": [L("（他转过身去，背对着她）", N), L("……凶手，没资格再问。")],
                      "set": {"flags": ["knight_asked_" + key, "knight_refused"]}},
    }


CELL = {
    "name": KNIGHT, "npc": "knight", "entries": [{"node": "cell"}],
    "nodes": dict({
        "cell": {"lines": [L("（最里面那间牢房。他背对着栏杆坐在地上，盔甲上的手印已经不动了。听见脚步声，他没有回头）", N),
                           L("……来灭口吗，凶手。"),
                           L("不是！我……我只是想知道，那天晚上到底发生了什么。", P, "sad"),
                           L("……装得真像。")],
                 "next": "ask"},
        "ask": {"prompt": "……（他不会回答很多问题）", "choices": [
            {"text": "那天晚上，你看见了什么？", "next": "night", "return": True, "if": {"not": "knight_asked_night"}},
            {"text": "王国……是怎么没的？", "next": "fall", "return": True, "if": {"not": "knight_asked_fall"}},
            {"text": "你为什么说是我？", "next": "why", "return": True, "if": {"not": "knight_asked_why"}},
            {"text": "（拿出那块旧手帕）", "next": "hanky", "return": True, "if": {"not": "knight_asked_hanky"}},
            {"text": "（身后传来了脚步声）", "next": "blue", "if": {"any": [{"flag": "knight_asked_hanky"}, {"flag": "knight_answered"}]}},
        ]},
        "hanky": {"lines": [
            L("（她把那块旧手帕从怀里掏出来，隔着栏杆递了过去）", N),
            L("……这个。你昏倒的时候掉的。", P, "sad"),
            L("（他猛地转过身，铁链「哗啦」一响，一把从她手里把手帕夺了过去）", N),
            L("……别用你的手碰它！"),
            L("（他攥着手帕，指节都发白了。面罩后面的呼吸乱了好几下）", N),
            L("……这是殿下亲手缝的。……那时候，她才这么高……"),
            L("（说到一半，他忽然停住了，像是说漏了什么）", N),
            L("……跟你没关系。"),
        ], "set": {"flags": ["knight_asked_hanky"]}},
        "blue": {"lines": [
            L("（身后的阴影里，有人走了过来。火把的光落在蓝色公主的脸上）", N),
            L("……巡逻，快回来了。", BLUE),
            L("（骑士抬起头，看见了她。他整个人僵住了）", N),
            L("……？"),
            L("（他看看蓝色公主，又看看粉色公主，再看回蓝色公主。铁链在他手腕上一下一下地抖）", N),
            L("……两个……？"),
            L("……一样的……脸……"),
            L("（他往后退，一直退到墙角，后背重重地撞在石壁上）", N),
            L("……又是这样……那天晚上……也是两个……"),
            L("你们……到底哪一个才是……！"),
            L("……？", BLUE),
            L("……幻术。……又是幻术！别过来！"),
            L("来人——！！有人闯进来了！！"),
        ]},
    }, **_question("night", [
        L("……你问我？"),
        L("钟敲了十三下。……你站在钟楼上，往下看着我们，在笑。"),
        L("十三下……？我、我不记得……", P, "sad"),
        L("你当然不记得。……凶手都这么说。"),
    ]), **_question("fall", [
        L("……你自己放出来的东西，还要问我？"),
        L("一千只手。……整座城都在笑，笑到再也站不起来。"),
        L("……那些笑声里，有一个，和你一模一样。"),
        L("……！", P, "surprise"),
    ]), **_question("why", [
        L("……城堡底下的封印，只有王族的手打得开。"),
        L("我赶到的时候，站在封印前面的——是你。"),
        L("……还要我说得更清楚吗？"),
    ])),
}
