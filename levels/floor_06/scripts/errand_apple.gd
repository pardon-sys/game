extends Node2D
## 委托「捡苹果」地上的一个苹果（程序画的小红苹果，轻轻晃）。

var _t := randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var y := -4.0 + sin(_t * 3.0) * 0.8
	draw_circle(Vector2(0, y), 3.6, Color(0.88, 0.2, 0.22))
	draw_circle(Vector2(-1.2, y - 1.2), 1.0, Color(1, 0.6, 0.6))
	draw_line(Vector2(0, y - 3.5), Vector2(0.8, y - 5.5), Color(0.45, 0.3, 0.15), 1.0)
	draw_line(Vector2(0.8, y - 5), Vector2(2.6, y - 5.8), Color(0.4, 0.75, 0.35), 1.2)
