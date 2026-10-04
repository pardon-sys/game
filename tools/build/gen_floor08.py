"""生成第八层「千手之间」：Boss 房（levels/floor_08）、巨石追逐（levels/floor_08_chase）、过场、战败小剧场、石碑。

floor_08（36x34）：下面是入口走廊（存档点，本层唯一），上面是 30x18 的 Boss 房（千手痒痒魔盘在上沿）；
  左上角另有一间封住的小屋 = 千手的巢穴（阶段三献祭时被抓进去，右边小窗拍那里）。
  到达点（spawn id=…，Floor8Director 用）：boss、pink、lair、circle、plate_a1/a2/b1/b2/c1/c2、summon1~4、limb1~4、
  blue_fight、pink_fight、arena_tl、arena_br。入口的门（gate group=f8_gate）开战时关上。
floor_08_chase（30x74）：两条竖直跑道（lane_a / lane_b = 第 0 格的中心），ChaseRun 控制。
过场 data/cutscenes/floor_08/：f8_intro_a / f8_intro_b（开场）、f8_phase2 / f8_phase3（阶段切换）、f8_victory_a / f8_victory_b（胜利）、f8_ending（逃出来）。
小剧场 data/theater/floor_08/：f8_defeat_<阶段>_<1|2>（每阶段两种，第二次起换第二种）、f8_chase_fail。
蓝色公主的台词：她和千手是旧识，带着惋惜和自责，但从不说出它是谁。
用法：python tools/build/gen_floor08.py，然后 build_level.gd -- floor=floor_08、floor=floor_08_chase
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")


class Map:
    def __init__(self, fid, w, h, header, title):
        self.fid, self.w, self.h, self.header, self.title = fid, w, h, header, title
        self.g = [["#"] * w for _ in range(h)]
        self.specs = {}
        self.pool = list(POOL)
        self.cells = {}

    def E(self, spec):
        fixed = {"player": "P", "torch lit=true": "t"}
        if spec in fixed:
            return fixed[spec]
        if spec not in self.specs:
            self.specs[spec] = self.pool.pop(0)
        return self.specs[spec]

    def room(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = "."

    def put(self, x, y, spec):
        assert self.g[y][x] != "#" or spec.startswith(("torch", "walltrap")), (self.fid, x, y, spec)
        self.cells.setdefault((x, y), []).append(spec)

    def torch(self, x, y):
        assert self.g[y][x] == "#", (x, y)
        self.cells[(x, y)] = ["torch lit=true"]

    def write(self):
        for (x, y), specs in self.cells.items():
            self.g[y][x] = self.E(" + ".join(specs))
        out = Path("levels") / self.fid
        out.mkdir(parents=True, exist_ok=True)
        legend = "".join("%s = %s\n" % (c, s) for s, c in self.specs.items())
        head = "[level]\n# %s（tools/build/gen_floor08.py 生成，不要直接改）\n%s\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n" % (self.title, self.header)
        (out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in self.g) + "\n")
        print("%s：%dx%d，图例 %d 种" % (self.fid, self.w, self.h, len(self.specs)))


# ================================================================ Boss 房
W, H = 36, 34
AX0, AY0, AX1, AY1 = 3, 7, 32, 24          # Boss 房（含）
m = Map("floor_08", W, H, "intro =\nintro_cutscene =\nambient = 0.42,0.36,0.55", "第八层·千手之间")
m.room(AX0, AY0, AX1, AY1)
m.room(16, AY1 + 1, 19, 32)                # 入口走廊
m.room(2, 1, 8, 4)                         # 巢穴（封住的小屋）
for x in (6, 12, 24, 29):
    m.torch(x, AY0 - 1)
for y in (12, 19):
    m.torch(AX0 - 1, y)
    m.torch(AX1 + 1, y)
m.torch(15, 29)
m.torch(20, 29)
# 入口（开战时关上）
for x in (17, 18):
    m.put(x, AY1 + 1, "gate group=f8_gate is_open=true")
m.put(18, 31, "player")
m.put(17, 29, "savepoint place=千手之间·入口")
m.put(18, 27, "sign dialogue=sign8_door")
m.put(19, 31, "f8director")
MARKS = {
    "boss": (18, 10), "pink": (18, 13), "lair": (5, 3), "circle": (18, 17),
    "plate_a1": (5, 15), "plate_a2": (30, 15), "plate_b1": (8, 22), "plate_b2": (27, 11),
    "plate_c1": (9, 11), "plate_c2": (26, 22),
    "summon1": (4, 9), "summon2": (31, 9), "summon3": (4, 23), "summon4": (31, 23),
    "limb1": (11, 16), "limb2": (25, 16), "limb3": (13, 21), "limb4": (23, 21),
    "blue_fight": (15, 20), "pink_fight": (21, 20), "arena_tl": (AX0, AY0), "arena_br": (AX1, AY1),
}
for k, (x, y) in MARKS.items():
    m.put(x, y, "spawn id=%s" % k)
# 巢穴里的装饰（羽毛、刷子）
m.put(3, 2, "decor tile=74")
m.put(7, 4, "decor tile=73")
m.write()
Path("levels/floor_08/design.json").write_text(json.dumps({
    "_说明": ["第八层（gen_floor08.py 生成）：isolated = 故意走不到的区域（千手的巢穴：阶段三献祭时被抓进去，右边小窗拍那里）。"],
    "isolated": [[2, 1, 8, 4]]}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 巨石追逐
CW, CH = 30, 74
CELLS, CELL_T = 10, 6                       # 10 格，每格 6 个图块（ChaseRun.CELL_PX = 96）
LANE_TOP = 6
c = Map("floor_08_chase", CW, CH, "intro =\nintro_cutscene =\nambient = 0.5,0.42,0.55", "第八层·崩塌的回廊")
c.room(3, 2, 9, LANE_TOP + CELLS * CELL_T + 4)
c.room(20, 2, 26, LANE_TOP + CELLS * CELL_T + 4)
for y in range(8, CH - 6, 9):
    c.torch(2, y)
    c.torch(10, y)
    c.torch(19, y)
    c.torch(27, y)
c.put(6, LANE_TOP, "spawn id=lane_a")
c.put(23, LANE_TOP, "spawn id=lane_b")
c.put(6, LANE_TOP + 3, "player")
c.put(8, 3, "f8chase")
c.write()
Path("levels/floor_08_chase/design.json").write_text(json.dumps({
    "_说明": ["追逐战（gen_floor08.py 生成）：两条跑道互不相通，isolated = 另一条跑道（小窗里的那个人跑的）。"],
    "isolated": [[20, 2, 26, LANE_TOP + CELLS * CELL_T + 4]]}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 对话 / 过场 / 小剧场
P, BLUE, BOSS, S, N = "公主", "蓝色的公主", "千手痒痒魔", "石碑", ""
DLG = Path("data/dialogues/floor_08")
DLG.mkdir(parents=True, exist_ok=True)
(DLG / "signs.json").write_text(json.dumps({
    "sign8_door": [{"speaker": S, "text": "【千手之间】进去之前，先在日记本上存档吧。"},
                   {"speaker": BLUE, "text": "……里面，有笑声。"}],
}, ensure_ascii=False, indent="\t") + "\n")


def A(do, **kw):
    kw["do"] = do
    return kw


def line(speaker, text, emotion=None, actions=None):
    s = {"speaker": speaker, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    return s


def cut(name, steps):
    return {"name": name, "letterbox": True, "skippable": True, "steps": steps}


BOSS_AT = list(MARKS["boss"])
CUTS = {
    "f8_intro_a": cut("第八层：千手之间", [
        {"actions": [A("fade_in", time=0.6), A("camera", who="princess", time=0.0)], "wait": 0.6},
        {"actions": [A("move", who="princess", to=[18, 22], speed=60), A("camera", who="princess", time=0.8)]},
        {"actions": [A("bubble", who="princess", kind="surprise"), A("camera", to=[18, 13], time=1.0), A("shake", time=0.4, strength=2.0)], "wait": 1.0},
        line(P, "哈哈哈哈！放、放我下来——哈哈哈！手、手太多了哈哈哈哈！", actions=[A("pose", who="Pink", emotion="helpless_2", hold=True)]),
        line(BOSS, "……嘻……嘻嘻……笑……再笑……"),
        line(BLUE, "……"),
        line(BLUE, "……原来，你在这里。", "sad"),
        line(P, "诶？蓝、蓝色的……你怎么会……哈哈哈哈！别、别挠那里——！"),
        line(BOSS, "……？……你……"),
        line(BLUE, "……别动。", "angry", [A("sfx", sound="chant"), A("camera", who="princess", time=0.6)]),
    ]),
    "f8_intro_b": cut("第八层：并肩", [
        {"actions": [A("flash", time=0.4), A("shake", time=0.5, strength=3.0)], "wait": 0.5},
        line(P, "掉、掉下来了……！呼……呼……得救了……", actions=[A("pose", who="Pink", emotion="surprise")]),
        line(P, "你……是追着我来的？明明我丢下你，自己跑了……", actions=[A("pose", who="Pink", emotion="sad")]),
        line(BLUE, "……之后再说。"),
        line(BOSS, "……一起……玩……？"),
        line(BLUE, "……对不起。……但我不会让你再挠她了。", "sad"),
        line(P, "你……认识这个怪物吗？", actions=[A("pose", who="Pink", emotion="surprise")]),
        line(BLUE, "……来了。", "angry"),
        {"actions": [A("notify", text="两人一起战斗！Tab 切换操控，没操控的那个会自己战斗"), A("set_flag", flag="f8_fight_started")], "wait": 0.3},
        {"actions": [A("notify", text="倒下的人：走到旁边按住 E 3 秒救起。地上的圆圈 / 红线是千手的攻击，快躲开")], "wait": 0.3},
    ]),
    "f8_phase2": cut("第八层：它缩上去了", [
        {"actions": [A("shake", time=0.6, strength=3.0), A("camera", to=[18, 12], time=0.8)], "wait": 0.8},
        line(BOSS, "……痛……好痛……"),
        line(P, "它、它缩到天花板上去了！这样打不到了！"),
        line(BLUE, "……你以前不会这样的。", "sad"),
        line(BLUE, "……地上有两块板子。一个人站一块。……锁链会把它拉下来。"),
        line(P, "两个人一起站上去……好！", "angry"),
        {"actions": [A("camera", who="princess", time=0.6),
                     A("notify", text="两块压力板同时站上人，锁链就会把千手拽下来——那时攻击本体！地形会不停变化")], "wait": 0.6},
    ]),
    "f8_phase3": cut("第八层：不再下来", [
        {"actions": [A("shake", time=0.8, strength=4.0), A("camera", to=[18, 12], time=0.8)], "wait": 0.8},
        line(BOSS, "……不……下去了……再也……不下去了……"),
        line(P, "它把手全收起来了……这样根本打不到！", "surprise"),
        line(BLUE, "……中间的光圈。走进去的人，会被它抓上去。"),
        line(BLUE, "……它挠人的时候，手会伸下来。……那时候打。"),
        line(P, "那、那谁去……", "sad"),
        line(BLUE, "……我去。……这是我欠它的。", "sad"),
        line(P, "不行！……我们轮流！谁撑不住了就换人！", "angry"),
        line(BLUE, "……嗯。"),
        {"actions": [A("camera", who="princess", time=0.6),
                     A("notify", text="走进光圈的人会被抓进巢穴（右边小窗：← → 交替连按挣扎），另一个人打下来的手臂")], "wait": 0.4},
        {"actions": [A("notify", text="阶段三：任何一人倒下都会战败！")], "wait": 0.3},
    ]),
    "f8_victory_a": cut("第八层：恼怒", [
        {"actions": [A("camera", to=[18, 12], time=0.8)], "wait": 0.8},
        line(BOSS, "……为……什么……"),
        line(P, "赢、赢了……？"),
        line(BOSS, "……走开……全部……走开——！", actions=[A("shake", time=1.0, strength=5.0)]),
    ]),
    "f8_victory_b": cut("第八层：崩塌", [
        line(P, "天花板塌下来了！快跑——！", "surprise", [A("shake", time=0.6, strength=4.0)]),
        line(BLUE, "……"),
        line(BLUE, "……再见。", "sad", [A("camera", to=[18, 12], time=0.8)]),
        line(P, "蓝色的公主！快点！", "angry"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.9},
    ]),
    "f8_ending": cut("第八层：逃出来", [
        {"actions": [A("shake", time=0.6, strength=3.0)], "wait": 0.5},
        line(P, "出、出来了……！我们逃出来了！", "happy"),
        line(BLUE, "……嗯。"),
        line(P, "……刚才那个怪物。你认识它，对吧？", "sad"),
        line(BLUE, "……"),
        line(BLUE, "……很久以前的事了。"),
        line(P, "……嗯。那我不问了。", "shy"),
        line(P, "下次……换我陪你去。不管是哪里。", "happy"),
        line(BLUE, "……嗯。……谢谢。", "shy"),
        {"actions": [A("chapter_end", title="第八章 · 千手之间", subtitle="—— 待续 ——")], "wait": 1.4},
    ]),
}
CUT = Path("data/cutscenes/floor_08")
CUT.mkdir(parents=True, exist_ok=True)
for name, cs in CUTS.items():
    (CUT / (name + ".json")).write_text(json.dumps(cs, ensure_ascii=False, indent="\t") + "\n")


# ---------------------------------------------------------------- 战败小剧场：两个公主一起被千手挠
def tk(who, by, zone, fx="hand", repeat=8):
    return A("tickle", who=who, by=by, repeat=repeat, interval=0.2, fx=fx, zone=zone)


def pose(who, visual):
    return A("pose", who=who, visual=visual, anim="helpless")


def theater(name, lines, intro_n=""):
    steps = [{"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5}]
    if intro_n:
        steps.append({"speaker": N, "text": intro_n})
    zones = ["armpit", "waist", "sole", "thigh", "belly", "butt"]
    for i, (sp, text) in enumerate(lines):
        acts = []
        z = zones[i % len(zones)]
        if sp == P:
            acts = [tk("pink", "boss", z, "feather" if i % 2 else "hand")]
            if i > len(lines) // 2:
                acts.append(pose("pink", "helpless_2"))
        elif sp == BLUE:
            acts = [tk("blue", "boss", ["thigh", "butt", "waist"][i % 3], "brush" if i % 2 else "hand")]
            if i > len(lines) // 2:
                acts.append(pose("blue", "helpless_2"))
        else:
            acts = [tk("pink", "boss", z), tk("blue", "boss", "thigh", "brush")]
        steps.append({"speaker": sp, "text": text, "actions": acts})
    steps.append({"actions": [A("voice", state=""), A("fade_out", time=0.8)], "wait": 0.9})
    return {"name": name, "cast": {
        "pink": {"kind": "npc:pink_princess", "at": [-24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
        "blue": {"kind": "npc:blue_princess", "at": [24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
        "boss": {"kind": "monster:thousand_hand", "at": [0, -16], "scale": 0.5},
    }, "steps": steps}


DEFEAT = {
    (1, 1): ("千手之间·战败（阶段一）", "（两个人都被手臂卷了起来，吊在千手的身前）", [
        (BOSS, "……抓到……了……两个……"), (P, "放、放开！哈哈……腋下……不要从腋下开始——！"),
        (BLUE, "……唔。……大腿……别、别碰……"), (BOSS, "……笑……一起……笑……"),
        (P, "哈哈哈！好多只手——数、数不过来哈哈哈！"), (BLUE, "……噗、哈哈……你、你还是……从右边来……"),
        (P, "蓝色的公主？！你、你在笑吗？哈哈哈哈——"), (BLUE, "哈、哈哈……别、别看……"),
        (BOSS, "……嘻嘻……脚……也……"), (P, "脚、脚心也——哈哈哈哈！不行不行不行！"),
        (BLUE, "哈哈哈……对、对不起……都是我……哈哈哈……"), (P, "什么都是你啦哈哈哈！先、先想办法哈哈哈！"),
        (BOSS, "……再……多……笑……"), (P, "哈哈哈哈哈……投降……投降哈哈哈哈……"),
        (BLUE, "……哈、哈哈……再、再来一次……下次……一定……"), (P, "……哈……哈……眼、眼前……全是手指……"),
    ]),
    (1, 2): ("千手之间·战败（阶段一·又一次）", "（又被抓住了。千手的手指好像比上次更多）", [
        (BOSS, "……又……来了……"), (P, "怎、怎么又被抓住了——呀哈哈！"),
        (BLUE, "……小怪……太多了……噗……"), (BOSS, "……这次……先……这里……"),
        (P, "腰！腰不行哈哈哈哈！"), (BLUE, "……哈、哈哈……屁、屁股……不行……"),
        (P, "你、你的弱点原来是那里吗哈哈哈！"), (BLUE, "……忘、忘掉……哈哈哈……"),
        (BOSS, "……记得……全部……记得……"), (BLUE, "……！……哈哈哈哈……你、你还记得……"),
        (P, "记得什么啦哈哈哈！"), (BLUE, "……哈哈……没、没什么……哈哈哈哈……！"),
        (BOSS, "……笑……像……以前……"), (P, "以前？哈哈哈哈——不、不行了——！"),
        (BLUE, "……哈哈哈……对不起……对不起……"), (P, "……哈……下次……下次一定……"),
    ]),
    (2, 1): ("千手之间·战败（阶段二）", "（锁链没能拉下它。两个人被吊上了半空）", [
        (BOSS, "……上来……陪我……"), (P, "好、好高！放我下去——哈哈哈！"),
        (BLUE, "……板子……没、没站稳……噗、哈哈……"), (BOSS, "……地上……都是……我的……"),
        (P, "刷子手！刷子手在刷脚心哈哈哈哈！"), (BLUE, "……哈、哈哈……大腿……别刷大腿……"),
        (BOSS, "……你……最怕……这里……"), (BLUE, "……！……哈哈哈……为、为什么还记得……哈哈哈哈……"),
        (P, "哈哈哈！它、它到底是谁啊——！"), (BLUE, "……哈哈……别、别问……哈哈哈……"),
        (BOSS, "……不……放……"), (P, "哈哈哈哈哈！投降！投降了哈哈哈哈！"),
        (BLUE, "哈哈哈哈……停、停下……我不想……这样见到你……"), (BOSS, "……一起……"),
        (P, "……哈……哈……锁、锁链……下次……一起拉……"), (BLUE, "……嗯……哈、哈哈……"),
    ]),
    (2, 2): ("千手之间·战败（阶段二·又一次）", "（又一次。地面变成了泥沼，两个人陷在里面动不了）", [
        (BOSS, "……陷……进去……"), (P, "泥、泥沼里还有手——哈哈哈！"),
        (BLUE, "……动、动不了……噗……"), (BOSS, "……这样……就……不会……走了……"),
        (P, "腋下和脚心一起——哈哈哈哈！"), (BLUE, "……哈哈……屁股……不、不行……"),
        (BOSS, "……以前……也是……这样……"), (BLUE, "……哈哈哈……以、以前……不是这样的……哈哈哈……"),
        (P, "以前到底怎样啦哈哈哈！"), (BLUE, "……哈、哈哈……以前……你……会停下来的……"),
        (BOSS, "……不……停……"), (P, "哈哈哈哈哈！完、完了哈哈哈！"),
        (BLUE, "……哈哈哈……对不起……是我……没回来……"), (P, "回、回来什么——哈哈哈哈！"),
        (BOSS, "……笑……"), (P, "……哈……下、下次……一定拉下来……"),
    ]),
    (3, 1): ("千手之间·战败（阶段三）", "（光圈里的那个撑不住了。另一个也被手臂拖了上去）", [
        (BOSS, "……都……上来……了……"), (P, "巢、巢穴里……全是手——哈哈哈！"),
        (BLUE, "……撑、撑不住了……噗、哈哈……"), (BOSS, "……不……放……永远……"),
        (P, "永、永远不行啦哈哈哈哈！"), (BLUE, "……哈哈……大腿……屁股……全、全部……"),
        (BOSS, "……你……回来了……"), (BLUE, "……哈哈哈……我……我回来了……哈哈哈……可是……"),
        (P, "可是什么——哈哈哈哈！"), (BLUE, "……哈哈……可是……我不能留下……哈哈哈哈……"),
        (BOSS, "……留……下……"), (P, "哈哈哈哈哈！放、放我们走哈哈哈！"),
        (BLUE, "……哈哈哈……对不起……对不起……"), (BOSS, "……笑……一直……"),
        (P, "……哈……哈……轮、轮流……下次……早点换人……"), (BLUE, "……嗯……哈……"),
    ]),
    (3, 2): ("千手之间·战败（阶段三·又一次）", "（又一次被拖进巢穴。手指好像认得她们哪里最怕）", [
        (BOSS, "……又……来……了……"), (P, "这、这次一上来就是脚心——哈哈哈！"),
        (BLUE, "……噗……别、别从右边……"), (BOSS, "……右边……你……喜欢……"),
        (BLUE, "……哈、哈哈……才、才不喜欢……哈哈哈……"), (P, "你们到底什么关系啦哈哈哈！"),
        (BLUE, "……哈哈……什么……关系都……没有……哈哈哈哈……"), (BOSS, "……骗……人……"),
        (P, "它说你骗人哈哈哈哈！"), (BLUE, "……哈哈哈哈……别、别学它说话……！"),
        (BOSS, "……笑……再笑……"), (P, "哈哈哈哈哈！不、不行了——！"),
        (BLUE, "……哈哈……下次……我撑久一点……"), (P, "下次……换我撑……哈哈……"),
        (BOSS, "……一起……"), (BLUE, "……哈……嗯……一起……"),
    ]),
}
TH = Path("data/theater/floor_08")
TH.mkdir(parents=True, exist_ok=True)
for (ph, k), (name, intro, lines) in DEFEAT.items():
    (TH / ("f8_defeat_%d_%d.json" % (ph, k))).write_text(json.dumps(theater(name, lines, intro), ensure_ascii=False, indent="\t") + "\n")
CHASE_FAIL = ("崩塌的回廊·没逃掉", "（巨石堵住了路。千手的残臂从碎石缝里伸了出来）", [
    (P, "路、路被堵住了——！"), (BOSS, "……别……走……"),
    (BLUE, "……它……还没放弃……"), (P, "手、手从石头缝里伸出来了——哈哈哈！"),
    (BLUE, "……噗……大腿……被抓住了……"), (BOSS, "……留……下……"),
    (P, "哈哈哈！脚、脚被抓着跑不了哈哈哈！"), (BLUE, "……哈、哈哈……别……别这样……"),
    (P, "两个人……要跑在一起才行……哈哈哈！"), (BLUE, "……哈哈……下次……别离我太远……"),
    (BOSS, "……笑……"), (P, "哈哈哈哈！好、好啦好啦——再来一次！"),
    (BLUE, "……哈……嗯。……再来。"), (P, "……一、二、三……跑！"),
])
(TH / "f8_chase_fail.json").write_text(json.dumps(theater(CHASE_FAIL[0], CHASE_FAIL[2], CHASE_FAIL[1]), ensure_ascii=False, indent="\t") + "\n")
print("第八层：%d 段过场、%d 段战败小剧场 + 追逐失败" % (len(CUTS), len(DEFEAT)))
