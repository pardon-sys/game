extends Node
## 小镇攻防战第二轮：黄字 10 秒叠放、看过的情报图标消失、AI 闲逛（粉色 / 蓝色公主、雪人、士兵）、友军士兵（打怪 / 撤退 / 抬蓝色公主复活）、
## 蓝色公主 40 秒自己复活、地精工兵搭敌塔（进度条 / 冻住打断）、13 个怪物配合技（凑齐发动 + 成套生成）、怪物 + 陷阱配合、
## 4 个陷阱组合、500 只怪同时在场的帧时间、离开攻防战后镜头复原。
## 用法：Godot --headless --path . res://tests/siege2_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var d: SiegeDirector


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false   # 按键说明情报不自动弹（siege3_test 单独测）
	TownBuffShow.enabled = false   # 镇民支援的过场跳过（buff 照样生效）
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked",
			"intro_done_siege_intro", "siege_intro_seen", "seen_fatigue_burst"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _until(func(): return SiegeDirector.current != null and SiegeDirector.current.state == "prep", 20.0)
	d = SiegeDirector.current
	d.quiet_spawn = true
	await _wait(0.5)
	_finish()
	var only := OS.get_environment("SIEGE2_ONLY")
	for sec in ["hints", "wander", "soldiers", "engineers", "teamwork", "trap_combos", "perf", "camera_reset"]:
		if only == "" or sec in only.split(","):
			# 士兵只在闲逛 / 士兵两段上场，别的段落里他们会先把测试放的怪打掉
			if is_instance_valid(d):
				d.bench_soldiers(not (sec in ["wander", "soldiers"]))
			await call("_run_" + sec)
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 工具
func _fight() -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.state = "fight"


func _clear() -> void:
	var g := 0
	while (CG.is_busy() or Dialogue.is_active()) and g < 400:
		if CG.is_busy():
			CG._can_skip = true
			CG.skip()
		_finish()
		await get_tree().process_frame
		g += 1
	# 先退回准备阶段再清场，免得导演以为这一波打完了（连着清几次会一路「打赢」到最后一波）
	d.state = "prep"
	d._busy = false
	d.wave = 1
	d.clear_field()
	for pd in get_tree().get_nodes_in_group("siege_pad"):
		pd.queue_free()
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		t.queue_free()
	for c: PlayableCharacter in [d.pink, d.blue]:
		var dn := c.get_node_or_null("Downed")
		if dn:
			dn.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		c.visible = true
		c.set_physics_process(true)
		c.laugh.set_value(0.0)
		c.remove_buff("frost_guard")
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
	d.pink.global_position = d.gate_pos + Vector2(0, 40)
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.wall_hp = d.wall_max
	await _wait(0.2)


func _key_tickle(c: PlayableCharacter, key: String, amount := 3.0) -> void:
	var s := Src.new()
	s.reaction_key = key
	add_child(s)
	c.receive_hit(HitData.make_tickle(s, amount))
	s.queue_free()


func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ------------------------------------------------------------------ 黄字 / 情报
func _run_hints() -> void:
	print("-- 黄字 10 秒 / 情报图标")
	var hint: CenterHint = main.find_child("CenterHint", true, false)
	GameState.hint("测试一")
	await _wait(0.3)
	GameState.hint("测试二")
	await _wait(0.3)
	GameState.hint("测试三")
	await _wait(0.2)
	var stacked := hint.get_parent().get_children().filter(func(n): return n is Label and (n as Label).text.begins_with("测试") and n.modulate.a > 0.1).size()
	await _wait(2.6)
	check("黄字叠放（同时 %d 条），按默认时长消失（%s）" % [stacked, hint.modulate.a < 0.1], stacked == 3 and hint.modulate.a < 0.1)
	var intel := d.intel
	for k in ["hug_bear", "cart"]:
		GameState.set_flag("siege_intel_" + k, false)
		intel.shown.erase(k)
		intel.discover(k)
	await get_tree().process_frame
	var before := intel._buttons.size()
	intel.open("hug_bear")
	await _press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	check("情报卡开着时按 Esc 只关卡片（%s），暂停菜单没打开（%s），看过的图标从右边消失（%d → %d）" % [not intel.is_open(), not get_tree().paused,
			before, intel._buttons.size()],
		not intel.is_open() and not get_tree().paused and intel._buttons.size() == before - 1)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


