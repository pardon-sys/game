"""装备系统的像素图（输出到 assets/generated/）：
  equip_icons.png   16x16 × 13   装备图标（顺序同 ICONS；tools/build/gen_equipment.py 按序号取）
  equip_slot.png    20x20 × 2    装备页的部位格底图（空 / 锁着）
用法：python tools/art/gen_equip_art.py
"""
from PIL import Image, ImageDraw

from palette import OUT, add_outline

ICONS = ["armpit_pad", "scarf", "wool_socks", "dance_shoes", "waist_sash", "mint_sachet", "chest_guard",
         "training_wraps", "padded_shorts", "party_bow", "feather_anklet", "ice_hairpin", "thousand_pants",
         # 攻防战里被敌人强制穿上的临时痒痒装备（粉紫色调）
         "t_feather_socks", "t_toe_brush", "t_fluff_bra", "t_thigh_ring", "t_pinch_pad", "t_knead_tights",
         "t_feather_shackles", "t_thigh_strap", "t_bell_anklet", "t_mark_patch",
         # 反省篇：挠脚鼠住在里面的鼠鼠装（诅咒）
         "mouse_shorts", "mouse_paw_shoes",
         # 第四章·旧王宫衣帽间：试穿的旧装备、自动穿袜机的丝袜、羽毛披肩鬼掉下来的披肩
         "palace_ribbon", "palace_corset", "palace_boots", "palace_stockings", "feather_shawl", "clock_watch", "queen_hairpin"]


