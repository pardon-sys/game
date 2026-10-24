extends "res://tests/f6_after_test.gd"
## 城门委托定向截图：三个阶段、实际干扰、结尾与完成后的地图。
const SPEC := preload("res://tests/helpers/f6_gate_chain.gd")
const OUT := "res://tools/.cache/shots/f6_gate_chain/"

func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f6_opening_done","f8_done","f8_returned","magic_unlocked","siege_won","after_started","penance_book","after_done_d4_morning"]: GameState.set_flag(f)
	DayClock.set_time(4,DayClock.AFTERNOON)
	GameState.vars["penance_hours"] = 50
	GameState.vars[GateChainShow.SAVE_STEP] = 0
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GateChainShow.quiet = true
	GateChainShow.fixed_seed = 61604
	var g := await SPEC.start(self)
	if g==null:
		push_error("未进入城门小游戏")
		get_tree().quit(1)
		return
	await _wait(0.35)
	await shot("thread")
	while g.completed<3: await SPEC.solve_node(self,g)
	await _wait(2.0)
	await shot("wheel")
	g.clear_feedback()
	g.apply_interference()
	await shot("interference")
	while g.completed<9: await SPEC.solve_node(self,g)
	await _wait(2.0)
	await shot("pull")
	while g.completed<11: await SPEC.solve_node(self,g)
	GateChainShow.quiet = false
	g.dialogue_quiet = false
	await SPEC.solve_node(self,g)
	await _advance_until(func():return Dialogue.is_active() and Dialogue._lines.size()==GateChainShow.text()["done"].size(),5.0)
	for i in 3:
		Dialogue.advance()
		Dialogue.advance()
		await get_tree().process_frame
	Dialogue._finish_typing()
	await get_tree().process_frame
	await shot("ending")
	await _advance_until(func():return AfterErrands.is_done("gate_chain"),5.0)
	await _wait(0.2)
	await shot("completed")
	get_tree().quit()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("SHOT ",label)
