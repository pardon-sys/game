extends Node
## 小镇攻防战（内容）：12 种攻城怪的关键行为、大范围陷阱、三种牺牲互救、临时痒痒装备、三来源组合、笑倒 CG / 小演出数据、战场情报。
## 用法：Godot --headless --path . res://tests/siege5_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var d: SiegeDirector


class HoldE extends CharacterController:
	func is_action_pressed(action: StringName) -> bool:
		return action == &"interact"


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false   # 按键说明情报不自动弹（siege3_test 单独测）
	TownBuffShow.enabled = false   # 镇民支援的过场跳过（buff 照样生效）
	Monster.random_specials = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked", "seen_fatigue_burst",
			"intro_done_siege_intro", "siege_intro_seen"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _until(func(): return SiegeDirector.current != null and SiegeDirector.current.state == "prep", 20.0)
	d = SiegeDirector.current
	d.quiet_spawn = true    # 不放出生动画（测试里生成的怪要马上能动）
	d.bench_soldiers(true)   # 士兵会先把测试里放的怪打掉；这个测试只看怪 / 陷阱本身
	await _wait(0.5)
	_finish()
	await _run_data()
	await _run_monsters()
	await _run_hazards()
	await _run_rescues()
	await _run_temp_equipment()
	await _run_combos()
	await _run_intel()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 工具
func _fight() -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.state = "fight"
	_hold_new_spells()


## 第三轮的新法术（暴风雪 / 冰川突刺 / 冰镜分身）在这个测试里一直冷却着：
## 这里测的是单个怪 / 陷阱本身，蓝色公主的 AI 放暴风雪、冰镜会把怪减速 / 引走（siege3_test 测新法术）。
func _hold_new_spells() -> void:
	if d and d.blue:
		var cd: Dictionary = d.blue.get_meta("siege_cd", {})
		for id in ["blizzard", "spike", "mirror"]:
			cd[id] = Time.get_ticks_msec() / 1000.0 + 99999.0
		d.blue.set_meta("siege_cd", cd)


func _reset() -> void:
	# 笑倒 CG 之类还在放的话先跳过；倒下的人扶起来
	var g := 0
	while (CG.is_busy() or Dialogue.is_active()) and g < 400:
		if CG.is_busy():
			CG._can_skip = true
			CG.skip()
		_finish()
		await get_tree().process_frame
		g += 1
	for c: PlayableCharacter in [d.pink, d.blue]:
		var dn := c.get_node_or_null("Downed")
		if dn:
			dn.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		if c.sprite:
			c.sprite.modulate.a = 1.0
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	d.monsters.clear()
	for n in get_tree().get_nodes_in_group("siege_temp"):
		if n.has_method("_end"):
			n.call("_end")
		n.queue_free()
	for c: PlayableCharacter in [d.pink, d.blue]:
		if c.status:
			c.status.release(true)
			c.status.clear_root()
		for k in ["siege_dragged", "siege_netted", "siege_bubbled", "siege_chained", "siege_beaming", "siege_falling"]:
			c.set_meta(k, false)
		c.visible = true
		c.set_physics_process(true)
		if c.laugh:
			c.laugh.set_value(0.0)
		c.remove_buff("lifted")
		c.remove_buff("frost_guard")
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
		c.set_meta("siege_cd", {})
		_hold_new_spells()
	Equipment.clear_forced()
	d.pink.global_position = d.gate_pos + Vector2(0, 40)
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.wall_hp = d.wall_max
	for w in d.walls:
		w.taken = 0.0
		w.shield_left = 0.0
	await _wait(0.2)


func _spawn(key: String, at: Vector2) -> Monster:
	return d.spawn(key, "", at)


func _tickle(c: PlayableCharacter, key: String, amount := 4.0, zone := "") -> void:
	var s := Src.new()
	s.reaction_key = key
	add_child(s)
	c.set_invulnerable(0.0)
	c._full_invuln = 0.0
	var h := HitData.make_tickle(s, amount)
	h.zone = zone
	c.receive_hit(h)
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


