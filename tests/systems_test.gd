extends Node
## 新系统测试：人物对话（两种选项模式、条件、效果、一次性选项、条件跳转、演绎）、选择记忆、
## 存档 / 读档、存档位界面、存档点、主界面、暂停菜单回主界面、对话 / 过场文件迁移。
## 用法：Godot --headless --path . res://tests/systems_test.tscn   （退出码 0 = 全部通过）

const TEST_SAVES := "user://test_saves/"

var main: Node
var player: Princess
var failures := 0
## 选项队列：驱动对话时依次选这些（用完选第一个）。
var picks: Array = []
## 每次弹出选项时显示的选项文本。
var asked: Array = []


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	SaveSystem.dir = TEST_SAVES
	for s in range(1, SaveSystem.SLOTS + 1):
		SaveSystem.delete(s)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _run_migration()
	await _run_dialogue_modes()
	await _run_memory()
	await _run_performances()
	await _run_save_load()
	await _run_slot_menu_and_save_point()
	await _run_title()
	for s in range(1, SaveSystem.SLOTS + 1):
		SaveSystem.delete(s)
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 迁移
func _run_migration() -> void:
	print("-- 对话 / 过场 / 小剧场文件结构")
	check("通用对话在 data/dialogues/common.json", FileAccess.file_exists("res://data/dialogues/common.json")
		and not FileAccess.file_exists("res://data/dialogues.json") and Dialogue.has_dialogue("intro"))
	var ok := true
	for id in ["floor_01", "floor_02", "floor_03", "floor_04", "floor_05"]:
		ok = ok and FileAccess.file_exists("res://data/dialogues/%s/signs.json" % id) and not FileAccess.file_exists("res://levels/%s/dialogues.json" % id)
	check("每层的对话搬到 data/dialogues/<楼层>/（signs + story），旧文件删掉", ok)
	Dialogue.load_floor("floor_05")
	check("第五层的石碑对话按楼层加载后能找到", Dialogue.has_dialogue("sign_f5_mud") or Dialogue.has_dialogue("sign5_welcome")
		or _any_key_starting("res://data/dialogues/floor_05/signs.json", "sign"))
	Dialogue.load_floor("floor_06_upper")
	check("第六层的地图共用 floor_06 文件夹：石碑对话加载，人物对话文件不混进普通对话", Dialogue.has_dialogue("sign6_town")
		and not Dialogue.has_dialogue("captain") and not Dialogue.has_dialogue("nodes"))
	check("过场按楼层分文件夹，id 不变（f5_intro / f5_ending / f6_wake）", Cutscene.has_cutscene("f5_intro") and Cutscene.has_cutscene("f5_ending")
		and Cutscene.has_cutscene("f6_wake") and FileAccess.file_exists("res://data/cutscenes/floor_05/f5_intro.json"))
	check("小剧场在 data/theater/floor_06/", CG.has_theater("f6_dance") and CG.has_theater("f6_punish_defiant"))
	check("过场数据校验通过（含 hold / talk 步骤）", Cutscene.validate("f6_wake").is_empty() and Cutscene.validate("f5_ending").is_empty())
	check("每个人物一个对话文件", FileAccess.file_exists("res://data/dialogues/floor_06/captain.json")
		and FileAccess.file_exists("res://data/dialogues/floor_06/blue_princess.json")
		and FileAccess.file_exists("res://data/dialogues/floor_06/supervisor.json")
		and FileAccess.file_exists("res://data/dialogues/floor_06/bonfire_host.json"))


func _any_key_starting(path: String, prefix: String) -> bool:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return false
	for k in d:
		if str(k).begins_with(prefix) and Dialogue.has_dialogue(str(k)):
			return true
	return false


