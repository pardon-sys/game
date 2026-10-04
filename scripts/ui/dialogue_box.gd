extends CanvasLayer
## 对话框（Autoload 名为 Dialogue）。对话全部在 data/dialogues/（总文件夹）：
##   common.json                通用对话
##   <楼层组>/*.json            每层一个文件夹：石碑 signs.json、剧情 story.json……（进入楼层时 load_floor 合并）；
##                              人物对话（每个人物一个文件，带 nodes：选项、条件、演绎）由 talk(文件) 播放（DialogueRunner）
## 公主立绘常驻左侧；正式对话和不阻断操作的受挠台词分别显示。

signal finished(id: String)

const DATA_PATH := "res://data/dialogues/common.json"
const PRINCESS := "公主"
const CHARS_PER_SEC := 30.0
const PORTRAIT_SHEET := preload("res://assets/generated/portraits.png")
const PORTRAIT_META := "res://assets/generated/portraits.json"
const HEAD_SHEET := preload("res://assets/generated/portrait_heads.png")
## 立绘套装：公主 / 蓝色公主（同样的格子和顺序）。常驻立绘和 HUD 头像用当前操控角色的 portrait_set。
const PORTRAIT_SETS := {
	"pink": ["res://assets/generated/portraits.png", "res://assets/generated/portrait_heads.png"],
	"blue": ["res://assets/generated/portraits_blue.png", "res://assets/generated/portrait_heads_blue.png"],
}
const TEXT_LEFT_WITH_PORTRAIT := 112.0
## 人物表（立绘、名字、行走图）：data/actors/npcs.json。
const NPCS_PATH := "res://data/actors/npcs.json"
## 右边人物立绘占的宽度（正文让出来）。
const NPC_PORTRAIT_W := 110.0
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
## 人物表 id -> {name, portrait, portrait_region?, sprite...}
var npcs := {}
var npc_portrait: TextureRect
var runner: DialogueRunner
var _npc_tex := {}
var floor_id := ""
var _lines: Array = []
var _index := 0
var _id := ""
var _active := false
var _typing := false
var _chars := 0.0
var _blink := 0.0
## 立绘套装名 -> {portraits, heads}
var _sets := {}
var _portraits: Array[AtlasTexture] = []
var _heads: Array[AtlasTexture] = []
var _emotion := ""
var _portrait_order: Array = []
var _reaction_time := 0.0
var _portrait_tween: Tween
## CG 立绘接口：设置后常驻立绘显示这张图（按比例放进立绘框），公主表情变化不会覆盖它。
var _portrait_override: Texture2D
## 横版大图（笑倒 CG 第三幕）：立绘框变成对话框上方左侧的横版大框。
var _wide := false
var _wide_frame: Panel
var _frame_tween: Tween
var _shake_tween: Tween
## 横版大框的基准位置（抖动围绕它进行）。
var _wide_rect := Rect2()
const PORTRAIT_RECT := Rect2(2, 114, 114, 152)
## 常驻立绘的被挠反馈（抖动、来源贴片、闪光、光晕、「哈哈」飘字、暴击爆闪、组合技心形）。
var portrait_fx: PortraitFx
const WIDE_POS := Vector2(4, 6)
const WIDE_HEIGHT := 180.0


func _ready() -> void:
	panel.hide()
	reaction_panel.hide()
	_style_scrollbar()
	GameState.emotion_changed.connect(_on_emotion_changed)
	GameState.princess_reacted.connect(show_reaction)
	GameState.player_registered.connect(_on_player_registered)
	GameState.combo_triggered.connect(func(id: String, _n: String):
		portrait_fx.on_combo(ComboTracker.is_triple(ComboTracker.combo_def(id))))
	# 立绘与头像是高密度纹理（density 倍像素），显示在固定的逻辑尺寸里（画面 stretch 为 canvas_items）
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(PORTRAIT_META))
	portrait_cell = Vector2(meta["cell"][0], meta["cell"][1])
	portrait_density = int(meta.get("density", 1))
	head_size = int(meta.get("head", 32))
	_portrait_order = meta["order"]
	assert(_portrait_order == GameState.VISUALS, "Portrait order differs from visual registry")
	for i in _portrait_order.size():
		_portraits.append(_atlas(PORTRAIT_SHEET, Rect2(Vector2(i * portrait_cell.x, 0), portrait_cell)))
		_heads.append(_atlas(HEAD_SHEET, Rect2(i * head_size, 0, head_size, head_size)))
	_sets["pink"] = {"portraits": _portraits, "heads": _heads}
	for set_name in PORTRAIT_SETS:
		if set_name == "pink" or not ResourceLoader.exists(PORTRAIT_SETS[set_name][0]):
			continue
		var ptex: Texture2D = load(PORTRAIT_SETS[set_name][0])
		var htex: Texture2D = load(PORTRAIT_SETS[set_name][1])
		var ps: Array[AtlasTexture] = []
		var hs: Array[AtlasTexture] = []
		for i in _portrait_order.size():
			ps.append(_atlas(ptex, Rect2(Vector2(i * portrait_cell.x, 0), portrait_cell)))
			hs.append(_atlas(htex, Rect2(i * head_size, 0, head_size, head_size)))
		_sets[set_name] = {"portraits": ps, "heads": hs}
	_show_portrait("normal")
	portrait_fx = PortraitFx.new()
	add_child(portrait_fx)
	portrait_fx.setup(portrait)
	_common = _read_json(DATA_PATH)
	_data = _common.duplicate()
	npcs = _read_json(NPCS_PATH).get("npcs", {})
	npc_portrait = TextureRect.new()
	npc_portrait.name = "NpcPortrait"
	npc_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_portrait.position = Vector2(364, 114)
	npc_portrait.size = Vector2(114, 152)
	npc_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc_portrait.hide()
	add_child(npc_portrait)
	move_child(npc_portrait, portrait.get_index())
	runner = DialogueRunner.new()
	runner.name = "Runner"
	runner.handler = self
	add_child(runner)


