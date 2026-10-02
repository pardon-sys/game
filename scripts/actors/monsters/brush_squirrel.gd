class_name BrushSquirrel
extends Monster
## 刷尾松鼠：跑得很快，专门绕到公主身后（她面朝方向的反面），用蓬松的大尾巴刷一下（挠痒 brush_tickle，
## 部位：屁股 3、腰 1、大腿 1）就跳开 hop_distance 像素，冷却 brush_cooldown 秒再绕回来。从前面过来时先绕到侧面。

@export var brush_tickle := 4.0
@export var brush_cooldown := 1.2
@export var hop_distance := 32.0
@export var hop_time := 0.25
@export var circle_speed := 75.0

var brushes := 0
var _brush_cd := 0.6
var _hop_t := 0.0
var _hop_dir := Vector2.ZERO
var _show_brush := 0.0


func _tick(delta: float) -> void:
	_brush_cd = maxf(_brush_cd - delta, 0.0)
	_show_brush = maxf(_show_brush - delta, 0.0)
	if GameState.in_dialogue or is_stunned() or state == State.HURT or not is_alive():
		_hop_t = 0.0
		super(delta)
		return
	if _hop_t > 0.0:
		_hop_t -= delta
		_t += delta
		velocity = _hop_dir * hop_distance / hop_time
		move_with_push()
		_animate(delta)
		return
	var p := target as PlayableCharacter
	if state != State.CHASE or p == null or not is_instance_valid(p) or not p.is_alive() \
			or global_position.distance_to(p.global_position) > stats.lose_range:
		super(delta)
		return
	_t += delta
	_state_time += delta
	_action_cd = maxf(_action_cd - delta, 0.0)
	var goal := behind_point(p)
	var to := goal - global_position
	var speed := circle_speed * stat_mul("speed")
	velocity = velocity.move_toward(to.normalized() * speed if to.length() > 3.0 else Vector2.ZERO, 700.0 * delta)
	move_with_push()
	if velocity.x != 0.0:
		facing = velocity.normalized()
	if _brush_cd <= 0.0 and can_act() and is_behind(p) and global_position.distance_to(p.global_position) <= 18.0:
		_brush(p)
	_animate(delta)


## 要去的位置：在她背后；人在她前面 / 侧面时先绕到侧面。
func behind_point(p: PlayableCharacter) -> Vector2:
	var fwd := p.facing.normalized() if p.facing != Vector2.ZERO else Vector2.DOWN
	var rel := global_position - p.global_position
	if rel.dot(fwd) > -4.0:
		var side := fwd.orthogonal() * (1.0 if rel.dot(fwd.orthogonal()) >= 0.0 else -1.0)
		return p.global_position + side * 16.0 - fwd * 6.0
	return p.global_position - fwd * 10.0


func is_behind(p: PlayableCharacter) -> bool:
	var fwd := p.facing.normalized() if p.facing != Vector2.ZERO else Vector2.DOWN
	return (global_position - p.global_position).dot(fwd) < -2.0


func _brush(p: PlayableCharacter) -> void:
	if not deliver_tickle(p, brush_tickle):
		return
	brushes += 1
	play_tickle_sound()
	maybe_taunt()
	Audio.play("swish", -6.0, 0.1, 1.3)
	_brush_cd = brush_cooldown
	_action_cd = stats.tickle_cooldown
	_show_brush = 0.15
	var away := global_position - p.global_position
	_hop_dir = away.normalized() if away.length() > 0.5 else -p.facing.normalized()
	_hop_t = hop_time


func _animate(_delta: float) -> void:
	if _show_brush > 0.0:
		sprite.frame = 2
	elif _hop_t > 0.0:
		sprite.frame = 3
	else:
		sprite.frame = int(_t * 10.0) % 2 if velocity.length() > 5.0 else 0
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0
