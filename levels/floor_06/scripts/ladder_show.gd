class_name LadderShow
extends TrainingStage
## 委托「扶梯子」的小游戏（借训练小游戏的画面）：粉色公主光脚站在梯子上补屋檐，工匠在下面扶着，小孩来凑热闹。
##   平衡条 balance（-1 ~ 1）：自己会晃（闷笑越高晃得越厉害），← / A、→ / D 往回拨；被挠一下就猛地偏一下（tickler 的 push）。到头 = 摔进干草堆（演一段）→ 这一阶段从头来。
##   干活：三个阶段（data/after/errand_ladder.json 的 phases）——爬上去按 ↑ / W、修屋檐按提示键（J / K / Q / E，限时 WORK_TIME 秒）、下梯子按 ↓ / S；
##   平衡偏得太厉害（> UNSTABLE）时按了不算、梯子还会晃一下。
##   挠她的人按阶段轮换（ticklers），第一次出现时暂停演几句；之后边挠边说，公主的反应字按部位 × 闷笑三档（react）。
##   闷笑满：腿一软，梯子大晃一下（闷笑回到 60%）。
## await play() → true（做完）。测试：quiet（不演对话）、press(键名)、time_scale。

const TEXT_PATH := "res://data/after/errand_ladder.json"
const WORK_KEYS := ["J", "K", "Q", "E"]
const WORK_TIME := 3.0
const UNSTABLE := 0.75
const NUDGE := 0.14

static var quiet := false
static var _text := {}

var balance := 0.0
var phase := 0
var step := 0
var falls := 0
var prompt := ""
var prompt_left := 0.0
var _drift := 0.0
var _drift_t := 0.0
var _tk_t := 2.0
var _seen := {}
var _done := false
var _info: Label
var _gauge: Control


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


class BalanceBar extends Control:
	var stage: LadderShow
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 8), Color(0.18, 0.12, 0.22))
		draw_rect(Rect2(w * 0.5 - w * 0.5 * LadderShow.UNSTABLE, 0, w * LadderShow.UNSTABLE, 8), Color(0.3, 0.55, 0.35))
		draw_line(Vector2(w * 0.5, -2), Vector2(w * 0.5, 10), Color(1, 1, 1, 0.6), 1.0)
		var x := w * 0.5 + stage.balance * w * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, -4), Vector2(x + 4, -4), Vector2(x, 4)]),
			Color(1, 0.4, 0.45) if absf(stage.balance) > LadderShow.UNSTABLE else Color(1, 0.86, 0.4))


class Ladder extends Node2D:
	func _draw() -> void:
		var c := Color(0.55, 0.36, 0.2)
		draw_line(Vector2(-9, -40), Vector2(-9, 28), c, 2.0)
		draw_line(Vector2(9, -40), Vector2(9, 28), c, 2.0)
		for y in range(-36, 28, 8):
			draw_line(Vector2(-9, y), Vector2(9, y), Color(0.65, 0.45, 0.25), 1.5)


