class_name StoryBackdrop
extends CanvasLayer
## 剧情过场的背景大图（Cutscene 的子节点；过场动作 bg / bg_clear）：整屏铺满一张高清插画，对话框（layer 20）照旧在上面。
## 图在 assets/generated/story_scenes/<名字>.png（16:9，codex 生成，见 tools/art/src/story_scenes/prompts.md）。
## 线性过滤（高清图不按像素放大）；摆上来以后慢慢推近 / 平移（pan：in 推近、out 拉远、left / right 横移、up 往上摇）；换图交叉淡入淡出。

const DIR := "res://assets/generated/story_scenes/"
const SIZE := Vector2(480, 270)
const FADE := 0.6
## 推近 / 平移的幅度和时间
const ZOOM := 0.08
const DRIFT := 18.0
const DRIFT_TIME := 14.0

var current := ""
var _shown: TextureRect
var _old: TextureRect


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS


static func path_of(img: String) -> String:
	return DIR + img + ".png"


static func exists(img: String) -> bool:
	return ResourceLoader.exists(path_of(img))


func is_shown() -> bool:
	return is_instance_valid(_shown)


## 摆上一张（已经是这张就不动）；instant：不淡入（跳过过场的时候）
func show_image(img: String, pan := "in", instant := false) -> void:
	if img == current and is_shown():
		return
	if not exists(img):
		push_warning("没有背景大图: " + img)
		return
	current = img
	if is_instance_valid(_old):
		_old.queue_free()
	_old = _shown
	var r := TextureRect.new()
	r.texture = load(path_of(img))
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 比屏幕大一圈，平移的时候边上不露底
	var pad := Vector2(DRIFT, DRIFT * 0.6) * 1.5
	r.size = SIZE + pad * 2.0
	r.position = -pad
	r.pivot_offset = r.size / 2.0
	add_child(r)
	_shown = r
	_drift(r, pan)
	if instant:
		r.modulate.a = 1.0
		if is_instance_valid(_old):
			_old.queue_free()
		return
	r.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 1.0, FADE)
	var old := _old
	if is_instance_valid(old):
		tw.tween_callback(old.queue_free)


func _drift(r: TextureRect, pan: String) -> void:
	var tw := r.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var p0 := r.position
	match pan:
		"out":
			r.scale = Vector2.ONE * (1.0 + ZOOM)
			tw.tween_property(r, "scale", Vector2.ONE, DRIFT_TIME)
		"left":
			r.position = p0 + Vector2(DRIFT, 0)
			tw.tween_property(r, "position", p0 - Vector2(DRIFT, 0), DRIFT_TIME)
		"right":
			r.position = p0 - Vector2(DRIFT, 0)
			tw.tween_property(r, "position", p0 + Vector2(DRIFT, 0), DRIFT_TIME)
		"up":
			r.position = p0 - Vector2(0, DRIFT * 0.6)
			tw.tween_property(r, "position", p0 + Vector2(0, DRIFT * 0.6), DRIFT_TIME)
		"none":
			pass
		_:
			tw.tween_property(r, "scale", Vector2.ONE * (1.0 + ZOOM), DRIFT_TIME)


## 收起（淡出）
func clear(t := FADE) -> void:
	current = ""
	for c in get_children():
		if t <= 0.0:
			c.queue_free()
		else:
			var tw := (c as CanvasItem).create_tween()
			tw.tween_property(c, "modulate:a", 0.0, t)
			tw.tween_callback(c.queue_free)
	_shown = null
	_old = null
