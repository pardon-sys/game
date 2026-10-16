class_name SiegeCamera
extends CanvasLayer
## 攻防战的镜头（SiegeDirector 创建；只在攻防战地图里用）：
##   缩放：鼠标滚轮 / 「=」放大、「-」缩小（输入动作 zoom_in / zoom_out），MIN_ZOOM ~ MAX_ZOOM 之间平滑过渡；
##         切换操控（C）时新的镜头沿用当前倍数。
##   全景：按 V（输入动作 overview）切到整个战场的全景（游戏暂停，镜头脱离人物、居中、缩到能看到整张地图），再按 V / Esc 回来。
##   镜头边界：地图范围（全景时不限）。

const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.5
const STEP := 0.25
const SPEED := 6.0

var director: Node
var zoom := 1.0
var target_zoom := 1.0
var overview := false
var _label: Label
var _paused_by_me := false
var _map_size := Vector2(1760, 1280)


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.text = "战场全景（V / Esc 返回）"
	_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(170, 250)
	_label.hide()
	add_child(_label)
	GameState.player_registered.connect(func(_p: Node): _apply(true))


func setup(map_size: Vector2) -> void:
	_map_size = map_size
	_apply(true)


func camera() -> Camera2D:
	var p := GameState.player
	return p.camera if is_instance_valid(p) and p.get("camera") else null


func set_zoom_level(z: float, instant := false) -> void:
	target_zoom = clampf(z, 0.30 if is_instance_valid(director) and director.wave == 12 else MIN_ZOOM, MAX_ZOOM)
	if instant:
		zoom = target_zoom
		_apply(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("overview") or (overview and (event.is_action("pause") or event.is_action("ui_cancel"))):
		if overview or not (GameState.in_dialogue or CG.is_busy() or get_tree().paused):
			toggle_overview()
			get_viewport().set_input_as_handled()
		return
	if overview or get_tree().paused or GameState.in_dialogue:
		return
	if event.is_action("zoom_in"):
		set_zoom_level(target_zoom + STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action("zoom_out"):
		set_zoom_level(target_zoom - STEP)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if overview:
		return
	if absf(zoom - target_zoom) > 0.001:
		zoom = lerpf(zoom, target_zoom, minf(1.0, delta * SPEED))
		if absf(zoom - target_zoom) < 0.005:
			zoom = target_zoom
		_apply(false)


func _apply(limits: bool) -> void:
	var cam := camera()
	if cam == null or overview:
		return
	cam.zoom = Vector2(zoom, zoom)
	if limits:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(_map_size.x)
		cam.limit_bottom = int(_map_size.y)


## 全景开 / 关。
func toggle_overview() -> void:
	var cam := camera()
	if cam == null:
		return
	overview = not overview
	_label.visible = overview
	if overview:
		var vs := cam.get_viewport_rect().size
		var fit := minf(vs.x / _map_size.x, vs.y / _map_size.y) * 0.98
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		cam.global_position = _map_size / 2.0
		cam.zoom = Vector2(fit, fit)
		cam.reset_smoothing()
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_me = true
	else:
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.position_smoothing_enabled = true
		_apply(true)
		cam.reset_smoothing()
		if _paused_by_me:
			get_tree().paused = false
			_paused_by_me = false