# ------------------------------------------------------------------ 数据
func _run_data() -> void:
	print("-- 数据")
	var ks := ["cart", "hook", "vine", "gecko", "shield_crab", "bat_swarm", "carrier", "warm_slime", "thigh_spider", "hug_bear", "suck_jelly", "twin_ghost"]
	var missing := ks.filter(func(k): return d.monster_scene(k) == "")
	check("12 种攻城怪都在怪物表里（缺 %s）" % [missing], missing.is_empty())
	var cg_keys := ["cart", "hook", "bind_vine", "gecko", "shield_crab", "bat_swarm", "carrier", "warm_slime", "thigh_spider", "hug_bear", "suck_jelly", "twin_ghost"]
	var no_cg := []
	for who in ["pink", "blue"]:
		Characters.scope(who)
		for k in cg_keys:
			if not CG.cgs().has(CG.death_cg_for(k)) or CG.death_cg_for(k) != "death_siege_" + k:
				no_cg.append("%s:%s" % [who, k])
		Characters.unscope()
	check("每种攻城怪都有专属笑倒 CG（粉 / 蓝两版，缺 %s）" % [no_cg], no_cg.is_empty())
	Characters.scope("pink")
	var pink_scenes := ["sg_foot_assault", "sg_toe_bloom", "sg_bear_bra", "sg_carried_mark", "sg_bell_tide", "sg_strap_tornado"].filter(func(k): return CG.scenes.has(k))
	Characters.unscope()
	Characters.scope("blue")
	var blue_scenes := ["sg_pants_frenzy", "sg_broom_wall", "sg_bell_tide", "sg_strap_tornado"].filter(func(k): return CG.scenes.has(k))
	Characters.unscope()
	check("三来源组合的小演出：粉色公主 %d / 6、蓝色公主 %d / 4" % [pink_scenes.size(), blue_scenes.size()], pink_scenes.size() == 6 and blue_scenes.size() == 4)
	var waves: Array = d.data.get("waves", [])
	var total := 0
	for w in waves:
		for g in w.get("groups", []):
			total += int(g.get("count", 0))
	var last := 0
	for g in waves[-1].get("groups", []):
		last += int(g.get("count", 0))
	check("12 波共 %d 只怪，最后一波 %d 只（> 100），后面几波有大范围陷阱和敌塔" % [total, last],
		waves.size() == 12 and last > 100 and not waves[-1].get("hazards", []).is_empty() and not waves[-1].get("enemy_towers", []).is_empty())


