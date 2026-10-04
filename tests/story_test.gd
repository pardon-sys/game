extends Node
## 剧情 / 界面测试：立绘避让；第六层后续剧情（参观小镇 → 蓝色小屋 → 夜晚 → 骑马刷凳 → 钥匙 → 睡觉 → 第二天）（后面几节）。
## 用法：Godot --headless --path . res://tests/story_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	await _run_portrait_fade()
	await _run_tour_and_house()
	await _run_stealth()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 立绘避让
func _run_portrait_fade() -> void:
	print("-- 立绘避让")
	await _wait(1.5)
	_finish()
	var cam: Camera2D = player.camera
	cam.position_smoothing_enabled = false
	cam.offset = Vector2.ZERO
	await _wait(1.2)
	check("公主在画面中间：立绘不透明", not Dialogue.player_behind_portrait() and Dialogue.portrait.self_modulate.a > 0.95)
	# 镜头往右上偏：公主在画面左下，正好在立绘后面
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	var cam_base := cam.position
	cam.position = cam_base + Vector2(170, -50)
	await _wait(1.0)
	check("公主走到立绘的位置：立绘变半透明（%.2f）" % Dialogue.portrait.self_modulate.a, Dialogue.player_behind_portrait()
		and absf(Dialogue.portrait.self_modulate.a - Dialogue.PORTRAIT_FADE_ALPHA) < 0.05)
	cam.position = cam_base
	await _wait(1.0)
	check("走开后恢复不透明", Dialogue.portrait.self_modulate.a > 0.95)


# ------------------------------------------------------------------ 参观小镇 → 小屋 → 夜晚 → 钥匙 → 睡觉
func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


## 每帧推进对话（过场 / 小剧场的台词）直到条件成立。
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func _run_tour_and_house() -> void:
	print("-- 第六层：参观小镇 → 蓝色小屋 → 夜晚 → 钥匙 → 睡觉")
	for f in ["f6_opening_done", "intro_done_f6_wake"]:
		GameState.set_flag(f)
	await main.change_level(Floors.scene("floor_06_upper"))
	await _wait(0.5)
	_finish()
	var house_door: Node = _exit_to(main.level, "floor_06_house")
	check("集市层有蓝色小屋的门，参观之前锁着", house_door != null and house_door.is_locked_now())
	for i in 4:
		GameState.set_flag("dlg_floor_06/blue_princess_hub_%d" % i)
	F6Story.on_talk_finished(F6Story.BLUE_FILE)
	await _wait(0.2)
	check("话题没问完：不开始参观", not GameState.has_flag("f6_tour_started"))
	GameState.set_flag("dlg_floor_06/blue_princess_hub_4")
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	F6Story.on_talk_finished(F6Story.BLUE_FILE)
	await _advance_until(func(): return _level_id() == "floor_06_house" and not F6Story.touring and not Cutscene.is_playing(), 120.0)
	Cutscene.started.disconnect(on_cut)
	check("5 个话题都问完 → 参观：集市层 → 营地层 → 矿道层 → 小屋门口 → 进小屋（%s）" % [seen],
		seen == ["f6_tour_upper", "f6_tour_camp", "f6_tour_mine", "f6_tour_home", "f6_house_enter"] and _level_id() == "floor_06_house")
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	var door: Node = _exit_to(main.level, "floor_06_upper")
	check("进屋后天黑了（night），小屋的门锁上，环境光变暗", GameState.has_flag("night") and GameState.has_flag("f6_house_open")
		and door != null and door.is_locked_now() and main.level.night_ambient.a > 0.0)
	# 家具都能调查
	var ho: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/house_objects.json"))
	var props: Array = main.level.find_children("*", "", true, false).filter(func(n): return n.get("action") != null and str(n.get("action")).begins_with("talk:floor_06/house_objects#"))
	var missing: Array = props.map(func(n): return str(n.action).split("#")[1]).filter(func(k): return not ho["nodes"].has(k))
	check("房间里 %d 件家具都能调查（床、衣柜、书架、梳妆台、茶桌、盆栽、窗户、画、骑马刷凳），对话节点齐全%s" % [props.size(), missing],
		props.size() >= 10 and missing.is_empty())
	# 拿到钥匙前床睡不了
	Dialogue.talk("floor_06/house_objects", "bed")
	await _advance_until(func(): return not Dialogue.runner.is_running() and not Dialogue.is_active(), 5.0)
	await _wait(0.3)
	check("还没发现钥匙：床「还睡不着」", GameState.has_flag("night") and Sleep.day() == 1)
	# 骑马刷凳
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	Dialogue.talk("floor_06/house_objects", "saddle")
	await _advance_until(func(): return GameState.has_flag("f6_key") and not Dialogue.runner.is_running() and not Cutscene.is_playing() and not CG.is_busy(), 90.0)
	CG.started.disconnect(on_cg)
	var saddle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_06/f6_house_saddle.json"))
	check("骑马刷凳：长的小剧场（%d 句）→ 蓝色公主下楼让她小声点 → 拿到神秘的钥匙" % saddle["steps"].filter(func(st): return st.has("text")).size(),
		cg_seen.has("theater:f6_house_saddle") and saddle["steps"].filter(func(st): return st.has("text")).size() >= 21
		and GameState.inventory.count("mystery_key") == 1 and GameState.has_flag("cutscene_seen_f6_blue_quiet"))
	# 睡觉
	var cut2 := []
	var on_cut2 := func(id: String): cut2.append(id)
	Cutscene.started.connect(on_cut2)
	Dialogue.talk("floor_06/house_objects", "bed")
	await _advance_until(func(): return Sleep.day() == 2 and not Sleep.sleeping and not Cutscene.is_playing() and GameState.has_flag("f6_escape"), 30.0)
	Cutscene.started.disconnect(on_cut2)
	check("拿到钥匙后睡觉 → 第 2 天，天亮了，早上公主说要逃离这里（f6_escape）", Sleep.day() == 2 and not GameState.has_flag("night")
		and cut2.has("f6_morning_escape") and GameState.has_flag("f6_escape") and not GameState.in_dialogue)


