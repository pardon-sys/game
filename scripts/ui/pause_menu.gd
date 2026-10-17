extends CanvasLayer
## 暂停菜单（Esc）。测试模式（DevConfig.enabled）打开时有测试入口：
##   「测试：跳关」展开成 dev_config.json 的跳关点列表（放在带滚动条的 skip_scroll 里：跳关点多了也能上下滚动，键盘移动焦点时自动滚到可见）；
##   攻防战里（SiegeDirector.current）多两项：「战场情报」（看过的情报列表，点开看简介卡）、「撤退」（回战时小镇，这一波从准备阶段重来）。
##   「测试：训练度」选角色（粉色 / 蓝色公主），每项训练值一行 − / + 调（到所有阶段的最高上限），「全部清零」「全部练满」，改完马上生效。
##   「测试：攻防战」复用同一滚动框：跳波次 / 免费部署 30 座友塔 / 清除测试塔。

@onready var root: Control = $Root
@onready var box: VBoxContainer = $Root/Box

var skip_button: Button
## 音乐音量（Audio.music_volume，左右键调）。
var music_slider: HSlider
var sfx_slider: HSlider
var skip_box: VBoxContainer
var skip_scroll: ScrollContainer
var train_button: Button
var siege_test_button: Button
var main_scroll: ScrollContainer
var intel_button: Button
var retreat_button: Button
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
	music_slider = _volume_slider("音乐", "MusicVolume", Audio.music_volume, Audio.set_music_volume)
	sfx_slider = _volume_slider("音效", "SfxVolume", Audio.sfx_volume, Audio.set_sfx_volume)
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
	siege_test_button = Button.new()
	siege_test_button.name = "DevSiege"
	siege_test_button.text = "测试：攻防战"
	siege_test_button.pressed.connect(show_siege_tests)
	box.add_child(siege_test_button)
	box.move_child(siege_test_button, 4)
	intel_button = Button.new()
	intel_button.name = "SiegeIntel"
	intel_button.text = "战场情报"
	intel_button.pressed.connect(show_intel_list)
	box.add_child(intel_button)
	box.move_child(intel_button, 1)
	retreat_button = Button.new()
	retreat_button.name = "SiegeRetreat"
	retreat_button.text = "撤退（回战时小镇）"
	retreat_button.pressed.connect(func():
		toggle()
		if SiegeDirector.current:
			SiegeDirector.current.retreat())
	box.add_child(retreat_button)
	box.move_child(retreat_button, 2)
	box.move_child(siege_test_button, 3)
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
	# 测试项多时主菜单也滚动，避免 270px 高的画面底部按钮出屏。
	main_scroll = ScrollContainer.new()
	main_scroll.name = "MainScroll"
	main_scroll.set_anchors_preset(Control.PRESET_CENTER)
	main_scroll.offset_left = -120.0
	main_scroll.offset_right = 120.0
	main_scroll.offset_top = -SKIP_HEIGHT / 2.0
	main_scroll.offset_bottom = SKIP_HEIGHT / 2.0
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(main_scroll.get_v_scroll_bar())
	root.add_child(main_scroll)
	box.reparent(main_scroll)
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2.ZERO
	box.custom_minimum_size = Vector2(226, 0)
	for item in box.get_children():
		if item is Button:
			item.focus_entered.connect(func(): main_scroll.ensure_control_visible(item))
	for slider in [music_slider, sfx_slider]:
		slider.focus_entered.connect(func(): main_scroll.ensure_control_visible(slider))


