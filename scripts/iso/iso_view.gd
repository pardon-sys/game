class_name IsoView
extends Node
## 等距显示层（可复用；关卡头 style = iso 时 scripts/level.gd 自动挂上，别的场景也能 IsoView.attach(宿主)）：
##   玩法逻辑完全留在俯视方格坐标（碰撞、寻路、机关都不动），这里每帧把世界里的东西按当前视角「投影」成等距画面：
##     project(p) = ISO · R_k · (p − center)，ISO：x' = gx − gy、y' = (gx + gy)/2（一格 16 像素 → 32x16 菱形），R_k = 转 k×90°。
##   怎么投影：宿主、宿主下的纯容器（没挂脚本的 Node2D：Entities / FloorObjects / Triggers ……）的直接子节点是「投影根」，
##     每帧在 RenderingServer.frame_pre_draw 里改写它们的绘制变换（节点自己的 position 不变），整棵子树跟着走、保持直立；
##     y 排序跟着改写后的屏幕 y 走（技术验证过）。宿主里的图块层（Floor / Walls / Decor）隐藏，只留碰撞——画面由 IsoTerrain 画。
##   光 / 挡光 / 粒子：Light2D 的位置不受绘制变换影响，所以每盏光在屏幕空间有一个替身（属性每帧照抄，地上压成椭圆），原来的光不照任何东西；
##     LightOccluder2D 同理；粒子改成 local_coords，跟着投影根走。
##   镜头：每帧把 viewport.canvas_transform 设成以「当前镜头的逻辑中心」投影后为中心（缩放、抖动、过场 camera to= 都照旧）。
##   转镜头：rotate_view(±1)（默认 rotate_left / rotate_right 两个动作 = Z / X），约 0.3 秒暗下 → 换视角 → 亮起；过场、对话、CG 中不能转。
##     换视角时发 rotated(k)，IsoTerrain / IsoDirectional 等跟着重建。
##   自己在本地坐标里画「地面上的线 / 圈」的节点：用 IsoView.offset(逻辑偏移) 换成屏幕偏移、ground_scale() 画地面上的圆。
##   贴地的东西（水洼、裂纹、光斑）加进分组 iso_ground：投影时再纵向压一半。
##   屏幕空间的节点（地面层、墙块、光的替身……）放进分组 iso_screen，不会被当成投影根。
##   anchor(子节点, 逻辑偏移)：投影根下面的子节点要放在「逻辑上偏一点」的地方（比如门的根在格子底边、方块要画在格子中心）——
##     转了视角屏幕偏移会变，这里记下来，开场和每次转视角时自动换算。
## 静态：IsoView.current（没有就是 null）、enabled（宿主进树时就设好，子节点 _ready 里能用来选等距贴图）、
##   screen_dir(逻辑方向) / world_dir(屏幕方向) / offset() / canvas_pos(节点)——没有等距显示时原样返回，调用方不用判断。

signal rotated(k: int)

const SCREEN_GROUP := "iso_screen"
const ANCHOR_GROUP := "iso_anchor"
const DIRECTIONAL_GROUP := "iso_directional"
const GROUND_GROUP := "iso_ground"
const CELL := 16.0
const TURN_TIME := 0.3
const FADE_LAYER := 7
## 光照分层：地面（IsoFloor / 装饰）用第 1 层、接收阴影；立着的东西（墙块、人物、物件）用第 2 层、只吃光不吃阴影——
## 2D 阴影从墙的菱形底座往外投，立着的东西画在底座上方，否则会被身后的墙「挡住」变黑
const GROUND_LIGHT := 1
const STAND_LIGHT := 2

static var current: IsoView
## 宿主进树时（子节点 _ready 之前）就设好：等距贴图要不要换
static var enabled := false

