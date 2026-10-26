class_name CursedArmor
extends CharacterBody2D
## 被诅咒附身的盔甲（骑士篇 E 镇中追逃）：一直追着粉色公主。直线快（SPEED，比她走路快）、转弯慢（TURN 弧度 / 秒），会被墙和房子挡住——绕着障碍物就甩得开。
##   铁手横扫：每 SWEEP_EVERY 秒，在她所在的那一行（或一列）亮一条预警线（danger 组，meta rect）WARN 秒，然后铁手扫过去：线上的人被挠一下、减速。
##   冻住：freeze(秒)，期间不动（蓝色公主）。晃一下：stun(秒)，期间不动（开局在楼梯口挣扎、被信标的光晃到）。被栅栏 / 墙卡住时贴着滑（move_and_slide）。
##   抓住：离她 CATCH_R 以内 → grabbed 信号（任务处理挣扎）。
## 不受伤、不参与战斗。画面用 npcs/knight_cursed.png（行走图 4×4）。测试：heading、freeze_left、sweep_now()、warn_rect。

signal grabbed(who: PlayableCharacter)

const TEX := preload("res://assets/generated/npcs/knight_cursed.png")
const SPEED := 86.0
const TURN := 2.2
const CATCH_R := 12.0
const SWEEP_EVERY := 5.5
const WARN := 0.9
const SWEEP_LEN := 180.0
const SWEEP_W := 14.0
const SWEEP_LAUGH := 0.08
const SLOW_TIME := 1.5
const SLOW_MULT := 0.6

var target: PlayableCharacter
var heading := Vector2.LEFT
var freeze_left := 0.0
var stun_left := 0.0
var paused := false
var warn_left := 0.0
var warn_rect := Rect2()
var _sweep_t := SWEEP_EVERY
var _t := 0.0
var _warn_node: Node2D
var _flash := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	shape.shape = c
	add_child(shape)
	z_index = 2
	add_to_group("cursed_armor")
	add_to_group(PantsBurst.KNIGHT_GROUP)


func stun(time: float) -> void:
	stun_left = maxf(stun_left, time)
	_flash = 0.3


## 蓝色公主的千手解放扫到：定住 PantsBurst.STUN 秒（和 J 的冻住分开算冷却）
func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		stun(PantsBurst.STUN)


func freeze(time: float) -> void:
	freeze_left = time
	Audio.play("ice", -4.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if paused or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(target):
		return
	if freeze_left > 0.0:
		freeze_left -= delta
		return
	if stun_left > 0.0:
		stun_left -= delta
		return
	var want := global_position.direction_to(target.global_position)
	var ang := heading.angle_to(want)
	heading = heading.rotated(clampf(ang, -TURN * delta, TURN * delta))
	velocity = heading * SPEED
	move_and_slide()
	if get_slide_collision_count() > 0:
		# 撞到墙：顺着墙转向她那边
		heading = heading.slerp(want, 0.3).normalized()
	# 冲刺无敌的时候抓不住（冲刺穿过去躲开）
	if global_position.distance_to(target.global_position) <= CATCH_R and not target.is_fully_invulnerable():
		grabbed.emit(target)
	_sweep(delta)


## 铁手横扫：先亮预警线，再扫
func _sweep(delta: float) -> void:
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left <= 0.0:
			_do_sweep()
		return
	_sweep_t -= delta
	if _sweep_t <= 0.0:
		_sweep_t = SWEEP_EVERY
		sweep_now()


func sweep_now() -> void:
	if not is_instance_valid(target):
		return
	var horizontal := absf(target.global_position.y - global_position.y) > absf(target.global_position.x - global_position.x)
	var c := target.global_position
	warn_rect = Rect2(c.x - SWEEP_LEN * 0.5, c.y - SWEEP_W * 0.5, SWEEP_LEN, SWEEP_W) if horizontal \
		else Rect2(c.x - SWEEP_W * 0.5, c.y - SWEEP_LEN * 0.5, SWEEP_W, SWEEP_LEN)
	warn_left = WARN
	if is_instance_valid(_warn_node):
		_warn_node.queue_free()
	_warn_node = WarnLine.new()
	_warn_node.rect = warn_rect
	_warn_node.add_to_group("danger")
	_warn_node.set_meta("rect", warn_rect)
	get_parent().add_child(_warn_node)
	_warn_node.global_position = Vector2.ZERO


func _do_sweep() -> void:
	if is_instance_valid(_warn_node):
		(_warn_node as WarnLine).sweep()
	_flash = 0.3
	for c in get_tree().get_nodes_in_group("player_chars"):
		var pc := c as PlayableCharacter
		if pc and warn_rect.has_point(pc.global_position) and not pc.is_fully_invulnerable():
			if pc.laugh:
				pc.laugh.add(pc.laugh.max_value * SWEEP_LAUGH)
			if pc.status:
				pc.status.apply_slow(SLOW_MULT, SLOW_TIME)
			ZoneFx.play("waist", pc.get_parent(), ZoneFx.body_point(pc, "waist"), 1.0, false)
			Audio.play("tickle", -5.0, 0.1)


func _exit_tree() -> void:
	if is_instance_valid(_warn_node):
		_warn_node.queue_free()


func _draw() -> void:
	var row := 0
	if absf(heading.x) > absf(heading.y):
		row = 1 if heading.x < 0 else 2
	elif heading.y < 0:
		row = 3
	var col := 0 if freeze_left > 0.0 else int(_t * 8.0) % 4
	var tint := Color(0.7, 0.9, 1.0) if freeze_left > 0.0 else (Color(1.5, 1.2, 1.6) if _flash > 0.0 else Color.WHITE)
	draw_circle(Vector2(0, 2), 9, Color(0.6, 0.3, 0.9, 0.25 + 0.1 * sin(_t * 6.0)))
	draw_texture_rect_region(TEX, Rect2(-24, -42, 48, 48), Rect2(col * 32, row * 32, 32, 32), tint)
	if freeze_left > 0.0:
		draw_arc(Vector2(0, -12), 16, 0, TAU, 20, Color(0.75, 0.92, 1.0, 0.8), 2)


## 地上的预警线（亮一会儿，扫过去时闪一下再消失）
class WarnLine extends Node2D:
	var rect := Rect2()
	var _t := 0.0
	var _swept := -1.0

	func _ready() -> void:
		z_index = 0

	func sweep() -> void:
		_swept = 0.3

	func _process(delta: float) -> void:
		_t += delta
		if _swept >= 0.0:
			_swept -= delta
			if _swept < 0.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var a := 0.25 + 0.2 * sin(_t * 18.0) if _swept < 0.0 else 0.7
		draw_rect(rect, Color(0.75, 0.35, 1.0, a))
		draw_rect(rect, Color(0.9, 0.6, 1.0, a + 0.2), false, 1.0)
