class_name TaskTailor
extends Node2D
## 弥补任务「裁缝的试衣模特·找漏风」（第 5 天早上，裁缝铺里间）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/tailor.json。
##   量尺寸（暖场，只第一次）→ 腋下 / 腰 / 脚心三个部位依次找漏风 → 验收（走过三个羽毛人台）。
##   每个部位：裁缝拿羽毛把四个点挨个试一遍（反应：漏风 strong 好痒、挨着没缝的漏风点 weak 有一点点、别的 none；
##     闷笑 ≥ NOISY 时挨着漏风的点有一半可能也说「好痒」）→ 选项页标点（部位图 TailorChart 同步显示）→「就缝这些」：
##     标对的缝上；标错的「仔细检查」（挠一阵、闷笑 +CHECK_LAUGH）。还可以「再试一遍」、「喝口茶」（闷笑 -TEA，TEAS 次）。
##   验收：三个人台（腋下 / 腰 / 脚心），走过去碰到还有没缝的漏风点的那个 → 被挠、回去重找那个部位；全缝好 → 走到镜子前 = 做完。
##   闷笑到 FAIL_AT = 失败（AfterStory 播 after_fail_tailor，罚工时；reset_items 把漏风点重新随机）。
## 状态在 vars：task_tailor_leaks {部位: [下标]}、task_tailor_sewn {部位: [下标]}、task_tailor_measured、task_tailor_tea。
## 测试：auto_marks = {部位: [下标] / "leaks"（标所有没缝的漏风点）/ "one"（只标第一个没缝的）}（不弹选项页，直接标这些点并缝）。

signal finished(ok: bool)

const PATH := "res://data/after/tailor.json"
const PARTS := ["armpit", "waist", "sole"]
const TAILOR := "after_tailor"
const MANNEQUINS := {"armpit": Vector2i(6, 9), "waist": Vector2i(9, 9), "sole": Vector2i(12, 9)}
const MIRROR := Vector2i(15, 9)
const NOISY := 0.6
const GAIN := {"strong": 0.07, "weak": 0.03, "none": 0.0}
const CHECK_LAUGH := 0.15
const TEA := 0.3
const TEAS := 3
const FAIL_AT := 0.97

static var auto_marks := {}
static var _data := {}

## 没做完就被删掉了（换图 / 读档 / 测试跳关）
var aborted := false
var stage := ""
var _emitted := false
var _failed := false
var _chart: TailorChart
var _layer: CanvasLayer
var _mannequins := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func part(id: String) -> Dictionary:
	return data().get("parts", {}).get(id, {})


static func leaks() -> Dictionary:
	if not GameState.vars.has("task_tailor_leaks"):
		_roll()
	return GameState.vars["task_tailor_leaks"]


static func sewn() -> Dictionary:
	if not GameState.vars.has("task_tailor_sewn"):
		GameState.vars["task_tailor_sewn"] = {"armpit": [], "waist": [], "sole": []}
	return GameState.vars["task_tailor_sewn"]


## 每个部位随机挑漏风点
static func _roll() -> void:
	var out := {}
	for id in PARTS:
		var idx := [0, 1, 2, 3]
		idx.shuffle()
		out[id] = idx.slice(0, int(part(id).get("leaks", 1)))
	GameState.vars["task_tailor_leaks"] = out


## 还没缝上的漏风点
static func open_leaks(id: String) -> Array:
	var s: Array = sewn().get(id, [])
	return (leaks().get(id, []) as Array).filter(func(i): return not s.has(i))


## 失败后：漏风点重新随机、缝过的拆掉（量尺寸不用再量）
static func reset_items() -> void:
	GameState.vars.erase("task_tailor_leaks")
	GameState.vars.erase("task_tailor_sewn")
	GameState.vars["task_tailor_tea"] = TEAS


static func status_text() -> String:
	var n := 0
	var total := 0
	for id in PARTS:
		total += (leaks().get(id, []) as Array).size()
		n += (leaks().get(id, []) as Array).size() - open_leaks(id).size()
	return "缝好的漏风点 %d / %d　茶还剩 %d 杯" % [n, total, int(GameState.vars.get("task_tailor_tea", TEAS))]


func _ready() -> void:
	if not GameState.vars.has("task_tailor_tea"):
		GameState.vars["task_tailor_tea"] = TEAS
	leaks()
	sewn()
	_layer = CanvasLayer.new()
	_layer.layer = 21
	add_child(_layer)
	_chart = TailorChart.new()
	_chart.position = Vector2(120, 12)
	_chart.visible = false
	_layer.add_child(_chart)
	Dialogue.line_shown.connect(_on_line)
	_loop.call_deferred()


