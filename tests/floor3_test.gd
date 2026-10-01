extends Node
## 楼层扩充 / 第三层 / 魔法 / 组合技测试。
## 用法：Godot --headless --path . res://tests/floor3_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: PlayableCharacter
var failures := 0


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
	GameState.set_flag("seen_laugh_recover")  # 否则第一次从失控恢复会弹对话、冻结输入
	_refresh()
	_run_floors()
	await _run_floor1_rooms()
	await _goto("floor_02")
	await _run_floor2_rooms()
	await _run_magic()
	await _run_status_effects()
	await _run_combos()
	await _run_new_monsters()
	await _run_new_traps()
	await _run_floor3()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 楼层表
func _run_floors() -> void:
	print("-- 楼层表")
	var ids := Floors.ids()
	check("floors.json 顺序", ids == ["floor_01", "floor_02", "floor_03", "floor_04"])
	check("下一层", Floors.next_of("floor_01") == "floor_02" and Floors.next_of("floor_02") == "floor_03" and Floors.next_of("floor_03") == "floor_04" and Floors.next_of("floor_04") == "")
	for id in ids:
		check("%s 有地图、对话和场景" % id, FileAccess.file_exists(Floors.map_path(id))
			and FileAccess.file_exists(Floors.dialogues_path(id)) and ResourceLoader.exists(Floors.scene(id)))
	check("第一层根节点记录 floor_id", level.get("floor_id") == "floor_01")


# ------------------------------------------------------------------ 第一层扩充房间
func _run_floor1_rooms() -> void:
	print("-- 第一层扩充房间")
	check("所有地面都能从起点走到（暗墙视为可通行）", _unreachable_cells(true).is_empty())
	var secret_cell := Vector2i(19, 13)
	check("暗墙打开前秘密储物间走不到", _unreachable_cells(false).has(Vector2i(22, 12)))

	var secret: SecretWall = _find("Secret_19_13")
	check("暗墙初始看不出来", not secret.revealed and not secret.interactable.enabled)
	_find("Torch_17_7").on_interact(player)
	check("点亮书房火把后显出裂缝", secret.revealed and secret.interactable.enabled)
	secret.on_interact(player)
	await _wait(0.1)
	var walls: TileMapLayer = level.get_node("Walls")
	check("推倒暗墙后墙格消失", walls.get_cell_source_id(secret_cell) == -1)
	check("秘密储物间可以走到", not _unreachable_cells(false).has(Vector2i(22, 12)))
	check("彩蛋石碑对话存在", Dialogue.has_dialogue("sign_knight_note"))

	var gate_a: Node = _find("Gate_18_40")
	var gate_b: Node = _find("Gate_14_40")
	check("谜题初始：外门关、内门开", not gate_a.is_open and gate_b.is_open)
	_find("Lever_24_40").on_interact(player)
	check("外拉杆：外门开、内门合上", gate_a.is_open and not gate_b.is_open)
	_find("Lever_16_38").on_interact(player)
	check("内拉杆：内门打开，宝物可取", gate_a.is_open and gate_b.is_open)

	var rack: Node = _find("Rack_38_37")
	rack.receive_hit(HitData.make_attack(player, 1, 0.0))
	await _wait(0.5)
	var barrel: Node2D = load("res://scenes/objects/barrel.tscn").instantiate()
	level.get_node("Entities").add_child(barrel)
	barrel.global_position = player.global_position + Vector2(-14, 0)
	player.facing = Vector2.LEFT
	await _wait(0.1)
	player.attack()
	await _wait(0.35)
	check("挥杖真的能打碎木桶（静态物体命中）", not is_instance_valid(barrel))
	check("武器架可以打碎", not is_instance_valid(rack) or rack.is_queued_for_deletion())
	check("兵器库宝箱放着心", _find("Chest_48_42").item.id == "heart")


# ------------------------------------------------------------------ 第二层扩充房间
func _run_floor2_rooms() -> void:
	print("-- 第二层扩充房间")
	check("第二层所有地面都能从起点走到", _unreachable_cells(true).is_empty())
	var a: Trap = _find("Vent_23_15")
	var b: Trap = _find("Vent_26_16")
	check("喷口回廊两排错开", absf(a.phase_offset - b.phase_offset) > 1.0 and a.idle_time >= 2.0)
	check("蛛丝幽灵房：蜘蛛和幽灵同屋", _find("Spider_40_16") != null and _find("Ghost_35_13") != null)
	check("休息室有检查点", _find("Checkpoint_36_27") != null)
	for id in ["sign2_vents", "sign2_webghost", "sign2_rest"]:
		check("第二层对话 " + id, Dialogue.has_dialogue(id))


# ------------------------------------------------------------------ 魔法
const SLIME := preload("res://scenes/actors/monsters/slime.tscn")


func _spawn_dummy(offset: Vector2, active := false) -> Monster:
	var m: Monster = SLIME.instantiate()
	level.get_node("Entities").add_child(m)
	m.global_position = player.global_position + offset
	m.health.max_hp = 20
	m.health.fill()
	if not active:
		m.process_mode = Node.PROCESS_MODE_DISABLED
	return m