func _on_player_registered(p: PlayableCharacter) -> void:
	_show_portrait("normal")
	portrait_fx.clear()
	if not p.tickled.is_connected(_on_player_tickled):
		p.tickled.connect(_on_player_tickled)
		p.died.connect(func(_a: Actor): portrait_fx.clear())


func _on_player_tickled(hit: HitData) -> void:
	var p := GameState.player
	portrait_fx.on_tickled(hit, p.laugh if is_instance_valid(p) else null)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("%s 解析失败" % path)
	return {}


## 通用对话 + 该楼层（楼层组）文件夹里的普通对话。对话 id 全局唯一，和通用对话重名时报错并保留通用版本。
## 人物对话文件（有 nodes 的）不合并，由 talk() 按文件播放。
func load_floor(id: String) -> void:
	floor_id = id
	_data = _common.duplicate()
	if id == "":
		return
	var dir := Floors.dialogue_dir(id)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var own := _read_json(dir + f)
		if own.has("nodes"):
			continue
		for key in own:
			if str(key).begins_with("_"):
				continue
			if _data.has(key):
				push_error("楼层 %s 的对话 id 与已有对话冲突: %s" % [id, key])
				continue
			_data[key] = own[key]


func _atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at


## 当前操控角色的立绘套装（公主 "pink" / 蓝色公主 "blue"）。
func active_set() -> String:
	var p := GameState.player
	var s := str(p.get("portrait_set")) if is_instance_valid(p) and p.get("portrait_set") != null else "pink"
	return s if _sets.has(s) else "pink"


## 全身立绘（对话框用）。set_name 为空 = 当前操控角色的那一套。
func portrait_for(emotion: String, set_name := "") -> AtlasTexture:
	var arr: Array = _sets[set_name if _sets.has(set_name) else active_set()]["portraits"]
	return arr[maxi(_portrait_order.find(emotion), 0)]


## 头像（HUD 用）。
func head_for(emotion: String, set_name := "") -> AtlasTexture:
	var arr: Array = _sets[set_name if _sets.has(set_name) else active_set()]["heads"]
	return arr[maxi(_portrait_order.find(emotion), 0)]


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
	# 也可以顺带获得被动技能（如 "grant_passive": "struggle_plus"）
	if line.has("grant_passive"):
		GameState.grant_passive(str(line["grant_passive"]))
	var speaker: String = line.get("speaker", "")
	var emotion: String = line.get("emotion", "")
	var is_princess := speaker == PRINCESS
	var left := TEXT_LEFT_WITH_PORTRAIT
	var npc := npc_of(line)
	# 蓝色公主当主角时，「公主」（粉色公主）说话：她是右边的人物（第八层两人同场）
	if is_princess and hero_speaker() != "" and not line.has("npc"):
		is_princess = false
		npc = "pink_princess"
	# 说话的是当前操控的角色本人（蓝色公主当主角时）：当成主角的台词——左边立绘换表情，右边不再重复显示她
	if (npc != "" and npc == hero_npc()) or (speaker != "" and speaker == hero_speaker()):
		npc = ""
		is_princess = true
		npc_portrait.hide()
	if npc != "":
		_show_npc(npc, emotion)
	elif not is_princess and speaker != "":
		npc_portrait.hide()  # 没有立绘的人物（普通居民）说话：右边不显示
	var right_gap := NPC_PORTRAIT_W if npc_portrait.visible else 0.0
	name_label.position.x = left
	text_label.position.x = left
	text_label.size.x = panel.size.x - left - 10.0 - right_gap
	# 人物说话时公主立绘变暗，公主说话时人物立绘变暗
	portrait.modulate = Color(0.55, 0.5, 0.6) if npc != "" else Color.WHITE
	npc_portrait.modulate = Color(0.55, 0.5, 0.6) if is_princess else Color.WHITE
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