# ------------------------------------------------------------------ 攻城怪
func _run_monsters() -> void:
	print("-- 攻城怪")
	await _reset()
	# 蓝色公主的 AI 先停下（不然她会把要测的怪打死）
	d.blue.set_controller(ScriptedController.new())
	_fight()
	# 攻城车
	var hp0 := d.wall_hp
	var cart := _spawn("cart", Vector2(d.blue.global_position.x, d.wall_foot_y() + 160.0))
	var lane_seen := false
	var t := 0.0
	while t < 8.0 and d.is_on_wall(d.blue):
		lane_seen = lane_seen or not get_tree().get_nodes_in_group("siege_lane").is_empty()
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.6)
	check("攻城痒痒车：先亮预警线（%s），撞墙大扣血（%d → %d），蓝色公主被震下城墙（%s）" % [lane_seen, int(hp0), int(d.wall_hp), not d.is_on_wall(d.blue)],
		lane_seen and hp0 - d.wall_hp >= 200.0 and not d.is_on_wall(d.blue))
	await _reset()
	_fight()
	# 诱饵冰雕吸引攻城车
	var pad := BuildPad.new()
	d.entities().add_child(pad)
	pad.global_position = Vector2(d.gate_pos.x - 300.0, d.wall_foot_y() + 60.0)
	pad._build("decoy", 1)
	await _wait(0.2)
	var decoy := pad.tower
	var dh := decoy.health.hp
	hp0 = d.wall_hp
	_spawn("cart", Vector2(decoy.global_position.x + 30.0, d.wall_foot_y() + 170.0))
	await _wait(6.0)
	check("攻城车会被诱饵冰雕吸过去（冰雕 %d → %d，城墙 %d → %d）" % [dh, decoy.health.hp if is_instance_valid(decoy) else 0, int(hp0), int(d.wall_hp)],
		(not is_instance_valid(decoy) or decoy.health.hp < dh) and d.wall_hp > hp0 - 100.0)
	pad.tower = null
	await _reset()
	_fight()
	# 钩索怪：滑上墙 / 绳子被射断
	var hook: HookClimber = _spawn("hook", Vector2(d.gate_pos.x + 80.0, d.wall_foot_y() + 130.0))
	t = await _until(func(): return hook.on_wall, 10.0)
	check("钩索怪：甩钩索、顺着绳子滑上墙顶（%.1f 秒）" % t, hook.on_wall)
	var hook2: HookClimber = _spawn("hook", Vector2(d.gate_pos.x - 120.0, d.wall_foot_y() + 130.0))
	await _until(func(): return is_instance_valid(hook2.rope) and hook2.climbing, 8.0)
	var was_climbing := hook2.climbing
	if is_instance_valid(hook2.rope):
		hook2.rope.cut(d.blue)
	await _wait(1.0)
	check("绳子被射断 → 钩索怪摔下来（滑的时候 %s，现在在墙上 %s）" % [was_climbing, hook2.on_wall if is_instance_valid(hook2) else false],
		was_climbing and (not is_instance_valid(hook2) or not hook2.on_wall))
	await _reset()
	_fight()
	# 捆绑藤怪：缠住 + 强制穿装备
	var vine := _spawn("vine", d.pink.global_position + Vector2(6, 0))
	t = await _until(func(): return not Equipment.forced_items("pink").is_empty() and d.pink.status.is_grabbed(), 8.0)
	check("捆绑藤怪：缠住粉色公主（%s），强制穿上临时装备（%s）" % [d.pink.status.is_grabbed(), Equipment.forced_items("pink")],
		d.pink.status.is_grabbed() and not Equipment.forced_items("pink").is_empty())
	await _reset()
	_fight()
	# 爬墙壁虎：爬上去 / 加固的墙爬不上去
	var g1: WallGecko = _spawn("gecko", Vector2(d.walls[1].global_position.x, d.wall_foot_y() + 30.0))
	t = await _until(func(): return g1.on_wall, 6.0)
	d.walls[5].reinforce(999, 30.0)
	var g2: WallGecko = _spawn("gecko", Vector2(d.walls[5].global_position.x, d.wall_foot_y() + 30.0))
	g2.set_meta("x0", g2.global_position.x)
	await _wait(3.0)
	var w5 := d.walls[5]
	var g2_stuck := not g2.on_wall or g2.global_position.x < w5.left_x() or g2.global_position.x > w5.right_x()
	check("爬墙壁虎：贴墙爬上城墙（%.1f 秒），冰墙加固的那段爬不上去（%s）" % [t, g2_stuck], g1.on_wall and g2_stuck)
	await _reset()
	_fight()
	# 盾甲螃蟹：正面挡、背后吃
	var crab := _spawn("shield_crab", d.pink.global_position + Vector2(0, 80))
	crab.mind = null
	var above := Src.new()
	add_child(above)
	above.global_position = crab.global_position + Vector2(0, -60)
	var front := crab.receive_hit(HitData.make_attack(above, 1, 0.0))
	crab.set_invulnerable(0.0)
	crab._attack_invuln = 0.0
	d.pink.global_position = crab.global_position + Vector2(0, 20)
	var back := crab.receive_hit(HitData.make_attack(d.pink, 1, 0.0))
	above.queue_free()
	check("盾甲螃蟹：正面（上方）来的攻击挡住（%s），背后（粉色公主）打得动（%s）" % [not front, back], not front and back)
	# 羽毛蝠群：粉色公主够不着，蓝色公主能打；飞上城墙
	var bats := _spawn("bat_swarm", d.pink.global_position + Vector2(0, 30))
	var pink_hit := bats.receive_hit(HitData.make_attack(d.pink, 1, 0.0))
	var blue_hit := bats.receive_hit(HitData.make_attack(d.blue, 1, 0.0))
	t = await _until(func(): return not is_instance_valid(bats) or bats.global_position.y < d.wall_foot_y() - 10.0, 10.0)
	check("羽毛蝠群：粉色公主打不到（%s）、蓝色公主能打（%s），直接飞上城墙（%.1f 秒）" % [not pink_hit, blue_hit, t],
		not pink_hit and blue_hit and (not is_instance_valid(bats) or bats.global_position.y < d.wall_foot_y() - 10.0))
	await _reset()
	_fight()
	# 暖炉史莱姆：冻不住、冰打不动、融化冰塔
	var pad2 := BuildPad.new()
	d.entities().add_child(pad2)
	pad2.global_position = Vector2(d.gate_pos.x + 300.0, d.wall_foot_y() + 60.0)
	pad2._build("icicle", 1)
	await _wait(0.2)
	var tower := pad2.tower
	var warm: WarmSlime = _spawn("warm_slime", tower.global_position + Vector2(0, 40))
	warm.stun(3.0)
	var stunned := warm.is_stunned()
	var ice_hit := warm.receive_hit(HitData.make_attack(tower, 1, 0.0))
	await _wait(3.0)
	check("暖炉史莱姆：冻不住（%s）、冰塔打不动（%s），贴着冰塔把它融化（%.0f / %.0f）" % [not stunned, not ice_hit,
			tower.melt_left if is_instance_valid(tower) else 0.0, IceTower.MELT_HP],
		not stunned and not ice_hit and (not is_instance_valid(tower) or tower.melt_left < IceTower.MELT_HP))
	pad2.tower = null
	await _reset()
	_fight()
	# 腿根爬爬蛛：裤子共振
	var spider := _spawn("thigh_spider", d.blue.global_position + Vector2(6, 0))
	(spider as SiegeMonster).on_wall = true
	spider.collision_mask = 0
	var efx := EquipFx.of(d.blue)
	efx.last = []
	t = await _until(func(): return efx.last.size() == 3 and efx.last[0] == Equipment.PANTS_ID, 8.0)
	check("腿根爬爬蛛：在墙上挠蓝色公主，千手痒痒裤跟着发作（%s）" % [efx.last], efx.last.size() == 3 and efx.last[0] == Equipment.PANTS_ID)
	await _reset()
	_fight()
	# 拥抱小熊：抱住粉色公主，蓝色公主的冰锥打中就松手
	var bear := _spawn("hug_bear", d.pink.global_position + Vector2(5, 0))
	await _until(func(): return d.pink.status.is_grabbed(), 6.0)
	var grabbed := d.pink.status.is_grabbed()
	bear.receive_hit(HitData.make_attack(d.blue, 1, 0.0))
	check("拥抱小熊：抱住粉色公主（%s），蓝色公主打中就松手（%s）" % [grabbed, not d.pink.status.is_grabbed()], grabbed and not d.pink.status.is_grabbed())
	await _reset()
	_fight()
	# 魔力吸吸水母：吸住蓝色公主，施法失败并挠腋下
	var jelly := _spawn("suck_jelly", d.blue.global_position + Vector2(0, 30))
	await _until(func(): return d.blue.status.is_grabbed(), 8.0)
	var lv0 := d.blue.laugh.value
	d.blue.set_meta("siege_cd", {})
	_hold_new_spells()
	var cast := SiegeSpells.cast(d.blue, "ice_rain", d.blue.global_position + Vector2(0, 80))
	check("魔力吸吸水母：吸住蓝色公主（%s），施法放不出来（%s）并被挠（%.0f → %.0f）" % [d.blue.status.is_grabbed(), not cast, lv0, d.blue.laugh.value],
		d.blue.status.is_grabbed() and not cast and d.blue.laugh.value > lv0)
	await _reset()
	_fight()
	# 双子痒痒鬼
	var ga: TwinGhost = _spawn("twin_ghost", d.pink.global_position + Vector2(0, 60))
	await _until(func(): return ga.twin != null, 3.0)
	var gb := ga.twin
	var paired := gb != null
	ga.health.damage(999)
	await _wait(0.2)
	var a_down := not ga.is_alive() and is_instance_valid(ga)
	await _wait(3.2)
	var revived := is_instance_valid(ga) and ga.is_alive()
	ga.health.damage(999)
	await _wait(0.3)
	gb.health.damage(999)
	await _wait(0.4)
	check("双子痒痒鬼：成对出现（%s），只打倒一只 3 秒后复活（%s / %s），两只一起打倒才消失（%s）" % [paired, a_down, revived,
			not is_instance_valid(ga) and not is_instance_valid(gb)],
		paired and a_down and revived and not is_instance_valid(ga) and not is_instance_valid(gb))
	d.blue.set_controller(d._make_ai(d.blue))
	await _reset()


