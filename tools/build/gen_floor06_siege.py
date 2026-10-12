"""生成小镇攻防战（levels/floor_06_siege，「地下小镇·攻防战」）和它的数据。
  地图 110×80（从上往下）：
    第 1~5 行   小镇边缘（烧焦的房子、路障、火堆）
    第 6~7 行   城墙顶走道（蓝色公主站的地方）
    第 8~9 行   城墙墙面（8 段 SiegeWall，放在第 10 行、节点往上挪一格贴着墙下沿）
    第 10 行起  墙下：梯子（两头 + 城门）、号角、粉色公主的出生点 / 复活点（spawn gate）
    第 11~16 行 墙下（粉色公主按 B 随处建冰塔；士兵的岗位）
    第 17~62 行 战场（碎石、沙袋、木桩；随机冒怪的地洞 spawn siege_hole_*）
    第 63~78 行 敌方区域（敌塔地基 enemysite；底边出怪 siege_bottom_*，左右出怪 siege_left_* / siege_right_*）
  数据：
    data/siege/waves.json   城墙血量、准备时间、怪物表、12 波（每波出完怪倒计时 countdown 秒自动进下一波）
    data/siege/town_buffs.json  镇民支援（每波固定一个 buff）
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
# （冰塔不再有固定格子：粉色公主在战场上按 B 随处建）
# —— 敌塔地基：全地图都有（战场 + 敌方区域，离城墙最近 4 格），地精工兵挑最近的空地基搭塔
_srnd = random.Random(2828)
SITES = []
for gy in range(15, 78, 9):
    for gx in range(9, W - 6, 20):
        x, y = gx + _srnd.randint(-3, 3), gy + _srnd.randint(-1, 2)
        if 1 < x < W - 2 and 14 <= y < H - 2 and not (abs(x - GATE_X) < 6 and y < 20):
            SITES.append((x, y))
for i, (x, y) in enumerate(SITES):
    put(x, y, "enemysite index=%d" % i)
# —— 战场：碎石、沙袋、木桩（少量，不挡路）
rnd = random.Random(1066)
for _ in range(26):
    x, y = rnd.randint(4, W - 5), rnd.randint(19, 60)
    if (x, y) not in cells and all(abs(x - sx) > 3 or abs(y - sy) > 3 for sx, sy in SITES):
        prop(x, y, rnd.choice(["rubble", "sandbag", "decal_scorch_0", "decal_ash_0", "decal_scorch_1", "decal_footprints_0"]))
# —— 出怪点
for i, x in enumerate(range(6, W - 5, 8)):
    put(x, H - 3, "spawn id=siege_bottom_%d" % i)
for i, y in enumerate(range(28, 72, 6)):
    put(5, y, "spawn id=siege_left_%d" % i)       # 往里挪 3 格：怪不会贴着地图边走
    put(W - 6, y, "spawn id=siege_right_%d" % i)
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
    # 第二轮加入的已有怪物
    "bat": "res://scenes/actors/monsters/feather_bat.tscn",
    "ghost": "res://scenes/actors/monsters/tickle_ghost.tscn",
    "troll": "res://scenes/actors/monsters/tickle_troll.tscn",
    "crab": "res://scenes/actors/monsters/pincer_crab.tscn",
    "split_slime": "res://scenes/actors/monsters/split_slime.tscn",
    "mana_jelly": "res://scenes/actors/monsters/mana_jelly.tscn",
    "bubble_fish": "res://scenes/actors/monsters/bubble_fish.tscn",
    "imp": "res://scenes/actors/monsters/machine_imp.tscn",
    "frog": "res://scenes/actors/monsters/tongue_frog.tscn",
    "octopus": "res://scenes/actors/monsters/suction_octopus.tscn",
    "barnacle": "res://scenes/actors/monsters/barnacle.tscn",
    "mini_tentacle": "res://scenes/actors/monsters/mini_tentacle.tscn",
    "goblin_engineer": "res://scenes/siege/monsters/goblin_engineer.tscn",
    "troll_general": "res://scenes/siege/monsters/troll_general.tscn",
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
# 第三轮：加第 11、12 波
WAVES += [
    {"name": "钢铁与羽毛", "reward": 44, "groups": [G("shield_crab", 8, "bottom", 2.0), G("cart", 4, "bottom", 8.0, 4),
                                                  G("bat_swarm", 10, "left", 1.5, 6), G("hook", 8, "right", 2.0, 8),
                                                  G("gecko", 18, "hole", 0.6, 10), G("hug_bear", 8, "bottom", 2.0, 12),
                                                  G("thigh_spider", 10, "right", 1.5, 14), G("slime", 28, "bottom", 0.4, 16)]},
    {"name": "终极攻城：全军压上", "reward": 60, "groups": [G("slime", 30, "bottom", 0.35), G("rat", 24, "left", 0.4, 2),
                                                        G("squirrel", 18, "right", 0.5, 4), G("hook", 10, "bottom", 1.6, 6),
                                                        G("gecko", 20, "hole", 0.6, 8), G("shield_crab", 8, "bottom", 2.5, 10),
                                                        G("bat_swarm", 10, "left", 1.6, 12), G("carrier", 4, "right", 7.0, 14),
                                                        G("warm_slime", 8, "hole", 2.0, 16), G("thigh_spider", 10, "bottom", 1.6, 18),
                                                        G("hug_bear", 8, "left", 2.0, 20), G("suck_jelly", 8, "right", 2.0, 22),
                                                        G("twin_ghost", 5, "bottom", 5.0, 24), G("vine", 8, "hole", 2.5, 26),
                                                        G("cart", 6, "bottom", 7.0, 28)]},
]
# —— 第二轮：怪物 3 倍、加入更多已有怪物、成套生成（配合技）、地精工兵队、陷阱 3 倍 + 陷阱组合
# —— 第三轮：再 ×2（MULT 3 → 6；EXTRA / 成套 / 陷阱组合也 ×2）
MULT = 6
EXTRA = {   # 每波额外的已有怪物
    1: [G("bat", 4, "left", 2.0, 8), G("frog", 3, "hole", 3.0, 12)],
    2: [G("ghost", 4, "hole", 2.0, 6), G("crab", 4, "bottom", 2.0, 10), G("split_slime", 3, "right", 3.0, 14)],
    3: [G("troll", 2, "bottom", 8.0, 6), G("bubble_fish", 4, "left", 2.0, 10), G("octopus", 2, "right", 6.0, 12)],
    4: [G("glove", 4, "hole", 2.0, 6), G("ghost", 4, "hole", 2.0, 8), G("barnacle", 4, "bottom", 2.0, 12), G("mana_jelly", 2, "left", 5.0, 14)],
    5: [G("troll", 3, "bottom", 6.0, 6), G("imp", 4, "right", 2.0, 8), G("hedgehog", 6, "hole", 1.5, 10), G("mini_tentacle", 4, "hole", 2.0, 16)],
    6: [G("bat", 8, "left", 1.0, 4), G("frog", 4, "right", 2.0, 8), G("octopus", 3, "bottom", 4.0, 10), G("barnacle", 6, "bottom", 1.5, 12)],
    7: [G("bubble_fish", 6, "hole", 1.5, 4), G("caterpillar", 6, "hole", 1.5, 6), G("mana_jelly", 3, "left", 4.0, 10), G("split_slime", 4, "right", 2.0, 14)],
    8: [G("glove", 6, "hole", 1.5, 4), G("ghost", 6, "hole", 1.5, 6), G("troll", 3, "bottom", 6.0, 10), G("imp", 6, "left", 1.5, 12)],
    9: [G("crab", 8, "bottom", 1.0, 4), G("frog", 6, "right", 1.5, 8), G("bat", 10, "left", 0.8, 10), G("mini_tentacle", 6, "hole", 1.5, 14)],
    10: [G("troll", 4, "bottom", 5.0, 4), G("octopus", 4, "right", 3.0, 6), G("barnacle", 8, "bottom", 1.0, 8), G("bubble_fish", 8, "hole", 1.0, 10),
         G("glove", 8, "hole", 1.0, 12), G("ghost", 8, "hole", 1.0, 14), G("mana_jelly", 4, "left", 3.0, 16)],
    11: [G("troll", 4, "bottom", 4.0, 4), G("ghost", 10, "hole", 1.0, 6), G("glove", 10, "hole", 1.0, 8), G("frog", 8, "right", 1.2, 10),
         G("crab", 10, "bottom", 1.0, 12), G("mana_jelly", 4, "left", 3.0, 14)],
    12: [G("troll", 6, "bottom", 3.0, 4), G("octopus", 6, "right", 2.0, 6), G("barnacle", 10, "bottom", 0.8, 8), G("bubble_fish", 10, "hole", 0.8, 10),
         G("glove", 10, "hole", 0.8, 12), G("ghost", 10, "hole", 0.8, 14), G("mana_jelly", 6, "left", 2.0, 16), G("imp", 8, "right", 1.0, 18)],
}
for _n, _gs in EXTRA.items():
    for _g in _gs:
        _g["count"] *= 2


def F(formation, count, frm="bottom", interval=10.0, delay=0.0):
    return {"formation": formation, "count": count, "from": frm, "interval": interval, "delay": delay}


FORMATIONS = {   # 成套生成的配合技（data/teamwork.json）
    2: [F("gecko_ladder", 1, "bottom", 0, 16), F("slime_merge", 2, "hole", 12, 8)],
    3: [F("cart_escort", 1, "bottom", 0, 20), F("troll_throw", 1, "bottom", 0, 12), F("strip_shoes", 1, "hole", 0, 14)],
    4: [F("raise_arms", 2, "hole", 15, 8), F("suction_chain", 1, "right", 0, 12), F("gecko_ladder", 1, "bottom", 0, 22)],
    5: [F("cart_escort", 2, "bottom", 14, 10), F("bat_airdrop", 2, "left", 12, 8), F("feather_dance", 2, "hole", 15, 12), F("jelly_charge", 1, "left", 0, 16)],
    6: [F("hedgehog_roll", 2, "hole", 14, 6), F("bubble_chain", 2, "hole", 14, 10), F("strip_shoes", 2, "hole", 12, 14)],
    7: [F("slime_merge", 3, "bottom", 10, 6), F("bat_airdrop", 2, "right", 12, 10), F("gecko_ladder", 2, "bottom", 14, 14), F("troll_throw", 2, "bottom", 14, 18)],
    8: [F("raise_arms", 3, "hole", 10, 6), F("suction_chain", 2, "right", 12, 10), F("feather_dance", 2, "hole", 12, 12), F("jelly_charge", 2, "left", 14, 16)],
    9: [F("cart_escort", 2, "bottom", 10, 8), F("hedgehog_roll", 2, "hole", 10, 10), F("bubble_chain", 2, "hole", 10, 12), F("gecko_ladder", 1, "bottom", 12, 14)],
    10: [F(t, 1, "bottom" if t in ("cart_escort", "gecko_ladder", "troll_throw") else "hole", 9, 4 + i * 3)
         for i, t in enumerate(["cart_escort", "gecko_ladder", "troll_throw", "slime_merge", "raise_arms", "strip_shoes", "suction_chain",
                                "feather_dance", "bubble_chain", "jelly_charge", "hedgehog_roll", "bat_airdrop"])],
}
for _n in (11, 12):
    FORMATIONS[_n] = [F(t, 1, "bottom" if t in ("cart_escort", "gecko_ladder", "troll_throw") else "hole", 8, 3 + i * 2.5)
                      for i, t in enumerate(["cart_escort", "gecko_ladder", "troll_throw", "slime_merge", "raise_arms", "strip_shoes",
                                             "suction_chain", "feather_dance", "bubble_chain", "jelly_charge", "hedgehog_roll", "bat_airdrop"])]
for _n, _fs in FORMATIONS.items():
    for _f in _fs:
        _f["count"] *= 2
        _f["interval"] = max(4.0, _f["interval"] * 0.6)
ENGINEERS = {n: [F("engineer_escort", 2 + n // 2, "bottom", max(4.0, 14.0 - n), 4.0)] for n in range(2, 13)}
ENGINEERS[1] = [F("engineer_escort", 1, "bottom", 0, 10.0)]
HAZARD_COMBOS = {4: [(40, "net_link")], 5: [(46, "bubble_broom")], 6: [(50, "double_tornado")], 7: [(56, "fog_tornado")],
                 8: [(40, "bubble_broom"), (64, "net_link")], 9: [(36, "double_tornado"), (60, "fog_tornado")],
                 10: [(30, "bubble_broom"), (50, "double_tornado"), (70, "fog_tornado"), (90, "net_link")],
                 11: [(20, "double_tornado"), (40, "net_link"), (60, "bubble_broom")],
                 12: [(15, "bubble_broom"), (30, "double_tornado"), (45, "fog_tornado"), (60, "net_link")]}
for _n, _hs in list(HAZARD_COMBOS.items()):
    HAZARD_COMBOS[_n] = sorted(_hs + [(t + 18, k) for t, k in _hs])   # 陷阱组合 ×2

# 敌塔：每波可能出现哪些（地精工兵搭 / 怪物聚集起来搭）
ENEMY_TOWERS = {
    3: ["glue", "windmill"], 4: ["vine_pull", "tailor", "glue"], 5: ["portal", "vine_pull", "windmill", "glue"],
    6: ["sole_tower", "net", "tailor"], 7: ["net", "sole_tower", "vine_pull", "glue"], 8: ["silence", "thigh_tower", "tailor"],
    9: ["totem", "thigh_tower", "silence", "portal"], 10: ["totem", "thigh_tower", "sole_tower", "silence", "portal", "net", "vine_pull", "tailor"],
    11: ["windmill", "glue", "net", "totem", "tailor"], 12: ["totem", "thigh_tower", "sole_tower", "silence", "portal", "net", "vine_pull", "tailor", "windmill", "glue"],
}
ENEMY_TOWERS[1] = ["glue", "windmill"]
ENEMY_TOWERS[2] = ["glue", "windmill", "vine_pull"]
# 大范围陷阱的时间表（战斗开始后第几秒）
HAZARDS = {
    3: [(22, "tornado")], 4: [(14, "link_rune"), (30, "sticky_net")], 5: [(12, "bubbles"), (26, "broom"), (36, "wall_vine")],
    6: [(10, "tornado"), (24, "fog"), (40, "sticky_net")], 7: [(10, "bubbles"), (22, "broom"), (34, "wall_vine"), (46, "link_rune")],
    8: [(10, "fog"), (20, "wall_vine"), (32, "sticky_net"), (44, "broom")], 9: [(8, "tornado"), (18, "broom"), (28, "bubbles"), (40, "wall_vine"), (52, "fog")],
    10: [(8, "bubbles"), (16, "broom"), (24, "tornado"), (34, "wall_vine"), (44, "sticky_net"), (52, "link_rune"), (60, "fog"), (70, "broom")],
    11: [(6, "tornado"), (14, "fog"), (22, "broom"), (30, "wall_vine"), (38, "bubbles"), (46, "sticky_net"), (54, "link_rune")],
    12: [(6, "bubbles"), (12, "broom"), (18, "tornado"), (26, "wall_vine"), (34, "sticky_net"), (42, "link_rune"), (50, "fog"), (58, "tornado")],
}
HAZARDS[2] = [(16, "tornado"), (30, "bubbles")]
HAZARD_KINDS = ["tornado", "bubbles", "link_rune", "broom", "fog", "wall_vine", "sticky_net"]
for n in range(2, 13):
    base = HAZARDS.get(n, [])
    # 陷阱 3 倍：原来的之间再插两倍的量（后几波每 6~8 秒一个）
    extra = []
    gap = max(6.0, 14.0 - n)
    t, i = 6.0, n
    while len(extra) < len(base) * 2 + 2:
        extra.append((round(t, 1), HAZARD_KINDS[i % len(HAZARD_KINDS)]))
        t += gap
        i += 3
    HAZARDS[n] = sorted(base + extra)
for n, hz in HAZARDS.items():
    WAVES[n - 1]["hazards"] = [{"t": t, "kind": k} for t, k in hz] + [{"t": t, "combo": k} for t, k in HAZARD_COMBOS.get(n, [])]
    WAVES[n - 1]["hazards"].sort(key=lambda h: h["t"])
for n, kinds in ENEMY_TOWERS.items():
    WAVES[n - 1]["enemy_towers"] = kinds
    WAVES[n - 1]["groups"].append(G("slime" if n % 2 else "rat", 10 + n, "site", 0.5, 2.0))
for i, w in enumerate(WAVES):
    n = i + 1
    for gr in w["groups"]:
        gr["count"] *= MULT
        gr["interval"] = round(max(0.15, gr["interval"] / 2.0), 2)
    for gr in EXTRA.get(n, []):
        gr = dict(gr)
        gr["interval"] = round(max(0.2, gr["interval"] / 2.0), 2)
        w["groups"].append(gr)
    w["groups"] = [gr for gr in w["groups"] if gr["monster"] in have]
    w["groups"] += FORMATIONS.get(n, []) + ENGINEERS.get(n, [])
    w["theater"] = "siege_fail_%d" % (i + 1)
    w["countdown"] = 15
# 第 3 波中段：小 Boss 攻城巨魔将军（出场时自己带 4 只盾甲螃蟹护卫）
if "troll_general" in have:
    WAVES[2]["groups"].append(G("troll_general", 1, "bottom", 1.0, 22.0))
    WAVES[2]["boss"] = "troll_general"
WAVE_DATA = {"_说明": ["小镇攻防战的波次（gen_floor06_siege.py 生成；SiegeDirector 读）。怪物表只有已经做好的怪。"],
             "wall_hp": 4320, "prep_first": 30, "prep": 20, "ability_rate": 3.0, "start_crystals": 30,
             "monsters": have, "waves": WAVES}
Path("data/siege").mkdir(parents=True, exist_ok=True)
Path("data/siege/waves.json").write_text(json.dumps(WAVE_DATA, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 冰塔 / 敌塔
TOWERS = {   # 每种 3 级（levels 三项）；unlock_wave：第几波开始能造（没写 = 第 1 波就能造）
    "icicle": {"name": "冰锥塔", "short": "冰锥 + 溅射", "cost": 10, "upgrade": 12,
               "desc": "自动朝射程内最近的怪射冰锥，落地碎开溅射一小片。",
               "levels": [{"range": 140, "interval": 1.2, "damage": 1, "splash": 22}, {"range": 170, "interval": 0.9, "damage": 2, "splash": 30},
                          {"range": 200, "interval": 0.7, "damage": 3, "splash": 38}]},
    "snowman": {"name": "雪人召唤塔", "short": "一群扔雪球的雪人", "cost": 14, "upgrade": 14,
                "desc": "每隔一会儿放出一群小雪人，扔雪球砸怪（落地炸开、减速）；怪物也会去打小雪人。",
                "levels": [{"interval": 7, "count": 3, "snow_hp": 4, "ball_splash": 18, "ball_damage": 1},
                           {"interval": 6, "count": 4, "snow_hp": 6, "ball_splash": 22, "ball_damage": 1},
                           {"interval": 5, "count": 5, "snow_hp": 8, "ball_splash": 26, "ball_damage": 2}]},
    "decoy": {"name": "诱饵冰雕", "short": "吸引攻击", "cost": 12, "upgrade": 12,
              "desc": "漂亮的公主冰雕，有血量。周围的怪和攻城车会优先去打它。",
              "levels": [{"hp": 60, "lure": 110}, {"hp": 120, "lure": 150}, {"hp": 200, "lure": 190}]},
    "mint": {"name": "薄荷冰泉", "short": "降低闷笑", "cost": 12, "upgrade": 12,
             "desc": "凉凉的泉水：范围内的公主闷笑值慢慢下降。", "levels": [{"radius": 60, "decay": 6}, {"radius": 80, "decay": 10}, {"radius": 100, "decay": 14}]},
    "frost": {"name": "寒霜塔", "short": "减速 + 冰爆", "cost": 12, "upgrade": 12,
              "desc": "范围内的怪减速；每隔几秒冻住一下，同时冰爆，范围里的怪都掉血。",
              "levels": [{"radius": 70, "freeze": 1.0, "burst": 1}, {"radius": 90, "freeze": 1.5, "burst": 2}, {"radius": 110, "freeze": 2.0, "burst": 3}]},
    "repair": {"name": "冰墙修补塔", "short": "修城墙", "cost": 16, "upgrade": 14,
               "desc": "慢慢修复它身后的那段城墙。", "levels": [{"repair": 3}, {"repair": 6}, {"repair": 10}]},
    "campfire": {"name": "篝火塔", "short": "照亮 + 暖和", "cost": 12, "upgrade": 12,
                 "desc": "一大圈火光：幽灵现形，暖炉史莱姆化得更快，圈里的友军闷笑慢慢降。",
                 "levels": [{"radius": 110, "decay": 3}, {"radius": 140, "decay": 5}, {"radius": 170, "decay": 7}]},
    "ballista": {"name": "冰棱弩炮", "short": "远程穿透 + 冰花", "cost": 18, "upgrade": 16,
                 "desc": "射程很远的穿透冰棱，射到尽头炸开一大朵冰花；专打敌塔和大型怪（攻城车 / Boss 伤害 ×3）。",
                 "levels": [{"range": 420, "interval": 2.6, "damage": 3, "pierce": 4, "bloom": 40, "bloom_damage": 2},
                            {"range": 480, "interval": 2.0, "damage": 4, "pierce": 6, "bloom": 56, "bloom_damage": 3},
                            {"range": 540, "interval": 1.6, "damage": 5, "pierce": 8, "bloom": 72, "bloom_damage": 4}]},
    "cocoa": {"name": "热可可摊", "short": "友军加速", "cost": 14, "upgrade": 12,
              "desc": "热乎乎的可可：附近友军攻击更快、走得更快，粉色公主闷笑降得更快。",
              "levels": [{"radius": 90, "haste": 0.75, "speed": 1.2, "decay": 4}, {"radius": 120, "haste": 0.65, "speed": 1.3, "decay": 6},
                         {"radius": 150, "haste": 0.55, "speed": 1.4, "decay": 8}]},
    # —— 随波次解锁的大范围攻击塔
    "mortar": {"name": "冰霜迫击炮", "short": "远程大范围", "cost": 20, "upgrade": 16, "unlock_wave": 3,
               "desc": "往射程里怪最密的地方抛一颗大冰弹（落点有影子），炸开一大片，减速。",
               "levels": [{"range": 520, "interval": 4.0, "radius": 48, "damage": 2}, {"range": 560, "interval": 3.5, "radius": 60, "damage": 3},
                          {"range": 600, "interval": 3.0, "radius": 72, "damage": 4}]},
    "vortex": {"name": "冰风旋涡塔", "short": "持续冰风", "cost": 18, "upgrade": 16, "unlock_wave": 4,
               "desc": "身边一直转着一圈冰风：里面的怪持续掉血，被往外推。",
               "levels": [{"radius": 80, "damage": 1, "push": 40}, {"radius": 100, "damage": 1, "push": 55}, {"radius": 120, "damage": 2, "push": 70}]},
    "resonance": {"name": "冰晶共鸣塔", "short": "连跳冰光", "cost": 20, "upgrade": 16, "unlock_wave": 5,
                  "desc": "一道冰光在怪之间连跳，每跳一下都掉血、冻一下。",
                  "levels": [{"range": 200, "interval": 2.2, "jumps": 5, "damage": 2}, {"range": 220, "interval": 1.9, "jumps": 7, "damage": 2},
                             {"range": 240, "interval": 1.6, "jumps": 9, "damage": 3}]},
    "meteor": {"name": "冰陨星台", "short": "超大范围陨星", "cost": 28, "upgrade": 20, "unlock_wave": 7,
               "desc": "蓄力后往全场最大的怪堆砸一颗冰陨星：超大范围伤害、把怪冻住。",
               "levels": [{"interval": 12, "radius": 90, "damage": 4, "freeze": 2.0}, {"interval": 10, "radius": 110, "damage": 6, "freeze": 2.0},
                          {"interval": 8, "radius": 130, "damage": 8, "freeze": 2.5}]},
    # —— 随波次解锁的大范围辅助塔（靠后的波次）
    "hotspring": {"name": "温泉治疗泉", "short": "大范围治疗", "cost": 18, "upgrade": 14, "unlock_wave": 6,
                  "desc": "冒热气的温泉：范围内公主闷笑持续下降、士兵回血，还慢慢修身后那段城墙。",
                  "levels": [{"radius": 110, "decay": 4, "heal": 1, "repair": 2}, {"radius": 140, "decay": 6, "heal": 1, "repair": 3},
                             {"radius": 170, "decay": 8, "heal": 2, "repair": 4}]},
    "lamp": {"name": "冰灯塔", "short": "照亮 + 减速", "cost": 16, "upgrade": 14, "unlock_wave": 8,
             "desc": "一大圈冷光：幽灵现形，里面的怪变慢，范围里的敌塔发动也变慢。",
             "levels": [{"radius": 140, "slow": 0.7, "etower_slow": 1.3}, {"radius": 170, "slow": 0.6, "etower_slow": 1.5},
                        {"radius": 200, "slow": 0.5, "etower_slow": 1.7}]},
    "shield": {"name": "冰盾发生器", "short": "给友军套冰盾", "cost": 20, "upgrade": 16, "unlock_wave": 9,
               "desc": "每隔一会儿给范围内的友军套一层冰盾，挡掉下一次挠痒或抓取。",
               "levels": [{"radius": 120, "interval": 8}, {"radius": 150, "interval": 7}, {"radius": 180, "interval": 6}]},
}
ETOWERS = {
    "vine_pull": {"name": "藤蔓拉拽塔", "hp": 13, "interval": 7, "range": 200, "pull": 55, "presses": 12, "reward": 8,
                  "lines": ["呀——！藤、藤蔓缠住腰了！", "被拖过去了……放开啦！", "藤蔓尖在腰上挠……嘻嘻嘻！"]},
    "tailor": {"name": "痒痒裁缝铺", "hp": 12, "interval": 8, "range": 240, "range_wall": 520, "reward": 8,
               "items": ["equip_t_feather_socks", "equip_t_toe_brush", "equip_t_fluff_bra", "equip_t_thigh_ring", "equip_t_pinch_pad",
                         "equip_t_knead_tights", "equip_t_bell_anklet", "equip_t_mark_patch"]},
    "glue": {"name": "黏胶喷泉", "hp": 11, "interval": 5, "range": 140, "reward": 6},
    "net": {"name": "吊网塔", "hp": 12, "interval": 9, "range": 190, "hang": 3.5, "reward": 8,
            "lines": ["网、网住了！吊起来了！", "网眼里伸出手来了……脚心！哈哈哈！", "脚、脚够不着地……别挠脚心！"]},
    "silence": {"name": "魔力干扰塔", "hp": 13, "interval": 3, "width": 130, "reward": 10},
    "portal": {"name": "怪物传送门", "hp": 16, "interval": 3, "cap": 6, "spawns": ["slime", "rat", "caterpillar"], "reward": 10},
    "windmill": {"name": "强风风车塔", "hp": 12, "interval": 6, "range": 320, "force": 340, "reward": 8,
                 "lines": ["哇啊——被吹走了！", "风、风好大……要吹到怪物堆里了！"]},
    "totem": {"name": "狂欢图腾", "hp": 17, "interval": 1, "range": 120, "reward": 12},
    "thigh_tower": {"name": "腿根揉揉塔", "hp": 13, "interval": 5, "range": 560, "amount": 6, "reward": 10,
                    "lines": ["腿、腿根被揉了！", "屁股被捏了一下……！"],
                    "lines_blue": ["……腿根。……拇指，在揉。", "……屁股……左、右……轮流捏……", "……飞、飞过来的手……揉腿根……", "……裤子……也跟着动了……"]},
    "sole_tower": {"name": "脚心刷刷塔", "hp": 12, "interval": 5, "range": 220, "amount": 4, "reward": 8,
                   "lines": ["脚踝被抓住了！脚趾……被扳开了！", "刷、刷子在刷脚心……哈哈哈哈！", "脚板被扳着往后……指甲在刮……不行不行！", "趾缝里也刷……嘻嘻嘻嘻！"]},
}
Path("data/siege/towers.json").write_text(json.dumps({"_说明": ["攻防战的冰塔（gen_floor06_siege.py 生成；IceTower 读）。"], **TOWERS},
                                                    ensure_ascii=False, indent="\t") + "\n")
Path("data/siege/enemy_towers.json").write_text(json.dumps({"_说明": ["攻防战的敌塔（gen_floor06_siege.py 生成；EnemyTower 读）。"], **ETOWERS},
                                                          ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 战场情报
def I(name, kind, desc, mech="", how=""):
    return {"name": name, "kind": kind, "desc": desc, "mech": mech, "how": how}


INTEL = {}
# 按键说明放第一条（正文按当前键位在游戏里生成：SiegeIntel.controls_text）；进攻防战、开场过场放完后自动弹出
INTEL["controls"] = I("攻防战按键说明", "操作", "两个人分工守城：粉色公主在墙下打怪、建冰塔，蓝色公主在城墙上放法术。")
INTEL["controls"]["icon"] = "horn"
TOWER_INTEL = {
    "icicle": ("冰锥：射程内自动瞄最近的怪。2 级射得更快、更痛。", "盾甲螃蟹的大钳子能挡住正面的冰锥。"),
    "snowman": ("小雪人会主动去找怪挠、把怪推开；怪物也会去打小雪人，帮公主分担火力。", "放在怪多的那一侧。"),
    "decoy": ("怪物和攻城车会优先去打它（诱饵范围内）。有血量，被打碎了就没了。", "放在城门前，或者攻城车的路线上。"),
    "mint": ("站在旁边闷笑值会慢慢降下来。粉色公主的 AI 闷笑高时会自己跑过来。", "放在粉色公主常去的前线后面。"),
    "frost": ("范围减速，每隔几秒把范围里的怪冻住一下。攻城车经过也会变慢。", "和冰锥塔放在一起效果最好。"),
    "repair": ("一秒一秒地修补它身后那一段城墙。", "放在最常被打的那段墙下面。"),
    "campfire": ("火光范围里幽灵会现形（能打到了），暖炉史莱姆化得更快；站在火边的友军闷笑慢慢降。", "放在幽灵多的那一侧。"),
    "ballista": ("每隔一会儿射出一根穿透的长冰棱，优先打敌塔、攻城车和 Boss，对它们伤害 ×3。", "放在墙下中间，射程能盖住大半个战场。"),
    "cocoa": ("附近的友军（公主和士兵）攻击间隔缩短、移动变快；粉色公主站在旁边闷笑降得更快。", "放在士兵扎堆的地方。"),
    "mortar": ("射程很远，抛物线飞过去，落点先出影子；炸开一大片、减速 2 秒。第 3 波解锁。", "放在墙下中间，盖住怪最多的那片。"),
    "vortex": ("身边一圈冰风一直转：每半秒掉血，把怪往外推，挡住冲过来的怪。第 4 波解锁。", "放在城门口、怪一定会经过的地方。"),
    "resonance": ("冰光在怪之间连跳，每跳一下都冻一下，怪越挤跳得越多。第 5 波解锁。", "对付成群的小怪。"),
    "meteor": ("蓄力后往全场最大的怪堆砸冰陨星，超大范围、冻住 2 秒、震屏。第 7 波解锁。", "越往后怪越多，越值。"),
    "hotspring": ("范围很大：公主闷笑一直降、士兵回血、修身后的城墙。第 6 波解锁。", "放在墙下正中，士兵和粉色公主常在的地方。"),
    "lamp": ("冷光范围里幽灵现形、怪减速，范围里的敌塔发动变慢。第 8 波解锁。", "放在敌塔多、幽灵多的那一侧。"),
    "shield": ("每隔几秒给范围里的友军套冰盾，挡掉下一次挠痒或抓取（挡下时会闪一下）。第 9 波解锁。", "和士兵、粉色公主放在一起。"),
}
for k, (mech, how) in TOWER_INTEL.items():
    INTEL["tower_" + k] = I(TOWERS[k]["name"], "冰塔", TOWERS[k]["desc"], mech, how)
ET_INTEL = {
    "vine_pull": ("甩出藤蔓勾住粉色公主，把她往塔下拖；拖到塔下藤尖会一直挠她。", "被拖时连按挣脱；蓝色公主能放冰链把人拉回来。尽快拆掉它。"),
    "tailor": ("射出带手的「痒痒装备」，打中就被强制穿上 20 秒：袜子、胸衣、紧身裤、铃铛……", "躲开飞过来的粉色小球；另一位公主靠近按住 E 能帮忙解开，清凉雪花也能解。"),
    "glue": ("往地上喷黏胶水洼，踩上去走得很慢。", "绕开黏胶；拆塔时注意脚下。"),
    "net": ("射网把粉色公主网住吊到半空，网眼里伸出手来挠脚心。", "看到网飞过来就冲刺躲开。"),
    "silence": ("城墙上它对着的那一段，蓝色公主一施法就会被打断、还被挠一下。", "让粉色公主去拆；蓝色公主先走到干扰范围外面。"),
    "portal": ("不停地吐出小怪，最多同时 6 只。", "越早拆越好。"),
    "windmill": ("每隔几秒刮一阵强风，把粉色公主往怪群里吹。", "从侧面靠近，别站在风口。"),
    "totem": ("附近的怪移动和挠痒都变快。只要它立着，蓝色公主的千手痒痒裤发作得更频繁、更重。", "优先拆掉！"),
    "thigh_tower": ("射程能够到城墙，专门往蓝色公主的大腿和屁股上射小手：拇指揉腿根、轮流捏屁股。穿着千手痒痒裤时裤子也会跟着动。", "粉色公主去拆；蓝色公主可以先换到别的那段墙。"),
    "sole_tower": ("刷子手飞过来抓住粉色公主的脚踝：扳开脚趾一根根刷趾缝、刷脚心，最后扳着脚板往后、用指甲刮。", "冲刺躲开刷子手，绕到旁边拆塔。"),
}
for k, (mech, how) in ET_INTEL.items():
    INTEL["etower_" + k] = I(ETOWERS[k]["name"], "敌塔", "怪物聚集在敌方区域的地基上搭起来的塔。", mech, how)
MON_INTEL = {
    "cart": ("攻城痒痒车", "装满小手和羽毛的木头车，车头一根撞角。", "地上先亮红色预警线，然后从下边加速冲过来撞墙：城墙大扣血，那一段墙上的蓝色公主会被震下去。路线附近有诱饵冰雕时改撞冰雕。", "在它的路线上放诱饵冰雕 / 寒霜塔；蓝色公主先离开那一段墙。"),
    "hook": ("钩索怪", "背着钩爪的小怪。", "走到墙前甩钩索勾住城墙，顺着绳子滑上墙顶，上去就挠蓝色公主。", "冰锥雨能射断绳子；滑的时候打它一下就会摔下来。"),
    "vine": ("捆绑藤怪", "一团会走路的藤蔓。", "缠住公主（连按挣脱），缠着的时候给她强制穿上一件临时痒痒装备，藤尖一直挠。", "别让它贴身；被缠住时蓝色公主的清凉雪花能解开。"),
    "gecko": ("爬墙壁虎", "又小又快的绿壁虎。", "走到墙下就贴着墙爬上去，在城墙顶上乱窜、挠蓝色公主。冰墙加固的那段爬不上去。", "数量多、血少：冰锥雨一扫一片。"),
    "shield_crab": ("盾甲螃蟹", "举着一对大钳子当盾牌的螃蟹。", "正面（朝城墙的那一面）挡得住冰锥、冰塔和法术；走到墙下用钳子夹墙，伤害很高。", "粉色公主绕到它背后（下面）打。"),
    "bat_swarm": ("羽毛蝠群", "一群叼着羽毛的小蝙蝠。", "飞在天上：粉色公主的近战够不着，直接越过战场飞上城墙挠蓝色公主。", "只有蓝色公主的法术和冰塔能打下来。"),
    "carrier": ("搬运小鬼队", "扛着长杆子的三只小鬼。", "粉色公主失控时冲过来把她抬走，运进敌塔里关起来挠 8 秒。", "蓝色公主用冰链把人拉回来；冻住 / 打倒小鬼也会把人放下。"),
    "warm_slime": ("暖炉史莱姆", "暖烘烘、冒着热气的橙色史莱姆。", "不怕冻，冰锥、冰塔、蓝色公主的法术都打不动；专找冰塔，贴上去把塔慢慢融化。", "只能粉色公主去打。"),
    "thigh_spider": ("腿根爬爬蛛", "紫色的小蜘蛛。", "爬上城墙专挠蓝色公主的大腿和屁股；她穿着千手痒痒裤时会引发「裤子共振」，裤子立刻跟着发作。", "在它爬墙之前打掉；冰墙加固能挡住它。"),
    "hug_bear": ("拥抱小熊", "毛茸茸、张着双臂的小熊。", "从正面扑上来抱住粉色公主（连按挣脱），抱着的时候一直挠胸口和腋下。", "蓝色公主的冰锥打中它就会松手。"),
    "suck_jelly": ("魔力吸吸水母", "半透明、会飘的水母。", "飘上城墙吸住蓝色公主：吸着的时候法术放不出来，她一抬手想施法就专挠腋下。", "连按挣脱；粉色公主爬上城墙帮忙打。"),
    "twin_ghost": ("双子痒痒鬼", "一粉一蓝的两只小幽灵。", "一只在墙下、一只在城墙上；要在 3 秒内把两只都打倒，不然先倒下的会复活。", "两个人约好一起出手。"),
}
for k, (name, desc, mech, how) in MON_INTEL.items():
    INTEL[k] = I(name, "攻城怪", desc, mech, how)
HZ_INTEL = {
    "tornado": ("痒痒龙卷风", "大范围陷阱", "在战场上慢慢游走的粉色小旋风。", "卷到人就转着圈挠，过一会儿甩出去。", "看到它靠近就跑开。"),
    "bubbles": ("痒痒泡泡潮", "大范围陷阱", "一排大泡泡从战场一边扫到另一边。", "被包进泡泡就飘起来动不了，泡泡里一直挠。", "看预警，提前走出泡泡的那一行。"),
    "link_rune": ("痒感连线符文", "大范围陷阱", "战场上发光的符文石。", "粉色公主踩到附近时两人之间连上粉线：一个被挠，另一个也痒一半。", "粉色公主打碎符文石。"),
    "broom": ("城墙羽毛扫帚", "大范围陷阱", "巨大的羽毛扫帚。", "沿城墙顶走道的某一行扫过去：被扫到就被挠、推下城墙。", "看预警，站到走道的另一行去。"),
    "fog": ("痒痒迷雾", "大范围陷阱", "一大片粉色的雾。", "粉色公主在雾里时，蓝色公主看不见她、支援不了；雾里还会伸出手来挠。", "别在雾里待太久。"),
    "wall_vine": ("城墙爬藤", "牺牲互救", "怪物在墙脚种下的藤根。", "藤蔓爬上城墙缠住蓝色公主：动不了、放不了法术，一直被挠大腿和腰。", "粉色公主去墙脚砍断藤根——砍的时候根须会缠住她的脚踝挠脚心，要忍住。"),
    "sticky_net": ("黏网", "牺牲互救", "从敌方区域抛过来的大黏网。", "罩住粉色公主后她动不了，网眼里伸出小手挠。", "蓝色公主走到她正上方的城墙上，探出城垛割网——探出去时大腿和屁股露在墙外，会被爬墙的怪挠。"),
}
for k, (name, kind, desc, mech, how) in HZ_INTEL.items():
    INTEL["hazard_" + k] = I(name, kind, desc, mech, how)
TEMP_INTEL = {
    "t_feather_socks": ("羽毛袜", "挠痒", "走一步挠一下脚心，移动变慢；跑得越快挠得越重。"),
    "t_toe_brush": ("趾缝刷套", "挠痒", "把脚趾一根根扳开、刷趾缝。"),
    "t_fluff_bra": ("绒毛胸衣", "挠痒", "绒毛随呼吸蹭胸口，闷笑消减变慢。"),
    "t_thigh_ring": ("腿根揉揉环", "挠痒", "环里的手指揉腿根。"),
    "t_pinch_pad": ("捏捏臀垫", "挠痒", "一下下捏屁股。"),
    "t_knead_tights": ("揉揉紧身裤", "挠痒", "揉腿根、捏屁股，走得慢。"),
    "t_feather_shackles": ("羽毛脚镣", "束缚", "两只脚踝连在一起：不能冲刺、只能小步走，羽毛扫脚踝。"),
    "t_thigh_strap": ("夹腿绑带", "束缚", "两条大腿绑在一起：走得很慢，绑带内侧挠腿。"),
    "t_bell_anklet": ("铃铛脚链", "负面", "一动就叮铃响，把附近的怪引过来。"),
    "t_mark_patch": ("痒痒印记臀贴", "负面", "怪物优先找她，闷笑涨得更快。"),
}
TEAMS = json.loads(Path("data/teamwork.json").read_text())["teams"] if Path("data/teamwork.json").exists() else []
for t in TEAMS:
    INTEL["team_" + t["id"]] = I(t["name"], "怪物配合技", t["intel"]["desc"], t["intel"]["mech"], t["intel"]["how"])
    INTEL["team_" + t["id"]]["icon"] = t["members"][0]["key"] if isinstance(t["members"][0]["key"], str) else t["members"][0]["key"][0]
HZC = {
    "bubble_broom": ("泡泡扫帚", "泡泡潮把怪运到墙下的同时，羽毛扫帚从墙顶扫过。", "蓝色公主先躲扫帚，粉色公主去墙下接住运来的怪。", "bubbles"),
    "double_tornado": ("双龙卷", "两个龙卷风反方向绕着一个中心转，被一个甩出去很容易又被另一个卷走。", "往两个龙卷风都够不着的外圈跑。", "tornado"),
    "fog_tornado": ("迷雾龙卷", "龙卷风藏在迷雾里游走，只看得到卷起的粉尘；卷着的时候雾里的手一起挠。", "别进雾里；看到粉尘就绕开。", "fog"),
    "net_link": ("黏网连线", "痒感连线符文旁紧接着落下黏网：网里被挠，连线另一头的蓝色公主也跟着痒。", "先打碎符文石，再让蓝色公主割网。", "link_rune"),
}
for k, (name, mech, how, icon) in HZC.items():
    INTEL["hzcombo_" + k] = I(name, "陷阱组合", "几个大范围陷阱成套出现。", mech, how)
    INTEL["hzcombo_" + k]["icon"] = "hazard_" + icon
INTEL["goblin_engineer"] = I("地精工兵", "攻城怪", "戴着安全帽、扛着木料的地精，三只一队。",
                             "走到离自己最近的空地基搭敌塔（地基上出进度条，12 秒）；搭完去找下一个。冻住时进度停下，冻久了倒退。",
                             "看到进度条就去打工兵；蓝色公主的冰晶结界能冻住他们。")
for k, (name, kind, mech) in TEMP_INTEL.items():
    INTEL["equip_" + k] = I(name, "临时痒痒装备·" + kind, "被痒痒裁缝铺或捆绑藤怪强制穿上的装备，20 秒后自己掉。", mech,
                             "另一位公主靠近按住 E 2 秒帮忙解开；蓝色公主的清凉雪花也能解开。蓝色公主穿着千手痒痒裤时，大腿 / 屁股的会被裤子吸收（裤子变得更频繁、更重）。")
# ================================================================ 镇民支援（每波固定一个；派对者的激励开局就有）
def TB(id, name, who, sheet, color, after, line, desc, buff=None, mul=None, add=None, once=None, per_wave=None):
    e = {"id": id, "name": name, "who": who, "sheet": sheet, "color": color, "after_wave": after, "line": line, "desc": desc}
    if buff:
        e["buff"] = buff
    for k, v in (("mul", mul), ("add", add), ("once", once), ("per_wave", per_wave)):
        if v:
            e[k] = v
    return e


TOWN_BUFFS = [
    TB("party", "派对者的激励", "派对主持人", "bonfire_host", "#ffb0e0", 0, "开打啦！大家跑起来——派对节奏！", "全部友军移动速度 +50%。", buff="town_party"),
    TB("smith", "铁匠的磨刀石", "铁匠", "miner", "#ffb070", 1, "矛尖、箭头、冰棱，统统给你们磨快了！", "士兵攻击 +50%，冰塔伤害 +30%，粉色公主近战 +1。",
       buff="town_smith", mul={"soldier_atk": 1.5, "tower_dmg": 1.3}),
    TB("band", "乐队的鼓点", "小镇乐队", "kid", "#ffe070", 2, "咚、咚、咚！跟着鼓点打！", "友军攻击间隔 -30%，蓝色公主城墙法术冷却 -25%。",
       buff="town_band", mul={"ally_cd": 0.7, "spell_cd": 0.75}),
    TB("tailor", "裁缝的厚棉衣", "裁缝", "maid", "#c8a8ff", 3, "厚厚的棉衣，痒痒手伸不进去！", "友军受到的挠痒 -25%，临时痒痒装备的发作力度减半。",
       buff="town_tailor", mul={"equip_power": 0.5}),
    TB("mason", "泥瓦匠的砂浆", "泥瓦匠", "supervisor", "#d0c0a0", 4, "砂浆来了！城墙补得结结实实！", "城墙上限 +15%，马上修 20%；之后每一波开始自动修 5%。",
       once={"wall_max_mul": 1.15, "wall_repair": 0.2}, per_wave={"wall_repair": 0.05}),
    TB("pharm", "药剂师的薄荷", "药剂师奶奶", "granny", "#a0f0d0", 5, "薄荷糖拿好，憋不住了就含一颗。", "马上送 2 颗薄荷糖，之后每波再送 2 颗；蓝色公主魔力疲倦增长 -30%。",
       mul={"fatigue": 0.7}, once={"mints": 2}, per_wave={"mints": 2}),
    TB("watch", "守夜人的灯笼", "守夜人", "guard", "#ffe8a0", 6, "灯笼挂起来——幽灵别想躲！", "所有友军身边有小光圈：幽灵靠近就现形；友军索敌范围 +40%。",
       mul={"detect": 1.4}, add={"lantern": 60}),
    TB("cheer", "村民们的加油声", "村民们", "kid", "#ff9090", 7, "公主加油——！忍住！别笑出来！", "两位公主更不容易失控，被抓 / 被缠时挣脱少按一半。",
       buff="town_cheer"),
    TB("captain", "卫兵队长的号令", "卫兵队长", "captain", "#90b0ff", 8, "全体听令！顶住！援兵马上到！", "士兵血量 +50%，撤退回来的时间减半，增派 2 个长矛兵。",
       mul={"soldier_hp": 1.5, "soldier_return": 0.5}, once={"spears": 2}),
    TB("hunter", "猎人的绊绳站", "猎人", "miner", "#b0d080", 9, "绊绳拉好了，那些地精跑不快！", "怪物搭敌塔的速度 -30%，地精工兵移动 -25%。",
       mul={"build_speed": 0.7, "engineer_speed": 0.75}),
    TB("florist", "花匠的香草", "花匠", "maid", "#a0ffa0", 10, "香草的味道，冰塔也精神起来了！", "冰塔射程 +25%，雪人召唤塔每次多召一只。",
       mul={"tower_range": 1.25}, add={"snowmen": 1}),
    TB("mayor", "镇长的祭典狂欢", "镇长", "merchant", "#ffd700", 11, "最后一波了！全镇一起——祭典开始！", "全部友军所有属性 +20%，城墙回满。",
       buff="town_mayor", mul={"tower_dmg": 1.2, "ally_cd": 0.83, "spell_cd": 0.83, "soldier_atk": 1.2, "soldier_hp": 1.2, "detect": 1.2},
       once={"wall_full": True, "fireworks": True}),
]
Path("data/siege/town_buffs.json").write_text(json.dumps(TOWN_BUFFS, ensure_ascii=False, indent="\t") + "\n")
for tb in TOWN_BUFFS:
    INTEL["town_" + tb["id"]] = I(tb["name"], "镇民支援", "%s：「%s」" % (tb["who"], tb["line"]), tb["desc"], "整局都有效（失败重来也保留）。")
    INTEL["town_" + tb["id"]]["icon"] = "crystal"
INTEL["troll_general"] = I("攻城巨魔将军", "小 Boss", "戴着牛角头盔、腰挂号角的独眼巨魔，第 3 波中段带着盾甲螃蟹出场。",
                           "大手抓住人扳脚挠脚心；三连扫掌；蓄力地震重击（墙下时把蓝色公主震下城墙）；把小怪扔上城墙；扛木桩冲撞城墙；"
                           "跳到墙脚劈墙再跳回战场中间；战吼让附近的怪发狂；插痒痒军旗（不断钻出小怪）；叫工兵就地搭敌塔；半血狂暴。",
                           "看清地上的预警形状就躲；被抓住连按挣脱，松手后他会僵 2 秒——这时全力打；军旗和工兵优先处理；冰棱弩炮伤害 ×3。")
for role, (name, mech) in {"shield": ("盾兵", "站在受伤最重的那段墙下，嘲讽附近的怪；攻城车撞上来能挡下一次。"),
                           "medic": ("医护兵", "跟着粉色公主和受伤的士兵，每 3 秒给范围内的人降闷笑、回血。"),
                           "artisan": ("工匠", "修城墙最破的一段、修冰塔，没事做时去拆敌塔地基的搭建进度。")}.items():
    INTEL["soldier_" + role] = I(name, "友军士兵", "小镇保卫队的%s。" % name, mech, "被挠得撑不住会撤回城门，过一会儿满血回来。")
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
    line(BLUE, "……你按 B，在脚下放冰塔基座。……我从城墙上放冰光，一起造。"),
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
def _count(gr):
    if "formation" in gr:
        tw = next((t for t in TEAMS if t["id"] == gr["formation"]), None)
        return gr["count"] * (sum(f[1] for f in tw["formation"]) if tw else 0)
    return gr["count"]


print("%s：%dx%d，图例 %d 种；怪物 %d 种，%d 波（共约 %d 只，每波 %s），地基 %d 个" % (
    FID, W, H, len(specs), len(have), len(WAVES), sum(_count(gr) for w in WAVES for gr in w["groups"]),
    [sum(_count(gr) for gr in w["groups"]) for w in WAVES], len(SITES)))
