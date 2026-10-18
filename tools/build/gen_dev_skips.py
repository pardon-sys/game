"""测试模式跳关点（第八层之后的新内容）：写到 data/dev/skip_points_more.json，DevConfig.skip_points() 把它接在 dev_config.json 的列表后面。
（dev_config.json 是各人本地的开关文件，不提交；新内容的跳关点放在这里，跟着代码一起更新。）
每出一段新内容就在这里加跳关点。flags 里 "!标记" = 清掉（重跳同一段时把上次走过的剧情标记清掉，过场会重新放）。
用法：python tools/build/gen_dev_skips.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

# 第八层打完、回到小屋之后（粉色公主当主角）
BASE = ["f6_tour_started", "f6_house_open", "f6_key", "f6_escape", "f7_pink_ran", "f7_blue_awake", "f7_argue_done",
        "intro_done_f7_pink_run", "intro_blue_magic", "magic_unlocked", "f8_intro_done", "f8_fight_started", "f8_boss_down",
        "f8_done", "f8_slept", "intro_done_f8_maze_intro", "f8m_tutorial", "f8_maze_done", "f8_maze_finale_seen", "f8_returned",
        "blue_tickle_pants", "got_backpack", "!blue_is_hero", "!night"]
WAR = BASE + ["f7r_done", "f6w_arrived", "equip_unlocked"]
SIEGE = WAR + ["f6w_ready", "siege_intro_seen", "intro_done_siege_intro", "!siege_won"]
# 七日赎罪：重跳时把第 1 天走过的标记都清掉
AFTER_RESET = ["!after_started", "!penance_book", "!after_night_busy", "!after_d1_clues", "!after_house_up_open",
               "!after_d1_clue_bed", "!after_d1_clue_tea"] + \
              ["!after_done_d1_%s" % s for s in ("morning", "afternoon", "night")] + \
              ["!after_ev_%s" % e for e in ("d1_open", "d1_verdict", "d1_sleepwalk", "d2_stocks")] + \
              ["!after_done_d2_morning"] + \
              ["!errand_%s_%s" % (e, k) for e in ("cookies", "apples") for k in ("open", "active", "done")]
AFTER = WAR + ["siege_won"] + AFTER_RESET
BOOK = {"penance_hours": 100, "penance_log": [], "penance_punish": [], "after_play_day": 0, "blue_bond": 0}


def point(name, floor, flags, vars_=None, **kw):
    p = {"name": name, "floor": floor, "rewards_through": "floor_06_upper", "flags": flags}
    if vars_:
        p["vars"] = vars_
    p.update(kw)
    return p


def after_done(*slots_):
    return ["after_started", "penance_book"] + ["after_done_d1_%s" % s for s in slots_] + \
           ["after_ev_%s" % e for e, s in (("d1_open", "morning"), ("d1_verdict", "afternoon"), ("d1_sleepwalk", "night")) if s in slots_]


POINTS = [
    point("第七层·归途（开场）", "floor_07_return", BASE + ["!f7r_done", "!f6w_arrived"], {"day": 2}),
    point("地下小镇·战时（队长过场后）", "floor_06_war", WAR, {"day": 2}),
    point("攻防战·第 1 波", "floor_06_siege", SIEGE, {"day": 2, "siege_wave": 1}),
    point("攻防战·第 6 波（风暴熊）", "floor_06_siege", SIEGE, {"day": 2, "siege_wave": 6}),
    point("攻防战·第 9 波（魔偶师）", "floor_06_siege", SIEGE, {"day": 2, "siege_wave": 9}),
    point("攻防战·第 12 波（狂欢要塞）", "floor_06_siege", SIEGE, {"day": 2, "siege_wave": 12}),
    point("七日赎罪·第 1 天（战后开场）", "floor_06_after", AFTER, dict({"day": 2, "after_day": 1, "after_slot": 0}, **BOOK), spawn="from_siege"),
    point("七日赎罪·第 1 天下午（宣判前）", "floor_06_after", AFTER + ["after_started", "after_done_d1_morning", "after_ev_d1_open"],
          dict({"day": 2, "after_day": 1, "after_slot": 1}, **BOOK), cell=[31, 31]),
    point("七日赎罪·第 1 天夜里（梦游）", "floor_06_after_house", AFTER + after_done("morning", "afternoon") + ["night"],
          dict({"day": 2, "after_day": 1, "after_slot": 2}, **BOOK), spawn="from_town"),
    point("七日赎罪·第 2 天早上（示众前）", "floor_06_after_house", AFTER + after_done("morning", "afternoon", "night") + ["!after_done_d2_morning", "!after_ev_d2_stocks"],
          dict({"day": 3, "after_day": 2, "after_slot": 0}, **BOOK), spawn="bed"),
    point("七日赎罪·第 2 天下午（委托 / 玩闹）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + ["after_done_d2_morning", "after_ev_d2_stocks"],
          dict({"day": 3, "after_day": 2, "after_slot": 1}, **BOOK), cell=[40, 26]),
]
Path("data/dev").mkdir(parents=True, exist_ok=True)
Path("data/dev/skip_points_more.json").write_text(json.dumps({
    "_说明": "测试模式跳关点（tools/build/gen_dev_skips.py 生成）：接在 dev_config.json 的 skip_points 后面。",
    "skip_points": POINTS}, ensure_ascii=False, indent="\t") + "\n")
print("跳关点 %d 个" % len(POINTS))
