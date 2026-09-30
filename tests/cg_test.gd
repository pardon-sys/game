extends Node
## 笑倒 CG 测试：cgs.json 数据校验、笑倒触发与选择、步骤切换立绘/姿势、复活、跳过、立绘接口。
## 用法：Godot --headless --path . res://tests/cg_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	_run_data()
	await _run_playback()
	await _run_skip()
	await _run_other_deaths()
	_run_portrait_interface()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 数据
func _run_data() -> void:
	print("-- cgs.json")
	var errors := CG.validate()
	for e in errors:
		print("    ", e)
	check("cgs.json 引用全部合法", errors.is_empty())
	for key in ["slime", "bat", "ghost", "spider", "troll", "rat", "crab", "split_slime", "mimic", "fairy", "tentacle"]:
		var id := CG.death_cg_for(key)
		check("怪物 %s 有专属笑倒 CG" % key, id == "death_" + key and CG.cgs().has(id))
	check("陷阱致死用通用 CG", CG.death_cg_for("vent") == "death_generic" and CG.death_cg_for("") == "death_generic")
	var all_have_text := true
	for id in CG.cgs():
		var texts: Array = CG.cgs()[id]["steps"].filter(func(s: Dictionary): return s.has("text"))
		all_have_text = all_have_text and texts.size() >= 4
	check("每段 CG 都有完整的对话过程", all_have_text)
	check("立绘缺素材时用失控 1 / 失控 2 占位", CG.portrait_texture("slime_1") == Dialogue.portrait_for("helpless_1")
		and CG.portrait_texture("slime_2") == Dialogue.portrait_for("helpless_2") and not CG.has_portrait_file("slime_1"))


# ------------------------------------------------------------------ 播放
## 让公主被 source 挠到笑倒（剩 1 点血、闷笑值接近满）。
func _laugh_to_death(source: Node) -> void:
	player.revive()
	player.health.damage(player.health.hp - 1)
	player.laugh.set_value(148.0)
	player._full_invuln = 0.0
	player.receive_hit(HitData.make_tickle(source, 10.0))


func _src(key: String) -> Src:
	var n := Src.new()
	n.reaction_key = key
	main.level.get_node("Entities").add_child(n)
	n.global_position = player.global_position + Vector2(20, 0)
	return n


func _wait_playing(limit := 3.0) -> bool:
	var t := 0.0
	while not CG.is_playing() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	return CG.is_playing()


