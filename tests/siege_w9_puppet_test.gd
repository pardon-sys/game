extends SiegeFixture
## 第 9 波小 Boss「狂欢挠痒魔偶师」、双子痒痒鬼、新敌塔（空投站 / 刷具轰击塔 / 共振钟楼）与真实换位的回归。


func _ready() -> void:
	fixture_wave = 9
	await _boot()
	var only := OS.get_environment("SIEGE9_ONLY")
	for part in ["data", "twins", "boss", "moves", "towers", "relay", "texts", "defeat", "perf"]:
		if only == "" or only.split(",").has(part):
			await call("_" + part + "9")
	await _reset()
	print("SIEGE9: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _data9() -> void:
	check("twin grace is eight seconds", TwinGhost.PAIR_TIME == 8.0)
	var wave: Dictionary = d.data["waves"][8]
	check("wave9 boss enters at16s", wave.get("boss") == "puppet_master" and wave["groups"].any(func(g): return g.get("monster") == "puppet_master" and g["delay"] == 16))
	check("six existing escorts reserved", wave["boss_escort"].size() == 3 and ["vine", "ghost", "thigh_spider"].all(func(k): return int(wave["boss_escort"].get(k, 0)) == 2))
	check("13 enemy towers registered", EnemyTower.kinds().size() == 13)
	for pair in [[3, "airdrop"], [5, "brush_battery"], [7, "resonance"]]:
		var first: int = pair[0]
		var key: String = pair[1]
		check("tower %s opens wave%d" % [key, first], not d.data["waves"][first - 2]["enemy_towers"].has(key) and d.data["waves"][first - 1]["enemy_towers"].has(key))
		check("first new tower prioritized", d.data["waves"][first - 1]["priority_enemy_towers"].has(key))
	check("legacy hp50percent and interval20percent", EnemyTower.info("portal")["hp"] == 24 and is_equal_approx(EnemyTower.info("portal")["interval"], 2.4))
	check("new tower final values not rescaled", EnemyTower.info("airdrop")["hp"] == 42 and EnemyTower.info("airdrop")["interval"] == 12)
	for key in SiegeBoss.cd_table("puppet_master"):
		check("short cue %s" % key, SiegeBoss.warn_table("puppet_master")[key] >= 0.1 and SiegeBoss.warn_table("puppet_master")[key] <= 0.18)
	await _reset()


func _twins9() -> void:
	# 单调时钟从进程启动计时；回溯8秒前须先让时钟超过8秒，避免撞上负数哨兵。
	await _wait(maxf(0.01, 8.3 - Time.get_ticks_msec() / 1000.0))
	var a := d.spawn("twin_ghost", "", Vector2(700, 930)) as TwinGhost
	await _wait(0.05)
	var b := a.twin
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.health.damage(999)
	a._down_at = Time.get_ticks_msec() / 1000.0 - 7.8
	b.health.damage(999)
	await _wait(0.05)
	check("late7.8s followup finishes twins", not is_instance_valid(a) and not is_instance_valid(b))
	a = d.spawn("twin_ghost", "", Vector2(700, 930)) as TwinGhost
	await _wait(0.05)
	b = a.twin
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.health.damage(999)
	a._down_at = Time.get_ticks_msec() / 1000.0 - 8.1
	b.health.damage(999)
	check("8.1s callback revives first even before AI tick", is_instance_valid(a) and a.is_alive() and a.health.hp == a.health.max_hp and not b.is_alive())
	await _reset()


func _boss9() -> void:
	var p := _puppet()
	check("boss420hp and all eight skills initially ready", p.health.max_hp == 420 and p.cds.size() == 8 and p.cds.values().all(func(v): return v == 0))
	check("live wave9 boss blocks progression", d.boss_alive())
	var t := _tower9("glue")
	var before := p.health.hp
	# 使用真实友方塔来源，来源减伤由 SiegeBoss 结算。
	var ice := IceTower.new()
	ice.kind = "icicle"
	d.entities().add_child(ice)
	p.receive_hit(HitData.make_attack(ice, 4))
	check("tower damage25percent", before - p.health.hp == 1)
	p._attack_invuln = 0
	before = p.health.hp
	p.receive_hit(HitData.make_attack(d.pink, 4))
	check("princess full damage", before - p.health.hp == 4)
	t.queue_free()
	for key in p.cds:
		p.cds[key] = 99
	p.global_position.y = d.wall_foot_y() + 10
	p._tick(0.02)
	check("prehalf body stays lower map", p.global_position.y >= p.min_y())
	p.health.damage(220)
	p._tick(0.02)
	check("halfhealth rage and no boundary", p.raged and p.min_y() == -INF and p.cds.values().all(func(v): return v < 3))
	p.health.damage(999)
	check("defeating wave9 boss clears boss gate", not d.boss_alive())
	await _reset()
	p = _puppet()
	for key in ["vine", "ghost", "thigh_spider", "hug_bear"]:
		d.spawn(key, "", p.global_position + Vector2(24, 24)).set_physics_process(false)
	p.set_physics_process(true)
	await _wait(3.0)
	check("real AI at most3casts3seconds", p.used.size() >= 1 and p.used.size() <= 3)
	await _wait(3.0)
	check("real AI retains field tether winch brush order over six seconds", p.used.has("cross") and p.used.has("tether") and p.used.has("winch") and p.used.has("brush"))
	await _reset()
	p = _puppet()
	for key in SiegeBoss.cd_table("puppet_master"):
		if key == "relay":
			continue
		p._execute(key)
		check("skill effect executes %s" % key, p._fields.size() > 0)
		await _wait(0.03)
	check("max8brush fields", p.brush_fields().size() <= 8)
	p._clear_all()
	await _wait(0.05)
	check("clear releases both and restores physics", not d.pink.status.is_grabbed() and not d.blue.status.is_grabbed() and d.pink.is_physics_processing() and d.blue.is_physics_processing())
	await _reset()


func _moves9() -> void:
	var p := _puppet()
	var a := d.pink.global_position
	var b := d.blue.global_position
	var move := SiegeTools.move(p, [d.pink, d.blue], [b, a], true)
	check("real swap acquires both", move != null and d.pink.status.is_grabbed_by(move) and d.blue.status.is_grabbed_by(move))
	p.register_field(move)
	await _wait(0.55)
	check("real swap changes planes permanently", d.is_on_wall(d.pink) and not d.is_on_wall(d.blue) and d.blue.global_position.distance_to(a) < 8)
	check("swap restores collision and physical control", d.pink.collision_mask != 0 and d.blue.collision_mask != 0 and d.pink.is_physics_processing() and d.blue.is_physics_processing())
	check("fallen timer reset for ground blue AI", d.fallen_for(d.blue) < 1.0)
	var wall_mob := d.spawn("ghost", "", d.pink.global_position + Vector2(24, 0))
	wall_mob.set_physics_process(false)
	TeamworkEffects.put_on_wall(wall_mob, wall_mob.global_position)
	(wall_mob.mind as SiegeMind).wall_top(wall_mob, 0.05)
	check("wall mobs chase pink after real swap", wall_mob.target == d.pink)
	for i in 4:
		p._t += 0.2
		SiegeTools.strike(p, d.blue, 1.0, i, "brush")
		check("blue afterswap tool part%d" % i, d.blue.last_tickle.zone == ("thigh" if i < 2 else "butt"))
	p._t += 0.2
	SiegeTools.strike(p, d.pink, 1, 0, "brush")
	check("pink onwall keeps sole weakness", d.pink.last_tickle.zone == "sole")
	await _reset()
	p = _puppet()
	a = d.pink.global_position
	move = SiegeTools.move(p, [d.pink], [a + Vector2(160, 0)])
	p.register_field(move)
	await _wait(0.2)
	GameState.in_cutscene = true
	var pos := d.pink.global_position
	await _wait(0.2)
	check("move pauses during cutscene", d.pink.global_position == pos and d.pink.is_force_moving())
	GameState.in_cutscene = false
	p._stun_left = 1.0
	p._on_stunned(1.0)
	await _wait(0.05)
	check("freeze immediately cancels movement and releases", not d.pink.get_meta("siege_puppet_move", false) and not d.pink.status.is_grabbed() and d.pink.is_physics_processing())
	check("ordinary move bounded160", d.pink.global_position.distance_to(a) <= 160)
	await _reset()
	p = _puppet()
	for key in p.cds:
		p.cds[key] = 99
	p.set_physics_process(true)
	a = d.pink.global_position
	var field := SiegeTools.BrushField.new()
	field.source = weakref(p)
	field.position = a + Vector2(80, 0)
	d.entities().add_child(field)
	p.register_field(field)
	move = SiegeTools.move(p, [d.pink], [a + Vector2(160, 0)])
	p.register_field(move)
	await _wait(0.65)
	check("forced path actually triggers brushfield", d.pink.laugh.value > 0 and d.pink.last_tickle.reaction_variant == "cross")
	await _reset()
	p = _puppet()
	a = d.pink.global_position
	var block := _tower9("glue", a + Vector2(72, 0))
	move = SiegeTools.move(p, [d.pink], [a + Vector2(160, 0)])
	p.register_field(move)
	await _wait(0.65)
	check("winch collision does not tunnel through tower", d.pink.global_position.x < block.global_position.x)
	await _reset()
	p = _puppet()
	var other := d.spawn("hug_bear", "", Vector2(600, 900))
	other.set_physics_process(false)
	d.pink.status.grab(other, 4, 16)
	check("foreign restraint is not stolen", SiegeTools.hold(p, d.pink, d.pink.global_position) == null and d.pink.status.is_grabbed_by(other))
	await _reset()
	p = _puppet()
	var hold := SiegeTools.hold(p, d.blue, d.blue.global_position, true, 3)
	p.register_field(hold)
	await _wait(0.1)
	check("lift reuses visible lifted buff animation", d.blue.sprite.position.y < 0)
	p.health.damage(999)
	await _wait(0.05)
	check("death releases lift and spriteoffset", not d.blue.status.is_grabbed() and not d.blue.has_buff("lifted") and d.blue.sprite.position.y == 0)
	await _reset()


func _towers9() -> void:
	var t := _tower9("airdrop")
	for _i in 6:
		EnemyTowerTools.attack(t)
	check("pending aircraft count capped16", EnemyTowerTools.pending(t) == 16)
	await _wait(0.7)
	check("sixteen soldiers really land", EnemyTowerTools.pending(t) == 16 and d.monsters.size() == 16)
	check("wall and ground airdrops", d.monsters.any(func(m): return m.get_meta("siege_on_wall", false)) and d.monsters.any(func(m): return not m.get_meta("siege_on_wall", false)))
	var victim: Monster = d.monsters[0]
	victim.health.damage(999)
	await _wait(0.05)
	EnemyTowerTools.attack(t)
	check("airdrop replenishes dead slots", EnemyTowerTools.pending(t) == 16)
	t.health.damage(999)
	await _wait(0.05)
	check("destroy cancels pending but landed live troops remain", EnemyTowerTools.pending() == 15)
	await _reset()
	for _i in 4:
		t = _tower9("airdrop", Vector2(700 + _i * 48, 960))
		for _j in 4:
			EnemyTowerTools.attack(t)
	check("all towers sharedcap48", EnemyTowerTools.pending() == 48)
	await _reset()
	for wall in d.walls:
		wall.shield_left = 5.0
	t = _tower9("airdrop")
	EnemyTowerTools.attack(t)
	await _wait(0.7)
	check("reinforced wall redirects air troops to ground", d.monsters.size() == 4 and d.monsters.all(func(m): return not m.get_meta("siege_on_wall", false) and m.global_position.y >= d.wall_foot_y()))
	await _reset()
	t = _tower9("brush_battery")
	d.blue.global_position = t.global_position + Vector2(80, 0)
	EnemyTowerTools.attack(t)
	await _wait(0.7)
	check("battery applies root and correctblue parts", d.blue.status.is_rooted() and d.blue.last_tickle != null and d.blue.last_tickle.zone in ["thigh", "butt"])
	t.health.damage(999)
	await _wait(0.03)
	var value := d.blue.laugh.value
	await _wait(0.2)
	check("destroy stops remaining brush attack callbacks", d.blue.laugh.value <= value)
	await _reset()
	var a := _tower9("resonance")
	var b := _tower9("resonance", a.global_position + Vector2(60, 0))
	d.pink.global_position = a.global_position + Vector2(90, 0)
	var m := d.spawn("slime", "", a.global_position + Vector2(80, 30))
	m.set_physics_process(false)
	var base_cd := m.stat_mul("tickle_cd")
	# 攻防战的难度状态（siege_hard）本来就乘了挠痒力度：钟楼的 ×1.2 叠在它上面
	var base_power := m.stat_mul("tickle_power")
	await get_tree().physics_frame
	EnemyTowerTools.aura(a)
	EnemyTowerTools.aura(b)
	check("multiplebells maxstack1", m.buff_stacks("siege_resonant") == 1 and is_equal_approx(m.stat_mul("tickle_power"), base_power * 1.2))
	check("actual monster hit carries20percent stronger tickle", is_equal_approx(m.make_tickle(d.pink, 10.0).tickle, 10.0 * base_power * 1.2))
	check("monster attack frequency1.3", is_equal_approx(m.stat_mul("tickle_cd"), base_cd / 1.3))
	var f := EquipFx.of(d.pink)
	check("equipment unique nonstacking modifier", f.has_mod("siege_resonance"))
	var target := _tower9("glue", a.global_position + Vector2(40, 0))
	check("bell supports old enemy towers", EnemyTowerTools.bell_at(target))
	a.health.damage(999)
	check("secondbell preserves aura", m.has_buff("siege_resonant") and f.has_mod("siege_resonance"))
	b.health.damage(999)
	check("lastbell removal clears all own boosts", not m.has_buff("siege_resonant") and not f.has_mod("siege_resonance") and not EnemyTowerTools.bell_at(target))
	await _reset()


func _relay9() -> void:
	var p := _puppet()
	d.blue.global_position = Vector2(p.global_position.x + 48, d.wall_top_y() + 4)
	for key in ["vine", "ghost", "thigh_spider", "hug_bear"]:
		var m := d.spawn(key, "", p.global_position + Vector2(24, 24))
		m.set_physics_process(false)
	var t := _tower9("airdrop", p.global_position + Vector2(90, 40))
	await get_tree().physics_frame
	var count := d.monsters.size()
	var fired := d.teamwork.try_fire("puppet_relay", p)
	await _wait(0.7)
	check("bosscommand relay runs existing teamwork", fired and d.teamwork.history.has("puppet_relay"))
	check("relay moves existing troops without duplicate", d.monsters.size() == count and d.monsters.any(func(m): return m != p and m.get_meta("siege_on_wall", false)))
	check("relay accelerates newtower without bypass loops", t._command_left > 0)
	d.teamwork._cd.clear()
	for m in d.monsters:
		m.set_meta("team_busy", 0.0)
		m.global_position = p.global_position + Vector2(16, 24)
	d.teamwork.try_fire("puppet_relay_rage", p)
	await _wait(0.18)
	p.stun(2.0)
	await _wait(0.05)
	check("freeze cancels relay passengers and resumes AI", d.monsters.all(func(m): return not m.get_meta("team_transfer", false) and (m == p or m.is_physics_processing())))
	await _reset()


func _texts9() -> void:
	for role in ["pink", "blue"]:
		var path := "res://data/characters/blue/reactions.json" if role == "blue" else "res://data/princess_reactions.json"
		var rx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var entry: Dictionary = rx["sources"]["puppet_master"]
		for key in SiegeBoss.cd_table("puppet_master"):
			check("%s authored variant%s" % [role, key], entry["variants"].has(key) and entry["variants"][key].values().all(func(v): return v.size() >= 2))
		for key in ["airdrop", "brush_battery", "resonance"]:
			check("%s tower reaction%s" % [role, key], rx["sources"].has("enemy_" + key))
		var cgpath := "res://data/characters/blue/siege_cgs.json" if role == "blue" else "res://data/siege_cgs.json"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cgpath))
		var cg: Dictionary = data["cgs"]["death_siege_puppet_master"]
		var lines: Array = cg["steps"].filter(func(st): return st.has("text"))
		var acts := {}
		for step in cg["steps"]:
			var a: Variant = step.get("act", "")
			acts[str(int(a)) if a is float else str(a)] = true
		check("%s standalone 4-act CG (%d lines) and atlas sprite" % [role, lines.size()], lines.size() >= 38 and acts.has("burst") and acts.has("4") and data["actors"]["puppet_master"]["sprite"]["key"] == "puppet_master_0")
		for step in cg["steps"]:
			for action in step.get("actions", []):
				if action["do"] == "tickle" and action.has("zone"):
					check("%s CG correct bodyparts and nonfeather tools" % role, action["zone"] in (["thigh", "butt"] if role == "blue" else ["sole"]) and action["fx"] in ["hand", "brush", "pinch"])
	# 同时存在旧符文和Boss连线：转发命中不再次转发。
	var p := _puppet()
	p._execute("link")
	var legacy := HazardLinkRune.new()
	legacy.auto_link = true
	legacy.position = Vector2(720, 930)
	d.entities().add_child(legacy)
	var echoes := [0]
	var callback := func(h: HitData):
		if h.tag == "tickle_echo":
			echoes[0] += 1
	d.blue.tickled.connect(callback)
	SiegeTools.strike(p, d.pink, 1, 0, "brush")
	check("multiplelinks no recursive echoes", echoes[0] == 2 and d.blue.last_tickle.tag == "tickle_echo")
	d.blue.tickled.disconnect(callback)
	await _reset()


