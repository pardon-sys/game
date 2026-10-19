class_name TailorChart
extends Control
## 弥补任务「找漏风」的部位图（标漏风点时盖在画面右上角）：画一个小人（腋下 / 腰）或一只脚（脚心），四个点按反应上色——
##   好痒！红、有一点点 黄、完全没感觉 灰、还没试过 暗；标记了的点套一个白圈，缝过的点画一个 ×。
##   set_state(部位, 点名, 反应{下标: strong/weak/none}, 标记[下标], 缝过[下标])

const POS := {
	"armpit": [Vector2(-14, -20), Vector2(-9, -12), Vector2(9, -12), Vector2(14, -20)],
	"waist": [Vector2(-10, 2), Vector2(0, 8), Vector2(10, 2), Vector2(0, -2)],
	"sole": [Vector2(0, 24), Vector2(-4, 10), Vector2(2, 0), Vector2(0, -16)],
}
const COLS := {"strong": Color(1, 0.35, 0.4), "weak": Color(1, 0.85, 0.35), "none": Color(0.6, 0.6, 0.66)}

var part := "armpit"
var names: Array = []
var results := {}
var marks: Array = []
var sewn: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(110, 96)
	size = custom_minimum_size


func set_state(p: String, n: Array, r: Dictionary, m: Array, s: Array) -> void:
	part = p
	names = n
	results = r
	marks = m
	sewn = s
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.14, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.75, 0.88), false, 1.0)
	var c := Vector2(size.x * 0.5, size.y * 0.5 + 4)
	var line := Color(0.85, 0.8, 0.9)
	if part == "sole":
		# 一只脚（脚底朝外）
		var foot := PackedVector2Array([c + Vector2(-6, 28), c + Vector2(6, 28), c + Vector2(9, 10), c + Vector2(8, -10), c + Vector2(10, -22),
			c + Vector2(0, -28), c + Vector2(-10, -22), c + Vector2(-8, -6), c + Vector2(-9, 12)])
		draw_polyline(PackedVector2Array(Array(foot) + [foot[0]]), line, 1.0)
		for i in 5:
			draw_circle(c + Vector2(-9 + i * 4.5, -31 + absf(i - 2) * 1.5), 2.0, line)
	else:
		# 小人（双手举起）
		draw_circle(c + Vector2(0, -30), 5, line)
		draw_polyline(PackedVector2Array([c + Vector2(-8, -22), c + Vector2(8, -22), c + Vector2(10, 4), c + Vector2(6, 22), c + Vector2(-6, 22),
			c + Vector2(-10, 4), c + Vector2(-8, -22)]), line, 1.0)
		draw_line(c + Vector2(-8, -22), c + Vector2(-18, -38), line, 1.0)
		draw_line(c + Vector2(8, -22), c + Vector2(18, -38), line, 1.0)
	var font := get_theme_default_font()
	var pos: Array = POS.get(part, [])
	for i in pos.size():
		var p: Vector2 = c + pos[i]
		var r := str(results.get(i, results.get(str(i), "")))
		var col: Color = COLS.get(r, Color(0.3, 0.26, 0.36))
		draw_circle(p, 3.5, col)
		if i in marks:
			draw_arc(p, 6.0, 0, TAU, 14, Color.WHITE, 1.0)
		if i in sewn:
			draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), Color(0.2, 1, 0.5), 1.5)
			draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), Color(0.2, 1, 0.5), 1.5)
		if font:
			draw_string(font, p + Vector2(6, 3), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
