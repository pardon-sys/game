class_name ExitGlow
extends Node2D
## 出口的微光（第八层夜迷宫；导演在每个出口 / 最终出口放一个）：一盏柔和的蓝白光、地上一圈慢慢呼吸的光环、往上飘的光点。
## 远远就能看到「那边是出口」。

const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")

var light: PointLight2D
var _t := 0.0


func _ready() -> void:
	add_to_group("exit_glow")
	z_index = -1
	light = PointLight2D.new()
	light.texture = LIGHT_TEX
	light.texture_scale = 1.5
	light.energy = 0.7
	light.color = Color(0.75, 0.88, 1.0)
	light.height = 24.0
	light.position = Vector2(0, -8)
	add_child(light)
	var motes := Fx.emitter(self, "snow", 10, 1.6, {"offset": Vector2(0, -2), "extents": Vector2(7, 3), "dir": Vector2.UP,
		"spread": 10.0, "speed": [8.0, 16.0], "color": Color(0.85, 0.95, 1.0, 0.9), "z": 3})
	motes.emitting = true


func _process(delta: float) -> void:
	_t += delta
	light.energy = 0.65 + 0.1 * sin(_t * 2.0)
	queue_redraw()


func _draw() -> void:
	var k := 0.5 + 0.5 * sin(_t * 2.0)
	draw_set_transform(Vector2(0, 2), 0.0, IsoView.ground_scale())
	draw_circle(Vector2.ZERO, 9.0, Color(0.7, 0.85, 1.0, 0.18 + 0.08 * k))
	draw_arc(Vector2.ZERO, 10.0 + k * 2.0, 0, TAU, 32, Color(0.85, 0.95, 1.0, 0.55), 1.0)
	draw_set_transform(Vector2.ZERO)
