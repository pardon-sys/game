extends Node
## 第八层第五轮：走出夜迷宫 → 千手过场 → 回小屋 → 粉色公主操控、蓝色公主跟着 → 新的第七层。
## 两种情况：迷宫里身上没到过 4 只手 / 有过 4 只手（千手痒痒裤：关键道具 + 永久状态；闷笑最低 20、移动 ×0.9、魔法 10% 失败并大笑）。
## 还有：粉色公主睡着时闭着眼（小人用闭眼图，立绘照旧）。
## 用法：Godot --headless --path . res://tests/f8_return_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var _watch_t := 0.0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8m_dark_first", "cutscene_seen_f8_maze_intro", "intro_done_f8_shelter_intro", "intro_done_f8_maze_intro"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_sleeping_eyes()
	await _run_ending(false)
	await _run_ending(true)
	await _run_pants_effects()
	await _run_floor7()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _process(delta: float) -> void:
	_watch_t += delta
	if _watch_t >= 5.0:
		_watch_t = 0.0
		print("    · 关卡 %s　过场 %s 第 %d 步　小剧场 %s　对话 %s" % [_level_id(), Cutscene.current if Cutscene.is_playing() else "-",
			Cutscene.step_index, CG.current if CG.is_busy() else "-", Dialogue.is_active()])


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


# ------------------------------------------------------------------ 睡着闭眼
func _run_sleeping_eyes() -> void:
	print("-- 粉色公主睡着闭眼")
	await main.change_level(Floors.scene("floor_08_shelter"))
	await _advance_until(func(): return not Cutscene.is_playing() and not Dialogue.is_active(), 20.0)
	var p := GameState.player
	var cs := load("res://scripts/cutscene/cutscene_player.gd")
	Cutscene._lie(p, {"at": [3, 4.25], "sleep": true})
	await _wait(0.2)
	var still := p.sprite.texture == p.sleep_texture() and p.sprite.hframes == 1
	GameState.emote("shy", 0.0, true)
	Dialogue.start_lines([{"speaker": "公主", "text": "……唔嘿嘿……", "emotion": "shy"}], "test")
	await _wait(0.3)
	# 立绘照旧（不换闭眼立绘）
	var portrait_closed: bool = Dialogue.portrait.texture == Dialogue.portrait_for("shy")
	var still_after := p.sprite.texture == p.sleep_texture()
	_finish()
	Cutscene._lie(p, {"on": false})
	await _wait(0.2)
	check("睡着：小人一直是闭眼图（%s → 说梦话换表情后 %s），立绘照旧（%s）；醒来换回正常图集（%s）" % [still, still_after, portrait_closed,
			p.sprite.texture != p.sleep_texture()],
		cs != null and still and still_after and portrait_closed and p.sprite.texture != p.sleep_texture() and not p.sleeping)


