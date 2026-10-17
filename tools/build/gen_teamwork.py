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

# 第六波扩展：沿用成员 / effect / formation 格式，额外条件只作用于新配合。
NEW_TEAMS = [
    T("sticky_pincer", "黏步夹击", "#90dca0", [("slime", 1, "leader"), ("rat", 2, "flank")],
      "sticky_pincer", 70, 30, 80, [("slime", 1), ("rat", 2)], "史莱姆领着两只挠脚鼠。", "预警后减速 2 秒，小鼠从两侧集结。", "离开预警圈，先击败领队。"),
    T("hook_relay", "钩索接力", "#a0d8e8", [("hook", 1, "leader"), ("gecko", 2, "passenger")],
      "hook_relay", 80, 30, 0, [("hook", 1), ("gecko", 2)], "钩索怪与壁虎小队。", "预警后沿钩索投送壁虎上墙。", "击败或冻结钩索怪；加固落点城墙。"),
    T("vine_pincer", "藤网合围", "#98c878", [("bind_vine", 1, "leader"), ("caterpillar", 2, "flank")],
      "vine_pincer", 70, 30, 80, [("vine", 1), ("caterpillar", 2)], "藤怪领着毛毛虫。", "预警后短暂定身 1 秒，毛毛虫趁机集结。", "先打藤怪；清凉雪花可解开束缚。"),
    T("escort_bear", "蟹盾熊扑", "#ecc070", [("hug_bear", 1, "leader"), ("shield_crab", 2, "guard")],
      "escort_bear", 100, 30, 0, [("hug_bear", 1), ("shield_crab", 2)], "两只盾甲螃蟹保护小熊。", "盾阵掩护小熊靠近；小熊受蓝色公主攻击仍会松手。", "绕后打蟹；用冰法救援搭档。"),
    T("melt_delivery", "搬运融塔", "#ffc890", [("carrier", 1, "leader"), ("warm_slime", 2, "passenger")],
      "melt_delivery", 90, 30, 0, [("carrier", 1), ("warm_slime", 2)], "搬运小鬼运送暖炉史莱姆。", "把两只史莱姆送到附近冰塔旁，沿用史莱姆融塔行为。", "冻结搬运者，或优先清掉暖炉史莱姆。"),
    T("jelly_guard", "水母护卫", "#c0a0ed", [("suck_jelly", 1, "leader"), ("glove", 2, "guard")],
      "jelly_guard", 90, 30, 0, [("suck_jelly", 1), ("glove", 2)], "手套护送吸吸水母接近施法者。", "保护水母并集结到蓝色公主附近，沿用各自施法干扰。", "先拆护卫，保持距离并用范围法术。"),
    T("bear_shield", "蟹盾风阵", "#ffd070", [("gale_bear", 1, "leader"), ("shield_crab", 3, "guard")],
      "bear_shield", 180, 36, desc="熊统领与三只盾甲螃蟹。", mech="三只盾蟹掩护熊统领吸引蓄力，沿用正面挡冰与护卫行为。", how="绕后拆盾，或冻结熊打断吸引。"),
    T("bear_airlift", "旋风挠痒运兵", "#80ded8", [("gale_bear", 1, "leader"), (["hug_bear", "spider", "hedgehog", "frog", "octopus", "barnacle"], 2, "passenger")],
      "bear_airlift", 224, 36, desc="熊统领借风投送现有小怪。", mech="两个运输龙卷分别压地面与墙顶；加固城墙可阻止上墙。", how="冻结熊或乘客，按落点预警躲开。"),
    T("bear_airlift_rage", "狂风双路运兵", "#80ded8", [("gale_bear", 1, "leader"), (["hug_bear", "spider", "hedgehog", "frog", "octopus", "barnacle"], 4, "passenger")],
      "bear_airlift_rage", 224, 36, desc="狂暴熊统领的双路运兵。", mech="每路两只现有小怪；运输途中冻结熊会立即取消。", how="加固落点或冻结熊。"),
    T("bear_roll", "借风滚击", "#e8c090", [("gale_bear", 1, "leader"), ("hedgehog", 3, "roller")],
      "bear_roll", 180, 36, 250, desc="熊统领与三只刷子刺猬。", mech="八向龙卷释放后，刺猬沿另有预警的路线接滚击。", how="向侧面躲开；冻结领队可以打断预警。"),
]
for team, first in zip(NEW_TEAMS, [1, 2, 4, 6, 7, 8, 6, 6, 6, 6]):
    team.update(siege_only=True, min_wave=first)
    if team["id"].startswith("bear_"):
        team["trigger"] = "boss_command"
        team.update(cooldown=9, busy_time=0.9, windup=0.12)
