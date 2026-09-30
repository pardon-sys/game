extends Node
## 强制遭遇段截图（开发用）：Godot --path . res://tests/capture_levels.tscn → tools/.cache/shots/lv_*.png

const OUT := "res://tools/.cache/shots/"
## [楼层, 镜头所在格, 截图名]
const SHOTS := [
	["floor_01", Vector2i(31, 32), "lv1_feather_porch"],
	["floor_01", Vector2i(31, 24), "lv1_guard_arena"],
	["floor_01", Vector2i(28, 4), "lv1_spikes"],
	["floor_01", Vector2i(52, 12), "lv1_treasure_belt"],
	["floor_02", Vector2i(12, 16), "lv2_bat_wind"],
	["floor_02", Vector2i(31, 5), "lv2_ghost_vines"],
	["floor_02", Vector2i(51, 19), "lv2_spider_arena"],
	["floor_02", Vector2i(41, 33), "lv2_machine_belt"],
	["floor_02", Vector2i(22, 35), "lv2_troll_arena"],
	["floor_03", Vector2i(30, 48), "lv3_rat_vines"],
	["floor_03", Vector2i(49, 33), "lv3_crab_belt"],
	["floor_03", Vector2i(31, 30), "lv3_workshop"],
	["floor_03", Vector2i(11, 18), "lv3_hall_arena"],
	["floor_03", Vector2i(25, 6), "lv3_boss"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	var current := "floor_01"
	for s in SHOTS:
		if s[0] != current:
			current = s[0]
			main.change_level(Floors.scene(current))
			await _wait(1.4)
			_finish()
		var p := GameState.player
		p.set_controller(ScriptedController.new())
		p.revive()
		p.set_invulnerable(5.0, true)
		p.global_position = Vector2(s[1].x * 16 + 8, s[1].y * 16 + 12)
		p.camera.reset_smoothing()
		await _wait(1.0)
		_finish()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + s[2] + ".png"))
		print("shot ", s[2])
	get_tree().quit()


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
