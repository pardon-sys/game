class_name TickleSpider
extends Monster
## 挠痒蜘蛛：和目标保持距离，定时吐丝（减速 + 少量挠痒）；
## 目标被丝缠住（减速中）时冲上去，贴身后用多条腿连挠。

const WEB := preload("res://scenes/combat/web_shot.tscn")

@export var keep_min := 50.0
@export var keep_max := 80.0
@export var web_cooldown := 3.0
@export var web_range := 150.0
@export var burst_count := 3
@export var burst_interval := 0.15
@export var burst_amount := 6.0

var _web_cd := 1.5
var _burst_left := 0
var _burst_t := 0.0


func _tick(delta: float) -> void:
	_web_cd -= delta
	_update_burst(delta)
	super(delta)
	if state == State.CHASE and is_instance_valid(target) and _web_cd <= 0.0 and not GameState.in_dialogue \
			and global_position.distance_to(target.global_position) <= web_range:
		shoot_web()


func shoot_web() -> void:
	_web_cd = web_cooldown
	var from := global_position + Vector2(0, -6)
	Projectile.fire(WEB, get_parent(), from, from.direction_to(target.global_position + Vector2(0, -4)), self)


func _move(dir: Vector2, speed: float, delta: float) -> void:
	if state != State.CHASE or not is_instance_valid(target):
		super(dir, speed, delta)
		return
	var d := global_position.distance_to(target.global_position)
	var caught: bool = target.status != null and target.status.is_slowed()
	if caught or d > keep_max:
		super(dir, speed, delta)
	elif d < keep_min:
		super(-dir, speed, delta)
	else:
		super(dir.orthogonal(), speed * 0.5, delta)


func _update_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_t -= delta
	if _burst_t > 0.0:
		return
	_burst_t = burst_interval
	_burst_left -= 1
	if is_instance_valid(target) and hit_area and target in hit_area.get_overlapping_bodies():
		if deliver_tickle(target, burst_amount):
			play_tickle_sound(-5.0)
	else:
		_burst_left = 0


func _on_tickle_performed(t: Node) -> void:
	if t is Actor:
		target = t
	_burst_left = burst_count - 1
	_burst_t = burst_interval


func _animate(_delta: float) -> void:
	var legs := 1.0 if velocity.length() > 5.0 else 0.0
	sprite.offset.y = -8.0 - roundf(absf(sin(_t * 14.0)) * legs)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
