"""生成小镇攻防战（levels/floor_06_siege，「地下小镇·攻防战」）和它的数据。
  地图 110×80（从上往下）：
    第 1~5 行   小镇边缘（烧焦的房子、路障、火堆）
    第 6~7 行   城墙顶走道（蓝色公主站的地方）
    第 8~9 行   城墙墙面（8 段 SiegeWall，放在第 10 行、节点往上挪一格贴着墙下沿）
    第 10 行起  墙下：梯子（两头 + 城门）、号角、粉色公主的出生点 / 复活点（spawn gate）
    第 11~16 行 待建区（冰塔格 buildpad）
    第 17~62 行 战场（碎石、沙袋、木桩；随机冒怪的地洞 spawn siege_hole_*）
    第 63~78 行 敌方区域（敌塔地基 enemysite；底边出怪 siege_bottom_*，左右出怪 siege_left_* / siege_right_*）
  数据：
    data/siege/waves.json   城墙血量、准备时间、同时在场上限、怪物表、10 波
    data/siege/intel.json   战场情报（新怪 / 冰塔 / 敌塔 / 陷阱 / 临时装备的简介、机制、应对）
    data/cutscenes/floor_06/siege_intro.json / siege_won.json
  怪物表只写已经有场景的怪（还没做的攻城怪先跳过，波次里也跳过），所以每个阶段生成出来的数据都能直接用。
用法：python tools/build/gen_floor06_siege.py，然后 build_level.gd -- floor=floor_06_siege
"""
import json
import os
import random
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

FID = "floor_06_siege"
W, H = 110, 80
WALL_ROWS = (8, 9)
GATE_X = 54
POOL = list("ACDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrsuvwyz0123456789!?$&*+-/:;<>@^_|~()'=,`{}\"")
POOL += list("αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥金木水火土日月山川")
P, BLUE, CAP, N = "公主", "蓝色的公主", "保卫队队长", ""

g = [["#"] * W for _ in range(H)]
cells = {}


