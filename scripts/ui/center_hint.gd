class_name CenterHint
extends Label
## 屏幕中间的黄字提示（HUD 自带一个）：淡入 → 停 HOLD 秒（规则介绍可以传更长的 hold）→ 淡出。新的一条来了不用排队：
## 正在显示的那条往上顶（继续数完自己的时间），同时最多 MAX_SHOWN 条。
## 用法：GameState.hint("按住 空格 憋笑……")、GameState.hint(规则, GameState.RULE_HOLD)。同一句正在放时不重复加。

const FADE_IN := 0.2
const HOLD := 1.6
const FADE_OUT := 0.4
const MAX_SHOWN := 3
const LINE_STEP := 22.0

## 最近放过的提示（测试用）
static var history: Array[String] = []

var _busy := false
var _left := 0.0
var _tw: Tween
var _old: Array = []


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


func show_hint(text: String, hold := -1.0) -> void:
	if text == "" or (modulate.a > 0.05 and self.text == text):
		return
	history.append(text)
	if history.size() > 32:
		history.pop_front()
	# 正在显示的那条变成一张「旧的」往上顶，剩下的时间照样数完；同时最多 MAX_SHOWN 条
	if modulate.a > 0.05 and self.text != "":
		_push_old(self.text, _left)
	self.text = text
	_left = HOLD if hold < 0.0 else hold
	_busy = true
	scale = Vector2(1.25, 1.25)
	modulate.a = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween().set_ignore_time_scale()
	_tw.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tw.parallel().tween_property(self, "scale", Vector2.ONE, FADE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			if _tw:
				_tw.kill()
			_tw = create_tween().set_ignore_time_scale()
			_tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
			_tw.tween_callback(func(): _busy = false)


## 旧的一条：在上面接着显示剩下的时间。
func _push_old(t: String, left: float) -> void:
	_old = _old.filter(func(l): return is_instance_valid(l))
	while _old.size() >= MAX_SHOWN - 1:
		var gone: Label = _old.pop_front()
		gone.queue_free()
	for l in _old:
		(l as Label).position.y -= LINE_STEP
	var l := Label.new()
	l.text = t
	l.position = position + Vector2(0, -LINE_STEP)
	l.size = size
	l.horizontal_alignment = horizontal_alignment
	l.vertical_alignment = vertical_alignment
	l.autowrap_mode = autowrap_mode
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	l.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.modulate.a = 0.85
	get_parent().add_child(l)
	_old.append(l)
	var tw := l.create_tween().set_ignore_time_scale()
	tw.tween_interval(maxf(left, 0.5))
	tw.tween_property(l, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(l.queue_free)
