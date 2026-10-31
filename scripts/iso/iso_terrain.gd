class_name IsoTerrain
extends Node
## 等距地形（可复用；跟着 IsoView 一起挂，外观来自 IsoTheme）：读宿主的 Floor / Walls 图层（逻辑格子，已被 IsoView 隐藏），画成等距画面。
##   地面：屏幕空间的等距图块层（ISOMETRIC + DIAMOND_DOWN，32x16），按当前视角把每个地面格放到转后的位置；再随机撒些跨格的装饰。
##   墙：Walls 每格一个方块墙精灵（进 Entities，和人物一起按屏幕 y 排序）；每格一块菱形挡光（屏幕空间）。
##   Walls 图层变了（TerrainShifter 升墙 / 降墙）→ 很快自动补上 / 拿掉（新墙淡入）：每 POLL 秒对一次（TileMapLayer 改格子不发信号）。
##   claim(格, 节点)：这一格的墙由别人画（活墙之类自己有动画）——这里不放墙块，但挡光照旧。release(格) 还回来。
##     也可以让节点进分组 iso_wall_owner、带一个 cell 属性：地形建起来时自动认领（节点比地形先进树时用）。
##   前景淡化：在主角前面、又挡住她身体的墙块，淡到主题的 fade_alpha（别人画的墙用 should_fade(屏幕位置) 自己判断）。
##   转视角（IsoView.rotated）时全部重排。

const LAYER_NAME := "IsoFloor"
const DECAL_CHANCE := 0.07
const FADE_SPEED := 6.0
const OWNER_GROUP := "iso_wall_owner"
const POLL := 0.1

var view: IsoView
var theme: IsoTheme
var host: Node2D
var floor_src: TileMapLayer
var walls_src: TileMapLayer
var entities: Node2D
var floor_layer: TileMapLayer
var decals: Node2D
var occluders: Node2D
var cubes := {}          # Vector2i -> Sprite2D
var occ := {}            # Vector2i -> LightOccluder2D
var claimed := {}        # Vector2i -> Node
var _decal_spots: Array = []   # [格子, 种类, 偏移]
var _dirty := false
var _poll_t := 0.0
var _faded := {}
var _wall_tex: Texture2D
## 前景淡化看谁（默认当前操控的角色）
var focus: Node2D


static func of(n: Node) -> IsoTerrain:
	var v := IsoView.current
	return v.get_node_or_null("IsoTerrain") as IsoTerrain if v else null


static func attach(v: IsoView, t: IsoTheme) -> IsoTerrain:
	var it := IsoTerrain.new()
	it.name = "IsoTerrain"
	it.view = v
	it.theme = t
	v.add_child(it)
	return it


func _ready() -> void:
	host = view.host
	view.light_squash = theme.light_squash
	floor_src = host.get_node_or_null("Floor") as TileMapLayer
	walls_src = host.get_node_or_null("Walls") as TileMapLayer
	entities = host.get_node_or_null("Entities") as Node2D
	if entities == null:
		entities = host
	_wall_tex = IsoTheme.lit(theme.walls, theme.walls_normal)
	floor_layer = TileMapLayer.new()
	floor_layer.name = LAYER_NAME
	floor_layer.tile_set = _make_tileset()
	floor_layer.collision_enabled = false   # 只是画面（碰撞在原来的 Walls 图层）
	floor_layer.add_to_group(IsoView.SCREEN_GROUP)
	decals = Node2D.new()
	decals.name = "IsoDecals"
	decals.add_to_group(IsoView.SCREEN_GROUP)
	occluders = Node2D.new()
	occluders.name = "IsoOccluders"
	occluders.add_to_group(IsoView.SCREEN_GROUP)
	host.add_child(floor_layer)
	host.move_child(floor_layer, 0)
	host.add_child(decals)
	host.move_child(decals, 1)
	host.add_child(occluders)
	_pick_decals()
	for n in get_tree().get_nodes_in_group(OWNER_GROUP):
		if host.is_ancestor_of(n):
			claimed[n.get("cell")] = n
	if walls_src:
		for c in walls_src.get_used_cells():
			_add_wall(c, false)
	rebuild()
	view.rotated.connect(func(_k): rebuild())


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(32, 16)
	var src := TileSetAtlasSource.new()
	src.texture = IsoTheme.lit(theme.floor, theme.floor_normal)
	src.texture_region_size = Vector2i(32, 16)
	ts.add_source(src, 0)
	var n := theme.floor_period
	for k in 4:
		for c in n * n:
			src.create_tile(Vector2i(c, k))
	return ts


func _pick_decals() -> void:
	if floor_src == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(host.get("floor_id")) + theme.theme_name)
	for c in floor_src.get_used_cells():
		if rng.randf() < DECAL_CHANCE:
			_decal_spots.append([c, rng.randi_range(0, theme.decal_count - 1), Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))])


# ------------------------------------------------------------------ 重建（开场 / 转视角）
func rebuild() -> void:
	_place_floor()
	_place_decals()
	for c in cubes:
		(cubes[c] as Sprite2D).position = _cube_pos(c)
	for c in occ:
		_shape_occluder(occ[c], c)


