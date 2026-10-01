class_name FatigueBar
extends Control
## HUD 魔力疲倦条（紫色）：刻度在 40% / 60% / 80%（闷笑积累加成 +5% / +10% / +30%），超过 90% 时闪烁。

const BG := Color(0.12, 0.08, 0.18, 0.9)
const BORDER := Color(0.3, 0.2, 0.42)
const FILL := Color(0.62, 0.45, 1.0)
const FILL_HIGH := Color(0.8, 0.5, 1.0)
const MARK := Color(0.16, 0.08, 0.24)
const MARKS := [0.4, 0.6, 0.8]
const HIGH := 0.8
const WARN := 0.9

var value := 0.0
var max_value := 500.0
var _t := 0.0


func bind(f: MagicFatigue) -> void:
	f.changed.connect(func(v: float, m: float):
		value = v
		max_value = m
		queue_redraw())
	value = f.value
	max_value = f.max_value
	queue_redraw()


func _process(delta: float) -> void:
	if value >= max_value * WARN:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG)
	var w := roundf(size.x * clampf(value / max_value, 0.0, 1.0))
	var col := FILL_HIGH if value >= max_value * HIGH else FILL
	if value >= max_value * WARN and int(_t * 6.0) % 2 == 0:
		col = col.lightened(0.35)
	draw_rect(Rect2(0, 0, w, size.y), col)
	for m in MARKS:
		var x := roundf(size.x * m)
		draw_line(Vector2(x, 0), Vector2(x, size.y), MARK)
	draw_rect(r, BORDER, false)
