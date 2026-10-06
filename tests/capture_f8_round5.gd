extends Node
## 第八层第五轮截图（开发用）：Godot --path . res://tests/capture_f8_round5.tscn → tools/.cache/shots/f8r5_*.png
## 地形陷阱、阶段三召唤的手臂、蓝色公主操控时的战败大图、叠在一起的剧场 + 爆发、长文字反应框、追逐战离太远的提示。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	ComboTracker.play_scenes = false
	ChaseRun.countdown = false
	TutorialBoard.enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["blue_is_hero", "f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic"]:
		GameState.set_flag(f)
	for k in ReactionDB.source_keys():
		GameState.set_flag("met_" + k)
	await main.change_level(Floors.scene("floor_08"))
	while not (Floor8Director.instance and Floor8Director.instance.phase == 1 and not Cutscene.is_playing()):
		_finish()
		await get_tree().process_frame
	var dir := Floor8Director.instance
	var b := dir.boss
	for m in Duo.members:
		m.set_invulnerable(9999.0, true)
	b.fighting = false
	b.cancel_attacks()
	await _wait(0.5)
	_finish()
	# 地形陷阱：在两人附近摆一圈
	var pc := dir._cell_of(dir.blue.global_position)
	var kinds := ["bounce_pad", "soap_floor", "feather_fan", "chute", "snare", "legloop", "binding", "cuffs", "stocks", "vine"]
	var offs := [Vector2i(-6, -3), Vector2i(-3, -3), Vector2i(0, -4), Vector2i(3, -3), Vector2i(6, -3),
		Vector2i(-6, 2), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(6, 2), Vector2i(0, 4)]
	for i in kinds.size():
		dir.place_trap(kinds[i], pc + offs[i], 0.0, {})
	await _wait(0.8)
	await _shot("terrain")
	dir.shifter.clear()
	# 阶段三召唤：手臂伸下来
	b.phase = 3
	dir.blue.global_position = dir._cell_pos(dir.arena_cells.position + dir.arena_cells.size / 2) + Vector2(0, 40)
	await _wait(0.6)
	b.fighting = true
	b.summon()
	await _wait(0.4)
	await _shot("summon_arm")
	await _wait(0.8)
	await _shot("summon_done")
	b.clear_summons()
	b.fighting = false
	b.phase = 1
	# 长文字反应框
	Dialogue.show_reaction("哈哈哈哈……不、不行……大腿……那里……真的不行……为什么偏偏是那里……哈哈哈哈……忍、忍不住……明明一直忍着的……刷子和羽毛一起……我、我投降……哈哈哈哈哈……！", 4.0)
	await _wait(0.2)
	await _shot("reaction_top")
	await _wait(2.4)
	await _shot("reaction_scrolled")
	# 蓝色公主操控：阶段三双人战败（大图）
	if GameState.player != dir.blue:
		GameState.switch_control(dir.blue)
	await _play_until("f8_defeat_3_1", "你、你还有空分析", "blue_cg")
	await _play_until("f8_defeat_3_4", "我们现在……像不像", "stack")
	await _play_until("f8_defeat_3_4", "这样……的……你……最……好", "stack_burst")
	# 追逐：离太远的提示
	GameState.set_flag("f8_boss_down")
	await main.change_level(Floors.scene("floor_08_chase"))
	var t := 0.0
	while t < 20.0 and not (get_tree().get_first_node_in_group("chase_run") and (get_tree().get_first_node_in_group("chase_run") as ChaseRun).running):
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	var run := get_tree().get_first_node_in_group("chase_run") as ChaseRun
	run._inv = {"a": 999.0, "b": 999.0}
	_finish()
	run.pa = 6.0
	run.pb = 3.3
	run._boulder_t = 0.0
	await _wait(0.6)
	_finish()
	await _wait(0.2)
	await _shot("chase_warning")
	get_tree().quit()


## 播 id 小剧场，等到台词里出现 marker 时截图，然后跳过剩下的。
func _play_until(id: String, marker: String, shot: String) -> void:
	CG.play_theater(id)
	var t := 0.0
	while t < 60.0 and not (Dialogue.is_active() and Dialogue.text_label.text.contains(marker)):
		if Dialogue.is_active() and not Dialogue.text_label.text.contains(marker):
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(1.0)
	await _shot(shot)
	CG.skip()
	t = 0.0
	while CG.is_busy() and t < 60.0:
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "f8r5_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
