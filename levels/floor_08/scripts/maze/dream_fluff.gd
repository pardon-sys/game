class_name DreamFluff
extends Monster
## 梦绒球（第八层夜迷宫）：软绵绵的小绒球，碰到她就粘在大腿上跟着走，每 TICK 秒蹭一下（来源键 dream_fluff）。
## 甩掉：连续冲刺 SHAKE_DASHES 次，或者冰晶结界（maze_magic_reactive：on_ice）。粘着的时候她一直在憋笑。

const SHEET := preload("res://assets/generated/maze/dream_fluff.png")
const TICK := 0.8
const TICKLE := 3.0
const SHAKE_DASHES := 3

var stuck_on: PlayableCharacter
var _tick_t := 0.0
var _dashes := 0
var _was_dashing := false
var _rest := 0.0


func _setup() -> void:
	super()
	add_to_group("maze_magic_reactive")
	sprite.texture = SHEET
	sprite.hframes = 2
	sprite.region_enabled = false


func is_stuck() -> bool:
	return is_instance_valid(stuck_on)


## 碰到她就粘上（代替普通的挠一下）。
func tickle(t: Node) -> bool:
	if _rest > 0.0 or is_stuck() or not (t is PlayableCharacter):
		return super(t)
	stuck_on = t
	_dashes = 0
	_tick_t = 0.0
	collision_layer = 0
	SpeechBubble.say(t, "……粘、粘住了……", 26.0)
	Audio.play("puff", -6.0, 0.1, 1.4)
	return true


func shake_off() -> void:
	if not is_stuck():
		return
	var c := stuck_on
	stuck_on = null
	collision_layer = 4
	_rest = 3.0
	global_position = c.global_position + Vector2(randf_range(-20, 20), 14)
	Fx.burst(get_parent(), global_position, "dust", 6, 30.0, 0.4)
	SpeechBubble.say(c, "……甩、甩掉了。", 26.0)


func on_ice(_time: float) -> void:
	shake_off()
	stun(2.0)


func _tick(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)
	if not is_stuck():
		super(delta)
		return
	_t += delta
	if not stuck_on.is_alive():
		shake_off()
		return
	global_position = stuck_on.global_position + Vector2(6, -2)
	z_index = 1
	var dashing := stuck_on.state == PlayableCharacter.State.DASH
	if dashing and not _was_dashing:
		_dashes += 1
		if _dashes >= SHAKE_DASHES:
			_was_dashing = dashing
			shake_off()
			return
	_was_dashing = dashing
	if GameState.in_dialogue:
		return
	_tick_t += delta
	if _tick_t >= TICK:
		_tick_t = 0.0
		var h := make_tickle(stuck_on, TICKLE)
		h.zone = "thigh"
		stuck_on.receive_hit(h)
	_animate(delta)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 4.0) % 2
