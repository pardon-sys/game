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
              ["!after_ev_%s" % e for e in ("d1_open", "d1_verdict", "d1_sleepwalk", "d2_stocks", "d2_equip", "d3_potion", "d3_cart",
                                             "d4_drain", "d4_drill", "d5_tailor", "d5_mine", "d6_inspect", "d6_drill", "d7_totem", "d7_festival", "d2_sweep", "d3_mice", "d4_tag", "d5_tom", "d6_lantern")] + \
              ["!after_done_d%d_%s" % (d, k) for d in (2, 3, 4, 5, 6, 7) for k in ("morning", "afternoon", "night")] + \
              ["!after_task_active", "!after_field_open", "!after_mine_open", "!after_totem_open", "!after_drain_open", "!after_drill_open", "!after_proving_open",
               "!after_d2_fainted", "!skill_pants_burst", "!drill_exam_passed", "!after_curfew", "!penalty_open", "!penalty_announcer_open",
               "!tom_prank_caught", "!tom_prank_quiet", "!tom_prank_fainted", "!after_blue_can_follow", "!after_blue_following", "!penalty_d7",
               "!after_festival_on", "!festival_dance_done", "!festival_finale_done", "!knight_started",
               "!knight_asked_night", "!knight_asked_fall", "!knight_asked_why"] + \
              ["!stall_%s_done" % sid for sid in ("guess", "ring", "ice", "fish", "lick")] + \
              ["!errand_%s_%s" % (e, k) for e in ("cookies", "apples", "ladder", "goats", "dance", "massage", "gate_chain", "shearing", "canopy", "sifting", "lamp_calibration") for k in ("open", "active", "done")]
AFTER = WAR + ["siege_won"] + AFTER_RESET
BOOK = {"penance_hours": 100, "penance_log": [], "penance_punish": [], "after_play_day": 0, "blue_bond": 0,
        "after_play_win_day": 0, "after_play_bond_day": 0, "after_blue_follow_day": 0, "errand_gate_chain_step": 0, "errand_shearing_step": 0, "errand_canopy_step": 0, "errand_sifting_step": 0, "errand_lamp_calibration_step": 0,
        "task_cart_done": [], "task_potion_recipe": 0, "task_potion_notes": [], "task_potion_wrong": 0,
        "task_tailor_measured": False, "task_tailor_tea": 3, "task_mine_slips": 0, "task_totem_runes": 0, "task_totem_cracks": 0, "task_drain_cleared": 0, "task_potion_ok": 0, "penance_settled": 0,
        "task_inspect_rates": {}, "task_inspect_tune": {},
        "knight_step": 0, "task_stretcher_drops": 0, "task_bait_caught": 0, "task_sneak_caught": 0,
        "task_chase_lit": 0, "task_chase_caught": 0, "task_boss_phase": 0, "task_boss_caught": 0}
D2_ALL = ["after_done_d2_morning", "after_ev_d2_stocks"]
# 第 3 天整天做完（第 4 天以后的跳关点用）
D3_ALL = D2_ALL + ["after_done_d2_afternoon", "after_ev_d2_equip", "after_done_d2_night", "after_done_d3_morning", "after_ev_d3_potion",
                   "after_done_d3_afternoon", "after_ev_d3_cart", "after_done_d3_night"]


