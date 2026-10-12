class_name SiegeIntel
extends CanvasLayer
## 攻防战的战场情报（SiegeDirector 创建）：新的怪物 / 冰塔 / 敌塔 / 陷阱 / 临时装备第一次出现时，屏幕右侧弹出它的图标并闪一下；
## 鼠标点图标，或按 H（输入动作 intel）打开最新的一条：简介卡写外观、机制、应对办法，打开时暂停游戏（Esc / E / H / 点击关闭）。
## 看过的记在剧情标记 siege_intel_<键>；暂停菜单的「战场情报」可以再翻（open_index）。
## 文本：data/siege/intel.json {键: {name, kind, icon（icons 图集里的名字）, desc, how}}（tools/build/gen_floor06_siege.py 生成）。
## 图标：assets/generated/siege/icons.png + icons.json（tools/art/gen_siege_art.py）。

const PATH := "res://data/siege/intel.json"
const ICONS := "res://assets/generated/siege/icons.png"
const ICONS_META := "res://assets/generated/siege/icons.json"
const COL_X := 458.0
const COL_Y := 116.0
const MAX_ICONS := 7

static var _data := {}
static var _icon_meta := {}

## 这一场里出现过的（图标栏里显示的，新的在前）
var shown: Array[String] = []
var _buttons: Array[Control] = []
var card: Panel
var _card_key := ""
var _paused_by_me := false
var _flash := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
		_data = parsed if parsed is Dictionary else {}
	return _data


## 动作当前绑定的键（按 InputMap 现查，改了键位也跟着变）：最多 n 个，用「 / 」连起来。
## 进攻防战、开场过场放完后自动弹出按键说明（测试里关掉）。
static var auto_controls := true


static func keys_of(action: String, n := 2) -> String:
	if not InputMap.has_action(action):
		return "?"
	var out: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k == null:
			continue
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var name := OS.get_keycode_string(code)
		name = {"Escape": "Esc", "Space": "空格", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→"}.get(name, name)
		if name != "" and not out.has(name):
			out.append(name)
		if out.size() >= n:
			break
	return " / ".join(out) if not out.is_empty() else "?"


## 攻防战按键说明（情报 controls 的正文，按当前键位生成）。
static func controls_text() -> String:
	var k := func(a: String, n := 2) -> String: return keys_of(a, n)
	return "\n".join([
		"【通用】移动 %s/%s/%s/%s　攻击 %s　冲刺 %s　交互 / 救人 / 帮搭档解开装备（按住）%s" % [k.call("move_up", 1), k.call("move_left", 1),
			k.call("move_down", 1), k.call("move_right", 1), k.call("attack", 1), k.call("dash"), k.call("interact", 1)],
		"换人操控 %s　薄荷糖 %s　憋笑 %s　背包 %s" % [k.call("switch_character", 1), k.call("use_item", 1), k.call("hold_laugh", 1), k.call("backpack")],
		"【粉色公主】%s：在脚下放冰塔基座、选塔；站在冰塔旁按 %s 升级 / 拆掉" % [k.call("siege_build", 1), k.call("siege_build", 1)],
		"【蓝色公主】%s~%s：城墙法术（冰锥雨 / 冰晶结界 / 清凉雪花 / 冰墙加固 / 暴风雪 / 冰川突刺 / 冰镜分身）" % [k.call("siege_spell_1", 1), k.call("siege_spell_7", 1)],
		"　瞄准时方向键 / 鼠标移动准星，再按同一个数字 / %s / 左键放出，%s 取消；%s 是她自己的冰晶结界" % [k.call("interact", 1), k.call("pause", 1), k.call("magic", 1)],
		"【镜头】滚轮 / %s / %s 缩放　%s 全景（暂停）" % [k.call("zoom_out", 1), k.call("zoom_in", 1), k.call("overview", 1)],
		"【其它】%s 看新情报（右边的图标也能点）　号角旁按 %s 提前开打　%s 暂停菜单（战场情报 / 撤退）" % [k.call("intel", 1), k.call("interact", 1), k.call("pause", 1)],
	])


static func entry(key: String) -> Dictionary:
	var e: Variant = data().get(key, {})
	return e if e is Dictionary else {}


static func icon_region(key: String) -> Rect2:
	if _icon_meta.is_empty() and FileAccess.file_exists(ICONS_META):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ICONS_META))
		_icon_meta = parsed if parsed is Dictionary else {}
	var r: Variant = _icon_meta.get(str(entry(key).get("icon", key)), null)
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])) if r is Array else Rect2()


func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS


## 新东西出现：没有情报条目的忽略；第一次见到时弹图标并闪。返回是不是新的。
func discover(key: String) -> bool:
	if entry(key).is_empty() or shown.has(key):
		return false
	shown.push_front(key)
	var fresh := not GameState.has_flag("siege_intel_" + key)
	if fresh:
		_flash[key] = 3.0
		GameState.notify("新情报：%s（按 H 查看）" % str(entry(key).get("name", key)))
		Audio.play("book", -8.0, 0.0, 1.4)
	_rebuild()
	return fresh


