extends Node
## 小镇攻防战：
##   城门 → 攻防战地图；导演、8 段城墙、梯子、两位公主（粉色操控、蓝色在城墙上用城墙法师 AI）。
##   波次：准备倒计时 → 号角提前开打 → 出怪、怪物走到墙下打墙（城墙总血量下降）→ 蓝色公主放法术打怪 → 打倒得冰晶 → 清完下一波。
##   失败：城墙归零 → 清场 → （失败小剧场）→ 城墙修好、从这一波的准备阶段重来。胜利：第 10 波打完 → siege_won。
##   蓝色公主：被挠下城墙 → 时间到自己走到梯子爬回去；倒下不倒计时，粉色公主按住 E 救起。粉色公主倒下 → 城门复活、城墙扣血。
##   C 键切换；性能：150 只怪同时在场的帧时间。
## 用法：Godot --headless --path . res://tests/siege_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0


class HoldE extends CharacterController:
	func is_action_pressed(action: StringName) -> bool:
		return action == &"interact"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_enter()
	await _run_waves()
	await _run_controls()
	await _run_towers()
	await _run_enemy_towers()
	await _run_blue_fall()
	await _run_downs()
	await _run_fail_and_win()
	await _run_perf()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


func _dir() -> SiegeDirector:
	return SiegeDirector.current


# ------------------------------------------------------------------ 进场
func _run_enter() -> void:
	print("-- 城门 → 攻防战")
	await main.change_level(Floors.scene("floor_06_war"))
	await _advance_until(func(): return not Cutscene.is_playing() and not Dialogue.is_active(), 15.0)
	Dialogue.call("talk", "floor_06/war_gate")
	await _advance_until(func(): return _level_id() == "floor_06_siege" and _dir() != null and _dir().state != "", 30.0)
	# 开场过场（关卡载入 0.6 秒后才开始）
	await _advance_until(func(): return GameState.has_flag("siege_intro_seen") and not Cutscene.is_playing() and not Dialogue.is_active(), 30.0)
	var d := _dir()
	check("城门「出发！」→ 攻防战地图（%s），导演就绪（%s）" % [_level_id(), d.state if d else ""], _level_id() == "floor_06_siege" and d != null)
	check("8 段城墙（%d）、3 架梯子（%d）、城墙总血量 %d" % [d.walls.size(), d.ladders.size(), int(d.wall_max)],
		d.walls.size() == 8 and d.ladders.size() == 3 and d.wall_hp == d.wall_max)
	check("粉色公主操控、在城门口；蓝色公主在城墙上，用城墙法师 AI（%s）" % [d.blue.controller.get_class() if d.blue else ""],
		GameState.player == d.pink and d.blue and d.is_on_wall(d.blue) and d.blue.controller is SiegeMageController and not d.is_on_wall(d.pink)
		and Duo.active)
	check("开场过场放过了（%s）" % GameState.has_flag("siege_intro_seen"), GameState.has_flag("siege_intro_seen"))


# ------------------------------------------------------------------ 波次
func _run_waves() -> void:
	print("-- 波次")
	var d := _dir()
	var p0 := d.prep_left
	await _wait(1.0)
	check("准备阶段倒计时（%.1f → %.1f）" % [p0, d.prep_left], d.state == "prep" and d.prep_left < p0)
	var horn: SiegeHorn = main.level.find_children("*", "SiegeHorn", true, false)[0]
	horn.blow()
	await _wait(0.3)
	check("号角提前开打（%s）" % d.state, d.state == "fight")
	var hp0 := d.wall_hp
	var c0 := d.crystals
	var spells := {}
	var t := 0.0
	while t < 40.0 and d.state == "fight":
		var it: String = (d.blue.controller as SiegeMageController).intent
		if it.begins_with("spell:"):
			spells[it] = true
		await get_tree().process_frame
		t += get_process_delta_time()
	check("出怪了（打倒 %d 只），怪物打到城墙（%d → %d）" % [d.kills, int(hp0), int(d.wall_hp)], d.kills > 0 and d.wall_hp < hp0)
	check("蓝色公主自动放法术（%s）" % [spells.keys()], spells.has("spell:ice_rain"))
	check("打倒怪物得冰晶（%d → %d）" % [c0, d.crystals], d.crystals > c0)
	# 剩下的直接清掉，看清波
	d._queue.clear()
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.health.damage(999)
	await _advance_until(func(): return d.state == "prep" and d.wave == 2, 5.0)
	check("清完第 1 波 → 第 2 波准备（第 %d 波，%s）" % [d.wave, d.state], d.wave == 2 and d.state == "prep")


