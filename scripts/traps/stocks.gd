class_name Stocks
extends Trap
## 足枷台（ON_STEP，拘束）：踩上去木枷"咔哒"合上锁住脚（抓取 lock_time 秒，连按 lock_presses 次挣脱），
## 下面的羽毛滚轮每 roll_interval 秒挠脚心 roll_tickle。
## 到时间还没挣脱：松开前最后一下必定暴击（roll_tickle × 2，暴击表现和公主的暴击台词）。
## 触发范围多 reach 格（走到相邻格就被拉过去，隔墙不会，见 TrapReach）；放开后 regrab_delay 秒内不会再锁同一个人。

@export var lock_time := 3.0
@export var lock_presses := 6
@export var roll_tickle := 4.0
@export var roll_interval := 0.4
@export var reach := 1
@export var regrab_delay := 1.5

var victim: Actor
var _roll_t := 0.0
var _pulling := false
var _immune := {}

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	stops_slide = true
	hit_kind = HitData.Kind.TICKLE
	TrapReach.expand(self, reach)


func _victims() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	return super().filter(func(b): return now >= float(_immune.get(b.get_instance_id(), -INF)) and TrapReach.can_reach(self, b))


func _physics_process(delta: float) -> void:
	super(delta)
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		_unlock()
		return
	if _pulling:
		_pulling = not TrapReach.pull(victim, global_position + Vector2(0, 4), delta)
	else:
		victim.global_position = global_position + Vector2(0, 4)
	# 组合技可能延长了锁定时间：锁着的时候 ACTIVE 阶段不能先结束
	active_time = maxf(active_time, _t + victim.status.grab_time_left() + 0.5)
	if GameState.in_dialogue:
		return
	_roll_t -= delta
	if _roll_t <= 0.0:
		_roll_t = roll_interval
		if victim.receive_hit(make_hit()):
			Audio.play("tickle", -5.0, 0.12, tickle_pitch)


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if victim != null or a == null or not a.can_be_grabbed():
		return false
	if not a.status.grab(self, lock_time, lock_presses):
		return false
	victim = a
	_roll_t = 0.25
	_pulling = a.global_position.distance_to(global_position + Vector2(0, 4)) > 3.0
	if _pulling:
		TrapReach.pull_fx(self, a)
	active_time = lock_time + 1.0
	a.status.released.connect(_on_released, CONNECT_ONE_SHOT)
	sprite.frame = 1
	Audio.play("stocks", -2.0, 0.05)
	Fx.burst(get_parent(), global_position + Vector2(0, -4), "chip", 8, 45.0, 0.45)
	return true


func make_hit() -> HitData:
	var h := super()
	h.tickle = roll_tickle
	return h


## 到时间松开（没挣脱）：最后一下必定暴击。
func _on_released(src: Node, broke_free: bool) -> void:
	if src != self or broke_free or not is_instance_valid(victim) or not victim.is_alive():
		return
	var h := make_hit()
	h.tickle *= 2.0
	h.special = true
	if victim.receive_hit(h):
		Monster.special_feedback(victim)


func is_locking() -> bool:
	return victim != null


func _unlock() -> void:
	if is_instance_valid(victim) and victim.status:
		if victim.status.released.is_connected(_on_released):
			victim.status.released.disconnect(_on_released)
		if victim.status.is_grabbed_by(self):
			victim.status.release(false)
		_immune[victim.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + regrab_delay
	victim = null
	_pulling = false
	sprite.frame = 0
	Audio.play("stocks", -8.0, 0.05, 1.3)
	_enter(Phase.COOLDOWN)


func _on_idle() -> void:
	sprite.frame = 0


func _on_cooldown() -> void:
	if victim != null:
		_unlock()
	sprite.frame = 0
