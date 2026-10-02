class_name MudTrap
extends RestraintTrap
## 痒痒泥沼（多格：从所在格向右 tiles_w、向下 tiles_h）：走进去 sink_time 秒内越陷越慢，陷到膝盖就被困住
## （lock_time 秒，连按挣脱）；泥里的软须挠脚心和小腿；风扇、活塞推不动陷住的人。露出部位：脚心 + 大腿 ×1.3。

const SHEET := preload("res://assets/generated/mud.png")

@export var tiles_w := 1
@export var tiles_h := 1
@export var sink_time := 1.0

## 每个人在泥里待了多久：{instance_id: 秒}
var _sink := {}
var _tiles: Array[Sprite2D] = []


func _restraint_setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	for y in tiles_h:
		for x in tiles_w:
			var s := Sprite2D.new()
			s.texture = SHEET
			s.hframes = 2
			s.position = Vector2(x, y) * 16.0
			s.frame = (x + y) % 2
			add_child(s)
			_tiles.append(s)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_w * 16.0 - 2.0, tiles_h * 16.0 - 2.0)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = Vector2(tiles_w - 1, tiles_h - 1) * 8.0
	Fx.emitter(self, "goo", 2 * tiles_w * tiles_h, 1.6, {"offset": shape.position, "extents": rect.size / 2.0 - Vector2(2, 2),
			"speed": [1.0, 4.0], "spread": 20.0, "color": Color(1, 0.6, 0.85), "z": 0})


var _hold_at := Vector2.ZERO


func _hold_point() -> Vector2:
	return _hold_at


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if a == null or victim != null or a.status == null:
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_immune.get(a.get_instance_id(), -INF)):
		return false
	var id := a.get_instance_id()
	_sink[id] = float(_sink.get(id, 0.0)) + get_physics_process_delta_time()
	var k := clampf(float(_sink[id]) / sink_time, 0.0, 1.0)
	a.status.apply_slow(1.0 - 0.75 * k, 0.15)
	if k < 1.0:
		return false
	_sink.erase(id)
	_hold_at = a.global_position
	return super(target)


func _physics_process(delta: float) -> void:
	super(delta)
	# 离开泥沼的人下沉计时清零
	for id in _sink.keys():
		var still := false
		for b in get_overlapping_bodies():
			still = still or b.get_instance_id() == id
		if not still:
			_sink.erase(id)


func _on_restrain(_a: Actor) -> void:
	Audio.play("puddle", -2.0, 0.05, 0.6)


func _process(delta: float) -> void:
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		for s in _tiles:
			s.frame = 1 - s.frame
