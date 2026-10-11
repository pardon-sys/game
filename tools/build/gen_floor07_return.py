"""生成第七层「第七层·归途」（levels/floor_07_return）：走出第八层的小房间之后，粉色公主带着蓝色公主往下走的长路。
（和原来的第七层「升天回廊」不是同一张图。）很平静、没有怪。
  地图：楼梯平台（spawn from_shelter，存档点）→ 回廊 → 旧大厅 → 往下的走廊 → 立柱厅 → 往右的回廊 → 出口前的小厅。
  边走边聊（BanterZone，data/dialogues/floor_07/banter.json）：4 段，两人头顶轮流冒气泡，不打断走路——
    f7r_1 夜迷宫和小屋（脚心为什么那么痒）/ f7r_2 地下小镇的变化 / f7r_3 对镇上的人的看法 / f7r_4 两个人自己
  第 5 段（过场 f7r_names，出口前的触发区）：互问名字 → 士兵冲进来打断：小镇被大量怪物袭击 → 两人跑回小镇（floor_06_war）。
  有千手痒痒裤（剧情标记 blue_tickle_pants）时，蓝色公主的几句换成夹着「哈哈」的版本，粉色公主会奇怪。
  人物：粉色公主操控，蓝色公主跟着（blue_princess follow=true）；不能切换（no_switch）。
  过场：f7r_arrive（到达时 3 句）、f7r_names。
用法：python tools/build/gen_floor07_return.py，然后 build_level.gd -- floor=floor_07_return
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

FID = "floor_07_return"
W, H = 70, 30
g = [["#"] * W for _ in range(H)]
cells = {}


def room(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "."


def put(x, y, spec):
    cells.setdefault((x, y), []).append(spec)


# 平台 → 回廊 → 旧大厅 → 往下的走廊 → 立柱厅 → 往右的回廊 → 出口前的小厅
room(2, 2, 11, 9)            # 楼梯平台
room(12, 5, 30, 6)           # 回廊一
room(31, 2, 42, 10)          # 旧大厅
room(36, 11, 37, 17)         # 往下的走廊
room(26, 18, 45, 25)         # 立柱厅
room(46, 21, 60, 22)         # 回廊二
room(61, 13, 67, 27)         # 出口前的小厅
room(63, 11, 65, 12)         # 出口
for (x, y) in ((30, 20), (34, 20), (38, 20), (42, 20), (30, 23), (34, 23), (38, 23), (42, 23)):
    g[y][x] = "#"            # 立柱
for (x, y) in ((34, 4), (39, 4), (34, 8), (39, 8)):
    g[y][x] = "#"            # 旧大厅的柱子
put(6, 3, "prop type=stairs_up")
put(6, 4, "spawn id=from_shelter")
put(6, 5, "player")
put(7, 5, "blue_princess follow=true ai=false")
put(3, 8, "savepoint place=第七层·归途")
put(64, 11, "prop type=stairs_down")
# 装饰：旧旗子、木箱、灯
for (x, y) in ((32, 3), (41, 3)):
    put(x, y, "prop type=banner")
for (x, y) in ((32, 9), (41, 9), (27, 24), (44, 19)):
    put(x, y, "prop type=crate")
for (x, y) in ((28, 19), (44, 24), (62, 14), (66, 14)):
    put(x, y, "prop type=lamp")
for (x, y) in ((4, 1), (9, 1), (16, 4), (24, 4), (33, 1), (40, 1), (35, 12), (38, 14), (28, 17), (43, 17), (50, 20),
               (56, 20), (62, 12), (66, 12)):
    if g[y][x] == "#":
        put(x, y, "torch lit=true")
# 边走边聊的触发区（w / h 格，以这一格为中心）
put(20, 5, "banter id=f7r_1 w=3 h=2")
put(36, 13, "banter id=f7r_2 w=2 h=3")
put(32, 21, "banter id=f7r_3 w=3 h=4")
put(52, 21, "banter id=f7r_4 w=3 h=2")
put(64, 17, "trigger cutscene=f7r_names w=7 h=3")

specs, pool = {}, list("ABCDEFGHIJKLMNOQRSUVXYZabcdefghijklmnopqrsuvwxyz0123456789")
fixed = {"player": "P", "torch lit=true": "t"}
for (x, y), sp in cells.items():
    spec = " + ".join(sp)
    ch = fixed.get(spec) or specs.get(spec)
    if ch is None:
        ch = specs[spec] = pool.pop(0)
    g[y][x] = ch
head = ("[level]\n# 第七层·归途（tools/build/gen_floor07_return.py 生成，不要直接改）\nintro =\nintro_cutscene = f7r_arrive\n"
        "ambient = 0.46,0.42,0.6\nno_switch = true\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n")
legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
out = Path("levels") / FID
out.mkdir(parents=True, exist_ok=True)
(out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
(out / "design.json").write_text(json.dumps({"_说明": [
    "第七层·归途（gen_floor07_return.py 生成）：没有怪的长路，4 段边走边聊（banter f7r_1~4）+ 出口前的问名字过场（f7r_names）→ 战乱的小镇。"]},
    ensure_ascii=False, indent="\t") + "\n")

P, BLUE, N = "公主", "蓝色的公主", ""


def L(who, text, pants=None, pants_only=False):
    d = {"who": who, "text": text}
    if pants:
        d["pants_text"] = pants
    if pants_only:
        d["pants_only"] = True
    return d


BANTER = {
    "f7r_1": [
        L("pink", "说起来……昨晚我做了好奇怪的梦。"),
        L("pink", "梦里一大堆羽毛追着我，醒来脚心还麻麻的。"),
        L("blue", "……是吗。", "……是、是吗。……哈。"),
        L("pink", "你那时候在哪里呀？醒来就看到你，吓我一跳。"),
        L("blue", "……散步。", "……散、散步。……噗。"),
        L("pink", "……你刚才是不是笑了？你今天好奇怪哦。", pants_only=True),
        L("blue", "……没有。……走吧。"),
    ],
    "f7r_2": [
        L("pink", "这次回去，小镇会不会又变样了？"),
        L("pink", "上次走的时候，集市那边又多了好几个摊子。"),
        L("blue", "……篝火派对，每天晚上都有。"),
        L("pink", "对对！还有新盖的房子，屋顶是用矿车的木板拼的！"),
        L("blue", "……以前只有三间屋子。……现在，好多人。", "……以前只有三间屋子。……哈、现在，好多人。"),
        L("pink", "都是大家一点点盖起来的吧。真厉害。"),
    ],
    "f7r_3": [
        L("pink", "队长看起来凶凶的，其实人很好。"),
        L("blue", "……他审问你的时候，可不好。"),
        L("pink", "那、那是一开始嘛！后来他还给我讲营地的故事。"),
        L("pink", "市场监督总是皱着眉头算账，派对的主人一直在笑。"),
        L("blue", "……面包店的奶奶，会多给一块饼干。"),
        L("pink", "诶——原来你也会去要饼干！"),
        L("blue", "……小孩子们……总缠着我，要看冰。", "……小孩子们……总缠着我，要看冰。……哈、哈，腿……"),
        L("pink", "腿？你的腿怎么了？", pants_only=True),
        L("blue", "……没事。"),
    ],
    "f7r_4": [
        L("pink", "一开始……你还把我关起来呢。"),
        L("blue", "……那时候，不知道你是谁。"),
        L("pink", "现在呢？"),
        L("blue", "……现在。……走在一起。"),
        L("pink", "嘿嘿。我也觉得，和你一起走，一点都不怕了。"),
        L("blue", "……", "……噗。"),
        L("blue", "……谢谢。"),
        L("pink", "诶？你、你刚才说谢谢了？再说一遍！"),
        L("blue", "……不说。"),
    ],
}
dlg = Path("data/dialogues/floor_07")
dlg.mkdir(parents=True, exist_ok=True)
(dlg / "banter.json").write_text(json.dumps({"_说明": ["第七层·归途边走边聊（gen_floor07_return.py 生成；BanterZone 读）。"], **BANTER},
                                            ensure_ascii=False, indent="\t") + "\n")
old = dlg / "return.json"
if old.exists():
    old.unlink()


def A(do, **kw):
    kw["do"] = do
    return kw


def line(sp, text, emotion=None, actions=None, auto=None):
    s = {"speaker": sp, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    if auto:
        s["auto"] = auto
    return s


BLUE_NPC = "BluePrincess_7_5"
ARRIVE = {"name": "第七层·归途", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("fade_in", time=1.0)], "wait": 1.0},
    line(P, "第七层……？我们之前走过这里吗？……好像不太一样。", "surprise"),
    line(BLUE, "……路，变了。"),
    line(P, "没关系！这次我们两个一起走！", "happy"),
]}
NAMES = {"name": "第七层·归途：名字", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("camera", to=[64, 17.5], zoom=1.3, time=0.6), A("face", who="princess", dir="right"),
                 A("move", who=BLUE_NPC, to=[65, 18], speed=40)], "wait": 0.8},
    {"actions": [A("face", who=BLUE_NPC, dir="left")], "wait": 0.3},
    line(P, "……说起来。", "normal"),
    line(P, "我们一起走了这么久……我还不知道你的名字。", "shy"),
    line(BLUE, "……"),
    line(BLUE, "……你先说。"),
    line(P, "诶？我、我的名字是——", "shy"),
    {"actions": [A("sfx", sound="door"), A("spawn", id="soldier", kind="npc:guard", at=[64, 11], dir="down"),
                 A("move", who="soldier", to=[64, 16], speed=110), A("shake", time=0.3)], "wait": 0.6},
    line("保卫队员", "找、找到了！两位公主——！", None, [A("bubble", who="princess", kind="surprise")]),
    line("保卫队员", "小镇……小镇被大量的怪物袭击了！"),
    line("保卫队员", "保卫队队长正在到处找你们，请马上回去！"),
    line(P, "怪物？！", "surprise"),
    line(BLUE, "……走。", "angry"),
    {"actions": [A("move", who="soldier", to=[64, 10], speed=110), A("move", who="princess", to=[64, 11], speed=95),
                 A("move", who=BLUE_NPC, to=[65, 11], speed=95), A("fade_out", time=1.0)], "wait": 1.2},
    {"actions": [A("set_flag", flag="f7r_done"), A("goto", to="floor_06_war", spawn="from_ruins")], "wait": 0.2},
]}
cut = Path("data/cutscenes/floor_07")
cut.mkdir(parents=True, exist_ok=True)
(cut / "f7r_arrive.json").write_text(json.dumps(ARRIVE, ensure_ascii=False, indent="\t") + "\n")
(cut / "f7r_names.json").write_text(json.dumps(NAMES, ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
if not any(f["id"] == FID for f in lst):
    i = next(i for i, f in enumerate(lst) if f["id"] == "floor_08_shelter") + 1
    lst.insert(i, {"id": FID, "name": "第七层·归途", "scene": "res://levels/%s/floor.tscn" % FID, "group": "floor_07", "music": "dungeon"})
    Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("%s：%dx%d" % (FID, W, H))
