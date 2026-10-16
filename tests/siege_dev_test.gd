extends "res://tests/siege9_boss_test.gd"
## 复用攻防战实际世界夹具：失效抓取引用、跳波生命周期、暂停测试 UI 与真实批量造塔。


func _ready() -> void:
	await _boot()
	if "--jump-buffs-only" in OS.get_cmdline_user_args():
		d.set_process(false)
		d.features.set_process(false)
		await _jump_buffs()
		get_tree().paused = false
		DevConfig.override = false
		print("SIEGE JUMP BUFFS: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	await _stale_grabber()
	await _dev_commands()
	await _dev_menu()
	get_tree().paused = false
	DevConfig.override = false
	await _reset()
	print("SIEGE DEV: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _jump_buffs() -> void:
	DevConfig.override = true
	for a in d.town.allies():
		for id in a.buffs.keys():
			if str(id).begins_with("town_"): a.remove_buff(id)
	d.town.owned.clear()
	GameState.vars["siege_town_buffs"] = []
	var wall_max := d.wall_max
	var soldier_count := d.soldiers.size()
	var mint_count := GameState.inventory.count("mint")
	var crystals := d.crystals
	# 真实跳波入口：每波都有对应累计支援，准备阶段即可生效。
	for wave in [1,2,3,4,9,10,11,12]:
		check("jump %d succeeds" % wave, await SiegeDevTools.jump_wave(d, wave))
		var expected: Array[String] = []
		for e in TownBuffs.all():
			if int(e["after_wave"]) < wave: expected.append(str(e["id"]))
		check("wave %d cumulative ownership and saved list" % wave, d.town.owned==expected and GameState.vars["siege_town_buffs"]==expected)
		var applied := true
		for c in [d.pink,d.blue]:
			for id in expected:
				var buff := str(TownBuffs.info(id).get("buff", ""))
				if buff != "": applied = applied and c.has_buff(buff)
		check("wave %d princess buffs active during prep" % wave, applied and d.state=="prep" and not d._busy)
	check("wall support grants fifteen percent once", is_equal_approx(d.wall_max,wall_max*1.15))
	check("captain actually adds two soldiers", d.soldiers.size()==soldier_count+2)
	check("pharmacist grants once without replaying old supply", GameState.inventory.count("mint")==mint_count+2)
	check("final wave includes real tower and spell multipliers", is_equal_approx(d.town.mul("tower_dmg"),1.56) and is_equal_approx(d.town.mul("spell_cd"),0.75*0.83))
	check("new soldiers receive all actor town buffs", d.soldiers.slice(-2).all(func(s): return s.has_buff("town_party") and s.has_buff("town_mayor")))
	check("jump grants without town cutscene", d.find_children("*","TownBuffShow",true,false).is_empty() and not SiegeTools.paused())
	var owned := d.town.owned.duplicate()
	var old_max := d.wall_max
	var old_count := d.soldiers.size()
	var old_mints := GameState.inventory.count("mint")
	get_tree().paused = true
	check("repeat final jump works from paused menu", await SiegeDevTools.jump_wave(d,12))
	check("repeat jump cannot farm one-time rewards", d.wall_max==old_max and d.soldiers.size()==old_count and GameState.inventory.count("mint")==old_mints and d.crystals==crystals)
	check("backward jump preserves permanent support", await SiegeDevTools.jump_wave(d,3) and d.town.owned==owned)
	d.pink.remove_buff("town_party")
	check("repeated jump repairs missing live buff", await SiegeDevTools.jump_wave(d,3) and d.pink.has_buff("town_party"))
	check("invalid jump leaves support unchanged", not await SiegeDevTools.jump_wave(d,13) and d.town.owned==owned and d.wall_max==old_max)
	get_tree().paused = false
	d.bench_soldiers(true)


func _stale_grabber() -> void:
	var p := _puppet()
	var c := d.blue
	var dangling := Node.new()
	d.entities().add_child(dangling)
	c.status.grab(dangling, 4.0, 16)
	c._set_state(PlayableCharacter.State.GRABBED)
	dangling.free()
	check("fixture retains a freed grabber", not is_instance_valid(c.status.grabber))
	# 原报错的准确路径：Status 下一帧清理前调用 release_own。
	SiegeTools.release_own(p, c)
	check("freed reference passes safe ownership check", SiegeTools.own_hold(p, c) == null and SiegeTools.can_move(p, c))
	var signals := []
	var record := func(src: Node, broke_free: bool): signals.append([src == null, broke_free])
	c.status.released.connect(record)
	c.status.release(false)
	check("invalid grab release emits null safely", c.status.grabber == null and signals == [[true, false]])
	c.status.released.disconnect(record)
	c._set_state(PlayableCharacter.State.IDLE)
	var h := SiegeTools.hold(p, c, c.global_position, true)
	c._set_state(PlayableCharacter.State.GRABBED)
	c._full_invuln = 0.0
	check("valid own hold still recognized", SiegeTools.own_hold(p, c) == h)
	SiegeTools.release_own(p, c)
	check("own handoff clears hold lift and state without escape invulnerability", not c.status.is_grabbed() and c.state == PlayableCharacter.State.IDLE and c._full_invuln == 0.0 and not c.buffs.has("lifted"))
	var other := _puppet(Vector2(800, 960))
	h = SiegeTools.hold(other, c, c.global_position)
	SiegeTools.release_own(p, c)
	check("foreign hold survives release and blocks move", c.status.is_grabbed_by(h) and not SiegeTools.can_move(p, c))
	h._end()
	await get_tree().process_frame
	SiegeTools.release_own(p, c)
	check("queued hold deletion safe", SiegeTools.own_hold(p, c) == null)
	var hobble := Node.new()
	d.entities().add_child(hobble)
	c.status.hobble(hobble)
	hobble.free()
	var hobble_signals := []
	c.status.hobble_released.connect(func(src: Node, broke_free: bool): hobble_signals.append([src == null, broke_free]), CONNECT_ONE_SHOT)
	c.status.release_hobble(false)
	check("freed hobbler follows same safe signal rule", c.status.hobbler == null and hobble_signals == [[true, false]])
	var stale := Node.new()
	d.entities().add_child(stale)
	c.status.grab(stale)
	# 同时注入两个失效引用，验证组件自己的下一帧清理路径。
	c.status.hobbler = stale
	c.status.root_after_release(0.8)
	stale.free()
	c.status._process(0.01)
	check("status next frame actually clears freed references", typeof(c.status.grabber) == TYPE_NIL and typeof(c.status.hobbler) == TYPE_NIL)
	check("freed source still applies pending release root", c.status.is_rooted())
	SiegeTools.release_own(p, null)
	await _reset()


func _dev_commands() -> void:
	DevConfig.override = false
	check("normal mode cannot use deploy or jump", SiegeDevTools.deploy_towers(d) == 0 and not await SiegeDevTools.jump_wave(d, 9))
	DevConfig.override = true
	check("bad wave rejected without mutation", not await SiegeDevTools.jump_wave(d, 0) and not await SiegeDevTools.jump_wave(d, 13) and d.wave == 9)
	d._busy = true
	check("pending transition cannot be interrupted", not await SiegeDevTools.jump_wave(d, 6) and SiegeDevTools.deploy_towers(d) == 0)
	d._busy = false
	GameState.in_cutscene = true
	check("cutscene blocks test mutations", not await SiegeDevTools.jump_wave(d, 6) and SiegeDevTools.deploy_towers(d) == 0)
	GameState.in_cutscene = false
	var original := BuildPad.new()
	d.entities().add_child(original)
	original.global_position = Vector2(800, d.wall_foot_y() + 64)
	original._build("icicle", 2, true)
	original._save()
	var crystals := d.crystals
	check("zero deployment is a no op", SiegeDevTools.deploy_towers(d, 0) == 0)
	var made := SiegeDevTools.deploy_towers(d)
	check("one click builds thirty actual towers", made == 30 and get_tree().get_nodes_in_group("siege_tower").size() == 31)
	check("deployment preserves budget and saves thirty plus original", d.crystals == crystals and GameState.vars["siege_towers"].size() == 31)
	var kinds := {}
	var pads := get_tree().get_nodes_in_group("siege_pad")
	var spacing_ok := true
	for pd: BuildPad in pads:
		if not pd.get_meta("siege_dev_tower", false):
			continue
		kinds[pd.tower.kind] = true
		spacing_ok = spacing_ok and pd.tower.pad == pd and pd.tower.level == 1 and pd.pending.is_empty() and IceTower.unlocked(pd.tower.kind)
		for neighbor: BuildPad in pads:
			if neighbor != pd and neighbor.global_position.distance_to(pd.global_position) < SiegeDirector.BUILD_GAP:
				spacing_ok = false
	check("batch uses unlocked mixed types and original base spacing", spacing_ok and kinds.size() == IceTower.kinds().filter(func(k): return IceTower.unlocked(k)).size())
	check("repeat deployment skips existing towers", SiegeDevTools.deploy_towers(d) == 30 and get_tree().get_nodes_in_group("siege_tower").size() == 61)
	var p := _puppet()
	p.register_field(SiegeTools.hold(p, d.blue, d.blue.global_position, true))
	d.blue._set_state(PlayableCharacter.State.GRABBED)
	d.spawn_hazard("fog")
	var site := get_tree().get_nodes_in_group("siege_enemy_site")[0] as EnemySite
	var enemy := site.build_tower("airdrop")
	enemy._t = 999
	site.build_progress = 3.0
	site._claim = 2
	var temporary := EnemySite.new()
	temporary.temporary = true
	d.entities().add_child(temporary)
	d.wall_hp = 1
	d.next_left = 2.0
	d.teamwork._cd["puppet_relay"] = 99.0
	original.pending = {"kind": "icicle", "upgrade": true}
	original.blue_beam(d.blue)
	original._blue_locked = true
	PlayerInputController.movement_locked = true
	get_tree().paused = true
	check("paused menu can jump to wave6", await SiegeDevTools.jump_wave(d, 6))
	check("jump cleans old boss enemies traps and temporary sites", not is_instance_valid(p) and not is_instance_valid(enemy) and not is_instance_valid(temporary) and d.monsters.is_empty() and d._queue.is_empty() and d._hazards.is_empty() and get_tree().get_nodes_in_group("siege_temp").is_empty())
	check("fixed sites reset for new wave", is_instance_valid(site) and site.tower == null and site.build_progress == 0 and site._claim == 0)
	check("jump preserves towers and crystals", get_tree().get_nodes_in_group("siege_tower").size() == 61 and d.crystals == crystals)
	check("jump resets progression with full prep time", d.wave == 6 and d.state == "prep" and not d._busy and d._fight_t == 0 and d.next_left == -1 and GameState.vars["siege_wave"] == 6 and d.prep_left == d.data["prep"] and d.teamwork._cd.is_empty())
	check("jump restores wall princesses and lift", d.wall_hp == d.wall_max and d.blue.global_position == Vector2(d.gate_pos.x + 16, d.wall_top_y() + 4) and d.pink.global_position == d.gate_pos and d.blue.is_physics_processing() and not d.blue.status.is_grabbed() and not d.blue.buffs.has("lifted"))
	check("jump stops old tower beam without deleting pending upgrade", not original.beaming and not PlayerInputController.movement_locked and not d.blue.get_meta("siege_beaming", false) and not original.pending.is_empty())
	check("clear test towers leaves normal tower saved", SiegeDevTools.clear_test_towers(d) == 60 and GameState.vars["siege_towers"].size() == 1 and GameState.vars["siege_towers"][0]["level"] == 2)
	await get_tree().process_frame
	check("normal tower survives cleanup", is_instance_valid(original.tower) and get_tree().get_nodes_in_group("siege_tower").size() == 1)
	await d._begin_fight()
	check("wave6 initialization includes delayed bear and its mechanics", d.state == "fight" and d._queue.any(func(q): return q.get("monster") == "gale_bear" and q["t"] == 16.0) and d.features.active == d.wave_data()["features"])
	check("jump onward to ninth initializes distinct boss queue", await SiegeDevTools.jump_wave(d, 9))
	await d._begin_fight()
	check("wave9 normal queue includes puppet master", d._queue.any(func(q): return q.get("monster") == "puppet_master" and q["t"] == 16.0))
	get_tree().paused = false
	original.tower.queue_free()
	original.queue_free()
	await get_tree().process_frame
	await _reset()


func _dev_menu() -> void:
	var menu := main.find_child("PauseMenu", true, false)
	DevConfig.override = false
	menu.toggle()
	check("siege test entry hidden in normal mode", not menu.siege_test_button.visible)
	menu.toggle()
	DevConfig.override = true
	menu.toggle()
	check("siege test entry visible in dev siege", menu.siege_test_button.visible)
	await _capture_dev("main_menu")
	menu.siege_test_button.pressed.emit()
	check("siege testing reuses paused scroll panel", get_tree().paused and menu.skip_scroll.visible and not menu.main_scroll.visible and menu.skip_box.get_node_or_null("DevWave12") != null)
	await _capture_dev("siege_tests")
	# ScrollContainer 的真实布局在下一帧完成，随后模拟键盘聚焦末项。
	await get_tree().process_frame
	await get_tree().process_frame
	menu.skip_box.get_node("DevWave12").grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	check("keyboard focus scrolls last wave into view", menu.skip_scroll.scroll_vertical > 0 and menu.skip_box.get_node("DevWave12").get_global_rect().end.y <= menu.skip_scroll.get_global_rect().end.y)
	menu.skip_box.get_child(2).pressed.emit()
	check("UI one click deployment invokes existing towers", get_tree().get_nodes_in_group("siege_tower").size() == 30 and get_tree().paused)
	menu.skip_box.get_child(4).pressed.emit()
	await get_tree().process_frame
	check("UI cleanup removes test towers", get_tree().get_nodes_in_group("siege_tower").is_empty())
	menu.skip_box.get_node("DevWave6").pressed.emit()
	for i in 4:
		await get_tree().process_frame
	check("wave button jumps and resumes game", d.wave == 6 and d.state == "prep" and not get_tree().paused and not menu.root.visible)
	menu.toggle()
	menu.show_training()
	check("training panel hides main scroll too", menu.skip_scroll.visible and not menu.main_scroll.visible)
	menu.hide_skip_list()
	await get_tree().process_frame
	check("main menu scroll stays inside 270px viewport", menu.main_scroll.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	menu.show_siege_tests()
	d._busy = true
	menu.show_siege_tests()
	check("busy state disables jump and deployment buttons", menu.skip_box.get_node("DevWave6").disabled and menu.skip_box.get_child(2).disabled)
	d._busy = false
	menu.hide_skip_list()
	menu.toggle()
	var current := SiegeDirector.current
	SiegeDirector.current = null
	menu.toggle()
	check("entry hidden outside siege", not menu.siege_test_button.visible)
	menu.toggle()
	SiegeDirector.current = current


func _capture_dev(label: String) -> void:
	if OS.get_environment("SIEGE_DEV_CAPTURE") != "1":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://doc/siege_dev_images/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	get_viewport().get_texture().get_image().save_png(folder + label + ".png")