# ------------------------------------------------------------------ 两种选项模式
const TEST_FILE := {
	"name": "测试员",
	"entries": [{"if": {"eq": {"t_mood": "happy"}}, "node": "happy"}, {"node": "start"}],
	"nodes": {
		"start": {"lines": [{"text": "你好。"}], "prompt": "要做什么？", "choices": [
			{"text": "聊聊天", "next": "chat", "return": true},
			{"text": "只能问一次", "next": "once", "return": true, "once": true},
			{"text": "秘密选项", "next": "secret", "return": true, "if": {"flag": "t_secret"}},
			{"text": "开心地离开", "next": "bye", "set": {"vars": {"t_mood": "happy"}, "add": {"t_count": 1}, "give_item": {"mint": 1}}}]},
		"chat": {"lines": [{"text": "今天天气不错。"}, {"speaker": "公主", "text": "是啊。"}]},
		"once": {"lines": [{"text": "这句话只说一次。"}], "set": {"flags": ["t_once_heard"]}},
		"secret": {"lines": [{"text": "被你发现了。"}]},
		"bye": {"lines": [{"text": "再见。"}], "next": "after"},
		"after": {"lines": [{"speaker": "", "text": "（继续到结束）"}]},
		"happy": {"goto": [{"if": {"var": {"t_count": [">=", 2]}}, "node": "very_happy"}], "lines": [{"text": "又见面啦！"}],
			"set": {"call": "rest"}},
		"very_happy": {"lines": [{"text": "你是常客了！"}]},
	},
}


func _run_dialogue_modes() -> void:
	print("-- 人物对话：选项两种模式、条件、效果")
	var r: DialogueRunner = Dialogue.runner
	r._cache["test/tester"] = TEST_FILE
	check("入口按条件选（还没设变量 → start）", r.entry_of("test/tester") == "start")
	var mint0 := GameState.inventory.count("mint")
	var seen_nodes: Array = []
	var on_node := func(_f: String, n: String): seen_nodes.append(n)
	r.node_entered.connect(on_node)
	# 回到选项页型：聊天 → 回来；一次性选项 → 回来；然后「继续到结束」型离开
	picks = [0, 1, 2]
	asked.clear()
	r.talk("test/tester")
	await _drive()
	check("「回到选项页」型：聊天分支演完回到选项页（选项弹了 3 次）", asked.size() == 3 and seen_nodes.count("start") == 1
		and seen_nodes.has("chat") and seen_nodes.has("once"))
	check("条件不满足的选项不显示（秘密选项）", asked.size() > 0 and not "秘密选项" in asked[0])
	check("一次性选项选过后不再显示", asked.size() == 3 and "只能问一次" in asked[1] and not "只能问一次" in asked[2])
	check("「继续到结束」型：选完一路 next 走到结束", seen_nodes.has("bye") and seen_nodes.has("after") and not r.is_running())
	check("效果：变量、累加、给物品、标记", GameState.vars.get("t_mood") == "happy" and float(GameState.vars.get("t_count", 0)) == 1.0
		and GameState.inventory.count("mint") == mint0 + 1 and GameState.has_flag("t_once_heard"))
	check("看过的节点、选过的选项记成标记（dlg_<文件>_<节点>[_序号]）", GameState.has_flag("dlg_test/tester_chat")
		and GameState.has_flag("dlg_test/tester_start_1"))
	# 选择记忆：入口变了；call 效果（rest）await 到结束
	check("选过「开心地离开」后，入口变成 happy", r.entry_of("test/tester") == "happy")
	player.health.damage(2)
	seen_nodes.clear()
	r.talk("test/tester")
	await _drive()
	check("call 效果：调到对话框上的 rest（篝火回血）", player.health.hp == player.health.max_hp and seen_nodes == ["happy"])
	GameState.set_var("t_count", 2)
	seen_nodes.clear()
	r.talk("test/tester")
	await _drive()
	check("条件跳转 goto：常客直接跳到 very_happy", seen_nodes == ["very_happy"])
	GameState.set_flag("t_secret")
	GameState.vars.erase("t_mood")
	picks = [2, 3]
	asked.clear()
	r.talk("test/tester")
	await _drive()
	check("满足条件后秘密选项出现（一次性选项已经不在了）", asked.size() > 0 and "秘密选项" in asked[0] and not "只能问一次" in asked[0])
	r.node_entered.disconnect(on_node)
	# 弹出选项时公主不能动：按上下键只换选项
	r._cache["test/move"] = {"name": "测试员", "entries": [{"node": "a"}], "nodes": {"a": {"lines": [{"text": "选吧。"}],
		"choices": [{"text": "一", "next": ""}, {"text": "二", "next": ""}, {"text": "三", "next": ""}]}}}
	r.talk("test/move")
	var cm: ChoiceMenu = r.choice_menu
	for i in 60:
		if cm.is_open():
			break
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.05)
	var p0 := player.global_position
	var ev := InputEventAction.new()
	ev.action = "move_down"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press("move_down")
	await _wait(0.4)
	Input.action_release("move_down")
	check("弹出选项时：剧情状态、公主不跟着上下键走，按下键换选项", cm.is_open() and GameState.in_dialogue
		and player.global_position.distance_to(p0) < 1.0 and cm.selected == 1)
	cm.choose(cm.selected)
	await _drive()
	await _wait(0.3)
	check("对话结束后交还控制权", not GameState.in_dialogue)
	# 说话人默认是人物名字；人物表里的人显示右侧立绘
	r._cache["test/cap"] = {"name": "保卫队队长", "npc": "captain", "entries": [{"node": "a"}], "nodes": {"a": {"lines": [{"text": "站住。"}]}}}
	r.talk("test/cap")
	await _wait(0.4)
	check("关键人物说话：右侧显示半身立绘，名字是人物名", Dialogue.npc_portrait.visible and Dialogue.npc_portrait.texture != null)
	await _drive()
	check("对话结束后右侧立绘收起", not Dialogue.npc_portrait.visible)


