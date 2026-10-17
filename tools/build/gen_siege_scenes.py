"""攻防战的三来源组合（装备 + 陷阱 / 塔 / Boss + 怪）和它们的小演出（可以反复运行，按 id 覆盖）：
  data/combos.json                        分类「攻防战」的组合（equip 占来源格，keys 是剩下的来源槽：怪物 / 敌塔 enemy_* / 陷阱 hazard_*）
  data/princess_reactions.json            组合的名字 / 说明 / 台词（蓝色公主版由 gen_blue_character.py 用 combo_lines(id, "blue") 取）
  data/siege_scenes.json                  粉色公主的小演出
  data/characters/blue/siege_scenes.json  蓝色公主的小演出
每组都有专属特效（effects 里的 siege_fx，由 SiegeDirector.on_combo_effect 放）。CG 把 siege_scenes 合并进组合演出（进 CG 图鉴）。
台词在 tools/build/siege_text/scenes_*.py（四幕，粉 / 蓝两版），这里写机制（来源、效果）并拼装演出。
四幕（每一步标 act）：1 被抓住 → 2 弱点被找到 → 3 魔力疲倦满了、爆发（act = burst，立绘 fatigue_burst）、爆发后更怕痒 → 4 彻底笑倒。
用法：python tools/build/gen_siege_scenes.py，之后再跑 gen_blue_character.py
"""
import json
import os
import sys
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
sys.path.insert(0, str(Path(__file__).resolve().parent))
from burst_lines import PORTRAIT as BURST_PORTRAIT  # noqa: E402
from siege_text import scenes_1, scenes_2, scenes_3  # noqa: E402

P, BLUE = "公主", "蓝色的公主"
TEXT = {**scenes_1.SCENES, **scenes_2.SCENES, **scenes_3.SCENES}


def fx(kind):
    return [{"type": "siege_fx", "kind": kind}, {"type": "focus"}]


