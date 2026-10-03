class_name SlotMenu
extends CanvasLayer
## 存档位选择界面（存档点存档、主界面读取共用）。mode = "save" / "load"。
## await choose(mode) 返回选中的存档位（1~SLOTS），取消返回 -1。存档时覆盖已有存档要再按一次确认。
## 测试 / 脚本可以直接调 pick(存档位) 和 cancel()。

signal done(slot: int)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.6, 0.55, 0.65)

var mode := "save"
var selected := 1
var confirm := false
var panel: Panel
var title: Label
var rows: VBoxContainer
var hint: Label
var _paused_by_me := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.07, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.97)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(70, 40)
	panel.size = Vector2(340, 190)
	add_child(panel)
	title = _label(GOLD)
	title.position = Vector2(12, 6)
	panel.add_child(title)
	rows = VBoxContainer.new()
	rows.position = Vector2(12, 30)
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)
	hint = _label(DIM)
	hint.position = Vector2(12, 166)
	panel.add_child(hint)


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	return l


func choose(m: String) -> int:
	mode = m
	selected = maxi(SaveSystem.latest(), 1) if m == "load" else 1
	confirm = false
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	_refresh()
	var s: int = await done
	# 选完后主界面可能马上换场景（菜单已离开场景树），用主循环取场景树
	if _paused_by_me:
		(Engine.get_main_loop() as SceneTree).paused = false
	return s


func pick(slot: int) -> void:
	if mode == "load" and SaveSystem.info(slot).is_empty():
		Audio.play("locked", -8.0)
		return
	if mode == "save" and not SaveSystem.info(slot).is_empty() and not confirm:
		confirm = true
		selected = slot
		_refresh()
		return
	done.emit(slot)


func cancel() -> void:
	done.emit(-1)


static func format_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _refresh() -> void:
	title.text = "存档　选择存档位置" if mode == "save" else "读取存档"
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	for s in range(1, SaveSystem.SLOTS + 1):
		var info := SaveSystem.info(s)
		var l := _label(PINK if s == selected else (TEXT if not info.is_empty() else DIM))
		var head := ("▶ " if s == selected else "　 ") + "存档 %d　" % s
		if info.is_empty():
			l.text = head + "（空）"
		else:
			l.text = head + "%s · %s\n　　　%s　游戏时间 %s" % [info["floor"], info["place"], str(info["time"]).replace("T", " ").left(16),
				format_time(float(info["play_time"]))]
		rows.add_child(l)
	if confirm:
		hint.text = "存档 %d 已有内容，再按 E 覆盖；Esc 取消" % selected
	else:
		hint.text = "上下 选择　E 确定　Esc 取消"


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not is_inside_tree():
		return
	var act := ""
	if event.is_action("move_up") or event.is_action("ui_up"):
		act = "up"
	elif event.is_action("move_down") or event.is_action("ui_down"):
		act = "down"
	elif event.is_action("interact") or event.is_action("ui_accept"):
		act = "ok"
	elif event.is_action("pause") or event.is_action("ui_cancel"):
		act = "cancel"
	else:
		return
	# 先吃掉输入：选定存档位后主界面会马上换场景，这个菜单随之离开场景树（get_viewport() 变成 null）
	get_viewport().set_input_as_handled()
	match act:
		"up":
			selected = (selected - 2 + SaveSystem.SLOTS) % SaveSystem.SLOTS + 1
			confirm = false
			_refresh()
		"down":
			selected = selected % SaveSystem.SLOTS + 1
			confirm = false
			_refresh()
		"ok":
			pick(selected)
		"cancel":
			cancel()