func _run_playback() -> void:
	print("-- 笑倒 CG 播放")
	var checkpoint := GameState.checkpoint
	player.global_position = checkpoint + Vector2(40, 0)
	var slime: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	main.level.get_node("Entities").add_child(slime)
	slime.global_position = player.global_position + Vector2(14, 0)
	slime.process_mode = Node.PROCESS_MODE_DISABLED
	player.revive()
	player.health.damage(player.health.hp - 1)
	player.laugh.set_value(148.0)
	slime._action_cd = 0.0
	slime.tickle(player)
	check("被史莱姆挠到笑倒", not player.is_alive() and player.died_from_laugh and player.last_tickle_key == "slime")
	check("开始播放史莱姆的笑倒 CG", await _wait_playing() and CG.current == "death_slime")
	check("CG 期间游戏冻结", GameState.in_dialogue and GameState.in_cutscene)
	check("舞台上有公主和史莱姆两个演员", CG.actors.has("princess") and CG.actors.has("foe") and CG.actors["foe"].reaction_key == "slime")
	check("第一次看不能跳过", not CG.can_skip())
	var pause_evt := InputEventAction.new()
	pause_evt.action = "pause"
	pause_evt.pressed = true
	Input.parse_input_event(pause_evt)
	await _wait(0.1)
	check("CG 期间 Esc 不会打开暂停菜单，也不会跳过", CG.is_playing() and not get_tree().paused)

	var seen := {}
	var checks_done := {}
	var guard := 0
	while CG.is_playing() and guard < 600:
		guard += 1
		var i: int = CG.step_index
		if not seen.has(i):
			seen[i] = true
			await _wait(0.25)
			if i == 1:
				checks_done["p1"] = Dialogue.current_portrait() == Dialogue.portrait_for("helpless_1") and Dialogue.has_portrait_override()
				checks_done["foe_in"] = CG.actors["foe"].visible
			elif i == 3:
				await _wait(0.4)
				checks_done["p2"] = Dialogue.current_portrait() == Dialogue.portrait_for("helpless_2")
				checks_done["pose2"] = CG.actors["princess"].visual == "helpless_2"
				checks_done["zoom"] = CG.view.scale == Vector2(3, 3)
				checks_done["voice"] = CG.voice.playing
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
	check("第 2 步：立绘换成失控 1 占位、史莱姆登场", checks_done.get("p1", false) and checks_done.get("foe_in", false))
	check("第 4 步：立绘换成失控 2 占位、公主姿势变失控 2", checks_done.get("p2", false) and checks_done.get("pose2", false))
	check("第 4 步：镜头拉近、笑声响起", checks_done.get("zoom", false) and checks_done.get("voice", false))
	check("CG 播完", not CG.is_playing() and seen.size() == CG.cgs()["death_slime"]["steps"].size())
	await _wait(0.4)
	check("CG 结束后在检查点复活", player.is_alive() and player.global_position.distance_to(checkpoint) < 4.0)
	check("复活后满血、闷笑值清零", player.health.hp == player.health.max_hp and player.laugh.value == 0.0)
	check("复活后恢复控制、立绘恢复", not GameState.in_dialogue and not GameState.in_cutscene and not Dialogue.has_portrait_override())
	check("CG 后不再弹复活对话", not Dialogue.is_active())
	check("记录为看过", GameState.has_flag("cg_seen_death_slime"))
	slime.queue_free()


func _run_skip() -> void:
	print("-- 跳过")
	var s := _src("slime")
	_laugh_to_death(s)
	check("再次笑倒又播 CG", await _wait_playing() and CG.current == "death_slime")
	check("看过的 CG 可以跳过", CG.can_skip() and CG.skip_label.visible)
	await _wait(1.0)
	var evt := InputEventAction.new()
	evt.action = "pause"
	evt.pressed = true
	Input.parse_input_event(evt)
	await _wait(0.6)
	check("按 Esc 跳过，直接复活", not CG.is_playing() and player.is_alive() and not get_tree().paused)
	s.queue_free()
	_finish_dialogue()
	await _wait(0.3)


func _run_other_deaths() -> void:
	print("-- 其它死因")
	var vent := _src("vent")
	_laugh_to_death(vent)
	check("陷阱挠到笑倒 → 通用 CG", await _wait_playing() and CG.current == "death_generic" and not CG.actors.has("foe"))
	CG._can_skip = true
	CG.skip()
	await _wait(0.6)
	vent.queue_free()
	_finish_dialogue()
	await _wait(0.3)
	player.revive()
	player._full_invuln = 0.0
	player._attack_invuln = 0.0
	var foe := _src("slime")
	player.receive_hit(HitData.make_attack(foe, 99))
	check("被攻击打死", not player.is_alive() and not player.died_from_laugh)
	await _wait(1.0)
	check("被攻击打死不播 CG", not CG.is_playing())
	await _wait(1.5)
	check("照常复活并播复活对话", player.is_alive() and Dialogue.is_active())
	_finish_dialogue()
	foe.queue_free()


func _run_portrait_interface() -> void:
	print("-- 立绘接口")
	var info: Dictionary = CG.data["portraits"]["slime_1"]
	var old: String = info["file"]
	info["file"] = "res://assets/generated/cg_fx.png"
	check("立绘文件存在时用正式素材", CG.has_portrait_file("slime_1") and CG.portrait_texture("slime_1") == load("res://assets/generated/cg_fx.png"))
	info["file"] = old


# ------------------------------------------------------------------ 工具
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
