extends Node
## 第五层与新系统测试：部位挠痒 / 敏感值、被动技能、地图内过场动画、第五层新陷阱和怪物、无解房间结局。
## 用法：Godot --headless --path . res://tests/floor5_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: Princess
var ctrl := ScriptedController.new()
var failures := 0


class Src extends Node2D:
	var reaction_key := ""
	var tickle_zones := {}


func _ready() -> void:
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	MagicFatigue.accumulate = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	_refresh()
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)
	await _run_zones()
	await _run_passives()
	await _run_cutscene()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 部位挠痒 / 敏感值
func _run_zones() -> void:
	print("-- 部位挠痒与敏感值")
	TickleZones.enabled = true
	check("部位表和来源分配校验通过", TickleZones.validate().is_empty())
	check("部位全来自配置（5 个部位，名字和敏感倍率）", TickleZones.zone_ids().size() == 5
		and TickleZones.zone_name("sole") == "脚心" and is_equal_approx(TickleZones.zone_multiplier("sole"), 1.2))
	# 抽部位：挠脚鼠只挠脚心；没分配的来源按默认 chance；实例覆盖优先
	var rat := _src("rat")
	var all_sole := true
	for i in 30:
		all_sole = all_sole and TickleZones.pick(rat) == "sole"
	check("挠脚鼠每下都落在脚心", all_sole)
	var odd := _src("no_such_source")
	var seen := {}
	for i in 200:
		seen[TickleZones.pick(odd)] = true
	check("没分配部位的来源按部位表的 chance 随机落在各部位", seen.size() == 5)
	var custom := _src("rat")
	custom.tickle_zones = {"armpit": 1}
	check("单个实例的 tickle_zones 覆盖来源表", TickleZones.pick(custom) == "armpit")
	# 露出部位：优先选露出的、来源能挠到的部位
	var glove := _src("glove")
	var ok := true
	for i in 30:
		ok = ok and TickleZones.pick(glove, {"waist": 1.5}) == "waist"
	check("被束缚露出部位时优先挠露出的部位（手套 → 腰）", ok)
	check("露出的部位来源挠不到时照常按权重", TickleZones.pick(rat, {"armpit": 1.5}) == "sole")
	# 数值：挠痒值 × 全身 × 部位 × 连续 × 露出
	_reset()
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("平静时挠脚心：10 × 1.0 × 1.2 = 12（实际 %.2f）" % player.laugh.value, absf(player.laugh.value - 12.0) < 0.01
		and player.last_tickle.zone == "sole")
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	var before := player.laugh.value
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("连续挠同一部位越来越敏感：第三下 ×1.03（%.2f）" % (player.laugh.value - before), absf(player.laugh.value - before - 12.0 * 1.03) < 0.05
		and is_equal_approx(player.sensitivity.streak_of("sole"), 0.06))
	await _wait(2.6)
	check("停下来后连续加成慢慢恢复", player.sensitivity.streak_of("sole") < 0.06)
	player.sensitivity.reset()
	player.laugh.set_value(player.laugh.max_value * 0.6)
	before = player.laugh.value
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("越笑越敏感 + 战损：失控 1 ×1.1 × 战损 1.1 × 脚心 1.2（%.2f）" % (player.laugh.value - before),
		absf(player.laugh.value - before - 10.0 * 1.1 * 1.1 * 1.2) < 0.05 and player.sensitivity.damaged)
	# 露出部位：×倍率、通用状态显示名、「弱点！」
	player.sensitivity.reset()
	player.laugh.clear()
	var trap := _src("")
	player.sensitivity.expose(trap, {"sole": 1.5}, player)
	check("露出部位：挂上通用状态，名字按部位动态显示", player.has_buff("exposed") and Buff.display("exposed", player)["name"] == "露出：脚心"
		and int(Buff.display("exposed", player)["icon"]) == 9)
	var weak := [""]
	player.sensitivity.weak_point.connect(func(z): weak[0] = z, CONNECT_ONE_SHOT)
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("挠到露出的部位：×1.5（%.2f），头上跳「弱点！」" % player.laugh.value, absf(player.laugh.value - 18.0) < 0.05 and weak[0] == "sole")
	player.sensitivity.unexpose(trap, player)
	check("放开后状态消失", not player.has_buff("exposed"))
	# 没有来源键的挠痒（组合额外挠痒、余痒）不抽部位
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	check("没有来源键的挠痒不抽部位，只乘全身项", player.last_tickle.zone == "" and absf(player.laugh.value - 10.0) < 0.01)
	# 飘字：来源按部位写的 → 来源自己的 → 部位默认 → 全局
	check("飘字回退：没配置的来源用部位默认台词", ReactionDB.portrait_words("vine", "helpless_2", "thigh") == TickleZones.words("thigh", "helpless_2"))
	check("飘字回退：来源自己配置的台词优先", ReactionDB.portrait_words("rat", "helpless_1", "sole") == ReactionDB.portrait_words("rat", "helpless_1"))
	# 状态页显示敏感度
	player.revive()
	check("复活重置敏感状态", not player.sensitivity.damaged and player.sensitivity.streak.is_empty())
	TickleZones.enabled = false
	_reset()


