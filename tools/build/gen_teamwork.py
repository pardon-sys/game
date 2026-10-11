"""怪物配合技的数据（data/teamwork.json；MonsterTeamwork 读，可复用的组件）。
每个配合技：id、name、color、members（[{key: 来源键或 [键…], count, role}]，第一个是 leader）、radius、cooldown、
            trigger（near = 场上凑齐就发动）、need_princess（公主要在 leader 多少像素内，0 = 不用）、effect（TeamworkEffects 的类型 + 参数）、
            formation（成套生成：[[怪物表的键, 只数], …]，键是攻防战 waves.json 里 monsters 的键）、intel（战场情报：desc / mech / how）。
用法：python tools/build/gen_teamwork.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])


def T(id, name, color, members, effect, radius=60, cooldown=12, need_princess=0, formation=(), desc="", mech="", how=""):
    return {"id": id, "name": name, "color": color, "members": [{"key": k, "count": c, "role": r} for k, c, r in members],
            "radius": radius, "cooldown": cooldown, "trigger": "near", "need_princess": need_princess, "effect": {"type": effect},
            "formation": [list(f) for f in formation], "intel": {"desc": desc, "mech": mech, "how": how}}


TEAMS = [
    T("troll_throw", "巨魔投掷", "#ffb070", [("troll", 1, "thrower"), (["rat", "slime"], 1, "ammo")], "throw_onto_wall", 40, 8,
      formation=[("troll", 1), ("rat", 4)], desc="挠痒巨魔和脚边的小怪。",
      mech="巨魔抓起旁边的挠脚鼠 / 史莱姆，直接扔上城墙去挠蓝色公主。", how="先打巨魔；蓝色公主注意墙上掉下来的小怪。"),
    T("slime_merge", "史莱姆合体", "#8cf0a0", [("slime", 4, "body")], "merge", 36, 14,
      formation=[("slime", 4)], desc="挤成一团的史莱姆。",
      mech="4 只挤在一起就合成一只大史莱姆：血厚、能把人整个裹住；打倒后分裂成 6 只小的。", how="趁它们还没挤到一起就打散。"),
    T("raise_arms", "举手挠腋", "#c8a8ff", [("glove", 1, "holder"), ("ghost", 1, "tickler")], "raise_arms", 90, 10, need_princess=24,
      formation=[("glove", 1), ("ghost", 2)], desc="幽灵手套和挠痒幽灵。",
      mech="手套抓住公主的手腕举高（腋下暴露、定身一下），幽灵趁机钻进腋下挠。", how="别让手套贴身；先打手套。"),
    T("strip_shoes", "脱鞋小队", "#f0c878", [("rat", 3, "stripper")], "strip_shoes", 34, 12, need_princess=22,
      formation=[("rat", 4), ("squirrel", 2), ("hedgehog", 1)], desc="一群挠脚鼠，后面跟着刷子怪。",
      mech="3 只挠脚鼠围住公主就把鞋子扒掉（脚心暴露 8 秒），附近的刷刷松鼠和刷子刺猬都围过来刷脚心。", how="冲刺跑出鼠群。"),
    T("suction_chain", "吸盘串串", "#ff9fd0", [("octopus", 1, "head"), ("barnacle", 1, "tail")], "suction_chain", 160, 12, need_princess=26,
      formation=[("octopus", 1), ("barnacle", 3)], desc="吸盘章鱼和藤壶。",
      mech="章鱼吸住公主后，藤壶一只接一只吸上来：越走越慢、挣脱要多按几下，还一直余痒。", how="连按挣脱；蓝色公主的清凉雪花能解开。"),
    T("feather_dance", "精灵羽毛舞会", "#ffe0f4", [("fairy", 1, "dust"), ("bat", 1, "fan")], "feather_dance", 70, 10, need_princess=110,
      formation=[("fairy", 2), ("bat", 2)], desc="小精灵群和羽毛蝙蝠。",
      mech="精灵撒痒痒粉、蝙蝠用羽毛扇：一大圈范围持续挠痒 3 秒。", how="看到粉色的圈就跑出去。"),
    T("bubble_chain", "泡泡鱼连环泡", "#9fd8ff", [("bubble_fish", 2, "blower")], "bubble_trap", 90, 12, need_princess=120,
      formation=[("bubble_fish", 3), ("caterpillar", 2)], desc="几只泡泡鱼，后面爬着毛毛虫。",
      mech="泡泡鱼一起吐泡泡把公主困进大泡泡（飘起来动不了 3 秒），毛毛虫钻进泡泡里挠。", how="远远看到泡泡鱼就绕开。"),
    T("jelly_charge", "魔力水母充能", "#c890ff", [("mana_jelly", 1, "charger"), (["slime", "rat", "caterpillar", "squirrel", "spider"], 2, "ally")],
      "charge", 90, 12, formation=[("mana_jelly", 1), ("slime", 3), ("rat", 2)], desc="魔力水母和身边的怪。",
      mech="魔力水母把吸来的魔力传给附近的怪：它们移动和挠痒都更快 6 秒。", how="先打水母。"),
    T("hedgehog_roll", "刷子滚球阵", "#e8c090", [("hedgehog", 3, "roller")], "roll_push", 60, 12, need_princess=160,
      formation=[("hedgehog", 3)], desc="三只刷子刺猬。",
      mech="排成一列滚过来，把公主一路撞向怪最多的地方。", how="往侧面躲。"),
    T("gecko_ladder", "壁虎叠罗汉", "#a0f0a0", [("gecko", 5, "rung")], "living_ladder", 50, 15,
      formation=[("gecko", 5)], desc="一队爬墙壁虎。",
      mech="同一段墙下凑齐 5 只就叠成活梯子，附近的普通怪也能顺着爬上城墙；梯子里的壁虎少于 3 只梯子就散。", how="打梯子里的壁虎；冰墙加固那段也有用。"),
    T("cart_escort", "攻城车护卫阵", "#ffd060", [("cart", 1, "cart"), ("shield_crab", 1, "guard")], "escort_cart", 120, 20,
      formation=[("cart", 1), ("shield_crab", 3)], desc="攻城痒痒车和排在车前的盾甲螃蟹。",
      mech="螃蟹排在车前：从前面（上面）来的冰锥和冰塔打不到车。", how="粉色公主绕到后面先打螃蟹。"),
    T("bat_airdrop", "蝠群空投", "#d0b0ff", [("bat_swarm", 1, "carrier"), (["hook", "hug_bear"], 1, "passenger")], "airdrop", 40, 14,
      formation=[("bat_swarm", 1), ("hug_bear", 1)], desc="羽毛蝠群抓着别的怪。",
      mech="蝙蝠抓起钩索怪 / 拥抱小熊，飞过城墙扔到墙顶。", how="冰锥打下蝠群；墙上的弓箭手也会射。"),
    T("engineer_escort", "工兵护送", "#90e080", [("goblin_engineer", 1, "builder"), (["slime", "rat", "shield_crab", "spider"], 3, "guard")],
      "escort_engineer", 70, 20, formation=[("goblin_engineer", 3), ("shield_crab", 2), ("slime", 3)], desc="扛着木料的地精工兵和护卫。",
      mech="护卫围着工兵走、攻击靠近的公主；护送着搭成的敌塔第一次发动威力加倍。", how="先拆护卫阵、再打工兵；冻住工兵能让搭建停下。"),
]

out = {"_说明": ["怪物配合技（tools/build/gen_teamwork.py 生成；MonsterTeamwork 读）。"], "teams": TEAMS}
Path("data/teamwork.json").write_text(json.dumps(out, ensure_ascii=False, indent="\t") + "\n")
print("怪物配合技：%d 个" % len(TEAMS))
