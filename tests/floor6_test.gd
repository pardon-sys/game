extends Node
## 第六层·地下小镇测试：四张地图和楼梯、居民（友军、溜达、对话）、篝火 / 市场 / 训练接口、存档点、
## 开场剧情（三种态度各跑一遍，后续台词不同，结束后自由活动）、第五层结局 → 第六层、封住的入口。
## 用法：Godot --headless --path . res://tests/floor6_test.tscn   （退出码 0 = 全部通过）

const LEVELS := ["floor_06_prison", "floor_06_upper", "floor_06_camp", "floor_06_mine"]
const KEY_NPCS := ["captain", "supervisor", "bonfire_host", "blue_princess"]

var main: Node
var player: Princess
var failures := 0
var picks: Array = []
var asked: Array = []


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	SaveSystem.dir = "user://test_saves_f6/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	await _run_maps()
	await _run_opening()
	await _run_town()
	await _run_stairs()
	await _run_transition()
	for s in range(1, SaveSystem.SLOTS + 1):
		SaveSystem.delete(s)
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 地图结构（不进场景树，直接看构建产物）
func _run_maps() -> void:
	print("-- 四张地图")
	var spawns := {}
	var stairs: Array = []
	var residents := 0
	var keys := {}
	var save_points := 0
	var bonfires := 0
	var stalls := 0
	var dummies := 0
	for id in LEVELS:
		check("%s 构建好、floor_id 正确、同属 floor_06 组" % id, ResourceLoader.exists(Floors.scene(id)) and Floors.group(id) == "floor_06")
		var lv: Node = load(Floors.scene(id)).instantiate()
		check("%s 根节点 floor_id" % id, lv.get("floor_id") == id)
		spawns[id] = []
		for n in lv.find_children("*", "", true, false):
			if n is SpawnPoint:
				spawns[id].append(n.id)
			elif n.get_script() == load("res://scripts/objects/level_exit.gd") and n.find_child("Look", false, false):
				stairs.append([id, n.target_level, n.spawn])
			elif n is Resident:
				if KEY_NPCS.has(n.npc_id):
					keys[n.npc_id] = id
				else:
					residents += 1
				if n.dialogue == "" or not FileAccess.file_exists(DialogueRunner.path_of(n.dialogue)):
					check("居民 %s 的对话文件存在（%s）" % [n.name, n.dialogue], false)
			elif n.get_script() == load("res://scripts/objects/save_point.gd"):
				save_points += 1
			elif n.get_script() == load("res://scripts/objects/prop.gd"):
				var k := str(n.get("kind"))
				bonfires += 1 if k.begins_with("bonfire") and n.get("action") == "heal" else 0
				stalls += 1 if str(n.get("action")).begins_with("shop:") else 0
				dummies += 1 if n.get("action") == "training" else 0
		lv.free()
	var bad: Array = []
	for s in stairs:
		var target_id := ""
		for id in LEVELS:
			if Floors.scene(id) == s[1]:
				target_id = id
		if target_id == "" or not spawns[target_id].has(s[2]):
			bad.append(s)
	check("楼梯 %d 个，都通向别的小镇地图，目标地图有同名到达点（坏的：%s）" % [stairs.size(), bad], stairs.size() >= 6 and bad.is_empty())
	check("约 15 个居民（%d 个）" % residents, residents >= 14)
	check("关键人物都在：队长在营地、市场监督和篝火派对的主人在集市层、蓝色公主在集市层广场",
		keys.get("captain") == "floor_06_camp" and keys.get("supervisor") == "floor_06_upper"
		and keys.get("bonfire_host") == "floor_06_upper" and keys.get("blue_princess") == "floor_06_upper")
	check("小镇里只有一个存档点", save_points == 1)
	check("篝火（回血）、市场摊位（交易）、训练台（训练）都有", bonfires >= 1 and stalls >= 6 and dummies >= 1)


