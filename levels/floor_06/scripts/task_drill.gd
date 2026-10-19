class_name TaskDrill
extends Node2D
## 蓝色公主的特训（队长的训练室 floor_06_after_drill）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/drill.json。
##   开始时换成操控蓝色公主（GameState.switch_control），结束换回粉色公主。课里破功 / 释放太多会自己重来（补课小剧场），任务本身不会失败。
##   第 4 天：第一课 IceSitShow → 课间（between）→ 第二课 PantsTameShow。
##   第 6 天：第三课 PantsHandShow「借手」→ 考核 DrillExamShow（及格 / 笑出声两种结局，都不算失败）→ 学会技能（skill）。
## 测试：DrillShow.quiet + 直接调各课的接口。

signal finished(ok: bool)


var aborted := false
var started := false
var lesson := ""
var show: DrillShow
var exam_passed := false
var _emitted := false
var _pink: PlayableCharacter
var _blue: PlayableCharacter


static func reset_items() -> void:
	pass


static func status_text() -> String:
	return str(GameState.vars.get("task_drill_text", ""))


func _ready() -> void:
	_run.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(show):
		show.queue_free()
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
	await _show("hand", PantsHandShow)
	exam_passed = bool(await _show("exam", DrillExamShow))
	var ex: Dictionary = DrillShow.text().get("lessons", {}).get("exam", {})
	await _say(ex.get("pass" if exam_passed else "fail", []))
	# 学会技能（及格不及格都学会：笑出来也是一种本事）
	GameState.grant_passive("ice_composure", true)
	GameState.set_flag(PantsBurst.FLAG)
	GameState.set_flag("drill_exam_passed", exam_passed)
	await _say(DrillShow.text().get("skill", []))


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
