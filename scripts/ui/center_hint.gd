class_name CenterHint
extends Label
## 屏幕中间的黄字提示（HUD 自带一个）：淡入 → 停一会 → 淡出，多条排队一条一条放。
## 用法：GameState.hint("按住 空格 憋笑……")。同一句正在放或已经在排队时不重复加。

const FADE_IN := 0.2
const HOLD := 1.6
const FADE_OUT := 0.4
const MAX_QUEUE := 4

## 最近放过的提示（测试用）
static var history: Array[String] = []

var _queue: Array[String] = []
var _busy := false


func _ready() -> void:
	name = "CenterHint"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20, 96)
	size = Vector2(440, 40)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	pivot_offset = size / 2.0
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.02))
	add_theme_constant_override("outline_size", 6)
	modulate.a = 0.0
	GameState.hint_requested.connect(show_hint)


func show_hint(text: String) -> void:
	if text == "" or text in _queue or (_busy and self.text == text):
		return
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
	_queue.append(text)
	history.append(text)
	if history.size() > 32:
		history.pop_front()
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	text = _queue.pop_front()
	scale = Vector2(1.25, 1.25)
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, FADE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(_next)
