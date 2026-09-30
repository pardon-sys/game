extends Node
## 第三层截图（开发用）：Godot --path . res://tests/capture_floor3.tscn → tools/.cache/shots/f3_*.png
## 各房间、吟唱魔法阵、星光爆发、组合技横幅、触手怪抓人。

const OUT := "res://tools/.cache/shots/"
const ROOMS := [
	[Vector2i(10, 48), "f3_01_landing"],
	[Vector2i(28, 48), "f3_02_rats"],
	[Vector2i(49, 47), "f3_03_vines"],
	[Vector2i(51, 33), "f3_04_crabs"],
	[Vector2i(31, 33), "f3_05_workshop"],
	[Vector2i(10, 33), "f3_06_trial"],
	[Vector2i(36, 19), "f3_07_wind"],
	[Vector2i(59, 18), "f3_08_chests"],
	[Vector2i(11, 18), "f3_09_hall"],
	[Vector2i(25, 8), "f3_10_boss"],
	[Vector2i(44, 7), "f3_11_stairs"],
]

var main: Node
var ctrl := ScriptedController.new()
var player: PlayableCharacter


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	main.change_level(Floors.scene("floor_03"))
	await _wait(1.6)
	await _shot("f3_00_intro")
	_finish()
	player = GameState.player
	player.set_controller(ctrl)
	var boss: TentacleBoss = main.level.find_child("Tentacle_25_4", true, false)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	for r in ROOMS:
		player.revive()
		player.global_position = Vector2(r[0].x * 16 + 8, r[0].y * 16 + 12)
		player.camera.reset_smoothing()
		await _wait(0.9)
		await _shot(r[1])
	# 吟唱与爆发（落脚点，小精灵会被吸引过来）
	player.revive()
	player.global_position = Vector2(8 * 16 + 8, 49 * 16 + 12)
	player.camera.reset_smoothing()
	await _wait(0.3)
	ctrl.hold(&"magic", true)
	await _wait(1.4)
	await _shot("f3_12_channel")
	await _wait(0.65)
	await _wait(0.1)
	await _shot("f3_13_burst")
	ctrl.hold(&"magic", false)
	# 组合技横幅
	player.revive()
	player.combo.reset()
	await _wait(0.2)
	_combo_banner()
	await _wait(0.3)
	await _shot("f3_14_combo")
	# 触手怪抓人
	player.revive()
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss._strike_cd = 0.2
	player.global_position = boss.global_position + Vector2(0, 60)
	player.camera.reset_smoothing()
	await _wait(1.3)
	await _shot("f3_15_boss_grab")
	get_tree().quit()


func _combo_banner() -> void:
	GameState.combo_triggered.emit("sole_duet", ReactionDB.combo("sole_duet")["name"])
	player.say_combo("sole_duet")


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
