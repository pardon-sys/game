class_name CompanionController
extends CharacterController
## AI 搭档（可复用组件：双人模式里没被操控的那个公主；以后别的 Boss 战也能直接用）。
## 和具体战斗的联系只通过 hooks（BattleAIHooks：安全点 / 目标点 / 优先目标 / 魔法目标 / 搭档），默认读 Duo.hooks；
## behaviours 决定开哪些行为、按什么优先级（按顺序，第一个「接手」的行为决定这一帧做什么）：
##   struggle   被抓 / 失控 / 被吸附 / 被绊住：连按挣扎
##   safe       导演给了安全点（Boss 大招）：跑进去，远的话冲刺
##   dodge      危险（danger 组：meta radius 的圈 / meta rect 的矩形，meta velocity = 正在冲过来的东西）在脚下或快碰到：
##              往远离圈心 / 矩形外 / 垂直于冲来方向的一侧冲刺（冲刺冷却中就跑开）
##   revive     搭档倒地：跑过去按住 E 救她（附近小怪太多时先打）
##   objective  导演给了目标点（压力板）：走过去站着
##   magic      魔法冷却好了且（身边敌人 ≥ 3 个，或 hooks.magic_target 够得着；玩家在吟唱时有 JOIN_CHANCE 几率一起）：
##              先往离敌人远的方向退到安全距离（SAFE_GAP 内没有敌人，最多 RETREAT_MAX 秒），再吟唱到 2 档松开；
##              吟唱被打断时强制放出当前档位（PlayableCharacter.interrupt_channel 里处理）
##   attack     打范围内最近的敌人（hooks.priority_target 优先）
##   follow     跟在玩家操控的角色身边（2~4 格）

const ALL_BEHAVIOURS: Array[String] = ["struggle", "safe", "dodge", "revive", "objective", "magic", "attack", "follow"]
## 危险快碰到时就躲（圈 / 矩形外扩这么多像素）
const DODGE_MARGIN := 10.0
const ATTACK_RANGE := 20.0
const ENGAGE_RANGE := 150.0
const FOLLOW_NEAR := 30.0
const FOLLOW_FAR := 60.0
const ATTACK_INTERVAL := 0.3
const STRUGGLE_INTERVAL := 0.1
const CHANNEL_TIME := 1.1
const SAFE_GAP := 48.0
const RETREAT_MAX := 1.5
const JOIN_CHANCE := 0.4

## 开哪些行为（按优先级）；别的战斗可以去掉不需要的
var behaviours: Array[String] = ALL_BEHAVIOURS.duplicate()
## 导演提示；null = 用 Duo.hooks（也没有就什么提示都没有）
var hooks: BattleAIHooks
var _move := Vector2.ZERO
var _pressed := {}
var _held := {}
var _attack_cd := 0.0
var _struggle_cd := 0.0
var _channel := 0.0
var _dash_cd := 0.0
## 准备放魔法：先退开的剩余时间（>0 = 正在退）
var _retreat := 0.0
## 玩家这次吟唱我们有没有决定过要不要一起
var _joined_decided := false
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
	for b in behaviours:
		if _run(b, me):
			return


static var _no_hooks := BattleAIHooks.new()


func _hooks() -> BattleAIHooks:
	if hooks:
		return hooks
	return Duo.hooks if Duo.hooks else _no_hooks


func _run(b: String, me: PlayableCharacter) -> bool:
	match b:
		"struggle": return _struggle(me)
		"safe": return _safe(me)
		"dodge": return _dodge(me)
		"revive": return _revive(me)
		"objective": return _plate(me)
		"magic": return _magic(me)
		"attack": return _attack(me)
		"follow":
			_follow(me)
			return true
	return false


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
static func danger_at(tree: SceneTree, pos: Vector2, margin := 0.0) -> Node2D:
	for d in tree.get_nodes_in_group("danger"):
		if not (d is Node2D) or not d.is_inside_tree():
			continue
		var n := d as Node2D
		if n.has_meta("rect"):
			if (n.get_meta("rect") as Rect2).grow(4.0 + margin).has_point(pos):
				return n
		elif pos.distance_to(n.global_position) <= float(n.get_meta("radius", 14.0)) + 6.0 + margin:
			return n
	return null


func _safe(me: PlayableCharacter) -> bool:
	var s: Variant = _hooks().safe_spot_for(me)
	if not (s is Vector2):
		return false
	intent = "dodge"
	var to: Vector2 = (s as Vector2) - me.global_position
	if to.length() > 6.0:
		_move = to.normalized()
		if to.length() > 60.0 and _dash_cd <= 0.0:
			_dash_cd = 0.8
			_pressed[&"dash"] = true
	return true


