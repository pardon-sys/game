"""已确认的十种配合。T 沿用 gen_teamwork 的成员 / 情报 / 编队格式。"""


def teams(T):
    specs = [
        ("hook_haunt", "钩索幽影", 9, .18, 12, 1.6, "#cf9cec", [("hook", 1), ("ghost", 2)], [("hook", 1), ("ghost", 2)],
         "钩索最多拖行96像素，两只幽灵交叉接战。"),
        ("bubble_roll", "泡泡滚刷", 6, .20, 14, 1.6, "#9fd8ff", [("bubble_fish", 2), ("hedgehog", 2)], [("bubble_fish", 2), ("hedgehog", 2)],
         "泡泡困住目标1.6秒，两只刺猬轮流滚刷。"),
        ("shield_melt", "钳盾融塔", 7, .25, 18, 6, "#ffd070", [("warm_slime", 1), ("shield_crab", 2)], [("warm_slime", 1), ("shield_crab", 2)],
         "蟹盾护送暖炉史莱姆六秒，集中贴塔融冰。"),
        ("magic_recoil", "魔力回旋滚击", 5, .18, 12, 1.8, "#c890ff", [("mana_jelly", 1), ("hedgehog", 2)], [("mana_jelly", 1), ("hedgehog", 2)],
         "水母充能，刺猬滚击后回旋再撞一次。"),
        ("twin_relay", "双子幽影接力", 9, .15, 16, 1.6, "#f2a6d9", [("twin_ghost", 2), ("ghost", 2)], [("twin_ghost", 1), ("ghost", 2)],
         "同一对双子连线脉冲，两只幽灵交替接战四轮。"),
        ("glue_roll", "黏池滚球", 5, .18, 12, 2, "#c5e878", [("enemy_glue", 1), ("hedgehog", 2)], [("hedgehog", 2)],
         "黏胶喷泉锁定落点，刺猬从黏池两侧夹击。"),
        ("wind_transport", "风车顺风运兵", 5, .20, 16, 1.2, "#b5edf3", [("enemy_windmill", 1), ("bat_swarm", 1), ("hug_bear", 2)], [("bat_swarm", 1), ("hug_bear", 2)],
         "风车加速蝠群运输两只拥抱熊，落地包夹；加固墙段仍阻止上墙。"),
        ("drop_hook", "空投牵引包夹", 5, .15, 18, 1.4, "#80cfee", [("enemy_airdrop", 1), ("hook", 1)], [("hook", 1)],
         "钩索把目标拖向标出的空投落点，不额外增加投兵数量或上限。"),
        ("web_battery", "蛛网校射", 8, .15, 14, 2, "#f2a6d9", [("enemy_brush_battery", 1), ("thigh_spider", 2)], [("thigh_spider", 2)],
         "蜘蛛限制目标，轰击塔同步三连射，实际角色决定工具和弱点。"),
        ("bell_repair", "共振抢修", 7, .25, 18, 1.8, "#ffd070", [("enemy_resonance", 1), ("goblin_engineer", 1)], [("goblin_engineer", 1)],
         "工兵持续维修1.5秒，完成后恢复受损敌塔15%最大血量；死亡的塔不能修复。"),
    ]
    result = []
    for ident, name, first, windup, cooldown, life, color, members, formation, mech in specs:
        no_hero = ident in {"shield_melt", "bell_repair"}
        radius = 240 if ident == "twin_relay" else 180
        item = T(ident, name, color, [(key, count, "leader" if i == 0 else "partner") for i, (key, count) in enumerate(members)],
                 ident, radius, cooldown, 0 if no_hero else 320, formation, name + "配合小队。", mech, "先击败参与者；拆除协作敌塔或冻结小怪可中断未完成联动。")
        item.update(siege_only=True, min_wave=first, windup=windup, busy_time=life + windup + .25)
        item["effect"]["joint"] = True
        if ident == "twin_relay":
            item["paired_twins"] = True
        result.append(item)
    return result
