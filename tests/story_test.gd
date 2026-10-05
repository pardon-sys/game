extends Node
## 剧情 / 界面测试：立绘避让；第六层后续剧情（参观小镇 → 蓝色小屋 → 夜晚 → 骑马刷凳 → 钥匙 → 睡觉 → 第二天）（后面几节）。
## 用法：Godot --headless --path . res://tests/story_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


class Src extends Node2D:
	var reaction_key := ""
	var tickle_zones := {}


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
	await _run_blue_arc()
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
	check("公主走到立绘的位置：立绘变成 30%% 透明度（%.2f）" % Dialogue.portrait.self_modulate.a, Dialogue.player_behind_portrait()
		and Dialogue.PORTRAIT_FADE_ALPHA == 0.3 and absf(Dialogue.portrait.self_modulate.a - Dialogue.PORTRAIT_FADE_ALPHA) < 0.05)
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
	# 脚步声：站着不动没声音；走动时 7 格内（背后看不见的）士兵过来查看，再远的听不见
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.state = "walk"
	player.global_position = g.global_position + Vector2(-50, 0)
	player.velocity = Vector2.ZERO
	d._footsteps(player, 1.0)
	d._footsteps(player, 1.0)
	var still_quiet := g.state != "investigate"
	player.global_position = g.global_position + Vector2(-140, 0)
	player.velocity = Vector2(60, 0)
	d._step_t = 0.0
	d._footsteps(player, 0.1)
	var far_quiet := g.state != "investigate"
	player.global_position = g.global_position + Vector2(-50, 0)
	d._step_t = 0.0
	d._footsteps(player, 0.1)
	check("脚步声：站着不动不会引来士兵，走动时 %d 像素内的士兵过来查看（再远的听不见），查看时走得快（%d → %d）" % [StealthDirector.STEP_RADIUS, g.speed, g.investigate_speed],
		still_quiet and far_quiet and g.state == "investigate" and g.sees(player) == 0.0 and g.investigate_speed > g.speed)
	# 士兵检查躲藏点：先飘一句提示、停 1 秒——这 1 秒里出来就不会被抓
	g.state = "walk"
	var crate2: Node2D = main.level.find_children("*", "", true, false).filter(func(n): return n.get("action") == "hide")[0]
	StealthDirector.toggle_hide(player, crate2)
	g._begin_check(d, crate2)
	var warned: bool = g._checking == crate2 and not d.caught_done and g.state == "look"
	StealthDirector.toggle_hide(player, crate2)
	await _wait(PatrolGuard.CHECK_DELAY + 0.2)
	check("士兵检查木箱前先飘提示、停 1 秒；这 1 秒里出来就没被抓", warned and not d.caught_done)
	# 系统提示太长时自动换行、不出屏幕
	GameState.notify("这是一条很长很长的系统提示，用来检查黄色的提示文字会不会自动换行，而不是一直延伸到屏幕外面去。再加一点点字，确保它一定会换行。")
	await get_tree().process_frame
	var hud: HUD = get_tree().root.find_children("*", "", true, false).filter(func(n): return n is HUD)[0]
	var vw := get_viewport().get_visible_rect().size.x
	check("黄色系统提示自动换行（%d 行）、不超出屏幕" % hud.toast_label.get_line_count(),
		hud.toast_label.get_line_count() >= 2 and hud.toast_label.position.x >= 0.0 and hud.toast_label.position.x + hud.toast_label.size.x <= vw)
	player.velocity = Vector2.ZERO
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
	var prison: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/floor_06/f6_caught_prison_1.json"))
	check("地牢过场里公主在保卫处下面的大牢房里（第六章开头那间，不在楼梯口）",
		prison["steps"][0]["actions"].any(func(a): return a.get("do") == "move" and a.get("who") == "princess" and int(a.get("to", [0, 0])[0]) == 19 and int(a.get("to", [0, 0])[1]) == 13))
	# 第 4 次起：直接放回矿道入口
	GameState.vars["f6_caught"] = 3
	GameState.pending_spawn = "from_camp"
	await main.change_level(Floors.scene("floor_06_mine"))
	await _wait(0.6)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	var spawn_pos := Vector2.ZERO
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if str(sp.get("id")) == "from_camp" and main.level.is_ancestor_of(sp):
			spawn_pos = (sp as Node2D).global_position
	player.global_position = spawn_pos + Vector2(200, 60)
	var seen4 := []
	var on_cut4 := func(id: String): seen4.append(id)
	Cutscene.started.connect(on_cut4)
	F6Story.on_caught()
	await _advance_until(func(): return seen4.has("f6_caught_again") and not Cutscene.is_playing(), 60.0)
	await _wait(0.3)
	Cutscene.started.disconnect(on_cut4)
	var leftover: int = main.level.find_children("Cutscene_cg*", "", true, false).filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size()
	check("被抓第 4 次之后围上来的士兵离场了（还剩 %d 个）" % leftover, leftover == 0 and not Cutscene.spawned.has("cg1") and not Cutscene.spawned.has("cg2"))
	# 过场里走路不穿墙：直线上有墙时沿地面绕过去
	# 找一块直线过去会穿墙、但沿地面走得到的地方
	var far := spawn_pos
	var floor_layer: TileMapLayer = main.level.get_node("Floor")
	var walls_layer: TileMapLayer = main.level.get_node("Walls")
	for c in floor_layer.get_used_cells():
		if walls_layer.get_cell_source_id(c) != -1 or (c.x + c.y) % 3 != 0:
			continue
		var p := Cutscene.cell_to_world([c.x, c.y])
		if p.distance_to(spawn_pos) > 120.0 and Cutscene._blocked(main.level, spawn_pos, p) and not GridPath.find(main.level, spawn_pos, p, 6000).is_empty():
			far = p
			break
	var route: Array[Vector2] = Cutscene._route(spawn_pos, far)
	var prev := spawn_pos
	var clear := true
	for p in route:
		clear = clear and not Cutscene._blocked(main.level, prev, p)
		prev = p
	check("过场里走路不穿墙：矿道入口走到墙后面的地方，路线 %d 段，每段都不穿过墙（直线有墙 %s、格子路 %d 步、距离 %.0f）" % [route.size(),
		Cutscene._blocked(main.level, spawn_pos, far), GridPath.find(main.level, spawn_pos, far, 6000).size(), spawn_pos.distance_to(far)],
		Cutscene._blocked(main.level, spawn_pos, far) and route.size() > 1 and clear)
	check("被抓第 4 次：统一的短过场（%s）→ 直接在矿道入口重新开始（不回小屋）（%s、第 %d 次、离入口 %.0f、警觉 %.2f、%s）" % [seen4, _level_id(),
		int(GameState.vars["f6_caught"]), player.global_position.distance_to(spawn_pos), StealthDirector.current.alert, StealthDirector.current.caught_done],
		seen4.has("f6_caught_again") and _level_id() == "floor_06_mine" and int(GameState.vars["f6_caught"]) == 4
		and player.global_position.distance_to(spawn_pos) < 20.0 and not StealthDirector.current.caught_done and StealthDirector.current.alert == 0.0)


