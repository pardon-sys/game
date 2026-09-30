extends Node
## 扩充房间截图（开发用）：Godot --path . res://tests/capture_rooms.tscn → tools/.cache/shots/rooms_*.png

const OUT := "res://tools/.cache/shots/"
## [楼层, 格子, 截图名, 截图前要交互的节点]
const SHOTS := [
	["floor_01", Vector2i(16, 12), "rooms_f1_library_dark", ""],
	["floor_01", Vector2i(16, 12), "rooms_f1_library_crack", "Torch_17_7"],
	["floor_01", Vector2i(23, 12), "rooms_f1_secret", "Secret_19_13"],
	["floor_01", Vector2i(20, 39), "rooms_f1_levers", ""],
	["floor_01", Vector2i(44, 39), "rooms_f1_armory", ""],
	["floor_02", Vector2i(26, 15), "rooms_f2_vents", ""],
	["floor_02", Vector2i(37, 15), "rooms_f2_webghost", ""],
	["floor_02", Vector2i(36, 27), "rooms_f2_rest", ""],
]

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	GameState.set_flag("seen_laugh_recover")
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	var current := "floor_01"
	for s in SHOTS:
		if s[0] != current:
			current = s[0]
			main.change_level(Floors.scene(current))
			await _wait(1.4)
			_finish()
		var player := GameState.player
		player.set_controller(ScriptedController.new())
		player.revive()
		if s[3] != "":
			main.level.find_child(s[3], true, false).on_interact(player)
		player.global_position = Vector2(s[1].x * 16 + 8, s[1].y * 16 + 12)
		player.camera.reset_smoothing()
		await _wait(0.8)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + s[2] + ".png"))
		print("shot ", s[2])
	get_tree().quit()


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