# ------------------------------------------------------------------ 镜头 / 切换 / 瞄准施法
func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _run_controls() -> void:
	print("-- 镜头缩放 / 全景 / C 切换 / 瞄准施法")
	var d := _dir()
	await _press("zoom_out")
	await _press("zoom_out")
	await _wait(1.0)
	var z1 := GameState.player.camera.zoom.x
	for i in 6:
		await _press("zoom_in")
	await _wait(1.0)
	var z2 := GameState.player.camera.zoom.x
	check("滚轮 / - / = 缩放：缩小到 %.2f、放大到 %.2f（范围 0.5~1.5）" % [z1, z2], is_equal_approx(z1, 0.5) and is_equal_approx(z2, 1.5))
	d.cam.set_zoom_level(1.0, true)
	await _press("overview")
	var ov_zoom := GameState.player.camera.zoom.x
	var paused := get_tree().paused
	await _press("overview")
	check("V 全景：游戏暂停（%s）、镜头缩到看全图（%.2f），再按 V 回来（%.2f、%s）" % [paused, ov_zoom, GameState.player.camera.zoom.x, get_tree().paused],
		paused and ov_zoom < 0.3 and is_equal_approx(GameState.player.camera.zoom.x, 1.0) and not get_tree().paused)
	# C 切换到蓝色公主，缩放倍数沿用
	d.cam.set_zoom_level(0.75, true)
	main.switch_character()
	await _wait(0.3)
	check("C 切换到蓝色公主（%s），镜头倍数沿用（%.2f），粉色公主变成 AI（%s）" % [GameState.player == d.blue, GameState.player.camera.zoom.x,
			d.pink.controller.get_script().get_global_name()],
		GameState.player == d.blue and is_equal_approx(GameState.player.camera.zoom.x, 0.75) and d.pink.controller is CompanionController)
	# 瞄准施法
	for i in 6:
		var m := d.spawn("slime", "bottom", Vector2(d.blue.global_position.x + i * 6.0, d.wall_foot_y() + 60.0))
		m.mind = null
	d.blue.set_meta("siege_cd", {})
	var took: bool = PlayableCharacter.magic_override.call(d.blue)
	var opened := d.aim.active and PlayerInputController.movement_locked
	d.aim.cycle(1)
	var second := d.aim.spell
	d.aim.cycle(-1)
	d.aim.point = Vector2(d.blue.global_position.x + 15.0, d.wall_foot_y() + 60.0)
	var hp_before := 0
	for m in d.monsters:
		hp_before += m.health.hp
	var fired := d.aim.fire()
	for i in 5:
		if fired:
			break
		d.blue.set_meta("siege_cd", {})
		d.aim.open(d.blue)
		d.aim.point = Vector2(d.blue.global_position.x + 15.0, d.wall_foot_y() + 60.0)
		fired = d.aim.fire()
	await _wait(0.8)
	var hp_after := 0
	for m in d.monsters:
		if is_instance_valid(m):
			hp_after += m.health.hp
	check("按 L 打开瞄准（%s / %s），Q / R 换法术（%s），放出冰锥雨（%s）打到怪（%d → %d），收起准星、进冷却（%.1f 秒）" % [took, opened, second,
			fired, hp_before, hp_after, SiegeSpells.cooldown_left(d.blue, "ice_rain")],
		took and opened and second == "barrier" and fired and hp_after < hp_before and not d.aim.active
		and SiegeSpells.cooldown_left(d.blue, "ice_rain") > 0.0 and not PlayerInputController.movement_locked)
	# 千手痒痒裤有 10% 让魔法失败：多试几次
	for i in 6:
		d.blue.set_meta("siege_cd", {})
		d.aim.open(d.blue)
		d.aim.spell = "reinforce"
		d.aim.point = Vector2(d.walls[2].global_position.x, d.wall_foot_y())
		if d.aim.fire():
			break
		d.aim.close()
	check("冰墙加固：那段墙罩上冰壳（%.0f 点、%.1f 秒），怪物爬不上来（%s）" % [d.walls[2].shield_hp, d.walls[2].shield_left, not d.walls[2].climbable()],
		d.walls[2].shield_hp > 0.0 and not d.walls[2].climbable())
	d.pink.laugh.set_value(d.pink.laugh.max_value * 0.8)
	var lv0 := d.pink.laugh.value
	var snow_ok := false
	for i in 6:
		d.blue.set_meta("siege_cd", {})
		d.aim.open(d.blue)
		d.aim.spell = "snow"
		d.aim.point = d.pink.global_position
		snow_ok = d.aim.fire()
		if snow_ok:
			break
		d.aim.close()
	check("清凉雪花：粉色公主闷笑下降（%.0f → %.0f）" % [lv0, d.pink.laugh.value], snow_ok and d.pink.laugh.value < lv0)
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	d.monsters.clear()
	main.switch_character()
	await _wait(0.3)
	d.cam.set_zoom_level(1.0, true)


