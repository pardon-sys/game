extends Node
## 小镇攻防战第三轮：规则黄字 10 秒 / 普通原时长、12 波自动推进、镇民支援（过场 + 数值）、第 3 波小 Boss 攻城巨魔将军（10 个技能 + 狂暴 + 笑倒 CG）、
## 新士兵（盾兵 / 医护兵 / 工匠）、新友军塔（篝火 / 弩炮 / 热可可）、新法术（暴风雪 / 冰川突刺 / 冰镜分身）与射程、瞄准时镜头跟随、
## 敌塔可拆 / 范围 / 地基离墙近、怪物不出地图 + 斜着走向城墙 + 绕开道具、出生动画、攻城车不被打断 + 被挡后再冲、城墙层级与墙脚碰撞、
## 幽灵在篝火旁现形、装备挠痒（发作 / 挡下）涨闷笑、CG 按图集键取图、1000 只怪的帧时间。
## 用法：Godot --headless --path . res://tests/siege3_test.tscn   （退出码 0 = 全部通过；SIEGE3_ONLY=段名,段名 只跑某几段）

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
	TownBuffShow.enabled = false
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
	var only := OS.get_environment("SIEGE3_ONLY")
	for sec in ["hints", "waves", "town", "boss", "soldiers", "towers", "spells", "etowers", "field", "cart", "wall", "locks", "bugs5", "towers5", "fixes6", "features6", "round7", "round8", "round9", "round10", "round11", "equip", "cg", "perf"]:
		if only == "" or sec in only.split(","):
			if is_instance_valid(d):
				d.bench_soldiers(sec != "soldiers")
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
	d.state = "prep"
	d._busy = false
	d.features.end()
	d.wave = 1
	d.next_left = -1.0
	d.clear_field()
	for n in get_tree().get_nodes_in_group("siege_pad"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("siege_enemy_tower"):
		n.queue_free()
	for c: PlayableCharacter in [d.pink, d.blue]:
		var dn := c.get_node_or_null("Downed")
		if dn:
			dn.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		# 上一段被抓 / 被吸住刚松开会有一小段无敌，别带到下一段
		if c.status and c.status.is_grabbed():
			c.status.release(true)
		if c.state == PlayableCharacter.State.GRABBED:
			c._set_state(PlayableCharacter.State.IDLE)
		c._full_invuln = 0.0
		c.set_invulnerable(0.0)
		c.visible = true
		c.set_physics_process(true)
		c.laugh.set_value(0.0)
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
		if c.status:
			c.status.release(true)
	d.pink.global_position = d.gate_pos + Vector2(0, 40)
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.wall_hp = d.wall_max
	for w in d.walls:
		w.taken = 0.0
		w.shield_left = 0.0
	Engine.time_scale = 1.0
	await _wait(0.2)


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


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


# ------------------------------------------------------------------ 1 黄字
func _run_hints() -> void:
	print("-- 黄字时长")
	var hud: Node = main.find_child("HUD", true, false)
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
	var toast: Label = hud.get("toast_label") if hud else null
	GameState.notify("普通通知")
	await _wait(5.6)
	var normal_gone := toast != null and toast.modulate.a < 0.1
	GameState.rule("规则说明：现在也是默认时长")
	await _wait(5.6)
	var rule_gone := toast != null and toast.modulate.a < 0.1
	check("黄字都是默认时长：普通通知（%s）、规则说明（%s）5.6 秒内都消失" % [normal_gone, rule_gone], normal_gone and rule_gone)
	# 按键说明情报：开场过场放完后自动弹出，正文按当前键位生成
	SiegeIntel.auto_controls = true
	d.intel.close()
	d._show_controls()
	await _until(func(): return d.intel.is_open(), 4.0)
	var txt := SiegeIntel.controls_text()
	var ok_keys := txt.contains(SiegeIntel.keys_of("siege_build", 1)) and txt.contains("1~7") and txt.contains(SiegeIntel.keys_of("switch_character", 1))
	check("进攻防战后自动弹出「攻防战按键说明」（%s，%s），按键按当前键位（%s）" % [d.intel.is_open(), d.intel._card_key, ok_keys],
		d.intel.is_open() and d.intel._card_key == "controls" and ok_keys)
	await _press("pause")
	await get_tree().process_frame
	check("按 Esc 关掉、不开暂停菜单（%s / %s）" % [not d.intel.is_open(), not get_tree().paused], not d.intel.is_open() and not get_tree().paused)
	SiegeIntel.auto_controls = false
	var src := FileAccess.get_file_as_string("res://scripts/components/combo_tracker.gd")
	check("组合技等首次说明走 GameState.rule（%s）" % src.contains("GameState.rule(ReactionDB.hint"), src.contains("GameState.rule(ReactionDB.hint"))


# ------------------------------------------------------------------ 2 波次
func _run_waves() -> void:
	print("-- 12 波自动推进")
	await _clear()
	check("一共 12 波（%d），城墙血量 %d" % [SiegeDirector.total_waves(), int(d.wall_max)], SiegeDirector.total_waves() == 12 and d.wall_max >= 4320.0)
	_fight()
	d._queue.clear()
	d._hazards.clear()
	var m := d.spawn("slime", "", Vector2(d.gate_pos.x, d.wall_foot_y() + 300.0))
	m.mind = null
	await _wait(0.3)
	var counting := d.next_left > 0.0
	d.next_left = 0.2
	await _until(func(): return d.wave == 2, 3.0)
	await _wait(0.2)
	check("这一波出完怪后倒计时（%s），到点自动进第 2 波（%d，%s），上一波的怪还留在场上（%s）" % [counting, d.wave, d.state, is_instance_valid(m) and m.is_alive()],
		counting and d.wave == 2 and d.state == "fight" and is_instance_valid(m) and m.is_alive())
	d._queue.clear()
	d._hazards.clear()
	for mm in d.monsters.duplicate():
		if is_instance_valid(mm):
			mm.health.damage(999)
	await _until(func(): return d.wave == 3, 3.0)
	check("场上清空就立刻进下一波（第 %d 波）" % d.wave, d.wave == 3)
	var ws: Array = d.data.get("waves", [])
	var with_boss: bool = ws[2].get("groups", []).any(func(g): return str(g.get("monster", "")) == "troll_general")
	check("第 3 波里有小 Boss 攻城巨魔将军（%s），每波都有 countdown（%s）" % [with_boss, ws.all(func(w): return int(w.get("countdown", 0)) == 15)],
		with_boss and ws.all(func(w): return int(w.get("countdown", 0)) == 15))
	await _clear()


# ------------------------------------------------------------------ 3 镇民支援
func _run_town() -> void:
	print("-- 镇民支援")
	await _clear()
	var all := TownBuffs.all()
	check("12 个镇民支援，派对者的激励开局给（after_wave 0：%s）" % [TownBuffs.for_wave(0).get("id", "")],
		all.size() == 12 and str(TownBuffs.for_wave(0).get("id", "")) == "party")
	d.town.owned.clear()
	GameState.vars["siege_town_buffs"] = []
	for c: PlayableCharacter in [d.pink, d.blue]:
		for id in c.buffs.keys():
			if str(id).begins_with("town_"):
				c.remove_buff(id)
	# 过场：开 → 暂停 → 跳过 → 恢复
	TownBuffShow.enabled = true
	var sp0 := d.pink.stat_mul("speed")
	var done := [false]
	var job := func():
		await d.town.grant("party")
		done[0] = true
	job.call()
	await get_tree().process_frame
	var show_node: Node = d.find_children("*", "TownBuffShow", false, false).front() if not d.find_children("*", "TownBuffShow", false, false).is_empty() else null
	var paused := get_tree().paused
	var cam := GameState.player.camera
	var cam_ok := cam.get_screen_center_position().distance_to(d.gate_pos) < 400.0
	await get_tree().create_timer(0.6, true, false, true).timeout
	if show_node and is_instance_valid(show_node):
		show_node.call("_finish")
	await get_tree().process_frame
	await get_tree().process_frame
	TownBuffShow.enabled = false
	check("过场一开始镜头没有闪到地图左上角（%s）" % [cam_ok], cam_ok)
	check("派对者的激励：播过场（暂停 %s，可以跳过 %s），全部友军移动 +50%%（%.2f → %.2f）" % [paused, done[0], sp0, d.pink.stat_mul("speed")],
		paused and done[0] and not get_tree().paused and is_equal_approx(d.pink.stat_mul("speed"), sp0 * 1.5))
	var wm := d.wall_max
	await d.town.grant("mason", false)
	check("泥瓦匠的砂浆：城墙上限 +15%%（%d → %d）" % [int(wm), int(d.wall_max)], d.wall_max > wm * 1.14)
	var spears := d.soldiers.filter(func(s): return s.role == "spear").size()
	await d.town.grant("captain", false)
	var sp_hp: int = d.soldiers.filter(func(s): return s.role == "spear")[0].health.max_hp
	await get_tree().physics_frame
	await get_tree().physics_frame
	sp_hp = d.soldiers.filter(func(s): return s.role == "spear")[0].health.max_hp
	check("卫兵队长的号令：增派 2 个长矛兵（%d → %d），士兵血量 ×1.5（%d）" % [spears, d.soldiers.filter(func(s): return s.role == "spear").size(), sp_hp],
		d.soldiers.filter(func(s): return s.role == "spear").size() == spears + 2 and sp_hp == 12)
	await d.town.grant("band", false)
	await d.town.grant("smith", false)
	check("乐队 / 铁匠：法术冷却 ×%.2f、冰塔伤害 ×%.2f、士兵攻击 ×%.2f" % [d.town.mul("spell_cd"), d.town.mul("tower_dmg"), d.town.mul("soldier_atk")],
		is_equal_approx(d.town.mul("spell_cd"), 0.75) and is_equal_approx(d.town.mul("tower_dmg"), 1.3) and is_equal_approx(d.town.mul("soldier_atk"), 1.5))
	check("已拿到的支援存进存档（%s）" % [GameState.vars.get("siege_town_buffs", [])], (GameState.vars.get("siege_town_buffs", []) as Array).size() == 5)
	d.bench_soldiers(true)


# ------------------------------------------------------------------ 4 小 Boss
func _run_boss() -> void:
	print("-- 小 Boss：攻城巨魔将军")
	await _clear()
	_fight()
	# 蓝色公主的 AI 会放清凉雪花（降闷笑、解开抓取），这一段先让她站着
	d.blue.set_controller(CharacterController.new())
	var bossbar_seen := [null]
	var cb := func(m: Node): bossbar_seen[0] = m
	GameState.boss_changed.connect(cb)
	var at := Vector2(d.gate_pos.x - 200.0, d.wall_foot_y() + 200.0)
	var g := d.spawn("troll_general", "", at) as TrollGeneral
	await _until(func(): return g._intro_done and g.visible and g.is_physics_processing(), 4.0)
	await _wait(0.5)
	var escorts := d.monsters.filter(func(m): return m.has_meta("escort_of") and m.get_meta("escort_of") == g)
	check("出场：钻出来（%s），Boss 血条（%s），带 4 只盾甲螃蟹护卫（%d）" % [g.visible, bossbar_seen[0] == g, escorts.size()],
		g.visible and bossbar_seen[0] == g and escorts.size() == 4)
	var p := d.pink
	var ok := {}
	for s in ["swipe", "quake", "cry", "banner", "build", "ram", "leap", "throw"]:
		p.global_position = g.global_position + Vector2(20, 10)
		p.laugh.set_value(0.0)
		if s == "throw":
			for i in 2:
				var mm := d.spawn("slime", "", g.global_position + Vector2(10 + i * 6, 6))
				mm.mind = null
		g.skill = ""
		g.mode = TickleTroll.Mode.NORMAL
		g._start(s)
		await _until(func(): return g.skill == "", 8.0)
		ok[s] = g.used.has(s) and g.skill == ""
		Engine.time_scale = 1.0
	var banner_ok := get_tree().get_nodes_in_group("siege_enemy_tower").any(func(n): return n is TrollGeneral.TrollBanner)
	var site_ok := get_tree().get_nodes_in_group("siege_enemy_site").any(func(n): return (n as EnemySite).temporary)
	check("技能都能放完：%s；军旗立起来（%s），就地搭塔的临时地基（%s）" % [ok, banner_ok, site_ok],
		ok.values().all(func(v): return v) and banner_ok and site_ok)
	# 大手抓挠：抓住、挠脚心、松手后僵直
	p.global_position = g.global_position + Vector2(16, 0)
	g.skill = ""
	g.mode = TickleTroll.Mode.NORMAL
	p.laugh.set_value(0.0)
	g._start("grab")
	await _until(func(): return g.mode == TickleTroll.Mode.GRABBING, 2.0)
	var grabbed := g.mode == TickleTroll.Mode.GRABBING
	var l0 := p.laugh.value
	await _wait(1.0)
	var sole := p.last_tickle != null and p.last_tickle.zone == "sole"
	g._end_grab()
	check("大手抓挠：抓住粉色公主（%s），挠的是脚心（%s，闷笑 %.0f → %.0f），松手后僵直（%s）" % [grabbed, sole, l0, p.laugh.value, g.mode == TickleTroll.Mode.STUNNED],
		grabbed and sole and p.laugh.value > l0 and g.mode == TickleTroll.Mode.STUNNED)
	if p.status:
		p.status.release(true)
	await _wait(2.2)
	var crabs0 := d.monsters.filter(func(m): return m is ShieldCrab).size()
	g.health.damage(g.health.max_hp / 2 + 1)
	await _wait(0.5)
	check("半血狂暴（%s）：变大（%.2f）、技能更快（×%.1f）、又召 4 只盾甲螃蟹（%d → %d）" % [g.raged, g._base_scale, g.rate, crabs0,
			d.monsters.filter(func(m): return m is ShieldCrab).size()],
		g.raged and g._base_scale > 1.1 and g.rate > 1.5 and d.monsters.filter(func(m): return m is ShieldCrab).size() >= crabs0 + 4)
	var cg_pink: bool = (CG.data.get("cgs", {}) as Dictionary).has("death_siege_troll_general")
	check("有专属笑倒 CG（%s）" % cg_pink, cg_pink)
	g.health.damage(999)
	await _wait(0.6)
	check("打倒后血条收起（%s）" % (bossbar_seen[0] == null), bossbar_seen[0] == null)
	GameState.boss_changed.disconnect(cb)
	Engine.time_scale = 1.0
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 5 士兵
func _run_soldiers() -> void:
	print("-- 新士兵")
	await _clear()
	_fight()
	var count := {}
	for s in d.soldiers:
		count[s.role] = int(count.get(s.role, 0)) + 1
	check("编制：%s" % [count], int(count.get("spear", 0)) >= 10 and count.get("archer", 0) == 6 and count.get("shield", 0) == 3
		and count.get("medic", 0) == 2 and count.get("artisan", 0) == 2)
	var sh: SiegeSoldier = d.soldiers.filter(func(s): return s.role == "shield")[0]
	var m := d.spawn("rat", "", sh.global_position + Vector2(60, 40))
	var t := d.nearest_target(m, 300.0)
	check("盾兵嘲讽：附近的怪优先找他（%s）" % (t == sh), t == sh)
	var cart := d.spawn("cart", "", Vector2(sh.global_position.x, sh.global_position.y + 160.0)) as SiegeCart
	cart.health.max_hp = 999
	cart.health.fill()
	sh.post = sh.global_position
	await _until(func(): return cart._phase == "reaim" or not is_instance_valid(cart), 8.0)
	check("攻城车撞上盾兵被挡下一次（车 %s，盾兵撤退 %s）" % [cart._phase if is_instance_valid(cart) else "没了", sh.retreating],
		is_instance_valid(cart) and cart._phase in ["reaim", "warn2", "charge"] and sh.retreating)
	if is_instance_valid(cart):
		cart.health.damage(999)
	var med: SiegeSoldier = d.soldiers.filter(func(s): return s.role == "medic")[0]
	d.pink.global_position = med.global_position + Vector2(10, 0)
	d.pink.laugh.set_value(d.pink.laugh.max_value * 0.6)
	var l0 := d.pink.laugh.value
	med._cd = 0.0
	await _wait(1.5)
	check("医护兵给粉色公主降闷笑（%.0f → %.0f）" % [l0, d.pink.laugh.value], d.pink.laugh.value < l0 - 10.0)
	var w := d.walls[2]
	w.take(200.0)
	var hp0 := d.wall_hp
	var taken0 := w.taken
	await _wait(5.0)
	check("工匠去修最破的那段墙（受损 %.0f → %.0f，城墙 %d → %d）" % [taken0, w.taken, int(hp0), int(d.wall_hp)], w.taken < taken0 - 4.0 and d.wall_hp > hp0)
	d.bench_soldiers(true)


# ------------------------------------------------------------------ 6 友军塔
func _make_tower(kind: String, at: Vector2) -> IceTower:
	var pd := BuildPad.new()
	d.entities().add_child(pd)
	pd.global_position = at
	pd._build(kind, 1)
	return pd.tower


func _run_towers() -> void:
	print("-- 新友军塔")
	await _clear()
	_fight()
	check("冰塔种类（%d 种，有篝火塔）" % IceTower.kinds().size(), IceTower.kinds().size() >= 9 and IceTower.kinds().has("campfire"))
	var at := Vector2(d.gate_pos.x - 300.0, d.wall_foot_y() + 120.0)
	var fire := _make_tower("campfire", at)
	var gh := d.spawn("ghost", "", at + Vector2(400, 0)) as TickleGhost
	gh.mind = null
	await _wait(0.4)
	var hidden0 := gh.revealed
	gh.global_position = at + Vector2(60, 0)
	await _wait(0.4)
	check("篝火塔：火光里的幽灵现形（远处 %s → 火边 %s）" % [hidden0, gh.revealed], not hidden0 and gh.revealed)
	var et_site: EnemySite = get_tree().get_nodes_in_group("siege_enemy_site")[0]
	var bal_at := et_site.global_position + Vector2(0, -300)
	bal_at.y = maxf(bal_at.y, d.wall_foot_y() + 40.0)
	var et := et_site.build_tower("glue")
	var bal := _make_tower("ballista", Vector2(et_site.global_position.x + 30.0, minf(et_site.global_position.y - 200.0, et_site.global_position.y - 60.0)))
	var hp0 := et.health.hp
	bal._t = 0.0
	await _wait(0.5)
	check("冰棱弩炮优先打敌塔，伤害 ×3（%d → %d）" % [hp0, et.health.hp if is_instance_valid(et) else 0],
		not is_instance_valid(et) or et.health.hp <= hp0 - 9)
	var coc := _make_tower("cocoa", at + Vector2(200, 0))
	d.pink.global_position = coc.global_position + Vector2(10, 0)
	await _wait(0.8)
	check("热可可摊：旁边的友军加速（%s，速度 ×%.2f）" % [d.pink.has_buff("town_cocoa"), d.pink.stat_mul("speed")], d.pink.has_buff("town_cocoa"))
	fire.queue_free()
	bal.queue_free()
	coc.queue_free()


# ------------------------------------------------------------------ 7 法术
func _run_spells() -> void:
	print("-- 新法术 / 射程 / 镜头跟随")
	await _clear()
	_fight()
	var b := d.blue
	check("城墙法术 7 个（%s），射程 %d" % [SiegeSpells.ORDER, int(SiegeSpells.RANGE)], SiegeSpells.ORDER.size() == 7 and SiegeSpells.RANGE >= 640.0)
	var at := Vector2(b.global_position.x, d.wall_foot_y() + 200.0)
	var ms: Array[Monster] = []
	for i in 5:
		var m := d.spawn("rat", "", at + Vector2(i * 8 - 16, 0))   # 不用史莱姆（挤在一起会合体）
		m.mind = null
		m.health.max_hp = 99
		m.health.fill()
		m.set_physics_process(false)   # 站着别动，看暴风雪的效果
		ms.append(m)
	_ready_caster(b)
	var ok_bz := _cast_retry(b, "blizzard", at)
	await _wait(2.3)
	var chilled := ms.filter(func(m): return is_instance_valid(m) and m.has_buff("siege_chill")).size()
	var hurt := ms.filter(func(m): return is_instance_valid(m) and m.health.hp < 99).size()
	check("暴风雪：放出（%s），里面的怪减速（%d 只）、持续掉血（%d 只）" % [ok_bz, chilled, hurt], ok_bz and chilled >= 4 and hurt >= 4)
	_ready_caster(b)
	var line_m := d.spawn("rat", "", Vector2(b.global_position.x, d.wall_foot_y() + 120.0))
	line_m.mind = null
	line_m.health.max_hp = 99
	line_m.health.fill()
	line_m.set_physics_process(false)
	var ok_sp := _cast_retry(b, "spike", Vector2(b.global_position.x, d.wall_foot_y() + 300.0))
	await _wait(1.2)
	check("冰川突刺：一条直线上的怪挨打（%s，%d）" % [ok_sp, line_m.health.hp], ok_sp and line_m.health.hp <= 95)
	var mat := Vector2(b.global_position.x + 120.0, d.wall_foot_y() + 160.0)
	var near := d.spawn("rat", "", mat + Vector2(40, 30))
	near.mind = null
	near.set_physics_process(false)
	_ready_caster(b)
	var ok_mr := _cast_retry(b, "mirror", mat)
	await _wait(0.2)
	var mirror: Node = get_tree().get_nodes_in_group("siege_temp").filter(func(n): return n is SiegeSpells.IceMirror).front() \
		if get_tree().get_nodes_in_group("siege_temp").any(func(n): return n is SiegeSpells.IceMirror) else null
	var lured := mirror != null and d.nearest_target(near, 400.0) == mirror
	if mirror:
		mirror.call("shatter")
	await _wait(0.1)
	check("冰镜分身：怪物被吸过去（%s），碎掉时冻住周围的怪（%s）" % [lured, near.is_stunned()], ok_mr and lured and near.is_stunned())
	# 镜头跟随准星
	b.set_controller(d._make_ai(b))
	GameState.switch_control(b)
	await _wait(0.3)
	b.set_meta("siege_cd", {})
	d.aim.open(b, "ice_rain")
	d.aim.point = b.global_position + Vector2(0, 500)
	await _wait(1.0)
	var off := b.camera.offset
	d.aim.close()
	await _wait(0.6)
	check("瞄准时镜头跟着准星走（offset %.0f），收起后回来（%.0f）" % [off.y, b.camera.offset.y], off.y > 300.0 and absf(b.camera.offset.y) < 30.0)
	b.camera_bias = Vector2.ZERO
	GameState.switch_control(d.pink)
	await _wait(0.3)


## 千手痒痒裤有几率让她施法失败：失败了清冷却再放（最多 8 次）。
func _cast_retry(b: PlayableCharacter, id: String, at: Vector2) -> bool:
	for i in 8:
		_ready_caster(b)
		if SiegeSpells.cast(b, id, at):
			return true
	return false


## 施法前：冷却清掉、魔力疲倦 / 闷笑清零、松开（被吸住 / 缠住时放不出来）。
func _ready_caster(b: PlayableCharacter) -> void:
	b.set_meta("siege_cd", {})
	if b.fatigue:
		b.fatigue.clear()
	b.laugh.set_value(0.0)
	if b.status:
		b.status.release(true)
	for m in d.enemies_near(b.global_position, 60.0):
		m.queue_free()
	b.set_controller(CharacterController.new())   # AI 别抢着放


# ------------------------------------------------------------------ 8 敌塔
func _run_etowers() -> void:
	print("-- 敌塔")
	await _clear()
	_fight()
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	var nearest := 99999.0
	for s in sites:
		nearest = minf(nearest, (s as Node2D).global_position.y - d.wall_foot_y())
	check("地基 %d 个，离城墙最近 %.0f 像素（≤ 6 格）" % [sites.size(), nearest], sites.size() >= 30 and nearest <= 96.0)
	check("强风风车范围 %d（≥ 300）" % int(EnemyTower.info("windmill").get("range", 0)), int(EnemyTower.info("windmill").get("range", 0)) >= 300)
	var site: EnemySite = sites[sites.size() / 2]
	var t := site.build_tower("windmill")
	await _wait(0.3)
	var p := d.pink
	p.global_position = t.global_position + Vector2(0, -12)
	p.facing = Vector2.DOWN
	var hp0 := t.health.hp
	for i in 6:
		p.attack()
		await _wait(0.35)
	check("粉色公主的近战能打到塔身（%d → %d，血 %d）" % [hp0, t.health.hp if is_instance_valid(t) else 0, hp0],
		not is_instance_valid(t) or t.health.hp < hp0)
	if is_instance_valid(t):
		t.health.damage(999)
	await _wait(0.8)
	check("打倒的塔塌掉、地基空出来（%s）" % (site.tower == null), site.tower == null and not is_instance_valid(t))


# ------------------------------------------------------------------ 9 战场：边界 / 斜着走 / 绕障 / 出生动画
func _run_field() -> void:
	print("-- 边界 / 行军 / 绕障 / 出生动画")
	await _clear()
	_fight()
	var ms := d.map_size()
	var m := d.spawn("rat", "", Vector2(30.0, d.wall_foot_y() + 500.0))
	m.target = null
	await _wait(0.2)
	var mx := float(m.get_meta("march_x", 0.0))
	m.global_position = Vector2(-50, d.wall_foot_y() + 500.0)
	await _wait(0.5)
	check("左边出生的怪：目标墙段往中间（march_x %.0f），被推出地图会被拉回来（x %.0f）" % [mx, m.global_position.x], mx > 120.0 and m.global_position.x >= 16.0)
	# 绕开挡路的东西：怪物正前方放一块挡板
	var y0 := d.wall_foot_y() + 300.0
	var x0 := ms.x / 2.0 + 300.0
	var block := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 16)
	cs.shape = r
	block.add_child(cs)
	d.entities().add_child(block)
	block.global_position = Vector2(x0, y0 - 40.0)
	var walker := d.spawn("slime", "", Vector2(x0, y0))
	walker.set_meta("march_x", x0)
	walker.mind.set("drift", 0.0)
	walker.health.max_hp = 999
	walker.health.fill()
	await _until(func(): return not is_instance_valid(walker) or walker.global_position.y < y0 - 70.0, 10.0)
	check("被挡住时自动绕过去（y %.0f → %.0f）" % [y0, walker.global_position.y if is_instance_valid(walker) else -1.0],
		is_instance_valid(walker) and walker.global_position.y < y0 - 70.0)
	block.queue_free()
	d.quiet_spawn = false
	var em := d.spawn("rat", "", Vector2(x0 - 200.0, y0))
	var p0 := em.global_position
	await _wait(0.4)
	var still: bool = em.global_position.distance_to(p0) < 3.0 and em.get_meta("siege_spawning", false)
	await _wait(1.0)
	d.quiet_spawn = true
	check("出生动画：刚钻出来的 0.6 秒不动（%s），之后正常走（移动 %.0f）" % [still, em.global_position.distance_to(p0)],
		still and em.global_position.distance_to(p0) > 5.0)


