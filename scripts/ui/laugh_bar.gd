class_name LaughBar
extends Control
## HUD 闷笑值条：带 憋笑 / 失控1 / 失控2 刻度（50 / 80 / 100），失控时闪烁。

const BG := Color(0.16, 0.1, 0.18, 0.9)
const BORDER := Color(0.36, 0.2, 0.3)
const CALM := Color(1.0, 0.72, 0.86)
const GIGGLE := Color(1.0, 0.47, 0.72)
const HELPLESS := Color(1.0, 0.28, 0.55)
const HELPLESS2 := Color(0.86, 0.12, 0.42)
const MARK := Color(0.2, 0.1, 0.16)

var value := 0.0
var max_value := 100.0
var marks: Array[float] = [50.0, 80.0, 100.0]
var stage2 := 100.0
var level := LaughMeter.Level.CALM
var _t := 0.0


func bind(meter: LaughMeter) -> void:
	marks = [meter.giggle_threshold, meter.helpless_threshold, meter.helpless_stage2_threshold]
	stage2 = meter.helpless_stage2_threshold
	meter.changed.connect(func(v: float, m: float):
		value = v
		max_value = m
		queue_redraw())
	meter.level_changed.connect(func(l: LaughMeter.Level):
		level = l
		queue_redraw())
	value = meter.value
	max_value = meter.max_value
	level = meter.level
	queue_redraw()


func _process(delta: float) -> void:
	if level == LaughMeter.Level.HELPLESS:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG)
	var col := CALM
	match level:
		LaughMeter.Level.GIGGLING: col = GIGGLE
		LaughMeter.Level.HELPLESS:
			var base := HELPLESS2 if value > stage2 else HELPLESS
			col = base if int(_t * (12.0 if value > stage2 else 8.0)) % 2 == 0 else Color.WHITE
	var w := roundf((size.x - 2.0) * clampf(value / max_value, 0.0, 1.0))
	if w > 0.0:
		draw_rect(Rect2(1, 1, w, size.y - 2.0), col)
	for m in marks:
		var x := roundf(1.0 + (size.x - 2.0) * m / max_value)
		draw_line(Vector2(x, 1), Vector2(x, size.y - 1), MARK)
	draw_rect(r, BORDER, false, 1.0)
