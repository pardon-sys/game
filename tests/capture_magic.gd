extends Node
## 魔法截图（开发用）：Godot --path . res://tests/capture_magic.tscn → tools/.cache/shots/magic_*.png

const OUT := "res://tools/.cache/shots/"
var main: Node
var ctrl := ScriptedController.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	GameState.set_flag("magic_unlocked")
	var p := GameState.player
	p.set_controller(ctrl)
	p.global_position = Vector2(12 * 16 + 8, 11 * 16 + 12)  # 第一层书房（没有怪物）
	p.camera.reset_smoothing()
	await _wait(0.5)
	ctrl.hold(&"magic", true)
	await _wait(0.3)
	await _shot("magic_0_channel")
	await _wait(0.5)
	await _shot("magic_1_tier1")
	await _wait(0.6)
	await _shot("magic_2_tier2")
	await _wait(0.5)
	await _shot("magic_3_tier3")
	await _wait(0.12)
	await _shot("magic_4_burst")
	await _wait(0.12)
	await _shot("magic_5_burst")
	ctrl.hold(&"magic", false)
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
