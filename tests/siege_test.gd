extends Node
## 小镇攻防战：
##   城门 → 攻防战地图；导演、8 段城墙、梯子、两位公主（粉色操控、蓝色在城墙上用城墙法师 AI）。
##   波次：准备倒计时 → 号角提前开打 → 出怪、怪物走到墙下打墙（城墙总血量下降）→ 蓝色公主放法术打怪 → 打倒得冰晶 → 清完下一波。
##   失败：城墙归零 → 清场 → （失败小剧场）→ 城墙修好、从这一波的准备阶段重来。胜利：最后一波（第 12 波）打完 → siege_won。
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
	SiegeIntel.auto_controls = false   # 按键说明情报不自动弹（siege3_test 单独测）
	TownBuffShow.enabled = false   # 镇民支援的过场跳过（buff 照样生效）
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked", "seen_fatigue_burst"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_enter()
	_dir().bench_soldiers(true)
	_dir().quiet_spawn = true   # 士兵（siege2_test 测）会先把测试里放的怪打掉
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
	# 打倒后会分裂 / 复活的（大史莱姆、分裂史莱姆、双子鬼）多清几轮
	for k in 6:
		for m in d.monsters.duplicate():
			if is_instance_valid(m):
				m.health.damage(999)
		await _wait(0.4)
	await _advance_until(func(): return d.wave == 2, 5.0)
	check("清完第 1 波 → 直接开打第 2 波（第 %d 波，%s）" % [d.wave, d.state], d.wave == 2 and d.state == "fight")


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
	# 按 1：打开瞄准、她进入吟诵姿势（小人 CHANNEL + 吟诵立绘），不走蓄力
	await _press("siege_spell_1")
	var took := d.aim.active and d.aim.spell == "ice_rain"
	var opened := took and PlayerInputController.movement_locked
	var chanting: bool = d.blue.state == PlayableCharacter.State.CHANNEL and d.blue.pose_only and d.blue.resolve_visual("").ends_with("chant")
	await _press("siege_spell_2")
	var second := d.aim.spell
	await _press("siege_spell_1")
	# 按 Esc：只收起准星，暂停菜单不打开
	var reopened := d.aim.active and d.aim.spell == "ice_rain"
	await _press("pause")
	var esc_ok := not d.aim.active and not get_tree().paused and d.blue.state != PlayableCharacter.State.CHANNEL
	d.blue.set_meta("siege_cd", {})
	d.aim.open(d.blue, "ice_rain")
	d.aim.point = Vector2(d.blue.global_position.x + 15.0, d.wall_foot_y() + 60.0)
	# 只看这几只（自动推进会一直出新怪）
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	var watch := d.monsters.filter(func(m): return is_instance_valid(m) and m.global_position.distance_to(d.aim.point) < 60.0)
	var hp_before := 0
	for m in watch:
		hp_before += m.health.hp
	var fired := d.aim.fire()
	for i in 5:
		if fired:
			break
		d.blue.set_meta("siege_cd", {})
		d.aim.open(d.blue, "ice_rain")
		d.aim.point = Vector2(d.blue.global_position.x + 15.0, d.wall_foot_y() + 60.0)
		fired = d.aim.fire()
	var casting: bool = d.blue.state == PlayableCharacter.State.CAST and d.blue.resolve_visual("").ends_with("burst")
	await _wait(0.8)
	var hp_after := 0
	for m in watch:
		if is_instance_valid(m):
			hp_after += m.health.hp
	check("按 1 打开瞄准（%s / %s）、吟诵姿势（%s），按 2 换法术（%s），Esc 只收起准星（%s / %s），放出冰锥雨（%s）进入释放姿势（%s）打到怪（%d → %d）" % [
			took, opened, chanting, second, reopened, esc_ok, fired, casting, hp_before, hp_after],
		took and opened and chanting and second == "barrier" and reopened and esc_ok and fired and casting and hp_after < hp_before
		and not d.aim.active and SiegeSpells.cooldown_left(d.blue, "ice_rain") > 0.0 and not PlayerInputController.movement_locked)
	# L 还是她自己的冰晶结界（原地吟唱，不是瞄准）
	await _wait(1.0)
	d.blue._magic_cd = 0.0
	var ev := InputEventAction.new()
	ev.action = "magic"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var own := d.blue.state == PlayableCharacter.State.CHANNEL and not d.blue.pose_only and not d.aim.active
	var up := InputEventAction.new()
	up.action = "magic"
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.5)
	check("L 还是她自己的冰晶结界（原地吟唱 %s，没打开瞄准）" % own, own)
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
func _make_pad(at: Vector2, kind: String, lvl := 1) -> BuildPad:
	var pd := BuildPad.new()
	_dir().entities().add_child(pd)
	pd.global_position = at
	pd._build(kind, lvl)
	return pd


