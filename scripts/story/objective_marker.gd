class_name ObjectiveMarker
extends Node2D
## 目标提示（七日赎罪的导演摆在地图上）：
##   地上：目标格上一圈发光的圈 + 上下跳的箭头（没有 cell 时不画）；
##   屏幕：目标不在画面里时，画面边缘有一个指向它的小箭头；右下角「第 N 天·下午 / 目标：…… / 实时状态」。
##   过场 / 对话 / 黑幕期间整套藏起来。
##   set_target({text, cell, radius}) 换目标；{} = 没有目标。

const COL := Color(1.0, 0.86, 0.4)
const COL_RING := Color(1.0, 0.8, 0.35, 0.5)

var text := ""
## 跟在目标后面的实时状态（委托的计时 / 剩几块饼干……）：() → String
var extra := Callable()
var has_cell := false
var radius := 16.0
var _t := 0.0
var _hud: CanvasLayer
var _label: Label
var _edge: Polygon2D


func _ready() -> void:
	z_index = 5
	_hud = CanvasLayer.new()
	_hud.layer = 8
	add_child(_hud)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", COL)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.position = Vector2(110, 210)
	_label.size = Vector2(364, 54)
	_hud.add_child(_label)
	_edge = Polygon2D.new()
	_edge.polygon = PackedVector2Array([Vector2(8, 0), Vector2(-5, -6), Vector2(-5, 6)])
	_edge.color = COL
	_hud.add_child(_edge)


func set_target(info: Dictionary) -> void:
	text = str(info.get("text", ""))
	has_cell = info.has("cell")
	if has_cell:
		global_position = Cutscene.cell_to_world(info["cell"])
		radius = float(info.get("radius", 1.0)) * 16.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var busy := GameState.in_cutscene or GameState.in_dialogue or DayClock.passing or Sleep.sleeping
	_label.visible = text != "" and not busy
	var more := str(extra.call()) if extra.is_valid() else ""
	_label.text = ("%s\n目标：%s%s" % [DayClock.label(), text, ("\n" + more) if more != "" else ""]) if text != "" else ""
	visible = has_cell and not busy
	_edge.visible = false
	if has_cell and not busy:
		queue_redraw()
		var vp := get_viewport()
		var screen := vp.get_canvas_transform() * global_position
		var rect := vp.get_visible_rect().grow(-14.0)
		if not rect.has_point(screen):
			var c := rect.get_center()
			var dir := (screen - c).normalized()
			# 沿方向射到边框上
			var k := INF
			if absf(dir.x) > 0.001:
				k = minf(k, (rect.size.x * 0.5) / absf(dir.x))
			if absf(dir.y) > 0.001:
				k = minf(k, (rect.size.y * 0.5) / absf(dir.y))
			_edge.position = c + dir * k
			_edge.rotation = dir.angle()
			_edge.scale = Vector2.ONE * (1.0 + 0.15 * sin(_t * 6.0))
			_edge.visible = true


func _draw() -> void:
	if not has_cell:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_set_transform(Vector2(0, -4), 0.0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(COL_RING, 0.35 + 0.35 * pulse), 2.0)
	draw_circle(Vector2.ZERO, radius, Color(1, 0.85, 0.4, 0.06 + 0.06 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var y := -34.0 - 4.0 * sin(_t * 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, y), Vector2(6, y), Vector2(0, y + 9)]), COL)
	draw_rect(Rect2(-2.5, y - 8, 5, 8), COL)
