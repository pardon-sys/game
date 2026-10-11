"""攻防战的三来源组合（装备 + 陷阱 / 塔 + 怪）和它们的小演出（可以反复运行，按 id 覆盖）：
  data/combos.json                        分类「攻防战」的组合（equip 占来源格，keys 是剩下的来源槽：怪物 / 敌塔 enemy_* / 陷阱 hazard_*）
  data/princess_reactions.json            组合的名字 / 说明 / 台词（蓝色公主版由 gen_blue_character.py 转换）
  data/siege_scenes.json                  粉色公主的小演出（她会遇到的组合）
  data/characters/blue/siege_scenes.json  蓝色公主的小演出
每组都有专属特效（effects 里的 siege_fx，由 SiegeDirector.on_combo_effect 放）。CG 把 siege_scenes 合并进组合演出（进 CG 图鉴）。
用法：python tools/build/gen_siege_scenes.py，之后再跑 gen_blue_character.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
P, BLUE, N = "公主", "蓝色的公主", ""

# id -> {name, desc, equip, keys, effects, src: [(kind, key, 名字, 舞台演员?)], who: pink / blue / both, pink: [...], blue: [...]}
COMBOS = {
    "sg_foot_assault": {
        "name": "脚心总攻", "desc": "羽毛袜里的羽毛、吊网里伸出的手、挠脚鼠的小爪子——三样东西全挤在同一个脚心上。",
        "equip": ["equip_t_feather_socks"], "keys": [["enemy_net"], ["rat"]],
        "effects": [{"type": "burst", "amount": 20}, {"type": "root", "duration": 2.5, "extend": True}, {"type": "special_next", "count": 3},
                    {"type": "siege_fx", "kind": "vortex"}, {"type": "focus"}],
        "src": [("equip", "equip_t_feather_socks", "羽毛袜", False), ("siege", "etower_net", "吊网塔", False), ("monster", "rat", "挠脚鼠", True)],
        "who": "pink",
        "pink": [(N, "（她被吊网吊在半空，两只脚够不着地。羽毛袜里的羽毛跟着脚一晃一晃地扫）"),
                 (None, "脚、脚够不着地……袜子里的羽毛还在扫……嘻嘻……"),
                 (None, "网眼里……伸出手来了！抓住脚踝——呀，挠脚心！"),
                 (None, "下面还有老鼠在跳——够、够到我的脚了！哈哈哈！"),
                 (N, "（网里的手扳住脚掌往后压，羽毛贴着脚心扫，小老鼠的爪子从下面一下下挠——三样都在同一个脚心上）"),
                 (None, "哈哈哈哈！三、三样一起……脚心要坏掉了哈哈哈哈！"),
                 (None, "脚趾缝也……羽毛钻进去了……扳、扳着不让缩哈哈哈哈！"),
                 (None, "呼……呼……再也不要穿这种袜子了……")],
    },
    "sg_toe_bloom": {
        "name": "趾缝开花", "desc": "脚踝被羽毛脚镣锁着跑不掉，趾缝刷套把脚趾一根根扳开，脚心刷刷塔的刷子手顺势刷进每一条趾缝。",
        "equip": ["equip_t_toe_brush", "equip_t_feather_shackles"], "keys": [["enemy_sole_tower"]],
        "effects": [{"type": "burst", "amount": 18}, {"type": "expose", "zone": "sole", "mult": 1.7, "duration": 6.0},
                    {"type": "siege_fx", "kind": "brush_flowers"}, {"type": "focus"}],
        "src": [("equip", "equip_t_toe_brush", "趾缝刷套", False), ("equip", "equip_t_feather_shackles", "羽毛脚镣", False),
                ("siege", "etower_sole_tower", "脚心刷刷塔", False)],
        "who": "pink",
        "pink": [(N, "（两只脚踝被短链连着，只能小步小步地挪。刷套的小钩子钩住脚趾，一根一根往外扳）"),
                 (None, "脚、脚趾被扳开了……跑、跑不快……嘻嘻……"),
                 (None, "刷子手飞过来了！抓、抓住脚踝了——"),
                 (None, "趾缝！刷子刷进趾缝里了——哈哈哈哈！"),
                 (N, "（脚趾被扳成一朵张开的花，刷毛在每一条趾缝里来回刷；脚镣上的羽毛还在扫脚踝）"),
                 (None, "哈哈哈哈！一、一条一条地刷……全部都刷到了哈哈哈！"),
                 (None, "脚、脚心也……扳着脚板刮……不行不行哈哈哈哈哈！"),
                 (None, "呼……脚趾……合不拢了……")],
    },
    "sg_bear_bra": {
        "name": "熊抱胸衣", "desc": "藤蔓把手绑在头顶，拥抱小熊一把抱紧，胸衣里的绒毛被挤得贴着胸口蹭——想喘口气都痒。",
        "equip": ["equip_t_fluff_bra"], "keys": [["hug_bear"], ["bind_vine"]],
        "effects": [{"type": "burst", "amount": 20}, {"type": "grab_extend", "seconds": 2.0}, {"type": "expose", "zone": "chest", "mult": 1.5, "duration": 5.0},
                    {"type": "siege_fx", "kind": "heart_fluff"}, {"type": "focus"}],
        "src": [("equip", "equip_t_fluff_bra", "绒毛胸衣", False), ("monster", "hug_bear", "拥抱小熊", True), ("monster", "bind_vine", "捆绑藤怪", True)],
        "who": "pink",
        "pink": [(N, "（胸衣里的绒毛随着呼吸一下下蹭着胸口。她刚想喘口气——）"),
                 (None, "绒、绒毛……一呼吸就蹭……嘻嘻……"),
                 (None, "藤、藤蔓！手被绑到头顶了——"),
                 (None, "小熊——别抱！抱紧了绒毛就……哈哈哈！"),
                 (N, "（小熊抱得越紧，胸衣就被挤得越贴；绒毛在胸口上蹭，小熊的爪子在腋下抓，藤尖在腰上扫）"),
                 (None, "哈哈哈哈！喘、喘不过气——一喘就更痒哈哈哈！"),
                 (None, "腋、腋下也……手被吊着放不下来哈哈哈哈！"),
                 (None, "呼……这件胸衣……一定要扔掉……")],
    },
    "sg_carried_mark": {
        "name": "被抬走的印记", "desc": "屁股上的痒痒印记把怪物全招来了：藤蔓拉拽塔一勾，搬运小鬼一扛，一路挠着直接运进了敌塔。",
        "equip": ["equip_t_mark_patch"], "keys": [["enemy_vine_pull"], ["carrier"]],
        "effects": [{"type": "burst", "amount": 16}, {"type": "siege_lockup"}, {"type": "siege_fx", "kind": "mark_trail"}, {"type": "focus"}],
        "src": [("equip", "equip_t_mark_patch", "痒痒印记臀贴", False), ("siege", "etower_vine_pull", "藤蔓拉拽塔", False),
                ("monster", "carrier", "搬运小鬼队", True)],
        "who": "pink",
        "pink": [(N, "（屁股上的印记一闪一闪地发光，怪物们的眼睛全朝这边看了过来）"),
                 (None, "大、大家都在看我的……屁股？！"),
                 (None, "藤蔓！勾、勾住腰了——往那边拖！"),
                 (None, "小鬼们……别、别扛起来！一边扛一边挠哈哈哈！"),
                 (N, "（藤蔓拖着，小鬼扛着，三只小手轮流在发光的印记上捏——一路往敌塔运过去）"),
                 (None, "哈哈哈哈！印、印记那里不要捏——越捏越亮哈哈哈！"),
                 (None, "要、要被关进去了——蓝色的公主——救救我哈哈哈哈！"),
                 (None, "呜……下次一定要先把那个贴纸撕掉……")],
    },
    "sg_pants_frenzy": {
        "name": "裤子大暴走", "desc": "狂欢图腾让千手痒痒裤兴奋得停不下来，腿根爬爬蛛又在外面一起爬——裤子里外的手指一起在腿根上爆发。",
        "equip": ["thousand_pants"], "keys": [["enemy_totem"], ["thigh_spider"]],
        "effects": [{"type": "burst", "amount": 20}, {"type": "special_next", "count": 3}, {"type": "dot", "rate": 4.0, "duration": 4.0},
                    {"type": "siege_fx", "kind": "purple_hands"}, {"type": "focus"}],
        "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("siege", "etower_totem", "狂欢图腾", False), ("monster", "thigh_spider", "腿根爬爬蛛", True)],
        "who": "blue",
        "blue": [(N, "（远处的狂欢图腾咚咚地响。每响一下，她的裤子就跟着抽一下）"),
                 (None, "……图腾。……裤子……在兴奋。"),
                 (None, "……蜘、蜘蛛……爬上来了……外、外面也……"),
                 (None, "……里面在揉……外面在点……噗……哈……"),
                 (N, "（裤子里的拇指按进腿根揉圈，外面的蜘蛛八只脚一起点；屁股上的手跟着图腾的鼓点一下下捏）"),
                 (None, "……哈哈哈哈……鼓、鼓点……跟着鼓点捏……不准……哈哈哈！"),
                 (None, "……交、交界那条线……里外一起刮……哈哈哈哈哈……！"),
                 (None, "……呼。……那个图腾。……一定要拆掉。")],
    },
    "sg_broom_wall": {
        "name": "扫帚下的城墙", "desc": "城墙羽毛扫帚扫过来的一瞬间，裤子里的手一起动、壁虎钻进裙底——她一脚踩空，被挠下了城墙。",
        "equip": ["thousand_pants"], "keys": [["hazard_broom"], ["gecko"]],
        "effects": [{"type": "burst", "amount": 18}, {"type": "siege_knockoff"}, {"type": "siege_fx", "kind": "feather_storm"}, {"type": "focus"}],
        "src": [("equip", "thousand_pants", "千手痒痒裤", False), ("siege", "hazard_broom", "城墙羽毛扫帚", False), ("monster", "gecko", "爬墙壁虎", True)],
        "who": "blue",
        "blue": [(N, "（巨大的羽毛扫帚沿着城墙顶扫了过来。她正要换到另一行——）"),
                 (None, "……扫帚。……躲开——"),
                 (None, "……！裤、裤子……这时候动……"),
                 (None, "……壁、壁虎……钻进裙子……"),
                 (N, "（羽毛从脖子扫到脚踝，裤子里的手在腿根上猛地一抓，壁虎顺着大腿往上爬——她脚下一软）"),
                 (None, "……哈哈哈哈……站、站不住……要、要掉下去了……！"),
                 (None, "……掉、掉下去的时候……也在挠……哈哈哈哈……！"),
                 (None, "……摔、摔下来了。……裤子。……你是故意的。")],
    },
    "sg_bell_tide": {
        "name": "铃声引来的潮水", "desc": "铃铛脚链一路叮铃铃地响，把羽毛蝠群全引了过来；痒痒泡泡潮一扫，她被包进泡泡里飘着，蝙蝠围着泡泡扫。",
        "equip": ["equip_t_bell_anklet"], "keys": [["hazard_bubble"], ["bat_swarm"]],
        "effects": [{"type": "burst", "amount": 16}, {"type": "rally", "radius": 220.0}, {"type": "grab_extend", "seconds": 2.0},
                    {"type": "siege_fx", "kind": "bell_ripple"}, {"type": "focus"}],
        "src": [("equip", "equip_t_bell_anklet", "铃铛脚链", False), ("siege", "hazard_bubbles", "痒痒泡泡潮", False), ("monster", "bat_swarm", "羽毛蝠群", True)],
        "who": "both",
        "pink": [(N, "（脚踝上的铃铛叮铃——叮铃——每走一步都响）"),
                 (None, "铃、铃铛好吵……怪物全听见了……"),
                 (None, "泡泡潮！被、被包进去了——飘起来了！"),
                 (None, "蝙蝠……围着泡泡转圈……羽毛从泡泡外面伸进来了！哈哈哈！"),
                 (N, "（她在泡泡里一挣，铃铛就响；铃铛一响，更多蝙蝠就飞过来，羽毛隔着泡泡壁扫个不停）"),
                 (None, "哈哈哈哈！别、别动……一动铃铛就响……可是好痒哈哈哈！"),
                 (None, "脚、脚心也……泡泡里躲不开哈哈哈哈！"),
                 (None, "呼……铃铛……快点掉下来吧……")],
        "blue": [(N, "（脚踝上的铃铛叮铃——叮铃——）"),
                 (None, "……吵。……都听见了。"),
                 (None, "……泡泡。……飘起来了。"),
                 (None, "……蝙蝠……围着泡泡……羽毛……噗……"),
                 (N, "（她一挣，铃铛就响；越响，蝙蝠越多，羽毛隔着泡泡扫大腿和脚心）"),
                 (None, "……哈哈哈哈……别、别响……一挣就响……哈哈哈！"),
                 (None, "……大、大腿……泡泡里……躲不开……哈哈哈哈……！"),
                 (None, "……铃铛。……拆掉。")],
    },
    "sg_strap_tornado": {
        "name": "夹腿龙卷", "desc": "夹腿绑带让她跑不动，痒痒龙卷风把她卷起来转圈，腿根揉揉塔的小手趁着转圈一下下揉——最后被甩飞出去。",
        "equip": ["equip_t_thigh_strap"], "keys": [["hazard_tornado"], ["enemy_thigh_tower"]],
        "effects": [{"type": "burst", "amount": 18}, {"type": "root", "duration": 1.5}, {"type": "dot", "rate": 3.0, "duration": 3.0},
                    {"type": "siege_fx", "kind": "wind_lines"}, {"type": "focus"}],
        "src": [("equip", "equip_t_thigh_strap", "夹腿绑带", False), ("siege", "hazard_tornado", "痒痒龙卷风", False),
                ("siege", "etower_thigh_tower", "腿根揉揉塔", False)],
        "who": "both",
        "pink": [(N, "（两条大腿被绑带绑在一起，只能一蹦一蹦地挪）"),
                 (None, "跑、跑不动……龙卷风过来了——"),
                 (None, "转、转起来了！绑着腿转圈……"),
                 (None, "小、小手飞过来了——揉、揉腿根！哈哈哈！"),
                 (N, "（转一圈，飞来的小手就揉一下腿根；绑带内侧的软毛也跟着蹭——她并着腿越转越快）"),
                 (None, "哈哈哈哈！转、转一圈揉一下……晕、晕了哈哈哈！"),
                 (None, "要、要被甩出去了——哇啊啊哈哈哈哈！"),
                 (None, "呼……天、天在转……腿还在痒……")],
        "blue": [(N, "（两条大腿被绑带绑在一起。她面无表情地一蹦一蹦）"),
                 (None, "……绑着。……跑不了。"),
                 (None, "……转、转起来了。"),
                 (None, "……小手……揉腿根……转着……揉……噗……"),
                 (N, "（转一圈，小手就揉一下腿根；裤子里的手也跟着节奏捏屁股——绑带把腿夹得更紧）"),
                 (None, "……哈哈哈哈……一、一圈一下……裤、裤子也……哈哈哈！"),
                 (None, "……甩、甩出去了……哈哈哈哈……！"),
                 (None, "……天在转。……腿根。……还在痒。")],
    },
}


def tk(by, n, iv):
    return {"do": "tickle", "who": "princess", "by": by, "repeat": n, "interval": iv, "fx": "lines"}


def scene(cid, c, who):
    lines = c[who]
    speaker = BLUE if who == "blue" else P
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    src_list = []
    actors = []
    for kind, key, name, on_stage in c["src"]:
        src_list.append({"kind": kind, "key": key, "name": name})
        if on_stage:
            aid = "src%d" % (len(actors) + 1)
            cast[aid] = {"kind": "monster:%s" % key, "at": [-28 if not actors else 28, 2], "dir": "right" if not actors else "left", "hidden": True}
            actors.append(aid)
    first = actors[0] if actors else None
    steps = [{"actions": [{"do": "fade_in", "time": 0.4}, {"do": "voice", "state": "giggle"}, {"do": "sources", "list": src_list}], "wait": 0.4},
             {"speaker": "", "text": "【三来源组合】%s——%s" % (c["name"], c["desc"]),
              "actions": [{"do": "light", "index": 0}, {"do": "bubble", "who": "princess", "kind": "surprise"}]}]
    for i, (sp, text) in enumerate(lines):
        acts = []
        if i == 2:
            acts.append({"do": "light", "index": 1})
            if first:
                acts += [{"do": "enter", "who": first, "from": [-80, 0], "time": 0.5}, tk(first, 6, 0.3)]
        elif i == 3:
            acts.append({"do": "light", "index": 2})
            for a in actors:
                if a != first or len(actors) == 1:
                    acts += [{"do": "enter", "who": a, "from": [80, 0], "time": 0.5}] if a != first else []
                acts.append(tk(a, 6, 0.28))
        elif i == 5:
            acts += [{"do": "light", "all": True}, {"do": "pose", "who": "princess", "visual": "helpless_2"}, {"do": "voice", "state": "laugh"},
                     {"do": "shake", "who": "princess", "time": 0.5}] + [tk(a, 8, 0.22) for a in actors]
            if not actors:
                acts.append({"do": "flash", "time": 0.2})
        elif i == 6:
            acts += [{"do": "flash", "time": 0.25}, {"do": "bubble", "who": "princess", "kind": "laugh"}] + [tk(a, 8, 0.2) for a in actors]
        elif i == 7:
            acts += [{"do": "voice", "state": ""}, {"do": "pose", "who": "princess", "visual": "helpless_1"}]
        steps.append({"speaker": speaker if sp is None else sp, "text": text, "actions": acts})
    steps.append({"actions": [{"do": "voice", "state": ""}, {"do": "fade_out", "time": 0.6}], "wait": 0.7})
    return {"name": c["name"], "cast": cast, "steps": steps}


def main():
    cb = json.loads(Path("data/combos.json").read_text())
    cb["combos"] = [c for c in cb["combos"] if c.get("category") != "攻防战"]
    for cid, c in COMBOS.items():
        cb["combos"].append({"id": cid, "category": "攻防战", "equip": c["equip"], "keys": c["keys"], "window": 3.0, "cooldown": 12.0,
                             "effects": c["effects"]})
    Path("data/combos.json").write_text(json.dumps(cb, ensure_ascii=False, indent="\t") + "\n")
    rx = json.loads(Path("data/princess_reactions.json").read_text())
    for cid, c in COMBOS.items():
        src = c.get("pink", c.get("blue"))
        lines = [t for (sp, t) in src if sp is None][4:7]
        rx.setdefault("combos", {})[cid] = {"name": c["name"], "description": c["desc"], "lines": lines}
    Path("data/princess_reactions.json").write_text(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")
    pink = {cid: scene(cid, c, "pink") for cid, c in COMBOS.items() if "pink" in c}
    blue = {cid: scene(cid, c, "blue") for cid, c in COMBOS.items() if "blue" in c}
    head = ["攻防战三来源组合的小演出（gen_siege_scenes.py 生成，不要直接改）：第一次触发时播放（CG.play_scene），进 CG 图鉴。"]
    Path("data/siege_scenes.json").write_text(json.dumps({"_说明": head, "scenes": pink}, ensure_ascii=False, indent="\t") + "\n")
    Path("data/characters/blue/siege_scenes.json").write_text(json.dumps({"_说明": head, "scenes": blue}, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战组合：%d 组（粉色公主小演出 %d、蓝色公主 %d）" % (len(COMBOS), len(pink), len(blue)))


if __name__ == "__main__":
    main()