func _defeat9() -> void:
	for c in [d.pink, d.blue]:
		await _reset()
		var p := _puppet()
		c.health.max_hp = 1
		c.health.set_hp(1)
		var h := p.make_tickle(c, 500.0)
		h.zone = "sole" if c.character_id == "pink" else "thigh"
		h.reaction_variant = "brush"
		c.receive_hit(h)
		for _i in 80:
			if CG.is_busy():
				break
			await _wait(0.05)
		check("actual puppet defeat opens proper character CG " + c.character_id, CG.current == "death_siege_puppet_master" and CG.character_id == c.character_id)
		CG._can_skip = true
		CG.skip()
		for _i in 80:
			if not CG.is_busy():
				break
			Dialogue.advance()
			await _wait(0.02)
		await _wait(0.2)
	await _reset()


func _perf9() -> void:
	for c in [d.pink, d.blue]:
		c.set_invulnerable(10.0, true)
	var p := _puppet()
	p._cast_raged = true
	p._execute("cross")
	p._execute("cross")
	for i in 1000:
		var m := d.spawn("slime", "", Vector2(200 + i % 50 * 26, 500 + i / 50 * 26))
		m.set_physics_process(true)
	for i in 3:
		var t := _tower9("airdrop", Vector2(500 + i * 180, 1050))
		for _j in 4:
			EnemyTowerTools.attack(t)
	var bell := _tower9("resonance", Vector2(780, 900))
	bell._t = 0
	await _wait(0.7)
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 2_000_000:
		await get_tree().physics_frame
		frames += 1
	var avg := float(Time.get_ticks_usec() - start) / 1000.0 / frames
	check("1000mobs+boss+8fields+48airdrop %.1fms/frame (mobs%d fields%d drops%d)" % [avg, d.monsters.size(), p.brush_fields().size(), EnemyTowerTools.pending()], avg <= 33 and d.monsters.size() >= 1000 and p.brush_fields().size() == 8 and EnemyTowerTools.pending() == 48)
	await _reset()