# ------------------------------------------------------------------ 选择记忆（第六层真实数据）
func _run_memory() -> void:
	print("-- 选择记忆：开场的态度影响其他人物")
	var r: DialogueRunner = Dialogue.runner
	GameState.set_flag("f6_opening_done")
	var ok := true
	for att in ["honest", "defiant", "beg"]:
		GameState.set_var("f6_attitude", att)
		ok = ok and r.entry_of("floor_06/captain") == "hello_" + att and r.entry_of("floor_06/supervisor") == "hello_" + att \
			and r.entry_of("floor_06/bonfire_host") == "hello_" + att
	check("队长 / 市场监督 / 篝火派对的主人：开场后按态度打招呼", ok)
	var sup: Dictionary = r.load_file("floor_06/supervisor")
	var hub: Array = sup["nodes"]["hub"]["choices"]
	GameState.set_var("f6_attitude", "defiant")
	var shown_def := hub.filter(func(c): return DialogueRunner.check(c.get("if", {}))).map(func(c): return c["text"])
	GameState.set_var("f6_attitude", "beg")
	var shown_beg := hub.filter(func(c): return DialogueRunner.check(c.get("if", {}))).map(func(c): return c["text"])
	check("市场监督：顶嘴后才有「队长说我坏话了吗？」，求饶后才有「爱笑的公主」的选项",
		shown_def.any(func(t): return "坏话" in t) and not shown_beg.any(func(t): return "坏话" in t)
		and shown_beg.any(func(t): return "爱笑" in t) and not shown_def.any(func(t): return "爱笑" in t))
	var readers := 0
	for f in DirAccess.get_files_at("res://data/dialogues/floor_06/"):
		if f.ends_with(".json") and FileAccess.get_file_as_string("res://data/dialogues/floor_06/" + f).contains("f6_attitude"):
			readers += 1
	check("至少 9 个人物会对开场的选择有反馈（%d 个）" % readers, readers >= 9)
	GameState.flags.erase("f6_opening_done")
	GameState.vars.erase("f6_attitude")


