class_name TextPrompt
extends CanvasLayer
## 对话里的输入框（密码门 / 石像问答这类「自己写答案」的谜题）：await ask(提示, 只收数字?) 返回输入的文字（Esc 取消 = ""）。
## 回车确定；numeric = true 时只留下数字（最多 max_len 位）。打开期间 GameState.in_dialogue = true（人物不动）。
## 测试 / 脚本可以直接调 submit(文字)。
## 判断答案：matches(输入, 答案们, exact)——去掉空白、全角数字转半角、不分大小写；exact = false 时「包含任一答案」就算对。

signal submitted(text: String)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)

var panel: PanelContainer
var prompt_label: Label
var edit: LineEdit
var hint_label: Label
var numeric := false
var max_len := 12


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.96)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	prompt_label = Label.new()
	prompt_label.add_theme_color_override("font_color", GOLD)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size.x = 220
	box.add_child(prompt_label)
	edit = LineEdit.new()
	edit.custom_minimum_size = Vector2(220, 20)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var es := StyleBoxFlat.new()
	es.bg_color = Color(0.22, 0.14, 0.26)
	es.border_color = Color(1, 0.72, 0.86, 0.6)
	es.set_border_width_all(1)
	es.set_corner_radius_all(3)
	es.content_margin_left = 6
	es.content_margin_right = 6
	edit.add_theme_stylebox_override("normal", es)
	edit.add_theme_stylebox_override("focus", es)
	edit.add_theme_color_override("font_color", Color(0.98, 0.95, 1.0))
	edit.text_changed.connect(_on_changed)
	edit.text_submitted.connect(func(t: String): submit(t))
	box.add_child(edit)
	hint_label = Label.new()
	hint_label.text = "回车确定　Esc 放弃"
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.85))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint_label)
	panel.hide()


func is_open() -> bool:
	return panel.visible


func ask(prompt: String, only_digits := false, length := 12) -> String:
	numeric = only_digits
	max_len = length
	prompt_label.text = prompt
	edit.text = ""
	edit.max_length = length
	edit.placeholder_text = "输入数字……" if only_digits else "输入答案……"
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER if only_digits else LineEdit.KEYBOARD_TYPE_DEFAULT
	panel.show()
	await get_tree().process_frame
	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y - 96 - panel.size.y)
	edit.grab_focus()
	DisplayServer.window_set_ime_active(not only_digits)
	var was := GameState.in_dialogue
	GameState.in_dialogue = true
	GameState.dialogue_holds += 1
	if is_instance_valid(GameState.player):
		GameState.player.velocity = Vector2.ZERO
	var text: String = await submitted
	DisplayServer.window_set_ime_active(false)
	GameState.dialogue_holds = maxi(0, GameState.dialogue_holds - 1)
	GameState.in_dialogue = was or Dialogue.is_active() or GameState.in_cutscene or GameState.dialogue_holds > 0
	return text


func submit(text: String) -> void:
	if not is_open():
		return
	panel.hide()
	edit.release_focus()
	Audio.play("book", -8.0, 0.05, 1.4)
	submitted.emit(text.strip_edges())


func _on_changed(t: String) -> void:
	if not numeric:
		return
	var keep := ""
	for ch in normalize(t):
		if ch >= "0" and ch <= "9":
			keep += ch
	if keep != t:
		edit.text = keep.substr(0, max_len)
		edit.caret_column = edit.text.length()


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		edit.text = ""
		submit("")


## 去掉空白、全角数字 / 字母转半角、转小写
static func normalize(t: String) -> String:
	var out := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if c >= 0xFF01 and c <= 0xFF5E:
			c -= 0xFEE0
		if c == 0x3000 or c == 0x20 or c == 0x09:
			continue
		out += String.chr(c)
	return out.to_lower()


static func matches(text: String, answers: Array, exact := false) -> bool:
	var t := normalize(text)
	if t == "":
		return false
	for a in answers:
		var n := normalize(str(a))
		if (t == n) if exact else t.contains(n):
			return true
	return false