func _dodge(me: PlayableCharacter) -> bool:
	# 预判：快碰到（外扩 DODGE_MARGIN）就躲；正在冲过来的东西（meta velocity）看得更远
	var d := danger_at(get_tree(), me.global_position, DODGE_MARGIN)
	if d == null:
		d = _incoming(me)
	if d == null:
		return false
	intent = "dodge"
	var away: Vector2
	if d.has_meta("velocity") and (d.get_meta("velocity") as Vector2).length() > 1.0:
		# 冲过来的：往垂直于它来向、离它路线远的一侧闪开
		var v: Vector2 = (d.get_meta("velocity") as Vector2).normalized()
		var side := v.orthogonal()
		away = side if side.dot(me.global_position - d.global_position) >= 0.0 else -side
	elif d.has_meta("rect"):
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


## 正朝她冲过来的危险（meta velocity）：0.6 秒内会经过她身边的。
func _incoming(me: PlayableCharacter) -> Node2D:
	for d in get_tree().get_nodes_in_group("danger"):
		var n := d as Node2D
		if n == null or not n.has_meta("velocity"):
			continue
		var v: Vector2 = n.get_meta("velocity")
		if v.length() < 1.0:
			continue
		var rel := me.global_position - n.global_position
		var t := clampf(rel.dot(v) / v.length_squared(), 0.0, 0.6)
		if (n.global_position + v * t).distance_to(me.global_position) <= float(n.get_meta("radius", 14.0)) + DODGE_MARGIN:
			return n
	return null


func _revive(me: PlayableCharacter) -> bool:
	var other := _hooks().partner_of(me)
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
	var p: Variant = _hooks().objective_for(me)
	if not (p is Vector2):
		return false
	intent = "plate"
	var to: Vector2 = (p as Vector2) - me.global_position
	if to.length() > 4.0:
		_move = to.normalized() * (1.0 if to.length() > 12.0 else 0.5)
	return true


func _magic(me: PlayableCharacter) -> bool:
	if not me.is_magic_unlocked() or me.magic_cooldown_left() > 0.0:
		_retreat = 0.0
		return false
	# 正在退到安全距离：退够了（或时间到）就开始吟唱
	if _retreat > 0.0:
		_retreat -= get_physics_process_delta_time()
		var near := _nearest_enemy(me, SAFE_GAP)
		if near == null or _retreat <= 0.0:
			_retreat = 0.0
			_start_channel()
		else:
			_move = (me.global_position - near.global_position).normalized()
		intent = "magic"
		return true
	# 玩家在吟唱：有几率一起吟唱（每次玩家吟唱只决定一次）
	var lead := GameState.player
	var lead_channeling := is_instance_valid(lead) and lead != me and lead.is_channeling()
	if not lead_channeling:
		_joined_decided = false
	elif not _joined_decided:
		_joined_decided = true
		if randf() < JOIN_CHANCE:
			intent = "magic"
			_start_channel()
			return true
	# 导演说有值得放魔法的目标（例如蓝色公主够得着 Boss 本体——冻住它）
	var freeze_boss: bool = _hooks().magic_target(me) is Node2D
	if _enemies_near(me, 64.0) < 3 and not freeze_boss:
		return false
	intent = "magic"
	# 冻 Boss 不用退（要够得着它）；被小怪围着时先退开
	if freeze_boss or _nearest_enemy(me, SAFE_GAP) == null:
		_start_channel()
	else:
		_retreat = RETREAT_MAX
	return true


func _start_channel() -> void:
	# 角色在「刚按下」时开始吟唱，按住期间蓄力
	_pressed[&"magic"] = true
	_held[&"magic"] = true
	_channel = CHANNEL_TIME


func _nearest_enemy(me: PlayableCharacter, r: float) -> Node2D:
	var best: Node2D = null
	var best_d := r
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Actor and e.is_alive() and e.get("attackable") != false:
			var d := (e as Node2D).global_position.distance_to(me.global_position)
			if d <= best_d:
				best_d = d
				best = e
	return best


func _attack(me: PlayableCharacter) -> bool:
	var t := _target(me)
	if t == null:
		return false
	intent = "attack"
	# 大型 Boss：走到本体正下方贴近打（本体碰撞形状在节点上方）
	var aim := t.global_position
	if t.has_method("aim_point"):
		aim = t.global_position + Vector2(clampf(me.global_position.x - t.global_position.x, -40.0, 40.0), 14.0)
	var to := aim - me.global_position
	var reach := ATTACK_RANGE + float(t.get_meta("hit_radius", 0.0))
	if t.has_method("aim_point"):
		reach = 6.0
	if to.length() > reach:
		_move = to.normalized()
	else:
		var face := (t.global_position - me.global_position) if t.has_method("aim_point") else to
		_move = face.normalized() * 0.15   # 慢慢贴过去（转向它）
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			_pressed[&"attack"] = true
	return true


func _target(me: PlayableCharacter) -> Node2D:
	var pt: Variant = _hooks().priority_target()
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
