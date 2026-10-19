class_name TaskDrill
extends Node2D
## 蓝色公主的特训（队长的训练室 floor_06_after_drill）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/drill.json。
##   开始时换成操控蓝色公主（GameState.switch_control），结束换回粉色公主。课里破功 / 释放太多会自己重来（补课小剧场），任务本身不会失败。
##   第 4 天：第一课 IceSitShow → 课间（between）→ 第二课 PantsTameShow。
##   第 6 天：第三课「借手」（训练室右边的障碍场，地图里实际走）→ 考核 DrillExamShow（及格 / 笑出声两种结局，都不算失败）→ 学会技能（skill）。
##   第三课：手点（HAND_POINTS）——走到 HAND_RANGE 以内按 E：anchor 抓住对岸把她拽过沟（ANCHOR_TO）、lever 拉开栅栏（GATE）；
##     附近没有手点按 E = 小手护身（ice_shield，挡下一次挠痒）。每次听话度 −USE_COST（每秒回 REGEN）；听话度 < USE_COST 时用 = 造反（挠自己）。
##     粉色公主每 RAID_EVERY 秒来捣乱一次（演几句 + 挠）。走到 GOAL = 过关；闷笑满 = 补课小剧场 → 回到起点重走。
## 测试：DrillShow.quiet；第三课的 use_hand()、raid()、obedience。

signal finished(ok: bool)

const HAND_RANGE := 96.0
const USE_COST := 34.0
const REGEN := 5.0
const RAID_EVERY := 14.0
const START := Vector2i(20, 7)
const GOAL := Vector2i(37, 7)
const ANCHOR := Vector2i(27, 4)
const ANCHOR_TO := Vector2i(27, 7)
const LEVER := Vector2i(34, 3)
const GATE_X := 31
const DITCH_X := 25

var aborted := false
var started := false
var lesson := ""
var show: DrillShow
var obedience := 100.0
var gate_open := false
var crossed := false
var uses := 0
var rebels := 0
var raids := 0
var exam_passed := false
var _gate: Node2D
var _raid_t := RAID_EVERY
var _busy := false
var _emitted := false
var _pink: PlayableCharacter
var _blue: PlayableCharacter
var _course_done := false


static func reset_items() -> void:
	pass


static func status_text() -> String:
	return str(GameState.vars.get("task_drill_text", ""))


func _ready() -> void:
	_run.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(show):
		show.queue_free()
	if is_instance_valid(_gate):
		_gate.queue_free()
	GameState.vars.erase("task_drill_text")
	_swap_back()


func _find_blue() -> PlayableCharacter:
	for n in get_parent().get_parent().find_children("*", "PlayableCharacter", true, false):
		if n != _pink:
			return n
	return null


func _say(lines: Array) -> void:
	if DrillShow.quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_drill")
	while Dialogue.is_active():
		await get_tree().process_frame


func _run() -> void:
	await TrainingDB.wait_dialogue_free()
	_pink = GameState.player
	_blue = _find_blue()
	if _blue:
		GameState.switch_control(_blue)
	started = true
	if DayClock.day() >= 6:
		await _day6()
	else:
		await _day4()
	if not is_instance_valid(self):
		return
	_swap_back()
	_emit(true)


func _show(id: String, scr: GDScript) -> Variant:
	lesson = id
	GameState.vars["task_drill_text"] = str(DrillShow.text().get("lessons", {}).get(id, {}).get("name", id))
	show = scr.new()
	get_tree().root.add_child(show)
	var res: Variant = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	show = null
	return res


func _day4() -> void:
	await _show("ice", IceSitShow)
	await _say(DrillShow.text().get("between", []))
	await _show("tame", PantsTameShow)


func _day6() -> void:
	await _course()
	exam_passed = bool(await _show("exam", DrillExamShow))
	var ex: Dictionary = DrillShow.text().get("lessons", {}).get("exam", {})
	await _say(ex.get("pass" if exam_passed else "fail", []))
	# 学会技能（及格不及格都学会：笑出来也是一种本事）
	GameState.grant_passive("ice_composure", true)
	GameState.set_flag(PantsBurst.FLAG)
	GameState.set_flag("drill_exam_passed", exam_passed)
	await _say(DrillShow.text().get("skill", []))


# ------------------------------------------------------------------ 第三课：借手（地图里走）
func _lesson() -> Dictionary:
	return DrillShow.text().get("lessons", {}).get("hand", {})


func _course() -> void:
	lesson = "hand"
	GameState.vars["task_drill_text"] = str(_lesson().get("name", "第三课"))
	await _say(_lesson().get("intro", []))
	await _say(_lesson().get("tutorial", []))
	_reset_course()
	while not _course_done:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
	await _say(_lesson().get("end", []))
	if is_instance_valid(_gate):
		_gate.queue_free()


func _reset_course() -> void:
	obedience = 100.0
	gate_open = false
	crossed = false
	_raid_t = RAID_EVERY
	if is_instance_valid(_gate):
		_gate.queue_free()
	_gate = Gate.new()
	get_parent().add_child(_gate)
	_gate.global_position = Cutscene.cell_to_world(Vector2i(GATE_X, 7))
	if is_instance_valid(_blue):
		_blue.global_position = Cutscene.cell_to_world(START)
		if _blue.laugh:
			_blue.laugh.set_value(0.0)


