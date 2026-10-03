class_name TrainingMenu
extends CanvasLayer
## 保卫队训练菜单（营地训练台）：列出各项训练（说明、进度 / 上限、阶段、费用），部位类训练再选部位。
## await choose() 返回 {id, zone}（取消返回 {}）。上下选、E 确定、Esc 返回 / 关闭。打开时暂停游戏。
## 测试 / 脚本可以直接调 pick(序号) 和 cancel()。

signal done(result: Dictionary)

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.6, 0.55, 0.65)

## "list" 训练列表 / "zone" 选部位
var page := "list"
var selected := 0
var chosen := {}
var panel: Panel
var title: Label
var rows: VBoxContainer
var desc: Label
var hint: Label
var _paused_by_me := false


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.07, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.16, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(50, 14)
	panel.size = Vector2(380, 240)
	add_child(panel)
	title = _label(GOLD)
	title.position = Vector2(12, 6)
	panel.add_child(title)
	rows = VBoxContainer.new()
	rows.position = Vector2(12, 26)
	rows.add_theme_constant_override("separation", 1)
	panel.add_child(rows)
	desc = _label(TEXT)
	desc.position = Vector2(12, 150)
	desc.size = Vector2(356, 66)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(desc)
	hint = _label(DIM)
	hint.position = Vector2(12, 218)
	panel.add_child(hint)


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	return l


func choose() -> Dictionary:
	page = "list"
	selected = 0
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Audio.play("book", -6.0)
	_refresh()
	var r: Dictionary = await done
	if _paused_by_me:
		(Engine.get_main_loop() as SceneTree).paused = false
	return r


func trainings() -> Array:
	return TrainingDB.list()


static func cost() -> int:
	return int(TrainingDB.data().get("cost", 5))


## 这一项（部位类给部位）现在能不能开始：返回 "" 或不能开始的原因。
static func blocked_reason(t: Dictionary, zone := "") -> String:
	var st := TrainingStats.stage(t)
	if st.is_empty() or not st.get("unlocked", false):
		return "还没开放"
	if GameState.inventory.count("coin") < cost():
		return "金币不够（要 %d）" % cost()
	var keys: Array = st.get("caps", {}).keys()
	var full := true
	for k in keys:
		var key := TrainingStats.zone_key(k, zone) if t.get("per_zone", false) else str(k)
		if t.get("per_zone", false) and zone == "":
			return ""
		full = full and TrainingStats.is_full(key)
	return "这一阶段已经练满了" if full else ""


static func progress_text(t: Dictionary, zone := "") -> String:
	var st := TrainingStats.stage(t)
	var parts: Array = []
	for k in st.get("caps", {}):
		var key := TrainingStats.zone_key(k, zone) if t.get("per_zone", false) else str(k)
		if t.get("per_zone", false) and zone == "":
			continue
		var v := TrainingStats.value(key)
		var c := TrainingStats.cap(key)
		parts.append(("%.3f/%.3f" if c < 1.0 else "%d/%d") % [v, c])
	return "　".join(parts)


func pick(i: int) -> void:
	if page == "list":
		var list := trainings()
		if i < 0 or i >= list.size():
			return
		var t: Dictionary = list[i]
		if t.get("per_zone", false):
			var why := blocked_reason(t)
			if why != "":
				_deny(why)
				return
			chosen = t
			page = "zone"
			selected = 0
			_refresh()
			return
		var why2 := blocked_reason(t)
		if why2 != "":
			_deny(why2)
			return
		done.emit({"id": str(t["id"]), "zone": ""})
	else:
		var zones := TickleZones.zone_ids()
		if i < 0 or i >= zones.size():
			return
		var why := blocked_reason(chosen, str(zones[i]))
		if why != "":
			_deny(why)
			return
		done.emit({"id": str(chosen["id"]), "zone": str(zones[i])})


func cancel() -> void:
	if page == "zone":
		page = "list"
		selected = 0
		_refresh()
		return
	done.emit({})


func _deny(why: String) -> void:
	GameState.notify(why)
	Audio.play("locked", -8.0)


func _count() -> int:
	return trainings().size() if page == "list" else TickleZones.zone_ids().size()


func _refresh() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	if page == "list":
		title.text = "保卫队训练营　　金币 ×%d　（每轮 %d 金币）" % [GameState.inventory.count("coin"), cost()]
		var list := trainings()
		for i in list.size():
			var t: Dictionary = list[i]
			var st := TrainingStats.stage(t)
			var stage_name := "第 %d 阶段" % (TrainingStats.stage_index(t) + 1)
			var l := _label(PINK if i == selected else TEXT)
			l.text = "%s%s　%s　%s" % ["▶ " if i == selected else "　 ", t["name"], stage_name,
				("（部位）" if t.get("per_zone", false) else progress_text(t)) if st.get("unlocked", false) else "未解锁"]
			rows.add_child(l)
		if not list.is_empty():
			desc.text = str(list[selected].get("desc", ""))
		hint.text = "上下 选择　E 开始　Esc 离开"
	else:
		title.text = "%s：选择部位" % chosen["name"]
		var zones := TickleZones.zone_ids()
		for i in zones.size():
			var z := str(zones[i])
			var l := _label(PINK if i == selected else TEXT)
			l.text = "%s%s　%s　（倍率 %.2f）" % ["▶ " if i == selected else "　 ", TickleZones.zone_name(z), progress_text(chosen, z),
				TickleZones.zone_multiplier(z)]
			rows.add_child(l)
		desc.text = str(chosen.get("desc", ""))
		hint.text = "上下 选择　E 开始　Esc 返回"


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
	get_viewport().set_input_as_handled()
	match act:
		"up":
			selected = (selected - 1 + _count()) % _count()
			_refresh()
		"down":
			selected = (selected + 1) % _count()
			_refresh()
		"ok":
			pick(selected)
		"cancel":
			cancel()
