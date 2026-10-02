class_name DusterWall
extends Trap
## 掸子墙（墙面陷阱，ON_STEP）：装在墙格上，沿着墙一排 length 格都藏着鸡毛掸子，探测区是墙前（dir 方向）那一行。
## 有人走进来 → 预警 warn_time（槽上亮红灯）→ 掸子从她进来的那一端开始依次伸出（每格 step_time 秒），
## 扫到她所在的那一格就挠一下（挠痒 tickle，部位：屁股 2、大腿 1）；一排扫完缩回，冷却 cooldown_time 秒。
## 掸子扫得比走路快：顺着走也会被追上，最好看准冷却从它旁边冲刺过去。

const SHEET := preload("res://assets/generated/duster.png")
const WALL_CENTER := Vector2(0, -8)

## 墙朝外的方向（装在下墙就是 up）。
@export var dir := "up"
@export var length := 3
@export var step_time := 0.12

var lane := Vector2.UP
var along := Vector2.RIGHT
var order: Array[int] = []
var sweeps := 0
var _mounts: Array[Sprite2D] = []
var _heads: Array[Sprite2D] = []
var _hit := {}


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	trigger_mode = TriggerMode.ON_STEP
	lane = Trap.dir_vector(dir)
	along = Vector2.RIGHT if lane.x == 0.0 else Vector2.DOWN
	for i in length:
		var m := _part(0)
		m.position = WALL_CENTER + along * 16.0 * i + lane * 6.0
		m.rotation = lane.angle() + PI / 2.0
		_mounts.append(m)
		var h := _part(2)
		h.position = cell_center(i)
		h.rotation = lane.angle()
		h.visible = false
		_heads.append(h)
	var rect := RectangleShape2D.new()
	var span := length * 16.0 - 2.0
	rect.size = Vector2(span, 14) if lane.x == 0.0 else Vector2(14, span)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = WALL_CENTER + lane * 16.0 + along * 8.0 * (length - 1)
	active_time = length * step_time + 0.15


func _part(frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SHEET
	s.hframes = 3
	s.frame = frame
	s.z_index = 2
	add_child(s)
	return s


## 第 i 格探测格的中心（本地坐标）。
func cell_center(i: int) -> Vector2:
	return WALL_CENTER + lane * 16.0 + along * 16.0 * i


## 某个世界坐标在探测区的第几格（不在探测区返回 -1）。
func cell_index(pos: Vector2) -> int:
	var rel := to_local(pos) - cell_center(0)
	if absf(rel.dot(lane)) > 9.0:
		return -1
	var i := roundi(rel.dot(along) / 16.0)
	return i if i >= 0 and i < length else -1


func _on_warn() -> void:
	for m in _mounts:
		m.frame = 1
	Audio.play("locked", -8.0, 0.05, 1.7)
	var start := 0
	for b in _victims():
		var i := cell_index((b as Node2D).global_position)
		if i >= 0:
			start = i
			break
	order.clear()
	for i in length:
		order.append(i if start * 2 < length else length - 1 - i)


func _physics_process(delta: float) -> void:
	super(delta)
	if phase != Phase.ACTIVE or not active or GameState.in_dialogue:
		return
	var k := mini(int(_t / step_time), length - 1)
	for j in k + 1:
		var h := _heads[order[j]]
		if not h.visible:
			h.visible = true
			h.position = cell_center(order[j]) - lane * 8.0
			h.create_tween().tween_property(h, "position", cell_center(order[j]), 0.06)
			Audio.play("swish", -10.0, 0.1, 1.5)
	var cur := order[k]
	for b in _victims():
		var id := (b as Node).get_instance_id()
		if cell_index((b as Node2D).global_position) == cur and int(_hit.get(id, -1)) != k:
			_hit[id] = k
			if b.receive_hit(make_hit()):
				Audio.play("tickle", -6.0, 0.12, tickle_pitch)


func _on_activate() -> void:
	_hit.clear()
	sweeps += 1
	if order.is_empty():
		for i in length:
			order.append(i)


func _apply_effect(_target: Node) -> bool:
	return false


func _on_idle() -> void:
	_retract()


func _on_cooldown() -> void:
	_retract()


func _retract() -> void:
	for m in _mounts:
		m.frame = 0
	for h in _heads:
		h.visible = false
