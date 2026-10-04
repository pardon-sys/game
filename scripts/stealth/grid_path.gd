class_name GridPath
extends RefCounted
## 格子寻路（巡逻士兵去查看石子落点 / 回到路线用）：按关卡的 Floor / Walls 图块做 BFS，返回一串世界坐标（每格中心）。

const TILE := 16.0


static func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori((p.y - 4.0) / TILE))


static func center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE - 4.0)


static func walkable(level: Node, c: Vector2i) -> bool:
	var floor_layer: TileMapLayer = level.get_node_or_null("Floor")
	var walls: TileMapLayer = level.get_node_or_null("Walls")
	if floor_layer == null or walls == null:
		return true
	return floor_layer.get_cell_source_id(c) != -1 and walls.get_cell_source_id(c) == -1


## 从 from 到 to 的路（不含起点）；走不到返回空数组。
static func find(level: Node, from: Vector2, to: Vector2, limit := 4000) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if level == null:
		return out
	var start := cell(from)
	var goal := cell(to)
	if not walkable(level, goal):
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if walkable(level, goal + d):
				goal += d
				break
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var n := 0
	while not queue.is_empty() and n < limit:
		n += 1
		var c: Vector2i = queue.pop_front()
		if c == goal:
			while c != start:
				out.push_front(center(c))
				c = prev[c]
			return out
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb: Vector2i = c + d
			if not prev.has(nb) and walkable(level, nb):
				prev[nb] = c
				queue.append(nb)
	return out
