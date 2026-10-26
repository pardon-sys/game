extends "res://tests/f6_after_test.gd"
## 骑士篇四个支线的截图：光脚地面和小孩、羽毛堆下的彩带、和小莉莉比谁先笑、石头下探头的手印碎片、地窖的手印团、
## 训练室里的刺击 / 扫腿预警、房檐掉下来的手印、钉门的节拍条。输出到 tools/.cache/shots/knight_quests/。
const OUT := "res://tools/.cache/shots/knight_quests/"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.ON, AfterFestival.DANCE_DONE, AfterFestival.FINALE_DONE, "blue_tickle_pants"]:
		GameState.set_flag(f)
	GameState.vars["penance_hours"] = 0
	# ① 骑士救公主
	KnightStory.jump("found")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.8)
	KnightQuests.start("shoes")
	await _advance_until(func(): return _node("Quest_shoes") != null and not Cutscene.is_playing(), 20.0)
	var rs := _node("Quest_shoes") as QuestShoes
	_go(rs.spot.global_position + Vector2(-20, 6))
	await _wait(0.6)
	await shot("shoes_straw")
	GameState.vars["kq_shoes_stage"] = 1
	KnightQuests._changed()
	await _wait(0.4)
	rs = _node("Quest_shoes") as QuestShoes
	_go(rs.spot.global_position + Vector2(4, 4))
	rs.search_held = true
	await _wait(0.6)
	rs.search_held = false
	await shot("shoes_feather")
	GameState.vars["kq_shoes_stage"] = 2
	KnightQuests._changed()
	await _wait(0.4)
	rs = _node("Quest_shoes") as QuestShoes
	LilyDuelShow.quiet = true
	_go(rs.lily.global_position + Vector2(0, 10))
	await _advance_until(func(): return get_tree().root.get_children().any(func(n): return n is LilyDuelShow and n.playing and not n.busy), 6.0)
	for n in get_tree().root.get_children():
		if n is LilyDuelShow:
			n.set_process(false)
			n.lily_laugh = 0.4
			n._refresh()
			await _wait(0.3)
			await shot("shoes_duel_attack")
			n._start_turn("defend")
			n.warn_left = 0.4
			n._refresh()
			await _wait(0.3)
			await shot("shoes_duel_defend")
			n.cancel()
	KnightQuests.abandon("shoes")
	await _wait(0.5)
	# ② 手印样本
	KnightStory.jump("afternoon")
	KnightQuests.refresh()
	KnightQuests.start("samples")
	GameState.pending_spawn = "from_pharmacy"
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.8)
	var rp := _node("Quest_samples") as QuestSamples
	var sh: HandShard = rp.shards[0]
	_go(sh.home + Vector2(26, 6))
	sh.lure(GameState.player)
	await _wait(0.5)
	await shot("samples_peek")
	GameState.vars["kq_samples_stage"] = 2
	KnightQuests._changed()
	GameState.pending_spawn = "from_pharmacy"
	await main.change_level(Floors.scene(KnightStory.CELLAR))
	await _wait(0.8)
	await shot("samples_cellar")
	KnightQuests.abandon("samples")
	# ③ 队长的旧剑术
	KnightQuests.start("spear")
	await _advance_until(func(): return not Cutscene.is_playing(), 10.0)
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene(KnightStory.DRILL))
	await _wait(0.8)
	var rq := _node("Quest_spear") as QuestSpear
	rq._paused = 30.0
	GameState.player.global_position = rq.origin() + Vector2(0, 60)
	rq.attack("thrust")
	rq.warn["left"] = 0.3
	await _wait(0.2)
	await shot("spear_thrust")
	rq.attack("sweep")
	rq.warn["left"] = 0.4
	await _wait(0.2)
	await shot("spear_sweep")
	KnightQuests.abandon("spear")
	# ④ 夜里的栅栏
	KnightStory.jump("sneak")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.8)
	KnightQuests.refresh()
	KnightQuests.start("fence")
	await _wait(0.6)
	var rf := _node("Quest_fence") as QuestFence
	rf.pick()
	var e: EaveHand = rf.eaves[0]
	_go(e.global_position + Vector2(0, 10))
	await _advance_until(func(): return e.state == "warn", 2.0)
	await _wait(0.4)
	await shot("fence_eave")
	e.state = "cool"
	_go(rf.gate_at(0))
	await _advance_until(func(): return rf.hammering, 2.0)
	await _wait(1.0)
	await shot("fence_hammer")
	get_tree().quit()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)
