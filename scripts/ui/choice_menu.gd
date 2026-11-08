class_name ChoiceMenu
extends CanvasLayer
## 对话选项页：在对话框上方列出选项，上下键选择、E / 回车确定。await ask(选项文字, 提示) 返回选中的序号。
## 测试 / 脚本可以直接调 choose(序号)。打开期间 GameState.in_dialogue = true（人物不跟着上下键走）。
## 选项多于 MAX_SHOWN 个时只显示一个窗口（上下 ▲ ▼ 提示还有更多），选中的那项跟着滚动；每次打开都从最上面开始。

signal chosen(index: int)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)

const MAX_SHOWN := 6

var selected := 0
var top := 0
var options: Array = []
var panel: PanelContainer
var box: VBoxContainer
var prompt_label: Label
var _layout := Rect2()


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


func ask(texts: Array, prompt := "", layout := Rect2()) -> int:
	_layout = layout
	panel.custom_minimum_size = layout.size
	options = texts
	selected = 0
	top = 0
	prompt_label.text = prompt
	prompt_label.visible = prompt != ""
	_refresh()
	panel.show()
	# 选项页开着的时候人物不动（上下键是用来选的）；关上以后还原
	var was := GameState.in_dialogue
	GameState.in_dialogue = true
	GameState.dialogue_holds += 1
	if is_instance_valid(GameState.player):
		GameState.player.velocity = Vector2.ZERO
	var pick: int = await chosen
	GameState.dialogue_holds = maxi(0, GameState.dialogue_holds - 1)
	GameState.in_dialogue = was or Dialogue.is_active() or GameState.in_cutscene or GameState.dialogue_holds > 0
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
	if selected < top:
		top = selected
	elif selected >= top + MAX_SHOWN:
		top = selected - MAX_SHOWN + 1
	top = clampi(top, 0, maxi(0, options.size() - MAX_SHOWN))
	var scrolls := options.size() > MAX_SHOWN
	if scrolls:
		box.add_child(_arrow("▲" if top > 0 else " "))
	for i in range(top, mini(options.size(), top + MAX_SHOWN)):
		var l := Label.new()
		l.text = ("▶ " if i == selected else "　 ") + str(options[i])
		if _layout.has_area():
			l.custom_minimum_size.x = _layout.size.x - 24
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", PINK if i == selected else TEXT)
		box.add_child(l)
	if scrolls:
		box.add_child(_arrow("▼" if top + MAX_SHOWN < options.size() else " "))
	await get_tree().process_frame
	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	panel.position = _layout.position if _layout.has_area() else Vector2(vp.x - panel.size.x - 16, vp.y - 96 - panel.size.y)


func _arrow(t: String) -> Label:
	var a := Label.new()
	a.text = t
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.add_theme_font_size_override("font_size", 8)
	a.add_theme_color_override("font_color", GOLD)
	return a


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	var act := ""
	if event.is_action("move_up") or event.is_action("ui_up"):
		act = "up"
	elif event.is_action("move_down") or event.is_action("ui_down"):
		act = "down"
	elif event.is_action("interact") or event.is_action("ui_accept") or event.is_action("attack"):
		act = "ok"
	else:
		return
	# 先吃掉输入：确定之后对话可能结束、菜单可能离开场景树
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