# ------------------------------------------------------------------ 第七层：粉色公主往上冲 → 主角换成蓝色公主
func _run_blue_arc() -> void:
	print("-- 第七层：粉色公主进塔 → 蓝色公主当主角 → 和队长争吵 → 升天回廊")
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	await main.change_level(Floors.scene("floor_07"))
	# 交接过程中（换关卡、过场、黑幕）介绍板不能弹出来——之前会在换关卡的空隙里弹出、暂停游戏，卡在黑屏
	var bad_board := [0]
	var watch := func():
		if TutorialBoard.is_open() and (main.get("_busy") == true or Cutscene.is_playing() or Cutscene.curtain.color.a > 0.05):
			bad_board[0] += 1
	get_tree().process_frame.connect(watch)
	await _advance_until(func(): return _level_id() == "floor_06_house_up" and not Cutscene.is_playing() and GameState.has_flag("f7_blue_awake"), 60.0)
	var hero = GameState.player
	check("粉色公主走进第七层（过场 f7_pink_run）→ 主角换成蓝色公主，在小屋楼上醒来（%s）" % [seen],
		seen.has("f7_pink_run") and seen.has("f7_blue_wake") and hero is BluePrincess and hero.hero and GameState.has_flag("blue_is_hero"))
	await _wait(1.6)
	check("在小屋楼上醒来时不弹介绍板（交接不卡住）", not TutorialBoard.is_open() and not get_tree().paused and not GameState.has_flag("intro_blue_magic"))
	# 她自己的基础数值和训练记录
	GameState.vars["train_fatigue_up"] = 60.0
	var blue_train := TrainingStats.value("train_fatigue_up")
	Characters.scope("pink")
	var pink_train := TrainingStats.value("train_fatigue_up")
	Characters.unscope()
	check("蓝色公主有自己的训练记录（粉色公主的 %d，她的 %d）和基础数值（闷笑上限 %d、魔法冷却 %.0f 秒）" % [pink_train, blue_train, hero.laugh.max_value, hero.magic_cooldown],
		pink_train == 60.0 and blue_train == 0.0 and is_equal_approx(hero.laugh.max_value, 165.0) and is_equal_approx(hero.magic_cooldown, 7.0))
	GameState.vars.erase("train_fatigue_up")
	check("蓝色公主：玩家操控、相机跟着她、用她的立绘套装和角色档案", hero.faction == Faction.Type.PLAYER and hero.camera.is_current()
		and hero.portrait_set == "blue" and Characters.current() == "blue" and hero.controller is PlayerInputController)
	var calm: Array = ReactionDB.lines("slime", "calm")
	var h2: Array = ReactionDB.lines("slime", "helpless_2")
	check("她的受挠台词是三无风格：平时很短（%s），失控后变长（%s）" % [calm[0], h2[0]],
		calm.all(func(t): return str(t).length() <= 14 and str(t).begins_with("……")) and h2.all(func(t): return str(t).length() > 20)
		and not str(ReactionDB.lines("", "calm")).contains("本公主"))
	check("她的部位表：大腿和屁股最怕（大腿 ×%.2f、屁股 ×%.2f、脚心 ×%.2f）" % [TickleZones.info("thigh")["sensitivity"], TickleZones.info("butt")["sensitivity"], TickleZones.info("sole")["sensitivity"]],
		TickleZones.info("thigh")["sensitivity"] >= 1.4 and TickleZones.info("butt")["sensitivity"] >= 1.4 and TickleZones.info("sole")["sensitivity"] < 1.0)
	var slime_cg: Dictionary = CG.cgs().get("death_slime", {})
	check("她的笑倒 CG / 组合演出是转换过的蓝色版（说话人、立绘），魔力疲倦爆发立绘是最后一格",
		slime_cg.get("steps", []).any(func(st): return st.get("speaker", "") == "蓝色的公主") and CG.scenes.size() == 73
		and str(CG.data["portraits"]["fatigue_burst"]["placeholder"]) == "damaged_giggle_burst" and hero.fatigue_burst_visual() == "damaged_giggle_burst"
		and GameState.VISUALS.find("damaged_giggle_burst") == GameState.VISUALS.size() - 1)
	check("训练成果只算粉色公主（换成她之后部位修正为 0）", TrainingStats.zone_modifier("sole") == 0.0)
	# 她说话时右边不再重复显示她的立绘（左边的主角立绘换表情）
	Dialogue.start_lines([{"speaker": "蓝色的公主", "text": "……嗯。", "emotion": "giggle"}])
	await get_tree().process_frame
	check("蓝色公主当主角时她说话：右边没有她的立绘、左边立绘不变暗", Dialogue.is_active() and not Dialogue.npc_portrait.visible
		and Dialogue.portrait.visible and Dialogue.portrait.modulate == Color.WHITE)
	_finish()
	Dialogue.talk("floor_06/house_objects", "bed")
	await _wait(0.2)
	check("她调查小屋楼下的东西：是她自己的台词（%s）" % Dialogue.text_label.text, Dialogue.text_label.text.contains("她睡过的床"))
	_finish()
	await _wait(0.2)
	check("她的笑声是自己的（%s / %s）" % [Audio.voice_key("giggle"), Audio.voice_key("laugh")],
		Audio.voice_key("giggle") == "blue_giggle" and Audio.voice_key("laugh") == "blue_laugh"
		and Audio.loop_stream("laugh") is AudioStreamMP3 and (Audio.loop_stream("laugh") as AudioStreamMP3).loop)
	var h1: Array = ReactionDB.lines("slime", "helpless_1")
	var w1 = ReactionDB.portrait_words("slime", "helpless_1", "")
	check("失控一就憋不住笑了（%s），立绘飘字也是她的（%s）" % [h1[0], w1],
		h1.all(func(t): return str(t).contains("哈")) and w1 is Array and not (w1 as Array).is_empty()
		and (w1 as Array).all(func(t): return str(t).contains("哈") or str(t).contains("憋")))
	check("小镇放小镇的配乐（%s）" % Audio.music_id, Audio.music_id == "town")
	# 出门 → 和队长争吵 → 第七层
	seen.clear()
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene("floor_06_upper"))
	await _advance_until(func(): return _level_id() == "floor_07" and not Cutscene.is_playing() and GameState.has_flag("cutscene_seen_f7_blue_arrive"), 90.0)
	Cutscene.started.disconnect(on_cut)
	hero = GameState.player
	var saves: Array = main.level.find_children("*", "", true, false).filter(func(n): return n.scene_file_path.ends_with("save_point.tscn"))
	check("走出小屋 → 和队长争吵 → 第七层（%s），蓝色公主站在塔底、旁边是本层唯一的存档点" % [seen],
		seen == ["f7_blue_argue", "f7_blue_arrive"] and hero is BluePrincess and saves.size() == 1
		and hero.global_position.distance_to((saves[0] as Node2D).global_position) < 80.0)
	# 第七层塔底的过场放完、开始自由活动时弹出她的魔法介绍板
	await _advance_until(func(): return TutorialBoard.is_open(), 8.0)
	get_tree().process_frame.disconnect(watch)
	var board_ok: bool = TutorialBoard.is_open() and get_tree().paused and bad_board[0] == 0 and TutorialBoard.current.layer > 50 and _level_id() == "floor_07"
	if TutorialBoard.is_open():
		TutorialBoard.current.close()
	check("第七层塔底的过场放完、开始自由活动时才弹出冰晶结界的介绍板（盖在黑幕上面，游戏暂停），关掉后继续（换关卡 / 过场中弹出 %d 次）" % bad_board[0],
		board_ok and not get_tree().paused and GameState.has_flag("intro_blue_magic"))
	# 第七层的新组合
	var fired := []
	var on_fired := func(id: String): fired.append(id)
	hero.combo.triggered.connect(on_fired)
	for spec in [["spider_binding_brush", ["spider", "binding", "hedgehog"]], ["octopus_vest", ["octopus", "vest", "fairy"]],
			["wardrobe_ghost", ["ghost", "glove", "wardrobe"]], ["mud_frog_dance", ["mud", "frog", "caterpillar"]],
			["supine_jelly", ["supine", "mana_jelly", "bubble_fish"]], ["cushion_cage", ["cushion", "cage", "rat"]],
			["spin_barnacle", ["spinwheel", "barnacle", "squirrel"]], ["legloop_glove", ["legloop", "teaser", "glove"]],
			["loop_rack", ["legloop", "supine", "frog"]], ["prone_wheel_crawl", ["prone", "wheel", "caterpillar"]],
			["cuffs_shower_slime", ["cuffs", "shower", "slime"]], ["rune_wings", ["rune", "bat", "fairy"]]]:
		hero.combo.reset()
		hero._full_invuln = 0.0
		for k in spec[1]:
			var s := Src.new()
			s.reaction_key = k
			main.level.get_node("Entities").add_child(s)
			s.global_position = hero.global_position + Vector2(20, 0)
			hero.receive_hit(HitData.make_tickle(s, 1.0))
		await _wait(0.1)
	hero.combo.triggered.disconnect(on_fired)
	var want := ["spider_binding_brush", "octopus_vest", "wardrobe_ghost", "mud_frog_dance", "supine_jelly", "cushion_cage", "spin_barnacle", "legloop_glove",
		"loop_rack", "prone_wheel_crawl", "cuffs_shower_slime", "rune_wings"]
	check("第七层 12 组新组合都能触发，有组合台词和（蓝色版的）组合演出（%s）" % [want.filter(func(c): return not fired.has(c))],
		want.all(func(c): return fired.has(c) and CG.scenes.has(c) and ReactionDB.combo(c).get("name", "") != ""))
	var cps: Array = main.level.find_children("*", "", true, false).filter(func(n): return n.scene_file_path.ends_with("checkpoint.tscn"))
	check("第七层：4 个检查点、地牢配乐（%d / %s）" % [cps.size(), Audio.music_id], cps.size() == 4 and Audio.music_id == "dungeon")
	await _run_ice_barrier(hero)