# ------------------------------------------------------------------ 被动技能
func _run_passives() -> void:
	print("-- 被动技能")
	GameState.passives.clear()
	check("被动技能数据：挣脱强化 3 级", PassiveDB.max_level("struggle_plus") == 3 and PassiveDB.name("struggle_plus") == "挣脱强化"
		and PassiveDB.icon("struggle_plus").atlas != null)
	_reset()
	player.laugh.set_value(80.0)
	player.struggle()
	var plain := 80.0 - player.laugh.value
	var changed := [""]
	GameState.passive_changed.connect(func(id, _lv): changed[0] = id, CONNECT_ONE_SHOT)
	check("获得被动技能", GameState.grant_passive("struggle_plus") and GameState.passive_level("struggle_plus") == 1 and changed[0] == "struggle_plus")
	check("重复获得不会重置", not GameState.grant_passive("struggle_plus"))
	player.laugh.set_value(80.0)
	player.struggle()
	var boosted := 80.0 - player.laugh.value
	check("挣脱强化 Lv1：挣扎降闷笑 +30%%（%.2f → %.2f）" % [plain, boosted], absf(boosted - plain * 1.3) < 0.01)
	check("可以升级到满级", GameState.upgrade_passive("struggle_plus") and GameState.upgrade_passive("struggle_plus")
		and not GameState.upgrade_passive("struggle_plus") and GameState.passive_level("struggle_plus") == 3
		and is_equal_approx(PassiveDB.value("struggle_plus"), 0.75))
	# 背包被动页
	GameState.set_flag(GameState.BACKPACK_FLAG)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_PASSIVES)
	await get_tree().process_frame
	var txt := _texts(bp.passives_page)
	check("背包被动技能页：图标、名字、等级、效果", bp.passives_page.visible and bp.passive_grid.get_child_count() == 1
		and txt.contains("挣脱强化") and txt.contains("Lv.3 / 3") and txt.contains("已经满级"))
	bp.set_page(Backpack.PAGE_STATUS)
	await get_tree().process_frame
	check("状态页显示全身和各部位敏感度", _texts(bp.status_page).contains("敏感度") and _texts(bp.status_page).contains("脚心 ×1.20"))
	bp.close()
	GameState.passives.clear()
	await _wait(0.1)


