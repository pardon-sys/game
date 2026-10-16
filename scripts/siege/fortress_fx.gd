extends RefCounted
## 独立于伤害的童趣像素爆发；每个事件一次生成，播完释放，清场统一回收。
static var _ink: CanvasItemMaterial

static func ink() -> CanvasItemMaterial:
	if _ink == null:
		_ink = CanvasItemMaterial.new()
		_ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _ink

static func play(parent: Node, at: Vector2, radius: float, kind: String) -> Burst:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return null
	var effect := Burst.new()
	effect.kind = kind
	effect.radius = radius
	effect.life = 0.45 if kind == "launch" else (1.05 if kind == "cannon" else 0.85)
	effect.z_index = 24
	# 发光的火花／尾焰不被地牢的CanvasModulate压暗。
	effect.material = ink()
	effect.add_to_group("siege_temp")
	effect.add_to_group("fortress_skill_fx")
	parent.add_child(effect)
	effect.global_position = at
	return effect


class Burst extends Node2D:
	var kind := "rockets"
	var radius := 48.0
	var life := 0.85
	var elapsed := 0.0

	func _process(delta: float) -> void:
		if SiegeTools.paused(): return
		elapsed += delta
		if elapsed >= life:
			queue_free()
		else:
			queue_redraw()

	func _star(at: Vector2, size: float, color: Color, angle: float) -> void:
		var points := PackedVector2Array()
		for i in 10:
			points.append((at+Vector2.from_angle(angle+i*PI/5.0)*size*(1.0 if i%2==0 else 0.42)).round())
		draw_colored_polygon(points,color)

	func _draw() -> void:
		var f := clampf(elapsed/life,0.0,1.0)
		var fade := 1.0-f
		var col := Color(1,0.55,0.18)
		match kind:
			"rockets": col = Color(0.4,0.9,1)
			"cannon", "recoil": col = Color(1,0.35,0.3)
			"hands": col = Color(1,0.5,0.8)
			"rescue": col = Color(0.4,1,0.8)
			"crane": col = Color(0.8,0.6,1)
		var reach := radius*(0.2+0.95*(1.0-pow(1.0-f,3)))
		# 扁平冲击圈与白亮内圈，清楚标出接触地面的瞬间。
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.55))
		draw_arc(Vector2.ZERO,reach,0,TAU,32,Color(col,fade),4)
		draw_arc(Vector2.ZERO,reach*0.7,0,TAU,24,Color(1,0.95,0.7,fade*0.8),2)
		draw_set_transform(Vector2.ZERO)
		# 方块烟团向两侧翻卷；重炮有更高、更厚的烟云。
		for i in 7:
			var a := PI+i*PI/6.0
			var p := (Vector2.from_angle(a)*reach*0.7+Vector2(0,-f*radius*(0.8 if kind=="cannon" else 0.35))).round()
			var side := roundf(radius*(0.15+f*0.16)*(1.0-f*0.5))
			draw_rect(Rect2(p-Vector2.ONE*side,Vector2.ONE*side*2),Color(0.75,0.66,0.83,fade*0.55))
		# 爆心星芒、橙黄火花和彩纸；不增加命中或碰撞体。
		if f<0.45:
			_star(Vector2(0,-8),radius*(0.7-f),Color(1,0.96,0.75,1.0-f*2),-PI/2)
		for i in 12:
			var a := i*TAU/12.0-PI/2
			var p := (Vector2.from_angle(a)*reach+Vector2(0,35*f*f-12*f)).round()
			if i%3==0:
				_star(p,5+radius*0.04,Color(col,fade),a+f*2)
			else:
				draw_rect(Rect2(p,Vector2(4,7) if i%2 else Vector2(6,3)),Color(Color(1,0.8,0.25) if i%2 else col,fade))
