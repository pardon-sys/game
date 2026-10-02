class_name LatchMonster
extends Monster
## 吸附类怪物基类（吸盘章鱼宝宝、毛毛虫、藤壶贝）：靠近公主后扑上去吸住，跟着她走、按自己的节奏一直挠；可以叠好几只。
## 三种状态：自由（普通怪物 AI）→ 扑上（lunge_time 秒的冲刺，碰到就吸住）→ 吸住（host）。
## 甩掉（公主一侧 PlayableCharacter 的 latchers）：
##   连按攻击 / 交互键「抖」：每下给每只吸着的怪物计一次，够 shake_presses 下就掉下来（弹开、晕 shaken_stun 秒）
##   冲刺有 PlayableCharacter.latch_dash_chance 的几率甩掉一只；满蓄力星光爆发、疲倦爆发全部震飞
##   被束缚陷阱 / 怪物抓住、倒下时全部松开（不晕）
## 吸着时公主移速 × host_slow（多只相乘）。掉下来后 relatch_delay 秒内不会再吸。
## anchored = true：不会走动，只在原地等公主路过 lunge_range 以内就弹上去，掉下来后爬回原处（藤壶贝）。
## 子类可重写：_latch_sprite_pos()（吸着时小怪摆在身上的哪里）、_latch_amount()、_on_latch()、_on_detach()、_on_latched_tick(delta)。

@export var shake_presses := 4
@export var latch_tickle := 3.0
@export var latch_interval := 0.6
## 吸着时贴在公主身上的位置（相对脚底）。
@export var latch_offset := Vector2(0, -16)
@export var host_slow := 0.85
@export var lunge_range := 30.0
@export var lunge_speed := 160.0
@export var lunge_time := 0.22
@export var relatch_delay := 2.5
@export var shaken_stun := 1.0
@export var anchored := false

var host: PlayableCharacter
var shakes_left := 0
var _latch_cd := 0.0
var _lunge_t := 0.0
var _lunge_dir := Vector2.ZERO
var _tk := 0.0
var _anchor_set := false


func _tick(delta: float) -> void:
	if anchored and not _anchor_set:
		_anchor_set = true
		_home = global_position  # 放好位置后的第一帧记下原处（生成后才设位置也没关系）
	if host != null:
		_tick_latched(delta)
		return
	_latch_cd = maxf(_latch_cd - delta, 0.0)
	if _lunge_t > 0.0 and not GameState.in_dialogue:
		_lunge_t -= delta
		_t += delta
		velocity = _lunge_dir * lunge_speed
		move_with_push()
		_try_latch_touching()
		_animate(delta)
		return
	super(delta)
	if _can_lunge():
		_lunge_dir = global_position.direction_to(target.global_position)
		_lunge_t = lunge_time
		Audio.play("pop", -8.0, 0.1, 1.4)


func _can_lunge() -> bool:
	if GameState.in_dialogue or is_stunned() or _latch_cd > 0.0 or not can_act():
		return false
	if anchored:
		target = GameState.player
	elif state != State.CHASE:
		return false
	var pc := target as PlayableCharacter
	return pc != null and is_instance_valid(pc) and pc.can_be_latched() \
			and global_position.distance_to(pc.global_position) <= lunge_range


## 扑的过程中碰到了就吸住。
func _try_latch_touching() -> void:
	if hit_area == null:
		return
	for b in hit_area.get_overlapping_bodies():
		var pc := b as PlayableCharacter
		if pc and Faction.are_hostile(self, pc) and pc.can_be_latched():
			latch(pc)
			return


## 碰到公主时：能吸就吸住，否则照常行动。
func _perform(action: String, t: Actor) -> bool:
	var pc := t as PlayableCharacter
	if pc and _latch_cd <= 0.0 and pc.can_be_latched():
		return latch(pc)
	return super(action, t)


func latch(pc: PlayableCharacter) -> bool:
	if host != null or not is_alive() or pc == null or not pc.can_be_latched():
		return false
	host = pc
	shakes_left = shake_presses
	_lunge_t = 0.0
	_tk = 0.25
	velocity = Vector2.ZERO
	_set_collision(false)
	if sprite:
		sprite.z_index = 2
	pc.add_latcher(self)
	Audio.play("pop", -4.0, 0.1, 0.9)
	_on_latch()
	if not GameState.has_flag("hint_latch"):
		GameState.set_flag("hint_latch")
		GameState.notify(ReactionDB.hint("latch"))
	return true


func is_latched() -> bool:
	return host != null and is_instance_valid(host)


func _tick_latched(delta: float) -> void:
	if not is_instance_valid(host) or not host.is_alive():
		detach()
		return
	_t += delta
	global_position = host.global_position + Vector2(0, 0.5)
	if sprite:
		sprite.position = _latch_sprite_pos()
		sprite.flip_h = host.facing.x < 0.0
	if GameState.in_dialogue:
		return
	_on_latched_tick(delta)
	_tk -= delta
	if _tk <= 0.0:
		_tk = latch_interval * stat_mul("tickle_cd")
		if deliver_tickle(host, _latch_amount()):
			play_tickle_sound(-5.0)
			maybe_taunt()
	_animate(delta)


## 被抖了一下：够次数就掉下来。返回是否掉了。
func shake_once() -> bool:
	if host == null:
		return false
	shakes_left -= 1
	if sprite:
		sprite.position.x += [-2.0, 2.0].pick_random()
	if shakes_left <= 0:
		var away := Vector2.from_angle(randf() * TAU)
		detach(away, shaken_stun)
		return true
	return false


## 从公主身上下来。fling ≠ 0 时朝那个方向弹开并晕 stun_time 秒（被抖掉 / 甩掉 / 震飞）；否则只是松开（被抓住、倒下）。
func detach(fling := Vector2.ZERO, stun_time := 0.0) -> void:
	if host == null:
		return
	var h := host
	host = null
	if is_instance_valid(h):
		h.remove_latcher(self)
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.z_index = 0
	_set_collision(true)
	_latch_cd = relatch_delay if fling != Vector2.ZERO else 1.0
	if fling != Vector2.ZERO:
		velocity = fling.normalized() * 140.0
		if stun_time > 0.0:
			stun(stun_time)
			velocity = fling.normalized() * 140.0
		Fx.burst(get_parent(), global_position + Vector2(0, -8), "goo", 5, 30.0, 0.35)
	_on_detach()


func _set_collision(on: bool) -> void:
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", not on)


## anchored：不追人，慢慢爬回原处。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if not anchored:
		super(dir, speed, delta)
		return
	var to := _home - global_position
	velocity = to.normalized() * 30.0 if to.length() > 2.0 else Vector2.ZERO


func _on_died() -> void:
	detach()
	super()


# ------------------------------------------------------------------ 子类钩子
func _latch_sprite_pos() -> Vector2:
	return latch_offset


func _latch_amount() -> float:
	return latch_tickle


func _on_latch() -> void:
	pass


func _on_detach() -> void:
	pass


func _on_latched_tick(_delta: float) -> void:
	pass
