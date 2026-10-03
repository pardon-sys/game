extends Node
## 保卫队训练营截图（开发用）：Godot --path . res://tests/capture_training.tscn → tools/.cache/shots/training_*.png
## 营地训练场的过场、训练菜单、训练一 / 三 / 四的小游戏画面、惩罚小剧场。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	GameState.set_flag("f6_opening_done")
	await main.change_level(Floors.scene("floor_06_camp"))
	await _wait(1.0)
	_finish()
	var p := GameState.player
	p.global_position = Cutscene.cell_to_world([32, 20])
	GameState.give_item(ItemDB.get_item("coin"), 50)
	await _wait(0.5)
	# 菜单
	var menu := TrainingMenu.new()
	get_tree().root.add_child(menu)
	menu.choose()
	await _wait(0.3)
	await _shot("menu")
	menu.pick(2)
	await _wait(0.2)
	await _shot("menu_zone")
	menu.cancel()
	menu.cancel()
	menu.queue_free()
	await _wait(0.3)
	# 训练一
	var go := func(): await TrainingDB.run("fatigue_endure")
	go.call()
	await _wait(1.2)
	await _shot("endure_walk")
	await _until_playing()
	var r: TrainingStage = TrainingDB.current
	await _wait(0.6)
	r.time_scale = 0.0
	r._call("ls")
	r._call("rt")
	r._call("lt")
	r._call("rs")
	await _wait(0.5)
	await _shot("endure_queue")
	r.press("A")
	r.press("A")
	await _wait(0.15)
	await _shot("endure_fail")
	r.time_scale = 1.0
	await _wait(2.5)
	await _shot("endure_play")
	r.add_fatigue(9999)
	await _wait(1.0)
	await _until(func(): return CG.is_playing())
	await _wait(1.0)
	for i in 3:
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.6)
	await _shot("endure_punish")
	await _until(func(): return not r.busy, true)
	await _quit_round()
	await _shot("endure_outro")
	await _until(func(): return TrainingDB.current == null, true)
	await _wait(0.5)
	# 训练三
	go = func(): await TrainingDB.run("zone_resist", "thigh")
	go.call()
	await _until_playing()
	r = TrainingDB.current
	r.time_scale = 0.0
	r._set_phase("windup", 5.0)
	r.fake = false
	r._set_phase("sweep", 1.0)
	r.pointer = r.green_c - 0.05
	r._needle.position.x = roundf(r.pointer * (r.BAR_W - 2))
	await _wait(0.5)
	await _shot("resist_sweep")
	r.time_scale = 1.0
	r._set_phase("windup", 5.0)
	r.fake = true
	r._set_phase("sweep", 3.0)
	await _wait(0.6)
	await _shot("resist_fake")
	await _quit_round()
	await _until(func(): return TrainingDB.current == null, true)
	await _wait(0.5)
	# 训练四
	go = func(): await TrainingDB.run("zone_sensitize", "sole")
	go.call()
	await _until_playing()
	r = TrainingDB.current
	await _wait(1.0)
	r.time_scale = 0.0
	r.rest_t = 0.0
	r.pending.clear()
	r.pending.append({"dir": "LEFT", "at": 0.0})
	r.pending.append({"dir": "UP", "at": 0.0})
	r._seg_total = 2
	r._seg_done = 0
	r.seg_t = 0.0
	r._tick(0.01)
	r._update_dots()
	await _wait(0.2)
	await _shot("sensitize_impulse")
	await _quit_round()
	await _until(func(): return TrainingDB.current == null, true)
	await _wait(0.3)
	# 训练二：迷宫
	GameState.player.global_position = Cutscene.cell_to_world([40, 21])
	go = func(): await TrainingDB.run("fatigue_release")
	go.call()
	await _wait(1.5)
	await _shot("maze_walk")
	await _until_playing()
	var m = TrainingDB.current
	await _wait(1.0)
	await _shot("maze_start")
	m.start_escape()
	await _wait(0.8)
	for i in 3:
		m.mash()
	await _wait(0.2)
	await _shot("maze_escape")
	m.stop_escape()
	GameState.player.combo.triggered.emit("swing_frenzy")
	GameState.player.magic_event.emit("fatigue_burst", 0)
	await _until(func(): return CG.is_playing())
	await _wait(0.8)
	for i in 4:
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.7)
	await _shot("maze_devotion")
	await _until(func(): return not CG.is_busy(), true)
	m.quit("esc")
	await _until(func(): return TrainingDB.current == null, true)
	await _wait(0.5)
	await _shot("maze_back")
	get_tree().quit()


func _quit_round() -> void:
	var r: TrainingStage = TrainingDB.current
	if r:
		r.time_scale = 1.0
		r.quit()
	await _wait(0.6)


func _until_playing() -> void:
	await _until(func(): return TrainingDB.current != null and TrainingDB.current.playing, true)


func _until(cond: Callable, advance := false) -> void:
	var g := 0
	while not cond.call() and g < 600:
		if advance and Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		g += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "training_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