## 蓝色公主的冰晶结界：冻住范围内的怪物和陷阱，期间她的闷笑不涨；到时间陷阱恢复。
func _run_ice_barrier(hero: BluePrincess) -> void:
	print("-- 蓝色公主的冰晶结界")
	var lv: Node = main.level
	var mon: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	lv.get_node("Entities").add_child(mon)
	mon.global_position = hero.global_position + Vector2(30, 0)
	var far: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	lv.get_node("Entities").add_child(far)
	far.global_position = hero.global_position + Vector2(160, 0)
	var trap: Trap = load("res://scenes/traps/feather_trap.tscn").instantiate()
	lv.add_child(trap)
	trap.global_position = hero.global_position + Vector2(-30, 0)
	await get_tree().physics_frame
	var hit := IceBarrier.cast(hero, 1)
	check("冰晶结界（1 档 48 像素）：范围内的怪物冻住、陷阱停住，远处的不受影响",
		hit.has(mon) and hit.has(trap) and not hit.has(far) and mon._stun_left > 1.5 and not trap.active and far._stun_left <= 0.0)
	hero.laugh.value = 0.0
	hero._full_invuln = 0.0
	hero.combo.reset()
	var s := Src.new()
	s.reaction_key = "slime"
	lv.get_node("Entities").add_child(s)
	s.global_position = hero.global_position + Vector2(20, 0)
	hero.receive_hit(HitData.make_tickle(s, 5.0))
	check("冰晶守护期间被挠闷笑不涨（%.1f）" % hero.laugh.value, hero.has_buff("frost_guard") and hero.laugh.value == 0.0)
	await _wait(1.2)
	var fx_mid := lv.find_children("*", "", true, false).filter(func(n): return n is IceBarrier).size()
	await _wait(1.1)
	check("2 秒后陷阱恢复；冰晶结界的特效一直留到冻结结束（1.2 秒时还在：%d 个）" % fx_mid, trap.active and trap.modulate == Color.WHITE and fx_mid >= 1)
	check("她的魔法台词是冰晶结界的", str(ReactionDB.magic("burst")).contains("冻") or str(ReactionDB.magic("burst")).contains("结界"))
	# 组合台词：不念组合名，说手法和感受；碰到大腿 / 屁股的明显更崩
	var named := []
	var weak_ok := true
	var rx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/blue/reactions.json"))
	for cid in rx.get("combos", {}):
		var c = rx["combos"][cid]
		if not c is Dictionary:
			continue
		var lines: Array = c.get("lines", [])
		for l in lines:
			if str(c.get("name", "~")) in str(l):
				named.append(cid)
		var first := str(lines[0]) if not lines.is_empty() else ""
		if (first.contains("大腿") or first.contains("屁股")) and not str(lines).contains("哈哈哈"):
			weak_ok = false
	check("蓝色公主的组合台词不念组合名（%s），碰到大腿 / 屁股的那些笑到崩" % [named.slice(0, 3)], named.is_empty() and weak_ok)
	var th: Array = rx["combos"]["th_brush_feast"]["lines"]
	check("三来源组合（%s）也是说手法：带「屁股」「哈哈哈」" % [th[0]], str(th).contains("屁股") and str(th).contains("哈哈哈"))
	# 疲倦爆发：带满蓄力范围、一半时间的冰晶控制
	await _wait(2.5)
	var m2: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	lv.get_node("Entities").add_child(m2)
	m2.global_position = hero.global_position + Vector2(80, 0)
	await get_tree().physics_frame
	hero.fatigue_burst()
	check("疲倦爆发也冻住范围内的怪物（满蓄力范围 96、冻 %.1f 秒）" % m2._stun_left, m2._stun_left > 1.5 and m2._stun_left <= 2.01)
	m2.queue_free()
	for n in [mon, far, trap, s]:
		n.queue_free()


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
