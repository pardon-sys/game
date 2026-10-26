class_name KnightBossFx
extends RefCounted
## 骑士 Boss「痒铠骑士」（TaskKnightBoss）场上的东西：都是程序画的（_draw），伤害判定由 TaskKnightBoss 每帧问它们。
##   Bolt        弹指 / 甩出来的诅咒装备：直线飞，碰到人就 hit
##   NetCell     十指痒网的一格：预警 → 指头冒出来（active 一瞬间算数）
##   Dust        踢沙扬起的痒尘：圈里的人闷笑慢慢涨、减速
##   Shard       飞散的甲片：在场地里弹来弹去
##   Ring        呼唤骑士之名的冲击波：一圈往外扩，有 gaps 个缺口（站在缺口的方向上安全），碰到的人往中间推
##   Mirror      镜面笑脸：先绕着盔甲转，再去追最近的人
##   Gear        穿在公主身上的诅咒装备（跟着她，一直挠那个部位；搭档按住 E 扯下来 / 她连按 J 挣掉）
##   WeakSpot    部件掉了露出来的破绽（怕痒的地方）：这时打它 = 挠骑士
##   Victim      场上的镇民 / 被挠倒的队员：在掩体之间乱跑、躲着探头，盔甲靠近就逃；会被手印贴上（cursed），按住 E 救下来；没被贴的按 E 说话
##   Crate       广场上的木箱（挡人、挡甲片；冲撞撞上去会碎、盔甲卡住）
##   LeapShadow  跳起来砸地的落点：影子越来越大
##   Lantern     最后阶段的笑声灯笼：progress 被笑声点亮，lit 以后升起光柱；finale 时光柱汇到盔甲上
##   Tentacle    笑面伸出来偷灯笼笑声的触手：爬过去（travel）→ 缠住吸（progress 往回掉）；冻住就碎
##   Helper      做过支线的人：跑到他那盏灯笼下陪着笑
##   Decor       爬满广场墙根的诅咒小手（装饰，慢慢地蠕动）
##   Burst       部件炸开时飞出去的碎片（纯特效）

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
	const MAX_R := 140.0
	const TIME := 1.1
	## 缺口（半宽，弧度）：站在缺口的方向上，冲击波扫不到
	const GAP := 0.42
	var r := 0.0
	var gaps: Array = []
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		r = MAX_R * minf(1.0, _t / TIME)
		if _t >= TIME + 0.2:
			queue_free()
		queue_redraw()

	## 这个方向（相对圆心的角度）在不在缺口里
	func in_gap(ang: float) -> bool:
		for g in gaps:
			if absf(angle_difference(ang, float(g))) <= GAP:
				return true
		return false

	func _draw() -> void:
		var a := 0.85 * (1.0 - _t / (TIME + 0.2))
		var steps := 64
		for i in steps:
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			if in_gap((a0 + a1) * 0.5):
				continue
			draw_arc(Vector2.ZERO, r, a0, a1, 2, Color(1, 0.75, 0.95, a), 4.0)
			draw_arc(Vector2.ZERO, r - 4.0, a0, a1, 2, Color(0.75, 0.4, 1.0, a * 0.6), 2.0)


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


