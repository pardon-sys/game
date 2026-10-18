extends Node2D
## 受罚转盘的盘面（PenanceRoulette 用）：四格扇形 + 刑具名字，正上方一个固定的指针（指针画在父节点坐标里，不跟着转）。

func _draw() -> void:
	var devices: Array = PenanceRoulette.DEVICES
	var seg := TAU / devices.size()
	var r := PenanceRoulette.R
	for i in devices.size():
		var a0 := i * seg
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in 17:
			pts.append(Vector2.from_angle(a0 + seg * k / 16.0) * r)
		draw_colored_polygon(pts, PenanceRoulette.COLORS[i])
		draw_line(Vector2.ZERO, Vector2.from_angle(a0) * r, Color(0.2, 0.1, 0.2), 2.0)
		var mid := Vector2.from_angle(a0 + seg * 0.5) * r * 0.6
		var font := ThemeDB.fallback_font
		var text := str(devices[i][1])
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		draw_set_transform(mid, a0 + seg * 0.5 + PI / 2.0)
		draw_string(font, Vector2(-size.x / 2.0, 4), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.18, 0.08, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.25, 0.12, 0.2), 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color(1, 0.86, 0.4))


func _process(_delta: float) -> void:
	# 指针：画在盘面外面正上方（抵消自己的旋转）
	queue_redraw()
	var p := get_parent().get_node_or_null("Pointer") as Polygon2D
	if p == null:
		p = Polygon2D.new()
		p.name = "Pointer"
		p.color = Color(1, 0.95, 0.95)
		p.polygon = PackedVector2Array([Vector2(-7, -PenanceRoulette.R - 12), Vector2(7, -PenanceRoulette.R - 12), Vector2(0, -PenanceRoulette.R + 6)])
		p.position = position
		get_parent().add_child.call_deferred(p)
