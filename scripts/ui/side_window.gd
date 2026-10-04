class_name SideWindow
extends CanvasLayer
## 主画面右边附加的小窗（可复用组件）：里面是一个和主画面共用同一个 World2D 的 SubViewport，
## 自带镜头跟着 target——所以小窗里显示的是同一个关卡里另一处的真实画面（角色、特效、气泡都照常）。
##   var w := SideWindow.open(target, {"title": "…", "zoom": 2.0, "size": Vector2(176, 180), "hint": "← → 交替连按挣扎"})
##   w.set_overlay(control)   在小窗里叠一层界面（挣扎条等），铺满小窗
##   w.retarget(node)         换跟随的目标
##   w.close()                关闭（淡出）
## 第八层的献祭挣扎、巨石追逐战都用它。CG / 过场播放时自动隐藏。同时只开一个（再开会先关掉旧的）。

const LAYER := 12
const MARGIN := 6.0

static var current: SideWindow

var target: Node2D
var zoom := 2.0
var cam_offset := Vector2(0, -10)
var frame: Panel
var viewport: SubViewport
var cam: Camera2D
var title_label: Label
var hint_label: Label
var overlay_root: Control
var _size := Vector2(176, 180)


static func open(t: Node2D, opts := {}) -> SideWindow:
	if is_instance_valid(current):
		current.close(true)
	var w := SideWindow.new()
	w.target = t
	w.zoom = float(opts.get("zoom", 2.0))
	w._size = opts.get("size", Vector2(176, 180))
	if opts.has("offset"):
		w.cam_offset = opts["offset"]
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	w.set_title(str(opts.get("title", "")))
	w.set_hint(str(opts.get("hint", "")))
	current = w
	return w


static func is_open() -> bool:
	return is_instance_valid(current) and not current.is_queued_for_deletion()


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp_size := get_viewport().get_visible_rect().size
	frame = Panel.new()
	frame.name = "Frame"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.09, 1.0)
	sb.border_color = Color(0.95, 0.75, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = _size + Vector2(4, 18)
	frame.position = Vector2(vp_size.x - frame.size.x - MARGIN, 66.0)   # 右上角表情头像的下面
	add_child(frame)
	title_label = Label.new()
	title_label.position = Vector2(6, 1)
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.95))
	frame.add_child(title_label)
	var holder := SubViewportContainer.new()
	holder.position = Vector2(2, 16)
	holder.size = _size
	holder.stretch = true
	frame.add_child(holder)
	viewport = SubViewport.new()
	viewport.size = Vector2i(_size)
	viewport.world_2d = get_tree().root.world_2d
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * zoom
	viewport.add_child(cam)
	cam.make_current()
	overlay_root = Control.new()
	overlay_root.position = holder.position
	overlay_root.size = _size
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(overlay_root)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	hint_label.add_theme_constant_override("outline_size", 3)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, _size.y - 14)
	hint_label.size = Vector2(_size.x, 14)
	overlay_root.add_child(hint_label)
	frame.modulate.a = 0.0
	frame.position.x += 30.0
	var tw := create_tween().set_parallel()
	tw.tween_property(frame, "modulate:a", 1.0, 0.2)
	tw.tween_property(frame, "position:x", frame.position.x - 30.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_follow()


func set_title(t: String) -> void:
	if title_label:
		title_label.text = t


func set_hint(t: String) -> void:
	if hint_label:
		hint_label.text = t


func retarget(t: Node2D) -> void:
	target = t
	_follow()


## 叠一层界面（铺满小窗，鼠标穿透）。
func set_overlay(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(c)
	overlay_root.move_child(c, 0)
	c.size = _size


func close(instant := false) -> void:
	if current == self:
		current = null
	if instant or not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(frame, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _follow() -> void:
	if cam and is_instance_valid(target):
		cam.global_position = target.global_position + cam_offset


func _process(_delta: float) -> void:
	_follow()
	var cg := get_node_or_null("/root/CG")
	var busy: bool = cg != null and cg.is_playing()
	visible = not busy and not get_tree().paused
