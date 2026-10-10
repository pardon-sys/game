"""生成第八层「千手之间」：Boss 房（levels/floor_08）、巨石追逐（levels/floor_08_chase）、过场、战败小剧场、石碑。

floor_08（36x34）：下面是入口走廊（存档点，本层唯一），上面是 30x18 的 Boss 房（千手痒痒魔盘在上沿）。
  到达点（spawn id=…，Floor8Director 用）：boss、pink、circle、plate_a1/a2/b1/b2/c1/c2、summon1~4、limb1~4、
  blue_fight、pink_fight、arena_tl、arena_br。入口的门（gate group=f8_gate）开战时关上。
floor_08_chase：一间底板小屋，无限滚动的跑道由 ChaseRun 自己画。
过场 data/cutscenes/floor_08/：f8_intro_a / f8_intro_b（开场）、f8_phase2 / f8_phase3（阶段切换）、f8_victory_a / f8_victory_b（胜利）、f8_ending（逃出来）。
小剧场 data/theater/floor_08/：f8_defeat_<阶段>_<n>（阶段一、二各两段按战败次数轮流；阶段三 1→2→3→4，之后一直是第 4 段「叠在一起」；
BOSS_CG 的大图按幕换上；每段结尾都有两个人魔力疲倦爆发的一幕）、f8_chase_fail。
蓝色公主的台词：她和千手是旧识，带着惋惜和自责，但从不说出它是谁。
小房间 floor_08_shelter：追逐逃出来后过夜（开场过场 f8_shelter_intro、调查对话 shelter_objects、窗边的蓝色公主 shelter_blue）。
用法：python tools/build/gen_floor08.py，然后 build_level.gd -- floor=floor_08、floor=floor_08_chase、floor=floor_08_shelter
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
        line(BLUE, "……天快黑了。先找个地方躲一下。"),
        {"actions": [A("fade_out", time=0.8)], "wait": 0.9},
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
    # 爆发之后另一个公主的立绘（右边）：她自己的魔力疲倦爆发立绘（emotion = fatigue_burst，和组合演出里一样）
    for i, ln in enumerate(lines[2:]):
        if i < 2:
            acts = [A("bubble", who="blue" if ln[0] == BLUE else "pink", kind="shy")]
            emo = "fatigue_burst"
        elif i == 2:
            acts = [A("move", who="boss", to=list(boss_at), time=0.6), A("voice", state="giggle")] + both_tk(4, 0.3)
            if mob:
                acts += [A("move", who="m1", to=[40, 22], time=0.6), A("move", who="m2", to=[8, 24], time=0.6)]
            emo = "fatigue_burst"
        else:
            acts = [A("voice", state="laugh"), A("shake", who="blue", time=0.6), A("shake", who="pink", time=0.6),
                    pose("pink", "helpless_2"), pose("blue", "helpless_2")] + both_tk(10, 0.15, ["sole", "waist", "armpit"][i % 3],
                                                                                     ["thigh", "butt"][i % 2])
            emo = "fatigue_burst"
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
            (P, "哈哈……不过……等出去了……你得告诉我……它为什么那么懂你……哈哈……"), (BLUE, "……哈……不告诉你。"),
            (N, "（手指终于慢了下来。两个人软软地挂在半空，连笑声都只剩下喘气）"),
            (P, "……哈……哈……下次……一定……打赢……"), (BLUE, "……嗯。")]},
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
            (BLUE, "……哈……够了……"), (P, "……哈……哈……我们……再来……")]},
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
            (P, "哈……哈……下次……我先去踩……"), (BLUE, "……我守另一块。")]},
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
            (N, "（蓝色公主没有回答。泥沼慢慢合拢，只剩下两个人沙哑的笑声）"), (P, "……哈……哈……再来一次……")]},
    ]),
    (3, 1): ("千手之间·战败（阶段三）", "（光圈里的那个撑不住了。另一个也被手臂吊了起来——然后，两个人一起被放倒在紫色的手掌上）", [
        {"note": "（紫色的手臂像丝带一样缠住两个人的手腕和脚踝，把她们并排放倒）", "cg": "boss8_duo_1", "lines": [
            (BOSS, "……都……上来……了……"), (P, "好、好多手……像丝带一样……缠、缠在腿上了！哈、哈哈……好痒！"),
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
            (BLUE, "……？", "surprise"), (P, "哈……哈……停、停了？……不对……这个安静……好可怕……")]},
        {"note": "（一只手握住蓝色公主的脚踝，把她的腿轻轻抬高——指尖落在了大腿内侧）", "cg": "boss8_weak_1",
         "emo": {P: "helpless_1"}, "lines": [
            (BLUE, "……！……哈……哈哈……等、等一下……那里……"), (BOSS, "……这里……"),
            (BLUE, "哈哈哈……！不、不对……你、你怎么……偏偏……哈哈哈哈！"),
            (N, "（指尖顺着大腿慢慢画圈，每画一圈，就往上挪一点）"),
            (BLUE, "哈哈哈哈……！别、别画圈……这个……这个是……哈哈哈哈……！"),
            (P, "破、破功了！忍了那么久，一碰大腿就——哈哈哈！"),
            (BLUE, "……你、你还记得……哈哈……这个画法……哈哈哈哈……！"), (P, "哈哈……「这个画法」？！你、你们以前到底在干嘛啊哈哈哈！")]},
        {"note": "（另一只手绕到身后，刷子在屁股上轻轻地、一下一下地扫——和大腿上的手指配合着同一个节奏）", "cg": "boss8_weak_2",
         "emo": {P: "helpless_1"}, "lines": [
            (BLUE, "哈哈哈哈哈……！屁、屁股也……一起……不、不行……真的不行……哈哈哈哈！"), (BOSS, "……一起……你……最……"),
            (BLUE, "哈哈哈……别、别说出来……！别说……哈哈哈哈哈……！"), (P, "哈哈……你、你笑成这样……我、我都看呆了……"),
            (P, "哈哈……它对你的弱点……熟到吓人……你们……该不会是……哈哈哈……"), (BLUE, "……哈哈哈……不、不是……你想的那样……哈哈哈哈……！"),
            (BOSS, "……那……是……哪样……"), (BLUE, "……哈哈哈……都、都说了……别问……哈哈哈哈……！"),
            (N, "（蓝色公主笑到眼泪都出来了，紫色的手却还在慢悠悠地，用同一个节奏画着圈）"),
            (P, "……哈……哈……下次……我来引开它……"), (BLUE, "……哈……哈……拜托了……")]},
    ]),
    (3, 3): ("千手之间·战败（阶段三·小怪们）", "（千手抬起手臂一挥，召唤来的小怪们从四面八方涌了过来）", [
        {"note": "（刷刷刺猬排成一排，在蓝色公主脚边转来转去）", "emo": {BLUE: "normal"}, "lines": [
            (BOSS, "……大家……一起……"), (P, "哈哈……好、好多刺猬！还有松鼠！它、它们都往你那边跑了哈哈！"),
            (BLUE, "……小东西。……一下就踢开。"), (N, "（刺猬软软的刺在她脚心上滚了一圈）"),
            (BLUE, "……脚心。……不痒。"), (P, "哈哈哈……你脚心不怕痒？太、太狡猾了吧哈哈！"),
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
            (BLUE, "……哈哈哈……你、你还记得……我、我说过的……哈哈哈哈……！"), (P, "哈哈……说过什么？什么时候说的？！哈哈哈……"),
            (BLUE, "……哈哈……很、很久以前……哈哈哈……忘、忘了吧……！"), (BOSS, "……忘……不了……")]},
        {"note": "（小怪们越挤越多，蓝色公主被埋在毛茸茸的尾巴和软刺里，只剩笑声传出来）", "lines": [
            (P, "哈……哈……你、你还活着吗……"), (BLUE, "……哈哈……毛……毛茸茸的……全、全是……哈哈哈……"),
            (BOSS, "……开心……吗……"), (BLUE, "……哈哈……才、才不……开心……"),
            (P, "哈……骗人……你刚才笑得……好像有一点开心……哈哈……"), (BLUE, "……哈……闭嘴……"),
            (N, "（千手低下头，手臂轻轻摸了摸蓝色公主的头发，然后挥了挥手——小怪们又一次涌了上去）"),
            (BLUE, "哈哈哈哈……！又、又来……！"), (P, "……哈……哈……下次……先清小怪……")]},
    ]),
}
# 每段剧场结尾的魔力疲倦爆发（各不相同）：两人满了 → 爆发 → 舒服 → 千手回来 → 更敏感、笑得更大声；
# 蓝色公主嘴硬（「才没有觉得舒服」）下一句就笑崩，千手夸她，粉色公主吐槽。
BURSTS = {
    (1, 1): [(BLUE, "……魔、魔力……满了……压、压不住……"), (P, "哈哈……我、我也是……身体里好烫……要、要出来了——！"),
             (BLUE, "……哈……全部……放出去了……嗯……"), (P, "呼……哈……好、好舒服……"), (BOSS, "……回……来……了……"),
             (P, "呀哈哈哈哈！刚、刚放完……碰哪里都痒——！"), (BLUE, "哈哈哈哈哈……！才、才没有……觉得舒服……哈哈哈哈……！"),
             (BOSS, "……这样……好……笑起来……很……可爱……"), (BLUE, "……！闭、闭嘴……哈哈哈……不准夸……哈哈哈哈！"),
             (P, "你、你脸红了！哈哈哈……原来你也会这样！"), (N, "（两个人的笑声比刚才大了一倍，在千手之间里回荡了好久）")],
    (1, 2): [(P, "哈哈哈……魔、魔力条……满了……！"), (BLUE, "……我也……唔……要、要溢出来了……"),
             (P, "哈……好、好舒服……"), (BLUE, "……嗯。……还、还可以。"), (BOSS, "……再……来……"),
             (BLUE, "哈哈哈哈……！放、放完再挠……犯规……大腿……哈哈哈哈！"), (P, "哈哈哈哈！它、它专门等我们放完才挠的吧——！"),
             (BOSS, "……你……这样……最……好看……"), (BLUE, "……哈哈……谁、谁要你说好看……哈哈哈哈哈……！"),
             (P, "「还可以」呢？刚才不是说「还可以」吗哈哈哈！")],
    (2, 1): [(BLUE, "……花、花瓣里……魔力……满了……"), (P, "哈哈哈……我、我也……刺猬再蹭一下就……呀——！"),
             (P, "……哈……啊……花瓣全飞起来了……好舒服……"), (BLUE, "……嗯……身体……轻轻的……"), (BOSS, "……刺猬……回来……"),
             (P, "哈哈哈哈！回、回来了！刚放完的脚心——哈哈哈不行！"),
             (BLUE, "哈哈哈……！才、才不是舒服……是、是魔力的关系……哈哈哈哈哈！"), (BOSS, "……嘴硬……也……可爱……"),
             (BLUE, "……！……哈哈哈哈……别、别说可爱……！"), (P, "它说得对……你嘴硬的样子好可爱哈哈哈！")],
    (2, 2): [(P, "哈哈……泥、泥巴里……魔力……满到喉咙了……"), (BLUE, "……我……也……忍、忍不住……"),
             (BLUE, "……哈……泥沼……被冲开了……"), (P, "呼……哈……好、好舒服……"), (BOSS, "……没……用……"),
             (P, "哈哈哈哈！手、手又从泥里伸出来了——！"), (BLUE, "哈哈哈哈哈……！屁、屁股……刚放完……不行……哈哈哈哈！"),
             (BOSS, "……笑……大声……一点……好……"), (BLUE, "……哈哈哈……才、才不会……照你说的……哈哈哈哈哈哈！"),
             (P, "你、你明明笑得更大声了啦哈哈哈！")],
    (3, 1): [(P, "哈……哈哈……魔、魔力……要满了……"), (BLUE, "……一起……要、要一起爆了……"),
             (P, "……哈……手、手都被弹开了……"), (BLUE, "……嗯……舒、舒服……"), (BOSS, "……没……关系……再……来……"),
             (P, "哈哈哈哈哈！全、全部又回来了！数、数不清——！"), (BLUE, "哈哈哈哈……！刚、刚才说舒服的……不算……哈哈哈哈哈！"),
             (BOSS, "……算……很……可爱……"), (BLUE, "……哈哈哈……可、可爱也不算……哈哈哈哈！"), (P, "哈哈哈……它记得比你还清楚呢！")],
    (3, 2): [(BLUE, "……魔、魔力……满了……忍、忍不住了……"), (P, "哈、哈……我这边……也……满了……！"),
             (BLUE, "……哈……嗯……身、身体……软了……"), (P, "哈哈……你、你的表情……好舒服的样子……"), (BOSS, "……再……画……圈……"),
             (BLUE, "哈哈哈哈哈……！放、放完了还画……大腿……更、更痒了……哈哈哈哈！"),
             (BLUE, "……才、才没有……喜欢……这样……哈哈哈哈哈哈！"), (BOSS, "……没……变……还是……这样……好……"),
             (BLUE, "……哈哈……「还是」什么……别、别说下去……哈哈哈哈！"), (P, "你、你们果然……哈哈哈……我、我不问了……先笑完再说……")],
    (3, 3): [(BLUE, "……毛、毛茸茸的……魔力……满了……"), (P, "哈哈哈……我、我这边松鼠也……要、要爆了——！"),
             (P, "……哈……小怪全被吹飞了……"), (BLUE, "……嗯……舒、舒服……一点点……"), (BOSS, "……大家……回来……"),
             (BLUE, "哈哈哈哈……！回、回来了……一起滚……哈哈哈哈哈！"), (P, "哈哈哈哈！我这边的尾巴也——刚放完不行啦！"),
             (BOSS, "……笑……这样……好……乖……"), (BLUE, "……哈哈……谁、谁乖了……哈哈哈哈哈……！"),
             (P, "「一点点」舒服？我都听到你哼了一声哈哈哈！")],
    "chase": [(P, "哈哈哈……魔、魔力……要满了……巨石还在后面哈哈……！"), (BLUE, "……我……也……一起……"),
              (P, "……哈……石、石头缝里的手……被弹开了……"), (BLUE, "……嗯……舒服……"), (BOSS, "……别……走……"),
              (P, "哈哈哈哈！又、又抓住脚了！刚放完——哈哈哈哈！"), (BLUE, "哈哈哈……！不、不是舒服……是累了……哈哈哈哈哈！"),
              (BOSS, "……累……也……可爱……"), (BLUE, "……哈哈哈……都、都说了别夸……哈哈哈哈！"), (P, "跑、跑之前……先笑完……哈哈哈……")],
}
# 阶段三第 4 段（第 4 次起每次都播）：两个人被叠在一起，上面的蓝色公主被专挠大腿和屁股、下面的粉色公主被专挠脚心；
# 中间、结尾各爆发一次。只用立绘（没有大图）。蓝色公主傲娇到破防，粉色公主天然呆吐槽。
STACK = ("千手之间·战败（阶段三·叠在一起）", "（千手的手臂一抬，小怪们把两个人推到一起——蓝色公主被压在上面，粉色公主垫在下面）", [
    {"note": "（两个人被手臂叠在一起，绑得紧紧的。上面那个的大腿和屁股朝着外面，下面那个的脚心朝着天）", "emo": {BLUE: "angry", P: "surprise"},
     "lines": [
        (BOSS, "……叠……起来……"), (P, "哈哈……重、重死了！你、你压到我了哈哈！"), (BLUE, "……是它们推的。……不是我。"),
        (P, "我们现在……像不像叠起来的点心……哈哈……"), (BLUE, "……这种时候……别说傻话。"),
        (N, "（刷刷刺猬爬上来，刷毛贴着蓝色公主的大腿；另一只羽毛手，停在粉色公主朝天的脚心上）"),
        (BLUE, "……唔。……不痒。", "shy"), (P, "脚、脚心——呀哈哈哈！痒痒痒！", "helpless_1"),
        (BLUE, "……别、别乱动……你一笑……我也跟着晃……", "helpless_1")]},
    {"note": "（刷子在大腿上来回、羽毛在脚心上画圈——两边的节奏一模一样）", "lines": [
        (P, "哈哈哈哈！羽、羽毛在脚心画圈——不行不行！"), (BLUE, "……嗯、嗯唔……大、大腿……刷、刷子……别……"),
        (BOSS, "……你……最怕……这里……她……最怕……那里……"), (P, "它、它连我怕脚心都知道？！哈哈哈……你们到底交流了什么啊！"),
        (BLUE, "……没、没交流……哈、哈哈……"), (N, "（松鼠们钻到了上面，蓬松的尾巴一下一下扫过蓝色公主的屁股）"),
        (BLUE, "……！……哈哈……哈哈哈……屁、屁股……不、不行……"), (P, "上面笑得在抖——我、我在下面也跟着抖哈哈哈哈！")]},
    {"burst": [(BLUE, "……魔、魔力……满了……"), (P, "哈哈……我、我也是……一、一起……！"),
               (BLUE, "……哈……嗯……身体……好轻……"), (P, "……呼……哈……好舒服……"), (BOSS, "……第……一……次……"),
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
    {"burst": [(BLUE, "……又、又满了……不、不行……这次……压不住……"), (P, "哈哈哈……我、我也……第二次了……呜哇——！"),
               (BLUE, "……哈……哈……全、全部……没了……"), (P, "……哈……软、软软的……像云……"), (BOSS, "……现在……最……敏感……"),
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
        (P, "哈……哈……路、路被堵住了——！笑、笑得腿都软了还要跑……！"), (BOSS, "……别……走……"), (BLUE, "……它……还没放弃……"),
        (P, "手、手从石头缝里伸出来了——呀哈哈！抓、抓住脚了哈哈！"), (BLUE, "……踢开。……用力。", "angry"),
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
        (P, "哈……哈……再跑一次！这次跑在一起！"), (BLUE, "……嗯。……再来。", "normal")]},
])
(TH / "f8_chase_fail.json").write_text(json.dumps(theater(CHASE_FAIL[0], CHASE_FAIL[1], CHASE_FAIL[2] + [{"burst": BURSTS["chase"]}]),
                                                 ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 小房间（追逐逃出来之后过夜的地方）
# 很久没人住的小女孩的房间（其实是蓝色公主小时候的房间，她不说）：落灰的床、小裙子、雪花发夹、裂了的镜子、两人份的茶具、
# 八音盒、门框上的身高刻痕、褪色的蜡笔画（蓝头发的小女孩和「好多只手」）。操控粉色公主、不能切换；蓝色公主站在窗边。
SH_OBJ = "talk:floor_08/shelter_objects#"
sh = Map("floor_08_shelter", 16, 12, "intro =\nintro_cutscene = f8_shelter_intro\nambient = 0.42,0.38,0.58\nno_switch = true", "第八层·小房间")
sh.room(2, 2, 13, 9)
for y in range(2, 10):
    for x in range(2, 14):
        sh.put(x, y, "prop type=wood_floor")
sh.put(2, 2, "prop type=cobweb")
sh.put(13, 2, "prop type=cobweb")
sh.put(12, 2, "prop type=window action=" + SH_OBJ + "window")
sh.put(8, 2, "prop type=crayon_drawing action=" + SH_OBJ + "drawing")
sh.put(3, 4, "prop type=old_bed action=" + SH_OBJ + "bed")
sh.put(6, 3, "prop type=wardrobe action=" + SH_OBJ + "wardrobe")
sh.put(10, 3, "prop type=bookshelf action=" + SH_OBJ + "bookshelf")
sh.put(3, 8, "prop type=old_dresser action=" + SH_OBJ + "dresser")
sh.put(5, 8, "prop type=music_box action=" + SH_OBJ + "music_box")
sh.put(8, 6, "prop type=rug")
sh.put(8, 6, "prop type=old_tea action=" + SH_OBJ + "tea")
sh.put(7, 6, "prop type=chair")
sh.put(9, 6, "prop type=chair")
sh.put(5, 5, "prop type=candle")
sh.put(12, 8, "prop type=candle")
sh.put(6, 9, "prop type=height_marks action=" + SH_OBJ + "marks")
sh.put(11, 9, "savepoint place=第八层·小房间")
# 门：走出夜迷宫、回到小屋之后（f8_returned）打开，通往新的第七层；之前一直锁着
sh.put(7, 9, "exit target=floor_07_return spawn=from_shelter unlock_flag=f8_returned locked_dialogue=f8s_door")
sh.put(13, 9, "f8shelter")
sh.put(12, 4, "blue_princess dialogue=floor_08/shelter_blue ai=false")
sh.put(7, 8, "player")
sh.write()


def SL(text, who=P, emotion=None):
    s = {"speaker": who, "text": text}
    if emotion:
        s["emotion"] = emotion
    return s


# 调查房间里的东西（Prop 的 talk:floor_08/shelter_objects#<节点>）：粉色公主的感想；有的蓝色公主在窗边插一句。
# 调查过蜡笔画 / 发夹 / 刻痕 / 八音盒会设标记，和蓝色公主说话时多出对应的话题。
SHELTER_OBJ = {"name": "", "entries": [{"node": "bed"}], "nodes": {
    "bed": {"lines": [SL("落了一层灰的床，帷幔是淡淡的蓝色……被子比我的床小一圈。", P, "surprise"),
                      SL("……今天就在这里过夜吧。", P, "shy")], "set": {"flags": ["f8s_seen_bed"]},
            "prompt": "……睡吧？", "choices": [{"text": "睡吧", "next": "bed_sleep"}, {"text": "再看看", "next": ""}],
            "goto": [{"if": {"flag": "f8_returned"}, "node": "bed_after"}]},
    "bed_after": {"lines": [SL("床单上还留着冰化掉的水印……脚心一想起来就痒痒的。", P, "shy"),
                            SL("不睡了！要出发了！", P, "happy")]},
    "bed_sleep": {"lines": [SL("……嗯。今天就到这里……晚安。", P, "shy")], "cutscene": "f8_shelter_sleep"},
    "wardrobe": {"lines": [SL("衣柜里挂着几件蓝色的小裙子……好小，像是给小孩子穿的。", P, "surprise"),
                           SL("裙摆上缝着雪花形状的花边。……做得好仔细。", P),
                           SL("……别乱翻。", BLUE)]},
    "drawing": {"lines": [SL("墙上贴着一张褪色的蜡笔画。一个蓝头发的小女孩……旁边是，好多只手？", P, "surprise"),
                          SL("大家都在笑……是在玩什么游戏吗？", P),
                          SL("……别看了。……很旧了。", BLUE, "sad")], "set": {"flags": ["f8s_seen_drawing"]}},
    "dresser": {"lines": [SL("梳妆台的镜子裂了一道缝。台面上放着一枚雪花形状的小发夹。", P),
                          SL("……和她头上的那个，好像。", P, "surprise"),
                          SL("……放回去吧。", BLUE)], "set": {"flags": ["f8s_seen_hairpin"]}},
    "tea": {"lines": [SL("小圆桌上摆着两个茶杯，一个蓝的，一个白的……杯底都积了灰。", P),
                      SL("以前，有两个人在这里喝茶吧。", P, "sad")]},
    "bookshelf": {"lines": [SL("书架上都是童话书……《会挠痒的森林》《雪花公主》……书角都翻卷了。", P),
                            SL("……最上面一格少了一本，只留下一个空位。", P, "surprise")]},
    "music_box": {"lines": [{"speaker": "", "text": "（拧了拧发条——盒子里传出一段断断续续的旋律）", "sfx": "music_box"},
                            SL("……好好听。有点……寂寞的调子。", P, "sad"),
                            SL("……", BLUE),
                            SL("……它还会响啊。", BLUE, "sad")], "set": {"flags": ["f8s_seen_music_box"]}},
    "marks": {"lines": [SL("门框上刻着一道道小刻痕……是在量身高吧？", P, "surprise"),
                        SL("最高的那道，才到我的胸口……之后就没有了。", P, "sad"),
                        SL("……那个，是别人的。", BLUE)], "set": {"flags": ["f8s_seen_marks"]}},
    "window": {"lines": [SL("窗外黑漆漆的，远处好像还有手臂的影子在晃……", P, "surprise"),
                         SL("……今晚确实别出去了。", P, "sad")]},
}}
(DLG / "shelter_objects.json").write_text(json.dumps(SHELTER_OBJ, ensure_ascii=False, indent="\t") + "\n")

# 和窗边的蓝色公主说话：调查过可疑的东西先聊那个（她岔开），否则按顺序的小话题，聊完重复最后一句。
SB = "蓝色的公主"
SHELTER_BLUE = {"name": SB, "npc": "blue_princess", "entries": [
    {"if": {"flag": "f8s_seen_drawing", "not": "f8s_t_drawing"}, "node": "drawing"},
    {"if": {"flag": "f8s_seen_music_box", "not": "f8s_t_music_box"}, "node": "music_box"},
    {"if": {"flag": "f8s_seen_hairpin", "not": "f8s_t_hairpin"}, "node": "hairpin"},
    {"if": {"flag": "f8s_seen_marks", "not": "f8s_t_marks"}, "node": "marks"},
    {"if": {"var": {"f8s_talk": ["<", 1]}}, "node": "t1"},
    {"if": {"var": {"f8s_talk": ["<", 2]}}, "node": "t2"},
    {"if": {"var": {"f8s_talk": ["<", 3]}}, "node": "t3"},
    {"if": {"var": {"f8s_talk": ["<", 4]}}, "node": "t4"},
    {"node": "last"}], "nodes": {
    "t1": {"lines": [SL("你冷不冷？这里除了那床被子，什么都没有诶。", P), SL("……不冷。习惯了。", SB),
                     SL("……你冷的话，被子给你。", SB, "shy")], "set": {"add": {"f8s_talk": 1}}},
    "t2": {"lines": [SL("说起来，今天你被挠的时候，笑得好大声哦。", P, "happy"), SL("……没有。", SB, "angry"),
                     SL("有！「才、才没有觉得舒服——」哈哈哈……", P, "happy"),
                     SL("……再学一遍，就把你冻住。", SB, "angry")], "set": {"add": {"f8s_talk": 1}}},
    "t3": {"lines": [SL("床只有一张诶……要不要一起睡？", P, "happy"), SL("……！", SB, "surprise"),
                     SL("……我、我睡椅子就好。", SB, "shy"), SL("椅子会腰痛的啦！", P),
                     SL("……再、再说吧。", SB, "shy")], "set": {"add": {"f8s_talk": 1}}},
    "t4": {"lines": [SL("你不睡吗？", P), SL("……你先睡。", SB),
                     SL("……我守一会儿。外面……不放心。", SB, "sad")], "set": {"add": {"f8s_talk": 1}}},
    "last": {"lines": [SL("……早点睡。明天还要走很远。", SB)]},
    "drawing": {"lines": [SL("墙上那张蜡笔画……是谁画的呀？", P), SL("……不知道。", SB),
                          SL("……很久以前的东西了。别在意。", SB, "sad")], "set": {"flags": ["f8s_t_drawing"]}},
    "music_box": {"lines": [SL("那个八音盒，你会拧吗？声音好好听。", P, "happy"), SL("……以前……", SB, "sad"),
                            SL("……没什么。……睡吧。", SB)], "set": {"flags": ["f8s_t_music_box"]}},
    "hairpin": {"lines": [SL("梳妆台上那个雪花发夹，和你的一模一样诶。", P, "surprise"), SL("……巧合。", SB),
                          SL("……雪花的发夹，很常见。", SB)], "set": {"flags": ["f8s_t_hairpin"]}},
    "marks": {"lines": [SL("门框上的身高刻痕，到我胸口就停了……那个孩子后来怎么了呢？", P, "sad"), SL("……", SB),
                        SL("……长大了吧。", SB, "sad")], "set": {"flags": ["f8s_t_marks"]}},
}}
(DLG / "shelter_blue.json").write_text(json.dumps(SHELTER_BLUE, ensure_ascii=False, indent="\t") + "\n")

# 开场过场：推门进来 → 灰尘、喷嚏 → 已经很晚了，今晚在这里过夜 → 小互动 → 她走到窗边
BLUE_NPC = "BluePrincess_12_4"
SHELTER_CUTS = {
    "f8_shelter_intro": cut("第八层：小房间", [
        {"actions": [A("move", who=BLUE_NPC, to=[8, 8]), A("face", who=BLUE_NPC, dir="up"), A("face", who="princess", dir="up"),
                     A("sfx", sound="door")], "wait": 0.6},
        line(P, "呼……这里……好像是个房间？", "surprise", [A("bubble", who="princess", kind="surprise")]),
        {"actions": [A("move", who="princess", to=[7, 6], speed=50), A("move", who=BLUE_NPC, to=[9, 7], speed=50)], "wait": 0.8},
        line(P, "哈……哈啾！好、好多灰……", "sad", [A("shake", who="princess", time=0.3)]),
        line(BLUE, "……很久没人住了。"),
        line(BLUE, "……已经很晚了。外面很危险，到处都是它的手。"),
        line(BLUE, "今晚……先在这里过夜。"),
        line(P, "嗯！那今天就在这里休息～", "happy"),
        line(P, "……不过，这里好像以前有人住过诶。床、裙子、茶杯……都小小的。", "surprise"),
        line(BLUE, "……", actions=[A("face", who=BLUE_NPC, dir="left")]),
        line(BLUE, "……别乱碰就好。"),
        line(P, "……嘿嘿。", "happy", [A("move", who="princess", to=[8, 7], speed=40)]),
        line(P, "今天你笑得那么大声，我还没报仇呢——看招！", "happy", [A("bubble", who="princess", kind="laugh")]),
        {"actions": [A("sfx", sound="chime"), A("shake", who="princess", time=0.3), A("move", who="princess", to=[7, 7], time=0.2)],
         "wait": 0.4},
        line(P, "呀！冰、冰晶把我弹开了……！", "surprise"),
        line(BLUE, "……想得美。", "angry"),
        line(BLUE, "……太暗了。", actions=[A("sfx", sound="chime")]),
        {"speaker": "", "text": "（蓝色公主指尖亮起一点冰晶的光，屋里的蜡烛一根一根亮了起来）"},
        line(P, "哇……好漂亮。今天……笑了一整天，现在这样安安静静的，真好。", "happy"),
        line(BLUE, "……嗯。"),
        {"actions": [A("move", who=BLUE_NPC, to=[12, 4], speed=45), A("face", who="princess", dir="right")], "wait": 1.2},
        {"actions": [A("face", who=BLUE_NPC, dir="down")], "wait": 0.3},
        line(BLUE, "……我在窗边。你想做什么就做什么。……早点睡。"),
        {"actions": [A("notify", text="可以调查房间里的东西，或者和蓝色公主说话。（现在只能操控粉色公主）")], "wait": 0.3},
    ]),
}
for name, cs in SHELTER_CUTS.items():
    (CUT / (name + ".json")).write_text(json.dumps(cs, ensure_ascii=False, indent="\t") + "\n")
SIGNS8 = json.loads((DLG / "signs.json").read_text())
SIGNS8["f8s_door"] = [{"speaker": BLUE, "text": "……外面很危险。今晚别出去。"}]
(DLG / "signs.json").write_text(json.dumps(SIGNS8, ensure_ascii=False, indent="\t") + "\n")
Path("levels/floor_08_shelter/design.json").write_text(json.dumps({
    "_说明": ["第八层的小房间（gen_floor08.py 生成）：追逐逃出来后过夜的地方；操控粉色公主、不能切换（no_switch）。"]}, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 小房间的夜晚：睡下 → 蓝色公主冰封她（脚露在外面）→ 离开
BED_AT = [3, 4.25]   # 床（old_bed，地图 (3,4)）的节点位置 (56, 80) 换成过场格子坐标（cell_to_world：y*16+12）
SLEEP_CUTS = {
    "f8_shelter_sleep": cut("第八层：小房间的夜晚", [
        {"actions": [A("fade_out", time=0.6)], "wait": 0.7},
        # 床（old_bed 道具）在 (3,4)：节点在 (56, 80)；她躺上去，脚在床尾、头在枕头上，被子盖到胸口
        {"actions": [A("lie", who="princess", at=BED_AT, blanket="old_bed_blanket", sleep=True), A("bubble", who="princess", kind="dots"),
                     A("move", who=BLUE_NPC, to=[11, 5]), A("face", who=BLUE_NPC, dir="left"), A("fade_in", time=0.8)], "wait": 0.9},
        {"speaker": "", "text": "（粉色公主钻进被窝，没过多久就发出了均匀的呼吸声）"},
        line(P, "……呼……呼……唔嘿嘿……再、再来一块饼干……", "shy"),
        {"actions": [A("move", who=BLUE_NPC, to=[5, 5], speed=30), A("face", who=BLUE_NPC, dir="left")], "wait": 1.6},
        line(BLUE, "……睡着了。"),
        line(BLUE, "……对不起。……不能让你跟来。", "sad"),
        {"actions": [A("sfx", sound="chime"), A("flash", time=0.4),
                     A("spawn", id="ice", kind="prop:ice_bed", at=BED_AT)], "wait": 0.6},
        {"speaker": "", "text": "（冰晶的光一闪，一层薄冰连着被子轻轻盖在她身上——从枕头一直盖到床尾）"},
        line(BLUE, "……这样，它们就找不到你了。"),
        line(BLUE, "……", actions=[A("face", who=BLUE_NPC, dir="left")]),
        line(BLUE, "……脚。……露在外面了。", "surprise", [A("camera", to=[3, 5], zoom=1.6, time=0.5)]),
        line(BLUE, "……她最怕脚心。……", "shy"),
        line(BLUE, "……算了。……没人会挠的。……应该。", "shy"),
        line(BLUE, "……对不起。", "sad", [A("camera", reset=True, time=0.5)]),
        {"actions": [A("move", who=BLUE_NPC, to=[7, 8], speed=40)], "wait": 1.4},
        {"actions": [A("sfx", sound="door"), A("set_flag", flag="blue_is_hero"), A("set_flag", flag="f8_slept"),
                     A("fade_out", time=1.0), A("goto", to="floor_08_maze_1", spawn="")], "wait": 1.2},
    ]),
    "f8_maze_intro": cut("第八层：夜迷宫", [
        {"actions": [A("fade_in", time=1.2)], "wait": 1.2},
        line(BLUE, "……这里。"),
        line(BLUE, "……你在吧。"),
        {"actions": [A("wait")], "wait": 0.8},
        line(BLUE, "……对不起。", "sad"),
        line(BLUE, "……这次，换我来补偿你。", "sad"),
        {"speaker": "", "text": "（远处的黑暗里，亮起一只紫色的手——轻轻晃了晃，又暗了下去）"},
        line(BLUE, "……", "surprise", [A("bubble", who="princess", kind="dots")]),
        line(BLUE, "……来吧。", "angry"),
    ]),
}
for name, cs in SLEEP_CUTS.items():
    (CUT / (name + ".json")).write_text(json.dumps(cs, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 夜迷宫（三段；tools/build/maze_gen.py 生成迷宫格子，2.5D 光照）
from maze_gen import Maze  # noqa: E402

# 段 -> (单元列, 单元行, 种子, 月光灯数, 回环比例, 小房间数, 呼吸墙对数, 回忆碎片 id)
# 第四轮：走廊 1 格宽（maze_gen step = 2），单元数加大约 1.3 倍，总路程和原来差不多
MAZES = {
    1: (26, 18, 81, 4, 0.14, 3, 4, (1, 2)),
    2: (31, 23, 82, 4, 0.13, 5, 6, (3, 4)),
    3: (36, 27, 83, 3, 0.12, 5, 8, (5, 6)),
}
MAZE_INFO = {}

# 每段的三来源组合区域（按顺序放进不含灯 / 起点 / 出口的小房间）：组合 id -> 要摆的东西
MAZE_COMBOS = {
    1: ["mz_moth_curtain", "mz_cradle_moth", "mz_moth_mirror_curtain"],
    2: ["mz_mirror_vine", "mz_fluff_jar", "mz_curtain_vine", "mz_mirror_jar", "mz_rhythm_combo"],
    3: ["mz_dark_raid", "mz_shadow_bench", "mz_gate_hands"],
}
# 来源键 -> 地图上的写法（maze_hand / hand_rhythm 由导演提供，不用摆；千手之门 / 影子另外处理）
MAZE_SPEC = {
    "glow_moth": "monster type=glow_moth", "dream_fluff": "monster type=dream_fluff", "lamp_imp": "monster type=lamp_imp",
    "laugh_jar": "monster type=laugh_jar", "mirror_puddle": "trap type=mirror_puddle", "shadow_vine": "trap type=shadow_vine",
    "feather_curtain": "trap type=feather_curtain", "cradle_bench": "cradle",
    # 第五轮：遮眼蝠、垂落吊手；以前楼层已有的束缚陷阱（倒吊绳套、绑腿、举手铐柱）
    "blind_bat": "monster type=blind_bat", "hanging_hands": "trap type=hanging_hands",
    "snare": "trap type=snare", "binding": "trap type=binding", "cuffs": "trap type=cuffs",
}
# 装在墙上的（墙格；下面 / 旁边一格是走廊）：墙缝刷轮（四个方向都行）、机关手 / 夹腿钳（只装在走廊上方的墙上，朝下）、羽毛臂（朝下伸 2 格）
MAZE_WALL_SPEC = {
    "wall_brush": "walltrap type=wall_brush face=%s", "grab_hand": "walltrap type=hand group=%s",
    "thigh_pincer": "walltrap type=thigh_pincer", "feather_arm": "walltrap type=arm dir=down len=2",
}
MAZE_COMBO_KEYS = {
    "mz_moth_curtain": ["glow_moth", "feather_curtain"], "mz_mirror_vine": ["mirror_puddle", "shadow_vine"],
    "mz_fluff_jar": ["dream_fluff", "laugh_jar"], "mz_cradle_moth": ["cradle_bench", "glow_moth"],
    "mz_curtain_vine": ["feather_curtain", "shadow_vine", "dream_fluff"], "mz_mirror_jar": ["mirror_puddle", "laugh_jar"],
    "mz_dark_raid": ["lamp_imp", "dream_fluff"], "mz_shadow_bench": ["hand_shadow", "cradle_bench"],
    "mz_gate_hands": ["hand_gate", "shadow_vine"], "mz_moth_mirror_curtain": ["glow_moth", "feather_curtain", "mirror_puddle"],
    "mz_rhythm_combo": ["dream_fluff", "shadow_vine"],
}
# 段 -> 散放的东西（来源键: 个数）、门帘（主路上的门洞数）、月光镜暗门数、千手之门捷径数、巡逻影子数
# 第五轮：怪物和陷阱多了约 60%（遮眼蝠、垂落吊手、以前楼层的束缚陷阱）
MAZE_SCATTER = {
    1: ({"glow_moth": 6, "mirror_puddle": 4, "cradle_bench": 1, "hanging_hands": 1, "snare": 1}, 3, 0, 0, 0),
    2: ({"glow_moth": 3, "dream_fluff": 5, "laugh_jar": 2, "shadow_vine": 4, "mirror_puddle": 3, "blind_bat": 2,
         "hanging_hands": 2, "binding": 1}, 2, 1, 0, 1),
    3: ({"glow_moth": 3, "dream_fluff": 3, "laugh_jar": 2, "lamp_imp": 4, "shadow_vine": 4, "blind_bat": 3,
         "hanging_hands": 3, "cuffs": 1}, 2, 1, 1, 2),
}
# 段 -> 墙上的陷阱（墙缝刷轮 / 机关手 / 夹腿钳 / 羽毛臂: 个数）
MAZE_WALL = {
    1: {"wall_brush": 2},
    2: {"wall_brush": 3, "grab_hand": 2, "thigh_pincer": 1},
    3: {"wall_brush": 4, "thigh_pincer": 2, "feather_arm": 2},
}
# 段 -> 夜啼追手（游荡的只数、第三段的固定追逐）
MAZE_STALKER = {1: (0, False), 2: (1, False), 3: (1, True)}
# 新陷阱 / 怪物离出生点、月光灯、出口至少几格（曼哈顿距离）
KEEP_AWAY = 4
DIRS4 = [(1, 0), (0, 1), (-1, 0), (0, -1)]   # MoonMirror.facing 0~3


class MazePlacer:
    """往一段迷宫里摆怪物 / 陷阱 / 机关 / 组合区域 / 巡逻影子；记下 design.json 用的组合区域和机关。"""

    def __init__(self, sec, mm, mz, reserved_cells):
        self.sec, self.mm, self.mz = sec, mm, mz
        self.rng = mz.rng
        self.used_cells = set(reserved_cells)
        self.used_tiles = set(mm.cells)
        self.no_go = set()          # 呼吸墙的格子：什么都不放
        for b in mz.breathing:
            self.no_go.update(b["a"])
            self.no_go.update(b["b"])
        self.areas = []
        self.devices = []
        self.keep_away = []

    def free_tile(self, x, y):
        return self.mm.g[y][x] == "." and (x, y) not in self.used_tiles and (x, y) not in self.no_go

    def put(self, x, y, spec):
        self.mm.put(x, y, spec)
        self.used_tiles.add((x, y))

    def put_in_cell(self, c, spec):
        tiles = [t for t in self.mz.cell_floor(c) if self.free_tile(*t)]
        if not tiles:
            return None
        t = self.rng.choice(tiles)
        self.put(t[0], t[1], spec)
        self.used_cells.add(c)
        return t

    # -------------------------------------------------------------- 组合区域
    def combo_rooms(self):
        return [r for r in self.mz.rooms if not any(c in self.used_cells for c in r)]

    def room_rect(self, cells):
        xs = [x for c in cells for (x, _y) in self.mz.cell_floor(c)]
        ys = [y for c in cells for (_x, y) in self.mz.cell_floor(c)]
        return [min(xs), min(ys), max(xs), max(ys)]

    def place_combos(self, combos):
        rooms = self.combo_rooms()
        assert len(rooms) >= len(combos), ("第 %d 段的小房间不够放组合区域" % self.sec, len(rooms), len(combos))
        for cid, room in zip(combos, rooms):
            rect = self.room_rect(room)
            tiles = [(x, y) for y in range(rect[1], rect[3] + 1) for x in range(rect[0], rect[2] + 1) if self.free_tile(x, y)]
            self.rng.shuffle(tiles)
            for key in MAZE_COMBO_KEYS[cid]:
                if key == "hand_gate":
                    g = self.hand_gate(room, "hg_%d_%s" % (self.sec, cid))
                    rect = [min([rect[0]] + [t[0] for t in g]), min([rect[1]] + [t[1] for t in g]), max([rect[2]] + [t[0] for t in g]), max([rect[3]] + [t[1] for t in g])]
                elif key == "hand_shadow":
                    self.shadow(room[0])
                else:
                    if MAZE_SPEC[key].startswith("monster"):   # 怪物放在房间中间（会走动，别一开始就贴着门口）
                        cx, cy = (rect[0] + rect[2]) / 2.0, (rect[1] + rect[3]) / 2.0
                        t = min(tiles, key=lambda p: abs(p[0] - cx) + abs(p[1] - cy))
                        tiles.remove(t)
                    else:
                        t = tiles.pop()
                    self.put(t[0], t[1], MAZE_SPEC[key])
            self.used_cells.update(room)
            # 区域外扩一格（门口一带也算）
            self.areas.append({"combo": cid, "rect": [rect[0] - 1, rect[1] - 1, rect[2] + 1, rect[3] + 1]})

    # -------------------------------------------------------------- 散放
    def far_enough(self, t):
        """离出生点、月光灯、出口都至少 KEEP_AWAY 格。"""
        return all(abs(t[0] - k[0]) + abs(t[1] - k[1]) >= KEEP_AWAY for k in self.keep_away)

    def scatter(self, counts):
        pool = [c for c in self.mz.corridor_cells(exclude=self.used_cells) + self.mz.dead_ends if c not in self.used_cells]
        pool = [c for c in pool if all(self.far_enough(t) for t in self.mz.cell_floor(c))]
        items = [k for k, n in counts.items() for _ in range(n)]
        self.rng.shuffle(items)
        for c, key in zip(self.mz.spread(pool, len(items)), items):
            self.put_in_cell(c, MAZE_SPEC[key])

    def wall_traps(self, counts):
        """墙上的陷阱：走廊旁边的墙格（墙缝刷轮四个方向都行；其它只装在走廊上方、朝下）。尽量分散。"""
        faces = {"down": (0, 1), "up": (0, -1), "right": (1, 0), "left": (-1, 0)}
        cands = []
        for y in range(1, self.mz.h - 1):
            for x in range(1, self.mz.w - 1):
                if self.mm.g[y][x] != "#" or (x, y) in self.used_tiles or (x, y) in self.mm.cells:
                    continue
                for f, (dx, dy) in faces.items():
                    fx, fy = x + dx, y + dy
                    if self.mm.g[fy][fx] == "." and self.free_tile(fx, fy) and self.far_enough((fx, fy)) \
                            and self.mz.cell_of((fx, fy)) not in self.used_cells:
                        cands.append(((x, y), f, (fx, fy)))
        items = [k for k, n in counts.items() for _ in range(n)]
        self.rng.shuffle(items)
        chosen = []
        for i, key in enumerate(items):
            pool = [c for c in cands if (key == "wall_brush" or c[1] == "down")
                    and all(abs(c[2][0] - o[0]) + abs(c[2][1] - o[1]) >= 8 for o in chosen)]
            if not pool:
                continue
            # 离已经放过的越远越好
            (wx, wy), f, ft = max(pool, key=lambda c: (min([abs(c[2][0] - o[0]) + abs(c[2][1] - o[1]) for o in chosen] or [99]),
                                                        self.rng.random()))
            spec = MAZE_WALL_SPEC[key]
            if key == "wall_brush":
                spec = spec % f
            elif key == "grab_hand":
                spec = spec % ("mzh_%d_%d" % (self.sec, i))
            self.mm.put(wx, wy, spec)
            self.used_tiles.add((wx, wy))
            self.used_tiles.add(ft)      # 正下方 / 正前方那一格不再放别的
            chosen.append(ft)
            self.devices.append({"kind": key, "wall": [wx, wy], "floor": list(ft), "face": f})

    def stalkers(self, n, scripted, lamp_cells):
        """夜啼追手：游荡的放在离起点很远的走廊；固定追逐：主路上第二盏灯前一段走廊放触发区，追手从身后冒出来。"""
        dist = self.mz._cell_dist(self.mz.start_cell)
        far = sorted([c for c in self.mz.corridor_cells(exclude=self.used_cells) if c not in self.used_cells],
                     key=lambda c: -dist.get(c, 0))
        for c in far[:n]:
            t = self.put_in_cell(c, "nightstalker")
            if t:
                self.devices.append({"kind": "night_stalker", "at": list(t)})
        if scripted:
            path = self.mz.main_path
            li = path.index(lamp_cells[1]) if lamp_cells[1] in path else len(path) // 2
            zc, sc = path[max(4, li - 6)], path[max(1, li - 10)]
            zx, zy = self.mz.tile(zc, 0)
            sx, sy = self.mz.tile(sc, 0)
            self.mm.put(zx, zy, "stalkerzone spawn=%d,%d" % (sx, sy))
            self.devices.append({"kind": "stalker_zone", "zone": [zx, zy], "spawn": [sx, sy], "lamp": list(self.mz.tile(lamp_cells[1], 3))})

    def curtains(self, n):
        """主路上的门洞（两个单元之间的 2 格）挂羽毛门帘。"""
        path = self.mz.main_path
        links = [(path[i], path[i + 1]) for i in range(3, len(path) - 2)]
        links = [p for p in links if all(self.free_tile(*t) for t in self.mz.link_cells(*sorted(p)))]
        for a, b in self.mz.rng.sample(links, min(n, len(links))):
            for i, (x, y) in enumerate(self.mz.link_cells(*sorted((a, b)))):
                self.put(x, y, "trap type=feather_curtain offset=%.1f" % (0.4 * i))

    # -------------------------------------------------------------- 机关
    def closed_links(self, near_cells, max_cells=3):
        """离 near_cells 不远、现在封着的单元间墙（打开后是捷径：两边绕路越远越好）。"""
        dist_from = {}
        out = []
        for c in self.mz.all_cells():
            if min(abs(c[0] - n[0]) + abs(c[1] - n[1]) for n in near_cells) > max_cells:
                continue
            for n in self.mz.neighbors(c):
                if c < n and not self.mz.linked(c, n):
                    lk = self.mz.link_cells(c, n)
                    if any(t in self.no_go or t in self.used_tiles for t in lk):
                        continue
                    if c not in dist_from:
                        dist_from[c] = self.mz._cell_dist(c)
                    out.append((dist_from[c].get(n, 999), c, n, lk))
        out.sort(key=lambda o: -o[0])
        return out

    def hand_gate(self, room, group):
        """千手之门：房间边上一段封着的墙打开、放两扇门（身上 ≥3 只手才推得开）。返回门两格。"""
        cands = [o for o in self.closed_links(room, 1) if (o[1] in room) != (o[2] in room)]
        assert cands, ("第 %d 段的房间旁边没有能开千手之门的墙" % self.sec)
        _d, _c, _n, lk = cands[0]
        for (x, y) in lk:
            self.mm.g[y][x] = "."
            self.put(x, y, "handgate group_name=%s" % group)
        self.devices.append({"kind": "hand_gate", "group": group, "cells": [list(t) for t in lk]})
        return lk

    def shortcut_gate(self, i):
        near = [c for c in self.mz.main_path[len(self.mz.main_path) // 3:]]
        cands = [o for o in self.closed_links(self.rng.sample(near, min(4, len(near))), 2) if o[0] >= 6 and o[0] < 999]
        if cands:
            self.hand_gate([cands[0][1]], "hg_%d_short%d" % (self.sec, i))

    def moon_mirror(self, lamp_cells, i):
        """月光镜：放在一盏灯（不是入口那盏）旁边，光带沿一条直走廊照到光开关；开关旁边一段封墙变暗门（捷径）。"""
        best = None
        for lc in lamp_cells[1:]:
            # 灯旁边 3 格以内的空地（走廊 1 格宽时灯那一格已经被灯占了）
            lx, ly = self.mz.tile(lc, 3)
            near = [(lx + dx, ly + dy) for dy in range(-3, 4) for dx in range(-3, 4) if abs(dx) + abs(dy) <= 3]
            for (mx, my) in near:
                if not (0 <= mx < self.mz.w and 0 <= my < self.mz.h) or not self.free_tile(mx, my):
                    continue
                for f, (dx, dy) in enumerate(DIRS4):
                    run = []
                    x, y = mx + dx, my + dy
                    while len(run) < 13 and self.mm.g[y][x] == "." and (x, y) not in self.no_go:
                        run.append((x, y))
                        x, y = x + dx, y + dy
                    if len(run) >= 5 and self.free_tile(*run[-1]) and (best is None or len(run) > len(best[3])):
                        best = (mx, my, f, run)
        assert best, ("第 %d 段找不到能放月光镜的直走廊" % self.sec)
        mx, my, f, run = best
        group = "beam_%d_%d" % (self.sec, i)
        sx, sy = run[-1]
        self.put(mx, my, "moonmirror facing=%d" % ((f + 2) % 4))     # 一开始朝反方向：要转两下
        self.put(sx, sy, "beamswitch group_name=%s" % group)
        scell = self.mz.cell_of((sx, sy))
        cands = [o for o in self.closed_links([scell], 2) if o[0] < 999]
        assert cands, ("第 %d 段的光开关旁边没有能开暗门的墙" % self.sec)
        _d, _c, _n, lk = cands[0]
        for (x, y) in lk:
            self.mm.g[y][x] = "."
            self.put(x, y, "gate group=%s" % group)
        self.devices.append({"kind": "moon_mirror", "mirror": [mx, my], "facing": f, "switch": [sx, sy], "group": group,
                             "door": [list(t) for t in lk]})

    def shadow(self, through=None):
        """千手的影子：飘在迷宫上空，沿一条横穿整个迷宫的直线来回巡游（穿过墙）。
        through（组合区域的房间单元）给了就从那里经过；否则挑一行 / 一列，离出生点远一点。"""
        sx0, sy0 = self.mz.tile(self.mz.start_cell, 0)
        horiz = self.rng.random() < 0.5 if through is None else (self.sec + len(self.devices)) % 2 == 0
        if through is not None:
            x, y = self.mz.tile(through, 0)
        else:
            for _ in range(40):
                c = self.rng.choice([c for c in self.mz.branch_cells if c not in self.used_cells] or self.mz.all_cells())
                x, y = self.mz.tile(c, 0)
                if (abs(y - sy0) if horiz else abs(x - sx0)) > 8:
                    break
        if horiz:
            pts = [(2, y), (self.mz.w - 3, y)]
        else:
            pts = [(x, 2), (x, self.mz.h - 3)]
        if through is not None:
            pts = [(x, y)] + pts     # 从房间出发
        spec = "handshadow route=" + ";".join("%d,%d" % p for p in pts)
        self.mm.put(pts[0][0], pts[0][1], spec)
        self.devices.append({"kind": "hand_shadow", "route": [list(p) for p in pts]})


def build_maze(sec):
    cols, rows, seed, lamps, loops, rooms, breathing, shards = MAZES[sec]
    mz = Maze(cols, rows, seed=seed, loops=loops, rooms=rooms, breathing=breathing, step=2)
    fid = "floor_08_maze_%d" % sec
    head = "intro =\nintro_cutscene = %s\nstyle = iso\niso_theme = blue_stone\nambient = 0.09,0.095,0.16\nlight_drain = 90" % ("f8_maze_intro" if sec == 1 else "")
    title = {1: "第八层·夜迷宫一·外环回廊", 2: "第八层·夜迷宫二·镜之回廊", 3: "第八层·夜迷宫三·千手深处"}[sec]
    mm = Map(fid, mz.w, mz.h, head, title)
    mm.g = [row[:] for row in mz.grid]
    # 呼吸墙的 b 段在地图上也是地面（运行时导演开场把它升成墙；TerrainShifter 只能降下自己升起的墙）
    for b in mz.breathing:
        for (x, y) in b["b"]:
            mm.g[y][x] = "."
    sx, sy = mz.tile(mz.start_cell, 2)
    mm.put(sx, sy, "player")
    mm.put(sx, sy, "spawn id=from_%d" % (sec - 1))
    dx, dy = mz.tile(mz.start_cell, 1)
    mm.put(dx, dy, "f8maze section=%d" % sec)
    # 月光灯：起点一盏，其余沿主路均匀分布
    path = mz.main_path
    # 入口那盏放在主路的下一格（不罩住出生点：上一段带过来的手要走进灯里才散）
    lamp_cells = [path[2]] + [path[int(len(path) * k)] for k in [(i + 1) / (lamps) for i in range(lamps - 1)]]
    for i, c in enumerate(lamp_cells):
        x, y = mz.tile(c, 3)
        mm.put(x, y, "moonlamp")
        mm.put(x, y, "spawn id=lamp_%d" % (i + 1))
    # 回忆碎片：离主路最远的死路
    for sid, c in zip(shards, mz.dead_ends[:len(shards)]):
        x, y = mz.tile(c, 3)
        mm.put(x, y, "memshard id=%d" % sid)
    # 怪物 / 陷阱 / 机关 / 组合区域（起点附近 3 个单元、灯、碎片、出口不放）
    reserved = set(path[:3]) | {path[-4]} | set(lamp_cells) | set(mz.dead_ends[:len(shards)]) | {mz.exit_cell}
    pl = MazePlacer(sec, mm, mz, reserved)
    pl.keep_away = [(sx, sy), mz.tile(mz.exit_cell, 3)] + [mz.tile(c, 3) for c in lamp_cells]
    pl.place_combos(MAZE_COMBOS[sec])
    counts, curtains, mirrors, gates, shadows = MAZE_SCATTER[sec]
    for i in range(mirrors):
        pl.moon_mirror(lamp_cells, i)
    for i in range(gates):
        pl.shortcut_gate(i)
    for i in range(shadows - sum(1 for d in pl.devices if d["kind"] == "hand_shadow")):
        pl.shadow()
    pl.curtains(curtains)
    pl.scatter(counts)
    pl.wall_traps(MAZE_WALL[sec])
    pl.stalkers(*MAZE_STALKER[sec], lamp_cells)
    ex, ey = mz.tile(mz.exit_cell, 3)
    if sec < 3:
        mm.put(ex, ey, "exit target=floor_08_maze_%d spawn=from_%d" % (sec + 1, sec))
    else:
        mm.put(ex, ey, "spawn id=maze_exit")
        # 测试模式跳关「出口前」：主路上离出口 3 个单元的地方
        bx, by = mz.tile(path[-4], 0)
        mm.put(bx, by, "spawn id=before_exit")
    mm.write()
    MAZE_INFO[sec] = mz
    Path("levels/%s/design.json" % fid).write_text(json.dumps({
        "_说明": ["第八层夜迷宫第 %d 段（gen_floor08.py + maze_gen.py 生成，种子 %d）。breathing = 呼吸墙对（a 现在是地面、b 心跳后打开）。" % (sec, seed)],
        "breathing": [{"a": [list(p) for p in b["a"]], "b": [list(p) for p in b["b"]]} for b in mz.breathing],
        "combo_areas": pl.areas,
        "devices": pl.devices,
    }, ensure_ascii=False, indent="\t") + "\n")
    return mm, mz


for _sec in MAZES:
    build_maze(_sec)

# ================================================================ 夜迷宫的小剧场（只用立绘；她看不见手——舞台上只有她，被看不见的手挠）
def mtk(zone, repeat=8, interval=0.2):
    return A("tickle", who="blue", repeat=repeat, interval=interval, fx="hand", zone=zone)


def maze_theater(name, lines, end_pose="helpless_1"):
    """夜迷宫的小剧场（三幕式，舞台是夜里：night = true 压暗）。lines 里每一项：
      (说话人, 文本, 部位或 None, 立绘状态或 None)：部位不为空时这一句带一下看不见的手挠那里
      ("ACT", 2 / 3)：换幕——第二幕起憋笑的轻笑声，第三幕大笑声 + 失控的姿势
      ("FLASH",)：灯一闪（黑暗里忽然亮一下）   ("CRACK",)：蓝色公主憋不住的笑声（短的一段）   ("CRACK_LONG",)：长的一段"""
    steps = [{"actions": [A("fade_in", time=0.6)], "wait": 0.6}]
    pending = []
    act = 1
    n_tk = 0
    for ln in lines:
        if ln[0] == "ACT":
            act = ln[1]
            if act == 2:
                pending.append(A("voice", state="giggle"))
            elif act == 3:
                pending += [A("voice", state="laugh"), pose("blue", end_pose)]
            continue
        if ln[0] == "FLASH":
            pending.append(A("flash", time=0.25))
            continue
        if ln[0] in ("CRACK", "CRACK_LONG"):
            pending.append(A("sfx", sound="blue_crack_long" if ln[0] == "CRACK_LONG" else "blue_crack", volume=-3.0))
            continue
        sp, text = ln[0], ln[1]
        zone = ln[2] if len(ln) > 2 else None
        emo = ln[3] if len(ln) > 3 else None
        acts = pending
        pending = []
        if zone:
            # 越往后挠得越密
            acts.append(mtk(zone, 5 + act * 2 + n_tk % 3, max(0.1, 0.24 - act * 0.04 - min(n_tk, 12) * 0.004)))
            acts.append(A("shake", who="blue", time=0.2 + act * 0.1))
            n_tk += 1
        st = {"speaker": sp, "text": text, "actions": acts}
        if sp == BLUE and emo:
            st["emotion"] = emo
        steps.append(st)
    steps.append({"actions": pending + [A("voice", state=""), A("fade_out", time=0.8)], "wait": 0.9})
    return {"name": name, "night": True,
            "cast": {"blue": {"kind": "npc:blue_princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"}},
            "steps": steps}


ACT2, ACT3, FLASH, CRACK, CRACK_LONG = ("ACT", 2), ("ACT", 3), ("FLASH",), ("CRACK",), ("CRACK_LONG",)
# 第五轮：每段都按三幕写（铺垫：黑暗、声音、看不清，她冷静地强撑 → 升级：猜不到下一下在哪，比白天更怕痒 → 高潮 + 收尾：破防，然后嘴硬 / 回忆）
MAZE_THEATERS = {
    "f8_maze_first": ("夜迷宫·第一只手", [
        (N, "（迷宫里黑得只剩冷光照着的一小圈。再往外，什么都看不见）"),
        (BLUE, "……好安静。", None, "normal"),
        (N, "（脚步声在墙之间来回撞，听起来像是有好几个人在走）"),
        (BLUE, "……只是回声。", None, "normal"),
        (N, "（冷光晃了一下。光圈外面，好像有什么东西动了动）"),
        FLASH,
        (BLUE, "……？", None, "surprise"),
        (BLUE, "……谁。", None, "angry"),
        (N, "（没有回答。只有自己的呼吸声，忽然变得很大）"),
        (N, "（——然后，腰上，有什么轻轻地碰了她一下）"),
        (BLUE, "……！", "waist", "surprise"),
        ACT2,
        (BLUE, "……看不见。……但是，在。", None, "shy"),
        (N, "（一只看不见的手，贴在了腰侧。手指慢慢地、一节一节地动了动）"),
        (BLUE, "……唔。", "waist", "shy"),
        (BLUE, "……看不见……就不知道……下一下在哪。", None, "shy"),
        (N, "（手指停住了。她屏住呼吸，等着——等了很久，什么也没有）"),
        (BLUE, "……走、走了吗……", None, "normal"),
        (N, "（就在她放松的那一瞬间，手指一下子戳进了腰窝）"),
        (BLUE, "……噗！", "waist", "helpless_1"),
        CRACK,
        (BLUE, "……刚、刚才的，不算。", None, "angry"),
        (BLUE, "……太黑了。……身体……自己在等……", None, "shy"),
        (N, "（看不见的时候，每一寸皮肤都在猜下一下会落在哪里——猜着猜着，就变得更怕痒了）"),
        (BLUE, "……别……别让我猜……", "waist", "helpless_1"),
        ACT3,
        (BLUE, "……哈、哈……这种程度……忍、忍得住……", "waist", "helpless_1"),
        (N, "（手指像是听懂了，挠得更轻、更慢——慢得让人发疯）"),
        (BLUE, "……哈哈……慢、慢的……更、更犯规……哈哈哈……", "waist", "helpless_2"),
        (BLUE, "……停……停一下……哈哈……", "waist", "helpless_2"),
        (N, "（手指停了。黑暗里，只剩她一个人的喘气声）"),
        (BLUE, "……哈……哈……", None, "helpless_1"),
        (BLUE, "……你在吧。……是你，对吧。", None, "sad"),
        (N, "（没有回答。远处，一只紫色的手亮了一下，又暗了下去）"),
        (BLUE, "……", None, "sad"),
        (BLUE, "……走吧。……下次……我不会笑的。", None, "angry"),
    ]),
    "f8_maze_weak_first": ("夜迷宫·大腿", [
        (N, "（走廊越来越窄，两边的墙几乎要贴到肩膀）"),
        (BLUE, "……窄。……躲不开。", None, "normal"),
        (N, "（冷光只够照亮脚下。墙壁冰冷，靠上去的时候背脊一凉）"),
        (BLUE, "……没关系。……腰、腋下……都、都还好。", None, "normal"),
        (BLUE, "……只要……别碰那里。", None, "shy"),
        FLASH,
        (N, "（——像是听见了这句话似的，黑暗里，有什么慢慢地贴上了她的大腿）"),
        (BLUE, "……！", "thigh", "surprise"),
        ACT2,
        (BLUE, "……不、不是那里……", "thigh", "shy"),
        (N, "（手掌整个贴着大腿外侧，没有动。只是贴着）"),
        (BLUE, "……别、别贴着……走开……", None, "shy"),
        (N, "（手指一根、一根地抬起来，又落下去，往大腿内侧挪了一点）"),
        (BLUE, "……唔、嗯……！", "thigh", "helpless_1"),
        (BLUE, "……看不见……它在往哪走……", None, "shy"),
        (N, "（她看不见。只能从皮肤上感觉到，手指一步一步地，往上走）"),
        (BLUE, "……停……停在那里……不准再……", "thigh", "helpless_1"),
        CRACK,
        (BLUE, "……噗哈……！……不、不准……", "thigh", "helpless_1"),
        (BLUE, "……你……你怎么知道……我最怕……", None, "surprise"),
        ACT3,
        (N, "（手指不回答，只是在大腿内侧画起了小小的圈）"),
        (BLUE, "……哈哈……哈哈哈……那、那里真的不行……！", "thigh", "helpless_2"),
        (BLUE, "……画、画圈……犯规……哈哈哈哈……！", "thigh", "helpless_2"),
        (N, "（她夹紧双腿想挡住，手指却已经钻进了缝里）"),
        (BLUE, "……哈哈哈哈……夹、夹住了还在动……哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……我、我认……不、不认……哈哈哈……", "thigh", "helpless_2"),
        (N, "（手指终于停了下来。贴着大腿，像是在等她喘过气）"),
        (BLUE, "……哈……哈……", None, "helpless_1"),
        (BLUE, "……刚才那个……谁都、谁都不许说出去。", None, "angry"),
        (BLUE, "……特别是……她。", None, "shy"),
    ]),
    "f8_maze_total_8": ("夜迷宫·八只以上", [
        (N, "（身上的手越来越多。走一步，衣服下面就有手指跟着动一下）"),
        (BLUE, "……一、二……三……", None, "normal"),
        (BLUE, "……数、数不清了。", None, "shy"),
        (N, "（冷光已经很暗了。她看不见那些手，只能靠身上的痒，猜它们在哪）"),
        (BLUE, "……腰……腋下……大腿……还有……", None, "shy"),
        (BLUE, "……够了。……都、都别动。", None, "angry"),
        FLASH,
        (N, "（——所有的手指，一起停住了）"),
        (BLUE, "……？", None, "surprise"),
        ACT2,
        (N, "（安静得可怕。八只手、四十根手指，全都贴着她，一动不动）"),
        (BLUE, "……为、为什么……不动了……", None, "shy"),
        (BLUE, "……反、反而……更……", None, "shy"),
        (N, "（看不见、也不知道哪一只会先动——她整个人都绷紧了）"),
        (BLUE, "……别……别等了……要挠就……", None, "helpless_1"),
        (N, "（一只。腋下）"),
        (BLUE, "……噗！", "armpit", "helpless_1"),
        (N, "（又一只。屁股）"),
        (BLUE, "……唔嗯——！", "butt", "helpless_1"),
        CRACK,
        (N, "（然后是大腿、腰、脚心——一只接一只，像是在弹一首她听不懂的曲子）"),
        (BLUE, "……哈、哈哈……一、一只一只来……更、更……哈哈……", "thigh", "helpless_1"),
        ACT3,
        (BLUE, "……哈哈哈……！别、别轮流……哈哈哈哈……！", "waist", "helpless_2"),
        (BLUE, "……猜、猜不到……猜不到下一只……哈哈哈哈……！", "butt", "helpless_2"),
        (N, "（她笑得靠着墙滑坐下来，笑声在走廊里来回回荡）"),
        (BLUE, "……哈哈……这、这么多……你、你一直在等吧……", "thigh", "helpless_2"),
        (BLUE, "……一个人……在这么黑的地方……哈哈……", None, "helpless_1"),
        (N, "（手指的动作，忽然轻了一点）"),
        (BLUE, "……哈……哈……没、没关系……", None, "helpless_1"),
        (BLUE, "……是我……自己来的。", None, "sad"),
        (BLUE, "……哈哈……再……再走一段……就好……", "thigh", "helpless_1"),
        (BLUE, "……站、站起来……", None, "angry"),
    ]),
    "f8_maze_weak_4": ("夜迷宫·大腿和屁股", [
        (N, "（大腿和屁股上的手已经多得数不过来了。每走一步，都像有人在后面推着她笑）"),
        (BLUE, "……走……走路……好难。", None, "shy"),
        (N, "（冷光照不到身后。她看不见，也不敢回头看）"),
        (BLUE, "……屁、屁股上……有……几只……", None, "shy"),
        (BLUE, "……不、不想知道。", None, "angry"),
        (N, "（迷宫深处，传来一声很轻的、像是在笑的声音）"),
        FLASH,
        (BLUE, "……笑什么。……不、不许笑。", None, "angry"),
        ACT2,
        (N, "（大腿上的手一起收紧，像是在回答她）"),
        (BLUE, "……唔、嗯……！", "thigh", "helpless_1"),
        (N, "（屁股上的手指，一下、一下地，按着节奏戳）"),
        (BLUE, "……别、别打拍子……！", "butt", "helpless_1"),
        (BLUE, "……看、看不见……节奏……就更……", None, "shy"),
        (N, "（黑暗里，她只能听见自己的心跳——还有手指跟着心跳的节奏，一起落下来）"),
        (BLUE, "……噗……哈……心、心跳……被、被跟上了……", "butt", "helpless_1"),
        CRACK,
        (BLUE, "……不行……这样下去……", None, "shy"),
        ACT3,
        (N, "（大腿内侧和屁股，同时被挠了起来）"),
        (BLUE, "……哈哈哈哈……！上、上下一起……不行……哈哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……屁、屁股……别画圈……哈哈哈……！", "butt", "helpless_2"),
        (BLUE, "……大腿……大腿也……哈哈哈哈哈……！", "thigh", "helpless_2"),
        (N, "（她想跑，腿却软得迈不开。想夹紧，一夹手指就钻得更深）"),
        (BLUE, "……哈哈哈……我、我知道了……知道了……我最怕这里……！", "butt", "helpless_2"),
        (BLUE, "……承认了……承认了……哈哈哈……所以……停……", "thigh", "helpless_2"),
        (N, "（手指停了。真的停了）"),
        (BLUE, "……哈……哈……", None, "helpless_1"),
        (BLUE, "……说了就停……", None, "surprise"),
        (BLUE, "……小时候……也是这样。", None, "sad"),
        (BLUE, "……说「我怕」……你就停。", None, "sad"),
        (BLUE, "……", None, "sad"),
        (BLUE, "……走吧。……刚才那句……收回。", None, "angry"),
    ]),
    "f8_maze_total_12": ("夜迷宫·十二只以上", [
        (N, "（看不见的手把她整个人裹住了。走一步，挠一下；停一下，挠得更凶）"),
        (BLUE, "……冷光……快、快没了。", None, "shy"),
        (N, "（光圈缩到只剩脚边一小片。四面八方都是黑的，四面八方都是手）"),
        (BLUE, "……看不见……全部……都看不见……", None, "shy"),
        (BLUE, "……没、没关系。……闭上眼睛……也一样。", None, "normal"),
        (N, "（她闭上眼——然后发现，闭着眼的时候，身上的每一根手指都清楚得可怕）"),
        (BLUE, "……！……不、不一样……", None, "surprise"),
        FLASH,
        ACT2,
        (BLUE, "……哈、哈……睁、睁开也……闭上也……", "waist", "helpless_1"),
        (N, "（腋下、腰、肚子、脚心、大腿、屁股——十二只手，没有一只是闲着的）"),
        (BLUE, "……哈哈……！全、全身……都……", "armpit", "helpless_1"),
        (BLUE, "……走、走不动了……哈哈哈……", "butt", "helpless_1"),
        CRACK,
        (N, "（她笑得眼泪都出来了，却还是一步一步往前挪）"),
        ACT3,
        (BLUE, "……哈哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……哈哈……我、我投降……投降……", "waist", "helpless_2"),
        (BLUE, "……但、但是……哈哈……不回去……", "sole", "helpless_2"),
        (BLUE, "……答应过……要来的……哈哈哈……", "thigh", "helpless_2"),
        (BLUE, "……你、你……一直在等吧……在这里……一个人……", None, "sad"),
        (N, "（手指忽然一起停了下来。迷宫里安静得只剩她的喘气声）"),
        (BLUE, "……哈……哈……", None, "helpless_1"),
        (BLUE, "……对不起。……让你等了这么久。", None, "sad"),
        (N, "（过了好一会儿，手指才又轻轻地、轻轻地动了起来）"),
        (BLUE, "……噗……哈……好、好……挠吧……", "thigh", "helpless_1"),
        (BLUE, "……我……不躲了。", None, "shy"),
        (N, "（黑暗里，十二只手一起，温柔地、慢慢地挠着她。她一边笑，一边往前走）"),
        (BLUE, "……哈……哈哈……出口……就在前面……对吧……", "butt", "helpless_1"),
        (BLUE, "……带我去。", None, "shy"),
    ]),
    "f8_maze_defeat_1": ("夜迷宫·笑倒", [
        (N, "（冷光灭了。黑暗一下子涌上来，把她整个吞了进去）"),
        (BLUE, "……光……", None, "surprise"),
        (N, "（看不见自己的手，也看不见墙。只能听见四面八方，手指窸窸窣窣地靠过来）"),
        (BLUE, "……别、别过来……", None, "shy"),
        (BLUE, "……我、我还……能走……", None, "angry"),
        FLASH,
        ACT2,
        (N, "（第一只落在大腿上。第二只落在腰上。第三只、第四只……）"),
        (BLUE, "……唔……！……哈……", "thigh", "helpless_1"),
        (BLUE, "……太、太多了……看不见……", "waist", "helpless_1"),
        (N, "（看不见的时候，连哪里被挠都分不清——好像全身都在被挠）"),
        (BLUE, "……哈哈……哪、哪里……到底是哪里……", "butt", "helpless_1"),
        CRACK,
        ACT3,
        (BLUE, "……哈哈哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……不、不行了……哈哈哈哈……", "butt", "helpless_2"),
        (BLUE, "……大腿……屁股……全、全部……哈哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……我、我认输……哈哈哈……认输……！", "waist", "helpless_2"),
        CRACK_LONG,
        (N, "（她瘫坐在冰冷的石板上，笑声慢慢变成了喘气）"),
        (BLUE, "……哈……哈……", None, "helpless_1"),
        (N, "（不知过了多久，一缕月光照在她脸上。身上的手都不见了）"),
        (BLUE, "……月光灯……", None, "sad"),
        (BLUE, "……是你……把我送回来的吗。", None, "sad"),
        (N, "（灯光外的黑暗里，好像有什么在看着她。没有靠近，只是看着）"),
        (BLUE, "……", None, "sad"),
        (BLUE, "……这次不算。", None, "angry"),
        (BLUE, "……再来。", None, "angry"),
    ]),
    "f8_maze_defeat_2": ("夜迷宫·又笑倒了", [
        (N, "（又一次。冷光暗下去的那一刻，她就知道要来了）"),
        (BLUE, "……又是……这里。", None, "shy"),
        (BLUE, "……我、我明明……记住路了。", None, "angry"),
        (N, "（黑暗里传来一声很轻的笑——不是她的）"),
        (BLUE, "……你、你故意的。", None, "angry"),
        FLASH,
        ACT2,
        (N, "（手指从脚踝开始，一路往上爬）"),
        (BLUE, "……唔……！……慢、慢一点……", "thigh", "helpless_1"),
        (BLUE, "……以前……玩捉迷藏……你、你也是这样……", "thigh", "helpless_1"),
        (BLUE, "……躲在黑的地方……等我……", None, "shy"),
        (N, "（手指停在大腿根，轻轻地、一下一下地敲）"),
        (BLUE, "……噗……别、别敲……", "butt", "helpless_1"),
        CRACK,
        ACT3,
        (BLUE, "……哈哈哈……又、又是……这里……", "butt", "helpless_2"),
        (BLUE, "……抓到我……就挠……到我认输……哈哈哈哈……！", "waist", "helpless_2"),
        (BLUE, "……认、认输……我认输……哈哈哈哈……！", "thigh", "helpless_2"),
        (N, "（她笑着笑着，忽然想起——那时候，认输之后，总会被抱起来转一圈）"),
        (BLUE, "……哈哈……现在……不、不准抱……哈哈……", "butt", "helpless_2"),
        (N, "（笑声停下来的时候，她又躺在了月光灯下）"),
        (BLUE, "……哈……", None, "helpless_1"),
        (BLUE, "……捉迷藏。……我输了。", None, "sad"),
        (BLUE, "……下一局。", None, "angry"),
    ]),
    "f8_maze_memory": ("夜迷宫·回忆", [
        (N, "（六片碎片在她手心里一起亮了起来。冷光、月光、碎片的光——迷宫第一次这么亮）"),
        (BLUE, "……亮了。", None, "surprise"),
        (N, "（光里，浮现出很久以前的那个房间。小小的床、蓝色的帷幔、墙上的蜡笔画）"),
        (BLUE, "……蜡笔、发夹、发条、蝴蝶结、茶匙……还有，这张画。", None, "sad"),
        (N, "（画上，一个蓝头发的小女孩被好多只手围着，笑得在地上打滚）"),
        (BLUE, "……那时候……我总说「再来一次」。", None, "sad"),
        ACT2,
        (BLUE, "……挠到我哭……也说「再来一次」。", None, "sad"),
        (BLUE, "……晚上怕黑……你就在床边……一只手、一只手地亮着。", None, "shy"),
        (BLUE, "……像星星。", None, "shy"),
        (BLUE, "……你从来没有累过。……也从来没有真的挠到我讨厌。", None, "shy"),
        (N, "（一只看不见的手，轻轻落在她的头发上——没有挠，只是摸了摸）"),
        (BLUE, "……！", None, "surprise"),
        (BLUE, "……你……还记得这个。", None, "sad"),
        (BLUE, "……哭的时候，你就这样……摸我的头。", None, "sad"),
        (BLUE, "……对不起。……那天，我没有回来。", None, "sad"),
        ACT3,
        (N, "（手停了很久。然后，在她的大腿上，很轻、很轻地挠了一下）"),
        (BLUE, "……噗。……哈……", "thigh", "helpless_1"),
        (BLUE, "……还、还是……那个地方……", "thigh", "helpless_1"),
        CRACK,
        (BLUE, "……哈哈……一点……都没变……", "thigh", "helpless_1"),
        (BLUE, "……嗯。……再来一次。", None, "shy"),
    ]),
    # 第五轮新增：第一次看不清（黑暗敏感）、被夜啼追手抓到（两段轮流）
    "f8_maze_dark_first": ("夜迷宫·看不清", [
        (N, "（冷光暗得只剩脚边一圈。再往外一步，就是什么都看不见的黑）"),
        (BLUE, "……看不清了。", None, "normal"),
        (BLUE, "……没关系。……摸着墙走。", None, "normal"),
        (N, "（手扶上墙的那一刻，墙缝里有什么，轻轻碰了碰她的指尖）"),
        (BLUE, "……！", None, "surprise"),
        ACT2,
        (N, "（看不见的时候，耳朵和皮肤会替眼睛去「看」——风吹过、衣角擦过，全都像是手指）"),
        (BLUE, "……是风。……是风……吧……", "neck", "shy"),
        (BLUE, "……不、不知道……下一下……从哪边来……", "waist", "helpless_1"),
        (N, "（身体自己绷紧了，等着那一下。等得越久，碰到的时候就越痒）"),
        CRACK,
        ACT3,
        (BLUE, "……哈、哈哈……碰、碰一下就……哈哈……", "thigh", "helpless_1"),
        (BLUE, "……太黑了……身体……变奇怪了……", None, "shy"),
        (BLUE, "……找……找月光灯。……快点。", None, "angry"),
    ]),
    "f8_maze_stalker_1": ("夜迷宫·被追上了", [
        (N, "（身后的脚步声——不，是很多很多只手拍在石板上的声音——一下子贴了上来）"),
        (BLUE, "……！", None, "surprise"),
        (N, "（一团长满手臂的影子，从背后把她整个抱住了）"),
        (BLUE, "……放、放开……！", None, "angry"),
        (BLUE, "……看、看不见……你在哪……", None, "shy"),
        ACT2,
        (N, "（手臂一圈一圈地收紧，指尖贴着腰侧和大腿，慢慢地揉）"),
        (BLUE, "……唔……！……抱、抱这么紧……", "waist", "helpless_1"),
        (BLUE, "……跑不掉……", "thigh", "helpless_1"),
        (N, "（影子的两只紫眼睛，就在她耳边。一眨，一眨）"),
        (BLUE, "……别、别在耳边……", "neck", "helpless_1"),
        CRACK,
        ACT3,
        (BLUE, "……哈哈哈……！一、一起揉……哈哈哈哈……！", "waist", "helpless_2"),
        (BLUE, "……大腿……大腿不行……哈哈哈哈……！", "thigh", "helpless_2"),
        (N, "（她笑得没了力气，影子却忽然松开，把两只手轻轻按在了她身上——然后缩回了黑暗里）"),
        (BLUE, "……哈……哈……留、留了两只……", None, "helpless_1"),
        (BLUE, "……下次……憋住。……不出声。", None, "angry"),
    ]),
    "f8_maze_stalker_2": ("夜迷宫·又被追上了", [
        (N, "（她明明憋住了笑。可是身上的手一动，那声「噗」还是漏了出去）"),
        (BLUE, "……！……听、听见了……", None, "surprise"),
        (N, "（下一秒，黑暗里伸出好多手臂，把她拖进了怀里）"),
        (BLUE, "……放……放开……我、我在赶路……", None, "angry"),
        ACT2,
        (N, "（手臂抱着她左右摇晃，像在哄小孩，指尖却一刻也没停）"),
        (BLUE, "……摇、摇什么……唔……！", "butt", "helpless_1"),
        (BLUE, "……又、又是屁股……", "butt", "helpless_1"),
        (BLUE, "……你们……是不是……商量好的……", None, "shy"),
        CRACK,
        ACT3,
        (BLUE, "……哈哈哈……不、不是摇篮……放我下来……哈哈哈哈……！", "thigh", "helpless_2"),
        (BLUE, "……哈哈……认、认输……这次……认输……", "waist", "helpless_2"),
        (N, "（影子把她放回地上，留下两只手，晃了晃手臂，像是在说「下次见」）"),
        (BLUE, "……哈……", None, "helpless_1"),
        (BLUE, "……没有下次。", None, "angry"),
    ]),
}
for tid, (tname, tlines) in MAZE_THEATERS.items():
    (TH / (tid + ".json")).write_text(json.dumps(maze_theater(tname, tlines), ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 第五轮：走出夜迷宫 → 千手过场（在出口原地演）→ 回小屋 → 粉色公主出发
# 过场里的「princess」是当前操控的角色：出口那段是蓝色公主，小屋那段是粉色公主（蓝色公主是 BLUE_NPC）。
# 台词大多 auto 自动推进（气泡、声音、手连着演），关键句才停下来等按键。


def au(sp, text, emo=None, acts=None, sec=None):
    """自动推进的台词：按字数停 1.6~3.8 秒。"""
    st = line(sp, text, emo, acts)
    st["auto"] = sec if sec is not None else round(max(1.6, min(3.8, 1.0 + len(text) * 0.085)), 2)
    return st


def ftk(zone, n=8, iv=0.16, by="boss", fx="hand"):
    return A("tickle", who="princess", by=by, repeat=n, interval=iv, fx=fx, zone=zone)


def cv(zone, n=1):
    return A("cover", who="princess", zone=zone, add=n)


def fburst(text_a, text_b, boss_line, after):
    """一次魔力疲倦爆发：快满 → 爆发（闪光 + 爆发立绘）→ 舒服地松一口气 → 千手趁刚放完最敏感时挠 → 她破防。"""
    return [
        au(BLUE, text_a, "helpless_2", [ftk("thigh", 10, 0.12), ftk("butt", 10, 0.13), A("shake", time=0.6, strength=2.0)]),
        line(BLUE, text_b, "helpless_2", [A("voice", state=""), A("bubble", who="princess", kind="surprise")]),
        {"actions": [A("burst", who="princess", hold=4.0), A("crack", fade=0.4)], "wait": 1.2},
        au(BLUE, after[0], None, [A("bubble", who="princess", kind="shy")], 3.0),
        au(BOSS, boss_line, None, [A("move", who="boss", to=FIN_BOSS_NEAR, time=0.6)]),
        au(BLUE, after[1], "helpless_2", [ftk("thigh", 12, 0.1), ftk("butt", 12, 0.11), A("voice", state="laugh"), A("crack")], 3.2),
    ]


_mz3 = MAZE_INFO[3]
FIN_EXIT = list(_mz3.tile(_mz3.exit_cell, 3))
FIN_BOSS = [FIN_EXIT[0] - 4.8, FIN_EXIT[1] - 4.8]       # 等距画面（视角 0）里正上方：大手悬在她头顶，不盖住她
FIN_BOSS_HIGH = [FIN_BOSS[0] - 3, FIN_BOSS[1] - 3]
FIN_BOSS_NEAR = [FIN_EXIT[0] - 4.0, FIN_EXIT[1] - 4.0]
FIN_CAM = [FIN_EXIT[0] - 1.4, FIN_EXIT[1] - 1.4]   # 她在对话框上方、千手的手在她头顶


def finale(pants):
    steps = [
        # —— 序：出口的光在前面
        {"actions": [A("camera", to=FIN_EXIT, zoom=1.4, time=0.8), A("face", who="princess", dir="up")], "wait": 0.8},
        au(BLUE, "……出口。", "surprise"),
        au(BLUE, "……光。……终于……", "normal"),
        {"actions": [A("fade_out", time=0.12)], "wait": 0.18},
        {"actions": [A("fade_in", time=0.12)], "wait": 0.3},
        {"actions": [A("fade_out", time=0.12)], "wait": 0.18},
        {"actions": [A("fade_in", time=0.2), A("sfx", sound="rumble", volume=-2.0)], "wait": 0.4},
        line(BLUE, "……？", "surprise", [A("bubble", who="princess", kind="question")]),
        {"actions": [A("fade_out", time=0.5)], "wait": 0.6},
        {"actions": [A("spawn", id="boss", kind="monster:thousand_hand", at=FIN_BOSS_HIGH, z=30),
                     A("camera", to=FIN_CAM, zoom=1.0, time=0.1)], "wait": 0.2},
        {"actions": [A("fade_in", time=1.2), A("move", who="boss", to=FIN_BOSS, time=1.8), A("sfx", sound="rumble", volume=0.0),
                     A("shake", time=1.2, strength=2.0)], "wait": 1.8},
        au(N, "（出口的光一下子熄灭了。上方的黑暗里，好多好多只手，慢慢地垂了下来）", sec=3.2),
        line(BOSS, "……你……来……了……"),
        line(BLUE, "……让开。", "angry"),
        au(BOSS, "……不……让……"),
        {"actions": [A("sfx", sound="chant", volume=-6.0), A("bubble", who="princess", kind="angry")], "wait": 0.8},
        au(N, "（她抬起手要放冰晶——手腕先被两只手扣住了，凝起来的冰一下子散成了雪）",
           None, [A("sfx", sound="fizzle"), A("sfx", sound="hand_grab"), A("shake", time=0.3)], 3.4),
        line(BLUE, "……！放、放开。", "surprise"),
        # —— 第一幕：一只一只加手，她强撑冷淡
        au(BOSS, "……一……只……", None, [cv("waist"), ftk("waist", 6, 0.22)]),
        au(BLUE, "……不痒。", "normal"),
        au(BOSS, "……两……只……", None, [cv("armpit"), ftk("armpit", 6, 0.22)]),
        au(BLUE, "……就这种程度。", "normal", [ftk("waist", 6, 0.2)]),
        au(N, "（她面无表情地站着。只有被扣住的手指，悄悄地蜷了一下）", sec=3.0),
        au(BOSS, "……三……只……", None, [cv("thigh"), ftk("thigh", 6, 0.2)]),
        line(BLUE, "……", "shy", [A("bubble", who="princess", kind="dots")]),
        au(BOSS, "……四……只……", None, [cv("butt"), ftk("butt", 6, 0.2)]),
        line(BLUE, "……那、那里……不行。", "shy", [A("shake", time=0.3)]),
        au(N, "（她的声音，第一次抖了一下）", sec=2.2),
        line(BOSS, "……大腿……屁股……你……最怕……"),
        au(BLUE, "……没有。……不怕。", "angry", [ftk("thigh", 8, 0.18)]),
        au(BLUE, "……一点、一点都……", "shy", [ftk("butt", 8, 0.16)]),
        {"actions": [A("crack", volume=-6.0), A("bubble", who="princess", kind="laugh"), A("shake", time=0.3)], "wait": 0.8},
        line(BLUE, "……刚才的，是……打喷嚏。", "angry", [A("cg", key="boss8_resist_1")]),
        au(BOSS, "……是……吗……", None, [cv("thigh"), cv("butt"), ftk("thigh", 10, 0.14)]),
        au(BLUE, "……唔、嗯……！……大、大腿……两只……", "helpless_1", [A("voice", state="giggle")]),
        au(N, "（手指贴着大腿内侧，一节一节地往上走，像在弹一首很慢的曲子）", None, [ftk("thigh", 10, 0.18)], 3.4),
        au(BLUE, "……别、别弹……哈……", "helpless_1", [ftk("butt", 10, 0.14)]),
        au(BLUE, "……魔力……在、在往上涨……", "helpless_1", [A("cg", key="")]),
    ]
    steps += fburst("……不、不行……魔力……要满出来了……", "……压、压不住——！", "……第……一……次……",
                    ["……呼……哈……身体……好轻……", "……哈、哈哈……！刚、刚放完……别碰……哈哈哈……！"])
    steps += [
        au(N, "（魔力像泄洪一样涌出去，带走了疲倦——也带走了她最后一点力气）", sec=3.2),
        line(BLUE, "……刚才的……不算。", "angry", [A("voice", state="")]),
        au(BOSS, "……不……算……？", None, [ftk("thigh", 6, 0.2)]),
        line(BLUE, "……不算。……我、我还没笑。", "angry"),
        # —— 第二幕：破防
        au(BOSS, "……那……再……多……一……点……", None, [cv("thigh", 2), cv("butt", 2), A("cg", key="boss8_resist_2"),
                                                       A("sfx", sound="hand_grab", volume=-2.0)]),
        au(N, "（大腿上四只，屁股上三只。手指一下一下地捏、揉，又沿着腿根画圈）", None, [ftk("thigh", 14, 0.11), ftk("butt", 14, 0.12)], 3.6),
        au(BLUE, "……哈、哈哈……不、不准……一起……", "helpless_1", [A("voice", state="giggle")]),
        au(BLUE, "……哈哈……哈哈哈……！", "helpless_2", [A("voice", state="laugh"), A("crack")]),
        au(N, "（她第一次笑出了声。笑声在出口的石壁之间来回回荡）", sec=3.0),
        line(BOSS, "……你……小时候……也……这样……笑……"),
        au(BLUE, "……！……那、那个……不准说……", "shy", [ftk("thigh", 8, 0.14)]),
        au(BOSS, "……捉……迷……藏……输……了……就……挠……", None, [ftk("butt", 12, 0.12)]),
        au(BLUE, "……哈哈哈……不、不准说……哈哈哈哈……！", "helpless_2", [ftk("thigh", 14, 0.1)]),
        au(BOSS, "……挠……到……你……说……「再……来……一……次」……", None, [A("cg", key="boss8_weak_1"), ftk("butt", 14, 0.1)], 3.4),
        au(BLUE, "……没、没说过……哈哈哈……一次都、都没……哈哈哈哈……！", "helpless_2", [ftk("thigh", 14, 0.1)]),
        au(BLUE, "……魔、魔力……又……", "helpless_2", [A("cg", key="")]),
    ]
    steps += [
        au(BLUE, "……又、又要满了……这么快……", "helpless_2", [ftk("thigh", 12, 0.1), ftk("butt", 12, 0.1), A("shake", time=0.6)]),
        line(BLUE, "……不、不要看……！", "helpless_2", [A("voice", state=""), A("bubble", who="princess", kind="surprise")]),
        {"actions": [A("burst", who="princess", hold=5.0), A("crack", long=True, volume=-2.0)], "wait": 1.4},
        au(BLUE, "……哈……哈……全、全部……放出去了……", None, [A("bubble", who="princess", kind="shy")], 3.0),
        au(N, "（长长的笑声里，她软软地靠在了千手的手臂上）", sec=3.4),
        # 反差萌：想找回冰之公主的样子
        line(BLUE, "……咳。", "normal", [A("crack", fade=1.0)]),
        line(BLUE, "……我是……冰之……", "angry"),
        {"actions": [ftk("thigh", 1, 0.1), A("shake", time=0.25), A("bubble", who="princess", kind="surprise"), A("sfx", sound="pop", pitch=1.6)],
         "wait": 0.3},
        line(BLUE, "……呀！", "surprise"),
        {"actions": [A("wait")], "wait": 2.0},
        line(BLUE, "……刚才那声……也不算。", "shy", [A("bubble", who="princess", kind="shy")]),
        line(BOSS, "……可……爱……"),
        line(BLUE, "……！！……闭、闭嘴……", "shy", [A("bubble", who="princess", kind="angry")]),
        # —— 第三幕：彻底大笑
        au(BOSS, "……那……全……部……", None, [cv("thigh", 2), cv("butt", 2), cv("belly"), cv("neck"), cv("sole"),
                                             A("sfx", sound="rumble"), A("shake", time=0.8, strength=2.0), A("cg", key="boss8_weak_2")], 3.0),
        au(N, "（大腿上六只，屁股上五只，腰、腋下、肚子、脖子、脚心——手指铺满了她的全身）", None,
           [ftk("thigh", 16, 0.08), ftk("butt", 16, 0.09), ftk("waist", 10, 0.12)], 3.6),
        au(BLUE, "……哈哈哈哈哈哈……！", "helpless_2", [A("voice", state="laugh"), A("crack")]),
        au(BLUE, "……好、好痒……好痒啦……哈哈哈哈……！", "helpless_2", [ftk("thigh", 14, 0.08), ftk("butt", 14, 0.09)]),
        au(BLUE, "……我、我认输……认输嘛……哈哈哈哈……！", "helpless_2", [ftk("armpit", 10, 0.1)]),
        au(BOSS, "……再……来……一……次……？", None, [ftk("thigh", 12, 0.09)]),
        line(BLUE, "……哈哈哈……不、不要……哈哈……", "helpless_2", [ftk("butt", 12, 0.09)]),
        line(BLUE, "……再、再来……一次……哈哈哈哈……！", "helpless_2", [ftk("thigh", 14, 0.08), A("crack")]),
        au(N, "（她说出口的那一刻，自己都愣住了。然后，笑得更厉害了）", sec=3.2),
    ]
    steps += fburst("……哈哈……第、第三次……要、要来了……哈哈哈……！", "……哈……哈……——！", "……第……三……次……",
                    ["……嗯……舒服……", "……哈哈哈哈……！刚放完……最、最敏感……哈哈哈哈哈……！"])
    steps += [
        au(N, "（刚放完魔力的身体敏感得不得了。手指一碰，魔力就又涌了上来）", None, [ftk("thigh", 16, 0.07), ftk("butt", 16, 0.08)], 3.2),
        au(BLUE, "……哈哈……又、又满了……连、连着……不行……哈哈哈……！", "helpless_2", [A("shake", time=0.6)]),
        {"actions": [A("burst", who="princess", hold=5.0), A("crack", long=True, volume=-1.0)], "wait": 1.4},
        au(BLUE, "……呼……哈……哈……", None, [A("bubble", who="princess", kind="shy"), A("voice", state="")], 3.0),
        au(N, "（第四次。她整个人软得像一团云，躺在千手的手心里，一边喘气一边止不住地笑）", None, [A("cg", key="boss8_mob")], 3.6),
        line(BOSS, "……这样……笑……的……你……"),
        line(BOSS, "……好……久……没……见……了……"),
        line(BLUE, "……哈……哈……", "helpless_1", [A("cg", key="")]),
        au(N, "（千手的手慢慢松开，一只、一只地散回黑暗里）", None, [A("uncover", who="princess"), A("move", who="boss", to=FIN_BOSS_HIGH, time=2.0)], 3.2),
    ]
    if pants:
        steps += [
            au(N, "（——有几只手没有散去。它们悄悄地缠在她的大腿和屁股上，变成了一层薄薄的、紫色的布）", None,
               [cv("thigh", 2), A("sfx", sound="hand_grab", volume=-10.0)], 4.2),
            au(N, "（她笑得太累了，一点都没有发觉）", sec=2.6),
        ]
    steps += [
        {"actions": [A("despawn", who="boss"), A("pose", emotion="helpless_1")], "wait": 0.6},
        au(BLUE, "……哈……哈哈……停、停不下来……哈哈……", "helpless_1", [A("voice", state="laugh"), A("crack", long=True, volume=-3.0)], 3.0),
        {"actions": [A("fade_out", time=2.4)], "wait": 2.6},
        {"actions": [A("set_flag", flag="f8_maze_finale_seen")], "wait": 0.2},
    ]
    cs = cut("第八层：夜迷宫的出口", steps)
    cs["end_dark"] = True
    return cs


FIN_NAME = {"f8_maze_finale": False, "f8_maze_finale_pants": True}
for fid, pants in FIN_NAME.items():
    (CUT / (fid + ".json")).write_text(json.dumps(finale(pants), ensure_ascii=False, indent="\t") + "\n")
_old_exit = CUT / "f8_maze_exit.json"
if _old_exit.exists():
    _old_exit.unlink()

# —— 回小屋：粉色公主冰封着睡在床上（闭着眼），床尾的小怪在挠她露出来的脚心；蓝色公主回来、赶走它们、解冻；粉色公主瞬间笑醒
DOOR_IN = [7, 9.6]
# 镜头的位置都往下偏一格半：下面三分之一是对话框，床和床尾要露在对话框上方
BED_FOOT = [[2.4, 5.7], [3.4, 5.9], [4.3, 5.6], [2.0, 5.2]]
RET_MON = [("m1", "squirrel"), ("m2", "hedgehog"), ("m3", "caterpillar"), ("m4", "fairy")]


def ptk(by, n=8, iv=0.18, fx="feather"):
    return A("tickle", who="princess", by=by, repeat=n, interval=iv, fx=fx, zone="sole")


def shelter_return(pants):
    setup = [A("lie", who="princess", at=BED_AT, blanket="old_bed_blanket", sleep=True),
             A("spawn", id="ice", kind="prop:ice_bed", at=BED_AT),
             A("move", who=BLUE_NPC, to=DOOR_IN), A("face", who=BLUE_NPC, dir="up"),
             A("camera", to=[4, 6.5], zoom=1.5, time=0.1)]
    for (mid, kind), at in zip(RET_MON, BED_FOOT):
        setup.append(A("spawn", id=mid, kind="monster:" + kind, at=at, dir="up"))
    steps = [
        {"actions": [A("fade_out", time=0.0)] + setup, "wait": 0.3},
        {"actions": [A("fade_in", time=1.6), A("crack", fade=2.5)], "wait": 1.4},
        au(N, "（小屋里静悄悄的。只有冰床那一头，传来细细的、窸窸窣窣的声音）", None, [ptk("m1", 6, 0.3)], 3.2),
        au(P, "……唔嘿……嘿嘿……", "shy", [A("shake", who="princess", time=0.3), ptk("m2", 6, 0.25, "brush")]),
        au(N, "（几只小怪围在床尾，正一下一下地挠着冰外面露出来的脚心）", None,
           [A("hop", who="m1"), A("hop", who="m3"), ptk("m3", 8, 0.2, "crawl")], 3.2),
        au(P, "……嘻……别……饼干……不、不要挠……嘿嘿嘿……", "shy", [ptk("m4", 8, 0.2), A("shake", time=0.3)]),
        {"actions": [A("sfx", sound="door"), A("camera", to=[5.5, 7.8], zoom=1.35, time=0.8)], "wait": 0.6},
        {"actions": [A("move", who=BLUE_NPC, to=[7, 7.6], speed=18)], "wait": 2.0},
        au(N, "（门开了。蓝色公主扶着门框，慢慢地走了进来。脚步有点晃）", sec=3.0),
    ]
    if pants:
        steps += [
            {"actions": [A("buff", who=BLUE_NPC, id="thousand_pants"), A("face", who=BLUE_NPC, dir="down"),
                         A("sfx", sound="hand_grab", volume=-8.0)], "wait": 0.6},
            line(BLUE, "……？", "surprise"),
            au(BLUE, "……腿上……有什么……", "shy", [A("say", who=BLUE_NPC, text="……？")]),
            au(N, "（大腿上紧紧的，像是穿着什么。低头一看——一层薄薄的紫色，从屁股一直裹到大腿）", sec=3.6),
            {"actions": [A("crack", volume=-8.0), A("say", who=BLUE_NPC, text="……噗。")], "wait": 0.9},
            line(BLUE, "……动、动了……这个……在动……", "shy"),
            {"actions": [A("item", id="thousand_pants"), A("set_flag", flag="blue_tickle_pants"),
                         A("hint", text="获得关键道具：千手痒痒裤")], "wait": 1.2},
            au(BLUE, "……之后……再说。", "angry"),
        ]
    steps += [
        {"actions": [A("face", who=BLUE_NPC, dir="left")], "wait": 0.4},
        line(BLUE, "……！", "surprise", [A("say", who=BLUE_NPC, text="！")]),
        line(BLUE, "……离她远点。", "angry"),
        {"actions": [A("sfx", sound="chant", volume=-4.0), A("say", who=BLUE_NPC, text="……冰。")], "wait": 0.9},
        {"actions": [A("flash", time=0.5), A("sfx", sound="star_burst"), A("shake", time=0.4)]
         + [A("hop", who=mid) for mid, _k in RET_MON], "wait": 0.5},
        {"actions": [A("move", who=mid, to=[7, 10.5], speed=90) for mid, _k in RET_MON], "wait": 1.2},
        {"actions": [A("despawn", who=mid) for mid, _k in RET_MON] + [A("sfx", sound="door_close", volume=-4.0)], "wait": 0.4},
        au(N, "（被冻得一跳的小怪们，吱吱叫着，一溜烟逃出了门）", sec=2.8),
        {"actions": [A("move", who=BLUE_NPC, to=[4.2, 5.6], speed=26), A("camera", to=[3.5, 6.5], zoom=1.6, time=1.2)], "wait": 1.6},
        {"actions": [A("face", who=BLUE_NPC, dir="up")], "wait": 0.3},
        au(BLUE, "……没事了。", "sad"),
        au(BLUE, "……我回来了。", "sad"),
        {"actions": [A("sfx", sound="ice_crack"), A("flash", time=0.4), A("despawn", who="ice"), A("shake", time=0.3)], "wait": 0.8},
        au(N, "（冰面「咔嚓」一声裂开，碎成一片闪闪发光的小冰粒）", sec=2.8),
        # 粉色公主瞬间被笑醒
        {"actions": [A("lie", who="princess", sleep=False, laugh="helpless_2"), A("voice", state="laugh"),
                     A("bubble", who="princess", kind="laugh"), A("shake", who="princess", time=0.6)], "wait": 0.4},
        au(P, "噗——哈哈哈哈哈！好痒——为、为什么脚心这么痒啊哈哈哈！", "helpless_2", [A("shake", time=0.5)], 3.2),
        au(P, "哈哈哈……我、我刚才梦见一大堆羽毛追着我……一直挠一直挠……停不下来……哈哈哈……", "helpless_2", None, 3.8),
        au(P, "呼……呼……脚心……到现在还麻麻的……嘻嘻……", "giggle", [A("voice", state="giggle")], 3.0),
        {"actions": [A("voice", state=""), A("lie", who="princess", on=False), A("move", who="princess", to=[3, 5.6], time=0.4),
                     A("face", who="princess", dir="right"), A("pose", emotion="surprise")], "wait": 0.6},
        line(P, "……啊！你回来啦！", "happy"),
        line(P, "……刚才，是不是有什么东西挠我的脚？", "surprise"),
        {"actions": [A("bubble", who=BLUE_NPC, kind="sweat"), A("face", who=BLUE_NPC, dir="right")], "wait": 0.6},
        line(BLUE, "……不知道。……大概……是做梦。", "normal"),
        {"actions": [A("crack", volume=-9.0), A("say", who=BLUE_NPC, text="……噗。")], "wait": 1.0},
        au(N, "（蓝色公主别过脸，肩膀一抖一抖的）", sec=2.4),
        line(P, "……？你刚才是不是笑了？", "surprise"),
        line(BLUE, "……没有。", "normal"),
    ]
    if pants:
        steps += [
            {"actions": [A("face", who="princess", dir="right")], "wait": 0.3},
            line(P, "……咦？你腿上那个紫紫的是什么？", "surprise"),
            {"actions": [A("bubble", who=BLUE_NPC, kind="sweat")], "wait": 0.5},
            line(BLUE, "……没什么。……别看。", "shy"),
            {"actions": [A("crack", volume=-6.0), A("say", who=BLUE_NPC, text="……唔、噗……！")], "wait": 1.0},
            line(P, "你、你又笑了！腿还抖了一下！", "surprise"),
            line(BLUE, "……没有。……是冷。", "angry"),
        ]
    steps += [
        {"actions": [A("face", who=BLUE_NPC, dir="left")], "wait": 0.3},
        line(BLUE, "……已经没事了。……我在。", "sad"),
        {"actions": [A("crack", volume=-10.0), A("say", who=BLUE_NPC, text="……嘻。")], "wait": 0.9},
        line(P, "……嗯。……谢谢你。", "shy"),
        line(P, "总觉得……你看起来好累哦。去了哪里？", "sad"),
        line(BLUE, "……散步。", "normal"),
        line(P, "骗人——！", "angry"),
        line(P, "……算啦。走吧！我们一起出去！", "happy"),
        line(BLUE, "……嗯。……一起。", "shy"),
        {"actions": [A("camera", reset=True, time=0.6), A("set_flag", flag="f8_returned")], "wait": 0.6},
    ]
    return cut("第八层：回到小屋", steps)


for rid, pants in {"f8_shelter_return": False, "f8_shelter_return_pants": True}.items():
    (CUT / (rid + ".json")).write_text(json.dumps(shelter_return(pants), ensure_ascii=False, indent="\t") + "\n")

print("第八层：%d 段过场、%d 段战败小剧场 + 追逐失败" % (len(CUTS), len(DEFEAT) + 1))