# ------------------------------------------------------------------ 大范围陷阱
func _run_hazards() -> void:
	print("-- 大范围陷阱")
	_fight()
	var p := d.pink
	# 龙卷风
	var tor := d.spawn_hazard("tornado", p.global_position + Vector2(10, 0))
	tor.set("_dir", Vector2.ZERO)
	var spun := false
	var t := 0.0
	while t < 5.0 and not spun:
		tor.global_position = p.global_position if not tor.get("_caught") else tor.global_position
		spun = tor.get("_caught") == p
		await get_tree().process_frame
		t += get_process_delta_time()
	var lv := p.laugh.value
	await _wait(2.6)
	check("痒痒龙卷风：卷起粉色公主转圈（%s），挠她（闷笑 %.0f），然后甩出来（%s）" % [spun, lv, tor.get("_caught") == null],
		spun and tor.get("_caught") == null and p.is_physics_processing())
	await _reset()
	_fight()
	# 泡泡潮
	var bub := d.spawn_hazard("bubbles", Vector2(d.map_size().x / 2.0, p.global_position.y))
	t = await _until(func(): return p.get_meta("siege_bubbled", false), 25.0)
	var caught: bool = p.get_meta("siege_bubbled", false)
	await _until(func(): return not p.get_meta("siege_bubbled", false), 6.0)
	check("痒痒泡泡潮：一排泡泡扫过来把粉色公主包进去飘着（%s，%.1f 秒），过一会儿泡泡破掉（%s）" % [caught, t, not p.get_meta("siege_bubbled", false)],
		caught and not p.get_meta("siege_bubbled", false))
	await _reset()
	_fight()
	# 痒感连线
	var rune: HazardLinkRune = d.spawn_hazard("link_rune", p.global_position + Vector2(30, 0))
	await _wait(1.4)
	p.global_position = rune.global_position
	await _until(func(): return rune.linked, 3.0)
	var b0 := d.blue.laugh.value
	_tickle(p, "hazard_test", 10.0, "waist")
	var shared := d.blue.laugh.value > b0
	rune.stone.health.damage(999)
	await _wait(0.2)
	b0 = d.blue.laugh.value
	_tickle(p, "hazard_test", 10.0, "waist")
	check("痒感连线符文：踩到后连上（%s），粉色公主被挠蓝色公主也痒（%s），打碎符文石就断开（%s）" % [rune.linked if is_instance_valid(rune) else false,
			shared, d.blue.laugh.value == b0],
		shared and is_equal_approx(d.blue.laugh.value, b0))
	await _reset()
	_fight()
	# 城墙羽毛扫帚：站在被扫的那一行 → 被挠下去；AI 会躲到另一行
	var broom: HazardBroom = d.spawn_hazard("broom")
	d.blue.global_position.y = broom.lane_y
	var dodge_y := broom.safe_y()
	await _until(func(): return not broom.threatens(d.blue.global_position.y), 1.4)
	var dodged := not broom.threatens(d.blue.global_position.y)
	await _wait(2.6)
	check("城墙羽毛扫帚：亮出要扫的那一行，蓝色公主的 AI 换到另一行躲开（%s，还在墙上 %s）" % [dodged, d.is_on_wall(d.blue)], dodged and d.is_on_wall(d.blue))
	await _reset()
	_fight()
	d.blue.set_controller(ScriptedController.new())
	var broom2: HazardBroom = d.spawn_hazard("broom")
	d.blue.global_position.y = broom2.lane_y
	await _wait(4.0)
	d.blue.set_controller(d._make_ai(d.blue))
	check("没躲开的话：被扫帚挠下城墙（%s）" % (not d.is_on_wall(d.blue)), not d.is_on_wall(d.blue))
	await _reset()
	_fight()
	# 迷雾
	var fog: HazardFog = d.spawn_hazard("fog", p.global_position)
	await _wait(1.4)
	d.blue.set_meta("siege_cd", {})
	_hold_new_spells()
	var snow := SiegeSpells.cast(d.blue, "snow", p.global_position)
	check("痒痒迷雾：粉色公主在雾里（%s），蓝色公主的清凉雪花放不进去（%s）" % [d.in_fog(p.global_position), not snow], d.in_fog(p.global_position) and not snow)
	await _reset()


