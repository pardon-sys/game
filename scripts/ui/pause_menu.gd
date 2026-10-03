extends CanvasLayer
## 暂停菜单（Esc）。测试模式（DevConfig.enabled）打开时多一项「测试：跳关」，展开成 dev_config.json 的跳关点列表
## （放在带滚动条的 skip_scroll 里：跳关点多了也能上下滚动，键盘移动焦点时自动滚到可见）。

@onready var root: Control = $Root
@onready var box: VBoxContainer = $Root/Box

var skip_button: Button
var skip_box: VBoxContainer
var skip_scroll: ScrollContainer
## 跳关列表可见的最大高度（超过就出现滚动条）。
const SKIP_HEIGHT := 176.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()
	$Root/Box/Resume.pressed.connect(toggle)
	$Root/Box/Restart.pressed.connect(_restart)
	$Root/Box/Quit.pressed.connect(func(): get_tree().quit())
	var title_button := Button.new()
	title_button.name = "ToTitle"
	title_button.text = "返回主界面"
	title_button.pressed.connect(to_title)
	box.add_child(title_button)
	box.move_child(title_button, box.get_child_count() - 2)
	skip_button = Button.new()
	skip_button.name = "DevSkip"
	skip_button.text = "测试：跳关"
	skip_button.pressed.connect(show_skip_list)
	box.add_child(skip_button)
	box.move_child(skip_button, 2)
	skip_scroll = ScrollContainer.new()
	skip_scroll.name = "SkipScroll"
	skip_scroll.set_anchors_preset(Control.PRESET_CENTER)
	skip_scroll.position = Vector2(-100, -SKIP_HEIGHT / 2.0)
	skip_scroll.custom_minimum_size = Vector2(200, SKIP_HEIGHT)
	skip_scroll.size = Vector2(200, SKIP_HEIGHT)
	skip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_style_scrollbar(skip_scroll.get_v_scroll_bar())
	skip_scroll.hide()
	root.add_child(skip_scroll)
	skip_box = VBoxContainer.new()
	skip_box.name = "SkipBox"
	skip_box.add_theme_constant_override("separation", 3)
	skip_box.custom_minimum_size = Vector2(186, 0)
	skip_scroll.add_child(skip_box)


## 细的像素风滚动条（和对话框的一样）。
func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.13, 0.2, 0.85)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.95, 0.72, 0.8)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.custom_minimum_size.x = 4.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if skip_scroll.visible:
			hide_skip_list()
			return
		toggle()


func toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	root.visible = paused
	if paused:
		Audio.stop_voice()
		skip_button.visible = DevConfig.enabled()
		hide_skip_list()
		$Root/Box/Resume.grab_focus()


## 跳关点列表（测试模式）。
func show_skip_list() -> void:
	if not DevConfig.enabled():
		return
	for c in skip_box.get_children():
		skip_box.remove_child(c)
		c.queue_free()
	for p in DevConfig.skip_points():
		var b := Button.new()
		b.text = str(p.get("name", p.get("floor", "")))
		b.pressed.connect(skip_to.bind(p))
		skip_box.add_child(b)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(hide_skip_list)
	skip_box.add_child(back)
	for b in skip_box.get_children():
		# 键盘上下移动焦点时滚到这一项
		(b as Button).focus_entered.connect(func(): skip_scroll.ensure_control_visible(b))
	box.hide()
	skip_scroll.show()
	skip_scroll.scroll_vertical = 0
	(skip_box.get_child(0) as Button).grab_focus()


func hide_skip_list() -> void:
	skip_scroll.hide()
	box.show()


func skip_to(point: Dictionary) -> void:
	root.hide()
	hide_skip_list()
	DevConfig.skip_to(point)


## 回主界面（没存的进度会丢）。
func to_title() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _restart() -> void:
	get_tree().paused = false
	GameState.reset()
	GameState.checkpoint = Vector2.ZERO
	get_tree().reload_current_scene()
