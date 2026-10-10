extends Node
## 等距显示组件测试（scripts/iso/，不依赖第八层）：一个小场景（几面墙 + 一个主角 + 一盏灯 + 一个有朝向的物件 + 粒子 + 挡光），
## 检查投影往返、四个视角、墙块 / 地面 / 挡光重建、漏投影、转镜头按键和朝向、走廊辅助、前景淡化、镜头、离开后静态状态复原。
## 用法：Godot --headless --path . res://tests/iso_view_test.tscn   （退出码 0 = 全部通过）

const MAP := [
	"#########",
	"#...#...#",
	"#.#.#.#.#",
	"#.#...#.#",
	"#.#####.#",
	"#.......#",
	"#########",
]

var failures := 0
var host: Node2D
var floor_l: TileMapLayer
var walls: TileMapLayer
var ents: Node2D
var body: CharacterBody2D
var lamp: Node2D
var arrow: Sprite2D
var view: IsoView
var terrain: IsoTerrain


func _ready() -> void:
	TutorialBoard.enabled = false
	_build()
	view = IsoView.attach(host)
	terrain = IsoTerrain.attach(view, IsoTheme.named("blue_stone"))
	terrain.focus = body
	await _frames(3)
	_run_projection()
	await _run_terrain()
	_run_leaks()
	await _run_rotation()
	await _run_mover()
	await _run_fade()
	await _run_cleanup()
	print("==== %s ====" % ("全部通过" if failures == 0 else "有失败 (%d 项失败)" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _build() -> void:
	host = Node2D.new()
	host.name = "IsoTestLevel"
	add_child(host)
	var ts: TileSet = load("res://assets/tilesets/dungeon_25d.tres")
	floor_l = TileMapLayer.new()
	floor_l.name = "Floor"
	floor_l.tile_set = ts
	walls = TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	host.add_child(floor_l)
	host.add_child(walls)
	for y in MAP.size():
		for x in MAP[y].length():
			if MAP[y][x] == "#":
				walls.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			else:
				floor_l.set_cell(Vector2i(x, y), 0, Vector2i(0, 4))
	var fo := Node2D.new()
	fo.name = "FloorObjects"
	host.add_child(fo)
	ents = Node2D.new()
	ents.name = "Entities"
	ents.y_sort_enabled = true
	host.add_child(ents)
	# 主角：碰撞 + 精灵 + 光 + 镜头
	body = CharacterBody2D.new()
	body.name = "Hero"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	body.add_child(shape)
	var sp := Sprite2D.new()
	sp.name = "Sprite"
	sp.texture = _tex(12, 20, Color.WHITE)
	sp.offset = Vector2(0, -10)
	body.add_child(sp)
	var light := PointLight2D.new()
	light.name = "Light"
	light.texture = _tex(64, 64, Color.WHITE)
	light.position = Vector2(0, -10)
	body.add_child(light)
	var cam := Camera2D.new()
	cam.position = Vector2(0, -12)
	body.add_child(cam)
	ents.add_child(body)
	body.global_position = _center(Vector2i(1, 5))
	cam.make_current()
	# 一盏灯（自己是投影根，带挡光和粒子）
	lamp = Node2D.new()
	lamp.name = "Lamp"
	var ll := PointLight2D.new()
	ll.texture = _tex(64, 64, Color.WHITE)
	lamp.add_child(ll)
	var occ := LightOccluder2D.new()
	occ.occluder = OccluderPolygon2D.new()
	occ.occluder.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	lamp.add_child(occ)
	var parts := CPUParticles2D.new()
	parts.local_coords = false
	lamp.add_child(parts)
	ents.add_child(lamp)
	lamp.global_position = _center(Vector2i(3, 3))
	# 有朝向的物件
	var post := Node2D.new()
	post.name = "Post"
	arrow = Sprite2D.new()
	arrow.texture = _tex(16, 4, Color.RED)
	arrow.hframes = 4
	post.add_child(arrow)
	fo.add_child(post)
	post.global_position = _center(Vector2i(5, 1))
	IsoDirectional.add_to(arrow, "dir4", Vector2.RIGHT)


func _tex(w: int, h: int, c: Color) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(c)
	return ImageTexture.create_from_image(im)


func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16 + 8, c.y * 16 + 12)


# ------------------------------------------------------------------
func _run_projection() -> void:
	print("-- 投影")
	var ok := true
	var k0 := view.k
	for kk in 4:
		view.k = kk
		for p in [Vector2(3, 7), Vector2(120, -40), Vector2(-77, 333)]:
			if view.unproject(view.project(p)).distance_to(p) > 0.01:
				ok = false
			var d: Vector2 = p.normalized()
			if IsoView.world_dir(IsoView.screen_dir(d)).normalized().distance_to(d) > 0.01:
				ok = false
	view.k = k0
	var cell_ok := view.linear(Vector2(16, 0)) == Vector2(16, 8) and view.linear(Vector2(0, 16)) == Vector2(-16, 8)
	check("四个视角投影 / 方向换算都可逆（%s），一格 = 32x16 菱形（%s）" % [ok, cell_ok], ok and cell_ok)


func _run_terrain() -> void:
	print("-- 地形")
	var missing := 0
	var misplaced := 0
	for c in walls.get_used_cells():
		if not terrain.cubes.has(c):
			missing += 1
		elif (terrain.cubes[c] as Node2D).position.distance_to(view.cell_screen(c)) > 0.5:
			misplaced += 1
	var floors := floor_l.get_used_cells().size()
	var iso_floors := terrain.floor_layer.get_used_cells().size()
	var aligned := terrain.floor_layer.position + terrain.floor_layer.map_to_local(view.cell_to_iso_map(Vector2i(2, 1))) \
		== view.cell_screen(Vector2i(2, 1))
	check("每个墙格一个方块墙（缺 %d、错位 %d），地面格 %d = 逻辑地面格 %d，等距图块层和投影对齐（%s），逻辑图层隐藏（%s），挡光 %d 块" % [
			missing, misplaced, iso_floors, floors, aligned, not walls.visible, terrain.occ.size()],
		missing == 0 and misplaced == 0 and iso_floors == floors and aligned and not walls.visible and not floor_l.visible
		and walls.collision_enabled and terrain.occ.size() == walls.get_used_cells().size())
	# 运行时改墙：升起一格 → 下一帧补上方块；拿掉 → 方块消失
	walls.set_cell(Vector2i(3, 1), 1, Vector2i(0, 0))
	await _wait(IsoTerrain.POLL + 0.05)
	var added := terrain.cubes.has(Vector2i(3, 1))
	walls.erase_cell(Vector2i(3, 1))
	await _wait(IsoTerrain.POLL + 0.05)
	var removed := not terrain.cubes.has(Vector2i(3, 1)) and not terrain.occ.has(Vector2i(3, 1))
	# 认领：别人画的墙格不放方块
	var owner := Node2D.new()
	terrain.claim(Vector2i(4, 2), owner)
	var claimed := not terrain.cubes.has(Vector2i(4, 2)) and terrain.has_wall_visual(Vector2i(4, 2))
	terrain.release(Vector2i(4, 2))
	await _frames(2)
	var released := terrain.cubes.has(Vector2i(4, 2))
	owner.free()
	check("Walls 变了自动补 / 拿方块（%s / %s），认领的墙格不放方块（%s），还回来又有（%s）" % [added, removed, claimed, released],
		added and removed and claimed and released)


func _run_leaks() -> void:
	print("-- 漏投影 / 光 / 粒子")
	var leaks := view.unprojected_visible()
	var light: PointLight2D = body.get_node("Light")
	var proxy: PointLight2D = view._lights.get(light)
	var parts := lamp.get_child(2) as CPUParticles2D
	view._pre_draw()
	check("看得见的东西都投影了（漏 %d 个 %s），光有屏幕空间的替身（原来的不照东西），粒子改成跟着走，挡光有替身" % [leaks.size(), leaks],
		leaks.is_empty() and proxy != null and light.range_item_cull_mask == 0
		and proxy.global_position.distance_to(view.screen_pos(light)) < 0.5 and parts.local_coords
		and view._occluders.size() == 1 and absf(proxy.global_scale.y / proxy.global_scale.x - terrain.theme.light_squash) < 0.01)


func _run_rotation() -> void:
	print("-- 转镜头")
	var k0 := view.k
	var got := []
	view.rotated.connect(func(k): got.append(k))
	await get_tree().process_frame   # 在这一帧的 _process 之前按下（真按键也是这样）
	Input.action_press("rotate_right")
	await _frames(2)
	Input.action_release("rotate_right")
	await _wait(IsoView.TURN_TIME + 0.2)
	var cube_c: Vector2i = terrain.cubes.keys()[0]
	var cube_ok := (terrain.cubes[cube_c] as Node2D).position.distance_to(view.cell_screen(cube_c)) < 0.5
	var c2 := Vector2i(2, 1)
	var tile_ok := terrain.floor_layer.get_cell_source_id(view.cell_to_iso_map(c2)) != -1 \
		and terrain.floor_layer.get_cell_atlas_coords(view.cell_to_iso_map(c2)).y == view.k
	var arrow_ok := arrow.frame == IsoDirectional.frame_for(Vector2.RIGHT)
	var cam_ok := view.camera_center().distance_to(view.camera_target()) < 2.0
	var up := IsoView.world_dir(Vector2.UP)
	check("按 X：视角 %d → %d（信号 %s），墙块 / 地面重排（%s / %s），朝向帧跟着变（%s），镜头跟着（%s），屏幕「上」= 逻辑 %s" % [
			k0, view.k, got, cube_ok, tile_ok, arrow_ok, cam_ok, up.round()],
		view.k == posmod(k0 + 1, 4) and got == [view.k] and cube_ok and tile_ok and arrow_ok and cam_ok
		and up.distance_to(view.unlinear(Vector2.UP).normalized()) < 0.01)
	await get_tree().process_frame
	Input.action_press("rotate_left")
	await _frames(1)
	await _frames(1)
	Input.action_release("rotate_left")
	await _wait(IsoView.TURN_TIME + 0.2)
	check("按 Z 转回来（视角 %d）" % view.k, view.k == k0)
	# 过场中不能转
	var dummy_locked := view.rotation_locked()
	check("没有过场 / 对话时能转（锁 %s）" % dummy_locked, not dummy_locked)


func _run_mover() -> void:
	print("-- 移动")
	# 底下那条横走廊（y = 5）：只按屏幕「右」，逻辑上斜着（右上），被上面的墙挡住 → 顺着走廊往右走，速度不打折
	body.global_position = _center(Vector2i(2, 5))
	await _frames(2)
	var v := IsoMover.from_screen(body, Vector2.RIGHT)
	var start := body.global_position
	for i in 20:
		body.velocity = IsoMover.from_screen(body, Vector2.RIGHT) * 60.0
		body.move_and_slide()
		await get_tree().physics_frame
	var moved := body.global_position - start
	check("走廊辅助：只按「右」，沿 1 格走廊往右走（方向 %s，走了 %s）" % [v.round(), moved.round()],
		absf(v.y) < 0.01 and v.x > 0.99 and moved.x > 12.0 and absf(moved.y) < 2.0)
	var open := IsoMover.assist(body, Vector2(0.7, 0.7))
	check("两个方向都通 / 都不通时不改方向（%s）" % open, open.is_equal_approx(Vector2(0.7, 0.7)) or open.length() > 0.98)


func _run_fade() -> void:
	print("-- 前景淡化")
	# 站在 (5,3)：(5,4) 是墙、在她屏幕前方
	body.global_position = _center(Vector2i(5, 3))
	await _wait(0.5)
	var s := terrain.cubes[Vector2i(5, 4)] as Sprite2D
	var faded := s.modulate.a
	body.global_position = _center(Vector2i(1, 1))
	await _wait(0.5)
	check("挡住她的墙淡到 %.2f，走开后回到 %.2f" % [faded, s.modulate.a], faded < 0.6 and s.modulate.a > 0.95)


func _run_cleanup() -> void:
	print("-- 复原")
	host.queue_free()
	await _frames(2)
	check("宿主离开后静态状态复原（current %s、enabled %s），没有等距时换算原样返回" % [IsoView.current, IsoView.enabled],
		IsoView.current == null and not IsoView.enabled and IsoView.screen_dir(Vector2(1, 2)) == Vector2(1, 2)
		and IsoView.world_dir(Vector2(0, -1)) == Vector2(0, -1))


# ------------------------------------------------------------------
func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
