"""攻防战的失败小剧场（12 段双人，每一波城墙被攻破时放这一波的那段；可以反复运行，覆盖写）：
  data/theater/siege/siege_fail_<N>.json         普通版
  data/theater/siege/siege_fail_<N>_pants.json   蓝色公主穿着千手痒痒裤时的版本（她的句子换成和裤子有关的，SiegeDirector 按剧情标记选）
台词在 tools/build/siege_text/theaters.py，这里只负责拼装。四幕（每一步标 act）：被抓住 → 弱点被找到 →
两个人的魔力疲倦先后满了、各自爆发（act = burst，怪被震开再回来）、爆发后更怕痒 → 一起笑到认输。
演绎（docs/POLISH_RULES.md）：
  - 被抓住以后、怪在场时（爆发震开之前、back 之后）两位公主说的每一句都接着被挠（台词没写 p: / b: 就自动给说话的人补一条 tickle），立绘和舞台跟着抖；
  - 两位公主的立绘按幕换表情（EMOTION：嘴硬 → 憋笑 → 失控 → 爆发 → 失控 2 → 收尾）；
  - 第 4 幕第一步换上这一波的战败 CG（横版大图 siege_fail_<N>，tools/art/import_cg.py 从 assets/generated/SIEGE_CG/ 生成；gen_cgs.py 登记），一直到结尾，挠痒时大图跟着抖、出贴片。
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


# 两位公主的立绘表情按幕（第 1 幕 / 第 2 幕 / 第 3 幕爆发前 / 爆发那一句 / 爆发后 / 第 4 幕 / 收尾）
EMOTION = {
    "P": {1: "angry", 2: "giggle", 3: "helpless_1", "burst": "damaged_burst", "after": "helpless_2", 4: "helpless_2", "end": "damaged"},
    "B": {1: "normal", 2: "giggle", 3: "helpless_1", "burst": "damaged_burst", "after": "helpless_2", 4: "helpless_2", "end": "shy"},
}
CG_PORTRAIT = "siege_fail_%d"


def burst(who, foe_ids, foe_at):
    """一个人爆发：白光、星光爆发 + 释放声，两只怪被震开。"""
    acts = [{"do": "flash", "time": 0.8}, {"do": "sfx", "sound": "star_burst", "volume": -1.0},
            {"do": "sfx", "sound": "water_release", "volume": -2.0}, {"do": "shake", "who": who, "time": 0.5},
            {"do": "bubble", "who": who, "kind": "surprise"}]
    for f in foe_ids:
        x, y = foe_at[f]
        acts.append({"do": "move", "who": f, "to": [x + (-50 if x < 0 else 50), y - 6], "time": 0.25})
    return acts


def build(n, title, foes, script, pants):
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
    present = False     # 怪在不在两个人身边（in 之后、爆发震开之前、back 之后）
    bursts = 0          # 爆发了几个人（两个人都爆发完才算「爆发后」）
    grabbed = False     # 被抓住了（第一次 p: / b: 之后）
    ended = False       # 第 4 幕里怪退走了（之后是收尾）
    cg_shown = False
    for row in script:
        sp, text, tags = row[0], row[1], row[2].split()
        if pants and len(row) > 3:
            text = row[3]
        acts = []
        step_act = None
        tickled = set()
        for t in tags:
            if t in ("a2", "a3", "a4"):
                act = int(t[1])
            elif t == "in":
                present = True
                for j, f in enumerate(foe_ids):
                    acts.append({"do": "enter", "who": f, "from": [-90 if j == 0 else 90, 0], "time": 0.5})
            elif t.startswith("p:"):
                acts.append(tk("pink", t[2:], foe_ids[0]))
                tickled.add("P")
                grabbed = True
            elif t.startswith("b:"):
                acts.append(tk("blue", t[2:], foe_ids[-1], fx="brush"))
                tickled.add("B")
                grabbed = True
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
                present = False
                bursts += 1
            elif t == "back":
                present = True
                acts += [{"do": "move", "who": f, "to": list(foe_at[f]), "time": 0.6} for f in foe_ids]
        if act == 4 and sp == "N" and not tags and cg_shown:
            ended = True
            present = False
        # 怪在场时，公主说话的这一句也接着被挠（没写 p: / b: 的补上）
        if present and grabbed and not ended and sp in ("P", "B") and sp not in tickled:
            if sp == "P":
                acts.append(tk("pink", "sole", foe_ids[0], n=5))
            else:
                acts.append(tk("blue", "thigh" if act < 3 else "butt", foe_ids[-1], n=5, fx="brush"))
        st = {"act": step_act or act, "speaker": speakers.get(sp, sp), "text": text}
        if sp in EMOTION:
            key = "end" if ended else ("burst" if step_act == "burst" else (4 if act == 4 else ("after" if bursts >= 2 and act == 3 else act)))
            st["emotion"] = EMOTION[sp][key]
        if act == 4 and not cg_shown:
            st["portrait"] = CG_PORTRAIT % n
            cg_shown = True
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
            data = build(n, "失败：" + title, foes, script, pants)
            (OUT / ("siege_fail_%d%s.json" % (n, suffix))).write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战失败小剧场：%d 段 × 2 版" % len(T))


if __name__ == "__main__":
    main()
