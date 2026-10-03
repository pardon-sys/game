class_name TrapFx
extends RefCounted
## 训练营新陷阱（LegTrap 的子类）的专属特效，全部用 Godot 内置的 Line2D / CPUParticles2D / tween 现场画，播完自动删除。
##   snap(parent, pos, cross)        「咔」夹合闪光：十字（夹腿羽毛钳）或交叉的 X（剪刀刷台）
##   feather_puff(parent, pos)       羽毛飘散
##   arc_trail(parent, center, r, a0, a1)  一道淡淡的弧形轨迹（羽毛秋千摆动）
##   stroke(parent, pos, dir)        刷痕：一道短短的弧线扫过（刑架 / 骑马刷凳换部位）
##   speed_lines(parent, pos)        速度线：几条短线向外飞（挣扎变快）
##   boing(parent, pos)              「嘣」：扩散的圆环 + 尘土（弹簧刷座弹起）
##   BristleRing                     绕腿旋转的刷毛光环（大腿刷环，speed 跟着挠的间隔变快）

const Z := 8
const WHITE := Color(1, 0.98, 1, 0.95)


static func _line(parent: Node, points: PackedVector2Array, width: float, col: Color, nm := "") -> Line2D:
	var l := Line2D.new()
	if nm != "":
		l.name = nm
	l.points = points
	l.width = width
	l.default_color = col
	l.z_index = Z
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)
	return l


static func _fade(n: CanvasItem, time: float, grow := 1.0) -> void:
	var tw := n.create_tween().set_parallel()
	tw.tween_property(n, "modulate:a", 0.0, time)
	if grow != 1.0:
		tw.tween_property(n, "scale", Vector2.ONE * grow, time)
	tw.chain().tween_callback(n.queue_free)


static func _ok(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree()


## 「咔」：中心一个小白点 + 四道（或交叉两道）短线，0.18 秒放大淡出。
static func snap(parent: Node, pos: Vector2, cross := false, size := 6.0) -> Node2D:
	if not _ok(parent):
		return null
	var n := Node2D.new()
	n.name = "TrapSnap"
	n.z_index = Z
	parent.add_child(n)
	n.global_position = pos
	var dirs := [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)] if cross else [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	if cross:
		_line(n, PackedVector2Array([Vector2(-size, -size), Vector2(size, size)]), 1.5, WHITE)
		_line(n, PackedVector2Array([Vector2(size, -size), Vector2(-size, size)]), 1.5, WHITE)
	else:
		for d in dirs:
			_line(n, PackedVector2Array([d * 2.0, d * size]), 1.2, WHITE)
	_fade(n, 0.18, 1.6)
	return n


static func feather_puff(parent: Node, pos: Vector2, amount := 6) -> void:
	Fx.burst(parent, pos, "feather", amount, 34.0, 0.9, Vector2(0, 26))


## 弧形轨迹：圆心 center、半径 r，从角度 a0 到 a1（弧度，0 = 正下方，向右为正）。
static func arc_trail(parent: Node, center: Vector2, r: float, a0: float, a1: float) -> Line2D:
	if not _ok(parent):
		return null
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(center + Vector2(sin(a), cos(a)) * r)
	var l := _line(parent, pts, 1.0, Color(1, 0.95, 1, 0.45), "TrapArc")
	_fade(l, 0.45)
	return l


## 刷痕：pos 处一道朝 dir 扫过的短弧，带几根刷毛。
static func stroke(parent: Node, pos: Vector2, dir := Vector2.RIGHT) -> Line2D:
	if not _ok(parent):
		return null
	var side := dir.orthogonal() * 2.0
	var pts := PackedVector2Array([pos - dir * 6.0 + side, pos - dir * 2.0 - side * 0.5, pos + dir * 2.0 - side * 0.5, pos + dir * 6.0 + side])
	var l := _line(parent, pts, 1.5, Color(1, 0.86, 0.5, 0.85), "TrapStroke")
	Fx.burst(parent, pos, "bristle", 3, 24.0, 0.4, Vector2(0, 40))
	_fade(l, 0.3)
	return l


## 速度线：count 条短线从 pos 向外飞出。
static func speed_lines(parent: Node, pos: Vector2, count := 3) -> void:
	if not _ok(parent):
		return
	for i in count:
		var d := Vector2.from_angle(randf_range(-PI * 0.9, -PI * 0.1))
		var l := _line(parent, PackedVector2Array([Vector2.ZERO, d * 5.0]), 1.0, Color(1, 1, 1, 0.8), "TrapSpeed")
		l.global_position = pos + d * 6.0
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "global_position", pos + d * 16.0, 0.25)
		tw.tween_property(l, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(l.queue_free)


## 「嘣」：扩散的圆环 + 尘土。
static func boing(parent: Node, pos: Vector2, r := 6.0) -> Line2D:
	if not _ok(parent):
		return null
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.45))
	var l := _line(parent, pts, 1.0, Color(1, 0.9, 0.7, 0.9), "TrapBoing")
	l.global_position = pos
	_fade(l, 0.35, 2.2)
	Fx.burst(parent, pos, "dust", 5, 28.0, 0.45, Vector2(0, 30))
	return l


## 绕腿旋转的刷毛光环：count 根刷毛沿椭圆转，speed = 每秒几圈。
class BristleRing extends Node2D:
	var speed := 1.0
	var radius := Vector2(10, 4)
	var _a := 0.0
	var _bits: Array[Sprite2D] = []

	func _init(count := 10) -> void:
		name = "BristleRing"
		z_index = TrapFx.Z
		# 淡金色的环（刷毛沿着它转）
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
		ring.points = pts
		ring.width = 1.0
		ring.default_color = Color(1, 0.85, 0.45, 0.55)
		add_child(ring)
		for i in count:
			var s := Sprite2D.new()
			s.texture = Fx.PARTICLES["bristle"]
			add_child(s)
			_bits.append(s)

	func _process(delta: float) -> void:
		if GameState.in_dialogue:
			return
		_a = fmod(_a + delta * speed * TAU, TAU)
		for i in _bits.size():
			var a := _a + TAU * i / _bits.size()
			var s := _bits[i]
			s.position = Vector2(cos(a) * radius.x, sin(a) * radius.y)
			s.modulate.a = 0.55 + 0.45 * sin(a)   # 转到前面亮、后面暗
			s.rotation = a