# ------------------------------------------------------------------ 开场
func _run_opening() -> void:
	print("-- 开场：营地地牢")
	var lines_by_att := {}
	for att_i in 3:
		var att: String = ["honest", "defiant", "beg"][att_i]
		GameState.flags.erase("intro_done_f6_wake")
		GameState.flags.erase("f6_opening_done")
		GameState.vars.erase("f6_attitude")
		for k in GameState.flags.keys():
			if str(k).begins_with("dlg_floor_06/") or str(k).begins_with("cutscene_seen_"):
				GameState.flags.erase(k)
		main.change_level(Floors.scene("floor_06_prison"))
		await _wait(1.6)
		player = GameState.player as Princess
		check("[%s] 进入营地地牢播开场过场 f6_wake" % att, Cutscene.is_playing() and Cutscene.current == "f6_wake")
		var nodes: Array = []
		var on_node := func(f: String, n: String): nodes.append(f.get_file() + ":" + n)
		Dialogue.runner.node_entered.connect(on_node)
		var held := [false, false]
		var theater := [""]
		var on_cg := func(id: String): theater[0] = id
		CG.started.connect(on_cg)
		var blue_seen := [false]
		picks = [att_i]
		asked.clear()
		var guard := 0
		while guard < 4000 and (Cutscene.is_playing() or Dialogue.runner.is_running() or Dialogue.is_active() or CG.is_busy()):
			guard += 1
			if player.get("puppet_anim") == "grabbed":
				if is_equal_approx(player.pose_rotation, -PI / 2.0):
					held[0] = true
				elif player.pose_offset == Vector2(0, 3):
					held[1] = true
			if Cutscene.spawned.has("blue"):
				blue_seen[0] = true
			await _step()
		Dialogue.runner.node_entered.disconnect(on_node)
		CG.started.disconnect(on_cg)
		check("[%s] 先被刑床 + 足枷 + 夹腿枷台困住（仰躺），中途换到挠痒坐垫 + 举手铐柱" % att, held[0] and held[1])
		check("[%s] 关键选择弹出三种态度" % att, asked.size() >= 1 and asked[0].size() == 3 and "老老实实" in asked[0][0]
			and "顶嘴" in asked[0][1] and "求饶" in asked[0][2])
		check("[%s] 选择记进 f6_attitude，队长的回应、惩罚小剧场、蓝色公主的台词都随之不同" % att, GameState.vars.get("f6_attitude") == att
			and nodes.has("captain:ans_" + att) and nodes.has("captain:punish_" + att) and theater[0] == "theater:f6_punish_" + att
			and nodes.has("blue_princess:rescue_" + att))
		check("[%s] 蓝色公主出场叫停" % att, blue_seen[0])
		check("[%s] 开场结束：f6_opening_done、刑具松开、过场演员离场、可以自由活动" % att, GameState.has_flag("f6_opening_done")
			and player.get("puppet_anim") == "" and player.pose_rotation == 0.0 and Cutscene.spawned.is_empty()
			and not GameState.in_cutscene and not GameState.in_dialogue)
		lines_by_att[att] = nodes
	check("三种态度走的节点各不相同", lines_by_att["honest"] != lines_by_att["defiant"] and lines_by_att["defiant"] != lines_by_att["beg"])
	# 自由活动：能走
	player.set_controller(ScriptedController.new())
	var c := player.controller as ScriptedController
	var p0 := player.global_position
	c.move = Vector2.LEFT
	await _wait(0.5)
	c.move = Vector2.ZERO
	check("开场后公主能自己走动", player.global_position.distance_to(p0) > 8.0)
	# 再进来不重播
	main.change_level(Floors.scene("floor_06_camp"))
	await _wait(1.4)
	main.change_level(Floors.scene("floor_06_prison"))
	await _wait(1.6)
	check("再回到地牢不会重播开场", not Cutscene.is_playing())
	var jailer: Resident = _find_resident("guard_jailer")
	check("开场后地牢的看守出现（show_flag）", jailer != null and jailer.visible)


