class_name Monster
extends Actor
## 怪物基类。两种基本行动：
##   attack(target) -> bool   攻击：扣目标血量
##   tickle(target) -> bool   挠痒：累积目标闷笑值（目标需有 LaughMeter）
## AI：闲逛 → 发现敌对目标后追击 → 接触范围（HitArea）内按 stats.tickle_weight 选择攻击或挠痒。
##
## 约定子节点：Sprite、Health、HitArea (Area2D，接触范围，mask 应包含玩家/友军层)
## 子类可重写：_move(dir, speed, delta)、_animate(delta)、_choose_action(target)、
##            _on_attack_performed(target)、_on_tickle_performed(target)、_on_died()

enum State { WANDER, CHASE, HURT }

@export var stats: MonsterStats

@onready var hit_area: Area2D = get_node_or_null("HitArea")

var state := State.WANDER
var target: Actor
var _home := Vector2.ZERO
var _wander_dir := Vector2.ZERO
var _think := 0.0
var _state_time := 0.0
var _action_cd := 0.0
var _last_taunt := -INF
var _t := 0.0


func _setup() -> void:
	if stats == null:
		stats = MonsterStats.new()
	if health:
		health.max_hp = stats.max_hp
		health.fill()
	_home = global_position
	_t = randf() * TAU


func _tick(delta: float) -> void:
	_t += delta
	_state_time += delta
	_action_cd = maxf(_action_cd - delta, 0.0)
	var frozen := GameState.in_dialogue
	match state:
		State.WANDER:
			_think -= delta
			if _think <= 0.0:
				_think = randf_range(0.8, 2.0)
				_wander_dir = Vector2.ZERO if randf() < 0.35 else Vector2.from_angle(randf() * TAU)
				if global_position.distance_to(_home) > 40.0:
					_wander_dir = global_position.direction_to(_home)
			_move(_wander_dir, stats.wander_speed, delta)
			if not frozen:
				target = nearest_hostile(stats.detect_range)
				if target:
					state = State.CHASE
		State.CHASE:
			if not is_instance_valid(target) or not target.is_alive() \
					or global_position.distance_to(target.global_position) > stats.lose_range:
				target = null
				state = State.WANDER
			else:
				_move(global_position.direction_to(target.global_position), stats.chase_speed, delta)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _state_time > stats.hurt_time:
				state = State.CHASE if target else State.WANDER
	if frozen:
		velocity = Vector2.ZERO
	move_and_slide()
	if velocity.x != 0.0:
		facing = velocity.normalized()
	if not frozen and state != State.HURT:
		_try_act()
	_animate(delta)


# ------------------------------------------------------------------ 两个基本行动
## 攻击：扣目标血量。成功返回 true。
func attack(t: Node) -> bool:
	if not Contracts.is_damageable(t):
		return false
	var ok: bool = t.receive_hit(HitData.make_attack(self, stats.attack_damage, stats.attack_knockback))
	if ok:
		_action_cd = stats.attack_cooldown
		_on_attack_performed(t)
	return ok


## 挠痒：累积目标闷笑值（不扣血）。成功返回 true。
func tickle(t: Node) -> bool:
	if not Contracts.is_tickleable(t):
		return false
	var ok: bool = t.receive_hit(HitData.make_tickle(self, stats.tickle_amount))
	if ok:
		_action_cd = stats.tickle_cooldown
		play_tickle_sound()
		maybe_taunt()
		_on_tickle_performed(t)
	return ok


## 按 stats.taunt_chance 概率在头顶冒出回嘴短句（台词在 princess_reactions.json 的 sources[key].taunts）。
func maybe_taunt(force := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not force and (now - _last_taunt < 2.5 or randf() >= stats.taunt_chance):
		return
	var lines := ReactionDB.taunts(stats.reaction_key)
	if lines.is_empty():
		return
	_last_taunt = now
	SpeechBubble.say(self, str(lines.pick_random()), 30.0 * sprite.scale.y if sprite else 30.0)


## 果冻挠痒声（音高由 stats.tickle_pitch 决定）。
func play_tickle_sound(volume_db := -3.0) -> void:
	Audio.play("tickle", volume_db, 0.1, stats.tickle_pitch)


func can_act() -> bool:
	return _action_cd <= 0.0 and not _dead


# ------------------------------------------------------------------ AI
func _try_act() -> void:
	if not can_act() or hit_area == null:
		return
	for body in hit_area.get_overlapping_bodies():
		var a := body as Actor
		if a == null or not a.is_alive() or not Faction.are_hostile(self, a):
			continue
		var first := _choose_action(a)
		var ok := _perform(first, a)
		if not ok:
			ok = _perform("attack" if first == "tickle" else "tickle", a)
		if ok:
			return


## 选择对目标的行动："attack" 或 "tickle"。默认按 stats.tickle_weight 随机。
func _choose_action(t: Actor) -> String:
	if not Contracts.is_tickleable(t):
		return "attack"
	return "tickle" if randf() < stats.tickle_weight else "attack"


func _perform(action: String, t: Actor) -> bool:
	return tickle(t) if action == "tickle" else attack(t)


## 移动方式（子类可重写，例如史莱姆的跳跃）。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	velocity = velocity.move_toward(dir * speed, 400.0 * delta)


func _animate(_delta: float) -> void:
	pass


func _on_attack_performed(_t: Node) -> void:
	pass


func _on_tickle_performed(_t: Node) -> void:
	pass


# ------------------------------------------------------------------ Actor 钩子
func _on_damaged(hit: HitData) -> void:
	Audio.play("hit")
	state = State.HURT
	_state_time = 0.0
	if is_instance_valid(hit.source) and hit.source is Actor:
		target = hit.source


func _on_died() -> void:
	if stats.is_boss:
		GameState.boss_changed.emit(null)
	set_physics_process(false)
	Audio.play("hit")
	Fx.puff(get_parent(), global_position + Vector2(0, -6))
	ItemDrop.roll(stats.drops, get_parent(), global_position)
	GameState.enemy_defeated.emit(self)
	queue_free()
