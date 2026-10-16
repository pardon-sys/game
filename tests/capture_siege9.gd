extends "res://tests/siege9_boss_test.gd"
## 真正渲染的第九波专项截图；复用实际世界夹具，不运行父类专项。

const OUT := "res://doc/siege_wave9_images/"


func _ready() -> void:
	await _boot()
	for flag in ["hint_tickled", "hint_first_special", "hint_grabbed", "seen_fatigue_burst", "seen_laugh_recover"]:
		GameState.set_flag(flag)
	await _drain9()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var p := _puppet()
	p._intro_done = false
	p.intro()
	for mon in d.monsters:
		mon.set_physics_process(false)
	_camera(Vector2(864, 900), 0.65)
	await _wait(0.3)
	await _shot9("intro")
	await _wait(2.0)
	await _reset()
	await _drain9()
	p = _puppet()
	for i in 3:
		p.global_position = Vector2(1100, 960)
		_tower9(["airdrop", "brush_battery", "resonance"][i], Vector2(740 + i * 90, 930))
	_camera(Vector2(940, 925), 0.65)
	await _wait(0.7)
	await _shot9("new_towers")
	for key in PuppetMaster.SKILL_CD:
		await _reset()
		await _drain9()
		p = _puppet()
		d.pink.global_position = Vector2(900, 950)
		d.blue.global_position = Vector2(984, 950)
		if key == "swap":
			d.blue.global_position = Vector2(940, d.wall_top_y() + 4)
			_camera((d.pink.global_position + d.blue.global_position) / 2.0 + Vector2(0, 50), 0.2)
		else:
			_camera(Vector2(924, 915), 0.65)
		if key in ["tether", "winch"]:
			p._execute("cross")
		if key == "relay":
			for mon in ["vine", "ghost", "thigh_spider", "hug_bear"]:
				d.spawn(mon, "", p.global_position + Vector2(24, 40)).set_physics_process(false)
			_tower9("brush_battery", Vector2(1020, 1010))
		for cd in p.cds:
			p.cds[cd] = 999
		p._start(key)
		await _wait(0.03)
		await _shot9(key + "_warning")
		p.set_physics_process(true)
		await _wait(0.26)
		await _drain9()
		await _shot9(key + "_active")
		if key == "swap":
			await _wait(0.4)
			await _shot9("swap_landed")
		if key == "brush":
			await _wait(0.32)
			await _shot9("blue_pad")
		p.set_physics_process(false)
	await _reset()
	p = _puppet()
	p._rage()
	p._cast_raged = true
	d.blue.global_position = Vector2(980, 950)
	p._execute("cross")
	_camera(Vector2(924, 915), 0.65)
	await _wait(0.25)
	await _shot9("rage")
	await _reset()
	d.state = "prep"
	for role in ["pink", "blue"]:
		Characters.scope(role)
		var play := func(): await CG.play_death("puppet_master")
		play.call()
		await _wait(0.1)
		# 文件编号为手写剧本行号；CG.steps 在前面另外加了一步开场。
		for step in [3, 5, 7]:
			for _i in 300:
				if CG.step_index >= step + 1:
					break
				if Dialogue.is_active():
					Dialogue.advance()
				await _wait(0.015)
			await _wait(0.07)
			if Dialogue.is_active():
				Dialogue.advance()  # 显示完整当前文字，不等工具动画消失。
			await _wait(0.03)
			await _shot9("cg_%s_%d" % [role, step])
			await _wait(0.65)  # 等本段工具动画结束，再前进到下一种工具。
		CG._can_skip = true
		CG.skip()
		for _i in 100:
			if not CG.is_busy():
				break
			Dialogue.advance()
			await _wait(0.02)
		Characters.unscope()
	print("SIEGE9 visual capture complete")
	get_tree().quit()


func _reset() -> void:
	await super()
	for role in ["pink", "blue"]:
		Equipment.release(role)
	await _drain9()


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


func _shot9(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("shot ", label)
	if label.begins_with("cg_"):
		print("CG step ", CG.step_index, " tools ", CG.fx_root.get_children().filter(func(n): return n is SiegeTools.ToolVisual).map(func(n): return n.key))


func _drain9() -> void:
	for _i in 100:
		if not Dialogue.is_active():
			break
		Dialogue.advance()
		await _wait(0.01)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.get("center_hint"):
		hud.center_hint.hide()
	if hud and hud.get("toast_label"):
		hud.toast_label.hide()
		for label in hud._toast_old:
			if is_instance_valid(label):
				label.hide()