# ------------------------------------------------------------------ 10 攻城车
func _run_cart() -> void:
	print("-- 攻城车")
	await _clear()
	_fight()
	var cart := d.spawn("cart", "", Vector2(d.gate_pos.x + 300.0, d.wall_foot_y() + 400.0)) as SiegeCart
	await _until(func(): return cart._phase == "charge" and cart._speed > 60.0, 6.0)
	var src := Src.new()
	add_child(src)
	src.global_position = cart.global_position + Vector2(0, 30)
	for i in 3:
		cart.receive_hit(HitData.make_attack(src, 1, 0.0))
	await _wait(0.2)
	src.queue_free()
	check("冲锋时挨打不会被打断（%s，速度 %.0f）" % [cart._phase, cart._speed], cart._phase == "charge" and cart.state != Monster.State.HURT)
	cart._start_reaim()
	await _until(func(): return cart._phase == "charge", 3.0)
	check("被挡住后很快重新瞄准再冲（%s）" % cart._phase, cart._phase == "charge")
	cart.health.damage(999)


# ------------------------------------------------------------------ 11 城墙
func _run_wall() -> void:
	print("-- 城墙")
	await _clear()
	var w := d.walls[3]
	check("城墙画在人物下面（墙 z %d，粉色公主 z %d）" % [w.z_index, d.pink.z_index], w.z_index < d.pink.z_index)
	d.pink.global_position = Vector2(w.global_position.x, d.wall_foot_y() + 30.0)
	GameState.switch_control(d.pink)
	var ev := InputEventAction.new()
	ev.action = "move_up"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(1.2)
	var up := InputEventAction.new()
	up.action = "move_up"
	up.pressed = false
	Input.parse_input_event(up)
	check("往城墙走会被墙脚挡住（y %.0f ≥ 墙脚 %.0f + %.0f）" % [d.pink.global_position.y, d.wall_foot_y(), SiegeWall.FOOT_STRIP],
		d.pink.global_position.y >= d.wall_foot_y() + SiegeWall.FOOT_STRIP)


