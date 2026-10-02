extends Node
## 新部位（肚子 / 屁股 / 胸）截图（开发用）：Godot --path . res://tests/capture_zones.tscn → tools/.cache/shots/zn_*.png
## 第五层的滑梯坡道、仰卧刑床 + 肚脐羽毛钻、落穴洞、掸子墙、张臂转盘、吸附类怪物、长舌蛙吐舌、部位专属特效、背包状态页。

const OUT := "res://tools/.cache/shots/"

var main: Node
var ctrl := ScriptedController.new()
var player: Princess
var level: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	for f in ["seen_laugh_recover", "hint_latch", "hint_restraint", "hint_cage"]:
		GameState.set_flag(f)
	main.change_level(Floors.scene("floor_05"))
	await _wait(2.2)
	var guard := 0
	while Cutscene.is_playing() and guard < 400:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.1)
		guard += 1
	level = main.level
	player = GameState.player as Princess
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().get_nodes_in_group("monster_nest"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	TickleZones.enabled = true
	# 区域总览
	for r in [[Vector2i(34, 66), "zn_01_chute_slope"], [Vector2i(77, 58), "zn_02_supine_area"], [Vector2i(34, 83), "zn_03_cage_corridor_new"]]:
		_place(r[0])
		await _wait(0.9)
		await _shot(r[1])
		_finish()
	# 滑梯：踩上去滑
	_place(Vector2i(46, 66))
	ctrl.move = Vector2.LEFT
	await _wait(0.3)
	ctrl.move = Vector2.ZERO
	await _shot("zn_04_chute_sliding")
	await _wait(1.0)
	await _shot("zn_05_prone_grabbed")
	player.status.release(true)
	await _wait(0.3)
	# 仰卧刑床 + 肚脐羽毛钻（部位特效）
	_place(Vector2i(77, 56))
	await _wait(1.0)
	await _shot("zn_06_supine_drill")
	player.status.release(true)
	await _wait(0.3)
	# 落穴洞
	_place(Vector2i(39, 84))
	await _wait(0.8)
	await _shot("zn_07_pit")
	player.status.release(true)
	await _wait(0.3)
	# 掸子墙
	_place(Vector2i(30, 85))
	await _wait(0.42)
	await _shot("zn_08_duster")
	await _wait(0.5)
	# 张臂转盘
	_place(Vector2i(45, 4))
	await _wait(0.7)
	await _shot("zn_09_spinwheel")
	player.status.release(true)
	await _wait(1.0)
	# 吸附：章鱼宝宝 + 毛毛虫
	_place(Vector2i(70, 22))
	var o: Monster = load("res://scenes/actors/monsters/suction_octopus.tscn").instantiate()
	level.get_node("Entities").add_child(o)
	o.global_position = player.global_position + Vector2(20, 0)
	var c: Monster = load("res://scenes/actors/monsters/caterpillar.tscn").instantiate()
	level.get_node("Entities").add_child(c)
	c.global_position = player.global_position + Vector2(-12, 0)
	await _wait(3.0)
	await _shot("zn_10_latched")
	GameState.set_flag(GameState.BACKPACK_FLAG)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_STATUS)
	await _wait(0.2)
	await _shot("zn_11_backpack_status")
	bp.close()
	player.fling_latchers()
	o.queue_free()
	c.queue_free()
	await _wait(0.3)
	# 长舌蛙吐舌
	_place(Vector2i(70, 26))
	var f: TongueFrog = load("res://scenes/actors/monsters/tongue_frog.tscn").instantiate()
	level.get_node("Entities").add_child(f)
	f.global_position = player.global_position + Vector2(40, 0)
	guard = 0
	while f.lick != TongueFrog.Lick.OUT and guard < 300:
		await get_tree().physics_frame
		guard += 1
	await _wait(0.08)
	await _shot("zn_12_frog_tongue")
	get_tree().quit()


func _place(cell: Vector2i) -> void:
	player.revive()
	player.laugh.clear()
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
