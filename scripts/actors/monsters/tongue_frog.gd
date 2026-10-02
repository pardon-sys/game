class_name TongueFrog
extends Monster
## 长舌蛙：一跳一跳地接近，到 tongue_range 以内就鼓起嘴蓄力 charge_time 秒（预警），然后朝那时公主的方向吐舌头。
## 舌头直着伸出去再缩回（tongue_time），蓄力时方向就定了——侧身走开就能躲。舔中：挠痒 lick_tickle（部位：肚子 3、腰 1），
## 并把人拉近 pull_distance 像素（可能拉进旁边的束缚陷阱）。冷却 tongue_cooldown 秒。
## 追到 hold_distance 以内就停下等舌头冷却（不往脸上凑）；被贴身时照常挠。

enum Lick { NONE, CHARGE, OUT }

@export var tongue_range := 48.0
@export var charge_time := 0.4
@export var tongue_time := 0.12
@export var tongue_cooldown := 1.6
@export var lick_tickle := 6.0
@export var pull_distance := 16.0
## 舌尖离公主多近算舔中（像素）。
@export var lick_radius := 8.0
## 追到这么近就停下来等舌头（像素）。
@export var hold_distance := 28.0

const MOUTH := Vector2(0, -6)
const BODY := Vector2(0, -8)

var lick := Lick.NONE
var lick_dir := Vector2.DOWN
var licked := false
## 舔中的次数。
var licks := 0
var tongue: Line2D
var _lick_t := 0.0
var _lick_cd := 0.8


func _setup() -> void:
	super()
	tongue = Line2D.new()
	tongue.width = 2.0
	tongue.default_color = Color(1.0, 0.45, 0.6)
	tongue.z_index = 3
	tongue.visible = false
	add_child(tongue)


func _tick(delta: float) -> void:
	if lick != Lick.NONE:
		if state == State.HURT or is_stunned() or not is_alive():
			_end_lick()
		elif not GameState.in_dialogue:
			_tick_lick(delta)
			return
	_lick_cd = maxf(_lick_cd - delta, 0.0)
	super(delta)
	var p := target as PlayableCharacter
	if lick == Lick.NONE and _lick_cd <= 0.0 and state == State.CHASE and can_act() and not GameState.in_dialogue \
			and p != null and is_instance_valid(p) and p.is_alive():
		var d := global_position.distance_to(p.global_position)
		if d <= tongue_range:
			lick = Lick.CHARGE
			licked = false
			_lick_t = 0.0
			lick_dir = (global_position + MOUTH).direction_to(p.global_position + BODY)
			velocity = Vector2.ZERO
			Audio.play("pop", -10.0, 0.05, 0.6)


func _tick_lick(delta: float) -> void:
	_t += delta
	_lick_t += delta
	velocity = Vector2.ZERO
	move_with_push()
	match lick:
		Lick.CHARGE:
			sprite.frame = 2
			sprite.scale = Vector2.ONE * (1.0 + _lick_t / charge_time * 0.15)
			if _lick_t >= charge_time:
				lick = Lick.OUT
				_lick_t = 0.0
				licked = false
				sprite.scale = Vector2.ONE
				Audio.play("swish", -4.0, 0.1, 1.6)
		Lick.OUT:
			sprite.frame = 3
			var k := _lick_t / tongue_time
			var length := tongue_range * (k if k <= 1.0 else maxf(2.0 - k, 0.0))
			tongue.visible = true
			tongue.points = PackedVector2Array([MOUTH, MOUTH + lick_dir * length])
			if not licked and k <= 1.2:
				_check_lick(length)
			if k >= 2.0:
				_end_lick()


func _check_lick(length: float) -> void:
	var p := GameState.player
	if not is_instance_valid(p) or not p.is_alive() or not Faction.are_hostile(self, p):
		return
	var a := global_position + MOUTH
	var b := a + lick_dir * length
	var hit_point := p.global_position + BODY
	var closest := Geometry2D.get_closest_point_to_segment(hit_point, a, b)
	if closest.distance_to(hit_point) > lick_radius:
		return
	licked = true
	licks += 1
	if deliver_tickle(p, lick_tickle):
		play_tickle_sound()
		maybe_taunt()
		p.force_move(-lick_dir * pull_distance / 0.15, 0.15, "pull")


func _end_lick() -> void:
	lick = Lick.NONE
	tongue.visible = false
	sprite.scale = Vector2.ONE
	_lick_cd = tongue_cooldown
	_action_cd = maxf(_action_cd, 0.3)


func is_licking() -> bool:
	return lick != Lick.NONE


## 一跳一跳：每 0.6 秒跳一下。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	var hop := 1.8 if fmod(_t, 0.6) < 0.25 else 0.0
	if state == State.CHASE and is_instance_valid(target) and global_position.distance_to(target.global_position) <= hold_distance:
		hop = 0.0
	velocity = velocity.move_toward(dir * speed * hop * stat_mul("speed"), 900.0 * delta)


func _animate(_delta: float) -> void:
	if lick != Lick.NONE:
		return
	sprite.frame = 1 if velocity.length() > 5.0 else 0
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
