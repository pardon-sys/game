extends Node
## 关卡设计测试：强制遭遇段绕不过去、锁门战斗房的上锁 / 解锁 / 倒下重置、各层从起点能走到出口。
## 用法：Godot --headless --path . res://tests/level_design_test.tscn   （退出码 0 = 全部通过）
##
## "危险格" = 关卡里所有陷阱覆盖的格子（风扇风道、整条传送带、机关手下方、压力板、羽毛 / 藤蔓 / 喷口 / 尖刺 / 旋转刷所在格）。
## 强制段检查：避开危险格就从 start 走不到 goal（证明玩家不得不踩进陷阱区），允许踩危险格时能走到（证明路是通的）。

## [楼层, 名称, 起点格, 终点格]
const FORCED := [
	["floor_01", "守卫室门前的羽毛门廊", Vector2i(31, 35), Vector2i(31, 29)],
	["floor_01", "尖刺走廊（尖刺 + 羽毛带）", Vector2i(8, 4), Vector2i(50, 4)],
	["floor_01", "宝库的传送带与羽毛带", Vector2i(52, 9), Vector2i(52, 17)],
	["floor_02", "蝙蝠巢穴的风扇风道", Vector2i(9, 22), Vector2i(17, 9)],
	["floor_02", "幽灵长廊的藤蔓带", Vector2i(17, 7), Vector2i(52, 9)],
	["floor_02", "机关走廊的整高传送带", Vector2i(50, 31), Vector2i(30, 33)],
	["floor_03", "鼠窝的藤蔓带", Vector2i(19, 47), Vector2i(38, 48)],
	["floor_03", "蟹池出口的传送带", Vector2i(50, 39), Vector2i(42, 33)],
	["floor_03", "传送带工坊", Vector2i(41, 33), Vector2i(30, 27)],
	["floor_03", "风洞走廊", Vector2i(30, 23), Vector2i(19, 18)],
]
## [楼层, 战斗房铁栅组]
const ARENAS := [
	["floor_01", "arena_guard"], ["floor_02", "arena_spider"], ["floor_02", "arena_troll"],
	["floor_03", "arena_rats"], ["floor_03", "arena_hall"], ["floor_03", "arena_trial"], ["floor_03", "arena_boss"],
]

var main: Node
var level: Node
var player: Princess
var failures := 0