# ------------------------------------------------------------------ 11b 输入锁 / 释放的目标
func _run_locks() -> void:
	print("-- 输入锁 / 被释放的目标")
	await _clear()
	_fight()
	# 救援中途换人：救完之后换过去的人照样能动
	PlayerInputController.movement_locked = true
	d.rescuing = false
	await get_tree().process_frame
	await get_tree().process_frame
	check("没人在瞄准 / 救援 / 放冰光时，残留的移动锁会被解开（%s）" % (not PlayerInputController.movement_locked), not PlayerInputController.movement_locked)
	# 怪物的目标被释放：不报错、忘掉它
	var sm := Snowman.new()
	d.entities().add_child(sm)
	sm.global_position = d.gate_pos + Vector2(0, 200)
	var frog := d.spawn("frog", "", sm.global_position + Vector2(20, 0))
	frog.target = sm
	frog.state = Monster.State.CHASE
	sm.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("目标被释放后怪物把它忘掉（%s）" % (frog.target == null), frog.target == null)


# ------------------------------------------------------------------ 第五轮的 bug
func _run_bugs5() -> void:
	print("-- 第五轮 bug：释放的目标 / 活梯子 / 开心表情")
	await _clear()
	_fight()
	# 1 目标 queue_free 之后（释放的对象和 null 相等，之前的保护失效）
	var sm := Snowman.new()
	d.entities().add_child(sm)
	sm.global_position = d.gate_pos + Vector2(0, 220)
	var sq := d.spawn("squirrel", "", sm.global_position + Vector2(20, 0))
	sq.target = sm
	sq.state = Monster.State.CHASE
	sm.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("目标 queue_free 后刷刷松鼠把它忘掉（%s）" % (not is_instance_valid(sq.target)), not is_instance_valid(sq.target) and sq.target == null)
	# 2 活梯子：粉色公主在墙脚就能打到
	var atw := Vector2(d.gate_pos.x - 300.0, d.wall_foot_y() + 4.0)
	var geckos := d.teamwork.spawn_formation("gecko_ladder", atw)
	for g in geckos:
		g.global_position = atw + Vector2(randf_range(-6, 6), 0)
		g.mind = null
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var lad := LivingLadder.near(get_tree(), atw.x)
	var in_group := lad != null and lad.is_in_group("siege_enemy_tower")
	var p := d.pink
	if lad:
		p.global_position = Vector2(lad.global_position.x, d.wall_foot_y() + 14.0)
	p.facing = Vector2.UP
	var hp0 := 0
	for g in geckos:
		if is_instance_valid(g):
			hp0 += g.health.hp
	for i in 10:
		p.set_invulnerable(0.0)
		p.attack()
		await _wait(0.3)
	var hp1 := 0
	for g in geckos:
		if is_instance_valid(g):
			hp1 += g.health.hp
	check("活梯子：粉色公主在墙脚就打得到（壁虎血 %d → %d），在敌塔组里（%s）" % [hp0, hp1, in_group], in_group and hp1 < hp0)
	await _clear()
	_fight()
	# 3 开心表情：士兵打倒的不算，自己打倒的才算
	p._happy_at = -INF   # 前面打梯子时她自己打倒过壁虎（4 秒内不重复开心）
	var emotes := []
	var cb := func(e: String, _dur: float, _b: bool): emotes.append(e)
	GameState.emotion_requested.connect(cb)
	var src := Src.new()
	add_child(src)
	for i in 6:
		var m := d.spawn("slime", "", d.gate_pos + Vector2(i * 10, 200))
		m.receive_hit(HitData.make_attack(d.soldiers[0], 99, 0.0))
	await _wait(0.2)
	var happy_by_others := emotes.count("happy")
	var mine := d.spawn("slime", "", p.global_position + Vector2(10, 0))
	mine.receive_hit(HitData.make_attack(p, 99, 0.0))
	await _wait(0.2)
	GameState.emotion_requested.disconnect(cb)
	src.queue_free()
	check("士兵打倒的怪不让粉色公主开心（%d 次），她自己打倒的才开心（%s）" % [happy_by_others, emotes.count("happy") > happy_by_others],
		happy_by_others == 0 and emotes.count("happy") == 1)


# ------------------------------------------------------------------ 第五轮的塔
func _cluster(at: Vector2, n: int, key := "rat") -> Array[Monster]:
	var out: Array[Monster] = []
	for i in n:
		var m := d.spawn(key, "", at + Vector2.from_angle(TAU * i / n) * 10.0)
		m.mind = null
		m.health.max_hp = 99
		m.health.fill()
		m.set_physics_process(false)
		out.append(m)
	return out


