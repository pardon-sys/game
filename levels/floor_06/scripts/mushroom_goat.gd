class_name MushroomGoat
extends Resident
## 委托「赶蘑菇羊回圈」里的蘑菇羊（头上顶着蘑菇伞的小羊）。只管走：玩法逻辑在 ErrandGoats 里。
##   goal_node / goal_pos：要跟着的东西（公主、前一只羊）或者要去的地方；spacing：跟到离它多远停下。
##   mode：WANDER 在 home 附近溜达 / FOLLOW 跟着 goal_node / GOTO 去 goal_pos / FLEE 躲着公主跑（小羊羔叼鞋的时候）/ STAY 原地不动。
##   离目标太远（> GHOST_DIST）时不撞东西，免得被房子卡住跟丢。

enum Mode { WANDER, FOLLOW, GOTO, FLEE, STAY }

const RUN := 60.0
const FLEE_SPEED := 58.0
const FLEE_RUN := 1.8
const FLEE_REST := 1.1
const GHOST_DIST := 56.0
const BOUNDS := Rect2(3 * 16, 3 * 16, 58 * 16, 37 * 16)

var gid := ""
var temper := "calm"
var mode := Mode.WANDER
var goal_node: Node2D
var goal_pos := Vector2.ZERO
var spacing := 14.0
var _flee_t := 0.0


static func spawn(parent: Node, at: Vector2, id: String, tr: String) -> MushroomGoat:
	var g: MushroomGoat = load("res://levels/floor_06/scenes/mushroom_goat.tscn").instantiate()
	g.npc_id = "goat"
	g.dialogue = ""
	g.wander = 1.5
	g.speed = 18.0
	g.gid = id
	g.temper = tr
	g.name = "Goat_" + id
	parent.add_child(g)
	g.global_position = at
	g._home = at
	g._goal = at
	return g


func set_home(at: Vector2) -> void:
	_home = at
	_goal = at


func _tick(delta: float) -> void:
	_t += delta
	if GameState.in_dialogue or GameState.in_cutscene:
		velocity = Vector2.ZERO
		_animate(delta)
		return
	match mode:
		Mode.WANDER:
			collision_mask = 1
			super(delta)
			return
		Mode.FOLLOW:
			if is_instance_valid(goal_node):
				_go(goal_node.global_position, RUN, spacing)
		Mode.GOTO:
			_go(goal_pos, RUN, 2.0)
		Mode.FLEE:
			_flee(delta)
		Mode.STAY:
			velocity = Vector2.ZERO
	move_and_slide()
	_animate(delta)


func _go(to: Vector2, spd: float, stop: float) -> void:
	var d := to - global_position
	collision_mask = 0 if d.length() > GHOST_DIST else 1
	if d.length() <= stop:
		velocity = Vector2.ZERO
		return
	velocity = d.normalized() * minf(spd, d.length() * 4.0)
	facing = d.normalized()


## 小羊羔叼着鞋躲着公主跑：跑一会儿歇一会儿（歇的时候追得上）
func _flee(delta: float) -> void:
	collision_mask = 1
	var p := GameState.player
	velocity = Vector2.ZERO
	if not is_instance_valid(p):
		return
	_flee_t -= delta
	if _flee_t <= -FLEE_REST:
		_flee_t = FLEE_RUN
	var d := global_position - p.global_position
	if _flee_t > 0.0 and d.length() < 80.0:
		var dir := d.normalized() if d.length() > 0.1 else Vector2.RIGHT
		# 别跑出镇子：贴边时沿着边跑
		var next := global_position + dir * 16.0
		if not BOUNDS.has_point(next):
			dir = Vector2(dir.y, -dir.x) if BOUNDS.has_point(global_position + Vector2(dir.y, -dir.x) * 16.0) else -dir
		velocity = dir * FLEE_SPEED
		facing = dir
	if get_slide_collision_count() > 0 and velocity != Vector2.ZERO:
		velocity = velocity.rotated(PI / 2)
