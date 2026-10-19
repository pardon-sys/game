class_name TaskPotion
extends Node2D
## 弥补任务「药剂师的试药员·配药」（第 3 天早上，药剂师工房）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）：
##   每一碗：先看配方本（被水渍盖住的配方 + 前几碗记下的反应）→ 从八味药草里挑三味（选项页，一味一味挑）→ 喝下 → 奶奶拿羽毛试：
##   配方里没有、却放进去的药草各走一段「试药流程」（potion.json 的 herbs：intro 开场 → 小操作 PotionTrial（timing / mash / guess / rhythm / choice）
##   → ok / bad 的几句、闷笑结算），反应记进配方本；三味都对 = 成品测试（final，一点都不痒的好笑演出）→ 做完。
##   台词行里写 "tickle": 部位 时奶奶顺手挠一下（Dialogue.line_shown）。
##   错 MAX_WRONG 次 = 失败（AfterStory 播 after_fail_potion，换下一张配方重来）。
## 状态存在 vars：task_potion_recipe（第几张配方）、task_potion_notes（配方本上记的反应）、task_potion_wrong（错了几次）。
## 测试：auto_picks = [[药草 id ×3], …] 依次喝。

signal finished(ok: bool)

## 没做完就被删掉了（换图 / 读档 / 测试跳关）：AfterStory 收拾残局，走回触发点能重新开始
var aborted := false
var _emitted := false

const PATH := "res://data/after/potion.json"
const MAX_WRONG := 3
const PHARM := "after_pharm"

static var auto_picks: Array = []
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func recipe() -> Dictionary:
	var rs: Array = data().get("recipes", [])
	return rs[int(GameState.vars.get("task_potion_recipe", 0)) % rs.size()] if not rs.is_empty() else {}


## 失败后：换下一张配方、清空配方本
static func reset_items() -> void:
	GameState.vars["task_potion_recipe"] = int(GameState.vars.get("task_potion_recipe", 0)) + 1
	GameState.vars["task_potion_notes"] = []
	GameState.vars["task_potion_wrong"] = 0


static func status_text() -> String:
	return "错了 %d / %d 次" % [int(GameState.vars.get("task_potion_wrong", 0)), MAX_WRONG]


var _trial: PotionTrial


func _ready() -> void:
	_trial = PotionTrial.new()
	add_child(_trial)
	Dialogue.line_shown.connect(_on_line)
	if not GameState.vars.has("task_potion_notes"):
		GameState.vars["task_potion_notes"] = []
		GameState.vars["task_potion_wrong"] = 0
	_loop.call_deferred()


func _loop() -> void:
	await TrainingDB.wait_dialogue_free()
	while true:
		await _book()
		var picks := await _choose()
		var ok := await _test(picks)
		if ok:
			_emit(true)
			return
		GameState.vars["task_potion_wrong"] = int(GameState.vars.get("task_potion_wrong", 0)) + 1
		if int(GameState.vars["task_potion_wrong"]) >= MAX_WRONG:
			_emit(false)
			return


## 配方本：被水渍盖住的配方 + 记下的反应
func _book() -> void:
	var lines: Array = [{"speaker": "", "text": "（配方本）" + str(recipe().get("blurred", ""))}]
	var notes: Array = GameState.vars.get("task_potion_notes", [])
	for n in notes:
		lines.append({"speaker": "", "text": "（记录）" + str(n)})
	lines.append({"speaker": "", "text": "（还能错 %d 次）" % (MAX_WRONG - int(GameState.vars.get("task_potion_wrong", 0)))})
	await _say(lines)


func _choose() -> Array:
	if not auto_picks.is_empty():
		return auto_picks.pop_front()
	var order: Array = data().get("order", []).duplicate()
	var herbs: Dictionary = data().get("herbs", {})
	var picks: Array = []
	for i in 3:
		var texts: Array = order.map(func(h): return str(herbs[h]["name"]))
		var pick: int = await Dialogue.runner.choice_menu.ask(texts, "第 %d 味药草：" % (i + 1))
		picks.append(order[clampi(pick, 0, order.size() - 1)])
		order.remove_at(clampi(pick, 0, order.size() - 1))
	return picks