func _cast(hold_time: float) -> int:
	var events: Array = []
	var cb := func(e: String, t: int): events.append([e, t])
	player.magic_event.connect(cb)
	ctrl.hold(&"magic", true)
	await _wait(hold_time)
	ctrl.hold(&"magic", false)
	await _wait(0.1)
	player.magic_event.disconnect(cb)
	for e in events:
		if e[0] == "burst":
			return e[1]
	return 0


func _reset_magic() -> void:
	if player.fatigue:
		player.fatigue.clear()  # 魔力疲倦不会自己消散，会给闷笑积累加成；这里的数值检查要从 0 开始
	if player.is_casting():  # 释放动作还没播完：直接结束，方便连续施法测试
		player._set_state(PlayableCharacter.State.IDLE)
	player._magic_cd = 0.0
	player.laugh.clear()
	player.health.fill()
	player.status.clear()
	player._attack_invuln = 0.0
	player._full_invuln = 0.0
	player.clear_buffs(false)  # 组合技附带的易痒 / 黏黏 / 封魔等状态
	player.forced_specials = 0
	if player.state == PlayableCharacter.State.GRABBED:
		player._set_state(PlayableCharacter.State.IDLE)  # 抬起（三来源组合）松开后不要再给挣脱无敌


var ctrl := ScriptedController.new()


func _run_magic() -> void:
	print("-- 星光爆发魔法")
	player.set_controller(ctrl)
	_move_player_to(Vector2i(9, 38))
	# 先把本层怪物都停掉，免得干扰
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(0.2)
	GameState.flags.erase("magic_unlocked")
	check("未学会时不能吟唱", not player.begin_channel() and player.state != PlayableCharacter.State.CHANNEL)
	var hud: Node = main.get_node("HUD")
	await _wait(0.05)
	check("未学会时 HUD 不显示魔法图标", not hud.magic_slot.visible)
	Dialogue.start_lines([{"speaker": "石碑", "text": "测试", "set_flag": "magic_unlocked"}], "t")
	_finish_dialogue()
	check("对话行 set_flag 学会魔法", player.is_magic_unlocked())
	await _wait(0.2)  # 对话结束后 0.12 秒才交还控制
	check("学会后 HUD 显示魔法图标", hud.magic_slot.visible)

	# 吟唱不能移动、档位
	_reset_magic()
	var pos := player.global_position
	ctrl.move = Vector2.RIGHT
	ctrl.hold(&"magic", true)
	await _wait(0.3)
	check("按住进入吟唱", player.is_channeling())
	check("吟唱时不能移动", player.global_position.distance_to(pos) < 2.0)
	check("HUD 显示弱点暴露", hud.exposed_label.visible)
	ctrl.press(&"dash")
	await _wait(0.05)
	check("吟唱时不能冲刺", player.is_channeling())
	ctrl.hold(&"magic", false)
	ctrl.move = Vector2.ZERO
	await _wait(0.1)
	check("不到 0.6 秒松开 = 落空，短冷却", not player.is_channeling() and is_equal_approx(snappedf(player.magic_cooldown_left(), 0.5), 1.5))
	check("档位阈值 0.6/1.2/2.0", player.channel_tier_for(0.59) == 0 and player.channel_tier_for(0.6) == 1
		and player.channel_tier_for(1.3) == 2 and player.channel_tier_for(2.0) == 3)

	# 1 档：半径 36，伤害 2
	_reset_magic()
	var near := _spawn_dummy(Vector2(30, 0))
	var mid := _spawn_dummy(Vector2(0, 46))
	var far := _spawn_dummy(Vector2(-66, 0))
	var tier := await _cast(0.75)
	check("按住 0.75 秒释放 1 档", tier == 1)
	check("1 档命中近处怪物（伤害 2）", near.health.hp == 18)
	check("1 档打不到 46px 外", mid.health.hp == 20)
	check("释放后冷却 6 秒", player.magic_cooldown_left() > 5.5 and not player.can_cast())
	# 2 档
	_reset_magic()
	for m in [near, mid, far]:
		m._attack_invuln = 0.0
	tier = await _cast(1.3)
	check("按住 1.3 秒释放 2 档", tier == 2)
	check("2 档命中 46px（伤害 3）", mid.health.hp == 17 and near.health.hp == 15)
	check("2 档打不到 66px 外", far.health.hp == 20)
	# 3 档：到 2 秒自动释放
	_reset_magic()
	for m in [near, mid, far]:
		m._attack_invuln = 0.0
	var cloud := TickleCloud.new()
	level.get_node("Entities").add_child(cloud)
	cloud.global_position = player.global_position + Vector2(0, -60)
	tier = await _cast(2.3)
	check("按满 2 秒自动释放 3 档", tier == 3)
	check("3 档命中 66px（伤害 4）", far.health.hp == 16)
	check("3 档让怪物僵直", far.is_stunned() and not far.can_act())
	check("3 档吹散痒痒粉雾", not is_instance_valid(cloud) or cloud.blown)
	for m in [near, mid, far]:
		m.queue_free()

	# 魔法姿态：小人图集、帧随蓄力推进、释放定住、对应的视觉状态
	await _run_magic_visuals()

	# 限制与打断
	_reset_magic()
	player.laugh.add(85.0)
	await _wait(0.05)
	check("闷笑值 >80 不能开始吟唱", not player.begin_channel())
	_reset_magic()
	await _wait(0.1)
	var interrupted := [0]
	var on_evt := func(e: String, _t: int):
		if e == "interrupted":
			interrupted[0] += 1
	player.magic_event.connect(on_evt)
	ctrl.hold(&"magic", true)
	await _wait(0.2)
	var tickler := _spawn_dummy(Vector2(10, 0))
	tickler.tickle(player)
	await _wait(0.05)
	check("80 以下被挠痒不打断", player.is_channeling() and interrupted[0] == 0)
	check("弱点暴露：挠痒 ×1.5", is_equal_approx(player.laugh.value, tickler.stats.tickle_amount * 1.5))
	player.laugh.add(80.0)
	await _wait(0.05)
	check("吟唱中进入失控被打断", not player.is_channeling() and interrupted[0] == 1)
	ctrl.hold(&"magic", false)
	await _wait(0.05)

	_reset_magic()
	await _wait(0.05)
	ctrl.hold(&"magic", true)
	await _wait(0.2)
	player.receive_hit(HitData.make_attack(tickler, 1))
	await _wait(0.05)
	check("吟唱中受到攻击被打断", not player.is_channeling() and interrupted[0] == 2)
	ctrl.hold(&"magic", false)
	await _wait(0.4)

	_reset_magic()
	await _wait(0.05)
	ctrl.hold(&"magic", true)
	await _wait(0.2)
	player.status.grab(tickler, 1.0, 3)
	await _wait(0.05)
	check("吟唱中被抓住被打断", not player.is_channeling() and interrupted[0] == 3)
	ctrl.hold(&"magic", false)
	player.status.release()
	player.magic_event.disconnect(on_evt)
	tickler.queue_free()

	# 弱点暴露吸引怪物
	_reset_magic()
	await _wait(0.8)
	var lured := _spawn_dummy(Vector2(150, 0), true)
	var ignored := _spawn_dummy(Vector2(0, 0), true)
	ignored.global_position = player.global_position + Vector2(0, 200)
	await _wait(0.05)
	lured.state = Monster.State.WANDER
	lured.target = null
	ignored.state = Monster.State.WANDER
	ignored.target = null
	ctrl.hold(&"magic", true)
	await _wait(0.15)
	check("180px 内的怪物锁定吟唱的公主", lured.target == player and lured.state == Monster.State.CHASE)
	check("180px 外的怪物不受影响", ignored.target != player)
	check("被吸引的怪物追击加速", lured.is_exposed_target(player))
	ctrl.hold(&"magic", false)
	await _wait(0.1)
	lured.queue_free()
	ignored.queue_free()
	_reset_magic()