func _hurt(ms: Array[Monster]) -> int:
	return ms.filter(func(m): return is_instance_valid(m) and m.health.hp < 99).size()


func _run_towers5() -> void:
	print("-- 第五轮的塔：范围伤害 / 新塔 / 3 级 / 解锁")
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	var base := Vector2(d.gate_pos.x - 300.0, d.wall_foot_y() + 140.0)
	var ok := {}
	# 冰锥溅射
	var t := _make_tower("icicle", base)
	var ms := _cluster(base + Vector2(0, 60), 4)
	await _wait(2.0)
	ok["冰锥溅射"] = _hurt(ms) >= 2
	t.queue_free()
	d.clear_field()
	# 寒霜冰爆
	t = _make_tower("frost", base)
	ms = _cluster(base + Vector2(0, 30), 4)
	await _wait(1.0)
	ok["寒霜冰爆"] = _hurt(ms) >= 3
	t.queue_free()
	d.clear_field()
	# 雪人：数量 / 雪球
	t = _make_tower("snowman", base)
	await _wait(0.3)
	var snows := get_tree().get_nodes_in_group("siege_temp").filter(func(n): return n is Snowman)
	ms = _cluster(base + Vector2(0, 70), 3)
	await _wait(3.0)
	ok["雪人 3 只 + 雪球"] = snows.size() == 3 and _hurt(ms) >= 2 and int(t.p("interval")) == 7
	t.queue_free()
	d.clear_field()
	for n in get_tree().get_nodes_in_group("siege_temp"):
		if n is Snowman:
			n.queue_free()
	# 新塔
	for k in ["mortar", "vortex", "resonance", "meteor"]:
		t = _make_tower(k, base)
		ms = _cluster(base + Vector2(0, 60), 5)
		t._t = 0.0
		await _wait(2.6 if k != "meteor" else 2.4)
		ok[k] = _hurt(ms) >= 3
		t.queue_free()
		d.clear_field()
		await _wait(0.2)
	# 温泉
	t = _make_tower("hotspring", base)
	d.pink.global_position = base + Vector2(20, 10)
	d.pink._full_invuln = 3.0
	d.pink.laugh.set_value(d.pink.laugh.max_value * 0.6)
	var l0 := d.pink.laugh.value
	await _wait(1.5)
	ok["温泉降闷笑"] = d.pink.laugh.value < l0 - 3.0
	t.queue_free()
	# 冰灯
	t = _make_tower("lamp", base)
	ms = _cluster(base + Vector2(0, 40), 2)
	await _wait(0.8)
	ok["冰灯减速 + 敌塔变慢"] = ms[0].stat_mul("speed") < 0.8 and IceTower.lamp_slow_at(get_tree(), base + Vector2(30, 0)) > 1.2
	t.queue_free()
	d.clear_field()
	# 冰盾
	t = _make_tower("shield", base)
	d.pink.global_position = base + Vector2(20, 10)
	d.pink._full_invuln = 0.0
	d.pink.set_invulnerable(0.0)
	t._t = 0.0
	await _wait(0.4)
	var shielded := d.pink.has_buff("ice_shield")
	var s2 := Src.new()
	s2.reaction_key = "slime"
	add_child(s2)
	d.pink.laugh.set_value(0.0)
	var blocked := not d.pink.receive_hit(HitData.make_tickle(s2, 10.0))
	s2.queue_free()
	ok["冰盾挡一下"] = shielded and blocked and not d.pink.has_buff("ice_shield") and d.pink.laugh.value == 0.0
	t.queue_free()
	var bad := ok.keys().filter(func(k): return not ok[k])
	check("范围伤害 / 新塔都生效（没生效：%s）" % [bad], bad.is_empty())
	# 3 级：范围更大
	t = _make_tower("frost", base)
	var r1 := float(t.p("radius"))
	t.upgrade()
	t.upgrade()
	check("升到 3 级（%d），范围变大（%.0f → %.0f）" % [t.level, r1, float(t.p("radius"))], t.level == 3 and float(t.p("radius")) > r1)
	t.queue_free()
	# 解锁
	d.wave = 2
	var locked := not IceTower.unlocked("mortar")
	d.wave = 3
	check("冰霜迫击炮第 3 波才解锁（第 2 波 %s，第 3 波 %s），共 %d 种塔" % [locked, IceTower.unlocked("mortar"), IceTower.kinds().size()],
		locked and IceTower.unlocked("mortar") and IceTower.kinds().size() == 16)
	d.wave = 1
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 第六轮的修正
func _run_fixes6() -> void:
	print("-- 第六轮修正：雪人 / 活梯子上半段 / 幽灵 / 小 Boss / 蓝色公主卡死 / 旧 Boss 当小怪 / 配合技情报 / 第 10 波")
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	# 1 雪人有速度加成时站着扔雪球，不会越来越快把自己扔飞
	var base := Vector2(d.gate_pos.x - 260.0, d.wall_foot_y() + 160.0)
	var sm := Snowman.new()
	d.entities().add_child(sm)
	sm.global_position = base
	sm.add_buff("siege_carnival", 99.0)
	sm.add_buff("town_party", 99.0)
	var foe := d.spawn("slime", "", base + Vector2(130, 0))   # 射程外：先走过去，再站住扔（原来的 bug：站住时速度越乘越大）
	foe.mind = null
	foe.set_physics_process(false)
	foe.health.max_hp = 999
	foe.health.fill()
	var max_v := 0.0
	for i in 150:
		await get_tree().physics_frame
		max_v = maxf(max_v, sm.velocity.length())
	var moved := sm.global_position.distance_to(base)
	check("雪人走到射程里站着扔雪球（移动 %.0f 像素、最大速度 %.0f），没把自己扔飞" % [moved, max_v], moved > 20.0 and moved < 80.0 and max_v < Snowman.SPEED * 2.0)
	sm.queue_free()
	d.clear_field()
	# 2 活梯子：受击范围高过墙顶；从墙顶打，打到的是正往上爬的怪
	var atw := Vector2(d.gate_pos.x - 320.0, d.wall_foot_y() + 4.0)
	var geckos := d.teamwork.spawn_formation("gecko_ladder", atw)
	for g in geckos:
		g.global_position = atw + Vector2(randf_range(-6, 6), 0)
		g.mind = null
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var lad := LivingLadder.near(get_tree(), atw.x)
	var climber := d.spawn("rat", "", Vector2(atw.x, d.wall_top_y() + 10.0))
	climber.mind = null
	climber.set_physics_process(false)
	climber.global_position = Vector2(atw.x, d.wall_top_y() + 10.0)
	var top_ok := false
	if lad:
		climber.set_meta("ladder_of", lad)
		var cs := lad.get_child(0) as CollisionShape2D
		for c in lad.get_children():
			if c is CollisionShape2D:
				cs = c
		var top_y := lad.global_position.y + cs.position.y - (cs.shape as RectangleShape2D).size.y / 2.0
		top_ok = top_y < d.wall_top_y()
		var src := Src.new()
		add_child(src)
		src.global_position = climber.global_position
		var hp0 := climber.health.hp
		lad.receive_hit(HitData.make_attack(src, 1, 0.0))
		await _wait(0.1)
		check("活梯子受击范围高过墙顶（%s），从墙顶打到正在爬的怪（血 %d → %d）" % [top_ok, hp0, climber.health.hp if is_instance_valid(climber) else -1],
			top_ok and (not is_instance_valid(climber) or climber.health.hp < hp0))
		src.queue_free()
	else:
		check("活梯子没搭起来", false)
	d.clear_field()
	for n in get_tree().get_nodes_in_group("siege_enemy_tower"):
		n.queue_free()
	# 3 幽灵：没显形时不会被选成目标，篝火旁现形后才会
	var gpos := Vector2(d.gate_pos.x + 260.0, d.wall_foot_y() + 200.0)
	var gh := d.spawn("ghost", "", gpos) as TickleGhost
	gh.mind = null
	gh.set_physics_process(false)
	gh._update_reveal()
	var hidden_skip: bool = not d.enemies_near(gpos, 30.0, false).has(gh) and gh.get("attackable") == false
	var cf := _make_tower("campfire", gpos + Vector2(20, 0))
	gh._update_reveal()
	var shown_ok: bool = d.enemies_near(gpos, 30.0, false).has(gh) and gh.get("attackable") == true
	check("没显形的幽灵不当目标（%s），篝火旁现形后才当（%s）" % [hidden_skip, shown_ok], hidden_skip and shown_ok)
	cf.pad.queue_free()
	cf.queue_free()
	d.clear_field()
	# 4 小 Boss：冰塔伤害 25%；狂暴前不上地图上半部、不冲锋不跳劈
	var gat := Vector2(d.gate_pos.x - 200.0, d.map_size().y * 0.75)
	var boss := d.spawn("troll_general", "", gat) as TrollGeneral
	await _until(func(): return boss._intro_done and boss.is_physics_processing(), 5.0)
	await _wait(0.8)
	boss._full_invuln = 0.0
	var tw := _make_tower("icicle", gat + Vector2(0, -80))
	var hp_a := boss.health.hp
	for i in 4:
		boss._attack_invuln = 0.0
		boss.receive_hit(HitData.make_attack(tw, 4, 0.0))
	var tower_loss := hp_a - boss.health.hp
	boss._attack_invuln = 0.0
	var hp_b := boss.health.hp
	boss.receive_hit(HitData.make_attack(d.pink, 4, 0.0))
	var pink_loss := hp_b - boss.health.hp
	check("冰塔打小 Boss 只有 25%%（4 下 ×4 → 掉 %d），粉色公主照常（4 → 掉 %d）" % [tower_loss, pink_loss], tower_loss == 4 and pink_loss == 4)
	tw.pad.queue_free()
	tw.queue_free()
	boss.global_position = Vector2(gat.x, d.wall_foot_y() + 60.0)
	d.pink.global_position = Vector2(gat.x + 600.0, d.map_size().y - 40.0)
	boss.skill = ""
	var picked: Array[String] = []
	for i in 30:
		for k in boss.cds:
			boss.cds[k] = 0.0
		boss.skill = ""
		boss._global_cd = 0.0
		boss._choose()
		if boss.skill != "":
			picked.append(boss.skill)
		boss.skill = ""
		boss.mode = TickleTroll.Mode.NORMAL
	boss.global_position = Vector2(gat.x, d.wall_foot_y() + 60.0)
	var y_up := boss.global_position.y
	await _wait(2.5)
	check("狂暴前：在上半部就往下走回去（y %.0f → %.0f，下半部从 %.0f 开始），路上不放技能（%s），不用冲锋 / 跳劈（选过 %s）" % [y_up,
			boss.global_position.y, boss.min_y(), boss.skill == "", picked],
		boss.global_position.y > y_up + 40.0 and boss.skill == "" and not picked.has("ram") and not picked.has("leap"))
	boss.health.damage(boss.health.max_hp / 2 + 1)
	await _wait(0.3)
	check("狂暴后不再限制（min_y = %s）" % boss.min_y(), boss.raged and boss.min_y() == -INF)
	boss.health.damage(9999)
	await _wait(0.5)
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	# 5 蓝色公主卡死：两个人都倒下也会照常倒计时 / 自己起来；倒了却没有倒地组件，看门狗会补上
	var b := d.blue
	var p := d.pink
	p._dead = true
	p._set_state(PlayableCharacter.State.DEAD)
	var dp := Downed.start(p)
	var dn := Downed.start(b)
	b._dead = true
	b._set_state(PlayableCharacter.State.DEAD)
	dn.revive_after = 0.6
	await _wait(1.2)
	var both_ok := b.is_alive() and not Downed.is_downed(b)
	dp.queue_free()
	p.revive()
	p._set_state(PlayableCharacter.State.IDLE)
	check("两个人都倒下：蓝色公主的倒地照样倒计时、自己起来（%s）" % both_ok, both_ok)
	b._dead = true
	b._set_state(PlayableCharacter.State.DEAD)
	await _until(func(): return Downed.is_downed(b), 6.0)
	var patched := Downed.is_downed(b)
	if patched:
		(b.get_node("Downed") as Downed).revive_after = -1.0
		d._blue_down_t = SiegeDirector.BLUE_REVIVE + 9.5
	await _until(func(): return b.is_alive(), 3.0)
	check("倒了却没有倒地组件 → 看门狗补上（%s），倒地太久直接救起（%s）" % [patched, b.is_alive()], patched and b.is_alive())
	await _clear()
	_fight()
	# 6 旧 Boss（挠痒巨魔）当小怪：不弹 Boss 血条、不掉钥匙
	var seen := [null]
	var cb := func(m: Node): seen[0] = m
	GameState.boss_changed.connect(cb)
	var tr := d.spawn("troll", "", d.gate_pos + Vector2(0, 300))
	tr.state = Monster.State.CHASE
	tr.target = d.pink
	await _wait(0.5)
	GameState.boss_changed.disconnect(cb)
	var keys := tr.stats.drops.filter(func(dr): return dr.item and dr.item.category == ItemData.Category.KEY).size()
	check("挠痒巨魔在攻防战里是小怪：is_boss %s、没弹 Boss 血条（%s）、不掉钥匙（%d）" % [tr.stats.is_boss, seen[0] == null, keys],
		not tr.stats.is_boss and seen[0] == null and keys == 0)
	var orig := load("res://data/monsters/tickle_troll.tres") as MonsterStats
	check("原来的挠痒巨魔数据没被改（第 1~5 层照旧是 Boss：%s）" % orig.is_boss, orig.is_boss)
	d.clear_field()
	# 7 配合技 / 陷阱组合不进情报
	var bad_keys := SiegeIntel.data().keys().filter(func(k): return str(k).begins_with("team_") or str(k).begins_with("hzcombo_"))
	var shown0 := d.intel.shown.size()
	d.teamwork.triggered.emit("slime_merge", d.gate_pos)
	d.spawn_hazard_combo("net_link")
	await _wait(0.2)
	check("配合技不进情报（情报表里 %d 条，发动后新情报 %d 条）" % [bad_keys.size(), d.intel.shown.size() - shown0],
		bad_keys.is_empty() and not d.intel.shown.any(func(k): return str(k).begins_with("team_") or str(k).begins_with("hzcombo_")))
	await _clear()
	# 8 第 10 波不叫最终波
	var w10 := str((d.data["waves"] as Array)[9].get("name", ""))
	check("第 10 波叫「%s」（不是最终波）" % w10, not w10.contains("最终") and not w10.contains("最后"))
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 第六轮：每波特色
func _run_features6() -> void:
	print("-- 每波特色机制")
	await _clear()
	var waves: Array = d.data["waves"]
	var all_ids := {}
	var every := true
	for w in waves:
		var fs: Array = (w as Dictionary).get("features", [])
		every = every and not fs.is_empty()
		for f in fs:
			all_ids[f] = true
	# 叠加看第 11 波（第 12 波是狂欢要塞的最终波，只留狂欢节）
	var later_repeat := (waves[10]["features"] as Array).all(func(f): return all_ids.has(f)) and (waves[10]["features"] as Array).size() >= 3
	check("每波都有特色（%s），12 种都用上（%d），后面的波次叠加前面的（%s）" % [every, all_ids.size(), later_repeat],
		every and all_ids.size() == 12 and later_repeat)
	# 开打时：大字 + 标签 + 配合技频率
	d.wave = 6
	await d._begin_fight()
	await _wait(0.2)
	var on := d.features.active.duplicate()
	check("第 6 波开打：特色 %s、小地图下的标签 %s、配合技冷却 ×%.2f" % [on, d.hud.tags, d.teamwork.cd_scale],
		on == ["gale"] and d.hud.tags == on and d.hud.tag_box.get_child_count() >= 1 and absf(d.teamwork.cd_scale - 1.0 / 1.6) < 0.01)
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	var f := d.features
	var ok := {}
	# 狂风：把粉色公主吹走
	f.begin(["gale"])
	var p := d.pink
	p.global_position = Vector2(d.gate_pos.x, d.wall_foot_y() + 220.0)
	var x0 := p.global_position.x
	f.gust()
	await _wait(1.8)
	ok["狂风"] = absf(p.global_position.x - x0) > 30.0 and signf(p.global_position.x - x0) == f.gust_dir.x
	# 攻城大队：一排车 + 螃蟹护卫
	f.begin(["corps"])
	var carts0 := d.monsters.filter(func(m): return m is SiegeCart).size()
	f.corps()
	await _wait(1.8)
	var carts := d.monsters.filter(func(m): return m is SiegeCart).size() - carts0
	var escorts := d.monsters.filter(func(m): return m is ShieldCrab and m.has_meta("escort_of")).size()
	ok["攻城大队 %d 车 %d 蟹" % [carts, escorts]] = carts >= WaveFeatures.CORPS_MIN and escorts >= WaveFeatures.CORPS_MIN * 2
	d.clear_field()
	_fight()
	# 抢掠小队：拆冰塔，基座留着
	f.begin(["raiders"])
	var tpos := Vector2(d.gate_pos.x + 200.0, d.wall_foot_y() + 160.0)
	var tw := _make_tower("cocoa", tpos)
	var pad := tw.pad
	tw.health.set_hp(3)
	var raiders := f.raid()
	for m in raiders:
		m.global_position = tpos + Vector2(randf_range(-30, 30), 50)
	p.global_position = tpos + Vector2(0, 260)
	var wtw: WeakRef = weakref(tw)
	await _until(func(): return wtw.get_ref() == null, 12.0)
	ok["抢掠小队拆塔、基座留着"] = raiders.size() == 6 and not is_instance_valid(tw) and is_instance_valid(pad) and pad.get("tower") == null \
		and raiders.all(func(m): return not is_instance_valid(m) or m.mind is RaiderMind)
	if is_instance_valid(pad):
		pad.queue_free()
	d.clear_field()
	_fight()
	# 羽毛暴风雪：开阔地涨闷笑，冰塔旁安全
	f.begin(["feathers"])
	p.global_position = Vector2(d.gate_pos.x + 300.0, d.wall_foot_y() + 260.0)
	p.laugh.set_value(0.0)
	await _wait(2.1)
	var open_gain := p.laugh.value
	var st := _make_tower("icicle", p.global_position + Vector2(20, 0))
	p.laugh.set_value(0.0)
	await _wait(1.6)
	ok["羽毛暴风雪 开阔 %.1f / 塔旁 %.1f" % [open_gain, p.laugh.value]] = open_gain > 1.0 and p.laugh.value <= 0.01 and f.feather_safe(p.global_position)
	st.pad.queue_free()
	st.queue_free()
	# 狂欢节：怪加速
	f.begin(["carnival"])
	var cm := d.spawn("slime", "", d.gate_pos + Vector2(0, 300))
	cm.mind = null
	await _wait(1.3)
	ok["狂欢节"] = cm.has_buff("siege_carnival") and cm.stat_mul("speed") > 1.2
	# 迷雾之夜：变暗，结束后恢复
	var dark := d.level().get_node("Darkness") as CanvasModulate
	var c0 := dark.color
	f.begin(["fog"])
	await _wait(1.7)
	var darker := dark.color.v < c0.v - 0.1
	f.end()
	await _wait(1.7)
	ok["迷雾之夜"] = darker and dark.color.is_equal_approx(c0)
	# 工兵狂潮 / 痒痒装备日：倍率
	f.begin(["engineers", "equip"])
	ok["工兵 / 装备倍率"] = WaveFeatures.mul_of("build_speed") == 1.5 and WaveFeatures.mul_of("equip_time") == 1.5
	f.end()
	ok["结束后倍率复原"] = WaveFeatures.mul_of("build_speed") == 1.0
	var bad := ok.keys().filter(func(k): return not ok[k])
	check("特色机制都生效（没生效：%s）" % [bad], bad.is_empty())
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 第七轮
func _run_round7() -> void:
	print("-- 第七轮：活梯子一只倒就散 / 小 Boss 挡波次 / 小 Boss 不卡 / 蓝色公主的通用 AI / 冰法学徒 / 城墙灯")
	await _clear()
	_fight()
	var b := d.blue
	b.set_controller(CharacterController.new())
	# 1 活梯子：打倒一只就散
	var atw := Vector2(d.gate_pos.x - 320.0, d.wall_foot_y() + 4.0)
	var geckos := d.teamwork.spawn_formation("gecko_ladder", atw)
	for g in geckos:
		g.global_position = atw + Vector2(randf_range(-6, 6), 0)
		g.mind = null
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var lad := LivingLadder.near(get_tree(), atw.x)
	var n0 := lad.start_count if lad else 0
	var wl: WeakRef = weakref(lad)
	if lad:
		(lad.alive_geckos()[0] as Monster).health.damage(999)
	await _wait(0.3)
	check("活梯子（%d 只）打倒一只就散（%s）" % [n0, wl.get_ref() == null], n0 >= 3 and wl.get_ref() == null)
	await _clear()
	_fight()
	b.set_controller(CharacterController.new())
	# 2 有小 Boss 的波：打倒它才进下一波
	d.wave = 3
	d._queue.clear()
	var boss := d.spawn("troll_general", "", Vector2(d.gate_pos.x + 300.0, d.map_size().y * 0.8)) as TrollGeneral
	d.monsters = [boss]
	await _wait(2.0)
	var held := d.wave == 3 and d.next_left < 0.0 and d.boss_alive() and d.hud.status_text().contains("小 Boss")
	var told := d.hud.status_text()
	boss.health.damage(99999)
	await _until(func(): return d.next_left >= 0.0 or d.wave == 4, 4.0)
	check("第 3 波：小 Boss 在场时不进下一波（%s，「%s」），打倒后开始下一波倒计时 / 进第 4 波（%.0f 秒，第 %d 波）" % [held, told, d.next_left, d.wave],
		held and (d.next_left >= 0.0 or d.wave == 4))
	await _clear()
	_fight()
	b.set_controller(CharacterController.new())
	# 3 小 Boss 被建筑挡住：绕开 / 穿过去
	var g2 := d.spawn("troll_general", "", Vector2(d.gate_pos.x, d.map_size().y * 0.85)) as TrollGeneral
	await _until(func(): return g2._intro_done and g2.is_physics_processing(), 5.0)
	await _wait(0.8)
	for k in g2.cds:
		g2.cds[k] = 999.0
	d.pink.global_position = Vector2(d.gate_pos.x + 900.0, d.map_size().y - 30.0)
	var box := StaticBody2D.new()
	box.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(160, 16)
	cs.shape = rs
	box.add_child(cs)
	d.entities().add_child(box)
	box.global_position = g2.global_position + Vector2(0, -34)
	b.global_position = Vector2(g2.global_position.x, b.global_position.y)
	var y0 := g2.global_position.y
	await _wait(6.0)
	check("小 Boss 被挡住会绕开 / 穿过去（处理了 %d 次，y %.0f → %.0f）" % [g2.unstuck, y0, g2.global_position.y],
		g2.unstuck > 0 and g2.global_position.y < box.global_position.y - 4.0)
	box.queue_free()
	g2.health.damage(99999)
	await _clear()
	_fight()
	# 4 蓝色公主的 AI：Boss 战的通用功能（挣扎 / 闪避 / 打墙顶的怪）
	var ai := d._make_ai(b)
	b.set_controller(ai)
	var is_comp := ai is CompanionController
	var wm := d.spawn("slime", "", b.global_position + Vector2(12, 0))
	wm.mind = null
	wm.health.max_hp = 99
	wm.health.fill()
	TeamworkEffects.put_on_wall(wm, b.global_position + Vector2(12, 0))
	var hp0 := wm.health.hp
	var fought := false
	for i in 30:
		await _wait(0.1)
		fought = fought or (ai as SiegeMageController).intent == "attack"
	check("蓝色公主的 AI 是通用 AI（%s），爬上墙的怪贴过来先打（%s，血 %d → %d）" % [is_comp, fought, hp0, wm.health.hp],
		is_comp and fought and wm.health.hp < hp0)
	wm.queue_free()
	await _wait(0.2)
	var src := Src.new()
	add_child(src)
	src.global_position = b.global_position
	b.status.grab(src, 3.0, 10)
	await _wait(0.3)
	var struggled := (ai as SiegeMageController).intent == "struggle"
	b.status.release(true)
	src.queue_free()
	await _wait(0.5)
	d.knock_off(b, "测试")
	await _until(func(): return not b.get_meta("siege_falling", false), 4.0)
	await _wait(0.3)
	var at := b.global_position
	SiegeFx.warn(d.entities(), at, "circle", 36.0, 1.5, Color(1, 0.4, 0.3), 0.0, 1.2, true)
	var dodged := false
	for i in 12:
		await _wait(0.1)
		dodged = dodged or (ai as SiegeMageController).intent == "dodge"
	check("被抓住连按挣扎（%s）；墙下踩到预警会闪开（%s，离开 %.0f 像素）" % [struggled, dodged, b.global_position.distance_to(at)],
		struggled and dodged and b.global_position.distance_to(at) > 20.0)
	d.revive_blue(b)
	await _clear()
	_fight()
	b.set_controller(CharacterController.new())
	# 5 冰法学徒：帮忙放冰光，效率是蓝色公主的一半
	var mages := d.soldiers.filter(func(x): return is_instance_valid(x) and x.role == "mage")
	d.bench_soldiers(false)
	d.add_crystals(200)
	var pd := BuildPad.new()
	d.entities().add_child(pd)
	pd.global_position = Vector2(d.gate_pos.x - 80.0, d.wall_foot_y() + 90.0)
	await _wait(0.1)
	pd.request("icicle")
	var need := pd._need
	await _until(func(): return pd.helpers.size() >= 1 or pd.tower != null, 15.0)
	var n_help := pd.helpers.size()
	var p_a := pd.progress
	await _wait(0.4)
	var same := pd.helpers.size() == n_help and not pd.pending.is_empty()
	var rate := (pd.progress - p_a) / 0.4 / maxf(n_help, 1)
	var most := 0
	while pd.tower == null and most < 300:
		await _wait(0.05)
		most += 1
	check("冰法学徒 %d 个，%d 个在帮忙，每个 %.2f / 秒（蓝色公主是 1，一半），塔造好了（%s）" % [mages.size(), n_help, rate, pd.tower != null],
		mages.size() == 3 and n_help >= 1 and (not same or absf(rate - 0.5) < 0.1) and pd.tower != null and need > 0.0)
	# 和蓝色公主一起放：更快
	var pd2 := BuildPad.new()
	d.entities().add_child(pd2)
	pd2.global_position = Vector2(d.gate_pos.x - 80.0, d.wall_foot_y() + 150.0)
	await _wait(0.1)
	pd2.request("icicle")
	await _until(func(): return pd2.helpers.size() >= 1, 15.0)
	pd2.blue_beam(b)
	var q0 := pd2.progress
	await _wait(0.5)
	var rate2 := (pd2.progress - q0) / 0.5
	check("蓝色公主 + 学徒一起放冰光更快（%.2f / 秒 > 1）" % rate2, rate2 > 1.3)
	await _until(func(): return pd2.tower != null, 10.0)
	check("造好后蓝色公主不再锁在冰光里（%s）" % (not b.get_meta("siege_beaming", false)), not b.get_meta("siege_beaming", false) and not pd2.beaming)
	d.bench_soldiers(true)
	# 6 城墙上的灯
	var lights := 0
	var braziers := 0
	for w in d.walls:
		for c in w.get_children():
			if c is SiegeWall.WallLight:
				lights += 1
				if c.is_in_group("torch"):
					braziers += 1
	check("城墙上的灯 %d 盏（火盆 %d 个，幽灵靠近会现形）" % [lights, braziers], lights >= 32 and braziers >= 16)
	b.set_controller(d._make_ai(b))