## 场上的人：被挠倒的队员（fallen，躺着不动）/ 镇民和队员（runner / guard：在掩体 covers 之间乱跑，躲一会儿探头，盔甲 threat 靠近就逃到最远的掩体）。
## cursed：被手印贴上（偷笑声、笑得停不下来、不再跑），cursed_t 贴了多久；rescue 救的进度（按住 E 1 秒）。talk_cool：按 E 说话的冷却。
class Victim extends Node2D:
	const FRAME := 32
	const RUN := 46.0
	const SCARE_R := 56.0
	var sheet: Texture2D
	## 被盔甲盯上了（KnightCurse.hunt）：吓得缩在原地发抖，不跑
	var hunted := false
	var kind := "runner"
	var who := "kid"
	var covers: Array = []
	var threat: Node2D
	var cursed := false
	var cursed_t := 0.0
	var rescue := 0.0
	var talk_cool := 0.0
	var helped := false
	var state := "run"
	var goal := Vector2.ZERO
	var _hide := 0.0
	var _dir := 0
	var _t := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		z_index = 1
		_rng.randomize()
		goal = global_position
		if kind != "fallen":
			_pick_cover(false)

	func _pick_cover(far: bool) -> void:
		if covers.is_empty():
			return
		if far and is_instance_valid(threat):
			var best: Vector2 = covers[0]
			for c in covers:
				if (c as Vector2).distance_to(threat.global_position) > best.distance_to(threat.global_position):
					best = c
			goal = best
		else:
			goal = covers[_rng.randi() % covers.size()]
		state = "run"

	func _process(delta: float) -> void:
		_t += delta
		talk_cool = maxf(0.0, talk_cool - delta)
		queue_redraw()
		if cursed:
			cursed_t += delta
			return
		if kind == "fallen" or GameState.in_cutscene or hunted:
			return
		# 盔甲靠近：逃到离它最远的掩体
		if is_instance_valid(threat) and threat.global_position.distance_to(global_position) <= SCARE_R and state != "flee":
			_pick_cover(true)
			state = "flee"
		match state:
			"run", "flee":
				var step := RUN * (1.3 if state == "flee" else 1.0) * delta
				var to := goal - global_position
				_dir = 1 if absf(to.x) > absf(to.y) and to.x < 0 else (2 if absf(to.x) > absf(to.y) else (3 if to.y < 0 else 0))
				global_position = global_position.move_toward(goal, step)
				if global_position.distance_to(goal) < 1.0:
					state = "hide"
					_hide = _rng.randf_range(2.0, 4.0)
			"hide":
				_hide -= delta
				if _hide <= 0.0:
					_pick_cover(false)

	func _draw() -> void:
		if sheet == null:
			return
		var moving := state in ["run", "flee"] and kind != "fallen" and not cursed
		var col := int(_t * 7.0) % 4 if moving else 0
		var row := _dir if moving else (0 if sin(_t * 1.3) > 0.0 else 3)
		var src := Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
		if hunted and not cursed and kind != "fallen":
			# 被盯上：缩成一团发抖
			draw_set_transform(Vector2(sin(_t * 40.0), 3), 0.0, Vector2(1.0, 0.85))
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == "fallen" or cursed:
			# 倒在地上笑 / 被手印贴着笑得发抖
			draw_set_transform(Vector2(0, -4), PI / 2 if kind == "fallen" else sin(_t * 30.0) * 0.08, Vector2.ONE)
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif state == "hide":
			# 蹲着躲：矮一截，时不时探头
			draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.85))
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), src)
		if cursed:
			# 贴在身上的紫色手印 + 「哈哈」
			for i in 2:
				var p := Vector2(-5 + i * 9, -10 + sin(_t * 8.0 + i) * 2.0)
				CurseHand.draw_hand(self, p, 0.6, PURPLE, Color(0.42, 0.18, 0.6), 0.9, sin(_t * 14.0 + i))
			if rescue > 0.0:
				draw_arc(Vector2(0, -34), 6, -PI / 2, -PI / 2 + TAU * rescue, 16, Color(1, 0.9, 0.5), 2.0)
			else:
				draw_arc(Vector2(0, -34), 5, 0, TAU, 12, Color(1, 0.6, 0.85, 0.5 + 0.4 * sin(_t * 8.0)), 1.5)
		elif talk_cool <= 0.0 and not helped and kind != "fallen":
			# 能说话：头上一个小小的「…」
			draw_string(ThemeDB.fallback_font, Vector2(-5, -32), "...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.75, 0.7))


## 广场上的木箱：挡人（墙一样的碰撞）、挡甲片；冲撞撞上去会碎（broken），盔甲卡住
class Crate extends StaticBody2D:
	const R := 10.0
	var broken := false
	## 诅咒爆发「痒波地脉」时镇民搬来的木桩（画成木桩，撞断的算数）
	var stake := false
	var _shake := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 10)
		shape.shape = rect
		shape.position = Vector2(0, -3)
		add_child(shape)
		z_index = 1

	func smash() -> void:
		if broken:
			return
		broken = true
		Fx.burst(get_parent(), global_position + Vector2(0, -8), "dust", 14, 50.0, 0.6, Vector2.ZERO, Color(0.75, 0.55, 0.35))
		Audio.play("break", -4.0)
		queue_free()

	func _process(delta: float) -> void:
		_shake = maxf(0.0, _shake - delta)

	func _draw() -> void:
		if stake:
			draw_rect(Rect2(-4, -22, 8, 22), Color(0.6, 0.4, 0.24))
			draw_rect(Rect2(-4, -22, 8, 22), Color(0.36, 0.22, 0.13), false, 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -22), Vector2(0, -27), Vector2(4, -22)]), Color(0.7, 0.5, 0.3))
			draw_line(Vector2(-4, -12), Vector2(4, -10), Color(0.85, 0.75, 0.4), 2.0)
			return
		draw_rect(Rect2(-9, -16, 18, 16), Color(0.62, 0.42, 0.26))
		draw_rect(Rect2(-9, -16, 18, 16), Color(0.38, 0.24, 0.15), false, 1.0)
		draw_line(Vector2(-9, -16), Vector2(9, 0), Color(0.45, 0.3, 0.18), 1.0)
		draw_line(Vector2(9, -16), Vector2(-9, 0), Color(0.45, 0.3, 0.18), 1.0)


