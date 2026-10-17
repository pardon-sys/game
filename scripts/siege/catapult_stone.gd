class_name CatapultStone
extends Node2D
## 拆塔投石车扔出去的石头：从 from 沿抛物线飞到 to（time 秒），落地自己删掉（伤害由 EnemyTower._catapult_land 算）。

var from := Vector2.ZERO
var to := Vector2.ZERO
var time := 1.2
var _t := 0.0


func _ready() -> void:
	z_index = 30


func _process(delta: float) -> void:
	if SiegeTools.paused():
		return
	_t += delta
	var k := clampf(_t / maxf(time, 0.01), 0.0, 1.0)
	global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 120.0)
	rotation += delta * 8.0
	queue_redraw()
	if k >= 1.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.45, 0.38, 0.35))
	draw_circle(Vector2(-2, -2), 3.0, Color(0.6, 0.52, 0.48))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color(0.25, 0.2, 0.2), 1.5)
