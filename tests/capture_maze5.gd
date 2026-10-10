extends Node
## 第八层夜迷宫第五轮截图（开发用）：Godot --path . res://tests/capture_maze5.tscn → tools/.cache/shots/m5_*.png
## 睡着闭眼、QTE、身上的小手、大量手提示、憋笑 / 憋爆、看不清、墙缝刷轮、垂落吊手、出口微光、遮眼蝠、夜啼追手、飘着的大手、
## 千手过场（加手 / 爆发 / 大笑）、回小屋（小怪挠脚 / 解冻 / 笑醒）、新的第七层。

const OUT := "res://tools/.cache/shots/"

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done",
			"intro_done_f8_shelter_intro", "f8m_dark_first", "f8m_tutorial", "f8m_hint_hold", "f8m_hint_qte"]:
		GameState.set_flag(f)
	for id in ["first", "total_8", "total_12", "weak_first", "weak_4"]:
		GameState.set_flag("f8m_ms_" + id)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _sleep_shots()
	GameState.set_flag("blue_is_hero")
	GameState.set_flag("intro_done_f8_maze_intro")
	await _maze1_shots()
	await _maze2_shots()
	await _finale_shots()
	await _return_shots()
	get_tree().quit(0)


# ------------------------------------------------------------------ 睡着闭眼
func _sleep_shots() -> void:
	await main.change_level(Floors.scene("floor_08_shelter"))
	await _wait(1.0)
	Cutscene.play("f8_shelter_sleep")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("饼干"))
	await _wait(0.6)
	await _shot("sleep_talk")
	while Cutscene.is_playing():
		_finish()
		await _wait(0.05)


# ------------------------------------------------------------------ 第一段
func _maze1_shots() -> void:
	await _goto(1)
	var dir := MazeDirector.instance
	var blue := dir.blue
	var spot := _open_spot()
	_place(blue, spot)
	await _wait(0.6)
	var q := KeySequenceQTE.start(blue, 4, 2.4)
	await _wait(0.35)
	await _shot("qte")
	await _wait(1.2)
	await _shot("qte_urgent")
	q.press(KEY_A)
	await _wait(0.6)
	for z in ["thigh", "thigh", "butt", "butt", "waist", "armpit"]:
		dir.cover_zone(z)
		await _wait(0.12)
	await _wait(0.1)
	await _shot("body_hands_pop")
	await _wait(0.6)
	_zoom(2.2)
	await _shot("body_hands")
	_zoom(1.0)
	dir.cover.clear()
	dir.summon_near(4)
	await _wait(0.5)
	await _shot("alarm")
	for h in dir.hands():
		h.queue_free()
	await _wait(2.0)
	blue.laugh.set_value(blue.laugh.giggle_threshold + 4.0)
	var hl := HoldLaugh.of(blue)
	hl.force_hold = true
	await _wait(1.6)
	await _shot("hold")
	hl.breath = 0.02
	await _wait(0.5)
	await _shot("hold_burst")
	hl.force_hold = false
	await _wait(1.5)
	_finish()
	blue.laugh.set_value(0.0)
	dir.carry_light().level = 0.2
	await _wait(0.8)
	await _shot("dark")
	dir.carry_light().level = 1.0
	await _wait(0.6)
	# 墙缝刷轮：伸出来夹住她
	var wb: WallBrush = main.level.find_children("*", "WallBrush", true, false)[0]
	wb.active = true
	_place(blue, wb._hold_point())
	wb._rhythm_t = 0.0
	await _wait(0.5)
	await _shot("wall_brush")
	_free_her(blue)
	# 垂落吊手：预警的影子 / 吊起来
	var hh: HangingHands = main.level.find_children("*", "HangingHands", true, false)[0]
	hh.active = true
	_place(blue, hh.global_position)
	await _wait(0.3)
	await _shot("hanging_warn")
	await _wait(0.8)
	await _shot("hanging")
	_free_her(blue)
	hh.active = false
	# 出口的微光（第一段的出口）
	var glow: Node2D = get_tree().get_nodes_in_group("exit_glow")[0]
	_place(blue, _floor_near(glow.global_position + Vector2(48, 0)))
	await _wait(0.8)
	await _shot("exit_glow")


# ------------------------------------------------------------------ 第二段
func _maze2_shots() -> void:
	await _goto(2)
	var dir := MazeDirector.instance
	var blue := dir.blue
	# 遮眼蝠：倒挂 / 蒙眼
	var bat: BlindBat = get_tree().get_nodes_in_group("blind_bat")[0]
	bat.process_mode = Node.PROCESS_MODE_INHERIT
	_place(blue, _floor_near(bat.global_position + Vector2(24, 0)))
	await _wait(0.6)
	await _shot("bat_perched")
	dir.carry_light().level = 0.2
	var t := 0.0
	while t < 4.0 and not bat.is_stuck():
		blue.global_position = bat.global_position + Vector2(6, 0)
		await _wait(0.05)
		t += 0.05
	await _wait(0.4)
	await _shot("bat_blind")
	bat.let_go()
	bat.process_mode = Node.PROCESS_MODE_DISABLED
	dir.carry_light().level = 1.0
	await _wait(1.0)
	# 夜啼追手：追过来
	var ns: NightStalker = get_tree().get_nodes_in_group("night_stalker")[0]
	ns.process_mode = Node.PROCESS_MODE_INHERIT
	var spot := _open_spot()
	_place(blue, spot)
	ns.global_position = _floor_near(spot + Vector2(40, 0))
	blue.laugh.set_value(blue.laugh.helpless_threshold + 5.0)
	await _wait(0.6)
	_finish()
	await _shot("stalker")
	blue.laugh.set_value(0.0)
	ns.retreat(999.0)
	await _wait(0.8)
	# 飘着的大手：隔着墙探照
	var hs: HandShadow = main.level.find_children("*", "HandShadow", true, false)[0]
	hs.process_mode = Node.PROCESS_MODE_DISABLED
	_place(blue, _floor_near(hs.global_position + Vector2(0, 40)))
	await _wait(0.8)
	await _shot("shadow_float")


