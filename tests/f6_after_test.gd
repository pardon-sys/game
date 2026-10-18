extends Node
## 七日赎罪（战后的小镇）：
##   攻防战胜利的过场最后去战后的小镇；第 1 天：早上开场（千手痒痒裤当众发作）→ 自动到下午 → 广场宣判（发赎罪簿）
##   → 镇民按日程摆位置（开场时只有队长和守城队员、宣判时围在台下、宣判完散开）→ 回小屋 = 天黑 → 被裤子的手挠醒
##   → 三处手印（楼梯那处要最后看）→ 楼上梦游的结尾 → 回床上睡 → 第 2 天早上。
##   赎罪簿：100 工时、加减和记录、背包里的「赎罪簿」页；时钟：日程的逐层覆盖、夜里宵禁锁门；旧存档从战时小镇送过来。
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
	_run_clock()
	await _run_old_save()
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


# ------------------------------------------------------------------ 第 1 天：开场 → 宣判
func _run_day1() -> void:
	print("-- 第 1 天：战后开场 → 广场宣判")
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
	await _advance_until(func(): return GameState.has_flag("after_done_d1_afternoon") and not Cutscene.is_playing() and not DayClock.passing, 120.0)
	Cutscene.started.disconnect(watch)
	check("进战后的小镇 = 第 1 天早上开始（after_started、开场时是早上 %s）" % morning.get("slot"),
		GameState.has_flag("after_started") and morning.get("slot") == DayClock.MORNING)
	check("开场的过场放了（千手痒痒裤当众发作）→ 自动到下午 → 宣判的过场（%s）" % [seen_cuts],
		seen_cuts.has("after_d1_open") and seen_cuts.has("after_d1_verdict") and seen_cuts.find("after_d1_open") < seen_cuts.find("after_d1_verdict"))
	check("开场时只有队长和守城的队员（奶奶藏着 %s、队长在 %s）" % [not morning.get("granny", true), morning.get("captain")],
		morning.get("granny") == false and morning.get("captain") == true)
	check("现在是第 1 天下午，早上和下午都做完了", DayClock.day() == 1 and DayClock.slot() == DayClock.AFTERNOON
		and DayClock.done(1, 0) and DayClock.done(1, 1))
	check("宣判之后拿到赎罪簿：100 工时", PenanceBook.started() and PenanceBook.hours() == 100)
	await _wait(1.0)
	check("过场留下的黑幕揭开了（%.2f）" % Cutscene.curtain.color.a, Cutscene.curtain.color.a < 0.05)
	# 镇民：节点改名成对话文件名、宣判完散回默认位置；蓝色公主跟着
	var cap := _node("after_captain") as Resident
	var want: Vector2 = Cutscene.cell_to_world([34, 29])
	check("宣判完队长回到默认位置（离 %.0f）、镇长也在广场上" % (cap.global_position.distance_to(want) if cap else -1.0),
		cap != null and cap.global_position.distance_to(want) < 4.0 and cap.visible and (_node("after_mayor") as Node2D).visible)
	var blue := _node("AfterBlue") as PlayableCharacter
	check("蓝色公主（AfterBlue）跟着粉色公主、粉色公主在操控", blue != null and blue.follow and GameState.player.character_id == "pink")
	# 镇民第 1 天的对话
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


# ------------------------------------------------------------------ 工具
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