func _process(delta: float) -> void:
	if lesson != "hand" or _course_done or _busy or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(_blue):
		return
	obedience = minf(100.0, obedience + REGEN * delta)
	GameState.vars["task_drill_text"] = "%s　听话度 %d" % [_lesson().get("name", ""), int(obedience)]
	if Input.is_action_just_pressed("interact"):
		use_hand()
	_raid_t -= delta
	if _raid_t <= 0.0:
		_raid_t = RAID_EVERY
		raid()
	if _blue.global_position.distance_to(Cutscene.cell_to_world(GOAL)) < 18.0:
		_course_done = true
		return
	if _blue.laugh and _blue.laugh.value >= _blue.laugh.max_value * 0.95:
		_fail_course()


## E：用小手（附近的手点；没有就护身）。返回用了什么（"" = 造反 / 没用成）
func use_hand() -> String:
	var use: Dictionary = _lesson().get("use", {})
	if obedience < USE_COST:
		rebels += 1
		_busy = true
		await _say(_lesson().get("rebel", []))
		_tickle_blue(0.15)
		_busy = false
		return ""
	obedience -= USE_COST
	uses += 1
	var pos := _blue.global_position
	var kind := "guard"
	if not crossed and pos.x < Cutscene.cell_to_world(Vector2i(DITCH_X, 0)).x and pos.distance_to(Cutscene.cell_to_world(ANCHOR)) < HAND_RANGE + 16.0:
		kind = "anchor"
	elif not gate_open and pos.distance_to(Cutscene.cell_to_world(LEVER)) < HAND_RANGE:
		kind = "lever"
	var lines: Array = use.get(kind, [])
	if lines.size() >= 1:
		SpeechBubble.say(_blue, str(lines[0]), 30.0, 1.0)
	_hand_line(pos, Cutscene.cell_to_world(ANCHOR if kind == "anchor" else (LEVER if kind == "lever" else Vector2i.ZERO)), kind)
	match kind:
		"anchor":
			crossed = true
			var tw := _blue.create_tween()
			tw.tween_property(_blue, "global_position", Cutscene.cell_to_world(ANCHOR_TO), 0.45).set_trans(Tween.TRANS_QUAD)
		"lever":
			gate_open = true
			if is_instance_valid(_gate):
				_gate.queue_free()
			Audio.play("lever", -4.0)
		"guard":
			_blue.add_buff("ice_shield", 4.0)
	return kind


func _hand_line(from: Vector2, to: Vector2, kind: String) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(1.0, 0.72, 0.88)
	l.z_index = 30
	if kind == "guard":
		l.points = PackedVector2Array([from + Vector2(-10, -10), from + Vector2(0, -16), from + Vector2(10, -10)])
	else:
		l.points = PackedVector2Array([from + Vector2(0, -8), (from + to) * 0.5 + Vector2(0, -14), to])
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## 粉色公主来捣乱
func raid() -> void:
	var rs: Array = _lesson().get("pink_raid", [])
	if rs.is_empty() or not is_instance_valid(_blue):
		return
	var lines: Array = rs[raids % rs.size()]
	raids += 1
	if is_instance_valid(_pink):
		_pink.global_position = _blue.global_position + Vector2(-14, 4)
	_busy = true
	await _say(lines)
	_busy = false
	if _blue.buffs.has("ice_shield"):
		_blue.break_ice_shield()
		SpeechBubble.say(_blue, "……挡住了。", 30.0, 1.0)
	elif raids % rs.size() != 0:
		_tickle_blue(0.12)


func _tickle_blue(ratio: float) -> void:
	if not is_instance_valid(_blue) or _blue.laugh == null:
		return
	_blue.laugh.set_value(minf(_blue.laugh.value + _blue.laugh.max_value * ratio, _blue.laugh.max_value))
	var z: String = ["thigh", "butt", "waist"].pick_random()
	ZoneFx.play(z, _blue.get_parent(), ZoneFx.body_point(_blue, z), 1.0, false)
	Audio.play("tickle", -6.0, 0.1)


func _fail_course() -> void:
	_busy = true
	if not DrillShow.quiet and CG.has_theater("after_fail_drill"):
		await CG.play_theater("after_fail_drill")
	await _say(_lesson().get("redo", []))
	_reset_course()
	_busy = false


func _swap_back() -> void:
	if is_instance_valid(_pink) and GameState.player != _pink:
		GameState.switch_control(_pink)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 障碍场的栅栏（挡路；小手拉开远处的拉杆就收起来）：一竖排木栅栏
class Gate extends StaticBody2D:
	func _ready() -> void:
		collision_layer = 1
		var sh := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(10, 16 * 8)
		sh.shape = r
		add_child(sh)

	func _draw() -> void:
		for i in 8:
			var y := -64.0 + i * 16.0
			draw_rect(Rect2(-4, y, 8, 15), Color(0.55, 0.36, 0.22))
			draw_line(Vector2(-4, y + 4), Vector2(4, y + 4), Color(0.4, 0.26, 0.16), 1.0)