TEAMS += NEW_TEAMS

for count, ident in ((2, "puppet_relay"), (4, "puppet_relay_rage")):
    team = T(ident, "魔偶挠痒接力", "#f2a6d9",
             [("puppet_master", 1, "leader"), (["bind_vine", "hug_bear", "thigh_spider", "ghost"], count, "tickler")],
             "puppet_relay", 360, 9, desc="魔偶师与已有束缚 / 挠痒小怪。",
             mech="接力小怪投送到受束缚目标附近，并催动最多两座新敌塔。", how="拆掉共振钟楼，打断领队。")
    team.update(siege_only=True, min_wave=9, trigger="boss_command", windup=0.12, busy_time=0.9)
    TEAMS.append(team)

from siege_cooperation_data import teams as cooperation_teams
TEAMS += cooperation_teams(T)

# 第九轮：给还没有配合的怪（钳钳蟹、机械小鬼、小触手、分裂史莱姆）加的配合（效果在 SiegeTeamEffects）
NEW_TEAMS_9 = [
    T("crab_rat", "夹脚脱鞋", "#ff9a80", [("crab", 1, "leader"), ("rat", 2, "flank")],
      "crab_rat", 70, 26, 70, [("crab", 1), ("rat", 2)], "钳钳蟹带着两只挠脚鼠。",
      "预警后钳钳蟹夹住脚踝（定身 2 秒），挠脚鼠扒掉鞋子挠脚心（脚心暴露）。", "看到预警就躲开；先打钳钳蟹，它一松钳小鼠就散了。"),
    T("crab_tentacle", "夹脚缠腿", "#c890ff", [("crab", 1, "leader"), ("tentacle", 2, "flank")],
      "crab_tentacle", 70, 26, 70, [("crab", 1), ("mini_tentacle", 2)], "钳钳蟹和两根小触手。",
      "钳钳蟹夹住脚踝，小触手顺着小腿往上缠着挠（余痒 4 秒，挣脱要多按几下）。", "先打小触手；蓝色公主的清凉雪花能解开。"),
    T("imp_slime", "史莱姆弹射", "#90e0ff", [("imp", 1, "leader"), ("split_slime", 2, "ammo")],
      "imp_slime", 120, 26, 220, [("imp", 1), ("split_slime", 2)], "机械小鬼背着两只分裂史莱姆。",
      "小鬼把史莱姆当弹药弹射过来，粘在身上分裂成更多小的一起挠（减速 3 秒）。", "离小鬼远一点；冰锥能在半空打碎史莱姆。"),
    T("bear_tentacle", "熊抱触手", "#ffb0c8", [("hug_bear", 1, "leader"), ("tentacle", 2, "flank")],
      "bear_tentacle", 70, 30, 60, [("hug_bear", 1), ("mini_tentacle", 2)], "拥抱小熊身边跟着两根小触手。",
      "小熊从背后抱住（连按挣脱），小触手趁机从前面挠。", "被抱住就连按挣扎；冰链 / 清凉雪花能帮忙。"),
]
for team, first in zip(NEW_TEAMS_9, [2, 4, 5, 6]):
    team.update(siege_only=True, min_wave=first)
TEAMS += NEW_TEAMS_9

out = {"_说明": ["怪物配合技（tools/build/gen_teamwork.py 生成；MonsterTeamwork 读）。"], "teams": TEAMS}
Path("data/teamwork.json").write_text(json.dumps(out, ensure_ascii=False, indent="\t") + "\n")
print("怪物配合技：%d 个" % len(TEAMS))
