"""检查人物对话文件（data/dialogues/**/<人物>.json，带 nodes 的那种）：
  - entries / next / goto / 选项 next 指向的节点都存在
  - cutscene / theater 引用的过场、小剧场存在；call 是认识的设施方法；npc 在人物表里
  - 条件里读的变量（eq / var）在某个对话的 set.vars / add 里写过
  - 列出每个关键变量被哪些人物读取（选择记忆的覆盖面）
用法：python tools/build/check_dialogues.py（有问题时返回 1）
"""
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
CALLS = {"open_shop", "open_training", "rest", "sleep"}


def ids_in(folder):
    return {p.stem for p in Path(folder).rglob("*.json")}


cutscenes = ids_in("data/cutscenes")
theaters = ids_in("data/theater")
npcs = json.loads(Path("data/actors/npcs.json").read_text())
npcs = npcs.get("npcs", npcs)
errors = []
writes = set()
reads = defaultdict(set)
files = {}
for p in sorted(Path("data/dialogues").rglob("*.json")):
    d = json.loads(p.read_text())
    if isinstance(d, dict) and "nodes" in d:
        files[str(p.relative_to("data/dialogues").with_suffix(""))] = d


def conds(c, name):
    if not c:
        return
    for k in c.get("eq", {}):
        reads[k].add(name)
    for k in c.get("var", {}):
        reads[k].add(name)
    for s in ([c["seen"]] if isinstance(c.get("seen"), str) else c.get("seen", [])):
        f, _, n = s.partition(":")
        if f not in files or n not in files[f]["nodes"]:
            errors.append("%s：seen 指向不存在的 %s" % (name, s))
    for sub in c.get("any", []):
        conds(sub, name)


def effects(fx, name, where):
    if not fx:
        return
    writes.update(fx.get("vars", {}).keys())
    writes.update(fx.get("add", {}).keys())
    if "call" in fx and fx["call"] not in CALLS:
        errors.append("%s %s：不认识的 call %s" % (name, where, fx["call"]))


for name, d in files.items():
    nodes = d["nodes"]
    if "npc" in d and d["npc"] not in npcs:
        errors.append("%s：人物表里没有 %s" % (name, d["npc"]))

    def need(target, where):
        if target and target not in nodes:
            errors.append("%s %s：节点 %s 不存在" % (name, where, target))

    for e in d.get("entries", []):
        need(e.get("node"), "entries")
        conds(e.get("if"), name)
    for nid, n in nodes.items():
        need(n.get("next", ""), nid + ".next")
        for g in n.get("goto", []):
            need(g.get("node"), nid + ".goto")
            conds(g.get("if"), name)
        effects(n.get("set"), name, nid)
        if n.get("cutscene") and n["cutscene"] not in cutscenes:
            errors.append("%s %s：过场 %s 不存在" % (name, nid, n["cutscene"]))
        if n.get("theater") and n["theater"] not in theaters:
            errors.append("%s %s：小剧场 %s 不存在" % (name, nid, n["theater"]))
        if not (n.get("lines") or n.get("choices") or n.get("goto") or n.get("cutscene") or n.get("theater") or n.get("set")):
            errors.append("%s %s：空节点" % (name, nid))
        for i, c in enumerate(n.get("choices", [])):
            need(c.get("next", ""), "%s.choices[%d]" % (nid, i))
            conds(c.get("if"), name)
            effects(c.get("set"), name, "%s.choices[%d]" % (nid, i))

# 过场里的 talk 步骤
for p in Path("data/cutscenes").rglob("*.json"):
    for st in json.loads(p.read_text()).get("steps", []):
        t = st.get("talk")
        if t:
            if t["file"] not in files:
                errors.append("过场 %s：对话文件 %s 不存在" % (p.stem, t["file"]))
            elif t.get("node") and t["node"] not in files[t["file"]]["nodes"]:
                errors.append("过场 %s：%s 没有节点 %s" % (p.stem, t["file"], t["node"]))
        if st.get("theater") and st["theater"] not in theaters:
            errors.append("过场 %s：小剧场 %s 不存在" % (p.stem, st["theater"]))

for k in sorted(reads):
    if k not in writes:
        errors.append("变量 %s 被读取（%s），但没有任何对话写它" % (k, "、".join(sorted(reads[k]))))
print("人物对话 %d 个文件" % len(files))
for k in sorted(reads):
    print("  选择记忆 %s：%d 个人物读取 —— %s" % (k, len(reads[k]), "、".join(sorted(reads[k]))))
for e in errors:
    print("  ✗ " + e)
print("没有问题" if not errors else "%d 个问题" % len(errors))
sys.exit(1 if errors else 0)
