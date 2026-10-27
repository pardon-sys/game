class_name WindupHand
extends Node2D
## 发条小手（骑士篇支线「没有名字的生日」·旧仓库）：旧玩具上拆下来的木头小手，背上插着一把发条钥匙。
##   音乐响着（music = true）：一动不动（像玩具一样摆着）；音乐一停：看得见她就朝她爬过去（SPEED），碰到就挠一下脚心（闷笑 +LAUGH），然后弹开 RECOIL 秒。
##   她躲在箱子 / 木桶后面（unseen = true，任务每帧给）：看不见她，原地转圈。
##   冰晶结界 / 千手解放：冻住 FROZEN 秒。
## 测试：music、unseen、target、state（still / chase / recoil / frozen）、touch()。

const SPEED := 40.0
const REACH := 9.0
const LAUGH := 0.08
const RECOIL := 1.5
const FROZEN := 4.0

var target: Node2D
var music := true
var unseen := false
var state := "still"
var _left := 0.0
var _t := 0.0
var _dir := Vector2.RIGHT


func _ready() -> void:
	z_index = 1
	add_to_group(PantsBurst.KNIGHT_GROUP)


func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		state = "frozen"
		_left = FROZEN


func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if global_position.distance_to(center) <= r:
		state = "frozen"
		_left = maxf(time, FROZEN)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	match state:
		"frozen", "recoil":
			_left -= delta
			if state == "recoil":
				global_position += _dir * SPEED * 0.8 * delta
			if _left <= 0.0:
				state = "still"
		"still":
			if not music and is_instance_valid(target) and not unseen:
				state = "chase"
		"chase":
			if music or unseen or not is_instance_valid(target):
				state = "still"
				return
			_dir = global_position.direction_to(target.global_position)
			global_position += _dir * SPEED * delta
			if global_position.distance_to(target.global_position) <= REACH:
				touch()


## 碰到她：挠一下脚心，弹开
func touch() -> void:
	var pc := target as PlayableCharacter
	if pc and pc.laugh:
		pc.laugh.add(pc.laugh.max_value * LAUGH)
		ZoneFx.play("sole", pc.get_parent(), ZoneFx.body_point(pc, "sole"), 0.8, false)
		Audio.play("tickle", -8.0, 0.1)
	state = "recoil"
	_left = RECOIL
	_dir = -_dir


func _draw() -> void:
	var wob := sin(_t * 18.0) * 1.0 if state == "chase" else 0.0
	var col := Color(0.75, 0.92, 1.0) if state == "frozen" else Color(0.78, 0.58, 0.38)
	# 木头小手：手掌 + 四根短指头
	draw_rect(Rect2(Vector2(-4, -6 + wob), Vector2(8, 6)), col)
	for i in 4:
		draw_rect(Rect2(Vector2(-4 + i * 2.2, -10 + wob + (1 if i % 2 else 0)), Vector2(1.6, 4)), col.darkened(0.1))
	draw_rect(Rect2(Vector2(-4, -6 + wob), Vector2(8, 6)), Color(0.4, 0.26, 0.16), false, 1.0)
	# 背上的发条钥匙（转）
	var a := _t * (6.0 if state == "chase" else 1.0)
	draw_line(Vector2(0, -3), Vector2(0, -3) + Vector2.from_angle(a) * 5.0, Color(0.8, 0.75, 0.5), 1.5)
	draw_circle(Vector2(0, -3) + Vector2.from_angle(a) * 5.0, 1.4, Color(0.95, 0.85, 0.5))
