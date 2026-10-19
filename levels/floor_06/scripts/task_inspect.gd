class_name TaskInspect
extends Node2D
## 弥补任务「陷阱验收」（第 6 天早上，保卫队训练营 floor_06_after_proving）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/inspect.json。
##   训练营里摆着五个挠痒陷阱的踏板（STATIONS）和三个辅助设施（AUX），顺序自选：
##     辅助：走上去 → 演几句、加状态（statuses：{id: 剩余秒}；冷敷石板清掉别的状态），闷笑按 laugh 降。
##     挠痒：走上去 → InspectShow 体验一遍（挠痒 × 身上状态的倍率）→ 评分（选项页：太强 / 刚好 / 太弱，提示里写涨了多少闷笑和身上的状态）：
##       评对 → 原样；评「太弱」（其实不弱）→ 加强 tune ×1.3；评「太强」（其实不强）→ 削弱 ×0.8，但队长让你再体验一次（重新评）。
##   五个都评完 → 综合演练（五个连着来，闷笑不清零、keep_laugh；倍率用评分调整后的 tune），笑倒 = 失败（after_fail_inspect，重来时从综合演练开始）。
## 状态：vars.task_inspect_rates {陷阱: 评分}、task_inspect_tune {陷阱: 倍率}。
## 测试：auto_rate = {陷阱: 评分}（不弹选项页）、InspectShow.auto_escape、run_station(id)、use_aux(id)。

signal finished(ok: bool)

const PATH := "res://data/after/inspect.json"
const STATIONS := {"curtain": Vector2i(8, 6), "holes": Vector2i(14, 6), "toes": Vector2i(20, 6), "hoist": Vector2i(26, 6), "kneel": Vector2i(32, 6)}
const AUX := {"soak": Vector2i(10, 13), "oil": Vector2i(20, 13), "cool": Vector2i(30, 13)}
const ORDER := ["curtain", "holes", "toes", "hoist", "kneel"]
const NEAR := 12.0

static var auto_rate := {}
static var _data := {}

var aborted := false
var started := false
var statuses := {}
var rated := {}
var tune := {}
var extra_runs := 0
var drill_done := false
var _cool := {}
var _busy := false
var _emitted := false
var _pads: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func reset_items() -> void:
	pass   # 评好的分留着：重来时直接综合演练


static func status_text() -> String:
	var r: Dictionary = GameState.vars.get("task_inspect_rates", {})
	return "评好了 %d / 5 个%s" % [r.size(), "　去终点线综合演练" if r.size() >= 5 else ""]


func _ready() -> void:
	rated = (GameState.vars.get("task_inspect_rates", {}) as Dictionary).duplicate()
	tune = (GameState.vars.get("task_inspect_tune", {}) as Dictionary).duplicate()
	for id in STATIONS:
		_pad(Cutscene.cell_to_world(STATIONS[id]), Color(1, 0.7, 0.85), str(data().get("stations", {}).get(id, {}).get("name", id)))
	for id in AUX:
		_pad(Cutscene.cell_to_world(AUX[id]), Color(0.6, 0.85, 1.0), str(data().get("aux", {}).get(id, {}).get("name", id)))
	_start.call_deferred()


func _exit_tree() -> void:
	for p in _pads:
		if is_instance_valid(p):
			p.queue_free()


func _pad(at: Vector2, col: Color, label: String) -> void:
	var p := Pad.new()
	p.col = col
	p.label = label
	get_parent().add_child(p)
	p.global_position = at
	_pads.append(p)


func _start() -> void:
	await TrainingDB.wait_dialogue_free()
	started = true
	if rated.size() >= ORDER.size():
		await _drill()


func status_mul() -> float:
	var m := 1.0
	for id in statuses:
		m *= float(data().get("status", {}).get(id, {}).get("mul", 1.0))
	return m


func status_names() -> String:
	if statuses.is_empty():
		return "没有"
	return "、".join(statuses.keys().map(func(id): return str(data().get("status", {}).get(id, {}).get("name", id))))


func _process(delta: float) -> void:
	for id in statuses.keys():
		statuses[id] = float(statuses[id]) - delta
		if float(statuses[id]) <= 0.0:
			statuses.erase(id)
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
		if float(_cool[k]) <= 0.0:
			_cool.erase(k)
	if _emitted or _busy or not started or drill_done or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	GameState.vars["task_inspect_state"] = status_names()
	for id in AUX:
		if not _cool.has(id) and p.global_position.distance_to(Cutscene.cell_to_world(AUX[id])) < NEAR:
			use_aux(id)
			return
	for id in STATIONS:
		if not rated.has(id) and not _cool.has(id) and p.global_position.distance_to(Cutscene.cell_to_world(STATIONS[id])) < NEAR:
			run_station(id)
			return


