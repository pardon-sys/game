"""装备系统的数据（可以反复运行，覆盖写）：
  data/items/equip_<名字>.tres   每件装备（EquipData；图标取 assets/generated/equip_icons.png 的第 n 格，顺序同 gen_equip_art.ICONS）
  data/items/thousand_pants.tres 千手痒痒裤也改成装备（大腿 + 屁股，蓝色公主专用，诅咒）
  data/shop/war_market.json      战乱小镇的商店：补给 + 辅助装备（装备要解锁了才显示）
新装备还要在 scripts/items/item_db.gd 的 PATHS 里登记（这里会打印缺哪些）。
用法：python tools/build/gen_equipment.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

ICONS = ["armpit_pad", "scarf", "wool_socks", "dance_shoes", "waist_sash", "mint_sachet", "chest_guard",
         "training_wraps", "padded_shorts", "party_bow", "feather_anklet", "ice_hairpin", "thousand_pants"]

# 名字 -> (显示名, 部位, 谁能穿, 属性, 部位加减, 挡下次数, 诅咒, 特殊, 好处, 代价, 说明, 价格(0 = 不卖))
EQUIP = {
    "armpit_pad": ("软绵护腋垫", ["armpit"], "", {"speed": 0.95}, {}, {"armpit": 6}, False, "",
                   "挡下 6 次腋下的挠痒", "移动 ×0.95",
                   "两块软乎乎的棉垫，夹在腋下。挠过来的手指先碰到的是垫子——就是走起路来有点别扭。", 15),
    "scarf": ("高领围巾", ["neck"], "", {"laugh_decay": -0.1}, {}, {"neck": 5}, False, "",
              "挡下 5 次脖子的挠痒", "闷笑消减 −10%",
              "厚厚的毛线围巾，一直围到下巴。脖子安全了，可是闷得笑意散不掉。", 10),
    "wool_socks": ("厚底羊毛袜", ["sole"], "", {"speed": 0.95}, {"sole": -0.3}, {}, False, "",
                   "脚心敏感 −0.3", "移动 ×0.95",
                   "鞋垫一样厚的羊毛袜。隔着它挠脚心就没那么痒了，只是走路有点笨重。", 12),
    "dance_shoes": ("轻便舞鞋", ["sole"], "", {"speed": 1.15}, {"sole": 0.25}, {}, False, "",
                    "移动 ×1.15", "脚心敏感 +0.25",
                    "薄薄的芭蕾舞鞋，跑起来轻得像要飞。鞋底也薄得像什么都没穿。", 12),
    "waist_sash": ("束腰布带", ["waist"], "", {}, {"waist": -0.3, "belly": 0.15}, {}, False, "",
                   "腰敏感 −0.3", "肚子敏感 +0.15",
                   "紧紧勒住腰的宽布带。腰挠不进去了，可肚子被挤得更怕痒。", 12),
    "mint_sachet": ("薄荷香囊", ["belly"], "", {"laugh_decay": 0.2}, {"belly": 0.2}, {}, False, "",
                    "闷笑消减 +20%", "肚子敏感 +0.2",
                    "挂在肚子前的薄荷小布袋，凉丝丝的，笑完很快就能平复——就是贴着肚子凉得发痒。", 12),
    "chest_guard": ("护胸软甲", ["chest"], "", {"laugh_gain": -0.05, "speed": 0.9}, {"chest": -0.3}, {}, False, "",
                    "胸敏感 −0.3、闷笑涨幅 −5%", "移动 ×0.9",
                    "保卫队淘汰下来的软甲，护住胸口。有点重。", 18),
    "training_wraps": ("训练绑腿", ["thigh"], "", {"attack": 1.2, "struggle": 0.3}, {"thigh": 0.2}, {}, False, "",
                       "攻击 +20%、挣脱 +30%", "大腿敏感 +0.2",
                       "保卫队员训练时缠在腿上的布条，发力的时候特别稳。勒得大腿一碰就痒。", 14),
    "padded_shorts": ("软垫短裤", ["butt"], "", {}, {"thigh": 0.15}, {"butt": 5}, False, "",
                      "挡下 5 次屁股的挠痒", "大腿敏感 +0.15",
                      "屁股上缝了厚厚的垫子。裤腿却短得露出一大截大腿。", 15),
    "party_bow": ("派对彩带蝴蝶结", ["waist"], "", {"laugh_gain": -0.1}, {}, {}, False, "bell",
                  "闷笑涨幅 −10%", "被挠到时叮铃响，引来附近的怪物",
                  "篝火派对的主人送的大蝴蝶结，系在腰上，挂着一只小铃铛。戴着它就想笑——可惜一被挠，铃铛就叮铃铃地把怪物全叫过来。", 0),
    "feather_anklet": ("羽毛脚环", ["sole"], "", {"speed": 1.1}, {"sole": 0.3}, {}, False, "",
                       "移动 ×1.1", "脚心敏感 +0.3",
                       "小孩们用彩绳和白羽毛编的脚环。跑起来很轻快，羽毛却总是蹭到脚心。", 0),
    "ice_hairpin": ("冰晶发夹", ["neck"], "blue", {"magic_cd": 0.85}, {"neck": 0.1}, {}, False, "",
                    "魔法冷却 −15%", "脖子敏感 +0.1",
                    "雪花形状的小发夹。面包店的奶奶一直替她收着——那是她小时候落在店里的。别在脖子后面的头发上，凉凉的。", 0),
    "thousand_pants": ("千手痒痒裤", ["thigh", "butt"], "blue", {}, {}, {}, True, "",
                       "（无）", "脱不下；闷笑最低 20、移动 ×0.9、魔法 10% 失败",
                       "走出夜迷宫时，几只没有散去的手悄悄缠在蓝色公主的大腿上，变成了一层薄薄的紫色紧身裤——裹着屁股和大腿，脱不下来，时不时还会动一下。", 0),
}


def tres(name):
    disp, slots, owner, mods, zmods, block, cursed, special, pros, cons, desc, _price = EQUIP[name]
    idx = ICONS.index(name)
    item_id = name if name == "thousand_pants" else "equip_" + name

    def gd(v):
        return json.dumps(v, ensure_ascii=False).replace(": ", ": ")

    lines = [
        '[gd_resource type="Resource" script_class="EquipData" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/items/equip_data.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://assets/generated/equip_icons.png" id="2"]', "",
        '[sub_resource type="AtlasTexture" id="icon"]', 'atlas = ExtResource("2")',
        "region = Rect2(%d, 0, 16, 16)" % (idx * 16), "",
        "[resource]", 'script = ExtResource("1")',
        'id = "%s"' % item_id, 'display_name = "%s"' % disp, "description = %s" % gd(desc),
        'icon = SubResource("icon")', "category = 4", "stackable = false", "show_in_hud = false",
        "pickup_emotion = \"%s\"" % ("shy" if cursed else "happy"),
        "slots = Array[String](%s)" % gd(slots), 'owner_id = "%s"' % owner,
        "modifiers = %s" % gd(mods), "zone_mods = %s" % gd(zmods), "block = %s" % gd(block),
        "cursed = %s" % ("true" if cursed else "false"), 'special = "%s"' % special,
        "pros = %s" % gd(pros), "cons = %s" % gd(cons),
    ]
    out = Path("data/items") / (("thousand_pants" if name == "thousand_pants" else "equip_" + name) + ".tres")
    out.write_text("\n".join(lines) + "\n")
    return item_id


def main():
    ids = [tres(n) for n in EQUIP]
    shop = {
        "_说明": ["战乱的小镇里的商店（ShopUI 读取）：补给 + 辅助装备。equip = true 的条目要解锁装备系统（和篝火派对的主人说话）后才显示。"],
        "name": "战时补给站",
        "keeper": "supervisor",
        "items": [
            {"id": "mint", "price": 3, "stock": -1},
            {"id": "clear_dew", "price": 5, "stock": -1},
            {"id": "heart", "price": 6, "stock": 6},
            {"id": "star_candy", "price": 12, "stock": 2},
        ] + [{"id": "equip_" + n, "price": EQUIP[n][11], "stock": 1, "equip": True} for n in EQUIP if EQUIP[n][11] > 0],
    }
    Path("data/shop/war_market.json").write_text(json.dumps(shop, ensure_ascii=False, indent="\t") + "\n")
    db = Path("scripts/items/item_db.gd").read_text()
    missing = [i for i in ids if '"%s"' % i not in db]
    print("装备：%d 件；ItemDB 缺：%s" % (len(ids), missing))


if __name__ == "__main__":
    main()