# ------------------------------------------------------------------ 出口 → 千手过场 → 回小屋
func _run_ending(pants: bool) -> void:
	print("-- 出口 → 千手过场 → 回小屋（%s）" % ("身上有过 4 只手" if pants else "没到 4 只手"))
	for f in ["f8_maze_done", "f8_returned", "blue_tickle_pants", "f8m_pants", "f8_maze_finale_seen"]:
		GameState.set_flag(f, false)
	GameState.set_flag("f8m_pants", pants)
	if GameState.inventory.has("thousand_pants"):
		GameState.inventory.remove("thousand_pants", 1)
	GameState.set_flag("blue_is_hero")
	await main.change_level(Floors.scene("floor_08_maze_3"))
	await _advance_until(func(): return MazeDirector.instance != null and MazeDirector.instance.blue != null and not Cutscene.is_playing(), 20.0)
	var dir := MazeDirector.instance
	var blue := dir.blue
	check("第三段出口有一盏微光（ExitGlow %d 个）" % get_tree().get_nodes_in_group("exit_glow").size(),
		get_tree().get_nodes_in_group("exit_glow").size() >= 1)
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	var hands_max := 0
	var bursts := 0
	var cg_keys := {}
	blue.global_position = dir._exit_at
	var t := 0.0
	while t < 150.0 and not (_level_id() == "floor_08_shelter" and GameState.has_flag("f8_returned") and not Cutscene.is_playing()):
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		if Cutscene.is_playing() and Cutscene.current.begins_with("f8_maze_finale") and is_instance_valid(GameState.player):
			var bh := BodyHands.of(GameState.player)
			if bh:
				hands_max = maxi(hands_max, bh.total())
			var st: Dictionary = Cutscene._steps[Cutscene.step_index] if Cutscene.step_index >= 0 and Cutscene.step_index < Cutscene._steps.size() else {}
			for a in st.get("actions", []):
				if str(a.get("do", "")) == "burst":
					bursts = maxi(bursts, _count_bursts_seen(Cutscene.step_index))
				if str(a.get("do", "")) == "cg" and str(a.get("key", "")) != "":
					cg_keys[str(a["key"])] = true
		await get_tree().process_frame
		t += get_process_delta_time()
	Cutscene.started.disconnect(on_cut)
	var fin := "f8_maze_finale_pants" if pants else "f8_maze_finale"
	var ret := "f8_shelter_return_pants" if pants else "f8_shelter_return"
	check("出口 → %s（身上的小手最多 %d 只、魔力爆发 %d 次、大立绘 %s）→ 换到小屋 → %s（%s）" % [fin, hands_max, bursts, cg_keys.keys(), ret, seen],
		seen.has(fin) and seen.has(ret) and hands_max >= 12 and bursts >= 4 and cg_keys.size() >= 3 and _level_id() == "floor_08_shelter")
	var p := GameState.player
	var b := _blue_in_level()
	var cc := b.controller as CompanionController if b else null
	check("过场后：操控粉色公主（%s），蓝色公主跟着（%s），不能切换（no_switch %s），门通向新的第七层（%s）" % [
			p.character_id if p else "-", cc.behaviours if cc else [], main.level.get("no_switch"), _shelter_exit_target()],
		p is PlayableCharacter and p.character_id == "pink" and not p.sleeping and cc != null and "follow" in cc.behaviours
		and bool(main.level.get("no_switch")) and _shelter_exit_target().contains("floor_07_return"))
	var has_item := GameState.inventory.has("thousand_pants")
	var has_buff := b != null and b.has_buff("thousand_pants")
	if pants:
		check("身上有过 4 只手 → 千手痒痒裤：关键道具（%s）、蓝色公主的永久状态（%s）、剧情标记（%s）" % [has_item, has_buff, GameState.has_flag("blue_tickle_pants")],
			has_item and has_buff and GameState.has_flag("blue_tickle_pants") and (b.buffs["thousand_pants"] as Buff).is_permanent())
	else:
		check("没到 4 只手 → 没有痒痒裤（道具 %s、状态 %s）" % [has_item, has_buff], not has_item and not has_buff and not GameState.has_flag("blue_tickle_pants"))
	# 跟随：粉色公主走开，蓝色公主跟上来
	if b and p:
		var start := b.global_position.distance_to(p.global_position)
		p.global_position += Vector2(48, 0)
		await _wait(2.0)
		check("蓝色公主跟着走（距离 %.0f → %.0f）" % [start + 48.0, b.global_position.distance_to(p.global_position)],
			b.global_position.distance_to(p.global_position) < 50.0)


func _count_bursts_seen(upto: int) -> int:
	var n := 0
	for i in mini(upto + 1, Cutscene._steps.size()):
		for a in Cutscene._steps[i].get("actions", []):
			if str(a.get("do", "")) == "burst":
				n += 1
	return n


func _blue_in_level() -> BluePrincess:
	for n in main.level.find_children("*", "BluePrincess", true, false):
		if n != GameState.player:
			return n
	return null


func _shelter_exit_target() -> String:
	for n in main.level.find_children("*", "Area2D", true, false):
		if n.get("target_level") != null and str(n.get("target_level")) != "":
			return str(n.get("target_level")) + (" 锁着" if n.is_locked_now() else " 开着")
	return ""


