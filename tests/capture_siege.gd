extends Node
## 攻防战截图（开发用）：Godot --path . res://tests/capture_siege.tscn [-- only=名字,名字] → tools/.cache/shots/siege_*.png

const OUT := "res://tools/.cache/shots/"

var main: Node
var only: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.trim_prefix("only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(500.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked",
			"intro_done_siege_intro", "siege_intro_seen"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _until(func(): return SiegeDirector.current != null and SiegeDirector.current.state == "prep")
	var d := SiegeDirector.current
	await _wait(0.5)
	_finish()
	await _wait(0.3)
	await _shot("prep")
	var pc := GameState.player.camera
	print("cam zoom ", pc.zoom, " limits ", pc.limit_left, ",", pc.limit_top, ",", pc.limit_right, ",", pc.limit_bottom, " current ", pc.is_current(), " vpcam ", get_viewport().get_camera_2d())
	pc.zoom = Vector2(0.5, 0.5)
	await _wait(0.5)
	print("after zoom ", pc.zoom)
	await _shot("zoomtest")
	# 开打
	d.start_now()
	await _wait(14.0)
	await _shot("fight")
	await _look(Vector2(d.blue.global_position.x, d.wall_foot_y() + 20.0), 1.0)
	await _wait(1.0)
	await _shot("wall")
	_unlook()
	get_tree().quit(0)


## 用玩家的镜头看某个地方（2.5D 的画面跟着玩家镜头渲染，所以不另建镜头）：镜头临时脱离人物。
func _look(at: Vector2, zoom: float) -> void:
	var cam := GameState.player.camera
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.global_position = at
	cam.zoom = Vector2(zoom, zoom)
	cam.reset_smoothing()
	await _wait(0.3)


func _unlook() -> void:
	var cam := GameState.player.camera
	cam.top_level = false
	cam.position = Vector2.ZERO
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = true
	cam.reset_smoothing()


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _until(cond: Callable, max_time := 20.0) -> void:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		t += 0.05


func _shot(name: String) -> void:
	if not only.is_empty() and not only.has(name):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "siege_" + name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
