class_name ChoiceMenu
extends CanvasLayer
## 对话选项页：在对话框上方列出选项，上下键选择、E / 回车确定。await ask(选项文字, 提示) 返回选中的序号。
## 测试 / 脚本可以直接调 choose(序号)。

signal chosen(index: int)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)

var selected := 0
var options: Array = []
var panel: PanelContainer
var box: VBoxContainer
var prompt_label: Label


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.96)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	prompt_label = Label.new()
	prompt_label.add_theme_color_override("font_color", GOLD)
	box.add_child(prompt_label)
	panel.hide()


func is_open() -> bool:
	return panel.visible


func ask(texts: Array, prompt := "") -> int:
	options = texts
	selected = 0
	prompt_label.text = prompt
	prompt_label.visible = prompt != ""
	_refresh()
	panel.show()
	var pick: int = await chosen
	return pick


func choose(i: int) -> void:
	if not is_open():
		return
	panel.hide()
	Audio.play("book", -8.0, 0.05, 1.4)
	chosen.emit(clampi(i, 0, options.size() - 1))


func _refresh() -> void:
	for c in box.get_children():
		if c != prompt_label:
			box.remove_child(c)
			c.queue_free()
	for i in options.size():
		var l := Label.new()
		l.text = ("▶ " if i == selected else "　 ") + str(options[i])
		l.add_theme_color_override("font_color", PINK if i == selected else TEXT)
		box.add_child(l)
	await get_tree().process_frame
	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(vp.x - panel.size.x - 16, vp.y - 96 - panel.size.y)


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("move_up") or event.is_action("ui_up"):
		selected = (selected - 1 + options.size()) % options.size()
		_refresh()
	elif event.is_action("move_down") or event.is_action("ui_down"):
		selected = (selected + 1) % options.size()
		_refresh()
	elif event.is_action("interact") or event.is_action("ui_accept") or event.is_action("attack"):
		choose(selected)
	else:
		return
	get_viewport().set_input_as_handled()
