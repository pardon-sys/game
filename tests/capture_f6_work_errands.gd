extends "res://tests/f6_after_test.gd"
## 两项劳动委托定向截图；只走相关接取、舞台和结尾，不跑七日流程。
const CHAIN := preload("res://tests/helpers/f6_gate_chain.gd")
const WOOL := preload("res://tests/helpers/f6_shearing.gd")
const OUT := "res://tools/.cache/shots/f6_work_errands/"

func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f6_opening_done", "f8_done", "f8_returned", "magic_unlocked", "siege_won", "after_started", "penance_book", "after_done_d4_morning", "errand_goats_done"]: GameState.set_flag(f)
	DayClock.set_time(4, DayClock.AFTERNOON)
	GameState.vars["penance_hours"] = 50
	GameState.vars[GateChainShow.SAVE_STEP] = 0
	GameState.vars[ShearingShow.SAVE_STEP] = 0
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GateChainShow.quiet = true
	GateChainShow.fixed_seed = 61604
	var g := await CHAIN.start(self)
	if g == null:
		push_error("未进入穿链舞台")
		get_tree().quit(1)
		return
	await _wait(1.65)
	await shot("chain_continuous")
	await _advance_until(func(): return g.interference.warning(), 5.0)
	await shot("chain_warning")
	while g.completed < 3: await CHAIN.solve_node(self, g)
	await _wait(1.5)
	await shot("chain_wheel")
	while g.completed < 9: await CHAIN.solve_node(self, g)
	await _wait(1.5)
	await shot("chain_pull")
	while g.completed < 11: await CHAIN.solve_node(self, g)
	g.dialogue_quiet = false
	await CHAIN.solve_node(self, g)
	Dialogue._finish_typing()
	await shot("chain_ending")
	await _advance_until(func(): return AfterErrands.is_done("gate_chain"), 5.0)
	_go(Cutscene.cell_to_world([55, 34]))
	ShearingShow.quiet = true
	ShearingShow.fixed_seed = 61605
	var s := await WOOL.start(self)
	if s == null:
		push_error("未进入剪毛舞台")
		get_tree().quit(1)
		return
	await _wait(1.65)
	await work_pose(s)
	await shot("wool_comb")
	while s.completed < 3: await WOOL.solve_segment(self, s)
	await work_pose(s)
	await shot("wool_shear")
	while s.completed < 7: await WOOL.solve_segment(self, s)
	await work_pose(s)
	s._sheep_left = 0.5
	s._refresh()
	await shot("wool_bag_warning")
	s.simulate(0.25)
	s.simulate(0.25)
	await shot("wool_shake")
	while s.completed < 9: await WOOL.solve_segment(self, s)
	s.dialogue_quiet = false
	# 最后一段会打开结尾对白，保留舞台直到截图。
	await WOOL.solve_segment(self, s)
	Dialogue._finish_typing()
	await shot("wool_ending")
	await _advance_until(func(): return AfterErrands.is_done("shearing"), 5.0)
	await _wait(0.2)
	await shot("completed")
	get_tree().quit()

func work_pose(s: ShearingShow) -> void:
	s.set_process(false)
	for i in 10:
		s.angle = s.target_angle
		s.hold_tool(true)
		s.simulate(0.1)
		await get_tree().process_frame
	s.clear_feedback()
	s._reaction()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)
