extends Node
## 第八层测试：双人模式（切换、各自的台词档案、AI 搭档、倒地救援）、千手痒痒魔三个阶段（压力板、地形、献祭小窗）、战败重来、
## 胜利 → 巨石追逐（碰障碍退一格、相差太远 / 被巨石追上失败、都到终点成功）、右边小窗组件。
## 用法：Godot --headless --path . res://tests/floor8_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var dir: Floor8Director


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	ChaseRun.countdown = false
	ChaseRun.seed_value = 7
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["blue_is_hero", "f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_done_f7_pink_run"]:
		GameState.set_flag(f)
	await _run_intro()
	await _run_duo()
	await _run_ai()
	await _run_downed()
	await _run_phase2()
	await _run_phase3()
	await _run_victory_and_chase()
	_run_side_window()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


# ------------------------------------------------------------------ 开场
func _run_intro() -> void:
	print("-- 第八层开场")
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	await main.change_level(Floors.scene("floor_08"))
	await _advance_until(func(): return Duo.active and not Cutscene.is_playing() and Floor8Director.instance != null and Floor8Director.instance.phase == 1, 60.0)
	Cutscene.started.disconnect(on_cut)
	dir = Floor8Director.instance
	check("开场过场（%s）→ 冰晶结界救下粉色公主 → 双人模式开始，阶段一" % [seen],
		seen.has("f8_intro_a") and seen.has("f8_intro_b") and Duo.active and dir.phase == 1 and dir.boss.fighting and not dir.pink.status.is_grabbed())
	check("两个人：玩家操控蓝色公主，粉色公主是 AI 搭档；Boss 战配乐（%s）" % Audio.music_id,
		GameState.player is BluePrincess and dir.pink.controller is CompanionController and dir.pink.faction == Faction.Type.ALLY
		and Audio.music_id == "boss" and Audio.MUSIC.has("boss") and ResourceLoader.exists(Audio.MUSIC["boss"]))


# ------------------------------------------------------------------ 切换 / 档案
func _run_duo() -> void:
	print("-- 切换操控、各自的台词档案")
	var blue := dir.blue
	var pink := dir.pink
	main.switch_character()
	await get_tree().process_frame
	check("Tab 切换：玩家变成粉色公主，蓝色公主变成 AI；镜头跟着粉色公主；当前档案 pink",
		GameState.player == pink and pink.controller is PlayerInputController and blue.controller is CompanionController
		and pink.camera.is_current() and Characters.current() == "pink")
	Characters.scope("blue")
	var blue_calm: Array = ReactionDB.lines("thousand_hand", "calm")
	Characters.unscope()
	var pink_calm: Array = ReactionDB.lines("thousand_hand", "calm")
	check("没被操控的人也用自己的台词：蓝色公主对千手（%s）≠ 粉色公主（%s）" % [blue_calm[0], pink_calm[0]],
		str(blue_calm).contains("以前") or str(blue_calm).contains("是你") and blue_calm != pink_calm)
	main.switch_character()
	await get_tree().process_frame
	check("再按一次切回蓝色公主", GameState.player == blue and pink.controller is CompanionController)


# ------------------------------------------------------------------ AI 搭档
func _run_ai() -> void:
	print("-- AI 搭档")
	dir.boss.fighting = false
	dir.boss.cancel_attacks()
	var pink := dir.pink
	var ai := pink.controller as CompanionController
	var lv: Node = main.level
	var slime: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	lv.get_node("Entities").add_child(slime)
	slime.global_position = pink.global_position + Vector2(40, 0)
	await get_tree().physics_frame
	slime.stun(5.0)   # 定住（不能用 PROCESS_MODE_DISABLED：那样碰撞体也会被移出物理世界）
	var hp0 := slime.health.hp
	await _wait(2.0)
	var hp1 := slime.health.hp if is_instance_valid(slime) else 0
	check("AI 会去打附近的敌人（%s，史莱姆血 %d → %d）" % [ai.intent, hp0, hp1], hp1 < hp0)
	if is_instance_valid(slime):
		slime.queue_free()
	await get_tree().process_frame
	var mark := Node2D.new()
	mark.add_to_group("danger")
	mark.set_meta("radius", 16.0)
	lv.add_child(mark)
	mark.global_position = pink.global_position
	var p0 := pink.global_position
	await _wait(0.5)
	check("AI 会躲开脚下的预警圈（移动了 %.0f 像素）" % pink.global_position.distance_to(p0), pink.global_position.distance_to(p0) > 14.0)
	mark.queue_free()
	pink.status.grab(dir.boss, 6.0, 6)
	await _wait(1.2)
	check("AI 被抓住会自己连按挣脱", not pink.status.is_grabbed())
	await _wait(0.3)


