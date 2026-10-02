"""检查部位挠痒配置：列出还没分配部位的挠痒来源、用了不存在部位的来源、没被任何来源用到的部位。

部位表：data/actors/princess_ticklish.json；来源 -> 部位：data/tickle_zones.json；来源列表：data/princess_reactions.json 的 sources
（写了 "no_tickle": true 的来源跳过）。
用法：python tools/build/check_zones.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
zones = json.load(open("data/actors/princess_ticklish.json"))["zones"]
table = json.load(open("data/tickle_zones.json"))["sources"]
reactions = json.loads(open("data/princess_reactions.json").read(), strict=False)["sources"]

missing = [k for k, v in reactions.items() if k not in table and not v.get("no_tickle")]
bad = ["%s -> %s" % (k, z) for k, w in table.items() for z in w if z not in zones]
used = {z for w in table.values() for z in w}
unused = [z for z in zones if z not in used]

print("部位：", "、".join("%s(%s ×%s)" % (z, v["name"], v["sensitivity"]) for z, v in zones.items()))
print("还没分配部位的来源：", missing or "无")
print("用了不存在部位的来源：", bad or "无")
print("没被任何来源用到的部位：", unused or "无")
