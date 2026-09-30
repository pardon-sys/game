class_name BrushHedgehog
extends Monster
## 刷刷刺猬：平时走动；公主和它在同一行或同一列（align_tolerance 内）、roll_range 以内时，
## 蜷成球 curl_time 秒，然后沿直线滚过去（roll_speed）。
## 滚中公主：一次必定暴击的挠痒（roll_tickle）+ 击退，然后停下；撞墙 / 撞到别的东西：晕 dizzy_time 秒。
## 蜷缩和滚动时普通攻击打不动（星光爆发、疲倦爆发可以）。

enum Roll { NONE, CURL, ROLL, DIZZY }

@export var roll_range := 120.0
@export var align_tolerance := 10.0
@export var curl_time := 0.5
@export var roll_speed := 160.0
@export var roll_max_time := 1.4
@export var roll_tickle := 7.0
@export var roll_knockback := 150.0
@export var dizzy_time := 1.0
@export var roll_cooldown := 2.5

var roll_state := Roll.NONE
var _roll_t := 0.0
var _roll_dir := Vector2.ZERO
var _roll_cd := 1.0


func _setup() -> void:
	super()
	sprite.hframes = 4


func _tick(delta: float) -> void:
	if roll_state == Roll.NONE:
		if not GameState.in_dialogue:
			_roll_cd -= delta
		super(delta)
		if _roll_cd <= 0.0 and state == State.CHASE and not is_stunned() and not GameState.in_dialogue:
			_check_align()
		return
	_t += delta
	_action_cd = maxf(_action_cd - delta, 0.0)
	if GameState.in_dialogue:
		velocity = Vector2.ZERO
		_animate(delta)
		return
	_roll_t -= delta
	match roll_state:
		Roll.CURL:
			velocity = Vector2.ZERO
			if _roll_t <= 0.0:
				_start_roll()
		Roll.ROLL:
			velocity = _roll_dir * roll_speed
			if _roll_t <= 0.0:
				_stop_roll()
		Roll.DIZZY:
			velocity = Vector2.ZERO
			if _roll_t <= 0.0:
				_stop_roll()
	move_with_push()
	if roll_state == Roll.ROLL:
		_check_roll_hit()
		if roll_state == Roll.ROLL and get_slide_collision_count() > 0:
			_bonk()
	_animate(delta)


func _check_align() -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	var to := target.global_position - global_position
	if to.length() > roll_range or to.length() < 6.0:
		return
	if absf(to.y) <= align_tolerance:
		begin_curl(Vector2(signf(to.x), 0))
	elif absf(to.x) <= align_tolerance:
		begin_curl(Vector2(0, signf(to.y)))


## 蜷缩，curl_time 秒后朝 dir 滚出去。
func begin_curl(dir: Vector2) -> void:
	roll_state = Roll.CURL
	_roll_t = curl_time
	_roll_dir = dir
	velocity = Vector2.ZERO
	Audio.play("roll", -8.0, 0.05, 1.4)


func _start_roll() -> void:
	roll_state = Roll.ROLL
	_roll_t = roll_max_time
	Audio.play("roll", -3.0, 0.05)


func _check_roll_hit() -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	if global_position.distance_to(target.global_position) > 11.0:
		return
	if deliver_tickle(target, roll_tickle, true, roll_knockback):
		play_tickle_sound(-2.0)
		maybe_taunt()
		_on_tickle_performed(target)
	_stop_roll()


## 撞墙（或撞到别的怪物）：晕乎乎。
func _bonk() -> void:
	roll_state = Roll.DIZZY
	_roll_t = dizzy_time
	velocity = Vector2.ZERO
	Audio.play("hit", -6.0, 0.05, 1.6)
	SpeechBubble.say(self, "咕噜……", 24.0)


func _stop_roll() -> void:
	roll_state = Roll.NONE
	_roll_cd = roll_cooldown
	_action_cd = maxf(_action_cd, 0.4)
	state = State.CHASE if is_instance_valid(target) else State.WANDER
	sprite.rotation = 0.0


func is_rolling() -> bool:
	return roll_state in [Roll.CURL, Roll.ROLL]


## 蜷成球时普通攻击被刷毛弹开（爆发类魔法照常打中）。
func receive_hit(hit: HitData) -> bool:
	if is_rolling() and hit.kind == HitData.Kind.ATTACK and not hit.is_burst():
		Audio.play("locked", -4.0, 0.1)
		SpeechBubble.say(self, "叮！", 22.0)
		return false
	return super(hit)


func _on_stunned(_duration: float) -> void:
	if roll_state != Roll.NONE:
		roll_state = Roll.NONE
		_roll_cd = roll_cooldown
		sprite.rotation = 0.0


func _animate(_delta: float) -> void:
	match roll_state:
		Roll.CURL:
			sprite.frame = 2
			sprite.offset.x = roundf(sin(_t * 50.0))
		Roll.ROLL:
			sprite.frame = 3 if int(_t * 12.0) % 2 else 2
			sprite.offset.x = 0.0
		Roll.DIZZY:
			sprite.frame = 0
			sprite.rotation = sin(_t * 12.0) * 0.2
		_:
			sprite.offset.x = 0.0
			sprite.frame = int(_t * 6.0) % 2 if velocity.length() > 5.0 else 0
			if velocity.x != 0.0:
				sprite.flip_h = velocity.x < 0.0
