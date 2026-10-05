extends Node
## 第八层测试：双人模式（切换、各自的台词档案、AI 搭档、倒地救援）、千手痒痒魔三个阶段（新技能、组合、掉落、冻住 Boss、
## 压力板保持、持续地形、献祭在主地图 + 空格挣扎 + 搭档帮忙、两人都倒下才输）、战败重来、
## 胜利 → 无限延伸的巨石追逐（并列画面、碰障碍退一格、相差太远 / 被巨石追上失败、都到终点成功）、右边小窗组件。
## 用法：Godot --headless --path . res://tests/floor8_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var dir: Floor8Director


class Src extends Node2D:
	var reaction_key := ""
	var tickle_zones := {}


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	ChaseRun.countdown = false
	ChaseRun.seed_value = 7
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	# 不设 blue_is_hero：粉色公主当主角走进第八层时，第八层自己换成蓝色公主（之前的 bug）
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_done_f7_pink_run", "intro_blue_magic"]:
		GameState.set_flag(f)
	await _run_intro()
	await _run_duo()
	await _run_ai()
	await _run_downed()
	await _run_phase1_extras()
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
	check("粉色公主当主角进来也会换成蓝色公主上场；两个人：玩家操控蓝色公主，粉色公主是 AI 搭档；Boss 战配乐（%s）" % Audio.music_id,
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


# ------------------------------------------------------------------ 阶段一：技能、组合、掉落、冻住 Boss、配乐
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


func _danger_count() -> int:
	return get_tree().get_nodes_in_group("danger").size()


func _run_phase1_extras() -> void:
	print("-- 阶段一：俯冲撞墙、组合、掉落、冻住 Boss")
	var b := dir.boss
	_protect()
	b.fighting = true
	b.skills.use("dash")
	await _wait(0.2)
	var warned := _danger_count() > 0
	var cages0 := get_tree().get_nodes_in_group("f8_dash_cage").size()
	await _advance_until(func(): return not b.skills.busy(), 6.0)
	check("俯冲撞墙：先亮整条通道的预警（进 danger 组），冲过去撞墙后掉落笼（%d 个）" % get_tree().get_nodes_in_group("f8_dash_cage").size(),
		warned and cages0 == 0 and get_tree().get_nodes_in_group("f8_dash_cage").size() >= 2)
	# 小怪掉落
	var items0: int = main.level.find_children("*", "", true, false).filter(func(n): return n is WorldItem).size()
	var m: Node2D = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	main.level.get_node("Entities").add_child(m)
	for i in 20:
		b.drop_loot(m)
	m.queue_free()
	await get_tree().process_frame
	var items: Array = main.level.find_children("*", "", true, false).filter(func(n): return n is WorldItem)
	check("召唤的小怪被打倒会掉爱心 / 星星糖（20 次掉了 %d 个）" % (items.size() - items0), items.size() - items0 >= 5)
	for it in items:
		it.queue_free()
	check("阶段一召唤更多小怪（同时最多 %d 只，每次 %d 只）" % [ThousandHand.SUMMON_CAP[1], ThousandHand.SUMMON_COUNT[1]],
		ThousandHand.SUMMON_CAP[1] >= 7 and ThousandHand.SUMMON_COUNT[1] >= 3)
	# 四组 Boss 三来源组合
	var fired := []
	var on_fired := func(id: String): fired.append(id)
	var hero := dir.blue
	hero.combo.triggered.connect(on_fired)
	for spec in [["th_brush_feast", ["thousand_hand", "squirrel", "hedgehog"]], ["th_bubble_web", ["thousand_hand", "bubble_fish", "spider"]],
			["th_feather_swarm", ["thousand_hand", "fairy", "squirrel"]], ["th_latch_crawl", ["thousand_hand", "caterpillar", "octopus"]]]:
		hero.combo.reset()
		hero._full_invuln = 0.0
		for k in spec[1]:
			var src := Src.new()
			src.reaction_key = k
			main.level.get_node("Entities").add_child(src)
			src.global_position = hero.global_position + Vector2(20, 0)
			hero.receive_hit(HitData.make_tickle(src, 1.0))
		await _wait(0.1)
	hero.combo.triggered.disconnect(on_fired)
	_protect()
	var want := ["th_brush_feast", "th_bubble_web", "th_feather_swarm", "th_latch_crawl"]
	check("四组 Boss 三来源组合都能触发、有台词和组合演出（%s）" % [want.filter(func(c): return not fired.has(c))],
		want.all(func(c): return fired.has(c) and CG.scenes.has(c) and ReactionDB.combo(c).get("name", "") != ""))
	# 冰晶结界冻住 Boss
	dir.blue.global_position = b.global_position + Vector2(0, 30)
	IceBarrier.cast_with(dir.blue, 96.0, 2.0)
	check("冰晶结界能冻住 Boss：不出招、技能停下、本体蒙冰", b.is_frozen() and b.pending_attacks() == 0 and not b.skills.busy()
		and b.sprite.modulate == IceBarrier.ICE)
	b._frozen_left = 0.0
	b.sprite.modulate = Color.WHITE
	# 连着换两次曲（读档时先地牢曲、马上 Boss 曲）不会没声音
	Audio.play_music("dungeon")
	Audio.play_music("boss")
	await _wait(1.6)
	var mp: AudioStreamPlayer = Audio._music[Audio._music_cur]
	check("连着换两次配乐（读档的情况）后仍在放 Boss 曲", Audio.music_id == "boss" and mp.playing and mp.volume_db > -30.0)


# ------------------------------------------------------------------ 阶段二：压力板、地形、手臂雨
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
	# 手臂砸地不抓人，积累闷笑（先关掉过场后可能还开着的对话：对话中挠痒和机关都不算）
	_finish()
	await get_tree().process_frame
	b.fighting = true
	dir.blue.set_invulnerable(0.0)
	dir.blue._full_invuln = 0.0
	dir.blue.laugh.set_value(0.0)
	dir.blue.remove_buff("frost_guard")   # 阶段一测试冻 Boss 时留下的冰晶守护（对话中状态不倒计时）
	b._slam(dir.blue.global_position)
	var slam_laugh := dir.blue.laugh.value
	_finish()
	check("阶段二手臂砸地不抓人（不打断操作），砸中积累闷笑（%.0f）" % slam_laugh, not dir.blue.status.is_grabbed() and slam_laugh > 5.0)
	_protect()
	# 压力板：离开后保持 3 秒
	b.fighting = false
	dir.pink.global_position = dir.plates[1].global_position + Vector2(0, 4)
	dir.blue.global_position = dir.plates[0].global_position + Vector2(0, 60)
	await _wait(0.3)
	_finish()
	dir.pink.global_position = dir.plates[1].global_position + Vector2(0, 80)
	await _wait(1.0)
	var still := dir.plate_pressed(1)
	dir.blue.global_position = dir.plates[0].global_position + Vector2(0, 4)
	await _wait(dir.PLATE_HOLD + 0.4)
	b.fighting = true
	var hp0 := b.health.hp
	b._attack_invuln = 0.0
	b.apply_hit(HitData.make_attack(dir.blue, 2, 0.0))
	check("压力板：人离开后还保持按下（1 秒后 %s）；另一块踩上去时两块都算按下 → 锁链把它拽下来，伤害 ×1.5（%d → %d）" % [still, hp0, b.health.hp],
		still and b.is_pulled() and b.attackable and hp0 - b.health.hp == 3)
	await _wait(dir.PLATE_LATCH + 0.3)
	# 持续长地形（石墙 / 泥沼 / 传送带 / 漩涡），不把路堵死
	b._pulled_left = 0.0
	for i in 12:
		dir.grow_terrain()
	check("阶段二地形持续变化：在玩家附近长出东西（%d 样），压力板仍然走得到" % dir.shifter.active_count(),
		dir.shifter.active_count() >= 1 and dir._still_reachable())
	dir.shift_terrain()
	var walls_up := dir.shifter.raised.size()
	dir.shift_terrain()
	var fields := dir.shifter.fields.size()
	check("整体改地形也还能用：石墙（%d 格）、泥沼和传送带（%d 片）" % [walls_up, fields], walls_up > 10 and fields >= 3)
	dir.shifter.clear()
	# 手臂雨
	b.fighting = true
	b.skills.use("rain")
	await _wait(1.2)
	check("手臂雨：一串砸地圈陆续落下（进 danger 组）", _danger_count() >= 3 or b.skills.busy())
	await _advance_until(func(): return not b.skills.busy(), 6.0)


# ------------------------------------------------------------------ 阶段三：献祭在主地图、羽毛风暴、千手乱舞
func _run_phase3() -> void:
	print("-- 阶段三")
	dir.boss._pulled_left = 0.0
	_hit_to_floor()
	await _advance_until(func(): return dir.phase == 3 and not dir.busy and not Cutscene.is_playing(), 60.0)
	_protect()
	var b := dir.boss
	check("打到 35%% → 阶段三：一直在上面；阶段三配乐（%s）、红色脉动暗角" % Audio.music_id,
		dir.phase == 3 and b.raised and not b.attackable and not dir.instant_defeat and Audio.music_id == "boss3"
		and is_instance_valid(dir._p3_vignette))
	b.fighting = false
	dir._circle_cd = 0.0
	var blue := dir.blue
	var pink := dir.pink
	blue.global_position = dir.circle.global_position
	await _wait(0.6)
	var sac := dir.sacrifice
	check("蓝色公主走进光圈 → 就在光圈那里被吊起来（不传送）：小窗对准她、主画面切到粉色公主、3 只手臂伸下来",
		not sac.is_empty() and sac["victim"] == blue and GameState.player == pink and SideWindow.is_open()
		and blue.global_position.distance_to(dir.circle.global_position) < 4.0 and sac["limbs"].size() == 3 and blue.status.is_grabbed()
		and not PlayerInputController.wasd_only)
	b.fighting = true
	var hp0 := b.health.hp
	b._attack_invuln = 0.0
	(sac["limbs"][0] as BossLimb).receive_hit(HitData.make_attack(pink, 2, 0.0))
	check("打下来的手臂 = 打本体（%d → %d）" % [hp0, b.health.hp], b.health.hp == hp0 - 2)
	b.fighting = false
	var st: SacrificeStruggle = sac["struggle"]
	var lm := blue.laugh
	var v0 := lm.value
	st.press()
	check("连按空格挣扎：每下降 %d" % SacrificeStruggle.PRESS, lm.value <= v0 - SacrificeStruggle.PRESS + 0.5)
	# 搭档在她身边攻击：帮她降闷笑
	var v1 := lm.value
	pink.global_position = blue.global_position + Vector2(14, 6)
	pink._set_state(PlayableCharacter.State.ATTACK)
	await get_tree().process_frame
	await get_tree().process_frame
	check("另一个人在她身边攻击也能帮她降闷笑（%.0f → %.0f）" % [v1, lm.value], st.assists >= 1 and lm.value < v1)
	pink._set_state(PlayableCharacter.State.IDLE)
	for i in 40:
		if not is_instance_valid(st) or dir.sacrifice.is_empty():
			break
		st.press()
	await _wait(0.4)
	check("降到憋笑以下 → 挣脱：小窗关上，她回到场地，可以切换", dir.sacrifice.is_empty() and not SideWindow.is_open()
		and not blue.status.is_grabbed() and not Duo.sacrifice_lock)
	# 献祭的人笑满 → 倒地（不直接战败）
	await _wait(0.3)
	dir._circle_cd = 0.0
	pink.global_position = dir.circle.global_position
	await _wait(0.6)
	var had: bool = dir.sacrifice.get("victim") == pink
	if had:
		pink.laugh.set_value(pink.laugh.max_value - 0.5)
	await _wait(0.4)
	check("献祭的人笑满 → 她倒地，但阶段三一个人倒下不算输（只有两个人都倒下才算）",
		had and Downed.is_downed(pink) and not dir.busy and dir.phase == 3)
	# 两个人都倒下 → 战败
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	blue.health.damage(99)
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and not dir.busy, 120.0)
	CG.started.disconnect(on_cg)
	_protect()
	check("两个人都倒下 → 阶段三战败小剧场（%s，四幕）→ 从阶段三开头重来" % [cg_seen],
		cg_seen.has("theater:f8_defeat_3_1") and dir.phase == 3 and pink.is_alive() and blue.is_alive() and not Downed.is_downed(pink)
		and b.health.hp == b.phase_start_hp(3))
	# 羽毛风暴：全场往一侧推
	b.fighting = true
	var p0 := pink.global_position
	var q0 := blue.global_position
	b.skills.use("storm")
	await _advance_until(func(): return not b.skills.busy(), 8.0)
	check("羽毛风暴：两个人都被吹到一侧（%.0f / %.0f 像素）" % [absf(pink.global_position.x - p0.x), absf(blue.global_position.x - q0.x)],
		absf(pink.global_position.x - p0.x) > 30.0 or absf(blue.global_position.x - q0.x) > 30.0)
	# 千手乱舞：安全圈里没事，外面挨一大口
	_place_both()
	b.skills.use("dance")
	await _wait(0.4)
	var spots: Array = b.skills.safe_spots.duplicate()
	check("千手乱舞：全屏压暗 + 红色暗角，地上 2~3 个安全圈", spots.size() >= 2 and b.skills._fx.size() == 2)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	pink.set_invulnerable(0.0)
	pink._full_invuln = 0.0
	blue.global_position = spots[0]
	pink.global_position = spots[0] + Vector2(0, 80) if (spots[0] + Vector2(0, 80)).y < b.arena.end.y else spots[0] - Vector2(0, 80)
	if pink != GameState.player:
		pink.set_controller(ScriptedController.new())
	blue.laugh.set_value(0.0)
	pink.laugh.set_value(0.0)
	await _advance_until(func(): return not b.skills.busy(), 6.0)
	check("站在安全圈里的没事（%.0f），外面的挨一大口闷笑（%.0f）" % [blue.laugh.value, pink.laugh.value],
		blue.laugh.value < 5.0 and pink.laugh.value > 20.0)
	_protect()
	if pink != GameState.player:
		pink.set_controller(CompanionController.new())