# ------------------------------------------------------------------ 牺牲互救
func _run_rescues() -> void:
	print("-- 牺牲互救")
	_fight()
	var p := d.pink
	var b := d.blue
	# 城墙爬藤：缠住墙上的蓝色公主，粉色公主砍藤根时被挠脚心
	# 蓝色公主的 AI 没威胁时会在墙顶巡逻走开：这一段先让她站着别动
	b.set_controller(CharacterController.new())
	var vine: HazardWallVine = d.spawn_hazard("wall_vine", Vector2(b.global_position.x, d.wall_foot_y()))
	await _until(func(): return vine.bound == b, 6.0)
	var bound := vine.bound == b
	b.set_controller(d._make_ai(b))
	b.set_meta("siege_cd", {})
	_hold_new_spells()
	var cast := SiegeSpells.cast(b, "ice_rain", b.global_position + Vector2(0, 80))
	p.global_position = vine.global_position + Vector2(0, 8)
	var lv := p.laugh.value
	await _wait(1.2)
	var paid := p.laugh.value > lv
	for i in 8:
		vine.root.set_invulnerable(0.0)
		vine.root._attack_invuln = 0.0
		if is_instance_valid(vine.root):
			vine.root.receive_hit(HitData.make_attack(p, 1, 0.0))
		await get_tree().process_frame
	await _wait(0.3)
	check("城墙爬藤：缠住城墙上的蓝色公主（%s），她放不了法术（%s）；粉色公主砍藤根时被挠脚心（%s），砍断后松开（%s）" % [bound, not cast, paid,
			not b.status.is_grabbed()],
		bound and not cast and paid and not b.status.is_grabbed())
	await _reset()
	_fight()
	# 黏网：蓝色公主（AI）走到正上方探出城垛割网，自己被挠
	p.global_position = Vector2(d.gate_pos.x + 160.0, d.wall_foot_y() + 70.0)
	var net: HazardStickyNet = d.spawn_hazard("sticky_net", p.global_position)
	await _until(func(): return net.caught == p, 3.0)
	var netted: bool = net.caught == p
	var bl := b.laugh.value
	var t := 0.0
	var intents := {}
	while t < 16.0 and p.get_meta("siege_netted", false):
		intents[(b.controller as SiegeMageController).intent if b.controller is SiegeMageController else "?"] = true
		await get_tree().process_frame
		t += get_process_delta_time()
	check("黏网：罩住粉色公主（%s）；蓝色公主走到正上方探出城垛割网（%.1f 秒后解开 %s），探出去时被挠（%.0f → %.0f）" % [netted, t,
			not p.get_meta("siege_netted", false), bl, b.laugh.value],
		netted and not p.get_meta("siege_netted", false) and t < 15.0 and b.laugh.value > bl)
	await _reset()
	_fight()
	# 冰链：藤蔓拉拽塔拖走粉色公主，蓝色公主拉住她、自己被挠
	var site: EnemySite = get_tree().get_nodes_in_group("siege_enemy_site")[2]
	var tw := site.build("vine_pull")
	await _wait(0.2)
	p.global_position = tw.global_position + Vector2(0, -120)
	tw._t = 0.0
	await _until(func(): return p.get_meta("siege_dragged", false), 3.0)
	var dragged: bool = p.get_meta("siege_dragged", false)
	b.global_position = Vector2(p.global_position.x, d.wall_top_y() + 4.0)
	# 清凉雪花的范围变大了（正下方放会把蓝色公主自己的闷笑也降掉），这里先让它冷却着
	b.set_meta("siege_cd", {"snow": Time.get_ticks_msec() / 1000.0 + 60.0})
	_hold_new_spells()
	bl = b.laugh.value
	t = await _until(func(): return not p.get_meta("siege_dragged", false), 12.0)
	check("冰链救援：粉色公主被藤蔓拖走（%s），蓝色公主放冰链拉回来（%.1f 秒 %s），拉的时候被挠（%.0f → %.0f）" % [dragged, t,
			not p.get_meta("siege_dragged", false), bl, b.laugh.value],
		dragged and not p.get_meta("siege_dragged", false) and b.laugh.value > bl)
	tw.health.damage(999)
	await _reset()


