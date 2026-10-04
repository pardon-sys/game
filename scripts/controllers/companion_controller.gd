class_name CompanionController
extends CharacterController
## AI 搭档（双人模式里没被操控的那个公主）。每帧按优先级决定：
##   1. 被抓 / 失控 / 被吸附 / 被绊住：连按挣扎
##   2. 脚下有预警（danger 组：手臂砸地的圈、扫击的线）：往外冲刺躲开
##   3. 搭档倒地：跑过去按住 E 救她（附近小怪太多时先打）
##   4. 导演要她去站压力板（director.plate_for(她)）：走过去站着
##   5. 身边敌人 ≥ 3 个且魔法冷却好了：蓄力 2 档放魔法
##   6. 打范围内最近的敌人（导演说本体 / 手臂能打时优先打它：director.priority_target()）
##   7. 跟在玩家操控的角色身边（2~4 格）

const ATTACK_RANGE := 20.0
const ENGAGE_RANGE := 150.0
const FOLLOW_NEAR := 30.0
const FOLLOW_FAR := 60.0
const ATTACK_INTERVAL := 0.3
const STRUGGLE_INTERVAL := 0.1
const CHANNEL_TIME := 1.3

var _move := Vector2.ZERO
var _pressed := {}
var _held := {}
var _attack_cd := 0.0
var _struggle_cd := 0.0
var _channel := 0.0
var _dash_cd := 0.0
## 最近一次做的决定（测试 / 调试用）：struggle / dodge / revive / plate / magic / attack / follow / idle
var intent := "idle"


func get_move_vector() -> Vector2:
	return _move


func is_action_just_pressed(action: StringName) -> bool:
	return _pressed.has(action)


func is_action_pressed(action: StringName) -> bool:
	return _held.has(action) or _pressed.has(action)


func end_frame() -> void:
	_pressed.clear()


func _me() -> PlayableCharacter:
	return get_parent() as PlayableCharacter


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	_struggle_cd -= delta
	_dash_cd -= delta
	_move = Vector2.ZERO
	var me := _me()
	if me == null or not me.is_alive() or GameState.in_dialogue or Downed.is_downed(me):
		_held.clear()
		intent = "idle"
		return
	# 蓄力中：按住直到 2 档，然后松开
	if _channel > 0.0:
		_channel -= delta
		if _channel <= 0.0 or me.status.is_grabbed():
			_held.erase(&"magic")
			_channel = 0.0
		return
	_held.erase(&"interact")
	if _struggle(me) or _dodge(me) or _revive(me) or _plate(me) or _magic(me) or _attack(me):
		return
	_follow(me)


func _struggle(me: PlayableCharacter) -> bool:
	var stuck: bool = (me.status and me.status.is_grabbed()) or me.state in [PlayableCharacter.State.GRABBED, PlayableCharacter.State.HELPLESS] \
		or me.latch_count() > 0 or me.get("hobbled") == true
	if not stuck:
		return false
	intent = "struggle"
	if _struggle_cd <= 0.0:
		_struggle_cd = STRUGGLE_INTERVAL
		_pressed[&"attack"] = true
	return true


## 脚下的预警（danger 组的节点：meta radius = 圆的半径，或 meta rect = 世界坐标的矩形）。
static func danger_at(tree: SceneTree, pos: Vector2) -> Node2D:
	for d in tree.get_nodes_in_group("danger"):
		if not (d is Node2D) or not d.is_inside_tree():
			continue
		var n := d as Node2D
		if n.has_meta("rect"):
			if (n.get_meta("rect") as Rect2).grow(4.0).has_point(pos):
				return n
		elif pos.distance_to(n.global_position) <= float(n.get_meta("radius", 14.0)) + 6.0:
			return n
	return null


func _dodge(me: PlayableCharacter) -> bool:
	var d := danger_at(get_tree(), me.global_position)
	if d == null:
		return false
	intent = "dodge"
	var away: Vector2
	if d.has_meta("rect"):
		var r: Rect2 = d.get_meta("rect")
		away = Vector2(0, 1 if me.global_position.y > r.get_center().y else -1) if r.size.x > r.size.y \
			else Vector2(1 if me.global_position.x > r.get_center().x else -1, 0)
	else:
		away = (me.global_position - d.global_position)
		if away.length() < 1.0:
			away = Vector2.RIGHT.rotated(randf() * TAU)
	_move = away.normalized()
	if _dash_cd <= 0.0:
		_dash_cd = 0.8
		_pressed[&"dash"] = true
	return true


func _revive(me: PlayableCharacter) -> bool:
	var other := Duo.partner_of(me)
	if other == null or not Downed.is_downed(other):
		return false
	# 身边小怪太多就先打（攻击判断在后面）
	if _enemies_near(me, 36.0) >= 3:
		return false
	intent = "revive"
	var to := other.global_position - me.global_position
	if to.length() > Downed.REVIVE_RANGE - 6.0:
		_move = to.normalized()
	else:
		_held[&"interact"] = true
	return true


func _plate(me: PlayableCharacter) -> bool:
	if Duo.director == null or not Duo.director.has_method("plate_for"):
		return false
	var p: Variant = Duo.director.plate_for(me)
	if not (p is Vector2):
		return false
	intent = "plate"
	var to: Vector2 = (p as Vector2) - me.global_position
	if to.length() > 4.0:
		_move = to.normalized() * (1.0 if to.length() > 12.0 else 0.5)
	return true


func _magic(me: PlayableCharacter) -> bool:
	if not me.is_magic_unlocked() or me.magic_cooldown_left() > 0.0:
		return false
	if _enemies_near(me, 64.0) < 3:
		return false
	intent = "magic"
	_held[&"magic"] = true
	_channel = CHANNEL_TIME
	return true


func _attack(me: PlayableCharacter) -> bool:
	var t := _target(me)
	if t == null:
		return false
	intent = "attack"
	var to := t.global_position - me.global_position
	var reach := ATTACK_RANGE + float(t.get_meta("hit_radius", 0.0))
	if to.length() > reach:
		_move = to.normalized()
	else:
		_move = to.normalized() * 0.15   # 慢慢贴过去（转向它）
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			_pressed[&"attack"] = true
	return true


func _target(me: PlayableCharacter) -> Node2D:
	if Duo.director and Duo.director.has_method("priority_target"):
		var pt: Variant = Duo.director.priority_target()
		if pt is Node2D and is_instance_valid(pt) and (pt as Node2D).global_position.distance_to(me.global_position) < ENGAGE_RANGE * 1.5:
			return pt
	var best: Node2D = null
	var best_d := ENGAGE_RANGE
	for n in get_tree().get_nodes_in_group("enemy"):
		var a := n as Actor
		if a == null or not a.is_alive() or a.get("attackable") == false:
			continue
		var dist := a.global_position.distance_to(me.global_position)
		if dist < best_d:
			best_d = dist
			best = a
	return best


func _enemies_near(me: PlayableCharacter, r: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Actor and e.is_alive() and e.get("attackable") != false and (e as Node2D).global_position.distance_to(me.global_position) <= r:
			n += 1
	return n


func _follow(me: PlayableCharacter) -> void:
	var lead := GameState.player
	if not is_instance_valid(lead) or lead == me:
		intent = "idle"
		return
	var to := lead.global_position - me.global_position
	if to.length() > FOLLOW_FAR:
		_move = to.normalized()
		intent = "follow"
	elif to.length() > FOLLOW_NEAR:
		_move = to.normalized() * 0.6
		intent = "follow"
	else:
		intent = "idle"
