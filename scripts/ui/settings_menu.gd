class_name SettingsMenu
extends CanvasLayer
## 设置菜单（P 键，动作 settings）：打开时暂停游戏。两项（↑↓ 选，←→ / 回车 / 点一下 切换，P / Esc 关）：
##   「角色画风」高清 / 像素：UserSettings.art_style（粉色 / 蓝色公主、派对主人的地图精灵图和 CG 舞台小人换成 *_hd.png 非像素图集；原像素图保留，随时切回）；
##   「显示常驻立绘」开 / 关：UserSettings.show_portrait（游戏中左下角的角色立绘；对话、CG、小剧场里的立绘照常显示）。
## 设置存在 settings.cfg 的 [display] 段。对话 / 过场 / CG / 别的菜单（暂停菜单、背包）开着时不响应。
## main.gd 进场时 add_child(SettingsMenu.new())。测试：open() / close()、toggle_row(i)、rows、index、is_open()。

const LAYER := 31
const GOLD := Color(1, 0.84, 0.28)
const TEXT := Color(0.93, 0.88, 0.95)
const DIM := Color(0.62, 0.56, 0.68)
const PINK := Color(0.96, 0.6, 0.76)
const PANEL_SIZE := Vector2(240, 104)
## 每一项：[标题, 设置键, [显示文字…], [对应的值…]]
const ROWS := [
	["角色画风", "art_style", ["高清", "像素"], ["hd", "pixel"]],
	["显示常驻立绘", "show_portrait", ["开", "关"], [true, false]],
]

var index := 0
var rows: Array[Label] = []
var _root: ColorRect
var _hint: Label


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	_root.color = Color(0.06, 0.04, 0.08, 0.75)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel := Panel.new()
	panel.size = PANEL_SIZE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -PANEL_SIZE / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.15, 0.95)
	sb.border_color = PINK
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)
	var title := _label("— 设置 —", GOLD)
	title.position = Vector2(0, 6)
	title.size = Vector2(PANEL_SIZE.x, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	for i in ROWS.size():
		var l := _label("", TEXT)
		l.position = Vector2(14, 30 + i * 20)
		l.size = Vector2(PANEL_SIZE.x - 28, 16)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_row_input.bind(i))
		panel.add_child(l)
		rows.append(l)
	_hint = _label("↑↓ 选择　←→ 切换　P / Esc 关闭", DIM)
	_hint.position = Vector2(0, PANEL_SIZE.y - 22)
	_hint.size = Vector2(PANEL_SIZE.x, 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(_hint)
	_root.hide()


func _label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 12)
	l.clip_text = false
	return l


func is_open() -> bool:
	return _root.visible


func _can_open() -> bool:
	return not get_tree().paused and not GameState.in_dialogue and not GameState.in_cutscene


func open() -> void:
	if is_open():
		return
	index = 0
	_root.show()
	get_tree().paused = true
	_refresh()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false


## 切换第 i 项到下一个值
func toggle_row(i: int, step := 1) -> void:
	var r: Array = ROWS[i]
	var values: Array = r[3]
	var cur := values.find(UserSettings.get_value(str(r[1])))
	UserSettings.set_value(str(r[1]), values[posmod(maxi(cur, 0) + step, values.size())])
	_refresh()


func _refresh() -> void:
	for i in rows.size():
		var r: Array = ROWS[i]
		var cur := maxi((r[3] as Array).find(UserSettings.get_value(str(r[1]))), 0)
		var opts: Array[String] = []
		for j in (r[2] as Array).size():
			opts.append(("【%s】" if j == cur else " %s ") % r[2][j])
		rows[i].text = ("▶ " if i == index else "　") + str(r[0]) + "：" + " ".join(opts)
		rows[i].add_theme_color_override("font_color", PINK if i == index else TEXT)


func _on_row_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = i
		toggle_row(i)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not is_open():
		if event.is_action_pressed("settings") and _can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("settings") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		index = posmod(index - 1, ROWS.size())
		_refresh()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		index = posmod(index + 1, ROWS.size())
		_refresh()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		toggle_row(index, -1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		toggle_row(index)
