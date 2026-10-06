extends Node
## 第八层第六轮截图（开发用）：Godot --path . res://tests/capture_f8_round6.tscn → tools/.cache/shots/f8r6_*.png
## 小房间开场过场、小房间全景、调查蜡笔画时蓝色公主插话、战败剧场里右边的魔力疲倦爆发立绘。

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
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done"]:
		GameState.set_flag(f)
	await main.change_level(Floors.scene("floor_08_shelter"))
	# 开场过场：打喷嚏那一句
	await _until_line("哈啾", 20.0)
	await _wait(0.5)
	await _shot("intro")
	await _until_line("我在窗边", 40.0)
	_finish()
	await _wait(1.2)
	_finish()
	await _wait(0.5)
	await _shot("room")
	# 调查蜡笔画：蓝色公主插话
	var p := GameState.player
	for n in main.level.find_children("*", "", true, false):
		if n.get("kind") == "crayon_drawing":
			p.global_position = (n as Node2D).global_position + Vector2(0, 20)
			await _wait(0.3)
			n.on_interact(p)
			break
	await _until_line("别看了", 10.0)
	await _wait(0.5)
	await _shot("drawing")
	_finish()
	await _wait(0.5)
	# 战败剧场（粉色公主操控）：爆发后右边是蓝色公主自己的魔力疲倦爆发立绘
	CG.play_theater("f8_defeat_1_1")
	await _until_line("闭、闭嘴", 60.0)
	await _wait(0.8)
	await _shot("burst_partner")
	get_tree().quit()


func _until_line(marker: String, limit: float) -> void:
	var t := 0.0
	while t < limit and not (Dialogue.is_active() and Dialogue.text_label.text.contains(marker)):
		if Dialogue.is_active() and not Dialogue.text_label.text.contains(marker):
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "f8r6_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