# ------------------------------------------------------------------ 冰塔
func _pads() -> Array:
	var a := get_tree().get_nodes_in_group("siege_pad")
	a.sort_custom(func(x, y): return x.index < y.index)
	return a


func _keep_fighting(d: SiegeDirector) -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d.state = "fight"


func _clear_monsters(d: SiegeDirector) -> void:
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	d.monsters.clear()


func _run_towers() -> void:
	print("-- 冰塔")
	var d := _dir()
	var pads := _pads()
	check("待建区 10 个冰塔格（%d）、敌方区域 6 个地基（%d）" % [pads.size(), get_tree().get_nodes_in_group("siege_enemy_site").size()],
		pads.size() == 10 and get_tree().get_nodes_in_group("siege_enemy_site").size() == 6)
	var pad: BuildPad = pads[4]
	d.add_crystals(200)
	var c0 := d.crystals
	d.pink.global_position = pad.global_position
	pad.on_pink(d.pink)
	await get_tree().process_frame
	var menu_open := Dialogue.runner.choice_menu.is_open()
	Dialogue.runner.choice_menu.choose(0)
	await get_tree().process_frame
	check("粉色公主在冰塔格上按 E：选塔菜单（%s），选了冰锥塔付冰晶（%d → %d），等蓝色公主的冰光（%s）" % [menu_open, c0, d.crystals, pad.waiting()],
		menu_open and d.crystals == c0 - 10 and pad.waiting())
	var t := await _advance_until(func(): return pad.tower != null, 25.0)
	check("蓝色公主（AI）走过来放冰光 → 冰锥塔破冰而出（%.1f 秒，%s）" % [t, pad.tower.kind if pad.tower else ""], pad.tower != null and pad.tower.kind == "icicle")
	pad.request("icicle", true)
	await _advance_until(func(): return pad.tower and pad.tower.level == 2, 20.0)
	check("同一格再造一次 → 2 级（%d），布置存进 vars（%s）" % [pad.tower.level if pad.tower else 0, GameState.vars.get("siege_towers", {})],
		pad.tower and pad.tower.level == 2 and GameState.vars.get("siege_towers", {}).get("4", []) == ["icicle", 2])
	# 其它 5 种的效果（直接建）
	var kinds := ["snowman", "decoy", "mint", "frost", "repair"]
	var built := {}
	for i in kinds.size():
		var pd: BuildPad = pads[i]
		pd._build(kinds[i], 1)
		built[kinds[i]] = pd.tower
	_keep_fighting(d)
	await _wait(0.3)
	# 冰锥：打怪
	var m1: Monster = d.spawn("slime", "", pad.global_position + Vector2(0, 60))
	m1.mind = null
	var hp1 := m1.health.hp
	await _wait(2.5)
	check("冰锥塔自动射冰锥打怪（%d → %d）" % [hp1, m1.health.hp if is_instance_valid(m1) else 0], not is_instance_valid(m1) or m1.health.hp < hp1)
	var snows := get_tree().get_nodes_in_group("siege_temp").filter(func(n): return n is Snowman)
	check("雪人召唤塔放出小雪人（%d），小雪人也是怪物的目标（%s）" % [snows.size(), snows.size() > 0 and d.extra_targets.has(snows[0])],
		snows.size() >= 2 and d.extra_targets.has(snows[0]))
	var decoy: IceTower = built["decoy"]
	var m2: Monster = d.spawn("slime", "", decoy.global_position + Vector2(40, 50))
	var t2 := d.nearest_target(m2, m2.stats.detect_range)
	check("诱饵冰雕：附近的怪优先找它（%s）" % [t2], t2 == decoy)
	var mint: IceTower = built["mint"]
	d.pink.global_position = mint.global_position + Vector2(0, 16)
	d.pink.laugh.set_value(d.pink.laugh.max_value * 0.5)
	var lv0 := d.pink.laugh.value
	await _wait(1.6)
	check("薄荷冰泉：旁边的粉色公主闷笑下降（%.0f → %.0f）" % [lv0, d.pink.laugh.value], d.pink.laugh.value < lv0 - 3.0)
	var frost: IceTower = built["frost"]
	var m3: Monster = d.spawn("slime", "", frost.global_position + Vector2(0, 40))
	m3.mind = null
	await _wait(0.8)
	check("寒霜塔：范围里的怪减速（%s）/ 冻住（%s）" % [m3.has_buff("siege_chill"), m3.is_stunned()], m3.has_buff("siege_chill") and m3.is_stunned())
	var rep: IceTower = built["repair"]
	var seg := d.segment_at(rep.global_position.x)
	seg.take(60.0)
	var tk := seg.taken
	await _wait(2.2)
	check("冰墙修补塔：身后那段墙慢慢修好（挨打 %.0f → %.0f）" % [tk, seg.taken], seg.taken < tk)
	_clear_monsters(d)
	d._queue.clear()
	d.state = "prep"


