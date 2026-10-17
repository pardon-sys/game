extends SiegeFixture
## 真正渲染的截图（第九轮）：四个大型强制位移陷阱、地面配合技的字幕、笑倒 CG 的爆发幕 / 第四幕、三来源组合演出的爆发幕。
## 输出到 tools/.cache/shots/siege_text/。

const OUT := "res://tools/.cache/shots/siege_text/"


func _ready() -> void:
	await _boot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var home := Vector2(d.gate_pos.x + 160.0, d.wall_foot_y() + 200.0)
	# 陷阱
	for kind in ["claw", "quicksand", "mushrooms", "portal_pair"]:
		await _reset()
		var p := d.pink
		p.global_position = home
		for i in 6:
			var m := d.spawn("slime", "", home + Vector2(260, 100) + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
			m.mind = null
			m.set_physics_process(false)
		var hz := d.spawn_hazard(kind, home + (Vector2(30, 0) if kind == "quicksand" else Vector2.ZERO))
		_camera(home + Vector2(120, 40), 1.1)
		await _wait(1.0)
		await _shot("hazard_%s_warn" % kind)
		if kind == "portal_pair":
			p.global_position = hz.global_position
		await _wait(2.2 if kind == "claw" else 1.6)
		await _shot("hazard_%s" % kind)
	# 地面配合技（字幕）
	await _reset()
	d.teamwork.enabled = true
	d.wave = 8
	var made := d.teamwork.spawn_formation("crab_rat", home + Vector2(30, 0))
	for m in made:
		m.mind = null
		m.set_physics_process(false)
		m.global_position = home + Vector2(randf_range(10, 40), randf_range(-8, 8))
	d.pink.global_position = home
	_camera(home, 1.4)
	d.teamwork.scan()
	await _wait(0.4)
	await _shot("team_crab_rat")
	d.teamwork.enabled = false
	# 笑倒 CG：爆发幕 + 第四幕；组合演出的爆发幕
	await _reset()
	d.state = "prep"
	for role in ["pink", "blue"]:
		Characters.scope(role)
		var play := func(): await CG.play_death("thigh_spider")
		play.call()
		await _wait(0.1)
		await _advance_to_act("burst")
		await _shot("cg_%s_burst" % role)
		await _advance_to_act("4")
		await _shot("cg_%s_act4" % role)
		await _skip()
		var scene := func(): await CG.play_scene("sg_sand_thighs" if role == "blue" else "sg_portal_toes")
		scene.call()
		await _wait(0.1)
		await _advance_to_act("burst")
		await _shot("scene_%s_burst" % role)
		await _skip()
		Characters.unscope()
	print("SIEGE TEXT capture complete")
	get_tree().quit()


func _advance_to_act(act: String) -> void:
	for _i in 600:
		if not CG.is_busy():
			return
		var cg: Dictionary = CG._scenes_for(CG.character_id).get(CG.current.trim_prefix("combo:"), {}) if CG.current.begins_with("combo:") else CG.cgs().get(CG.current, {})
		var steps: Array = cg.get("steps", [])
		var cur := CG.step_index
		if cur >= 0 and cur < steps.size():
			var a: Variant = steps[cur].get("act", "")
			if (str(int(a)) if a is float or a is int else str(a)) == act:
				await _wait(0.5)
				if Dialogue.is_active():
					Dialogue.advance()  # 打完当前这句
				await _wait(0.1)
				return
		if Dialogue.is_active():
			Dialogue.advance()
		await _wait(0.02)


func _skip() -> void:
	CG._can_skip = true
	CG.skip()
	for _i in 200:
		if not CG.is_busy():
			break
		Dialogue.advance()
		await get_tree().process_frame


func _camera(at: Vector2, zoom: float) -> void:
	d.cam.set_process(false)
	var cam := GameState.player.camera
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = at
	cam.reset_smoothing()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("shot ", label)
