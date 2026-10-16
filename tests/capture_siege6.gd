extends Node
## 第六波视觉验收：真实渲染保存到 tools/.cache/shots/siege6_*.png。

const OUT := "res://tools/.cache/shots/"
var d: SiegeDirector


func _ready() -> void:
	seed(606)
	DevConfig.override = false
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false
	TownBuffShow.enabled = false
	ComboTracker.play_scenes = false
	Monster.random_specials = false
	HUD.slow_motion = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.7)
	for flag in ["magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept", "f8_returned", "f6w_arrived", "intro_done_siege_intro", "siege_intro_seen", "seen_fatigue_burst", "seen_laugh_recover", "hint_tickled", "hint_first_special", "hint_grabbed"]:
		GameState.set_flag(flag)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _wait(0.5)
	d = SiegeDirector.current
	await _drain()
	d.bench_soldiers(true)
	d.teamwork.enabled = false
	d.wave = 6
	d.state = "fight"
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.quiet_spawn = true
	for c in [d.pink, d.blue]:
		c.set_controller(CharacterController.new())
		c.health.max_hp = 1000
		c.health.fill()
	d.pink.global_position = Vector2(d.gate_pos.x, 910)
	d.blue.global_position = Vector2(d.gate_pos.x + 70, 900)
	d.cam.set_process(false)
	var cam := GameState.player.camera
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	cam.zoom = Vector2(0.95, 0.95)
	cam.global_position = Vector2(d.gate_pos.x, 870)
	cam.reset_smoothing()
	var bear := d.spawn("gale_bear", "", Vector2(d.gate_pos.x - 70, 900)) as GaleBear
	bear.set_physics_process(false)
	bear.intro()
	for m in d.monsters:
		m.set_physics_process(false)
	await _wait(0.3)
	await _shot("intro")
	for c in [d.pink, d.blue]:
		c.fatigue.clear()
	await _wait(2.8)
	for m in d.monsters:
		m.set_physics_process(false)
	cam.zoom = Vector2(0.55, 0.55)
	cam.global_position = Vector2(d.gate_pos.x, 880)
	cam.reset_smoothing()
	for key in GaleBear.SKILL_CD:
		bear._cancel()
		bear._clear_fields()
		await _wait(0.1)
		bear.global_position = Vector2(d.gate_pos.x - 40, 900)
		bear._stun_left = 0.0
		bear.mode = TickleTroll.Mode.NORMAL
		bear.raged = key == "tornado"
		for c in [d.pink, d.blue]:
			c.laugh.set_value(0.0)
			c.fatigue.clear()
			c.status.release(true)
			c.status.clear_root()
			c._full_invuln = 0.0
			c._set_state(PlayableCharacter.State.IDLE)
		d.pink.global_position = bear.global_position + Vector2(35, 5)
		d.blue.global_position = bear.global_position + Vector2(120, 0)
		d.teamwork._cd.clear()
		for m in d.monsters:
			m.set_meta("team_busy", 0.0)
			if m != bear:
				m.global_position = bear.global_position + Vector2(randf_range(-60, 60), 70)
		if key in ["lanes", "convoy"]:
			d.blue.global_position = Vector2(d.gate_pos.x + 60, d.wall_top_y() + 4)
			cam.global_position.y = 480
			cam.zoom = Vector2(0.18, 0.18)
		else:
			cam.global_position.y = 880
			cam.zoom = Vector2(0.55, 0.55)
		cam.reset_smoothing()
		bear._start(key)
		await _wait(0.04)
		await _drain()
		await _shot(key + "_warning")
		await _wait(maxf(0.0, float(GaleBear.WARN_TIME[key]) - 0.04))
		bear._skill_tick(float(GaleBear.WARN_TIME[key]) + 0.01)
		if key == "tornado":
			await _wait(GaleBear.TORNADO_GAP + 0.01)
			bear._skill_tick(GaleBear.TORNADO_GAP + 0.01)
			await _wait(0.4)
		elif key == "convoy":
			await _wait(0.3)
		elif key == "paw":
			await _wait(GaleBear.PAW_GAP + 0.01)
			bear._skill_tick(GaleBear.PAW_GAP + 0.01)
			await _wait(0.07)
		else:
			await _wait(0.3)
		await _drain()
		await _shot(key + "_active")
	bear._rage()
	await _wait(0.3)
	await _shot("rage")
	d.state = "prep"
	d.clear_field()
	await _wait(0.2)
	for who in ["pink", "blue"]:
		Characters.scope(who)
		var play := func(): await CG.play_death("gale_bear")
		play.call()
		await _wait(0.15)
		for i in 200:
			if CG.step_index >= 9:
				break
			if Dialogue.is_active():
				Dialogue.advance()
			await _wait(0.05)
		await _wait(0.6)
		await _shot("cg_" + who)
		CG._can_skip = true
		CG.skip()
		for i in 100:
			if not CG.is_busy():
				break
			Dialogue.advance()
			await _wait(0.05)
		Characters.unscope()
	print("SIEGE6 visual capture complete")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image()
	result.save_png(ProjectSettings.globalize_path(OUT + "siege6_" + label + ".png"))
	print("shot ", label)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _drain() -> void:
	for i in 100:
		if not Dialogue.is_active():
			break
		Dialogue.advance()
		await _wait(0.01)
	# 截图只检查新内容，不让开局的规则提示遮住技能预警。
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.get("center_hint"):
		hud.center_hint.hide()
