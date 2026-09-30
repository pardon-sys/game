extends Node
## 第二层与新系统测试：关卡切换、减速/抓取、投射物、新怪物、新陷阱、立绘密度。
## 用法：Godot --headless --path . res://tests/floor2_test.tscn   （退出码 0 = 全部通过）

const FLOOR2 := "res://levels/floor_02/floor.tscn"
const WEB := preload("res://scenes/combat/web_shot.tscn")

var main: Node
var level: Node
var player: PlayableCharacter
var ctrl := ScriptedController.new()
var failures := 0


func _ready() -> void:
	Monster.random_specials = false  # 这里要精确的挠痒数值；暴击在 floor4_test 里测
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_transition()
	await _run_status()
	await _run_monsters()
	await _run_traps()
	await _run_troll()
	await _run_long_dialogue()
	await _run_reactions()
	_run_data()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 关卡切换
func _run_transition() -> void:
	print("-- 关卡切换")
	var exit: Node = main.level.find_child("Exit_52_23", true, false)
	check("第一层楼梯是通往下一层（floors.json → 第二层）的出口", exit != null and exit.target_level == "next" and exit.resolve_target() == FLOOR2 and exit.dialogue == "ending")
	var p1: Princess = GameState.player
	p1.health.set_hp(7)
	p1.laugh.notify_attacked()
	p1.laugh.set_value(30.0)
	p1.battle_damaged = true
	GameState.inventory.add(ItemDB.get_item("mint"), 1)
	main.change_level(FLOOR2)
	await _wait(1.3)
	level = main.level
	player = GameState.player
	check("切换到第二层", level != null and level.name == "Floor02" and player != p1 and is_instance_valid(player))
	check("血量保留", player.health.hp == 7)
	check("闷笑值保留（切换期间正常衰减）", player.laugh.value > 10.0 and player.laugh.value <= 30.0)
	check("战损保留", (player as Princess).battle_damaged)
	check("背包保留", GameState.inventory.count("mint") >= 1)
	check("第二层开场对话", Dialogue.is_active())
	check("按层载入对话：第二层对话可用、第一层专属对话已卸载、通用对话保留",
		Dialogue.floor_id == "floor_02" and Dialogue.has_dialogue("troll_intro") and not Dialogue.has_dialogue("sign_cell") and Dialogue.has_dialogue("respawn"))
	_finish_dialogue()
	await _wait(0.3)
	player.set_controller(ctrl)
	(player as Princess).revive()
	GameState.set_flag("seen_laugh_recover")


# ------------------------------------------------------------------ 状态效果
func _run_status() -> void:
	print("-- 减速 / 抓取")
	_move_player_to(Vector2i(9, 36))
	await _wait(0.2)
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	var v_normal := player.velocity.x
	ctrl.move = Vector2.ZERO
	_move_player_to(Vector2i(9, 36))
	player.status.apply_slow(0.5, 1.5)
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	var v_slow := player.velocity.x
	ctrl.move = Vector2.ZERO
	check("减速 50%% (%.0f → %.0f)" % [v_normal, v_slow], absf(v_slow - v_normal * 0.5) < 3.0)
	player.status.clear()

	var grabber := Node2D.new()
	level.add_child(grabber)
	check("可以被抓住", player.can_be_grabbed() and player.status.grab(grabber, 5.0, 3))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("进入 GRABBED 状态", player.state == PlayableCharacter.State.GRABBED)
	var p0 := player.global_position
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	ctrl.move = Vector2.ZERO
	check("被抓时不能移动", player.global_position.distance_to(p0) < 1.0)
	player.laugh.notify_attacked()
	player.laugh.set_value(110.0)
	await get_tree().physics_frame
	check("被抓时超过 100 显示失控 2", player.emotion.current == "helpless_2")
	var before := player.laugh.value
	for i in 3:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame
	check("连打挣脱", not player.status.is_grabbed())
	check("挣扎同时降闷笑值", player.laugh.value <= before - 9.0 + 0.01)
	await get_tree().physics_frame
	check("挣脱后仍失控则进入失控状态", player.state == PlayableCharacter.State.HELPLESS)
	check("挣脱后短暂无敌", player.is_fully_invulnerable())
	player.laugh.clear()
	await _wait(0.8)
	player.status.grab(grabber, 0.4, 99)
	await _wait(0.6)
	check("超时自动松开", not player.status.is_grabbed())
	player._full_invuln = 0.0
	check("冲刺无敌时抓不住", _dash_blocks_grab(grabber))
	grabber.queue_free()
	await _wait(0.8)


