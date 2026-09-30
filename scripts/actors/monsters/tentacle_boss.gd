class_name TentacleBoss
extends Monster
## 痒痒触手怪（第三层 Boss）：本体不动，血厚（data/monsters/tentacle_boss.tres），遭遇时显示 Boss 血条。
##   触手抽打：目标在 strike_range 内时，每 strike_interval 秒在她脚下标出落点，预警 strike_warn 秒后抽下；
##            打中就抓住并把她拉到身边，多根触手一起挠（每 grab_interval 秒 grab_tickle），连按 grab_presses 次挣脱。
##   满蓄力星光爆发（3 档）：收回所有触手、松手并僵直 magic_stun 秒（MagicReactive）。
##   血量低于一半：召唤羽毛小精灵群（最多同时 max_fairies 群）。
##   死亡时打开 open_on_death 组的 Switchable（Boss 房的门）。

const TENTACLE_TEX := preload("res://assets/generated/tentacle.png")
const MARK_TEX := preload("res://assets/generated/strike_mark.png")
const FAIRY_SCENE := "res://scenes/actors/monsters/fairy_swarm.tscn"

@export var strike_range := 110.0
@export var strike_interval := 2.2
@export var strike_warn := 0.6
@export var strike_hit_radius := 12.0
@export var grab_tickle := 8.0
@export var grab_interval := 0.4
@export var grab_max_time := 6.0
@export var grab_presses := 12
@export var magic_stun := 2.0
@export var summon_interval := 12.0
@export var max_fairies := 2
@export var open_on_death := ""

var victim: Actor
var magic_radius := 16.0
var _strike_cd := 1.5
var _grab_tick := 0.0
var _summon_cd := 0.0
var _announced := false
## 正在预警的落点：[{pos, time, mark}]
var _strikes: Array[Dictionary] = []
## 抓住时缠在公主身上的触手（每根是一串节）
var _wraps: Array[Node2D] = []


func _setup() -> void:
	super()
	add_to_group("magic_reactive")
	sprite.hframes = 2


func _tick(delta: float) -> void:
	_t += delta
	_state_time += delta
	_action_cd = maxf(_action_cd - delta, 0.0)
	velocity = Vector2.ZERO
	var frozen := GameState.in_dialogue
	if _stun_left > 0.0 and not frozen:
		_stun_left -= delta
		if _stun_left <= 0.0:
			sprite.modulate = Color.WHITE
	var p := GameState.player
	if not frozen and is_instance_valid(p) and p.is_alive():
		var d := global_position.distance_to(p.global_position)
		if not _announced and d <= strike_range + 30.0:
			_announced = true
			target = p
			state = State.CHASE
			GameState.boss_changed.emit(self)
		if not is_stunned():
			_update_grab(delta)
			_update_strikes(delta)
			if victim == null and d <= strike_range:
				_strike_cd -= delta
				if _strike_cd <= 0.0 and _strikes.is_empty():
					_strike_cd = strike_interval * (0.7 if health.hp <= health.max_hp / 2 else 1.0)
					_begin_strike(p.global_position)
			_update_summon(delta)
			if victim == null:
				_try_act()
	move_with_push()
	_animate(delta)


# ------------------------------------------------------------------ 触手抽打
func _begin_strike(pos: Vector2) -> void:
	var mark := Sprite2D.new()
	mark.texture = MARK_TEX
	mark.hframes = 2
	mark.z_index = -1
	get_parent().add_child(mark)
	mark.global_position = pos
	_strikes.append({"pos": pos, "time": strike_warn, "mark": mark})
	Audio.play("vine", -6.0, 0.1, 0.7)


func _update_strikes(delta: float) -> void:
	for s in _strikes.duplicate():
		s["time"] -= delta
		var mark: Sprite2D = s["mark"]
		if is_instance_valid(mark):
			mark.frame = int(s["time"] * 10.0) % 2
		if s["time"] <= 0.0:
			_strikes.erase(s)
			_lash(s["pos"])
			if is_instance_valid(mark):
				mark.queue_free()


func _lash(pos: Vector2) -> void:
	_flash_tentacle(pos)
	Audio.play("swish", -2.0, 0.05, 0.8)
	var p := GameState.player
	if is_instance_valid(p) and p.global_position.distance_to(pos) <= strike_hit_radius and victim == null:
		if p.can_be_grabbed() and p.status.grab(self, grab_max_time, grab_presses):
			victim = p
			_grab_tick = 0.3
			Audio.play("grab", -2.0, 0.05, 0.9)
			maybe_taunt(true)
			_make_wraps()