# ------------------------------------------------------------------ 敌塔
func _run_enemy_towers() -> void:
	print("-- 敌塔")
	var d := _dir()
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	_keep_fighting(d)
	# 自己聚集起来搭塔
	var site: EnemySite = sites[0]
	for i in 9:
		var m: Monster = d.spawn("slime", "site", site.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)))
		(m.mind as SiegeMind).hold(site.global_position, 30.0)
	var t := await _advance_until(func(): return site.tower != null, 12.0)
	check("怪物在地基旁聚集 9 只、待够 6 秒 → 自己搭起敌塔（%.1f 秒，%s）" % [t, site.tower.kind if site.tower else ""], site.tower != null)
	if site.tower:
		var c0 := d.crystals
		site.tower.health.damage(999)
		await _wait(0.2)
		check("拆掉敌塔掉冰晶（%d → %d），地基空出来（%s）" % [c0, d.crystals, site.tower == null], d.crystals > c0 and site.tower == null)
	_clear_monsters(d)
	var near_pink := func(et: EnemyTower, off := Vector2(0, -60)):
		d.pink.global_position = et.global_position + off
		d.pink.camera.reset_smoothing()
	# 各种敌塔
	var results := {}
	var s1: EnemySite = sites[1]
	for kind in ["vine_pull", "glue", "net", "windmill", "sole_tower", "portal", "totem", "thigh_tower", "silence"]:
		var et := s1.build(kind)
		await get_tree().process_frame
		d.pink.status.release(true)
		d.pink.status.clear_root()
		d.pink.laugh.set_value(0.0)
		d.blue.laugh.set_value(0.0)
		near_pink.call(et)
		var p0 := d.pink.global_position
		et._t = 0.0
		var ok := false
		var tt := 0.0
		while tt < 4.0 and not ok:
			match kind:
				"vine_pull": ok = d.pink.get_meta("siege_dragged", false) and d.pink.global_position.distance_to(et.global_position) < p0.distance_to(et.global_position) - 4.0
				"glue": ok = get_tree().get_nodes_in_group("siege_temp").any(func(n): return n is GluePuddle)
				"net": ok = d.pink.status.is_rooted() and d.pink.has_buff("lifted")
				"windmill": ok = d.pink.global_position.distance_to(p0) > 10.0
				"sole_tower": ok = d.pink.status.is_rooted() and d.pink.laugh.value > 0.0
				"portal": ok = d.monsters.size() > 0
				"totem": ok = EquipFx.of(d.blue).rate_mul > 1.5 and is_equal_approx(EquipFx.of(d.blue).power_mul, 1.5)
				"thigh_tower": ok = d.blue.laugh.value > 0.0
				"silence":
					et.global_position.x = d.blue.global_position.x
					ok = d.silenced(d.blue)
			await get_tree().process_frame
			tt += get_process_delta_time()
		results[kind] = ok
		et.health.damage(999)
		await _wait(0.2)
		_clear_monsters(d)
	check("敌塔各自生效：%s" % [results], results.values().all(func(v): return v))
	check("狂欢图腾倒了以后千手痒痒裤恢复（频率 ×%.2f）" % EquipFx.of(d.blue).rate_mul, is_equal_approx(EquipFx.of(d.blue).rate_mul, 1.0))
	d.pink.status.release(true)
	d.pink.status.clear_root()
	for n in get_tree().get_nodes_in_group("siege_temp"):
		n.queue_free()
	d._queue.clear()
	d.state = "prep"