func _place_both() -> void:
	dir.blue.global_position = dir.marks["blue_fight"]
	dir.pink.global_position = dir.marks["pink_fight"]


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
	check("追逐：主画面和右半屏的小窗并列一样大、镜头不放大，小窗跟着粉色公主；两人从第 3 格出发",
		SideWindow.is_open() and SideWindow.current.half and SideWindow.current.target == run.b and run.a == GameState.player
		and run.a.camera.zoom == Vector2.ONE and run.pa < ChaseRun.START + 0.2 and run.boulder == 0.0)
	run.running = false
	# 无限延伸：一直跑，障碍不断生成、跑道一直滚
	var spawned0 := run.spawned
	var always := true
	for i in 120:
		run.pa = 5.0
		run.pb = 5.0
		run.boulder = 0.0
		run.advance(0.1)
		if run.obstacles.is_empty():
			always = false
	check("无限延伸：跑了 12 秒，障碍一直有（新生成 %d 个），跑道滚了 %.0f 像素" % [run.spawned - spawned0, run.scroll],
		always and run.spawned - spawned0 >= 20 and run.scroll > 1500.0)
	run.running = true
	# 碰障碍退一格
	var o: Dictionary = run.obstacles.filter(func(x): return x["lane"] == "a" and not x["hit"])[0]
	o["y"] = 0.0
	run.xa = o["x"]
	run._inv["a"] = 0.0
	run.pa = 5.0
	run.pb = 5.0
	var before := run.pa
	var hits0: int = run.hits["a"]
	run.advance(0.001)
	check("碰到障碍：后退一格（%.2f → %.2f），显示被挠的反馈" % [before, run.pa], run.pa < before - 0.9 and run.hits["a"] == hits0 + 1)
	# 相差太远 → 失败 → 小剧场 → 重来
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	run.pa = 8.0
	run.pb = 3.5
	run.check_end()
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and run.running, 90.0)
	check("两人相差超过 4 格 → 追逐失败小剧场（%s）→ 从头再来" % [cg_seen], cg_seen.has("theater:f8_chase_fail") and run.pa < ChaseRun.START + 0.2)
	cg_seen.clear()
	run.boulder = 3.2
	run.check_end()
	await _advance_until(func(): return cg_seen.size() > 0 and not CG.is_busy() and run.running, 90.0)
	CG.started.disconnect(on_cg)
	check("巨石追上 → 也是失败", cg_seen.has("theater:f8_chase_fail") and run.boulder < 0.5)
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