# ------------------------------------------------------------------ 临时痒痒装备
func _run_temp_equipment() -> void:
	print("-- 临时痒痒装备")
	await _reset()
	_fight()
	var p := d.pink
	var sp0 := p.stat_mul("speed")
	var how := Equipment.force("pink", "equip_t_feather_socks")
	check("羽毛袜强制穿上（%s）：移动 ×%.2f → ×%.2f，脱不下（%s）" % [how, sp0, p.stat_mul("speed"), not Equipment.unequip("pink", "sole")],
		how == "worn" and absf(p.stat_mul("speed") / sp0 - 0.8) < 0.01 and not Equipment.unequip("pink", "sole"))
	var efx := EquipFx.of(p)
	var lv := p.laugh.value
	var txt := efx.flare("equip_t_feather_socks", "sole")
	await get_tree().process_frame
	check("发作：挠脚心（%.0f → %.0f），立绘飘字（%s）" % [lv, p.laugh.value, txt], p.laugh.value > lv and txt != "")
	Equipment.tick_forced("pink", 21.0)
	check("20 秒后自己掉（%s）" % [Equipment.forced_items("pink")], Equipment.forced_items("pink").is_empty())
	Equipment.force("pink", "equip_t_fluff_bra")
	d.blue.global_position = p.global_position + Vector2(8, 0)
	var ctl := d.blue.controller
	d.blue.set_controller(HoldE.new())
	await _until(func(): return Equipment.forced_items("pink").is_empty(), 4.0)
	d.blue.set_controller(d._make_ai(d.blue))
	check("搭档靠近按住 E 帮忙解开（%s）" % [Equipment.forced_items("pink")], Equipment.forced_items("pink").is_empty())
	Equipment.force("pink", "equip_t_pinch_pad")
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.blue.set_meta("siege_cd", {})
	_hold_new_spells()
	p.global_position = d.gate_pos + Vector2(0, 40)
	var ok := false
	for i in 6:
		d.blue.set_meta("siege_cd", {})
		_hold_new_spells()
		if SiegeSpells.cast(d.blue, "snow", p.global_position):
			ok = true
			break
	check("清凉雪花也能解开（%s / %s）" % [ok, Equipment.forced_items("pink")], ok and Equipment.forced_items("pink").is_empty())
	var bfx := EquipFx.of(d.blue)
	var how2 := Equipment.force("blue", "equip_t_knead_tights")
	check("蓝色公主穿着千手痒痒裤：揉揉紧身裤被裤子吸收（%s），裤子更频繁 ×%.2f、更重 ×%.2f" % [how2, bfx.rate_mul, bfx.power_mul],
		how2 == "absorbed" and bfx.rate_mul > 1.5 and bfx.power_mul > 1.3 and Equipment.forced_items("blue").is_empty())
	bfx.remove_mod("absorb")
	Equipment.force("pink", "equip_t_feather_shackles")
	check("羽毛脚镣：不能冲刺（%s）" % Equipment.has_special("pink", "no_dash"), Equipment.has_special("pink", "no_dash"))
	Equipment.release("pink")
	Equipment.force("pink", "equip_t_mark_patch")
	var m: Monster = d.spawn("slime", "", (p.global_position + d.blue.global_position) / 2.0)
	var tgt := d.nearest_target(m, 999.0)
	check("痒痒印记臀贴：怪物优先找她（%s）" % [tgt == p], tgt == p)
	await _reset()