# ------------------------------------------------------------------ 人物对话 / 人物立绘
## 播放人物对话文件（data/dialogues/<楼层组>/<人物>.json，带选项、条件、演绎），await 到结束。
func talk(file: String, node := "") -> void:
	await runner.talk(file, node)


## 人物对话里的 call 效果（小镇设施）。
func open_shop() -> void:
	await Town.open_shop("market")


## 对话里只选训练项目；训练本身等这段对话结束后再开始（Town.start_training_later，不 await）。
func open_training() -> void:
	var r := await Town.choose_training()
	if not r.is_empty():
		runner.end_conversation()   # 选好了就结束对话（不回到选项页），对话收尾后马上开始训练
		Town.start_training_later(r)


## 对话里选择睡觉（床）：结束这段对话，等它收尾后再睡（Sleep），早上的过场按剧情选。
func sleep() -> void:
	runner.end_conversation()
	Sleep.sleep_later(F6Story.morning_cutscene())


func rest() -> void:
	Town.rest(GameState.player)


## 这行台词是哪个人物说的（line.npc，或说话人名字和人物表里的名字一样）。
## 当前操控角色在人物表里的 id（蓝色公主当主角时是 blue_princess；粉色公主不在人物表里，返回 ""）。
func hero_npc() -> String:
	return "blue_princess" if Characters.current() == "blue" else ""


## 当前主角在台词里的名字（蓝色公主当主角时是「蓝色的公主」；有的楼层的人物表里没有她，按名字认）。
func hero_speaker() -> String:
	return "蓝色的公主" if Characters.current() == "blue" else ""


func npc_of(line: Dictionary) -> String:
	if line.has("npc"):
		return str(line["npc"])
	var speaker := str(line.get("speaker", ""))
	if speaker == "" or speaker == PRINCESS:
		return ""
	for id in npcs:
		if str(npcs[id].get("name", "")) == speaker:
			return str(id)
	return ""


## 人物的立绘：有 portrait_set 的（蓝色公主）按台词的 emotion 取那一套里的格子，其它人物只有一张。
func npc_texture(id: String, emotion := "") -> Texture2D:
	var info: Dictionary = npcs.get(id, {})
	if info.has("portrait_set") and _sets.has(str(info["portrait_set"])):
		return portrait_for(emotion if emotion != "" else "normal", str(info["portrait_set"]))
	if _npc_tex.has(id):
		return _npc_tex[id]
	var file := str(info.get("portrait", ""))
	var tex: Texture2D = null
	if file != "" and ResourceLoader.exists(file):
		tex = load(file)
		if info.has("portrait_region"):
			var r: Array = info["portrait_region"]
			tex = _atlas(tex, Rect2(r[0], r[1], r[2], r[3]))
	_npc_tex[id] = tex
	return tex