# ------------------------------------------------------------------ 状态效果
## 假的挠痒来源：只有 reaction_key。
class Src extends Node2D:
	var reaction_key := ""


func _src(key: String, offset := Vector2(20, 0)) -> Src:
	var n := Src.new()
	n.reaction_key = key
	level.get_node("Entities").add_child(n)
	n.global_position = player.global_position + offset
	return n


func _tickle_from(key: String, amount := 4.0) -> void:
	var n := _src(key)
	player.receive_hit(HitData.make_tickle(n, amount))
	n.queue_free()


func _run_status_effects() -> void:
	print("-- 状态效果")
	_reset_magic()
	player.combo.reset()
	await _wait(0.1)
	var pos := player.global_position
	player.status.apply_root(0.5)
	ctrl.move = Vector2.RIGHT
	await _wait(0.25)
	check("定身：不能移动", player.global_position.distance_to(pos) < 2.0 and player.is_immobile())
	ctrl.press(&"dash")
	await _wait(0.05)
	check("定身：不能冲刺", player.state != PlayableCharacter.State.DASH)
	ctrl.press(&"attack")
	await _wait(0.05)
	check("定身：仍可攻击", player.state == PlayableCharacter.State.ATTACK)
	await _wait(0.5)
	check("定身结束后能移动", player.global_position.distance_to(pos) > 4.0 and not player.is_immobile())
	ctrl.move = Vector2.ZERO
	await _wait(0.1)

	player.laugh.clear()
	player.status.add_dot(4.0, 1.0, null)
	await _wait(1.1)
	check("余痒：每秒 4 持续 1 秒 ≈ 4", absf(player.laugh.value - 4.0) < 0.6 and not player.status.has_dot())
	player.laugh.clear()
	player.status.add_tickle_multiplier(1.5, 0.5)
	_tickle_from("slime", 10.0)
	check("易痒 ×1.5", is_equal_approx(player.laugh.value, 15.0))
	await _wait(0.6)
	player.laugh.clear()
	_tickle_from("slime", 10.0)
	check("易痒到时失效", is_equal_approx(player.laugh.value, 10.0))
	player.laugh.clear()

	pos = player.global_position
	for i in 20:
		player.add_push(Vector2(60, 0))
		await get_tree().physics_frame
	check("外力推动角色", player.global_position.x - pos.x > 10.0)
	check("外力不累积进速度", absf(player.velocity.x) < 1.0)
	var anchor := _src("", Vector2(-60, 0))
	pos = player.global_position
	player.status.add_pull(anchor, 50.0, 0.4)
	await _wait(0.45)
	check("拉扯：被拉向来源", player.global_position.x < pos.x - 8.0)
	anchor.queue_free()
	player.status.clear()


