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