func panel_title() -> String:
	return "扶梯子（光脚）"


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, -6], "visual": "normal", "anim": "idle", "dir": "up"},
		"worker": {"kind": "npc:miner", "at": [0, 26], "dir": "up"},
		"kid1": {"kind": "npc:kid", "at": [-26, 24], "dir": "right"},
		"kid2": {"kind": "npc:kid", "at": [26, 24], "dir": "left"},
		"kid3": {"kind": "npc:kid", "at": [-44, 18], "dir": "right"}}


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": "扶梯子"}
	_build_ui()
	hint_label.text = "← → / A D 稳住平衡　按提示的键干活"
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 40)
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_gauge = BalanceBar.new()
	_gauge.stage = self
	_gauge.position = Vector2(2, 52)
	_gauge.size = Vector2(panel_body.size.x - 4, 8)
	panel_body.add_child(_gauge)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	var lad := Ladder.new()
	lad.z_index = 1
	view.add_child(lad)
	for k in ["kid1", "kid2", "kid3"]:
		if actors.has(k):
			actors[k].visible = false
	busy = true
	await _lines(text().get("intro", []))
	await _start_phase()
	busy = false
	while not _done:
		await get_tree().process_frame
	await _exit_game()
	finished.emit()
	return true


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var was := busy
	busy = true
	Dialogue.start_lines(lines, "ladder_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func cur() -> Dictionary:
	var ps: Array = text().get("phases", [])
	return ps[phase] if phase < ps.size() else {}


func _start_phase() -> void:
	step = 0
	balance = 0.0
	if str(cur().get("id", "")) in ["fix", "down"]:
		for k in ["kid1", "kid2", "kid3"]:
			if actors.has(k):
				actors[k].visible = true
	await _lines(cur().get("start", []))
	_next_prompt()


func _next_prompt() -> void:
	match str(cur().get("key", "")):
		"UP":
			prompt = "UP"
		"DOWN":
			prompt = "DOWN"
		_:
			prompt = WORK_KEYS[rng.randi() % WORK_KEYS.size()]
	prompt_left = WORK_TIME
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var names := {"UP": "↑ / W 往上爬", "DOWN": "↓ / S 往下踩", "J": "J 钉钉子", "K": "K 递瓦片", "Q": "Q 抹泥灰", "E": "E 扶正瓦片"}
	_info.text = "%s　%d / %d\n→ %s%s\n摔下来 %d 次" % [cur().get("name", ""), step, int(cur().get("steps", 1)), names.get(prompt, prompt),
		("（%.1f 秒）" % prompt_left) if prompt in WORK_KEYS else "", falls]
	if _gauge:
		_gauge.queue_redraw()


func _on_key(k: String) -> void:
	if k in ["A", "LEFT"]:
		balance -= NUDGE
	elif k in ["D", "RIGHT"]:
		balance += NUDGE
	elif (k == prompt) or (prompt == "UP" and k == "W") or (prompt == "DOWN" and k == "S"):
		_work()
	elif k in WORK_KEYS or k in ["UP", "DOWN", "W", "S"]:
		balance += NUDGE * (1.0 if rng.randf() < 0.5 else -1.0)
		pop(actors.get("princess"), "按错了——梯子一晃！", BAD, 0.8)
	_refresh()


func _work() -> void:
	if absf(balance) > UNSTABLE:
		balance += 0.2 * signf(balance)
		pop(actors.get("princess"), "站不稳……先稳住！", BAD, 0.8)
		return
	step += 1
	Audio.play("hit" if prompt in WORK_KEYS else "step", -8.0, 0.1)
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.position.y += -4.0 if prompt == "UP" else (4.0 if prompt == "DOWN" else 0.0)
	if step >= int(cur().get("steps", 1)):
		busy = true
		await _lines(cur().get("end", []))
		phase += 1
		if phase >= (text().get("phases", []) as Array).size():
			await _lines(text().get("done", []))
			_done = true
			busy = false
			return
		await _start_phase()
		busy = false
		return
	_next_prompt()


func _tick(delta: float) -> void:
	# 自己晃：闷笑越高晃得越厉害
	_drift_t -= delta
	if _drift_t <= 0.0:
		_drift_t = rng.randf_range(0.6, 1.4)
		_drift = rng.randf_range(-1.0, 1.0)
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	balance += _drift * delta * (0.18 + lr * 0.5)
	if prompt in WORK_KEYS:
		prompt_left -= delta
		if prompt_left <= 0.0:
			balance += 0.15 * (1.0 if rng.randf() < 0.5 else -1.0)
			pop(actors.get("princess"), "手、手慢了……", BAD, 0.8)
			_next_prompt()
	_tk_t -= delta
	if _tk_t <= 0.0:
		var ev: Array = cur().get("every", [3.0, 4.0])
		_tk_t = rng.randf_range(float(ev[0]), float(ev[1]))
		_tickle_once()
	if absf(balance) >= 1.0:
		_fall()
		return
	_refresh()


## 挑一个挠她的人（按阶段）
func _pick_tickler() -> String:
	match str(cur().get("id", "")):
		"climb":
			return ["worker_finger", "worker_brush"][rng.randi() % 2]
		"down":
			return ["kid_grass", "kid_feather", "kid_feather", "worker_finger"][rng.randi() % 4]
	return ["worker_finger", "kid_grass", "kid_feather", "worker_brush"][rng.randi() % 4]


func _tickle_once() -> void:
	var id := _pick_tickler()
	var tk: Dictionary = text().get("ticklers", {}).get(id, {})
	if tk.is_empty():
		return
	if not _seen.has(id):
		_seen[id] = true
		await _lines(tk.get("first", []))
	var by: String = "worker" if str(tk.get("who", "")) == "工匠" else ["kid1", "kid2", "kid3"][rng.randi() % 3]
	tickle(by, str(tk.get("zone", "sole")), rng.randf() < 0.15)
	balance += float(tk.get("push", 0.4)) * (1.0 if rng.randf() < 0.5 else -1.0)
	add_laugh(laugh_max() * 0.1)
	var said: Array = tk.get("lines", [])
	if not said.is_empty():
		say(by, str(said.pick_random()))
	GameState.princess_reacted.emit(react_line(), 1.8)
	var wb: Array = text().get("wobble", [])
	if not wb.is_empty() and absf(balance) > 0.5:
		pop(actors.get("princess"), str(wb.pick_random()), BAD, 0.9)


## 反应字：按闷笑分三档
func react_line() -> String:
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	var tier := "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")
	var pool: Array = text().get("react", {}).get(tier, ["……"])
	return str(pool.pick_random())


## 闷笑满：腿一软，梯子大晃
func _punish(kind: String) -> void:
	if kind != "laugh":
		return
	balance += 0.6 * (1.0 if balance >= 0.0 else -1.0)
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.6)
	pop(actors.get("princess"), "腿、腿软了……！", BAD, 1.2)


func _fall() -> void:
	busy = true
	falls += 1
	Audio.play("drop", -2.0)
	flash(Color(1, 0.9, 0.7, 0.8), 0.4)
	await _lines(text().get("fall", []))
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.3)
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.position = Vector2(0, -6)
	await _start_phase()
	busy = false


func _update_count() -> void:
	pass
