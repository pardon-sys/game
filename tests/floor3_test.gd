extends Node
## 楼层扩充 / 第三层 / 魔法 / 组合技测试。
## 用法：Godot --headless --path . res://tests/floor3_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: PlayableCharacter
var failures := 0


func _ready() -> void:
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
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 楼层表
func _run_floors() -> void:
	print("-- 楼层表")
	var ids := Floors.ids()
	check("floors.json 顺序", ids.slice(0, 2) == ["floor_01", "floor_02"])
	check("下一层", Floors.next_of("floor_01") == "floor_02")
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
	player._magic_cd = 0.0
	player.laugh.clear()
	player.health.fill()
	player.status.clear()
	player._attack_invuln = 0.0
	player._full_invuln = 0.0


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
		if k == "*":
			for m in ComboTracker.group("monster"):
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
