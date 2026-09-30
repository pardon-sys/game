extends Node
## 第二层截图（开发用）：Godot --path . res://tests/capture_floor2.tscn → tools/.cache/shots/f2_*.png

const OUT := "res://tools/.cache/shots/"
var main: Node
var player: PlayableCharacter


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	main.change_level("res://scenes/levels/dungeon_02.tscn")
	await _wait(1.4)
	await _shot("f2_0_intro")
	_finish()
	player = GameState.player
	player.set_controller(ScriptedController.new())
	GameState.set_flag("seen_laugh_recover")
	await _go(Vector2i(9, 38), "f2_1_landing", 0.8)
	var vent: Trap = main.level.find_child("Vent_12_13", true, false)
	vent.trigger()
	await _go(Vector2i(12, 16), "f2_2_bats", 1.3)
	player.revive()
	await _go(Vector2i(26, 6), "f2_3_ghosts", 1.2)
	var spider: TickleSpider = main.level.find_child("Spider_47_19", true, false)
	await _go(Vector2i(50, 21), "", 0.4)
	spider.target = player
	spider.state = Monster.State.CHASE
	spider.shoot_web()
	await _wait(0.25)
	await _shot("f2_4_spiders")
	player.revive()
	await _go(Vector2i(36, 31), "f2_5_machines", 1.4)
	player.revive()
	var troll: TickleTroll = main.level.find_child("Troll_22_34", true, false)
	await _go(Vector2i(25, 34), "", 0.2)
	troll.target = player
	troll.state = Monster.State.CHASE
	troll._perform("tickle", player)
	await _wait(1.6)
	await _shot("f2_6_troll_grab")
	get_tree().quit()


func _go(cell: Vector2i, shot_name: String, wait: float) -> void:
	player.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 12)
	player.camera.reset_smoothing()
	await _wait(wait)
	if shot_name != "":
		await _shot(shot_name)


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("shot ", n)


func _finish() -> void:
	while Dialogue.is_active():
		Dialogue.advance()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
