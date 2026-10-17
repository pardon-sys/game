"""攻防战笑倒 CG（每种攻城怪 / Boss 一段，粉色 / 蓝色公主各一版；可以反复运行，覆盖写）：
  data/siege_cgs.json                     粉色公主版：actors（舞台演员：攻城怪的场景 + 图）、cgs（death_siege_<键>）、death（来源键 → CG）
  data/characters/blue/siege_cgs.json     蓝色公主版
CG 播放器把它们合并进 cgs.json 的数据（像巢穴 CG 一样）。台词在 tools/build/siege_text/cgs_*.py，这里只负责拼装。
四幕（每一步标 act）：1 被抓住、嘴硬 → 2 弱点被找到、开始破功 → 3 魔力疲倦满了、爆发（act = burst，立绘 fatigue_burst，
怪被震开再回来）、爆发后更怕痒 → 4 彻底笑倒。立绘按幕换：defeat_1 → defeat_2 → fatigue_burst → defeat_2。
用法：python tools/build/gen_siege_cgs.py
"""
import json
import os
import sys
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
sys.path.insert(0, str(Path(__file__).resolve().parent))
from burst_lines import PORTRAIT as BURST_PORTRAIT  # noqa: E402
from siege_text import cgs_1, cgs_2, cgs_3, cgs_bosses  # noqa: E402

PINK, BLUE = "公主", "蓝色的公主"
CG = {**cgs_1.CGS, **cgs_2.CGS, **cgs_3.CGS, **cgs_bosses.CGS}
BOSSES = ("troll_general", "gale_bear", "puppet_master", "carnival_fortress")
# 用刷子 / 机械手指、不用羽毛的怪（羽毛标签换成手）
NO_FEATHER = ("puppet_master", "carnival_fortress")
ACT_PORTRAIT = {1: "defeat_1", 2: "defeat_2", 3: "defeat_2", 4: "defeat_2"}

MON_META = json.loads(Path("assets/generated/siege/monsters.json").read_text())
ACTOR_SCENE = {
    "carnival_fortress": ("carnival_fortress", "fortress"),
    "cart": ("siege_cart", "cart"), "hook": ("hook_climber", "hook"), "bind_vine": ("bind_vine", "vine"), "gecko": ("wall_gecko", "gecko"),
    "shield_crab": ("shield_crab", "shield_crab"), "bat_swarm": ("feather_bat_swarm", "bat_swarm"), "carrier": ("carrier_imps", "carrier"),
    "warm_slime": ("warm_slime", "warm_slime"), "thigh_spider": ("thigh_spider", "thigh_spider"), "hug_bear": ("hug_bear", "hug_bear"),
    "suck_jelly": ("suck_jelly", "suck_jelly"), "twin_ghost": ("twin_ghost", "twin_ghost_a"),
    "troll_general": ("troll_general", "general"),
    "gale_bear": ("gale_bear", "gale_bear"),
    "puppet_master": ("puppet_master", "puppet_master"),
    "goblin_engineer": ("goblin_engineer", "engineer"), "horn_bugler": ("horn_bugler", "bugler"),
}


def actor(key):
    if key == "carnival_fortress":
        return {"scene": "res://scenes/siege/monsters/carnival_fortress.tscn",
                "sprite": {"texture": "res://assets/generated/siege/fortress_v2_hull.png", "offset": [0, -200], "scale": 0.055}}
    scene, spr = ACTOR_SCENE[key]
    _x, _y, _w, h = MON_META[spr + "_0"]
    # 按图集键引用（CGActor.atlas_region），图集重新打包也不会错位
    result = {"scene": "res://scenes/siege/monsters/%s.tscn" % scene,
              "sprite": {"texture": "res://assets/generated/siege/monsters.png", "atlas": "res://assets/generated/siege/monsters.json",
                         "key": spr + "_0", "offset": [0, -h / 2]}}
    if key in ("gale_bear", "puppet_master"):
        result["sprite"]["scale"] = 0.55
    return result


def A(do, **kw):
    kw["do"] = do
    return kw


def tk(n=5, iv=0.3, fx="lines"):
    return A("tickle", who="princess", by="foe", repeat=n, interval=iv, fx=fx)


def foe_at(key):
    if key == "carnival_fortress":
        return [55, 4]
    return [40, 8] if key in BOSSES else [22, 8]


