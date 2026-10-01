class_name TickleTroll
extends Monster
## 挠痒巨魔（小 Boss）：血厚、移动慢。
##   抓取：抓住公主后每 grab_interval 秒挠痒 grab_tickle；公主连按挣扎 grab_presses 次或 grab_max_time 秒后松开，
##         松开后巨魔僵直 stun_time 秒（反击窗口）。
##   重击：slam_chance 概率蓄力后范围重击（扣血 + 击退）。
##   召唤：一开战就召唤羽毛蝙蝠，之后每 summon_interval 秒补充（最多同时 max_bats 只）；倒下时召唤的蝙蝠一起散掉。

const BAT_SCENE := "res://scenes/actors/monsters/feather_bat.tscn"

enum Mode { NORMAL, WINDUP, GRABBING, STUNNED }

@export var grab_tickle := 8.0
@export var grab_interval := 0.5
@export var grab_max_time := 3.5
@export var grab_presses := 10
@export var stun_time := 1.5
@export var slam_chance := 0.15
@export var slam_damage := 2
@export var slam_radius := 30.0
@export var slam_windup := 0.45
@export var slam_knockback := 220.0
@export var summon_interval := 10.0
@export var max_bats := 2

var mode := Mode.NORMAL
var victim: Actor
var _mode_t := 0.0
var _grab_tick := 0.0
var _announced := false
var _summon_cd := 0.0


func _tick(delta: float) -> void:
	if not _announced and state == State.CHASE:
		_announced = true
		GameState.boss_changed.emit(self)
	if _announced and is_alive() and not GameState.in_dialogue:
		_update_summon(delta)
	match mode:
		Mode.NORMAL:
			super(delta)
			return
		Mode.WINDUP:
			_t += delta
			velocity = Vector2.ZERO
			_mode_t -= delta
			sprite.position.x = roundf(sin(_t * 60.0))
			if _mode_t <= 0.0:
				sprite.position.x = 0.0
				_do_slam()
				mode = Mode.NORMAL
		Mode.GRABBING:
			_t += delta
			velocity = Vector2.ZERO
			if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
				_end_grab()
			else:
				victim.global_position = global_position + Vector2(signf(facing.x if facing.x != 0.0 else 1.0) * 14.0, 3.0)
				if not GameState.in_dialogue:
					_grab_tick -= delta
				if _grab_tick <= 0.0:
					_grab_tick = grab_interval
					if deliver_tickle(victim, grab_tickle):
						play_tickle_sound()
						maybe_taunt()
		Mode.STUNNED:
			_t += delta
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			_mode_t -= delta
			if _mode_t <= 0.0:
				mode = Mode.NORMAL
	move_with_push()
	_animate(delta)


func _update_summon(delta: float) -> void:
	_summon_cd -= delta
	if _summon_cd > 0.0:
		return
	_summon_cd = summon_interval
	var n := max_bats - get_tree().get_nodes_in_group("summoned_bat").size()
	if n <= 0:
		return
	for i in n:
		var b: Monster = load(BAT_SCENE).instantiate()
		b.add_to_group("summoned_bat")
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(-24.0 + 48.0 * i, -20.0)
		b.target = target
		b.state = State.CHASE
		Fx.puff(get_parent(), b.global_position)
	Audio.play("swish", -2.0, 0.05, 0.7)
	SpeechBubble.say(self, "蝙蝠们，扇她！", 40.0)


func _on_died() -> void:
	for b in get_tree().get_nodes_in_group("summoned_bat"):
		if b is Actor and (b as Actor).is_alive():
			(b as Actor).health.damage(99)
	super()


func _choose_action(t: Actor) -> String:
	if not Contracts.is_tickleable(t):
		return "attack"
	return "attack" if randf() < slam_chance else "tickle"


func _perform(action: String, t: Actor) -> bool:
	if action == "attack":
		mode = Mode.WINDUP
		_mode_t = slam_windup
		_action_cd = stats.attack_cooldown + slam_windup
		flash(Color(1, 0.4, 0.3), slam_windup)
		return true
	if t.can_be_grabbed() and t.status.grab(self, grab_max_time, grab_presses):
		mode = Mode.GRABBING
		victim = t
		_grab_tick = 0.15
		Audio.play("grab", -2.0, 0.05, 0.8)
		maybe_taunt(true)
		return true
	return tickle(t)


func is_stunned() -> bool:
	return mode == Mode.STUNNED or super()


## 星光爆发的僵直：打断蓄力重击、松开抓住的人。
func _on_stunned(_duration: float) -> void:
	sprite.position.x = 0.0
	if mode == Mode.GRABBING:
		_end_grab()
	mode = Mode.NORMAL


func _end_grab() -> void:
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	mode = Mode.STUNNED
	_mode_t = stun_time
	_action_cd = stun_time + 0.5
	flash(Color(1, 1, 0.6), 0.4)


func _do_slam() -> void:
	Audio.play("break", 0.0, 0.05, 0.6)
	Fx.puff(get_parent(), global_position + Vector2(0, -4))
	for n in get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a and a.is_alive() and Faction.are_hostile(self, a) and a.global_position.distance_to(global_position) <= slam_radius:
			a.receive_hit(HitData.make_attack(self, slam_damage, slam_knockback))
			if a is PlayableCharacter:
				a.shake(0.3)


func _animate(_delta: float) -> void:
	var s := sin(_t * (6.0 if state == State.CHASE else 3.0)) * 0.05
	sprite.scale = Vector2(2.0 + s, 2.0 - s)
	if velocity.x != 0.0 and mode == Mode.NORMAL:
		sprite.flip_h = velocity.x < 0.0
