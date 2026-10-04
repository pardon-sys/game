class_name VisionCone
extends Node2D
## 视野扇形（可复用组件，挂在巡逻士兵等节点下）：朝 facing 方向张开 angle 度、远 range 像素。
## 视线被墙（碰撞层 1）挡住；目标在暗处（离最近的光源超过 dark_radius）时视野只有一半；目标躲起来（不可见）时看不见。
## sees(目标) 返回 0（看不见）~ 1（贴脸）；画出来的扇形按射线被墙截断，发现目标时变红。

@export var range_px := 88.0
@export var angle_deg := 70.0
@export var rays := 14
@export var dark_radius := 56.0
@export var color := Color(1.0, 0.95, 0.55, 0.32)
@export var alert_color := Color(1.0, 0.35, 0.35, 0.45)

var facing := Vector2.DOWN
var alerting := false
var _poly: Polygon2D
## 光源（PointLight2D）的位置，由 StealthDirector 收集。
static var lights: Array[Vector2] = []


func _ready() -> void:
	_poly = Polygon2D.new()
	_poly.color = color
	add_child(_poly)


## 目标所在的位置是不是暗处。
static func in_dark(pos: Vector2, radius := 56.0) -> bool:
	if lights.is_empty():
		return false
	for l in lights:
		if l.distance_to(pos) <= radius:
			return false
	return true


func effective_range(target_pos: Vector2) -> float:
	return range_px * (0.5 if in_dark(target_pos, dark_radius) else 1.0)


## 0 = 看不见；否则越近越大（0.35 ~ 1）。
func sees(target: Node2D) -> float:
	if target == null or not is_instance_valid(target) or not target.visible or not target.is_inside_tree():
		return 0.0
	var eye := global_position
	var tp := target.global_position + Vector2(0, -8)
	var d := tp - eye
	var r := effective_range(target.global_position)
	if d.length() > r:
		return 0.0
	if d.length() > 4.0 and absf(facing.angle_to(d)) > deg_to_rad(angle_deg) / 2.0:
		return 0.0
	if _blocked(eye, tp):
		return 0.0
	return clampf(1.0 - d.length() / r, 0.0, 1.0) * 0.65 + 0.35


func _blocked(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	q.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and not (hit.get("collider") is CharacterBody2D)


func _process(_delta: float) -> void:
	if not visible:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(angle_deg) / 2.0
	var space := get_world_2d().direct_space_state
	for i in rays + 1:
		var a := facing.angle() - half + (half * 2.0) * i / rays
		var dir := Vector2.from_angle(a)
		var to := global_position + dir * range_px
		var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
		var hit := space.intersect_ray(q)
		var end: Vector2 = hit["position"] if not hit.is_empty() and not (hit.get("collider") is CharacterBody2D) else to
		pts.append(end - global_position)
	_poly.polygon = pts
	_poly.color = alert_color if alerting else color
