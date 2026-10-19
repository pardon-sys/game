class_name DanceShow
extends TrainingStage
## 委托「篝火舞会排练」的小游戏（借训练小游戏的画面 + 下方的 RhythmLane 音符条）。台词 data/after/errand_dance.json。
##   教学（四拍，失误不算）→ 三段（sections：双人舞 / 举手转圈 / 踩影子），每段一张谱面（bpm、音符数），开始和结束各演几句。
##   Miss：舞伴（或小孩们）挠一下（部位按段：腰 / 腋下 / 脚心），旁白 + 反应字（闷笑三档），闷笑上涨。
##   羽毛围巾：每隔 SCARF_EVERY 秒左右扫一下脖子，音符抖一会儿。
##   闷笑满：脚下一绊（演一段），这一段重跳。三段跳完总分 < PASS 比例：整首重跳。
## await play() → true。测试：quiet、press(键)、lane。

const TEXT_PATH := "res://data/after/errand_dance.json"
const PASS := 0.6
const SCARF_EVERY := 6.0
const MISS_LAUGH := 0.11

static var quiet := false
static var _text := {}

var lane: RhythmLane
var section := -1
var tutorial := true
var total := 0
var total_max := 0
var retries := 0
var stumbles := 0
var misses := 0
var _done := false
var _info: Label
var _scarf_t := SCARF_EVERY
var _seed := 0
var _last_partner := "host"


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func panel_title() -> String:
	return "篝火舞会排练"


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"},
		"host": {"kind": "npc:bonfire_host", "at": [22, 4], "dir": "left"},
		"merchant": {"kind": "npc:merchant", "at": [-22, 4], "dir": "right"},
		"kid1": {"kind": "npc:kid", "at": [-40, 22], "dir": "right"},
		"kid2": {"kind": "npc:kid", "at": [40, 22], "dir": "left"},
		"kid3": {"kind": "npc:kid", "at": [0, 32], "dir": "up"}}


func play() -> bool:
	player = GameState.player
	rng.randomize()
	_seed = rng.randi()
	layer = 14
	t = {"name": "篝火舞会"}
	_build_ui()
	hint_label.text = "音符滑进圆圈时按 ↑↓←→ / WASD"
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	lane = RhythmLane.new()
	lane.position = Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y - 22)
	lane.size = Vector2(FRAME_RECT.size.x, 20)
	root.add_child(lane)
	lane.judged.connect(_on_judged)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	busy = true
	await _lines(text().get("intro", []))
	await _lines(text().get("tutorial", []))
	lane.load_chart(RhythmLane.make_chart(80, 4, 7, 1.0))
	tutorial = true
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
	Dialogue.start_lines(lines, "dance_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func cur() -> Dictionary:
	var ss: Array = text().get("sections", [])
	return ss[section] if section >= 0 and section < ss.size() else {}


func _start_section(i: int) -> void:
	section = i
	tutorial = false
	var s := cur()
	await _lines(s.get("start", []))
	lane.load_chart(RhythmLane.make_chart(float(s.get("bpm", 100)), int(s.get("notes", 16)), _seed + i * 31 + retries * 7))
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	if tutorial:
		_info.text = "教学：先试四拍\n（按错了不算）"
		return
	var c := lane.counts
	_info.text = "%s\n完美 %d　不错 %d　失误 %d\n本段 %d / %d\n总分 %d" % [cur().get("name", ""), int(c["perfect"]), int(c["good"]), int(c["miss"]),
		lane.score(), lane.max_score(), total + lane.score()]


func _on_key(k: String) -> void:
	lane.press(k)


func _on_judged(res: String, _n: Dictionary) -> void:
	var pr: CGActor = actors.get("princess")
	if res == "miss":
		pop(pr, "失误", BAD, 0.6)
		if not tutorial:
			misses += 1
			_miss_tickle()
	else:
		var pool: Array = text().get("praise", {}).get(res, ["好！"])
		pop(pr, "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.6)
		if rng.randf() < 0.25:
			say("host", str(pool.pick_random()))
		if pr:
			pr.set_dir(["left", "right", "down", "up"][rng.randi() % 4])
	_refresh()


func _partner() -> String:
	match str(cur().get("partner", "host")):
		"merchant":
			return "merchant"
		"kids":
			return ["kid1", "kid2", "kid3"][rng.randi() % 3]
	return "host"


func _miss_tickle() -> void:
	var z := str(cur().get("zone", "waist"))
	_last_partner = _partner()
	tickle(_last_partner, z, rng.randf() < 0.12)
	add_laugh(laugh_max() * MISS_LAUGH)
	var caps: Array = cur().get("miss", [])
	var tier := _tier()
	var pool: Array = cur().get("react", {}).get(tier, ["……"])
	if not caps.is_empty():
		narrate(str(caps.pick_random()))
	say("princess", str(pool.pick_random()))


func _tier() -> String:
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	return "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")


func _tick(delta: float) -> void:
	lane.advance(delta)
	if not tutorial and section >= 0:
		_scarf_t -= delta
		if _scarf_t <= 0.0:
			_scarf_t = rng.randf_range(SCARF_EVERY * 0.7, SCARF_EVERY * 1.3)
			_scarf()
	if lane.finished() and lane.time >= lane.end_time():
		_section_end()


func _scarf() -> void:
	lane.jitter(0.9)
	tickle("host", "neck")
	add_laugh(laugh_max() * 0.04)
	var caps: Array = text().get("scarf", [])
	var rs: Array = text().get("scarf_react", [])
	if not caps.is_empty():
		narrate(str(caps.pick_random()), 1.8)
	if not rs.is_empty():
		say("princess", str(rs.pick_random()))


func _section_end() -> void:
	busy = true
	if tutorial:
		await _lines(text().get("tutorial_done", []))
		await _start_section(0)
		busy = false
		return
	total += lane.score()
	total_max += lane.max_score()
	await _lines(cur().get("end", []))
	var n := (text().get("sections", []) as Array).size()
	if section + 1 < n:
		await _start_section(section + 1)
		busy = false
		return
	if float(total) < float(total_max) * PASS:
		retries += 1
		await _lines(text().get("retry", []))
		total = 0
		total_max = 0
		await _start_section(0)
		busy = false
		return
	await _lines(text().get("done", []))
	_done = true
	busy = false


## 闷笑满：脚下一绊，这一段重跳
func _punish(kind: String) -> void:
	if kind != "laugh":
		return
	busy = true
	stumbles += 1
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.shake(0.6)
	await _lines(text().get("stumble", []))
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.35)
	if not tutorial:
		await _start_section(section)
	busy = false


func _update_count() -> void:
	pass