# ------------------------------------------------------------------ 小镇设施和居民
func _run_town() -> void:
	print("-- 集市层：居民、篝火、市场、存档点")
	GameState.set_var("f6_attitude", "defiant")
	main.change_level(Floors.scene("floor_06_upper"))
	await _wait(1.4)
	_finish_dialogue()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	check("小镇里没有敌人", get_tree().get_nodes_in_group("enemy").is_empty())
	var kid: Resident = _find_resident("kid_tom")
	check("居民是友军", kid != null and kid.faction == Faction.Type.ALLY and kid.is_in_group("ally"))
	var start := kid.global_position
	var moved := false
	for i in 40:
		await _wait(0.15)
		moved = moved or kid.global_position.distance_to(start) > 4.0
	check("居民会在附近溜达", moved and kid.global_position.distance_to(kid._home) <= kid.wander * 16.0 + 12.0)
	var blue: Resident = _find_resident("blue_princess")
	check("开场后蓝色公主出现在广场（show_flag）", blue != null and blue.visible)
	# 和居民说话：停下、转向公主、台词按态度不同
	player.global_position = kid.global_position + Vector2(14, 0)
	var nodes: Array = []
	var on_node := func(_f: String, n: String): nodes.append(n)
	Dialogue.runner.node_entered.connect(on_node)
	kid.talk(player)
	await _wait(0.2)
	check("和居民对话：居民停下并转向公主", kid.talking and kid.velocity == Vector2.ZERO and kid.facing.x > 0.5)
	await _drive()
	check("居民的台词按开场态度（顶嘴）不同", nodes.has("hello_defiant"))
	# 蓝色公主：「回到选项页」型菜单
	nodes.clear()
	picks = [0, 5]
	asked.clear()
	blue.talk(player)
	await _wait(0.3)
	check("关键人物对话显示右侧立绘（蓝色调的公主）", Dialogue.npc_portrait.visible)
	await _drive()
	check("蓝色公主：问完「你是谁」回到选项页，再选「先这样吧」结束", asked.size() == 2 and nodes.has("who") and nodes.has("bye"))
	Dialogue.runner.node_entered.disconnect(on_node)
	# 篝火
	var fire := _find_prop("heal")
	player.health.damage(2)
	player.laugh.set_value(player.laugh.max_value * 0.5)
	fire.call("on_interact", player)
	await _wait(0.2)
	check("篝火：回满生命、闷笑清零", player.health.hp == player.health.max_hp and player.laugh.value == 0.0)
	# 市场
	var coins := GameState.inventory.count("coin")
	GameState.give_item(ItemDB.get_item("coin"), 20 - coins)
	Town.open_shop("market")
	await _wait(0.2)
	var shop: ShopUI = null
	for c in get_tree().root.get_children():
		if c is ShopUI:
			shop = c
	check("市场：打开商店界面（暂停游戏）", shop != null and get_tree().paused)
	if shop:
		var mint := GameState.inventory.count("mint")
		check("买薄荷糖：扣 3 金币，多一个", shop.buy(0) and GameState.inventory.count("coin") == 17 and GameState.inventory.count("mint") == mint + 1)
		var star := shop.items().map(func(it): return it["id"]).find("star_candy")
		shop.buy(star)
		check("限量商品库存减少（星星糖还剩 1）", shop.stock_left(star) == 1)
		GameState.inventory.remove("coin", GameState.inventory.count("coin"))
		check("金币不够买不了", not shop.buy(0))
		shop.close()
		await _wait(0.1)
		check("关掉商店取消暂停", not get_tree().paused)
	# 训练接口
	check("训练接口：3 个训练项目（以后各自是小游戏），现在都还没开放", TrainingDB.list().size() == 3
		and not TrainingDB.start("endure").get("ok", true) and str(TrainingDB.start("").get("message", "")) != ""
		and DirAccess.dir_exists_absolute("res://scenes/training"))
	# 存档点
	var sp: Node = null
	for n in main.level.find_children("*", "", true, false):
		if n.get_script() == load("res://scripts/objects/save_point.gd"):
			sp = n
	check("集市层的存档点", sp != null and sp.get("place") == "集市广场")
	# 封住的地牢入口
	var gate: Node = null
	for n in main.level.find_children("*", "", true, false):
		if n.get_script() == load("res://scripts/objects/level_exit.gd") and n.get("locked"):
			gate = n
	if gate:
		player.global_position = (gate as Node2D).global_position
		await _wait(0.6)
		_finish_dialogue()
	check("封住的入口进不去（还在集市层）", gate != null and main.level.get("floor_id") == "floor_06_upper")


