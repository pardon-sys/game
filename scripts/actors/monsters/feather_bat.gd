class_name FeatherBat
extends Monster
## 羽毛蝙蝠：绕着目标盘旋 → 俯冲挠一下 → 飞开 → 再绕回来（打了就跑）。只在俯冲时行动。

enum Phase { CIRCLE, DIVE, RETREAT }

@export var orbit_radius := 40.0
@export var circle_time := Vector2(1.0, 1.8)
@export var dive_time := 1.0
@export var retreat_time := 1.2
@export var dive_speed_mult := 1.8

var phase := Phase.CIRCLE
var _phase_t := 0.0
var _orbit := 0.0


func _setup() -> void:
	super()
	_orbit = randf() * TAU
	_phase_t = randf_range(circle_time.x, circle_time.y)


func _tick(delta: float) -> void:
	_phase_t -= delta
	super(delta)


func _move(dir: Vector2, speed: float, delta: float) -> void:
	if state != State.CHASE or not is_instance_valid(target):
		super(dir, speed, delta)
		return
	var tp := target.global_position
	match phase:
		Phase.CIRCLE:
			_orbit += 2.4 * delta
			var goal := tp + Vector2.from_angle(_orbit) * orbit_radius
			super(global_position.direction_to(goal), speed, delta)
			if _phase_t <= 0.0:
				phase = Phase.DIVE
				_phase_t = dive_time
		Phase.DIVE:
			super(global_position.direction_to(tp), speed * dive_speed_mult, delta)
			if _phase_t <= 0.0:
				_start_retreat()
		Phase.RETREAT:
			super(tp.direction_to(global_position), speed, delta)
			if _phase_t <= 0.0:
				phase = Phase.CIRCLE
				_phase_t = randf_range(circle_time.x, circle_time.y)


## 只有俯冲时才会挠痒 / 攻击。
func can_act() -> bool:
	return super() and phase == Phase.DIVE


func _start_retreat() -> void:
	phase = Phase.RETREAT
	_phase_t = retreat_time
	if is_instance_valid(target):
		_orbit = (global_position - target.global_position).angle()


func _on_tickle_performed(_t: Node) -> void:
	_start_retreat()


func _on_attack_performed(_t: Node) -> void:
	_start_retreat()


func _animate(_delta: float) -> void:
	sprite.offset.y = -14.0 + roundf(sin(_t * 12.0) * 2.0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
