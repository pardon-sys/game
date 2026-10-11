"""装备组合（穿着某件装备 + 指定的怪物 / 陷阱挠到 → 组合）和它们的小演出（可以反复运行，按 id 覆盖）：
  data/combos.json                     分类「装备」的组合（equip: [装备键] 占来源格，keys 是剩下的来源槽）
  data/princess_reactions.json         组合的名字 / 说明 / 台词（蓝色公主版由 gen_blue_character.py 转换）
  data/equip_scenes.json               粉色公主的小演出（只有她穿得上的组合）
  data/characters/blue/equip_scenes.json 蓝色公主的小演出（全部，含千手痒痒裤的两组）
CG 把 equip_scenes 合并进组合演出（CG 图鉴自动出现）。之后再跑 gen_blue_character.py。
用法：python tools/build/gen_equip_scenes.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

P, BLUE, N = "公主", "蓝色的公主", ""
RESTRAINTS = ["snare", "cuffs", "stocks", "binding", "legloop", "clamp", "supine", "prone", "wardrobe", "thigh_pincer",
              "wall_brush", "hanging_hands"]

# id -> {name, desc, equip, keys, effects, cast: [(角色, kind, key, 名字)], who: both / blue,
#        pink: [8 句]（粉色公主）, blue: [8 句]（蓝色公主）}；句子 (说话人, 文本) —— 说话人 None = 当前公主
COMBOS = {
    "eq_anklet_rat": {
        "name": "脚环共鸣", "desc": "羽毛脚环的羽毛还在蹭脚心，挠脚鼠的小爪子又扑上来，机关再补一下——脚心一下子痒到顶。",
        "equip": ["equip_feather_anklet"], "keys": [["rat"], ["*trap"]],
        "effects": [{"type": "burst", "amount": 18}, {"type": "special_next", "count": 3}, {"type": "focus"}],
        "cast": [("monster", "rat", "挠脚鼠"), ("trap", "feather", "羽毛机关")], "who": "both",
        "pink": [(N, "（脚踝上的羽毛脚环一跑起来，白羽毛就一下下蹭过脚心）"),
                 (None, "嘻嘻……脚环……又、又蹭到了……"),
                 (None, "呀——！小老鼠！别、别抓脚心……哈哈哈！"),
                 (None, "机、机关的羽毛也……三、三样都在脚心上……哈哈哈哈！"),
                 (N, "（羽毛、小爪子、机关的羽毛——都挤在同一个小小的脚心上）"),
                 (None, "哈哈哈哈！脚、脚环是来帮我跑快的……不是来帮它们的……哈哈哈！"),
                 (None, "脚趾……脚趾缝也……不行不行哈哈哈哈哈！"),
                 (None, "呼……呼……这个脚环……回去要好好想想要不要戴……")],
        "blue": [(N, "（脚踝上的羽毛脚环一走动，白羽毛就一下下蹭过脚心）"),
                 (None, "……脚环。……在蹭。"),
                 (None, "……！老、老鼠……别抓……脚心……"),
                 (None, "……机关也……噗……三、三样……"),
                 (N, "（羽毛、小爪子、机关——都挤在同一个脚心上）"),
                 (None, "……哈、哈哈……脚、脚心……没那么怕的……哈哈哈……！"),
                 (None, "……脚趾缝……不、不准钻……哈哈哈哈……！"),
                 (None, "……呼。……这个脚环……摘掉。……之后。")],
    },
    "eq_bow_fairy": {
        "name": "铃声派对", "desc": "派对蝴蝶结的铃铛叮铃铃响个不停，小精灵们闻声赶来开派对，旁边的怪也凑了过来——越笑越热闹。",
        "equip": ["equip_party_bow"], "keys": [["fairy"], ["*"]],
        "effects": [{"type": "burst", "amount": 14}, {"type": "rally", "radius": 200.0}, {"type": "dot", "rate": 3.0, "duration": 3.0},
                    {"type": "focus"}],
        "cast": [("monster", "fairy", "小精灵群"), ("monster", "slime", "史莱姆")], "who": "both",
        "pink": [(N, "（腰上的蝴蝶结一晃，小铃铛叮铃——叮铃——）"),
                 (None, "嘻……铃铛在响……好、好吵……"),
                 (None, "小、小精灵们……你们是听到铃声来开派对的吗？！哈哈哈！"),
                 (None, "别、别一起往腰上挤——还有别的怪也来了！哈哈哈哈！"),
                 (N, "（铃声越响，过来的东西越多；越多，她笑得越厉害，铃声就更响）"),
                 (None, "哈哈哈哈！停、停不下来——是铃铛在叫你们的吗？！"),
                 (None, "派、派对的主人……你送的到底是什么啊——哈哈哈哈哈！"),
                 (None, "呼……呼……蝴蝶结……先、先摘下来……")],
        "blue": [(N, "（腰上的蝴蝶结一晃，小铃铛叮铃——叮铃——）"),
                 (None, "……吵。"),
                 (None, "……精、精灵……不是派对……走开……"),
                 (None, "……别、别的也来了……噗……腰……"),
                 (N, "（铃声越响，过来的越多；越多，她越憋不住，铃声就更响）"),
                 (None, "……哈、哈哈……铃、铃铛……别响了……哈哈哈……！"),
                 (None, "……那个人……送的……什么东西……哈哈哈哈……！"),
                 (None, "……摘掉。……现在就摘。")],
    },
    "eq_pad_glove": {
        "name": "垫子被掀开", "desc": "护腋垫挡了太多下，已经瘪得挡不住了——幽灵手套一把掀开，腋下整个露了出来。",
        "equip": ["equip_armpit_pad:spent"], "keys": [["glove"], ["*"]],
        "effects": [{"type": "burst", "amount": 16}, {"type": "expose", "zone": "armpit", "mult": 1.6, "duration": 6.0},
                    {"type": "focus"}],
        "cast": [("monster", "glove", "幽灵手套"), ("monster", "slime", "史莱姆")], "who": "both",
        "pink": [(N, "（护腋垫已经被挠得瘪瘪的，软乎乎地贴在腋下，什么都挡不住了）"),
                 (None, "垫、垫子……怎么扁了……"),
                 (None, "呀！手套……把垫子掀开了——！"),
                 (None, "腋、腋下……整个露出来了……别、别过来……哈哈哈！"),
                 (N, "（垫子被丢到一边，空空的手套和别的怪一起钻进腋下）"),
                 (None, "哈哈哈哈！好、好不容易护着的……一下子全……哈哈哈哈！"),
                 (None, "手、手臂放不下来……哈哈哈哈哈哈！"),
                 (None, "呼……呼……下次……要记得去篝火那里把垫子拍蓬……")],
        "blue": [(N, "（护腋垫已经被挠得瘪瘪的，软乎乎地贴在腋下）"),
                 (None, "……垫子。……扁了。"),
                 (None, "……！掀、掀开了……"),
                 (None, "……腋下……露、露出来了……别……"),
                 (N, "（垫子被丢到一边，空手套和别的怪一起钻进腋下）"),
                 (None, "……哈、哈哈……手、手臂……放不下来……哈哈哈……！"),
                 (None, "……不、不准钻……哈哈哈哈……！"),
                 (None, "……回去。……拍蓬。")],
    },
    "eq_socks_stocks": {
        "name": "袜子被扒掉", "desc": "脚被脚枷锁住，挠脚鼠咬住厚底羊毛袜，一点一点往下扒——脚心慢慢露了出来。",
        "equip": ["equip_wool_socks"], "keys": [["stocks"], ["rat"]],
        "effects": [{"type": "burst", "amount": 14}, {"type": "expose", "zone": "sole", "mult": 1.7, "duration": 6.0},
                    {"type": "dot", "rate": 4.0, "duration": 3.0}, {"type": "focus"}],
        "cast": [("trap", "stocks", "脚枷"), ("monster", "rat", "挠脚鼠")], "who": "both",
        "pink": [(N, "（脚枷咔嗒一声扣住了脚踝。还好——脚上套着厚厚的羊毛袜）"),
                 (None, "哼哼，这次可挠不到我的脚心了！"),
                 (None, "……诶？小老鼠……你、你咬袜子干什么……"),
                 (N, "（小老鼠咬住袜口，一点、一点，往下扒）"),
                 (None, "不、不要扒……脚跟露出来了……脚弓……哈哈……！"),
                 (None, "脚、脚心——全露出来了！呀哈哈哈哈！"),
                 (None, "还、还被锁着……缩不回来……哈哈哈哈哈哈！"),
                 (None, "呼……呼……袜子……袜子还给我……")],
        "blue": [(N, "（脚枷咔嗒一声扣住了脚踝。脚上套着厚厚的羊毛袜）"),
                 (None, "……没用。……隔着袜子。"),
                 (None, "……老鼠。……咬袜子……做什么。"),
                 (N, "（小老鼠咬住袜口，一点、一点，往下扒）"),
                 (None, "……别、别扒……脚跟……"),
                 (None, "……！脚、脚心……露出来了……噗……"),
                 (None, "……锁、锁着……缩不回来……哈哈哈……！"),
                 (None, "……袜子。……还来。")],
    },
    "eq_pants_crawl": {
        "name": "裤内外夹击", "desc": "千手痒痒裤里的手指在里面动，毛毛虫在裤腿外沿着大腿爬，松鼠的尾巴扫屁股——里里外外一起。",
        "equip": ["thousand_pants"], "keys": [["caterpillar"], ["squirrel"]],
        "effects": [{"type": "burst", "amount": 20}, {"type": "root", "duration": 1.5}, {"type": "special_next", "count": 2},
                    {"type": "focus"}],
        "cast": [("monster", "caterpillar", "毛毛虫"), ("monster", "squirrel", "刷刷松鼠")], "who": "blue",
        "blue": [(N, "（紫色的痒痒裤紧紧裹着大腿和屁股。裤子里的手指，又开始一根一根地动）"),
                 (None, "……裤、裤子……又……"),
                 (None, "……毛、毛虫……在裤腿外面……往上爬……！"),
                 (None, "……松、松鼠……尾巴……扫屁股……噗……"),
                 (N, "（里面是手指揉着腿根，外面是一排小脚沿着大腿爬、蓬松的尾巴扫过屁股）"),
                 (None, "……哈、哈哈……里、里外一起……犯规……哈哈哈……！"),
                 (None, "……裤子……还、还配合它们……哈哈哈哈……！"),
                 (None, "……呼……这条裤子……是叛徒。")],
    },
    "eq_pants_bind": {
        "name": "动弹不得的裤子", "desc": "被束缚陷阱困住动不了，千手痒痒裤趁机一起发作，旁边的怪物也凑了上来。",
        "equip": ["thousand_pants"], "keys": [RESTRAINTS, ["*"]],
        "effects": [{"type": "burst", "amount": 18}, {"type": "grab_extend", "duration": 1.5}, {"type": "crit_storm", "duration": 2.5},
                    {"type": "focus"}],
        "cast": [("trap", "stocks", "束缚陷阱"), ("monster", "slime", "史莱姆")], "who": "blue",
        "blue": [(N, "（被陷阱扣住，一动也不能动。就在这时，痒痒裤里的手指像是等了很久似的——一起动了）"),
                 (None, "……！现、现在……？"),
                 (None, "……别、别趁我动不了……腿根……揉……"),
                 (None, "……外、外面的也……过来了……噗……"),
                 (N, "（裤子里的手指轮流捏着屁股，外面的怪物挠着露在外面的地方。挣不开，也躲不了）"),
                 (None, "……哈、哈哈……动、动不了……哈哈哈哈……！"),
                 (None, "……交、交界那里……刮……不行……哈哈哈哈哈……！"),
                 (None, "……呼……裤子……你……记住。")],
    },
}


def tk(by, n, iv):
    return {"do": "tickle", "who": "princess", "by": by, "repeat": n, "interval": iv, "fx": "lines"}


def scene(cid, c, who):
    lines = c[who]
    speaker = BLUE if who == "blue" else P
    src_list = [{"kind": "equip", "key": c["equip"][0].split(":")[0],
                 "name": {"equip_feather_anklet": "羽毛脚环", "equip_party_bow": "派对彩带蝴蝶结", "equip_armpit_pad": "软绵护腋垫",
                          "equip_wool_socks": "厚底羊毛袜", "thousand_pants": "千手痒痒裤"}[c["equip"][0].split(":")[0]]}]
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    for i, (kind, key, name) in enumerate(c["cast"]):
        cast["src%d" % (i + 1)] = {"kind": "%s:%s" % (kind, key), "at": [-32 if i == 0 else 32, 2], "dir": "right" if i == 0 else "left",
                                   "hidden": True}
        src_list.append({"kind": kind, "key": key, "name": name})
    steps = [{"actions": [{"do": "fade_in", "time": 0.4}, {"do": "voice", "state": "giggle"}, {"do": "sources", "list": src_list}],
              "wait": 0.4},
             {"speaker": "", "text": "【装备+来源】%s——%s" % (c["name"], c["desc"]),
              "actions": [{"do": "light", "index": 0}, {"do": "bubble", "who": "princess", "kind": "surprise"}]}]
    for i, (sp, text) in enumerate(lines):
        acts = []
        if i == 2:
            acts += [{"do": "enter", "who": "src1", "from": [-80, 0], "time": 0.5}, {"do": "light", "index": 1}, tk("src1", 6, 0.3)]
        elif i == 3:
            acts += [{"do": "enter", "who": "src2", "from": [80, 0], "time": 0.5}, {"do": "light", "index": 2}, tk("src1", 6, 0.28),
                     tk("src2", 6, 0.28)]
        elif i == 5:
            acts += [{"do": "light", "all": True}, {"do": "pose", "who": "princess", "visual": "helpless_2"}, {"do": "voice", "state": "laugh"},
                     {"do": "shake", "who": "princess", "time": 0.5}, tk("src1", 8, 0.22), tk("src2", 8, 0.22)]
        elif i == 6:
            acts += [{"do": "flash", "time": 0.25}, {"do": "bubble", "who": "princess", "kind": "laugh"}, tk("src1", 8, 0.2), tk("src2", 8, 0.2)]
        elif i == 7:
            acts += [{"do": "voice", "state": ""}, {"do": "pose", "who": "princess", "visual": "helpless_1"}]
        steps.append({"speaker": speaker if sp is None else sp, "text": text, "actions": acts})
    steps.append({"actions": [{"do": "voice", "state": ""}, {"do": "fade_out", "time": 0.6}], "wait": 0.7})
    return {"name": c["name"], "cast": cast, "steps": steps}


def main():
    cb = json.loads(Path("data/combos.json").read_text())
    cb["combos"] = [c for c in cb["combos"] if c.get("category") != "装备"]
    for cid, c in COMBOS.items():
        cb["combos"].append({"id": cid, "category": "装备", "equip": c["equip"], "keys": c["keys"], "window": 2.5, "cooldown": 10.0,
                             "effects": c["effects"]})
    Path("data/combos.json").write_text(json.dumps(cb, ensure_ascii=False, indent="\t") + "\n")
    rx = json.loads(Path("data/princess_reactions.json").read_text())
    for cid, c in COMBOS.items():
        lines = [t for (sp, t) in c.get("pink", c["blue"]) if sp is None][4:7]
        rx.setdefault("combos", {})[cid] = {"name": c["name"], "description": c["desc"], "lines": lines}
    Path("data/princess_reactions.json").write_text(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")
    pink = {cid: scene(cid, c, "pink") for cid, c in COMBOS.items() if c["who"] == "both"}
    blue = {cid: scene(cid, c, "blue") for cid, c in COMBOS.items()}
    head = ["装备组合的小演出（gen_equip_scenes.py 生成，不要直接改）：穿着装备 + 指定的来源挠到时第一次播放（CG.play_scene），进 CG 图鉴。"]
    Path("data/equip_scenes.json").write_text(json.dumps({"_说明": head, "scenes": pink}, ensure_ascii=False, indent="\t") + "\n")
    Path("data/characters/blue/equip_scenes.json").write_text(json.dumps({"_说明": head, "scenes": blue}, ensure_ascii=False, indent="\t") + "\n")
    print("装备组合：%d 组（粉色公主小演出 %d、蓝色公主 %d）" % (len(COMBOS), len(pink), len(blue)))


if __name__ == "__main__":
    main()