## 喝下去、奶奶用羽毛试；返回配对了没有
func _test(picks: Array) -> bool:
	var herbs: Dictionary = data().get("herbs", {})
	var answer: Array = recipe().get("answer", [])
	var names: Array = picks.map(func(h): return str(herbs[h]["name"]))
	var lines: Array = [{"speaker": "", "text": "（把%s放进药锅，咕嘟咕嘟熬成一碗——一口气喝了下去）" % "、".join(names)}]
	await _say(lines)
	var wrong := picks.filter(func(h): return not answer.has(h))
	if wrong.is_empty():
		_tickle("sole", 2)
		await _say(data().get("success", []))
		await _say(data().get("final", []))
		return true
	var notes: Array = GameState.vars.get("task_potion_notes", [])
	var seen: Array = []
	for h in wrong:
		var hd: Dictionary = herbs[h]
		var ok := await _run_trial(hd)
		trials_run += 1
		_add_laugh(0.05 if ok else 0.15)
		seen.append(str(hd.get("note", "")))
	notes.append("第 %d 碗：%s → %s" % [notes.size() + 1, "、".join(names), "；".join(seen)])
	GameState.vars["task_potion_notes"] = notes
	await _say(data().get("miss", []))
	return false


## 测试用：走过几段试药流程
var trials_run := 0


## 一味配错的药草的试药流程：开场 → 小操作 → ok / bad
func _run_trial(hd: Dictionary) -> bool:
	await _say(hd.get("intro", []))
	var ok := true
	match str(hd.get("kind", "")):
		"timing":
			var spots: Array = hd.get("spots", [])
			for i in int(hd.get("times", 1)):
				var z := str(spots[i]) if i < spots.size() else str(hd.get("zone", "sole"))
				_tickle(z, 3)
				if not await _trial.timing(str(hd.get("prompt", "")), float(hd.get("width", 0.3)), float(hd.get("speed", 1.0))):
					ok = false
					break
		"mash":
			ok = await _trial.mash(str(hd.get("prompt", "")), int(hd.get("count", 12)), float(hd.get("time", 4.0)))
		"rhythm":
			var beats := int(hd.get("beats", 4))
			ok = await _trial.rhythm(str(hd.get("prompt", "")), beats) >= beats - 1
		"guess":
			ok = await _guess(hd)
		"choice":
			var opts: Array = hd.get("options", [])
			var pick := int(hd.get("good", 0)) if PotionTrial.auto == "ok" else (0 if PotionTrial.auto == "bad" else -1)
			if pick < 0:
				pick = await Dialogue.runner.choice_menu.ask(opts, str(hd.get("prompt", "")))
			ok = pick == int(hd.get("good", 0))
	await _say(hd.get("ok" if ok else "bad", []))
	return ok


## 痒感转移：奶奶按顺序挠，猜下一下痒在哪里
func _guess(hd: Dictionary) -> bool:
	var order: Array = hd.get("order", [])
	var zones: Dictionary = hd.get("zones", {})
	if order.is_empty():
		return true
	var at := randi() % order.size()
	for r in int(hd.get("rounds", 3)):
		var nxt := (at + 1) % order.size()
		var pick := nxt if PotionTrial.auto == "ok" else ((nxt + 1) % order.size() if PotionTrial.auto == "bad" else -1)
		if pick < 0:
			pick = await Dialogue.runner.choice_menu.ask(order, str(hd.get("prompt", "%s")) % str(order[at]))
		_tickle(str(zones.get(str(order[nxt]), "sole")), 4)
		if pick != nxt:
			return false
		at = nxt
	return true


func _on_line(line: Dictionary) -> void:
	if line.has("tickle"):
		_tickle(str(line["tickle"]), 5)


func _add_laugh(ratio: float) -> void:
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * ratio, p.laugh.max_value * 0.9))


func _tickle(zone: String, n: int) -> void:
	Cutscene._do({"do": "tickle", "who": "princess", "by": PHARM, "zone": zone, "fx": "feather", "repeat": n, "interval": 0.25}, false)


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_potion")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _exit_tree() -> void:
	if Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.disconnect(_on_line)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)
