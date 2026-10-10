class_name CarryLight
extends PointLight2D
## 跟着角色走的冷光（可复用；2.5D 楼层自动挂在操控的角色身上）：冷色、开阴影、有高度（法线光照用）。
## 冷光值（level 0~1）：慢慢下降（drain_time 秒从满到空），光的半径和亮度跟着变小，最暗只剩脚边一圈；
## refill(速度) 在月光灯下补、spend(比例) 放魔法扣、dim(秒) 被吹暗一阵子。drain_time = 0 时不消耗（只是一盏灯）。

signal level_changed(level: float)

const TEX := preload("res://assets/lights/light_soft.tres")
const MIN_SCALE := 0.55
const MAX_SCALE := 1.9

var level := 1.0
## 从满到空的秒数（0 = 不消耗）
var drain_time := 0.0
var _dim_left := 0.0
var _refill := 0.0
## 光圈再缩小的倍率（被蒙住眼 / 看不清时，DarkSense 设）
var squeeze := 1.0


static func attach(host: Node2D, drain := 0.0) -> CarryLight:
	var old := host.get_node_or_null("CarryLight") as CarryLight
	if old:
		old.drain_time = drain
		return old
	var l := CarryLight.new()
	l.name = "CarryLight"
	l.drain_time = drain
	host.add_child(l)
	return l


func _ready() -> void:
	texture = TEX
	color = Color(0.62, 0.8, 1.0)
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	height = 28.0
	position = Vector2(0, -10)
	_apply()


func _process(delta: float) -> void:
	if GameState.in_dialogue:
		return
	var before := level
	if _refill > 0.0:
		level = minf(1.0, level + _refill * delta)
	elif drain_time > 0.0:
		level = maxf(0.0, level - delta / drain_time)
	_refill = 0.0
	_dim_left = maxf(0.0, _dim_left - delta)
	if not is_equal_approx(before, level):
		level_changed.emit(level)
	_apply()


## 这一帧在补光（月光灯下、月光镜光带里调）：每秒补 rate。
func refill(rate: float) -> void:
	_refill = maxf(_refill, rate)


func spend(ratio: float) -> void:
	level = maxf(0.0, level - ratio)
	level_changed.emit(level)


func dim(sec: float) -> void:
	_dim_left = maxf(_dim_left, sec)


func is_dimmed() -> bool:
	return _dim_left > 0.0


## 现在实际的亮度（0~1，被吹暗时只剩一半）。
func brightness() -> float:
	return level * (0.45 if _dim_left > 0.0 else 1.0)


func _apply() -> void:
	var b := brightness()
	texture_scale = lerpf(MIN_SCALE, MAX_SCALE, b) * squeeze
	energy = lerpf(0.35, 0.85, b)