# ------------------------------------------------------------------ 三来源组合
func _run_combos() -> void:
	print("-- 三来源组合")
	_fight()
	var p := d.pink
	Equipment.force("pink", "equip_t_feather_socks")
	var got := []
	var on_t := func(id: String): got.append(id)
	p.combo.triggered.connect(on_t)
	p.combo.reset()
	_tickle(p, "enemy_net", 3.0, "sole")
	await _wait(0.1)
	_tickle(p, "rat", 3.0, "sole")
	await _wait(0.2)
	p.combo.triggered.disconnect(on_t)
	check("羽毛袜 + 吊网塔 + 挠脚鼠 → 「脚心总攻」（%s）" % [got], got.has("sg_foot_assault"))
	var b := d.blue
	got.clear()
	var on_b := func(id: String): got.append(id)
	b.combo.triggered.connect(on_b)
	b.combo.reset()
	_tickle(b, "enemy_totem", 3.0, "thigh")
	await _wait(0.1)
	_tickle(b, "thigh_spider", 3.0, "thigh")
	await _wait(0.2)
	b.combo.triggered.disconnect(on_b)
	check("千手痒痒裤 + 狂欢图腾 + 腿根爬爬蛛 → 「裤子大暴走」（%s）" % [got], got.has("sg_pants_frenzy"))
	got.clear()
	b.combo.triggered.connect(on_b)
	b.combo.reset()
	_tickle(b, "hazard_broom", 3.0, "thigh")
	await _wait(0.1)
	_tickle(b, "gecko", 3.0, "thigh")
	await _wait(0.4)
	b.combo.triggered.disconnect(on_b)
	check("千手痒痒裤 + 城墙羽毛扫帚 + 爬墙壁虎 → 「扫帚下的城墙」并被挠下城墙（%s，%s）" % [got, not d.is_on_wall(b)],
		got.has("sg_broom_wall") and not d.is_on_wall(b))
	await _reset()


# ------------------------------------------------------------------ 情报
func _run_intel() -> void:
	print("-- 战场情报")
	var intel := d.intel
	GameState.set_flag("siege_intel_hug_bear", false)
	intel.shown.erase("hug_bear")
	var fresh := intel.discover("hug_bear")
	var icon := intel.shown.has("hug_bear") and intel._buttons.size() > 0
	var ev := InputEventAction.new()
	ev.action = "intel"
	ev.pressed = true
	intel._unhandled_input(ev)
	var opened := intel.is_open() and get_tree().paused
	intel.close()
	check("新怪第一次出现：右侧弹出图标（%s / %s），按 H 打开简介卡并暂停（%s），关掉恢复（%s）" % [fresh, icon, opened, not get_tree().paused],
		fresh and icon and opened and not get_tree().paused)
	var e := SiegeIntel.entry("hug_bear")
	check("简介卡写了外观、机制、应对（%s）" % [e.get("name", "")], str(e.get("desc", "")) != "" and str(e.get("mech", "")) != "" and str(e.get("how", "")) != "")