# 第 4~7 天白天的事都做完（庆功宴 / 骑士篇的跳关点用）
D7_DAYS = ["after_done_d%d_%s" % (d, k) for d in (4, 5, 6) for k in ("morning", "afternoon", "night")] + \
          ["after_done_d7_morning", "after_done_d7_afternoon"] + \
          ["after_ev_%s" % e for e in ("d4_drain", "d4_drill", "d5_tailor", "d5_mine", "d6_inspect", "d6_drill", "d7_totem")]


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
    point("七日赎罪·灯轮校准委托", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d4_morning", "after_ev_d4_drain", "errand_dance_done", "errand_massage_done"],
          dict(BOOK, day=5, after_day=4, after_slot=1), cell=[43, 27]),
    point("七日赎罪·忍笑报幕补罚", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d4_morning", "after_ev_d4_drain", "errand_dance_done", "errand_massage_done", "errand_lamp_calibration_done"],
          dict(BOOK, day=5, after_day=4, after_slot=1, penance_punish=[{"day": 4, "slot": 1, "text": "测试待抵记录", "theater": ""}]), cell=[43, 27]),
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
    point("七日赎罪·第 2 天下午（装备回收 / 委托 / 玩闹）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D2_ALL,
          dict({"day": 3, "after_day": 2, "after_slot": 1}, **BOOK), cell=[14, 27]),
    point("七日赎罪·第 3 天早上（配药）", "floor_06_after_pharmacy", AFTER + after_done("morning", "afternoon", "night") + D2_ALL +
          ["after_done_d2_afternoon", "after_ev_d2_equip", "after_done_d2_night"],
          dict({"day": 4, "after_day": 3, "after_slot": 0}, **BOOK), spawn="from_town"),
    point("七日赎罪·第 3 天下午（拆攻城车）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D2_ALL +
          ["after_done_d2_afternoon", "after_ev_d2_equip", "after_done_d2_night", "after_done_d3_morning", "after_ev_d3_potion"],
          dict({"day": 4, "after_day": 3, "after_slot": 1}, **BOOK), cell=[32, 36]),
    point("七日赎罪·第 4 天早上（疏通排水管）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL,
          dict({"day": 5, "after_day": 4, "after_slot": 0}, **BOOK), cell=[20, 37]),
    point("七日赎罪·第 4 天下午（特训第一、二课 / 委托）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d4_morning", "after_ev_d4_drain"], dict({"day": 5, "after_day": 4, "after_slot": 1}, **BOOK), cell=[8, 11]),
    point("七日赎罪·第 5 天早上（裁缝找漏风）", "floor_06_after_tailor", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d4_morning", "after_done_d4_afternoon", "after_done_d4_night"],
          dict({"day": 6, "after_day": 5, "after_slot": 0}, **BOOK), spawn="from_town"),
    point("七日赎罪·第 5 天下午（矿车护送）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d4_morning", "after_done_d4_afternoon", "after_done_d4_night", "after_done_d5_morning", "after_ev_d5_tailor"],
          dict({"day": 6, "after_day": 5, "after_slot": 1}, **BOOK), cell=[54, 7]),
    point("七日赎罪·第 6 天早上（陷阱验收）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d%d_%s" % (d, k) for d in (4, 5) for k in ("morning", "afternoon", "night")] + ["after_ev_d4_drain", "after_ev_d4_drill", "after_ev_d5_tailor", "after_ev_d5_mine"],
          dict({"day": 7, "after_day": 6, "after_slot": 0}, **BOOK), cell=[59, 20]),
    point("七日赎罪·第 6 天下午（特训第三课 + 考核）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d%d_%s" % (d, k) for d in (4, 5) for k in ("morning", "afternoon", "night")] + ["after_ev_d4_drain", "after_ev_d4_drill", "after_ev_d5_tailor", "after_ev_d5_mine",
          "after_done_d6_morning", "after_ev_d6_inspect"], dict({"day": 7, "after_day": 6, "after_slot": 1}, **BOOK), cell=[8, 11]),
    point("七日赎罪·第 7 天（修补图腾柱）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL +
          ["after_done_d%d_%s" % (d, k) for d in (4, 5, 6) for k in ("morning", "afternoon", "night")] + ["after_ev_d4_drain", "after_ev_d4_drill", "after_ev_d5_tailor", "after_ev_d5_mine", "after_ev_d6_inspect", "after_ev_d6_drill"],
          # 工时按正常玩到第 7 天的样子给：图腾柱（20）做完刚好还清
          dict(BOOK, day=8, after_day=7, after_slot=0, penance_hours=20), cell=[4, 32]),
    point("七日赎罪·第 7 天晚上（庆功宴）", "floor_06_after", AFTER + after_done("morning", "afternoon", "night") + D3_ALL + D7_DAYS,
          dict(BOOK, day=8, after_day=7, after_slot=2, penance_hours=0), cell=[40, 25]),
    point("骑士篇·开头（庆功宴之后的早上）", "floor_06_after_house", AFTER + after_done("morning", "afternoon", "night") + D3_ALL + D7_DAYS +
          ["after_done_d7_night", "after_ev_d7_festival", "after_festival_on", "festival_dance_done", "festival_finale_done", "knight_started"],
          dict(BOOK, day=9, after_day=8, after_slot=0, penance_hours=0, knight_step=0), cell=[5, 6]),
    point("骑士篇·诅咒失控（追逃 + Boss）", "floor_06_after_house", AFTER + after_done("morning", "afternoon", "night") + D3_ALL + D7_DAYS +
          ["after_done_d7_night", "after_ev_d7_festival", "after_festival_on", "festival_dance_done", "festival_finale_done", "knight_started"],
          dict(BOOK, day=10, after_day=9, after_slot=0, penance_hours=0, knight_step=6), cell=[5, 6]),
]
Path("data/dev").mkdir(parents=True, exist_ok=True)
Path("data/dev/skip_points_more.json").write_text(json.dumps({
    "_说明": "测试模式跳关点（tools/build/gen_dev_skips.py 生成）：接在 dev_config.json 的 skip_points 后面。",
    "skip_points": POINTS}, ensure_ascii=False, indent="\t") + "\n")
print("跳关点 %d 个" % len(POINTS))
