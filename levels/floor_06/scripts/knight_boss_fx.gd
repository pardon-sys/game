class_name KnightBossFx
extends RefCounted
## 骑士 Boss「痒铠骑士」（TaskKnightBoss）场上的东西：都是程序画的（_draw），伤害判定由 TaskKnightBoss 每帧问它们。
##   Bolt        弹指 / 甩出来的诅咒装备：直线飞，碰到人就 hit
##   NetCell     十指痒网的一格：预警 → 指头冒出来（active 一瞬间算数）
##   Dust        踢沙扬起的痒尘：圈里的人闷笑慢慢涨、减速
##   Shard       飞散的甲片：在场地里弹来弹去
##   Ring        呼唤骑士之名的冲击波：一圈往外扩，碰到的人往中间推
##   Mirror      镜面笑脸：先绕着盔甲转，再去追最近的人
##   Gear        穿在公主身上的诅咒装备（跟着她，一直挠那个部位；搭档按住 E 扯下来 / 她连按 J 挣掉）
##   WeakSpot    部件掉了露出来的破绽（怕痒的地方）：这时打它 = 挠骑士
##   Victim      场上的镇民 / 被挠倒的队员：会被手印贴上（cursed），按住 E 救下来

const PURPLE := Color(0.72, 0.45, 0.95)
const ICE := Color(0.75, 0.92, 1.0)


class Bolt extends Node2D:
	var vel := Vector2.ZERO
	var life := 2.4
	var radius := 6.0
	var icon: Texture2D
	var hit := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		life -= delta
		position += vel * delta
		if life <= 0.0 or hit:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if icon:
			draw_texture_rect(icon, Rect2(-8, -8, 16, 16), false)
			draw_arc(Vector2.ZERO, 10, 0, TAU, 14, Color(PURPLE, 0.7), 1.5)
			return
		# 弹出来的铁指头
		draw_circle(Vector2.ZERO, radius, Color(PURPLE, 0.35))
		draw_line(-vel.normalized() * 6.0, vel.normalized() * 4.0, Color(0.85, 0.85, 0.95), 3)
		draw_circle(vel.normalized() * 4.0, 2.0, Color(1, 0.8, 1))


class NetCell extends Node2D:
	const SIZE := 18.0
	var warn := 0.9
	var active := 0.0
	var done := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if warn > 0.0:
			warn -= delta
			if warn <= 0.0:
				active = 0.25
		elif active > 0.0:
			active -= delta
			if active <= 0.0:
				done = true
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
		if warn > 0.0:
			draw_rect(r, Color(PURPLE, 0.15 + 0.15 * sin(_t * 14.0)))
			draw_rect(r, Color(PURPLE, 0.8), false, 1.0)
		else:
			for i in 4:
				var x := -6.0 + i * 4.0
				draw_line(Vector2(x, 6), Vector2(x, -4), Color(0.85, 0.85, 0.95), 2)
				draw_circle(Vector2(x, -4), 1.5, Color(1, 0.8, 1))


class Dust extends Node2D:
	const RADIUS := 18.0
	var life := 5.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 0.35 * clampf(life / 1.0, 0.0, 1.0)
		for i in 6:
			var p := Vector2.from_angle(i * TAU / 6.0 + _t * 0.7) * 9.0
			draw_circle(p, 9.0, Color(0.85, 0.72, 0.55, a))
		draw_circle(Vector2.ZERO, 3.0, Color(1, 0.7, 0.9, a))


class Shard extends Node2D:
	var vel := Vector2.ZERO
	var bounds := Rect2()
	var life := 5.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		life -= delta
		position += vel * delta
		var gp := global_position
		if gp.x < bounds.position.x or gp.x > bounds.end.x:
			vel.x = -vel.x
			global_position.x = clampf(gp.x, bounds.position.x, bounds.end.x)
		if gp.y < bounds.position.y or gp.y > bounds.end.y:
			vel.y = -vel.y
			global_position.y = clampf(gp.y, bounds.position.y, bounds.end.y)
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := _t * 9.0
		var pts := PackedVector2Array([Vector2.from_angle(r) * 6.0, Vector2.from_angle(r + 2.2) * 4.0, Vector2.from_angle(r + 4.0) * 5.0])
		draw_colored_polygon(pts, Color(0.78, 0.8, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(PURPLE, 0.9), 1.0)


class Ring extends Node2D:
	const MAX_R := 130.0
	const TIME := 1.0
	var r := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		r = MAX_R * minf(1.0, _t / TIME)
		if _t >= TIME + 0.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 0.75, 0.95, 0.8 * (1.0 - _t / (TIME + 0.2))), 3.0)


