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
# —— 待建区：10 个冰塔格（避开城门）
PADS = [8, 18, 28, 38, 47, 61, 70, 80, 90, 100]
for i, x in enumerate(PADS):
    put(x, 14, "buildpad index=%d" % i)
# —— 敌方区域：6 个敌塔地基
SITES = [(14, 68), (34, 72), (55, 67), (76, 72), (96, 68), (55, 75)]
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
# 敌塔：每波可能出现哪些（从敌塔地基出来的怪聚集起来就搭）
ENEMY_TOWERS = {
    3: ["glue", "windmill"], 4: ["vine_pull", "tailor", "glue"], 5: ["portal", "vine_pull", "windmill", "glue"],
    6: ["sole_tower", "net", "tailor"], 7: ["net", "sole_tower", "vine_pull", "glue"], 8: ["silence", "thigh_tower", "tailor"],
    9: ["totem", "thigh_tower", "silence", "portal"], 10: ["totem", "thigh_tower", "sole_tower", "silence", "portal", "net", "vine_pull", "tailor"],
}
for n, kinds in ENEMY_TOWERS.items():
    WAVES[n - 1]["enemy_towers"] = kinds
    WAVES[n - 1]["groups"].append(G("slime" if n % 2 else "rat", 10 + n, "site", 0.5, 2.0))
for i, w in enumerate(WAVES):
    w["groups"] = [gr for gr in w["groups"] if gr["monster"] in have]
    w["theater"] = "siege_fail_%d" % (i + 1)
WAVE_DATA = {"_说明": ["小镇攻防战的波次（gen_floor06_siege.py 生成；SiegeDirector 读）。怪物表只有已经做好的怪。"],
             "wall_hp": 2400, "prep_first": 30, "prep": 20, "alive_cap": 90, "start_crystals": 24,
             "monsters": have, "waves": WAVES}
Path("data/siege").mkdir(parents=True, exist_ok=True)
Path("data/siege/waves.json").write_text(json.dumps(WAVE_DATA, ensure_ascii=False, indent="\t") + "\n")

# ================================================================ 冰塔 / 敌塔
TOWERS = {
    "icicle": {"name": "冰锥塔", "short": "自动射冰锥", "cost": 10, "upgrade": 12,
               "desc": "自动朝射程内最近的怪射冰锥。", "levels": [{"range": 140, "interval": 1.2, "damage": 1}, {"range": 170, "interval": 0.8, "damage": 2}]},
    "snowman": {"name": "雪人召唤塔", "short": "放出小雪人", "cost": 14, "upgrade": 14,
                "desc": "每隔一段时间放出小雪人，去挠 / 推怪物；怪物也会去打小雪人。",
                "levels": [{"interval": 12, "count": 2, "snow_hp": 4}, {"interval": 10, "count": 3, "snow_hp": 6}]},
    "decoy": {"name": "诱饵冰雕", "short": "吸引攻击", "cost": 12, "upgrade": 12,
              "desc": "漂亮的公主冰雕，有血量。周围的怪和攻城车会优先去打它。",
              "levels": [{"hp": 60, "lure": 110}, {"hp": 120, "lure": 150}]},
    "mint": {"name": "薄荷冰泉", "short": "降低闷笑", "cost": 12, "upgrade": 12,
             "desc": "凉凉的泉水：范围内的公主闷笑值慢慢下降。", "levels": [{"radius": 60, "decay": 6}, {"radius": 80, "decay": 10}]},
    "frost": {"name": "寒霜塔", "short": "减速 + 冻住", "cost": 12, "upgrade": 12,
              "desc": "范围内的怪减速，每隔几秒冻住一下。", "levels": [{"radius": 70, "freeze": 1.0}, {"radius": 90, "freeze": 1.8}]},
    "repair": {"name": "冰墙修补塔", "short": "修城墙", "cost": 16, "upgrade": 14,
               "desc": "慢慢修复它身后的那段城墙。", "levels": [{"repair": 3}, {"repair": 6}]},
}
ETOWERS = {
    "vine_pull": {"name": "藤蔓拉拽塔", "hp": 22, "interval": 7, "range": 200, "pull": 55, "presses": 12, "reward": 8,
                  "lines": ["呀——！藤、藤蔓缠住腰了！", "被拖过去了……放开啦！", "藤蔓尖在腰上挠……嘻嘻嘻！"]},
    "tailor": {"name": "痒痒裁缝铺", "hp": 20, "interval": 8, "range": 240, "range_wall": 520, "reward": 8,
               "items": ["equip_t_feather_socks", "equip_t_toe_brush", "equip_t_fluff_bra", "equip_t_thigh_ring", "equip_t_pinch_pad",
                         "equip_t_knead_tights", "equip_t_bell_anklet", "equip_t_mark_patch"]},
    "glue": {"name": "黏胶喷泉", "hp": 18, "interval": 5, "range": 140, "reward": 6},
    "net": {"name": "吊网塔", "hp": 20, "interval": 9, "range": 190, "hang": 3.5, "reward": 8,
            "lines": ["网、网住了！吊起来了！", "网眼里伸出手来了……脚心！哈哈哈！", "脚、脚够不着地……别挠脚心！"]},
    "silence": {"name": "魔力干扰塔", "hp": 22, "interval": 3, "width": 130, "reward": 10},
    "portal": {"name": "怪物传送门", "hp": 26, "interval": 3, "cap": 6, "spawns": ["slime", "rat", "caterpillar"], "reward": 10},
    "windmill": {"name": "强风风车塔", "hp": 20, "interval": 6, "range": 170, "force": 300, "reward": 8,
                 "lines": ["哇啊——被吹走了！", "风、风好大……要吹到怪物堆里了！"]},
    "totem": {"name": "狂欢图腾", "hp": 28, "interval": 1, "range": 120, "reward": 12},
    "thigh_tower": {"name": "腿根揉揉塔", "hp": 22, "interval": 5, "range": 560, "amount": 6, "reward": 10,
                    "lines": ["腿、腿根被揉了！", "屁股被捏了一下……！"],
                    "lines_blue": ["……腿根。……拇指，在揉。", "……屁股……左、右……轮流捏……", "……飞、飞过来的手……揉腿根……", "……裤子……也跟着动了……"]},
    "sole_tower": {"name": "脚心刷刷塔", "hp": 20, "interval": 5, "range": 220, "amount": 4, "reward": 8,
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
TOWER_INTEL = {
    "icicle": ("冰锥：射程内自动瞄最近的怪。2 级射得更快、更痛。", "盾甲螃蟹的大钳子能挡住正面的冰锥。"),
    "snowman": ("小雪人会主动去找怪挠、把怪推开；怪物也会去打小雪人，帮公主分担火力。", "放在怪多的那一侧。"),
    "decoy": ("怪物和攻城车会优先去打它（诱饵范围内）。有血量，被打碎了就没了。", "放在城门前，或者攻城车的路线上。"),
    "mint": ("站在旁边闷笑值会慢慢降下来。粉色公主的 AI 闷笑高时会自己跑过来。", "放在粉色公主常去的前线后面。"),
    "frost": ("范围减速，每隔几秒把范围里的怪冻住一下。攻城车经过也会变慢。", "和冰锥塔放在一起效果最好。"),
    "repair": ("一秒一秒地修补它身后那一段城墙。", "放在最常被打的那段墙下面。"),
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
