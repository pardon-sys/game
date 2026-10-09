class_name MazeHand
extends CharacterBody2D
## 千手的紫手（第八层夜迷宫专属）：一只发着紫光、半透明的手，在迷宫里慢慢游荡。
##   被笑声半径里的笑声吸引：沿着走廊（GridPath）朝她过去，走得更快。
##   靠近到 REACH 时向导演要一次 QTE（同一时间只有一个，别的手排队等）；QTE 成功 → 被弹开消散，失败 → 飞到一个部位盖住（导演处理）。
##   月光灯 / 月光镜的光带里不敢进来（往外退）。冰晶结界冻住它（freeze）。
##   冷光越暗画得越淡（director.hand_visibility()）。

const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")
const REACH := 22.0
const WANDER_SPEED := 16.0
const CHASE_SPEED := 38.0

var director: Node
var _dir := Vector2.ZERO
var _think := 0.0
var _t := 0.0
var _frozen := 0.0
var _cool := 0.0
var _gone := false
var _path: Array[Vector2] = []
var _repath := 0.0
var glow: PointLight2D


func _ready() -> void:
	add_to_group("maze_hand")
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	shape.shape = c
	add_child(shape)
	z_index = 3
	glow = PointLight2D.new()
	glow.texture = LIGHT_TEX
	glow.texture_scale = 0.35
	glow.energy = 0.55
	glow.color = Color(0.7, 0.4, 1.0)
	glow.height = 16.0
	glow.position = Vector2(0, -10)
	add_child(glow)
	_t = randf() * TAU
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func freeze(sec: float) -> void:
	_frozen = maxf(_frozen, sec)


func is_frozen() -> bool:
	return _frozen > 0.0


func is_gone() -> bool:
	return _gone


## QTE 成功 / 被光逼退：消散。
func vanish() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group("maze_hand")
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "crystal", 5, 30.0, 0.4, Vector2(0, 30), Color(0.85, 0.55, 1.0))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), 0.35)
	tw.tween_callback(queue_free)


## QTE 没过：朝她飞过去（之后由导演把它算成盖在部位上，这只手本身消失）。
func latch_onto(c: Node2D) -> void:
	if _gone:
		return
	_gone = true
	remove_from_group("maze_hand")
	var tw := create_tween()
	tw.tween_property(self, "global_position", c.global_position + Vector2(0, -10), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


## 等一会儿再要 QTE（被别的 QTE 占着、刚失败过）。
func cooldown(sec: float) -> void:
	_cool = maxf(_cool, sec)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _gone or GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing():
		return
	if director:
		modulate.a = lerpf(0.3, 1.0, director.hand_visibility())
	if _frozen > 0.0:
		_frozen -= delta
		return
	_cool = maxf(0.0, _cool - delta)
	var p := GameState.player as Node2D
	if not is_instance_valid(p):
		return
	# 光里不敢进：往远离光源的方向退
	var light: Variant = director.light_at(global_position) if director else null
	if light is Vector2:
		velocity = (global_position - (light as Vector2)).normalized() * CHASE_SPEED
		move_and_slide()
		return
	var to_p := p.global_position - global_position
	var attracted: bool = director != null and director.attracts(self)
	if attracted:
		_repath -= delta
		if _repath <= 0.0 or _path.is_empty():
			_repath = 0.5
			_path = GridPath.find(director.level(), global_position, p.global_position, 1500)
		var goal := p.global_position
		while not _path.is_empty() and _path[0].distance_to(global_position) < 6.0:
			_path.remove_at(0)
		if not _path.is_empty() and to_p.length() > 30.0:
			goal = _path[0]
		velocity = (goal - global_position).normalized() * CHASE_SPEED * (1.0 + float(director.attract_boost()))
	else:
		_think -= delta
		if _think <= 0.0 or get_slide_collision_count() > 0:
			_think = randf_range(1.0, 2.4)
			_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.8 else Vector2.ZERO
		velocity = _dir * WANDER_SPEED
	move_and_slide()
	if to_p.length() < REACH and _cool <= 0.0 and director and director.has_method("request_qte"):
		director.request_qte(self)


func _draw() -> void:
	# 一小段垂下来的手臂 + 张开的手掌，轻轻摆动；底下一圈紫色的影子
	draw_circle(Vector2(0, 2), 6.0, Color(0.3, 0.1, 0.4, 0.35))
	var sway := sin(_t * 2.4) * 2.0
	for i in 3:
		var p := Vector2(sway * (1.0 - i / 3.0), -30.0 + i * 7.0)
		draw_texture_rect_region(ARM, Rect2(p - Vector2(8, 8), Vector2(16, 16)), Rect2((i % 2) * 24, 0, 24, 24),
			Color(0.85, 0.6, 1.0, 0.7))
	var f := 2 + int(_t * 6.0) % 2
	draw_texture_rect_region(ARM, Rect2(Vector2(sway * 0.3, -10) - Vector2(10, 10), Vector2(20, 20)), Rect2(f * 24, 0, 24, 24),
		Color(0.95, 0.75, 1.0, 0.9))
