extends Node
## 第六层截图（开发用）：Godot --path . res://tests/capture_floor6.tscn → tools/.cache/shots/f6_*.png
## 开场各阶段（刑床、审问选项、换刑具、小剧场、蓝色公主）、小镇各层、NPC 立绘对话、商店、存档界面、主界面。

const OUT := "res://tools/.cache/shots/"
const SPOTS := [
	["floor_06_upper", Vector2i(44, 27), "f6_10_bonfire"],
	["floor_06_upper", Vector2i(12, 25), "f6_11_market"],
	["floor_06_upper", Vector2i(20, 11), "f6_12_houses"],
	["floor_06_upper", Vector2i(32, 31), "f6_13_save_point"],
	["floor_06_upper", Vector2i(54, 8), "f6_14_gate"],
	["floor_06_camp", Vector2i(26, 17), "f6_20_camp"],
	["floor_06_camp", Vector2i(36, 22), "f6_21_training"],
	["floor_06_mine", Vector2i(30, 13), "f6_30_mine"],
]

var main: Node
var player: Princess
var shots := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveSystem.dir = "user://capture_saves/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	main.change_level(Floors.scene("floor_06_prison"))
	await _wait(1.3)
	# 开场：按步骤截
	var want := {2: "f6_01_wake_bed", 8: "f6_02_captain", 12: "f6_03_question", 17: "f6_04_cushion", 19: "f6_05_theater",
		23: "f6_06_blue", 29: "f6_07_free"}
	var guard := 0
	var taken := {}
	var cg_shot := false
	while guard < 3000 and (Cutscene.is_playing() or Dialogue.runner.is_running() or Dialogue.is_active() or CG.is_busy()):
		guard += 1
		var idx := Cutscene.step_index
		if want.has(idx) and not taken.has(idx):
			await _wait(1.2)
			taken[idx] = true
			await _shot(want[idx])
		if CG.is_playing() and not cg_shot and Dialogue.is_active():
			cg_shot = true
			await _wait(1.0)
			await _shot("f6_05_theater_cg")
		var cm: ChoiceMenu = Dialogue.runner.choice_menu
		if cm.is_open():
			await _wait(0.3)
			await _shot("f6_03_question_menu")
			cm.choose(1)
		elif Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.12)
	await _shot("f6_08_after")
	for s in SPOTS:
		if main.level.get("floor_id") != s[0]:
			main.change_level(Floors.scene(s[0]))
			await _wait(1.4)
			_finish()
		player = GameState.player as Princess
		player.set_controller(ScriptedController.new())
		player.global_position = Vector2(s[1].x * 16 + 8, s[1].y * 16 + 12)
		player.camera.reset_smoothing()
		await _wait(0.8)
		await _shot(s[2])
	# 关键人物对话（右侧立绘）+ 选项
	main.change_level(Floors.scene("floor_06_upper"))
	await _wait(1.4)
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	for r in get_tree().get_nodes_in_group("ally"):
		if r is Resident and r.npc_id == "supervisor":
			player.global_position = r.global_position + Vector2(16, 0)
			player.camera.reset_smoothing()
			r.talk(player)
	await _wait(1.2)
	await _shot("f6_40_npc_portrait")
	for i in 20:
		if Dialogue.runner.choice_menu.is_open():
			break
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.2)
	await _wait(0.3)
	await _shot("f6_41_choice_menu")
	Dialogue.runner.choice_menu.choose(0)
	await _wait(0.6)
	await _shot("f6_42_shop")
	for c in get_tree().root.get_children():
		if c is ShopUI:
			c.close()
	await _wait(0.3)
	while Dialogue.runner.is_running():
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(Dialogue.runner.choice_menu.options.size() - 1)
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.1)
	SaveSystem.save(1, "集市广场")
	var menu := SlotMenu.new()
	get_tree().root.add_child(menu)
	menu.choose("save")
	await _wait(0.3)
	await _shot("f6_50_save_menu")
	menu.cancel()
	menu.queue_free()
	main.queue_free()
	await _wait(0.3)
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(0.8)
	await _shot("f6_60_title")
	SaveSystem.delete(1)
	print("截图 %d 张" % shots)
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	shots += 1
	print("shot ", n)


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
