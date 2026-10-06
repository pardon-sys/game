"""生成第八层「千手之间」：Boss 房（levels/floor_08）、巨石追逐（levels/floor_08_chase）、过场、战败小剧场、石碑。

floor_08（36x34）：下面是入口走廊（存档点，本层唯一），上面是 30x18 的 Boss 房（千手痒痒魔盘在上沿）。
  到达点（spawn id=…，Floor8Director 用）：boss、pink、circle、plate_a1/a2/b1/b2/c1/c2、summon1~4、limb1~4、
  blue_fight、pink_fight、arena_tl、arena_br。入口的门（gate group=f8_gate）开战时关上。
floor_08_chase：一间底板小屋，无限滚动的跑道由 ChaseRun 自己画。
过场 data/cutscenes/floor_08/：f8_intro_a / f8_intro_b（开场）、f8_phase2 / f8_phase3（阶段切换）、f8_victory_a / f8_victory_b（胜利）、f8_ending（逃出来）。
小剧场 data/theater/floor_08/：f8_defeat_<阶段>_<n>（阶段一、二各两段按战败次数轮流；阶段三 1→2→3→4，之后一直是第 4 段「叠在一起」；
BOSS_CG 的大图按幕换上；每段结尾都有两个人魔力疲倦爆发的一幕）、f8_chase_fail。
蓝色公主的台词：她和千手是旧识，带着惋惜和自责，但从不说出它是谁。
用法：python tools/build/gen_floor08.py，然后 build_level.gd -- floor=floor_08、floor=floor_08_chase
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import burst_lines as BL  # noqa: E402

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
for x in (6, 12, 24, 29):
    m.torch(x, AY0 - 1)
# 两侧竖墙上的火把照不到地面：改成场地四角和两侧中间的落地灯（灯光道具）
for (x, y) in ((AX0, AY0 + 1), (AX1, AY0 + 1), (AX0, AY1), (AX1, AY1), (AX0, 16), (AX1, 16)):
    m.put(x, y, "prop type=lamp")
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
    "boss": (18, 10), "pink": (18, 13), "circle": (18, 17),
    "plate_a1": (5, 15), "plate_a2": (30, 15), "plate_b1": (8, 22), "plate_b2": (27, 11),
    "plate_c1": (9, 11), "plate_c2": (26, 22),
    "summon1": (4, 9), "summon2": (31, 9), "summon3": (4, 23), "summon4": (31, 23),
    "limb1": (11, 16), "limb2": (25, 16), "limb3": (13, 21), "limb4": (23, 21),
    "blue_fight": (15, 20), "pink_fight": (21, 20), "arena_tl": (AX0, AY0), "arena_br": (AX1, AY1),
}
for k, (x, y) in MARKS.items():
    m.put(x, y, "spawn id=%s" % k)
m.write()
Path("levels/floor_08/design.json").write_text(json.dumps({
    "_说明": ["第八层（gen_floor08.py 生成）：boss_combos = 千手痒痒魔和它召唤的小怪凑的三来源组合（小怪是战斗中召唤的，不在地图上；",
             "level_design_test 检查组合的每个来源都是千手或它会召唤的小怪）。"],
    "boss_combos": ["th_brush_feast", "th_bubble_web", "th_feather_swarm", "th_latch_crawl"]}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 巨石追逐
# 跑道由 ChaseRun 自己画（无限滚动），这里只是一间底板小屋（level.gd 需要地板 / 墙 / 玩家出生点）。
c = Map("floor_08_chase", 20, 12, "intro =\nintro_cutscene =\nambient = 0.5,0.42,0.55", "第八层·崩塌的回廊")
c.room(2, 2, 17, 9)
for x in (5, 10, 15):
    c.torch(x, 1)
c.put(9, 6, "player")
c.put(11, 6, "f8chase")
c.write()
Path("levels/floor_08_chase/design.json").write_text(json.dumps({
    "_说明": ["追逐战（gen_floor08.py 生成）：这间小屋只是底板，两个人在 ChaseRun 画的无限跑道上跑（不在这间屋里），不做走遍地面的检查。"],
    "no_reachability": True}, ensure_ascii=False, indent="\t") + "\n")

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
        line(BLUE, "……别动。", "angry", [A("sfx", sound="chime", pitch=1.6), A("camera", who="princess", time=0.6)]),
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
        line(BLUE, "……中间的光圈。走进去的人，会被它吊起来。"),
        line(BLUE, "……它挠人的时候，手会伸下来。……那时候打。"),
        line(P, "那、那谁去……", "sad"),
        line(BLUE, "……我去。……这是我欠它的。", "sad"),
        line(P, "不行！……我们轮流！谁撑不住了就换人！", "angry"),
        line(BLUE, "……嗯。"),
        {"actions": [A("camera", who="princess", time=0.6),
                     A("notify", text="走进光圈的人会被吊起来挠（右边小窗：连按空格挣扎），另一个人打下来的手臂；打她也能帮她降闷笑")], "wait": 0.4},
        {"actions": [A("notify", text="阶段三：千手会用上全部力气——小心全屏的大招，躲进发光的安全圈！")], "wait": 0.3},
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


# 战败小剧场按幕写：每幕 {note 开头旁白, cg 这一幕的大图（没有就用失控立绘）, emo 两个人这一幕的立绘状态, lines}。
# 台词 (说话人, 文本) 或 (说话人, 文本, 立绘状态)；另一个公主说话时右边的立绘按这个状态显示（失控一 / 失控二）并跟着抖。
# 蓝色公主被挠的地方以大腿、屁股为主（她最怕）；千手对她的弱点了如指掌（暗示两人的过去，不点明）。
EMO_BY_ACT = ["helpless_1", "helpless_1", "helpless_2", "helpless_2", "helpless_2"]


# ---------------------------------------------------------------- 魔力疲倦爆发的一幕（每段战败剧场的结尾；叠在一起的那段中间也有一次）
# lines：前两句「满了」，然后爆发（白光 + 星光 + 释放的水声，千手被震开、立绘换成魔力释放），
#        第 3 句舒服、第 5 句千手回来，之后挠得更密、笑得更大声（蓝色公主嘴硬 → 破防，千手夸她，粉色公主吐槽）。
def burst_act(lines, boss_at=(0, -16), mob=False):
    def both_tk(repeat, interval, z_p="sole", z_b="thigh"):
        out = [tk("pink", "boss", z_p, "feather", repeat), tk("blue", "boss", z_b, "brush", repeat)]
        for t in out:
            t["interval"] = interval
        if mob:
            out.append(A("tickle", who="blue", by="m1", repeat=repeat, interval=interval, fx="brush", zone="butt"))
            out.append(A("tickle", who="pink", by="m2", repeat=repeat, interval=interval, fx="feather", zone="sole"))
        return out

    def say(ln, actions, emo):
        st = {"act": "burst", "speaker": ln[0], "text": ln[1], "actions": actions}
        if ln[0] in (P, BLUE):
            st["emotion"] = ln[2] if len(ln) > 2 else emo
        return st

    steps = []
    for ln in lines[:2]:
        steps.append(say(ln, [A("shake", who="pink", time=0.8), A("shake", who="blue", time=0.8), A("bubble", who="blue", kind="surprise"),
                              A("voice", state="laugh")] + both_tk(5, 0.24), "helpless_2"))
    boom = [A("flash", time=0.8), A("sfx", sound="star_burst", volume=-1.0), A("sfx", sound="water_release", volume=-2.0), A("voice", state=""),
            A("shake", who="pink", time=0.5), A("shake", who="blue", time=0.5), A("move", who="boss", to=[boss_at[0], boss_at[1] - 30], time=0.25)]
    if mob:
        boom += [A("move", who="m1", to=[80, 18], time=0.25), A("move", who="m2", to=[-70, 20], time=0.25)]
    steps.append({"act": "burst", "portrait": BL.PORTRAIT, "actions": boom, "wait": 1.1})
    for i, ln in enumerate(lines[2:]):
        if i < 2:
            acts = [A("bubble", who="blue" if ln[0] == BLUE else "pink", kind="shy")]
            emo = "burst"
        elif i == 2:
            acts = [A("move", who="boss", to=list(boss_at), time=0.6), A("voice", state="giggle")] + both_tk(4, 0.3)
            if mob:
                acts += [A("move", who="m1", to=[40, 22], time=0.6), A("move", who="m2", to=[8, 24], time=0.6)]
            emo = "helpless_1"
        else:
            acts = [A("voice", state="laugh"), A("shake", who="blue", time=0.6), A("shake", who="pink", time=0.6),
                    pose("pink", "helpless_2"), pose("blue", "helpless_2")] + both_tk(10, 0.15, ["sole", "waist", "armpit"][i % 3],
                                                                                     ["thigh", "butt"][i % 2])
            emo = "helpless_2"
        steps.append(say(ln, acts, emo))
    return steps


def theater(name, intro, acts, mob=False, cast_at=None):
    steps = [{"actions": [A("fade_in", time=0.5), A("voice", state="laugh")], "wait": 0.5}]
    if intro:
        steps.append({"speaker": N, "text": intro})
    pz = ["armpit", "waist", "sole", "neck", "belly"]
    bz = ["thigh", "butt", "thigh", "waist", "butt"]
    li = 0
    k = -1
    for act in acts:
        if "burst" in act:
            boss_at = (cast_at or {}).get("boss", [0, -16])
            steps.extend(burst_act(act["burst"], tuple(boss_at), mob))
            continue
        k += 1
        emo = dict({P: EMO_BY_ACT[k], BLUE: EMO_BY_ACT[k]}, **act.get("emo", {}))
        portrait = act.get("cg") or ("defeat_1" if k < 2 else "defeat_2")
        first = [tk("pink", "boss", pz[k % 5], "feather"), tk("blue", "boss", bz[k % 5], "brush")]
        if emo[P] == "helpless_2":
            first.append(pose("pink", "helpless_2"))
        if emo[BLUE] == "helpless_2":
            first.append(pose("blue", "helpless_2"))
        steps.append({"speaker": N, "text": act["note"], "portrait": portrait, "actions": first})
        for ln in act["lines"]:
            sp, text = ln[0], ln[1]
            li += 1
            if sp == P:
                acts_ = [tk("pink", "m2" if mob and li % 3 == 0 else "boss", pz[li % 5], "feather" if li % 2 else "hand")]
            elif sp == BLUE:
                by = ("m1" if li % 2 else "m2") if mob and k >= 1 else "boss"
                acts_ = [tk("blue", by, bz[li % 5], "brush" if li % 2 else "hand")]
            else:
                acts_ = [tk("pink", "boss", pz[li % 5]), tk("blue", "m1" if mob else "boss", bz[li % 5], "brush")]
            st = {"speaker": sp, "text": text, "actions": acts_}
            if sp in (P, BLUE):
                st["emotion"] = ln[2] if len(ln) > 2 else emo[sp]
            steps.append(st)
    steps.append({"actions": [A("voice", state=""), A("fade_out", time=0.8)], "wait": 0.9})
    cast = {
        "pink": {"kind": "npc:pink_princess", "at": [-24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
        "blue": {"kind": "npc:blue_princess", "at": [24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
        "boss": {"kind": "monster:thousand_hand", "at": [0, -16], "scale": 0.5},
    }
    if mob:
        cast["m1"] = {"kind": "monster:hedgehog", "at": [40, 22]}
        cast["m2"] = {"kind": "monster:squirrel", "at": [8, 24]}
    for who, at in (cast_at or {}).items():
        cast[who]["at"] = at
    return {"name": name, "cast": cast, "steps": steps}


DEFEAT = {
    (1, 1): ("千手之间·战败（阶段一）", "（两个人都被手臂卷了起来，吊在千手的身前。几十根手指在空中慢慢张开）", [
        {"note": "（手指先落在粉色公主的腋下——轻轻地、一根一根地划）", "emo": {BLUE: "shy"}, "lines": [
            (BOSS, "……抓到……了……两个……"), (P, "放、放开！哈哈……腋下……不要从腋下开始——！"),
            (P, "手指一根一根地划下来……好、好慢……慢得更痒啦哈哈哈！"), (BLUE, "……吵。……忍住就好。"),
            (P, "你说得轻松——哈哈哈！你倒是看看你那边！"),
            (N, "（另一只手停在蓝色公主的膝盖上，没有挠，只是轻轻搭着）"),
            (BLUE, "……唔。……别。……别往上。"), (BOSS, "……往……上……"),
            (BLUE, "……！……嗯、嗯唔……大腿……不……", "helpless_1"), (P, "诶？你刚才是不是抖了一下？哈哈哈……")]},
        {"note": "（召唤来的刷尾松鼠也爬了上来，蓬松的尾巴在两个人的腰上扫来扫去）", "lines": [
            (P, "尾、尾巴！毛茸茸的在腰上扫——哈哈哈哈！"), (BLUE, "……噗。……刚才是咳嗽。"),
            (P, "骗人哈哈哈！你明明笑了！"), (BOSS, "……这里……你……最……"),
            (N, "（一根手指在蓝色公主的大腿外侧画了个小圈——一圈，又一圈，不快也不慢）"),
            (BLUE, "……哈、哈哈……别、别画圈……这个节奏……"), (P, "节奏？什么节奏？哈哈哈你怎么知道它要画圈？"),
            (BLUE, "……不、不知道……哈……哈哈哈……"), (BOSS, "……一直……知道……")]},
        {"note": "（手指越来越多。粉色公主的脚心被刷子手来回刷，蓝色公主的屁股上落下了好几根轻飘飘的指尖）", "lines": [
            (P, "脚、脚心也——哈哈哈哈！不行不行不行！刷子来回刷——哈哈哈哈！"), (BLUE, "……哈哈……那里……那里不可以……哈哈哈……！"),
            (P, "噗哈哈哈……你、你原来最怕的是那里？"), (BLUE, "……忘、忘掉……哈哈哈……全部忘掉……！"),
            (BOSS, "……忘……不了……"), (BLUE, "……哈哈哈……你、你还记得……哈哈……！"),
            (P, "记得什么啦哈哈哈！你们认识吗？！"), (BLUE, "……没、没有……哈哈哈哈……！")]},
        {"note": "（两个人笑得喘不过气，千手却一点也没有停下的意思）", "lines": [
            (P, "哈、哈……数、数不清了……到底有几只手……"), (BLUE, "……哈哈……一千……只……哈哈哈……"),
            (BOSS, "……再……一起……"), (P, "不、不要一起了——哈哈哈哈哈！"),
            (BLUE, "……对不起……是我……带你来的……哈……"), (P, "笨蛋……哈哈……是我自己跑来的……"),
            (P, "不过……等出去了……你得告诉我……它为什么那么懂你……"), (BLUE, "……哈……不告诉你。"),
            (N, "（手指终于慢了下来。两个人软软地挂在半空，连笑声都只剩下喘气）"),
            (P, "……下次……一定……打赢……"), (BLUE, "……嗯。")]},
    ]),
    (1, 2): ("千手之间·战败（阶段一·又一次）", "（又被抓住了。这一次，千手先把两个人的鞋子脱了下来）", [
        {"note": "（松软的刷毛先落在脚心——从脚跟慢慢刷到脚趾）", "emo": {BLUE: "normal"}, "lines": [
            (BOSS, "……又……来了……"), (P, "鞋、鞋子还我——呀哈哈！刷、刷脚心！"),
            (BLUE, "……脚心……没什么。……我不怕。"), (P, "真、真的假的？哈哈哈……那我岂不是很吃亏！"),
            (BOSS, "……脚……不怕……知道……"),
            (N, "（刷子手在蓝色公主的脚心上只刷了一下，就像确认过什么一样，收了回去）"),
            (BLUE, "……？", "surprise"), (P, "它、它怎么不刷你了？哈哈哈不公平！")]},
        {"note": "（收回去的刷子手绕了一圈，停在了蓝色公主的大腿后面）", "lines": [
            (BLUE, "……！……等、等一下……", "surprise"), (BOSS, "……这里……"),
            (BLUE, "……唔……唔嗯……哈、哈……从、从后面……不行……"), (P, "噗——哈哈哈！你刚才那声是什么！"),
            (BLUE, "……没、没出声……哈哈……"), (P, "腰——腰也来了哈哈哈！我、我的腰——！"),
            (N, "（手指在粉色公主的腰两边一按一放，像弹琴一样）"), (P, "别弹啦哈哈哈！我又不是琴！")]},
        {"note": "（更多的手伸了过来。刷子顺着蓝色公主的大腿往上，羽毛停在她的屁股上轻轻打转）", "lines": [
            (BLUE, "……哈哈……哈哈哈……屁、屁股……不行……那、那里不行……！"), (P, "哈哈哈……原、原来你也会这样笑啊……"),
            (BOSS, "……笑……像……以前……"), (P, "以前？以前是什么时候？哈哈哈哈——"),
            (BLUE, "……哈哈哈……别、别学以前……以前你……会停下来的……"), (BOSS, "……不……停……"),
            (P, "你们果然认识吧？！哈哈哈……我、我好好奇……可是好痒——！"), (BLUE, "……哈哈哈哈……不、不认识……哈哈哈……！")]},
        {"note": "（手指一根接一根地落下，笑声在大厅里回荡）", "lines": [
            (P, "哈……哈……你、你刚才说……「以前」……"), (BLUE, "……哈哈……别、别问……"),
            (BOSS, "……记得……你……笑起来……"), (BLUE, "……！……哈哈哈……别、别说了……"),
            (P, "它好像……很喜欢你……哈哈哈……喜欢到连你哪里怕痒都记得……"), (BLUE, "……那是……以前……哈……"),
            (N, "（千手的手指停在蓝色公主的大腿上，迟迟没有落下——过了好久，才又轻轻挠了一下）"),
            (BLUE, "……哈……够了……"), (P, "……我们……再来……")]},
    ]),
    (2, 1): ("千手之间·战败（阶段二）", "（锁链没能拉下它。两个人被手臂按倒在花瓣堆里）", [
        {"note": "（手臂把两个人放倒在地上，脚踝上缠着紫色的手）", "emo": {BLUE: "shy"}, "lines": [
            (BOSS, "……下来……陪我……"), (P, "地、地上全是花瓣……哈哈……还、还有刺猬！"),
            (BLUE, "……板子……没、没站稳……"), (P, "刺猬在脚边蹭——呀哈哈！软刺扎扎的！"),
            (BOSS, "……地上……都是……我的……"), (BLUE, "……别慌。……挣开就……唔。"),
            (N, "（一只手握住蓝色公主的脚踝，把她的腿轻轻抬了起来）"), (BLUE, "……放、放下。……腿……放下……", "helpless_1")]},
        {"note": "（刺猬们一拥而上，手臂按住两个人的手腕，刷子和手指同时落下）", "cg": "boss8_p2", "lines": [
            (P, "哈哈哈哈！刷子手！刷子手在刷脚心哈哈哈哈！"), (P, "刺、刺猬在腿上滚来滚去——哈哈哈好扎！"),
            (BLUE, "……哈、哈哈……大腿……别刷大腿……"), (BOSS, "……你……最怕……这里……"),
            (BLUE, "……！……哈哈哈……为、为什么还记得……哈哈哈哈……"), (P, "哈哈哈！它、它到底是谁啊——！"),
            (BLUE, "……哈哈……别、别问……哈哈哈……"),
            (N, "（手指沿着大腿内侧一点一点地往上爬，在快到裙摆的地方又退了回来，再爬一遍）"),
            (BLUE, "哈哈哈……！别、别反复……那样……更……哈哈哈哈！", "helpless_2")]},
        {"note": "（另一只手绕到身后。刷子在屁股上轻轻打圈，越转越快）", "cg": "boss8_p2", "lines": [
            (BLUE, "哈哈哈哈哈……！不、不行……那里……真的不行……！"), (P, "哈哈……你、你笑得比我还大声……"),
            (P, "喂……千手！你是不是专门挑她怕的地方？哈哈哈……我也很痒啊！"), (BOSS, "……她……先……"),
            (P, "偏心！哈哈哈——偏心鬼！"),
            (BLUE, "……哈哈哈……你、你还记得……我、我只要被这样……就……哈哈哈哈……！"),
            (P, "被这样就怎样？！哈哈哈话说一半最讨厌了！")]},
        {"note": "（锁链在头顶晃荡。两个人被翻来覆去地挠，眼角全是笑出来的泪）", "lines": [
            (P, "锁、锁链……刚才明明差一点……哈哈……"), (BLUE, "……板子……要一起踩……"),
            (BOSS, "……不……放……"), (P, "哈哈哈哈！投降！投降了哈哈哈哈！"),
            (BLUE, "哈哈哈哈……停、停下……我不想……这样见到你……"), (P, "「这样」？那你想怎样见它啊……哈哈……"),
            (BLUE, "……哈……不、不知道……"),
            (N, "（锁链叮当作响，两个人在花瓣里滚来滚去，直到笑得没有一点力气）"),
            (P, "……下次……我先去踩……"), (BLUE, "……我守另一块。")]},
    ]),
    (2, 2): ("千手之间·战败（阶段二·又一次）", "（又一次。地面变成了泥沼，两个人陷在里面动不了）", [
        {"note": "（泥沼里冒出一个又一个小气泡，每一个都在脚心上啵地炸开）", "emo": {BLUE: "normal"}, "lines": [
            (BOSS, "……陷……进去……"), (P, "泥、泥沼里还有泡泡——哈哈哈！脚心一直被啵啵啵！"),
            (BLUE, "……动、动不了……"), (BLUE, "……泡泡……没、没什么……"),
            (BOSS, "……泡泡……不够……"),
            (N, "（泥里伸出了手。冰凉的手指扣住了蓝色公主的膝盖内侧）"),
            (BLUE, "……唔……！", "helpless_1"), (P, "你又抖了！哈哈哈我都看到了！")]},
        {"note": "（传送带从泥里升起来，把两个人往手臂底下送）", "lines": [
            (P, "传、传送带！它、它在送我们过去——哈哈哈不要啊！"), (P, "腋下和脚心一起——哈哈哈哈！"),
            (BLUE, "……哈、哈……膝盖……往、往上……不行……"), (BOSS, "……这样……就……不会……走了……"),
            (BLUE, "……哈哈……走、走了的人……是我……"), (P, "你说什么？哈哈哈我听不清——！"),
            (BLUE, "……没、没什么……哈哈哈……")]},
        {"note": "（手指从膝盖慢慢爬到大腿，再绕到后面，在屁股上停下，一下、一下地点）", "lines": [
            (BLUE, "哈哈哈哈……！屁股……屁股不、不行……一下一下的……更、更不行……！"), (BOSS, "……以前……也是……这样……"),
            (BLUE, "……哈哈哈……以、以前……不是这样的……哈哈哈……"), (P, "以前到底怎样啦哈哈哈！"),
            (BLUE, "……哈、哈哈……以前……你……会停下来的……"), (BOSS, "……不……停……"),
            (P, "哈哈哈哈哈！完、完了哈哈哈！"), (BLUE, "……哈哈哈……对不起……是我……没回来……")]},
        {"note": "（泥沼慢慢变暖，手指却一刻也没有停）", "lines": [
            (P, "回、回来什么——哈哈哈哈！你、你到底瞒着我什么！"), (P, "泥、泥巴里……也有手……哈哈哈……"),
            (BLUE, "……哈哈……往、往下拉……"), (BOSS, "……留……下……"),
            (BLUE, "……哈哈哈……不能……留下……"), (P, "对、对啊……我们要出去……哈哈哈哈！"),
            (BOSS, "……出去……也……带上……我……"), (BLUE, "……！……", "sad"),
            (N, "（蓝色公主没有回答。泥沼慢慢合拢，只剩下两个人沙哑的笑声）"), (P, "……再来一次……")]},
    ]),
    (3, 1): ("千手之间·战败（阶段三）", "（光圈里的那个撑不住了。另一个也被手臂吊了起来——然后，两个人一起被放倒在紫色的手掌上）", [
        {"note": "（紫色的手臂像丝带一样缠住两个人的手腕和脚踝，把她们并排放倒）", "cg": "boss8_duo_1", "lines": [
            (BOSS, "……都……上来……了……"), (P, "好、好多手……像丝带一样……缠、缠在腿上了！"),
            (BLUE, "……靠、靠过来一点。……别怕。"), (P, "你、你自己声音都在抖哈哈……"),
            (N, "（手指先落在两个人的脖子上——轻轻一挠，又收回去，像在打招呼）"),
            (P, "呀哈哈！脖、脖子！痒痒痒——！"), (BLUE, "……噗。……脖子……还好。"),
            (BOSS, "……还好……知道……"), (BLUE, "……你……别「知道」了。")]},
        {"note": "（手指开始认真起来：粉色公主的腋下被一阵快挠，蓝色公主的大腿被羽毛慢慢地扫）", "cg": "boss8_duo_2", "lines": [
            (P, "腋、腋下——哈哈哈哈！好快好快好快！"), (BLUE, "……哈、哈……慢的……比快的……更……哈哈……"),
            (P, "你、你还有空分析快慢——哈哈哈哈！"), (BOSS, "……慢……你……喜欢……"),
            (BLUE, "……才、才不喜欢……哈哈哈……"), (P, "你们到底什么关系啦哈哈哈！连你喜欢快的还是慢的都知道！"),
            (BLUE, "……哈哈……什么……关系都……没有……哈哈哈哈……"), (BOSS, "……骗……人……"),
            (P, "它说你骗人哈哈哈哈！")]},
        {"note": "（手臂越来越多，铺满了整个视野。数不清的指尖同时落在两个人的腰、脚心、大腿和屁股上）", "cg": "boss8_duo_3", "lines": [
            (P, "哈哈哈哈哈！全、全部一起——不行了不行了——！"), (BLUE, "哈哈哈哈……！大、大腿……屁股……一起……哈哈哈哈哈……！"),
            (P, "你、你终于笑出来了……哈哈哈……笑得好大声……"),
            (BLUE, "……哈哈哈……别、别看……！你、你还记得……我、我一被挠屁股就……哈哈哈哈！"),
            (BOSS, "……记得……全部……"), (P, "就怎样？！哈哈哈……又是话说一半！"),
            (BLUE, "……哈哈哈……就、就会……笑到……停不下来……哈哈哈哈……！"), (P, "那、那不就是现在嘛哈哈哈哈！")]},
        {"note": "（红色的光一明一暗，像心跳。两个人的笑声越来越哑）", "lines": [
            (BOSS, "……不……放……永远……"), (P, "永、永远不行啦哈哈哈哈！"),
            (BLUE, "……哈哈哈……我……回来了……哈哈……可是……"), (P, "可是什么——哈哈哈哈！"),
            (BLUE, "……哈哈……可是……我不能留下……哈哈哈哈……"), (BOSS, "……彼……此……"),
            (N, "（千手的手臂一下子僵住了，像是想起了什么——然后又更用力地挠了起来）"),
            (P, "……哈……下次……换人要快……"), (BLUE, "……嗯……我撑得住。")]},
    ]),
    (3, 2): ("千手之间·战败（阶段三·她一个人）", "（粉色公主被几只手按在一边。千手的大半只手臂，全都朝蓝色公主伸了过去）", [
        {"note": "（手指从四面八方伸过来，蓝色公主咬着嘴唇，一动不动）", "cg": "boss8_resist_1",
         "emo": {P: "helpless_1", BLUE: "angry"}, "lines": [
            (BOSS, "……这次……只……你……"), (BLUE, "……来吧。……我不会笑的。"),
            (P, "喂！别、别只挠她——哈哈……我、我这边也有两只手啊！"),
            (N, "（手指落在蓝色公主的腋下、腰两侧，一根一根地挠）"),
            (BLUE, "……嗯。"), (BLUE, "……不痒。……这种程度。"),
            (P, "好、好厉害……她真的忍住了……哈哈……我这边才两只手就……"), (BOSS, "……忍……一直……这样……"),
            (BLUE, "……一直？……你又知道了。")]},
        {"note": "（手指加快了。脚心、膝盖、手肘——蓝色公主的肩膀开始一抽一抽）", "cg": "boss8_resist_2",
         "emo": {P: "helpless_1", BLUE: "shy"}, "lines": [
            (BLUE, "……唔……嗯唔……"), (BLUE, "……刚才……是咳嗽……"),
            (P, "哈哈……咳嗽会咳得肩膀一抖一抖的吗？"), (BOSS, "……还……不……是……这里……"),
            (BLUE, "……「还不是」……？……你……想做什么……"),
            (N, "（所有的手忽然一起停了下来。大厅里安静得只能听见呼吸声）"),
            (BLUE, "……？", "surprise"), (P, "停、停了？……不对……这个安静……好可怕……")]},
        {"note": "（一只手握住蓝色公主的脚踝，把她的腿轻轻抬高——指尖落在了大腿内侧）", "cg": "boss8_weak_1",
         "emo": {P: "helpless_1"}, "lines": [
            (BLUE, "……！……哈……哈哈……等、等一下……那里……"), (BOSS, "……这里……"),
            (BLUE, "哈哈哈……！不、不对……你、你怎么……偏偏……哈哈哈哈！"),
            (N, "（指尖顺着大腿慢慢画圈，每画一圈，就往上挪一点）"),
            (BLUE, "哈哈哈哈……！别、别画圈……这个……这个是……哈哈哈哈……！"),
            (P, "破、破功了！忍了那么久，一碰大腿就——哈哈哈！"),
            (BLUE, "……你、你还记得……哈哈……这个画法……哈哈哈哈……！"), (P, "「这个画法」？！你们以前到底在干嘛啊？！")]},
        {"note": "（另一只手绕到身后，刷子在屁股上轻轻地、一下一下地扫——和大腿上的手指配合着同一个节奏）", "cg": "boss8_weak_2",
         "emo": {P: "helpless_1"}, "lines": [
            (BLUE, "哈哈哈哈哈……！屁、屁股也……一起……不、不行……真的不行……哈哈哈哈！"), (BOSS, "……一起……你……最……"),
            (BLUE, "哈哈哈……别、别说出来……！别说……哈哈哈哈哈……！"), (P, "哈哈……你、你笑成这样……我、我都看呆了……"),
            (P, "它对你的弱点……熟到吓人……你们……该不会是……"), (BLUE, "……哈哈哈……不、不是……你想的那样……哈哈哈哈……！"),
            (BOSS, "……那……是……哪样……"), (BLUE, "……哈哈哈……都、都说了……别问……哈哈哈哈……！"),
            (N, "（蓝色公主笑到眼泪都出来了，紫色的手却还在慢悠悠地，用同一个节奏画着圈）"),
            (P, "……下次……我来引开它……"), (BLUE, "……哈……哈……拜托了……")]},
    ]),
    (3, 3): ("千手之间·战败（阶段三·小怪们）", "（千手抬起手臂一挥，召唤来的小怪们从四面八方涌了过来）", [
        {"note": "（刷刷刺猬排成一排，在蓝色公主脚边转来转去）", "emo": {BLUE: "normal"}, "lines": [
            (BOSS, "……大家……一起……"), (P, "好、好多刺猬！还有松鼠！它、它们都往你那边跑了！"),
            (BLUE, "……小东西。……一下就踢开。"), (N, "（刺猬软软的刺在她脚心上滚了一圈）"),
            (BLUE, "……脚心。……不痒。"), (P, "你脚心不怕痒？太、太狡猾了吧！"),
            (BOSS, "……脚……不……要……"), (N, "（刺猬们好像听懂了，转了个方向，爬上了她的小腿）"),
            (BLUE, "……喂。……往哪爬。", "surprise")]},
        {"note": "（刺猬滚上大腿，松鼠的尾巴扫过腰，千手的手按住她的手腕——小怪们一拥而上）", "cg": "boss8_mob", "lines": [
            (BLUE, "……唔、嗯……刺、刺猬……在大腿上……滚……"), (P, "哈哈……刺猬滚大腿！听起来就好痒！"),
            (BLUE, "……哈……哈哈……一、一只还好……三、三只……哈哈哈……！"), (BOSS, "……再……来……"),
            (N, "（又有两只刺猬爬了上来，挤在她的大腿两边，一起慢慢地滚）"),
            (BLUE, "哈哈哈……！别挤……别一起滚……哈哈哈哈……！", "helpless_2"),
            (P, "你、你笑出来了！哈哈哈……我这边也有松鼠……尾巴扫腰——哈哈哈！")]},
        {"note": "（松鼠们钻到了她身后，蓬松的尾巴在屁股上扫来扫去）", "cg": "boss8_mob", "lines": [
            (BLUE, "哈哈哈哈哈……！尾、尾巴……屁股……那里不行……哈哈哈哈！"), (BOSS, "……教……过……它们……"),
            (P, "教、教过？！你还专门教小怪挠她哪里？！哈哈哈哈……"),
            (BLUE, "……哈哈哈……你、你还记得……我、我说过的……哈哈哈哈……！"), (P, "说过什么？什么时候说的？！"),
            (BLUE, "……哈哈……很、很久以前……哈哈哈……忘、忘了吧……！"), (BOSS, "……忘……不了……")]},
        {"note": "（小怪们越挤越多，蓝色公主被埋在毛茸茸的尾巴和软刺里，只剩笑声传出来）", "lines": [
            (P, "哈……哈……你、你还活着吗……"), (BLUE, "……哈哈……毛……毛茸茸的……全、全是……哈哈哈……"),
            (BOSS, "……开心……吗……"), (BLUE, "……哈哈……才、才不……开心……"),
            (P, "骗人……你刚才笑得……好像有一点开心……"), (BLUE, "……哈……闭嘴……"),
            (N, "（千手低下头，手臂轻轻摸了摸蓝色公主的头发，然后挥了挥手——小怪们又一次涌了上去）"),
            (BLUE, "哈哈哈哈……！又、又来……！"), (P, "……下次……先清小怪……")]},
    ]),
}
# 每段剧场结尾的魔力疲倦爆发（各不相同）：两人满了 → 爆发 → 舒服 → 千手回来 → 更敏感、笑得更大声；
# 蓝色公主嘴硬（「才没有觉得舒服」）下一句就笑崩，千手夸她，粉色公主吐槽。
BURSTS = {
    (1, 1): [(BLUE, "……魔、魔力……满了……压、压不住……"), (P, "我、我也是……身体里好烫……要、要出来了——！"),
             (BLUE, "……哈……全部……放出去了……嗯……"), (P, "呼……好、好舒服……"), (BOSS, "……回……来……了……"),
             (P, "呀哈哈哈哈！刚、刚放完……碰哪里都痒——！"), (BLUE, "哈哈哈哈哈……！才、才没有……觉得舒服……哈哈哈哈……！"),
             (BOSS, "……这样……好……笑起来……很……可爱……"), (BLUE, "……！闭、闭嘴……哈哈哈……不准夸……哈哈哈哈！"),
             (P, "你、你脸红了！哈哈哈……原来你也会这样！"), (N, "（两个人的笑声比刚才大了一倍，在千手之间里回荡了好久）")],
    (1, 2): [(P, "魔、魔力条……满了……！"), (BLUE, "……我也……唔……要、要溢出来了……"),
             (P, "哈……好、好舒服……"), (BLUE, "……嗯。……还、还可以。"), (BOSS, "……再……来……"),
             (BLUE, "哈哈哈哈……！放、放完再挠……犯规……大腿……哈哈哈哈！"), (P, "哈哈哈哈！它、它专门等我们放完才挠的吧——！"),
             (BOSS, "……你……这样……最……好看……"), (BLUE, "……哈哈……谁、谁要你说好看……哈哈哈哈哈……！"),
             (P, "「还可以」呢？刚才不是说「还可以」吗哈哈哈！")],
    (2, 1): [(BLUE, "……花、花瓣里……魔力……满了……"), (P, "我、我也……刺猬再蹭一下就……呀——！"),
             (P, "……啊……花瓣全飞起来了……好舒服……"), (BLUE, "……嗯……身体……轻轻的……"), (BOSS, "……刺猬……回来……"),
             (P, "哈哈哈哈！回、回来了！刚放完的脚心——哈哈哈不行！"),
             (BLUE, "哈哈哈……！才、才不是舒服……是、是魔力的关系……哈哈哈哈哈！"), (BOSS, "……嘴硬……也……可爱……"),
             (BLUE, "……！……哈哈哈哈……别、别说可爱……！"), (P, "它说得对……你嘴硬的样子好可爱哈哈哈！")],
    (2, 2): [(P, "泥、泥巴里……魔力……满到喉咙了……"), (BLUE, "……我……也……忍、忍不住……"),
             (BLUE, "……哈……泥沼……被冲开了……"), (P, "呼……好、好舒服……"), (BOSS, "……没……用……"),
             (P, "哈哈哈哈！手、手又从泥里伸出来了——！"), (BLUE, "哈哈哈哈哈……！屁、屁股……刚放完……不行……哈哈哈哈！"),
             (BOSS, "……笑……大声……一点……好……"), (BLUE, "……哈哈哈……才、才不会……照你说的……哈哈哈哈哈哈！"),
             (P, "你、你明明笑得更大声了啦哈哈哈！")],
    (3, 1): [(P, "……魔、魔力……要满了……"), (BLUE, "……一起……要、要一起爆了……"),
             (P, "……哈……手、手都被弹开了……"), (BLUE, "……嗯……舒、舒服……"), (BOSS, "……没……关系……再……来……"),
             (P, "哈哈哈哈哈！全、全部又回来了！数、数不清——！"), (BLUE, "哈哈哈哈……！刚、刚才说舒服的……不算……哈哈哈哈哈！"),
             (BOSS, "……算……很……可爱……"), (BLUE, "……哈哈哈……可、可爱也不算……哈哈哈哈！"), (P, "哈哈哈……它记得比你还清楚呢！")],
    (3, 2): [(BLUE, "……魔、魔力……满了……忍、忍不住了……"), (P, "哈、哈……我这边……也……满了……！"),
             (BLUE, "……哈……嗯……身、身体……软了……"), (P, "你、你的表情……好舒服的样子……"), (BOSS, "……再……画……圈……"),
             (BLUE, "哈哈哈哈哈……！放、放完了还画……大腿……更、更痒了……哈哈哈哈！"),
             (BLUE, "……才、才没有……喜欢……这样……哈哈哈哈哈哈！"), (BOSS, "……没……变……还是……这样……好……"),
             (BLUE, "……哈哈……「还是」什么……别、别说下去……哈哈哈哈！"), (P, "你、你们果然……哈哈哈……我、我不问了……先笑完再说……")],
    (3, 3): [(BLUE, "……毛、毛茸茸的……魔力……满了……"), (P, "我、我这边松鼠也……要、要爆了——！"),
             (P, "……哈……小怪全被吹飞了……"), (BLUE, "……嗯……舒、舒服……一点点……"), (BOSS, "……大家……回来……"),
             (BLUE, "哈哈哈哈……！回、回来了……一起滚……哈哈哈哈哈！"), (P, "哈哈哈哈！我这边的尾巴也——刚放完不行啦！"),
             (BOSS, "……笑……这样……好……乖……"), (BLUE, "……哈哈……谁、谁乖了……哈哈哈哈哈……！"),
             (P, "「一点点」舒服？我都听到你哼了一声哈哈哈！")],
    "chase": [(P, "魔、魔力……要满了……巨石还在后面……！"), (BLUE, "……我……也……一起……"),
              (P, "……哈……石、石头缝里的手……被弹开了……"), (BLUE, "……嗯……舒服……"), (BOSS, "……别……走……"),
              (P, "哈哈哈哈！又、又抓住脚了！刚放完——哈哈哈哈！"), (BLUE, "哈哈哈……！不、不是舒服……是累了……哈哈哈哈哈！"),
              (BOSS, "……累……也……可爱……"), (BLUE, "……哈哈哈……都、都说了别夸……哈哈哈哈！"), (P, "跑、跑之前……先笑完……哈哈哈……")],
}
# 阶段三第 4 段（第 4 次起每次都播）：两个人被叠在一起，上面的蓝色公主被专挠大腿和屁股、下面的粉色公主被专挠脚心；
# 中间、结尾各爆发一次。只用立绘（没有大图）。蓝色公主傲娇到破防，粉色公主天然呆吐槽。
STACK = ("千手之间·战败（阶段三·叠在一起）", "（千手的手臂一抬，小怪们把两个人推到一起——蓝色公主被压在上面，粉色公主垫在下面）", [
    {"note": "（两个人被手臂叠在一起，绑得紧紧的。上面那个的大腿和屁股朝着外面，下面那个的脚心朝着天）", "emo": {BLUE: "angry", P: "surprise"},
     "lines": [
        (BOSS, "……叠……起来……"), (P, "重、重死了！你、你压到我了！"), (BLUE, "……是它们推的。……不是我。"),
        (P, "我们现在……像不像叠起来的点心……哈哈……"), (BLUE, "……这种时候……别说傻话。"),
        (N, "（刷刷刺猬爬上来，刷毛贴着蓝色公主的大腿；另一只羽毛手，停在粉色公主朝天的脚心上）"),
        (BLUE, "……唔。……不痒。", "shy"), (P, "脚、脚心——呀哈哈哈！痒痒痒！", "helpless_1"),
        (BLUE, "……别、别乱动……你一笑……我也跟着晃……", "helpless_1")]},
    {"note": "（刷子在大腿上来回、羽毛在脚心上画圈——两边的节奏一模一样）", "lines": [
        (P, "哈哈哈哈！羽、羽毛在脚心画圈——不行不行！"), (BLUE, "……嗯、嗯唔……大、大腿……刷、刷子……别……"),
        (BOSS, "……你……最怕……这里……她……最怕……那里……"), (P, "它、它连我怕脚心都知道？！哈哈哈……你们到底交流了什么啊！"),
        (BLUE, "……没、没交流……哈、哈哈……"), (N, "（松鼠们钻到了上面，蓬松的尾巴一下一下扫过蓝色公主的屁股）"),
        (BLUE, "……！……哈哈……哈哈哈……屁、屁股……不、不行……"), (P, "上面笑得在抖——我、我在下面也跟着抖哈哈哈哈！")]},
    {"burst": [(BLUE, "……魔、魔力……满了……"), (P, "我、我也是……一、一起……！"),
               (BLUE, "……哈……嗯……身体……好轻……"), (P, "……呼……好舒服……"), (BOSS, "……第……一……次……"),
               (BLUE, "……刚、刚才那个不算……我、我还能忍……", "angry"), (BOSS, "……那……再……来……"),
               (BLUE, "哈哈哈哈……！放、放完再刷大腿……更、更……哈哈哈哈哈！"), (P, "你、你自己说还能忍的哈哈哈哈！"),
               (N, "（刚放完魔力的身体敏感得不得了，两个人一起笑得直抖）")]},
    {"note": "（手指、刷子、尾巴越来越多。魔力条又在一点一点涨上去）", "lines": [
        (P, "脚、脚心……刷子和羽毛轮流……哈哈哈哈哈！"), (BLUE, "哈哈哈……大腿……屁股……一起……不、不准一起……哈哈哈哈！"),
        (BOSS, "……你……小时候……也……这样……说……"), (BLUE, "……！……哈哈哈哈……那、那个不准说……哈哈哈……！"),
        (P, "小时候？！哈哈哈……你、你小时候也被这样挠过？！"), (BLUE, "……没、没有……哈哈哈哈……忘、忘掉……！"),
        (P, "我、我记住了哈哈哈……出去以后要问清楚！"), (BOSS, "……又……要……满……了……")]},
    {"note": "（第二次了。两个人的魔力条一起闪着光，刷子和羽毛一刻也没有停）", "lines": [
        (P, "又、又要满了……好、好快……哈哈哈……"), (BLUE, "……这、这次……一定……忍住……"),
        (BOSS, "……忍……不住……的……"), (BLUE, "……哈……哈哈……别、别看着我……")]},
    {"burst": [(BLUE, "……又、又满了……不、不行……这次……压不住……"), (P, "我、我也……第二次了……呜哇——！"),
               (BLUE, "……哈……哈……全、全部……没了……"), (P, "……软、软软的……像云……"), (BOSS, "……现在……最……敏感……"),
               (BLUE, "哈哈哈哈哈哈……！不、不行……全、全身都……哈哈哈哈哈哈哈！"),
               (BLUE, "……我、我投降……哈哈哈……我承认……很、很痒……哈哈哈哈哈！"), (BOSS, "……这样……的……你……最……好……"),
               (P, "哈哈哈……她、她终于说投降了！我、我要记下来！"), (BLUE, "……哈哈……不、不准记……哈哈哈哈……！"),
               (N, "（两个人叠在一起，笑声一个比一个大，一直笑到再也发不出声音）")]},
])
STACK_AT = {"pink": [0, 16], "blue": [0, 6]}
DEFEAT_VARIANTS = {1: 2, 2: 2, 3: 4}
TH = Path("data/theater/floor_08")
TH.mkdir(parents=True, exist_ok=True)
for (ph, k), (name, intro, acts) in DEFEAT.items():
    (TH / ("f8_defeat_%d_%d.json" % (ph, k))).write_text(json.dumps(theater(name, intro, acts + [{"burst": BURSTS[(ph, k)]}], mob=(ph, k) == (3, 3)),
                                                                   ensure_ascii=False, indent="\t") + "\n")
(TH / "f8_defeat_3_4.json").write_text(json.dumps(theater(STACK[0], STACK[1], STACK[2], mob=True, cast_at=STACK_AT), ensure_ascii=False, indent="\t") + "\n")
CHASE_FAIL = ("崩塌的回廊·没逃掉", "（巨石堵住了路。千手的残臂从碎石缝里伸了出来）", [
    {"note": "（碎石缝里伸出的手越来越多，抓住了两个人的脚踝）", "emo": {BLUE: "surprise", P: "surprise"}, "lines": [
        (P, "路、路被堵住了——！"), (BOSS, "……别……走……"), (BLUE, "……它……还没放弃……"),
        (P, "手、手从石头缝里伸出来了——呀！抓、抓住脚了！"), (BLUE, "……踢开。……用力。", "angry"),
        (N, "（手指没有放开，反而在脚踝上轻轻挠了一下）"), (P, "哈哈！脚、脚踝！不要在这种时候挠——！", "helpless_1")]},
    {"note": "（两个人被拖倒在碎石上，滚作一团。手指趁机钻进了裙摆底下）", "cg": "boss8_chase", "lines": [
        (P, "哈哈哈！脚、脚被抓着跑不了哈哈哈！"), (BLUE, "……唔……哈……大腿……被、被抓住了……"),
        (BOSS, "……留……下……"), (BLUE, "……哈、哈哈……都、都这种时候了……还挠大腿……哈哈……"),
        (P, "它、它是不是只会挠你大腿？哈哈哈……"), (BLUE, "……哈哈……不、不是只会……是……哈哈哈……"),
        (P, "是什么啦！哈哈哈……又、又说一半！"), (BLUE, "……是……它知道……那里……最……哈哈哈哈……！"),
        (N, "（指尖顺着大腿外侧一路往上挠，又在膝盖窝打了个转，一点也不急）")]},
    {"note": "（巨石在背后轰隆作响，可手指一点也不着急——一根挠着粉色公主的腰，一根在蓝色公主的屁股上打圈）", "cg": "boss8_chase", "lines": [
        (P, "哈哈哈哈！腰、腰——巨石要来了啦哈哈哈！"), (BLUE, "哈哈哈……屁、屁股……别打圈……哈哈哈哈……！"),
        (P, "你、你都快被压扁了还在笑——哈哈哈！"),
        (BLUE, "……哈哈……你、你还记得……那时候……也是在逃跑的路上……哈哈哈……"),
        (P, "那时候？！逃跑？！你们以前到底经历了什么啦哈哈哈！"), (BOSS, "……一起……跑……过……"),
        (P, "一、一起跑过？！哈哈哈……我越来越好奇了……可是好痒——！"),
        (BLUE, "……哈哈……别好奇了……先、先跑……哈哈哈……！")]},
    {"note": "（两个人靠在一起，笑得一点力气都没有了）", "lines": [
        (P, "两个人……要跑在一起才行……哈哈哈！"), (BLUE, "……哈哈……下次……别离我太远……"),
        (P, "巨、巨石……还在后面……哈哈哈……"), (BLUE, "……对不起。……我们要走。", "sad"),
        (P, "哈哈哈……用、用力——挣开了！"), (N, "（两个人互相拉着，从碎石里爬了出来）"),
        (P, "……再跑一次！这次跑在一起！"), (BLUE, "……嗯。……再来。", "normal")]},
])
(TH / "f8_chase_fail.json").write_text(json.dumps(theater(CHASE_FAIL[0], CHASE_FAIL[1], CHASE_FAIL[2] + [{"burst": BURSTS["chase"]}]),
                                                 ensure_ascii=False, indent="\t") + "\n")
print("第八层：%d 段过场、%d 段战败小剧场 + 追逐失败" % (len(CUTS), len(DEFEAT) + 1))