# ------------------------------------------------------------------ 倒地救援 / 战败重来
func _run_downed() -> void:
	print("-- 倒地救援、战败")
	var blue := dir.blue
	var pink := dir.pink
	pink.set_invulnerable(0.0)
	pink._full_invuln = 0.0
	pink.health.damage(99)
	await get_tree().process_frame
	check("粉色公主笑倒：不放 CG，倒在地上（倒计时 %d 秒）" % Downed.TIME, Downed.is_downed(pink) and not CG.is_busy() and not Duo.all_down())
	blue.global_position = pink.global_position + Vector2(10, 0)
	Input.action_press("interact")
	await _wait(Downed.REVIVE_TIME + 0.4)
	Input.action_release("interact")
	check("蓝色公主走到旁边按住 E 3 秒 → 救起，半血（%d/%d）" % [pink.health.hp, pink.health.max_hp],
		not Downed.is_downed(pink) and pink.is_alive() and pink.health.hp == int(ceil(pink.health.max_hp / 2.0)))
	# 倒地超时 → 战败小剧场 → 从阶段一开头重来
	dir.boss.fighting = true
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	pink._full_invuln = 0.0
	pink.health.damage(99)
	await get_tree().process_frame
	(pink.get_node("Downed") as Downed).time_left = 0.05
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and not dir.busy, 90.0)
	CG.started.disconnect(on_cg)
	check("倒地 25 秒没人救 → 阶段一的战败小剧场（%s）→ 两人满血回到起点、重来" % [cg_seen],
		cg_seen.has("theater:f8_defeat_1_1") and int(GameState.vars.get("f8_defeat_1", 0)) == 1 and dir.phase == 1
		and blue.is_alive() and pink.is_alive() and not Downed.is_downed(pink) and dir.boss.fighting)


# ------------------------------------------------------------------ 阶段二：压力板、地形
func _hit_to_floor() -> void:
	var b := dir.boss
	b.fighting = true
	b._attack_invuln = 0.0   # 上一下的受击无敌时间（0.12 秒）里打不动
	var floor_hp := 1 if b.phase >= 3 else int(ceil(b.health.max_hp * float(ThousandHand.PHASE_FLOOR[b.phase])))
	b.health.set_hp(floor_hp + 1)
	b.apply_hit(HitData.make_attack(dir.blue, 5, 0.0))


## 之后的阶段测试不让战斗本身打乱流程：两人无敌（献祭的闷笑由测试直接设置）。
func _protect() -> void:
	for m in Duo.members:
		m.set_invulnerable(9999.0, true)


func _run_phase2() -> void:
	print("-- 阶段二")
	_protect()
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	_hit_to_floor()
	await _advance_until(func(): return dir.phase == 2 and not dir.busy and not Cutscene.is_playing(), 60.0)
	Cutscene.started.disconnect(on_cut)
	var b := dir.boss
	check("打到 70%% → 过场（%s）→ 阶段二：Boss 缩到天花板打不到，两块压力板亮起" % [seen],
		seen.has("f8_phase2") and dir.phase == 2 and b.raised and not b.attackable and dir.plates_lit and dir.plates[0].visible)
	check("AI 会去站玩家没站的那块板", dir.plate_for(dir.pink) is Vector2)
	b.fighting = false
	dir.blue.global_position = dir.plates[0].global_position + Vector2(0, 4)
	dir.pink.global_position = dir.plates[1].global_position + Vector2(0, 4)
	await _wait(dir.PLATE_HOLD + 0.4)
	b.fighting = true
	var hp0 := b.health.hp
	b.apply_hit(HitData.make_attack(dir.blue, 2, 0.0))
	check("两人同时站上压力板 → 锁链把它拽下来：能打、伤害 ×1.5（%d → %d）" % [hp0, b.health.hp],
		b.is_pulled() and b.attackable and hp0 - b.health.hp == 3)
	dir.shift_terrain()
	var walls_up := dir.shifter.raised.size()
	dir.shift_terrain()
	var fields := dir.shifter.fields.size()
	dir.shift_terrain()
	check("改变地形：升起石墙（%d 格）→ 泥沼和传送带（%d 片）→ 落穴洞（%d 个）" % [walls_up, fields, dir.shifter.fields.size()],
		walls_up > 10 and fields >= 3 and dir.shifter.fields.size() >= 3)
	dir.shifter.clear()


