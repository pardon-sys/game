class_name AfterPenance
extends RefCounted
## 七日赎罪的补罚任务（镇民执行惩罚，抵罚的工时）：赎罪簿上的受罚（PenanceBook.punishments）比已经抵掉的多时，开 penalty_open
## （市场监督 / 篝火派对的主人头上冒「！」，对话里接：set {vars: {penalty_req: model / dance}, call: after_penalty}）。
##   model → ModelShow（活体模特）、dance → PenaltyDanceShow（罚跳舞）。做完：抵掉一条（vars.penance_settled +1）、减 HOURS 工时。
## 台词 data/after/penalty.json（← after_text/penalty.py）。

const PATH := "res://data/after/penalty.json"
const FLAG := "penalty_open"

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


static func run(kind: String) -> void:
	if running or pending() <= 0:
		return
	running = true
	refresh()
	await TrainingDB.wait_dialogue_free()
	var show: Node = ModelShow.new() if kind == "model" else PenaltyDanceShow.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(show)
	var ok: bool = await show.play()
	show.queue_free()
	if ok:
		GameState.vars["penance_settled"] = settled() + 1
		PenanceBook.add(-int(data().get("hours", 3)), "补罚：" + ("活体模特" if kind == "model" else "罚跳舞"))
	else:
		GameState.notify("没撑住……下次再来抵吧。")
	running = false
	refresh()