# ------------------------------------------------------------------ 组合技
func _combo_keys(c: Dictionary) -> Array:
	var keys: Array = []
	for slot in c["keys"]:
		var k: String = slot[0]
		if k == "*" or k == "*trap":
			for m in ComboTracker.group("monster" if k == "*" else "trap"):
				if not keys.has(m) and not c["keys"].any(func(sl: Array): return sl.has(m)):
					k = m
					break
		keys.append(k)
	return keys


func _run_combos() -> void:
	print("-- 组合技")
	var fired: Array[String] = []
	player.combo.triggered.connect(func(id: String): fired.append(id))
	var hud: Node = main.get_node("HUD")
	for c in ComboTracker.data()["combos"]:
		var id: String = c["id"]
		var text := ReactionDB.combo(id)
		check("组合技 %s 有名称和公主台词" % id, text.get("name", "") != "" and not text.get("lines", []).is_empty())
		if c.has("condition"):
			continue
		_reset_magic()
		player.combo.reset()
		fired.clear()
		# 只让这一个组合可以触发：其它组合都先进冷却（否则更高优先级的组合、或者三来源之前的两来源组合会先触发）
		for other in ComboTracker.ids():
			if other != id:
				player.combo._ready_at[other] = 1.0e9
		var keys := _combo_keys(c)
		keys.reverse()  # 顺序无关
		for k in keys:
			_tickle_from(k)
			await get_tree().physics_frame
		check("时间窗口组合 %s（%s）触发" % [id, ", ".join(keys)], fired == [id])
		if id == "sole_duet":
			check("脚心双重奏：额外挠痒 + 定身", player.laugh.value >= 8.0 + 15.0 and player.status.is_rooted())
			check("HUD 横幅显示组合技名", hud.combo_label.text.contains("脚心双重奏") and hud.combo_label.modulate.a > 0.5)
		elif id == "sticky_feather":
			check("黏黏羽毛：余痒", player.status.has_dot())
		elif id == "invisible_web":
			check("无形蛛网：定身 + 易痒", player.status.is_rooted() and player.status.tickle_multiplier() >= 1.5)
		elif id == "wind_brush":
			check("风卷刷：减速", player.status.is_slowed())

	_reset_magic()
	player.combo.reset()
	fired.clear()
	_tickle_from("rat")
	await _wait(1.7)
	_tickle_from("crab")
	check("超出 1.5 秒窗口不触发", fired.is_empty())
	player.combo.reset()
	_tickle_from("rat")
	_tickle_from("crab")
	_tickle_from("rat")
	_tickle_from("crab")
	check("同一组合 4 秒冷却", fired.size() == 1)
	player.combo.reset()
	fired.clear()
	_tickle_from("fairy")
	_tickle_from("vine")
	check("精灵起哄的 * 只匹配怪物（陷阱不算）", not fired.has("fairy_cheer"))
	_tickle_from("ghost")
	check("精灵起哄：精灵 + 任意怪物", fired.has("fairy_cheer"))
	player.combo.reset()
	fired.clear()
	_tickle_from("spider")
	_tickle_from("spider")
	check("同一来源挠两次不算组合", fired.is_empty())

	# 条件型：趁手打劫
	_reset_magic()
	player.combo.reset()
	fired.clear()
	var hand := _src("hand")
	player.status.grab(hand, 3.0, 99)
	await get_tree().physics_frame
	_tickle_from("slime", 10.0)
	check("趁手打劫：被机关手抓着时怪物挠痒 ×1.5", is_equal_approx(player.laugh.value, 15.0) and fired.has("hand_heist"))
	player.laugh.clear()
	_tickle_from("vine", 10.0)
	check("趁手打劫只对怪物生效", is_equal_approx(player.laugh.value, 10.0))
	player.status.release()
	hand.queue_free()

	# 条件型：扑粉蝙蝠
	_reset_magic()
	player.combo.reset()
	fired.clear()
	var bat: FeatherBat = load("res://scenes/actors/monsters/feather_bat.tscn").instantiate()
	level.get_node("Entities").add_child(bat)
	bat.global_position = player.global_position + Vector2(60, 0)
	var cloud := TickleCloud.new()
	cloud.affects_player = false
	level.get_node("Entities").add_child(cloud)
	cloud.global_position = bat.global_position
	await _wait(0.1)
	check("蝙蝠飞过粉雾后带粉", bat.is_powdered())
	bat.process_mode = Node.PROCESS_MODE_DISABLED
	bat.tickle(player)
	check("扑粉蝙蝠：挠痒附带余痒", fired.has("powdered_bat") and player.status.has_dot())
	bat.tickle(player)
	check("扑粉蝙蝠冷却中仍然附带余痒", player.status._dots.size() >= 2)
	bat.queue_free()
	cloud.queue_free()
	player.status.clear()
	_reset_magic()


# ------------------------------------------------------------------ 新怪物
func _spawn_monster(file: String, offset: Vector2, active := false) -> Monster:
	var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % file).instantiate()
	level.get_node("Entities").add_child(m)
	m.global_position = player.global_position + offset
	if not active:
		m.process_mode = Node.PROCESS_MODE_DISABLED
	return m


