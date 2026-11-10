extends RefCounted
## 剪毛专项：前置、真实接取、连续操作／干扰、恢复、存档、来源清理与一次性结算。
static var checks := 0

static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)

static func find_show(t: Node) -> ShearingShow:
	return t._show(ShearingShow) as ShearingShow

static func start(t: Node) -> ShearingShow:
	await t._talk("floor_06/after_maid", "errand_shearing", [0])
	t._go(Cells.to_world([57, 33]))
	await t._advance_until(func(): return find_show(t) != null, 3.0)
	return find_show(t)

static func solve_segment(t: Node, show: ShearingShow) -> void:
	await t._advance_until(func(): return not is_instance_valid(show) or not show.busy, 3.0)
	if not is_instance_valid(show) or show._done: return
	show.set_process(false)
	show.player.laugh.set_value(0.0)
	var before := show.completed
	for i in 90:
		for j in 20:
			if show.angle_error() <= ShearingShow.TURN_STEP * 0.55: break
			show.press("RIGHT" if angle_difference(show.angle, show.target_angle) > 0 else "LEFT")
		show.hold_tool(true)
		show.simulate(0.1)
		if show.completed != before: break
		if i % 10 == 0: await t.get_tree().process_frame
	await t.get_tree().process_frame

static func run(t: Node) -> void:
	checks = 0
	ShearingShow.quiet = true
	ShearingShow.fixed_seed = 61605
	for f in ["after_started", "penance_book", "f6_opening_done", "after_done_d4_morning"]: GameState.set_flag(f)
	for id in AfterErrands.ids():
		for suffix in ["open", "active", "done"]: GameState.set_flag("errand_%s_%s" % [id, suffix], false)
	GameState.vars.erase(ShearingShow.SAVE_STEP)
	GameState.vars["penance_hours"] = 50
	GameState.vars["penance_punish"] = []
	DayClock.set_time(4, DayClock.AFTERNOON)
	AfterErrands.start("shearing")
	verify(t, "赶羊未完成，提示及直接接取均不可绕过前置", not AfterErrands.is_open("shearing") and AfterErrands.active() == "")
	GameState.set_flag("errand_goats_done")
	DayClock.set_time(3, DayClock.AFTERNOON)
	verify(t, "第3天不开放剪毛", not AfterErrands.is_open("shearing"))
	DayClock.set_time(4, DayClock.NIGHT)
	verify(t, "夜间不开放剪毛", not AfterErrands.is_open("shearing"))
	DayClock.set_time(4, DayClock.AFTERNOON)
	verify(t, "第4天白天完成赶羊后开放，旧档进度默认为零", AfterErrands.is_open("shearing") and ShearingShow.saved_step() == 0)
	GameState.vars[ShearingShow.SAVE_STEP] = 99
	verify(t, "旧档越界进度钳制", ShearingShow.saved_step() == 10)
	GameState.vars[ShearingShow.SAVE_STEP] = 0
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	verify(t, "女仆新委托不会被赶羊完成闲谈挡住", Dialogue.runner.entry_of("floor_06/after_maid") == "errand_shearing")
	var s := await start(t)
	verify(t, "通过真实对白和羊圈目标开演", s != null and AfterErrands.is_active("shearing"))
	if s == null: return
	verify(t, "演员：粉色、女仆、咕咕、还没出场的小羊羔，持有一个地图锁", s.actors.size() == 4 and s.actors.has("sheep") and not s.actors["lamb"].visible and not s.actors.has("blue") and GameState.dialogue_holds == 1)
	verify(t, "开场合成一个对白块", s.dialogue_blocks == 1)
	await t._advance_until(func(): return s.shake_count >= 1 and s.interference.strong_count >= 2, 20.0)
	verify(t, "不推进也持续干扰、两次加强、咕咕舔脚和一次抖毛", s.interference.strong_count >= 2 and s.shake_count >= 1 and s.licks > 0 and s.completed == 0 and s.player.laugh.value > 0)
	await t._advance_until(func(): return s.fx_root.get_child_count() > 0 and not s._floating.is_empty(), 2.0)
	verify(t, "操作期间特效与反应存在，无阻塞对白", s.fx_root.get_child_count() > 0 and not s._floating.is_empty() and not Dialogue.is_active() and not s.busy)
	verify(t, "毛流动作在原方框内，右侧按键说明不遮挡", s._action_caption==Dialogue.reaction_text and not s._action_caption.text.is_empty() and s.hint_label.position.x>=Dialogue.reaction_panel.position.x+Dialogue.reaction_panel.size.x)
	s.set_process(false)
	var clock := s.elapsed
	var sheep_left := s._sheep_left
	var laugh_before := s.player.laugh.value
	s.busy = true
	s.simulate(1.0)
	s.hold_tool(true)
	verify(t, "阶段对白冻结计时、压力和工具", s.elapsed == clock and s.player.laugh.value == laugh_before and not s.holding_tool)
	s.busy = false
	t.get_tree().paused = true
	s.simulate(1.0)
	s.press("J")
	verify(t, "暂停冻结女仆和羊两套计时", s.elapsed == clock and s._sheep_left == sheep_left and not s.holding_tool)
	t.get_tree().paused = false
	GameState.in_cutscene = true
	s.simulate(1.0)
	verify(t, "外部演出不消耗工作时间", s.elapsed == clock)
	GameState.in_cutscene = false
	var strong_before := s.interference.strong_count
	s.simulate(0.1)
	verify(t, "恢复仅推进当前帧，没有集中补发", is_equal_approx(s.elapsed - clock, 0.1) and s.interference.strong_count - strong_before <= 1)
	s.angle = wrapf(s.target_angle + PI, -PI, PI)
	s.hold_tool(true)
	for i in 5: s.simulate(0.1)
	verify(t, "按住工具但方向错误不推进", s.progress == 0.0 and s.completed == 0)
	s.hold_tool(false)
	s.angle = s.target_angle
	s.simulate(0.1)
	verify(t, "松开工具即使方向正确也不推进", s.progress == 0.0)
	s.hold_tool(true)
	s.simulate(0.1)
	verify(t, "方向正确并持续工作才增长", s.progress > 0.0)
	var release := InputEventKey.new()
	release.keycode = KEY_J
	release.pressed = false
	s._input(release)
	verify(t, "真实J松开事件停止工作", not s.holding_tool)
	s.salt = 1.0
	var calm := s.sheep_interval()
	var calm_warn := s.sheep_warning()
	var lick_fast := s.lick_interval()
	s.salt = 0.0
	verify(t, "盐越多咕咕越乖：抖毛隔得久、预告早，舔得也勤", calm > s.sheep_interval() and calm_warn > s.sheep_warning() and lick_fast < s.lick_interval())
	s.salt = 1.0
	s.player.laugh.set_value(0.0)
	var licks_before := s.licks
	s.lick_now()
	var salty := s.player.laugh.value
	verify(t, "舔一下脚：盐少一点", s.licks == licks_before + 1 and s.salt < 1.0)
	s.salt = 0.0
	s.player.laugh.set_value(0.0)
	s.lick_now()
	verify(t, "盐越多舔得越痒（%.2f > %.2f）" % [salty, s.player.laugh.value], salty > s.player.laugh.value)
	s.salt = 0.6
	verify(t, "K 擦掉一些盐，有冷却", s.wipe() and is_equal_approx(s.salt, 0.35) and not s.wipe())
	s.player.laugh.set_value(0.0)
	await solve_segment(t, s)
	await solve_segment(t, s)
	verify(t, "持续对准完成两段并保存，不逐段播剧情", s.completed == 2 and ShearingShow.saved_step() == 2 and s.dialogue_blocks == 1)
	s.add_laugh(s.laugh_max())
	s._process(0.01)
	verify(t, "满闷笑安全恢复不倒扣已完成段、不加补罚", s.completed == 2 and s.recovery_left > 0.0 and s.progress == 0.0 and PenanceBook.punishments().is_empty())
	for i in 16: s.simulate(0.1)
	var clean_laugh := s._start_laugh
	var clean_fatigue := s._start_fatigue
	s.quit()
	await t._advance_until(func(): return find_show(t) == null, 2.0)
	verify(t, "退出保留两段且不发奖励，归还输入锁和临时状态", ShearingShow.saved_step() == 2 and PenanceBook.hours() == 50 and GameState.dialogue_holds == 0 and is_equal_approx(GameState.player.laugh.value, clean_laugh) and is_equal_approx(GameState.player.fatigue.value, clean_fatigue) and GameState.player.laugh.is_processing() and not GameState.player.has_meta("suppress_laugh_tutorials"))
	t._go(Cells.to_world([55, 34]))
	var save_dir := SaveSystem.dir
	SaveSystem.dir = "/private/tmp/f6-shearing-test-saves/"
	verify(t, "真实隔离存档保存剪毛进度", SaveSystem.save(1, "shearing-test") and int(SaveSystem.read(1)["vars"][ShearingShow.SAVE_STEP]) == 2)
	s = await start(t)
	verify(t, "重新接取恢复第三段", s != null and s.completed == 2)
	if s == null: return
	s.dialogue_quiet = false
	s._lines(ShearingShow.text()["resume"])
	await t.get_tree().process_frame
	verify(t, "对白进行中读档成功", Dialogue.is_active() and await SaveSystem.load_slot(1))
	await t._wait(0.2)
	verify(t, "读档清理旧舞台与对白并保留进度", find_show(t) == null and not Dialogue.is_active() and GameState.dialogue_holds == 0 and ShearingShow.saved_step() == 2)
	s = await start(t)
	if s == null:
		verify(t, "读档后可重接", false)
		return
	await solve_segment(t, s)
	verify(t, "三毛结完成进入分区剪毛，只增加一次转换对白", s.phase == 1 and s.dialogue_blocks == 2)
	var carry := []
	var capture := func(p):
		if p.character_id == "pink": carry.append([p.laugh.value, p.fatigue.value])
	clean_laugh = s._start_laugh
	clean_fatigue = s._start_fatigue
	GameState.player_registered.connect(capture)
	s.hold_tool(true)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	GameState.player_registered.disconnect(capture)
	await t._wait(0.2)
	verify(t, "工作中换图释放演出并保留委托", find_show(t) == null and AfterErrands.is_active("shearing") and GameState.dialogue_holds == 0)
	verify(t, "换图不携带临时闷笑疲倦", carry.size() == 1 and is_equal_approx(float(carry[0][0]), clean_laugh) and is_equal_approx(float(carry[0][1]), clean_fatigue))
	t._go(Cells.to_world([57, 33]))
	await t._advance_until(func(): return find_show(t) != null, 3.0)
	s = find_show(t)
	if s == null: return
	verify(t, "换图回目标恢复剪毛阶段", s.phase == 1 and s.completed == 3)
	while s.completed < 7: await solve_segment(t, s)
	verify(t, "四区域完成后进入三堆装袋", s.phase == 2 and s.completed == 7)
	verify(t, "装袋阶段小羊羔挤过来，女仆又抹了盐（%.2f）" % s.salt, s.actors["lamb"].visible and s.salt > 0.3)
	var lickers := {}
	for i in 2:
		s.lick_now()
		lickers[s.lick_by] = true
	verify(t, "小羊羔和咕咕轮流舔两只脚", lickers.has("lamb") and lickers.has("sheep"))
	s.player.laugh.set_value(0.0)
	s.player.fatigue.set_value(0.0)
	s.set_process(false)
	s.progress = 3.0
	s._sheep_left = 0.01
	s.hold_tool(false)
	s.simulate(0.1)
	verify(t, "抖毛散开未装袋部分，已完成区域不丢", s.progress == 2.25 and s.completed == 7)
	var final_blocks := []
	s.finished.connect(func(): final_blocks.append(s.dialogue_blocks))
	while is_instance_valid(s) and s.completed < 10: await solve_segment(t, s)
	verify(t, "重进后的开场、装袋转换和结尾总共三处对白", final_blocks == [3])
	await t._advance_until(func(): return AfterErrands.is_done("shearing"), 3.0)
	await t.get_tree().process_frame
	verify(t, "十段完成减三工时，舞台与锁清理", AfterErrands.is_done("shearing") and ShearingShow.saved_step() == 10 and PenanceBook.hours() == 47 and find_show(t) == null and GameState.dialogue_holds == 0)
	AfterErrands.start("shearing")
	AfterErrands.complete("shearing")
	verify(t, "重复接取或完成不能重复减工时", PenanceBook.hours() == 47 and AfterErrands.active() == "")
	var dev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/skip_points_more.json"))
	var points: Array = dev["skip_points"].filter(func(p): return str(p["name"]).begins_with("七日赎罪"))
	verify(t, "赎罪跳关清理剪毛标记与进度", points.all(func(p): return p["vars"].get(ShearingShow.SAVE_STEP, -1) == 0 and "!errand_shearing_done" in p["flags"]))
	SaveSystem.delete(1)
	SaveSystem.dir = save_dir
	ShearingShow.quiet = false
	ShearingShow.fixed_seed = -1
	print("蘑菇羊剪毛针对性断言：%d" % checks)
