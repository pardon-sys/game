extends CanvasLayer
## 对话框（Autoload 名为 Dialogue）。通用对话来自 data/dialogues.json，
## 楼层专属对话来自 levels/<id>/dialogues.json（进入楼层时 load_floor 合并）。
## 公主立绘常驻左侧；正式对话和不阻断操作的受挠台词分别显示。

signal finished(id: String)

const DATA_PATH := "res://data/dialogues.json"
const PRINCESS := "公主"
const CHARS_PER_SEC := 30.0
const PORTRAIT_SHEET := preload("res://assets/generated/portraits.png")
const PORTRAIT_META := "res://assets/generated/portraits.json"
const HEAD_SHEET := preload("res://assets/generated/portrait_heads.png")
const TEXT_LEFT_WITH_PORTRAIT := 112.0
## 手动滚动一行的像素数（12px 字体 + 行距）。
const LINE_STEP := 13.0

var portrait_cell := Vector2(114, 152)
var portrait_density := 1
var head_size := 32

@onready var panel: Control = $Panel
@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $Panel/Name
@onready var text_label: RichTextLabel = $Panel/Text
@onready var arrow: Label = $Panel/Arrow
@onready var reaction_panel: Panel = $Reaction
@onready var reaction_text: Label = $Reaction/Text

var _data := {}
var _common := {}
var floor_id := ""
var _lines: Array = []
var _index := 0
var _id := ""
var _active := false
var _typing := false
var _chars := 0.0
var _blink := 0.0
var _portraits: Array[AtlasTexture] = []
var _heads: Array[AtlasTexture] = []
var _emotion := ""
var _portrait_order: Array = []
var _reaction_time := 0.0
var _portrait_tween: Tween


func _ready() -> void:
	panel.hide()
	reaction_panel.hide()
	_style_scrollbar()
	GameState.emotion_changed.connect(_on_emotion_changed)
	GameState.princess_reacted.connect(show_reaction)
	GameState.player_registered.connect(func(_player: PlayableCharacter): _show_portrait("normal"))
	# 立绘与头像是高密度纹理（density 倍像素），显示在固定的逻辑尺寸里（画面 stretch 为 canvas_items）
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(PORTRAIT_META))
	portrait_cell = Vector2(meta["cell"][0], meta["cell"][1])
	portrait_density = int(meta.get("density", 1))
	head_size = int(meta.get("head", 32))
	_portrait_order = meta["order"]
	assert(_portrait_order == GameState.EMOTIONS, "Portrait order differs from visual registry")
	for i in _portrait_order.size():
		_portraits.append(_atlas(PORTRAIT_SHEET, Rect2(Vector2(i * portrait_cell.x, 0), portrait_cell)))
		_heads.append(_atlas(HEAD_SHEET, Rect2(i * head_size, 0, head_size, head_size)))
	_show_portrait("normal")
	_common = _read_json(DATA_PATH)
	_data = _common.duplicate()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("%s 解析失败" % path)
	return {}


## 通用对话 + 该楼层的对话。对话 id 全局唯一，和通用对话重名时报错并保留通用版本。
func load_floor(id: String) -> void:
	floor_id = id
	_data = _common.duplicate()
	if id == "":
		return
	var own := _read_json(Floors.dialogues_path(id))
	for key in own:
		if _data.has(key):
			push_error("楼层 %s 的对话 id 与通用对话冲突: %s" % [id, key])
			continue
		_data[key] = own[key]


func _atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at


## 全身立绘（对话框用）。
func portrait_for(emotion: String) -> AtlasTexture:
	return _portraits[maxi(_portrait_order.find(emotion), 0)]


## 头像（HUD 用）。
func head_for(emotion: String) -> AtlasTexture:
	return _heads[maxi(_portrait_order.find(emotion), 0)]


func has_dialogue(id: String) -> bool:
	return _data.has(id)


func is_active() -> bool:
	return _active


func start(id: String) -> void:
	if not _data.has(id):
		push_warning("没有对话: " + id)
		return
	start_lines(_data[id], id)


