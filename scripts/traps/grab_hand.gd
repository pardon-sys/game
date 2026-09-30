class_name GrabHand
extends Trap
## 机关手：装在墙面上，由压力板触发（MANUAL，Triggerable）。
## 伸出后抓住前方一格内的目标，每 grab_interval 秒挠痒 grab_tickle；目标连按挣扎或超时后松开，缩回并冷却。

## 压力板的 target 与此相同即可触发。
@export var group_name := "hand1"
@export var grab_tickle := 6.0
@export var grab_interval := 0.5
@export var grab_max_time := 3.0
@export var grab_presses := 8

@onready var sprite: Sprite2D = $Sprite

var victim: Actor
var _grab_tick := 0.0


func _setup() -> void:
	trigger_mode = TriggerMode.MANUAL
	hit_kind = HitData.Kind.TICKLE
	add_to_group(group_name)


func _physics_process(delta: float) -> void:
	super(delta)
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		victim = null
		sprite.frame = 1
		_enter(Phase.COOLDOWN)
		return
	victim.global_position = global_position + Vector2(0, 14)
	if GameState.in_dialogue:
		return
	_grab_tick -= delta
	if _grab_tick <= 0.0:
		_grab_tick = grab_interval
		if victim.receive_hit(HitData.make_tickle(self, grab_tickle)):
			Audio.play("tickle", -4.0, 0.12, tickle_pitch)


## ACTIVE 期间：抓住第一个能抓的目标（抓住后停在 ACTIVE 直到松开）。
func _apply_effect(target: Node) -> bool:
	if victim != null or not (target is Actor) or not target.can_be_grabbed():
		return false
	if target.status.grab(self, grab_max_time, grab_presses):
		victim = target
		_grab_tick = 0.1
		sprite.frame = 2
		active_time = grab_max_time + 1.0
		Audio.play("grab", -3.0, 0.05, 1.1)
		return true
	return false


func _on_idle() -> void:
	sprite.frame = 0
	z_index = 0


func _on_warn() -> void:
	sprite.frame = 1
	z_index = 1


func _on_activate() -> void:
	sprite.frame = 1
	active_time = 0.6


func _on_cooldown() -> void:
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	sprite.frame = 0
	z_index = 0