# ------------------------------------------------------------------ 第八轮
func _run_round8() -> void:
	print("-- 第八轮：活梯子连着打得到 / 蓝色公主法术更勤 / 跟着粉色公主放魔法")
	await _clear()
	_fight()
	var b := d.blue
	b.set_controller(CharacterController.new())
	# 1 活梯子：每一下都打得到（之前壁虎物理关掉了，受一次击后无敌时间不再减少，之后都打不到）
	var atw := Vector2(d.gate_pos.x - 320.0, d.wall_foot_y() + 4.0)
	var geckos := d.teamwork.spawn_formation("gecko_ladder", atw)
	for g in geckos:
		g.global_position = atw + Vector2(randf_range(-6, 6), 0)
		g.mind = null
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.6)
	var lad := LivingLadder.near(get_tree(), atw.x)
	var wl: WeakRef = weakref(lad)
	var src := Src.new()
	add_child(src)
	src.global_position = Vector2(atw.x, d.wall_foot_y() + 14.0)
	var landed := 0
	for i in 4:
		var l := wl.get_ref() as LivingLadder
		if l == null:
			break
		if l.receive_hit(HitData.make_attack(src, 1, 0.0)):
			landed += 1
		await _wait(0.3)
	src.queue_free()
	check("活梯子连着打：每一下都打得到（打中 %d 下），打倒一只就散（%s）" % [landed, wl.get_ref() == null], landed >= 2 and wl.get_ref() == null)
	await _clear()
	_fight()
	# 2 蓝色公主的 AI：冷却 × 0.6、法术放得勤
	var ai := d._make_ai(b) as SiegeMageController
	b.set_controller(ai)
	b.set_meta("siege_cd", {})
	if b.fatigue:
		b.fatigue.clear()
	var at := Vector2(b.global_position.x, d.wall_foot_y() + 140.0)
	SiegeSpells.cast(b, "ice_rain", at)
	var cd_ai := SiegeSpells.cooldown_left(b, "ice_rain")
	b.set_meta("siege_cd", {})
	var ms: Array[Monster] = []
	for i in 14:
		var m := d.spawn("slime", "", at + Vector2(randf_range(-40, 40), randf_range(-20, 20)))
		m.mind = null
		m.set_physics_process(false)
		m.health.max_hp = 999
		m.health.fill()
		ms.append(m)
	var casts := {}
	for i in 60:
		await _wait(0.1)
		for id in SiegeSpells.INFO:
			if SiegeSpells.cooldown_left(b, id) > 0.0:
				casts[id] = true
	check("AI 的冷却是 0.6 倍（冰锥雨 %.1f 秒，原来 3.5），6 秒里放了 %d 种法术（%s）" % [cd_ai, casts.size(), casts.keys()],
		absf(cd_ai - 3.5 * SiegeSpells.AI_CD * (d.town.mul("spell_cd") if d.town else 1.0)) < 0.3 and casts.size() >= 3)
	d.clear_field()
	_fight()
	# 3 粉色公主放魔法：一半的几率跟着放
	var yes := 0
	for i in 400:
		ai._on_pink_magic("channel", 0)
		if ai.join_next:
			yes += 1
	ai.join_next = false
	for i in 6:
		var m2 := d.spawn("slime", "", d.pink.global_position + Vector2(randf_range(-20, 20), randf_range(10, 30)))
		m2.mind = null
		m2.set_physics_process(false)
	# 所有法术都在冷却也能跟着放（不看冷却的冰锥雨）
	var big := {}
	for id in SiegeSpells.INFO:
		big[id] = Time.get_ticks_msec() / 1000.0 + 999.0
	b.set_meta("siege_cd", big)
	var j0 := ai.joined
	# 千手痒痒裤之类的装备会让魔法有几率失败：多试几次
	for i in 6:
		if ai.joined > j0:
			break
		ai._on_pink_magic("channel", 0)
		ai.join_next = true
		d.pink.magic_event.emit("burst", 2)
		await _wait(0.2)
	check("粉色公主吟唱时跟着放的几率 %.0f%%（约一半），她放出来那一下蓝色公主一起放（%d → %d，%s）" % [yes / 4.0, j0, ai.joined, ai.intent],
		yes > 160 and yes < 240 and ai.joined == j0 + 1)
	b.set_meta("siege_cd", {})