## 辅助设施
func use_aux(id: String) -> void:
	var info: Dictionary = data().get("aux", {}).get(id, {})
	_cool[id] = 6.0
	_busy = true
	await _say(info.get("enter", []))
	if bool(info.get("clears", false)):
		statuses.clear()
	var st := str(info.get("status", ""))
	if st != "":
		statuses[st] = float(data().get("status", {}).get(st, {}).get("time", 30.0))
	var p := GameState.player
	if is_instance_valid(p) and p.laugh and float(info.get("laugh", 0.0)) < 0.0:
		p.laugh.set_value(maxf(0.0, p.laugh.value + p.laugh.max_value * float(info.get("laugh", 0.0))))
	GameState.notify("状态：%s" % status_names(), 2.0)
	_busy = false


## 体验一个陷阱并评分（评「太强」但其实不强：再体验一次）
func run_station(id: String) -> void:
	var info: Dictionary = data().get("stations", {}).get(id, {})
	_busy = true
	if not _cool.has("intro_" + id):
		_cool["intro_" + id] = 99999.0
		await _say(info.get("intro", []))
	while true:
		var res := await _experience(id, info, false)
		var pick := await _rate(id, info, float(res["gain"]))
		var truth := str(info.get("strength", "ok"))
		var rt: Dictionary = data().get("rate", {})
		if pick == truth:
			var right: Array = rt.get("right", [])
			if not right.is_empty():
				await _say(right.pick_random())
			tune[id] = 1.0
			break
		if pick == "weak":
			await _say(rt.get("too_weak", []))
			tune[id] = 1.3
			break
		if pick == "strong":
			await _say(rt.get("too_strong", []))
			tune[id] = 0.8
			extra_runs += 1
			continue   # 再体验一次
		# 评「刚好」但其实不是：按真实情况调整
		tune[id] = 1.3 if truth == "weak" else 0.8
		break
	rated[id] = true
	GameState.vars["task_inspect_rates"] = rated
	GameState.vars["task_inspect_tune"] = tune
	_cool[id] = 3.0
	_busy = false
	if rated.size() >= ORDER.size():
		await _drill()


func _experience(id: String, info: Dictionary, keep: bool) -> Dictionary:
	var show := InspectShow.new()
	get_tree().root.add_child(show)
	var res: Dictionary = await show.play_station(id, info, status_mul() if not keep else 1.0, float(tune.get(id, 1.0)) if keep else 1.0, keep)
	show.queue_free()
	return res


func _rate(id: String, info: Dictionary, gain: float) -> String:
	var rt: Dictionary = data().get("rate", {})
	var ids: Array = rt.get("ids", ["strong", "ok", "weak"])
	if auto_rate.has(id):
		var a: Variant = auto_rate[id]
		if a is Array:
			return str((a as Array).pop_front()) if (a as Array).size() > 1 else str(a[0])
		return str(a)
	var prompt := str(rt.get("prompt", "%s %d%% %s")) % [str(info.get("name", id)), int(round(gain * 100.0)), status_names()]
	var pick: int = await Dialogue.runner.choice_menu.ask(rt.get("options", ["太强了", "刚刚好", "太弱了"]), prompt)
	return str(ids[clampi(pick, 0, ids.size() - 1)])


## 综合演练：五个连着来，闷笑不清零
func _drill() -> void:
	_busy = true
	statuses.clear()
	await _say(data().get("drill_intro", []))
	var btw: Array = data().get("drill_between", [])
	for i in ORDER.size():
		var id := str(ORDER[i])
		if i > 0 and i - 1 < btw.size():
			GameState.notify(str(btw[i - 1]), 1.2)
		var res := await _experience(id, data().get("stations", {}).get(id, {}), true)
		if bool(res.get("laughed_out", false)):
			_emit(false)
			return
	drill_done = true
	await _say(data().get("drill_done", []))
	_emit(true)


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_inspect")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	GameState.vars.erase("task_inspect_state")
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 地上的踏板（程序画：一块发光的圆垫子 + 名字）
class Pad extends Node2D:
	var col := Color.WHITE
	var label := ""
	var _t := 0.0

	func _ready() -> void:
		z_index = 0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a := 0.55 + 0.25 * sin(_t * 3.0)
		draw_circle(Vector2.ZERO, 9.0, Color(col.r, col.g, col.b, 0.25))
		draw_arc(Vector2.ZERO, 9.0, 0, TAU, 20, Color(col.r, col.g, col.b, a), 1.5)
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(f, Vector2(-w * 0.5, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.85))