# ------------------------------------------------------------------ 演绎
func _run_performances() -> void:
	print("-- 对话里的演绎：小剧场 / 地图内过场")
	var r: DialogueRunner = Dialogue.runner
	r._cache["test/perf"] = {"name": "测试员", "entries": [{"node": "a"}], "nodes": {
		"a": {"lines": [{"text": "来跳个舞吧。"}], "theater": "f6_dance", "next": "b"},
		"b": {"lines": [{"text": "跳完了。"}]}}}
	var cg_seen := [false]
	var on_cg := func(id: String): cg_seen[0] = cg_seen[0] or id == "theater:f6_dance"
	CG.started.connect(on_cg)
	var b_after := [false]
	var on_node := func(_f: String, n: String): b_after[0] = b_after[0] or (n == "b" and not CG.is_busy())
	r.node_entered.connect(on_node)
	r.talk("test/perf")
	await _drive()
	check("对话节点播小剧场（CG 舞台，npc: 演员），播完才接着说下一句", cg_seen[0] and b_after[0])
	CG.started.disconnect(on_cg)
	r.node_entered.disconnect(on_node)
	# 过场里的 talk 步骤：打开人物对话并选项
	r._cache["test/q"] = {"name": "测试员", "entries": [{"node": "q"}], "nodes": {
		"q": {"lines": [{"text": "选一个。"}], "choices": [{"text": "甲", "next": "", "set": {"vars": {"t_pick": "a"}}},
			{"text": "乙", "next": "", "set": {"vars": {"t_pick": "b"}}}]}}}
	picks = [1]
	Cutscene.play_data("test_talk", {"steps": [{"speaker": "", "text": "（过场开始）"}, {"talk": {"file": "test/q"}},
		{"actions": [{"do": "set_flag", "flag": "t_after_talk"}], "wait": 0.1}]})
	await _drive()
	check("过场的 talk 步骤：过场里弹出选项，选完过场继续", GameState.vars.get("t_pick") == "b" and GameState.has_flag("t_after_talk"))


# ------------------------------------------------------------------ 存档 / 读档
func _run_save_load() -> void:
	print("-- 存档 / 读档")
	check("没有存档时 latest = -1", SaveSystem.latest() == -1 and SaveSystem.info(1).is_empty())
	GameState.set_flag("t_saved_flag")
	GameState.set_var("f6_attitude", "beg")
	GameState.give_item(ItemDB.get_item("coin"), 7)
	GameState.grant_passive("struggle_plus", true)
	var coins := GameState.inventory.count("coin")
	player.health.fill()
	player.health.damage(1)
	var hp := player.health.hp
	var pos := player.global_position + Vector2(16, 0)
	player.global_position = pos
	GameState.play_time = 125.0
	check("存档写入", SaveSystem.save(2, "测试地点") and FileAccess.file_exists(TEST_SAVES + "slot_2.json"))
	var info := SaveSystem.info(2)
	check("存档摘要：楼层名、地点、时间、游戏时长", info.get("floor") == Floors.display_name("floor_01") and info.get("place") == "测试地点"
		and str(info.get("time", "")) != "" and is_equal_approx(float(info.get("play_time", 0)), 125.0) and SaveSystem.latest() == 2)
	# 弄乱进度，再读档
	GameState.flags.erase("t_saved_flag")
	GameState.vars.clear()
	GameState.inventory.remove("coin", coins)
	main.change_level(Floors.scene("floor_02"))
	await _wait(1.2)
	_finish_dialogue()
	await SaveSystem.load_slot(2)
	await _wait(0.3)
	_finish_dialogue()
	player = GameState.player as Princess
	check("读档：回到存档的关卡和位置", main.level.get("floor_id") == "floor_01" and player.global_position.distance_to(pos) < 1.0)
	check("读档：标记、选择变量、物品、被动、游戏时长都还原", GameState.has_flag("t_saved_flag") and GameState.vars.get("f6_attitude") == "beg"
		and GameState.inventory.count("coin") == coins and GameState.passives.has("struggle_plus") and GameState.play_time >= 125.0)
	check("读档：公主的生命值还原（不被换关卡前的状态覆盖）", player.health.hp == hp)
	GameState.vars.erase("f6_attitude")


