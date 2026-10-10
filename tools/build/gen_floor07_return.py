"""生成新的第七层「第七层·归途」（levels/floor_07_return）：走出第八层的小房间之后，粉色公主带着蓝色公主往下走到的地方。
（和原来的第七层「升天回廊」不是同一张图；先做到这里，之后再设计。）
  地图：楼梯下来的平台（spawn from_shelter，存档点）→ 一段有柱子的走廊 → 尽头一块写着「（待续）」的石碑。过道里不放怪。
  人物：粉色公主操控，蓝色公主跟着（blue_princess follow=true）；不能切换（no_switch）。
  过场：f7r_arrive（到达时 2~3 句，结尾黄字「（待续）」）。对话：data/dialogues/floor_07/return.json。
用法：python tools/build/gen_floor07_return.py，然后 build_level.gd -- floor=floor_07_return
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

FID = "floor_07_return"
W, H = 34, 13
g = [["#"] * W for _ in range(H)]
cells = {}


def room(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "."


def put(x, y, spec):
    cells.setdefault((x, y), []).append(spec)


# 平台（左）、走廊（中）、尽头的小厅（右）
room(2, 3, 9, 9)
room(10, 5, 25, 7)
room(26, 3, 31, 9)
for x in (13, 17, 21):          # 走廊里的柱子
    g[5][x] = "#"
    g[7][x + 2] = "#"
put(5, 3, "prop type=stairs_up")
put(5, 4, "spawn id=from_shelter")
put(5, 5, "player")
put(6, 5, "blue_princess follow=true ai=false")
put(3, 8, "savepoint place=第七层·归途")
put(29, 4, "sign dialogue=sign7r_end")
for (x, y) in ((2, 2), (9, 2), (26, 2), (31, 2), (14, 4), (22, 4)):
    if g[y][x] == "#":
        put(x, y, "torch lit=true")

specs, pool = {}, list("ABCDEFGHIJKLMNOQRSUVXYZ")
fixed = {"player": "P", "torch lit=true": "t"}
for (x, y), sp in cells.items():
    spec = " + ".join(sp)
    ch = fixed.get(spec) or specs.get(spec)
    if ch is None:
        ch = specs[spec] = pool.pop(0)
    g[y][x] = ch
head = ("[level]\n# 第七层·归途（tools/build/gen_floor07_return.py 生成，不要直接改）\nintro =\nintro_cutscene = f7r_arrive\n"
        "ambient = 0.46,0.42,0.6\nno_switch = true\n[legend]\n# = wall\n. = floor\nP = player\nt = torch lit=true\n")
legend = "".join("%s = %s\n" % (c, s) for s, c in specs.items())
out = Path("levels") / FID
out.mkdir(parents=True, exist_ok=True)
(out / "map.txt").write_text(head + legend + "\n[map]\n" + "\n".join("".join(r) for r in g) + "\n")
(out / "design.json").write_text(json.dumps({"_说明": ["第七层·归途（gen_floor07_return.py 生成）：先做到这里——楼梯平台、走廊、写着「（待续）」的石碑。"]},
                                            ensure_ascii=False, indent="\t") + "\n")

P, BLUE, S = "公主", "蓝色的公主", "石碑"
Path("data/dialogues/floor_07/return.json").write_text(json.dumps({
    "sign7r_end": [{"speaker": S, "text": "（石碑上的字被磨掉了。只剩下一行歪歪扭扭的小字：「（待续）」）"},
                   {"speaker": P, "text": "……待续？", "emotion": "surprise"},
                   {"speaker": BLUE, "text": "……前面的路，还没有。"}],
}, ensure_ascii=False, indent="\t") + "\n")


def A(do, **kw):
    kw["do"] = do
    return kw


ARRIVE = {"name": "第七层·归途", "letterbox": True, "skippable": True, "steps": [
    {"actions": [A("fade_in", time=1.0)], "wait": 1.0},
    {"speaker": P, "text": "第七层……？我们之前走过这里吗？……好像不太一样。", "emotion": "surprise"},
    {"speaker": BLUE, "text": "……路，变了。"},
    {"speaker": P, "text": "没关系！这次我们两个一起走！", "emotion": "happy"},
    {"actions": [A("hint", text="（待续）")], "wait": 1.0},
]}
cut = Path("data/cutscenes/floor_07")
cut.mkdir(parents=True, exist_ok=True)
(cut / "f7r_arrive.json").write_text(json.dumps(ARRIVE, ensure_ascii=False, indent="\t") + "\n")

floors = json.loads(Path("data/floors.json").read_text())
lst = floors["floors"]
if not any(f["id"] == FID for f in lst):
    i = next(i for i, f in enumerate(lst) if f["id"] == "floor_08_shelter") + 1
    lst.insert(i, {"id": FID, "name": "第七层·归途", "scene": "res://levels/%s/floor.tscn" % FID, "group": "floor_07", "music": "dungeon"})
    Path("data/floors.json").write_text(json.dumps(floors, ensure_ascii=False, indent="\t") + "\n")
print("%s：%dx%d" % (FID, W, H))