# ------------------------------------------------------------------ AI 闲逛
func _run_wander() -> void:
	print("-- AI 没目标时随机走")
	await _clear()
	main.switch_character()
	await _wait(0.3)
	var p0 := d.pink.global_position
	var pk := d.pink.controller as CompanionController
	var intent := ""
	var moved := 0.0
	var t := 0.0
	var last := p0
	while t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		moved += d.pink.global_position.distance_to(last)
		last = d.pink.global_position
	intent = str(pk.intent) if is_instance_valid(pk) else ""
	main.switch_character()
	await _wait(0.3)
	check("粉色公主的 AI 没事做时在附近走动（走了 %.0f 像素，%s）" % [moved, intent], moved > 20.0)
	var b0 := d.blue.global_position
	await _wait(6.0)
	check("蓝色公主的 AI 没威胁时在墙顶巡逻（x %.0f → %.0f，还在墙上 %s）" % [b0.x, d.blue.global_position.x, d.is_on_wall(d.blue)],
		absf(d.blue.global_position.x - b0.x) > 10.0 and d.is_on_wall(d.blue))
	var pd := BuildPad.new()
	d.entities().add_child(pd)
	pd.global_position = Vector2(d.gate_pos.x - 200.0, d.wall_foot_y() + 80.0)
	pd._build("snowman", 1)
	_fight()
	await _until(func(): return get_tree().get_nodes_in_group("siege_temp").any(func(n): return n is Snowman), 3.0)
	var sm: Snowman = get_tree().get_nodes_in_group("siege_temp").filter(func(n): return n is Snowman)[0]
	var s0 := sm.global_position
	await _wait(4.0)
	check("雪人没怪可打时在附近走动（移动 %.0f）" % sm.global_position.distance_to(s0), sm.global_position.distance_to(s0) > 5.0)
	var sp: SiegeSoldier = d.soldiers.filter(func(s): return s.role == "spear")[0]
	var q0 := sp.global_position
	await _wait(4.0)
	check("长矛兵没怪时在岗位附近巡逻（移动 %.0f）" % sp.global_position.distance_to(q0), sp.global_position.distance_to(q0) > 4.0)
	d.state = "prep"
	d._queue.clear()


