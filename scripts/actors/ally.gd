class_name Ally
extends Actor
## 友军基类。三种行为（可重写）：
##   follow(leader, delta)  跟随领队（默认是玩家角色）
##   engage(enemy, delta)   攻击附近的敌人
##   assist(leader, delta)  领队闷笑值过高时靠近并帮她平复（降低闷笑值）
## 优先级：assist > engage > follow。_choose_behavior() 可重写以改变优先级。
## 友军默认没有 LaughMeter，所以不会被挠痒（需要的话在场景里加一个 Laugh 节点即可）。

signal assisted(leader: Actor)

enum Behavior { FOLLOW, ENGAGE, ASSIST }

@export var stats: AllyStats

var leader: Actor
var enemy: Actor
var behavior := Behavior.FOLLOW
var _attack_cd := 0.0
var _assist_cd := 0.0
var _hurt := 0.0


func _setup() -> void:
	if stats == null:
		stats = AllyStats.new()
	if health:
		health.max_hp = stats.max_hp
		health.fill()


func _tick(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_assist_cd = maxf(_assist_cd - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	if not is_instance_valid(leader):
		leader = GameState.player
	if GameState.in_dialogue or _hurt > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	else:
		behavior = _choose_behavior()
		match behavior:
			Behavior.ASSIST: assist(leader, delta)
			Behavior.ENGAGE: engage(enemy, delta)
			_: follow(leader, delta)
	move_with_push()
	if velocity.length() > 1.0:
		facing = velocity.normalized()
	_animate(delta)


func _choose_behavior() -> Behavior:
	if leader and leader.is_alive() and leader.laugh and leader.laugh.ratio() > stats.assist_threshold_ratio:
		return Behavior.ASSIST
	var center := leader.global_position if leader else global_position
	enemy = null
	var e := nearest_hostile(stats.engage_range)
	if e and e.global_position.distance_to(center) <= stats.engage_range:
		enemy = e
		return Behavior.ENGAGE
	return Behavior.FOLLOW


# ------------------------------------------------------------------ 三种行为
func follow(target: Actor, _delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	_move_to(target.global_position, stats.follow_distance)


func engage(target: Actor, _delta: float) -> void:
	if target == null:
		return
	if global_position.distance_to(target.global_position) > stats.attack_range:
		_move_to(target.global_position, stats.attack_range * 0.8)
	else:
		velocity = Vector2.ZERO
		if _attack_cd <= 0.0 and target.receive_hit(HitData.make_attack(self, stats.attack_damage, stats.attack_knockback)):
			_attack_cd = stats.attack_cooldown
			_on_attack_performed(target)


func assist(target: Actor, _delta: float) -> void:
	if target == null or target.laugh == null:
		return
	if global_position.distance_to(target.global_position) > stats.assist_range:
		_move_to(target.global_position, stats.assist_range * 0.7)
	else:
		velocity = Vector2.ZERO
		if _assist_cd <= 0.0:
			_assist_cd = stats.assist_cooldown
			target.laugh.reduce_ratio(stats.assist_ratio)
			assisted.emit(target)
			_on_assist_performed(target)


func _move_to(pos: Vector2, stop_distance: float) -> void:
	if global_position.distance_to(pos) <= stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(pos) * stats.move_speed


# ------------------------------------------------------------------ 钩子
func _animate(_delta: float) -> void:
	pass


func _on_attack_performed(_target: Actor) -> void:
	pass


func _on_assist_performed(_target: Actor) -> void:
	pass


func _on_damaged(_hit: HitData) -> void:
	_hurt = 0.25
	Audio.play("hurt", -6.0)


func _on_died() -> void:
	Fx.puff(get_parent(), global_position + Vector2(0, -6))
	queue_free()