func start_lines(lines: Array, id := "") -> void:
	if _active or lines.is_empty():
		return
	_lines = lines
	_index = 0
	_id = id
	_active = true
	GameState.in_dialogue = true
	show_reaction("", 0.0)
	panel.show()
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	# 对话行可以顺带设置剧情标记（如 "set_flag": "magic_unlocked"）
	if line.has("set_flag"):
		GameState.set_flag(str(line["set_flag"]))
	var speaker: String = line.get("speaker", "")
	var emotion: String = line.get("emotion", "")
	var is_princess := speaker == PRINCESS
	var left := TEXT_LEFT_WITH_PORTRAIT
	name_label.position.x = left
	text_label.position.x = left
	text_label.size.x = panel.size.x - left - 10.0
	if is_princess:
		GameState.emote(emotion if emotion != "" else "normal", 0.0, true)
		_show_portrait(GameState.player.emotion.current if is_instance_valid(GameState.player) else "normal")
	name_label.text = speaker
	name_label.visible = speaker != ""
	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	_chars = 0.0
	_typing = true
	arrow.visible = false


func _on_emotion_changed(emotion: String) -> void:
	_show_portrait(emotion)


func _show_portrait(emotion: String) -> void:
	portrait.texture = portrait_for(emotion)
	var appearing := not portrait.visible
	portrait.show()
	if emotion == _emotion and not appearing:
		return
	_emotion = emotion
	# 出场时从左侧滑入，换表情时轻轻一跳
	if _portrait_tween:
		_portrait_tween.kill()
	portrait.scale = Vector2.ONE
	var tw := create_tween()
	_portrait_tween = tw
	if appearing:
		portrait.position.x = -30.0
		portrait.modulate.a = 0.0
		tw.set_parallel()
		tw.tween_property(portrait, "position:x", 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(portrait, "modulate:a", 1.0, 0.18)
	else:
		portrait.position.x = 2.0
		portrait.modulate.a = 1.0
		tw.tween_property(portrait, "scale", Vector2(1.04, 0.96), 0.06)
		tw.tween_property(portrait, "scale", Vector2(0.98, 1.03), 0.06)
		tw.tween_property(portrait, "scale", Vector2.ONE, 0.06)


func show_reaction(text: String, duration: float) -> void:
	_reaction_time = duration if not _active else 0.0
	reaction_text.text = text
	reaction_panel.visible = text != "" and _reaction_time > 0.0


func _process(delta: float) -> void:
	if _reaction_time > 0.0:
		_reaction_time = maxf(0.0, _reaction_time - delta)
		if _reaction_time == 0.0:
			reaction_panel.hide()
	if not _active:
		return
	if _typing:
		_chars += delta * CHARS_PER_SEC
		text_label.visible_characters = int(_chars)
		if text_label.visible_characters >= text_label.get_total_character_count():
			_finish_typing()
	else:
		_blink += delta
		arrow.visible = fmod(_blink, 0.8) < 0.5


## 细的像素风滚动条（内容超出对话框时才出现）。
func _style_scrollbar() -> void:
	var bar := text_label.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.13, 0.2, 0.8)
	track.content_margin_left = 1.0
	track.content_margin_right = 1.0
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.95, 0.72, 0.8)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.custom_minimum_size.x = 3.0


## 按行滚动对话文本（dir = -1 向上，1 向下）。
func scroll_text(dir: int) -> void:
	var bar := text_label.get_v_scroll_bar()
	bar.value = clampf(bar.value + dir * LINE_STEP, 0.0, bar.max_value)


## 文本是否超出对话框（需要滚动）。
func is_text_scrollable() -> bool:
	return text_label.get_content_height() > text_label.size.y


func _finish_typing() -> void:
	_typing = false
	text_label.visible_characters = -1
	_blink = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	# 内容超出对话框时可滚动：打字时自动跟随到底部；↑/↓（W/S）或鼠标滚轮手动翻看
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		scroll_text(-1 if event.is_action_pressed("move_up") else 1)
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


## 跳过打字效果或进入下一句（测试中也会直接调用）。
func advance() -> void:
	if _typing:
		_finish_typing()
		return
	_index += 1
	if _index >= _lines.size():
		_end()
	else:
		_show_line()


func _end() -> void:
	_active = false
	panel.hide()
	GameState.emote("", 1.2, false)  # 松开对话中保持的表情，1.2 秒后回到默认
	var id := _id
	finished.emit(id)
	# 稍等片刻再把控制权交还，避免同一次按键触发公主攻击/交互
	await get_tree().create_timer(0.12).timeout
	if not _active:
		GameState.in_dialogue = false
