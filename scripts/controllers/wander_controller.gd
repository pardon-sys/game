class_name WanderController
extends CharacterController
## AI 输入：在关卡里 wander_spot 组的点之间溜达（蓝色公主平时用）。
## 用 Walls 图块和静态物体（摊位、房子……）做格子 BFS 寻路，顺着路点走；卡住就换一个点。
## 到点后停 rest_time 秒（偶尔做个表情）；公主在附近时转头看她；对话 / 过场中、paused 时不动。
## 没有 wander_spot 时在出生点 home_radius 格内随便挑一格。

const TILE := 16.0

@export var rest_time := Vector2(2.0, 5.0)
@export var home_radius := 6
## 走路速度（移动向量的长度，1 = 跑满速）。
@export var pace := 0.55

var paused := false
var body: PlayableCharacter
var path: Array[Vector2] = []
var target_spot: Node2D
var _wait := 1.0
var _move := Vector2.ZERO
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _home := Vector2.INF
var _blocked_cache := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	body = get_parent() as PlayableCharacter
	_rng.randomize()
	_wait = _rng.randf_range(0.5, 2.0)


func get_move_vector() -> Vector2:
	if paused or GameState.in_dialogue or GameState.in_cutscene:
		return Vector2.ZERO
	return _move


func _physics_process(delta: float) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	if _home == Vector2.INF:
		_home = body.global_position
	_move = Vector2.ZERO
	if paused or GameState.in_dialogue or GameState.in_cutscene:
		return
	if path.is_empty():
		_wait -= delta
		_look_at_player()
		if _wait <= 0.0:
			_pick_target()
		return
	var to := path[0] - body.global_position
	if to.length() < 3.0:
		path.pop_front()
		if path.is_empty():
			_arrive()
		return
	_move = to.normalized() * pace
	# 卡住检测：一直没走动就换一个点
	if body.global_position.distance_to(_last_pos) < 0.3:
		_stuck += delta
		if _stuck > 0.8:
			_stuck = 0.0
			path.clear()
			_wait = 0.3
	else:
		_stuck = 0.0
	_last_pos = body.global_position


func _arrive() -> void:
	_wait = _rng.randf_range(rest_time.x, rest_time.y)
	if body.emotion and _rng.randf() < 0.35:
		body.emotion.request(["happy", "shy", "surprise"][_rng.randi() % 3], 1.5)


func _look_at_player() -> void:
	var p := GameState.player
	if is_instance_valid(p) and p != body and p.global_position.distance_to(body.global_position) < 48.0:
		var d := p.global_position - body.global_position
		if d.length() > 1.0:
			body.facing = d.normalized()


func _level() -> Node:
	var n: Node = body
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori((p.y - 4.0) / TILE))


func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE - 4.0)


func _blocked(c: Vector2i, walls: TileMapLayer, floor_layer: TileMapLayer) -> bool:
	if _blocked_cache.has(c):
		return _blocked_cache[c]
	var b := floor_layer.get_cell_source_id(c) == -1 or walls.get_cell_source_id(c) != -1
	if not b:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = _center(c)
		q.collision_mask = 1
		for hit in body.get_world_2d().direct_space_state.intersect_point(q, 4):
			if hit["collider"] is StaticBody2D:
				b = true
	_blocked_cache[c] = b
	return b


func _pick_target() -> void:
	var lv := _level()
	if lv == null:
		_wait = 2.0
		return
	var walls: TileMapLayer = lv.get_node("Walls")
	var floor_layer: TileMapLayer = lv.get_node("Floor")
	var spots := body.get_tree().get_nodes_in_group("wander_spot").filter(func(s): return lv.is_ancestor_of(s) and s != target_spot)
	var goal: Vector2i
	if not spots.is_empty():
		target_spot = spots[_rng.randi() % spots.size()]
		goal = _cell(target_spot.global_position)
	else:
		goal = _cell(_home) + Vector2i(_rng.randi_range(-home_radius, home_radius), _rng.randi_range(-home_radius, home_radius))
	var route := _bfs(_cell(body.global_position), goal, walls, floor_layer)
	if route.is_empty():
		_wait = 1.0
		return
	path.clear()
	for c in route:
		path.append(_center(c))
	_last_pos = body.global_position


func _bfs(start: Vector2i, goal: Vector2i, walls: TileMapLayer, floor_layer: TileMapLayer) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _blocked(goal, walls, floor_layer):
		# 目标格被挡住（点放在道具上）：找旁边能站的格子
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if not _blocked(goal + d, walls, floor_layer):
				goal += d
				break
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var guard := 0
	while not queue.is_empty() and guard < 6000:
		guard += 1
		var c: Vector2i = queue.pop_front()
		if c == goal:
			while c != start:
				out.push_front(c)
				c = prev[c]
			return out
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not prev.has(n) and not _blocked(n, walls, floor_layer):
				prev[n] = c
				queue.append(n)
	return out
