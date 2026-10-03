extends Node
## 保卫队训练营测试：训练数值（上限、部位均分、加成、套到公主身上）、训练菜单（费用 / 未解锁 / 练满）、
## Esc 测试列表滚动条；训练一~四的小游戏、新陷阱和新组合（后面几节）。
## 用法：Godot --headless --path . res://tests/training_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	await _run_stats()
	await _run_menu()
	await _run_esc_list()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 数值
func _clear_training() -> void:
	for k in GameState.vars.keys():
		if str(k).begins_with("train_"):
			GameState.vars.erase(k)
	TrainingStats.apply(player)


func _run_stats() -> void:
	print("-- 训练数值")
	_clear_training()
	check("没练过：魔力疲倦 500、闷笑 150、生命 10、部位倍率不变", player.fatigue.max_value == 500.0 and player.laugh.max_value == 150.0
		and player.health.max_hp == 10 and is_equal_approx(TickleZones.zone_multiplier("sole"), 1.2))
	check("4 项训练，第一阶段开放、二三阶段未解锁", TrainingDB.list().size() == 4
		and TrainingDB.list().all(func(t): return t["stages"][0]["unlocked"] and not t["stages"][1]["unlocked"] and not t["stages"][2]["unlocked"]))
	check("一阶段上限：疲倦 +100 / -100、释放强度 50%、耐笑 0.1、强化 0.3", TrainingStats.cap("train_fatigue_up") == 100.0
		and TrainingStats.cap("train_fatigue_down") == 100.0 and TrainingStats.cap("train_burst_power") == 50.0
		and is_equal_approx(TrainingStats.cap("train_resist_sole"), 0.1) and is_equal_approx(TrainingStats.cap("train_sens_belly"), 0.3))
	var got := TrainingStats.add("train_fatigue_up", 130)
	check("加到上限为止（加 130 实际 +100）", got == 100.0 and TrainingStats.is_full("train_fatigue_up"))
	TrainingStats.add("train_fatigue_down", 30)
	TrainingStats.add("train_burst_power", 20)
	var n := TickleZones.zone_ids().size()
	TrainingStats.add("train_resist_sole", 0.1)     # 一个部位练满
	TrainingStats.add("train_sens_thigh", 0.15)     # 一个部位练一半
	var hp_before := player.health.hp
	TrainingStats.apply(player)
	check("魔力疲倦上限 = 500 + 100 - 30", player.fatigue.max_value == 570.0)
	var lb := 25.0 / n + 0.5 * 50.0 / n
	check("闷笑上限按部位均分（耐笑满 1 个 25/%d + 强化半个 50/%d×0.5 = %.2f）" % [n, n, lb], is_equal_approx(player.laugh.max_value, 150.0 + lb))
	check("生命上限按部位均分取整（%d 个部位时 +%d HP）" % [n, TrainingStats.hp_bonus()],
		player.health.max_hp == 10 + int(floor(2.0 / n + 0.5 * 4.0 / n + 1e-6)) and player.health.hp >= hp_before)
	check("近战强度 = 50%% / %d（只有耐笑训练加）" % n, is_equal_approx(TrainingStats.melee_bonus(), 0.5 / n))
	check("部位倍率：脚心 -0.1、大腿 +0.15", is_equal_approx(TickleZones.zone_multiplier("sole"), 1.1)
		and is_equal_approx(TickleZones.zone_multiplier("thigh"), 1.05))
	var total := 0
	for i in 2000:
		total += TrainingStats.melee_damage(2)
	check("近战伤害期望 = 基础 × (1 + 强度)（%.3f）" % (total / 2000.0), absf(total / 2000.0 - 2.0 * (1.0 + 0.5 / n)) < 0.05)
	check("疲倦释放强度倍率 1.2", is_equal_approx(TrainingStats.burst_mult(), 1.2))
	check("训练成果写进 GameState.vars（随存档保存）", GameState.vars.has("train_fatigue_up") and GameState.vars.has("train_resist_sole"))
	check("训练成果总览（背包用）有疲倦 / 释放 / 闷笑 / 生命 / 近战和练过的部位", TrainingStats.summary().size() >= 7)
	_clear_training()


# ------------------------------------------------------------------ 菜单
func _run_menu() -> void:
	print("-- 训练菜单")
	GameState.inventory.remove("coin", GameState.inventory.count("coin"))
	var t := TrainingDB.info("fatigue_endure")
	check("金币不够不能开始", TrainingMenu.blocked_reason(t).contains("金币"))
	GameState.give_item(ItemDB.get_item("coin"), 20)
	check("有金币就能开始（每轮 %d 金币）" % TrainingMenu.cost(), TrainingMenu.blocked_reason(t) == "" and TrainingMenu.cost() == 5)
	TrainingStats.add("train_fatigue_up", 100)
	check("这一阶段练满就不能再练", TrainingMenu.blocked_reason(t).contains("练满"))
	_clear_training()
	var menu := TrainingMenu.new()
	get_tree().root.add_child(menu)
	var result := [null]
	var run := func(): result[0] = await menu.choose()
	run.call()
	await _wait(0.1)
	check("训练菜单列出 4 项训练并暂停游戏", menu.rows.get_child_count() == 4 and get_tree().paused)
	menu.pick(2)
	await _wait(0.05)
	check("部位类训练（耐笑）先选部位", menu.page == "zone" and menu.rows.get_child_count() == TickleZones.zone_ids().size())
	menu.cancel()
	await _wait(0.05)
	check("Esc 从选部位回到训练列表", menu.page == "list")
	menu.pick(3)
	menu.pick(1)
	await _wait(0.05)
	check("选好部位返回 {id, zone}", result[0] is Dictionary and result[0].get("id") == "zone_sensitize"
		and result[0].get("zone") == str(TickleZones.zone_ids()[1]) and not get_tree().paused)
	menu.queue_free()


# ------------------------------------------------------------------ Esc 测试列表
func _run_esc_list() -> void:
	print("-- Esc 测试列表")
	DevConfig.override = true
	var pm: Node = null
	for n in main.find_children("*", "CanvasLayer", true, false):
		if n.has_method("show_skip_list"):
			pm = n
	pm.toggle()
	pm.show_skip_list()
	await _wait(0.2)
	var sc: ScrollContainer = pm.skip_scroll
	check("跳关列表放在滚动容器里（高度固定，内容比它高时能滚）", sc.visible and pm.skip_box.get_parent() == sc
		and sc.size.y <= pm.SKIP_HEIGHT + 1.0 and pm.skip_box.get_child_count() == DevConfig.skip_points().size() + 1)
	var last: Button = pm.skip_box.get_child(pm.skip_box.get_child_count() - 1)
	last.grab_focus()
	await _wait(0.2)
	check("焦点移到最后一项时自动滚下去", pm.skip_box.size.y <= sc.size.y or sc.scroll_vertical > 0)
	pm.hide_skip_list()
	pm.toggle()
	DevConfig.override = false
	await _wait(0.1)


# ------------------------------------------------------------------ 工具
func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