def canvas():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def icon(name):
    img, d = canvas()
    if name.startswith("t_"):
        t_icon(name, img, d)
        return add_outline(img)
    if name == "armpit_pad":      # 软绵护腋垫：两块圆圆的粉色软垫 + 带子
        d.ellipse((2, 5, 7, 12), fill=(255, 205, 225, 255))
        d.ellipse((9, 5, 14, 12), fill=(255, 205, 225, 255))
        d.line((7, 7, 9, 7), fill=(200, 140, 180, 255))
        d.point((4, 7), fill=(255, 240, 248, 255))
        d.point((11, 7), fill=(255, 240, 248, 255))
    elif name == "scarf":         # 高领围巾：红色长围巾，一端垂下
        d.rounded_rectangle((2, 4, 13, 8), 2, fill=(220, 80, 90, 255))
        d.rectangle((9, 8, 12, 14), fill=(200, 60, 75, 255))
        for x in (3, 6, 9, 12):
            d.point((x, 6), fill=(255, 180, 170, 255))
        d.line((9, 14, 12, 14), fill=(255, 220, 160, 255))
    elif name == "wool_socks":    # 厚底羊毛袜：米白的厚袜子
        d.rectangle((5, 2, 10, 9), fill=(240, 230, 210, 255))
        d.polygon([(5, 9), (10, 9), (13, 12), (13, 14), (5, 14)], fill=(240, 230, 210, 255))
        d.line((5, 4, 10, 4), fill=(200, 180, 150, 255))
        d.rectangle((5, 13, 13, 14), fill=(180, 150, 120, 255))
    elif name == "dance_shoes":   # 轻便舞鞋：浅蓝的芭蕾鞋 + 丝带
        d.ellipse((2, 8, 14, 14), fill=(150, 200, 255, 255))
        d.ellipse((4, 9, 12, 12), fill=(220, 240, 255, 255))
        d.line((7, 8, 5, 3), fill=(255, 170, 210, 255))
        d.line((9, 8, 11, 3), fill=(255, 170, 210, 255))
    elif name == "waist_sash":    # 束腰布带：棕色宽带子 + 扣
        d.rectangle((1, 6, 14, 10), fill=(160, 110, 80, 255))
        d.rectangle((6, 5, 9, 11), fill=(230, 200, 110, 255))
        d.rectangle((7, 7, 8, 9), fill=(160, 110, 80, 255))
    elif name == "mint_sachet":   # 薄荷香囊：绿色小布袋 + 叶子
        d.ellipse((3, 6, 12, 14), fill=(120, 200, 150, 255))
        d.rectangle((6, 4, 9, 6), fill=(90, 160, 120, 255))
        d.polygon([(8, 4), (12, 1), (11, 5)], fill=(160, 240, 170, 255))
        d.point((6, 10), fill=(220, 255, 230, 255))
    elif name == "chest_guard":   # 护胸软甲：灰蓝的软甲
        d.polygon([(3, 3), (12, 3), (13, 8), (8, 14), (2, 8)], fill=(140, 160, 190, 255))
        d.line((8, 4, 8, 12), fill=(200, 215, 235, 255))
        d.line((4, 6, 12, 6), fill=(110, 130, 160, 255))
    elif name == "training_wraps":  # 训练绑腿：缠着的白布条 + 红绳
        for y in range(3, 14, 3):
            d.line((5, y, 11, y + 1), fill=(235, 230, 220, 255), width=2)
        d.line((4, 3, 4, 14), fill=(200, 60, 70, 255))
    elif name == "padded_shorts":   # 软垫短裤：鼓鼓的粉白短裤
        d.rectangle((3, 4, 12, 7), fill=(250, 220, 235, 255))
        d.polygon([(3, 7), (7, 7), (7, 12), (2, 12)], fill=(250, 220, 235, 255))
        d.polygon([(8, 7), (12, 7), (13, 12), (8, 12)], fill=(250, 220, 235, 255))
        d.line((3, 4, 12, 4), fill=(255, 160, 200, 255))
    elif name == "mouse_shorts":    # 鼠鼠短裤：灰色毛绒短裤 + 一条卷尾巴 + 探出头的小老鼠
        d.rectangle((3, 4, 12, 7), fill=(160, 160, 170, 255))
        d.polygon([(3, 7), (7, 7), (7, 12), (2, 12)], fill=(160, 160, 170, 255))
        d.polygon([(8, 7), (12, 7), (13, 12), (8, 12)], fill=(160, 160, 170, 255))
        d.line((3, 4, 12, 4), fill=(255, 190, 210, 255))
        d.arc((11, 7, 16, 13), 270, 160, fill=(230, 170, 190, 255))
        d.ellipse((5, 1, 9, 5), fill=(190, 190, 200, 255))
        d.point((6, 3), fill=(30, 30, 40, 255))
    elif name == "mouse_paw_shoes":  # 鼠爪鞋：灰色拖鞋，前面露出脚趾、粉色肉垫
        d.polygon([(2, 9), (11, 9), (14, 12), (14, 14), (2, 14)], fill=(150, 150, 160, 255))
        for x in (10, 12, 14):
            d.ellipse((x - 2, 11, x, 13), fill=(255, 210, 200, 255))
        d.ellipse((4, 11, 7, 13), fill=(255, 170, 200, 255))
        d.ellipse((3, 5, 7, 9), fill=(180, 180, 190, 255))
        d.ellipse((8, 5, 12, 9), fill=(180, 180, 190, 255))
    elif name == "palace_ribbon":   # 小殿下的发带：粉蓝两色的小蝴蝶结
        d.polygon([(8, 7), (2, 3), (3, 11)], fill=(255, 150, 190, 255))
        d.polygon([(8, 7), (14, 3), (13, 11)], fill=(140, 190, 255, 255))
        d.ellipse((6, 5, 10, 9), fill=(255, 225, 120, 255))
        d.line((7, 9, 5, 14), fill=(255, 150, 190, 255))
        d.line((9, 9, 11, 14), fill=(140, 190, 255, 255))
    elif name == "palace_corset":   # 女仆长的束腰：深蓝束腰 + 白色系带
        d.rectangle((3, 4, 12, 12), fill=(50, 60, 110, 255))
        for y in range(5, 12, 2):
            d.line((6, y, 9, y + 1), fill=(240, 240, 250, 255))
        d.line((3, 4, 12, 4), fill=(200, 180, 120, 255))
    elif name == "palace_boots":    # 宫廷长靴：白色高筒靴 + 金扣
        d.rectangle((4, 2, 8, 12), fill=(235, 232, 240, 255))
        d.polygon([(4, 12), (8, 12), (12, 14), (4, 14)], fill=(235, 232, 240, 255))
        d.line((4, 6, 8, 6), fill=(220, 180, 80, 255))
        d.line((4, 9, 8, 9), fill=(220, 180, 80, 255))
    elif name == "palace_stockings":  # 宫廷丝袜：淡紫色、袜口一圈蕾丝
        d.rectangle((5, 2, 9, 10), fill=(215, 200, 240, 255))
        d.polygon([(5, 10), (9, 10), (13, 13), (13, 14), (5, 14)], fill=(215, 200, 240, 255))
        for x in range(5, 10, 2):
            d.point((x, 2), fill=(255, 255, 255, 255))
    elif name == "feather_shawl":   # 羽毛披肩：一圈白羽毛
        d.arc((1, 3, 15, 15), 180, 360, fill=(250, 248, 255, 255), width=3)
        for x in (3, 6, 10, 13):
            d.line((x, 7, x - 1, 11), fill=(240, 236, 250, 255))
        d.ellipse((7, 3, 9, 5), fill=(255, 200, 220, 255))
    elif name == "clock_watch":     # 守钟人的怀表：金色表壳 + 链子
        d.ellipse((3, 4, 13, 14), fill=(220, 180, 80, 255))
        d.ellipse((5, 6, 11, 12), fill=(250, 245, 230, 255))
        d.line((8, 9, 8, 7), fill=(40, 30, 30, 255))
        d.line((8, 9, 10, 9), fill=(40, 30, 30, 255))
        d.line((8, 4, 8, 1), fill=(200, 160, 70, 255))
        d.line((8, 1, 13, 2), fill=(200, 160, 70, 255))
    elif name == "queen_hairpin":   # 女王的羽毛发饰：金色小发夹 + 一根白长羽毛
        d.line((3, 13, 13, 3), fill=(255, 255, 255, 255), width=3)
        d.line((4, 12, 12, 4), fill=(225, 225, 240, 255))
        d.rectangle((2, 11, 6, 14), fill=(230, 185, 70, 255))
        d.point((4, 12), fill=(255, 120, 150, 255))
    elif name == "party_bow":     # 派对彩带蝴蝶结：彩色蝴蝶结 + 小铃铛
        d.polygon([(8, 7), (2, 3), (2, 11)], fill=(255, 120, 170, 255))
        d.polygon([(8, 7), (14, 3), (14, 11)], fill=(120, 200, 255, 255))
        d.ellipse((6, 5, 10, 9), fill=(255, 220, 90, 255))
        d.ellipse((6, 10, 9, 13), fill=(255, 210, 60, 255))
    elif name == "feather_anklet":  # 羽毛脚环：细绳圈 + 白羽毛
        d.arc((2, 6, 13, 13), 0, 360, fill=(200, 160, 110, 255))
        d.line((9, 9, 14, 2), fill=(255, 255, 255, 255), width=2)
        d.point((12, 4), fill=(200, 220, 255, 255))
    elif name == "ice_hairpin":   # 冰晶发夹：雪花 + 夹子
        c = (190, 230, 255, 255)
        for a, b in (((8, 2), (8, 10)), ((4, 6), (12, 6)), ((5, 3), (11, 9)), ((11, 3), (5, 9))):
            d.line((a, b), fill=c)
        d.point((8, 6), fill=(255, 255, 255, 255))
        d.line((7, 10, 7, 14), fill=(150, 170, 200, 255))
        d.line((9, 10, 9, 14), fill=(150, 170, 200, 255))
    else:                         # 千手痒痒裤：紫色紧身短裤 + 小手印
        cloth = (150, 80, 200, 255)
        d.rectangle((3, 4, 12, 7), fill=cloth)
        d.polygon([(3, 7), (6, 7), (6, 12), (3, 12)], fill=cloth)
        d.polygon([(9, 7), (12, 7), (12, 12), (9, 12)], fill=cloth)
        d.line((3, 4, 12, 4), fill=(210, 160, 250, 255))
        for x in (4, 10):
            d.point((x, 9), fill=(230, 190, 255, 255))
            d.point((x + 1, 9), fill=(230, 190, 255, 255))
    return add_outline(img)