# ------------------------------------------------------------------ 存档位界面 / 存档点
func _run_slot_menu_and_save_point() -> void:
	print("-- 存档位界面与存档点")
	var menu := SlotMenu.new()
	get_tree().root.add_child(menu)
	var result := [0]
	var run := func(): result[0] = await menu.choose("save")
	run.call()
	await _wait(0.1)
	check("存档界面列出 3 个存档位并暂停游戏", menu.rows.get_child_count() == SaveSystem.SLOTS and get_tree().paused)
	menu.pick(2)
	check("覆盖已有存档要再确认一次", menu.confirm and result[0] == 0)
	menu.pick(2)
	await _wait(0.05)
	check("确认后返回存档位，取消暂停", result[0] == 2 and not get_tree().paused)
	result[0] = 0
	run = func(): result[0] = await menu.choose("load")
	run.call()
	await _wait(0.05)
	menu.pick(3)
	check("读取界面：空存档位选不了", result[0] == 0)
	menu.cancel()
	await _wait(0.05)
	check("取消返回 -1", result[0] == -1)
	# 主界面读档：按 E 确定后菜单马上离开场景树（换场景），不能再碰 get_viewport()
	result[0] = 0
	run = func(): result[0] = await menu.choose("load")
	run.call()
	await _wait(0.05)
	var gone := func(_s: int): menu.get_parent().remove_child(menu)
	menu.done.connect(gone, CONNECT_ONE_SHOT)
	menu.selected = 2
	var ok_ev := InputEventAction.new()
	ok_ev.action = "interact"
	ok_ev.pressed = true
	Input.parse_input_event(ok_ev)
	await _wait(0.1)
	check("读档界面按 E：选中存档位，菜单离开场景树也不报错", result[0] == 2 and not menu.is_inside_tree())
	get_tree().paused = false
	menu.queue_free()
	# 存档点
	var sp: Node2D = load("res://scenes/objects/save_point.tscn").instantiate()
	sp.set("place", "测试存档点")
	main.level.get_node("Entities").add_child(sp)
	sp.global_position = player.global_position + Vector2(10, 0)
	player.health.damage(1)
	sp.call("on_interact", player)
	await _wait(0.1)
	var sm: SlotMenu = null
	for c in get_tree().root.get_children():
		if c is SlotMenu:
			sm = c
	check("存档点：按 E 打开存档位界面", sm != null)
	if sm:
		sm.pick(1)
	await _wait(0.2)
	check("存档点：存进选的存档位，顺便回满生命", SaveSystem.info(1).get("place") == "测试存档点" and player.health.hp == player.health.max_hp)
	var it := sp.get_node_or_null("Interactable")
	check("存档点有交互区和发光的日记本", it != null and sp.get("sprite") != null)
	sp.queue_free()


# ------------------------------------------------------------------ 主界面
func _run_title() -> void:
	print("-- 主界面")
	check("项目主场景是主界面", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(0.1)
	var texts: Array = title.buttons.get_children().map(func(b): return (b as Button).text)
	check("主界面按钮：新游戏 / 继续 / 读取存档 / 退出", texts == ["新游戏", "继续", "读取存档", "退出"])
	check("有存档时可以继续、读取", not title.continue_button.disabled and not title.load_button.disabled)
	title.queue_free()
	for s in range(1, SaveSystem.SLOTS + 1):
		SaveSystem.delete(s)
	title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(0.1)
	check("没有存档时「继续」「读取存档」是灰的", title.continue_button.disabled and title.load_button.disabled)
	title.queue_free()
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm == null:
		for n in main.find_children("*", "CanvasLayer", true, false):
			if n.has_method("to_title"):
				pm = n
	check("暂停菜单有「返回主界面」", pm != null and pm.find_child("ToTitle", true, false) != null)


# ------------------------------------------------------------------ 工具
## 驱动对话 / 过场 / 小剧场直到结束：自动翻页，弹出选项时按 picks 依次选。
func _drive() -> void:
	var guard := 0
	await get_tree().process_frame
	while guard < 3000 and (Dialogue.runner.is_running() or Dialogue.is_active() or Cutscene.is_playing() or CG.is_busy()):
		guard += 1
		var cm: ChoiceMenu = Dialogue.runner.choice_menu
		if cm.is_open():
			asked.append(cm.options.duplicate())
			cm.choose(picks.pop_front() if not picks.is_empty() else 0)
		elif Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.03)


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