# ------------------------------------------------------------------ 第九轮
func _run_round9() -> void:
	print("-- 第九 / 十一轮：盾甲螃蟹只吃冰晶共鸣（10%）和粉色公主从背后的锤子")
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	var at := Vector2(d.gate_pos.x - 260.0, d.wall_foot_y() + 220.0)
	var hurt := {}
	for kind in ["icicle", "icicle_back", "resonance", "meteor"]:
		var crab := d.spawn("shield_crab", "", at) as ShieldCrab
		crab.mind = null
		crab.set_physics_process(false)
		crab.health.max_hp = 99
		crab.health.fill()
		# 塔在螃蟹上方（正面）；icicle_back 在下方（背后）
		var t := _make_tower(kind.trim_suffix("_back"), at + Vector2(0, 90 if kind == "icicle_back" else -90))
		t.level = 1
		var hp0 := crab.health.hp
		if kind.begins_with("icicle"):
			for i in 3:
				t._t = 0.0
				t._icicle()
				await _wait(0.7)
		elif kind == "resonance":
			t._t = 0.0
			t._resonance()
			await _wait(0.3)
		else:
			t._t = 0.0
			for i in 160:
				t._meteor(0.05)
				await get_tree().physics_frame
			await _wait(1.6)
		hurt[kind] = hp0 - crab.health.hp
		t.pad.queue_free()
		t.queue_free()
		crab.queue_free()
		await _wait(0.2)
	# 公主：粉色公主正面挡住、背后打得动；蓝色公主（法术 / 普攻）打不动
	var crab2 := d.spawn("shield_crab", "", at) as ShieldCrab
	crab2.mind = null
	crab2.set_physics_process(false)
	crab2.health.max_hp = 99
	crab2.health.fill()
	var hits := {}
	for who in ["pink_front", "pink_back", "blue"]:
		var c: PlayableCharacter = d.pink if who.begins_with("pink") else d.blue
		var keep := c.global_position
		c.global_position = at + Vector2(0, 40 if who == "pink_back" else -40)
		var hp1 := crab2.health.hp
		crab2.set_invulnerable(0.0)
		crab2.receive_hit(HitData.make_attack(c, 5, 0.0))
		hits[who] = hp1 - crab2.health.hp
		c.global_position = keep
	crab2.queue_free()
	check("盾甲螃蟹：冰锥正面 %d / 背后 %d、陨石 %d 都打不动，冰晶共鸣只掉 %d；粉色公主正面 %d、背后 %d，蓝色公主 %d" % [hurt["icicle"], hurt["icicle_back"], hurt["meteor"], hurt["resonance"], hits["pink_front"], hits["pink_back"], hits["blue"]],
		hurt["icicle"] == 0 and hurt["icicle_back"] == 0 and hurt["meteor"] == 0 and hurt["resonance"] >= 1 and hurt["resonance"] <= 2
		and hits["pink_front"] == 0 and hits["pink_back"] > 0 and hits["blue"] == 0)
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 第十轮：大型强制位移陷阱 + 新配合技
func _run_round10() -> void:
	print("-- 第十轮：抓娃娃机 / 流沙 / 弹弹蘑菇 / 传送门，四个新配合技")
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	var p := d.pink
	var home := Vector2(d.gate_pos.x + 160.0, d.wall_foot_y() + 200.0)
	var ok := {}
	# 抓娃娃机：抓起来运到怪堆、一路挠
	for i in 8:
		var m := d.spawn("slime", "", home + Vector2(320, 120) + Vector2(randf_range(-20, 20), randf_range(-12, 12)))
		m.mind = null
		m.set_physics_process(false)
	p.global_position = home
	p.laugh.set_value(0.0)
	var claw := d.spawn_hazard("claw", home) as HazardClaw
	claw.target = p
	await _until(func(): return claw.phase == "carry", 6.0)
	var carried := claw.phase == "carry" and p.status.is_grabbed_by(claw)
	await _until(func(): return claw.phase == "rise" or not is_instance_valid(claw), 6.0)
	ok["抓娃娃机 运走 %.0f 像素" % p.global_position.distance_to(home)] = carried and p.global_position.distance_to(home) > 120.0 \
		and p.laugh.value > 0.0 and not p.status.is_grabbed() and p.is_physics_processing()
	d.clear_field()
	_fight()
	# 流沙：吸到中心、抓住挠、标记成被拖着（冰链能救）
	p.global_position = home
	p.laugh.set_value(0.0)
	var qs := d.spawn_hazard("quicksand", home + Vector2(40, 0)) as HazardQuicksand
	await _until(func(): return qs.sunk == p, 7.0)
	var sunk: bool = qs.sunk == p and p.get_meta("siege_dragged", false) and d.rescue_request() == p
	await _wait(1.2)
	var l_sand := p.laugh.value
	qs.release_drag()
	ok["流沙 吸住挠（%.0f）冰链能救" % l_sand] = sunk and l_sand > 0.0 and not p.get_meta("siege_dragged", false) and not p.status.is_grabbed()
	d.clear_field()
	_fight()
	# 弹弹蘑菇：踩到第一颗，一路弹到最后
	p.global_position = home
	p.laugh.set_value(0.0)
	var mush := d.spawn_hazard("mushrooms", home) as HazardMushrooms
	await _until(func(): return mush.warned, 3.0)
	await _wait(0.2)
	await _until(func(): return not mush._bouncing.has(p.get_instance_id()), 6.0)
	ok["弹弹蘑菇 弹出 %.0f 像素" % p.global_position.distance_to(home)] = p.global_position.distance_to(home) > HazardMushrooms.STEP * 2.5 and p.laugh.value > 0.0
	d.clear_field()
	_fight()
	# 传送门：粉色公主进紫门 → 粉门出来；怪进粉门 → 紫门出来；法术冰封紫门后不传送
	p.global_position = home + Vector2(0, 60)
	var portal := d.spawn_hazard("portal_pair", home) as HazardPortalPair
	await _until(func(): return portal.warned, 3.0)
	p.global_position = portal.global_position
	await _wait(0.2)
	var sent := p.global_position.distance_to(portal.exit) < 40.0
	var mob := d.spawn("rat", "", portal.exit)
	mob.mind = null
	await _wait(0.2)
	var mob_sent := mob.global_position.distance_to(portal.global_position) < 30.0
	SiegeHazard.notify_spell(get_tree(), portal.global_position, 20.0)
	await _wait(2.8)
	p.global_position = portal.global_position
	await _wait(0.2)
	var frozen_ok := p.global_position.distance_to(portal.global_position) < 10.0
	ok["传送门 人（%s）怪（%s）冰封（%s）" % [sent, mob_sent, frozen_ok]] = sent and mob_sent and frozen_ok
	d.clear_field()
	_fight()
	var bad := ok.keys().filter(func(k): return not ok[k])
	check("四个大型强制位移陷阱都生效（没生效：%s）" % [bad], bad.is_empty())
	# 四个新配合技
	var team_ok := {}
	for id in ["crab_rat", "crab_tentacle", "imp_slime", "bear_tentacle"]:
		await _clear()
		_fight()
		d.blue.set_controller(CharacterController.new())
		d.wave = 8
		d.teamwork._cd.clear()
		d.teamwork.history.clear()
		p.global_position = home
		var made := d.teamwork.spawn_formation(id, home + Vector2(30, 0))
		for m in made:
			m.mind = null
			m.set_physics_process(false)
			m.global_position = home + Vector2(randf_range(10, 40), randf_range(-8, 8))
		await get_tree().process_frame
		if p.has_meta("siege_team_said"):
			p.remove_meta("siege_team_said")
		d.teamwork.scan()
		await _wait(1.3)
		# 发动后横幅飘过，她走字幕说了一句（SiegeTeamEffects.say_later）
		var fired: bool = d.teamwork.history.has(id) and p.has_meta("siege_team_said")
		var effect := false
		match id:
			"crab_rat": effect = p.status.is_rooted() and p.has_meta("shoeless_until")
			"crab_tentacle": effect = p.status.is_rooted()
			"imp_slime": effect = made.any(func(m): return is_instance_valid(m) and m.global_position.distance_to(p.global_position) < 30.0)
			"bear_tentacle": effect = p.status.is_grabbed()
		team_ok[id] = fired and effect and made.size() == 3
		if p.status:
			p.status.release(true)
			p.status.clear_root()
		d.wave = 1
	var tbad := team_ok.keys().filter(func(k): return not team_ok[k])
	check("四个新配合技凑齐就发动、效果生效、公主说了字幕（没生效：%s）" % [tbad], tbad.is_empty())
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 第十一轮：难度、陷阱配合、双向传送门、攻城车撞塔 / 撞人、投石车、胜利清空支援
func _run_round11() -> void:
	print("-- 第十一轮：难度倍率 / 陷阱配合 / 攻城车 / 投石车 / 胜利清空支援")
	await _clear()
	_fight()
	d.blue.set_controller(CharacterController.new())
	var p := d.pink
	var home := Vector2(d.gate_pos.x + 160.0, d.wall_foot_y() + 220.0)
	var ok := {}
	# 难度：小怪血量 ×hp、挂 siege_hard（挠痒力度）
	var slime := d.spawn("slime", "", home + Vector2(300, 200))
	ok["难度倍率 hp ×%.1f、挠痒 ×%.1f" % [SiegeDirector.difficulty("hp"), slime.stat_mul("tickle_power")]] = SiegeDirector.difficulty("hp") >= 1.4 \
		and slime.has_buff("siege_hard") and slime.stat_mul("tickle_power") >= 1.39
	slime.queue_free()
	# 传送门：双向 + 怪潮
	p.global_position = home + Vector2(0, 80)
	var portal := d.spawn_hazard("portal_pair", home) as HazardPortalPair
	await _until(func(): return portal.warned, 3.0)
	p.global_position = portal.exit
	await _wait(0.2)
	var back := p.global_position.distance_to(portal.global_position) < 40.0
	var mob := d.spawn("rat", "", portal.global_position)
	mob.mind = null
	await _wait(0.2)
	var mob_out := mob.global_position.distance_to(portal.exit) < 30.0
	await _wait(HazardPortalPair.TIDE_GAP + 0.3)
	ok["传送门双向：公主从出口回到入口（%s）、怪从入口到出口（%s）、门里涌怪 %d" % [back, mob_out, portal.tide]] = back and mob_out and portal.tide > 0
	d.clear_field()
	_fight()
	# 弹弹蘑菇：9 颗，怪一路弹到尽头弹上城墙
	p.global_position = home + Vector2(-300, 120)
	var mush := d.spawn_hazard("mushrooms", home) as HazardMushrooms
	await _until(func(): return mush.warned, 3.0)
	var hop := d.spawn("slime", "", mush.global_position + mush.caps[0])
	hop.mind = null
	await _wait(HazardMushrooms.HOP_TIME * HazardMushrooms.COUNT + 1.5)
	ok["蘑菇 %d 颗，怪弹完整条路 %d 只（上墙：%s）" % [mush.caps.size(), mush.launched_to_wall, hop.get_meta("siege_on_wall", false) if is_instance_valid(hop) else "-"]] = mush.caps.size() == 9 and mush.launched_to_wall >= 1
	d.clear_field()
	_fight()
	# 龙卷风：卷怪，甩的时候一半上墙
	p.global_position = home + Vector2(-400, 200)
	d.blue.global_position = Vector2(home.x, d.wall_top_y() + 4)
	var tor := d.spawn_hazard("tornado", home) as HazardTornado
	for i in 6:
		var m := d.spawn("slime", "", home + Vector2(randf_range(-10, 10), randf_range(-8, 8)))
		m.mind = null
	await _until(func(): return tor.warned, 3.0)
	await _until(func(): return tor.flung_to_wall > 0, 8.0)
	ok["龙卷风卷怪甩上墙 %d 只" % tor.flung_to_wall] = tor.flung_to_wall > 0
	d.clear_field()
	_fight()
	# 抓娃娃机：没抓到公主就抓怪扔过去
	p.global_position = home + Vector2(0, 260)
	var claw := d.spawn_hazard("claw", home) as HazardClaw
	# 两位公主都在冷却里：爪子不追人，落下来只抓得到怪
	claw._cool["pink"] = 99.0
	claw._cool["blue"] = 99.0
	claw.target = null
	claw.global_position = home
	for i in 4:
		var m2 := d.spawn("rat", "", home + Vector2(randf_range(-8, 8), randf_range(-6, 6)))
		m2.mind = null
		# 待在爪子底下（不追人、不闲逛）
		m2.stats = m2.stats.duplicate()
		m2.stats.chase_speed = 0.0
		m2.stats.wander_speed = 0.0
	var wclaw: WeakRef = weakref(claw)
	var dropped := 0
	var t_claw := 0.0
	while t_claw < 8.0 and wclaw.get_ref() != null:
		dropped = (wclaw.get_ref() as HazardClaw).dropped_mobs
		if dropped > 0:
			break
		await _wait(0.1)
		t_claw += 0.1
	ok["抓娃娃机投怪 %d 只" % dropped] = dropped > 0
	d.clear_field()
	_fight()
	# 流沙伏兵 + 黏网伏兵（粉色公主 → 挠脚鼠）
	p.global_position = home + Vector2(0, 300)
	var qs := d.spawn_hazard("quicksand", home) as HazardQuicksand
	await _until(func(): return qs.ambushed > 0, 6.0)
	ok["流沙钻出伏兵 %d 只" % qs.ambushed] = qs.ambushed > 0
	d.clear_field()
	_fight()
	p.global_position = home
	var net := d.spawn_hazard("sticky_net", home) as HazardStickyNet
	await _until(func(): return net.caught != null, 3.0)
	ok["黏网伏兵 %d 只挠脚鼠" % net.ambushed.size()] = net.ambushed.size() > 0 and net.ambushed.all(func(m3): return MonsterTeamwork.key_of(m3) == "rat")
	net.free_caught()
	d.clear_field()
	_fight()
	# 攻城车：撞碎路上的冰塔继续冲；撞到粉色公主闷笑 +50%
	var lane_x := home.x + 260.0
	var tw := _make_tower("icicle", Vector2(lane_x, d.wall_foot_y() + 140.0))
	var pad := tw.pad
	var cart := d.spawn("cart", "", Vector2(lane_x, d.wall_foot_y() + 300.0)) as SiegeCart
	var wcart: WeakRef = weakref(cart)
	await _until(func(): return wcart.get_ref() == null or (wcart.get_ref() as SiegeCart).smashed > 0, 8.0)
	var smashed := cart.smashed if is_instance_valid(cart) else 0
	await _wait(0.2)
	ok["攻城车撞碎冰塔（%d）、基座还在、车继续冲" % smashed] = smashed == 1 and not is_instance_valid(tw) and is_instance_valid(pad) \
		and (not is_instance_valid(cart) or cart._phase in ["charge", "done"])
	if is_instance_valid(pad):
		pad.queue_free()
	d.clear_field()
	_fight()
	# 黏网 / 爪子松开后的挣脱无敌要等状态机走完再清
	await _wait(0.3)
	p.status.release(true)
	p.end_forced_move()
	p._set_state(PlayableCharacter.State.IDLE)
	p.laugh.set_value(0.0)
	p.set_invulnerable(0.0)
	p._full_invuln = 0.0
	var cart2 := d.spawn("cart", "", Vector2(lane_x, d.wall_foot_y() + 320.0)) as SiegeCart
	p.global_position = Vector2(lane_x, d.wall_foot_y() + 200.0)
	var w2: WeakRef = weakref(cart2)
	await _until(func(): return w2.get_ref() == null or (w2.get_ref() as SiegeCart)._hit_pink, 8.0)
	await _wait(0.1)
	ok["攻城车撞到粉色公主：闷笑 %.0f / %.0f" % [p.laugh.value, p.laugh.max_value]] = p.laugh.value >= p.laugh.max_value * 0.5
	d.clear_field()
	_fight()
	p.laugh.set_value(0.0)
	# 拆塔投石车：砸冰塔；粉色公主站进影子替塔挡（先清掉前面几段留下的冰塔，免得它挑别的塔）
	for old_tower in get_tree().get_nodes_in_group("siege_tower"):
		old_tower.queue_free()
	await get_tree().process_frame
	var cat := EnemyTower.new()
	cat.kind = "catapult"
	d.entities().add_child(cat)
	cat.global_position = Vector2(home.x - 200.0, home.y + 200.0)
	var tw2 := _make_tower("frost", Vector2(home.x - 200.0, home.y - 60.0))
	var hp0 := tw2.health.hp
	p.global_position = home + Vector2(300, 300)
	cat._catapult()
	await _wait(EnemyTower.CATAPULT_WARN + 0.3)
	var hit_dmg := hp0 - (tw2.health.hp if is_instance_valid(tw2) else 0)
	if is_instance_valid(tw2):
		tw2.health.fill()
	var hp1 := tw2.health.hp if is_instance_valid(tw2) else 0
	p.global_position = (tw2.global_position if is_instance_valid(tw2) else home) + Vector2(0, 16)
	p.end_forced_move()
	p.velocity = Vector2.ZERO
	cat._catapult()
	await _wait(EnemyTower.CATAPULT_WARN + 0.3)
	ok["投石车砸冰塔掉 %d、公主挡下 %d 次" % [hit_dmg, cat.catapult_blocked]] = hit_dmg > 0 and cat.catapult_blocked == 1 and is_instance_valid(tw2) and tw2.health.hp == hp1
	if is_instance_valid(tw2):
		tw2.pad.queue_free()
	cat.queue_free()
	d.clear_field()
	_fight()
	# 胜利清空镇民支援
	var saved: Array = GameState.vars.get("siege_town_buffs", []).duplicate()
	d.town.grant(str(TownBuffs.for_wave(1).get("id", "")), false)
	var had := d.town.owned.size() > 0 and p.buffs.keys().any(func(k): return str(k).begins_with("town_"))
	d.town.clear_all()
	ok["胜利后镇民支援清空（之前有：%s）" % had] = had and d.town.owned.is_empty() and not GameState.vars.has("siege_town_buffs") \
		and not p.buffs.keys().any(func(k): return str(k).begins_with("town_"))
	GameState.vars["siege_town_buffs"] = saved
	d.town.restore()
	var bad := ok.keys().filter(func(k): return not ok[k])
	check("第十一轮都生效（没生效：%s）" % [bad], bad.is_empty())
	d.blue.set_controller(d._make_ai(d.blue))