func _exit_tree() -> void:
	if Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.disconnect(_on_line)
	for m in _mannequins.values():
		if is_instance_valid(m):
			m.queue_free()


## 台词里写了 "tickle": 部位 → 裁缝顺手挠一下（闷笑涨一点，量尺寸时不会笑到失败）
func _on_line(line: Dictionary) -> void:
	if not line.has("tickle"):
		return
	var z := str(line["tickle"])
	_tickle(z, 6)
	_add_laugh(0.04 if stage == "measure" else 0.05, 0.9 if stage == "measure" else 1.0)


func _loop() -> void:
	await TrainingDB.wait_dialogue_free()
	if not bool(GameState.vars.get("task_tailor_measured", false)):
		stage = "measure"
		await _say(data().get("measure", []))
		await _say(data().get("tutorial", []))
		GameState.vars["task_tailor_measured"] = true
	var todo: Array = PARTS.duplicate()
	var visited := {}
	while true:
		for id in todo:
			stage = id
			var ok := await _part(id, not visited.has(id))
			visited[id] = true
			if not ok:
				_emit(false)
				return
		stage = "inspect"
		var leaking := await _inspect()
		if _failed:
			_emit(false)
			return
		if leaking == "":
			_emit(true)
			return
		todo = [leaking]


# ------------------------------------------------------------------ 一个部位
## 返回 false = 笑到失败
func _part(id: String, first: bool) -> bool:
	var info := part(id)
	if first:
		await _say(info.get("intro", []))
	var results := {}
	var marks: Array = []
	await _test_round(id, results)
	if _failed:
		return false
	while true:
		var pick := await _menu(id, results, marks)
		var n_points := (info.get("points", []) as Array).size()
		if pick < n_points:
			if pick in marks:
				marks.erase(pick)
			else:
				marks.append(pick)
			continue
		match pick - n_points:
			0:
				results.clear()
				await _test_round(id, results)
				if _failed:
					return false
			1:
				var left := int(GameState.vars.get("task_tailor_tea", 0))
				if left <= 0:
					await _say(data().get("no_tea", []))
				else:
					GameState.vars["task_tailor_tea"] = left - 1
					var p := GameState.player
					if is_instance_valid(p) and p.laugh:
						p.laugh.set_value(maxf(0.0, p.laugh.value - p.laugh.max_value * TEA))
					await _say(data().get("tea", []))
			_:
				if marks.is_empty():
					await _say(data().get("empty_mark", []))
					continue
				await _sew(id, marks)
				if _failed:
					return false
				await _say(info.get("end", []))
				return true
	return true


## 裁缝把四个点挨个试一遍
func _test_round(id: String, results: Dictionary) -> void:
	var info := part(id)
	var names: Array = info.get("points", [])
	var tests: Array = info.get("test", ["（羽毛扫过%s）"])
	for i in names.size():
		var r := reaction(id, i)
		results[i] = r
		var pool: Array = info.get("react", {}).get(r, ["……"])
		_tickle(str(info.get("zone", "sole")), 6 if r == "strong" else 3)
		_add_laugh(float(GAIN[r]))
		var emo := "helpless_2" if r == "strong" else ("shy" if r == "weak" else "normal")
		await _say([{"speaker": "", "text": str(tests[i % tests.size()]) % str(names[i])},
			{"speaker": "公主", "text": "【%s】%s" % [names[i], str(pool.pick_random())], "emotion": emo}])
		if _failed:
			return
		_refresh_chart(id, results, [])


## 这个点的反应（闷笑高的时候挨着漏风的点也可能觉得好痒）
func reaction(id: String, i: int) -> String:
	var open := open_leaks(id)
	if i in open:
		return "strong"
	for pair in part(id).get("adj", []):
		var a := int(pair[0])
		var b := int(pair[1])
		if (a == i and open.has(b)) or (b == i and open.has(a)):
			var p := GameState.player
			if is_instance_valid(p) and p.laugh and p.laugh.ratio() >= NOISY and randf() < 0.5:
				return "strong"
			return "weak"
	return "none"


