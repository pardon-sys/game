class_name SpeechBubble
extends Label
## 角色头顶冒出的短句（怪物回嘴等）。SpeechBubble.say(角色, "咕啪咕啪～")
## duration：停留秒数（边走边聊的长句子用得长一点；默认 DURATION）。

const DURATION := 1.8
const WRAP_CHARS := 14
const WRAP_WIDTH := 168.0

var duration := DURATION


static func say(target: Node2D, text: String, height := 30.0, duration := DURATION) -> SpeechBubble:
	if target == null or not is_instance_valid(target) or text == "":
		return null
	var old := target.get_node_or_null("Speech")
	if old:
		old.free()
	var b := SpeechBubble.new()
	b.name = "Speech"
	b.duration = duration
	b.text = text
	b.z_index = 20
	b.add_theme_color_override("font_color", Color(1, 0.9, 0.96))
	b.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.22))
	b.add_theme_constant_override("outline_size", 4)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 长句子（边走边聊）自动换行，宽度固定
	if text.length() > WRAP_CHARS:
		b.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		b.custom_minimum_size.x = WRAP_WIDTH
	target.add_child(b)
	# 关卡的环境光（CanvasModulate）会把世界里的字也压暗：反过来补亮，暗处也看得清
	var cm := _darkness(target)
	if cm:
		var c := cm.color
		b.modulate = Color(minf(1.0 / maxf(c.r, 0.25), 3.0), minf(1.0 / maxf(c.g, 0.25), 3.0), minf(1.0 / maxf(c.b, 0.25), 3.0))
	b.reset_size()
	b.position = Vector2(-b.size.x / 2.0, -height - b.size.y).round()
	return b


static func _darkness(target: Node) -> CanvasModulate:
	var n := target
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	if n == null:
		return null
	for c in n.find_children("*", "CanvasModulate", true, false):
		if (c as CanvasModulate).visible:
			return c
	return null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "position:y", -4.0, 0.25).as_relative()
	tw.tween_interval(maxf(0.2, duration - 0.6))
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
