"""怪物配合技（data/teamwork.json）的公主台词：每个配合技是一个挠痒来源 team_<id>（发动时公主走字幕说 trigger；
被它挠时按闷笑阶段说 calm / giggle / helpless_1 / helpless_2；taunts 是怪物的回嘴）。
粉色 / 蓝色各写一套：gen_siege_reactions.py 写进 data/princess_reactions.json，gen_blue_character.py 写进蓝色公主的。
"""

TEAM_LINES = {
    "hook_haunt": {"pink": {"trigger": ["哇！钩子和幽灵还会接力？"]}, "blue": {"trigger": ["先松开钩子！我可没答应陪你们练配合！"]}},
    "bubble_roll": {"pink": {"trigger": ["泡泡里面也能刷到？哈哈，别两边一起！"]}, "blue": {"trigger": ["区区泡泡……哈！那两只刷子给我停下！"]}},
    "magic_recoil": {"pink": {"trigger": ["还会滚回来？这也太犯规啦！"]}, "blue": {"trigger": ["我躲过第一下了——哈！谁让你们再来一遍！"]}},
    "twin_relay": {"pink": {"trigger": ["一只刚停，另一只又来啦！"]}, "blue": {"trigger": ["别以为轮流来，我就会认输……哈！"]}},
    "glue_roll": {"pink": {"trigger": ["黏住了！刷子别从两边滚过来呀！"]}, "blue": {"trigger": ["这点黏胶困不住我……先把刷子拿开！"]}},
    "drop_hook": {"pink": {"trigger": ["空投还带钩子的？不许把我拉过去！"]}, "blue": {"trigger": ["你们连落点都算好了？哼，别碰我！"]}},
    "web_battery": {"pink": {"trigger": ["蛛丝黏住了，炮弹又来了——！"]}, "blue": {"trigger": ["别拿我当靶子！哈……这两只蜘蛛真碍事！"]}},
    "sticky_pincer": {"pink": {"trigger": ["脚步乱了！先打领头的！"]}, "blue": {"trigger": ["……包围。先打领头的。"]}},
    "vine_pincer": {"pink": {"trigger": ["脚步乱了！先打领头的！"]}, "blue": {"trigger": ["……包围。先打领头的。"]}},
}


def sources(who):
    """{team_<id>: 来源段}（who = pink / blue）。"""
    out = {}
    for tid, d in TEAM_LINES.items():
        src = dict(d.get(who, {}))
        src.setdefault("name", d.get("name", tid))
        out["team_" + tid] = src
    return out
