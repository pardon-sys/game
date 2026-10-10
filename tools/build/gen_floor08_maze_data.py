"""第八层夜迷宫的来源 / 组合数据（可以反复运行，按键覆盖）：
  data/tickle_zones.json      新来源的部位权重（大腿 / 屁股为主——她最怕的地方）
  data/princess_reactions.json 新来源的名字和台词（粉色公主版；蓝色公主的版本由 gen_blue_character.py 转换）、新组合的名字 / 说明 / 台词
  data/combos.json            新组合（「第八层·夜迷宫」分类，11 组）和来源分组（怪物 / 陷阱）
之后再跑 gen_blue_character.py、gen_combo_scenes.py。
用法：python tools/build/gen_floor08_maze_data.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

P = "公主"


def L(text, emotion=None):
    s = {"speaker": P, "text": text}
    if emotion:
        s["emotion"] = emotion
    return s


# 来源键 -> (名字, 部位权重, 怪物 / 陷阱, 第一次遇到, calm, giggle, helpless_1, helpless_2, special)
SOURCES = {
    "maze_hand": ("千手的紫手", {"thigh": 3, "butt": 3, "waist": 1, "sole": 1, "armpit": 1}, "monster",
                  ["……看不见的手？！", "有、有什么贴在身上了——！", "手、手指在动……！"],
                  ["谁、谁在摸？！", "看不见……"], ["嘻嘻……什么在挠……"], ["哈哈哈！看不见的手哈哈哈！"],
                  ["哈哈哈哈！好多只——看不见哈哈哈哈！"], ["呀——大腿上一下子全是手指——哈哈哈哈！"]),
    "glow_moth": ("夜光羽蛾", {"thigh": 3, "butt": 1, "neck": 1}, "monster",
                  ["发、发光的蛾子……好漂亮……", "噫！翅膀上的粉撒到腿上了！", "痒痒的……发着光……"],
                  ["粉、粉掉下来了！", "别扇翅膀！"], ["嘻嘻……亮晶晶的粉……"], ["哈哈哈！鳞粉好痒哈哈哈！"],
                  ["哈哈哈哈！大腿上全是粉哈哈哈哈！"], ["呀——鳞粉一下子钻进大腿内侧——哈哈哈哈！"]),
    "dream_fluff": ("梦绒球", {"thigh": 4, "butt": 1}, "monster",
                    ["软、软乎乎的球……", "粘、粘在腿上了！甩不掉！", "它、它在慢慢地蹭……"],
                    ["下、下去！", "别粘着！"], ["嘻嘻……软绵绵的……"], ["哈哈哈！一直蹭大腿哈哈哈！"],
                    ["哈哈哈哈！甩、甩不掉哈哈哈哈！"], ["呀——绒毛一下子全竖起来了——哈哈哈哈！"]),
    "lamp_imp": ("偷灯小鬼", {"sole": 2, "waist": 1, "thigh": 1}, "monster",
                 ["小、小黑鬼……戴着灭烛帽？", "它把灯吹灭了！", "还、还来挠脚——！"],
                 ["别吹灯！", "走开！"], ["嘻嘻……趁黑挠……"], ["哈哈哈！黑漆漆的哈哈哈！"],
                 ["哈哈哈哈！看不见哈哈哈哈！"], ["呀——灯一灭就扑过来了——哈哈哈哈！"]),
    "laugh_jar": ("笑声收集瓶", {"waist": 2, "thigh": 1, "armpit": 1}, "monster",
                  ["瓶、瓶子会跑？！", "它在装我的笑声……", "装满了会怎样……"],
                  ["别、别装！", "不许笑……"], ["嘻嘻……瓶子在吸……"], ["哈哈哈！越笑装得越快哈哈哈！"],
                  ["哈哈哈哈！要满了哈哈哈哈！"], ["呀——瓶子一开，笑声全炸出来了——哈哈哈哈！"]),
    "mirror_puddle": ("镜面水洼", {"butt": 3, "thigh": 1}, "trap",
                      ["水洼里……有我的倒影……", "倒影里伸出手来了！", "从、从下面挠……！"],
                      ["别从下面！", "倒影走开！"], ["嘻嘻……水里的手……"], ["哈哈哈！倒影挠屁股哈哈哈！"],
                      ["哈哈哈哈！水面全是手哈哈哈哈！"], ["呀——倒影一下子抓住屁股——哈哈哈哈！"]),
    "shadow_vine": ("影子缠腿藤", {"thigh": 4}, "trap",
                    ["影子里长出藤蔓……", "缠、缠住腿了！动不了！", "藤尖在大腿内侧画圈……"],
                    ["松开！", "动不了……"], ["嘻嘻……藤尖……"], ["哈哈哈！缠着腿挠哈哈哈！"],
                    ["哈哈哈哈！越缠越紧哈哈哈哈！"], ["呀——藤蔓一下子缠到大腿根——哈哈哈哈！"]),
    "feather_curtain": ("羽毛门帘", {"thigh": 3, "waist": 1, "neck": 1}, "trap",
                        ["门、门帘是羽毛做的……", "穿过去的时候刷到腿了！", "从大腿一路刷过去……"],
                        ["等它卷起来！", "别刷……"], ["嘻嘻……羽毛帘子……"], ["哈哈哈！帘子刷腿哈哈哈！"],
                        ["哈哈哈哈！整面帘子哈哈哈哈！"], ["呀——羽毛从大腿一直刷到腰——哈哈哈哈！"]),
    "cradle_bench": ("摇篮长椅", {"butt": 4, "thigh": 1}, "trap",
                     ["一张摇来摇去的长椅……", "坐一下休息……", "椅、椅子下面有手？！"],
                     ["起、起来！", "椅子下面……"], ["嘻嘻……摇着摇着……"], ["哈哈哈！椅下的手挠屁股哈哈哈！"],
                     ["哈哈哈哈！起不来哈哈哈哈！"], ["呀——摇到最高的时候挠屁股——哈哈哈哈！"]),
    "hand_gate": ("千手之门", {"thigh": 3, "butt": 2}, "trap",
                  ["门上……刻着好多手印。", "推开的时候，门后伸出手来了！", "直、直接贴到腿上……"],
                  ["门后有手！", "别拉！"], ["嘻嘻……门里……"], ["哈哈哈！门后的手哈哈哈！"],
                  ["哈哈哈哈！门里全是手哈哈哈哈！"], ["呀——门一开就一起扑上来——哈哈哈哈！"]),
    "hand_shadow": ("千手的影子", {"thigh": 2, "butt": 2, "waist": 1}, "trap",
                    ["好、好大的手影……", "它在看我！", "被看到的地方……凉凉的……"],
                    ["别看！", "躲起来……"], ["嘻嘻……被看着……"], ["哈哈哈！影子召来好多手哈哈哈！"],
                    ["哈哈哈哈！被看到了哈哈哈哈！"], ["呀——影子一眨眼，手全涌过来了——哈哈哈哈！"]),
    "hand_rhythm": ("手的节奏", {"thigh": 3, "butt": 3, "waist": 1}, "trap",
                    ["身上的手……一起停下来了……", "它们在等什么……", "一、一起来了——！"],
                    ["别一起……", "屏、屏住……"], ["嘻嘻……要来了……"], ["哈哈哈！一起挠哈哈哈！"],
                    ["哈哈哈哈！全部一起哈哈哈哈！"], ["呀——全身的手同时——哈哈哈哈！"]),
    # 第五轮：追逐怪、遮眼蝠、墙缝刷轮、垂落吊手、千手痒痒裤
    "night_stalker": ("夜啼追手", {"waist": 2, "thigh": 2, "butt": 1}, "monster",
                      ["后、后面有东西在追！", "好多手臂……一团影子……", "被、被抱住了——！"],
                      ["放开！", "别抱！"], ["嘻嘻……抱得好紧……"], ["哈哈哈！抱着挠哈哈哈！"],
                      ["哈哈哈哈！跑不掉哈哈哈哈！"], ["呀——所有手臂一起收紧——哈哈哈哈！"]),
    "blind_bat": ("遮眼蝠", {"neck": 3, "armpit": 1}, "monster",
                  ["蝙、蝙蝠扑到脸上了！", "看、看不见了！", "翅膀在扫脖子……"],
                  ["眼睛！", "走开！"], ["嘻嘻……看不见……"], ["哈哈哈！看不见更痒哈哈哈！"],
                  ["哈哈哈哈！翅膀哈哈哈哈！"], ["呀——看不见的时候一下扫到脖子——哈哈哈哈！"]),
    "wall_brush": ("墙缝刷轮", {"thigh": 3, "butt": 3}, "trap",
                   ["墙、墙缝里有刷子！", "夹、夹住了！", "刷子在转……"],
                   ["缩回去！", "别转……"], ["嘻嘻……刷来刷去……"], ["哈哈哈！刷大腿哈哈哈！"],
                   ["哈哈哈哈！转得好快哈哈哈哈！"], ["呀——两只刷子一起刷屁股——哈哈哈哈！"]),
    "hanging_hands": ("垂落吊手", {"waist": 3, "belly": 2}, "trap",
                      ["头顶……有手垂下来了！", "被、被吊起来了！", "脚够不着地……"],
                      ["放我下来！", "别晃！"], ["嘻嘻……吊着……"], ["哈哈哈！吊着挠腰哈哈哈！"],
                      ["哈哈哈哈！下不来哈哈哈哈！"], ["呀——吊到最高的时候挠肚子——哈哈哈哈！"]),
    "thousand_pants": ("千手痒痒裤", {"thigh": 3, "butt": 3}, "trap",
                       ["裤、裤子在动……？！", "里面……有手指……", "大腿上……一圈都是……"],
                       ["别、别动……", "安静点……"], ["嘻嘻……裤子里……"], ["哈哈哈！裤子在挠哈哈哈！"],
                       ["哈哈哈哈！脱、脱不掉哈哈哈哈！"], ["呀——裤子里的手指一起动了——哈哈哈哈！"]),
}

# 组合 id -> (名字, 说明, 来源, 效果, 粉色公主台词)
CATEGORY = "第八层·夜迷宫"
COMBOS = {
    "mz_moth_curtain": ("蛾粉羽帘", "鳞粉落在大腿上，羽毛门帘再刷一遍，紫手趁机贴上来。", ["glow_moth", "feather_curtain", "maze_hand"],
                        [{"type": "burst", "amount": 20}, {"type": "root", "duration": 1.2}, {"type": "special_next", "count": 2}, {"type": "focus"}],
                        ["鳞粉加羽毛加手——哈哈哈！", "腿、腿上全是——哈哈哈哈！"]),
    "mz_mirror_vine": ("镜中藤影", "藤蔓缠住大腿，倒影里的手专挑屁股。", ["mirror_puddle", "shadow_vine", "maze_hand"],
                       [{"type": "burst", "amount": 22}, {"type": "dot", "rate": 4.0, "duration": 3.0}, {"type": "cover_hands", "zone": "butt", "count": 1},
                        {"type": "focus"}],
                       ["缠着腿、倒影里的手——哈哈哈！", "动不了还被挠——哈哈哈哈！"]),
    "mz_fluff_jar": ("梦绒笑瓶", "梦绒球蹭得停不下来，笑声全被瓶子装走，紫手闻声而来。", ["dream_fluff", "laugh_jar", "maze_hand"],
                     [{"type": "burst", "amount": 16}, {"type": "laugh_radius_boost", "mult": 2.0, "duration": 8.0}, {"type": "summon_hands", "count": 3},
                      {"type": "focus"}],
                     ["笑、笑声被装走了——哈哈哈！", "手、手听到了——哈哈哈哈！"]),
    "mz_cradle_moth": ("摇篮夜蛾", "坐在摇篮长椅上被鳞粉撒满大腿，椅子下的手挠屁股，被摇得起不来。", ["cradle_bench", "glow_moth", "maze_hand"],
                       [{"type": "burst", "amount": 18}, {"type": "root", "duration": 2.0}, {"type": "dot", "rate": 5.0, "duration": 2.0}, {"type": "focus"}],
                       ["起、起不来——哈哈哈！", "摇着、撒着、挠着——哈哈哈哈！"]),
    "mz_curtain_vine": ("门帘缠藤", "羽毛刷、藤蔓缠、绒球粘——三样全在大腿上。", ["feather_curtain", "shadow_vine", "dream_fluff"],
                        [{"type": "burst", "amount": 22}, {"type": "crit_storm", "duration": 3.0}, {"type": "focus"}],
                        ["大、大腿上三样——哈哈哈！", "刷、缠、粘——哈哈哈哈！"]),
    # 第六轮：水洼相关的组合不再一下子召出一大堆手（只盖一只 / 笑声圈只放大一点）
    "mz_mirror_jar": ("镜中笑瓶", "倒影里的笑声把瓶子一下子灌满——瓶塞飞了出去，倒影里的手趁机贴上屁股。", ["mirror_puddle", "laugh_jar", "maze_hand"],
                      [{"type": "burst", "amount": 16}, {"type": "jar_burst"}, {"type": "cover_hands", "zone": "butt", "count": 1}, {"type": "focus"}],
                      ["瓶、瓶子要炸了——哈哈哈！", "全、全都听到了——哈哈哈哈！"]),
    "mz_dark_raid": ("熄灯偷袭", "冷光被吹灭，黑暗里的手全都屏住，然后一起挠下来。", ["lamp_imp", "dream_fluff", "maze_hand"],
                     [{"type": "burst", "amount": 14}, {"type": "light_drain", "to": 0.05}, {"type": "rhythm_now"}, {"type": "focus"}],
                     ["灯、灯灭了——哈哈哈！", "黑漆漆的全是手——哈哈哈哈！"]),
    "mz_shadow_bench": ("影下长椅", "坐着的时候被千手的影子看见——涌出来的手先扑向屁股。", ["hand_shadow", "cradle_bench", "maze_hand"],
                        [{"type": "burst", "amount": 18}, {"type": "summon_hands", "count": 4}, {"type": "cover_hands", "zone": "butt", "count": 1},
                         {"type": "focus"}],
                        ["被、被看到了——哈哈哈！", "屁、屁股——哈哈哈哈！"]),
    "mz_gate_hands": ("门后千手", "推开千手之门的瞬间，门后的手直接缠上大腿。", ["hand_gate", "shadow_vine", "maze_hand"],
                      [{"type": "burst", "amount": 20}, {"type": "cover_hands", "zone": "thigh", "count": 2}, {"type": "focus"}],
                      ["门、门后全是手——哈哈哈！", "直、直接贴上来了——哈哈哈哈！"]),
    "mz_moth_mirror_curtain": ("蛾影镜帘", "鳞粉被水面和帘子反射得到处都是，笑声传得更远了一点。", ["glow_moth", "feather_curtain", "mirror_puddle"],
                               [{"type": "burst", "amount": 15}, {"type": "laugh_radius_boost", "mult": 1.3, "duration": 5.0}, {"type": "focus"}],
                               ["亮、亮晶晶的——哈哈哈！", "到处都是粉——哈哈哈哈！"]),
    "mz_rhythm_combo": ("节奏连击", "身上的手一起狠挠的那一下，被藤蔓缠住、绒球粘住，躲不开——再来一次。", ["hand_rhythm", "dream_fluff", "shadow_vine"],
                        [{"type": "burst", "amount": 18}, {"type": "root", "duration": 1.5}, {"type": "rhythm_again"}, {"type": "focus"}],
                        ["躲、躲不开——哈哈哈！", "又、又来一次——哈哈哈哈！"]),
}


def main():
    tz = json.load(open("data/tickle_zones.json"))
    for k, v in SOURCES.items():
        tz["sources"][k] = v[1]
    open("data/tickle_zones.json", "w").write(json.dumps(tz, ensure_ascii=False, indent="\t") + "\n")

    rx = json.loads(open("data/princess_reactions.json").read(), strict=False)
    for k, (name, _w, kind, first, calm, giggle, h1, h2, special) in SOURCES.items():
        rx["sources"][k] = {"name": name, "first_encounter": [L(first[0], "surprise"), L(first[1], "shy"), L(first[2], "angry")],
                            "calm": calm, "giggle": giggle, "helpless_1": h1, "helpless_2": h2, "special": special}
    for cid, (name, desc, _keys, _fx, lines) in COMBOS.items():
        rx["combos"][cid] = {"name": name, "description": desc, "lines": lines}
    open("data/princess_reactions.json", "w").write(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")

    cb = json.load(open("data/combos.json"))
    for k, v in SOURCES.items():
        group = cb["groups"]["monster" if v[2] == "monster" else "trap"]
        if k not in group:
            group.append(k)
    cb["combos"] = [c for c in cb["combos"] if c["id"] not in COMBOS]
    for cid, (_n, _d, keys, fx, _l) in COMBOS.items():
        cb["combos"].append({"id": cid, "category": CATEGORY, "keys": [[k] for k in keys], "window": 2.5, "cooldown": 8.0, "effects": fx})
    open("data/combos.json", "w").write(json.dumps(cb, ensure_ascii=False, indent="\t") + "\n")
    print("夜迷宫：%d 个来源、%d 组组合" % (len(SOURCES), len(COMBOS)))


if __name__ == "__main__":
    main()
