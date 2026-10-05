extends CanvasLayer
## 暂停菜单（Esc）。测试模式（DevConfig.enabled）打开时多两项：
##   「测试：跳关」展开成 dev_config.json 的跳关点列表（放在带滚动条的 skip_scroll 里：跳关点多了也能上下滚动，键盘移动焦点时自动滚到可见）；
##   「测试：训练度」选角色（粉色 / 蓝色公主），每项训练值一行 − / + 调（到所有阶段的最高上限），「全部清零」「全部练满」，改完马上生效。

@onready var root: Control = $Root
@onready var box: VBoxContainer = $Root/Box

var skip_button: Button
## 音乐音量（Audio.music_volume，左右键调）。
var music_slider: HSlider
var skip_box: VBoxContainer
var skip_scroll: ScrollContainer
var train_button: Button
## 训练度页正在调的角色（"pink" / "blue"）
var train_who := "pink"
## 一项分几步调满
const TRAIN_STEPS := 10
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
	var music_row := HBoxContainer.new()
	music_row.name = "MusicRow"
	var music_label := Label.new()
	music_label.text = "音乐"
	music_row.add_child(music_label)
	music_slider = HSlider.new()
	music_slider.name = "MusicVolume"
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.1
	music_slider.custom_minimum_size = Vector2(70, 12)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_slider.focus_mode = Control.FOCUS_ALL
	music_slider.value = Audio.music_volume
	music_slider.value_changed.connect(Audio.set_music_volume)
	music_row.add_child(music_slider)
	box.add_child(music_row)
	box.move_child(music_row, box.get_child_count() - 2)
	skip_button = Button.new()
	skip_button.name = "DevSkip"
	skip_button.text = "测试：跳关"
	skip_button.pressed.connect(show_skip_list)
	box.add_child(skip_button)
	box.move_child(skip_button, 2)
	train_button = Button.new()
	train_button.name = "DevTraining"
	train_button.text = "测试：训练度"
	train_button.pressed.connect(show_training)
	box.add_child(train_button)
	box.move_child(train_button, 3)
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
	ScrollTextBox.style_scrollbar(bar)


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
		train_button.visible = DevConfig.enabled()
		music_slider.set_value_no_signal(Audio.music_volume)
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


## 训练度页（测试模式）：和跳关列表共用滚动框。
func show_training(focus_index := 0) -> void:
	if not DevConfig.enabled():
		return
	if Characters.current() != "" and focus_index == 0 and not skip_scroll.visible:
		train_who = Characters.current() if Characters.current() in ["pink", "blue"] else "pink"
	for c in skip_box.get_children():
		skip_box.remove_child(c)
		c.queue_free()
	var who_b := Button.new()
	who_b.text = "角色：%s（点击切换）" % ("蓝色公主" if train_who == "blue" else "粉色公主")
	who_b.pressed.connect(_train_toggle_who)
	skip_box.add_child(who_b)
	for item in TrainingStats.all_keys():
		var key: String = item[0]
		var mx := TrainingStats.max_cap(key)
		if mx <= 0.0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var l := Label.new()
		l.text = "%s %s/%s" % [item[1], _num(TrainingStats.dev_value(train_who, key)), _num(mx)]
		l.custom_minimum_size = Vector2(230, 0)
		l.add_theme_font_size_override("font_size", 10)
		row.add_child(l)
		for dir_sign in [-1, 1]:
			var b := Button.new()
			b.text = "−" if dir_sign < 0 else "+"
			b.custom_minimum_size = Vector2(20, 0)
			b.pressed.connect(_train_step.bind(key, dir_sign, skip_box.get_child_count()))
			row.add_child(b)
		skip_box.add_child(row)
	for spec in [["全部清零", 0.0], ["全部练满", 1.0]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(_train_all.bind(spec[1]))
		skip_box.add_child(b)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(hide_skip_list)
	skip_box.add_child(back)
	var focusables: Array[Control] = []
	for c in skip_box.get_children():
		if c is Button:
			focusables.append(c)
		else:
			for cc in c.get_children():
				if cc is Button:
					focusables.append(cc)
	for f in focusables:
		f.focus_entered.connect(func(): skip_scroll.ensure_control_visible(f))
	box.hide()
	# 训练度页比跳关列表宽，往下挪一点（不挡住「暂停」标题）
	_scroll_rect(300.0, 28.0)
	skip_box.custom_minimum_size = Vector2(286, 0)
	skip_scroll.show()
	var target := skip_box.get_child(clampi(focus_index, 0, skip_box.get_child_count() - 1))
	if target is Button:
		(target as Button).grab_focus()
	elif target.get_child_count() > 0:
		(target.get_child(target.get_child_count() - 1) as Button).grab_focus()


func _num(v: float) -> String:
	return str(snappedf(v, 0.001)) if v < 10.0 else str(roundi(v))


func _train_toggle_who() -> void:
	train_who = "blue" if train_who == "pink" else "pink"
	show_training(1)
	(skip_box.get_child(0) as Button).grab_focus()


func _train_step(key: String, dir_sign: int, row_index: int) -> void:
	var mx := TrainingStats.max_cap(key)
	TrainingStats.dev_set(train_who, key, TrainingStats.dev_value(train_who, key) + dir_sign * mx / TRAIN_STEPS)
	var keep := skip_scroll.scroll_vertical
	show_training(row_index)
	skip_scroll.scroll_vertical = keep


func _train_all(ratio: float) -> void:
	for item in TrainingStats.all_keys():
		TrainingStats.dev_set(train_who, item[0], TrainingStats.max_cap(item[0]) * ratio)
	GameState.notify("%s的训练度：%s" % ["蓝色公主" if train_who == "blue" else "粉色公主", "全部清零" if ratio == 0.0 else "全部练满"])
	show_training(1)


func hide_skip_list() -> void:
	skip_scroll.hide()
	_scroll_rect(200.0, 0.0)
	skip_box.custom_minimum_size = Vector2(186, 0)
	box.show()


## 滚动框的大小（锚点在屏幕中间，用 offset 摆）：宽 w，往下挪 dy。
func _scroll_rect(w: float, dy: float) -> void:
	skip_scroll.offset_left = -w / 2.0
	skip_scroll.offset_right = w / 2.0
	skip_scroll.offset_top = -SKIP_HEIGHT / 2.0 + dy
	skip_scroll.offset_bottom = SKIP_HEIGHT / 2.0 + dy


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
