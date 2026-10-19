class_name PenaltyDanceShow
extends TrainingStage
## 补罚「罚跳舞」（篝火派对的主人）：篝火边跳（RhythmLane 音游），跳错一拍，围观的人上来挠一下（crowd 轮换挠法 / 部位，描写进下方框）。
##   一首 notes 个音符；失误超过 extra_after 个 → 加跳一段（再来一首）。跳完 = 抵掉一笔受罚（这个补罚不会失败）。
##   闷笑满：脚一软停一下（闷笑回到 40%）。await play() → true。测试：quiet、lane。

static var quiet := false

var lane: RhythmLane
var misses := 0
var extra := false
var _crowd_i := 0
var _done := false
var _info: Label


func panel_title() -> String:
	return "补罚：罚跳舞"


func quit() -> void:
	pass


func data() -> Dictionary:
	return AfterPenance.data().get("dance", {})


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"},
		"host": {"kind": "npc:bonfire_host", "at": [24, 4], "dir": "left"},
		"c1": {"kind": "npc:merchant", "at": [-26, 4], "dir": "right"},
		"c2": {"kind": "npc:kid", "at": [-34, 20], "dir": "right"},
		"c3": {"kind": "npc:guard", "at": [34, 20], "dir": "left"}}


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = "音符滑进圆圈时按 ↑↓←→ / WASD"
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
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
	await _lines(data().get("intro", []))
	lane.load_chart(RhythmLane.make_chart(float(data().get("bpm", 108)), int(data().get("notes", 24)), rng.randi()))
	busy = false
	while not _done:
		await get_tree().process_frame
	busy = true
	await _lines(data().get("done", []))
	await _exit_game()
	finished.emit()
	return true


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "penalty_dance")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true


func _on_key(k: String) -> void:
	lane.press(k)


func _on_judged(res: String, _n: Dictionary) -> void:
	if res == "miss":
		misses += 1
		var cr: Array = data().get("crowd", [])
		if not cr.is_empty():
			var c: Dictionary = cr[_crowd_i % cr.size()]
			_crowd_i += 1
			var by: String = ["c1", "c2", "c3", "host"][_crowd_i % 4]
			tickle(by, str(c.get("zone", "waist")))
			narrate(str(c.get("desc", "")), 1.8)
		add_laugh(laugh_max() * 0.1)
		var r: Dictionary = data().get("react", {})
		var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
		var pool: Array = r.get("light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy"), ["……"])
		say("princess", str(pool.pick_random()))
	else:
		pop(actors.get("princess"), "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.5)
	_refresh()


func _refresh() -> void:
	if _info:
		_info.text = "罚跳舞%s\n失误 %d" % ["（加跳一段）" if extra else "", misses]


func _tick(delta: float) -> void:
	lane.advance(delta)
	if lane.finished() and lane.time >= lane.end_time():
		if not extra and misses > int(data().get("extra_after", 8)):
			extra = true
			busy = true
			await _lines(data().get("extra", []))
			lane.load_chart(RhythmLane.make_chart(float(data().get("bpm", 108)) + 8.0, 12, rng.randi()))
			busy = false
			return
		_done = true


func _punish(kind: String) -> void:
	if kind == "laugh" and player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.4)
		pop(actors.get("princess"), "腿、腿软了……", BAD, 1.0)
	elif player.fatigue:
		player.fatigue.clear()


func _update_count() -> void:
	pass