## 标点的选项页：返回 0~3 点、4 再试一遍、5 喝茶、6 就缝这些
func _menu(id: String, results: Dictionary, marks: Array) -> int:
	var info := part(id)
	var names: Array = info.get("points", [])
	var m: Dictionary = data().get("menu", {})
	var rn: Dictionary = data().get("reaction_names", {})
	_refresh_chart(id, results, marks)
	if auto_marks.has(id):
		var spec: Variant = auto_marks[id]
		var open := open_leaks(id)
		var want: Array = spec if spec is Array else (open if str(spec) == "leaks" else open.slice(0, 1))
		for i in want:
			if i not in marks:
				return int(i)
		return names.size() + 2
	var texts: Array = []
	for i in names.size():
		var r := str(results.get(i, ""))
		texts.append("%d %s：%s%s" % [i + 1, names[i], rn.get(r, m.get("unknown", "还没试过")), ("　" + str(m.get("mark", "【标记】"))) if i in marks else ""])
	texts.append(str(m.get("retest", "再试一遍")))
	texts.append(str(m.get("tea", "喝口茶（%d）")) % int(GameState.vars.get("task_tailor_tea", 0)))
	texts.append(str(m.get("sew", "就缝这些！")))
	_chart.visible = true
	var pick: int = await Dialogue.runner.choice_menu.ask(texts, str(m.get("prompt", "%s")) % str(info.get("name", id)), Rect2(304, 12, 168, 164))
	_chart.visible = false
	return pick


func _sew(id: String, marks: Array) -> void:
	var info := part(id)
	var names: Array = info.get("points", [])
	var s: Array = sewn()[id]
	for i in marks:
		var nm := str(names[int(i)])
		if int(i) in open_leaks(id):
			s.append(int(i))
			await _say(_fmt(info.get("fixed", []), nm))
		else:
			await _say(_fmt(info.get("check", []), nm))
			_add_laugh(CHECK_LAUGH)
		if _failed:
			return
	sewn()[id] = s


func _fmt(lines: Array, nm: String) -> Array:
	return lines.map(func(l):
		var d: Dictionary = (l as Dictionary).duplicate()
		if "%s" in str(d.get("text", "")):
			d["text"] = str(d["text"]) % nm
		return d)


# ------------------------------------------------------------------ 验收
## 返回还漏着的部位（""= 全缝好了，走到了镜子前）
func _inspect() -> String:
	await _say(data().get("inspect_intro", []))
	var lv := get_parent()
	for id in PARTS:
		if not _mannequins.has(id) or not is_instance_valid(_mannequins[id]):
			var m := FeatherMannequin.new()
			m.zone = id
			m.name = "Mannequin_" + id
			lv.add_child(m)
			m.global_position = Cutscene.cell_to_world(MANNEQUINS[id])
			_mannequins[id] = m
	var passed := {}
	while true:
		await get_tree().process_frame
		if not is_inside_tree():
			return ""
		var p := GameState.player
		if not is_instance_valid(p) or GameState.in_dialogue or GameState.in_cutscene:
			continue
		for id in PARTS:
			if passed.has(id):
				continue
			var m: FeatherMannequin = _mannequins[id]
			if m.global_position.distance_to(p.global_position) < 14.0:
				passed[id] = true
				m.spin(1.5)
				if not open_leaks(id).is_empty():
					await _say(data().get("inspect_leak", {}).get(id, []))
					_add_laugh(0.06)
					return id
		if Cutscene.cell_to_world(MIRROR).distance_to(p.global_position) < 14.0:
			if passed.size() < PARTS.size():
				GameState.notify("要从三个人台中间走过去才算验收哦。", 2.0)
				p.global_position = Cutscene.cell_to_world(MIRROR - Vector2i(1, 0))
				continue
			await _say(data().get("inspect_pass", []))
			return ""
	return ""


# ------------------------------------------------------------------ 工具
func _refresh_chart(id: String, results: Dictionary, marks: Array) -> void:
	_chart.set_state(id, part(id).get("points", []), results, marks, sewn().get(id, []))


func _add_laugh(ratio: float, cap := 1.0) -> void:
	var p := GameState.player
	if not is_instance_valid(p) or p.laugh == null:
		return
	p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * ratio, p.laugh.max_value * minf(cap, FAIL_AT)))
	if p.laugh.value >= p.laugh.max_value * FAIL_AT - 0.01 and cap >= 1.0:
		_failed = true


func _tickle(zone: String, n: int) -> void:
	Cutscene._do({"do": "tickle", "who": "princess", "by": TAILOR, "zone": zone, "fx": "feather", "repeat": n, "interval": 0.22}, false)


func _say(lines: Array) -> void:
	if lines.is_empty() or _failed:
		return
	Dialogue.start_lines(lines, "task_tailor")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)
