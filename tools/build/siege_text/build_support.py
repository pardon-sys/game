"""建塔友军情报的单一文本源。"""
SPECS = {
    "mage": ("冰吟诵学徒", "五名学徒走到待建基座旁吟诵冰光，单人效率是蓝色公主的一半；可独立完成已付款的订单，也能协作。"),
    "builder": ("冰筑工匠", "自主建造全部已解锁塔种，不设塔数量上限；付费后保留30冰晶，完成后冷却30秒。撤退时订单进度保留。"),
}

def intel():
    return {"soldier_" + key: {"name": name, "kind": "友军士兵", "desc": "小镇保卫队的%s。" % name,
                             "mech": mech, "how": "被挠得撑不住会撤回城门，过一会儿满血回来。"}
            for key, (name, mech) in SPECS.items()}