def room(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "."


def put(x, y, spec):
    cells.setdefault((x, y), []).append(spec)


def prop(x, y, kind):
    put(x, y, "prop type=" + kind)


room(1, 1, W - 2, H - 2)
for y in WALL_ROWS:
    for x in range(1, W - 1):
        g[y][x] = "#"
# —— 小镇边缘
for i, x in enumerate(range(8, W - 6, 14)):
    prop(x, 3, ["house_burnt_0", "house_1", "house_burnt_1", "house_2"][i % 4])
for x in range(5, W - 4, 9):
    prop(x, 5, ["fire_small", "barricade", "sandbag", "lamp"][(x // 9) % 4])
put(GATE_X - 2, 3, "siege")
# —— 城墙（8 段）、梯子、号角、出生点
SEG = (W - 2) / 8.0
for i in range(8):
    cx = 1 + SEG * (i + 0.5)
    put(int(cx), 10, "siegewall index=%d w=%s" % (i, round(SEG, 2)))
for x in (6, GATE_X, W - 7):
    put(x, 10, "siegeladder" + (" gate=true" if x == GATE_X else ""))
put(GATE_X - 3, 11, "siegehorn")
put(GATE_X, 12, "spawn id=gate")
put(GATE_X, 13, "player")
put(GATE_X + 3, 7, "blue_princess")
# —— 战场：碎石、沙袋、木桩（少量，不挡路）
rnd = random.Random(1066)
for _ in range(26):
    x, y = rnd.randint(4, W - 5), rnd.randint(19, 60)
    if (x, y) not in cells:
        prop(x, y, rnd.choice(["rubble", "sandbag", "decal_scorch_0", "decal_ash_0", "decal_scorch_1", "decal_footprints_0"]))
# —— 出怪点
for i, x in enumerate(range(6, W - 5, 8)):
    put(x, H - 3, "spawn id=siege_bottom_%d" % i)
for i, y in enumerate(range(28, 72, 6)):
    put(2, y, "spawn id=siege_left_%d" % i)
    put(W - 3, y, "spawn id=siege_right_%d" % i)
for i, (x, y) in enumerate([(14, 26), (40, 30), (70, 28), (95, 26), (24, 40), (56, 42), (86, 40), (10, 52), (38, 54),
                            (66, 56), (98, 52), (52, 34)]):
    put(x, y, "spawn id=siege_hole_%d" % i)
    prop(x, y + 1, "decal_ash_1")

specs, pool = {}, list(POOL)
fixed = {"player": "P"}
for (x, y), sp in cells.items():
    spec = " + ".join(sp)
    ch = fixed.get(spec) or specs.get(spec)
    if ch is None:
        ch = specs[spec] = pool.pop(0)
    g[y][x] = ch
head = ("[level]\n# 地下小镇·攻防战（tools/build/gen_floor06_siege.py 生成，不要直接改）\nintro =\nintro_cutscene = siege_intro\n"
        "ambient = 0.62,0.5,0.52\n[legend]\n# = wall\n. = floor\nP = player\n")
legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
out = Path("levels") / FID
out.mkdir(parents=True, exist_ok=True)
(out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
(out / "design.json").write_text(json.dumps({"_说明": [
    "小镇攻防战（gen_floor06_siege.py 生成）：上方城墙（8 段、共用总血量），蓝色公主在墙顶，粉色公主在墙下；10 波，城墙破了放失败小剧场后重来。"]},
    ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 怪物表 + 波次
MONSTERS = {
    # 杂兵（已有的怪）
    "slime": "res://scenes/actors/monsters/slime.tscn",
    "rat": "res://scenes/actors/monsters/foot_rat.tscn",
    "caterpillar": "res://scenes/actors/monsters/caterpillar.tscn",
    "fairy": "res://scenes/actors/monsters/fairy_swarm.tscn",
    "squirrel": "res://scenes/actors/monsters/brush_squirrel.tscn",
    "hedgehog": "res://scenes/actors/monsters/brush_hedgehog.tscn",
    "spider": "res://scenes/actors/monsters/tickle_spider.tscn",
    "glove": "res://scenes/actors/monsters/ghost_glove.tscn",
    # 攻城怪（scenes/siege/monsters/，阶段 5 做）
    "cart": "res://scenes/siege/monsters/siege_cart.tscn",
    "hook": "res://scenes/siege/monsters/hook_climber.tscn",
    "vine": "res://scenes/siege/monsters/bind_vine.tscn",
    "gecko": "res://scenes/siege/monsters/wall_gecko.tscn",
    "shield_crab": "res://scenes/siege/monsters/shield_crab.tscn",
    "bat_swarm": "res://scenes/siege/monsters/feather_bat_swarm.tscn",
    "carrier": "res://scenes/siege/monsters/carrier_imps.tscn",
    "warm_slime": "res://scenes/siege/monsters/warm_slime.tscn",
    "thigh_spider": "res://scenes/siege/monsters/thigh_spider.tscn",
    "hug_bear": "res://scenes/siege/monsters/hug_bear.tscn",
    "suck_jelly": "res://scenes/siege/monsters/suck_jelly.tscn",
    "twin_ghost": "res://scenes/siege/monsters/twin_ghost.tscn",
}
have = {k: v for k, v in MONSTERS.items() if Path(v.replace("res://", "")).exists()}


def G(monster, count, frm="bottom", interval=1.0, delay=0.0):
    return {"monster": monster, "count": count, "from": frm, "interval": interval, "delay": delay}


WAVES = [
    {"name": "小怪潮", "reward": 14, "groups": [G("slime", 12, "bottom", 1.4), G("rat", 8, "bottom", 1.6, 6), G("slime", 6, "hole", 2.0, 14)]},
    {"name": "钩索与壁虎", "reward": 16, "groups": [G("slime", 10, "bottom", 1.2), G("caterpillar", 8, "left", 1.5, 4),
                                                    G("hook", 4, "bottom", 4.0, 8), G("gecko", 10, "right", 1.2, 12)]},
    {"name": "攻城痒痒车", "reward": 18, "groups": [G("rat", 12, "bottom", 1.0), G("squirrel", 8, "hole", 1.5, 5),
                                                   G("cart", 2, "bottom", 14.0, 10), G("slime", 10, "left", 1.0, 16)]},
    {"name": "捆绑藤怪", "reward": 18, "groups": [G("caterpillar", 12, "bottom", 1.0), G("vine", 6, "hole", 3.0, 6),
                                                 G("fairy", 8, "right", 1.4, 10), G("hug_bear", 3, "bottom", 5.0, 14)]},
    {"name": "大波次：怪物潮", "reward": 26, "groups": [G("slime", 18, "bottom", 0.6), G("rat", 14, "left", 0.8, 4),
                                                      G("squirrel", 10, "right", 0.9, 8), G("hook", 5, "bottom", 3.0, 10),
                                                      G("gecko", 10, "hole", 1.0, 14), G("cart", 2, "bottom", 12.0, 18)]},
    {"name": "盾甲螃蟹与拥抱小熊", "reward": 22, "groups": [G("shield_crab", 6, "bottom", 3.0), G("hug_bear", 6, "left", 3.0, 4),
                                                         G("hedgehog", 10, "hole", 1.2, 6), G("spider", 10, "right", 1.0, 10),
                                                         G("slime", 14, "bottom", 0.8, 14)]},
    {"name": "暖炉与搬运小鬼", "reward": 24, "groups": [G("rat", 18, "bottom", 0.7), G("fairy", 12, "hole", 1.0, 4),
                                                      G("warm_slime", 6, "left", 3.0, 8), G("carrier", 3, "right", 8.0, 10),
                                                      G("bat_swarm", 6, "bottom", 2.5, 14), G("vine", 4, "hole", 4.0, 18)]},
    {"name": "魔力吸吸水母", "reward": 26, "groups": [G("suck_jelly", 6, "bottom", 3.0), G("thigh_spider", 8, "right", 2.0, 4),
                                                    G("bat_swarm", 8, "left", 2.0, 6), G("glove", 12, "hole", 1.0, 8),
                                                    G("gecko", 14, "bottom", 0.8, 10), G("cart", 2, "bottom", 15.0, 20)]},
    {"name": "狂欢与共振", "reward": 30, "groups": [G("slime", 20, "bottom", 0.5), G("thigh_spider", 10, "hole", 1.5, 4),
                                                  G("twin_ghost", 3, "bottom", 8.0, 6), G("hook", 6, "left", 2.5, 8),
                                                  G("hug_bear", 6, "right", 2.5, 10), G("warm_slime", 6, "hole", 2.5, 14),
                                                  G("vine", 6, "bottom", 3.0, 16), G("cart", 3, "bottom", 10.0, 18),
                                                  G("squirrel", 20, "left", 0.6, 20)]},
    {"name": "最终波：全部一起上", "reward": 40, "groups": [G("slime", 26, "bottom", 0.4), G("rat", 20, "left", 0.5, 2),
                                                        G("squirrel", 16, "right", 0.6, 4), G("hook", 8, "bottom", 2.0, 6),
                                                        G("gecko", 16, "hole", 0.7, 8), G("shield_crab", 6, "bottom", 3.0, 10),
                                                        G("bat_swarm", 8, "left", 2.0, 12), G("carrier", 3, "right", 8.0, 14),
                                                        G("warm_slime", 6, "hole", 2.5, 16), G("thigh_spider", 8, "bottom", 2.0, 18),
                                                        G("hug_bear", 6, "left", 2.5, 20), G("suck_jelly", 6, "right", 2.5, 22),
                                                        G("twin_ghost", 4, "bottom", 6.0, 24), G("vine", 6, "hole", 3.0, 26),
                                                        G("cart", 4, "bottom", 9.0, 28)]},
]
for i, w in enumerate(WAVES):
    w["groups"] = [gr for gr in w["groups"] if gr["monster"] in have]
    w["theater"] = "siege_fail_%d" % (i + 1)
WAVE_DATA = {"_说明": ["小镇攻防战的波次（gen_floor06_siege.py 生成；SiegeDirector 读）。怪物表只有已经做好的怪。"],
             "wall_hp": 2400, "prep_first": 30, "prep": 20, "alive_cap": 90, "start_crystals": 24,
             "monsters": have, "waves": WAVES}
Path("data/siege").mkdir(parents=True, exist_ok=True)
Path("data/siege/waves.json").write_text(json.dumps(WAVE_DATA, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 战场情报
INTEL = {}
Path("data/siege/intel.json").write_text(json.dumps({"_说明": ["战场情报（gen_floor06_siege.py 生成；SiegeIntel 读）。"], **INTEL},
                                                   ensure_ascii=False, indent="\t") + "\n")


# ================================================================ 过场
def A(do, **kw):
    kw["do"] = do
    return kw


def line(sp, text, emotion=None, actions=None):
    s = {"speaker": sp, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    return s


INTRO = {"name": "攻防战：开始", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("fade_in", time=0.8), A("camera", to=[GATE_X, 20], zoom=0.8, time=0.1)], "wait": 0.8},
    {"actions": [A("camera", to=[GATE_X, 40], zoom=0.8, time=2.0)], "wait": 2.0},
    line(N, "（城墙外面，一大片开阔地。远处的黑暗里，怪物的眼睛一对一对地亮起来）"),
    {"actions": [A("camera", to=[GATE_X, 9], zoom=1.2, time=1.2)], "wait": 1.2},
    line(BLUE, "……我在城墙上。远的，交给我。"),
    line(P, "那下面的就交给我！", "happy"),
    line(BLUE, "……冰塔格，你站上去按 E。……我从上面放冰，一起造。"),
    line(P, "嗯！还有——要是你被挠下来了，我就去救你！", "happy"),
    line(BLUE, "……不会被挠下来。", "angry"),
    {"actions": [A("hint", text="C 切换操控；蓝色公主：L 瞄准施法；H 查看新情报；城门口的号角可以提前开打")], "wait": 0.2},
    {"actions": [A("set_flag", flag="siege_intro_seen")], "wait": 0.1},
]}
WON = {"name": "攻防战：胜利", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("camera", to=[GATE_X, 30], zoom=0.9, time=1.0)], "wait": 1.0},
    line(N, "（最后一只怪物逃回了黑暗里。战场上安静下来，只剩下冰塔的光）"),
    line(P, "我们……守住了！", "happy"),
    line(BLUE, "……嗯。……守住了。"),
    line(N, "（待续）"),
    {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
    {"actions": [A("goto", to="floor_06_war", spawn="from_siege")], "wait": 0.1},
]}
cut = Path("data/cutscenes/floor_06")
(cut / "siege_intro.json").write_text(json.dumps(INTRO, ensure_ascii=False, indent="\t") + "\n")
(cut / "siege_won.json").write_text(json.dumps(WON, ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
entry = {"id": FID, "name": "地下小镇·攻防战", "scene": "res://levels/%s/floor.tscn" % FID, "group": "floor_06",
         "music": "siege" if Path("assets/audio/music/siege_loop.wav").exists() else "boss"}
for i, f in enumerate(lst):
    if f["id"] == FID:
        lst[i] = entry
        break
else:
    i = next(i for i, f in enumerate(lst) if f["id"] == "floor_06_war") + 1
    lst.insert(i, entry)
Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("%s：%dx%d，图例 %d 种；怪物 %d 种，10 波（共 %d 只）" % (FID, W, H, len(specs), len(have),
                                                     sum(gr["count"] for w in WAVES for gr in w["groups"])))