# ------------------------------------------------------------------ 痒痒裤的效果
func _run_pants_effects() -> void:
	print("-- 千手痒痒裤的效果")
	var b := _blue_in_level()
	if b == null:
		check("找得到蓝色公主", false)
		return
	# 闷笑最低 20
	# 闷笑最低 20（痒痒裤每 6 秒左右还会轻轻挠一下，所以看这段时间里的最低值）
	b.laugh.set_value(60.0)
	b.laugh._since_attacked = 99.0
	var lowest := 999.0
	var tt := 0.0
	while tt < 7.0:
		await get_tree().process_frame
		tt += get_process_delta_time()
		if tt > 4.0:
			lowest = minf(lowest, b.laugh.value)
	b.laugh.clear()
	check("闷笑值消减停在 20（最低 %.1f），清空也是 20（%.1f）" % [lowest, b.laugh.value], absf(lowest - 20.0) < 0.6 and absf(b.laugh.value - 20.0) < 0.6)
	check("移动速度 ×0.9（stat_mul speed = %.2f）" % b.stat_mul("speed"), absf(b.stat_mul("speed") - 0.9) < 0.001)
	# 发作：四种手法各一次，每种都有对应的台词、挠对应的部位
	var ways_ok := []
	for way in ["knead", "climb", "pinch", "scrape"]:
		b.laugh.set_value(20.0)
		b.set_invulnerable(0.0)
		var before := b.laugh.value
		b._pants_bubble_t = 0.0
		b.pants_flare(way)
		if b.laugh.value > before and MazeLines.pick("pants_" + way) != "":
			ways_ok.append(way)
	check("痒痒裤发作：揉腿根 / 沿内侧往上爬 / 轮流捏屁股 / 交界处轻刮都有对应的台词并挠到（%s）" % [ways_ok], ways_ok.size() == 4)
	# 魔法 10% 失败：固定随机种子放 300 次
	seed(20261010)
	var events := {"fail": 0}
	var laughed := 0
	var cracked := 0
	b.magic_event.connect(func(e: String, _t: int): if e == "fail": events["fail"] += 1)
	for i in 300:
		# 上一次成功放出的冰晶结界（frost_guard）期间闷笑不涨：每次都先去掉
		b.remove_buff("frost_guard")
		var before := b.laugh.value
		b.state = PlayableCharacter.State.CHANNEL
		b._channel_tier = 1
		b.release_magic()
		if b.laugh.value > before:
			laughed += 1
		if Audio.crack_playing():
			cracked += 1
		b.state = PlayableCharacter.State.IDLE
		b.laugh.set_value(20.0)
		b.reset_magic_cooldown()
	var fails: int = events["fail"]
	check("释放魔法约 10%% 失败（%d / 300），失败时大笑（闷笑上涨 %d 次、憋不住的笑声 %d 次）" % [fails, laughed, cracked],
		fails >= 15 and fails <= 50 and laughed >= fails and cracked > 0)
	# 小人的大腿上有一圈紫色
	var bh := BodyHands.of(b)
	check("痒痒裤不画在小人身上（身上没有手时 BodyHands 不显示：%s）" % (bh.visible if bh else false), bh == null or not bh.visible)
	# 背包状态页：可以切到蓝色公主，列出被动状态
	var bp := get_tree().root.find_child("Backpack", true, false)
	var ok_page := false
	var shown := ""
	if bp and bp.has_method("status_members"):
		var members: Array = bp.status_members()
		ok_page = members.size() >= 2 and members.has(b)
		bp.open()
		bp.set_page(bp.PAGE_STATUS)
		bp.status_index = members.find(b)
		bp._refresh()
		for c in bp.status_page.box.get_children():
			var l: Label = c if c is Label else (c.get_child(1) if c.get_child_count() > 1 and c.get_child(1) is Label else null)
			if l:
				shown += l.text + "\n"
		bp.close()
	# 部位敏感度按她自己的部位表：脚心 ×0.95（粉色公主是 ×1.20）
	check("背包状态页能切换看蓝色公主（同行 %s），切过去显示的是她自己的状态（痒痒裤 %s、脚心 ×0.95 %s）" % [ok_page,
			shown.contains("千手痒痒裤"), shown.contains("脚心 ×0.95")],
		ok_page and shown.contains("蓝色的公主") and shown.contains("千手痒痒裤") and shown.contains("脚心 ×0.95"))


# ------------------------------------------------------------------ 新的第七层
func _run_floor7() -> void:
	print("-- 小屋的门 → 新的第七层")
	var exit: Node = null
	for n in main.level.find_children("*", "Area2D", true, false):
		if n.get("target_level") != null and str(n.get("target_level")).contains("floor_07_return"):
			exit = n
	if exit == null:
		check("小屋的门通向 floor_07_return", false)
		return
	GameState.player.global_position = (exit as Node2D).global_position
	await _advance_until(func(): return (_level_id() == "floor_07_return" and GameState.has_flag("cutscene_seen_f7r_arrive")
		and not Cutscene.is_playing() and not Dialogue.is_active()), 30.0)
	var p := GameState.player
	var b := _blue_in_level()
	check("到了新的第七层（%s），粉色公主操控（%s），蓝色公主跟着（%s），痒痒裤还在（%s），不能切换（%s）" % [_level_id(),
			p.character_id if p else "-", b != null and b.follow, b != null and b.has_buff("thousand_pants"), main.level.get("no_switch")],
		_level_id() == "floor_07_return" and p.character_id == "pink" and b != null and b.follow and b.has_buff("thousand_pants")
		and bool(main.level.get("no_switch")) and GameState.has_flag("cutscene_seen_f7r_arrive"))


# ------------------------------------------------------------------ 工具
func _advance_until(cond: Callable, max_time: float) -> float:
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


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