# ------------------------------------------------------------------ 12 装备挠痒
func _run_equip() -> void:
	print("-- 装备挠痒")
	await _clear()
	var p := d.pink
	Equipment.force("pink", "equip_t_feather_socks")
	p.laugh.set_value(0.0)
	var fx := EquipFx.of(p)
	fx.flare("equip_t_feather_socks", "sole")
	await get_tree().process_frame
	var l1 := p.laugh.value
	check("负面装备发作：闷笑明显上涨（%.1f）" % l1, l1 >= 3.0)
	Equipment.clear_forced()
	GameState.inventory.add(ItemDB.get_item("equip_armpit_pad"), 1)
	Equipment.equip("pink", "equip_armpit_pad")
	Equipment.restore_charges()
	var s := Src.new()
	s.reaction_key = "slime"
	add_child(s)
	p.laugh.set_value(0.0)
	p.set_invulnerable(0.0)
	# 先不穿：同一下挠多少
	Equipment.unequip("pink", "armpit")
	var h0 := HitData.make_tickle(s, 10.0)
	h0.zone = "armpit"
	p.receive_hit(h0)
	var full := p.laugh.value
	p.laugh.set_value(0.0)
	p.set_invulnerable(0.0)
	Equipment.equip("pink", "equip_armpit_pad")
	Equipment.restore_charges()
	await get_tree().process_frame
	var h := HitData.make_tickle(s, 10.0)
	h.zone = "armpit"
	p.receive_hit(h)
	var blocked := p.laugh.value
	Equipment.unequip("pink", "armpit")
	s.queue_free()
	check("防护装备挡下：还是涨一点闷笑（%.1f，没挡是 %.1f，约 30%%）" % [blocked, full], blocked > 0.0 and blocked < full * 0.5)