def burst_actions(at):
    """爆发：白光、星光爆发 + 释放声，怪被震开（和 burst_lines.burst_steps 的爆发一样）。"""
    return [A("flash", time=0.8), A("sfx", sound="star_burst", volume=-1.0), A("sfx", sound="water_release", volume=-2.0),
            A("voice", state=""), A("shake", who="princess", time=0.5), A("camera", zoom=1, focus="princess", time=0.5),
            A("move", who="foe", to=[at[0] + 60, at[1] - 6], time=0.25)]


def tag_actions(t, key, speaker, at):
    pink = speaker == PINK
    feather = "hand" if key in NO_FEATHER else "feather"
    if t == "in":
        return [A("enter", who="foe", **{"from": [90, 0]}, time=0.6), A("bubble", who="princess", kind="surprise")]
    if t == "tk":
        return [tk()]
    if t == "tk2":
        return [tk(8, 0.22)]
    if t == "g1":
        return [A("pose", who="princess", visual="giggle", anim="idle"), A("voice", state="giggle")]
    if t == "h1":
        return [A("pose", who="princess", visual="helpless_1", anim="helpless"), A("voice", state="laugh")]
    if t == "h2":
        return [A("pose", who="princess", visual="helpless_2"), A("voice", state="laugh")]
    if t in ("ft", "pt"):
        zone = "sole" if pink else ("thigh" if t == "ft" else "butt")
        return [A("tickle", who="princess", by="foe", repeat=3, interval=0.35, fx=feather if t == "ft" else "hand", zone=zone)]
    if t == "fl":
        return [A("flash", time=0.4)]
    if t == "sh":
        return [A("shake", who="princess", time=0.4)]
    if t == "hop":
        return [A("hop", who="foe", count=2)]
    if t == "taunt":
        return [A("taunt", who="foe")]
    if t == "laugh":
        return [A("bubble", who="princess", kind="laugh")]
    if t == "zoom":
        return [A("camera", zoom=1.5, focus="princess", time=0.5), A("shake", who="princess", time=1.0)]
    if t == "unzoom":
        return [A("camera", zoom=1, focus="princess", time=0.4), A("bubble", who="princess", kind="shy")]
    if t == "back":
        return [A("move", who="foe", to=list(at), time=0.6), A("voice", state="giggle")]
    if t == "burst":
        return burst_actions(at)
    return []


def build(key, entry, who):
    speaker = PINK if who == "pink" else BLUE
    script = entry[who]
    at = foe_at(key)
    steps = [{"act": 1, "portrait": ACT_PORTRAIT[1], "actions": [A("fade_in", time=0.7), A("voice", state="giggle")], "wait": 0.8}]
    act = 1
    burst_done = False
    for sp, text, tags in script:
        tags = tags.split()
        for t in tags:
            if t in ("a2", "a3", "a4"):
                act = int(t[1])
        acts = []
        for t in tags:
            acts += tag_actions(t, key, speaker, at)
        st = {"act": act, "speaker": {"P": speaker, "F": entry["foe"], "N": ""}[sp], "text": text, "actions": acts}
        if "burst" in tags:
            st["act"] = "burst"
            st["portrait"] = BURST_PORTRAIT
            st["wait"] = 1.1
            burst_done = True
        elif act == 3 and burst_done:
            st["portrait"] = BURST_PORTRAIT
        else:
            st["portrait"] = ACT_PORTRAIT[act]
        steps.append(st)
    steps.append({"act": 4, "actions": [A("voice", state=""), A("fade_out", time=0.8)], "wait": 0.9})
    return {"name": entry["title"][0 if who == "pink" else 1],
            "cast": {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
                     "foe": {"kind": "monster:" + key, "at": at, "dir": "left", "hidden": True}},
            "steps": steps}


def main():
    actors = {k: actor(k) for k in ACTOR_SCENE}
    death = {k: "death_siege_" + k for k in CG}
    for who, path, note in (("pink", "data/siege_cgs.json", "攻防战攻城怪的笑倒 CG（gen_siege_cgs.py 生成，不要直接改）：CG 播放器合并进 cgs.json。"),
                            ("blue", "data/characters/blue/siege_cgs.json", "蓝色公主版的攻防战笑倒 CG（gen_siege_cgs.py 生成）。")):
        data = {"_说明": [note], "actors": actors, "death": death, "portraits": {},
                "cgs": {"death_siege_" + k: build(k, e, who) for k, e in CG.items()}}
        Path(path).write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战笑倒 CG：%d 段 × 2 版" % len(CG))


if __name__ == "__main__":
    main()