## 跳起来砸地的落点：影子越来越大、越来越深（left / total）
class LeapShadow extends Node2D:
	var radius := 26.0
	var total := 0.9
	var left := 0.9
	var _t := 0.0

	func _ready() -> void:
		z_index = 0
		add_to_group("danger")
		set_meta("radius", radius)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - clampf(left / maxf(0.01, total), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(0.15, 0.05, 0.2, 0.25 + 0.35 * k))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 28, Color(0.85, 0.4, 1.0, 0.6 + 0.3 * sin(_t * 16.0)), 1.5)


## 最后阶段的笑声灯笼：被笑声点亮（progress 0~1）；亮了以后升起光柱；finale：光柱汇到盔甲上
class Lantern extends Node2D:
	var index := 0
	var progress := 0.0
	var lit := false
	var stealing := false
	var finale := false
	var target: Node2D
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# 竿子 + 灯笼
		draw_line(Vector2(0, 0), Vector2(0, -26), Color(0.45, 0.3, 0.2), 2.0)
		var glow := 1.0 if lit else progress
		var col := Color(0.35, 0.3, 0.4).lerp(Color(1, 0.8, 0.45), glow)
		draw_circle(Vector2(0, -28), 6.0, col)
		draw_rect(Rect2(-4, -36, 8, 2), Color(0.5, 0.32, 0.2))
		if glow > 0.0:
			draw_circle(Vector2(0, -28), 10.0 + 6.0 * glow + sin(_t * 4.0), Color(1, 0.85, 0.5, 0.12 + 0.2 * glow))
		if not lit:
			draw_arc(Vector2(0, -28), 9.0, -PI / 2, -PI / 2 + TAU * progress, 20, Color(1, 0.9, 0.55, 0.9), 2.0)
			if stealing:
				draw_arc(Vector2(0, -28), 11.0, 0, TAU, 16, Color(0.75, 0.35, 1.0, 0.5 + 0.4 * sin(_t * 12.0)), 1.5)
		else:
			# 光柱
			draw_rect(Rect2(-4, -160, 8, 132), Color(1, 0.88, 0.55, 0.18 + 0.08 * sin(_t * 3.0 + index)))
			draw_rect(Rect2(-1.5, -160, 3, 132), Color(1, 0.95, 0.75, 0.35))
			if finale and is_instance_valid(target):
				var to := target.global_position - global_position + Vector2(0, -30)
				draw_line(Vector2(0, -60), to, Color(1, 0.9, 0.6, 0.7), 4.0)
				draw_line(Vector2(0, -60), to, Color(1, 1, 0.9, 0.9), 1.5)


