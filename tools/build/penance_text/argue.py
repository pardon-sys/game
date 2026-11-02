"""反省篇第一章·开场：营地医务帐篷（floor_06_penance_tent，进图就演 penance_argue）。
骑士篇尾声以后的那个夜里，骑士走到营地门口就倒下了，一直没醒。粉色公主要回地面查清自己是谁、王国为什么会亡；
队长说什么都不让。两个人越吵越凶，蓝色公主几次想插嘴都被盖过去。最后队长把粉色公主关进反省牢房。
"""
from .common import A, BLUE, CAP, KNIGHT, N, P, line

K, C, B, G1, G2 = "PtKnight", "PtCaptain", "PtBlue", "PtGuard1", "PtGuard2"


def argue():
    s = [
        {"actions": [A("spawn", id=K, kind="npc:knight", at=[4, 3], dir="down"), A("lie", who=K),
                     A("spawn", id=C, kind="npc:captain", at=[11, 4], dir="left"),
                     A("spawn", id=B, kind="npc:blue_princess", at=[6, 6], dir="up"),
                     A("camera", to=[8, 5], zoom=1.0, time=0.5)], "wait": 0.6},
        line(N, "（营地的医务帐篷里点着一盏油灯。骑士躺在角落的行军床上，盔甲卸在一边——他走到营地门口，就一头栽倒了，到现在都没醒）"),
        line(N, "（药剂师奶奶来看过，说他只是累坏了：诅咒在身体里待了太久，要睡很久很久）"),
        line(P, "……他会醒的，对吧？", "sad"),
        line(CAP, "……会。"),
        line(P, "那等他醒了，我想问他那天晚上的事。还有那半枚徽章——", "sad"),
        line(CAP, "不用等他。……你们俩，明天开始照常过日子。"),
        line(P, "……照常？", "surprise"),
        line(P, "队长，我想回地面。", None, [A("face", who="princess", dir="right")]),
        line(CAP, "……", None, [A("face", who=C, dir="left")]),
        line(P, "我想知道我是谁。为什么醒来就在地底下，为什么大家都叫我公主，王国为什么会没了——", "angry"),
        line(P, "骑士叫她殿下，你说我小时候钻管道，奶奶说我像「小时候的那孩子」……大家都知道些什么，就我不知道！", "angry"),
        line(CAP, "不行。"),
        line(P, "为什么！", "angry"),
        line(CAP, "地面上什么都没有了。"),
        line(P, "那我就去看看「什么都没有」是什么样子！", "angry"),
        line(BLUE, "……那个……", None, [A("bubble", who=B, kind="dots")]),
        line(CAP, "你不懂。那天晚上——", None, [A("face", who=C, dir="down")]),
        line(N, "（队长的话停在了一半。他攥紧了拳头，又松开）"),
        line(P, "那天晚上怎么了？你说呀！每次都说一半！", "angry"),
        line(CAP, "……我说过的话，就是全部。"),
        line(BLUE, "……我觉得……", None, [A("bubble", who=B, kind="dots")]),
        line(P, "你骗人！那块手帕上绣的两个小人——", "angry"),
        line(CAP, "……手帕给了你，就是你的。别的不要问。", None, [A("face", who=C, dir="left")]),
        line(P, "……又是这样！", "angry"),
        line(CAP, "……总之，不行。地面上的路早就塌了，上去的人一个都没回来。"),
        line(P, "那是他们不够努力！我会憋笑、会冲刺、会魔力释放——", "angry"),
        line(CAP, "然后在半路上笑倒，被什么东西抓去挠一整晚？"),
        line(P, "……那、那也是我的事！", "angry"),
        line(BLUE, "……两个人……都……", None, [A("bubble", who=B, kind="sad")]),
        line(N, "（两个人的声音越来越大，把蓝色公主那句小小的话整个盖了过去。她张了张嘴，又闭上了）"),
        line(CAP, "你的事？七天前你还是被罚在广场上的赎罪犯人。"),
        line(P, "罚完了！一百个工时，一个不少！", "angry"),
        line(CAP, "……你倒是记得清楚。"),
        line(P, "你不让我去，我就自己去！今天晚上就走！", "angry"),
        line(KNIGHT, "……唔……", None, [A("bubble", who=K, kind="dots")]),
        line(N, "（行军床上的骑士皱了皱眉，又沉沉地睡了过去。帐篷里一下子安静了）"),
        line(BLUE, "……小声……", None, [A("face", who=B, dir="right")]),
        line(CAP, "……", None, [A("face", who=C, dir="left")]),
        line(CAP, "……好。既然你听不进去，就去一个安静的地方，好好想一想。"),
        line(P, "……什么意思？", "surprise"),
        line(CAP, "来人。", None, [A("spawn", id=G1, kind="npc:guard", at=[14, 8], dir="left"),
                                   A("spawn", id=G2, kind="npc:guard", at=[14, 9], dir="left")]),
        line(N, "（两个保卫队员掀开帘子走了进来，一左一右站到了她身边）", None,
             [A("move", who=G1, to=[9, 7], time=0.6), A("move", who=G2, to=[7, 8], time=0.6)]),
        line(CAP, "把她关进反省室。……让她好好反省。想通了再出来。"),
        line(P, "反、反省室！？我又没做错事！放开——！", "angry", [A("shake", who="princess", time=0.4)]),
        line(BLUE, "……等……", None, [A("move", who=B, to=[7, 6], time=0.3)]),
        line(CAP, "你也回去睡觉。"),
        line(BLUE, "……", None, [A("bubble", who=B, kind="dots")]),
        line(N, "（蓝色公主站在原地，攥着手心里的半枚徽章。她看了看被架走的粉色公主，又看了看队长的背影，什么都没有说出来）"),
        line(P, "臭队长——！我才不会认错的——！", "angry"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.8},
        {"actions": [A("goto", to="floor_06_penance_cell", spawn="from_tent")], "wait": 0.2},
    ]
    return {"name": "吵架", "letterbox": True, "skippable": True, "steps": s}


def cell_in():
    s = [
        {"actions": [A("camera", to=[10, 7], zoom=1.0, time=0.4)], "wait": 0.4},
        line(N, "（「哐当」。铁门在身后锁上了。保卫队员的脚步声越走越远）"),
        line(P, "……反省室。", "angry"),
        line(N, "（一间小小的石头屋子。一张床、一个木桶、一张奇怪的凳子、一口旧箱子……门口还趴着一只橘猫，懒洋洋地看着她）"),
        line(P, "……这哪里是反省室。这些东西，怎么看都是……", "sad"),
        line(P, "……挠痒用的吧。", "sad"),
        line(P, "哼。我才不会反省。我就坐在这里，一动不动，等到天亮。", "angry"),
        line(N, "（……十秒钟以后，她已经开始在屋子里转来转去了）"),
        line(P, "……就、就看一看。看一看又不会怎么样。", "shy"),
        {"actions": [A("camera", reset=True, time=0.4), A("notify", text="调查反省室里的东西（按 E）")], "wait": 0.4},
    ]
    return {"name": "反省室", "letterbox": True, "skippable": True, "steps": s}


CUTSCENES = {"penance_argue": argue, "penance_cell_in": cell_in}
