extends Node
## 第八层截图（开发用）：Godot --path . res://tests/capture_floor8.tscn → tools/.cache/shots/f8_*.png
## 开场（粉色公主被吊着挠）、阶段一、阶段二（压力板 / 锁链拽下来 / 石墙）、阶段三（献祭小窗）、追逐战。4 分钟没跑完就退出。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	ComboTracker.play_scenes = false
	ChaseRun.countdown = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["blue_is_hero", "f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked"]:
		GameState.set_flag(f)
	for k in ReactionDB.source_keys():
		GameState.set_flag("met_" + k)
	await main.change_level(Floors.scene("floor_08"))
	# 开场：等到粉色公主被吊着的那一幕
	var t := 0.0
	while t < 20.0 and not (Cutscene.is_playing() and Dialogue.is_active() and Dialogue.text_label.text.contains("放、放我")):
		if Dialogue.is_active() and not Dialogue.text_label.text.contains("放、放我"):
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.6)
	await _shot("intro")
	while not (Floor8Director.instance and Floor8Director.instance.phase == 1 and not Cutscene.is_playing()):
		_finish()
		await get_tree().process_frame
	var dir := Floor8Director.instance
	for m in Duo.members:
		m.set_invulnerable(9999.0, true)
	await _wait(5.0)
	await _shot("phase1")
	dir.boss.fighting = true
	dir.boss.health.set_hp(int(ceil(dir.boss.health.max_hp * 0.7)) + 1)
	dir.boss._attack_invuln = 0.0
	dir.boss.apply_hit(HitData.make_attack(dir.blue, 5, 0.0))
	while not (dir.phase == 2 and not dir.busy and not Cutscene.is_playing()):
		_finish()
		await get_tree().process_frame
	for m in Duo.members:
		m.set_invulnerable(9999.0, true)
	await _wait(1.0)
	await _shot("phase2_plates")
	dir.shift_terrain()
	await _wait(0.8)
	await _shot("phase2_walls")
	dir.shifter.clear()
	dir.blue.global_position = dir.plates[0].global_position + Vector2(0, 4)
	dir.pink.global_position = dir.plates[1].global_position + Vector2(0, 4)
	await _wait(1.6)
	await _shot("phase2_pulled")
	dir.boss._pulled_left = 0.0
	dir.boss.health.set_hp(int(ceil(dir.boss.health.max_hp * 0.35)) + 1)
	dir.boss._attack_invuln = 0.0
	dir.boss.apply_hit(HitData.make_attack(dir.blue, 5, 0.0))
	while not (dir.phase == 3 and not dir.busy and not Cutscene.is_playing()):
		_finish()
		await get_tree().process_frame
	for m in Duo.members:
		m.set_invulnerable(9999.0, true)
	dir._circle_cd = 0.0
	await _wait(0.5)
	await _shot("phase3_circle")
	dir.blue.global_position = dir.circle.global_position
	await _wait(1.5)
	await _shot("phase3_sacrifice")
	dir.end_sacrifice(true)
	dir.boss.health.set_hp(2)
	dir.boss._attack_invuln = 0.0
	dir.boss.fighting = true
	dir.boss.apply_hit(HitData.make_attack(dir.blue, 5, 0.0))
	t = 0.0
	var shot_rage := false
	while t < 60.0 and not (get_tree().get_first_node_in_group("chase_run") and (get_tree().get_first_node_in_group("chase_run") as ChaseRun).running):
		if not shot_rage and Cutscene.is_playing() and Dialogue.is_active() and Dialogue.text_label.text.contains("走开"):
			shot_rage = true
			await _wait(0.4)
			await _shot("victory_rage")
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(2.5)
	await _shot("chase")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "f8_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