func _count(cls_check: Callable) -> int:
	var n := 0
	for c in level.get_node("Entities").get_children():
		if cls_check.call(c) and not c.is_queued_for_deletion():
			n += 1
	return n


func _run_new_monsters() -> void:
	print("-- 新怪物")
	for key in ["rat", "crab", "split_slime", "mimic", "fairy", "tentacle", "vine", "fan", "conveyor"]:
		var src := ReactionDB.source(key)
		check("台词文件有 %s 的首次遭遇和分档台词" % key, not src.get("first_encounter", []).is_empty() and not src.get("giggle", []).is_empty())

	# 挠脚鼠
	_reset_magic()
	var rat := _spawn_monster("foot_rat", Vector2(12, 0))
	check("挠脚鼠：挠痒优先（90%）、血 1", rat.stats.tickle_weight >= 0.9 and rat.health.max_hp == 1 and rat.stats.reaction_key == "rat")
	rat.tickle(player)
	var normal := player.laugh.value
	player.laugh.clear()
	player.status.apply_root(1.0)
	rat._action_cd = 0.0
	rat.tickle(player)
	check("挠脚鼠：公主动不了时挠痒 ×2", is_equal_approx(player.laugh.value, normal * 2.0) and normal > 0.0)
	player.status.clear()
	rat.receive_hit(HitData.make_attack(player, 1))
	await _wait(0.05)
	check("挠脚鼠一下就倒", not is_instance_valid(rat))

	# 钳钳蟹
	_reset_magic()
	var crab := _spawn_monster("pincer_crab", Vector2(12, 0))
	crab.tickle(player)
	check("钳钳蟹：夹脚定身", player.status.is_rooted() and player.laugh.value > 0.0)
	crab._move(Vector2(0.3, 1.0).normalized(), 40.0, 1.0)
	check("钳钳蟹横着走", absf(crab.velocity.x) > absf(crab.velocity.y))
	crab.queue_free()
	player.status.clear()

	# 分裂史莱姆
	_reset_magic()
	var is_split := func(c: Node): return c is SplitSlime
	var before: int = _count(is_split)
	var big := _spawn_monster("split_slime", Vector2(30, 0))
	check("分裂史莱姆血 4", big.health.max_hp == 4)
	big.receive_hit(HitData.make_attack(player, 4))
	await _wait(0.1)
	var minis: Array = level.get_node("Entities").get_children().filter(func(c: Node): return c is SplitSlime and c.is_mini and not c.is_queued_for_deletion())
	check("被打倒后分裂成 2 只小史莱姆", minis.size() == 2 and _count(is_split) == before + 2)
	check("小史莱姆血 1、挠痒 5", minis.size() > 0 and minis[0].health.max_hp == 1 and is_equal_approx(minis[0].stats.tickle_amount, 5.0))
	for m in minis:
		m.receive_hit(HitData.make_attack(player, 1))
	await _wait(0.1)
	check("小史莱姆不再分裂", _count(is_split) == before)
	big = _spawn_monster("split_slime", Vector2(30, 0))
	var h := HitData.make_attack(player, 4)
	h.tag = "magic_3"
	big.receive_hit(h)
	await _wait(0.1)
	check("被满蓄力星光打倒不分裂", _count(is_split) == before)

	# 宝箱怪
	_reset_magic()
	var mimic: Mimic = _spawn_monster("mimic", Vector2(0, -16), true)
	await _wait(0.1)
	check("宝箱怪伪装成宝箱，可以交互", mimic.is_disguised() and mimic.interactable.enabled)
	ctrl.hold(&"magic", true)
	await _wait(0.1)
	check("伪装时不被吟唱吸引", mimic.target == null)
	ctrl.hold(&"magic", false)
	await _wait(0.1)
	_reset_magic()
	mimic.on_interact(player)
	check("打开宝箱：现形并抓住公主", not mimic.is_disguised() and player.status.is_grabbed_by(mimic))
	await _wait(1.1)
	check("被宝箱怪抓着持续挠痒", player.laugh.value >= 14.0)
	for i in 8:
		player.struggle()
	await _wait(0.1)
	check("连按 8 次挣脱，宝箱怪开始追击", not player.status.is_grabbed() and mimic.state == Monster.State.CHASE)
	var drops: Array = mimic.stats.drops.filter(func(d: ItemDrop): return d.item.id == "mint" and d.chance >= 1.0 and d.min_amount == 2)
	check("宝箱怪必掉 2 颗薄荷糖", drops.size() == 1)
	mimic.queue_free()
	var mimic2: Mimic = _spawn_monster("mimic", Vector2(40, 0))
	mimic2.receive_hit(HitData.make_attack(player, 1))
	check("被攻击也会现形", not mimic2.is_disguised())
	mimic2.queue_free()
	player.status.clear()

	# 羽毛小精灵群
	_reset_magic()
	var fairy: FairySwarm = _spawn_monster("fairy_swarm", Vector2(20, 0))
	check("小精灵群只挠痒", fairy.stats.tickle_weight >= 1.0 and fairy.stats.attack_damage == 0)
	fairy.dodge_chance = 1.0
	check("普通攻击会被闪开", not fairy.receive_hit(HitData.make_attack(player, 1)) and fairy.health.hp == 3)
	StarBurst.cast(player, 1)
	check("魔法必中", fairy.health.hp == 1)
	fairy._attack_invuln = 0.0
	var fairy2: FairySwarm = _spawn_monster("fairy_swarm", Vector2(-20, 0))
	fairy2.health.max_hp = 50
	fairy2.health.fill()
	StarBurst.cast(player, 3)
	await _wait(0.1)
	check("满蓄力星光击散整群", not is_instance_valid(fairy2) and not is_instance_valid(fairy))

	# 痒痒触手怪
	_reset_magic()
	await _wait(0.3)
	var boss_seen := [null]
	var on_boss := func(m: Node): boss_seen[0] = m
	GameState.boss_changed.connect(on_boss)
	var gate: Node = load("res://scenes/objects/gate.tscn").instantiate()
	gate.group_name = "boss_test_gate"
	level.get_node("Entities").add_child(gate)
	gate.global_position = player.global_position + Vector2(200, 0)
	var boss: TentacleBoss = _spawn_monster("tentacle_boss", Vector2(0, -80), true)
	boss.open_on_death = "boss_test_gate"
	boss.strike_interval = 0.3
	boss._strike_cd = 0.1
	await _wait(0.25)
	check("触手怪出现 Boss 血条", boss_seen[0] == boss)
	check("触手落点预警", boss.pending_strikes() == 1)
	await _wait(0.7)
	check("预警后抽中：抓住公主", player.status.is_grabbed_by(boss) and boss.is_grabbing())
	var d0 := player.global_position.distance_to(boss.global_position)
	await _wait(0.6)
	check("把公主拉到身边并挠痒", player.global_position.distance_to(boss.global_position) < d0 and player.laugh.value > 0.0)
	for i in 12:
		player.struggle()
	await _wait(0.1)
	check("连按 12 次挣脱", not player.status.is_grabbed())
	_reset_magic()
	player.set_invulnerable(0.0)
	boss._strike_cd = 0.0
	await _wait(0.1)
	boss.on_magic_burst(3, player)
	check("满蓄力星光：收回触手并僵直", boss.pending_strikes() == 0 and boss.is_stunned())
	boss._stun_left = 0.0
	boss.health.hp = 9
	boss._summon_cd = 0.0
	var is_fairy := func(c: Node): return c is FairySwarm
	await _wait(0.1)
	check("血量低于一半召唤小精灵群", _count(is_fairy) >= 1)
	boss.health.damage(99)
	await _wait(0.1)
	check("触手怪倒下后 Boss 血条消失", boss_seen[0] == null)
	GameState.boss_changed.disconnect(on_boss)
	check("召唤的小精灵随 Boss 消失", _count(is_fairy) == 0)
	check("触手怪倒下打开 Boss 房的门", gate.is_open)
	gate.queue_free()
	player.status.clear()
	_reset_magic()