func _show_npc(id: String, emotion := "") -> void:
	var tex := npc_texture(id, emotion)
	if tex == null:
		npc_portrait.hide()
		return
	var appearing := not npc_portrait.visible or npc_portrait.texture != tex
	npc_portrait.texture = tex
	npc_portrait.show()
	if appearing:
		npc_portrait.position.x = 394.0
		npc_portrait.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(npc_portrait, "position:x", 364.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(npc_portrait, "modulate:a", 1.0, 0.18)


func _on_emotion_changed(emotion: String) -> void:
	_show_portrait(emotion)


## CG 用：替换常驻立绘（null = 恢复为公主当前状态的立绘）。
## wide = true：横版大图，立绘框变成高 180、宽度按图片比例的大框（原比例填满），带粉色边框。
func set_portrait_override(tex: Texture2D, wide := false) -> void:
	_portrait_override = tex
	if tex:
		portrait_fx.clear()
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if tex else TextureRect.STRETCH_SCALE
	var want_wide := wide and tex != null
	if want_wide != _wide or want_wide:
		_set_wide(want_wide, tex)
	var emotion := GameState.player.emotion.current if is_instance_valid(GameState.player) else "normal"
	_emotion = ""  # 强制刷新（播放换图的小跳动）
	_show_portrait(emotion)


func is_portrait_wide() -> bool:
	return _wide


## 立绘随挠痒抖动（几个像素的来回晃动，结束后回到原位）：横版 CG 图连大框一起抖；常驻立绘围绕立绘框位置抖。
func shake_portrait(strength := 2.0, time := 0.2) -> void:
	if _frame_tween and _frame_tween.is_running():
		return  # 大框正在展开，展开完再抖
	if not _wide and (_portrait_tween and _portrait_tween.is_running() or not portrait.visible):
		return  # 立绘正在滑入 / 换表情
	if _shake_tween:
		_shake_tween.kill()
	var base := _wide_rect.position if _wide else PORTRAIT_RECT.position
	_shake_tween = create_tween()
	var steps := maxi(2, int(time / 0.04))
	for i in steps:
		var fade := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * strength * fade
		off = off.round()
		_shake_tween.tween_callback(func():
			portrait.position = base + off
			if _wide:
				_wide_frame.position = base + off - Vector2(2, 2))
		_shake_tween.tween_interval(0.04)
	_shake_tween.tween_callback(func():
		portrait.position = base
		if _wide:
			_wide_frame.position = base - Vector2(2, 2))


## 立绘是否正在抖（测试用）。
func is_portrait_shaking() -> bool:
	return _shake_tween != null and _shake_tween.is_running()


func _set_wide(on: bool, tex: Texture2D) -> void:
	_wide = on
	if _wide_frame == null:
		_wide_frame = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.03, 0.07)
		sb.border_color = Color(0.95, 0.72, 0.84)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		_wide_frame.add_theme_stylebox_override("panel", sb)
		_wide_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_wide_frame)
		move_child(_wide_frame, portrait.get_index())
		_wide_frame.hide()
	if _frame_tween:
		_frame_tween.kill()
	if _shake_tween:
		_shake_tween.kill()
	if _portrait_tween:
		_portrait_tween.kill()
	portrait.scale = Vector2.ONE
	portrait.modulate.a = 1.0
	var rect := PORTRAIT_RECT
	if on:
		var size := tex.get_size()
		rect = Rect2(WIDE_POS, Vector2(roundf(WIDE_HEIGHT * size.x / size.y), WIDE_HEIGHT))
		_wide_rect = rect
		_wide_frame.position = rect.position - Vector2(2, 2)
		_wide_frame.size = rect.size + Vector2(4, 4)
		_wide_frame.modulate.a = 0.0
		_wide_frame.show()
	_frame_tween = create_tween().set_parallel()
	_frame_tween.tween_property(portrait, "position", rect.position, 0.25).set_trans(Tween.TRANS_QUAD)
	_frame_tween.tween_property(portrait, "size", rect.size, 0.25).set_trans(Tween.TRANS_QUAD)
	_frame_tween.tween_property(_wide_frame, "modulate:a", 1.0 if on else 0.0, 0.25)
	if not on:
		_frame_tween.chain().tween_callback(_wide_frame.hide)


func has_portrait_override() -> bool:
	return _portrait_override != null


## 当前显示的立绘贴图（测试 / CG 用）。
func current_portrait() -> Texture2D:
	return portrait.texture if portrait.visible else null


## 立刻结束当前对话（CG 跳过用），照常发出 finished。
func close() -> void:
	if _active:
		_typing = false
		_end()


func _show_portrait(emotion: String) -> void:
	portrait.texture = _portrait_override if _portrait_override else portrait_for(emotion)
	if _wide:  # 横版大图：不做滑入 / 小跳动，位置由 _set_wide 控制
		portrait.show()
		_emotion = emotion
		return
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


## 立绘避让：操控的角色走到左下角立绘的位置时，常驻立绘变半透明（self_modulate，和说话时的变暗互不影响）。
const PORTRAIT_FADE_ALPHA := 0.5


## 操控角色在屏幕上占的矩形是否和常驻立绘重叠。
func player_behind_portrait() -> bool:
	var p := GameState.player
	if not is_instance_valid(p) or not p.is_inside_tree() or _wide or not portrait.visible:
		return false
	var c := p.get_global_transform_with_canvas().origin
	var body := Rect2(c + Vector2(-8, -26), Vector2(16, 28))
	return body.intersects(Rect2(portrait.global_position, portrait.size))


func _update_portrait_fade(delta: float) -> void:
	var target := PORTRAIT_FADE_ALPHA if (not _active and player_behind_portrait()) else 1.0
	portrait.self_modulate.a = move_toward(portrait.self_modulate.a, target, delta * 3.0)


func _process(delta: float) -> void:
	_update_portrait_fade(delta)
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
	ScrollTextBox.style_scrollbar(text_label.get_v_scroll_bar(), 3.0)


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
	npc_portrait.hide()
	portrait.modulate = Color.WHITE
	GameState.emote("", 1.2, false)  # 松开对话中保持的表情，1.2 秒后回到默认
	var id := _id
	finished.emit(id)
	# 稍等片刻再把控制权交还，避免同一次按键触发公主攻击/交互
	await get_tree().create_timer(0.12).timeout
	# 人物对话还在进行（接下来是选项或下一个节点）时不交还控制权：选项用上下键，公主不能跟着走
	if not _active and not GameState.in_cutscene and not runner.is_running():
		GameState.in_dialogue = false
