extends Node
## 笑倒 CG 测试：cgs.json 数据校验、笑倒触发与选择、步骤切换立绘/姿势、复活、跳过、立绘接口。
## 用法：Godot --headless --path . res://tests/cg_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	ComboTracker.play_scenes = false  # 三来源组合的小演出会暂停战斗；需要时在专门的测试里打开
	HUD.slow_motion = false
	Monster.random_specials = false  # 这里要精确的挠痒数值；暴击在 floor4_test 里测
	MagicFatigue.accumulate = false  # 同理，魔力疲倦的闷笑加成在 floor4_test 里测
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
	await _run_real_monsters()
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
	for key in MONSTER_SCENES:
		var id := CG.death_cg_for(key)
		check("怪物 %s 有专属笑倒 CG" % key, id == "death_" + key and CG.cgs().has(id))
	check("陷阱致死用通用 CG", CG.death_cg_for("vent") == "death_generic" and CG.death_cg_for("") == "death_generic")
	var all_have_text := true
	for id in CG.cgs():
		var texts: Array = CG.cgs()[id]["steps"].filter(func(s: Dictionary): return s.has("text"))
		all_have_text = all_have_text and texts.size() >= 4
	check("每段 CG 都有完整的对话过程", all_have_text)
	var third_ok := true
	for key in MONSTER_SCENES:
		var steps: Array = CG.cgs()["death_" + key]["steps"]
		var idx := -1
		for i in steps.size():
			if str(steps[i].get("portrait", "")) == key + "_3":
				idx = i
		var after: Array = steps.slice(maxi(idx, 0)).filter(func(st: Dictionary): return st.has("text"))
		var ok: bool = idx >= 0 and CG.has_portrait_file(key + "_3") and CG.data["portraits"][key + "_3"].get("wide", false) and after.size() >= 6
		if not ok:
			print("    第三幕有问题：", key)
		third_ok = third_ok and ok
	check("16 段怪物 CG 都有第三幕（横版 CG 图 + 最多的剧情）", third_ok)
	var fourth_ok := true
	for key in ["bubble_fish", "jelly_queen"]:
		var steps: Array = CG.cgs()["death_" + key]["steps"]
		var i3 := -1
		var i4 := -1
		for i in steps.size():
			var pid := str(steps[i].get("portrait", ""))
			if pid == key + "_3":
				i3 = i
			elif pid == key + "_4":
				i4 = i
		var act4: Array = steps.slice(maxi(i4, 0)).filter(func(st: Dictionary): return st.has("text"))
		var ok: bool = i3 >= 0 and i4 > i3 and CG.has_portrait_file(key + "_4") and CG.data["portraits"][key + "_4"].get("wide", false) \
				and act4.size() >= 6
		if not ok:
			print("    第四幕有问题：", key)
		fourth_ok = fourth_ok and ok
	check("两张 CG 图的怪物（泡泡鱼、水母女王）有第四幕", fourth_ok and not CG.data["portraits"].has("slime_4"))
	check("通用 CG 没有第三幕", not CG.cgs()["death_generic"]["steps"].any(func(st: Dictionary): return str(st.get("portrait", "")).ends_with("_3")))
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
	check("被史莱姆挠到笑倒", not player.is_alive() and player.died_from_laugh and player.defeat_source_key() == "slime")
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
			elif i == 5:
				await _wait(0.4)
				var tex := CG.portrait_texture("slime_3")
				checks_done["wide"] = Dialogue.is_portrait_wide() and Dialogue.current_portrait() == tex \
					and Dialogue.portrait.size.is_equal_approx(Vector2(roundf(180.0 * tex.get_width() / tex.get_height()), 180.0))
				checks_done["stage_right"] = CG.view.position.x > 200.0
				# 挠痒时横版 CG 图抖动：采样一段时间内的位置，应该偏离过基准位置
				var moved := false
				for k in 20:
					await get_tree().process_frame
					if not Dialogue.portrait.position.is_equal_approx(Dialogue.WIDE_POS):
						moved = true
				checks_done["cg_shake"] = moved
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
	check("第 2 步：立绘换成失控 1 占位、史莱姆登场", checks_done.get("p1", false) and checks_done.get("foe_in", false))
	check("第 4 步：立绘换成失控 2 占位、公主姿势变失控 2", checks_done.get("p2", false) and checks_done.get("pose2", false))
	check("第 4 步：镜头拉近、笑声响起", checks_done.get("zoom", false) and checks_done.get("voice", false))
	check("第三幕：立绘框变成横版大框，显示史莱姆 CG 图（原比例）", checks_done.get("wide", false))
	check("第三幕：舞台镜头移到右侧继续演", checks_done.get("stage_right", false))
	check("第三幕：CG 图随挠痒抖动", checks_done.get("cg_shake", false))
	check("CG 播完", not CG.is_playing() and seen.size() == CG.cgs()["death_slime"]["steps"].size())
	await _wait(0.4)
	check("CG 结束后在检查点复活", player.is_alive() and player.global_position.distance_to(checkpoint) < 4.0)
	check("复活后满血、闷笑值清零", player.health.hp == player.health.max_hp and player.laugh.value == 0.0)
	check("复活后恢复控制、立绘恢复", not GameState.in_dialogue and not GameState.in_cutscene and not Dialogue.has_portrait_override()
		and not Dialogue.is_portrait_wide())
	await _wait(0.3)
	check("立绘框回到原位", Dialogue.portrait.position.is_equal_approx(Dialogue.PORTRAIT_RECT.position))
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


