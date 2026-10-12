class_name ScrollPicker
extends CanvasLayer
## 带滚动的选择界面（和商店 ShopUI 同一个模板：上面标题、中间可滚动的选项列表、下面选中项的说明、最下面按键提示）。
## 选项多了自动出滚动条，选中的那行自动滚进来；整块面板固定在屏幕中间，不会跑出屏幕。打开时暂停游戏。
##   var i := await ScrollPicker.ask("造哪一种冰塔？", [{"text": "冰锥塔　❄10", "desc": "……", "enabled": true}, …])
##   返回选中的序号；Esc / Tab 取消返回 -1。测试 / 脚本可以用 ScrollPicker.current.choose(i) 直接选。
## 用在：攻防战 B 键的造塔 / 升级菜单。

signal picked(index: int)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.6, 0.55, 0.65)

## 正在开着的那个（测试用）
static var current: ScrollPicker

var title := ""
var options: Array = []
var hint_text := "上下 选择　E 确定　Esc 取消"
var selected := 0
var panel: Panel
var title_label: Label
var list_box: ScrollTextBox
var desc_box: ScrollTextBox
var desc_label: Label
var _paused_by_me := false
var _done := false
var _opened_frame := 0


## 打开一个选择界面，await 到选完（-1 = 取消）。
static func ask(t: String, opts: Array, hint := "") -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var p := ScrollPicker.new()
	p.title = t
	p.options = opts
	if hint != "":
		p.hint_text = hint
	tree.root.add_child(p)
	var r: int = await p.picked
	p.queue_free()
	return r


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	current = self
	_opened_frame = Engine.get_process_frames()
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(80, 30)
	panel.size = Vector2(320, 200)
	add_child(panel)
	title_label = _label(GOLD)
	title_label.position = Vector2(12, 6)
	title_label.size = Vector2(296, 16)
	title_label.clip_text = true
	panel.add_child(title_label)
	list_box = ScrollTextBox.make(Rect2(12, 26, 296, 106), 2)
	panel.add_child(list_box)
	desc_box = ScrollTextBox.make(Rect2(12, 136, 296, 40), 1)
	panel.add_child(desc_box)
	desc_label = desc_box.add_line("", TEXT)
	var hint := _label(DIM)
	hint.text = hint_text
	hint.position = Vector2(12, 178)
	panel.add_child(hint)
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Audio.play("book", -8.0)
	_refresh()


func _exit_tree() -> void:
	if current == self:
		current = null
	if _paused_by_me:
		(Engine.get_main_loop() as SceneTree).paused = false
		_paused_by_me = false


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	return l


func _enabled(i: int) -> bool:
	return bool((options[i] as Dictionary).get("enabled", true))


func _refresh() -> void:
	title_label.text = title
	list_box.clear()
	var chosen: Label = null
	for i in options.size():
		var o: Dictionary = options[i]
		var l := list_box.add_line("%s%s" % ["▶ " if i == selected else "　 ", str(o.get("text", ""))],
			PINK if i == selected else (TEXT if _enabled(i) else DIM))
		if i == selected:
			chosen = l
	desc_label.text = str((options[selected] as Dictionary).get("desc", "")) if not options.is_empty() else ""
	desc_box.scroll_to_top()
	if chosen:
		list_box.ensure_control_visible.call_deferred(chosen)


## 选第 i 个（不可选的不算数）。
func choose(i: int) -> void:
	if _done or i < 0 or i >= options.size() or not _enabled(i):
		Audio.play("locked", -8.0)
		return
	_finish(i)


func cancel() -> void:
	_finish(-1)


func _finish(i: int) -> void:
	if _done:
		return
	_done = true
	if _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false
	picked.emit(i)


func _input(event: InputEvent) -> void:
	if _done or options.is_empty() or not event.is_pressed() or event.is_echo():
		return
	# 打开这一帧的按键（B / E）不算
	if Engine.get_process_frames() == _opened_frame:
		get_viewport().set_input_as_handled()
		return
	var act := ""
	if event.is_action("move_up") or event.is_action("ui_up"):
		act = "up"
	elif event.is_action("move_down") or event.is_action("ui_down"):
		act = "down"
	elif event.is_action("interact") or event.is_action("ui_accept"):
		act = "ok"
	elif event.is_action("pause") or event.is_action("ui_cancel") or event.is_action("backpack"):
		act = "cancel"
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()   # 开着时别的键都吃掉（不让人物动 / 放法术）
		return
	else:
		return
	get_viewport().set_input_as_handled()
	match act:
		"up":
			selected = (selected - 1 + options.size()) % options.size()
			_refresh()
		"down":
			selected = (selected + 1) % options.size()
			_refresh()
		"ok":
			choose(selected)
		"cancel":
			cancel()
