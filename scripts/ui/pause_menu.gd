extends CanvasLayer
## 暂停菜单（Esc）。测试模式（DevConfig.enabled）打开时多一项「测试：跳关」，展开成 dev_config.json 的跳关点列表。

@onready var root: Control = $Root
@onready var box: VBoxContainer = $Root/Box

var skip_button: Button
var skip_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()
	$Root/Box/Resume.pressed.connect(toggle)
	$Root/Box/Restart.pressed.connect(_restart)
	$Root/Box/Quit.pressed.connect(func(): get_tree().quit())
	skip_button = Button.new()
	skip_button.name = "DevSkip"
	skip_button.text = "测试：跳关"
	skip_button.pressed.connect(show_skip_list)
	box.add_child(skip_button)
	box.move_child(skip_button, 2)
	skip_box = VBoxContainer.new()
	skip_box.name = "SkipBox"
	skip_box.add_theme_constant_override("separation", 3)
	skip_box.set_anchors_preset(Control.PRESET_CENTER)
	skip_box.position = Vector2(-90, -70)
	skip_box.custom_minimum_size = Vector2(180, 0)
	skip_box.hide()
	root.add_child(skip_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if skip_box.visible:
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
	box.hide()
	skip_box.show()
	(skip_box.get_child(0) as Button).grab_focus()


func hide_skip_list() -> void:
	skip_box.hide()
	box.show()


func skip_to(point: Dictionary) -> void:
	root.hide()
	hide_skip_list()
	DevConfig.skip_to(point)


func _restart() -> void:
	get_tree().paused = false
	GameState.reset()
	GameState.checkpoint = Vector2.ZERO
	get_tree().reload_current_scene()
