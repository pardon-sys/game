class_name MachineImp
extends Monster
## 机关小工匠：本身挠痒很弱，但会利用机关——
##   踩机关：看到公主就跑去踩最近的「怪物也能踩」的压力板 / 绊线（monster_switch 组），让连着的陷阱对准公主发动
##   修复：拉杆关掉的陷阱（风扇、传送带、机关……）它会跑去把拉杆拨回来
##   逃跑：被打一下就逃向最近的拉杆，顺手把它拨一下
## 打倒它（血 2）就安全了。数值见 data/monsters/machine_imp.tres。

enum Mode { NORMAL, TO_SWITCH, REPAIR, FLEE }

@export var switch_range := 160.0
@export var lever_range := 240.0
@export var run_speed := 70.0
@export var switch_cooldown := 4.0

var mode := Mode.NORMAL
var goal: Node2D
var _switch_cd := 1.0
var _think_cd := 0.0
var _arrived_t := 0.0
var _flee := false


func _tick(delta: float) -> void:
	if GameState.in_dialogue or not is_alive() or is_stunned():
		super(delta)
		return
	_switch_cd -= delta
	_think_cd -= delta
	if _think_cd <= 0.0:
		_think_cd = 0.4
		_decide()
	if mode == Mode.NORMAL or not is_instance_valid(goal):
		mode = Mode.NORMAL
		super(delta)
		return
	_t += delta
	_state_time += delta
	_action_cd = maxf(_action_cd - delta, 0.0)
	var to := goal.global_position - global_position
	if to.length() <= 6.0:
		velocity = Vector2.ZERO
		_arrive(delta)
	else:
		_move(to.normalized(), run_speed, delta)
	move_with_push()
	if velocity.x != 0.0:
		facing = velocity.normalized()
	_animate(delta)


func _decide() -> void:
	if mode != Mode.NORMAL and is_instance_valid(goal):
		return
	if _flee:
		_flee = false
		var lv := _nearest(levers(), lever_range * 1.5)
		if lv:
			_set_goal(Mode.FLEE, lv)
			return
	var broken := _nearest(levers().filter(func(l): return lever_has_disabled(l)), lever_range)
	if broken:
		_set_goal(Mode.REPAIR, broken)
		return
	var p := GameState.player
	if _switch_cd <= 0.0 and is_instance_valid(p) and p.is_alive() and global_position.distance_to(p.global_position) <= stats.detect_range:
		var sw := _nearest(get_tree().get_nodes_in_group("monster_switch"), switch_range)
		if sw:
			_set_goal(Mode.TO_SWITCH, sw)


func _set_goal(m: Mode, n: Node2D) -> void:
	mode = m
	goal = n
	_arrived_t = 0.0
	if m == Mode.TO_SWITCH:
		SpeechBubble.say(self, "嘿嘿，看我的～", 20.0)
	elif m == Mode.REPAIR:
		SpeechBubble.say(self, "谁把机关关掉了！", 20.0)


func _arrive(delta: float) -> void:
	_arrived_t += delta
	match mode:
		Mode.REPAIR, Mode.FLEE:
			if goal.has_method("on_interact"):
				goal.on_interact(self)
			mode = Mode.NORMAL
		Mode.TO_SWITCH:
			# 站一会儿让压力板 / 绊线触发，然后离开
			if goal is TripwireTrap and _arrived_t < 0.05:
				(goal as TripwireTrap).fire(self)
			if _arrived_t >= 0.4:
				_switch_cd = switch_cooldown
				mode = Mode.NORMAL


static func is_lever(n: Node) -> bool:
	return n.get_script() != null and str(n.get_script().resource_path).ends_with("lever.gd")


func levers() -> Array:
	var lvl := get_tree().get_first_node_in_group("main")
	var root: Node = lvl.get("level") if lvl else get_parent()
	return root.find_children("*", "", true, false).filter(func(n): return is_lever(n)) if root else []


## 这个拉杆管的组里有没有被关掉的陷阱（拨一下就会重新打开）。
static func lever_has_disabled(lever: Node) -> bool:
	for group in str(lever.get("target")).split(",", false):
		for n in lever.get_tree().get_nodes_in_group(group.strip_edges()):
			if n is Trap and not (n as Trap).active and (n as Trap).switch_disables:
				return true
	return false


func _nearest(nodes: Array, max_dist: float) -> Node2D:
	var best: Node2D = null
	var bd := max_dist
	for n in nodes:
		var n2 := n as Node2D
		if n2 == null or not is_instance_valid(n2):
			continue
		var d := global_position.distance_to(n2.global_position)
		if d <= bd:
			bd = d
			best = n2
	return best


func _on_damaged(hit: HitData) -> void:
	super(hit)
	_flee = true
	mode = Mode.NORMAL
	SpeechBubble.say(self, "哇！别打我！", 20.0)


func _animate(_delta: float) -> void:
	var moving := velocity.length() > 5.0
	var run := mode != Mode.NORMAL
	sprite.frame = (2 if run else 0) + (int(_t * (12.0 if run else 6.0)) % 2 if moving else 0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
