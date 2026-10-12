class_name SiegeFx
extends RefCounted
## 攻防战的小特效（Godot 内置绘制 + Tween，不用图）：预警圈 / 预警线、冰锥落下、冰光束……


## 地上的圆圈（预警 / 法术范围），time 秒后淡出删掉。
static func ring(parent: Node, at: Vector2, r: float, col: Color, time := 0.6, fill := 0.18) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var n := Ring.new()
	n.radius = r
	n.color = col
	n.fill = fill
	n.z_index = -1
	n.add_to_group("siege_temp")
	parent.add_child(n)
	n.global_position = at
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, time).set_delay(time * 0.4)
	tw.tween_callback(n.queue_free)
	return n


## 地上的预警线（攻城车的路线、扫帚扫过的走道）：from → to，宽 w，time 秒。
static func lane(parent: Node, from: Vector2, to: Vector2, w: float, col: Color, time := 1.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var l := Line2D.new()
	l.width = w
	l.default_color = Color(col.r, col.g, col.b, 0.35)
	l.points = PackedVector2Array([from, to])
	l.z_index = -1
	l.add_to_group("siege_temp")
	l.add_to_group("siege_lane")
	parent.add_child(l)
	l.global_position = Vector2.ZERO
	var tw := l.create_tween().set_loops(int(time / 0.3))
	tw.tween_property(l, "modulate:a", 0.4, 0.15)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	l.get_tree().create_timer(time).timeout.connect(l.queue_free)
	return l


## 一根冰锥从上面落下、碎成冰屑。
static func icicle(parent: Node, at: Vector2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-2, -10), Vector2(2, -10), Vector2(0, 0)])
	p.color = Color(0.8, 0.94, 1.0)
	p.z_index = 25
	parent.add_child(p)
	p.global_position = at + Vector2(0, -60)
	var tw := p.create_tween()
	tw.tween_property(p, "global_position", at, randf_range(0.12, 0.22)).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Fx.burst(parent, at, "crystal", 4, 30.0, 0.35, Vector2(0, 40), Color(0.8, 0.94, 1.0))
		p.queue_free())


## 一道光束（造冰塔：城墙上的蓝色公主 → 冰塔格），time 秒，期间闪烁。
static func beam(parent: Node, from: Vector2, to: Vector2, col: Color, time: float, w := 3.0) -> Line2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var l := Line2D.new()
	l.width = w
	l.default_color = col
	l.points = PackedVector2Array([from, to])
	l.z_index = 30
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = mat
	parent.add_child(l)
	l.global_position = Vector2.ZERO
	var tw := l.create_tween().set_loops(maxi(1, int(time / 0.2)))
	tw.tween_property(l, "width", w * 1.8, 0.1)
	tw.tween_property(l, "width", w, 0.1)
	l.get_tree().create_timer(time).timeout.connect(l.queue_free)
	return l


## 屏幕震动（当前镜头的 offset 抖几下再回来）。
static func screen_shake(node: Node, strength := 3.0, time := 0.35) -> void:
	# 操控的人自己的镜头：交给她（她每帧会重设 offset）
	var pc := GameState.player
	if pc and is_instance_valid(pc) and pc.has_method("shake_camera"):
		pc.shake_camera(time, strength)
		return
	var cam := node.get_viewport().get_camera_2d() if node and node.is_inside_tree() else null
	if cam == null:
		return
	var base := cam.offset
	var tw := cam.create_tween()
	var steps := maxi(2, int(time / 0.04))
	for i in steps:
		var f := 1.0 - float(i) / steps
		tw.tween_property(cam, "offset", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * f, 0.04)
	tw.tween_property(cam, "offset", base, 0.04)


## 地面预警（Boss 技能、敌塔蓄力……）：kind = circle / sector / shadow；time 秒内从里往外填满，到点后消失。
## sector：angle 朝向、arc 张角（弧度）。shadow：落点影子，越来越大越来越黑（跳劈、空投）。返回预警节点。
static func warn(parent: Node, at: Vector2, kind: String, r: float, time: float, col: Color, angle := 0.0, arc := 1.2) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var n := Warn.new()
	n.kind = kind
	n.radius = r
	n.time = time
	n.color = col
	n.angle = angle
	n.arc = arc
	n.z_index = -1
	n.add_to_group("siege_temp")
	parent.add_child(n)
	n.global_position = at
	return n