# ------------------------------------------------------------------ 阶段三：献祭
func _run_phase3() -> void:
	print("-- 阶段三：献祭")
	dir.boss._pulled_left = 0.0
	_hit_to_floor()
	await _advance_until(func(): return dir.phase == 3 and not dir.busy and not Cutscene.is_playing(), 60.0)
	_protect()
	check("打到 35% → 阶段三：一直在上面，打不到", dir.phase == 3 and dir.boss.raised and not dir.boss.attackable and dir.instant_defeat)
	dir.boss.fighting = false
	dir._circle_cd = 0.0
	var blue := dir.blue
	var pink := dir.pink
	blue.global_position = dir.circle.global_position
	await _wait(0.6)
	var sac := dir.sacrifice
	check("蓝色公主走进光圈 → 被抓进巢穴：右边小窗打开、主画面切到粉色公主、方向键留给小窗、3 只手臂伸下来",
		not sac.is_empty() and sac["victim"] == blue and GameState.player == pink and SideWindow.is_open()
		and PlayerInputController.wasd_only and sac["limbs"].size() == 3 and blue.status.is_grabbed() and Duo.sacrifice_lock)
	var win := SideWindow.current
	check("小窗和主画面共用同一个世界、镜头对准巢穴里的她",
		win.viewport.world_2d == get_tree().root.world_2d and win.cam.global_position.distance_to(blue.global_position) < 20.0)
	dir.boss.fighting = true
	var hp0 := dir.boss.health.hp
	(sac["limbs"][0] as BossLimb).receive_hit(HitData.make_attack(pink, 2, 0.0))
	check("打下来的手臂 = 打本体（%d → %d）" % [hp0, dir.boss.health.hp], dir.boss.health.hp == hp0 - 2)
	dir.boss.fighting = false
	var st: SacrificeStruggle = sac["struggle"]
	var lm := blue.laugh
	var v0 := lm.value
	st.press(-1)
	st.press(-1)
	var same_dir := v0 - lm.value
	st.press(1)
	check("← → 交替按才算挣扎（同一个键连按只算一次）", same_dir <= SacrificeStruggle.PRESS + 0.1 and lm.value < v0 - SacrificeStruggle.PRESS * 1.5)
	var r0 := st.rate()
	st.held_time = 20.0
	check("被抓越久闷笑涨得越快（%.1f → %.1f / 秒）" % [r0, st.rate()], st.rate() > r0 * 2.0)
	st.held_time = 0.0
	for i in 40:
		st.press(-1 if i % 2 == 0 else 1)
		if not is_instance_valid(st) or dir.sacrifice.is_empty():
			break
	await _wait(0.4)
	check("降到憋笑以下 → 挣脱：小窗关上，她掉回场地，可以切换", dir.sacrifice.is_empty() and not SideWindow.is_open()
		and not blue.status.is_grabbed() and not PlayerInputController.wasd_only and not Duo.sacrifice_lock)
	# 笑满 → 战败
	await _wait(0.3)
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	dir._circle_cd = 0.0
	pink.global_position = dir.circle.global_position
	await _wait(0.6)
	var st2: SacrificeStruggle = dir.sacrifice.get("struggle")
	var had: bool = st2 != null and dir.sacrifice.get("victim") == pink
	if had:
		pink.laugh.set_value(pink.laugh.max_value - 1.0)
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and not dir.busy, 90.0)
	CG.started.disconnect(on_cg)
	_protect()
	check("献祭的人笑满 → 阶段三战败小剧场（%s）→ 从阶段三开头重来（阶段 %d、Boss 血 %d / %d）" % [cg_seen, dir.phase, dir.boss.health.hp, dir.boss.phase_start_hp(3)],
		had and cg_seen.has("theater:f8_defeat_3_1") and dir.phase == 3 and pink.is_alive() and blue.is_alive()
		and dir.boss.health.hp == dir.boss.phase_start_hp(3))


