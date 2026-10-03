extends Node
## 新精灵图截图（开发用）：Godot --path . res://tests/capture_sprites.tscn → tools/.cache/shots/sp_*.png
## 在地下小镇里把公主和蓝色公主并排放着，依次截：站立、四个方向走路、憋笑、失控一 / 二、战损、魔法吟诵。

const OUT := "res://tools/.cache/shots/"

var main: Node
var pink: Princess
var blue: BluePrincess
var ctrl := ScriptedController.new()
var bctrl := ScriptedController.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	GameState.set_flag("f6_opening_done")
	GameState.set_flag("intro_done_f6_wake")
	GameState.set_flag("magic_unlocked")
	GameState.set_flag("seen_laugh_recover")
	GameState.set_flag("was_helpless")
	main.change_level(Floors.scene("floor_06_upper"))
	await _wait(1.5)
	_finish()
	pink = GameState.player as Princess
	pink.set_controller(ctrl)
	for n in main.level.find_children("*", "", true, false):
		if n is BluePrincess:
			blue = n
	blue.set_controller(bctrl)
	pink.global_position = Vector2(30 * 16 + 8, 27 * 16 + 12)
	blue.global_position = pink.global_position + Vector2(24, 0)
	pink.camera.reset_smoothing()
	pink.camera.zoom = Vector2(4, 4)
	await _wait(0.5)
	await _shot("sp_01_idle")
	for d in [["down", Vector2.DOWN], ["left", Vector2.LEFT], ["right", Vector2.RIGHT], ["up", Vector2.UP]]:
		ctrl.move = d[1] * 0.4
		bctrl.move = d[1] * 0.4
		await _wait(0.35)
		await _shot("sp_02_walk_" + d[0])
		ctrl.move = Vector2.ZERO
		bctrl.move = Vector2.ZERO
		pink.global_position = Vector2(30 * 16 + 8, 27 * 16 + 12)
		blue.global_position = pink.global_position + Vector2(24, 0)
		await _wait(0.1)
	pink.facing = Vector2.DOWN
	blue.facing = Vector2.DOWN
	for st in [["giggle", 0.45], ["helpless_1", 0.6], ["helpless_2", 0.8]]:
		pink.laugh.set_value(pink.laugh.max_value * st[1])
		blue.laugh.set_value(blue.laugh.max_value * st[1])
		await _wait(0.5)
		await _shot("sp_03_" + st[0])
	pink.laugh.clear()
	blue.laugh.clear()
	pink.battle_damaged = true
	blue.battle_damaged = true
	pink.emotion.refresh()
	blue.emotion.refresh()
	await _wait(0.5)
	await _shot("sp_04_damaged")
	pink.battle_damaged = false
	pink.emotion.refresh()
	ctrl.hold(&"magic", true)
	bctrl.hold(&"magic", true)
	await _wait(0.8)
	await _shot("sp_05_chant")
	ctrl.hold(&"magic", false)
	bctrl.hold(&"magic", false)
	await _wait(0.15)
	await _shot("sp_06_burst")
	print("截图完成")
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("shot ", n)


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
