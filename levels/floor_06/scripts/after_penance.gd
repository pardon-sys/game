class_name AfterPenance
extends RefCounted
## 七日赎罪的补罚任务（镇民执行惩罚，抵罚的工时）：赎罪簿上的受罚（PenanceBook.punishments）比已经抵掉的多时，开 penalty_open
## （市场监督 / 篝火派对的主人头上冒「！」，对话里接：set {vars: {penalty_req: model / dance / announcer}, call: after_penalty}）。
##   model → ModelShow（活体模特）、dance → PenaltyDanceShow（罚跳舞）、announcer → AnnouncerShow（第4天白天起，原舞会排练后）。做完：抵掉一条（vars.penance_settled +1）、减 hours 工时。
## 最后一天（AfterStory.must_settle：第 7 天、工时还没还清）：不看受罚记录，工时大于 0 就能接（报幕晚上也能接），一次减 hours_d7 工时；
##   有没抵的受罚时顺便抵一条。对话里的入口换成 penalty_d7 那一套（标记 penalty_d7）。
## 台词 data/after/penalty.json（← after_text/penalty.py）。

const PATH := "res://data/after/penalty.json"
const FLAG := "penalty_open"
const SHOWS := {"model": "res://levels/floor_06/scripts/model_show.gd", "dance": "res://levels/floor_06/scripts/penalty_dance_show.gd", "announcer": "res://levels/floor_06/scripts/announcer_show.gd"}

static var _data := {}
static var running := false


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func settled() -> int:
	return int(GameState.vars.get("penance_settled", 0))


## 还没抵掉的受罚有几条
static func pending() -> int:
	return maxi(0, PenanceBook.punishments().size() - settled())


## 最后一天补工时：工时大于 0 就能补罚
static func settle_mode() -> bool:
	return AfterStory.must_settle()


static func settle_hours() -> int:
	return int(data().get("hours_d7", 5))


## 现在有没有能补的（没抵的受罚，或者最后一天还欠工时）
static func can_settle() -> bool:
	if KnightStory.active():
		return false
	return pending() > 0 or settle_mode()


static func refresh() -> void:
	var want := PenanceBook.started() and can_settle() and not running and not GameState.has_flag(AfterStory.TASK_FLAG) and AfterErrands.active() == ""
	if GameState.has_flag(FLAG) != want:
		GameState.set_flag(FLAG, want)
	var d7 := want and settle_mode()
	if GameState.has_flag("penalty_d7") != d7:
		GameState.set_flag("penalty_d7", d7)
	var announcer := want and available("announcer")
	if GameState.has_flag("penalty_announcer_open") != announcer:
		GameState.set_flag("penalty_announcer_open", announcer)


static func available(kind: String) -> bool:
	if not SHOWS.has(kind): return false
	if kind == "announcer":
		return DayClock.day() >= 4 and (DayClock.slot() != DayClock.NIGHT or settle_mode()) and AfterErrands.is_done("dance")
	return true


static func run(kind: String) -> void:
	if running or not can_settle() or not available(kind):
		return
	var main := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("main")
	var source: Node = main.get("level") if main else null
	if not is_instance_valid(source): return
	running = true
	refresh()
	await TrainingDB.wait_dialogue_free()
	if not is_instance_valid(source) or main.get("level") != source or not available(kind) or not can_settle():
		running = false
		refresh()
		return
	var show: Node = load(SHOWS[kind]).new()
	(Engine.get_main_loop() as SceneTree).root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show): show.queue_free()
	if not is_instance_valid(source) or main.get("level") != source:
		running = false
		refresh()
		return
	if ok and can_settle():
		var hrs := settle_hours() if settle_mode() else int(data().get("hours", 3))
		if pending() > 0:
			GameState.vars["penance_settled"] = settled() + 1
		PenanceBook.add(-hrs, "补罚：" + str(data()["names"][kind]))
		if AfterStory.must_settle():
			GameState.hint(AfterStory.settle_text())
		elif DayClock.day() >= AfterStory.SETTLE_DAY:
			GameState.hint("工时还清了！")
	else:
		GameState.notify("没撑住……下次再来抵吧。")
	running = false
	refresh()