func _keep_fighting(d: SiegeDirector) -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d.state = "fight"


## 前面被挠倒了的话扶起来（倒地 / 失控时塔和冰泉都不理她）。
func _revive_pink(d: SiegeDirector) -> void:
	var p := d.pink
	var dn := p.get_node_or_null("Downed")
	if dn:
		dn.free()
	if not p.is_alive() or p.state == PlayableCharacter.State.DEAD:
		p.revive()
	if p.state in [PlayableCharacter.State.DEAD, PlayableCharacter.State.HELPLESS, PlayableCharacter.State.GRABBED]:
		p._set_state(PlayableCharacter.State.IDLE)
	p.visible = true
	p.set_physics_process(true)
	p.laugh.set_value(0.0)
	if p.status:
		p.status.release(true)
		p.status.clear_root()
	for k in ["siege_dragged", "siege_netted", "siege_bubbled", "siege_chained"]:
		p.set_meta(k, false)


func _clear_monsters(d: SiegeDirector) -> void:
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	d.monsters.clear()


func _run_towers() -> void:
	print("-- 冰塔")
	var d := _dir()
	check("没有固定的冰塔格（%d），敌塔地基全地图都有（%d 个）" % [get_tree().get_nodes_in_group("siege_pad").size(),
			get_tree().get_nodes_in_group("siege_enemy_site").size()],
		get_tree().get_nodes_in_group("siege_pad").is_empty() and get_tree().get_nodes_in_group("siege_enemy_site").size() >= 24)
	if GameState.player != d.pink:
		main.switch_character()
		await _wait(0.3)
	d.add_crystals(200)
	var c0 := d.crystals
	var spot := Vector2(d.gate_pos.x + 100.0, d.wall_foot_y() + 70.0)
	d.pink.global_position = spot
	await _press("siege_build")
	await get_tree().process_frame
	# 造塔菜单：带滚动的选择界面（ScrollPicker），整块面板在屏幕里
	var picker := ScrollPicker.current
	var menu_open := picker != null and picker.options.size() == IceTower.kinds().size() + 1
	var vp := get_viewport().get_visible_rect().size
	var inside := picker != null and Rect2(Vector2.ZERO, vp).encloses(Rect2(picker.panel.position, picker.panel.size))
	# 往下翻到最后一个塔（列表滚动），再回到第一个选
	for i in IceTower.kinds().size() - 1:
		await _press("move_down")
	var scrolled := picker != null and picker.list_box.scroll_vertical > 0
	for i in IceTower.kinds().size() - 1:
		await _press("move_up")
	if picker:
		picker.choose(0)
	await get_tree().process_frame
	await get_tree().process_frame
	check("造塔菜单在屏幕里（%s），选项多了能往下滚（%s）" % [inside, scrolled], inside and scrolled)
	var pad: BuildPad = null
	for pd in get_tree().get_nodes_in_group("siege_pad"):
		pad = pd
	check("粉色公主按 B：在脚下放冰塔基座、选塔菜单（%s），选了冰锥塔付冰晶（%d → %d），等蓝色公主的冰光（%s）" % [menu_open, c0, d.crystals,
			pad.waiting() if pad else false],
		menu_open and d.crystals == c0 - 10 and pad != null and pad.waiting() and pad.global_position.distance_to(spot) < 6.0)
	var t := await _advance_until(func(): return pad.tower != null, 25.0)
	check("蓝色公主（AI）走过来放冰光 → 冰锥塔破冰而出（%.1f 秒，%s）" % [t, pad.tower.kind if pad.tower else ""], pad.tower != null and pad.tower.kind == "icicle")
	var why_wall := d.build_blocked(Vector2(spot.x, d.wall_top_y()))
	var why_near := d.build_blocked(spot + Vector2(16, 0))
	var far_pad := BuildPad.new()
	d.entities().add_child(far_pad)
	far_pad.global_position = Vector2(spot.x, d.wall_foot_y() + 520.0)
	var beam_far := far_pad.beam_time()
	far_pad.queue_free()
	check("城墙上不能建（%s）、离塔太近不能建（%s）；离城墙越远冰光越久（%.1f 秒 > %.1f 秒）" % [why_wall, why_near, beam_far, pad.beam_time()],
		why_wall != "" and why_near != "" and beam_far > pad.beam_time())
	pad.request("icicle", true)
	await _advance_until(func(): return pad.tower and pad.tower.level == 2, 20.0)
	var saved: Array = GameState.vars.get("siege_towers", [])
	check("同一座再造一次 → 2 级（%d），布置存进 vars（%s）" % [pad.tower.level if pad.tower else 0, saved],
		pad.tower and pad.tower.level == 2 and saved.size() == 1 and saved[0]["kind"] == "icicle" and int(saved[0]["level"]) == 2)
	# 其它 5 种的效果（直接建）
	var kinds := ["snowman", "decoy", "mint", "frost", "repair"]
	var built := {}
	for i in kinds.size():
		var pd2 := _make_pad(Vector2(d.gate_pos.x - 400.0 + i * 70.0, d.wall_foot_y() + 70.0), kinds[i])
		built[kinds[i]] = pd2.tower
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
	_clear_monsters(d)   # 旁边的怪会一边挠她（闷笑反而涨）
	_revive_pink(d)
	d.pink.global_position = mint.global_position + Vector2(0, 16)
	d.pink.laugh.set_value(d.pink.laugh.max_value * 0.5)
	d.pink._full_invuln = 2.0   # 只看冰泉本身（别让路过的怪挠到她）
	var lv0 := d.pink.laugh.value
	await _wait(1.6)
	check("薄荷冰泉：旁边的粉色公主闷笑下降（%.0f → %.0f）" % [lv0, d.pink.laugh.value], d.pink.laugh.value < lv0 - 3.0)
	var frost: IceTower = built["frost"]
	var m3: Monster = d.spawn("slime", "", frost.global_position + Vector2(0, 40))
	m3.mind = null
	m3.health.max_hp = 99   # 寒霜冰爆有范围伤害：别让它半路被打倒
	m3.health.fill()
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
	# 各种敌塔（蓝色公主的 AI 见粉色公主被拖走 / 抓住会放清凉雪花解开，这一段先让她站着）
	d.blue.set_controller(CharacterController.new())
	var results := {}
	var s1: EnemySite = sites[1]
	for kind in ["vine_pull", "glue", "net", "windmill", "sole_tower", "portal", "totem", "thigh_tower", "silence"]:
		var et := s1.build(kind)
		await get_tree().process_frame
		if kind != "portal":
			_clear_monsters(d)   # 别的怪抓着她时藤蔓勾不住
		_revive_pink(d)
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
				# 勾住了、开始往塔下拖（机器很忙时帧少，拖得慢，只看拖动开始了没有）
				"vine_pull": ok = d.pink.get_meta("siege_dragged", false) and d.pink.global_position.distance_to(et.global_position) < p0.distance_to(et.global_position) - 1.0
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
	d.blue.set_controller(d._make_ai(d.blue))
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
	# 前面几段留下的敌塔 / 怪清掉（地基离城墙近了，塔会够到墙下）
	_clear_monsters(d)
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		t.queue_free()
	if d.blue.status:
		d.blue.status.release(true)
	await _wait(0.3)
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
	d.wave = SiegeDirector.total_waves()
	d.start_now()
	await _wait(0.3)
	d._queue.clear()
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.health.damage(999)
	await _advance_until(func(): return GameState.has_flag("siege_won"), 5.0)
	check("最后一波打完 → 胜利（%s）" % GameState.has_flag("siege_won"), GameState.has_flag("siege_won") and d.state == "won")
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