# ------------------------------------------------------------------ 13 CG 素材
func _run_cg() -> void:
	print("-- CG 素材")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/siege/monsters.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/siege_cgs.json"))
	var bad := []
	for k in data.get("actors", {}):
		var spr: Dictionary = data["actors"][k].get("sprite", {})
		if spr.has("region"):
			bad.append(k)
		elif spr.has("key"):
			var r := CGActor.atlas_region(str(spr["atlas"]), str(spr["key"]))
			var want: Array = meta.get(str(spr["key"]), [])
			if want.is_empty() or r != Rect2(want[0], want[1], want[2], want[3]):
				bad.append(k)
	check("攻防战 CG 的演员按图集键取图、和图集一致（不对的：%s）" % [bad], bad.is_empty() and data.get("actors", {}).size() >= 13)
	# 四幕：笑倒 CG / 组合演出（粉 / 蓝）都有第 1~4 幕和爆发幕，句数够；失败小剧场两个人各爆发一次
	var short := []
	for path in ["res://data/siege_cgs.json", "res://data/characters/blue/siege_cgs.json", "res://data/siege_scenes.json", "res://data/characters/blue/siege_scenes.json"]:
		var d2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var group: Dictionary = d2.get("cgs", d2.get("scenes", {}))
		for id in group:
			var steps: Array = group[id]["steps"]
			var acts := {}
			for st in steps:
				var a: Variant = st.get("act", "")
				acts[str(int(a)) if a is float else str(a)] = true
			var lines := steps.filter(func(st): return st.has("text")).size()
			if not (acts.has("1") and acts.has("2") and acts.has("3") and acts.has("4") and acts.has("burst")) or lines < 28:
				short.append("%s:%s(%d)" % [path.get_file(), id, lines])
	for n in range(1, 13):
		for suffix in ["", "_pants"]:
			var th: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/siege/siege_fail_%d%s.json" % [n, suffix]))
			var bursts: int = th["steps"].filter(func(st): return str(st.get("act", "")) == "burst").size()
			if bursts < 2 or th["steps"].filter(func(st): return st.has("text")).size() < 24:
				short.append("siege_fail_%d%s" % [n, suffix])
	check("笑倒 CG / 组合演出 / 失败小剧场都是四幕 + 魔力爆发、句数够（不够的：%s）" % [short], short.is_empty())
	var mute := []
	var teams: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/teamwork.json")) as Dictionary)["teams"]
	for who in ["pink", "blue"]:
		Characters.scope(who)
		for t in teams:
			if ReactionDB.lines("team_" + str(t["id"]), "trigger").is_empty():
				mute.append("%s/%s" % [who, t["id"]])
		Characters.unscope()
	check("每个配合技发动时两位公主都有字幕台词（缺：%s）" % [mute], mute.is_empty())


# ------------------------------------------------------------------ 14 性能
func _run_perf() -> void:
	print("-- 性能：1000 只怪")
	await _clear()
	_fight()
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy", "bat", "spider", "crab", "ghost", "hedgehog"]
	for i in 1000:
		d.spawn(keys[i % keys.size()], ["bottom", "left", "right", "hole"][i % 4])
	await _wait(1.0)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 4_000_000:
		await get_tree().physics_frame
		frames += 1
	var avg := 4000.0 / frames
	check("1000 只怪同时在场：平均每物理帧 %.1f ms（目标 ≤ 33 ms）" % avg, avg <= 33.0 and d.monsters.size() >= 900)
	d.clear_field()