# ------------------------------------------------------------------ 新陷阱
func _spawn_trap(file: String, offset: Vector2, props := {}) -> Trap:
	var t: Trap = load("res://scenes/traps/%s.tscn" % file).instantiate()
	for k in props:
		t.set(k, props[k])
	level.get_node("FloorObjects").add_child(t)
	t.global_position = player.global_position + offset
	return t


func _run_new_traps() -> void:
	print("-- 新陷阱")
	_reset_magic()
	player.combo.reset()
	# 痒痒藤蔓
	var vine: TickleVine = _spawn_trap("tickle_vine", Vector2(0, 30))
	await _wait(0.1)
	player.global_position = vine.global_position
	await _wait(0.2)
	check("踩到藤蔓：缠住脚（定身）", player.status.is_rooted() and vine.is_dangerous())
	await _wait(0.6)
	check("缠住期间持续挠痒", player.laugh.value >= 11.0)
	player.facing = Vector2.DOWN
	player.global_position = vine.global_position + Vector2(0, -14)
	player.status.clear_root()
	await _wait(0.1)
	player.attack()
	await _wait(0.35)
	check("权杖砍断藤蔓", vine.is_cut() and not vine.cleared and not vine.active)
	vine.cut_left = 0.05
	await _wait(0.15)
	check("砍断后会长回来", not vine.is_cut() and vine.active)
	_reset_magic()
	StarBurst.cast(player, 3)
	check("满蓄力星光清除藤蔓，不再长回", vine.cleared)
	vine.queue_free()

	# 羽毛风扇
	_reset_magic()
	await _wait(0.1)
	var fan: FeatherFan = _spawn_trap("feather_fan", Vector2(-24, 0), {"dir": "right", "length": 5})
	fan.add_to_group("fan_test_lever")
	await _wait(0.1)
	var x0 := player.global_position.x
	await _wait(0.6)
	check("风扇把风道里的公主往外推", player.global_position.x - x0 > 20.0)
	check("风里的羽毛轻挠", player.laugh.value > 0.0)
	_reset_magic()
	player.global_position = fan.global_position + Vector2(24, 0)
	var cloud := TickleCloud.new()
	cloud.duration = 3.0
	level.get_node("Entities").add_child(cloud)
	cloud.global_position = fan.global_position + Vector2(40, 0)
	var r0 := cloud.radius
	await _wait(0.1)
	check("粉末旋风：粉雾顺风飘、变大", cloud.whirled and cloud.radius > r0 and cloud.drift.x > 0.0)
	player.combo.reset()
	player.global_position = cloud.global_position
	var fired := [false]
	var on_fire := func(id: String):
		if id == "powder_whirlwind":
			fired[0] = true
	player.combo.triggered.connect(on_fire)
	await _wait(0.6)
	check("旋风粉雾挠到公主触发粉末旋风", fired[0])
	player.combo.triggered.disconnect(on_fire)
	cloud.queue_free()
	var lever: Node = load("res://scenes/objects/lever.tscn").instantiate()
	lever.target = "fan_test_lever"
	level.get_node("Entities").add_child(lever)
	lever.global_position = player.global_position + Vector2(0, 60)
	lever.on_interact(player)
	check("拉杆关掉风扇", not fan.active and not fan.is_dangerous())
	_reset_magic()
	player.global_position = fan.global_position + Vector2(24, 0)
	x0 = player.global_position.x
	await _wait(0.4)
	check("关掉后不再推人", absf(player.global_position.x - x0) < 2.0)
	lever.queue_free()
	fan.queue_free()

	# 痒痒传送带
	_reset_magic()
	player.global_position += Vector2(0, -8)
	var conveyor: TickleConveyor = _spawn_trap("tickle_conveyor", Vector2(-8, 0), {"dir": "left", "length": 4})
	await _wait(0.1)
	x0 = player.global_position.x
	await _wait(0.5)
	check("传送带把公主往 dir 方向送", x0 - player.global_position.x > 10.0)
	check("滚轮轻挠", player.laugh.value > 0.0)
	var crab := _spawn_monster("pincer_crab", Vector2.ZERO, true)
	crab.global_position = conveyor.global_position + Vector2(-20, 0)
	var cx := crab.global_position.x
	crab.process_mode = Node.PROCESS_MODE_INHERIT
	crab.stun(1.0)
	await _wait(0.4)
	check("怪物也会被传送带送走", crab.global_position.x < cx - 4.0)
	crab.queue_free()
	conveyor.set_active(true)
	check("拉杆能停下传送带", not conveyor.is_dangerous())
	conveyor.queue_free()
	_reset_magic()