func _dash_blocks_grab(grabber: Node) -> bool:
	player.set_invulnerable(0.3, true)
	var ok := not player.can_be_grabbed()
	player._full_invuln = 0.0
	return ok


# ------------------------------------------------------------------ 怪物
func _run_monsters() -> void:
	print("-- 新怪物")
	player.laugh.clear()
	_clear_invuln()
	# 蜘蛛丝
	_move_player_to(Vector2i(9, 38))
	await _wait(0.1)
	var shot := Projectile.fire(WEB, level.get_node("Entities"), player.global_position + Vector2(40, -4), Vector2.LEFT, _find("Spider_55_21"))
	await _wait(0.6)
	check("蛛丝命中减速", player.status.is_slowed())
	check("蛛丝少量挠痒", player.laugh.value > 0.0 and player.laugh.value <= 4.0)
	check("蛛丝命中后消失", not is_instance_valid(shot) or shot._done)
	player.status.clear()
	player.laugh.clear()

	# 蝙蝠：只在俯冲时行动，行动后退开
	var bat: FeatherBat = _find("Bat_8_13")
	bat.phase = FeatherBat.Phase.CIRCLE
	bat._action_cd = 0.0
	check("蝙蝠盘旋时不行动", not bat.can_act())
	bat.phase = FeatherBat.Phase.DIVE
	check("蝙蝠俯冲时可行动", bat.can_act())
	bat.target = player
	check("蝙蝠挠痒成功", bat.tickle(player))
	check("蝙蝠挠完就退开", bat.phase == FeatherBat.Phase.RETREAT)
	player.laugh.clear()

	# 幽灵：未显形免疫攻击，火把照亮后显形
	var ghost: TickleGhost = _find("Ghost_28_6")
	ghost.global_position = Vector2(30 * 16 + 8, 5 * 16 + 8)
	await get_tree().physics_frame
	check("幽灵默认未显形", not ghost.revealed)
	check("未显形时攻击无效", not ghost.receive_hit(HitData.make_attack(player, 1)))
	check("幽灵只会挠痒", ghost._choose_action(player) == "tickle")
	_find("Torch_30_3").on_interact(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("火把照亮后幽灵显形", ghost.revealed)
	check("显形后可以被攻击", ghost.receive_hit(HitData.make_attack(player, 1)))

	# 蜘蛛：保持距离、定时吐丝
	var spider: TickleSpider = _find("Spider_47_19")
	spider.target = player
	spider.state = Monster.State.CHASE
	spider._web_cd = 0.0
	var shots_before := _count_projectiles()
	spider.shoot_web()
	check("蜘蛛吐丝", _count_projectiles() > shots_before)
	spider._burst_left = 0
	player.laugh.clear()


func _count_projectiles() -> int:
	var n := 0
	for c in level.get_node("Entities").get_children():
		if c is Projectile:
			n += 1
	return n


# ------------------------------------------------------------------ 陷阱
func _run_traps() -> void:
	print("-- 新陷阱")
	_clear_invuln()
	player.laugh.clear()
	var hp := player.health.hp
	var vent: Trap = _find("Vent_7_19")
	# 只测粉雾本身：暂停附近的怪物，避免蝙蝠的普通攻击随机扣血
	var paused: Array[Node] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.global_position.distance_to(vent.global_position) < 200.0 and e.process_mode != Node.PROCESS_MODE_DISABLED:
			e.process_mode = Node.PROCESS_MODE_DISABLED
			paused.append(e)
	player.global_position = vent.global_position + Vector2(0, 2)
	vent.phase = Trap.Phase.IDLE
	vent.trigger()
	await _wait(1.6)
	check("喷口粉雾持续挠痒", player.laugh.value >= 8.0)
	check("粉雾不扣血", player.health.hp == hp)
	for e in paused:
		e.process_mode = Node.PROCESS_MODE_INHERIT
	player.laugh.clear()
	_move_player_to(Vector2i(9, 36))
	await _wait(2.8)

	var brush: Trap = _find("Brush_40_33")
	check("旋转刷是持续生效陷阱", brush.trigger_mode == Trap.TriggerMode.CONTINUOUS and brush.is_dangerous())
	var r0 := brush.rotation
	await _wait(0.2)
	check("旋转刷在转", absf(brush.rotation - r0) > 0.1)
	player.laugh.clear()
	player.global_position = brush.global_position + Vector2.from_angle(brush.rotation + 0.35) * 28.0 + Vector2(0, 3)
	await _wait(0.35)
	check("被刷扫到加闷笑值", player.laugh.value > 0.0)
	player.laugh.clear()
	_move_player_to(Vector2i(56, 33))
	await _wait(1.0)

	var hand: GrabHand = _find("Hand_36_30")
	var plate: Node = _find("Plate_36_31")
	check("压力板关联机关手", hand.is_in_group(plate.target))
	_clear_invuln()
	player.laugh.clear()
	player.global_position = plate.global_position + Vector2(0, 3)
	await _wait(0.6)
	check("踩压力板触发机关手抓人", player.status.is_grabbed_by(hand) and player.state == PlayableCharacter.State.GRABBED)
	await _wait(0.6)
	check("机关手挠痒", player.laugh.value > 0.0)
	for i in 10:
		ctrl.press(&"interact")
		await get_tree().physics_frame
		await get_tree().physics_frame
	check("挣脱机关手", not player.status.is_grabbed())
	await _wait(0.1)
	check("机关手缩回冷却", hand.phase == Trap.Phase.COOLDOWN)
	player.laugh.clear()
	_move_player_to(Vector2i(56, 33))
	await _wait(0.8)


# ------------------------------------------------------------------ 巨魔
func _run_troll() -> void:
	print("-- 挠痒巨魔")
	var troll: TickleTroll = _find("Troll_22_34")
	var hud := main.get_node("HUD")
	_clear_invuln()
	player.laugh.clear()
	player.health.fill()
	troll.target = player
	troll.state = Monster.State.CHASE
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("Boss 血条显示", hud.get_node("BossBar").visible)
	player.global_position = troll.global_position + Vector2(10, 0)
	check("巨魔抓住公主", troll._perform("tickle", player) and player.status.is_grabbed_by(troll))
	await _wait(1.2)
	check("被巨魔抓着持续挠痒", player.laugh.value >= 8.0)
	for i in 10:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame
	await get_tree().physics_frame
	check("连打 10 次挣脱巨魔", not player.status.is_grabbed())
	check("巨魔僵直", troll.is_stunned())
	player.laugh.clear()
	_clear_invuln()
	var hp := player.health.hp
	player.global_position = troll.global_position + Vector2(12, 0)
	troll.mode = TickleTroll.Mode.WINDUP
	troll._mode_t = 0.01
	await _wait(0.1)
	check("巨魔重击扣 2 血", player.health.hp == hp - 2)
	# 真实流程：用权杖一下下打倒巨魔（之前只用 health.damage 直接扣血，漏掉了拿不到金钥匙的 bug）
	var keys_before := GameState.inventory.count("key_gold")
	var swings := 0
	var troll_pos := troll.global_position
	while is_instance_valid(troll) and swings < 80:
		_finish_dialogue()
		player.revive()
		player.set_invulnerable(0.6, true)
		if player.status.is_grabbed():
			player.status.release()
		troll_pos = troll.global_position
		player.global_position = troll_pos + Vector2(0, 16)
		player.facing = Vector2.UP
		troll._attack_invuln = 0.0
		ctrl.press(&"attack")
		swings += 1
		await _wait(0.35)
	check("用权杖打倒巨魔（%d 次挥杖）" % swings, not is_instance_valid(troll))
	await _wait(0.5)
	_finish_dialogue()
	var near_hearts: Array = level.get_node("Entities").get_children().filter(
		func(c: Node): return c is WorldItem and c.item.id == "heart" and c.global_position.distance_to(troll_pos) < 24.0)
	check("掉落物落在巨魔倒下的位置附近（不会飞到地图原点）", not near_hearts.is_empty())
	check("Boss 的金钥匙直接放进背包，不掉在地上", GameState.inventory.count("key_gold") == keys_before + 1
		and not level.get_node("Entities").get_children().any(func(c: Node): return c is WorldItem and c.item.id == "key_gold"))
	_finish_dialogue()
	check("Boss 血条隐藏", not hud.get_node("BossBar").visible)
	var gold_door: Node = _find("Door_22_44")
	gold_door.on_interact(player)
	_finish_dialogue()
	check("金钥匙打开第二层金锁门", gold_door.is_open)


# ------------------------------------------------------------------ 长对话滚动
func _run_long_dialogue() -> void:
	print("-- 长对话")
	var long_text := "这是一段很长很长的对话，用来检查超出对话框的内容会不会被截断。".repeat(6)
	Dialogue.start_lines([{"speaker": "公主", "emotion": "normal", "text": long_text}])
	await _wait(0.2)
	Dialogue.advance()  # 跳过打字效果，显示全部
	await get_tree().process_frame
	await get_tree().process_frame
	var bar := Dialogue.text_label.get_v_scroll_bar()
	check("长文本超出对话框时可滚动", Dialogue.is_text_scrollable() and bar.max_value > Dialogue.text_label.size.y)
	check("文字完整保留（没有被截断）", Dialogue.text_label.get_parsed_text() == long_text and Dialogue.text_label.visible_characters == -1)
	check("自动滚到最后一行", bar.value > 0.0)
	var v := bar.value
	Dialogue.scroll_text(-1)
	check("可以向上翻看", bar.value < v)
	_finish_dialogue()
	await _wait(0.3)


# ------------------------------------------------------------------ 分来源的受挠台词
func _run_reactions() -> void:
	print("-- 分来源台词")
	var princess := player as Princess
	princess.revive()
	_move_player_to(Vector2i(9, 36))
	await _wait(0.2)
	var bat: FeatherBat = null
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is FeatherBat:
			bat = n
			break
	check("能找到一只蝙蝠", bat != null)
	check("台词来源识别（怪物 / 陷阱 / 粉雾 / 蛛丝）",
		ReactionDB.key_of(bat) == "bat" and ReactionDB.key_of(_find("Vent_7_19")) == "vent"
		and ReactionDB.key_of(_find("Hand_44_30")) == "hand")
	var shot := WebShot.new()
	shot.shooter = _find("Spider_55_21")
	check("蛛丝台词算作蜘蛛", ReactionDB.key_of(shot) == "spider")
	shot.free()
	GameState.flags.erase("met_bat")
	_clear_invuln()
	bat.phase = FeatherBat.Phase.DIVE
	bat._action_cd = 0.0
	bat.tickle(player)
	await get_tree().process_frame
	check("第一次被蝙蝠挠：播放首次遭遇剧情", Dialogue.is_active() and Dialogue._id == "first_bat")
	check("首次剧情来自台词文件", Dialogue._lines == ReactionDB.first_encounter("bat"))
	var lv := player.laugh.value
	await _wait(0.8)
	check("剧情中暂停挠痒类陷阱与计时", player.laugh.value <= lv + 0.01)
	_finish_dialogue()
	await _wait(0.4)
	player.laugh.clear()
	_clear_invuln()
	princess._reaction_cooldown = 0.0
	princess._reaction_stage = ""
	bat.phase = FeatherBat.Phase.DIVE
	bat._action_cd = 0.0
	bat.tickle(player)
	await get_tree().process_frame
	check("第二次不再播放剧情", not Dialogue.is_active())
	check("显示蝙蝠专属台词", Dialogue.reaction_text.text in ReactionDB.lines("bat", "calm"))
	check("缺省阶段回退通用台词", ReactionDB.lines("feather", "helpless_2") == ReactionDB.lines("", "helpless_2"))
	bat.maybe_taunt(true)
	var speech := bat.get_node_or_null("Speech") as Label
	check("怪物头顶冒出回嘴", speech != null and speech.text in ReactionDB.taunts("bat"))
	var ok := true
	for key in ReactionDB.source_keys():
		ok = ok and not ReactionDB.first_encounter(key).is_empty() and not ReactionDB.lines(key, "calm").is_empty()
	check("每个来源都有首次剧情与台词（%d 个）" % ReactionDB.source_keys().size(), ok)
	player.laugh.clear()
	await _wait(0.3)


# ------------------------------------------------------------------ 数据与表现
func _run_data() -> void:
	print("-- 数据")
	var ok := true
	var names := []
	for path in ["feather_bat", "tickle_ghost", "tickle_spider", "tickle_troll"]:
		var st: MonsterStats = load("res://data/monsters/%s.tres" % path)
		ok = ok and st.tickle_weight >= 0.85
		names.append("%s %.2f" % [st.display_name, st.tickle_weight])
	check("新怪物挠痒概率 ≥ 85%%（%s）" % ", ".join(names), ok)
	check("史莱姆保持 75%", is_equal_approx((load("res://data/monsters/slime.tres") as MonsterStats).tickle_weight, 0.75))
	ok = true
	for path in ["feather_bat", "tickle_ghost", "tickle_spider", "tickle_troll"]:
		var m: Node = load("res://scenes/actors/monsters/%s.tscn" % path).instantiate()
		ok = ok and m is Monster and Contracts.implements(m, Contracts.MONSTER)
		m.free()
	check("新怪物满足 MONSTER 接口", ok)
	ok = true
	for path in ["powder_vent", "feather_brush", "grab_hand"]:
		var t: Node = load("res://scenes/traps/%s.tscn" % path).instantiate()
		ok = ok and t is Trap and Contracts.implements(t, Contracts.TRAP)
		t.free()
	check("新陷阱满足 TRAP 接口（含 Triggerable）", ok)
	check("立绘 2 倍像素密度", Dialogue.portrait_density == 2 and Dialogue.portrait_for("normal").region.size == Vector2(228, 304))
	check("HUD 头像 2 倍密度", Dialogue.head_for("normal").region.size == Vector2(64, 64))
	var sheet := load("res://assets/generated/princess.png") as Texture2D
	check("精灵表 11 行 x 16 列 32px", sheet.get_width() == 512 and sheet.get_height() == 352)
	check("挠痒果冻音效已加载", Audio._streams.get("tickle", []).size() == 4)
	check("闷笑上限 150 / 失控 2 阈值 100", is_equal_approx(player.laugh.max_value, 150.0) and is_equal_approx(player.laugh.helpless_stage2_threshold, 100.0))


# ------------------------------------------------------------------ 工具
func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _find(n: String) -> Node:
	var node := level.find_child(n, true, false)
	assert(node != null, "找不到节点 " + n)
	return node


func _move_player_to(c: Vector2i) -> void:
	player.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 12)
	player.velocity = Vector2.ZERO


func _clear_invuln() -> void:
	player._attack_invuln = 0.0
	player._full_invuln = 0.0


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
