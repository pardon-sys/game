extends Node
## 第八层夜迷宫截图（开发用）：Godot --path . res://tests/capture_maze.tscn → tools/.cache/shots/maze_*.png
## 冰封在床上的粉色公主（睡觉过场）、2.5D 透视 + 高墙（墙前 / 墙后）、活墙、紫手 + 头顶 QTE、立绘上盖着的手；月光镜光带、新怪物、千手的影子。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done",
			"intro_done_f8_shelter_intro"]:
		GameState.set_flag(f)
	# 小房间：睡觉过场里冰块盖上床的那一刻
	await main.change_level(Floors.scene("floor_08_shelter"))
	await _wait(1.0)
	Cutscene.play("f8_shelter_sleep")
	var g := 0
	while not Cutscene.spawned.has("ice") and g < 400:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		g += 1
	await _wait(0.6)
	await _shot("bed")
	for f in ["blue_is_hero", "intro_done_f8_maze_intro"]:
		GameState.set_flag(f)
	while Cutscene.is_playing() and g < 1200:
		_finish()
		await _wait(0.05)
		g += 1
	await main.change_level(Floors.scene("floor_08_maze_1"))
	await _wait(1.0)
	_finish()
	await _wait(1.0)
	await _shot("lit")
	# 高墙：找一段上下都是地面的墙，站在墙前 / 墙后各拍一张
	var walls: TileMapLayer = main.level.get_node("Walls")
	var wc := Vector2i(-1, -1)
	for c in walls.get_used_cells():
		if GridPath.walkable(main.level, c + Vector2i(0, -1)) and GridPath.walkable(main.level, c + Vector2i(0, 1)) \
				and walls.get_cell_source_id(c + Vector2i(1, 0)) != -1 and c.y > 6:
			wc = c
			break
	var hero := GameState.player
	hero.global_position = Vector2(wc.x * 16 + 8, (wc.y + 1) * 16 + 14)
	hero.camera.reset_smoothing()
	await _wait(0.5)
	await _shot("wall_front")
	hero.global_position = Vector2(wc.x * 16 + 8, (wc.y - 1) * 16 + 12)
	hero.camera.reset_smoothing()
	await _wait(0.5)
	await _shot("wall_behind")
	# 活墙：站在一面升起的活墙旁边，心跳前发亮
	var lw: LivingWall = null
	for n in get_tree().get_nodes_in_group("living_wall"):
		if (n as LivingWall).up:
			lw = n
	if lw:
		hero.global_position = lw.global_position + Vector2(0, 30)
		hero.camera.reset_smoothing()
		MazeDirector.instance._warn_living_walls(true)
		await _wait(0.5)
		await _shot("living_wall")
		MazeDirector.instance._warn_living_walls(false)
		hero.global_position = Vector2(wc.x * 16 + 8, (wc.y + 1) * 16 + 14)
	var dir := MazeDirector.instance
	var blue := GameState.player
	blue.global_position += Vector2(40, -20)
	var h := dir.spawn_hand(blue.global_position + Vector2(30, 0))
	await _wait(0.2)
	h.global_position = blue.global_position + Vector2(14, 0)
	await _wait(0.5)
	await _shot("qte")
	if KeySequenceQTE.current:
		KeySequenceQTE.current.press(0)
	await _wait(0.6)
	for z in ["thigh", "thigh", "thigh", "butt", "butt", "sole", "armpit"]:
		dir.cover_zone(z)
	blue.laugh.set_value(blue.laugh.giggle_threshold + 5.0)
	await _wait(1.2)
	var fx: PortraitFx = Dialogue.portrait_fx
	print("DEBUG hands=", fx.cover_hands, " active=", fx.active(), " layer_vis=", fx._hand_layer.visible, " rect=", fx.portrait_rect(),
		" in_cutscene=", GameState.in_cutscene, " wide=", Dialogue.is_portrait_wide())
	await _shot("hands")
	# 第二段：月光镜转到正确方向，光带照到光开关（先把节点小剧场放完、标成看过，手不带过去）
	g = 0
	while (CG.is_busy() or Dialogue.is_active()) and g < 600:
		Dialogue.advance()
		await _wait(0.05)
		g += 1
	for id in ["first", "total_8", "total_12", "weak_first", "weak_4"]:
		GameState.set_flag("f8m_ms_" + id)
	dir.cover.clear()
	GameState.vars["f8m_hands"] = {}
	for k in ReactionDB.source_keys():
		GameState.set_flag("met_" + k)
	await main.change_level(Floors.scene("floor_08_maze_2"))
	await _wait(1.5)
	_finish()
	dir = MazeDirector.instance
	dir.cover.clear()
	dir._spawn_t = 999.0
	blue = GameState.player
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/floor_08_maze_2/design.json"))
	var dev: Dictionary = design["devices"].filter(func(d: Dictionary): return d["kind"] == "moon_mirror")[0]
	var mirror: MoonMirror = main.level.find_children("*", "MoonMirror", true, false)[0]
	mirror.facing = int(dev["facing"])
	mirror._refresh()
	blue.global_position = mirror.global_position + (mirror.beam_end - mirror.source_point()).normalized() * 40.0 + Vector2(0, 8)
	blue.camera.reset_smoothing()
	await _wait(1.2)
	await _shot("beam")
	# 新怪物：羽蛾、梦绒球、笑声收集瓶、偷灯小鬼围在她身边
	var i := 0
	for m in ["glow_moth", "dream_fluff", "laugh_jar", "lamp_imp"]:
		var mon: Node2D = load("res://levels/floor_08/scenes/%s.tscn" % m).instantiate()
		main.level.add_child(mon)
		mon.global_position = blue.global_position + Vector2(-24 + i * 16, -14 + (i % 2) * 22)
		mon.process_mode = Node.PROCESS_MODE_DISABLED
		i += 1
	await _wait(0.4)
	await _shot("monsters")
	# 第三段：千手的影子（视野锥）
	await main.change_level(Floors.scene("floor_08_maze_3"))
	await _wait(1.5)
	_finish()
	MazeDirector.instance._spawn_t = 999.0
	blue = GameState.player
	var shadow: HandShadow = main.level.find_children("*", "HandShadow", true, false)[0]
	blue.global_position = shadow.global_position + Vector2(0, 50)
	blue.camera.reset_smoothing()
	await _wait(0.6)
	await _shot("shadow")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "maze_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
