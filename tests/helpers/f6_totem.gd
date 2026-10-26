extends RefCounted
## 图腾共鸣·双人符文专项（第 7 天）：真实进图腾柱废地开演，验证共鸣区 / 调节键 / 痒感连线 / 裂开重刻 / 释放充能 / 三道符文 / 失败重来，
## 以及做完以后的工时规则（减 20、停在下午、欠工时不让休息和睡觉、补罚随时能接且一次减 5）。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func find_show(t: Node) -> TotemResonanceShow:
	return t._show(TotemResonanceShow) as TotemResonanceShow


## 进废地 → 过场 → 小游戏开演
static func start(t: Node) -> TotemResonanceShow:
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene("floor_06_after_totem"))
	await t._advance_until(func(): return find_show(t) != null and not find_show(t).busy, 40.0)
	return find_show(t)


## 把这一道符文刻完（两人停在共鸣区里、充能拉满）
static func solve_rune(t: Node, s: TotemResonanceShow) -> void:
	var before := s.completed
	s.recovery_left = 0.0
	s.meter.charge = 0.995
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.blue_laugh = 0.5
	s.simulate(0.2)
	await t._advance_until(func(): return not is_instance_valid(s) or s._done or (s.completed > before and not s.busy), 15.0)


static func run(t: Node) -> void:
	checks = 0
	TotemResonanceShow.quiet = true
	TotemResonanceShow.fixed_seed = 7707
	for f in ["after_started", "penance_book", "f6_opening_done"]:
		GameState.set_flag(f)
	for f in ["after_done_d7_morning", "after_done_d7_afternoon", "after_ev_d7_totem"]:
		GameState.set_flag(f, false)
	GameState.vars[TotemResonanceShow.SAVE_KEY] = 0
	GameState.vars[TotemResonanceShow.CRACK_KEY] = 0
	GameState.vars["penance_hours"] = 40
	GameState.vars["penance_punish"] = []
	GameState.vars["penance_settled"] = 0
	DayClock.set_time(7, DayClock.MORNING)
	var tx := TotemResonanceShow.data()
	verify(t, "三道符文，每道两种挠法（%s）" % [tx["phases"].map(func(p): return p["tools"])], tx["phases"].size() == 3 and tx["phases"].all(func(p): return p["tools"].size() == 2))
	var pink_events: Array = tx["feedback"].filter(func(e): return tx["tool_who"][e["tool"]] == "pink")
	var blue_events: Array = tx["feedback"].filter(func(e): return tx["tool_who"][e["tool"]] == "blue")
	verify(t, "挠痒事件 %d 组：粉色的都挠脚，蓝色的挠大腿 / 屁股" % tx["feedback"].size(), tx["feedback"].size() >= 18
		and pink_events.all(func(e): return e["zone"] == "sole") and blue_events.all(func(e): return e["zone"] in ["thigh", "butt"]))
	verify(t, "每组反应三档都有", tx["feedback"].all(func(e): return e["react"]["light"].size() >= 2 and e["react"]["mid"].size() >= 2 and e["react"]["heavy"].size() >= 2))
	verify(t, "日程：图腾柱减 20 工时", int(DayClock.slot_info(7, DayClock.MORNING).get("hours", 0)) == 20)
	verify(t, "任务表：不再清零、不再直接天黑", not AfterStory.TASKS["d7_totem"].has("clear_book") and not AfterStory.TASKS["d7_totem"].has("to_night"))
	var s := await start(t)
	verify(t, "进废地 → 过场 → 小游戏开演（两位公主都在舞台上）", s != null and s.actors.has("princess") and s.actors.has("blue") and t.seen_cuts.has("after_d7_totem"))
	if s == null:
		return
	verify(t, "开演时锁住地图输入", GameState.dialogue_holds >= 1 and GameState.in_dialogue)
	# 调节键
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.set_mode("pink", -1)
	var l0 := s.pink_ratio()
	s.simulate(0.2)
	s.simulate(0.2)
	verify(t, "A 绷紧脚趾：粉色的闷笑往下压（%.2f → %.2f）" % [l0, s.pink_ratio()], s.pink_ratio() < l0)
	s.press("D")
	verify(t, "D 张开脚趾", s.pink_mode == 1)
	s.press("D")
	verify(t, "同一个键再按一次回到平常", s.pink_mode == 0)
	s.blue_laugh = 0.5
	s.press("J")
	var b0 := s.blue_laugh
	s.simulate(0.2)
	verify(t, "J 冰封：蓝色的闷笑往下压（%.2f → %.2f）" % [b0, s.blue_laugh], s.blue_laugh < b0)
	s.press("J")
	# 共鸣
	s.meter.charge = 0.0
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.blue_laugh = 0.5
	for i in 5:
		s.simulate(0.2)
	var c1 := s.meter.charge
	verify(t, "两人都在共鸣区：符文充能（%.2f）" % c1, c1 > 0.05)
	s.blue_laugh = 0.1
	s.simulate(0.2)
	verify(t, "有人太低：不充，慢慢漏（%.3f → %.3f）" % [c1, s.meter.charge], s.meter.charge < c1)
	# 痒感连线
	s.player.laugh.set_value(s.laugh_max() * 0.3)
	s.blue_laugh = 0.3
	s.active_tool = "feather"
	s.strike()
	verify(t, "挠粉色（羽毛）：蓝色跟着涨一半（粉 %.2f / 蓝 %.2f）" % [s.pink_ratio(), s.blue_laugh],
		is_equal_approx(s.blue_laugh - 0.3, (s.pink_ratio() - 0.3) * TotemResonanceShow.LINK) and s.blue_laugh > 0.3)
	s.player.laugh.set_value(s.laugh_max() * 0.3)
	s.blue_laugh = 0.3
	s.active_tool = "hand"
	s.strike()
	verify(t, "挠蓝色（小手）：粉色跟着涨一半", s.target == "blue" and s.blue_laugh > s.pink_ratio() and s.pink_ratio() > 0.3)
	# 裂开
	s.meter.charge = 0.6
	s.player.laugh.set_value(s.laugh_max() * 0.95)
	s.simulate(0.1)
	verify(t, "有人笑过红线：符文裂开（%d 次）、充能清零、两人回到 %.0f%%" % [s.cracks, TotemResonanceShow.CRACK_RESET * 100],
		s.cracks == 1 and s.meter.charge == 0.0 and is_equal_approx(s.blue_laugh, TotemResonanceShow.CRACK_RESET) and TotemResonanceShow.saved_cracks() == 1)
	await t._wait(ErrandWorkStage.RECOVER_TIME + 0.2)
	s.recovery_left = 0.0
	# 释放
	s.meter.charge = 0.2
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.blue_laugh = 0.5
	s.add_fatigue(s.fatigue_max())
	s._process(0.016)
	verify(t, "魔力疲倦满：舒服的释放 + 共鸣爆发（充能 %.2f）、之后敏感" % s.meter.charge,
		s.releases == 1 and s.meter.charge >= 0.2 + TotemResonanceShow.RELEASE_CHARGE - 0.01 and s.sensitive_left > 0.0 and s.player.fatigue.value == 0.0)
	await t._wait(ErrandWorkStage.RELEASE_TIME + 0.2)
	s.recovery_left = 0.0
	# 三道符文
	await solve_rune(t, s)
	verify(t, "第一道刻好：存档 1 道、裂开次数清零、换成交叉符文（%s）" % s.active_tool,
		TotemResonanceShow.saved_runes() == 1 and TotemResonanceShow.saved_cracks() == 0 and s.phase == 1 and s.active_tool in ["finger", "brush"])
	await solve_rune(t, s)
	verify(t, "第二道刻好 → 笑脸符文", TotemResonanceShow.saved_runes() == 2 and s.phase == 2 and s.active_tool in ["tongue", "pinch"])
	s.meter.charge = TotemResonanceShow.FINAL_AT + 0.01
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.blue_laugh = 0.5
	s.simulate(0.1)
	verify(t, "笑脸符文充到七成：持续加强", s.final_surge)
	# 失败：同一道裂开三次
	GameState.vars[TotemResonanceShow.CRACK_KEY] = 2
	s.cracks = 2
	s.player.laugh.set_value(s.laugh_max() * 0.95)
	s.simulate(0.1)
	verify(t, "同一道裂开第三次：失败", s.failed)
	var hours0 := PenanceBook.hours()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:after_fail_totem") and find_show(t) != null and not find_show(t).busy and not CG.is_busy(), 60.0)
	s = find_show(t)
	verify(t, "失败小剧场 → 罚 2 工时 → 从第三道重刻（刻好的还在）", GameState.has_flag("cg_seen_theater:after_fail_totem") and s != null
		and s.completed == 2 and s.cracks == 0 and PenanceBook.hours() == hours0 + 2)
	if s == null:
		return
	var before := PenanceBook.hours()
	await solve_rune(t, s)
	await t._advance_until(func(): return DayClock.done(7, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and not AfterStory.running, 60.0)
	verify(t, "三道刻好 → 图腾柱扶正 → 减 20 工时（%d → %d）→ 晚上有庆功宴：天黑、停在晚上（%s）" % [before, PenanceBook.hours(), DayClock.label()],
		t.seen_cuts.has("after_d7_totem_done") and PenanceBook.hours() == before - 20 and DayClock.slot() == DayClock.NIGHT)
	# 工时规则
	verify(t, "还欠工时：最后一天要补（%d）、庆功宴还不开" % PenanceBook.hours(), AfterStory.must_settle() and AfterStory.pending_event() == "")
	var day := DayClock.day()
	await AfterStory.sleep_later()
	verify(t, "欠工时：床不让睡", DayClock.day() == day and DayClock.slot() == DayClock.NIGHT)
	DayClock.set_time(7, DayClock.AFTERNOON)
	var slot := DayClock.slot()
	var rested := await AfterStory.rest()
	verify(t, "（晚上没有安排时停在下午）欠工时：床不让休息", not rested and DayClock.slot() == slot)
	verify(t, "目标提示改成补罚", AfterStory.objective(AfterStory.TOWN).get("text", "").contains("补罚"))
	GameState.vars["penance_settled"] = PenanceBook.punishments().size()
	AfterPenance.refresh()
	verify(t, "补罚不看受罚记录也能接（penalty_open / penalty_d7）", AfterPenance.pending() == 0 and GameState.has_flag(AfterPenance.FLAG) and GameState.has_flag("penalty_d7"))
	var owed := PenanceBook.hours()
	verify(t, "补罚一次抵开始补时欠的三分之一、至少 5（欠 %d → 一次 %d）" % [owed, AfterPenance.settle_hours()], AfterPenance.settle_hours() == maxi(5, ceili(owed / 3.0)))
	# 跳关点曾经给 100 工时（图腾柱以后还欠 80）：要补 16 次，等于卡死。现在欠多少都是三次还清
	GameState.vars["penance_hours"] = 80
	GameState.vars.erase(AfterPenance.DEBT_KEY)
	var times := 0
	while AfterStory.must_settle() and times < 10:
		PenanceBook.add(-AfterPenance.settle_hours(), "补罚（测试）", true)
		times += 1
	verify(t, "欠 80 工时：补罚三次就还清（%d 次）" % times, times == 3 and PenanceBook.hours() == 0)
	GameState.vars["penance_hours"] = owed
	GameState.vars.erase(AfterPenance.DEBT_KEY)
	AfterPenance.refresh()
	DayClock.set_time(7, DayClock.NIGHT)
	verify(t, "欠着工时的晚上：报幕也能接、小屋不宵禁", AfterPenance.available("announcer") == AfterErrands.is_done("dance") and AfterStory.objective(AfterStory.TOWN).get("text", "").contains("补罚") and not GameState.has_flag(AfterStory.CURFEW))
	DayClock.set_time(7, DayClock.AFTERNOON)
	GameState.vars["penance_hours"] = 0
	AfterPenance.refresh()
	verify(t, "工时还清：补罚关掉、不再要补", not AfterStory.must_settle() and not GameState.has_flag("penalty_d7"))
	rested = await AfterStory.rest()
	verify(t, "还清以后可以休息到晚上（%s），庆功宴开放" % DayClock.label(), rested and DayClock.slot() == DayClock.NIGHT and AfterStory.pending_event() == "d7_festival")
	TotemResonanceShow.quiet = false
	TotemResonanceShow.fixed_seed = -1