# ------------------------------------------------------------------ 友军士兵
func _run_soldiers() -> void:
	print("-- 友军士兵")
	await _clear()
	_fight()
	var spears := d.soldiers.filter(func(s): return s.role == "spear")
	var archers := d.soldiers.filter(func(s): return s.role == "archer")
	check("墙下 %d 个长矛兵、墙顶 %d 个弓箭手（弓箭手在墙上 %s）" % [spears.size(), archers.size(), archers.all(func(a): return d.is_on_wall(a))],
		spears.size() == 10 and archers.size() == 6 and archers.all(func(a): return d.is_on_wall(a)))
	var sp: SiegeSoldier = spears[2]
	var m := d.spawn("slime", "", sp.global_position + Vector2(0, 30))
	m.mind = null
	var hp0 := m.health.hp
	var ar: SiegeSoldier = archers[1]
	var m2 := d.spawn("slime", "", Vector2(ar.global_position.x, d.wall_foot_y() + 100.0))
	m2.mind = null
	var hp2 := m2.health.hp
	await _wait(3.0)
	check("长矛兵打附近的怪（%d → %d），弓箭手往墙下射箭（%d → %d）" % [hp0, m.health.hp if is_instance_valid(m) else 0, hp2, m2.health.hp if is_instance_valid(m2) else 0],
		(not is_instance_valid(m) or m.health.hp < hp0) and (not is_instance_valid(m2) or m2.health.hp < hp2))
	sp.health.damage(sp.health.hp)
	await _wait(0.2)
	var retreated := sp.retreating
	await _until(func(): return not sp.retreating, 30.0)
	check("撑不住就撤回城门（%s），20 秒后满血回到岗位（%s）" % [retreated, not sp.retreating and sp.visible], retreated and not sp.retreating and sp.visible)
	await _clear()
	_fight()
	# 蓝色公主倒在墙下 → 两个长矛兵抬上城墙复活
	d.blue.global_position = Vector2(d.gate_pos.x + 140.0, d.wall_foot_y() + 40.0)
	d.blue.health.damage(999)
	await _until(func(): return Downed.is_downed(d.blue), 6.0)
	var dn: Downed = d.blue.get_node_or_null("Downed")
	var auto := dn.revive_after if dn else 0.0
	var t := await _until(func(): return not Downed.is_downed(d.blue), 35.0)
	check("蓝色公主倒在墙下：士兵把她抬上城墙复活（%.1f 秒，在墙上 %s，倒计时 %.0f 秒）" % [t, d.is_on_wall(d.blue), auto],
		not Downed.is_downed(d.blue) and d.is_on_wall(d.blue) and absf(auto - SiegeDirector.BLUE_REVIVE) < 0.1)
	# 没有士兵能来：40 秒后自己复活
	await _clear()
	_fight()
	for s in d.soldiers:
		s.retreating = true
	d.blue.health.damage(999)
	await _until(func(): return Downed.is_downed(d.blue), 6.0)
	var dn2: Downed = d.blue.get_node_or_null("Downed")
	dn2.revive_after = 0.5
	await _wait(1.0)
	check("没有士兵能来时倒计时到了自己复活（%s）" % (not Downed.is_downed(d.blue)), not Downed.is_downed(d.blue))
	for s in d.soldiers:
		s.retreating = false
	d.state = "prep"
	d._queue.clear()


# ------------------------------------------------------------------ 工兵
func _run_engineers() -> void:
	print("-- 地精工兵搭敌塔")
	await _clear()
	_fight()
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	var site: EnemySite = sites[sites.size() - 1]
	var made := d.teamwork.spawn_formation("engineer_escort", site.global_position + Vector2(40, 30))
	var engineers := made.filter(func(m): return m is GoblinEngineer)
	var guards := made.filter(func(m): return not (m is GoblinEngineer))
	check("成套生成工兵队：%d 只工兵 + %d 只护卫（护卫跟着工兵 %s，工兵有护送 %s）" % [engineers.size(), guards.size(),
			guards.all(func(g): return g.has_meta("escort_of")), engineers.all(func(e): return e.escorted)],
		engineers.size() == 3 and guards.size() >= 3 and guards.all(func(g): return g.has_meta("escort_of")))
	var target: EnemySite = (engineers[0] as GoblinEngineer)._pick_site()
	await _until(func(): return target.is_building(), 12.0)
	var building := target.is_building()
	# 冻住：进度停下
	for e in engineers:
		(e as Monster).stun(2.0)
	var b0 := target.build_progress
	await _wait(1.0)
	var paused := absf(target.build_progress - b0) < 0.05
	var t := await _until(func(): return target.tower != null, 25.0)
	check("工兵走到最近的空地基开始搭（进度条 %s），冻住时进度停下（%s），搭完立起敌塔（%.1f 秒，%s），护送的塔第一次威力加倍（%s）" % [building, paused, t,
			target.tower.kind if target.tower else "", target.tower.get_meta("escort_built", false) if target.tower else false],
		building and paused and target.tower != null and target.tower.get_meta("escort_built", false))
	var tower_count := get_tree().get_nodes_in_group("siege_enemy_tower").size()
	await _until(func(): return get_tree().get_nodes_in_group("siege_enemy_site").any(func(s): return s != target and s.is_building()), 15.0)
	check("搭完去找下一个空地基接着搭（%s）" % get_tree().get_nodes_in_group("siege_enemy_site").any(func(s): return s != target and s.is_building()),
		get_tree().get_nodes_in_group("siege_enemy_site").any(func(s): return s != target and s.is_building()) and tower_count >= 1)
	for e in engineers:
		if is_instance_valid(e):
			e.health.damage(999)
	await _wait(0.3)
	var waves: Array = d.data.get("waves", [])
	var with_eng := waves.filter(func(w): return w.get("groups", []).any(func(g): return g.get("formation", "") == "engineer_escort")).size()
	check("每一波都有工兵队（%d / %d 波）" % [with_eng, waves.size()], with_eng == waves.size())
	d.state = "prep"
	d._queue.clear()