## 视角 0~3
var k := 0
## 投影的中心（逻辑坐标，对齐格子角）
var center := Vector2.ZERO
var can_rotate := true
var host: Node2D
var containers: Array[Node] = []
var roots: Array[CanvasItem] = []
var _root_set := {}
var _lights := {}       # 原来的 Light2D -> 替身
var _occluders := {}    # 原来的 LightOccluder2D -> 替身
var light_squash := 0.5
var lights_layer: Node2D
var turning := false
var _fade: ColorRect
var _cam_center := Vector2.INF
var _cam_base := Vector2(0, -12)
var _cam_ref: Camera2D


static func of(n: Node) -> IsoView:
	return current


static func attach(h: Node2D, rotate := true) -> IsoView:
	var v := h.get_node_or_null("IsoView") as IsoView
	if v:
		return v
	v = IsoView.new()
	v.name = "IsoView"
	v.can_rotate = rotate
	v.host = h
	h.add_child(v)
	return v


# ------------------------------------------------------------------ 换算
static func rot(v: Vector2, n: int) -> Vector2:
	for i in posmod(n, 4):
		v = Vector2(-v.y, v.x)
	return v


## 逻辑方向 / 偏移 → 屏幕（不含中心平移）。
func linear(v: Vector2) -> Vector2:
	var r := rot(v, k)
	return Vector2(r.x - r.y, (r.x + r.y) * 0.5)


func unlinear(s: Vector2) -> Vector2:
	return rot(Vector2(s.y + s.x * 0.5, s.y - s.x * 0.5), -k)


func project(p: Vector2) -> Vector2:
	return linear(p - center)


func unproject(s: Vector2) -> Vector2:
	return unlinear(s) + center


## 格子 c 的中心投影到屏幕。
func cell_screen(c: Vector2i) -> Vector2:
	return project(Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5)


## 格子 c 在等距图块层（DIAMOND_DOWN，32x16）里的坐标。
func cell_to_iso_map(c: Vector2i) -> Vector2i:
	var cc := (center / CELL).round()
	var r := rot(Vector2(c) - cc + Vector2(0.5, 0.5), k) - Vector2(0.5, 0.5)
	return Vector2i(roundi(r.x), roundi(r.y))


static func screen_dir(v: Vector2) -> Vector2:
	return current.linear(v) if current else v


## 屏幕方向 → 逻辑方向（长度不变）。
static func world_dir(v: Vector2) -> Vector2:
	if current == null or v == Vector2.ZERO:
		return v
	return current.unlinear(v).normalized() * v.length()


static func offset(v: Vector2) -> Vector2:
	return current.linear(v) if current else v


## 子节点 n 放在相对投影根「逻辑偏移 v」的位置（转视角时自动跟着换算）。没有等距显示时直接放 v。
static func anchor(n: Node2D, v: Vector2) -> void:
	n.set_meta("iso_offset", v)
	n.add_to_group(ANCHOR_GROUP)
	n.position = offset(v)


func _apply_anchors() -> void:
	for n in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		if host.is_ancestor_of(n):
			(n as Node2D).position = linear(n.get_meta("iso_offset", Vector2.ZERO))
	for n in get_tree().get_nodes_in_group(DIRECTIONAL_GROUP):
		if host.is_ancestor_of(n):
			n.call("refresh")


## 地面上的圆在画面里的形状（draw_set_transform 的缩放）。
static func ground_scale() -> Vector2:
	return Vector2(sqrt(2.0), sqrt(2.0) * 0.5) if current else Vector2.ONE


## 世界节点在视口里的位置（UI 判断遮挡用）。
static func canvas_pos(n: Node2D) -> Vector2:
	if current == null or not current.is_inside_tree():
		return n.get_global_transform_with_canvas().origin
	return current.get_viewport().canvas_transform * current.screen_pos(n)


## 世界节点画在屏幕（画布）上的位置：投影根投影，子树里的节点 = 根的投影 + 相对根的偏移。
func screen_pos(n: Node2D) -> Vector2:
	var r := root_of(n)
	if r == null:
		return project(n.global_position)
	return project(r.global_position) + (n.global_position - r.global_position)