func _exit_to(level: Node, floor_id: String) -> Node:
	for n in level.find_children("*", "", true, false):
		if n.get("target_level") != null and str(n.get("target_level")) == Floors.scene(floor_id):
			return n
	return null


# ------------------------------------------------------------------ 潜入矿道
func _run_stealth() -> void:
	print("-- 第六层：潜入矿道（巡逻、视野、暗处、躲藏、丢石子、被抓）")
	GameState.pending_spawn = "from_camp"
	await main.change_level(Floors.scene("floor_06_mine"))
	await _wait(0.6)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	var d := StealthDirector.current
	var guards := get_tree().get_nodes_in_group("patrol_guard").filter(func(g): return main.level.is_ancestor_of(g))
	check("f6_escape 之后矿道是潜入模式：%d 个巡逻士兵，矿工不见了" % guards.size(), d != null and d.is_active() and guards.size() >= 8
		and guards.all(func(g): return g.visible) and main.level.find_children("*", "", true, false).filter(func(n): return n.get("npc_id") == "miner" and n.visible).is_empty())
	var gate: Node = _exit_to(main.level, "floor_07")
	GameState.set_flag("f6_key", false)
	var locked_without: bool = gate != null and gate.is_locked_now()
	GameState.set_flag("f6_key")
	check("最深处的门：没有钥匙锁着，有钥匙就开（通往第七层）", locked_without and not gate.is_locked_now())
	# 视野
	var g: PatrolGuard = guards[0]
	g.process_mode = Node.PROCESS_MODE_DISABLED
	var g_home := g.global_position
	g.cone.facing = Vector2.RIGHT
	player.global_position = g.global_position + Vector2(36, 0)
	await get_tree().physics_frame
	check("士兵正前方 36 像素：看得见（%.2f）" % g.sees(player), g.sees(player) > 0.0)
	player.global_position = g.global_position + Vector2(-36, 0)
	await get_tree().physics_frame
	check("在士兵背后：看不见", g.sees(player) == 0.0)
	player.global_position = g.global_position + Vector2(36, 0)
	var wall := StaticBody2D.new()
	var ws := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 40)
	ws.shape = rect
	wall.add_child(ws)
	main.level.add_child(wall)
	wall.global_position = g.global_position + Vector2(18, -10)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("中间隔着墙：看不见", g.sees(player) == 0.0)
	wall.queue_free()
	var lit: Vector2 = VisionCone.lights[0] if not VisionCone.lights.is_empty() else Vector2.ZERO
	check("暗处（离灯远）视野只有一半（%d → %d 像素）" % [g.cone.effective_range(lit), g.cone.effective_range(Vector2(-5000, -5000))],
		not VisionCone.lights.is_empty() and is_equal_approx(g.cone.effective_range(Vector2(-5000, -5000)), g.cone.effective_range(lit) / 2.0))
	# 躲藏
	var crate: Node2D = main.level.find_children("*", "", true, false).filter(func(n): return n.get("action") == "hide")[0]
	StealthDirector.toggle_hide(player, crate)
	await get_tree().physics_frame
	check("躲进木箱 / 矿车：看不见、不能动", d.is_player_hidden() and not player.visible and g.sees(player) == 0.0
		and player.process_mode == Node.PROCESS_MODE_DISABLED)
	StealthDirector.toggle_hide(player, crate)
	check("再按一次出来", not d.is_player_hidden() and player.visible)
	# 丢石子
	g.process_mode = Node.PROCESS_MODE_INHERIT
	var n := d.noise(g.global_position + Vector2(40, 0))
	check("石子落地的声音：附近的士兵去查看（%d 个）" % n, n >= 1 and g.state == "investigate")
	# 被发现 → 惩罚 → 回小屋 → 第二天
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	# 士兵回到一开始验证过视线的地方，面朝公主
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.global_position = g_home
	g.cone.facing = Vector2.RIGHT
	player.global_position = g_home + Vector2(36, 0)
	d.alert = 0.98
	await _advance_until(func(): return Sleep.day() == 3 and not Sleep.sleeping and not Cutscene.is_playing() and not CG.is_busy() and _level_id() == "floor_06_house", 120.0)
	CG.started.disconnect(on_cg)
	check("警觉满了被抓 → 营地地牢的惩罚小剧场（%s）→ 蓝色公主领回小屋 → 睡一觉到第 3 天" % [cg_seen],
		int(GameState.vars.get("f6_caught", 0)) == 1 and cg_seen.has("theater:f6_caught_1") and Sleep.day() == 3 and _level_id() == "floor_06_house"
		and GameState.has_flag("cutscene_seen_f6_morning_retry"))
	var th: Array = [1, 2, 3].map(func(i): return (JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/floor_06/f6_caught_%d.json" % i)) as Dictionary)["steps"].filter(func(st): return st.has("text")).size())
	check("被抓的惩罚按次数 3 种，每段都长（%s 句）" % [th], th.all(func(x): return x >= 14))


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
