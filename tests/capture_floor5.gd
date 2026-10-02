extends Node
## 第五层截图（开发用）：Godot --path . res://tests/capture_floor5.tscn → tools/.cache/shots/f5_*.png
## 开场过场（黑框）、各区域、束缚陷阱 + 弱点、背包被动页、结局（黑影）与章节结束画面。

const OUT := "res://tools/.cache/shots/"
const ROOMS := [
	[Vector2i(9, 84), "f5_01_landing"],
	[Vector2i(30, 82), "f5_02_cage_corridor"],
	[Vector2i(60, 66), "f5_03_workshop"],
	[Vector2i(56, 42), "f5_04_leg_corridor"],
	[Vector2i(30, 41), "f5_05_greenhouse"],
	[Vector2i(46, 23), "f5_06_wheel_workshop"],
	[Vector2i(68, 22), "f5_07_mud_cellar"],
	[Vector2i(78, 7), "f5_08_imp_workshop"],
	[Vector2i(44, 6), "f5_09_final_chain"],
	[Vector2i(9, 7), "f5_10_trap_room"],
]

var main: Node
var ctrl := ScriptedController.new()
var player: Princess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	main.change_level(Floors.scene("floor_05"))
	await _wait(2.2)
	await _shot("f5_00_intro_letterbox")
	var guard := 0
	while Cutscene.is_playing() and guard < 400:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.1)
		guard += 1
	player = GameState.player as Princess
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().get_nodes_in_group("monster_nest"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	for r in ROOMS:
		_place(r[0])
		await _wait(0.9)
		await _shot(r[1])
		_finish()
	# 倒吊绳套 + 弱点
	TickleZones.enabled = true
	var snare := main.level.find_child("Snare_81_66", true, false) as Node2D
	_place(Vector2i(81, 66))
	await _wait(0.5)
	var rat := main.level.find_child("Rat_75_70", true, false) as Monster
	for i in 3:
		player.receive_hit(HitData.make_tickle(rat, 4.0))
		await _wait(0.15)
	await _shot("f5_11_snare_weak_point")
	player.status.release(true)
	await _wait(0.5)
	# 举手铐柱 + 逗弄器
	_place(Vector2i(53, 62))
	await _wait(1.2)
	await _shot("f5_12_cuffs_teaser")
	player.status.release(true)
	await _wait(0.3)
	# 背包被动页
	GameState.set_flag(GameState.BACKPACK_FLAG)
	GameState.grant_passive("struggle_plus", true)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_PASSIVES)
	await _wait(0.2)
	await _shot("f5_13_backpack_passives")
	bp.set_page(Backpack.PAGE_STATUS)
	await _wait(0.2)
	await _shot("f5_14_backpack_status")
	bp.close()
	# 结局过场：黑影
	_place(Vector2i(16, 9))
	GameState.checkpoint = player.global_position
	Cutscene.play("f5_ending")
	guard = 0
	var shot_shadow := false
	while Cutscene.is_playing() and guard < 600:
		if not shot_shadow and Cutscene.spawned.has("shadow") and Cutscene.step_index >= 13:
			shot_shadow = true
			await _wait(0.5)
			await _shot("f5_15_ending_shadow")
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.1)
		guard += 1
	await _wait(1.5)
	await _shot("f5_16_chapter_end")
	get_tree().quit()


func _place(cell: Vector2i) -> void:
	player.revive()
	player.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 12)
	player.camera.reset_smoothing()


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
