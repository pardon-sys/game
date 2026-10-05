class_name TerrainShifter
extends Node
## 改变地形（可复用；第八层 Boss 阶段二 / 三用）：
##   raise_walls(格子们)   这些格子升起石墙（Walls 图层，碰撞跟着有）；有人站着的格子跳过，带尘土和震动
##   spawn_field(kind, 格子, opts)  放一片临时陷阱：mud（opts.w / h）、conveyor（opts.dir / len）、pit（opts.content）
##   clear()               收回所有石墙和临时陷阱
##   life > 0 时（raise_walls / spawn_field 的最后一个参数）到时间自己收回——第八层阶段二的「持续变化」用它。
##   vortex（opts.radius）：挠痒漩涡（强制位移）。
## 墙块用 ref_cell 那一格的墙图块（关卡里本来就有的墙）。

const TRAPS := {
	"mud": "res://scenes/traps/mud.tscn",
	"conveyor": "res://scenes/traps/tickle_conveyor.tscn",
	"pit": "res://scenes/traps/pit.tscn",
	"feather": "res://scenes/traps/feather_trap.tscn",
	"vortex": "res://scenes/traps/tickle_vortex.tscn",
}

var level: Node2D
var walls: TileMapLayer
var raised: Array[Vector2i] = []
var fields: Array[Node] = []
## 有寿命的东西：[{cells 或 node, until}]
var _timed: Array[Dictionary] = []
var _clock := 0.0
var _src := 0
var _atlas := Vector2i.ZERO


func setup(lv: Node2D, ref_cell: Vector2i) -> void:
	level = lv
	walls = lv.get_node("Walls")
	_src = walls.get_cell_source_id(ref_cell)
	_atlas = walls.get_cell_atlas_coords(ref_cell)


func cell_center(c: Vector2i) -> Vector2:
	return walls.to_global(walls.map_to_local(c))


func _occupied(c: Vector2i) -> bool:
	var center := cell_center(c)
	for n in get_tree().get_nodes_in_group("actor"):
		if n is Node2D and level.is_ancestor_of(n) and (n as Node2D).global_position.distance_to(center + Vector2(0, 4)) < 13.0:
			return true
	return false


func raise_walls(cells: Array, life := 0.0) -> int:
	var n := 0
	var placed: Array[Vector2i] = []
	for c in cells:
		var cell := c as Vector2i
		if walls.get_cell_source_id(cell) != -1 or _occupied(cell):
			continue
		walls.set_cell(cell, _src, _atlas)
		raised.append(cell)
		placed.append(cell)
		n += 1
		if n % 3 == 0:
			Fx.burst(level, cell_center(cell), "dust", 4, 30.0, 0.4, Vector2(0, 20))
	if n > 0:
		Audio.play("door_close", -4.0, 0.1, 0.6)
		if life > 0.0:
			_timed.append({"cells": placed, "until": _clock + life})
	return n


func lower_cells(cells: Array) -> void:
	for c in cells:
		if raised.has(c):
			walls.erase_cell(c)
			raised.erase(c)
			Fx.burst(level, cell_center(c), "dust", 2, 20.0, 0.3, Vector2(0, 20))


func lower_walls() -> void:
	for c in raised:
		walls.erase_cell(c)
		Fx.burst(level, cell_center(c), "dust", 2, 20.0, 0.3, Vector2(0, 20))
	raised.clear()


func spawn_field(kind: String, cell: Vector2i, opts := {}, life := 0.0) -> Node:
	if not TRAPS.has(kind):
		return null
	var t: Node2D = load(TRAPS[kind]).instantiate()
	match kind:
		"mud":
			t.set("tiles_w", int(opts.get("w", 3)))
			t.set("tiles_h", int(opts.get("h", 2)))
		"conveyor":
			t.set("dir", str(opts.get("dir", "right")))
			t.set("length", int(opts.get("len", 4)))
		"pit":
			t.set("content", str(opts.get("content", "squirrel")))
		"vortex":
			t.set("radius", int(opts.get("radius", 2)))
	var parent := level.get_node_or_null("FloorObjects")
	(parent if parent else level).add_child(t)
	t.global_position = cell_center(cell) + Vector2(0, 0)
	t.modulate.a = 0.0
	t.create_tween().tween_property(t, "modulate:a", 1.0, 0.4)
	fields.append(t)
	if life > 0.0:
		_timed.append({"node": t, "until": _clock + life})
	return t


func _process(delta: float) -> void:
	_clock += delta
	for e in _timed.duplicate():
		if _clock < float(e["until"]):
			continue
		_timed.erase(e)
		if e.has("cells"):
			lower_cells(e["cells"])
		elif is_instance_valid(e["node"]):
			var n: Node2D = e["node"]
			fields.erase(n)
			var tw := n.create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 0.4)
			tw.tween_callback(n.queue_free)


## 现在场上有几样临时地形（石墙按段算）。
func active_count() -> int:
	return _timed.size()


func clear() -> void:
	lower_walls()
	for f in fields:
		if is_instance_valid(f):
			f.queue_free()
	fields.clear()
	_timed.clear()
