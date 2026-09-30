class_name Monster
extends Actor
## 怪物基类。两种基本行动：
##   attack(target) -> bool   攻击：扣目标血量
##   tickle(target) -> bool   挠痒：累积目标闷笑值（目标需有 LaughMeter）
## AI：闲逛 → 发现敌对目标后追击 → 接触范围（HitArea）内按 stats.tickle_weight 选择攻击或挠痒。
## 弱点暴露：公主吟唱魔法时，expose_radius 内的怪物立即锁定她，追击速度 ×EXPOSED_CHASE_MULT
##（挠痒加重由公主一侧的 _tickle_multiplier 处理，陷阱同样生效）。
## stun(秒)：僵直（满蓄力星光爆发），期间不移动不行动。
##
## 约定子节点：Sprite、Health、HitArea (Area2D，接触范围，mask 应包含玩家/友军层)
## 子类可重写：_move(dir, speed, delta)、_animate(delta)、_choose_action(target)、
##            _on_attack_performed(target)、_on_tickle_performed(target)、_on_died()

enum State { WANDER, CHASE, HURT }

const EXPOSED_CHASE_MULT := 1.3
## 是否随机暴击（测试里需要精确数值时关掉；必暴击 / forced_specials 不受影响）。
static var random_specials := true

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
var _stun_left := 0.0


func _setup() -> void:
	buffs_changed.connect(_refresh_buff_mark)
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
	if _stun_left > 0.0 and not frozen:
		_stun_left -= delta
		if _stun_left <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	if not frozen and state != State.HURT:
		var exposed := exposed_player()
		if exposed:
			target = exposed
			state = State.CHASE
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
				var speed := stats.chase_speed * (EXPOSED_CHASE_MULT if is_exposed_target(target) else 1.0)
				_move(global_position.direction_to(target.global_position), speed, delta)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _state_time > stats.hurt_time and _stun_left <= 0.0:
				state = State.CHASE if target else State.WANDER
	if frozen:
		velocity = Vector2.ZERO
	move_with_push()
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
	var ok := deliver_tickle(t, _tickle_amount(t), _force_special(t))
	if ok:
		_action_cd = stats.tickle_cooldown * stat_mul("tickle_cd")
		play_tickle_sound()
		maybe_taunt()
		_on_tickle_performed(t)
	return ok


# ------------------------------------------------------------------ 特殊挠痒（暴击）
## 怪物所有的挠痒都从这里生成（普通挠痒、抓住后的持续挠痒、蛛丝连挠……）：
## 暴击率 = stats.special_chance + 增益 special_chance；目标身上的 forced_specials 优先（必暴击）。
func make_tickle(t: Node, amount: float, force_special := false, kb := 0.0) -> HitData:
	var special := force_special
	if not special and t is Actor and (t as Actor).forced_specials > 0:
		(t as Actor).forced_specials -= 1
		special = true
	if not special and random_specials:
		special = randf() < stats.special_chance + stat_add("special_chance")
	var h := HitData.make_tickle(self, amount * (stats.special_mult if special else 1.0), kb)
	h.special = special
	h.fatigue_mult = stats.fatigue_mult
	return h


## 生成并送出一次挠痒；暴击时播放暴击表现。返回是否挠到。
func deliver_tickle(t: Node, amount: float, force_special := false, kb := 0.0) -> bool:
	var h := make_tickle(t, amount, force_special, kb)
	var ok: bool = t.receive_hit(h)
	if ok and h.special:
		special_feedback(t)
		_on_special_tickle(t)
	return ok


## 暴击的表现：水里果冻抖动的升调音效、目标头上金色「暴击！」、镜头轻震。陷阱的暴击也用它。
static func special_feedback(t: Node) -> void:
	Audio.play("tickle_special", -1.0, 0.04)
	if t is Node2D:
		var b := SpeechBubble.say(t, "暴击！", 36.0)
		if b:
			b.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
			b.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.25))
	if t is PlayableCharacter:
		(t as PlayableCharacter).shake(0.18)


## 子类钩子：这次普通挠痒是否必定暴击（幽灵手套成对时）。
func _force_special(_t: Node) -> bool:
	return false


## 子类钩子：打出暴击后（刺猬、手套、狂热连击等）。
func _on_special_tickle(_t: Node) -> void:
	pass


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
	return _action_cd <= 0.0 and not _dead and _stun_left <= 0.0


# ------------------------------------------------------------------ 弱点暴露 / 僵直
## 正在吟唱且在暴露范围内的敌对公主（没有则 null）。
func exposed_player() -> PlayableCharacter:
	var p := GameState.player
	if is_instance_valid(p) and is_exposed_target(p) and Faction.are_hostile(self, p) \
			and global_position.distance_to(p.global_position) <= p.expose_radius:
		return p
	return null


func is_exposed_target(t: Node) -> bool:
	return is_instance_valid(t) and t is PlayableCharacter and (t as PlayableCharacter).is_channeling()


func stun(duration: float) -> void:
	if _dead:
		return
	_stun_left = maxf(_stun_left, duration)
	state = State.HURT
	_state_time = 0.0
	velocity = Vector2.ZERO
	if sprite:
		sprite.modulate = Color(0.75, 0.85, 1.35)
	_on_stunned(duration)


func is_stunned() -> bool:
	return _stun_left > 0.0


## 头顶的增益标记：有增益时显示第一个增益的图标，上下浮动。
func _refresh_buff_mark() -> void:
	var mark := get_node_or_null("BuffMark") as Sprite2D
	var shown := ""
	for id in buffs:
		if not (buffs[id] as Buff).is_debuff():
			shown = id
			break
	if shown == "":
		if mark:
			mark.queue_free()
		return
	if mark == null:
		mark = Sprite2D.new()
		mark.name = "BuffMark"
		mark.texture = preload("res://assets/generated/buff_icons.png")
		mark.hframes = 6
		mark.z_index = 10
		mark.scale = Vector2(0.75, 0.75)
		add_child(mark)
		var tw := mark.create_tween().set_loops()
		tw.tween_property(mark, "offset:y", -2.0, 0.4)
		tw.tween_property(mark, "offset:y", 0.0, 0.4)
	mark.frame = int(Buff.info(shown).get("icon", 0))
	mark.position = Vector2(0, -24.0 * (sprite.scale.y if sprite else 1.0) - 6.0)


## 子类钩子：被僵直（例如松开抓住的公主）。
func _on_stunned(_duration: float) -> void:
	pass


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
	velocity = velocity.move_toward(dir * speed * stat_mul("speed"), 400.0 * delta)


func _animate(_delta: float) -> void:
	pass


## 这次挠痒的量（子类可按目标状态调整，例如挠脚鼠对动不了的目标加倍）。
func _tickle_amount(_t: Node) -> float:
	return stats.tickle_amount


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
	ItemDrop.roll(stats.drops, get_parent(), global_position, stats.is_boss)
	GameState.enemy_defeated.emit(self)
	queue_free()
