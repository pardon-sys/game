"""攻防战的失败小剧场（12 段双人，每一波城墙被攻破时放这一波的那段；可以反复运行，覆盖写）：
  data/theater/siege/siege_fail_<N>.json         普通版
  data/theater/siege/siege_fail_<N>_pants.json   蓝色公主穿着千手痒痒裤时的版本（她的句子换成和裤子有关的，SiegeDirector 按剧情标记选）
台词在 tools/build/siege_text/theaters.py，这里只负责拼装。四幕（每一步标 act）：被抓住 → 弱点被找到 →
两个人的魔力疲倦先后满了、各自爆发（act = burst，怪被震开再回来）、爆发后更怕痒 → 一起笑到认输。
用法：python tools/build/gen_siege_theaters.py
"""
import json
import os
import sys
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
sys.path.insert(0, str(Path(__file__).resolve().parent))
from siege_text.theaters import FOE_NAMES, T  # noqa: E402

P, B, N = "公主", "蓝色的公主", ""
OUT = Path("data/theater/siege")


def tk(who, zone, by, n=8, iv=0.22, fx="hand"):
    return {"do": "tickle", "who": who, "by": by, "repeat": n, "interval": iv, "fx": fx, "zone": zone}


def burst(who, foe_ids, foe_at):
    """一个人爆发：白光、星光爆发 + 释放声，两只怪被震开。"""
    acts = [{"do": "flash", "time": 0.8}, {"do": "sfx", "sound": "star_burst", "volume": -1.0},
            {"do": "sfx", "sound": "water_release", "volume": -2.0}, {"do": "shake", "who": who, "time": 0.5},
            {"do": "bubble", "who": who, "kind": "surprise"}]
    for f in foe_ids:
        x, y = foe_at[f]
        acts.append({"do": "move", "who": f, "to": [x + (-50 if x < 0 else 50), y - 6], "time": 0.25})
    return acts


def build(title, foes, script, pants):
    cast = {"pink": {"kind": "npc:pink_princess", "at": [-24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
            "blue": {"kind": "npc:blue_princess", "at": [24, 10], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    foe_ids, foe_at = [], {}
    for i, key in enumerate(foes):
        fid = "foe%d" % (i + 1)
        foe_ids.append(fid)
        foe_at[fid] = [-44 + i * 88, 0]
        cast[fid] = {"kind": "monster:" + key, "at": foe_at[fid], "dir": "right" if i == 0 else "left", "hidden": True}
    speakers = {"P": P, "B": B, "N": N, "F1": FOE_NAMES.get(foes[0], ""), "F2": FOE_NAMES.get(foes[-1], "")}
    steps = [{"act": 1, "actions": [{"do": "fade_in", "time": 0.5}, {"do": "voice", "state": "giggle"}], "wait": 0.5}]
    act = 1
    for row in script:
        sp, text, tags = row[0], row[1], row[2].split()
        if pants and len(row) > 3:
            text = row[3]
        acts = []
        step_act = None
        for t in tags:
            if t in ("a2", "a3", "a4"):
                act = int(t[1])
            elif t == "in":
                for j, f in enumerate(foe_ids):
                    acts.append({"do": "enter", "who": f, "from": [-90 if j == 0 else 90, 0], "time": 0.5})
            elif t.startswith("p:"):
                acts.append(tk("pink", t[2:], foe_ids[0]))
            elif t.startswith("b:"):
                acts.append(tk("blue", t[2:], foe_ids[-1], fx="brush"))
            elif t == "h2":
                acts += [{"do": "pose", "who": "pink", "visual": "helpless_2"}, {"do": "pose", "who": "blue", "visual": "helpless_2"},
                         {"do": "voice", "state": "laugh"}]
            elif t == "fl":
                acts.append({"do": "flash", "time": 0.3})
            elif t == "laugh":
                acts += [{"do": "bubble", "who": "pink", "kind": "laugh"}, {"do": "bubble", "who": "blue", "kind": "laugh"}]
            elif t in ("burst_p", "burst_b"):
                acts += burst("pink" if t == "burst_p" else "blue", foe_ids, foe_at)
                step_act = "burst"
            elif t == "back":
                acts += [{"do": "move", "who": f, "to": list(foe_at[f]), "time": 0.6} for f in foe_ids]
        st = {"act": step_act or act, "speaker": speakers.get(sp, sp), "text": text}
        if acts:
            st["actions"] = acts
        if step_act == "burst":
            st["wait"] = 1.0
        steps.append(st)
    steps.append({"act": 4, "actions": [{"do": "voice", "state": ""}, {"do": "fade_out", "time": 0.8}], "wait": 0.9})
    return {"name": title, "cast": cast, "steps": steps}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for n, (title, foes, script) in T.items():
        for pants, suffix in ((False, ""), (True, "_pants")):
            data = build("失败：" + title, foes, script, pants)
            (OUT / ("siege_fail_%d%s.json" % (n, suffix))).write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战失败小剧场：%d 段 × 2 版" % len(T))


if __name__ == "__main__":
    main()