HAND = (255, 175, 215, 255)
TPINK = (240, 150, 210, 255)
TPURP = (180, 110, 220, 255)


def t_icon(name, img, d):
    if name == "t_feather_socks":
        d.rectangle((5, 2, 10, 9), fill=TPINK)
        d.polygon([(5, 9), (10, 9), (13, 12), (13, 14), (5, 14)], fill=TPINK)
        for (x, y) in ((6, 11), (9, 12), (11, 13)):
            d.line((x, y, x + 2, y - 3), fill=(255, 255, 255, 255))
    elif name == "t_toe_brush":
        d.polygon([(2, 9), (12, 9), (14, 13), (2, 13)], fill=TPINK)
        for x in range(4, 14, 2):
            d.line((x, 8, x, 5), fill=(250, 240, 200, 255))
        d.ellipse((11, 2, 15, 6), fill=HAND)
    elif name == "t_fluff_bra":
        d.ellipse((2, 5, 8, 11), fill=TPINK)
        d.ellipse((8, 5, 14, 11), fill=TPINK)
        for (x, y) in ((3, 6), (6, 9), (10, 6), (12, 9)):
            d.point((x, y), fill=(255, 255, 255, 255))
        d.line((2, 5, 14, 5), fill=TPURP)
    elif name == "t_thigh_ring":
        d.ellipse((2, 4, 13, 12), outline=TPURP, width=2)
        for x in (4, 7, 10):
            d.line((x, 6, x, 3), fill=HAND)
    elif name == "t_pinch_pad":
        d.ellipse((2, 5, 13, 13), fill=TPINK)
        d.ellipse((4, 2, 8, 6), fill=HAND)
        d.ellipse((8, 2, 12, 6), fill=HAND)
    elif name == "t_knead_tights":
        d.rectangle((3, 2, 12, 6), fill=TPURP)
        d.rectangle((3, 6, 7, 14), fill=TPURP)
        d.rectangle((8, 6, 12, 14), fill=TPURP)
        for (x, y) in ((4, 8), (10, 10)):
            d.ellipse((x, y, x + 2, y + 2), fill=HAND)
    elif name == "t_feather_shackles":
        d.ellipse((1, 8, 6, 13), outline=(200, 200, 220, 255), width=2)
        d.ellipse((10, 8, 15, 13), outline=(200, 200, 220, 255), width=2)
        d.line((6, 10, 10, 10), fill=(200, 200, 220, 255))
        d.line((3, 7, 6, 2), fill=(255, 255, 255, 255))
        d.line((12, 7, 9, 2), fill=(255, 255, 255, 255))
    elif name == "t_thigh_strap":
        d.rectangle((3, 3, 7, 14), fill=(250, 230, 240, 255))
        d.rectangle((8, 3, 12, 14), fill=(250, 230, 240, 255))
        d.rectangle((2, 7, 13, 9), fill=TPURP)
    elif name == "t_bell_anklet":
        d.arc((2, 3, 13, 12), 0, 180, fill=(230, 190, 90, 255), width=2)
        d.ellipse((6, 9, 10, 14), fill=(255, 220, 90, 255))
        d.point((8, 12), fill=(120, 80, 30, 255))
    elif name == "t_mark_patch":
        d.ellipse((2, 4, 13, 13), fill=(255, 210, 230, 255))
        d.polygon([(7, 5), (9, 8), (12, 8), (10, 10), (11, 13), (7, 11), (4, 13), (5, 10), (3, 8), (6, 8)], fill=(230, 60, 150, 255))


def slot_bg(locked):
    img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 19, 19), 3, fill=(40, 22, 48, 230), outline=(150, 100, 170, 255))
    if locked:   # 诅咒：紫色锁链
        for i in range(0, 20, 4):
            d.ellipse((i - 1, 8, i + 3, 12), outline=(180, 110, 230, 255))
    return img


def main():
    sheet = Image.new("RGBA", (16 * len(ICONS), 16), (0, 0, 0, 0))
    for i, n in enumerate(ICONS):
        sheet.alpha_composite(icon(n), (i * 16, 0))
    sheet.save(OUT / "equip_icons.png")
    s2 = Image.new("RGBA", (40, 20), (0, 0, 0, 0))
    s2.alpha_composite(slot_bg(False), (0, 0))
    s2.alpha_composite(slot_bg(True), (20, 0))
    s2.save(OUT / "equip_slot.png")
    print("装备图标：", len(ICONS))


if __name__ == "__main__":
    main()