func _rebuild() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	# 看过的图标不再留在右边（暂停菜单的「战场情报」里还能翻）
	var unread := shown.filter(func(k): return not GameState.has_flag("siege_intel_" + k))
	for i in mini(unread.size(), MAX_ICONS):
		var key: String = unread[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(COL_X, COL_Y + i * 20.0)
		b.size = Vector2(18, 18)
		b.custom_minimum_size = Vector2(18, 18)
		b.tooltip_text = str(entry(key).get("name", key))
		var ic := TextureRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size = Vector2(16, 16)
		ic.position = Vector2(1, 1)
		var r := icon_region(key)
		if r.size != Vector2.ZERO and ResourceLoader.exists(ICONS):
			var at := AtlasTexture.new()
			at.atlas = load(ICONS)
			at.region = r
			ic.texture = at
		b.add_child(ic)
		b.pressed.connect(func(): open(key))
		b.draw.connect(func(): _draw_frame(b, key))
		add_child(b)
		_buttons.append(b)


func _draw_frame(b: Control, key: String) -> void:
	var lit := float(_flash.get(key, 0.0)) > 0.0 and int(Time.get_ticks_msec() / 150) % 2 == 0
	var unread := not GameState.has_flag("siege_intel_" + key)
	b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(0.13, 0.08, 0.16, 0.85))
	b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(1, 0.86, 0.4) if lit else (Color(1, 0.6, 0.8) if unread else Color(0.5, 0.35, 0.55)), false, 1.0)


func _process(delta: float) -> void:
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	for b in _buttons:
		b.queue_redraw()
	var hide_icons: bool = CG.is_busy() or GameState.in_cutscene
	for b in _buttons:
		b.visible = not hide_icons


## 卡片开着时 Esc / E / H / 点击只关卡片（在 _input 里先处理，暂停菜单收不到这次 Esc）。
var _card_box: ScrollTextBox


func _input(event: InputEvent) -> void:
	# 卡片开着时 ↑↓ 滚动正文
	if card and card.visible and event.is_pressed() and _card_box and (event.is_action("move_up") or event.is_action("ui_up")
			or event.is_action("move_down") or event.is_action("ui_down")):
		_card_box.scroll_by(-1 if (event.is_action("move_up") or event.is_action("ui_up")) else 1)
		get_viewport().set_input_as_handled()
		return
	if card and card.visible and event.is_pressed() and not event.is_echo() and (event.is_action("pause") or event.is_action("ui_cancel")
			or event.is_action("interact") or event.is_action("intel") or (event is InputEventMouseButton and not _over_icon(event))):
		close()
		get_viewport().set_input_as_handled()


func _over_icon(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and _buttons.any(func(b): return is_instance_valid(b) and (b as Control).get_global_rect().has_point(mb.position))


func _unhandled_input(event: InputEvent) -> void:
	if card and card.visible:
		return
	if event.is_action_pressed("intel") and not GameState.in_dialogue and not shown.is_empty():
		var key := ""
		for k in shown:
			if not GameState.has_flag("siege_intel_" + k):
				key = k
				break
		if key == "":
			key = shown[0]
		open(key)
		get_viewport().set_input_as_handled()


## 打开一条情报的简介卡（暂停游戏）。
func open(key: String) -> void:
	var e := entry(key)
	if e.is_empty():
		return
	GameState.set_flag("siege_intel_" + key)
	_flash.erase(key)
	_card_key = key
	_rebuild.call_deferred()
	if card == null:
		card = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.07, 0.15, 0.97)
		sb.border_color = Color(1, 0.72, 0.86)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", sb)
		card.position = Vector2(80, 40)
		card.size = Vector2(320, 176)
		add_child(card)
	for c in card.get_children():
		c.queue_free()
	var ic := TextureRect.new()
	ic.position = Vector2(12, 12)
	ic.size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := icon_region(key)
	if r.size != Vector2.ZERO and ResourceLoader.exists(ICONS):
		var at := AtlasTexture.new()
		at.atlas = load(ICONS)
		at.region = r
		ic.texture = at
	card.add_child(ic)
	var title := _label(str(e.get("name", key)), Color(1, 0.86, 0.4), 13)
	title.position = Vector2(52, 10)
	card.add_child(title)
	var kind := _label("【%s】" % str(e.get("kind", "")), Color(1, 0.65, 0.85), 9)
	kind.position = Vector2(52, 30)
	card.add_child(kind)
	var box := ScrollTextBox.make(Rect2(12, 50, 296, 104), 3, 10)
	card.add_child(box)
	_card_box = box
	box.add_line(str(e.get("desc", "")), Color(0.95, 0.92, 0.98))
	if key == "controls":
		for line in controls_text().split("\n"):
			box.add_line(line, Color(1, 0.86, 0.6) if line.begins_with("【") else Color(0.95, 0.92, 0.98))
	if str(e.get("mech", "")) != "":
		box.add_line("机制：" + str(e.get("mech", "")), Color(1.0, 0.7, 0.75))
	if str(e.get("how", "")) != "":
		box.add_line("应对：" + str(e.get("how", "")), Color(0.6, 1.0, 0.75))
	var hint := _label("↑↓ 滚动　Esc / E / H 关闭", Color(0.7, 0.62, 0.78), 8)
	hint.position = Vector2(12, 158)
	card.add_child(hint)
	card.show()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true


func close() -> void:
	if card:
		card.hide()
	_card_key = ""
	if _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false


func is_open() -> bool:
	return card != null and card.visible


## 暂停菜单「战场情报」：看过的全部（按情报表的顺序）。
static func seen_keys() -> Array:
	return data().keys().filter(func(k): return k != "_说明" and GameState.has_flag("siege_intel_" + str(k)))


func _label(t: String, col: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 3)
	return l
