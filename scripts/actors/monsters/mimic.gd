class_name Mimic
extends Monster
## 宝箱怪：平时伪装成宝箱（每 4~6 秒轻微发抖），不追击、不被魔法吸引。
## 公主按 E 打开 → 现形并抓住她：每 grab_interval 秒挠痒 grab_tickle，连按 grab_presses 次挣脱；
## 挣脱（或被满蓄力魔法僵直）后变成跳着走的普通怪物。被攻击也会直接现形。
## 数值见 data/monsters/mimic.tres（掉落 2 颗薄荷糖 + 金币）。

const CHEST_REGION := Rect2(80, 112, 16, 16)
const MIMIC_REGION := Rect2(128, 112, 16, 16)

@export var grab_tickle := 7.0
@export var grab_interval := 0.5
@export var grab_max_time := 6.0
@export var grab_presses := 8
@export var twitch_interval := Vector2(4.0, 6.0)

var disguised := true
var victim: Actor
var _grab_tick := 0.0
var _twitch := 0.0

@onready var interactable: Interactable = get_node_or_null("Interactable")


func _setup() -> void:
	super()
	_twitch = randf_range(twitch_interval.x, twitch_interval.y)
	sprite.region_rect = CHEST_REGION


func _tick(delta: float) -> void:
	if disguised:
		_t += delta
		velocity = Vector2.ZERO
		if not GameState.in_dialogue:
			_twitch -= delta
			if _twitch <= 0.0:
				_twitch = randf_range(twitch_interval.x, twitch_interval.y)
				_do_twitch()
		move_with_push()
		return
	if is_instance_valid(victim):
		_t += delta
		velocity = Vector2.ZERO
		if not victim.is_alive() or not victim.status or not victim.status.is_grabbed_by(self):
			_end_grab()
		else:
			victim.global_position = global_position + Vector2(0, 5)
			if not GameState.in_dialogue:
				_grab_tick -= delta
			if _grab_tick <= 0.0:
				_grab_tick = grab_interval
				if deliver_tickle(victim, grab_tickle):
					play_tickle_sound()
					maybe_taunt()
		sprite.position.x = roundf(sin(_t * 40.0))
		move_with_push()
		_animate(delta)
		return
	super(delta)


func is_disguised() -> bool:
	return disguised


## 伪装时不会被吟唱吸引。
func exposed_player() -> PlayableCharacter:
	return null if disguised else super()


## 打开"宝箱"。
func on_interact(actor: Node) -> void:
	if not disguised:
		return
	_reveal()
	var a := actor as Actor
	if a and a.can_be_grabbed() and a.status.grab(self, grab_max_time, grab_presses):
		victim = a
		_grab_tick = 0.2
		Audio.play("grab", -2.0, 0.05, 1.2)
		maybe_taunt(true)


func receive_hit(hit: HitData) -> bool:
	if disguised and hit.kind == HitData.Kind.ATTACK:
		_reveal()
	return super(hit)


func _reveal() -> void:
	if not disguised:
		return
	disguised = false
	if interactable:
		interactable.enabled = false
	sprite.region_rect = MIMIC_REGION
	Audio.play("chomp", 0.0)
	flash(Color(1, 0.5, 0.6), 0.3)
	target = GameState.player
	state = State.CHASE
	if stats.is_boss:
		GameState.boss_changed.emit(self)


func _end_grab() -> void:
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	sprite.position.x = 0.0
	_action_cd = 1.2


func _on_stunned(_duration: float) -> void:
	if is_instance_valid(victim):
		_end_grab()


func _do_twitch() -> void:
	Audio.play("chest", -14.0, 0.1, 1.4)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(sprite, "position:x", 1.0, 0.04)
		tw.tween_property(sprite, "position:x", -1.0, 0.04)
	tw.tween_property(sprite, "position:x", 0.0, 0.04)


## 现形后一跳一跳地追。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	var hop := 0.3 + 0.7 * maxf(sin(_t * 7.0), 0.0) if state == State.CHASE else 1.0
	super(dir, speed * hop, delta)


func _animate(_delta: float) -> void:
	if disguised:
		return
	sprite.offset.y = -8.0 - roundf(maxf(sin(_t * 7.0), 0.0) * 3.0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
