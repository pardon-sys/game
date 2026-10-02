extends Node
## 这一批修复的截图（开发用）：Godot --path . res://tests/capture_fixes.tscn → tools/.cache/shots/fx_*.png
## 暂停菜单跳关列表、背包 CG 图鉴、第五层加密后的各区域、无解房间、落笼影子。

const OUT := "res://tools/.cache/shots/"

var main: Node
var player: Princess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ComboTracker.play_scenes = false
	DevConfig.override = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	var pm: Node = main.get_node("PauseMenu")
	pm.toggle()
	pm.show_skip_list()
	await _wait(0.2)
	await _shot("fx_01_pause_skip")
	pm.hide_skip_list()
	pm.toggle()
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_GALLERY)
	bp.gallery_selected = 5
	bp._refresh()
	await _wait(0.2)
	await _shot("fx_02_gallery")
	bp.close()
	await DevConfig.skip_to(DevConfig.skip_points()[4])
	await _wait(1.0)
	var guard := 0
	while Cutscene.is_playing() and guard < 400:
		_finish()
		await _wait(0.1)
		guard += 1
	player = GameState.player as Princess
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for r in [[Vector2i(28, 82), "fx_03_cage_corridor"], [Vector2i(66, 62), "fx_04_workshop"], [Vector2i(34, 64), "fx_05_chute_slope"],
			[Vector2i(56, 41), "fx_06_leg_corridor"], [Vector2i(76, 6), "fx_07_imp_workshop"], [Vector2i(7, 7), "fx_08_trap_room_top"],
			[Vector2i(7, 17), "fx_09_trap_room_loop"]]:
		player.global_position = Vector2(r[0].x * 16 + 8, r[0].y * 16 + 12)
		player.camera.reset_smoothing()
		await _wait(0.8)
		_finish()
		await _shot(r[1])
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
