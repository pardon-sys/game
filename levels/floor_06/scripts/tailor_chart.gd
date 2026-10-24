class_name TailorChart
extends Control
## 弥补任务「找漏风」的生成服装插画。图像与归一化编号点来自tailor.json，反应／圈选／缝补由界面叠加。
##   set_state(部位, 点名, 反应{下标: strong/weak/none}, 标记[下标], 缝过[下标])

const PANEL_SIZE := Vector2(176, 154)
const ART_RECT := Rect2(8, 22, 160, 108)
const COLS := {"strong": Color(1, 0.35, 0.4), "weak": Color(1, 0.85, 0.35), "none": Color(0.6, 0.6, 0.66)}
static var _textures := {}
var _texture: Texture2D
var _points: Array = []
var _title := ""
var _legend := ""

var part := "armpit"
var names: Array = []
var results := {}
var marks: Array = []
var sewn: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL_SIZE
	size = custom_minimum_size


func set_state(p: String, n: Array, r: Dictionary, m: Array, s: Array) -> void:
	part = p
	names = n
	results = r
	marks = m
	sewn = s
	var spec: Dictionary = TaskTailor.data().get("parts", {}).get(part, {})
	var chart: Dictionary = spec.get("chart", {})
	var path := str(chart.get("texture", ""))
	if not _textures.has(path) and ResourceLoader.exists(path): _textures[path] = load(path)
	_texture = _textures.get(path)
	_points = chart.get("points_uv", [])
	_title = str(spec.get("name", ""))
	_legend = str(TaskTailor.data().get("chart_legend", ""))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.14, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.75, 0.88), false, 1.0)
	var font := get_theme_default_font()
	if _texture: draw_texture_rect(_texture, ART_RECT, false)
	draw_string(font, Vector2(8, 14), _title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 9, Color(1, 0.85, 0.5))
	draw_string(font, Vector2(8, size.y - 8), _legend, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 7, Color.WHITE)
	for i in _points.size():
		var uv: Array = _points[i]
		var p := ART_RECT.position + Vector2(float(uv[0]), float(uv[1])) * ART_RECT.size
		var r := str(results.get(i, results.get(str(i), "")))
		var col: Color = COLS.get(r, Color(0.3, 0.26, 0.36))
		draw_circle(p, 5.0, Color(0.08, 0.04, 0.1))
		draw_circle(p, 3.5, col)
		if i in marks:
			draw_arc(p, 6.0, 0, TAU, 14, Color.WHITE, 1.0)
		if i in sewn:
			draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), Color(0.2, 1, 0.5), 1.5)
			draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), Color(0.2, 1, 0.5), 1.5)
		if font:
			draw_string_outline(font, p + Vector2(7, 3), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color.BLACK)
			draw_string(font, p + Vector2(7, 3), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
