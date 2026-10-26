extends "res://tests/f6_after_test.gd"
## 骑士 Boss 的截图：开打（耐久条、木箱、乱跑的镇民）、扑抓预警、跳起来的影子、呼唤骑士之名的缺口、最后阶段的灯笼 / 触手 / 帮手、光柱汇聚。
## 输出到 tools/.cache/shots/knight_boss/。
const OUT := "res://tools/.cache/shots/knight_boss/"


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
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 0
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	KnightStory.jump("boss")
	GameState.pending_spawn = "from_prison"
	await main.change_level(Floors.scene(KnightStory.KCHASE))
	await _advance_until(func(): return _node("Task_boss") != null and bool(_node("Task_boss").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 40.0)
	var b := _node("Task_boss") as TaskKnightBoss
	b.ai_enabled = false
	b.attack_t = 999.0
	var pink := b.pink
	pink.global_position = b._body.global_position + Vector2(0, 50)
	await _wait(1.2)
	await shot("boss_open")
	b._warn_grab(pink)
	b.warn["left"] = 99.0
	await _wait(0.4)
	await shot("boss_grab_warn")
	b._clear_field()
	b.curse_victim(b.victims[0])
	await _wait(0.3)
	b.parts[0].freeze_left = 4.0
	for i in TaskKnightBoss.PART_HP:
		b.hit_part(b.parts[0])
	await _wait(0.2)
	await shot("boss_part_break")
	for i in TaskKnightBoss.PART_HP:
		b.parts[1].freeze_left = 4.0
		b.hit_part(b.parts[1])
	await _wait(0.5)
	await shot("boss_transition")
	await _advance_until(func(): return b.phase == 1 and not b.transitioning, 10.0)
	b.attack_t = 999.0
	pink.global_position = b._body.global_position + Vector2(60, 40)
	b.leap(pink)
	b.leap_left = 0.5
	await _wait(0.25)
	await shot("boss_leap")
	await _wait(1.0)
	b.stuck_left = 4.0
	for part in b.parts.duplicate():
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await _advance_until(func(): return b.phase == 2 and not b.transitioning, 10.0)
	for part in b.parts.duplicate():
		part.freeze_left = 4.0
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await _advance_until(func(): return b.phase == 3 and not b.transitioning, 10.0)
	b.attack_t = 999.0
	b._clear_field()
	b.name_call()
	b.warn["left"] = 99.0
	pink.global_position = b._body.global_position + Vector2(0, 60)
	await _wait(0.5)
	await shot("boss_name_gaps")
	b._clear_field()
	await _wait(2.0)
	b.lanterns[1].progress = 0.5
	b.lanterns[0].progress = 0.3
	var tn := b.send_tentacle()
	tn.left = 0.0
	tn.attached = true
	pink.global_position = b.lanterns[2].global_position + Vector2(0, 6)
	KnightLaugh.force_hold = true
	await _wait(1.0)
	await shot("boss_lanterns")
	KnightLaugh.force_hold = false
	for l in b.lanterns:
		l.progress = 0.99
	TaskKnightBoss.skip_cutscenes = true
	for l in b.lanterns:
		b._light(l, 0.02)
	b.finale = false
	b._purify()
	await _wait(0.3)
	await shot("boss_finale")
	TaskKnightBoss.skip_cutscenes = false
	get_tree().quit()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)
