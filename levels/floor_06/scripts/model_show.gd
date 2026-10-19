class_name ModelShow
extends TrainingStage
## 补罚「活体模特」（市场监督）：站在摊位上给「防痒袜子」当模特（借训练小游戏的画面）。台词 data/after/penalty.json 的 model。
##   顾客一个接一个（customers，每 CUSTOMER_TIME 秒换一个）来「试试效果」：登场的话 → 挠（描写进下方框，部位按顾客），
##   每次挠：姿势晃 push（平衡条，A / D 往回拨，自己也会晃）、表情 −face（J 绷住：表情 +FACE_FIX，冷却 FACE_CD）。
##   平衡到头 = 动了、表情到 0 = 笑了：市场监督加时 EXTRA 秒（平衡 / 表情回到中间）；加时超过 MAX_EXTRA 次 = 没撑住（失败）。
##   撑过时间（time）= 抵掉一笔受罚。await play() → 成功没有。测试：quiet、press(键)、hit_once()。

const CUSTOMER_TIME := 5.0
const HIT_EVERY := 1.4
const NUDGE := 0.16
const FACE_FIX := 22.0
const FACE_CD := 0.6
const EXTRA := 8.0
const MAX_EXTRA := 6

static var quiet := false

var time_left := 45.0
var balance := 0.0
var face := 100.0
var extras := 0
var hits := 0
var cust := -1
var _cust_t := 0.0
var _hit_t := 1.0
var _fix_cd := 0.0
var _drift := 0.0
var _drift_t := 0.0
var _done := false
var _failed := false
var _info: Label


func panel_title() -> String:
	return "补罚：活体模特"


func quit() -> void:
	pass


func data() -> Dictionary:
	return AfterPenance.data().get("model", {})


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 4], "visual": "normal", "anim": "idle", "dir": "down"},
		"stand": {"kind": "trap:cushion", "at": [0, 8]},
		"sup": {"kind": "npc:supervisor", "at": [-34, 6], "dir": "right"},
		"c": {"kind": "npc:merchant", "at": [20, 16], "dir": "left"}}


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = "A / D 保持姿势　J 绷住表情"
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	time_left = float(data().get("time", 45.0))
	_enter_game()
	busy = true
	await _lines(data().get("intro", []))
	busy = false
	while not _done:
		await get_tree().process_frame
	busy = true
	await _lines(data().get("fail" if _failed else "done", []))
	await _exit_game()
	finished.emit()
	return not _failed


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "model_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true


func _refresh() -> void:
	if _info:
		_info.text = "剩余 %d 秒　加时 %d / %d\n姿势 %s\n表情 %d%%" % [ceili(maxf(time_left, 0.0)), extras, MAX_EXTRA,
			"稳" if absf(balance) < 0.5 else "晃！", int(face)]


func _next_customer() -> void:
	var cs: Array = data().get("customers", [])
	if cs.is_empty():
		return
	cust = (cust + 1) % cs.size()
	_cust_t = CUSTOMER_TIME
	var c: Dictionary = cs[cust]
	say("c", str(c.get("intro", "")))


func hit_once() -> void:
	var cs: Array = data().get("customers", [])
	if cust < 0 or cs.is_empty():
		return
	var c: Dictionary = cs[cust]
	hits += 1
	tickle("c", str(c.get("zone", "sole")), rng.randf() < 0.12)
	narrate(str(c.get("desc", "")), 1.8)
	balance += float(c.get("push", 0.4)) * (1.0 if rng.randf() < 0.5 else -1.0)
	face -= float(c.get("face", 20))
	add_laugh(laugh_max() * 0.05, 0.95)
	var r: Dictionary = data().get("react", {})
	var pool: Array = r.get("light" if face > 60.0 else ("mid" if face > 25.0 else "heavy"), ["……"])
	say("princess", str(pool.pick_random()))
	_check()


func _check() -> void:
	if absf(balance) >= 1.0:
		_penalize("move")
	elif face <= 0.0:
		_penalize("laugh")


func _penalize(kind: String) -> void:
	extras += 1
	time_left += EXTRA
	balance = 0.0
	face = 70.0
	if kind == "move":
		var w: Array = data().get("wobble", [])
		if not w.is_empty():
			narrate(str(w.pick_random()), 1.4)
	busy = true
	await _lines(data().get(kind, []))
	busy = false
	if extras > MAX_EXTRA:
		_failed = true
		_done = true


func _on_key(k: String) -> void:
	if k in ["A", "LEFT"]:
		balance -= NUDGE
	elif k in ["D", "RIGHT"]:
		balance += NUDGE
	elif k == "J" and _fix_cd <= 0.0:
		_fix_cd = FACE_CD
		face = minf(100.0, face + FACE_FIX)
		pop(actors.get("princess"), "（绷住……）", GOLD, 0.6)
	_refresh()


func _tick(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		_done = true
		return
	_fix_cd = maxf(0.0, _fix_cd - delta)
	_drift_t -= delta
	if _drift_t <= 0.0:
		_drift_t = rng.randf_range(0.8, 1.6)
		_drift = rng.randf_range(-1.0, 1.0)
	balance += _drift * delta * 0.2
	_cust_t -= delta
	if _cust_t <= 0.0:
		_next_customer()
	_hit_t -= delta
	if _hit_t <= 0.0:
		_hit_t = HIT_EVERY
		hit_once()
	_check()
	_refresh()


func _punish(kind: String) -> void:
	if kind == "fatigue" and player.fatigue:
		player.fatigue.clear()


func _update_count() -> void:
	pass