## 两种音量沿用同一行控件；键盘左右键调节，聚焦时主菜单自动滚到该行。
func _volume_slider(label_text: String, control_name: String, value: float, changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.name = control_name.trim_suffix("Volume") + "Row"
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = control_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.custom_minimum_size = Vector2(70, 12)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = value
	slider.value_changed.connect(changed)
	row.add_child(slider)
	box.add_child(row)
	box.move_child(row, box.get_child_count() - 2)
	return slider


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
		siege_test_button.visible = DevConfig.enabled() and is_instance_valid(SiegeDirector.current)
		intel_button.visible = SiegeDirector.current != null
		retreat_button.visible = SiegeDirector.current != null
		music_slider.set_value_no_signal(Audio.music_volume)
		sfx_slider.set_value_no_signal(Audio.sfx_volume)
		hide_skip_list()
		box.get_node("Resume").grab_focus()


## 攻防战的战场情报列表（看过的；点一条打开简介卡）。
func show_intel_list() -> void:
	for c in skip_box.get_children():
		c.queue_free()
	var keys := SiegeIntel.seen_keys()
	if keys.is_empty():
		var l := Label.new()
		l.text = "还没有情报"
		skip_box.add_child(l)
	for k in keys:
		var b := Button.new()
		b.text = str(SiegeIntel.entry(str(k)).get("name", k))
		b.pressed.connect(func():
			var d := SiegeDirector.current
			if d and d.intel:
				d.intel.open(str(k)))
		skip_box.add_child(b)
	skip_scroll.show()
	box.hide()
	main_scroll.hide()
	if skip_box.get_child_count() > 0 and skip_box.get_child(0) is Button:
		(skip_box.get_child(0) as Button).grab_focus.call_deferred()


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
	main_scroll.hide()
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
	main_scroll.hide()
	# 训练度页比跳关列表宽，往下挪一点（不挡住「暂停」标题）
	_scroll_rect(300.0, 0.0)
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
	main_scroll.show()
	box.get_node("Resume").grab_focus()


## 测试命令只在攻防战、开发模式下显示；过场 / 结算期间禁止跳波避免旧协程继续运行。
func show_siege_tests() -> void:
	var d := SiegeDirector.current
	if not DevConfig.enabled() or not is_instance_valid(d):
		return
	for child in skip_box.get_children():
		skip_box.remove_child(child)
		child.queue_free()
	var ready := SiegeDevTools.available(d)
	var title := Label.new()
	title.text = "攻防战测试 · 当前第 %d 波" % d.wave
	title.add_theme_font_size_override("font_size", 10)
	skip_box.add_child(title)
	var note := Label.new()
	note.text = "跳波清敌军、复位公主 / 城墙，保留友塔和冰晶。\n部署：免费 / 已解锁类型 / 1级。" if ready else "过场 / 结算中，结束后再测试。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 286.0
	note.add_theme_font_size_override("font_size", 9)
	skip_box.add_child(note)
	for spec in [["一键部署 30 座友塔", _dev_deploy], ["全部友塔免费升一级", _dev_upgrade], ["清除本次部署的测试友塔", _dev_clear_towers]]:
		var b := Button.new()
		b.text = str(spec[0])
		b.disabled = not ready
		b.pressed.connect(spec[1])
		skip_box.add_child(b)
	for i in d.data.get("waves", []).size():
		var b := Button.new()
		b.name = "DevWave%d" % (i + 1)
		b.text = "第 %d 波：%s" % [i + 1, str(d.wave_data(i + 1).get("name", ""))]
		b.disabled = not ready
		b.pressed.connect(_dev_jump_wave.bind(i + 1))
		skip_box.add_child(b)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(hide_skip_list)
	skip_box.add_child(back)
	for item in skip_box.get_children():
		if item is Button:
			item.focus_entered.connect(func(): skip_scroll.ensure_control_visible(item))
	box.hide()
	main_scroll.hide()
	_scroll_rect(300.0, 0.0)
	skip_box.custom_minimum_size = Vector2(286, 0)
	skip_scroll.show()
	skip_scroll.scroll_vertical = 0
	if ready:
		(skip_box.get_child(2) as Button).grab_focus()
	else:
		back.grab_focus()


func _dev_jump_wave(wave: int) -> void:
	# 先禁用整页，防止 queue_free 等待帧内连续点击发起多个跳波。
	for item in skip_box.get_children():
		if item is Button:
			item.disabled = true
	var ok := await SiegeDevTools.jump_wave(SiegeDirector.current, wave)
	if ok:
		hide_skip_list()
		toggle()
	else:
		show_siege_tests()


func _dev_deploy() -> void:
	SiegeDevTools.deploy_towers(SiegeDirector.current)
	show_siege_tests()


func _dev_clear_towers() -> void:
	SiegeDevTools.clear_test_towers(SiegeDirector.current)
	show_siege_tests()


func _dev_upgrade() -> void:
	SiegeDevTools.upgrade_towers(SiegeDirector.current)
	show_siege_tests()


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
