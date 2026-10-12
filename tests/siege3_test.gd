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
	for sec in ["hints", "waves", "town", "boss", "soldiers", "towers", "spells", "etowers", "field", "cart", "wall", "equip", "cg", "perf"]:
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
	GameState.rule("规则说明：这条要停 10 秒")
	await _wait(8.0)
	var rule_still := toast != null and toast.modulate.a > 0.5
	await _wait(2.6)
	check("普通通知按原来的时长消失（%s），规则说明停 10 秒（8 秒时还在 %s，10.6 秒后没了 %s）" % [normal_gone, rule_still, toast.modulate.a < 0.1 if toast else false],
		normal_gone and rule_still and toast.modulate.a < 0.1)
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
	await get_tree().create_timer(0.6, true, false, true).timeout
	if show_node and is_instance_valid(show_node):
		show_node.call("_finish")
	await get_tree().process_frame
	await get_tree().process_frame
	TownBuffShow.enabled = false
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
	check("冰塔种类 9 种（%s）" % [IceTower.kinds()], IceTower.kinds().size() == 9 and IceTower.kinds().has("campfire"))
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
