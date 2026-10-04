extends Node
## 第六层后续剧情截图（开发用）：Godot --path . res://tests/capture_story.tscn → tools/.cache/shots/story_*.png
## 蓝色小屋外观、夜里的小屋（主角的房间）、潜入模式的矿道（巡逻士兵和视野、脚步声的波纹）、
## 第七层（蓝色公主说话、各层的房间、冰晶结界）。整段 4 分钟没跑完就退出。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().always_on_top = true
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	ComboTracker.play_scenes = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f6_opening_done", "intro_done_f6_wake", "f6_house_open"]:
		GameState.set_flag(f)
	for k in ReactionDB.source_keys():
		GameState.set_flag("met_" + k)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_upper"))
	await _wait(1.2)
	_finish()
	await _shot("house_outside")
	GameState.set_flag("night")
	GameState.pending_spawn = "from_upper"
	await main.change_level(Floors.scene("floor_06_house"))
	await _wait(2.0)
	_finish()
	await _shot("house_night")
	GameState.set_flag("night", false)
	await _wait(1.6)
	await _shot("house_day")
	GameState.set_flag("f6_escape")
	GameState.pending_spawn = "from_camp"
	await main.change_level(Floors.scene("floor_06_mine"))
	await _wait(1.5)
	_finish()
	await _shot("mine_stealth")
	GameState.player.global_position = Vector2(22 * 16 + 8, 20 * 16 + 12)
	await _wait(1.0)
	await _shot("mine_stealth_mid")
	StealthDirector.current.noise(GameState.player.global_position, StealthDirector.STEP_RADIUS, true)
	await _wait(0.15)
	await _shot("mine_footstep")
	# 第七层：蓝色公主在塔底（跳过粉色公主的开场）
	for f in ["intro_done_f7_pink_run", "f7_pink_ran", "blue_is_hero", "f7_argue_done"]:
		GameState.set_flag(f)
	GameState.pending_spawn = "blue_start"
	await main.change_level(Floors.scene("floor_07"))
	await _wait(1.5)
	_finish()
	await _shot("f7_blue_start")
	Dialogue.start_lines([{"speaker": "蓝色的公主", "text": "……哈、哈哈……憋、憋不住……", "emotion": "helpless_1"}])
	await _wait(0.8)
	await _shot("f7_blue_talk")
	_finish()
	# 拍各层的房间时陷阱不动（对话中陷阱不生效），免得被组合抓住挡住后面的截图
	var lv: Node = GameState.player.get_parent()
	while lv and not lv.has_node("Walls"):
		lv = lv.get_parent()
	var paused: Array[Node] = []
	for n in get_tree().get_nodes_in_group("trap") + get_tree().get_nodes_in_group("actor"):
		if n != GameState.player and lv.is_ancestor_of(n):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			paused.append(n)
	if GameState.player.status and GameState.player.status.is_grabbed():
		GameState.player.status.release(true)
	for k in [1, 2, 3, 4, 5, 6]:
		GameState.in_dialogue = true
		GameState.player.global_position = Vector2((30 if k % 2 else 18) * 16 + 8, (84 - 13 * k + 7) * 16)
		await _wait(1.0)
		await _shot("f7_storey%d" % k)
	GameState.in_dialogue = false
	for n in paused:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.player.global_position = Vector2(20 * 16 + 8, (84 + 4) * 16)
	await _wait(0.8)
	var p: PlayableCharacter = GameState.player
	for i in 2:
		var m: Node2D = load("res://scenes/actors/monsters/slime.tscn").instantiate()
		p.get_parent().add_child(m)
		m.global_position = p.global_position + Vector2(-40 + 80 * i, 10)
	await _wait(0.3)
	IceBarrier.cast(p, 3)
	await _wait(0.2)
	await _shot("f7_ice_barrier")
	await _wait(0.6)
	await _shot("f7_ice_after")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "story_" + name + ".png"))
	print("shot ", name)


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