class Mirror extends Node2D:
	var center: Node2D
	var angle := 0.0
	var orbit := 2.0
	var chase := 5.0
	var target: Node2D
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		if orbit > 0.0:
			orbit -= delta
			angle += delta * 2.6
			if is_instance_valid(center):
				global_position = center.global_position + Vector2.from_angle(angle) * 40.0 + Vector2(0, -20)
		else:
			chase -= delta
			if is_instance_valid(target):
				global_position = global_position.move_toward(target.global_position + Vector2(0, -8), 45.0 * delta)
			if chase <= 0.0:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 8, Color(0.55, 0.3, 0.75, 0.75))
		draw_arc(Vector2(0, 1), 4, 0.2, PI - 0.2, 8, Color(1, 0.8, 1.0), 1.5)
		draw_circle(Vector2(-3, -2), 1.2, Color(1, 0.85, 1.0))
		draw_circle(Vector2(3, -2), 1.2, Color(1, 0.85, 1.0))
		draw_arc(Vector2.ZERO, 9, 0, TAU, 14, Color(0.9, 0.95, 1.0, 0.6), 1.0)


## 穿在公主身上的诅咒装备：跟着她，图标画在那个部位；pull 扯下来的进度（0~1）
class Gear extends Node2D:
	var who: PlayableCharacter
	var item_id := ""
	var zone := "sole"
	var icon: Texture2D
	var pull := 0.0
	var tears := 0
	var _t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(who):
			global_position = ZoneFx.body_point(who, zone)
		queue_redraw()

	func _draw() -> void:
		var wob := sin(_t * 12.0) * 1.5
		draw_circle(Vector2.ZERO, 9, Color(PURPLE, 0.25 + 0.1 * sin(_t * 6.0)))
		if icon:
			draw_texture_rect(icon, Rect2(-7 + wob, -7, 14, 14), false)
		if pull > 0.0:
			draw_arc(Vector2(0, -14), 5, -PI / 2, -PI / 2 + TAU * pull, 16, Color(1, 0.9, 0.5), 2.0)


## 部件掉下来以后露出来的破绽：打它 = 挠骑士（TaskKnightBoss.tickle_knight）
class WeakSpot extends CharacterBody2D:
	var task: Node
	var spot := ""
	var faction := Faction.Type.ENEMY
	var _t := 0.0

	func _ready() -> void:
		add_to_group("enemy")
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 11.0
		shape.shape = c
		add_child(shape)
		z_index = 5
		set_meta("hit_radius", 11.0)

	func is_alive() -> bool:
		return true

	func receive_hit(_hit: HitData) -> bool:
		return is_instance_valid(task) and task.tickle_knight()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a := 0.5 + 0.4 * sin(_t * 10.0)
		draw_arc(Vector2.ZERO, 11 + sin(_t * 6.0) * 2.0, 0, TAU, 20, Color(1, 0.85, 0.4, a), 2.0)
		for i in 3:
			var p := Vector2.from_angle(_t * 3.0 + i * TAU / 3.0) * 13.0
			draw_circle(p, 1.5, Color(1, 0.95, 0.6, a))


## 场上的人：镇民逃跑（runner，沿着场边绕圈）/ 被挠倒的队员（fallen，躺着）/ 护着镇民的队员（guard，站着）。
## cursed：被手印贴上（偷笑声、笑得停不下来），cursed_t 贴了多久；rescue 救的进度（按住 E 1 秒）。
class Victim extends Node2D:
	const FRAME := 32
	var sheet: Texture2D
	var kind := "runner"
	var path: Array = []
	var cursed := false
	var cursed_t := 0.0
	var rescue := 0.0
	var line := ""
	var _leg := 0
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_t += delta
		if cursed:
			cursed_t += delta
		elif kind == "runner" and path.size() >= 2:
			var to: Vector2 = path[(_leg + 1) % path.size()]
			global_position = global_position.move_toward(to, 38.0 * delta)
			if global_position.distance_to(to) < 1.0:
				_leg = (_leg + 1) % path.size()
		queue_redraw()

	func _draw() -> void:
		if sheet == null:
			return
		var col := int(_t * 6.0) % 4 if kind == "runner" and not cursed else 0
		var row := 0
		var src := Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
		if kind == "fallen" or cursed:
			# 倒在地上笑 / 被手印贴着笑得发抖
			draw_set_transform(Vector2(0, -4), PI / 2 if kind == "fallen" else sin(_t * 30.0) * 0.08, Vector2.ONE)
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
		if cursed:
			# 贴在身上的紫色手印 + 「哈哈」
			for i in 2:
				var p := Vector2(-5 + i * 9, -10 + sin(_t * 8.0 + i) * 2.0)
				draw_circle(p, 3.5, Color(PURPLE, 0.85))
				for j in 3:
					draw_line(p, p + Vector2.from_angle(-PI * 0.7 + j * 0.6) * 5.0, Color(PURPLE, 0.85), 1.0)
			if rescue > 0.0:
				draw_arc(Vector2(0, -34), 6, -PI / 2, -PI / 2 + TAU * rescue, 16, Color(1, 0.9, 0.5), 2.0)
			else:
				draw_arc(Vector2(0, -34), 5, 0, TAU, 12, Color(1, 0.6, 0.85, 0.5 + 0.4 * sin(_t * 8.0)), 1.5)