# ------------------------------------------------------------------ 胜利 → 追逐
func _run_victory_and_chase() -> void:
	print("-- 胜利 → 巨石追逐")
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	_hit_to_floor()
	await _advance_until(func(): return _level_id() == "floor_08_chase" and get_tree().get_first_node_in_group("chase_run") != null \
		and (get_tree().get_first_node_in_group("chase_run") as ChaseRun).running, 90.0)
	Cutscene.started.disconnect(on_cut)
	var run := get_tree().get_first_node_in_group("chase_run") as ChaseRun
	check("打到 1 点 → 恼怒、砸墙、巨石滚落（%s）→ 进入巨石追逐" % [seen],
		seen.has("f8_victory_a") and seen.has("f8_victory_b") and GameState.has_flag("f8_boss_down") and run != null and run.running)
	check("追逐：主画面跟着蓝色公主，右边小窗跟着粉色公主；两人从第 3 格出发，巨石在第 0 格",
		SideWindow.is_open() and SideWindow.current.target == run.b and run.a == GameState.player and run.pa < ChaseRun.START + 0.2 and run.boulder == 0.0)
	run.running = false
	# 碰障碍退一格
	var o: Dictionary = run.obstacles.filter(func(x): return x["lane"] == "a")[0]
	run.pa = o["cell"]
	run.xa = o["x"]
	run.running = true
	var before := run.pa
	run.advance(0.016)
	check("碰到障碍：后退一格（%.2f → %.2f），显示被挠的反馈" % [before, run.pa], run.pa < before - 0.9 and run.hits["a"] == 1)
	# 相差太远 → 失败 → 小剧场 → 重来
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	run.pa = 8.0
	run.pb = 3.5
	run.check_end()
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and run.running, 60.0)
	check("两人相差超过 4 格 → 追逐失败小剧场（%s）→ 从头再来" % [cg_seen], cg_seen.has("theater:f8_chase_fail") and is_equal_approx(run.pa, ChaseRun.START))
	cg_seen.clear()
	run.boulder = 3.2
	run.check_end()
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and run.running, 60.0)
	CG.started.disconnect(on_cg)
	check("巨石追上 → 也是失败", cg_seen.has("theater:f8_chase_fail") and run.boulder == 0.0)
	# 都到终点 → 成功
	for x in run.obstacles:
		x["hit"] = true
	run.pa = ChaseRun.CELLS - 0.01
	run.pb = ChaseRun.CELLS - 0.01
	seen.clear()
	Cutscene.started.connect(on_cut)
	run.advance(0.1)
	await _advance_until(func(): return seen.has("f8_ending") and not Cutscene.is_playing(), 60.0)
	Cutscene.started.disconnect(on_cut)
	check("两人一起到第 10 格 → 逃出来的结局过场（%s）" % [seen], GameState.has_flag("f8_done") and seen.has("f8_ending") and not SideWindow.is_open())


# ------------------------------------------------------------------ 小窗组件
func _run_side_window() -> void:
	print("-- 右边小窗组件")
	var target := Node2D.new()
	main.level.add_child(target)
	target.global_position = Vector2(200, 300)
	var w := SideWindow.open(target, {"title": "测试", "zoom": 2.0})
	check("SideWindow.open：共用主画面的世界、镜头跟随、标题", SideWindow.is_open() and w.viewport.world_2d == get_tree().root.world_2d
		and w.title_label.text == "测试")
	var label := Label.new()
	w.set_overlay(label)
	w.close(true)
	check("set_overlay / close", label.get_parent() != null and not SideWindow.is_open())


# ------------------------------------------------------------------ 工具
func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