# ------------------------------------------------------------------ 第三层
func _run_floor3() -> void:
	print("-- 第三层")
	var exits := level.find_children("Exit*", "", true, false)
	check("第二层楼梯通往第三层", exits.size() == 1 and exits[0].resolve_target() == Floors.scene("floor_03"))
	_reset_magic()
	player.status.clear()
	GameState.flags.erase("magic_unlocked")
	var hp := player.health.hp
	await _goto("floor_03")
	check("切换到第三层", level.name == "Floor03" and level.get("floor_id") == "floor_03")
	check("状态跨层保留", player.health.hp == hp)
	check("第三层开场剧情教会星光爆发", player.is_magic_unlocked())
	check("第三层对话已载入", Dialogue.has_dialogue("boss3_intro") and Dialogue.has_dialogue("ending_3") and not Dialogue.has_dialogue("troll_intro"))
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	check("第三层所有地面都能从起点走到", _unreachable_cells(true).is_empty())

	var kinds := {}
	for m in level.find_children("*", "Monster", true, false):
		kinds[m.stats.reaction_key] = kinds.get(m.stats.reaction_key, 0) + 1
	for k in ["rat", "crab", "split_slime", "mimic", "fairy", "tentacle"]:
		check("第三层有 %s" % k, kinds.get(k, 0) > 0)
	check("两只宝箱怪（宝物间 + 触手怪大厅角落）、一只触手怪", kinds.get("mimic", 0) == 2 and kinds.get("tentacle", 0) == 1)
	check("落脚点有练手的小精灵", _find("Fairy_15_45") != null)
	var trap_types := {}
	for t in level.find_children("*", "Trap", true, false):
		trap_types[t.get_script().get_global_name()] = true
	for cls in ["TickleVine", "FeatherFan", "TickleConveyor", "PowderVent", "FeatherBrush"]:
		check("第三层有陷阱 %s" % cls, trap_types.has(cls))

	var fans := get_tree().get_nodes_in_group("fans")
	check("风洞有 3 台风扇", fans.size() == 3)
	_find("Lever_48_21").on_interact(player)
	check("风洞拉杆关掉全部风扇", fans.all(func(f: Trap): return not f.active))
	var belts := get_tree().get_nodes_in_group("belts")
	_find("Lever_34_28").on_interact(player)
	check("工坊拉杆停下全部传送带（3 条整宽 + 1 条）", belts.size() == 4 and belts.all(func(b: Trap): return not b.active))

	var gate: Node = _find("Gate_39_6")
	var boss: TentacleBoss = _find("Tentacle_25_4")
	check("Boss 门初始关闭", not gate.is_open)
	boss.health.damage(99)
	await _wait(0.1)
	check("打倒触手怪后 Boss 门打开", gate.is_open)
	var exit: Node = _find("Exit_44_5")
	check("出口楼梯通往第四层（带结尾剧情）", exit != null and exit.dialogue == "ending_3" and exit.target_level == "next"
		and exit.resolve_target() == Floors.scene("floor_04"))
	Dialogue.start("ending_3")
	_finish_dialogue()
	await _wait(0.2)
	check("第三章通关标记", GameState.has_flag("chapter3_clear"))


