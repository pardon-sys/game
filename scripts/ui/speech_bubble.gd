class_name SpeechBubble
extends Label
## 角色头顶冒出的短句（怪物回嘴等）。SpeechBubble.say(角色, "咕啪咕啪～")

const DURATION := 1.8


static func say(target: Node2D, text: String, height := 30.0) -> SpeechBubble:
	if target == null or not is_instance_valid(target) or text == "":
		return null
	var old := target.get_node_or_null("Speech")
	if old:
		old.free()
	var b := SpeechBubble.new()
	b.name = "Speech"
	b.text = text
	b.z_index = 20
	b.add_theme_color_override("font_color", Color(1, 0.9, 0.96))
	b.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.22))
	b.add_theme_constant_override("outline_size", 4)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_child(b)
	b.reset_size()
	b.position = Vector2(-b.size.x / 2.0, -height - b.size.y).round()
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "position:y", -4.0, 0.25).as_relative()
	tw.tween_interval(DURATION - 0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
