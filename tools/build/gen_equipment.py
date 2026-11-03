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
         "training_wraps", "padded_shorts", "party_bow", "feather_anklet", "ice_hairpin", "thousand_pants",
         "t_feather_socks", "t_toe_brush", "t_fluff_bra", "t_thigh_ring", "t_pinch_pad", "t_knead_tights",
         "t_feather_shackles", "t_thigh_strap", "t_bell_anklet", "t_mark_patch",
         "mouse_shorts", "mouse_paw_shoes", "palace_ribbon", "palace_corset", "palace_boots", "palace_stockings", "feather_shawl"]

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
# 反省篇（骑士篇之后）：钻鼠洞的报酬——挠脚鼠住在身上，裤子 / 鞋子被强制换成这一套（诅咒，出了鼠洞才能脱）。
# 攻击 ×0.8；发作 = 挠脚鼠乱窜（EquipFx：equip_reactions 的 crit → 暴击，魔力疲倦大涨）；短裤 special = mouse_scent（附近一小圈的怪被引过来）
EQUIP.update({
    "mouse_shorts": ("鼠鼠短裤", ["thigh", "butt"], "pink", {"attack": 0.8}, {"thigh": 0.2, "butt": 0.2}, {}, True, "mouse_scent",
                     "（无）", "脱不下；攻击 ×0.8；挠脚鼠时不时乱窜（暴击）；鼠味把附近的怪引过来",
                     "毛茸茸的灰色鼠鼠短裤，后面拖着一条会动的尾巴。挠脚鼠就住在里面——它说这是「报酬」。", 0),
    "mouse_paw_shoes": ("鼠爪鞋", ["sole"], "pink", {}, {"sole": 0.25}, {}, True, "",
                        "（无）", "脱不下；脚心敏感 +0.25；挠脚鼠时不时钻进鞋里",
                        "露着脚趾的鼠爪拖鞋，鞋底有粉色的肉垫。挠脚鼠最喜欢从短裤一路钻下来，躲进这里。", 0),
})
# 第四章·旧王宫的衣帽间：试穿的三件旧装备（衣架）、自动穿袜机给的丝袜、冻住羽毛披肩鬼掉下来的披肩
EQUIP.update({
    "palace_ribbon": ("小殿下的发带", ["neck"], "", {"magic_cd": 0.9}, {"neck": 0.15}, {}, False, "",
                      "魔法冷却 −10%", "脖子敏感 +0.15",
                      "衣帽间角落里一条粉蓝两色的小发带。系上以后脑袋暖暖的——就是发带的流苏总蹭到后颈。", 0),
    "palace_corset": ("女仆长的束腰", ["waist"], "", {"laugh_gain": -0.05, "speed": 0.95}, {"waist": -0.2, "belly": 0.15}, {}, False, "",
                      "闷笑涨幅 −5%、腰敏感 −0.2", "移动 ×0.95、肚子敏感 +0.15",
                      "勒得紧紧的深蓝束腰。腰挠不进去了，可是肚子被挤得更怕痒，走路也挺得笔直。", 0),
    "palace_boots": ("宫廷长靴", ["sole"], "", {"speed": 0.92}, {}, {"sole": 4}, False, "",
                     "挡下 4 次脚心的挠痒", "移动 ×0.92",
                     "鞋底厚厚的白色高筒靴。挠脚心的手先碰到的是靴底——就是太重了，跑不快。", 0),
    "palace_stockings": ("宫廷丝袜", ["sole"], "", {"laugh_decay": 0.1}, {"sole": -0.2}, {}, False, "",
                         "脚心敏感 −0.2、闷笑消减 +10%", "（无）",
                         "自动穿袜机「清洁」完脚底以后给套上的淡紫色丝袜。滑滑的，隔着它挠就没那么痒了。", 0),
    "feather_shawl": ("羽毛披肩", ["neck"], "", {"laugh_decay": -0.05}, {}, {"neck": 4}, False, "",
                      "挡下 4 次脖子的挠痒", "闷笑消减 −5%",
                      "冻住的羽毛披肩鬼化成的披肩，安安静静的。软乎乎的羽毛围着脖子——偶尔还会自己蹭一下。", 0),
})
# 攻防战的临时痒痒装备（被痒痒裁缝铺 / 捆绑藤怪强制穿上 20 秒；不卖、不进背包）：名字 -> (显示名, 部位, 类别, 属性, 部位加减, 特殊, 好处, 代价, 说明)
TEMP = {
    "t_feather_socks": ("羽毛袜", ["sole"], "tickle", {"speed": 0.8}, {"sole": 0.3}, "",
                        "（无）", "走一步挠一下脚心、移动 ×0.8，跑得越快挠得越重",
                        "袜子内侧铺满了细细的羽毛。每走一步，羽毛就在脚心上扫一下。"),
    "t_toe_brush": ("趾缝刷套", ["sole"], "tickle", {}, {"sole": 0.4}, "",
                    "（无）", "把脚趾一根根扳开刷趾缝、脚心敏感 +0.4",
                    "套在脚上的软刷套：小钩子把脚趾一根根扳开，刷毛钻进趾缝里来回刷。"),
    "t_fluff_bra": ("绒毛胸衣", ["chest"], "tickle", {"laugh_decay": -0.2}, {"chest": 0.3}, "",
                    "（无）", "绒毛随呼吸蹭胸口、闷笑消减 −20%",
                    "里面全是软绒毛的小胸衣。一呼吸，绒毛就蹭一下胸口——越喘越痒。"),
    "t_thigh_ring": ("腿根揉揉环", ["thigh"], "tickle", {}, {"thigh": 0.3}, "",
                     "（无）", "环里的手指揉腿根、大腿敏感 +0.3",
                     "套在大腿根上的软环，里面藏着几根手指，一圈一圈地揉。"),
    "t_pinch_pad": ("捏捏臀垫", ["butt"], "tickle", {}, {"butt": 0.3}, "",
                    "（无）", "一下下捏屁股、屁股敏感 +0.3",
                    "贴在屁股上的软垫，左边捏一下、右边捏一下。"),
    "t_knead_tights": ("揉揉紧身裤", ["thigh", "butt"], "tickle", {"speed": 0.9}, {"thigh": 0.2, "butt": 0.2}, "",
                       "（无）", "揉腿根、捏屁股、移动 ×0.9",
                       "紧紧裹住大腿和屁股的紧身裤，里面全是手。"),
    "t_feather_shackles": ("羽毛脚镣", ["sole"], "bind", {"speed": 0.55}, {}, "no_dash",
                           "（无）", "两脚踝连在一起：不能冲刺、移动 ×0.55，羽毛扫脚踝",
                           "两只脚踝被一根短链连在一起，只能小步小步地走。链子上的羽毛扫着脚踝。"),
    "t_thigh_strap": ("夹腿绑带", ["thigh"], "bind", {"speed": 0.6}, {"thigh": 0.2}, "",
                      "（无）", "大腿绑在一起：移动 ×0.6，绑带内侧挠腿",
                      "把两条大腿绑在一起的宽绑带，内侧一圈软毛。"),
    "t_bell_anklet": ("铃铛脚链", ["sole"], "curse", {}, {}, "bell_move",
                      "（无）", "一动就叮铃响，把附近的怪引过来",
                      "挂满小铃铛的脚链。走一步响一下，怪物全听得见。"),
    "t_mark_patch": ("痒痒印记臀贴", ["butt"], "curse", {"laugh_gain": 0.15}, {"butt": 0.2}, "mark",
                     "（无）", "怪物优先找她、闷笑涨幅 +15%",
                     "贴在屁股上的发光印记。怪物闻得到，全朝这里来。"),
}
for k, (disp, slots, kind, mods, zmods, special, pros, cons, desc) in TEMP.items():
    EQUIP[k] = (disp, slots, "", mods, zmods, {}, False, special, pros, cons, desc, 0, kind)


def tres(name):
    disp, slots, owner, mods, zmods, block, cursed, special, pros, cons, desc, _price = EQUIP[name][:12]
    kind = EQUIP[name][12] if len(EQUIP[name]) > 12 else ""
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
    if kind:
        lines += ["temporary = true", 'kind = "%s"' % kind]
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
