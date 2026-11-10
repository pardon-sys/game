extends "res://tests/f6_after_test.gd"
## 这一批改动的截图：背包键位页、右下角目标文字、训练室队长出招 + 特效、追逃扔陷阱 / 信标指路、Boss 的诅咒爆发 / 盯上镇民、庆功宴领舞。
## 输出到 tools/.cache/shots/knight_fixes/。
const OUT := "res://tools/.cache/shots/knight_fixes/"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.FINALE_DONE, "blue_tickle_pants", "kq_shoes_done", "kq_spear_done", "kq_fence_done"]:
		GameState.set_flag(f)
	await _knight_day()
	await _drill()
	await _chase()
	await _boss()
	await _festival()
	get_tree().quit()


## 白天的小镇：右下角目标、背包键位页
func _knight_day() -> void:
	KnightStory.jump("afternoon")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene(KnightStory.KDAY))
	await _advance_until(func(): return not Cutscene.is_playing() and not GameState.in_dialogue, 10.0)
	await _wait(1.0)
	await shot("town_objective")
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_KEYS)
	await _wait(0.3)
	await shot("backpack_keys")
	bp.status_page.scroll_by(1)
	bp.status_page.scroll_by(1)
	await _wait(0.3)
	await shot("backpack_keys_scrolled")
	bp.close()


## 训练室：再练一次，队长出招的动作 + 刺击 / 扫腿特效
func _drill() -> void:
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene(KnightStory.DRILL))
	await _wait(0.6)
	QuestSpear.start_replay()
	await _advance_until(func(): return _node("Replay_spear") != null, 3.0)
	var rq := _node("Replay_spear") as QuestSpear
	await _advance_until(func(): return rq._paused < 900.0, 5.0)
	rq._paused = 999.0
	var pink := rq.pink
	pink.global_position = rq.origin() + Vector2(0, 56)
	rq.attack("thrust")
	await _wait(0.3)
	await shot("drill_windup")
	rq.resolve()
	await _wait(0.12)
	await shot("drill_thrust")
	await _wait(0.6)
	pink.global_position = rq.origin() + Vector2(40, 40)
	rq.attack("sweep")
	rq.resolve()
	await _wait(0.15)
	await shot("drill_sweep")
	rq.queue_free()


## 追逃：扔陷阱、落地、信标点亮、指路
func _chase() -> void:
	GameState.vars[TaskArmorChase.LIT_KEY] = 0
	GameState.vars[TaskArmorChase.CAUGHT_KEY] = 0
	KnightStory.jump("chase")
	GameState.pending_spawn = "from_prison"
	await main.change_level(Floors.scene(KnightStory.KCHASE))
	await _advance_until(func(): return _node("Task_chase") != null and bool(_node("Task_chase").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 40.0)
	var ch := _node("Task_chase") as TaskArmorChase
	if ch == null:
		return
	ch.armor.paused = true
	ch.throw_left = 999.0
	ch.armor.global_position = ch.pink.global_position + Vector2(90, 0)
	ch.throw_trap("cage", ch.pink.global_position + Vector2(-40, 0))
	await _wait(0.45)
	await shot("chase_throw")
	await _wait(0.7)
	ch.land("tickle_vine", ch.pink.global_position + Vector2(-40, 24))
	await _wait(0.3)
	await shot("chase_trap_landed")
	ch.light(0)
	await _wait(0.4)
	await shot("chase_beacon_lit")
	ch.pink.global_position = Cells.to_world(TaskArmorChase.BEACONS[0])
	await _wait(0.5)
	await shot("chase_guide_next")


## Boss：三种诅咒爆发、盯上镇民、吸笑
func _boss() -> void:
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
	b.ai_enabled = false
	b.attack_t = 999.0
	var cu := b.curse
	var pink := b.pink
	pink.global_position = b._body.global_position + Vector2(0, 50)
	cu.start()
	await _wait(1.2)
	await shot("boss_surge_hands")
	for v in cu.surge_victims.duplicate():
		b.rescue(v)
	await _wait(0.6)
	await shot("boss_surge_broken")
	cu.start_hunt(b.victims.filter(func(x): return x.kind != "fallen")[0])
	await _wait(1.5)
	await shot("boss_hunt")
	cu._end_hunt()
	b._clear_field()
	for part in b.parts.duplicate():
		part.freeze_left = 4.0
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await _advance_until(func(): return b.phase == 1 and not b.transitioning, 10.0)
	b.attack_t = 999.0
	cu.start()
	pink.global_position = b._body.global_position + Vector2(0, 70)
	await _wait(1.0)
	await shot("boss_surge_veins")
	cu.end(true)
	b.stuck_left = 4.0
	for part in b.parts.duplicate():
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await _advance_until(func(): return b.phase == 2 and not b.transitioning, 10.0)
	b.attack_t = 999.0
	cu.start()
	await _wait(1.0)
	await shot("boss_surge_heart")
	cu.end(true)
	for part in b.parts.duplicate():
		part.freeze_left = 4.0
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await _advance_until(func(): return b.phase == 3 and not b.transitioning, 10.0)
	b.attack_t = 999.0
	b._light(b.lanterns[0], 1.0)
	cu.start()
	pink.global_position = b.lanterns[0].global_position
	b.blue.global_position = b._body.global_position + Vector2(-40, 40)
	await _wait(1.0)
	await shot("boss_drain")
	cu.end(true)
	KnightCurse.auto = true


## 庆功宴领舞：台上的人跟着跳
func _festival() -> void:
	for f in ["after_done_d7_morning", "after_done_d7_afternoon", "errand_dance_done"]:
		GameState.set_flag(f)
	for f in [KnightStory.STARTED, AfterFestival.ON, AfterFestival.DANCE_DONE, AfterFestival.FINALE_DONE, "after_ev_d7_festival", "after_done_d7_night"]:
		GameState.set_flag(f, false)
	DayClock.set_time(7, DayClock.NIGHT)
	GameState.vars["penance_hours"] = 0
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene(AfterStory.TOWN))
	await _wait(0.8)
	_go(Cells.to_world(AfterStory.TOWN_DOORS[AfterStory.FESTIVAL]))
	await _advance_until(func(): return _level_id() == AfterStory.FESTIVAL and GameState.has_flag(AfterFestival.ON) and not Cutscene.is_playing() and not AfterStory.running, 30.0)
	FestivalDanceShow.quiet = true
	await _talk("floor_06/after_fest_host", "festival_dance", [0])
	await _advance_until(func(): return _show(FestivalDanceShow) != null and not (_show(FestivalDanceShow) as FestivalDanceShow).busy, 8.0)
	var d := _show(FestivalDanceShow) as FestivalDanceShow
	if d == null:
		return
	for i in 4:
		d._on_judged("perfect", {})
		await _wait(0.08)
		await shot("dance_%d" % i)
		await _wait(0.5)


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)