# ------------------------------------------------------------------ 配合技
func _run_teamwork() -> void:
	print("-- 怪物配合技")
	# 蓝色公主的 AI 会用暴风雪 / 冰锥把测试里的怪打掉（壁虎只有 2 血），这一段先让她站着
	d.blue.set_controller(CharacterController.new())
	var ok := {}
	for t in MonsterTeamwork.data().get("teams", []):
		await _clear()
		_fight()
		var id: String = t["id"]
		d.teamwork._cd.clear()
		d.teamwork.history.clear()
		var at := Vector2(d.gate_pos.x - 160.0, d.wall_foot_y() + (6.0 if id in ["gecko_ladder"] else 90.0))
		d.pink.global_position = at + Vector2(10, 0)
		var made := d.teamwork.spawn_formation(id, at)
		for m in made:
			m.mind = null if id != "gecko_ladder" else m.mind
			m.global_position = at + Vector2(randf_range(-8, 8), randf_range(-6, 6))
		await get_tree().process_frame
		d.teamwork.scan()
		await _wait(0.6)
		ok[id] = d.teamwork.history.has(id) and not made.is_empty()
	var bad := ok.keys().filter(func(k): return not ok[k])
	check("13 个怪物配合技都能成套生成、凑齐就发动（没发动：%s）" % [bad], ok.size() == 13 and bad.is_empty())
	# 几个效果
	await _clear()
	_fight()
	var at2 := Vector2(d.gate_pos.x + 200.0, d.wall_foot_y() + 120.0)
	var slimes := d.teamwork.spawn_formation("slime_merge", at2)
	for m in slimes:
		m.mind = null
		m.global_position = at2
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var giant := slimes.filter(func(m): return is_instance_valid(m) and m.get_meta("giant", false))
	var hp: int = (giant[0] as Monster).health.max_hp if not giant.is_empty() else 0
	check("史莱姆合体：合成一只大的（血 %d）" % hp, giant.size() == 1 and hp >= 8)
	if not giant.is_empty():
		var n0 := d.monsters.size()
		giant[0].health.damage(999)
		await _wait(0.3)
		check("大史莱姆打倒后分裂成更多小的（%d → %d）" % [n0, d.monsters.size()], d.monsters.size() >= n0 + 4)
	await _clear()
	_fight()
	var atw := Vector2(d.gate_pos.x - 260.0, d.wall_foot_y() + 4.0)
	var geckos := d.teamwork.spawn_formation("gecko_ladder", atw)
	for g in geckos:
		g.global_position = atw + Vector2(randf_range(-10, 10), 0)
		g.mind = null
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var lad := LivingLadder.near(get_tree(), atw.x)
	var climber := d.spawn("slime", "", Vector2(atw.x + 4.0, d.wall_foot_y() + 30.0))
	await _until(func(): return is_instance_valid(climber) and climber.get_meta("siege_on_wall", false), 8.0)
	check("壁虎叠罗汉：叠成活梯子（%s），普通怪顺着爬上墙（%s）" % [lad != null, is_instance_valid(climber) and climber.get_meta("siege_on_wall", false)],
		lad != null and is_instance_valid(climber) and climber.get_meta("siege_on_wall", false))
	await _clear()
	_fight()
	var crew := d.teamwork.spawn_formation("cart_escort", Vector2(d.gate_pos.x + 300.0, d.wall_foot_y() + 300.0))
	var cart: Monster = crew.filter(func(m): return m is SiegeCart)[0]
	var above := Src.new()
	add_child(above)
	var crabs: Array = cart.get_meta("escorts", [])
	for c in crabs:
		(c as Node2D).global_position = cart.global_position + Vector2(0, -16)
	above.global_position = cart.global_position + Vector2(0, -80)
	var blocked := not cart.receive_hit(HitData.make_attack(above, 1, 0.0))
	above.queue_free()
	check("攻城车护卫阵：螃蟹排在车前（%d 只），从前面打不到车（%s）" % [crabs.size(), blocked], crabs.size() == 3 and blocked)
	await _clear()
	_fight()
	var drop := d.teamwork.spawn_formation("bat_airdrop", Vector2(d.gate_pos.x, d.wall_foot_y() + 200.0))
	var pas: Array = drop.filter(func(m): return MonsterTeamwork.key_of(m) == "hug_bear")
	await _until(func(): return not pas.is_empty() and is_instance_valid(pas[0]) and pas[0].get_meta("siege_on_wall", false), 8.0)
	check("蝠群空投：小熊被扔到墙顶（%s）" % (not pas.is_empty() and is_instance_valid(pas[0]) and pas[0].get_meta("siege_on_wall", false)),
		not pas.is_empty() and is_instance_valid(pas[0]) and pas[0].get_meta("siege_on_wall", false))
	# 组件单独可用：一个空的 Node2D 上挂 MonsterTeamwork（不设 spawn_func / monsters_func，用 "enemy" 组）
	await _clear()
	d.teamwork.enabled = false
	var room := Node2D.new()
	add_child(room)
	var solo := MonsterTeamwork.new()
	room.add_child(solo)
	for i in 4:
		var sl: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
		room.add_child(sl)
		sl.global_position = Vector2(-3000 + i * 4.0, -3000)
	await get_tree().process_frame
	var fired := solo.scan()
	check("MonsterTeamwork 在没有攻防战宿主的空场景里也能用（发动 %s）" % [fired], fired.has("slime_merge"))
	room.queue_free()
	d.teamwork.enabled = true
	var n_new := ["bat", "ghost", "troll", "crab", "split_slime", "mana_jelly", "bubble_fish", "imp", "frog", "octopus", "barnacle", "mini_tentacle"]
	var in_waves := {}
	for w in d.data.get("waves", []):
		for g in w.get("groups", []):
			in_waves[str(g.get("monster", ""))] = true
	var missing := n_new.filter(func(k): return not in_waves.has(k))
	check("新加入的已有怪物都出现在波次里（缺 %s）" % [missing], missing.is_empty())
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 陷阱
func _run_trap_combos() -> void:
	print("-- 怪物 + 陷阱 / 陷阱组合")
	await _clear()
	_fight()
	var p := d.pink
	var c := Vector2(d.gate_pos.x - 200.0, d.wall_foot_y() + 220.0)
	p.global_position = c + Vector2(300, 0)
	var tor: HazardTornado = d.spawn_hazard("tornado", c)
	for i in 3:
		var m := d.spawn("slime", "", c + Vector2(i * 6.0, 4))
		m.mind = null
	await _wait(1.6)
	var caught := tor._mobs.size()
	check("龙卷风卷怪：小怪被卷进去一起转（%d 只）" % caught, caught >= 2)
	await _clear()
	_fight()
	var fog: HazardFog = d.spawn_hazard("fog", c)
	var hidden := d.spawn("rat", "", c + Vector2(10, 0))
	hidden.mind = null
	await _wait(1.6)
	var tower_sees := d.enemies_near(c, 40.0, false).has(hidden)
	p.global_position = c + Vector2(200, 0)
	await _wait(0.2)
	p.global_position = c + Vector2(20, 0)
	await _wait(0.3)
	check("迷雾伏击：雾里的怪半透明（%.2f）、冰塔打不到（%s），粉色公主一进雾就扑上来（目标 %s）" % [hidden.modulate.a, not tower_sees, hidden.target],
		hidden.modulate.a < 0.5 and not tower_sees and hidden.target == p)
	await _clear()
	_fight()
	p.global_position = d.gate_pos + Vector2(0, 40)
	var bub: HazardBubbles = d.spawn_hazard("bubbles", Vector2(d.map_size().x / 2.0, d.wall_foot_y() + 200.0))
	await _wait(1.4)
	var first: Dictionary = bub._bubbles[0]
	var mob := d.spawn("slime", "", first["pos"])
	mob.mind = null
	await _until(func(): return bub._bubbles.any(func(b): return b.get("mob") == mob), 3.0)
	var carried := bub._bubbles.any(func(b): return b.get("mob") == mob)
	await _until(func(): return not is_instance_valid(mob) or mob.global_position.y < d.wall_foot_y() + 30.0, 12.0)
	check("泡泡运兵：小怪被包进泡泡（%s），运到城墙下（y %.0f）" % [carried, mob.global_position.y if is_instance_valid(mob) else -1.0],
		carried and is_instance_valid(mob) and mob.global_position.y < d.wall_foot_y() + 30.0)
	var combos_ok := {}
	for k in SiegeDirector.HAZARD_COMBOS:
		await _clear()
		_fight()
		var made: Array = d.spawn_hazard_combo(k)
		combos_ok[k] = made.size() >= 2 or k == "net_link"
		await _wait(1.6)
		if k == "double_tornado":
			combos_ok[k] = combos_ok[k] and made.all(func(h): return is_instance_valid(h) and (h as HazardTornado).orbit_center != Vector2.INF)
		elif k == "fog_tornado":
			combos_ok[k] = combos_ok[k] and is_instance_valid(made[1]) and (made[1] as HazardTornado).hidden_in != null
		elif k == "net_link":
			combos_ok[k] = get_tree().get_nodes_in_group("siege_hazard").any(func(h): return h is HazardStickyNet) \
				and get_tree().get_nodes_in_group("siege_hazard").any(func(h): return h is HazardLinkRune)
	check("4 个陷阱组合都能成套出现（%s）" % [combos_ok], combos_ok.values().all(func(v): return v))
	var waves: Array = d.data.get("waves", [])
	var hz2: int = waves[1].get("hazards", []).size()
	var hz10: int = waves[9].get("hazards", []).size()
	check("陷阱更频繁：第 2 波 %d 个、第 10 波 %d 个（含陷阱组合）" % [hz2, hz10], hz2 >= 2 and hz10 >= 15)
	d.state = "prep"
	d._queue.clear()


