extends Node2D
## 地上发光的临时痒痒装备（弥补任务「装备回收」）：装备图标 + 一圈一闪一闪的光。

var item_id := ""
var _t := randf() * TAU
var _icon: Sprite2D


func _ready() -> void:
	z_index = 0
	var it := ItemDB.get_item(item_id)
	if it and it.icon:
		_icon = Sprite2D.new()
		_icon.texture = it.icon
		_icon.position = Vector2(0, -8)
		add_child(_icon)


func _process(delta: float) -> void:
	_t += delta
	if _icon:
		_icon.position.y = -8.0 - 1.5 * sin(_t * 3.0)
	queue_redraw()


func _draw() -> void:
	var a := 0.35 + 0.25 * sin(_t * 4.0)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(1, 0.6, 0.85, a * 0.5))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 20, Color(1, 0.75, 0.9, a + 0.2), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _icon == null:
		draw_circle(Vector2(0, -8), 4.0, Color(1, 0.7, 0.9))
