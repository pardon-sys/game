"""反省篇第四章（追加事件）的物品：16×16 图标 + data/items/<id>.tres（KeyItem，不能使用、背包里能看）。
  smile_badge     笑脸徽记（七枚集齐在王座前厅的徽记台换女王的羽毛发饰）
  music_sheet     笑声乐谱（三片：钟面暗格 / 送餐 / 浴场镜子；王座前厅的笑声地砖按它踩）
  queen_music_box 女王的八音盒（石像问答全对；王座间 Boss 战里用，MusicBoxItem，R 键）
新物品还要在 scripts/items/item_db.gd 的 PATHS 里登记。
用法：python tools/art/gen_palace_items.py
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.chdir(Path(__file__).resolve().parents[2])
from gen_expansion import canvas  # noqa: E402
from palette import OUT, add_outline  # noqa: E402

GOLD, GOLD_D, INK = (240, 200, 80, 255), (190, 140, 50, 255), (60, 40, 30, 255)


def i_smile_badge():
    img, d = canvas(16, 16)
    d.ellipse((2, 2, 13, 13), fill=GOLD)
    d.arc((2, 2, 13, 13), 0, 360, fill=GOLD_D)
    d.point((6, 6), fill=INK)
    d.point((9, 6), fill=INK)
    d.arc((5, 6, 10, 11), 20, 160, fill=INK)
    d.point((4, 9), fill=(255, 150, 160, 255))
    d.point((11, 9), fill=(255, 150, 160, 255))
    return add_outline(img)


def i_music_sheet():
    img, d = canvas(16, 16)
    d.polygon([(2, 2), (13, 1), (14, 13), (3, 14)], fill=(245, 235, 210, 255))
    for y in (4, 7, 10):
        d.line((3, y, 13, y - 1), fill=(170, 150, 120, 255))
    d.ellipse((5, 8, 7, 10), fill=INK)
    d.line((7, 9, 7, 4), fill=INK)
    d.ellipse((9, 6, 11, 8), fill=INK)
    d.line((11, 7, 11, 2), fill=INK)
    return add_outline(img)


def i_queen_music_box():
    img, d = canvas(16, 16)
    d.rectangle((2, 7, 13, 14), fill=(200, 120, 160, 255))
    d.rectangle((2, 7, 13, 8), fill=GOLD)
    d.polygon([(2, 7), (4, 3), (15, 3), (13, 7)], fill=(225, 150, 185, 255))
    d.line((14, 10, 15, 10), fill=GOLD_D)
    d.point((15, 9), fill=GOLD_D)
    d.ellipse((6, 9, 9, 12), fill=GOLD)
    return add_outline(img)


ITEMS = {
    "smile_badge": ("笑脸徽记", "金色的小徽记，上面刻着一张咧嘴笑的脸。王座前厅的徽记台上，有七个刚好放得下它的小凹槽。", i_smile_badge, True),
    "music_sheet": ("笑声乐谱（残片）", "一小片泛黄的乐谱，音符画得歪歪扭扭的，旁边写着「踩」。三片拼起来，就是王座前厅地砖的顺序。", i_music_sheet, True),
    "queen_music_box": ("女王的八音盒", "粉色的小八音盒。打开它，会放出一段很久以前的笑声。……王座间的画像，好像很怕听到它。", i_queen_music_box, False),
}

TRES = """[gd_resource type="Resource" script_class="{cls}" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/{script}.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/generated/item_{id}.png" id="2"]

[resource]
script = ExtResource("1")
icon = ExtResource("2")
id = "{id}"
display_name = "{name}"
description = "{desc}"
{key_line}category = {cat}
stackable = {stack}
show_in_hud = false
hotkey = "{hotkey}"
pickup_emotion = "happy"
"""


def main():
    for iid, (name, desc, fn, stack) in ITEMS.items():
        fn().save(OUT / ("item_%s.png" % iid))
        box = iid == "queen_music_box"   # 八音盒能用（王座间 Boss 战，R 键）：MusicBoxItem
        Path("data/items/%s.tres" % iid).write_text(TRES.format(id=iid, name=name, desc=desc, stack="true" if stack else "false",
            cls="MusicBoxItem" if box else "KeyItem", script="music_box_item" if box else "key_item",
            key_line="" if box else 'key_type = "palace"\n', cat=0 if box else 1, hotkey="use_special" if box else ""))
    print("第四章追加事件的物品：", ", ".join(ITEMS))


if __name__ == "__main__":
    main()