func _place_floor() -> void:
	floor_layer.clear()
	if floor_src == null:
		return
	# 对齐：格子 (0,0) 在等距图块层里的中心应该在 (0, 8)
	floor_layer.position = Vector2(0, 8) - floor_layer.map_to_local(Vector2i.ZERO)
	var n := theme.floor_period
	for c in floor_src.get_used_cells():
		if walls_src and walls_src.get_cell_source_id(c) != -1 and not claimed.has(c):
			continue
		var tile := Vector2i(posmod(c.y, n) * n + posmod(c.x, n), view.k)
		floor_layer.set_cell(view.cell_to_iso_map(c), 0, tile)


func _place_decals() -> void:
	for ch in decals.get_children():
		ch.queue_free()
	for spot in _decal_spots:
		var s := Sprite2D.new()
		s.texture = theme.decals
		s.region_enabled = true
		s.region_rect = Rect2(view.k * 64, int(spot[1]) * 32, 64, 32)
		s.position = view.project(Vector2(spot[0]) * IsoView.CELL + Vector2(8, 8) + spot[2])
		decals.add_child(s)


# ------------------------------------------------------------------ 墙
func _cube_pos(c: Vector2i) -> Vector2:
	return view.cell_screen(c)


func _add_wall(c: Vector2i, animate: bool) -> void:
	if not occ.has(c):
		var o := LightOccluder2D.new()
		o.occluder = OccluderPolygon2D.new()
		occluders.add_child(o)
		occ[c] = o
		_shape_occluder(o, c)
	if claimed.has(c) or cubes.has(c):
		return
	var s := Sprite2D.new()
	s.add_to_group(IsoView.SCREEN_GROUP)
	s.texture = _wall_tex
	s.light_mask = IsoView.STAND_LIGHT
	s.centered = false
	s.region_enabled = true
	var size := theme.cube_size()
	s.region_rect = Rect2(_variant(c) * size.x, 0, size.x, size.y)
	s.offset = -Vector2(16, 8 + theme.wall_height)
	s.position = _cube_pos(c)
	entities.add_child(s)
	cubes[c] = s
	if animate:
		s.modulate.a = 0.0
		s.create_tween().tween_property(s, "modulate:a", 1.0, 0.25)


func _remove_wall(c: Vector2i) -> void:
	if cubes.has(c):
		(cubes[c] as Node).queue_free()
		cubes.erase(c)
	if occ.has(c):
		(occ[c] as Node).queue_free()
		occ.erase(c)


func _variant(c: Vector2i) -> int:
	var h := posmod(c.x * 73856093 ^ c.y * 19349663, 100)
	if h < 8:
		return 2     # 苔藓
	if h < 20:
		return 1     # 裂缝
	if h < 45:
		return 3
	return 0


func _shape_occluder(o: LightOccluder2D, c: Vector2i) -> void:
	var p := Vector2(c) * IsoView.CELL
	var cs := IsoView.CELL
	o.occluder.polygon = PackedVector2Array([view.project(p), view.project(p + Vector2(cs, 0)),
		view.project(p + Vector2(cs, cs)), view.project(p + Vector2(0, cs))])


func claim(c: Vector2i, by: Node) -> void:
	claimed[c] = by
	if cubes.has(c):
		(cubes[c] as Node).queue_free()
		cubes.erase(c)
	_dirty = true


func release(c: Vector2i) -> void:
	claimed.erase(c)
	_dirty = true


func _sync_walls() -> void:
	var forced := _dirty
	_dirty = false
	if walls_src == null:
		return
	var now := {}
	var changed := false
	for c in walls_src.get_used_cells():
		now[c] = true
		if not occ.has(c) or (not cubes.has(c) and not claimed.has(c)):
			_add_wall(c, true)
			changed = true
	for c in occ.keys():
		if not now.has(c):
			_remove_wall(c)
			changed = true
	if changed or forced:
		_place_floor()


# ------------------------------------------------------------------ 前景淡化
func _process(delta: float) -> void:
	_poll_t += delta
	if _dirty or _poll_t >= POLL:
		_poll_t = 0.0
		_sync_walls()
	var p := _focus()
	var targets := {}
	if is_instance_valid(p) and host.is_ancestor_of(p):
		var pc := Vector2i((p.global_position / IsoView.CELL).floor())
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var c := pc + Vector2i(dx, dy)
				if cubes.has(c) and should_fade((cubes[c] as Node2D).position):
					targets[c] = true
	for c in targets:
		_faded[c] = true
	for c in _faded.keys():
		if not cubes.has(c):
			_faded.erase(c)
			continue
		var s := cubes[c] as Sprite2D
		var to := theme.fade_alpha if targets.has(c) else 1.0
		s.modulate.a = move_toward(s.modulate.a, to, delta * FADE_SPEED)
		if not targets.has(c) and s.modulate.a >= 1.0:
			_faded.erase(c)


## 屏幕位置 at 的墙块（格子中心）挡不挡主角：在她前面（屏幕 y 更大）、横向和她的身体重叠、墙顶高过她的脚。
func should_fade(at: Vector2) -> bool:
	var p := _focus()
	if not is_instance_valid(p) or not p.is_inside_tree():
		return false
	var ps := view.screen_pos(p)
	return at.y > ps.y + 1.0 and absf(at.x - ps.x) < 22.0 and at.y - ps.y < theme.wall_height + 14.0


func _focus() -> Node2D:
	return focus if is_instance_valid(focus) else GameState.player as Node2D


## 这一格有没有方块墙（自己画的或别人认领的）。
func has_wall_visual(c: Vector2i) -> bool:
	return cubes.has(c) or claimed.has(c)