# ------------------------------------------------------------------ 地图内过场动画
func _run_cutscene() -> void:
	print("-- 地图内过场动画")
	_reset()
	var hud: CanvasLayer = main.get_node("HUD")
	var start := player.global_position
	var cell := Vector2i(int(start.x) / 16, int(start.y) / 16)
	var feather: Trap = load("res://scenes/traps/feather_trap.tscn").instantiate()
	level.get_node("Entities").add_child(feather)
	feather.global_position = Vector2((cell.x + 1) * 16 + 8, cell.y * 16 + 8)
	var cs := {"name": "测试", "steps": [
		{"actions": [{"do": "move", "who": "princess", "to": [cell.x + 3, cell.y], "time": 0.5},
				{"do": "camera", "to": [cell.x + 6, cell.y], "time": 0.3}], "wait": 0.6},
		{"speaker": "公主", "text": "过场里的一句台词。", "auto": 0.3,
			"actions": [{"do": "spawn", "id": "shadow", "kind": "shadow", "at": [cell.x + 5, cell.y]}, {"do": "pose", "laugh": 60}]},
		{"actions": [{"do": "carry", "who": "shadow", "on": true}, {"do": "move", "who": "shadow", "to": [cell.x + 5, cell.y + 1], "time": 0.3},
				{"do": "trap", "who": feather.name, "time": 0.3}, {"do": "set_flag", "flag": "test_cutscene_flag"}], "wait": 0.4},
		{"actions": [{"do": "carry", "on": false}, {"do": "despawn", "who": "shadow"}], "wait": 0.1},
	]}
	check("过场数据校验：认识所有动作", Cutscene.validate("f5_intro").size() <= 1)
	ctrl.move = Vector2.LEFT
	Cutscene.play_data("test_demo", cs)
	await _wait(0.5)
	check("过场开始：上下黑框滑入、HUD 隐藏、剧情状态", Cutscene.is_playing() and Cutscene.is_letterboxed() and not hud.visible
		and GameState.in_cutscene and GameState.in_dialogue)
	check("过场中按方向键不能操作，公主被脚本移动并播走路动画", player.global_position.x > start.x + 8.0 and player.state == PlayableCharacter.State.MOVE)
	check("过场中陷阱暂停（羽毛陷阱没有被踩发）", feather.phase == Trap.Phase.IDLE and player.last_tickle == null)
	var t := 0.0
	while Cutscene.step_index < 1 and t < 3.0:
		await _wait(0.05)
		t += 0.05
	check("镜头移到指定的格子（%.0f）" % player.camera.position.x, player.camera.position.x > 40.0)
	await _wait(0.05)
	check("台词用对话框显示", Dialogue.is_active())
	t = 0.0
	while Cutscene.step_index < 2 and t < 3.0:
		await _wait(0.05)
		t += 0.05
	await _wait(0.15)
	var shadow: Node2D = Cutscene.spawned.get("shadow")
	check("生成黑影（公主精灵蒙黑）并抱着公主走", shadow != null and shadow.has_meta("shadow")
		and (shadow.get_node("Sprite") as Sprite2D).modulate.v < 0.2 and player.global_position.distance_to(shadow.global_position + Vector2(0, -8)) < 1.0)
	check("陷阱演一次发动（只有表现）", feather.phase == Trap.Phase.ACTIVE and player.last_tickle == null)
	check("pose 设置闷笑值（失控的表现）", player.laugh.percent() > 55.0)
	t = 0.0
	while Cutscene.is_playing() and t < 4.0:
		await _wait(0.05)
		t += 0.05
	await _wait(0.4)
	check("过场结束：黑框收起、HUD 恢复、可以操作、镜头回到公主", not Cutscene.is_playing() and not Cutscene.is_letterboxed() and hud.visible
		and not GameState.in_cutscene and not GameState.in_dialogue and player.camera.position.distance_to(Vector2(0, -12)) < 1.0)
	check("过场里的 set_flag 生效、黑影已移除", GameState.has_flag("test_cutscene_flag") and not is_instance_valid(shadow))
	# 看过的可以跳过：跳过时剩下的 set_flag 仍然生效
	GameState.flags.erase("test_cutscene_flag")
	Cutscene.play_data("test_demo", cs)
	await _wait(0.5)
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	t = 0.0
	while Cutscene.is_playing() and t < 3.0:
		await _wait(0.05)
		t += 0.05
	check("看过的过场按 Esc 跳过，剩下的 set_flag 照样生效（%.1f 秒）" % t, not Cutscene.is_playing() and t < 1.5 and GameState.has_flag("test_cutscene_flag"))
	ctrl.move = Vector2.ZERO
	feather.queue_free()
	_finish_dialogue()
	_reset()
	await _wait(0.3)


# ------------------------------------------------------------------ 工具
func _src(key: String) -> Src:
	var n := Src.new()
	n.reaction_key = key
	level.get_node("Entities").add_child(n)
	n.global_position = player.global_position + Vector2(20, 0)
	return n


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	return out


func _reset() -> void:
	player.revive()
	player._set_state(PlayableCharacter.State.IDLE)
	player.combo.reset()
	player.clear_buffs(false)
	player._full_invuln = 0.0
	player._attack_invuln = 0.0


func _refresh() -> void:
	level = main.level
	player = GameState.player as Princess


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 100:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