# ------------------------------------------------------------------ 蓝色公主被挠下城墙
func _run_blue_fall() -> void:
	print("-- 蓝色公主被挠下城墙 / 爬回去")
	var d := _dir()
	d.knock_off(d.blue, "测试")
	await _wait(1.0)
	var down := not d.is_on_wall(d.blue)
	d.blue.set_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0 - SiegeDirector.FALLEN_TIME - 0.1)
	var t := await _advance_until(func(): return d.is_on_wall(d.blue), 25.0)
	check("被挠下城墙（%s），时间到自己走去梯子爬回去（%.1f 秒）" % [down, t], down and d.is_on_wall(d.blue))
	# 粉色公主也能爬梯子
	var lad: SiegeLadder = d.nearest_ladder(d.pink.global_position)
	d.pink.global_position = lad.bottom_pos()
	await lad.climb(d.pink)
	var up := d.is_on_wall(d.pink)
	await lad.climb(d.pink)
	check("粉色公主爬梯子上城墙（%s）再下来（%s）" % [up, not d.is_on_wall(d.pink)], up and not d.is_on_wall(d.pink))


# ------------------------------------------------------------------ 倒下
func _run_downs() -> void:
	print("-- 倒下")
	var d := _dir()
	d.blue.health.damage(999)
	await _advance_until(func(): return Downed.is_downed(d.blue), 5.0)
	var dn: Downed = d.blue.get_node_or_null("Downed")
	var tl0 := dn.time_left if dn else 0.0
	await _wait(1.0)
	check("蓝色公主倒下：倒地不倒计时（%.1f → %.1f）" % [tl0, dn.time_left if dn else -1.0], dn != null and dn.time_left == tl0)
	var lad: SiegeLadder = d.nearest_ladder(d.blue.global_position)
	d.pink.global_position = d.blue.global_position + Vector2(10, 0)
	d.pink.set_controller(HoldE.new())
	await _advance_until(func(): return not Downed.is_downed(d.blue), 5.0)
	d.pink.set_controller(PlayerInputController.new())
	check("粉色公主过去按住 E 救起蓝色公主（%s）" % (not Downed.is_downed(d.blue)), not Downed.is_downed(d.blue) and d.blue.is_alive())
	# 粉色公主倒下：城门复活、打仗时城墙扣血
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d._queue = [{"t": 9999.0, "monster": "slime", "from": "bottom"}]   # 让这一波别马上清完
	d.state = "fight"
	d.pink.global_position = d.gate_pos + Vector2(200, 300)
	var hp0 := d.wall_hp
	d.pink.health.damage(999)
	await _advance_until(func(): return d.pink.is_alive() and d.pink.state != PlayableCharacter.State.DEAD, 8.0)
	check("粉色公主倒下 → 城门复活（离城门 %.0f），城墙扣血（%d → %d）" % [d.pink.global_position.distance_to(d.gate_pos), int(hp0), int(d.wall_hp)],
		d.pink.is_alive() and d.pink.global_position.distance_to(d.gate_pos) < 24.0 and d.wall_hp < hp0)
	d._queue.clear()
	d.state = "prep"


