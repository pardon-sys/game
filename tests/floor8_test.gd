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
	await _run_shelter()
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
	# 冲过来的危险（meta velocity）：还没碰到就往旁边闪
	var rush := Node2D.new()
	rush.add_to_group("danger")
	rush.set_meta("radius", 30.0)
	rush.set_meta("velocity", Vector2(240, 0))
	lv.add_child(rush)
	rush.global_position = pink.global_position + Vector2(-90, 0)
	var py0 := pink.global_position.y
	await _wait(0.35)
	check("AI 预判闪避：东西朝她冲过来时提前往旁边闪（偏开 %.0f 像素）" % absf(pink.global_position.y - py0),
		absf(pink.global_position.y - py0) > 10.0)
	rush.queue_free()
	check("AI 组件：通过 BattleAIHooks 读导演提示（第八层是 Floor8AIHooks），行为可开关",
		Duo.hooks is Floor8AIHooks and ai.behaviours == CompanionController.ALL_BEHAVIOURS and ai._hooks() == Duo.hooks)
	pink.status.grab(dir.boss, 6.0, 6)
	await _wait(1.2)
	check("AI 被抓住会自己连按挣脱", not pink.status.is_grabbed())
	await _wait(0.3)
	# AI 吟唱被打断：强制放出当前档位（不落空）
	var evs := []
	var on_ev := func(kind: String, _tier: int): evs.append(kind)
	pink.magic_event.connect(on_ev)
	pink._magic_cd = 0.0
	ai._start_channel()
	await _wait(0.25)
	var was_ch := pink.is_channeling()
	pink.interrupt_channel()
	await get_tree().process_frame
	check("AI 吟唱被打断 → 强制放出当前档位（%s）" % [evs], was_ch and evs.has("burst") and not evs.has("interrupted"))
	ai._held[&"magic"] = false
	ai._channel = 0.0
	# 敌人多：先退到安全距离再吟唱
	await _wait(0.5)
	evs.clear()
	pink._magic_cd = 0.0
	var mobs: Array[Monster] = []
	for off in [Vector2(14, 0), Vector2(-12, 6), Vector2(2, 14)]:
		var s: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
		lv.get_node("Entities").add_child(s)
		s.global_position = pink.global_position + off
		mobs.append(s)
	await get_tree().physics_frame
	for s in mobs:
		s.stun(5.0)
	var center := pink.global_position
	await _wait(0.2)
	var retreating := ai._retreat > 0.0
	await _advance_until(func(): return evs.has("channel"), 2.5)
	check("身边小怪多：AI 先退开（离小怪 %.0f 像素）再吟唱（%s）" % [pink.global_position.distance_to(center), evs],
		retreating and evs.has("channel") and pink.global_position.distance_to(center) > 10.0)
	await _wait(1.4)
	for s in mobs:
		if is_instance_valid(s):
			s.queue_free()
	pink.magic_event.disconnect(on_ev)
	# 玩家吟唱时 AI 有几率一起吟唱
	seed(4)
	var joined := 0
	var blue := dir.blue
	for i in 8:
		blue._magic_cd = 0.0
		pink._magic_cd = 0.0
		ai._retreat = 0.0
		Input.action_press("magic")
		await _wait(0.2)
		if ai._held.get(&"magic", false):
			joined += 1
		Input.action_release("magic")
		ai._held[&"magic"] = false
		ai._channel = 0.0
		await _wait(0.1)
		if pink.is_channeling():
			pink._end_channel()
		await _wait(0.3)
	check("玩家吟唱时 AI 有几率一起吟唱（8 次里一起了 %d 次）" % joined, joined >= 1 and joined <= 7)
	blue._magic_cd = 0.0


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
	var home := b.global_position
	b.skills.use("dash")
	await _wait(0.2)
	var warned := _danger_count() > 0
	var cages0 := get_tree().get_nodes_in_group("f8_dash_cage").size()
	var far := 0.0
	var dazed_hit := false
	var t := 0.0
	while b.skills.busy() and t < 8.0:
		far = maxf(far, b.global_position.distance_to(home))
		if b.is_dazed() and not dazed_hit:
			var hp0 := b.health.hp
			b._attack_invuln = 0.0
			b.apply_hit(HitData.make_attack(dir.blue, 1, 0.0))
			dazed_hit = b.health.hp < hp0
		await get_tree().process_frame
		t += get_process_delta_time()
	check("俯冲撞墙：先亮整条通道的预警（进 danger 组），本体真的冲出去（离原位 %.0f 像素），撞墙后掉落笼（%d 个）" % [far,
		get_tree().get_nodes_in_group("f8_dash_cage").size()],
		warned and cages0 == 0 and far > 60.0 and get_tree().get_nodes_in_group("f8_dash_cage").size() >= 2)
	check("撞墙后晕 %.1f 秒，晕的时候能打本体；之后飞回原位（差 %.0f 像素）" % [b.skills.daze_time(), b.global_position.distance_to(home)],
		dazed_hit and b.global_position.distance_to(home) < 2.0 and not b.dashing)
	# 冲到一半被取消（转阶段 / 战败）：本体直接回原位，不报错
	b.skills.use("dash")
	await _wait(BossSkills.DASH_WARN + 0.15)
	b.skills.cancel()
	await _wait(0.2)
	check("俯冲中途被取消：本体回到原位", b.global_position.distance_to(home) < 2.0 and not b.dashing)
	b.health.set_hp(b.health.max_hp)
	# 被俯冲的本体撞到：闷笑直接加一半
	var victim := dir.pink
	victim.set_invulnerable(0.0)
	victim._full_invuln = 0.0
	victim._attack_invuln = 0.0
	victim.remove_buff("frost_guard")
	victim.laugh.set_value(0.0)
	victim.set_controller(ScriptedController.new())   # 站着不动（AI 会走开）
	var lane := Rect2(b.arena.position.x, victim.global_position.y - 16.0, b.arena.size.x, 30.0)
	var raised0 := b.raised
	b.begin_dash()
	await b.skills._dash_run(lane, true, b.skills._serial)
	var got := victim.laugh.value
	await b.return_home(home, raised0, true)
	victim.set_controller(CompanionController.new())
	_protect()
	check("被俯冲的本体撞到：闷笑直接加最大值的一半（%.0f / %.0f）" % [got, victim.laugh.max_value],
		got >= victim.laugh.max_value * BossSkills.DASH_LAUGH - 2.0)
	victim.laugh.set_value(0.0)
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
	# 冰晶守护：闷笑自然消减更快、不用等被挠后的延迟
	var lp := dir.pink.laugh
	lp.set_value(60.0)
	lp.notify_attacked()
	dir.pink.add_buff("frost_guard", 2.0)
	await _wait(1.0)
	var fast := 60.0 - lp.value
	dir.pink.remove_buff("frost_guard")
	lp.set_value(60.0)
	lp.notify_attacked()
	await _wait(1.0)
	var slow := 60.0 - lp.value
	check("冰晶守护期间闷笑自然消减更快（1 秒降 %.1f，没有守护降 %.1f）" % [fast, slow], fast > slow + 3.0)
	lp.set_value(0.0)
	# 冰晶守护给范围内的友军（包括另一个可操作的公主）
	dir.pink.remove_buff("frost_guard")
	dir.pink.global_position = dir.blue.global_position + Vector2(20, 0)
	IceBarrier.cast_with(dir.blue, 60.0, 2.0)
	check("冰晶结界：范围内的另一个公主也得到冰晶守护（闷笑不涨）", dir.pink.has_buff("frost_guard") and dir.blue.has_buff("frost_guard"))
	b._frozen_left = 0.0
	b.sprite.modulate = Color.WHITE
	dir.pink.remove_buff("frost_guard")
	dir.blue.remove_buff("frost_guard")
	# 战败剧场：两个公主的笑声都有；爆发后另一个公主的立绘是她自己的魔力疲倦爆发立绘
	CG.play_theater("f8_defeat_1_2")
	await _wait(1.2)
	var both_laugh: bool = CG.voice.playing and CG.voice2.playing and CG.voice.stream != CG.voice2.stream
	CG.skip()
	await _advance_until(func(): return not CG.is_busy(), 60.0)
	check("战败剧场：两个公主的笑声一起放（各用自己的）", both_laugh)
	var d12: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_08/f8_defeat_1_2.json"))
	var after_boom := false
	var burst_emo := true
	var pink_laugh := true
	for st in d12["steps"]:
		if st.get("act", "") == "burst" and st.has("portrait"):
			after_boom = true
		if after_boom and st.get("act", "") == "burst" and st.has("emotion") and st["emotion"] != "fatigue_burst":
			burst_emo = false
	for id in ["f8_defeat_1_1", "f8_defeat_2_1", "f8_defeat_3_2", "f8_defeat_3_4", "f8_chase_fail"]:
		var dd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_08/%s.json" % id))
		for st in dd["steps"]:
			if str(st.get("speaker", "")) == "公主" and not str(st["text"]).contains("哈"):
				pink_laugh = false
	Characters.scope("blue")
	var blue_burst: Texture2D = CG.portrait_texture("fatigue_burst")
	Characters.unscope()
	Characters.scope("pink")
	var pink_burst: Texture2D = CG.portrait_texture("fatigue_burst")
	Characters.unscope()
	check("爆发后另一个公主的立绘 = 她组合演出里的魔力疲倦爆发立绘；粉色公主的台词都边笑边说",
		burst_emo and after_boom and blue_burst != pink_burst and Dialogue.npc_texture("blue_princess", "fatigue_burst") == blue_burst
		and Dialogue.npc_texture("pink_princess", "fatigue_burst") == pink_burst and pink_laugh)
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
	dir.blue.sensitivity.streak["thigh"] = 6.0
	dir.pink.sensitivity.streak["sole"] = 4.0
	_hit_to_floor()
	await _advance_until(func(): return dir.phase == 2 and not dir.busy and not Cutscene.is_playing(), 60.0)
	Cutscene.started.disconnect(on_cut)
	check("转阶段：两个人积累的敏感度清零", dir.blue.sensitivity.streak_of("thigh") == 0.0 and dir.pink.sensitivity.streak_of("sole") == 0.0)
	var b := dir.boss
	check("打到 70%% → 过场（%s）→ 阶段二：Boss 缩到天花板打不到，两块压力板亮起" % [seen],
		seen.has("f8_phase2") and dir.phase == 2 and b.raised and not b.attackable and dir.plates_lit and dir.plates[0].visible)
	check("AI 会去站玩家没站的那块板", dir.plate_for(dir.pink) is Vector2)
	# 变化地形：强制位移 + 束缚类陷阱（阶段二、三共用一个池子），收回时放开抓着的人
	var placed := []
	var ar := dir.arena_cells
	var cell := ar.position + Vector2i(4, 6)
	for kind in TerrainShifter.DISPLACE + TerrainShifter.RESTRAIN:
		var node: Node = dir.place_trap(kind, cell, 0.0, {})
		if node:
			placed.append(kind)
		cell.x += 3
		if cell.x > ar.end.x - 5:
			cell = Vector2i(ar.position.x + 4, cell.y + 4)
	check("变化地形能放出全部强制位移 / 束缚陷阱（%d / %d：%s）" % [placed.size(), TerrainShifter.DISPLACE.size() + TerrainShifter.RESTRAIN.size(), placed],
		placed.size() == TerrainShifter.DISPLACE.size() + TerrainShifter.RESTRAIN.size())
	var holder: Node = dir.shifter.fields.filter(func(f): return f is RestraintTrap)[0]
	dir.pink.status.grab(holder, 10.0, 99)
	dir.shifter.clear()
	check("收回地形陷阱时，被它抓着的人放开", not dir.pink.status.is_grabbed())
	var seen_kinds := {}
	# 玩家在场地中间往一侧走、搭档在另一边（她前面的格子不在压力板 / 人的保护范围里）
	var mid := dir._cell_pos(ar.position + ar.size / 2)
	var lead := GameState.player
	var other := Duo.partner_of(lead)
	var lead_pos := lead.global_position
	var other_pos := other.global_position
	lead.global_position = mid + Vector2(-40, 0)
	other.global_position = mid + Vector2(0, 60)
	for i in 40:
		lead.velocity = Vector2(80, 0) if i % 2 == 0 else Vector2(0, -80)
		dir.grow_terrain()
		for f in dir.shifter.fields:
			if is_instance_valid(f):
				seen_kinds[f.scene_file_path.get_file().get_basename()] = true
		dir.shifter.clear()
	check("持续地形会长出强制位移 / 束缚类陷阱（%s），两个人仍走得到压力板" % [seen_kinds.keys()],
		seen_kinds.keys().any(func(k): return k in ["bounce_pad", "soap_floor", "feather_fan", "chute", "tickle_vortex", "tickle_conveyor"])
		and seen_kinds.keys().any(func(k): return k in ["snare", "legloop", "binding", "cuffs", "stocks", "tickle_vine"]) and dir._still_reachable())
	lead.velocity = Vector2.ZERO
	lead.global_position = lead_pos
	other.global_position = other_pos
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
	# 冰晶结界对阶段三的 Boss：冻不住，出招变慢
	IceBarrier.cast_with(blue, 300.0, 2.0)
	check("阶段三的 Boss 被冰晶命中：不冻住，改成迟缓（出招频率减半）", b.is_slowed() and not b.is_frozen())
	b._slow_left = 0.0
	b.sprite.modulate = Color.WHITE
	blue.remove_buff("frost_guard")
	pink.remove_buff("frost_guard")
	# 搭档正在献祭时玩家操控的人倒下：搭档闷笑大降、说一句，挣开后由玩家操控
	# （先收掉持续地形、暂停生长：束缚陷阱可能在她走进光圈前把她抓住）
	dir.shifter.clear()
	dir._terrain_cd = 999.0
	if pink.status.is_grabbed():
		pink.status.release(false)
	await _wait(0.3)
	dir._circle_cd = 0.0
	if GameState.player != blue:
		GameState.switch_control(blue)
		pink.set_controller(CompanionController.new())
	pink.global_position = dir.circle.global_position
	await _wait(0.6)
	var sac2: bool = dir.sacrifice.get("victim") == pink
	if sac2:
		pink.laugh.set_value(pink.laugh.max_value - 2.0)
	var lv0 := pink.laugh.value
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	blue.health.damage(99)
	await get_tree().process_frame
	check("搭档正在献祭时操控的人倒下：搭档闷笑大降（%.0f → %.0f），先不切换" % [lv0, pink.laugh.value],
		sac2 and Downed.is_downed(blue) and pink.laugh.value < lv0 * 0.7 and not pink.laugh.is_helpless() and dir.sacrifice.get("victim") == pink)
	for i in 40:
		if dir.sacrifice.is_empty():
			break
		(dir.sacrifice["struggle"] as SacrificeStruggle).press()
	await _wait(0.3)
	check("挣脱献祭后由玩家操控她", dir.sacrifice.is_empty() and GameState.player == pink)
	(blue.get_node("Downed") as Downed)._revive()
	dir._terrain_cd = 3.0
	await _wait(0.2)
	_protect()
	check("战败小剧场顺序：阶段三 1→2→3→4，之后一直是 4（叠在一起）；阶段一 / 二 1→2→1",
		Floor8Director.defeat_theater(3, 2) == "f8_defeat_3_2" and Floor8Director.defeat_theater(3, 3) == "f8_defeat_3_3"
		and Floor8Director.defeat_theater(3, 4) == "f8_defeat_3_4" and Floor8Director.defeat_theater(3, 5) == "f8_defeat_3_4"
		and Floor8Director.defeat_theater(3, 9) == "f8_defeat_3_4" and Floor8Director.defeat_theater(1, 3) == "f8_defeat_1_1")
	var bursts_ok := true
	var burst_bad := []
	for id in ["f8_defeat_1_1", "f8_defeat_1_2", "f8_defeat_2_1", "f8_defeat_2_2", "f8_defeat_3_1", "f8_defeat_3_2", "f8_defeat_3_3", "f8_defeat_3_4", "f8_chase_fail"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_08/%s.json" % id))
		var booms: int = d["steps"].filter(func(s): return s.get("act", "") == "burst" and s.has("portrait")).size()
		var praise := false
		for s in d["steps"]:
			if s.get("act", "") == "burst" and str(s.get("speaker", "")) == "千手痒痒魔" and (str(s["text"]).contains("可爱") or str(s["text"]).contains("好")):
				praise = true
		if booms != (2 if id == "f8_defeat_3_4" else 1) or not praise:
			bursts_ok = false
			burst_bad.append(id)
	check("每段战败 / 追逐失败剧场结尾都有两人魔力疲倦爆发、千手夸她（叠在一起那段爆发两次）（%s）" % [burst_bad], bursts_ok)
	# 蓝色公主操控时战败大图正常显示
	var shows := true
	for who in ["blue", "pink"]:
		Characters.scope(who)
		var tex := CG.portrait_texture("boss8_duo_1")
		shows = shows and CG.has_portrait_file("boss8_duo_1") and tex != null and tex.get_width() > 300
		Characters.unscope()
	check("蓝色 / 粉色公主操控时，战败剧场的大图都能正常显示", shows)
	# 阶段三召唤：手臂从上面伸下来，小怪落在场地中线附近左右（不在墙角）
	b.clear_summons()
	b.fighting = true
	b.summon()
	await get_tree().process_frame
	var arms := get_tree().get_nodes_in_group("f8_summon_arm").size()
	await _wait(0.8)
	var center := dir._cell_pos(dir.arena_cells.position + dir.arena_cells.size / 2)
	var mobs := get_tree().get_nodes_in_group("f8_summon").filter(func(n): return n is Monster)
	var near_mid := mobs.all(func(m): return absf(m.global_position.x - center.x) <= 130.0 and absf(m.global_position.y - center.y) <= 56.0)
	check("阶段三召唤：手臂伸下来放下小怪（%d 只手臂），小怪在中线附近左右（%d 只）" % [arms, mobs.size()],
		arms >= 1 and mobs.size() >= 1 and near_mid)
	var homes_mid := true
	for m in mobs:
		if (m as Monster)._home.distance_to(b.arena.get_center()) >= 1.0 or (m as Monster).wander_radius < 60.0:
			homes_mid = false
	check("阶段三召唤的小怪没目标时在场地中间晃（家在场地中心），撞墙只晕 %.1f 秒" % b.skills.daze_time(),
		homes_mid and is_equal_approx(b.skills.daze_time(), 0.5))
	b.clear_summons()
	b.fighting = false
	var th_ok := true
	var th_bad := []
	for id in ["f8_defeat_1_1", "f8_defeat_1_2", "f8_defeat_2_1", "f8_defeat_2_2", "f8_defeat_3_1", "f8_defeat_3_2", "f8_defeat_3_3", "f8_defeat_3_4",
			"f8_chase_fail"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_08/%s.json" % id))
		var steps: Array = d.get("steps", [])
		var acts := steps.filter(func(s): return s.has("portrait")).size()
		var lines := steps.filter(func(s): return s.has("text")).size()
		var emo := steps.filter(func(s): return s.has("emotion")).size()
		if acts < 4 or lines < 36 or emo < 10:
			th_ok = false
			th_bad.append("%s 幕 %d 句 %d" % [id, acts, lines])
	check("战败 / 追逐失败小剧场都 ≥ 4 幕、≥ 36 句，台词带另一个人的立绘状态（%s）" % [th_bad], th_ok)
	var cg_of := func(id: String) -> Array:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_08/%s.json" % id))
		var out := []
		for s in d["steps"]:
			if str(s.get("portrait", "")).begins_with("boss8_") and not out.has(s["portrait"]):
				out.append(s["portrait"])
		return out
	check("BOSS_CG 按阶段放进小剧场：阶段二 boss8_p2、阶段三 双人 1→3 / 抵抗→弱点特攻 / 群怪、追逐失败 巨石",
		cg_of.call("f8_defeat_2_1") == ["boss8_p2"] and cg_of.call("f8_defeat_3_1") == ["boss8_duo_1", "boss8_duo_2", "boss8_duo_3"]
		and cg_of.call("f8_defeat_3_2") == ["boss8_resist_1", "boss8_resist_2", "boss8_weak_1", "boss8_weak_2"]
		and cg_of.call("f8_defeat_3_3") == ["boss8_mob"] and cg_of.call("f8_chase_fail") == ["boss8_chase"]
		and cg_of.call("f8_defeat_1_1").is_empty() and cg_of.call("f8_defeat_3_4").is_empty() and CG.has_portrait_file("boss8_duo_1"))
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
	check("追逐：两个人都朝下跑、画在巨石上面", run.a.dir_name() == "down" and run.b.dir_name() == "down"
		and run.a.z_index > (run._boulders["a"] as Sprite2D).z_index and run.b.z_index > (run._boulders["b"] as Sprite2D).z_index)
	# 按 C 切换：主画面、小窗、HUD 跟着换人
	run.switch_lane()
	check("按 C 切换：玩家操控另一个，主画面跟着她、小窗跟着 AI 控制的那个",
		GameState.player == run.b and run.ai_lane() == "a" and SideWindow.current.target == run.a and run.b.camera.is_current())
	run.switch_lane()
	check("再按 C 切回来", GameState.player == run.a and SideWindow.current.target == run.b and run.a.camera.is_current())
	run.running = false
	# AI 躲障碍：正前方有障碍时往旁边让
	for x in run.obstacles:
		x["hit"] = true
	var o_ai := {"lane": "b", "y": 40.0, "x": 0.0, "base_x": 0.0, "node": null, "kind": "slime", "hit": false, "phase": 0.0}
	run.obstacles.append(o_ai)
	run.xb = 0.0
	var tx := run.ai_pick_x("b", 0.0)
	run.obstacles.erase(o_ai)
	check("AI 看到正前方的障碍会往旁边让（目标 x = %.0f）" % tx, absf(tx) >= 16.0)
	# 进度越往后，人在画面里越往下；巨石往下移得更多，但不盖住人
	run.pa = ChaseRun.CELLS - 0.5
	run.pb = ChaseRun.CELLS - 0.5
	run.boulder = ChaseRun.CELLS - 1.0
	for i in 60:
		run._update_drift(0.1)
	run._place()
	var s_a: Sprite2D = run._boulders["a"]
	var bottom := s_a.global_position.y + ChaseRun.BOULDER_TEX.get_height() * s_a.scale.y / 2.0
	check("进度靠后：人往下移了 %.0f 像素（巨石最多 %.0f），巨石底边在人脚上方 %.0f 像素" % [run._drift["a"], ChaseRun.BOULDER_DRIFT,
		run.a.global_position.y - bottom],
		run._drift["a"] > 20.0 and run._drift["a"] < ChaseRun.BOULDER_DRIFT and bottom <= run.a.global_position.y - ChaseRun.BOULDER_CLEAR + 0.5)
	run.pa = ChaseRun.START
	run.pb = ChaseRun.START
	run.boulder = 0.0
	# 离太远的提示：≥ 2.5 格出现，< 1.5 格消失
	run.pa = 6.0
	run.pb = 3.4
	run._update_warning(0.01)
	var warn_on := run.warning
	run.pb = 4.2
	run._update_warning(0.01)
	var still := run.warning
	run.pb = 4.6
	run._update_warning(0.01)
	check("两人相差 ≥ 2.5 格出现「离得太远了」提示，回到 1.5 格以内才消失", warn_on and still and not run.warning)
	run.pa = ChaseRun.START
	run.pb = ChaseRun.START
	var fails0: int = int(GameState.vars.get("f8_chase_fail", 0))
	GameState.vars["f8_chase_fail"] = 9
	var t9 := run.boulder_time()
	GameState.vars["f8_chase_fail"] = 10
	var t10 := run.boulder_time()
	GameState.vars["f8_chase_fail"] = 20
	var t20 := run.boulder_time()
	GameState.vars["f8_chase_fail"] = fails0
	check("追逐失败 10 次以上滚石变慢（%.1f → %.1f → %.1f 秒一格）" % [t9, t10, t20], t10 > t9 and t20 > t10)
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
	o["y"] = run._drift["a"]
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


# ------------------------------------------------------------------ 小房间（追逐逃出来后过夜）
func _talk_through(trigger: Callable) -> Array:
	var said := []
	var on_line := func(_i: int, line: Dictionary): said.append(str(line.get("text", "")))
	if Dialogue.has_signal("line_shown"):
		Dialogue.line_shown.connect(on_line)
	trigger.call()
	await get_tree().process_frame
	var g := 0
	while (Dialogue.is_active() or Dialogue.runner.is_running()) and g < 400:
		if Dialogue.is_active():
			said.append(Dialogue.text_label.text)
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		g += 1
	if Dialogue.has_signal("line_shown"):
		Dialogue.line_shown.disconnect(on_line)
	return said


func _shelter_ready() -> bool:
	return _level_id() == "floor_08_shelter" and GameState.has_flag("intro_done_f8_shelter_intro") and not Cutscene.is_playing() \
		and not Dialogue.is_active()


func _run_shelter() -> void:
	print("-- 小房间")
	await _advance_until(_shelter_ready, 60.0)
	var p := GameState.player
	check("逃出来 → 第八层的小房间：开场过场播完，配乐 night_room，操控粉色公主",
		_level_id() == "floor_08_shelter" and not GameState.has_flag("blue_is_hero") and p is Princess and not (p is BluePrincess)
		and Audio.music_id == "night_room")
	var ev := InputEventAction.new()
	ev.action = "switch_character"
	ev.pressed = true
	main._unhandled_input(ev)
	await get_tree().process_frame
	check("小房间里不能切换操控", GameState.player == p and main.level.get("no_switch") == true and not Duo.active)
	var nodes: Array = main.level.find_children("*", "", true, false)
	var saves: Array = nodes.filter(func(n): return n.get("place") != null and str(n.get("place")).contains("小房间"))
	var door: Array = nodes.filter(func(n): return n.get("target_level") != null)
	check("有存档点；门锁着（外面危险）", saves.size() == 1 and door.size() == 1 and door[0].get("locked") == true)
	var props: Array = nodes.filter(func(n): return n.has_method("on_interact") and str(n.get("action")).begins_with("talk:floor_08/shelter_objects"))
	var all_talk := true
	var blue_cut_in := false
	for pr in props:
		var said := await _talk_through(func(): pr.on_interact(p))
		if said.is_empty():
			all_talk = false
		if str(pr.get("kind")) == "crayon_drawing":
			blue_cut_in = said.any(func(t): return str(t).contains("别看了"))
	check("房间里的东西都能调查（%d 件），调查蜡笔画时蓝色公主插话" % props.size(), props.size() >= 8 and all_talk and blue_cut_in)
	check("床：现在只说一句、不睡觉", GameState.has_flag("f8s_seen_bed") and not Sleep.sleeping and Sleep.day() == 1)
	var blue: Array = nodes.filter(func(n): return n is BluePrincess)
	var topics := []
	for i in 6:
		var said := await _talk_through(func(): blue[0].talk(p))
		topics.append(said[0] if not said.is_empty() else "")
		await _wait(0.2)   # 她的 talk() 结束、talking 复位
	check("和窗边的蓝色公主说话：先聊调查过的东西（她岔开），再按顺序聊小话题，最后重复一句（%s）" % [topics.slice(0, 3)],
		blue.size() == 1 and GameState.has_flag("f8s_t_drawing") and int(GameState.vars.get("f8s_talk", 0)) >= 1
		and topics.any(func(t): return str(t).contains("蜡笔画")))


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