# ------------------------------------------------------------------ 性能
func _run_perf() -> void:
	print("-- 性能：500 只怪")
	await _clear()
	_fight()
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy", "bat", "spider", "crab", "ghost", "hedgehog"]
	for i in 500:
		d.spawn(keys[i % keys.size()], ["bottom", "left", "right", "hole"][i % 4])
	await _wait(1.0)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 4_000_000:
		await get_tree().physics_frame
		frames += 1
	var avg := 4000.0 / frames
	var total_waves := 0
	for w in d.data.get("waves", []):
		for g in w.get("groups", []):
			total_waves += int(g.get("count", 0))
	check("500 只怪同时在场：平均每物理帧 %.1f ms（目标 ≤ 33 ms），波次没有同时在场上限（%s）" % [avg, not d.data.has("alive_cap")],
		avg <= 33.0 and not d.data.has("alive_cap") and d.monsters.size() >= 450)
	d.clear_field()


func _run_camera_reset() -> void:
	print("-- 离开攻防战镜头复原")
	d.cam.set_zoom_level(0.5, true)
	await _wait(0.3)
	d.retreat()
	await _until(func(): return main.level and str(main.level.get("floor_id")) == "floor_06_war", 20.0)
	await _wait(1.0)
	check("回到战时小镇后镜头倍数是 1（%.2f）" % GameState.player.camera.zoom.x, is_equal_approx(GameState.player.camera.zoom.x, 1.0))
