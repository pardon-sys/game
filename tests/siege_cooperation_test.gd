extends SiegeFixture
## 真正升级、真实换位后的双人 CG 排队、双子距离与十种联动生命周期。

var new_teams: Array


func _ready() -> void:
	fixture_wave = 9
	await _boot()
	await _drain()
	new_teams = MonsterTeamwork.data()["teams"].filter(func(t): return t["effect"].get("joint", false))
	check("ten confirmed new teams use short windup", new_teams.size() == 10 and new_teams.all(func(t): return t["windup"] >= 0.15 and t["windup"] <= 0.25 and t["cooldown"] >= 12 and t["cooldown"] <= 18))
	var only := _option("only")
	for section in [["upgrade", _upgrade_all], ["twins", _twin_leash], ["identity", _identity_cgs], ["effects", _joint_effects], ["pressure", _pressure]]:
		if only == "" or only.split(",").has(section[0]):
			await section[1].call()
	await _reset()
	print("SIEGE COOPERATION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _drain() -> void:
	for _i in 100:
		if not Dialogue.is_active():
			break
		Dialogue.advance()
		await _wait(0.01)


func _upgrade_all() -> void:
	DevConfig.override = true
	d.wave = 12
	d.state = "prep"
	var saved: Array = GameState.vars.get("siege_towers", []).duplicate(true)
	var original := BuildPad.new()
	d.entities().add_child(original)
	original.global_position = Vector2(864, 1100)
	original._build("icicle", 1, true)
	original.pending = {"kind": "icicle", "upgrade": true}
	check("upgrade fixture deploys thirty test towers", SiegeDevTools.deploy_towers(d) == 30)
	var crystals := d.crystals
	check("one click raises all existing towers one level", SiegeDevTools.upgrade_towers(d) == 31 and get_tree().get_nodes_in_group("siege_tower").all(func(t): return t.level == 2))
	check("normal tower and pending project survive free upgrade", original.tower.level == 2 and not original.pending.is_empty() and d.crystals == crystals)
	check("upgraded levels immediately saved", GameState.vars["siege_towers"].size() == 31 and GameState.vars["siege_towers"].all(func(t): return t["level"] == 2))
	var menu := main.get_node("PauseMenu")
	menu.toggle()
	menu.show_siege_tests()
	menu.skip_box.get_child(3).pressed.emit()
	check("paused UI raises towers to three", get_tree().paused and get_tree().get_nodes_in_group("siege_tower").all(func(t): return t.level == 3))
	check("max level click does not exceed cap", SiegeDevTools.upgrade_towers(d) == 0)
	await _shot("upgrade_menu")
	menu.hide_skip_list()
	menu.toggle()
	DevConfig.override = false
	check("normal mode cannot bulk upgrade", SiegeDevTools.upgrade_towers(d) == 0)
	DevConfig.override = true
	SiegeDevTools.clear_test_towers(d)
	original.tower.queue_free()
	original.queue_free()
	await get_tree().process_frame
	GameState.vars["siege_towers"] = saved
	DevConfig.override = false
	await _reset()


func _twin_leash() -> void:
	var a := d.spawn("twin_ghost", "", Vector2(700, 1220)) as TwinGhost
	await _wait(0.05)
	var b := a.twin
	check("twins enter together away from wall", is_instance_valid(b) and a.global_position.distance_to(b.global_position) < 40 and not d.is_on_wall(b))
	a.global_position = Vector2(700, d.wall_foot_y() + 112)
	b.global_position = a.global_position + Vector2(20, -16)
	# b 跟着 a 斜着飘上去，一般 3.5~4 秒；最多等 7 秒
	var t := 0.0
	while t < 7.0 and not (b.on_wall and d.is_on_wall(b)):
		await _wait(0.1)
		t += 0.1
	check("partner can float onto wall after approaching together", b.on_wall and d.is_on_wall(b))
	b.global_position = a.global_position + Vector2(600, -100)
	b._limit_pair()
	check("hard leash corrects overlong pair", a.global_position.distance_to(b.global_position) <= 240.001)
	a.target = d.pink
	a.state = Monster.State.CHASE
	a.apply_knockback(b.global_position, 2000)
	await _wait(0.3)
	check("chase and knockback cannot separate twins", a.global_position.distance_to(b.global_position) <= 240.001)
	var other := d.spawn("twin_ghost", "", Vector2(760, 1160)) as TwinGhost
	await _wait(0.05)
	check("multiple pairs keep original companions", a.twin == b and other.twin != b and other.twin.twin == other)
	a.health.damage(999)
	await _wait(0.1)
	check("downed half stays down and partner stays nearby", not a.is_alive() and b.is_alive() and a.global_position.distance_to(b.global_position) <= 240.001)
	check("eight second defeat window unchanged", TwinGhost.PAIR_TIME == 8.0)
	await _shot("twins")
	await _reset()


func _finish_cgs() -> void:
	for _i in 500:
		if not CG.is_busy():
			break
		CG._can_skip = true
		CG.skip()
		if Dialogue.is_active():
			Dialogue.advance()
		await _wait(0.02)
	await _wait(0.2)


func _identity_cgs() -> void:
	for c in [d.pink, d.blue]:
		await _reset()
		var p := _puppet()
		var swap := SiegeTools.move(p, [d.pink, d.blue], [d.blue.global_position, d.pink.global_position], true)
		p.register_field(swap)
		await _wait(0.55)
		GameState.switch_control(d.blue if c == d.pink else d.pink)
		var depth := Characters._scope.size()
		c.health.max_hp = 1
		c.health.set_hp(1)
		c._full_invuln = 0
		c.receive_hit(p.make_tickle(c, 500))
		for _i in 100:
			if CG.is_playing():
				break
			await _wait(0.025)
		check("real swap defeat binds victim " + c.character_id, CG.current == "death_siege_puppet_master" and CG.character_id == c.character_id)
		var actor: CGActor = CG.actors.get("princess")
		var expected := CGActor.make_princess("comparison", c.character_id)
		check("stage sprite matches victim " + c.character_id, actor != null and actor.sprite.texture == expected.sprite.texture)
		expected.free()
		check("CG does not hold global role scope " + c.character_id, Characters._scope.size() == depth)
		for _i in 100:
			if Dialogue.is_active():
				break
			await _wait(0.02)
		check("dialogue identifies CG owner " + c.character_id, Dialogue.line_character == c.character_id and Dialogue.active_set() == c.character_id)
		check("CG placeholder uses victim portrait " + c.character_id, CG.portrait_texture("helpless_1") == Dialogue.portrait_for("helpless_1", c.character_id))
		await _shot("swap_cg_" + c.character_id)
		await _finish_cgs()
	await _reset()
	var p := _puppet()
	var swap := SiegeTools.move(p, [d.pink, d.blue], [d.blue.global_position, d.pink.global_position], true)
	p.register_field(swap)
	await _wait(0.55)
	var seen := []
	var record := func(_id: String): seen.append(CG.character_id)
	CG.started.connect(record)
	for c in [d.pink, d.blue]:
		c.health.max_hp = 1
		c.health.set_hp(1)
		c._full_invuln = 0
		c.receive_hit(p.make_tickle(c, 500))
	await _wait(1.0)
	check("two real defeat callbacks queue separate roles", CG.is_playing() and CG._queue.size() == 1 and CG.character_id != CG._queue[0]["character_id"])
	await _finish_cgs()
	check("both real victims get matching CGs", seen.size() == 2 and seen.has("pink") and seen.has("blue") and Characters._scope.is_empty())
	CG.started.disconnect(record)
	await _reset()
	p = _puppet()
	d.pink.health.max_hp = 1
	d.pink.health.set_hp(1)
	d.pink.receive_hit(p.make_tickle(d.pink, 500))
	await _wait(13.1)
	check("down sequence timeout cannot change unfinished CG identity", CG.is_playing() and CG.character_id == "pink" and Characters._scope.is_empty() and d.pink.is_alive())
	await _finish_cgs()
	await _reset()
	var done := []
	var play := func(who: String):
		await CG.play_death("puppet_master", who)
		done.append(who)
	play.call("pink")
	play.call("blue")
	check("queued CG snapshots both identities", CG.character_id == "pink" and CG._queue.size() == 1 and CG._queue[0]["character_id"] == "blue")
	GameState.switch_control(d.blue)
	await _wait(0.1)
	check("control switch cannot change active stage", CG.character_id == "pink" and CG.render_character() == "pink")
	CG._can_skip = true
	CG.skip()
	for _i in 100:
		if CG.character_id == "blue" and CG.is_playing():
			break
		await _wait(0.02)
	check("next queued CG starts with its own actor data", CG.character_id == "blue" and CG.is_playing() and done.has("pink"))
	check("partner portrait remains explicitly blue while another hero active", CG.portrait_texture("helpless_1", "pink") == Dialogue.portrait_for("helpless_1", "pink"))
	await _finish_cgs()
	check("queue completion leaves no character scope", done.size() == 2 and Characters._scope.is_empty())
	var first := {"cast": {"princess": {"kind": "princess"}}, "steps": [{"speaker": "公主", "text": "自动推进的第一段", "auto": 0.3}]}
	var second := {"cast": {"princess": {"kind": "princess"}}, "steps": [{"speaker": "蓝色的公主", "text": "下一位角色的台词仍应等待玩家"}]}
	var request := func(cg: Dictionary, who: String):
		await CG._request({"cg": cg, "id": "test:auto", "source": "", "skippable": true, "fx": 0, "character_id": who}, false)
	request.call(first, "pink")
	request.call(second, "blue")
	await _wait(0.04)
	CG.skip()
	await _wait(0.38)
	check("old automatic advance cannot close next character line", CG.is_playing() and CG.character_id == "blue" and Dialogue.is_active() and Dialogue.line_character == "blue")
	await _finish_cgs()
	GameState.switch_control(d.pink)
	await _reset()


func _members(team: Dictionary) -> Actor:
	d.wave = 12
	var lead: Actor
	var first := str(team["members"][0]["key"])
	if first.begins_with("enemy_"):
		lead = _tower9(first.trim_prefix("enemy_"), Vector2(844, 970))
	var made := d.teamwork.spawn_formation(str(team["id"]), Vector2(864, 970))
	if lead == null:
		lead = made[0]
	for m in made:
		m.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	if lead is TwinGhost:
		lead.twin.set_physics_process(false)
	if team["id"] == "bell_repair":
		lead.health.damage(20)
	if team["id"] == "shield_melt":
		var tower := IceTower.new()
		tower.kind = "icicle"
		tower.position = Vector2(880, 1040)
		d.entities().add_child(tower)
	return lead


func _joint_effects() -> void:
	for team in new_teams:
		if _option("teams") != "" and not _option("teams").split(",").has(team["id"]):
			continue
		await _reset()
		var lead: Actor = await _members(team)
		var before := d.pink.laugh.value
		var hp := lead.health.hp
		var hits := []
		var record := func(h: HitData):
			if h.reaction_variant == team["id"] or (team["id"] == "web_battery" and h.reaction_variant == "battery" and h.source == lead):
				hits.append(h.zone)
		d.pink.tickled.connect(record)
		check("member matching fires " + team["id"], d.teamwork.try_fire(team["id"], lead))
		check("shared cooldown prevents repeated " + team["id"], not d.teamwork.try_fire(team["id"], lead))
		await _wait(float(team["windup"]) + 0.06)
		check("short windup creates real effect " + team["id"], get_tree().get_nodes_in_group("siege_cooperation").size() == 1)
		await _shot("skill_" + str(team["id"]))
		await _wait(float(SiegeCooperation.LIFE[team["id"]]) + 0.15)
		check("completed effect cleans up " + team["id"], get_tree().get_nodes_in_group("siege_cooperation").is_empty() and not d.pink.status.is_grabbed() and not d.pink.is_force_moving())
		if team["id"] in ["hook_haunt", "bubble_roll", "magic_recoil", "twin_relay", "glue_roll", "web_battery"]:
			check("joint hits reach real weakness " + team["id"], not hits.is_empty() and hits.all(func(z): return z == "sole"))
		if team["id"] == "bell_repair":
			check("repair heals fifteen percent after full channel", lead.health.hp == hp + int(round(lead.health.max_hp * 0.15)))
		if team["id"] == "drop_hook":
			check("coordinated drop retains normal four soldier count", EnemyTowerTools.pending(lead) == 4)
		d.pink.tickled.disconnect(record)
		await _reset()
		lead = await _members(team)
		check("second fixture fires " + team["id"], d.teamwork.try_fire(team["id"], lead))
		await _wait(float(team["windup"]) + 0.05)
		var action := get_tree().get_nodes_in_group("siege_cooperation")[0] as SiegeCooperation.JointAction
		var last := action.members.back().get_ref() as Monster
		last.stun(1.0)
		await _wait(0.06)
		check("freeze cancels and releases " + team["id"], get_tree().get_nodes_in_group("siege_cooperation").is_empty() and not d.pink.status.is_grabbed() and not d.pink.is_force_moving())
		check("freeze restores moving AI " + team["id"], d.monsters.all(func(m): return not SiegeTools.alive(m) or not m.get_meta("team_transfer", false)))
		if lead is EnemyTower:
			await _reset()
			lead = await _members(team)
			d.teamwork.try_fire(team["id"], lead)
			await _wait(float(team["windup"]) + 0.06)
			lead.health.damage(999)
			await _wait(0.1)
			check("tower destruction cancels dependent collaboration " + team["id"], get_tree().get_nodes_in_group("siege_cooperation").is_empty() and not d.pink.status.is_grabbed() and not d.pink.is_force_moving())
	await _reset()


func _pressure() -> void:
	DevConfig.override = true
	d.wave = 12
	d.state = "prep"
	var deployed := SiegeDevTools.deploy_towers(d)
	var first := SiegeDevTools.upgrade_towers(d)
	var second := SiegeDevTools.upgrade_towers(d)
	var towers := get_tree().get_nodes_in_group("siege_tower")
	check("pressure fixture has thirty actual max level towers", deployed == 30 and first == 30 and second == 30 and towers.size() == 30 and towers.all(func(t): return t.level == 3))
	d.state = "fight"
	for i in 160:
		d.spawn("slime" if i % 2 == 0 else "rat", "", Vector2(200 + i % 20 * 65, 1040 + i / 20 * 20))
	await _wait(0.3)
	var start := Time.get_ticks_usec()
	for _i in 8:
		d.teamwork.scan()
	var ms := float(Time.get_ticks_usec() - start) / 8000.0
	check("160 mobs and thirty max towers scan under 40ms", ms < 40.0)
	print("cooperation scan average: %.3f ms" % ms)
	await _shot("pressure")
	d.state = "prep"
	SiegeDevTools.clear_test_towers(d)
	DevConfig.override = false
	await _reset()
	check("cleanup leaves no collaboration fields", get_tree().get_nodes_in_group("siege_cooperation").is_empty())


func _shot(label: String) -> void:
	if OS.get_environment("SIEGE_COOP_CAPTURE") != "1" and not OS.get_cmdline_user_args().has("--capture-coop"):
		return
	if CG.is_playing() and label.begins_with("swap_cg_"):
		for _i in 100:
			if CG.step_index >= 5:
				break
			if Dialogue.is_active():
				Dialogue.advance()
				Dialogue.advance()
			await _wait(0.025)
		if Dialogue.is_active():
			Dialogue.advance()
	if not CG.is_playing():
		d.cam.set_process(false)
		var cam := GameState.player.camera
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		cam.zoom = Vector2.ONE
		cam.global_position = Vector2(864, 930)
		if label == "twins":
			for actor in d.monsters:
				if is_instance_valid(actor) and actor is TwinGhost and is_instance_valid(actor.twin):
					cam.global_position = (actor.global_position + actor.twin.global_position) * 0.5
					break
		elif label == "pressure":
			cam.zoom = Vector2(0.2, 0.2)
			cam.global_position = d.map_size() * 0.5
		cam.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://doc/siege_cooperation_images/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	get_viewport().get_texture().get_image().save_png(folder + label + ".png")


func _option(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + key + "="):
			return arg.trim_prefix("--" + key + "=")
	return ""