## 笑面伸出来的触手：从盔甲爬向一盏灯笼（travel 秒），缠住以后吸它的笑声；冻住就碎
class Tentacle extends Node2D:
	var lantern: Lantern
	var from: Node2D
	var travel := 1.5
	var left := 1.5
	var attached := false
	var frozen := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 3
		add_to_group("danger")

	## 触手的头在哪（世界坐标）
	func head() -> Vector2:
		if not is_instance_valid(lantern) or not is_instance_valid(from):
			return global_position
		var k := 1.0 - clampf(left / maxf(0.01, travel), 0.0, 1.0)
		return from.global_position.lerp(lantern.global_position + Vector2(0, -24), k)

	func _process(delta: float) -> void:
		_t += delta
		if not frozen and not attached:
			left -= delta
			if left <= 0.0:
				attached = true
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(from):
			return
		var a := from.global_position - global_position + Vector2(0, -20)
		var b := head() - global_position
		var col := KnightBossFx.ICE if frozen else KnightBossFx.PURPLE
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			var p := a.lerp(b, k) + (b - a).orthogonal().normalized() * sin(k * 9.0 + _t * 8.0) * 5.0 * (1.0 - k * 0.5)
			pts.append(p)
		draw_polyline(pts, Color(col, 0.85), 3.0)
		CurseHand.draw_hand(self, b, 0.8, col, Color(0.42, 0.18, 0.6), 0.9, 0.0 if frozen else sin(_t * 12.0))


## 做过支线的人：跑到他那盏灯笼下陪着笑
class Helper extends Node2D:
	var sheet: Texture2D
	var goal := Vector2.ZERO
	var line := ""
	var arrived := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_t += delta
		if not arrived:
			global_position = global_position.move_toward(goal, 70.0 * delta)
			if global_position.distance_to(goal) < 1.0:
				arrived = true
				if line != "":
					SpeechBubble.say(self, line, 30.0, 3.0)
		queue_redraw()

	func _draw() -> void:
		if sheet == null:
			return
		var col := int(_t * 7.0) % 4 if not arrived else int(_t * 3.0) % 2 * 2
		draw_texture_rect_region(sheet, Rect2(-16, -28 - (absf(sin(_t * 9.0)) * 2.0 if arrived else 0.0), 32, 32), Rect2(col * 32, 0, 32, 32))
		if arrived:
			draw_string(ThemeDB.fallback_font, Vector2(8, -30), "哈", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.6, 0.6 + 0.4 * sin(_t * 8.0)))


## 爬满墙根的诅咒小手（装饰）：慢慢地蠕动，灯笼亮一盏少一点
class Decor extends Node2D:
	var spots: Array = []
	var fade := 1.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 0
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in spots.size():
			var p: Vector2 = spots[i] - global_position + Vector2(sin(_t * 0.7 + i) * 3.0, cos(_t * 0.5 + i * 1.7) * 2.0)
			CurseHand.draw_hand(self, p, 0.7, PURPLE, Color(0.42, 0.18, 0.6), 0.35 * fade, sin(_t * 3.0 + i), -PI * 0.85 + i)


## 部件炸开时飞出去的碎片（纯特效，LIFE 秒）
class Burst extends Node2D:
	const LIFE := 0.9
	var col := Color(0.72, 0.45, 0.95)
	var bits: Array = []
	var _t := 0.0

	func _ready() -> void:
		z_index = 6
		for i in 12:
			bits.append({"v": Vector2.from_angle(randf() * TAU) * randf_range(60, 140), "r": randf() * TAU, "s": randf_range(2.0, 4.0)})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / LIFE
		draw_circle(Vector2.ZERO, 6.0 + _t * 40.0, Color(1, 1, 1, 0.5 * a))
		for b in bits:
			var p: Vector2 = b["v"] * _t + Vector2(0, 60.0 * _t * _t)
			var s: float = b["s"]
			var r: float = b["r"] + _t * 12.0
			draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(r) * s, p + Vector2.from_angle(r + 2.2) * s, p + Vector2.from_angle(r + 4.1) * s]), Color(col, a))
