class_name AfterPenance
extends RefCounted
## 七日赎罪的补罚任务（镇民执行惩罚，抵罚的工时）：赎罪簿上的受罚（PenanceBook.punishments）比已经抵掉的多时，开 penalty_open
## （市场监督 / 篝火派对的主人头上冒「！」，对话里接：set {vars: {penalty_req: model / dance / announcer}, call: after_penalty}）。
##   model → ModelShow（活体模特）、dance → PenaltyDanceShow（罚跳舞）、announcer → AnnouncerShow（第4天白天起，原舞会排练后）。做完：抵掉一条（vars.penance_settled +1）、减 HOURS 工时。
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


static func refresh() -> void:
	var want := PenanceBook.started() and pending() > 0 and not running and not GameState.has_flag(AfterStory.TASK_FLAG) and AfterErrands.active() == ""
	if GameState.has_flag(FLAG) != want:
		GameState.set_flag(FLAG, want)
	var announcer := want and available("announcer")
	if GameState.has_flag("penalty_announcer_open") != announcer:
		GameState.set_flag("penalty_announcer_open", announcer)


static func available(kind: String) -> bool:
	if not SHOWS.has(kind): return false
	if kind == "announcer":
		return DayClock.day() >= 4 and DayClock.slot() != DayClock.NIGHT and AfterErrands.is_done("dance")
	return true


static func run(kind: String) -> void:
	if running or pending() <= 0 or not available(kind):
		return
	var main := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("main")
	var source: Node = main.get("level") if main else null
	if not is_instance_valid(source): return
	running = true
	refresh()
	await TrainingDB.wait_dialogue_free()
	if not is_instance_valid(source) or main.get("level") != source or not available(kind) or pending() <= 0:
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
	if ok and pending() > 0:
		GameState.vars["penance_settled"] = settled() + 1
		PenanceBook.add(-int(data().get("hours", 3)), "补罚：" + str(data()["names"][kind]))
	else:
		GameState.notify("没撑住……下次再来抵吧。")
	running = false
	refresh()