# ------------------------------------------------------------------ 楼梯
func _run_stairs() -> void:
	print("-- 楼梯上下")
	player = GameState.player as Princess
	var to_camp: Node2D = _find_stairs("floor_06_camp")
	player.global_position = to_camp.global_position + Vector2(0, -2)
	await _wait(1.6)
	player = GameState.player as Princess
	var sp := _find_spawn("from_upper")
	check("集市层下楼梯 → 营地层，站在 from_upper 到达点", main.level.get("floor_id") == "floor_06_camp" and sp != null
		and player.global_position.distance_to(sp.global_position) < 1.0)
	var cap: Resident = _find_resident("captain")
	check("队长在营地的指挥帐篷前", cap != null and cap.visible)
	GameState.set_var("f6_attitude", "beg")
	check("队长按态度打招呼（求饶 → hello_beg）", Dialogue.runner.entry_of("floor_06/captain") == "hello_beg")
	await _wait(0.5)
	var to_prison: Node2D = _find_stairs("floor_06_prison")
	player.global_position = to_prison.global_position + Vector2(0, -2)
	await _wait(1.6)
	player = GameState.player as Princess
	check("营地层下楼梯 → 地牢，站在 from_camp", main.level.get("floor_id") == "floor_06_prison" and _find_spawn("from_camp") != null
		and player.global_position.distance_to(_find_spawn("from_camp").global_position) < 1.0)
	await _wait(0.5)
	var up: Node2D = _find_stairs("floor_06_camp")
	player.global_position = up.global_position + Vector2(0, -2)
	await _wait(1.6)
	check("地牢上楼梯 → 回到营地", main.level.get("floor_id") == "floor_06_camp")
	await _wait(0.5)
	player = GameState.player as Princess
	var mine: Node2D = _find_stairs("floor_06_mine")
	player.global_position = mine.global_position + Vector2(0, -2)
	await _wait(1.6)
	check("营地层下楼梯 → 矿道层", main.level.get("floor_id") == "floor_06_mine")


# ------------------------------------------------------------------ 第五层结局 → 第六层
func _run_transition() -> void:
	print("-- 第五层结局之后进入第六层")
	var cs: Dictionary = Cutscene.load_cutscene("f5_ending")
	var last: Dictionary = cs["steps"][-1]
	var ce: Array = last.get("actions", []).filter(func(a): return a.get("do") == "chapter_end")
	check("第五章结束画面写了下一层 floor_06_prison", not ce.is_empty() and ce[0].get("next") == "floor_06_prison")
	main.change_level(Floors.scene("floor_05"))
	await _wait(1.6)
	await _drive()
	GameState.flags.erase("intro_done_f6_wake")
	Cutscene.play_data("test_end", {"steps": [{"actions": [{"do": "chapter_end", "title": "第五章　完", "next": "floor_06_prison"}], "wait": 0.2}]})
	await _wait(1.8)
	check("章节结束画面显示「按 E 继续」", Cutscene.chapter_screen.visible and Cutscene.chapter_hint.visible)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(1.8)
	check("按 E 后进入第六层营地地牢，开场过场开始", main.level.get("floor_id") == "floor_06_prison" and not Cutscene.chapter_screen.visible
		and Cutscene.is_playing() and Cutscene.current == "f6_wake")
	picks = [1]
	await _drive()


# ------------------------------------------------------------------ 工具
func _find_resident(dialogue_name: String) -> Resident:
	for n in get_tree().get_nodes_in_group("ally"):
		if n is Resident and (n.dialogue.get_file() == dialogue_name or n.npc_id == dialogue_name) and main.level.is_ancestor_of(n):
			return n
	for n in main.level.find_children("*", "", true, false):
		if n is Resident and (n.dialogue.get_file() == dialogue_name or n.npc_id == dialogue_name):
			return n
	return null


func _find_prop(action: String) -> Node:
	for n in main.level.find_children("*", "", true, false):
		if n.get_script() == load("res://scripts/objects/prop.gd") and n.get("action") == action:
			return n
	return null


func _find_stairs(target_id: String) -> Node2D:
	for n in main.level.find_children("*", "", true, false):
		if n.get_script() == load("res://scripts/objects/level_exit.gd") and n.get("target_level") == Floors.scene(target_id) and not n.get("locked"):
			return n
	return null


func _find_spawn(id: String) -> Node2D:
	for n in main.level.find_children("*", "", true, false):
		if n is SpawnPoint and n.id == id:
			return n
	return null


func _step() -> void:
	var cm: ChoiceMenu = Dialogue.runner.choice_menu
	if cm.is_open():
		asked.append(cm.options.duplicate())
		cm.choose(picks.pop_front() if not picks.is_empty() else 0)
	elif Dialogue.is_active():
		Dialogue.advance()
		Dialogue.advance()
	await _wait(0.03)


func _drive() -> void:
	var guard := 0
	await get_tree().process_frame
	while guard < 4000 and (Dialogue.runner.is_running() or Dialogue.is_active() or Cutscene.is_playing() or CG.is_busy()):
		guard += 1
		await _step()


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
	await get_tree().create_timer(sec, true, false, true).timeout
