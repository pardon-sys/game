class_name StallGuessShow
extends ErrandWorkStage
## 庆功宴摊位「脚底猜猜乐」（面包店奶奶）：两只光脚伸进帘子后面的木箱，奶奶拿一样东西挠，挠一阵以后四选一猜是什么。台词 data/after/stall_guess.json。
##   每一轮：挠 TICKLE_TIME 秒（道具的手感描写 + 她的反应，闷笑每秒 +RATE）→ 猜（← → 选、J 确定；猜的时候还在挠）。
##   猜对：连对 +1（completed），连对 GOAL 次通关；猜错：连对清零、罚挠 WRONG_TIME 秒（闷笑每秒 +WRONG_RATE），换下一样。
##   闷笑满 / 魔力释放见 ErrandWorkStage（闷笑满：这一轮重挠，连对不清）。不存档：每次从头玩。
## 测试：quiet、fixed_seed、press()、simulate()、tool、options、choice、state。

const PATH := "res://data/after/stall_guess.json"
const GOAL := 3
const OPTIONS := 4
const TICKLE_TIME := 4.0
const WRONG_TIME := 3.0
const RATE := 0.03
const WRONG_RATE := 0.08
const STRONG_LAUGH := 0.05
const FATIGUE_RATE := 0.012
const FX := {"feather": "feather", "brush": "brush", "finger": "hand", "tongue": "suck", "grass": "feather", "comb": "brush"}

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var tool := ""
var options: Array = []
var choice := 0
var state := "tickle"
var state_left := 0.0
var rounds := 0
var _last_tool := ""
var _info: Label
var _rig: BoxRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [GOAL]


func panel_title() -> String:
	return str(data().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [-26, 8], "visual": "normal", "anim": "idle", "dir": "right"},
		"keeper": {"kind": "npc:granny", "at": [30, 0], "dir": "left"}}


func tool_info(id: String) -> Dictionary:
	for t in data().get("tools", []):
		if str(t["id"]) == id:
			return t
	return {}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "keeper"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_enter_game()
	_rig = BoxRig.new()
	_rig.stage = self
	view.add_child(_rig)
	if not await start_work():
		return false
	return await work_result()


## 新一轮：换一样道具（不和上一样相同），配三个干扰项
func _begin_segment() -> void:
	if not _alive():
		return
	rounds += 1
	var ids: Array = data().get("tools", []).map(func(t): return str(t["id"]))
	ids.erase(_last_tool)
	tool = str(ids[rng.randi_range(0, ids.size() - 1)])
	_last_tool = tool
	active_tool = tool
	var others: Array = data().get("tools", []).map(func(t): return str(t["id"])).filter(func(i): return i != tool)
	options = [tool]
	while options.size() < OPTIONS and not others.is_empty():
		options.append(others.pop_at(rng.randi_range(0, others.size() - 1)))
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = options[i]
		options[i] = options[j]
		options[j] = tmp
	choice = 0
	state = "tickle"
	state_left = TICKLE_TIME
	busy = false
	_clue()
	_refresh()


func _reset_segment() -> void:
	state = "tickle"
	state_left = TICKLE_TIME


func _on_key(k: String) -> void:
	if recovery_left > 0.0 or state != "guess":
		return
	match k:
		"LEFT", "A":
			choice = posmod(choice - 1, options.size())
		"RIGHT", "D":
			choice = (choice + 1) % options.size()
		"J", "E":
			guess(choice)
	_refresh()


## 猜：对了连对 +1；错了连对清零、罚挠一阵
func guess(index: int) -> void:
	if state != "guess" or busy:
		return
	var name := str(tool_info(tool).get("name", tool))
	if str(options[clampi(index, 0, options.size() - 1)]) == tool:
		narrate(str(data()["reveal"]) % name, 2.0, true)
		say("keeper", str(data()["right_line"]))
		advance_step()
		return
	completed = 0
	state = "wrong"
	state_left = WRONG_TIME
	var caps: Array = data().get("wrong", [])
	narrate((str(data()["reveal"]) % name) + str(caps[rng.randi_range(0, caps.size() - 1)]), 3.0, true)
	_pop_random(data().get("wrong_react", []), PINK, 1.8)
	_refresh()


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	_update_bars()
	simulate(delta * time_scale)


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := interference.advance(dt)
	elapsed = interference.elapsed
	sensitive_left = maxf(0.0, sensitive_left - float(event["dt"]))
	work_laugh(laugh_max() * (WRONG_RATE if state == "wrong" else RATE) * dt)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	if event["fx"]:
		tickle("keeper", "sole", state == "wrong" and rng.randf() < 0.2, "princess", str(FX.get(tool, "hand")))
	if event["strong"]:
		work_laugh(laugh_max() * STRONG_LAUGH)
	if event["reaction"]:
		_clue()
	state_left -= dt
	if state_left <= 0.0:
		if state == "tickle":
			state = "guess"
			narrate(str(data()["guessing"]), 3.0, true)
		elif state == "wrong":
			_begin_segment()
	if _rig:
		_rig.queue_redraw()


## 这一样道具的手感描写和她的反应（猜错罚挠时描写换成 wrong 那几句）
func _clue() -> void:
	var info := tool_info(tool)
	var clues: Array = info.get("clues", [])
	if not clues.is_empty() and state != "wrong":
		narrate(str(clues[rng.randi_range(0, clues.size() - 1)]), 3.2)
	var ratio := player.laugh.ratio() if player.laugh else 0.0
	var tier := "light" if ratio < 0.4 else ("mid" if ratio < 0.75 else "heavy")
	var replies: Array = info.get("react", {}).get(tier, [])
	if sensitive_left > 0.0:
		replies = data().get("sensitive", {}).get(tier, replies)
	_pop_random(replies, PINK, 1.8)


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [completed, rounds]
	if state == "guess":
		_info.text += "\n" + str(data()["prompt"])
		for i in options.size():
			_info.text += "\n%s%s" % ["▶ " if i == choice else "　", tool_info(str(options[i])).get("name", "")]
	count_label.text = str(data()["count"]) % completed
	if _rig:
		_rig.queue_redraw()


## 帘子、木箱，箱子里伸进去的两只脚（帘子随着挠动一抖一抖）
class BoxRig extends Node2D:
	var stage: StallGuessShow

	func _draw() -> void:
		var wob := sin(stage.elapsed * 12.0) * (1.5 if stage.state != "guess" else 0.6)
		draw_rect(Rect2(-6, -6, 30, 22), Color("7a5638"))
		draw_rect(Rect2(-6, -6, 30, 3), Color("a47a50"))
		for i in 6:
			var x := -4.0 + i * 5.0
			draw_rect(Rect2(x + wob * (0.5 if i % 2 else -0.5), -18, 4, 14), Color("c25d6e") if i % 2 else Color("d9788a"))
		draw_line(Vector2(-8, -19), Vector2(26, -19), Color("e8c98f"), 2)
		# 脚从左边伸进箱子
		for y in [2.0, 8.0]:
			draw_rect(Rect2(-18, y - 2, 13, 4), Color("f6d3c4"))
		draw_string(ThemeDB.fallback_font, Vector2(2, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.6, 0.6 + 0.4 * absf(sin(stage.elapsed * 3.0))))