## 重击落地：冲击波环（扩散）+ 碎石 + 尘土 + 裂纹；strong 时再加震屏和顿帧。
static func impact(parent: Node, at: Vector2, r: float, strong := true, col := Color(1, 0.85, 0.6)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var ringn := ring(parent, at, r * 0.25, Color(col.r, col.g, col.b, 0.95), 0.5, 0.12)
	if ringn:
		ringn.create_tween().tween_property(ringn, "scale", Vector2(4.0, 2.6), 0.45).set_ease(Tween.EASE_OUT)
	var ring2 := ring(parent, at, r * 0.15, Color(1, 1, 1, 0.8), 0.35, 0.0)
	if ring2:
		ring2.create_tween().tween_property(ring2, "scale", Vector2(5.0, 3.2), 0.3)
	Fx.burst(parent, at + Vector2(0, -4), "rock", 18 if strong else 8, r * 1.2, 0.8, Vector2(0, 160), Color(0.85, 0.78, 0.7))
	Fx.burst(parent, at + Vector2(0, -6), "dust", 26 if strong else 10, r, 0.9, Vector2(0, 30), Color(0.85, 0.75, 0.65))
	var cr := Cracks.new()
	cr.radius = r * 0.8
	cr.z_index = -1
	cr.add_to_group("siege_temp")
	parent.add_child(cr)
	cr.global_position = at
	if strong:
		screen_shake(parent, 6.0, 0.5)
		hitstop(parent, 0.06)


## 顿帧：时间几乎停一下（real 秒），用来让命中有分量。
static func hitstop(node: Node, real := 0.06) -> void:
	if node == null or not node.is_inside_tree() or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	node.get_tree().create_timer(real, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## 从地里钻出来（出生动画）：土堆 + 裂缝 → 小人从地下往上冒（下半截先藏着），冒土块。期间 0.6 秒不行动、不受击。
## fly = true（会飞 / 幽灵）：从一团烟里淡入。
static func burrow(a: Node2D, fly := false) -> void:
	if a == null or not a.is_inside_tree():
		return
	var spr := a.get("sprite") as Sprite2D if a.get("sprite") else null
	var parent := a.get_parent()
	if a is Actor:
		(a as Actor).set_invulnerable(0.6)
	if a is Monster:
		var mm := a as Monster
		mm._stun_left = maxf(mm._stun_left, 0.6)
		mm.state = Monster.State.HURT
		mm.velocity = Vector2.ZERO
	a.set_meta("siege_spawning", true)
	a.get_tree().create_timer(0.6, false).timeout.connect(func():
		if is_instance_valid(a):
			a.set_meta("siege_spawning", false))
	if fly or spr == null:
		Fx.burst(parent, a.global_position + Vector2(0, -8), "steam", 10, 30.0, 0.6, Vector2(0, -10), Color(0.9, 0.85, 1.0, 0.8))
		if spr:
			spr.modulate.a = 0.0
			spr.create_tween().tween_property(spr, "modulate:a", 1.0, 0.5)
		return
	var mound := Mound.new()
	mound.add_to_group("siege_temp")
	parent.add_child(mound)
	mound.global_position = a.global_position
	Fx.burst(parent, a.global_position + Vector2(0, -2), "rock", 8, 45.0, 0.6, Vector2(0, 140), Color(0.6, 0.48, 0.4))
	Fx.burst(parent, a.global_position + Vector2(0, -3), "dust", 8, 30.0, 0.6, Vector2(0, 20), Color(0.7, 0.6, 0.5))
	if spr.region_enabled:
		# 图集区域：从上往下一点点露出来（下半截还在土里），底边一直贴着地面
		var full := spr.region_rect
		var base_off := spr.offset
		var wr: WeakRef = weakref(spr)
		var tw := spr.create_tween()
		tw.tween_method(func(v: float):
			var sp := wr.get_ref() as Sprite2D
			if sp == null:
				return
			var h := maxf(1.0, full.size.y * v)
			sp.region_rect = Rect2(full.position, Vector2(full.size.x, h))
			sp.offset = Vector2(base_off.x, base_off.y + (full.size.y - h) / 2.0 + (full.size.y - h) * 0.0), 0.1, 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			var sp := wr.get_ref() as Sprite2D
			if sp:
				sp.region_rect = full
				sp.offset = base_off)
	else:
		# 帧动画的图：从扁扁的一点长出来
		var sc := spr.scale
		spr.scale = Vector2(sc.x * 1.2, sc.y * 0.15)
		spr.create_tween().tween_property(spr, "scale", sc, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 镜头临时看向某处 time 秒（不暂停；Boss 出场等）。返回后镜头回到人物身上。
static func camera_peek(node: Node, at: Vector2, time := 1.6, zoom := 0.8) -> void:
	var cam := node.get_viewport().get_camera_2d() if node and node.is_inside_tree() else null
	if cam == null:
		return
	var saved := [cam.top_level, cam.position, cam.zoom, cam.position_smoothing_enabled, cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	# 起点要在改 top_level 之前取（改完 global_position 会变成相对坐标那个值 = 地图左上角）
	var from := cam.get_screen_center_position()
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.global_position = from
	cam.reset_smoothing()
	var tw := cam.create_tween()
	tw.tween_method(func(v: float):
		cam.global_position = from.lerp(at, v)
		cam.zoom = Vector2.ONE * lerpf(float(saved[2].x), zoom, v)
		cam.reset_smoothing(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(time)
	tw.tween_callback(func():
		if is_instance_valid(cam):
			cam.top_level = saved[0]
			cam.position = saved[1]
			cam.zoom = saved[2]
			cam.position_smoothing_enabled = saved[3]
			cam.limit_left = saved[4]
			cam.limit_top = saved[5]
			cam.limit_right = saved[6]
			cam.limit_bottom = saved[7]
			cam.reset_smoothing())


## 屏幕中间的大字（Boss 名字、「将军狂暴了！」）。
static func big_title(node: Node, text: String, col: Color, sub := "") -> void:
	if node == null or not node.is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 55
	node.get_tree().current_scene.add_child(layer) if node.get_tree().current_scene else node.add_child(layer)
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, 92)
	l.size = Vector2(480, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", 8)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(2.2, 2.2)
	layer.add_child(l)
	if sub != "":
		var l2 := Label.new()
		l2.text = sub
		l2.position = Vector2(0, 122)
		l2.size = Vector2(480, 16)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.add_theme_font_size_override("font_size", 10)
		l2.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
		l2.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.05))
		l2.add_theme_constant_override("outline_size", 4)
		layer.add_child(l2)
	var tw := layer.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


## 全屏闪一下颜色（狂暴、镇长的烟花……）。
static func screen_flash(node: Node, col: Color, time := 0.5) -> void:
	if node == null or not node.is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 54
	node.add_child(layer)
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(4000, 4000)
	r.position = Vector2(-1000, -1000)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	var tw := layer.create_tween()
	tw.tween_property(r, "color:a", 0.0, time)
	tw.tween_callback(layer.queue_free)


## 三来源组合的专属特效（在公主身上放）。
static func combo_fx(c: Node2D, kind: String) -> void:
	var parent := c.get_parent()
	var at := c.global_position + Vector2(0, -10)
	match kind:
		"vortex":
			for i in 3:
				Fx.burst(parent, at + Vector2(0, 8), "feather", 10, 60.0 + i * 20.0, 0.9, Vector2(0, -40), Color(1, 1, 1))
			ring(parent, c.global_position, 26.0, Color(1, 0.95, 0.8, 0.9), 0.8)
		"brush_flowers":
			for i in 8:
				var p := c.global_position + Vector2.from_angle(TAU * i / 8.0) * 14.0
				Fx.burst(parent, p, "bristle", 4, 30.0, 0.7, Vector2(0, -20), Color(1, 0.9, 0.6))
		"heart_fluff":
			Fx.burst(parent, at, "heart", 18, 70.0, 0.9, Vector2(0, -30), Color(1, 0.7, 0.88))
			Fx.burst(parent, at, "snow", 14, 50.0, 0.9, Vector2(0, -10), Color(1, 0.9, 0.95))
		"mark_trail":
			var e := Fx.emitter(c, "ember", 12, 0.8, {"offset": Vector2(0, -6), "color": Color(1, 0.35, 0.7)})
			if e:
				c.get_tree().create_timer(3.0).timeout.connect(e.queue_free)
		"purple_hands":
			for i in 6:
				Fx.burst(parent, at + Vector2(randf_range(-12, 12), randf_range(-4, 10)), "ember", 6, 40.0, 0.8, Vector2(0, -30), Color(0.75, 0.45, 1.0))
			ring(parent, c.global_position, 22.0, Color(0.7, 0.4, 1.0, 0.9), 0.9)
		"feather_storm":
			Fx.burst(parent, at, "feather", 30, 110.0, 1.0, Vector2(0, 60), Color(1, 1, 1))
			Fx.burst(parent, c.global_position, "dust", 14, 60.0, 0.6, Vector2(0, 30))
		"bell_ripple":
			for i in 3:
				var r := ring(parent, c.global_position, 18.0 + i * 16.0, Color(1, 0.9, 0.4, 0.8), 0.6 + i * 0.2, 0.05)
				if r:
					r.scale = Vector2.ONE * 0.4
					r.create_tween().tween_property(r, "scale", Vector2.ONE, 0.5 + i * 0.2)
			Audio.play("chime", -4.0, 0.05, 1.7)
		"wind_lines":
			for i in 10:
				var a := TAU * i / 10.0
				lane(parent, c.global_position + Vector2.from_angle(a) * 8.0, c.global_position + Vector2.from_angle(a + 0.6) * 30.0, 1.5,
					Color(0.9, 0.95, 1.0), 0.6)


class Ring extends Node2D:
	var radius := 24.0
	var color := Color.WHITE
	var fill := 0.18

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, color.a * fill))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, 1.5)


## 地面预警（warn 用）。
class Warn extends Node2D:
	var kind := "circle"
	var radius := 40.0
	var time := 1.0
	var color := Color(1, 0.3, 0.3)
	var angle := 0.0
	var arc := 1.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= time:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / time, 0.0, 1.0)
		var pulse := 0.6 + 0.4 * sin(_t * 18.0)
		match kind:
			"sector":
				var pts := PackedVector2Array([Vector2.ZERO])
				for i in 17:
					pts.append(Vector2.from_angle(angle - arc / 2.0 + arc * i / 16.0) * radius)
				draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.16))
				var pts2 := PackedVector2Array([Vector2.ZERO])
				for i in 17:
					pts2.append(Vector2.from_angle(angle - arc / 2.0 + arc * i / 16.0) * radius * k)
				draw_colored_polygon(pts2, Color(color.r, color.g, color.b, 0.32))
				draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(color.r, color.g, color.b, 0.9 * pulse), 1.5)
			"shadow":
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
				draw_circle(Vector2.ZERO, radius * (0.3 + 0.7 * k), Color(0.1, 0.02, 0.06, 0.25 + 0.4 * k))
				draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color.r, color.g, color.b, 0.8 * pulse), 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
				draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.14))
				draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.3))
				draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.9 * pulse), 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 地上的裂纹（impact 用），慢慢淡掉。
