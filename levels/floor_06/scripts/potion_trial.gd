class_name PotionTrial
extends CanvasLayer
## 试药流程里的小操作（TaskPotion 用；也可以给别的「暂停一下按键」的场面用），画在画面正中偏下的一个小面板上：
##   await timing(提示, 绿区宽度, 速度) → bool   指针来回扫，扫到绿区时按 J（扫完一趟没按 / 按在绿区外 = 失败）
##   await mash(提示, 次数, 秒) → bool           限时连按 J
##   await rhythm(提示, 拍数) → int              每拍「嗝！」亮起时按 J（前后 GOOD 秒内算准），返回按准了几拍
## 打开期间 GameState.in_dialogue = true（人物不动）。测试：auto = "ok" / "bad"（不等按键，直接返回成功 / 失败）。

const GOOD := 0.22
const W := 220.0
const H := 54.0

static var auto := ""

var _prompt: Label
var _panel: Panel
var _draw: Control
var _mode := ""
var _cursor := 0.0
var _dir := 1.0
var _zone := Vector2(0.4, 0.6)
var _count := 0
var _need := 0
var _beat_on := false
var _t := 0.0


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vs := Vector2(480, 270)
	if get_viewport():
		vs = get_viewport().get_visible_rect().size
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.07, 0.15, 0.94)
	sb.border_color = Color(1, 0.72, 0.86)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size = Vector2(W, H)
	_panel.position = ((vs - _panel.size) * Vector2(0.5, 0.62)).round()
	add_child(_panel)
	_prompt = Label.new()
	_prompt.position = Vector2(8, 4)
	_prompt.size = Vector2(W - 16, 20)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	_panel.add_child(_prompt)
	_draw = Control.new()
	_draw.position = Vector2(8, 30)
	_draw.size = Vector2(W - 16, 16)
	_draw.draw.connect(_on_draw)
	_panel.add_child(_draw)
	_panel.hide()


func _open(prompt: String, mode: String) -> void:
	_prompt.text = prompt
	_mode = mode
	_t = 0.0
	_panel.show()
	GameState.in_dialogue = true


func _close() -> void:
	_mode = ""
	_panel.hide()


func timing(prompt: String, width := 0.3, speed := 1.0) -> bool:
	if auto != "":
		return auto == "ok"
	_open(prompt, "timing")
	_cursor = 0.0
	_dir = 1.0
	_zone = Vector2(0.62 - width * 0.5, 0.62 + width * 0.5)
	var res := -1
	while res < 0:
		await get_tree().process_frame
		var d := get_process_delta_time()
		_cursor += _dir * speed * d / 1.2
		if _cursor >= 1.0 or _cursor <= 0.0:
			_cursor = clampf(_cursor, 0.0, 1.0)
			_dir = -_dir
			if _dir > 0.0:
				res = 0    # 来回一趟都没按
		if _pressed():
			res = 1 if _cursor >= _zone.x and _cursor <= _zone.y else 0
		_draw.queue_redraw()
	_close()
	Audio.play("pickup" if res == 1 else "hit", -8.0, 0.1)
	return res == 1


func mash(prompt: String, count := 12, time := 4.0) -> bool:
	if auto != "":
		return auto == "ok"
	_open(prompt, "mash")
	_count = 0
	_need = count
	while _t < time and _count < _need:
		await get_tree().process_frame
		_t += get_process_delta_time()
		if _pressed():
			_count += 1
			Audio.play("step", -12.0, 0.2)
		_draw.queue_redraw()
	_close()
	return _count >= _need


func rhythm(prompt: String, beats := 4) -> int:
	if auto != "":
		return beats if auto == "ok" else 0
	_open(prompt, "rhythm")
	var hit := 0
	var gap := 1.1
	for b in beats:
		_t = 0.0
		var done := false
		while _t < gap:
			await get_tree().process_frame
			_t += get_process_delta_time()
			_beat_on = absf(_t - gap * 0.7) < GOOD
			if _pressed() and not done:
				done = true
				if _beat_on:
					hit += 1
					Audio.play("pickup", -10.0, 0.1)
			_draw.queue_redraw()
	_close()
	return hit


func _pressed() -> bool:
	return Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")


func _on_draw() -> void:
	var w := _draw.size.x
	match _mode:
		"timing":
			_draw.draw_rect(Rect2(0, 4, w, 8), Color(0.2, 0.14, 0.24))
			_draw.draw_rect(Rect2(w * _zone.x, 4, w * (_zone.y - _zone.x), 8), Color(0.3, 0.62, 0.38))
			_draw.draw_line(Vector2(w * _cursor, 0), Vector2(w * _cursor, 16), Color(1, 0.9, 0.5), 2.0)
		"mash":
			_draw.draw_rect(Rect2(0, 4, w, 8), Color(0.2, 0.14, 0.24))
			_draw.draw_rect(Rect2(0, 4, w * clampf(float(_count) / maxf(1.0, _need), 0.0, 1.0), 8), Color(1, 0.6, 0.75))
		"rhythm":
			_draw.draw_circle(Vector2(w * 0.5, 8), 7.0, Color(1, 0.86, 0.4) if _beat_on else Color(0.35, 0.28, 0.4))
			if _beat_on:
				_draw.draw_string(_draw.get_theme_default_font(), Vector2(w * 0.5 + 12, 12), "嗝！", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
