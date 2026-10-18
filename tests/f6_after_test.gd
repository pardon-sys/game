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
	Cutscene.started.connect(func(id: String): seen_cuts.append(id))
	_run_data()
	await _run_day1()
	await _run_book()
	await _run_night()
	await _run_day2()
	await _run_errands()
	await _run_play()
	await _run_rest()
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
	var spot: Vector2 = Cutscene.cell_to_world([31, 27])
	check("目标提示：「%s」，标记在宣判台前（离 %.0f）" % [mk.text if mk else "", mk.global_position.distance_to(spot) if mk else -1.0],
		mk != null and mk.text.contains("宣判台") and mk.has_cell and mk.global_position.distance_to(spot) < 2.0)
	await _wait(1.0)
	check("自由活动时等了一秒也不会自己开演", not seen_cuts.has("after_d1_verdict") and not Cutscene.is_playing())
	var blue := _node("AfterBlue") as PlayableCharacter
	check("蓝色公主（AfterBlue）跟着粉色公主、粉色公主在操控", blue != null and blue.follow and GameState.player.character_id == "pink")
	await _talk("floor_06/after_mayor", "")
	check("宣判之前镇民说的是等着宣判的话", GameState.has_flag("dlg_floor_06/after_mayor_d1_wait"))
	# 走到宣判台前 → 宣判 → 晚上
	_go(spot)
	await _advance_until(func(): return DayClock.done(1, 1) and not Cutscene.is_playing() and not DayClock.passing, 120.0)
	await _wait(0.5)
	check("走到宣判台前 → 宣判的过场（%s）→ 到晚上（%s）" % [seen_cuts.has("after_d1_verdict"), DayClock.label()],
		seen_cuts.has("after_d1_verdict") and DayClock.slot() == DayClock.NIGHT and GameState.has_flag("night"))
	check("宣判之后拿到赎罪簿：100 工时", PenanceBook.started() and PenanceBook.hours() == 100)
	var door: Vector2 = Cutscene.cell_to_world(AfterStory.TOWN_HOUSE_DOOR)
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
	_go(Cutscene.cell_to_world([23, 25.5]))
	await _advance_until(func(): return DayClock.done(2, DayClock.MORNING) and not Cutscene.is_playing() and not DayClock.passing and not CG.is_busy(), 180.0)
	get_tree().node_added.disconnect(hook)
	StocksShow.auto_respond = ""
	check("示众：开场过场 → 小游戏 → 撑过时间的结局（%s）" % [seen_cuts.filter(func(c): return c.begins_with("after_d2"))],
		seen_cuts.has("after_d2_stocks") and seen_cuts.has("after_d2_stocks_end") and not seen_cuts.has("after_d2_stocks_faint"))
	check("工时：示众做完 -12、笑出声 3 次 +6（%d → %d）" % [h0, PenanceBook.hours()], PenanceBook.hours() == h0 - 12 + 6)
	var pun := PenanceBook.punishments()
	check("笑出声 3 次以上 → 训练营转盘停在转轮，播了刑具小剧场、记进受罚记录（%s）" % [pun.back().get("text") if pun.size() > p0 else ""],
		pun.size() == p0 + 1 and str(pun.back()["theater"]) == "after_roulette_wheel" and GameState.has_flag("cg_seen_theater:after_roulette_wheel"))
	check("示众完到了第 2 天下午、蓝色公主回到身边", DayClock.day() == 2 and DayClock.slot() == DayClock.AFTERNOON
		and _node("AfterBlue") != null and (_node("AfterBlue") as Node2D).global_position.distance_to(GameState.player.global_position) < 80.0)
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
		_go(Cutscene.cell_to_world(c))
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
	check("一天只能玩一次（关系值不再加）", int(GameState.vars.get("blue_bond", 0)) == b0 + 1)
	AfterPlay.auto_picks = []
	AfterPlay.auto_qte = null


# ------------------------------------------------------------------ 空时段：床上休息
func _run_rest() -> void:
	print("-- 空时段：小屋的床上休息到晚上")
	GameState.pending_spawn = "from_town"
	await main.change_level(Floors.scene("floor_06_after_house"))
	await _wait(0.5)
	check("第 2 天下午没有剧情：进小屋不会天黑", DayClock.slot() == DayClock.AFTERNOON)
	await _talk("floor_06/after_house_objects", "bed", [0])
	await _advance_until(func(): return DayClock.slot() == DayClock.NIGHT and not DayClock.passing, 10.0)
	check("床上「休息到下一个时段」→ 晚上（%s）" % DayClock.label(), DayClock.day() == 2 and DayClock.slot() == DayClock.NIGHT)


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


## 说一段对话：picks = 依次在选项页选第几个（用完了选第一个）
func _talk(file: String, node: String, picks: Array = []) -> void:
	Dialogue.runner.talk(file, node)
	var t := 0.0
	while Dialogue.runner.is_running() and t < 10.0:
		if Dialogue.runner.choice_menu.is_open():
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
