extends "res://tests/siege9_boss_test.gd"
## 实际泡泡与魔偶师交叠的生命周期回归，另覆盖批量塔光效和居中暂停页。


func _ready() -> void:
	await _boot()
	for _i in 100:
		if not Dialogue.is_active():
			break
		Dialogue.advance()
		await _wait(0.01)
	await _bubble_swap()
	await _inactive_target()
	await _appearance()
	await _audio_settings()
	if OS.get_environment("SIEGE_REVISION_CAPTURE") == "1":
		await _capture_cgs_revision()
	print("SIEGE REVISION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _bubble_swap() -> void:
	var p := _puppet()
	var c := d.pink
	c._full_invuln = 1.4
	var bubble := HazardBubbles.new()
	bubble.position = c.global_position
	d.entities().add_child(bubble)
	bubble._bubbles = [{"pos": c.global_position, "held": null, "left": 0.0, "pop": false}]
	bubble._active(0.001)
	check("real bubble pauses pink physics", c.get_meta("siege_bubbled", false) and not c.is_physics_processing())
	p._execute("swap")
	check("puppet does not take over a bubble passenger", not p._fields.any(func(ref): return is_instance_valid(ref.get_ref()) and ref.get_ref() is SiegeTools.Move))
	# 旧泡泡先放开、换位后结束，是原先把 physics=false 再次写回角色的卡死路径。
	bubble._end()
	await _wait(1.8)
	check("bubble release cannot leave pink physics disabled", c.is_physics_processing() and not c.get_meta("siege_puppet_move", false))
	check("temporary invulnerability continues ticking after release", c._full_invuln == 0.0)
	var before := c.laugh.value
	p._t += 0.2
	check("released pink receives tickle again", SiegeTools.strike(p, c, 4.0, 0, "brush") and c.laugh.value > before)
	var ctrl := ScriptedController.new()
	c.set_controller(ctrl)
	var from := c.global_position
	ctrl.move = Vector2.RIGHT
	await _wait(0.25)
	check("released pink can move through real controller", c.global_position.x > from.x + 4.0)
	await _reset()


func _appearance() -> void:
	DevConfig.override = true
	d.wave = 12
	d.state = "prep"
	var old_lights := d.level().find_children("*", "PointLight2D", true, false).size()
	check("batch deploy still makes thirty real towers", SiegeDevTools.deploy_towers(d) == 30)
	var original_lights := true
	var functional_lights := true
	for t: IceTower in get_tree().get_nodes_in_group("siege_tower"):
		var lights := t.find_children("*", "PointLight2D", true, false)
		if lights.size() != 1:
			original_lights = false
			continue
		var light: PointLight2D = lights[0]
		var energy := 0.9 if t.kind in ["campfire", "lamp"] else 0.5
		var scale := 1.8 if t.kind == "lamp" else (1.6 if t.kind == "campfire" else 0.5)
		var color: Color = {"mint": Color(0.6, 1.0, 0.85), "campfire": Color(1.0, 0.65, 0.35), "cocoa": Color(1.0, 0.8, 0.55)}.get(t.kind, Color(0.6, 0.85, 1.0))
		original_lights = original_lights and is_equal_approx(light.energy, energy) and is_equal_approx(light.texture_scale, scale) \
			and light.color == color and light.texture == load("res://assets/lights/light_soft.tres") and light.position == Vector2(0, -14)
		if t.kind in ["campfire", "lamp"]:
			functional_lights = functional_lights and t.lit and t.light_radius > 0 and t.is_in_group("torch")
	check("thirty towers restore original light texture color brightness and radius", original_lights and old_lights + 30 == d.level().find_children("*", "PointLight2D", true, false).size())
	check("lamp and campfire keep gameplay illumination", functional_lights)
	check("siege floor and walls use smaller light batches", d.level().get_node("Floor").rendering_quadrant_size == 4 and d.level().get_node("Walls").rendering_quadrant_size == 4)
	if OS.get_environment("SIEGE_REVISION_CAPTURE") == "1" or OS.get_environment("SIEGE_AUDIO_CAPTURE") == "1":
		d.cam.set_process(false)
		var cam := GameState.player.camera
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		cam.zoom = Vector2(0.38, 0.38)
		cam.global_position = Vector2(d.gate_pos.x, d.wall_foot_y() + 120)
		cam.reset_smoothing()
		for _i in 100:
			if not Dialogue.is_active():
				break
			Dialogue.advance()
			await _wait(0.01)
		await _wait(3.0)
		await _shot_revision("thirty_towers")
	var menu := main.get_node("PauseMenu")
	menu.toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	var center := get_viewport().get_visible_rect().get_center()
	check("pause menu is horizontally and vertically centered", menu.main_scroll.get_global_rect().get_center().is_equal_approx(center))
	check("pause title sits above centered menu", menu.get_node("Root/Title").get_global_rect().end.y < menu.main_scroll.get_global_rect().position.y)
	await _shot_revision("pause_center")
	menu.show_siege_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	check("siege test submenu also centered", menu.skip_scroll.get_global_rect().get_center().is_equal_approx(center))
	await _shot_revision("siege_tests_center")
	menu.hide_skip_list()
	menu.toggle()
	SiegeDevTools.clear_test_towers(d)
	await get_tree().process_frame
	DevConfig.override = false
	await _reset()


func _shot_revision(label: String) -> void:
	if OS.get_environment("SIEGE_REVISION_CAPTURE") != "1" and OS.get_environment("SIEGE_AUDIO_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var folder := "res://doc/siege_audio_lights_images/" if OS.get_environment("SIEGE_AUDIO_CAPTURE") == "1" else "res://doc/siege_revision_images/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	get_viewport().get_texture().get_image().save_png(folder + label + ".png")


func _capture_cgs_revision() -> void:
	d.state = "prep"
	for boss in ["gale_bear", "puppet_master"]:
		for role in ["pink", "blue"]:
			Characters.scope(role)
			var play := func(): await CG.play_death(boss)
			play.call()
			for _i in 100:
				if CG.step_index >= 5:
					break
				if Dialogue.is_active():
					Dialogue.advance()
					Dialogue.advance()
				await _wait(0.025)
			if Dialogue.is_active():
				Dialogue.advance()
			await _shot_revision("cg_" + boss + "_" + role)
			CG.skip()
			for _i in 100:
				if not CG.is_busy():
					break
				if Dialogue.is_active():
					Dialogue.advance()
				await _wait(0.025)
			Characters.unscope()


func _inactive_target() -> void:
	var p := _puppet()
	var c := d.pink
	c.set_physics_process(false)
	check("disabled physics cannot become a new hold", SiegeTools.hold(p, c, c.global_position) == null)
	check("disabled physics cannot become a forced move", SiegeTools.move(p, [c], [c.global_position + Vector2(60, 0)]) == null)
	c.set_physics_process(true)
	c.hide()
	check("hidden prisoner cannot become a puppet target", not SiegeTools.can_move(p, c))
	c.show()
	await _reset()


## 设置落盘会先备份并最终还原，测试不会修改玩家的音量偏好。
func _audio_settings() -> void:
	var path := Audio.settings_path()
	var existed := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	var music := Audio.music_volume
	var sfx := Audio.sfx_volume
	var bus := AudioServer.get_bus_index(Audio.SFX_BUS)
	check("SFX bus exists and music stays independent", bus > 0 and Audio._music.all(func(p): return p.bus == &"Master"))
	check("one shot voice and CG players share SFX bus", Audio._players.all(func(p): return p.bus == Audio.SFX_BUS) and Audio._voice.bus == Audio.SFX_BUS and Audio._crack.bus == Audio.SFX_BUS and CG.voice.bus == Audio.SFX_BUS and CG.voice2.bus == Audio.SFX_BUS)
	var loops := []
	for kind in ["feather_fan", "tickle_vortex", "tickle_conveyor"]:
		var trap: Trap = load("res://scenes/traps/" + kind + ".tscn").instantiate()
		trap.position = Vector2(100, 100)
		d.entities().add_child(trap)
		loops.append(trap)
	check("all three positional trap loops share SFX bus", loops.all(func(t): return t._sound.bus == Audio.SFX_BUS and t._sound.playing))
	var stalker := preload("res://levels/floor_08/scenes/night_stalker.tscn").instantiate()
	d.entities().add_child(stalker)
	check("maze chase drums also share SFX bus", stalker._drums.bus == Audio.SFX_BUS)
	stalker.queue_free()
	check("actual magic channel starts its loop", d.pink.begin_channel())
	check("magic chant shares SFX bus", d.pink._chant != null and d.pink._chant.bus == Audio.SFX_BUS)
	d.pink.interrupt_channel()
	Audio.play_music("siege", 0.01)
	await _wait(0.2)
	var mp: AudioStreamPlayer = Audio._music[Audio._music_cur]
	var menu := main.get_node("PauseMenu")
	menu.toggle()
	menu.music_slider.value = 1.0
	await _wait(0.2)
	check("music is six dB louder and adjustable while paused", is_equal_approx(mp.volume_db, -6.0 + Audio._duck))
	menu.sfx_slider.value = 0.0
	check("SFX slider mutes every routed effect without muting music", AudioServer.is_bus_mute(bus) and mp.playing and not AudioServer.is_bus_mute(0))
	menu.sfx_slider.value = 0.4
	check("SFX slider immediately restores chosen loudness", not AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.4)))
	menu.music_slider.value = 0.0
	await _wait(0.2)
	check("large music volume jump reaches mute", mp.volume_db <= -79.0)
	menu.music_slider.value = 0.7
	await _wait(0.2)
	check("music recovers from mute without changing track", mp.playing and is_equal_approx(mp.volume_db, -6.0 + linear_to_db(0.7) + Audio._duck))
	var cfg := ConfigFile.new()
	check("both sliders persist independent settings", cfg.load(path) == OK and is_equal_approx(float(cfg.get_value("audio", "sfx_volume", -1)), 0.4) and is_equal_approx(float(cfg.get_value("audio", "music_volume", -1)), 0.7))
	menu.sfx_slider.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	check("SFX slider keyboard focus scrolls into centered menu", menu.main_scroll.get_global_rect().encloses(menu.sfx_slider.get_global_rect()))
	await _shot_revision("audio_sliders")
	menu.toggle()
	Audio.set_sfx_volume(2.0)
	check("SFX volume clamps at full volume", Audio.sfx_volume == 1.0 and is_zero_approx(AudioServer.get_bus_volume_db(bus)))
	Audio.set_sfx_volume(-1.0)
	check("negative SFX volume clamps to mute", Audio.sfx_volume == 0.0 and AudioServer.is_bus_mute(bus))
	Audio.play_music("dungeon", 0.01)
	Audio.play_music("boss", 0.01)
	await _wait(0.2)
	check("rapid music changes still complete the correct crossfade", Audio.music_id == "boss" and Audio._music[Audio._music_cur].playing and Audio._music[Audio._music_cur].volume_db > -30.0)
	Audio.stop_music()
	await _wait(1.3)
	check("music stop fade remains stopped", Audio.music_id == "" and not Audio._music.any(func(p): return p.playing))
	Audio.set_music_volume(music)
	Audio.set_sfx_volume(sfx)
	if existed:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("audio regression restores player settings byte for byte", FileAccess.get_file_as_bytes(path) == backup if existed else not FileAccess.file_exists(path))
	for trap in loops:
		trap.queue_free()
	await _reset()