# id -> {equip, keys, effects, src: [(kind, key, 名字, 舞台演员?)]}；名字 / 说明 / 台词在 TEXT
MECH = {
    # ---------------------------------------------------------------- 原有 8 组
    "sg_foot_assault": {"equip": ["equip_t_feather_socks"], "keys": [["enemy_net"], ["rat"]],
                        "effects": [{"type": "burst", "amount": 20}, {"type": "root", "duration": 2.5, "extend": True}, {"type": "special_next", "count": 3}] + fx("vortex"),
                        "src": [("equip", "equip_t_feather_socks", "羽毛袜", False), ("siege", "etower_net", "吊网塔", False), ("monster", "rat", "挠脚鼠", True)]},
    # 趾缝刷套和羽毛脚镣都占脚心格，不能同时穿：第三个来源是黏网
    "sg_toe_bloom": {"equip": ["equip_t_toe_brush"], "keys": [["hazard_net"], ["enemy_sole_tower"]],
                     "effects": [{"type": "burst", "amount": 18}, {"type": "expose", "zone": "sole", "mult": 1.7, "duration": 6.0}] + fx("brush_flowers"),
                     "src": [("equip", "equip_t_toe_brush", "趾缝刷套", False), ("siege", "hazard_sticky_net", "黏网", False),
                             ("siege", "etower_sole_tower", "脚心刷刷塔", False)]},
    "sg_bear_bra": {"equip": ["equip_t_fluff_bra"], "keys": [["hug_bear"], ["bind_vine"]],
                    "effects": [{"type": "burst", "amount": 20}, {"type": "grab_extend", "seconds": 2.0}, {"type": "expose", "zone": "chest", "mult": 1.5, "duration": 5.0}] + fx("heart_fluff"),
                    "src": [("equip", "equip_t_fluff_bra", "绒毛胸衣", False), ("monster", "hug_bear", "拥抱小熊", True), ("monster", "bind_vine", "捆绑藤怪", True)]},
    "sg_carried_mark": {"equip": ["equip_t_mark_patch"], "keys": [["enemy_vine_pull"], ["carrier"]],
                        "effects": [{"type": "burst", "amount": 16}, {"type": "siege_lockup"}] + fx("mark_trail"),
                        "src": [("equip", "equip_t_mark_patch", "痒痒印记臀贴", False), ("siege", "etower_vine_pull", "藤蔓拉拽塔", False),
                                ("monster", "carrier", "搬运小鬼队", True)]},
    "sg_pants_frenzy": {"equip": ["thousand_pants"], "keys": [["enemy_totem"], ["thigh_spider"]],
                        "effects": [{"type": "burst", "amount": 20}, {"type": "special_next", "count": 3}, {"type": "dot", "rate": 4.0, "duration": 4.0}] + fx("purple_hands"),
                        "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("siege", "etower_totem", "狂欢图腾", False), ("monster", "thigh_spider", "腿根爬爬蛛", True)]},
    "sg_broom_wall": {"equip": ["thousand_pants"], "keys": [["hazard_broom"], ["gecko"]],
                      "effects": [{"type": "burst", "amount": 18}, {"type": "siege_knockoff"}] + fx("feather_storm"),
                      "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("siege", "hazard_broom", "城墙羽毛扫帚", False), ("monster", "gecko", "爬墙壁虎", True)]},
    "sg_bell_tide": {"equip": ["equip_t_bell_anklet"], "keys": [["hazard_bubble"], ["bat_swarm"]],
                     "effects": [{"type": "burst", "amount": 16}, {"type": "rally", "radius": 220.0}, {"type": "grab_extend", "seconds": 2.0}] + fx("bell_ripple"),
                     "src": [("equip", "equip_t_bell_anklet", "铃铛脚链", False), ("siege", "hazard_bubbles", "痒痒泡泡潮", False), ("monster", "bat_swarm", "羽毛蝠群", True)]},
    "sg_strap_tornado": {"equip": ["equip_t_thigh_strap"], "keys": [["hazard_tornado"], ["enemy_thigh_tower"]],
                         "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 1.5}, {"type": "dot", "rate": 3.0, "duration": 3.0}] + fx("wind_lines"),
                         "src": [("equip", "equip_t_thigh_strap", "夹腿绑带", False), ("siege", "hazard_tornado", "痒痒龙卷风", False),
                                 ("siege", "etower_thigh_tower", "腿根揉揉塔", False)]},
    # ---------------------------------------------------------------- 新增第一批 7 组
    "sg_portal_toes": {"equip": ["equip_t_toe_brush"], "keys": [["hazard_portal"], ["crab"]],
                       "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 2.0}, {"type": "dot", "rate": 3.0, "duration": 4.0}] + fx("brush_flowers"),
                       "src": [("equip", "equip_t_toe_brush", "趾缝刷套", False), ("siege", "hazard_portal_pair", "挠痒传送门", False), ("monster", "crab", "钳钳蟹", True)]},
    "sg_launch_soles": {"equip": ["equip_t_feather_shackles"], "keys": [["enemy_brush_battery"], ["imp"]],
                        "effects": [{"type": "burst", "amount": 16}, {"type": "crit_storm", "duration": 3.0}] + fx("feather_storm"),
                        "src": [("equip", "equip_t_feather_shackles", "羽毛脚镣", False), ("siege", "etower_brush_battery", "机关刷具轰击塔", False),
                                ("monster", "imp", "机械小鬼", True)]},
    "sg_sand_thighs": {"equip": ["equip_t_thigh_ring"], "keys": [["hazard_quicksand"], ["tentacle"]],
                       "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 2.5}, {"type": "multiplier", "value": 1.4, "duration": 5.0}] + fx("purple_hands"),
                       "src": [("equip", "equip_t_thigh_ring", "腿根揉揉环", False), ("siege", "hazard_quicksand", "挠痒流沙旋涡", False), ("monster", "tentacle", "小触手", True)]},
    "sg_mushroom_bounce": {"equip": ["equip_t_pinch_pad"], "keys": [["hazard_mushroom"], ["split_slime"]],
                           "effects": [{"type": "burst", "amount": 16}, {"type": "confuse", "duration": 3.0}] + fx("heart_fluff"),
                           "src": [("equip", "equip_t_pinch_pad", "捏捏臀垫", False), ("siege", "hazard_mushrooms", "弹弹蘑菇阵", False),
                                   ("monster", "split_slime", "分裂史莱姆", True)]},
    "sg_bear_tentacle_pants": {"equip": ["thousand_pants"], "keys": [["hug_bear"], ["tentacle"]],
                               "effects": [{"type": "burst", "amount": 20}, {"type": "lift", "duration": 2.0}] + fx("purple_hands"),
                               "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("monster", "hug_bear", "拥抱小熊", True), ("monster", "tentacle", "小触手", True)]},
    "sg_puppet_dance": {"equip": ["equip_t_knead_tights"], "keys": [["puppet_master"], ["enemy_resonance"]],
                        "effects": [{"type": "burst", "amount": 18}, {"type": "confuse", "duration": 3.0}, {"type": "dot", "rate": 3.0, "duration": 4.0}] + fx("bell_ripple"),
                        "src": [("equip", "equip_t_knead_tights", "揉揉紧身裤", False), ("monster", "puppet_master", "狂欢挠痒魔偶师", True),
                                ("siege", "etower_resonance", "共振刷钟楼", False)]},
    "sg_storm_airlift": {"equip": ["equip_t_mark_patch"], "keys": [["gale_bear"], ["hazard_claw"]],
                         "effects": [{"type": "burst", "amount": 18}, {"type": "rally", "radius": 200.0}, {"type": "lift", "duration": 2.0}] + fx("vortex"),
                         "src": [("equip", "equip_t_mark_patch", "痒痒印记臀贴", False), ("monster", "gale_bear", "狂风熊统领", True),
                                 ("siege", "hazard_claw", "天降抓娃娃机", False)]},
    # ---------------------------------------------------------------- 新增第二批 8 组
    "sg_glue_soles": {"equip": ["equip_t_feather_socks"], "keys": [["enemy_glue"], ["squirrel"]],
                      "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 2.5}, {"type": "special_next", "count": 3}] + fx("brush_flowers"),
                      "src": [("equip", "equip_t_feather_socks", "羽毛袜", False), ("siege", "etower_glue", "黏胶喷泉", False), ("monster", "squirrel", "刷刷松鼠", True)]},
    "sg_windmill_feet": {"equip": ["equip_t_bell_anklet"], "keys": [["enemy_windmill"], ["bat_swarm"]],
                         "effects": [{"type": "burst", "amount": 16}, {"type": "rally", "radius": 220.0}, {"type": "multiplier", "value": 1.4, "duration": 5.0}] + fx("feather_storm"),
                         "src": [("equip", "equip_t_bell_anklet", "铃铛脚链", False), ("siege", "etower_windmill", "强风风车塔", False), ("monster", "bat_swarm", "羽毛蝠群", True)]},
    "sg_mushroom_shoes": {"equip": ["equip_t_feather_shackles"], "keys": [["hazard_mushroom"], ["rat"]],
                          "effects": [{"type": "burst", "amount": 16}, {"type": "root", "duration": 2.0}, {"type": "dot", "rate": 3.0, "duration": 4.0}] + fx("vortex"),
                          "src": [("equip", "equip_t_feather_shackles", "羽毛脚镣", False), ("siege", "hazard_mushrooms", "弹弹蘑菇阵", False), ("monster", "rat", "挠脚鼠", True)]},
    "sg_tornado_toes": {"equip": ["equip_t_toe_brush"], "keys": [["hazard_tornado"], ["imp"]],
                        "effects": [{"type": "burst", "amount": 18}, {"type": "lift", "duration": 2.0}, {"type": "confuse", "duration": 2.5}] + fx("wind_lines"),
                        "src": [("equip", "equip_t_toe_brush", "趾缝刷套", False), ("siege", "hazard_tornado", "痒痒龙卷风", False), ("monster", "imp", "机械小鬼", True)]},
    "sg_portal_spiders": {"equip": ["equip_t_thigh_strap"], "keys": [["hazard_portal"], ["thigh_spider"]],
                          "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 2.5}, {"type": "multiplier", "value": 1.4, "duration": 5.0}] + fx("purple_hands"),
                          "src": [("equip", "equip_t_thigh_strap", "夹腿绑带", False), ("siege", "hazard_portal_pair", "挠痒传送门", False),
                                  ("monster", "thigh_spider", "腿根爬爬蛛", True)]},
    "sg_bubble_pinch": {"equip": ["equip_t_pinch_pad"], "keys": [["hazard_bubble"], ["suck_jelly"]],
                        "effects": [{"type": "burst", "amount": 16}, {"type": "lift", "duration": 2.0}, {"type": "fatigue", "percent": 15.0}] + fx("bell_ripple"),
                        "src": [("equip", "equip_t_pinch_pad", "捏捏臀垫", False), ("siege", "hazard_bubbles", "痒痒泡泡潮", False), ("monster", "suck_jelly", "魔力吸吸水母", True)]},
    "sg_fog_seam": {"equip": ["thousand_pants"], "keys": [["hazard_fog"], ["twin_ghost"]],
                    "effects": [{"type": "burst", "amount": 18}, {"type": "crit_storm", "duration": 3.5}] + fx("purple_hands"),
                    "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("siege", "hazard_fog", "痒痒迷雾", False), ("monster", "twin_ghost", "双子痒痒鬼", True)]},
    "sg_airdrop_tights": {"equip": ["equip_t_knead_tights"], "keys": [["enemy_airdrop"], ["hook"]],
                          "effects": [{"type": "burst", "amount": 16}, {"type": "lift", "duration": 2.0}, {"type": "dot", "rate": 3.0, "duration": 4.0}] + fx("mark_trail"),
                          "src": [("equip", "equip_t_knead_tights", "揉揉紧身裤", False), ("siege", "etower_airdrop", "痒痒空投站", False), ("monster", "hook", "钩索怪", True)]},
}
assert set(MECH) == set(TEXT), "机制和台词的组合 id 对不上：%s" % (set(MECH) ^ set(TEXT))
COMBOS = {cid: dict(MECH[cid], **TEXT[cid]) for cid in MECH}


def A(do, **kw):
    kw["do"] = do
    return kw


def combo_lines(cid, who):
    """组合触发时的三句台词（受挠反应的 combos.<id>.lines）：第二幕、爆发后、第四幕各取她的第一句。"""
    act, out, after_back = 1, {}, False
    for sp, text, tags in COMBOS[cid][who]:
        tags = tags.split()
        for t in tags:
            if t in ("a2", "a3", "a4"):
                act = int(t[1])
        if "back" in tags:
            after_back = True
        if sp != "P":
            continue
        slot = 2 if act == 2 else (3 if act == 3 and after_back else (4 if act == 4 else 0))
        if slot and slot not in out:
            out[slot] = text
    return [out[k] for k in (2, 3, 4) if k in out]


def scene(cid, c, who):
    speaker = BLUE if who == "blue" else P
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    src_list, actor_of, actors, at = [], {}, [], {}
    for i, (kind, key, name, on_stage) in enumerate(c["src"]):
        src_list.append({"kind": kind, "key": key, "name": name})
        if on_stage:
            aid = "src%d" % (len(actors) + 1)
            at[aid] = [-28 if not actors else 28, 2]
            cast[aid] = {"kind": "monster:%s" % key, "at": at[aid], "dir": "right" if not actors else "left", "hidden": True}
            actors.append(aid)
            actor_of[i] = aid
    foe_name = next((name for i, (_k, _key, name, _st) in enumerate(c["src"]) if i in actor_of), "")
    entered = set()

    def tickles(n, iv, fx_kind="lines"):
        live = [a for a in actors if a in entered] or [None]
        return [dict(A("tickle", who="princess", repeat=n, interval=iv, fx=fx_kind), **({"by": a} if a else {})) for a in live]

    def light(i):
        acts = [A("light", index=i)]
        aid = actor_of.get(i)
        if aid and aid not in entered:
            entered.add(aid)
            acts += [A("enter", who=aid, **{"from": [-80 if at[aid][0] < 0 else 80, 0]}, time=0.5)]
        return acts

    steps = [{"act": 1, "actions": [A("fade_in", time=0.4), A("voice", state="giggle"), A("sources", list=src_list)], "wait": 0.4},
             {"act": 1, "speaker": "", "text": "【三来源组合】%s——%s" % (c["name"], c["desc"]),
              "actions": [A("light", index=0), A("bubble", who="princess", kind="surprise")]}]
    act = 1
    for sp, text, tags in c[who]:
        tags = tags.split()
        acts, step_act = [], None
        for t in tags:
            if t in ("a2", "a3", "a4"):
                act = int(t[1])
            elif t in ("s1", "s2"):
                acts += light(int(t[1])) + tickles(6, 0.28)
            elif t == "sall":
                for i in actor_of:
                    if actor_of[i] not in entered:
                        acts += light(i)
                acts.append(A("light", all=True))
            elif t == "tk":
                acts += tickles(6, 0.3)
            elif t == "tk2":
                acts += tickles(8, 0.22)
            elif t in ("ft", "pt"):
                zone = "sole" if who == "pink" else ("thigh" if t == "ft" else "butt")
                acts += [dict(a, zone=zone, fx="feather" if t == "ft" else "hand", repeat=3, interval=0.35) for a in tickles(3, 0.35)]
            elif t == "g1":
                acts += [A("pose", who="princess", visual="giggle", anim="idle"), A("voice", state="giggle")]
            elif t == "h1":
                acts += [A("pose", who="princess", visual="helpless_1", anim="helpless"), A("voice", state="laugh")]
            elif t == "h2":
                acts += [A("pose", who="princess", visual="helpless_2"), A("voice", state="laugh")]
            elif t == "sh":
                acts.append(A("shake", who="princess", time=0.4))
            elif t == "fl":
                acts.append(A("flash", time=0.25))
            elif t == "laugh":
                acts.append(A("bubble", who="princess", kind="laugh"))
            elif t == "hop" and actors:
                acts.append(A("hop", who=actors[0], count=2))
            elif t == "taunt" and actors:
                acts.append(A("taunt", who=actors[0]))
            elif t == "zoom":
                acts += [A("camera", zoom=1.5, focus="princess", time=0.4), A("shake", who="princess", time=1.0)]
            elif t == "unzoom":
                acts += [A("camera", zoom=1, focus="princess", time=0.4), A("bubble", who="princess", kind="shy")]
            elif t == "burst":
                step_act = "burst"
                acts += [A("flash", time=0.8), A("sfx", sound="star_burst", volume=-1.0), A("sfx", sound="water_release", volume=-2.0),
                         A("voice", state=""), A("shake", who="princess", time=0.5), A("camera", zoom=1, focus="princess", time=0.5)]
                acts += [A("move", who=a, to=[at[a][0] + (-50 if at[a][0] < 0 else 50), at[a][1] - 6], time=0.25) for a in entered]
            elif t == "back":
                acts += [A("move", who=a, to=list(at[a]), time=0.6) for a in entered] + [A("voice", state="giggle")]
        st = {"act": step_act or act, "speaker": {"P": speaker, "N": "", "F": foe_name}[sp], "text": text, "actions": acts}
        if step_act == "burst":
            st["portrait"] = BURST_PORTRAIT
            st["wait"] = 1.0
        steps.append(st)
    steps.append({"act": 4, "actions": [A("voice", state=""), A("fade_out", time=0.6)], "wait": 0.7})
    return {"name": c["name"], "cast": cast, "steps": steps}


def main():
    cb = json.loads(Path("data/combos.json").read_text())
    cb["combos"] = [c for c in cb["combos"] if c.get("category") != "攻防战"]
    for cid, c in COMBOS.items():
        cb["combos"].append({"id": cid, "category": "攻防战", "equip": c["equip"], "keys": c["keys"], "window": 3.0, "cooldown": 4.0,
                             "effects": c["effects"]})
    Path("data/combos.json").write_text(json.dumps(cb, ensure_ascii=False, indent="\t") + "\n")
    rx = json.loads(Path("data/princess_reactions.json").read_text())
    for cid, c in COMBOS.items():
        rx.setdefault("combos", {})[cid] = {"name": c["name"], "description": c["desc"], "lines": combo_lines(cid, "pink")}
    Path("data/princess_reactions.json").write_text(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")
    head = ["攻防战三来源组合的小演出（gen_siege_scenes.py 生成，不要直接改）：第一次触发时播放（CG.play_scene），进 CG 图鉴。"]
    for who, path in (("pink", "data/siege_scenes.json"), ("blue", "data/characters/blue/siege_scenes.json")):
        scenes = {cid: scene(cid, c, who) for cid, c in COMBOS.items()}
        Path(path).write_text(json.dumps({"_说明": head, "scenes": scenes}, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战组合：%d 组（粉 / 蓝小演出各 %d 段）" % (len(COMBOS), len(COMBOS)))


if __name__ == "__main__":
    main()
