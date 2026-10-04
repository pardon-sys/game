class_name PatrolGuard
extends Node2D
## 巡逻士兵（可复用）：沿路线点来回走（loop = true 时绕圈），到点停下左右张望；身上带一个 VisionCone。
## 听到石子（investigate）→ 走去落点查看几秒 → 回到路线。经过有人躲着的木箱旁边时有几率去检查（StealthDirector.found_hidden）。
## 只有所在地图的 StealthDirector 打开（潜入模式）时才出现。
## 图例：X = guard_patrol path=x,y;x,y;… [loop=true] [wait=1.2] [speed=34] [view_range=88] [view_angle=70]

const SHEET := "res://assets/generated/npcs/guard.png"
const DIR_ROW := {"down": 0, "left": 1, "right": 2, "up": 3}

@export var path := ""
@export var loop := false
@export var wait := 1.2
@export var speed := 34.0
## 听到动静去查看 / 查看完回去时走得快。
@export var investigate_speed := 64.0
@export var view_range := 88.0
@export var view_angle := 70.0
## 经过躲藏点时去检查的几率。
@export var check_chance := 0.35

var points: Array[Vector2] = []
var idx := 0
var step_dir := 1
## walk / wait / investigate / look / return
var state := "walk"
var route: Array[Vector2] = []
var facing := Vector2.DOWN
var cone: VisionCone
var sprite: Sprite2D
var _timer := 0.0
var _anim := 0.0
var _look_base := Vector2.DOWN
var _checked := {}


func _ready() -> void:
	add_to_group("patrol_guard")
	# 视野扇形先加（画在士兵身后）
	cone = VisionCone.new()
	cone.position = Vector2(0, -10)
	cone.range_px = view_range
	cone.angle_deg = view_angle
	add_child(cone)
	sprite = Sprite2D.new()
	if ResourceLoader.exists(SHEET):
		sprite.texture = load(SHEET)
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.offset = Vector2(0, -14)
	add_child(sprite)
	for part in path.split(";", false):
		var xy := part.split(",")
		if xy.size() == 2:
			points.append(GridPath.center(Vector2i(int(xy[0]), int(xy[1]))))
	if not points.is_empty():
		global_position = points[0]
		if points.size() > 1:
			_set_facing(points[1] - points[0])


func _level() -> Node:
	var n: Node = self
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _set_facing(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	facing = v.normalized()
	cone.facing = facing


func _row() -> int:
	if absf(facing.x) > absf(facing.y):
		return DIR_ROW["right"] if facing.x > 0 else DIR_ROW["left"]
	return DIR_ROW["down"] if facing.y > 0 else DIR_ROW["up"]


func _physics_process(delta: float) -> void:
	var d := StealthDirector.current
	var on := d != null and d.is_active() and d.is_ancestor_of_level(self)
	visible = on
	if not on or GameState.in_dialogue or d.caught_done:
		return
	match state:
		"walk":
			if points.size() < 2:
				_look(delta)
			elif _move_to(points[idx], delta):
				state = "wait"
				_timer = wait
				_look_base = facing
		"wait":
			_timer -= delta
			_look(delta)
			if _timer <= 0.0:
				_next_point()
				state = "walk"
		"investigate", "return":
			if route.is_empty():
				if state == "investigate":
					state = "look"
					_timer = 2.5
					_look_base = facing
				else:
					state = "walk"
			elif _move_to(route[0], delta, investigate_speed):
				route.pop_front()
		"look":
			_timer -= delta
			_look(delta)
			if _timer <= 0.0:
				state = "return"
				route = GridPath.find(_level(), global_position, points[idx] if not points.is_empty() else global_position)
	_check_hiding(d)
	sprite.frame = _row() * 4 + (int(_anim * 6.0) % 4 if state in ["walk", "investigate", "return"] else 0)


## 走向 target，到了返回 true。
func _move_to(target: Vector2, delta: float, spd := -1.0) -> bool:
	var v := speed if spd < 0.0 else spd
	var to := target - global_position
	if to.length() <= v * delta + 0.5:
		global_position = target
		return true
	_set_facing(to)
	global_position += to.normalized() * v * delta
	_anim += delta
	return false


func _next_point() -> void:
	if points.size() < 2:
		return
	if loop:
		idx = (idx + 1) % points.size()
		return
	if idx + step_dir >= points.size() or idx + step_dir < 0:
		step_dir = -step_dir
	idx += step_dir


## 停下时左右张望（朝向在原方向 ±50° 之间摆）。
func _look(delta: float) -> void:
	_anim += delta
	var a := _look_base.angle() + sin(_anim * 1.6) * deg_to_rad(50.0)
	facing = Vector2.from_angle(a)
	cone.facing = facing


## 听到动静：走过去看看。
func investigate(pos: Vector2) -> void:
	route = GridPath.find(_level(), global_position, pos)
	state = "investigate"
	SpeechBubble.say(self, "……？", 26.0)


## 看见目标的程度（0 ~ 1）。
func sees(target: Node2D) -> float:
	return cone.sees(target) if visible else 0.0


func _check_hiding(d: StealthDirector) -> void:
	var spot: Node2D = d.hidden_in
	if spot == null or not is_instance_valid(spot) or _checked.has(spot.get_instance_id()):
		return
	if global_position.distance_to(spot.global_position) < 22.0:
		_checked[spot.get_instance_id()] = true
		if randf() < check_chance:
			d.found_hidden(self)
		else:
			SpeechBubble.say(self, "……错觉吗。", 26.0)