func _magic_sheet_frame() -> Vector2i:
	return player.sprite.frame_coords


func _run_magic_visuals() -> void:
	var princess := player as Princess
	var walk_tex: Texture2D = player.animator._default["texture"]
	_reset_magic()
	princess.battle_damaged = false
	player.facing = Vector2.DOWN
	await _wait(0.1)
	ctrl.hold(&"magic", true)
	await _wait(0.1)
	check("吟唱姿态：普通 → chant", princess.emotion.current == "chant")
	check("吟唱时换成 48 格魔法图集", player.animator.sheet == "magic" and player.sprite.hframes == 32 and player.sprite.texture != walk_tex)
	var early := _magic_sheet_frame().x
	check("对话立绘 / HUD 头像有吟唱姿态", Dialogue.portrait_for("chant") != Dialogue.portrait_for("normal") and Dialogue.head_for("chant") != Dialogue.head_for("normal"))
	await _wait(1.75)
	var late := _magic_sheet_frame().x
	check("吟唱帧随蓄力推进（正面第 1 帧 → 第 7~8 帧）", early <= 1 and late >= 6 and late <= 7)
	check("魔法图集行 = 当前姿态", _magic_sheet_frame().y == 0)
	ctrl.hold(&"magic", false)
	await _wait(0.05)
	check("释放：进入 CAST，姿态 burst", player.is_casting() and princess.emotion.current == "burst" and _magic_sheet_frame().y == 1)
	var pos := player.global_position
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	check("释放动作期间原地定住", player.is_casting() and player.global_position.distance_to(pos) < 2.0 and player.is_immobile())
	await _wait(0.3)
	check("约 0.5 秒后恢复行动、换回行走图集", not player.is_casting() and player.animator.sheet == "" and player.sprite.texture == walk_tex)
	ctrl.move = Vector2.ZERO
	await _wait(0.1)

	# 战损 / 战损闷笑
	var cases := [[false, 0.0, "chant", "burst"], [true, 0.0, "damaged_chant", "damaged_burst"], [true, 70.0, "damaged_giggle_chant", "damaged_giggle_burst"]]
	for c in cases:
		_reset_magic()
		princess.battle_damaged = c[0]
		player.laugh.set_value(c[1])
		await _wait(0.05)
		ctrl.hold(&"magic", true)
		await _wait(0.7)
		check("吟唱姿态：战损=%s 闷笑=%d → %s" % [c[0], c[1], c[2]], princess.emotion.current == c[2])
		ctrl.hold(&"magic", false)
		await _wait(0.05)
		check("释放姿态 → %s" % c[3], princess.emotion.current == c[3]
			and _magic_sheet_frame().y == GameState.MAGIC_VISUALS.find(c[3]))
		await _wait(0.6)
	check("战损闷笑释放借用战损释放立绘", Dialogue.portrait_for("damaged_giggle_burst").region.size == Dialogue.portrait_for("damaged_burst").region.size)

	# 释放动作中受到攻击 → 受伤
	_reset_magic()
	princess.battle_damaged = false
	await _wait(0.05)
	ctrl.hold(&"magic", true)
	await _wait(0.7)
	ctrl.hold(&"magic", false)
	await _wait(0.05)
	var foe := _spawn_dummy(Vector2(40, 0))
	player.receive_hit(HitData.make_attack(foe, 1))
	check("释放动作中受到攻击会中断（受伤）", player.state == PlayableCharacter.State.HURT)
	foe.queue_free()
	await _wait(0.4)
	princess.battle_damaged = false
	_reset_magic()


## 从公主位置出发做 4 邻域洪泛：墙层有图块的格子不可走（暗墙可选视为可走），门、铁栅视为可走。
## 返回地面层上走不到的格子。
func _unreachable_cells(secret_open: bool) -> Array[Vector2i]:
	var walls: TileMapLayer = level.get_node("Walls")
	var floor_layer: TileMapLayer = level.get_node("Floor")
	var open := {}
	if secret_open:
		for s in level.find_children("*", "SecretWall", true, false):
			open[walls.local_to_map(walls.to_local(s.global_position + Vector2(0, -8)))] = true
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or floor_layer.get_cell_source_id(n) == -1:
				continue
			if walls.get_cell_source_id(n) != -1 and not open.has(n):
				continue
			seen[n] = true
			queue.append(n)
	var missing: Array[Vector2i] = []
	for c in floor_layer.get_used_cells():
		if walls.get_cell_source_id(c) == -1 and not seen.has(c):
			missing.append(c)
	if not missing.is_empty():
		print("    走不到的格子（前 10 个）: ", missing.slice(0, 10))
	return missing


# ------------------------------------------------------------------ 工具
func _move_player_to(c: Vector2i) -> void:
	player.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 12)
	player.velocity = Vector2.ZERO


func _goto(floor_id: String) -> void:
	main.change_level(Floors.scene(floor_id))
	await _wait(1.2)
	_finish_dialogue()
	_refresh()


func _refresh() -> void:
	level = main.level
	player = get_tree().get_first_node_in_group("player") as PlayableCharacter


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _find(n: String) -> Node:
	var node := level.find_child(n, true, false)
	if node == null:
		print("    找不到节点 " + n)
	return node


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 200:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