func cancel_strikes() -> void:
	for s in _strikes:
		if is_instance_valid(s["mark"]):
			s["mark"].queue_free()
	_strikes.clear()


func pending_strikes() -> int:
	return _strikes.size()


# ------------------------------------------------------------------ 抓住
func _update_grab(delta: float) -> void:
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		_end_grab()
		return
	# 拉到身边
	var hold := global_position + Vector2(0, 22)
	victim.global_position = victim.global_position.move_toward(hold, 120.0 * delta)
	if GameState.in_dialogue:
		return
	_grab_tick -= delta
	if _grab_tick <= 0.0:
		_grab_tick = grab_interval
		if deliver_tickle(victim, grab_tickle):
			play_tickle_sound()
			maybe_taunt()


func _end_grab() -> void:
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	_strike_cd = strike_interval
	for w in _wraps:
		if is_instance_valid(w):
			w.queue_free()
	_wraps.clear()


func is_grabbing() -> bool:
	return victim != null


# ------------------------------------------------------------------ 魔法 / 僵直 / 召唤
## MagicReactive：满蓄力星光爆发收回触手、松手、僵直。
func on_magic_burst(tier: int, _caster: Node) -> void:
	if tier >= 3 and is_alive():
		cancel_strikes()
		stun(magic_stun)


func stun(duration: float) -> void:
	super(maxf(duration, magic_stun))


func _on_stunned(_duration: float) -> void:
	cancel_strikes()
	if victim:
		_end_grab()


func _update_summon(delta: float) -> void:
	if health.hp > health.max_hp / 2:
		return
	_summon_cd -= delta
	if _summon_cd > 0.0:
		return
	_summon_cd = summon_interval
	var alive := get_tree().get_nodes_in_group("summoned_fairy").size()
	if alive >= max_fairies:
		return
	var f: Monster = load(FAIRY_SCENE).instantiate()
	f.add_to_group("summoned_fairy")
	get_parent().add_child(f)
	f.global_position = global_position + Vector2(randf_range(-30, 30), 30)
	Audio.play("chime", -4.0)
	SpeechBubble.say(self, "小精灵们，来帮忙！", 44.0)


func _on_died() -> void:
	cancel_strikes()
	_end_grab()
	for f in get_tree().get_nodes_in_group("summoned_fairy"):
		if f is Actor and f.is_alive():
			f.health.damage(99)
	if open_on_death != "":
		for n in get_tree().get_nodes_in_group(open_on_death):
			if Contracts.is_switchable(n):
				n.set_active(true)
	super()


# ------------------------------------------------------------------ 表现
func _tentacle_chain(from: Vector2, to: Vector2) -> Node2D:
	var chain := Node2D.new()
	var n := maxi(2, int(from.distance_to(to) / 6.0))
	for i in n + 1:
		var s := Sprite2D.new()
		s.texture = TENTACLE_TEX
		s.hframes = 3
		s.frame = 1 if i == n else (2 if i % 3 == 1 else 0)
		s.position = from.lerp(to, float(i) / n).round()
		chain.add_child(s)
	return chain


## 抽打：一条触手从本体伸到落点，0.25 秒后消失。
func _flash_tentacle(pos: Vector2) -> void:
	var chain := _tentacle_chain(Vector2(0, -10), to_local(pos))
	add_child(chain)
	var tw := chain.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(chain, "modulate:a", 0.0, 0.1)
	tw.tween_callback(chain.queue_free)


## 抓住时 3 根触手缠在公主身边扭动。
func _make_wraps() -> void:
	for i in 3:
		var w := Node2D.new()
		add_child(w)
		_wraps.append(w)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 3.0) % 2
	if is_instance_valid(victim):
		for i in _wraps.size():
			var w := _wraps[i]
			for c in w.get_children():
				c.queue_free()
			var tip := to_local(victim.global_position) + Vector2(cos(_t * 8.0 + i * 2.1) * 8.0, -6.0 + sin(_t * 6.0 + i) * 5.0)
			var chain := _tentacle_chain(Vector2(-12 + i * 12, -6), tip)
			for c in chain.get_children():
				chain.remove_child(c)
				w.add_child(c)
			chain.free()
