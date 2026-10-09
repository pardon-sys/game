extends Node
## 第八层夜迷宫截图（开发用）：Godot --path . res://tests/capture_maze.tscn → tools/.cache/shots/maze_*.png
## 2.5D 光照、紫手 + 头顶 QTE、立绘上盖着的手、冰封的粉色公主（睡觉过场）。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "blue_is_hero",
			"intro_done_f8_maze_intro"]:
		GameState.set_flag(f)
	await main.change_level(Floors.scene("floor_08_maze_1"))
	await _wait(1.0)
	_finish()
	await _wait(1.0)
	await _shot("lit")
	var dir := MazeDirector.instance
	var blue := GameState.player
	blue.global_position += Vector2(40, -20)
	var h := dir.spawn_hand(blue.global_position + Vector2(30, 0))
	await _wait(0.2)
	h.global_position = blue.global_position + Vector2(14, 0)
	await _wait(0.5)
	await _shot("qte")
	if KeySequenceQTE.current:
		KeySequenceQTE.current.press(0)
	await _wait(0.6)
	for z in ["thigh", "thigh", "thigh", "butt", "butt", "sole", "armpit"]:
		dir.cover_zone(z)
	blue.laugh.set_value(blue.laugh.giggle_threshold + 5.0)
	await _wait(1.2)
	var fx: PortraitFx = Dialogue.portrait_fx
	print("DEBUG hands=", fx.cover_hands, " active=", fx.active(), " layer_vis=", fx._hand_layer.visible, " rect=", fx.portrait_rect(),
		" in_cutscene=", GameState.in_cutscene, " wide=", Dialogue.is_portrait_wide())
	await _shot("hands")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "maze_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