# ------------------------------------------------------------------ 千手过场
func _finale_shots() -> void:
	GameState.set_flag("f8m_ms_total_8")
	await _goto(3)
	var dir := MazeDirector.instance
	_place(dir.blue, dir._exit_at + Vector2(0, 20))
	await _wait(0.5)
	dir.blue.global_position = dir._exit_at
	await _cut_until(func(st: Dictionary): return str(st.get("speaker", "")) == "千手痒痒魔" and str(st.get("text", "")).contains("你……来"))
	await _wait(0.8)
	await _shot("finale_boss")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("……那、那里……不行"))
	await _wait(0.5)
	await _shot("finale_hands")
	await _cut_until(func(st: Dictionary): return st.get("actions", []).any(func(a): return a.get("do") == "burst"))
	await _wait(0.5)
	await _shot("finale_burst")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("……呀！"))
	await _wait(0.4)
	await _shot("finale_cute")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("好痒啦"))
	await _wait(0.6)
	await _shot("finale_laugh")


# ------------------------------------------------------------------ 回小屋 / 第七层
func _return_shots() -> void:
	await _cut_until(func(st: Dictionary): return Cutscene.current.begins_with("f8_shelter_return") and str(st.get("text", "")).contains("几只小怪"), 240.0)
	await _wait(1.2)
	await _shot("return_monsters")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("紫色"))
	await _wait(0.5)
	await _shot("return_pants")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("咔嚓"))
	await _wait(0.3)
	await _shot("return_thaw")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("为、为什么脚心"))
	await _wait(0.6)
	await _shot("return_wake")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("是做梦"))
	await _wait(0.6)
	await _shot("return_sweat")
	while Cutscene.is_playing():
		_finish()
		await _wait(0.05)
	await _wait(1.0)
	await _shot("return_after")
	await main.change_level(Floors.scene("floor_07_return"))
	await _wait(1.5)
	_finish()
	await _wait(2.0)
	_finish()
	await _wait(1.0)
	await _shot("floor7_return")


# ------------------------------------------------------------------ 工具
func _goto(sec: int) -> void:
	await main.change_level(Floors.scene("floor_08_maze_%d" % sec))
	await _wait(1.0)
	_finish()
	await _wait(0.5)
	var dir := MazeDirector.instance
	dir._spawn_t = 999.0
	for h in get_tree().get_nodes_in_group("maze_hand"):
		h.queue_free()
	for g in ["enemy", "night_stalker", "blind_bat"]:
		for e in get_tree().get_nodes_in_group(g):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	for t in get_tree().get_nodes_in_group("restraint"):
		(t as Trap).active = false


## 一直推进过场，直到当前这一步满足 pred（或者超时）。
func _cut_until(pred: Callable, max_time := 120.0) -> void:
	var t := 0.0
	while t < max_time:
		if Cutscene.is_playing() and Cutscene.step_index >= 0 and Cutscene.step_index < Cutscene._steps.size() \
				and pred.call(Cutscene._steps[Cutscene.step_index]):
			return
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.03)
		t += 0.03
	push_warning("截图：等不到那一步")


func _open_spot() -> Vector2:
	var dir := MazeDirector.instance
	for c in dir._floor_cells:
		var p := GridPath.center(c)
		if dir.light_at(p) is Vector2:
			continue
		if GridPath.walkable(main.level, c + Vector2i(1, 0)) and GridPath.walkable(main.level, c - Vector2i(1, 0)) and c.y > 6:
			return p
	return dir.blue.global_position


func _free_her(blue: PlayableCharacter) -> void:
	var n := 0
	while blue.status.is_grabbed() and n < 40:
		blue.status.struggle()
		n += 1
	_place(blue, _open_spot())


func _zoom(z: float) -> void:
	var cam := GameState.player.camera as Camera2D
	if cam:
		cam.zoom = Vector2(z, z)


func _place(hero: Node2D, at: Vector2) -> void:
	hero.global_position = at
	if hero.get("camera"):
		hero.camera.reset_smoothing()
	if IsoView.current:
		IsoView.current.snap_camera()


func _floor_near(pos: Vector2) -> Vector2:
	var c0 := GridPath.cell(pos)
	for r in 6:
		for off in [Vector2i(0, r), Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, -r), Vector2i(r, r), Vector2i(-r, r)]:
			if GridPath.walkable(main.level, c0 + off):
				return GridPath.center(c0 + off)
	return pos


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "m5_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
