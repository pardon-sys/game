"""生成三来源组合第一次触发时的小演出 data/combo_scenes.json（格式同 data/cgs.json 的 cgs：cast / steps / actions）。

每个三来源组合（data/combos.json 里 keys 有 3 个槽位）一段，约 4–5 秒：
  淡入 → 旁白报出组合名和说明，三个来源依次登场（怪物用 cgs.json 的演员；陷阱没有演员，用挠痒特效代替）
  → 公主一句台词（princess_reactions.json 的 combos 段），一起挠、镜头拉近 → 淡出。
台词步骤自动前进（auto），随时可以按 Esc 跳过。需要手写的演出可以在 CUSTOM 里覆盖，或直接改生成结果。
用法：python tools/build/gen_combo_scenes.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

combos = json.load(open("data/combos.json"))
reactions = json.loads(open("data/princess_reactions.json").read(), strict=False)
actors = json.load(open("data/cgs.json"))["actors"]
# 通配符槽位在演出里用哪只怪物代表
WILDCARD = {"*": "slime", "*trap": "feather"}
# 陷阱来源的挠痒特效
TRAP_FX = {"stocks": "feather", "arm": "feather", "carpet": "lines", "rune": "heart", "conveyor": "lines",
           "brush": "feather", "hand": "hand", "vine": "lines", "fan": "feather", "feather": "feather"}
SPOTS = [(-30, 2), (30, 2), (0, -26)]
ENTER = [(-80, 0), (80, 0), (0, -70)]
CUSTOM = {}


def scene(c):
    cid = c["id"]
    text = reactions["combos"].get(cid, {})
    name = text.get("name", cid)
    desc = text.get("description", "")
    lines = text.get("lines", ["哈哈哈哈！"])
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    enter, tickle = [], []
    for i, slot in enumerate(c["keys"]):
        key = WILDCARD.get(slot[0], slot[0])
        if key in actors:
            who = "src%d" % (i + 1)
            cast[who] = {"kind": "monster:" + key, "at": list(SPOTS[i]), "dir": "left" if SPOTS[i][0] > 0 else "right", "hidden": True}
            enter.append({"do": "enter", "who": who, "from": list(ENTER[i]), "time": 0.5})
            tickle.append({"do": "tickle", "who": "princess", "by": who, "repeat": 5, "interval": 0.26, "fx": "lines"})
        else:
            tickle.append({"do": "tickle", "who": "princess", "repeat": 5, "interval": 0.3, "fx": TRAP_FX.get(key, "feather")})
    steps = [
        {"actions": [{"do": "fade_in", "time": 0.4}, {"do": "voice", "state": "giggle"}], "wait": 0.4},
        {"speaker": "", "text": "【%s】%s——%s" % (c.get("category", "三重组合"), name, desc), "auto": 2.2,
         "actions": enter + [{"do": "bubble", "who": "princess", "kind": "surprise"}] + tickle[:1]},
        {"speaker": "公主", "text": lines[0], "auto": 2.2,
         "actions": [{"do": "pose", "who": "princess", "visual": "helpless_2"}, {"do": "voice", "state": "laugh"},
                     {"do": "camera", "zoom": 1.5, "focus": "princess", "time": 0.4},
                     {"do": "shake", "who": "princess", "time": 0.5}] + tickle},
        {"actions": [{"do": "fade_out", "time": 0.5}, {"do": "voice", "state": ""}], "wait": 0.6},
    ]
    return {"name": name, "cast": cast, "steps": steps}


def main():
    out = {}
    for c in combos["combos"]:
        if len(c.get("keys", [])) >= 3:
            out[c["id"]] = CUSTOM.get(c["id"]) or scene(c)
    data = {
        "_说明": [
            "三来源组合第一次触发时的小演出（CG.play_scene(组合 id)，随时可以按 Esc 跳过）。",
            "scenes：组合 id -> {name, cast, steps}，格式和 data/cgs.json 的 cgs 一样；怪物演员沿用 cgs.json 的 actors。",
            "由 tools/build/gen_combo_scenes.py 生成；手写的演出可以写进脚本的 CUSTOM，或直接改这里（重新生成会覆盖）。",
        ],
        "scenes": out,
    }
    open("data/combo_scenes.json", "w").write(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print(len(out), "段组合演出")


if __name__ == "__main__":
    main()
