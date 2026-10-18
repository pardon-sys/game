class_name DayClock
extends RefCounted
## 七日赎罪的时钟：第几天（GameState.vars.after_day，1 ~ DAYS）+ 时段（vars.after_slot：0 早上 / 1 下午 / 2 夜晚）。
## 夜晚打开剧情标记 night（地图换夜晚的环境光、小屋的门锁上）；时间一变，GameState.flag_changed 发 TICK（镇民按日程换位置）。
## 日程 data/after/schedule.json（tools/build/gen_floor06_after.py 生成）：
##   npcs  镇民日程：键（对话文件名，如 after_captain）-> {default, morning / afternoon / night, d<N>: {all, morning / afternoon / night}}，
##         每一层是 {at [格], dir, dialogue, hidden, wander}，按 default → 时段 → d<N>.all → d<N>.时段 的顺序覆盖；
##         这个时段的事件做完以后再叠 <时段>_done、d<N>.<时段>_done（宣判完大家散开）
##   days  每天每个时段的事件：d<N> -> {morning / afternoon / night: {event 事件 id, task 赎罪簿上的任务名, hours 做完减几工时}}
## 事件做完记剧情标记 after_done_d<N>_<时段>（done / mark_done）。事件本身由 AfterStory 按 id 演。

const PATH := "res://data/after/schedule.json"
const SLOTS := ["morning", "afternoon", "night"]
const SLOT_NAMES := ["早上", "下午", "夜晚"]
const MORNING := 0
const AFTERNOON := 1
const NIGHT := 2
const DAYS := 7
## 时间变了：GameState.flag_changed 发这个名字
const TICK := "after_clock"
const LAYER := 44

static var _data := {}
static var passing := false


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func day() -> int:
	return int(GameState.vars.get("after_day", 1))


static func slot() -> int:
	return int(GameState.vars.get("after_slot", MORNING))


static func slot_key(s := -1) -> String:
	return SLOTS[clampi(slot() if s < 0 else s, 0, 2)]


static func label(d := -1, s := -1) -> String:
	return "第 %d 天·%s" % [day() if d < 0 else d, SLOT_NAMES[clampi(slot() if s < 0 else s, 0, 2)]]


static func set_time(d: int, s: int) -> void:
	GameState.vars["after_day"] = d
	GameState.vars["after_slot"] = s
	GameState.set_flag("night", s == NIGHT)
	GameState.flag_changed.emit(TICK)


## 下一个时段（夜晚之后要睡觉：用 sleep）
static func advance() -> void:
	if slot() < NIGHT:
		set_time(day(), slot() + 1)


static func done_flag(d := -1, s := -1) -> String:
	return "after_done_d%d_%s" % [day() if d < 0 else d, slot_key(s)]


static func done(d := -1, s := -1) -> bool:
	return GameState.has_flag(done_flag(d, s))


static func mark_done(d := -1, s := -1) -> void:
	GameState.set_flag(done_flag(d, s))


## 某天某时段的事件：{event, task, hours}（没有就是空字典）
static func slot_info(d := -1, s := -1) -> Dictionary:
	var dd: Dictionary = data().get("days", {}).get("d%d" % (day() if d < 0 else d), {})
	return dd.get(slot_key(s), {})


static func event(d := -1, s := -1) -> String:
	return str(slot_info(d, s).get("event", ""))


## 按日程叠出一个镇民现在的安排：{at, dir, dialogue, hidden, wander}
static func npc(key: String, d := -1, s := -1) -> Dictionary:
	var table: Dictionary = data().get("npcs", {}).get(key, {})
	var out := {}
	var k := slot_key(s)
	var today: Dictionary = table.get("d%d" % (day() if d < 0 else d), {})
	var layers: Array = [table.get("default", {}), table.get(k, {}), today.get("all", {}), today.get(k, {})]
	# <时段>_done：这个时段的事件做完以后（宣判之后大家散开……）
	if done(d, s):
		layers.append(table.get(k + "_done", {}))
		layers.append(today.get(k + "_done", {}))
	for layer in layers:
		out.merge(layer, true)
	return out


## 过一段时间（黑幕 + 「第 N 天·下午」字样）：黑着的时候换时间（镇民这时候换位置），再亮起来。
static func pass_time(to_slot: int, to_day := -1) -> void:
	if passing:
		return
	passing = true
	var tree := Engine.get_main_loop() as SceneTree
	var was := GameState.in_dialogue
	GameState.in_dialogue = true
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	tree.root.add_child(layer)
	var black := ColorRect.new()
	black.color = Color(0.03, 0.02, 0.05, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var text := Label.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color", Color(0.98, 0.92, 0.84))
	text.modulate.a = 0.0
	layer.add_child(text)
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.8)
	await tw.finished
	var d := day() if to_day < 0 else to_day
	set_time(d, to_slot)
	# 上一段过场留着的黑幕（end_dark）在这里揭掉（上面还盖着这层黑）
	Cutscene.curtain_clear(0.01)
	text.text = label(d, to_slot)
	tw = text.create_tween()
	tw.tween_property(text, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.0)
	tw.tween_property(text, "modulate:a", 0.0, 0.4)
	await tw.finished
	tw = black.create_tween()
	tw.tween_property(black, "color:a", 0.0, 0.8)
	await tw.finished
	layer.queue_free()
	GameState.in_dialogue = was
	passing = false


## 夜里睡觉 → 第二天早上（Sleep 的黑幕里换时间；最后一天之后不再往后）。
static func sleep() -> void:
	var d := mini(day() + 1, DAYS)
	await Sleep.sleep("", "赎罪的第 %d 天" % d, func():
		set_time(d, MORNING)
		Cutscene.curtain_clear(0.01))