class Cracks extends Node2D:
	var radius := 40.0
	var _t := 0.0
	var _lines: Array = []

	func _ready() -> void:
		for i in 7:
			var a := TAU * i / 7.0 + randf_range(-0.3, 0.3)
			var pts := PackedVector2Array([Vector2.ZERO])
			var p := Vector2.ZERO
			for j in 4:
				p += Vector2.from_angle(a + randf_range(-0.5, 0.5)) * radius / 4.0
				pts.append(Vector2(p.x, p.y * 0.55))
			_lines.append(pts)

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = clampf(2.0 - _t / 1.5, 0.0, 1.0)
		if _t > 3.0:
			queue_free()

	func _draw() -> void:
		for pts in _lines:
			draw_polyline(pts, Color(0.18, 0.1, 0.1, 0.8), 1.5)


## 出生动画的土堆（burrow 用）：裂开的土 → 慢慢塌平。
class Mound extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 1.6:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.6 - _t, 0.0, 1.0)
		var h := 4.0 * clampf(1.0 - _t / 1.2, 0.2, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 10.0, Color(0.38, 0.27, 0.2, 0.8 * a))
		draw_circle(Vector2(0, -h), 7.0, Color(0.5, 0.36, 0.26, 0.9 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 4:
			var ang := TAU * i / 4.0 + 0.4
			draw_line(Vector2.ZERO, Vector2.from_angle(ang) * Vector2(12, 5), Color(0.15, 0.08, 0.06, 0.8 * a), 1.0)