# ------------------------------------------------------------------ 真实怪物 AI 挠到倒下
const MONSTER_SCENES := {
	"slime": "slime", "bat": "feather_bat", "ghost": "tickle_ghost", "spider": "tickle_spider",
	"troll": "tickle_troll", "rat": "foot_rat", "crab": "pincer_crab", "split_slime": "split_slime",
	"mimic": "mimic", "fairy": "fairy_swarm", "tentacle": "tentacle_boss",
	"mana_jelly": "mana_jelly", "bubble_fish": "bubble_fish", "glove": "ghost_glove", "hedgehog": "brush_hedgehog",
	"jelly_queen": "jelly_queen",
}


func _skip_cg() -> void:
	CG._can_skip = true
	CG.skip()
	await _wait(0.7)
	_finish_dialogue()
	await _wait(0.2)


func _run_real_monsters() -> void:
	print("-- 真实怪物 AI：每种怪物挠到公主倒下都播对应 CG")
	var spot := Vector2(31 * 16 + 8, 23 * 16 + 12)   # 第一层守卫室中间，空间够大
	for key in MONSTER_SCENES:
		player.revive()
		player.global_position = spot
		player.camera.reset_smoothing()
		player._full_invuln = 0.0
		player._attack_invuln = 0.0
		var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % MONSTER_SCENES[key]).instantiate()
		main.level.get_node("Entities").add_child(m)
		m.global_position = spot + (Vector2(0, -60) if key == "tentacle" else Vector2(18, 0))
		await _wait(0.1)
		if m is Mimic:
			(m as Mimic).on_interact(player)
		if m is JellyQueen:
			(m as JellyQueen)._summon_cd = 999.0  # 不让召唤的小水母抢走最后一下
		if m is BrushHedgehog:
			m.global_position = spot + Vector2(60, 0)  # 同一行，滚过来
		# 公主剩 1 点血、闷笑值接近满、已经失控：接下来无论是挠痒还是普通攻击让她倒下，都算笑倒
		player.health.damage(player.health.hp - 1)
		player.laugh.set_value(140.0)
		var t := 0.0
		while player.is_alive() and t < 25.0:
			await _wait(0.2)
			t += 0.2
			player._attack_invuln = 0.0
			if player.is_alive() and player.laugh.value < 147.0:
				player.laugh.set_value(147.0)  # 模拟一直被挠：下一下挠痒就会溢出，只看怪物自己的那一下能不能触发 CG
		var playing := await _wait_playing(3.0)
		check("%s 挠到倒下 → 播 %s 的 CG（实际：%s，%.1f 秒）" % [key, key, CG.current, t], playing and CG.current == "death_" + key)
		if is_instance_valid(m):
			m.queue_free()
		for c in main.level.get_node("Entities").get_children():
			if c is Monster and c.process_mode != Node.PROCESS_MODE_DISABLED:
				c.queue_free()  # 分裂出来的小史莱姆、召唤的精灵
		if CG.is_playing():
			await _skip_cg()

	print("-- 最后一下是普通攻击")
	player.revive()
	player.global_position = spot
	var slime: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	main.level.get_node("Entities").add_child(slime)
	slime.global_position = spot + Vector2(14, 0)
	slime.process_mode = Node.PROCESS_MODE_DISABLED
	player._full_invuln = 0.0
	player._attack_invuln = 0.0
	player.health.damage(player.health.hp - 1)
	player.laugh.set_value(90.0)
	slime.tickle(player)
	player._attack_invuln = 0.0
	slime._action_cd = 0.0
	slime.attack(player)
	check("失控时被普通攻击打倒", not player.is_alive() and not player.died_from_laugh and player.is_laugh_defeat())
	check("仍然播史莱姆的笑倒 CG", await _wait_playing() and CG.current == "death_slime")
	await _skip_cg()
	slime.queue_free()


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
