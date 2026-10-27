extends "res://tests/f6_after_test.gd"
## 骑士篇第三轮的截图：六个支线的新段落（小巷、草药洞、熬药、城墙蒙眼、裂缝、旧会堂、借东西、旧仓库、逗她笑、井边冰面、储物间、小桥）、
## Boss 的帮手和机制介绍过场。输出到 tools/.cache/shots/knight_round3/。
const OUT := "res://tools/.cache/shots/knight_round3/"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.FINALE_DONE, "blue_tickle_pants"]:
		GameState.set_flag(f)
	await _quest("shoes", 3, "found", KnightStory.ALLEY, "from_town", "alley", 2.0)
	await _quest("samples", 4, "afternoon", KnightStory.HERBCAVE, "from_cellar", "herbcave", 1.0)
	await _quest("spear", 1, "afternoon", KnightStory.WALL, "from_town", "wall", 1.0)
	var rw := _node("Quest_spear") as QuestWatch
	if rw:
		rw.start_blind()
		rw.next_cue("left")
		await _wait(0.2)
		await shot("wall_blind")
		rw._lights_on()
	await _quest("fence", 3, "sneak", KnightStory.CRACK, "from_town", "crack", 1.0)
	await _quest("fence", 4, "sneak", KnightStory.OLDHALL, "from_crack", "oldhall", 1.5)
	await _quest("host", 2, "afternoon", KnightStory.WAREHOUSE, "from_town", "warehouse", 1.0)
	var rwh := _node("Quest_host") as QuestWarehouse
	if rwh:
		rwh.set_music(false)
		await _wait(0.8)
		await shot("warehouse_music_stopped")
	await _quest("blue", 2, "sneak", KnightStory.KNIGHT_N, "from_house", "well", 1.0)
	await _quest("blue", 3, "sneak", KnightStory.STORAGE, "from_town", "storage", 1.5)
	await _quest("blue", 4, "sneak", KnightStory.BRIDGE, "from_town", "bridge", 1.5)
	# 小游戏画面
	await _show_shot(PartyShow, "duster", "party_duster")
	await _show_shot(BlueTickleShow, "tickle", "blue_tickle")
	await _show_shot(BrewShow, "", "brew")
	await _boss()
	get_tree().quit()


func _quest(q: String, stage: int, step: String, fid: String, spawn: String, label: String, wait := 1.0) -> void:
	for id in KnightQuests.ids():
		GameState.set_flag("kq_%s_active" % id, false)
	KnightStory.jump(step)
	GameState.set_flag("kq_%s_active" % q)
	GameState.set_flag("kq_active")
	GameState.vars["kq_%s_stage" % q] = stage
	KnightQuests.refresh()
	GameState.pending_spawn = spawn
	await main.change_level(Floors.scene(fid))
	await _advance_until(func(): return not Cutscene.is_playing() and not GameState.in_dialogue, 20.0)
	await _wait(wait)
	if Dialogue.is_active():
		Dialogue._end()
	await shot(label)


func _show_shot(cls: Variant, mode: String, label: String) -> void:
	var show: Node = cls.new()
	if mode != "":
		show.set("mode", mode)
	cls.quiet = true
	get_tree().root.add_child(show)
	show.play()
	await _wait(1.2)
	await shot(label)
	show.queue_free()
	cls.quiet = false
	GameState.dialogue_holds = 0
	GameState.in_dialogue = false
	await _wait(0.3)


func _boss() -> void:
	for id in KnightQuests.ids():
		GameState.set_flag("kq_%s_active" % id, false)
		GameState.set_flag("kq_%s_done" % id)
	GameState.set_flag("kq_active", false)
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 0
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	KnightCurse.auto = false
	KnightStory.jump("boss")
	GameState.pending_spawn = "from_prison"
	await main.change_level(Floors.scene(KnightStory.KCHASE))
	await _advance_until(func(): return _node("Task_boss") != null and bool(_node("Task_boss").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 40.0)
	var b := _node("Task_boss") as TaskKnightBoss
	if b == null:
		return
	b.attack_t = 999.0
	await _wait(1.5)
	await shot("boss_helpers")
	GameState.set_flag("knight_intro_seen_hunt", false)
	b.curse.start_hunt(b.victims.filter(func(x): return x.kind != "fallen")[0])
	await _wait(0.8)
	await shot("boss_intro_cut")
	KnightCurse.auto = true


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)
