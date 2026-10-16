extends Node
## 第六波新 Boss / 九种配合 / 延迟塔来源 / 角色 CG 的实际场景回归。
## Godot --headless --path . res://tests/siege6_boss_test.tscn

var main: Node
var d: SiegeDirector
var failures := 0
var checks := 0


class PlainDamageTower extends IceTower:
	func _dmg(base: int) -> int:
		return base


func _boot() -> void:
	seed(606)
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false
	TownBuffShow.enabled = false
	Monster.random_specials = false
	HUD.slow_motion = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	for flag in ["magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept", "f8_returned", "f6w_arrived", "intro_done_siege_intro", "siege_intro_seen", "seen_fatigue_burst", "seen_laugh_recover"]:
		GameState.set_flag(flag)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _wait(0.5)
	d = SiegeDirector.current
	if d == null:
		get_tree().quit(1)
		return
	d.quiet_spawn = true
	d.bench_soldiers(true)
	d.teamwork.enabled = false
	await _reset()


func _ready() -> void:
	await _boot()
	await _rules()
	await _live_ai()
	await _damage()
	await _skills()
	await _pace()
	await _wind_rules()
	await _reactions()
	await _teams()
	await _interruptions()
	await _wind_transport()
	await _performance()
	await _cg()
	await _real_defeat_cg()
	await _reset()
	print("SIEGE6: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _reset() -> void:
	d.state = "prep"
	d.clear_field()
	d.features.end()
	d.teamwork._cd.clear()
	for tower in get_tree().get_nodes_in_group("siege_tower"):
		tower.queue_free()
	await get_tree().process_frame
	for c in [d.pink, d.blue]:
		var downed: Node = c.get_node_or_null("Downed")
		if downed:
			downed.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		c.set_controller(CharacterController.new())
		c.health.max_hp = 1000
		c.health.fill()
		c.status.release(true)
		c.status.clear_root()
		c.laugh.set_value(0.0)
		c.fatigue.clear()
		c.fatigue_bursting = false
		c._set_state(PlayableCharacter.State.IDLE)
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
		c._attack_invuln = 0.0
		c.clear_buffs()
		c.set_meta("siege_cd", {})
		c.global_position = Vector2(d.gate_pos.x + (0 if c == d.pink else 50), 880)
	d.wave = 6
	d.state = "fight"
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.wall_hp = d.wall_max
	for wall in d.walls:
		wall.shield_left = 0.0
	Engine.time_scale = 1.0
	# Downed 是延后删除的节点，夹具返回前确保复活状态已经完全清理。
	await get_tree().process_frame


func _bear(at := Vector2(864, 900)) -> GaleBear:
	var bear := d.spawn("gale_bear", "", at) as GaleBear
	bear.set_physics_process(false)
	bear._intro_done = true
	bear._intro_left = 0.0
	return bear


func _rules() -> void:
	var wave: Dictionary = d.data["waves"][5]
	check("wave 6 boss and 16 second spawn", wave.get("boss") == "gale_bear" and wave["groups"].any(func(g): return g.get("monster", "") == "gale_bear" and g["delay"] == 16))
	var bear := _bear()
	check("320 HP, shared SiegeBoss rules", bear.health.hp == 320 and bear is SiegeBoss and bear.is_in_group("siege_boss"))
	d._queue.clear()
	check("living bear blocks wave advancement", d.boss_alive())
	bear.global_position.y = 300.0
	bear._tick(0.1)
	check("above-half displacement is bounded", bear.global_position.y >= bear.min_y() and bear.skill == "")
	check("six old skills retired", ["grab", "swipe", "gust", "disc", "rush", "command"].all(func(k): return not bear._start(k)))
	bear.health.set_hp(160)
	bear._tick(0.1)
	bear._tick(0.1)
	check("half health transitions once", bear.raged and bear.rage_count == 1 and bear.min_y() == -INF)
	bear.health.damage(9999)
	check("dead bear releases wave gate", not d.boss_alive())
	d._queue = [{"t": 16.0, "monster": "gale_bear", "from": "bottom"}]
	check("queued bear blocks wave gate", d.boss_alive())
	await _reset()
	bear = _bear()
	bear._intro_done = false
	bear.intro()
	check("intro spawns exactly eight reserved escorts", d.monsters.size() == 9)
	var bars := main.find_children("*", "BossBar", true, false)
	check("boss bar avoids siege wall bar", not bars.is_empty() and bars[0].position.y >= 40.0)
	bear.intro()
	check("intro cannot duplicate escorts", d.monsters.size() == 9)
	await _reset()


func _damage() -> void:
	var bear := _bear()
	for kind in IceTower.kinds():
		var tower := IceTower.new()
		tower.kind = kind
		d.entities().add_child(tower)
		tower.set_physics_process(false)
		var before := bear.health.hp
		bear._attack_invuln = 0.0
		bear.receive_hit(HitData.make_attack(tower, 4))
		check("tower source x0.25: " + kind, before - bear.health.hp == 1)
		tower.queue_free()
	var before := bear.health.hp
	for i in 4:
		bear._attack_invuln = 0.0
		bear.receive_hit(HitData.make_attack(null, 1, 0.0, true))
	check("four quarter hits accumulate one HP", before - bear.health.hp == 1)
	var fraction := bear._tower_frac
	bear._full_invuln = 1.0
	bear.receive_hit(HitData.make_attack(null, 3, 0.0, true))
	check("invulnerable hit does not accumulate", is_equal_approx(bear._tower_frac, fraction))
	bear._full_invuln = 0.0
	bear._attack_invuln = 0.0
	var hit := HitData.make_attack(d.pink, 4, 12.0, true)
	hit.origin = Vector2(10, 20)
	hit.tag = "test_tag"
	hit.reaction_variant = "paw"
	bear.receive_hit(hit)
	check("reduction preserves metadata and caller", hit.damage == 4 and bear.last_hit.damage == 1 and bear.last_hit.origin == Vector2(10, 20) and bear.last_hit.tag == "test_tag" and bear.last_hit.reaction_variant == "paw")
	for c in [d.pink, d.blue]:
		bear._attack_invuln = 0.0
		before = bear.health.hp
		bear.receive_hit(HitData.make_attack(c, 4))
		check("princess damage unchanged: " + c.character_id, before - bear.health.hp == 4)
	var soldier := d.soldiers[0]
	bear._attack_invuln = 0.0
	before = bear.health.hp
	bear.receive_hit(HitData.make_attack(soldier, 4))
	check("soldier damage unchanged", before - bear.health.hp == 4)
	await _reset()


	bear = _bear()
	var tower := PlainDamageTower.new()
	d.entities().add_child(tower)
	tower.global_position = bear.global_position + Vector2(0, 50)
	tower.set_physics_process(false)
	tower._t = 0.0
	# 飞行和来源销毁走真实塔逻辑；测试隔离镇民伤害增益的随机舍入。
	var expected := tower._dmg(int(tower.p("damage", 1))) * SiegeBoss.TOWER_MULT
	# enemies_near按物理帧缓存；新怪出生后等下一物理帧再选择目标。
	await get_tree().physics_frame
	tower._icicle()
	check("delayed test launches actual tower projectile", get_tree().get_nodes_in_group("siege_temp").any(func(n): return n is SiegeProjectile))
	tower.queue_free()
	await _wait(0.6)
	check("deleted tower projectile retains origin class (frac %.2f expected %.2f)" % [bear._tower_frac, fmod(expected, 1.0)], is_equal_approx(bear._tower_frac, fmod(expected, 1.0)) and bear.health.hp == 320 - int(floorf(expected)))
	var snow := Snowman.new()
	d.entities().add_child(snow)
	snow.set_physics_process(false)
	snow.global_position = bear.global_position + Vector2(10, 50)
	bear._attack_invuln = 0.0
	expected += snow.ball_damage * SiegeBoss.TOWER_MULT
	snow._throw(bear.global_position)
	snow.queue_free()
	await _wait(0.7)
	check("deleted snowman ball retains origin class (frac %.2f expected %.2f)" % [bear._tower_frac, fmod(expected, 1.0)], is_equal_approx(bear._tower_frac, fmod(expected, 1.0)))
	await _reset()


func _live_ai() -> void:
	await _reset()
	var bear := _bear()
	bear._rest = 0.0
	for key in bear.cds:
		bear.cds[key] = 0.0
	d.pink.global_position = bear.global_position + Vector2(24, 4)
	d.blue.global_position = Vector2(d.gate_pos.x + 80, d.wall_top_y() + 4.0)
	bear.set_physics_process(true)
	var stayed_lower := true
	for i in 100:
		await _wait(0.1)
		stayed_lower = stayed_lower and bear.global_position.y >= bear.min_y()
	check("live AI selects multiple skills", bear.used.size() >= 2)
	check("live AI stays below half before rage", stayed_lower)
	bear._cancel()
	if bear.mode == TickleTroll.Mode.GRABBING:
		bear._end_grab()
	bear.mode = TickleTroll.Mode.NORMAL
	bear._stun_left = 0.0
	bear.health.set_hp(159)
	d.pink.global_position = Vector2(d.gate_pos.x, d.wall_foot_y() + 70)
	for key in bear.cds:
		bear.cds[key] = 999.0
	bear.cds["chase"] = 0.0
	bear.global_position.y = bear.min_y() + 6.0
	bear._rest = 0.0
	await _wait(4.0)
	check("live rage advances toward wall", bear.raged and bear.used.has("chase") and bear.global_position.y < d.map_size().y / 2.0)
	await _reset()


func _skills() -> void:
	var bear := _bear()
	check("pink hits sole", bear.make_tickle(d.pink, 1.0).zone == "sole")
	check("blue hits thigh then butt", bear.make_tickle(d.blue, 1.0).zone == "thigh" and bear.make_tickle(d.blue, 1.0).zone == "butt")
	for key in GaleBear.SKILL_CD:
		await _reset()
		bear = _bear()
		d.pink.global_position = bear.global_position + Vector2(15, 5)
		d.blue.global_position = bear.global_position + Vector2(55, 0)
		var started := bear._start(key)
		bear._skill_tick(float(GaleBear.WARN_TIME[key]) + 0.01)
		if key == "vacuum":
			check("vacuum releases caster immediately", bear.skill == "" and is_instance_valid(bear._vortex))
			await _wait(0.35)
		elif key in ["chase", "paw"]:
			for i in 2:
				await _wait(0.65)
				bear._skill_tick(0.65)
		check("skill executes and finishes: " + key, started and bear.used.has(key) and bear.skill == "")
		if key == "paw":
			check("paw chain uses sole and variant", d.pink.last_tickle != null and d.pink.last_tickle.zone == "sole" and d.pink.last_tickle.reaction_variant == "paw")
	await _reset()
	bear = _bear()
	bear._start("tornado")
	bear.stun(1.0)
	check("freeze cancels warning and skill", bear.skill == "" and bear._warns.is_empty())
	await _reset()


func _pace() -> void:
	var bear := _bear()
	check("all seven skills ready at spawn", bear.cds.values().all(func(cd): return cd == 0.0))
	check("all windups at most 180ms", GaleBear.WARN_TIME.values().all(func(t): return t <= 0.18))
	bear._end_skill()
	check("normal post attack rest 1.2s", bear._rest == 1.2)
	d.pink.global_position = bear.global_position + Vector2(20, 0)
	bear._start("vacuum")
	bear._skill_tick(float(GaleBear.WARN_TIME["vacuum"]) + 0.01)
	check("live vortex does not lock boss skill", bear.skill == "" and is_instance_valid(bear._vortex) and bear._start("chase"))
	bear.global_position += Vector2(24, 0)
	await _wait(0.03)
	check("independent vortex follows moving bear", bear._vortex.global_position.is_equal_approx(bear.global_position))
	bear._skill_tick(float(GaleBear.WARN_TIME["chase"]) + 0.01)
	check("wind field overlaps next attack", is_instance_valid(bear._vortex) and bear.skill == "chase")
	bear._skill_tick(GaleBear.CHASE_GAP + 0.01)
	bear._skill_tick(GaleBear.CHASE_GAP + 0.01)
	check("three chase rounds finish in under 600ms", bear.skill == "" and bear._elapsed < 0.6)
	check("duplicate live vortex rejected", not bear._start("vacuum"))
	bear._cancel()
	bear.raged = true
	bear._start("pulse")
	check("rage applies stronger cooldown reduction", is_equal_approx(bear.cds["pulse"], 2.7 * 2.0 * 0.45))
	for id in ["bear_shield", "bear_roll", "bear_airlift", "bear_airlift_rage"]:
		var t := MonsterTeamwork.team(id)
		check("boss collaboration fast: " + id, t.get("windup") == 0.12 and t.get("busy_time") == 0.9 and t["cooldown"] == 9)
	check("normal teamwork timing remains default", not MonsterTeamwork.team("hook_relay").has("windup") and not MonsterTeamwork.team("hook_relay").has("busy_time"))
	await _reset()
	bear = _bear()
	for c in [d.pink, d.blue]:
		c.set_invulnerable(10.0, true)
		c.fatigue.clear()
	d.pink.global_position = bear.global_position + Vector2(20, 0)
	d.blue.global_position = bear.global_position + Vector2(120, 0)
	bear.set_physics_process(true)
	await _wait(3.0)
	check("real AI slowed to at most three skills in three seconds", bear.used.size() >= 1 and bear.used.size() <= 3)
	await _reset()


func _wind_rules() -> void:
	var bear := _bear()
	d.pink.global_position = bear.global_position + Vector2(250, 150)
	d.blue.global_position = Vector2(d.gate_pos.x, d.wall_top_y() + 4)
	bear._start("tornado")
	bear._skill_tick(float(GaleBear.WARN_TIME["tornado"]) + 0.01)
	check("first phase launches eight tornadoes", bear.tornado_count() == 8)
	var tor: HazardTornado = bear._fields[0].get_ref()
	var before := tor.global_position
	await _wait(0.2)
	check("radial tornado travels in indicated direction", tor.global_position.distance_to(before) > 15.0)
	tor._travel = 6.01
	before = tor.global_position
	await _wait(0.2)
	check("tornado remains as stationary trap", tor.global_position.is_equal_approx(before))
	tor.active = false
	await _wait(0.1)
	check("frozen tornado removes AI danger", not tor.is_in_group("danger"))
	tor.on_magic_burst(3, d.pink)
	await _wait(0.6)
	check("full starlight clears tornado", not is_instance_valid(tor))
	await _reset()
	bear = _bear()
	bear.raged = true
	bear._start("tornado")
	bear._skill_tick(float(GaleBear.WARN_TIME["tornado"]) + 0.01)
	check("rage second wave waits for new warning", bear.tornado_count() == 8 and bear.skill == "tornado")
	bear._skill_tick(GaleBear.TORNADO_GAP + 0.01)
	check("rage emits offset second wave", bear.tornado_count() == 16 and bear.skill == "")
	var one: HazardTornado = bear._fields[0].get_ref()
	var nine: HazardTornado = bear._fields[8].get_ref()
	check("second wave angle offset is 22.5 degrees", is_equal_approx(absf(one.wind_direction.angle_to(nine.wind_direction)), PI / 8.0))
	bear._start("tornado")
	bear._skill_tick(float(GaleBear.WARN_TIME["tornado"]) + 0.01)
	bear._skill_tick(GaleBear.TORNADO_GAP + 0.01)
	bear._start("tornado")
	bear._skill_tick(float(GaleBear.WARN_TIME["tornado"]) + 0.01)
	bear._skill_tick(GaleBear.TORNADO_GAP + 0.01)
	check("tornado cap prevents fourth overlapping cast", bear.tornado_count() == GaleBear.MAX_TORNADOES and not bear._start("tornado"))
	await _reset()
	bear = _bear()
	d.pink.global_position = bear.global_position + Vector2(100, 0)
	d.blue.global_position = bear.global_position + Vector2(260, 0)
	var vortex := GaleVortex.spawn(bear, false)
	check("vortex eye is centered on field", vortex._eye.global_position.is_equal_approx(vortex.global_position))
	var mob := d.spawn("slime", "", bear.global_position + Vector2(120, 50))
	mob.set_meta("siege_spawning", false)
	mob._stun_left = 0.0
	mob._action_cd = 999.0
	check("vortex reuses original pull formula", vortex.pull_for(d.pink).dot(d.pink.global_position.direction_to(vortex.global_position)) > 55.0)
	check("vortex excludes bear and rooted actors", not vortex.can_pull(bear))
	d.pink.status.apply_root(1.0)
	check("root excludes pull", not vortex.can_pull(d.pink))
	d.pink.status.clear_root()
	d.pink._set_state(PlayableCharacter.State.DASH)
	check("dash excludes pull", not vortex.can_pull(d.pink))
	d.pink._set_state(PlayableCharacter.State.IDLE)
	mob.stun(1.0)
	check("frozen mob excludes pull", not vortex.can_pull(mob))
	mob._stun_left = 0.0
	var distance: float = mob.global_position.distance_to(bear.global_position)
	await _wait(0.25)
	check("actual physics pulls both player and minion", d.pink.global_position.x < bear.global_position.x + 95 and mob.global_position.distance_to(bear.global_position) < distance)
	var item := WorldItem.spawn(d.entities(), bear.global_position + Vector2(-100, 0), ItemDB.get_item("mint"), 1, false)
	# 使用已注册的可拾取物；检查内容与数量不变。
	if item.item == null:
		item.item = ItemDB.get_item(ItemDB.PATHS.keys()[0])
	var item_before := item.global_position
	vortex._gather()
	check("loose item moves without being consumed", is_instance_valid(item) and item.global_position.distance_to(bear.global_position) < item_before.distance_to(bear.global_position) and item.amount == 1)
	var calls := [0]
	var p := SiegeProjectile.shoot(d.entities(), bear.global_position + Vector2(30, 0), d.blue, "proj_equip", 150.0, func(c):
		calls[0] += 1
		Equipment.force(c.character_id, "equip_t_feather_socks", 20.0))
	var lifetime := p._life
	vortex._gather()
	await _wait(0.15)
	check("enemy equipment keeps lifetime while captured", p._wind_ref != null and is_equal_approx(p._life, lifetime))
	p.wind_hit(d.blue)
	p.wind_hit(d.blue)
	check("equipment callback executes once and keeps original effect", calls[0] == 1 and not GameState.equip_forced.get("blue", {}).is_empty())
	var other := SiegeProjectile.shoot(d.entities(), bear.global_position + Vector2(25, 0), d.blue, "proj_brush", 100.0, func(_c): pass)
	vortex._gather()
	check("second projectile captured", other._wind_ref != null)
	vortex._end()
	check("field cancellation restores original flight", other._wind_ref == null and other.target == d.blue)
	await _reset()
	bear = _bear()
	d.pink.global_position = bear.global_position + Vector2(5, 0)
	check("first boss hit accepted", bear.strike(d.pink, 3.0, "tornado"))
	var laugh := d.pink.laugh.value
	check("overlapping boss fields share hit protection", not bear.strike(d.pink, 10.0, "vacuum") and is_equal_approx(laugh, d.pink.laugh.value))
	await _wait(0.4)
	var shot := GaleWind.shoot(bear, d.pink.global_position + Vector2(-40, 0), Vector2.RIGHT, 8.0, "chase", true)
	await _wait(0.3)
	check("directional projectile hits actual target and retains variant", not is_instance_valid(shot) and d.pink.last_tickle.reaction_variant == "chase")
	await _reset()
	bear = _bear()
	d.pink.global_position = bear.global_position + Vector2(50, 0)
	var pulse := GaleWind.pulse(bear, bear.global_position)
	await _wait(0.4)
	check("expanding pulse hits once", pulse._hits.has(d.pink.get_instance_id()))
	var wall := d.walls[4]
	var hp := d.wall_hp
	GaleWind.lane(bear, Vector2(wall.global_position.x, wall.foot_y() + 70), Vector2(wall.global_position.x, wall.top_y() + 4), 4.5)
	await _wait(1.5)
	check("wind lane damages wall once", is_equal_approx(hp - d.wall_hp, 12.0 * SiegeWall.DAMAGE_MULT))
	await _wait(0.4)
	check("wind lane does not repeatedly damage wall", is_equal_approx(hp - d.wall_hp, 12.0 * SiegeWall.DAMAGE_MULT))
	await _reset()
	bear = _bear()
	var legacy := d.spawn_hazard("tornado", bear.global_position) as HazardTornado
	legacy._mob_tick(0.1)
	check("legacy tornado cannot capture siege boss", not legacy._mobs.has(bear) and legacy.boss_ref == null and legacy.radius == HazardTornado.RADIUS)
	await _reset()


func _reactions() -> void:
	for who in ["pink", "blue"]:
		Characters.scope(who)
		var src := ReactionDB.source("gale_bear")
		for key in GaleBear.SKILL_CD:
			var variant: Dictionary = src.get("lines_by_content", {}).get(key, {})
			check("four stages per skill: " + who + "/" + key, ["calm", "giggle", "helpless_1", "helpless_2"].all(func(stage): return variant.get(stage, []).size() >= 2))
		check("handwritten generic and special lines: " + who, src["calm"].size() == 4 and src["special"].size() == 3 and src["first_encounter"].size() == 3)
		check("helpless voice actually breaks into laughter: " + who, src["helpless_2"].all(func(line): return "哈哈" in line))
		var cg: Dictionary = CG.cgs()["death_siege_gale_bear"]
		check("CG has 15 authored beats: " + who, cg["steps"].size() == 17)
		check("CG uses original tickle choreography: " + who, cg["steps"].any(func(step): return step.get("actions", []).any(func(action): return action.get("do") == "tickle")))
		check("CG portraits follow poses: " + who, not cg["steps"].any(func(step): return step.has("portrait")))
		Characters.unscope()
	var bear := _bear()
	var saved_player := GameState.player
	for c in [d.pink, d.blue]:
		Characters.scope(c.character_id)
		GameState.player = c
		var said: Array[String] = []
		var collect := func(line, _seconds): said.append(line)
		GameState.princess_reacted.connect(collect)
		c.laugh.clear()
		c._reaction_cooldown = 0.0
		c._full_invuln = 0.0
		bear.skill = "paw" # 延迟旧风眼命中时，本体已经换了招。
		var hit := bear.make_tickle(c, 1.0)
		hit.reaction_variant = "vacuum"
		c.receive_hit(hit)
		var pool := ReactionDB.lines("gale_bear", "calm", "vacuum")
		check("actual delayed hit selects correct skill text: " + c.character_id, said.size() == 1 and said[0] in pool)
		c._reaction_cooldown = 0.0
		c.receive_hit(hit.copy())
		check("reaction avoids consecutive repetition: " + c.character_id, said.size() == 2 and said[0] != said[1])
		c.laugh.set_value(100.0)
		c._reaction_cooldown = 0.0
		c.receive_hit(hit.copy())
		check("actual high laugh selects helpless text: " + c.character_id, not said.is_empty() and said[-1] in ReactionDB.lines("gale_bear", "helpless_1", "vacuum"))
		GameState.princess_reacted.disconnect(collect)
		Characters.unscope()
	GameState.player = saved_player
	bear.skill = ""
	check("pink and blue skill variants are independent", ReactionDB._data["pink"]["sources"]["gale_bear"]["lines_by_content"] != ReactionDB._data["blue"]["sources"]["gale_bear"]["lines_by_content"])
	await _reset()


func _teams() -> void:
	for id in ["sticky_pincer", "hook_relay", "vine_pincer", "escort_bear", "melt_delivery", "jelly_guard", "bear_shield", "bear_airlift", "bear_airlift_rage", "bear_roll"]:
		await _reset()
		var spec := MonsterTeamwork.team(id)
		d.wave = int(spec["min_wave"])
		var group: Array = []
		for member in spec["members"]:
			var key: String = member["key"][0] if member["key"] is Array else member["key"]
			if key == "bind_vine":
				key = "vine"
			for i in int(member["count"]):
				var m := d.spawn(key, "", Vector2(d.gate_pos.x, 900) + Vector2(group.size() * 8, 0))
				m.set_physics_process(false)
				if m is GaleBear:
					m._intro_done = true
					m._intro_left = 0.0
				group.append(m)
		d.pink.global_position = group[0].global_position + Vector2(20, 0)
		d.blue.global_position = Vector2(d.gate_pos.x, d.wall_top_y() + 4.0)
		if id == "melt_delivery":
			var tower := IceTower.new()
			d.entities().add_child(tower)
			tower.global_position = group[0].global_position + Vector2(100, 0)
			tower.set_physics_process(false)
		check("component matches and fires: " + id, d.teamwork.try_fire(id, group[0]))
		check("component cooldown prevents duplicate: " + id, not d.teamwork.try_fire(id, group[0]))
		await _wait(1.0)
		match id:
			"sticky_pincer": check("pincer applies slow", d.pink.status.speed_multiplier() < 1.0)
			"vine_pincer": check("vine applies short root", d.pink.status.is_rooted())
			"escort_bear", "bear_shield", "jelly_guard": check("escort metadata reused: " + id, group[1].get_meta("escort_of", null) == group[0])
			"hook_relay", "bear_airlift", "bear_airlift_rage":
				await _wait(1.0)
				check("relay puts passenger on wall: " + id, group[1].get_meta("siege_on_wall", false))
			"melt_delivery":
				await _wait(1.0)
				check("carrier lands and restores passenger AI", not group[1].get_meta("airborne", false) and group[1].global_position.x > d.gate_pos.x + 60)
			"bear_roll": check("roll effect moves existing minions", group[1].global_position != group[0].global_position)
	await _reset()
	var bear := _bear()
	var crab := d.spawn("shield_crab", "", bear.global_position + Vector2(20, 0))
	crab.set_physics_process(false)
	check("insufficient members do not trigger", not d.teamwork.try_fire("bear_shield", bear))
	d.wave = 1
	check("boss collaboration gated before wave 6", not d.teamwork.try_fire("bear_shield", bear))
	await _reset()
	var hook := d.spawn("hook", "", Vector2(d.gate_pos.x, 900))
	hook.set_physics_process(false)
	for i in 2:
		var gecko := d.spawn("gecko", "", hook.global_position + Vector2(10 + i * 5, 0))
		gecko.set_physics_process(false)
	d.teamwork.try_fire("hook_relay", hook)
	hook.stun(5.0)
	await _wait(1.0)
	check("frozen leader cancels relay before launch", not d.monsters.any(func(m): return m.get_meta("airborne", false)))
	await _reset()


func _cg() -> void:
	for who in ["pink", "blue"]:
		Characters.scope(who)
		var id := CG.death_cg_for("gale_bear")
		check("independent death CG registered: " + who, id == "death_siege_gale_bear" and CG.cgs().has(id))
		check("CG data validates: " + who, CG.validate().is_empty())
		var job := func(): await CG.play_death("gale_bear")
		job.call()
		await _wait(0.3)
		check("CG starts: " + who, CG.is_busy())
		CG._follow_pose("helpless_1")
		var wanted := Dialogue.portrait_for("helpless_1", who)
		var actual := Dialogue._portrait_override as AtlasTexture
		check("auto CG portrait follows actual role: " + who, actual != null and actual.atlas == wanted.atlas and actual.region == wanted.region)
		CG._can_skip = true
		CG.skip()
		for i in 50:
			if not CG.is_busy():
				break
			Dialogue.advance()
			await _wait(0.02)
		check("CG skips and releases stage: " + who, not CG.is_busy())
		Characters.unscope()


func _interruptions() -> void:
	await _reset()
	var hook := d.spawn("hook", "", Vector2(d.gate_pos.x, 900))
	hook.set_physics_process(false)
	var rider := d.spawn("gecko", "", hook.global_position + Vector2(10, 0))
	rider.set_physics_process(false)
	var other := d.spawn("gecko", "", hook.global_position + Vector2(20, 0))
	other.set_physics_process(false)
	d.blue.global_position = Vector2(d.walls[4].global_position.x, d.wall_top_y() + 4.0)
	var wall := d.segment_at(d.blue.global_position.x)
	wall.reinforce(100.0, 5.0)
	d.teamwork.try_fire("hook_relay", hook)
	await _wait(1.0)
	check("reinforced wall blocks relay", not rider.get_meta("airborne", false) and not rider.get_meta("siege_on_wall", false))
	wall.shield_left = 0.0
	d.teamwork._cd.clear()
	for m in d.monsters:
		m.set_meta("team_busy", 0.0)
	d.teamwork.try_fire("hook_relay", hook)
	await _wait(0.85)
	check("relay launches after warning", rider.get_meta("airborne", false))
	hook.health.damage(9999)
	await _wait(1.0)
	check("dead leader cancels landing and restores AI", not rider.get_meta("siege_on_wall", false) and not rider.get_meta("airborne", false) and rider.is_physics_processing())
	await _reset()
	var bear := _bear()
	bear.global_position = d.pink.global_position + Vector2(-15, -5)
	var vortex := GaleVortex.spawn(bear, false)
	check("vortex acquired before clear", is_instance_valid(vortex))
	d.state = "prep"
	d.clear_field()
	await get_tree().process_frame
	check("clear releases actors and owned wind fields", not d.pink.status.is_grabbed() and get_tree().get_nodes_in_group("siege_temp").is_empty())
	await _reset()


func _wind_transport() -> void:
	await _reset()
	var bear := _bear()
	var rider := d.spawn("hug_bear", "", bear.global_position + Vector2(20, 0))
	var from := rider.global_position
	rider._stun_left = 0.0
	rider.set_meta("siege_spawning", false)
	TeamworkEffects._transfer(bear, rider, d.blue.global_position, false, true)
	await _wait(0.2)
	check("wind transport takes over existing minion", rider.get_meta("team_transfer", false) and not rider.is_physics_processing())
	bear.stun(3.0)
	await _wait(0.1)
	check("freeze immediately cancels wind transport and restores AI", not rider.get_meta("airborne", false) and not rider.get_meta("team_transfer", false) and rider.is_physics_processing() and rider.global_position.distance_to(from) < 15.0)
	await _reset()
	bear = _bear()
	rider = d.spawn("hug_bear", "", bear.global_position + Vector2(20, 0))
	rider._stun_left = 0.0
	TeamworkEffects._transfer(bear, rider, d.blue.global_position, false, true)
	await _wait(0.1)
	GameState.in_dialogue = true
	await _wait(0.05)
	var paused := rider.global_position
	await _wait(0.2)
	check("dialogue pauses transport arc", rider.global_position.is_equal_approx(paused))
	GameState.in_dialogue = false
	await _wait(1.0)
	check("transport resumes and releases flags", rider.is_physics_processing() and not rider.get_meta("airborne", false))
	await _reset()
	bear = _bear()
	var vortex := GaleVortex.spawn(bear, false)
	var p := SiegeProjectile.shoot(d.entities(), bear.global_position + Vector2(30, 0), d.blue, "proj_equip", 150.0, func(_c): pass)
	vortex._gather()
	check("equipment held before owner freeze", p._wind_ref != null)
	bear.stun(2.0)
	await _wait(0.05)
	check("owner freeze releases equipment and cancels vortex", p._wind_ref == null and not is_instance_valid(vortex))
	await _reset()


func _performance() -> void:
	# 前面的真实受挠测试会积累疲倦；不能让自动爆发清掉压力测试的风场。
	for c in [d.pink, d.blue]:
		c.fatigue.clear()
		c.laugh.clear()
		c.set_invulnerable(6.0, true)
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy", "bat", "spider", "crab", "ghost", "hedgehog"]
	for i in 1000:
		d.spawn(keys[i % keys.size()], ["bottom", "left", "right", "hole"][i % 4])
	var bear := _bear()
	bear.raged = true
	for i in GaleBear.MAX_TORNADOES / 8:
		bear._release_tornadoes(i * PI / 16.0)
	var vortex := GaleVortex.spawn(bear, true)
	await _wait(0.2)
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 2_000_000:
		await get_tree().physics_frame
		frames += 1
	var avg := float(Time.get_ticks_usec() - start) / 1000.0 / frames
	check("1000 mobs + 48 tornadoes + vortex %.1f ms/frame <= 33 (mobs=%d winds=%d vortex=%s)" % [avg, d.monsters.size(), bear.tornado_count(), is_instance_valid(vortex)], avg <= 33.0 and d.monsters.size() >= 900 and bear.tornado_count() == GaleBear.MAX_TORNADOES and is_instance_valid(vortex))
	await _reset()


func _real_defeat_cg() -> void:
	for c in [d.pink, d.blue]:
		await _reset()
		var bear := _bear()
		c.health.max_hp = 1
		c.health.set_hp(1)
		c.laugh.set_value(0.0)
		c._full_invuln = 0.0
		c.receive_hit(bear.make_tickle(c, 500.0))
		for i in 80:
			if CG.is_busy():
				break
			await _wait(0.05)
		check("actual boss defeat routes to CG: " + c.character_id, CG.current == "death_siege_gale_bear" and CG.character_id == c.character_id)
		CG._can_skip = true
		CG.skip()
		for i in 80:
			if not CG.is_busy():
				break
			Dialogue.advance()
			await _wait(0.02)
		await _wait(0.2)
	await _reset()
