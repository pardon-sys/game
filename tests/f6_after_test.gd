extends Node
## 七日赎罪（战后的小镇）：
##   攻防战胜利的过场最后去战后的小镇；第 1 天：早上开场（千手痒痒裤当众发作）→ 自动到下午 → 广场宣判（发赎罪簿）
##   → 镇民按日程摆位置（开场时只有队长和守城队员、宣判时围在台下、宣判完散开）→ 回小屋 = 天黑 → 被裤子的手挠醒
##   → 三处手印（楼梯那处要最后看）→ 楼上梦游的结尾 → 回床上睡 → 第 2 天早上。
##   第 2 天早上：广场足枷示众（四轮忍笑选择，笑出声罚工时，3 次以上去训练营转受罚转盘 → 刑具小剧场 → 受罚记录）；按应对分支。
##   赎罪簿：100 工时、加减和记录、受罚记录、背包里的「赎罪簿」页；时钟：日程的逐层覆盖、夜里宵禁锁门；旧存档从战时小镇送过来。
## 用法：Godot --headless --path . res://tests/f6_after_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0
var seen_cuts: Array[String] = []


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f6w_arrived", "siege_won"]:
		GameState.set_flag(f)
	# 第一次碰到各种来源的介绍台词（会打断）先记成看过
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	Characters.scope("blue")
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	Characters.scope("pink")
	Cutscene.started.connect(func(id: String): seen_cuts.append(id))
	if "--festival-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_festival.gd").run(self)
		main.queue_free()
		for i in 3: await get_tree().process_frame
		# 仅本专项退出前排空音频线程，避免脚步声仍播放时立即终止引擎。
		for sound in Audio.get_children():
			if sound is AudioStreamPlayer: sound.stop()
		await _wait(0.3)
		print("祭典专项：%s（%d项失败）" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--workshop-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_workshop.gd").run(self)
		main.queue_free()
		for i in 3: await get_tree().process_frame
		print("新任务专项：%d项失败" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--shearing-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_shearing.gd").run(self)
		print("剪毛专项：%d项失败" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--town-workshop-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_gate_chain.gd").run(self)
		await preload("res://tests/helpers/f6_shearing.gd").run(self)
		await preload("res://tests/helpers/f6_workshop.gd").run(self)
		print("\n==== 四项劳动委托%s (%d 项失败) ====" % ["全部通过" if failures==0 else "有失败",failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--work-errands-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_gate_chain.gd").run(self)
		await preload("res://tests/helpers/f6_shearing.gd").run(self)
		print("\n==== 劳动委托%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--gate-chain-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_gate_chain.gd").run(self)
		print("\n==== 城门穿链%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--penance-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_penance.gd").run(self)
		print("\n==== 反省篇第一~四章%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--knight-finale-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_knight_finale.gd").run(self)
		print("\n==== 骑士篇后半%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--knight-quests-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_knight_quests.gd").run(self)
		print("\n==== 骑士篇支线%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--knight-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_knight.gd").run(self)
		print("\n==== 骑士篇%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--festival-night-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_festival_night.gd").run(self)
		print("\n==== 庆功宴%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--totem-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_totem.gd").run(self)
		print("\n==== 图腾共鸣%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--daily-polish-only" in OS.get_cmdline_user_args():
		await preload("res://tests/helpers/f6_after_daily_polish.gd").run(self)
		print("\n==== 日常优化%s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
		get_tree().quit(1 if failures else 0)
		return
	_run_data()
	await _run_day1()
	await _run_book()
	await _run_night()
	await _run_day2()
	await _run_errands()
	await _run_play()
	await _run_rest()
	await _run_equip()
	await _run_sweep()
	await _run_potion()
	await _run_cart()
	await _run_mice()
	await _run_rest_free()
	await _run_errands2()
	await _run_penalty()
	await _run_drill()
	await _run_tag()
	await _run_tailor()
	await _run_mine()
	await _run_tom()
	await _run_inspect()
	await _run_drill2()
	await _run_lantern()
	await _run_totem()
	_run_clock()
	await _run_old_save()
	await _run_skip()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


func _node(n: String) -> Node:
	return main.level.find_child(n, true, false) if main.level else null


# ------------------------------------------------------------------ 数据
func _run_data() -> void:
	print("-- 数据：胜利过场去战后的小镇、日程、楼层表")
	var won: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/floor_06/siege_won.json"))
	var last: Dictionary = (won["steps"] as Array).back()
	var goto: Dictionary = last["actions"][0]
	check("siege_won 最后 goto 到战后的小镇（%s / %s）" % [goto.get("to"), goto.get("spawn")],
		goto.get("to") == "floor_06_after" and goto.get("spawn") == "from_siege")
	check("三张新地图都在楼层表里", Floors.ids().has("floor_06_after") and Floors.ids().has("floor_06_after_house") and Floors.ids().has("floor_06_after_house_up"))
	check("日程里第 1 天三个时段都有事件（%s / %s / %s）" % [DayClock.event(1, 0), DayClock.event(1, 1), DayClock.event(1, 2)],
		DayClock.event(1, 0) == "d1_open" and DayClock.event(1, 1) == "d1_verdict" and DayClock.event(1, 2) == "d1_sleepwalk")
	check("镇长有自己的行走图", ResourceLoader.exists(str(Dialogue.npcs.get("mayor", {}).get("sprite", ""))))


# ------------------------------------------------------------------ 第 1 天：开场 → 自由活动 → 走到宣判台 → 宣判 → 晚上
func _run_day1() -> void:
	print("-- 第 1 天：战后开场 → 自由活动 → 广场宣判")
	var morning := {}
	var watch := func(id: String):
		if id == "after_d1_open":
			var g := _node("after_granny") as Node2D
			var c := _node("after_captain") as Node2D
			morning["granny"] = g.visible if g else true
			morning["captain"] = c.visible if c else false
			morning["slot"] = DayClock.slot()
	Cutscene.started.connect(watch)
	GameState.pending_spawn = "from_siege"
	await main.change_level(Floors.scene("floor_06_after"))
	await _advance_until(func(): return DayClock.done(1, 0) and not Cutscene.is_playing() and not DayClock.passing, 120.0)
	Cutscene.started.disconnect(watch)
	await _wait(0.5)
	check("进战后的小镇 = 第 1 天早上开始（after_started、开场时是早上 %s）" % morning.get("slot"),
		GameState.has_flag("after_started") and morning.get("slot") == DayClock.MORNING)
	check("开场时只有队长和守城的队员（奶奶藏着 %s、队长在 %s）" % [not morning.get("granny", true), morning.get("captain")],
		morning.get("granny") == false and morning.get("captain") == true)
	check("开场演完 → 到下午，宣判不会接着自动演（%s，%s）" % [DayClock.label(), seen_cuts],
		DayClock.slot() == DayClock.AFTERNOON and not DayClock.done(1, 1) and not seen_cuts.has("after_d1_verdict"))
	check("过场留下的黑幕揭开了（%.2f）" % Cutscene.curtain.color.a, Cutscene.curtain.color.a < 0.05)
	var mk := _node("Objective") as ObjectiveMarker
	var spot: Vector2 = Cells.to_world([31, 27])
	check("目标提示：「%s」，标记在宣判台前（离 %.0f）" % [mk.text if mk else "", mk.global_position.distance_to(spot) if mk else -1.0],
		mk != null and mk.text.contains("宣判台") and mk.has_cell and mk.global_position.distance_to(spot) < 2.0)
	await _wait(1.0)
	check("自由活动时等了一秒也不会自己开演", not seen_cuts.has("after_d1_verdict") and not Cutscene.is_playing())
	var blue := _node("AfterBlue") as PlayableCharacter
	# 战后的蓝色公主按自己的日程在镇上活动（AfterBlueRoutine），默认不跟着
	check("蓝色公主（AfterBlue）在镇上自由活动、粉色公主在操控", blue != null and not blue.follow and GameState.player.character_id == "pink")
	await _talk("floor_06/after_mayor", "")
	check("宣判之前镇民说的是等着宣判的话", GameState.has_flag("dlg_floor_06/after_mayor_d1_wait"))
	# 走到宣判台前 → 宣判 → 晚上
	_go(spot)
	await _advance_until(func(): return DayClock.done(1, 1) and not Cutscene.is_playing() and not DayClock.passing, 120.0)
	await _wait(0.5)
	check("走到宣判台前 → 宣判的过场（%s）→ 到晚上（%s）" % [seen_cuts.has("after_d1_verdict"), DayClock.label()],
		seen_cuts.has("after_d1_verdict") and DayClock.slot() == DayClock.NIGHT and GameState.has_flag("night"))
	check("宣判之后拿到赎罪簿：100 工时", PenanceBook.started() and PenanceBook.hours() == 100)
	var door: Vector2 = Cells.to_world(AfterStory.TOWN_HOUSE_DOOR)
	check("晚上的目标：回蓝色小屋（标记在小屋门口）", mk.text.contains("回蓝色小屋") and mk.global_position.distance_to(door) < 2.0)
	check("晚上镇民回家了（队长不在），宵禁的守卫还在", not (_node("after_captain") as Node2D).visible and (_node("after_guard_gate") as Node2D).visible)
	await _talk("floor_06/after_captain", "", [0, 2])
	check("队长第 1 天的对话（问钥匙被岔开）", GameState.has_flag("dlg_floor_06/after_captain_d1") and GameState.has_flag("dlg_floor_06/after_captain_d1_key"))


# ------------------------------------------------------------------ 赎罪簿
func _run_book() -> void:
	print("-- 赎罪簿")
	var before := PenanceBook.entries().size()
	PenanceBook.add(-5, "测试：搬木料")
	PenanceBook.add(3, "测试：偷懒")
	check("还 5、罚 3 → 98 工时，记了两笔（最后一笔是罚加）", PenanceBook.hours() == 98 and PenanceBook.entries().size() == before + 2
		and int(PenanceBook.entries().back()["delta"]) == 3)
	var bp: Backpack = main.get_node("Backpack")
	check("背包里有「赎罪簿」页（插在物品后面）", bp.page_order()[1] == Backpack.PAGE_PENANCE)
	var rows := PenanceBook.page_rows()
	var text := "\n".join(rows.map(func(r): return str(r["text"])))
	check("赎罪簿页：剩余工时、今天的安排（下午做完打勾）、记录", text.contains("剩余工时　98") and text.contains("✔ 下午：广场听候宣判")
		and text.contains("测试：偷懒"))
	bp.open()
	bp.set_page(Backpack.PAGE_PENANCE)
	await _wait(0.2)
	check("翻到赎罪簿页，显示的是赎罪簿的内容", bp.status_page.visible and bp.tabs_label.text.contains("【赎罪簿】"))
	bp.close()
	GameState.vars["penance_hours"] = 100
	var log: Array = PenanceBook.entries()
	log.resize(before)
	GameState.vars["penance_log"] = log


# ------------------------------------------------------------------ 第 1 天夜里：梦游
func _run_night() -> void:
	print("-- 第 1 天夜里：千手痒痒裤梦游")
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _advance_until(func(): return GameState.has_flag(AfterStory.NIGHT_BUSY) and not Cutscene.is_playing() and not DayClock.passing, 60.0)
	check("回小屋 = 天黑（夜晚、night 标记）→ 被裤子的手挠醒（%s）" % [seen_cuts.has("after_d1_night")],
		DayClock.slot() == DayClock.NIGHT and GameState.has_flag("night") and seen_cuts.has("after_d1_night"))
	await _wait(0.3)
	var clues := ["clue_bed", "clue_tea", "clue_stairs"].filter(func(c): return _node("Clue_" + c) != null)
	check("地上出现三处可以调查的手印（%d）" % clues.size(), clues.size() == 3)
	var door: Node = null
	var up: Node = null
	for n in main.level.find_children("*", "Area2D", true, false):
		var t := str(n.get("target_level")) if n.get("target_level") != null else ""
		if t.contains("floor_06_after_house_up"):
			up = n
		elif t.contains("floor_06_after"):
			door = n
	check("夜里出门的门锁着（宵禁）、楼梯还锁着", door != null and door.is_locked_now() and up != null and up.is_locked_now())
	# 床：梦游还没完不能睡
	await _talk("floor_06/after_house_objects", "bed")
	check("梦游还没弄清楚：床睡不了", GameState.has_flag("dlg_floor_06/after_house_objects_bed_busy") and DayClock.day() == 1)
	# 楼梯那处先看：不行
	await _talk("floor_06/after_house_objects", "clue_stairs")
	check("先看楼梯的手印：还不能上去", not GameState.has_flag(AfterStory.CLUES_FLAG))
	for c in ["clue_bed", "clue_tea", "clue_stairs"]:
		await _talk("floor_06/after_house_objects", c)
	check("三处都看过 → 楼梯解锁", GameState.has_flag(AfterStory.CLUES_FLAG) and not up.is_locked_now())
	# 楼上：梦游的结尾 → 回床上睡 → 第 2 天早上
	GameState.pending_spawn = "from_down"
	await main.change_level(Floors.scene("floor_06_after_house_up"))
	await _advance_until(func(): return DayClock.day() == 2 and not Sleep.sleeping and not Cutscene.is_playing() and not StoryDirector.instance.sequence_running, 90.0)
	check("楼上梦游的结尾放了（%s）→ 第 1 天夜里做完" % seen_cuts.has("after_d1_night_end"), seen_cuts.has("after_d1_night_end") and DayClock.done(1, 2))
	check("回到楼下的床边睡了一觉 → 第 2 天早上（%s，%s）" % [DayClock.label(), _level_id()],
		DayClock.day() == 2 and DayClock.slot() == DayClock.MORNING and not GameState.has_flag("night") and _level_id() == "floor_06_after_house")
	await _wait(0.6)
	check("梦游的手印收掉了、黑幕揭开了（%.2f）" % Cutscene.curtain.color.a,
		not GameState.has_flag(AfterStory.NIGHT_BUSY) and _node("Clue_clue_bed") == null and Cutscene.curtain.color.a < 0.05)


# ------------------------------------------------------------------ 第 2 天早上：足枷示众
func _run_day2() -> void:
	print("-- 第 2 天早上：广场足枷示众（小游戏）")
	var h0 := PenanceBook.hours()
	var p0 := PenanceBook.punishments().size()
	PenanceRoulette.forced = "wheel"
	StocksShow.auto_respond = "calm"
	# 示众开始以后：倒计时调到 2 秒、笑出声记成 3 次（看结算和转盘）
	var hook := func(n: Node):
		if n is StocksShow:
			(func():
				await get_tree().process_frame
				n.time_left = 2.0
				n.bursts = 3).call()
	get_tree().node_added.connect(hook)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.5)
	var mk := _node("Objective") as ObjectiveMarker
	check("第 2 天早上：目标是广场的足枷，进镇不会自己开演（%s）" % (mk.text if mk else ""),
		mk != null and mk.text.contains("足枷") and not seen_cuts.has("after_d2_stocks"))
	check("示众之前蓝色公主不在身边（一早去了训练室）", not (_node("AfterBlue") as Node2D).visible)
	await _talk("floor_06/after_kid_tom", "")
	check("示众之前镇民说的是等着示众的话", GameState.has_flag("dlg_floor_06/after_kid_tom_d2_wait"))
	var said := {"paused_talk": false}
	_go(Cells.to_world([23, 25.5]))
	await _advance_until(func():
		for n in get_tree().root.get_children():
			if n is StocksShow and (n as StocksShow).busy and Dialogue.is_active():
				said["paused_talk"] = true
		return DayClock.done(2, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and not CG.is_busy(), 180.0)
	get_tree().node_added.disconnect(hook)
	StocksShow.auto_respond = ""
	check("示众里孩子登场时暂停示众、在对话框里演挠法和对话", said["paused_talk"])
	check("示众：开场过场 → 小游戏 → 撑过时间的结局（%s）" % [seen_cuts.filter(func(c): return c.begins_with("after_d2"))],
		seen_cuts.has("after_d2_stocks") and seen_cuts.has("after_d2_stocks_end") and not seen_cuts.has("after_d2_stocks_faint"))
	check("工时：示众做完 -12、笑出声 3 次 +6（%d → %d）" % [h0, PenanceBook.hours()], PenanceBook.hours() == h0 - 12 + 6)
	var pun := PenanceBook.punishments()
	check("笑出声 3 次以上 → 训练营转盘停在转轮，播了刑具小剧场、记进受罚记录（%s）" % [pun.back().get("text") if pun.size() > p0 else ""],
		pun.size() == p0 + 1 and str(pun.back()["theater"]) == "after_roulette_wheel" and GameState.has_flag("cg_seen_theater:after_roulette_wheel"))
	check("示众完到了第 2 天下午、蓝色公主回到镇上", DayClock.day() == 2 and DayClock.slot() == DayClock.AFTERNOON and _node("AfterBlue") != null)
	var text := "\n".join(PenanceBook.page_rows().map(func(r): return str(r["text"])))
	check("赎罪簿页列出受罚记录", text.contains("受罚记录") and text.contains("训练营转盘：转轮"))
	var groups := Backpack.gallery_entries().filter(func(e): return str(e.get("id", "")).begins_with("after_roulette_")).map(func(e): return e["group"])
	check("四段转盘小剧场都在 CG 图鉴的「七日赎罪」分组里（%d）" % groups.size(), groups.size() == 4 and groups.all(func(g): return g == "七日赎罪"))
	await _run_stocks_rules()
	# 笑晕的结局过场
	Cutscene.play("after_d2_stocks_faint")
	await get_tree().process_frame
	await _advance_until(func(): return not Cutscene.is_playing(), 90.0)
	check("笑晕的结局过场（蓝色公主描述她昏过去以后的事）能放完", GameState.has_flag("cutscene_seen_after_d2_stocks_faint"))
	Cutscene.curtain_clear(0.01)


## 示众小游戏的规则（单独开一个，直接调它的方法）
func _run_stocks_rules() -> void:
	print("-- 示众小游戏的规则")
	StocksShow.quiet = true
	var show := StocksShow.new()
	add_child(show)
	var res := {}
	(func(): res.merge(await show.play_show())).call()
	await get_tree().process_frame
	var p := GameState.player
	var lmax := p.laugh.max_value
	check("开始：120 秒、求情 3 次、第一个孩子挑了部位", show.time_left > 118.0 and show.pleads == 3 and not show.part.is_empty())
	# 部位：前脚掌比脚弓涨得快（先让孩子挑脚心，再求情换到前脚掌）
	show._set_part(1)
	var t_before := show.time_left
	show.plead(0)
	check("按 1 求情：换到前脚掌、求情 -1、倒计时 +2", show.part["id"] == "ball" and show.pleads == 2 and absf(show.time_left - t_before - 2.0) < 0.01)
	p.laugh.set_value(0.0)
	show._tick(1.0)
	var ball := p.laugh.value
	show.plead(3)
	p.laugh.set_value(0.0)
	show._tick(1.0)
	var arch := p.laugh.value
	check("前脚掌每秒涨闷笑 %.1f，脚弓 %.1f（前脚掌最痒）" % [ball, arch], ball > arch * 2.5)
	# 挣扎
	p.laugh.set_value(lmax * 0.5)
	show.press("J")
	check("J 挣扎：闷笑降 2.5%%（%.1f%%）" % (p.laugh.ratio() * 100.0), absf(p.laugh.ratio() - 0.475) < 0.005)
	for i in StocksShow.SWITCH_AFTER:
		show.press("E")
	check("同一部位连挣 6 次：孩子换部位（%s）" % show.part["name"], show.part["id"] != "arch")
	# 应对：顶嘴 → 两只脚、求情 -1
	show.part_left = 0.0
	show._tick(0.01)
	check("孩子挠完一段 → 间隙弹出应对", show.responding)
	var pl := show.pleads
	show.respond("sass")
	check("顶嘴：挂「挑衅」、两只脚一起挠、求情 -1", show.debuff == "sass" and show.both_feet and show.pleads == pl - 1)
	show.part_left = 0.0
	show._tick(0.01)
	show.respond("beg")
	check("求饶：挂「丢脸」、求情 +1、这个孩子时间 -30%", show.debuff == "beg" and show.pleads == pl and show.part_left <= float(show.part["time"]) * 0.71)
	# 闷笑满 = 笑出声
	show.add_laugh(lmax)
	await _wait(1.2)
	check("闷笑满：笑出声（%d）、闷笑回到 40%%" % show.bursts, show.bursts == 1 and absf(p.laugh.ratio() - 0.4) < 0.05)
	# 疲倦满 = 释放、加时
	var t0 := show.time_left
	show.add_fatigue(p.fatigue.max_value)
	await _wait(1.6)
	check("魔力疲倦满：自动释放（%d）、队长加时 +15 秒（%.0f → %.0f）" % [show.releases, t0, show.time_left], show.releases == 1 and show.time_left > t0 + 14.0)
	# 释放超过 5 次 = 笑晕
	for i in 5:
		show.add_fatigue(p.fatigue.max_value)
		await _wait(1.8)
	await _advance_until(func(): return not res.is_empty(), 10.0)
	check("释放第 6 次：笑晕，示众结束（%s）" % [res], bool(res.get("fainted", false)) and int(res.get("releases", 0)) == 6)
	show.queue_free()
	StocksShow.quiet = false
	# 演出：孩子登场 / 应对 / 笑出声 / 释放的台词都在（前四个孩子是原来过场里的戏份）
	var tx := StocksShow.text()
	check("台词：四个孩子的登场 + 应对（各三种反应）、16 段「工具 × 部位」挠法描写、笑出声 / 释放的小段",
		tx["kids"].size() == 4 and tx["kids"].all(func(k): return k["replies"].size() == 3 and k["options"].size() == 3)
		and tx["narration"].size() == 4 and tx["narration"].values().all(func(v): return v.size() == 4)
		and not tx["burst"].is_empty() and not tx["release"].is_empty())


# ------------------------------------------------------------------ 镇民委托
func _run_errands() -> void:
	print("-- 镇民委托：送饼干、捡苹果")
	await _wait(0.5)
	check("第 2 天下午：送饼干和捡苹果都能接，委托人头上冒「！」",
		GameState.has_flag("errand_cookies_open") and GameState.has_flag("errand_apples_open")
		and _node("after_granny").get_node_or_null("ErrandMark") != null and _node("after_merchant").get_node_or_null("ErrandMark") != null)
	var h0 := PenanceBook.hours()
	# 送饼干：接下 → 小孩闻香过来挠、拿走一块 → 送到守城门的队员
	await _talk("floor_06/after_granny", "", [0])
	await _wait(0.3)
	var runner := _node("Errand_cookies")
	var kids: Array = main.level.find_children("*", "AfterKid", true, false)
	check("接下送饼干：篮子 6 块、路上 3 个小孩、别的委托暂时接不了（%d 个小孩）" % kids.size(),
		AfterErrands.active() == "cookies" and runner != null and kids.size() == 3 and int(GameState.vars.get("errand_cookies_left", 0)) == 6
		and not GameState.has_flag("errand_apples_open"))
	var kid := kids[0] as AfterKid
	var l0 := GameState.player.laugh.value
	_go(kid.global_position + Vector2(20, 0))
	await _advance_until(func(): return int(GameState.vars.get("errand_cookies_left", 0)) < 6, 8.0)
	check("小孩闻到香味跑过来挠（闷笑 %.0f → %.0f），拿走一块饼干（剩 %d）" % [l0, GameState.player.laugh.value, int(GameState.vars.get("errand_cookies_left", 0))],
		int(GameState.vars.get("errand_cookies_left", 0)) == 5 and GameState.player.laugh.value > l0)
	var k2 := kids[1] as AfterKid
	k2.talk(GameState.player)
	check("按 E 哄走：分他一块就走了（剩 %d）" % int(GameState.vars.get("errand_cookies_left", 0)), int(GameState.vars.get("errand_cookies_left", 0)) == 4 and k2.mode == AfterKid.Mode.LEAVE)
	GameState.player.laugh.clear()
	_go((_node("after_guard_gate") as Node2D).global_position + Vector2(0, 10))
	await _advance_until(func(): return AfterErrands.is_done("cookies") and not Dialogue.is_active(), 10.0)
	check("送到守城门的队员 → 委托完成、减 3 工时（%d → %d）、小孩散了" % [h0, PenanceBook.hours()],
		AfterErrands.is_done("cookies") and PenanceBook.hours() == h0 - 3 and main.level.find_children("*", "AfterKid", true, false).is_empty())
	# 捡苹果：失败一次（时间到）→ 再接 → 捡齐
	await _talk("floor_06/after_merchant", "", [0])
	await _wait(0.3)
	var ap := _node("Errand_apples")
	check("接下捡苹果：地上 10 个苹果、5 丛痒痒草", ap != null and get_tree().get_nodes_in_group("tickle_grass").size() == 5)
	var grass := get_tree().get_nodes_in_group("tickle_grass")[0] as TickleGrass
	_go(grass.global_position)
	await _wait(0.5)
	check("踩到痒痒草：被缠住（定身）、闷笑上涨", grass.caught >= 1 and GameState.player.status.is_rooted())
	await _wait(1.5)
	ap.left_t = 0.05
	await _advance_until(func(): return AfterErrands.active() == "" and not Dialogue.is_active(), 10.0)
	check("时间到没捡齐 → 失败（被掸子挠一下），委托回到能接", not AfterErrands.is_done("apples") and GameState.has_flag("errand_apples_open"))
	GameState.player.laugh.clear()
	await _talk("floor_06/after_merchant", "", [0])
	await _wait(0.3)
	ap = _node("Errand_apples")
	for c in ap.APPLES:
		_go(Cells.to_world(c))
		await _wait(0.12)
	await _advance_until(func(): return AfterErrands.is_done("apples") and not Dialogue.is_active(), 10.0)
	check("十个苹果都捡回来 → 委托完成", AfterErrands.is_done("apples") and not GameState.has_flag("errand_apples_open"))
	GameState.player.laugh.clear()


# ------------------------------------------------------------------ 两位公主的玩闹
func _run_play() -> void:
	print("-- 两位公主的玩闹")
	var weak := AfterPlay.weak_spot()
	var other: String = AfterPlay.SPOTS[(AfterPlay.SPOTS.find(weak) + 2) % 4]
	check("每天的弱点不一样（第 2 天 %s、第 3 天 %s）" % [weak, AfterPlay.weak_spot(3)], AfterPlay.weak_spot(2) != AfterPlay.weak_spot(3))
	var b0 := int(GameState.vars.get("blue_bond", 0))
	AfterPlay.auto_picks = [AfterPlay.SPOTS.find(other), AfterPlay.SPOTS.find(weak)]
	AfterPlay.auto_qte = true
	await _talk("floor_06/after_partner", "", [0])
	await _advance_until(func(): return AfterPlay.played_today() and not AfterPlay.running and not Dialogue.is_active(), 30.0)
	check("先挠错一个、再挠中弱点 + 连击成功 → 她破功大笑，关系值 +1（%d → %d）" % [b0, int(GameState.vars.get("blue_bond", 0))],
		int(GameState.vars.get("blue_bond", 0)) == b0 + 1 and AfterPlay.played_today())
	AfterPlay.auto_picks = [0, 0, 0]
	await _talk("floor_06/after_partner", "", [0])
	await _wait(0.5)
	await _advance_until(func(): return not AfterPlay.running and not Dialogue.is_active(), 10.0)
	check("当天获胜后不重复玩闹或加关系值", int(GameState.vars.get("blue_bond", 0)) == b0 + 1)
	AfterPlay.auto_picks = []
	AfterPlay.auto_qte = null


# ------------------------------------------------------------------ 空时段：床上休息
func _run_rest() -> void:
	print("-- 床上休息：还有事没做时不让休息")
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _wait(0.5)
	await _talk("floor_06/after_house_objects", "bed", [0])
	await _wait(1.0)
	check("第 2 天下午还有「回收痒痒装备」没做：床不让休息", DayClock.slot() == DayClock.AFTERNOON)


# ------------------------------------------------------------------ 弥补任务一：痒痒装备回收
func _run_equip() -> void:
	print("-- 弥补任务：痒痒装备回收")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	GameState.player.laugh.clear()
	_go(Cells.to_world([13, 24.5]))
	await _advance_until(func(): return _node("Task_d2_equip") != null and not Cutscene.is_playing() and not Dialogue.is_active(), 30.0)
	var task := _node("Task_d2_equip") as TaskEquip
	check("走到补给站 → 开场过场 → 任务开始：地上 8 件装备、路上 4 个小孩、小屋的门锁上、委托接不了",
		task != null and task.spots.size() == 8 and task.kids.size() == 4 and GameState.has_flag(AfterStory.TASK_FLAG)
		and not GameState.has_flag("errand_cookies_open") and seen_cuts.has("after_d2_equip"))
	# 捡起来就自己穿上；同部位再捡一件，旧的掉在脚下
	var p := GameState.player
	_go(Cells.to_world([6, 13]))
	await _wait(0.3)
	check("捡起羽毛袜：自己穿上了", TaskEquip.worn().has("equip_t_feather_socks"))
	_go(Cells.to_world([52, 13]))
	await _wait(0.3)
	check("再捡趾缝刷套（也是脚上的）：刷套穿上、羽毛袜掉在脚下（地上还是 7 件）",
		TaskEquip.worn() == ["equip_t_toe_brush"] and task.spots.size() == 7
		and (GameState.vars["task_equip_left"] as Array).any(func(it): return it[0] == "equip_t_feather_socks"))
	# 小孩按穿着的装备配合着挠
	check("小孩的配合挠法跟着装备走：刷套 → 扳脚趾刷趾缝（%s）" % EquipKids.caption(["equip_t_toe_brush"]).left(20),
		EquipKids.caption(["equip_t_toe_brush"]).contains("刷") and EquipKids.zone_for(["equip_t_toe_brush"]) == "sole"
		and EquipKids.caption(["equip_t_feather_socks", "equip_t_toe_brush"]).contains("袜"))
	var kid := task.kids[0]
	p.laugh.set_value(p.laugh.max_value * 0.5)
	_go(kid.global_position + Vector2(30, 0))
	await _advance_until(func(): return kid.mode == AfterKid.Mode.TICKLE, 6.0)
	check("闷笑超过 40%%：小孩跑过来挠（%s）" % kid.mode, kid.mode == AfterKid.Mode.TICKLE)
	kid.talk(p)
	check("按 E 把他哄走", kid.mode == AfterKid.Mode.LEAVE)
	# 冲刺甩不掉小孩（K 不管用），挠的时间更长、看得更远
	check("小孩看得更远、挠得更久", AfterKid.SIGHT >= 150.0 and AfterKid.TICKLE_TIME >= 3.5)
	# 长椅 / 井（先让小孩们别来）
	for k in task.kids:
		k._leave()
		k._cool = 60.0
	await _advance_until(func(): return not GameState.in_dialogue, 5.0)
	p.laugh.set_value(p.laugh.max_value * 0.6)
	_go(Cells.to_world([40, 21.6]))
	await _wait(2.0)
	check("在长椅上歇着：闷笑慢慢降（%.0f%%）" % (p.laugh.ratio() * 100.0), p.laugh.ratio() < 0.55)
	p.laugh.set_value(p.laugh.max_value * 0.6)
	_go(Cells.to_world([30, 19]))
	await _advance_until(func(): return p.laugh.ratio() < 0.35, 3.0)
	check("井边洗把脸：闷笑一下子降 30%%（%.0f%%）" % (p.laugh.ratio() * 100.0), p.laugh.ratio() < 0.35)
	# 笑倒 = 失败 → 失败小剧场 → 装备散回原位
	p.laugh.set_value(p.laugh.max_value * 0.95)
	var tid := task.get_instance_id()
	await _advance_until(func(): return _node("Task_d2_equip") != null and _node("Task_d2_equip").get_instance_id() != tid and not CG.is_busy() and not Dialogue.is_active(), 60.0)
	check("闷笑到 90%%：笑倒 → 失败小剧场、罚工时，装备散回原位重来（%s）" % GameState.has_flag("cg_seen_theater:after_fail_equip"),
		GameState.has_flag("cg_seen_theater:after_fail_equip") and (GameState.vars["task_equip_left"] as Array).size() == 8 and TaskEquip.worn().is_empty())
	# 一件一件送到补给站
	for it in TaskEquip.ITEMS:
		p.laugh.clear()
		_go(Cells.to_world([it[1], it[2]]))
		await _wait(0.15)
		_go(Cells.to_world(TaskEquip.DEPOT))
		await _wait(0.15)
	await _advance_until(func(): return DayClock.done(2, DayClock.AFTERNOON) and not Cutscene.is_playing() and not DayClock.passing, 30.0)
	check("8 件都送回补给站 → 收尾过场 → 天黑（%s）" % DayClock.label(),
		seen_cuts.has("after_d2_equip_done") and DayClock.slot() == DayClock.NIGHT and not GameState.has_flag(AfterStory.TASK_FLAG))


## 夜里回小屋睡觉 → 第二天早上
func _sleep_night() -> void:
	# 晚上的弥补任务做完会自动睡到天亮：已经是早上就不用再睡
	if DayClock.slot() == DayClock.MORNING:
		return
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _wait(0.5)
	await _talk("floor_06/after_house_objects", "bed")
	var d := DayClock.day()
	await _advance_until(func(): return DayClock.day() == d + 1 and not Sleep.sleeping, 30.0)


# ------------------------------------------------------------------ 弥补任务二：配药
func _run_potion() -> void:
	print("-- 弥补任务：药剂师的试药员")
	await _sleep_night()
	check("睡一觉到第 3 天早上", DayClock.day() == 3 and DayClock.slot() == DayClock.MORNING)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	var mk := _node("Objective") as ObjectiveMarker
	check("目标：去药剂师工房（标记在工房门口）", mk.text.contains("药剂师") and mk.global_position.distance_to(Cells.to_world([16, 10])) < 2.0)
	GameState.vars["task_potion_recipe"] = 0
	GameState.vars["task_potion_ok"] = 0
	# 错三碗（第一张配方是 薄荷叶 + 冰晶草 + 薰衣草）→ 失败 → 换第二张（薄荷叶 + 冰晶草 + 蜂蜜根）→ 配对
	TaskPotion.auto_picks = [["mint", "mushroom", "feather"], ["mint", "ice", "honey"], ["lavender", "honey", "mushroom"], ["mint", "ice", "honey"],
		["ice", "lavender", "ginger"], ["mint", "lavender", "honey"]]
	PotionTrial.auto = "bad"
	var pd := TaskPotion.data()
	check("配药：八味药草、每味都有自己的试药流程（开场 + 小操作 + 成功 / 失败）、配对后的成品测试",
		(pd["order"] as Array).size() == 8 and (pd["herbs"] as Dictionary).values().all(func(h): return h.has("kind") and h["intro"].size() >= 4 and not h["ok"].is_empty() and not h["bad"].is_empty())
		and (pd["final"] as Array).size() >= 8)
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_pharmacy"))
	await _wait(0.8)
	var notes := {"n": 0}
	_go(Cells.to_world([8, 6]))
	await _advance_until(func():
		notes["n"] = maxi(notes["n"], (GameState.vars.get("task_potion_notes", []) as Array).size())
		return DayClock.done(3, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and not CG.is_busy(), 120.0)
	TaskPotion.auto_picks = []
	PotionTrial.auto = ""
	check("配错的药草记进配方本（最多记了 %d 碗）" % notes["n"], notes["n"] >= 2)
	check("错三碗 → 全身羽毛测试的失败小剧场、换一张配方；之后配对三张才算完（配对 %d 张，到了第 %d 张配方）" % [int(GameState.vars.get("task_potion_ok", 0)), int(GameState.vars.get("task_potion_recipe", 0))],
		GameState.has_flag("cg_seen_theater:after_fail_potion") and int(GameState.vars.get("task_potion_ok", 0)) == 3 and int(GameState.vars.get("task_potion_recipe", 0)) == 3)
	check("配对了 → 得到薄荷止痒药 → 到下午", GameState.inventory.count("mint_potion") >= 1 and DayClock.slot() == DayClock.AFTERNOON)
	var item := ItemDB.get_item("mint_potion")
	GameState.player.laugh.clear()
	item.use(GameState.player)
	GameState.player.laugh.add(30.0)
	check("喝了薄荷止痒药：一会儿内不涨闷笑", GameState.player.laugh.value < 1.0)


# ------------------------------------------------------------------ 弥补任务三：拆攻城车
func _run_cart() -> void:
	print("-- 弥补任务：拆除哑火的攻城车")
	GameState.pending_spawn = "from_pharmacy"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	check("第 3 天下午：城门开了、目标是城外的战场", GameState.has_flag(AfterStory.FIELD_OPEN) and (_node("Objective") as ObjectiveMarker).text.contains("战场"))
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_field"))
	await _advance_until(func(): return _node("Task_d3_cart") != null and not Cutscene.is_playing() and not Dialogue.is_active(), 40.0)
	var task := _node("Task_d3_cart") as TaskCart
	check("进战场 → 队长讲规矩的过场 → 任务开始（3 辆睡着的车）", task != null and task.carts.size() == 3 and seen_cuts.has("after_d3_cart"))
	var p := GameState.player
	var c0 := task.carts[0]
	# 被车灯照到 → 惊醒 → 捞进车斗 → 挣开
	TaskCart.auto_struggle = true
	_go(c0.global_position + c0.front.normalized() * 40.0)
	c0.cone.facing = c0.front
	c0._t = 0.0
	await _advance_until(func(): return c0.awake, 4.0)
	check("被车灯照到：车醒了", c0.awake)
	await _advance_until(func(): return not task._busy and not Cutscene.is_playing(), 15.0)
	check("被捞进车斗挠、挣扎挣开了：被甩出来，任务还在", is_instance_valid(task) and _node("Task_d3_cart") == task)
	await _wait(2.5)
	# 蓝色公主冻车轮：冻着的车不醒；冻太久裤子反弹
	var blue := _node("AfterBlue") as PlayableCharacter
	GameState.switch_control(blue)
	await _wait(0.3)
	await _advance_until(func(): return not Dialogue.is_active(), 10.0)   # 第一次换成她时的千手痒痒裤台词
	_go(c0.global_position + Vector2(0, 60))
	Input.action_press("magic")
	await _wait(1.0)
	check("蓝色公主按住技能键：车轮冻住了（车灯不扫）", c0.is_frozen() and not c0.cone.visible)
	var bl0 := blue.laugh.value
	await _advance_until(func(): return task._cool > 0.0, 6.0)
	Input.action_release("magic")
	check("冻得太久：千手痒痒裤反弹（蓝色公主闷笑 %.0f → %.0f），冰化了" % [bl0, blue.laugh.value], blue.laugh.value > bl0 and not c0.is_frozen())
	GameState.switch_control(_node("princess") if _node("princess") else main.level.find_children("*", "Princess", true, false)[0])
	await _wait(0.3)
	p = GameState.player
	# 车尾按住 E 拆车轴
	_go(c0.rear_point())
	c0.frozen_t = 10.0   # 拆的时候先冻着（不然车灯扫过来）
	Input.action_press("interact")
	await _advance_until(func(): return c0.done, 5.0)
	Input.action_release("interact")
	check("绕到车尾按住 E 三秒：车轴拆下来了", c0.done and (GameState.vars.get("task_cart_done", []) as Array).size() == 1)
	# 挣不开 = 失败
	TaskCart.auto_struggle = false
	var c1 := task.carts[1]
	c1.frozen_t = 0.0
	_go(c1.global_position + c1.front.normalized() * 40.0)
	c1.cone.facing = c1.front
	c1._t = 0.0
	await _advance_until(func(): return GameState.has_flag("cg_seen_theater:after_fail_cart") and not CG.is_busy() and _node("Task_d3_cart") != null, 90.0)
	check("挣不开：车斗里刷子的失败小剧场 → 回到战场入口重来，拆完的车不用重拆",
		GameState.has_flag("cg_seen_theater:after_fail_cart") and (_node("Task_d3_cart") as TaskCart).carts[0].done)
	TaskCart.auto_struggle = null
	task = _node("Task_d3_cart") as TaskCart
	for c in task.carts:
		c.add_progress(5.0)
	await _advance_until(func(): return DayClock.done(3, DayClock.AFTERNOON) and not Cutscene.is_playing() and not DayClock.passing, 40.0)
	check("三辆都拆完 → 队长递手帕的过场（「花猫样」的口误）→ 天黑", seen_cuts.has("after_d3_cart_done") and DayClock.slot() == DayClock.NIGHT)
	var cut: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/floor_06/after_d3_cart_done.json"))
	check("口误那句是用户给的原话", (cut["steps"] as Array).any(func(st): return str(st.get("text", "")) == "擦擦吧，你小时候只要一赌气去钻管道，出来也是这副花猫样……"))


# ------------------------------------------------------------------ 没有剧情的时段：床上休息
func _run_rest_free() -> void:
	print("-- 第 4 天早上：疏通排水管")
	await _sleep_night()
	check("第 4 天早上：要去通排水管", DayClock.day() == 4 and DayClock.slot() == DayClock.MORNING and DayClock.event() == "d4_drain")
	await _talk("floor_06/after_house_objects", "bed", [0])
	await _wait(0.3)
	check("有事没做时床上不让休息", DayClock.slot() == DayClock.MORNING)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	var mk := _node("Objective") as ObjectiveMarker
	check("目标：南边的排水口（开了）", mk.text.contains("排水") and GameState.has_flag(AfterStory.DRAIN_OPEN)
		and mk.global_position.distance_to(Cells.to_world([20, 38])) < 2.0)
	GameState.vars["task_drain_cleared"] = 0
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_drain"))
	await _advance_until(func(): return _node("Task_d4_drain") != null and (_node("Task_d4_drain") as TaskDrain).started and not GameState.in_dialogue, 40.0)
	await _wait(0.1)
	var task := _node("Task_d4_drain") as TaskDrain
	var p := GameState.player
	check("进排水管 → 队员讲规矩的过场 → 趴着爬（慢、不能冲刺，但能攻击打老鼠）", task != null and seen_cuts.has("after_d4_drain")
		and p.buffs.has("crawl") and p.has_meta(&"no_dash") and not p.has_meta(&"busy_hands"))
	if task == null:
		return
	# 脚被抓
	task._grabs_left.clear()
	var l0 := p.laugh.value
	task.grab_now()
	await _advance_until(func(): return not task._busy and not GameState.in_dialogue, 10.0)
	await _wait(0.5)
	check("管口外的小孩抓住脚：定身 + 挠（闷笑 %.0f → %.0f）" % [l0, p.laugh.value], task.grabbed and p.status.is_rooted() and p.laugh.value > l0)
	for i in TaskDrain.KICKS:
		task.kick()
	check("按 J 蹬 %d 下：挣开了" % TaskDrain.KICKS, not task.grabbed and not p.status.is_rooted())
	# 绒苔球
	var mb: TaskDrain.MossBall = task.moss[0]
	_go(mb.global_position)
	await _advance_until(func(): return mb.stuck and not task._busy and not GameState.in_dialogue, 10.0)
	check("碰到绒苔球：贴在腿上蹭（第一次演几句）", mb.stuck and task.moss_seen)
	task.wipe(TaskDrain.WIPE + 0.1)
	await _wait(0.1)
	check("按住 E 擦掉", not is_instance_valid(mb))
	# 三处堵塞（每段开场 / 涂鸦）
	for i in TaskDrain.CLOGS.size():
		p.laugh.clear()
		for m in task.moss:
			if is_instance_valid(m):
				m.queue_free()
		_go(Cells.to_world(TaskDrain.SEG_AT[i]))
		await _advance_until(func(): return task._seg_seen.has(i) and not task._busy and not GameState.in_dialogue, 20.0)
		var c: Node2D = task.clogs[i]
		_go(c.global_position + Vector2(-14, 0))
		await _advance_until(func(): return task._clog_lines.has(i) and not task._busy and not GameState.in_dialogue, 20.0)
		task.scrub(TaskDrain.SCRUB + 0.1)
		await _advance_until(func(): return TaskDrain.cleared() == i + 1 and not task._busy and not GameState.in_dialogue, 20.0)
	check("三段：开场（第二段管壁上的涂鸦）→ 擦通三处堵塞（%d）" % TaskDrain.cleared(), TaskDrain.cleared() == 3 and task._seg_seen.size() == 3)
	# 失败：笑满被拖出去
	p.laugh.set_value(p.laugh.max_value)
	var again := func() -> bool:
		var td := _node("Task_d4_drain") as TaskDrain
		return GameState.has_flag("cg_seen_theater:after_fail_drain") and not CG.is_busy() and td != null and td.started and not GameState.in_dialogue
	await _advance_until(again, 60.0)
	task = _node("Task_d4_drain") as TaskDrain
	check("闷笑满：被小孩抓着脚拖出管子的小剧场 → 重来（通了的还算）", GameState.has_flag("cg_seen_theater:after_fail_drain") and TaskDrain.cleared() == 3)
	p = GameState.player
	p.laugh.clear()
	task.pull_lever()
	await _advance_until(func(): return DayClock.done(4, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and _level_id() == "floor_06_after", 60.0)
	check("拉总闸放水 → 队长递手帕（「又是这副样子」）→ 回到小镇、下午", seen_cuts.has("after_d4_drain_done") and DayClock.slot() == DayClock.AFTERNOON
		and _level_id() == "floor_06_after" and not GameState.player.buffs.has("crawl"))


# ------------------------------------------------------------------ 第 4 天下午：蓝色公主的特训（第一、二课）
func _run_drill() -> void:
	print("-- 蓝色公主的特训：第一课 冰封静坐、第二课 驯裤")
	DrillShow.quiet = true
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_drill"))
	await _wait(0.8)
	_go(Cells.to_world([10, 7]))
	await _advance_until(func(): return _node("Task_d4_drill") != null and (_node("Task_d4_drill") as TaskDrill).show != null, 30.0)
	var task := _node("Task_d4_drill") as TaskDrill
	check("训练室 → 特训的过场 → 换成操控蓝色公主、第一课开始", task != null and seen_cuts.has("after_d4_drill")
		and GameState.player.character_id == "blue" and task.show is IceSitShow)
	if task == null:
		return
	var ice := task.show as IceSitShow
	await _wait(0.2)
	ice.target = "lthigh"
	ice.decoy = ""
	ice.warn_t = 0.5
	ice.press("A")
	check("身体图亮起左大腿 → 按 A 冻住", ice.frozen.has("lthigh"))
	var face0 := ice.face
	ice._strike("lthigh", "cap")
	check("挠到冻住的地方：没感觉（表情不掉）", ice.face == face0 and ice.blocked == 1)
	ice._strike("butt", "cap")
	check("挠到没冻的地方：表情掉（%.0f）" % ice.face, ice.face < face0)
	var c0 := ice.cold
	ice.freeze("knee")
	check("冻新的地方不涨寒冷（%.0f → %.0f）" % [c0, ice.cold], ice.cold <= c0)
	ice.cold = 95.0
	ice.freeze("knee")
	await _wait(0.2)
	check("冻太多：发抖，冻住的地方全化开", ice.shivers == 1 and ice.frozen.is_empty())
	# 第九轮：六处全冻住 → 寒冷值不回落、很快涨
	ice.cold = 0.0
	for sp in ice.lesson().get("spots", []):
		ice.frozen[str(sp["id"])] = IceSitShow.FREEZE_TIME
	var shiv0 := ice.shivers
	ice._tick(1.0)
	check("全身都冻住：寒冷值大幅积累（1 秒 +%.0f）" % ice.cold, ice.all_frozen() and ice.cold >= IceSitShow.ALL_FROZEN_COLD * 0.9 or ice.shivers > shiv0)
	ice.frozen.clear()
	ice.cold = 0.0
	await _wait(0.2)
	ice.add_fatigue(ice.fatigue_max())
	await _wait(0.3)
	check("魔力疲倦满：自动释放 → 释放后敏感（%.0f 秒）" % ice.sensitive_t, ice.releases == 1 and ice.sensitive_t > 10.0)
	ice.face = 100.0
	ice.frozen.erase("rwaist")
	var f1 := ice.face
	ice._strike("rwaist", "cap")
	check("释放后敏感：表情掉得更快（%.0f → %.0f）" % [f1, ice.face], f1 - ice.face > IceSitShow.HIT_FACE * 1.5)
	for i in 3:
		ice.add_fatigue(ice.fatigue_max())
		await _wait(0.3)
	check("一节课释放超过 3 次：这节课重来（%d）" % ice.redos, ice.redos == 1 and ice.releases == 0)
	ice.time_left = 0.05
	await _advance_until(func(): return task.show is PantsTameShow, 10.0)
	check("撑够时间 → 下课 → 第二课 驯裤", task.show is PantsTameShow)
	var tame := task.show as PantsTameShow
	await _wait(0.2)
	tame.gesture = tame._gestures()[0]
	tame.fake = {}
	tame.left = 1.0
	tame.press("W")
	check("手势「抖」→ W 按住：听话度涨（%.0f）" % tame.obedience, tame.obedience > 0.0 and tame.rights == 1)
	var ob := tame.obedience
	tame.gesture = tame._gestures()[1]
	tame.fake = {}
	tame.left = 1.0
	tame.press("W")
	check("手势「并拢」却下了「按住」：小手造反挠她、听话度降", tame.wrongs == 1 and tame.obedience < ob)
	tame.gesture = tame._gestures()[2]
	tame.fake = tame._gestures()[0]
	tame.left = 1.0
	tame.press("W")
	check("假手势（先比「抖」、其实是「张开」）照着假的下指令：算错", tame.wrongs == 2)
	tame.obedience = tame.goal()
	await _advance_until(func(): return DayClock.done(4, DayClock.AFTERNOON) and not Cutscene.is_playing() and not DayClock.passing, 40.0)
	check("听话度满 → 出师 → 换回粉色公主 → 后天再来的过场 → 天黑", seen_cuts.has("after_d4_drill_done") and DayClock.slot() == DayClock.NIGHT
		and GameState.player.character_id != "blue")
	DrillShow.quiet = false


# ------------------------------------------------------------------ 第 3 天起的委托
func _show(cls: Variant) -> Node:
	for c in get_tree().root.get_children():
		if is_instance_of(c, cls):
			return c
	return null


func _run_errands2() -> void:
	print("-- 第 3 天起的委托：扶梯子、赶蘑菇羊、足底按摩、篝火舞会排练")
	await main.change_level(Floors.scene("floor_06_after"))
	await _advance_until(func(): return not Cutscene.is_playing() and not DayClock.passing, 10.0)
	await _wait(0.4)
	check("第 4 天下午：四个新委托都能接，工匠 / 女仆 / 派对主人头上冒「！」",
		["ladder", "goats", "dance", "massage"].all(func(e): return GameState.has_flag("errand_%s_open" % e))
		and ["after_engineer", "after_maid", "after_bonfire_host"].all(func(n): return _node(n) and _node(n).get_node_or_null("ErrandMark") != null))
	var tx := LadderShow.text()
	var lines := 0
	for k in ["intro", "fall", "done"]:
		lines += (tx[k] as Array).size()
	for ph in tx["phases"]:
		lines += ph["start"].size() + ph["end"].size()
	for tk in tx["ticklers"].values():
		lines += tk["first"].size()
	var reacts := 0
	for tier in tx["react"].values():
		reacts += tier.size()
	check("扶梯子台词 %d 句、反应字 %d 条（三档）" % [lines, reacts], lines >= 60 and reacts >= 36 and tx["react"].size() == 3)
	await _run_ladder()
	await _run_goats()
	await _run_massage()
	await _run_dance()


func _run_ladder() -> void:
	var h0 := PenanceBook.hours()
	LadderShow.quiet = true
	await _talk("floor_06/after_engineer", "errand_ladder", [0])
	await _wait(0.2)
	check("接下扶梯子：目标是脚手架房子底下", AfterErrands.active() == "ladder" and _node("Errand_ladder") != null)
	_go(Cells.to_world([24, 10]))
	await _advance_until(func(): return _show(LadderShow) != null, 3.0)
	var ls := _show(LadderShow) as LadderShow
	check("走到梯子底下：开演扶梯子小游戏", ls != null and ls.phase == 0 and ls.prompt == "UP")
	await _wait(0.4)
	check("小游戏开着时：人物不能动、按 E 不会和别人说话（对话锁 %d）" % GameState.dialogue_holds, GameState.in_dialogue and GameState.dialogue_holds > 0)
	if ls == null:
		return
	ls._tk_t = 99.0
	ls.balance = 0.0
	var l0 := GameState.player.laugh.value
	await ls._tickle_once()
	check("被挠一下：平衡猛地偏过去（%.2f）、闷笑上涨" % ls.balance, absf(ls.balance) > 0.3 and GameState.player.laugh.value > l0)
	ls.balance = 0.0
	ls.press("A")
	check("← 往回拨平衡（%.2f）" % ls.balance, ls.balance < -0.1)
	ls.balance = 0.9
	ls.press("UP")
	check("偏得太厉害时干活不算", ls.step == 0)
	ls.balance = 0.0
	ls.press("UP")
	ls.press("UP")
	ls.balance = 1.1
	ls._tk_t = 99.0
	ls._tick(0.01)
	await _wait(0.1)
	check("平衡到头：摔进干草堆（%d 次），这一段从头来（%d 步）" % [ls.falls, ls.step], ls.falls == 1 and ls.step == 0)
	var g := 0
	while not ls._done and g < 200:
		ls.balance = 0.0
		ls._tk_t = 99.0
		ls.press(ls.prompt)
		await get_tree().process_frame
		g += 1
	await _advance_until(func(): return AfterErrands.is_done("ladder") and not Dialogue.is_active(), 10.0)
	check("爬上去 → 修屋檐（10 下）→ 下梯子 → 委托完成、减 3 工时（%d → %d）" % [h0, PenanceBook.hours()],
		AfterErrands.is_done("ladder") and PenanceBook.hours() == h0 - 3)
	LadderShow.quiet = false
	GameState.player.laugh.clear()


func _run_goats() -> void:
	ErrandGoats.quiet = true
	await _talk("floor_06/after_maid", "errand_goats", [0])
	await _wait(0.3)
	var r := _node("Errand_goats") as ErrandGoats
	var goats: Array = main.level.find_children("*", "MushroomGoat", true, false)
	check("接下赶羊：镇上 5 只蘑菇羊、小羊羔叼着鞋在跑（%d 只）" % goats.size(),
		AfterErrands.active() == "goats" and r != null and goats.size() == 5 and r.goats["mimi"].mode == MushroomGoat.Mode.FLEE)
	if r == null:
		return
	var p := GameState.player
	var lamb: MushroomGoat = r.goats["mimi"]
	_go(lamb.global_position)
	await _advance_until(func(): return r.phase == "lead", 3.0)
	check("追上小羊羔：拿回鞋（湿透了只好光脚），咩咩跟上来", r.phase == "lead" and r.followers.size() == 1)
	var dudu: MushroomGoat = r.goats["dudu"]
	dudu.global_position = p.global_position + Vector2(12, 0)
	dudu.set_home(dudu.global_position)
	await _wait(0.4)
	check("抱着盐块走近贪吃的嘟嘟：跟上来（跟着 %d 只）" % r.followers.size(), dudu in r.followers)
	var l0 := p.laugh.value
	var n0: int = r.licks_done
	await _wait(1.8)
	check("站着不动：跟着的羊追上来舔（舔了 %d 下，闷笑 %.0f → %.0f）" % [r.licks_done - n0, l0, p.laugh.value], r.licks_done > n0 and p.laugh.value > l0)
	var lulu: MushroomGoat = r.goats["lulu"]
	lulu.global_position = p.global_position + Vector2(-34, 0)
	lulu.set_home(lulu.global_position)
	await _wait(1.6)
	check("怕生的噜噜：站着不动等它过来才跟", lulu in r.followers)
	var home := p.global_position
	_go(home + Vector2(-320, 0))
	await _wait(0.2)
	check("走太快（离得太远）：羊不跟了（跟着 %d 只）" % r.followers.size(), r.followers.is_empty())
	_go(home)
	for id in r._cd:
		r._cd[id] = 0.0
	p.laugh.set_value(p.laugh.max_value * 0.96)
	for id in ["mimi", "dudu"]:
		var gg: MushroomGoat = r.goats[id]
		gg.global_position = p.global_position + Vector2(10, 4)
		gg.set_home(gg.global_position)
	await _wait(0.3)
	check("闷笑满：绊倒、盐块掉了", r.trips >= 1 and not r.has_salt and is_instance_valid(r.salt))
	_go(r.salt.global_position)
	await _wait(0.2)
	check("捡回盐块：接着赶", r.has_salt)
	p.laugh.clear()
	for id in r.goats:
		r._cd[id] = 0.0
		var gg: MushroomGoat = r.goats[id]
		if gg not in r.followers:
			gg.global_position = p.global_position + Vector2(randf_range(-14, 14), 12)
			gg.set_home(gg.global_position)
	await _wait(1.5)
	check("五只都跟上了（%d）" % r.followers.size(), r.followers.size() == 5)
	var h0 := PenanceBook.hours()
	var gate := Cells.to_world(r.PEN_GATE)
	_go(gate)
	for gg in r.followers:
		gg.global_position = gate + Vector2(randf_range(-10, 10), 8)
	await _advance_until(func(): return AfterErrands.is_done("goats") and not Dialogue.is_active(), 8.0)
	check("带到羊圈门口：五只进圈 → 门口的「谢礼」→ 委托完成（%d → %d）" % [h0, PenanceBook.hours()],
		AfterErrands.is_done("goats") and PenanceBook.hours() == h0 - 3)
	ErrandGoats.quiet = false
	p.laugh.clear()


func _run_massage() -> void:
	MassageShow.quiet = true
	await _talk("floor_06/after_bonfire_host", "errand_massage", [0])
	await _wait(0.2)
	check("派对主人先给足底按摩的委托", AfterErrands.active() == "massage")
	_go(Cells.to_world([41, 27]))
	await _advance_until(func(): return _show(MassageShow) != null, 3.0)
	var ms := _show(MassageShow) as MassageShow
	if ms == null:
		check("开演足底按摩", false)
		return
	ms.cursor = 0.58
	ms._pressed = false
	ms.press("J")
	check("指针在绿区按 J：忍住了（%d）" % ms.held, ms.held == 1)
	for i in 3:
		ms.cursor = 0.02
		ms._pressed = false
		ms.press("J")
		await get_tree().process_frame
	await _wait(0.1)
	check("没按准踢中三次：「重来！」这一式从头来（重来 %d 次）" % ms.redos, ms.redos == 1 and ms.held == 0 and ms.kicks == 0)
	var g := 0
	while not ms._done and g < 300:
		ms.cursor = 0.58
		ms._dir = 1.0
		ms._pressed = false
		ms.press("J")
		await get_tree().process_frame
		g += 1
	await _advance_until(func(): return AfterErrands.is_done("massage") and not Dialogue.is_active(), 10.0)
	check("六式按完：委托完成、疲倦清空、加「脚底轻快」",
		AfterErrands.is_done("massage") and GameState.player.buffs.has(MassageShow.BUFF) and GameState.player.fatigue.value < 0.01)
	MassageShow.quiet = false
	GameState.player.laugh.clear()


func _run_dance() -> void:
	DanceShow.quiet = true
	await _talk("floor_06/after_bonfire_host", "errand_dance", [0])
	await _wait(0.2)
	check("再找派对主人：篝火舞会排练", AfterErrands.active() == "dance")
	_go(Cells.to_world([44, 26]))
	await _advance_until(func(): return _show(DanceShow) != null, 3.0)
	var ds := _show(DanceShow) as DanceShow
	if ds == null:
		check("开演篝火舞会", false)
		return
	check("先教学四拍", ds.tutorial and ds.lane.chart.size() == 4)
	var lane: RhythmLane = ds.lane
	var n0: Dictionary = lane.chart[0]
	lane.time = float(n0["t"])
	ds.press(str(n0["key"]))
	check("音符滑到判定圈时按对的键：完美", int(lane.counts["perfect"]) == 1)
	await _autoplay(ds, func(): return not ds.tutorial)
	check("教学完 → 第一段双人舞（%d 个音符）" % lane.chart.size(), ds.section == 0 and lane.chart.size() == 16)
	var l0 := GameState.player.laugh.value
	var n1: Dictionary = lane.chart[0]
	lane.time = float(n1["t"])
	var wrong := "LEFT" if str(n1["key"]) != "LEFT" else "RIGHT"
	ds.press(wrong)
	check("按错键：失误，舞伴挠腰（闷笑 %.0f → %.0f）" % [l0, GameState.player.laugh.value], ds.misses == 1 and GameState.player.laugh.value > l0)
	ds.add_laugh(ds.laugh_max())
	await _wait(0.2)
	check("闷笑满：脚下一绊，这一段重跳（%d）" % ds.stumbles, ds.stumbles == 1 and lane._next == 0)
	await _autoplay(ds, func(): return ds._done)
	var score := [ds.total, ds.total_max, ds.section]
	await _advance_until(func(): return AfterErrands.is_done("dance") and not Dialogue.is_active(), 10.0)
	check("三段跳完（第 %d 段，总分 %d / %d）→ 委托完成" % [score[2] + 1, score[0], score[1]], AfterErrands.is_done("dance") and score[2] == 2)
	DanceShow.quiet = false
	GameState.player.laugh.clear()


## 自动按准每一个音符，直到 cond 成立
func _autoplay(ds: DanceShow, cond: Callable) -> void:
	var g := 0
	while not cond.call() and g < 600:
		var lane: RhythmLane = ds.lane
		ds._scarf_t = 99.0
		if not lane.finished():
			var n: Dictionary = lane.chart[lane._next]
			lane.time = float(n["t"])
			ds.press(str(n["key"]))
		else:
			lane.time = lane.end_time() + 0.01
		await get_tree().process_frame
		g += 1


# ------------------------------------------------------------------ 第 5 天早上：裁缝找漏风
func _run_tailor() -> void:
	print("-- 弥补任务：裁缝的试衣模特·找漏风")
	await _sleep_night()
	check("睡到第 5 天早上", DayClock.day() == 5 and DayClock.slot() == DayClock.MORNING)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	var mk := _node("Objective") as ObjectiveMarker
	check("目标：去裁缝铺（标记在北边最右边的房子门口）", mk.text.contains("裁缝") and mk.global_position.distance_to(Cells.to_world([32, 10])) < 2.0)
	var tx := TaskTailor.data()
	var n := (tx["measure"] as Array).size() + (tx["tutorial"] as Array).size() + (tx["inspect_intro"] as Array).size() + (tx["inspect_pass"] as Array).size()
	var reacts := 0
	for pid in tx["parts"]:
		var pt: Dictionary = tx["parts"][pid]
		n += pt["intro"].size() + pt["end"].size() + pt["check"].size()
		for k in pt["react"]:
			reacts += pt["react"][k].size()
	check("找漏风台词 %d 句、试点反应 %d 条" % [n, reacts], n >= 60 and reacts >= 36)
	# 第一次：腋下全标错（「仔细检查」挠到笑满）→ 失败 → 重来
	GameState.vars["task_tailor_leaks"] = {"armpit": [1], "waist": [0, 2], "sole": [1, 2]}
	TaskTailor.auto_marks = {"armpit": [0, 2, 3]}
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_tailor"))
	await _wait(0.8)
	_go(Cells.to_world([9, 7]))
	await _advance_until(func(): return GameState.has_flag("cg_seen_theater:after_fail_tailor") and not CG.is_busy() and _node("Task_d5_tailor") != null, 90.0)
	check("腋下标错三个点：「仔细检查」挠到笑满 → 全身尺码复查的失败小剧场 → 重来（量尺寸不再量）",
		GameState.has_flag("cg_seen_theater:after_fail_tailor") and bool(GameState.vars.get("task_tailor_measured", false)) and seen_cuts.has("after_d5_tailor"))
	# 第二次：腰只缝一个 → 验收时第二个人台挠腰 → 回去补 → 验收通过
	TaskTailor.auto_marks = {"armpit": "leaks", "waist": "one", "sole": "leaks"}
	await _advance_until(func(): return _node("Mannequin_waist") != null and not Dialogue.is_active(), 90.0)
	var task := _node("Task_d5_tailor") as TaskTailor
	check("三个部位找完 → 验收：摆出三个羽毛人台（腰还漏 %d 个）" % TaskTailor.open_leaks("waist").size(),
		task != null and task.stage == "inspect" and TaskTailor.open_leaks("waist").size() == 1 and TaskTailor.open_leaks("armpit").is_empty())
	for id in ["armpit", "waist"]:
		_go((_node("Mannequin_" + id) as Node2D).global_position)
		await _wait(0.2)
	await _advance_until(func(): return not is_instance_valid(task) or task.stage == "waist", 10.0)
	check("走过第二个人台：腰还漏着 → 被挠、回去重找腰", is_instance_valid(task) and task.stage == "waist")
	await _advance_until(func(): return not is_instance_valid(task) or (task.stage == "inspect" and not Dialogue.is_active()), 60.0)
	check("补好腰 → 再验收（没有中途笑到失败）", is_instance_valid(task) and task.stage == "inspect")
	if not is_instance_valid(task):
		return
	for id in ["armpit", "waist", "sole"]:
		_go((_node("Mannequin_" + id) as Node2D).global_position)
		await _wait(0.2)
	_go(Cells.to_world(TaskTailor.MIRROR))
	await _advance_until(func(): return DayClock.done(5, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing, 60.0)
	TaskTailor.auto_marks = {}
	check("全缝好 → 一点都不痒的验收 → 得到防痒棉衣 → 到下午",
		GameState.inventory.count("equip_tailor_coat") >= 1 and DayClock.slot() == DayClock.AFTERNOON and seen_cuts.has("after_d5_tailor_done"))
	var coat := ItemDB.get_item("equip_tailor_coat") as EquipData
	check("防痒棉衣占腋下 / 腰 / 脚心三格、各挡 2 次", coat != null and coat.slots.size() == 3 and int(coat.block.get("sole", 0)) == 2)
	GameState.player.laugh.clear()


# ------------------------------------------------------------------ 第 5 天下午：矿车护送
func _run_mine() -> void:
	print("-- 弥补任务：矿车护送·双人轨道")
	GameState.pending_spawn = "from_tailor"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	check("第 5 天下午：矿道门开了、目标是矿道口", GameState.has_flag(AfterStory.MINE_OPEN) and (_node("Objective") as ObjectiveMarker).text.contains("矿道"))
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_mine"))
	await _advance_until(func(): return _node("Task_d5_mine") != null and (_node("Task_d5_mine") as TaskMine).started and not GameState.in_dialogue, 40.0)
	await _wait(0.1)
	var task := _node("Task_d5_mine") as TaskMine
	check("进矿道 → 老矿工的过场 → 任务开始（矿车在起点、蓝色公主坐在车上）",
		task != null and seen_cuts.has("after_d5_mine") and task._blue != null and task._blue.global_position.distance_to(task.cart.global_position) < 10.0)
	if task == null:
		return
	var p := GameState.player
	var x0 := task.cart_x
	task.push(1.0)
	check("推一秒：车往前走（%.0f → %.0f）" % [x0, task.cart_x], task.cart_x > x0 + 30.0)
	_go(Vector2(task.cart_x + 4.0, task.rail_y()))
	await get_tree().process_frame
	await get_tree().process_frame
	check("人过不去车（被挡在车后面）", p.global_position.x <= task.cart_x - 11.0)
	# 冰封模式：冻住前方的喷口
	task.cart_x = Cells.to_world(Vector2i(16, 0)).x
	await _advance_until(func(): return task.stage == 1 and not task._busy and not GameState.in_dialogue, 10.0)
	check("车进喷口段：两人的对话（第 %d 段）" % task.stage, task.stage == 1)
	task.toggle_freeze()
	var n := task.cast_freeze()
	var froze: Array = get_tree().get_nodes_in_group("trap").filter(func(t): return task.is_frozen(t))
	check("C 换成蓝色公主、J 冻住前方的陷阱（%d 个），陷阱停了" % n, task.freeze_mode and n >= 1 and froze.all(func(t): return not t.active))
	await _wait(TaskMine.FREEZE_TIME + 0.3)
	check("冻了几秒以后陷阱恢复", froze.all(func(t): return t.active))
	task.toggle_freeze()
	# 笑满：车溜回检查点
	task.cart_x = Cells.to_world(Vector2i(30, 0)).x
	p.laugh.set_value(p.laugh.max_value * 0.96)
	await _advance_until(func(): return task.slips == 1 and not task._busy and not GameState.in_dialogue, 10.0)
	var tc := TickleCloud.new()
	main.level.get_node("Entities").add_child(tc)
	tc.global_position = task._blue.global_position
	await _wait(1.2)
	check("陷阱打到车上的蓝色公主：她也会被挠（%d 次）" % task.blue_hits, task.blue_hits >= 1)
	tc.queue_free()
	check("闷笑满：车溜回这一段的起点（%.1f 格）" % task.cell_x(), task.slips == 1 and absf(task.cell_x() - TaskMine.STAGES[1]) < 0.6)
	# 上坡：小鬼跳上车
	task.cart_x = Cells.to_world(Vector2i(TaskMine.SLOPE_X + 2, 0)).x
	await _advance_until(func(): return task.stage == 3 and not task._busy and not GameState.in_dialogue, 20.0)
	check("车到了上坡段（第 %d 段）" % task.stage, task.stage == 3)
	var xs := task.cart_x
	await _wait(0.5)
	check("上坡不推：车往回溜（%.0f → %.0f）" % [xs, task.cart_x], task.cart_x < xs)
	var pw := task._power()
	var imp := task.spawn_imp()
	await _advance_until(func(): return imp.on_cart, 6.0)
	check("小鬼跳上车：推得更慢（力气 %.2f → %.2f）" % [pw, task._power()], imp.on_cart and task._power() < pw)
	_go(task.cart.global_position + Vector2(-16, 0))
	check("车旁边按 J：把小鬼拍下去", task.swat() and task.imps_swatted == 1)
	xs = task.cart_x
	task.tap()
	check("连按 →：车往上推一下", task.cart_x > xs)
	# 溜三次 = 失败
	task.slips = 2
	GameState.vars["task_mine_slips"] = 2
	p.laugh.set_value(p.laugh.max_value * 0.96)
	await _advance_until(func(): return GameState.has_flag("cg_seen_theater:after_fail_mine") and not CG.is_busy() and _node("Task_d5_mine") != null, 90.0)
	task = _node("Task_d5_mine") as TaskMine
	check("溜回去第三次：翻车进刷子堆的失败小剧场 → 回到起点重来（溜车次数清零）",
		GameState.has_flag("cg_seen_theater:after_fail_mine") and task != null and task.slips == 0 and task.cell_x() < 10.0)
	p = GameState.player
	p.laugh.clear()
	task.cart_x = Cells.to_world(Vector2i(TaskMine.GOAL_X + 1, 0)).x
	await _advance_until(func(): return DayClock.done(5, DayClock.AFTERNOON) and not Cutscene.is_playing() and not DayClock.passing, 60.0)
	check("送到矿工营地 → 旧门的传闻 → 天黑", seen_cuts.has("after_d5_mine_done") and DayClock.slot() == DayClock.NIGHT)


# ------------------------------------------------------------------ 第 5 天夜里：小汤姆的恶作剧
func _run_tom() -> void:
	print("-- 第 5 天夜里：小汤姆的恶作剧")
	var tx := TomPrankShow.text()
	check("恶作剧四段（观察 / 轻挠 / 橘子上场 / 一起来），脚趾缝有「又痒又舒服」的挠法",
		(tx["phases"] as Array).size() == 4 and (tx["phases"][1]["options"] as Array).any(func(o): return o.get("special", false)))
	TomPrankShow.quiet = true
	TomPrankShow.auto_picks = [1, 4, 4, 4, 4, 3, 3, 3]
	TomPrankShow.auto_release = "intensify"
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _advance_until(func(): return DayClock.day() == 6 and not Sleep.sleeping and not DayClock.passing, 60.0)
	check("进小屋 → 扮演小汤姆：一直揉脚趾缝 + 橘子打呼噜，舒服满了魔力释放 → 加大强度 → 姐姐笑晕都没发现（%s）→ 睡到第 6 天" % str(GameState.vars.get("tom_prank_result", "")),
		str(GameState.vars.get("tom_prank_result", "")) == "fainted" and GameState.has_flag("tom_prank_fainted") and DayClock.day() == 6)
	# 痒满了 = 笑醒被抓（直接测小游戏）
	TomPrankShow.auto_picks = [2, 2, 2, 2, 2, 2]
	TomPrankShow.auto_release = ""
	var sh := TomPrankShow.new()
	add_child(sh)
	var r := {}
	(func(): r["v"] = await sh.play()).call()
	await _advance_until(func(): return r.has("v"), 10.0)
	check("一直挠前脚掌：痒满了，姐姐笑醒、被抓个正着（%s）" % str(r.get("v", "")), str(r.get("v", "")) == "caught")
	sh.queue_free()
	GameState.set_flag("tom_prank_caught", false)
	GameState.set_flag("tom_prank_fainted")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/after_kid_tom.json"))
	check("第 6 天小汤姆的话按结局变（笑晕 / 安静 / 被抓三套）", d["nodes"].has("tom_prank_fainted") and d["nodes"].has("tom_prank_quiet") and d["nodes"].has("tom_prank_caught"))
	TomPrankShow.quiet = false
	TomPrankShow.auto_picks = []


# ------------------------------------------------------------------ 第 6 天早上：陷阱验收
func _run_inspect() -> void:
	print("-- 弥补任务：陷阱验收")
	if DayClock.day() < 6:
		await _sleep_night()
	check("第 6 天早上：陷阱验收", DayClock.day() == 6 and DayClock.event() == "d6_inspect")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	var mk := _node("Objective") as ObjectiveMarker
	check("目标：东边的训练营（开了）", mk.text.contains("训练营") and GameState.has_flag(AfterStory.PROVING_OPEN))
	GameState.vars.erase("task_inspect_rates")
	GameState.vars.erase("task_inspect_tune")
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_proving"))
	await _advance_until(func(): return _node("Task_d6_inspect") != null and (_node("Task_d6_inspect") as TaskInspect).started and not GameState.in_dialogue, 40.0)
	var task := _node("Task_d6_inspect") as TaskInspect
	check("进训练营 → 队员讲规矩的过场 → 五个陷阱踏板 + 三个辅助设施", task != null and seen_cuts.has("after_d6_inspect") and task._pads.size() == 8)
	if task == null:
		return
	var tx := TaskInspect.data()
	check("五个挠痒陷阱（羽毛帘 / 地洞挠挠手 / 脚趾分隔刷 / 单脚吊环架 / 跪台）、三个辅助设施，各有开场和挠法描写",
		tx["stations"].size() == 5 and tx["aux"].size() == 3 and tx["stations"].values().all(func(s): return s["intro"].size() >= 3 and s["cap"].size() >= 3))
	task.use_aux("soak")
	await _advance_until(func(): return task.statuses.has("soaked") and not task._busy and not GameState.in_dialogue, 10.0)
	check("泡脚盆：舒服、留下「泡软」（挠痒 ×%.1f）" % task.status_mul(), task.statuses.has("soaked") and task.status_mul() > 1.4)
	task.use_aux("cool")
	await _advance_until(func(): return task.statuses.has("cooled") and not task._busy and not GameState.in_dialogue, 10.0)
	check("冷敷石板：清掉别的状态、敏感降低（×%.1f）" % task.status_mul(), not task.statuses.has("soaked") and task.status_mul() < 1.0)
	# 体验：吊环架真的会挠（不自动挣开）
	var p := GameState.player
	p.laugh.clear()
	var sh := InspectShow.new()
	add_child(sh)
	var res := {}
	(func(): res.merge(await sh.play_station("toes", tx["stations"]["toes"], 1.5, 1.0, true))).call()
	await _wait(1.5)
	check("脚趾分隔刷：被夹住刷趾缝、闷笑上涨（%.0f%%）" % (p.laugh.ratio() * 100.0), p.laugh.value > 0.0 and sh.grabbed)
	for i in InspectShow.ESC_TOES:
		sh.press("J")
	await _advance_until(func(): return not res.is_empty(), 5.0)
	check("连按 J 挣开：返回刚才涨了多少（%.0f%%）" % (float(res.get("gain", 0.0)) * 100.0), bool(res.get("escaped", false)) and float(res.get("gain", 0.0)) > 0.0)
	sh.queue_free()
	p.laugh.set_value(p.laugh.max_value * 0.97)
	var sh2 := InspectShow.new()
	add_child(sh2)
	var res2 := {}
	(func(): res2.merge(await sh2.play_station("kneel", tx["stations"]["kneel"], 1.0, 1.3, true))).call()
	await _advance_until(func(): return not res2.is_empty(), 8.0)
	check("综合演练里笑满：算笑倒（任务判失败 → 失败小剧场 + CG）", bool(res2.get("laughed_out", false)))
	# 魔力疲倦：被挠时跟着涨；满了自动释放、闷笑降一半
	p.laugh.set_value(p.laugh.max_value * 0.4)
	if p.fatigue:
		p.fatigue.clear()
	var sh3 := InspectShow.new()
	add_child(sh3)
	var res3 := {}
	(func(): res3.merge(await sh3.play_station("toes", tx["stations"]["toes"], 1.0, 1.0, true))).call()
	await _advance_until(func(): return sh3.playing, 3.0)
	var fa0 := p.fatigue.value if p.fatigue else 0.0
	await _advance_until(func(): return p.fatigue and p.fatigue.value > fa0 + 1.0, 3.0)
	check("陷阱验收：被挠的时候魔力疲倦跟着涨（%.1f → %.1f）" % [fa0, p.fatigue.value if p.fatigue else -1.0], p.fatigue and p.fatigue.value > fa0)
	var lh := p.laugh.value
	sh3._punish("fatigue")
	check("魔力满：自动释放、清空魔力、闷笑降一半（%.0f → %.0f）" % [lh, p.laugh.value], sh3.bursts == 1 and p.laugh.value <= lh * 0.55 and (p.fatigue == null or p.fatigue.value == 0.0))
	sh3._done = true
	await _advance_until(func(): return not res3.is_empty(), 5.0)
	sh3.queue_free()
	sh2.queue_free()
	p.laugh.clear()
	# 第十一轮：体验陷阱时笑满 → 任务失败 → 失败小剧场（CG）→ 任务重来（评过的记着）
	GameState.set_flag("cg_seen_theater:after_fail_inspect", false)
	InspectShow.auto_escape = false
	p.laugh.set_value(p.laugh.max_value * 0.97)
	task.run_station("toes")
	await _advance_until(func(): return GameState.has_flag("cg_seen_theater:after_fail_inspect") and not CG.is_busy() and not Dialogue.is_active(), 90.0)
	check("体验陷阱时笑满：失败小剧场 + CG（after_fail_inspect）", GameState.has_flag("cg_seen_theater:after_fail_inspect"))
	await _advance_until(func(): return _node("Task_d6_inspect") != null and _node("Task_d6_inspect") != task and (_node("Task_d6_inspect") as TaskInspect).started and not GameState.in_dialogue, 40.0)
	task = _node("Task_d6_inspect") as TaskInspect
	check("失败以后任务重来（闷笑清空）", task != null and GameState.player.laugh.value < GameState.player.laugh.max_value * 0.1)
	if task == null:
		return
	p = GameState.player
	# 评分：评对 / 评「太弱」加强 / 评「太强」再体验一次
	InspectShow.auto_escape = true
	TaskInspect.auto_rate = {"curtain": "weak", "holes": "weak", "toes": "strong", "hoist": "ok", "kneel": ["strong", "ok"]}
	for id in TaskInspect.ORDER:
		if id == "kneel":
			break
		task.run_station(id)
		await _advance_until(func(): return task.rated.has(id) and not task._busy and not GameState.in_dialogue, 20.0)
	check("评对的原样、评「太弱」的被加强（地洞 ×%.1f）、评错成「刚好」的按真实情况调（吊环 ×%.1f）" % [task.tune["holes"], task.tune["hoist"]],
		task.tune["curtain"] == 1.0 and task.tune["holes"] > 1.0 and task.tune["toes"] == 1.0 and task.tune["hoist"] < 1.0)
	task.run_station("kneel")
	await _advance_until(func(): return DayClock.done(6, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing, 90.0)
	check("跪台评「太强」→ 队长让再体验一次（%d）→ 五个都评完 → 综合演练 → 收尾 → 下午" % task.extra_runs if is_instance_valid(task) else "收尾",
		seen_cuts.has("after_d6_inspect_done") and DayClock.slot() == DayClock.AFTERNOON)
	InspectShow.auto_escape = false
	TaskInspect.auto_rate = {}
	GameState.player.laugh.clear()


# ------------------------------------------------------------------ 第 6 天下午：特训第三课 + 考核
func _run_drill2() -> void:
	print("-- 蓝色公主的特训：第三课 借手、考核、学会技能")
	DrillShow.quiet = true
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_drill"))
	await _wait(0.8)
	_go(Cells.to_world([10, 7]))
	await _advance_until(func(): return _node("Task_d6_drill") != null and (_node("Task_d6_drill") as TaskDrill).show is PantsHandShow, 30.0)
	var task := _node("Task_d6_drill") as TaskDrill
	check("第 6 天：特训第三课「借手」（换成蓝色公主、小游戏画面）", task != null and GameState.player.character_id == "blue" and task.show is PantsHandShow)
	if task == null:
		return
	var hs := task.show as PantsHandShow
	await _wait(0.2)
	hs.event_id = "feather_l"
	hs.left = 1.0
	hs.press("LEFT")
	check("羽毛从左边飞来 → ← 让小手挡掉（处理 %d）" % hs.handled, hs.handled == 1)
	hs.event_id = "lever_r"
	hs.left = 1.0
	hs.press("D")
	hs.event_id = "sneak"
	hs.left = 1.0
	hs.press("DOWN")
	check("拉杆（D）、抓住背后偷袭的粉色公主（↓）", hs.handled == 3)
	hs.event_id = "feather_u"
	hs.left = 1.0
	hs.press("LEFT")
	check("按错方向：漏掉、被挠", hs.missed == 1)
	hs.obedience = 5.0
	hs.event_id = "feather_r"
	hs.left = 1.0
	hs.press("RIGHT")
	check("听话度太低时下指令：小手造反", hs.rebels == 1)
	hs.handled = hs.goal()
	await _advance_until(func(): return task.show is DrillExamShow, 15.0)
	check("处理够了 → 第三课过关 → 考核开始", task.show is DrillExamShow)
	var ex := task.show as DrillExamShow
	await _wait(0.2)
	ex.order_guard()
	ex._strike("lthigh", "pink")
	check("J 指挥小手挡下粉色公主的一下", ex.blocks == 1 and not ex.guard)
	ex.burst()
	await _wait(0.2)
	check("U 千手解放：把她推开、之后小手挠自己", ex.bursts == 1 and ex.pushed_t > 0.0 and ex.backlash_t > 0.0)
	ex.time_left = 0.05
	await _advance_until(func(): return DayClock.done(6, DayClock.AFTERNOON) and not Cutscene.is_playing() and not DayClock.passing, 40.0)
	check("撑过时间 → 及格 → 学会「冰封自制」和「千手解放」→ 第七天前夜的过场 → 天黑",
		GameState.has_flag("drill_exam_passed") and PantsBurst.learned() and GameState.passives.has("ice_composure")
		and seen_cuts.has("after_d6_drill_done") and DayClock.slot() == DayClock.NIGHT)
	DrillShow.quiet = false
	# 技能：战斗里也能用
	var b := main.level.find_child("AfterBlue", true, false) as PlayableCharacter
	if b == null:
		for n in main.level.find_children("*", "PlayableCharacter", true, false):
			if (n as PlayableCharacter).character_id == "blue":
				b = n
	var slime := (load("res://scenes/actors/monsters/slime.tscn") as PackedScene).instantiate() as Monster
	main.level.get_node("Entities").add_child(slime)
	slime.global_position = b.global_position + Vector2(30, 0)
	await _wait(0.2)
	var cast_ok := PantsBurst.cast(b)
	await get_tree().process_frame
	check("千手解放：放出来了（%s）、附近的怪定身（%s）、她自己挂上「小手收不回来」（%s）" % [cast_ok, slime.is_stunned(), b.buffs.has("pants_backlash")],
		cast_ok and b.buffs.has("pants_backlash") and slime.is_stunned())
	check("冷却中再放不出来", not PantsBurst.cast(b))
	slime.queue_free()
	check("冰封自制：蓝色公主的闷笑涨幅降低（laugh_gain %.2f）" % b.stat_add("laugh_gain"), b.stat_add("laugh_gain") <= -0.09)


# ------------------------------------------------------------------ 第 7 天：修补狂欢图腾柱
func _rest_to_next() -> void:
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _wait(0.4)
	var s := DayClock.slot()
	await _talk("floor_06/after_house_objects", "bed", [0])
	await _advance_until(func(): return DayClock.slot() != s and not DayClock.passing, 15.0)


func _run_totem() -> void:
	print("-- 弥补任务：修补狂欢图腾柱（图腾共鸣·双人符文）")
	await _sleep_night()
	check("睡到第 7 天早上", DayClock.day() == 7 and DayClock.slot() == DayClock.MORNING)
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(1.0)
	var mk := _node("Objective") as ObjectiveMarker
	check("目标：去图腾柱废地（西边的小路开了）", mk.text.contains("图腾") and GameState.has_flag(AfterStory.TOTEM_OPEN)
		and mk.global_position.distance_to(Cells.to_world([3, 32])) < 2.0)
	GameState.vars[TotemResonanceShow.SAVE_KEY] = 0
	GameState.vars[TotemResonanceShow.CRACK_KEY] = 0
	TotemResonanceShow.quiet = true
	var spec := preload("res://tests/helpers/f6_totem.gd")
	var s: TotemResonanceShow = await spec.start(self)
	check("进废地 → 镇长和工匠讲笑声刻符文的过场 → 双人符文开演", s != null and seen_cuts.has("after_d7_totem"))
	if s == null:
		return
	var hours := PenanceBook.hours()
	for i in 3:
		await spec.solve_rune(self, s)
	await _advance_until(func(): return DayClock.done(7, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and not AfterStory.running, 60.0)
	TotemResonanceShow.quiet = false
	check("三道符文刻好 → 图腾柱扶正 → 减 20 工时（%d → %d）→ 晚上有庆功宴：天黑（%s）" % [hours, PenanceBook.hours(), DayClock.label()],
		seen_cuts.has("after_d7_totem_done") and PenanceBook.hours() == maxi(0, hours - 20) and DayClock.day() == 7 and DayClock.slot() == DayClock.NIGHT)


# ------------------------------------------------------------------ 晚上的弥补任务
## 晚上：走到委托人那里（目标圈）开始任务
func _night_start(level: String, spawn: String, cell: Array, task_name: String) -> Node:
	GameState.pending_spawn = spawn
	await main.change_level(Floors.scene(level))
	await _wait(1.0)
	check("夜里镇上还有事：门没锁（宵禁）、床不让睡", not GameState.has_flag(AfterStory.CURFEW))
	_go(Cells.to_world(cell))
	await _advance_until(func(): return _node(task_name) != null and bool(_node(task_name).get("started")) and not GameState.in_dialogue, 40.0)
	return _node(task_name)


func _run_sweep() -> void:
	print("-- 第 2 天晚上：面包店奶奶的羽毛大扫除")
	check("第 2 天晚上：要帮奶奶扫羽毛", DayClock.day() == 2 and DayClock.slot() == DayClock.NIGHT and DayClock.event() == "d2_sweep")
	GameState.vars.erase("task_sweep_left")
	var task := await _night_start("floor_06_after", "from_house", [45, 13], "Task_d2_sweep") as TaskSweep
	check("走到烤炉后院 → 奶奶的开场 → 六堆羽毛", task != null and task.piles.size() == 6)
	if task == null:
		return
	var p := GameState.player
	check("羽毛堆画在地面上面（z_index %d）、两处屋檐下的避风处" % task.piles[0].z_index, task.piles[0].z_index >= 1 and task.shelters.size() == 2)
	check("扫的时候不再占着两只手（能闪避）", not p.has_meta(&"busy_hands"))
	_go(Cells.to_world(TaskSweep.SHELTERS[0]))
	var f00 := task.feet
	task.gust_now()
	check("起风时躲在屋檐下：一根羽毛也没沾上", task.feet == f00)
	_go(Cells.to_world(TaskSweep.PILES[0]) + Vector2(0, 30))
	task.gust_now()
	check("起风时站在外面：羽毛钻进脚趾缝（%d 根）" % task.feet, task.feet >= 2)
	var f0 := task.feet
	task.shake()
	check("脚上的羽毛自己掉一根（不用按键）", task.feet == f0 - 1)
	for pl in task.piles:
		_go(pl.global_position)
		task.sweep(4.0)
	await _advance_until(func(): return DayClock.day() == 3 and not Sleep.sleeping and not DayClock.passing, 60.0)
	check("六堆都扫光 → 最后一阵风（整袋羽毛扑在身上）→ 回小屋睡到第 3 天", DayClock.day() == 3 and DayClock.slot() == DayClock.MORNING)
	p = GameState.player
	if p.laugh:
		p.laugh.clear()


func _run_mice() -> void:
	print("-- 第 3 天晚上：药剂师奶奶的逃跑的痒痒鼠")
	MouseShow.quiet = true
	check("第 3 天晚上：痒痒鼠", DayClock.slot() == DayClock.NIGHT and DayClock.event() == "d3_mice")
	await _night_start("floor_06_after_pharmacy", "from_town", [8, 6], "Task_d3_mice")
	await _advance_until(func(): return _show(MouseShow) != null, 10.0)
	var ms := _show(MouseShow) as MouseShow
	check("工房里 → 五只小鼠钻进衣服", ms != null and ms.mice.size() == 5)
	if ms == null:
		return
	ms.mice = ["waist", "waist", "shoe", "armpit", "knee"]
	ms.press("E")
	check("小鼠在腰上 → 按 E 拍住一只", ms.caught == 1)
	ms.press("Q")
	check("袖子里没有 → 拍空、拍到自己", ms.misses == 1)
	ms.press("E")
	ms.press("D")
	ms.press("W")
	await _wait(0.2)
	check("抓到四只 → 最后一只钻进鞋里", ms.last_phase)
	for i in MouseShow.LAST_MASH:
		ms.press("D")
	await _advance_until(func(): return DayClock.day() == 4 and not Sleep.sleeping and not DayClock.passing, 60.0)
	check("连按 D 抖出来 → 五只都进笼子 → 睡到第 4 天", DayClock.day() == 4 and DayClock.slot() == DayClock.MORNING)
	MouseShow.quiet = false


func _run_tag() -> void:
	print("-- 第 4 天晚上：小孩们的挠痒捉人")
	check("第 4 天晚上：捉人游戏", DayClock.slot() == DayClock.NIGHT and DayClock.event() == "d4_tag")
	var task := await _night_start("floor_06_after", "from_drill", [31, 31], "Task_d4_tag") as TaskTag
	check("广场 → 孩子们的开场 → 第一轮姐姐当鬼（四个孩子）", task != null and task.kids.size() == 4 and task.round_i == 0)
	# 第九轮：孩子们跑动没有边界（不再被关在广场的方框里）
	if task:
		await _advance_until(func(): return not GameState.in_dialogue and not GameState.in_cutscene, 15.0)
		var kd = task.kids[0]
		var edge := Cells.to_world(Vector2i(TaskTag.AREA.end.x, TaskTag.AREA.position.y + 4))
		var lvn: Node = main.get("level")
		print("  （方框外那一格能走：%s）" % str(GridPath.walkable(lvn, Vector2i(TaskTag.AREA.end.x + 1, TaskTag.AREA.position.y + 4))))
		kd.global_position = edge
		kd.mode = TaskTag.TagKid.Mode.FLEE
		var pl := GameState.player
		kd.target = pl
		var pos_pl := pl.global_position
		pl.global_position = edge + Vector2(-30, 0)
		for k in 20:
			kd._process(0.05)
		check("捉人游戏：孩子能跑出原来的方框（x %.0f > %.0f）" % [kd.global_position.x, edge.x], kd.global_position.x > edge.x + 4.0)
		# 第十轮：房子 / 摊位这些有碰撞的东西，孩子穿不过去
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var wsh := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(24, 24)
		wsh.shape = wr
		wall.add_child(wsh)
		main.level.add_child(wall)
		wall.global_position = kd.global_position + Vector2(30, 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check("捉人游戏：孩子不能穿过有碰撞的东西（房子 / 摊位）", not kd._ok(wall.global_position) and kd._ok(kd.global_position))
		wall.queue_free()
		kd.global_position = Cells.to_world(TaskTag.SPAWN[0])
		pl.global_position = pos_pl
	if task == null:
		return
	for k in task.kids:
		task.tickle_kid(k)
	await _advance_until(func(): return task.round_i == 1 and not task._busy and not GameState.in_dialogue, 20.0)
	check("四个都挠到 → 第二轮孩子当鬼", task.round_i == 1)
	task.catch_by(task.kids[0])
	await _wait(0.5)
	check("被摸到：按倒挠一阵（定身）", task.pinned_by != null and GameState.player.status.is_rooted())
	await _wait(TaskTag.PIN_TIME)
	task.time_left = 0.05
	await _advance_until(func(): return task.round_i == 2 and not task._busy and not GameState.in_dialogue, 20.0)
	check("撑到时间 → 第三轮大家一起当鬼", task.round_i == 2)
	task.time_left = 0.05
	await _advance_until(func(): return DayClock.day() == 5 and not Sleep.sleeping and not DayClock.passing, 60.0)
	check("撑过第三轮 → 躺在广场上聊天 → 睡到第 5 天", DayClock.day() == 5 and DayClock.slot() == DayClock.MORNING)
	GameState.player.laugh.clear()


func _run_lantern() -> void:
	print("-- 第 6 天晚上：镇长的笑声灯笼")
	LanternShow.quiet = true
	check("第 6 天晚上：笑声灯笼", DayClock.slot() == DayClock.NIGHT and DayClock.event() == "d6_lantern")
	await _night_start("floor_06_after", "from_drill", [31, 27], "Task_d6_lantern")
	await _advance_until(func(): return _show(LanternShow) != null, 10.0)
	var ls := _show(LanternShow) as LanternShow
	if ls == null:
		check("开演笑声灯笼", false)
		return
	await _wait(0.2)
	ls.press("UP")
	ls.press("UP")
	check("↑ 调刷子的强度（%s）" % ls.level_name(), ls.level == 2)
	var p := GameState.player
	var L: Dictionary = ls.lanterns()[0]
	p.laugh.set_value(p.laugh.max_value * (float(L["lo"]) + float(L["hi"])) * 0.5)
	ls.level = 1
	await _advance_until(func(): return ls.lit >= 1, 5.0)
	check("闷笑停在范围里几秒 → 第一盏亮了", ls.lit >= 1)
	p.laugh.set_value(p.laugh.max_value * 0.98)
	await _wait(0.2)
	check("笑过头：灯泡炸了", ls.bursts >= 1)
	ls.lit = 3
	ls.add_fatigue(ls.fatigue_max())
	await _wait(0.3)
	check("魔力疲倦满释放：只吹灭1–2盏（%d）" % ls.lit, ls.lit in [1, 2] and ls.blown == 1)
	ls.lit = ls.lanterns().size()
	await _advance_until(func(): return DayClock.day() == 7 and not Sleep.sleeping and not DayClock.passing, 60.0)
	check("五盏全亮 → 镇长说起「很会笑的小姑娘」→ 睡到第 7 天", DayClock.day() == 7 and DayClock.slot() == DayClock.MORNING)
	LanternShow.quiet = false


# ------------------------------------------------------------------ 补罚任务
func _run_penalty() -> void:
	print("-- 补罚任务：活体模特、罚跳舞")
	AfterErrands.refresh()
	var pend := AfterPenance.pending()
	check("赎罪簿上有没抵的受罚（%d 条）→ 市场监督 / 派对主人头上冒「！」" % pend, pend > 0 and GameState.has_flag(AfterPenance.FLAG))
	var h0 := PenanceBook.hours()
	ModelShow.quiet = true
	AfterPenance.run("model")
	await _advance_until(func(): return _show(ModelShow) != null, 10.0)
	var ms := _show(ModelShow) as ModelShow
	if ms:
		await _wait(0.2)
		ms.cust = 0
		ms.balance = 0.0
		ms.hit_once()
		check("顾客「试试效果」：姿势晃、表情掉", absf(ms.balance) > 0.2 and ms.face < 100.0)
		ms.balance = 1.1
		ms._check()
		await _wait(0.1)
		check("动了：市场监督加时（%d）" % ms.extras, ms.extras == 1)
		ms.time_left = 0.05
	await _advance_until(func(): return not AfterPenance.running, 20.0)
	check("撑过时间 → 抵掉一笔受罚、减工时（%d → %d）" % [h0, PenanceBook.hours()], AfterPenance.settled() == 1 and PenanceBook.hours() < h0)
	ModelShow.quiet = false
	if AfterPenance.pending() > 0:
		PenaltyDanceShow.quiet = true
		AfterPenance.run("dance")
		await _advance_until(func(): return _show(PenaltyDanceShow) != null, 10.0)
		var ds := _show(PenaltyDanceShow) as PenaltyDanceShow
		if ds:
			await _wait(0.2)
			var n0: Dictionary = ds.lane.chart[0]
			ds.lane.time = float(n0["t"])
			ds.press("LEFT" if str(n0["key"]) != "LEFT" else "RIGHT")
			check("罚跳舞：跳错一拍，围观的人上来挠", ds.misses == 1)
			var g := 0
			while not AfterPenance.running == false and g < 400:
				if is_instance_valid(ds) and ds.lane:
					if not ds.lane.finished():
						var n: Dictionary = ds.lane.chart[ds.lane._next]
						ds.lane.time = float(n["t"])
						ds.press(str(n["key"]))
					else:
						ds.lane.time = ds.lane.end_time() + 0.01
				await get_tree().process_frame
				g += 1
		check("跳完 → 又抵掉一笔", AfterPenance.settled() == 2)
		PenaltyDanceShow.quiet = false
	GameState.player.laugh.clear()


# ------------------------------------------------------------------ 时钟 / 日程
func _run_clock() -> void:
	print("-- 时钟和日程")
	var keep := [DayClock.day(), DayClock.slot()]
	DayClock.set_time(1, DayClock.AFTERNOON)
	var after := DayClock.npc("after_mayor")
	check("下午的事做完以后叠 afternoon_done：镇长回到默认位置（%s）" % [after.get("at")], _cell(after) == Vector2(31, 29))
	GameState.set_flag("after_done_d1_afternoon", false)
	var on_stage := DayClock.npc("after_mayor")
	check("还没宣判时：镇长在台上（%s）" % [on_stage.get("at")], _cell(on_stage) == Vector2(30, 24))
	GameState.set_flag("after_done_d1_afternoon")
	DayClock.set_time(3, DayClock.NIGHT)
	check("夜里镇民藏起来、宵禁的守卫还在", bool(DayClock.npc("after_granny").get("hidden")) and not bool(DayClock.npc("after_guard_gate").get("hidden")))
	check("时段名：%s" % DayClock.label(), DayClock.label() == "第 3 天·夜晚" and GameState.has_flag("night"))
	DayClock.set_time(keep[0], keep[1])


# ------------------------------------------------------------------ 旧存档
func _run_old_save() -> void:
	print("-- 旧存档：打赢攻防战之后在战时小镇的，送到战后的小镇")
	GameState.set_flag(AfterStory.STARTED, false)
	await main.change_level(Floors.scene("floor_06_war"))
	await _advance_until(func(): return _level_id() == "floor_06_after" and not StoryDirector.instance.sequence_running, 30.0)
	check("进战时小镇 → 直接到战后的小镇（%s）" % _level_id(), _level_id() == "floor_06_after" and GameState.has_flag(AfterStory.STARTED))


# ------------------------------------------------------------------ 测试跳关
func _run_skip() -> void:
	print("-- 测试跳关：能跳到最新的内容")
	var names := DevConfig.skip_points().map(func(p): return str(p["name"]))
	check("跳关列表有归途、战时小镇、攻防战第 12 波、七日赎罪第 1 天各段（共 %d 个）" % names.size(),
		names.has("第七层·归途（开场）") and names.has("地下小镇·战时（队长过场后）") and names.has("攻防战·第 12 波（狂欢要塞）")
		and names.has("七日赎罪·第 1 天（战后开场）") and names.has("七日赎罪·第 1 天夜里（梦游）"))
	var night: Dictionary = DevConfig.skip_points().filter(func(p): return p["name"] == "七日赎罪·第 1 天夜里（梦游）")[0]
	await DevConfig.skip_to(night)
	await _advance_until(func(): return GameState.has_flag(AfterStory.NIGHT_BUSY) and not Cutscene.is_playing() and not DayClock.passing, 60.0)
	check("跳到第 1 天夜里：进小屋天黑、梦游开演（%s，%s）" % [_level_id(), DayClock.label()],
		_level_id() == "floor_06_after_house" and DayClock.day() == 1 and DayClock.slot() == DayClock.NIGHT and GameState.has_flag(AfterStory.NIGHT_BUSY))


# ------------------------------------------------------------------ 工具
## 把公主放到某个位置（模拟走过去）
func _go(at: Vector2) -> void:
	var p := GameState.player
	p.global_position = at
	if p.camera:
		p.camera.reset_smoothing()


func _cell(info: Dictionary) -> Vector2:
	var a: Array = info.get("at", [-1, -1])
	return Vector2(float(a[0]), float(a[1]))


## 说一段对话：picks = 依次在选项页选第几个（用完了选第一个）；遇到输入框时 picks 里放字符串（用完了 = 放弃）
var last_options: Array = []


func _talk(file: String, node: String, picks: Array = []) -> void:
	# 别的对话（例如道具提示）还在跑：先让它说完，不然这一段会被忽略
	await _advance_until(func(): return not Dialogue.runner.is_running(), 10.0)
	Dialogue.runner.talk(file, node)
	var t := 0.0
	while Dialogue.runner.is_running() and t < 10.0:
		if Dialogue.runner.text_prompt.is_open():
			Dialogue.runner.text_prompt.submit(str(picks.pop_front()) if not picks.is_empty() else "")
		if Dialogue.runner.choice_menu.is_open():
			last_options = Dialogue.runner.choice_menu.options.duplicate()
			Dialogue.runner.choice_menu.choose(int(picks.pop_front()) if not picks.is_empty() else 0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.text_prompt.is_open():
			Dialogue.runner.text_prompt.submit("")
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
