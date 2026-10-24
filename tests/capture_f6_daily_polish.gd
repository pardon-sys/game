extends "res://tests/f6_after_test.gd"
## 本批视觉验收：三张裁缝卡、早午夜日程与实际考核冻结，输出tools/.cache/shots。
const OUT := "res://tools/.cache/shots/f6_daily_polish/"
func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	for flag in ["f6_opening_done","f8_done","f8_returned","blue_tickle_pants","magic_unlocked","siege_won","after_started","penance_book"]: GameState.set_flag(flag)
	DayClock.set_time(3,0)
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var chart := TailorChart.new()
	chart.position = Vector2(120,12)
	layer.add_child(chart)
	var task := TaskTailor.new()
	task._chart = chart
	var sole_only := "--sole-only" in OS.get_cmdline_user_args()
	for part in (["sole"] if sole_only else ["armpit","waist","sole"]):
		(func(): await task._menu(part,{0:"strong",1:"weak",2:"none"},[0])).call()
		await _wait(0.2)
		await shot("tailor_"+part)
		Dialogue.runner.choice_menu.choose(0)
		await get_tree().process_frame
	task.free()
	layer.queue_free()
	GameState.in_dialogue = false
	if sole_only:
		get_tree().quit()
		return
	for slot in 3:
		DayClock.set_time(3,slot)
		AfterBlueRoutine.current.sync(true)
		var blue := AfterBlueRoutine.current.blue
		var cam := GameState.player.camera
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.global_position = blue.global_position
		cam.reset_smoothing()
		await _wait(0.2)
		await shot("blue_routine_"+str(slot))
	var blue := AfterBlueRoutine.current.blue
	GameState.switch_control(blue)
	DrillShow.quiet = true
	var show := DrillExamShow.new()
	add_child(show)
	(func(): await show.play()).call()
	await _wait(0.4)
	show.set_process(false)
	for key in ["Q","W","A"]: show.press(key)
	await _wait(0.2)
	await shot("exam_frozen")
	show._done = true
	await _wait(0.5)
	get_tree().quit()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("SHOT ",label)