func root_of(n: Node) -> Node2D:
	var c := n
	while c and c != host:
		if _root_set.has(c):
			return c as Node2D
		c = c.get_parent()
	return null


# ------------------------------------------------------------------ 生命周期
func _enter_tree() -> void:
	current = self
	enabled = true
	if host == null:
		host = get_parent() as Node2D


func _ready() -> void:
	var floor_layer := host.get_node_or_null("Floor") as TileMapLayer
	if floor_layer:
		var r := floor_layer.get_used_rect()
		center = Vector2(r.position + r.size / 2) * CELL
	for c in host.get_children():
		if _is_container(c):
			containers.append(c)
	_scan(host)
	_apply_anchors()
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	lights_layer = Node2D.new()
	lights_layer.name = "IsoLights"
	lights_layer.add_to_group(SCREEN_GROUP)
	host.add_child.call_deferred(lights_layer)
	var cl := CanvasLayer.new()
	cl.layer = FADE_LAYER
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_fade)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	if current == self:
		current = null
		enabled = false


func _is_container(n: Node) -> bool:
	return n.get_class() == "Node2D" and n.get_script() == null and not n.is_in_group(SCREEN_GROUP)


func _scan(n: Node) -> void:
	for c in n.get_children():
		_consider(c)
		_scan(c)


func _on_node_added(n: Node) -> void:
	if host and host.is_ancestor_of(n):
		_consider(n)


func _consider(n: Node) -> void:
	if n.is_in_group(SCREEN_GROUP) or _in_screen_space(n):
		return
	var p := n.get_parent()
	if n is TileMapLayer and (p == host or containers.has(p)):
		_hide_tiles(n as TileMapLayer)
		return
	if n is Light2D:
		_mirror_light.call_deferred(n)
	elif n is LightOccluder2D:
		_mirror_occluder.call_deferred(n)
	elif n is CPUParticles2D:
		(n as CPUParticles2D).local_coords = true
	elif n is GPUParticles2D:
		(n as GPUParticles2D).local_coords = true
	if not (n is CanvasItem) or n is CanvasModulate or n is Light2D:
		return
	if p == host and _is_container(n):
		if not containers.has(n):
			containers.append(n)
		return
	if (p == host or containers.has(p)) and not _root_set.has(n):
		_root_set[n] = true
		roots.append(n as CanvasItem)
	if root_of(n) != null and not n.is_in_group(GROUND_GROUP):
		stand_lit(n as CanvasItem)


## 立着的东西：只吃光、不吃阴影（STAND_LIGHT）。
static func stand_lit(ci: CanvasItem) -> void:
	if ci.light_mask & GROUND_LIGHT:
		ci.light_mask = (ci.light_mask & ~GROUND_LIGHT) | STAND_LIGHT


func _in_screen_space(n: Node) -> bool:
	var c := n.get_parent()
	while c and c != host:
		if c.is_in_group(SCREEN_GROUP):
			return true
		c = c.get_parent()
	return false


func _hide_tiles(l: TileMapLayer) -> void:
	l.visible = false
	l.occlusion_enabled = false


# ------------------------------------------------------------------ 每帧
func _pre_draw() -> void:
	if not is_inside_tree():
		return
	var keep: Array[CanvasItem] = []
	for r in roots:
		if not is_instance_valid(r) or not r.is_inside_tree():
			_root_set.erase(r)
			continue
		keep.append(r)
		if not r.visible or not (r is Node2D):
			continue
		var n := r as Node2D
		var gt := n.global_transform
		var x := gt.x
		var y := gt.y
		if n.is_in_group(GROUND_GROUP):
			x.y *= 0.5
			y.y *= 0.5
		var screen := Transform2D(x, y, project(gt.origin))
		var parent := n.get_parent() as CanvasItem
		if parent and parent != null:
			screen = parent.get_global_transform().affine_inverse() * screen
		RenderingServer.canvas_item_set_transform(n.get_canvas_item(), screen)
	roots = keep
	_update_lights()
	_update_occluders()
	_apply_camera()