# ------------------------------------------------------------------ 失败 / 胜利
func _run_fail_and_win() -> void:
	print("-- 失败 / 胜利")
	var d := _dir()
	d.start_now()
	await _wait(0.3)
	var w := d.wave
	d.wall_hp = 10.0
	d.walls[3].take(50.0)
	await _advance_until(func(): return d.state == "prep" and not d._busy, 20.0)
	check("城墙归零 → 失败 → 城墙修好（%d）、怪物清空（%d）、从第 %d 波的准备阶段重来（第 %d 波 %s）" % [int(d.wall_hp), d.monsters.size(), w, d.wave, d.state],
		d.wall_hp == d.wall_max and d.monsters.is_empty() and d.wave == w and d.state == "prep")
	d.wave = 10
	d.start_now()
	await _wait(0.3)
	d._queue.clear()
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.health.damage(999)
	await _advance_until(func(): return GameState.has_flag("siege_won"), 5.0)
	check("第 10 波打完 → 胜利（%s）" % GameState.has_flag("siege_won"), GameState.has_flag("siege_won") and d.state == "won")
	await _advance_until(func(): return _level_id() == "floor_06_war", 20.0)
	check("胜利过场后回到战时小镇（%s）" % _level_id(), _level_id() == "floor_06_war")


# ------------------------------------------------------------------ 性能
func _run_perf() -> void:
	print("-- 性能：150 只怪")
	GameState.set_flag("siege_won", false)
	GameState.vars["siege_wave"] = 3
	await _wait(2.0)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _advance_until(func(): return _dir() != null and _dir().state == "prep" and not Cutscene.is_playing(), 20.0)
	var d := _dir()
	d.data["alive_cap"] = 200
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy"]
	for i in 150:
		d.spawn(keys[i % keys.size()], ["bottom", "left", "right", "hole"][i % 4])
	d.state = "fight"
	await _wait(1.0)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 4_000_000:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	var avg := 4000.0 / frames
	check("150 只怪同时在场：平均每物理帧 %.1f ms（%d 帧，最慢 %.1f ms），目标 ≤ 33 ms" % [avg, frames, worst], avg <= 33.0 and d.monsters.size() >= 120)


# ------------------------------------------------------------------ 工具
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		if CG.is_busy() and CG.has_method("skip"):
			CG.skip()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
