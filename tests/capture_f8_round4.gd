extends Node
## 第八层第四轮截图（开发用）：Godot --path . res://tests/capture_f8_round4.tscn → tools/.cache/shots/f8r4_*.png
## 追逐战（两人朝下跑、巨石在人后面）、按 C 切换后、阶段三战败小剧场（大图 + 另一个公主的失控立绘）、测试页训练度面板。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	ComboTracker.play_scenes = false
	ChaseRun.countdown = false
	ChaseRun.seed_value = 3
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["blue_is_hero", "f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_boss_down"]:
		GameState.set_flag(f)
	await main.change_level(Floors.scene("floor_08_chase"))
	var t := 0.0
	while t < 20.0 and not (get_tree().get_first_node_in_group("chase_run") and (get_tree().get_first_node_in_group("chase_run") as ChaseRun).running):
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	var run := get_tree().get_first_node_in_group("chase_run") as ChaseRun
	for c in [run.a, run.b]:
		c.set_invulnerable(9999.0, true)
	run._inv = {"a": 999.0, "b": 999.0}   # 截图时不碰障碍
	_finish()
	await _wait(2.0)
	_finish()
	await _shot("chase")
	run.pa = 8.8
	run.pb = 8.8
	run.boulder = 7.9
	run._boulder_t = 0.0
	await _wait(1.5)
	_finish()
	await _shot("chase_late")
	run.pa = 5.0
	run.pb = 5.0
	run.boulder = 2.0
	run._boulder_t = 0.0
	run.switch_lane()
	await _wait(1.0)
	_finish()
	await _shot("chase_switched")
	run.running = false
	# 战败小剧场：阶段三双人（第二幕：大图 + 粉色公主失控立绘）
	CG.play_theater("f8_defeat_3_1")
	t = 0.0
	while t < 30.0 and not (Dialogue.is_active() and Dialogue.text_label.text.contains("你、你还有空分析")):
		if Dialogue.is_active() and not Dialogue.text_label.text.contains("你、你还有空分析"):
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(1.0)
	await _shot("defeat_duo")
	while t < 60.0 and not (Dialogue.is_active() and Dialogue.text_label.text.contains("永、永远不行")):
		if Dialogue.is_active() and not Dialogue.text_label.text.contains("永、永远不行"):
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.6)
	await _shot("defeat_act4")
	CG.skip()
	t = 0.0
	while CG.is_busy() and t < 60.0:
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)
	# 测试页：训练度
	DevConfig.override = true
	var pm := main.get_node("PauseMenu")
	pm.toggle()
	await _wait(0.3)
	(pm.get_node("Root/Box/DevTraining") as Button).pressed.emit()
	await _wait(0.2)
	pm._train_step("train_fatigue_up", 1, 2)
	await _wait(0.3)
	await _shot("training_panel")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "f8r4_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