func _process(delta: float) -> void:
	_follow_camera(delta)
	if not can_rotate or turning:
		return
	if InputMap.has_action("rotate_left") and Input.is_action_just_pressed("rotate_left"):
		rotate_view(-1)
	elif InputMap.has_action("rotate_right") and Input.is_action_just_pressed("rotate_right"):
		rotate_view(1)


# ------------------------------------------------------------------ 光 / 挡光的替身
func _mirror_light(l) -> void:
	if not is_instance_valid(l) or _lights.has(l) or not (l is PointLight2D) or lights_layer == null:
		return
	var p := PointLight2D.new()
	p.add_to_group(SCREEN_GROUP)
	l.set_meta("iso_mask", l.range_item_cull_mask)
	l.range_item_cull_mask = 0
	if not lights_layer.is_inside_tree():
		await lights_layer.tree_entered
	lights_layer.add_child(p)
	_lights[l] = p


func _update_lights() -> void:
	for l in _lights.keys():
		var p: PointLight2D = _lights[l]
		if not is_instance_valid(l) or not l.is_inside_tree():
			if is_instance_valid(p):
				p.queue_free()
			_lights.erase(l)
			continue
		var src := l as PointLight2D
		if src.range_item_cull_mask != 0:
			src.set_meta("iso_mask", src.range_item_cull_mask)
			src.range_item_cull_mask = 0
		p.enabled = src.enabled and src.is_visible_in_tree()
		p.texture = src.texture
		p.texture_scale = src.texture_scale
		p.offset = src.offset
		p.color = src.color
		p.energy = src.energy
		p.height = src.height
		p.blend_mode = src.blend_mode
		p.shadow_enabled = src.shadow_enabled
		p.shadow_color = src.shadow_color
		p.shadow_filter = src.shadow_filter
		p.shadow_filter_smooth = src.shadow_filter_smooth
		p.shadow_item_cull_mask = GROUND_LIGHT
		p.range_z_min = src.range_z_min
		p.range_z_max = src.range_z_max
		p.range_layer_min = src.range_layer_min
		p.range_layer_max = src.range_layer_max
		var mask := int(src.get_meta("iso_mask", 1))
		p.range_item_cull_mask = mask | STAND_LIGHT if mask & GROUND_LIGHT else mask
		p.global_position = screen_pos(src)
		p.global_rotation = 0.0
		p.global_scale = src.global_scale.abs() * Vector2(1.0, light_squash)


func _mirror_occluder(o) -> void:
	if not is_instance_valid(o) or _occluders.has(o) or lights_layer == null:
		return
	var p := LightOccluder2D.new()
	p.add_to_group(SCREEN_GROUP)
	p.occluder = OccluderPolygon2D.new()
	o.set_meta("iso_mask", o.occluder_light_mask)
	o.occluder_light_mask = 0
	if not lights_layer.is_inside_tree():
		await lights_layer.tree_entered
	lights_layer.add_child(p)
	_occluders[o] = p


func _update_occluders() -> void:
	for o in _occluders.keys():
		var p: LightOccluder2D = _occluders[o]
		if not is_instance_valid(o) or not o.is_inside_tree():
			if is_instance_valid(p):
				p.queue_free()
			_occluders.erase(o)
			continue
		var src := o as LightOccluder2D
		if src.occluder_light_mask != 0:
			src.set_meta("iso_mask", src.occluder_light_mask)
			src.occluder_light_mask = 0
		p.visible = src.is_visible_in_tree() and src.occluder != null
		p.occluder_light_mask = int(src.get_meta("iso_mask", 1))
		if src.occluder == null:
			continue
		var pts := PackedVector2Array()
		var gt := src.global_transform
		for v in src.occluder.polygon:
			pts.append(project(gt * v))
		p.occluder.polygon = pts
		p.occluder.closed = src.occluder.closed
		p.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED


# ------------------------------------------------------------------ 镜头
func _camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam != _cam_ref:
		_cam_ref = cam
		_cam_center = Vector2.INF
		if cam and cam.get_parent() is Node2D:
			_cam_base = Vector2(0, cam.position.y) if absf(cam.position.x) < 0.01 else Vector2.ZERO
	return cam


## 当前镜头在屏幕（画布）上的中心：逻辑位置投影 + 镜头本来的上抬（屏幕方向）+ 抖动。
func camera_target() -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.ZERO
	return project(cam.global_position - _cam_base) + _cam_base + cam.offset


func snap_camera() -> void:
	_cam_center = Vector2.INF


## 每帧（_process）算镜头中心：跟着目标平滑移动（镜头本来开了平滑就平滑），离得太远 / 刚转视角就直接跳过去。
func _follow_camera(dt: float) -> void:
	var cam := _camera()
	if cam == null:
		return
	var target := camera_target()
	if _cam_center == Vector2.INF or _cam_center.distance_to(target) > 200.0 or not cam.position_smoothing_enabled:
		_cam_center = target
	else:
		_cam_center = _cam_center.lerp(target, 1.0 - exp(-cam.position_smoothing_speed * dt))


## 画之前（frame_pre_draw）把镜头写进 canvas_transform：Camera2D 每帧也会写，这里最后写、以这里为准。
func _apply_camera() -> void:
	var cam := _camera()
	if cam == null:
		return
	if _cam_center == Vector2.INF:
		_follow_camera(0.0)
	var vp := get_viewport().get_visible_rect().size
	var z := cam.zoom
	get_viewport().canvas_transform = Transform2D(0.0, z, 0.0, (vp * 0.5 - _cam_center * z).round())


## 镜头中心（屏幕 / 画布坐标；测试用）。
func camera_center() -> Vector2:
	return _cam_center


# ------------------------------------------------------------------ 转镜头
func rotation_locked() -> bool:
	if Cutscene.is_playing() or Dialogue.is_active():
		return true
	return CG.is_playing()


## 转 dir 个 90°（+1 / −1）。instant = true 不要过渡（测试 / 读档）。
func rotate_view(dir: int, instant := false) -> bool:
	if turning or (not instant and rotation_locked()):
		return false
	if instant:
		set_view(k + dir)
		return true
	turning = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.85, TURN_TIME * 0.4)
	tw.tween_callback(func(): set_view(k + dir))
	tw.tween_property(_fade, "color:a", 0.0, TURN_TIME * 0.6)
	tw.tween_callback(func(): turning = false)
	Audio.play("lever", -14.0, 0.05, 1.6)
	return true


func set_view(n: int) -> void:
	k = posmod(n, 4)
	_apply_anchors()
	snap_camera()
	rotated.emit(k)


## 漏投影检查（测试用）：宿主下面所有看得见、又没有被投影的东西。
func unprojected_visible() -> Array[Node]:
	var out: Array[Node] = []
	_collect_unprojected(host, out)
	return out


func _collect_unprojected(n: Node, out: Array[Node]) -> void:
	for c in n.get_children():
		if c.is_in_group(SCREEN_GROUP) or _root_set.has(c) or c is CanvasLayer or c == self:
			continue
		if c is TileMapLayer:
			if (c as TileMapLayer).visible:
				out.append(c)
			continue
		if c is Light2D:
			if not _lights.has(c) and c is PointLight2D:
				out.append(c)
			continue
		if containers.has(c):
			_collect_unprojected(c, out)
			continue
		if c is CanvasItem and (c as CanvasItem).is_visible_in_tree() and not (c is CanvasModulate):
			out.append(c)