func _ready() -> void:
	Monster.random_specials = false  # 这里要精确的挠痒数值；暴击在 floor4_test 里测
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	for id in Floors.ids():
		if id != "floor_01":
			main.change_level(Floors.scene(id))
			await _wait(1.4)
		_finish_dialogue()
		level = main.level
		player = GameState.player as Princess
		player.set_controller(ScriptedController.new())
		for e in get_tree().get_nodes_in_group("enemy"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
		print("-- ", id)
		_run_forced(id)
		await _run_arenas(id)
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 强制遭遇
func _run_forced(id: String) -> void:
	var hazards := hazard_cells()
	for f in FORCED:
		if f[0] != id:
			continue
		var start: Vector2i = f[2]
		var goal: Vector2i = f[3]
		var open_ok := _reachable(start, goal, {})
		var avoid_ok := _reachable(start, goal, hazards)
		check("强制段「%s」：路是通的，但不踩陷阱区就过不去" % f[1], open_ok and not avoid_ok)
	if id == "floor_03":
		# 对照：安全区里不碰陷阱也能走动（证明上面的检查不是恒成立）
		check("对照：第三层落脚点里不踩陷阱也能走动", _reachable(Vector2i(10, 50), Vector2i(12, 45), hazards))
	check("%s：从起点能走到每一块地面（铁栅、门视为可通过）" % id, _reachable_all())


## 所有陷阱覆盖的格子。
func hazard_cells() -> Dictionary:
	var walls: TileMapLayer = level.get_node("Walls")
	var cells := {}
	var cell_of := func(p: Vector2) -> Vector2i: return walls.local_to_map(walls.to_local(p))
	for n in level.find_children("*", "", true, false):
		if n is FeatherFan:
			var fan := n as FeatherFan
			var c0: Vector2i = cell_of.call(fan.global_position)
			for dx in range(-fan.length - 2, fan.length + 3):
				for dy in range(-fan.length - 2, fan.length + 3):
					var c := c0 + Vector2i(dx, dy)
					if fan.in_lane(walls.to_global(walls.map_to_local(c))):
						cells[c] = true
			cells[c0] = true
		elif n is TickleConveyor:
			var belt := n as TickleConveyor
			var c0: Vector2i = cell_of.call(belt.global_position)
			for i in belt.length:
				cells[c0 + Vector2i(belt.belt) * i] = true
		elif n is GrabHand:
			cells[cell_of.call((n as Node2D).global_position) + Vector2i(0, 1)] = true
		elif n is Trap or (n.get_script() and str(n.get_script().resource_path).ends_with("pressure_plate.gd")):
			cells[cell_of.call((n as Node2D).global_position)] = true
	return cells


func _walkable(c: Vector2i, blocked: Dictionary) -> bool:
	var walls: TileMapLayer = level.get_node("Walls")
	var floor_layer: TileMapLayer = level.get_node("Floor")
	return floor_layer.get_cell_source_id(c) != -1 and walls.get_cell_source_id(c) == -1 and not blocked.has(c)


func _flood(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nc: Vector2i = c + d
			if not seen.has(nc) and _walkable(nc, blocked):
				seen[nc] = true
				queue.append(nc)
	return seen


func _reachable(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> bool:
	return _flood(start, blocked).has(goal)


func _reachable_all() -> bool:
	var walls: TileMapLayer = level.get_node("Walls")
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var seen := _flood(start, {})
	var missing := 0
	for c in (level.get_node("Floor") as TileMapLayer).get_used_cells():
		if _walkable(c, {}) and not seen.has(c):
			missing += 1
	# 第一层的秘密储物间要推倒暗墙才进得去
	return missing == 0 or (level.get("floor_id") == "floor_01" and missing <= 60)


# ------------------------------------------------------------------ 锁门战斗房
func _gates(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(n: Node): return n is StaticBody2D and n.has_method("set_open"))


func _arena(group: String) -> ArenaZone:
	for a in get_tree().get_nodes_in_group("arena"):
		if a.group_name == group:
			return a
	return null


func _run_arenas(id: String) -> void:
	for a_info in ARENAS:
		if a_info[0] != id:
			continue
		var group: String = a_info[1]
		var arena := _arena(group)
		var gates := _gates(group)
		check("战斗房 %s 存在且有铁栅" % group, arena != null and not gates.is_empty())
		if arena == null:
			continue
		check("%s：进去之前门是开的" % group, gates.all(func(g: Node): return g.is_open))
		player.revive()
		player.global_position = arena.global_position
		await _wait(0.2)
		check("%s：进去后门关上、困在房间里" % group, arena.active and gates.all(func(g: Node): return not g.is_open) and arena.remaining() > 0)
		if group == ARENAS.filter(func(x: Array): return x[0] == id)[0][1]:
			# 每层第一个战斗房再测一次倒下重置
			await _laugh_down()
			check("%s：中途笑倒 → CG → 复活后门打开、战斗重置" % group, not arena.active and gates.all(func(g: Node): return g.is_open) and not arena.cleared)
			player.global_position = arena.global_position
			await _wait(0.2)
			check("%s：再次进入重新上锁" % group, arena.active and gates.all(func(g: Node): return not g.is_open))
		for m in arena._tracked:
			if is_instance_valid(m) and m.is_alive():
				m.health.damage(999)
		await _wait(0.4)
		for m in get_tree().get_nodes_in_group("enemy"):  # 分裂出来 / 召唤出来的
			if arena.room_rect().has_point(m.global_position) and m.is_alive():
				m.health.damage(999)
		await _wait(0.4)
		check("%s：打倒所有怪物后开门，不再触发" % group, not arena.active and arena.cleared and gates.all(func(g: Node): return g.is_open))
		_finish_dialogue()


func _laugh_down() -> void:
	player._full_invuln = 0.0
	player.health.damage(player.health.hp - 1)
	player.laugh.set_value(148.0)
	var src := Node2D.new()
	level.get_node("Entities").add_child(src)
	player.receive_hit(HitData.make_tickle(src, 10.0))
	var t := 0.0
	while not CG.is_playing() and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	CG._can_skip = true
	CG.skip()
	await _wait(0.8)
	_finish_dialogue()
	src.queue_free()


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
