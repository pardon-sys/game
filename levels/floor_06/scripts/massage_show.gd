class_name MassageShow
extends TrainingStage
## 委托「足底按摩试新手法」的小游戏（借训练小游戏的画面）：粉色公主坐在篝火边的长椅上，光脚搁在派对主人的膝盖上。台词 data/after/errand_massage.json。
##   「忍住别踢」节奏条：指针来回扫，扫到绿区时按 J 忍住（一下）；按早了 / 按晚了 / 一趟扫完都没按 = 忍不住踢了一脚。
##   六种手法（moves）依次来：每种开始前演几句，要忍住 hits 下；越往后指针越快（speed）、绿区越窄（width）。
##   每扫一趟都挠一下（闷笑上涨，反应字按闷笑三档）；踢中 KICKS_REDO 次 → 「重来！」这一种手法从头来。
##   闷笑满：笑得直蹬腿，算踢一脚，闷笑回到一半。
## await play() → true。做完：清空魔力疲倦，加状态「脚底轻快」。测试：quiet、press("J")、cursor。

const TEXT_PATH := "res://data/after/errand_massage.json"
const KICKS_REDO := 3
const SWEEP := 1.4
const BUFF := "foot_light"

static var quiet := false
static var _text := {}

var move := 0
var held := 0
var kicks := 0
var total_kicks := 0
var redos := 0
## 指针位置 0 ~ 1（来回扫）
var cursor := 0.0
var _dir := 1.0
var _pressed := false
var _done := false
var _info: Label
var _gauge: Control
var _tk_t := 0.0


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


class HoldBar extends Control:
	var stage: MassageShow
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 8), Color(0.18, 0.12, 0.22))
		var z := stage.zone_rect()
		draw_rect(Rect2(w * z.x, 0, w * (z.y - z.x), 8), Color(0.3, 0.6, 0.38))
		var x := w * stage.cursor
		draw_line(Vector2(x, -3), Vector2(x, 11), Color(1, 0.9, 0.5), 2.0)


func panel_title() -> String:
	return "足底按摩（忍住别踢）"


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [-10, 8], "visual": "normal", "anim": "idle", "dir": "right"},
		"host": {"kind": "npc:bonfire_host", "at": [14, 10], "dir": "left"},
		"kid1": {"kind": "npc:kid", "at": [30, 20], "dir": "left"},
		"kid2": {"kind": "npc:kid", "at": [34, 6], "dir": "left"}}


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": "足底按摩"}
	_build_ui()
	hint_label.text = "指针扫到绿区时按 J 忍住"
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 44)
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_gauge = HoldBar.new()
	_gauge.stage = self
	_gauge.position = Vector2(2, 54)
	_gauge.size = Vector2(panel_body.size.x - 4, 8)
	panel_body.add_child(_gauge)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	for k in ["kid1", "kid2"]:
		if actors.has(k):
			actors[k].visible = false
	busy = true
	await _lines(text().get("intro", []))
	await _start_move()
	busy = false
	while not _done:
		await get_tree().process_frame
	await _exit_game()
	_reward()
	finished.emit()
	return true


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var was := busy
	busy = true
	Dialogue.start_lines(lines, "massage_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func cur() -> Dictionary:
	var ms: Array = text().get("moves", [])
	return ms[move] if move < ms.size() else {}


## 绿区 [起, 止]（0 ~ 1，在中间偏右一点，免得一开局就在里面）
func zone_rect() -> Vector2:
	var w := float(cur().get("width", 0.3))
	var c := 0.58
	return Vector2(c - w * 0.5, c + w * 0.5)


func _start_move() -> void:
	held = 0
	kicks = 0
	cursor = 0.0
	_dir = 1.0
	_pressed = false
	if str(cur().get("id", "")) in ["toes", "roller", "brush"]:
		for k in ["kid1", "kid2"]:
			if actors.has(k):
				actors[k].visible = true
	await _lines(cur().get("intro", []))
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	_info.text = "第 %d / %d 式：%s\n忍住 %d / %d　踢了 %d / %d" % [move + 1, (text().get("moves", []) as Array).size(), cur().get("name", ""),
		held, int(cur().get("hits", 5)), kicks, KICKS_REDO]
	if _gauge:
		_gauge.queue_redraw()


func _on_key(k: String) -> void:
	if k not in ["J", "SPACE"] or _pressed:
		return
	_pressed = true
	var z := zone_rect()
	if cursor >= z.x and cursor <= z.y:
		_hold()
	else:
		_kick()


func _hold() -> void:
	held += 1
	pop(actors.get("princess"), "忍住了！", GOOD, 0.7)
	Audio.play("pickup", -10.0, 0.1)
	add_laugh(laugh_max() * 0.03)
	_refresh()
	if held >= int(cur().get("hits", 5)):
		busy = true
		move += 1
		if move >= (text().get("moves", []) as Array).size():
			await _lines(text().get("done", []))
			_done = true
			busy = false
			return
		await _start_move()
		busy = false


func _kick() -> void:
	kicks += 1
	total_kicks += 1
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.shake(0.4)
	var h: CGActor = actors.get("host")
	if h:
		h.shake(0.3)
	pop(h, "踢中了！", BAD, 0.9)
	Audio.play("hit", -4.0, 0.1)
	_refresh()
	if kicks == 1 or kicks >= KICKS_REDO:
		await _lines(cur().get("kick", []))
	if kicks >= KICKS_REDO:
		busy = true
		redos += 1
		await _lines(text().get("redo", []))
		await _start_move()
		busy = false


func _tick(delta: float) -> void:
	var spd := float(cur().get("speed", 1.0)) / SWEEP
	cursor += _dir * spd * delta
	if cursor >= 1.0 or cursor <= 0.0:
		cursor = clampf(cursor, 0.0, 1.0)
		_dir = -_dir
		# 一趟扫完：没按就是没忍住；按过了，下一趟重新算
		if not _pressed:
			_kick()
		_pressed = false
		_massage_tickle()
	_refresh()


## 每扫一趟按摩手法挠一下
func _massage_tickle() -> void:
	var by := "host"
	if actors.has("kid1") and actors["kid1"].visible and rng.randf() < 0.35:
		by = "kid1"
	tickle(by, str(cur().get("zone", "sole")), rng.randf() < 0.1)
	add_laugh(laugh_max() * 0.07 * float(cur().get("speed", 1.0)))
	var said: Array = cur().get("host", [])
	if not said.is_empty() and by == "host":
		say("host", str(said.pick_random()))
	GameState.princess_reacted.emit(react_line(), 1.8)


func react_line() -> String:
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	var tier := "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")
	var pool: Array = cur().get("react", {}).get(tier, ["……"])
	return str(pool.pick_random())


## 闷笑满：笑得直蹬腿（算踢一脚）
func _punish(kind: String) -> void:
	if kind != "laugh":
		return
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.5)
	pop(actors.get("princess"), "笑、笑得直蹬腿……！", BAD, 1.2)
	_kick()


## 做完：疲倦清空，加「脚底轻快」
func _reward() -> void:
	if not is_instance_valid(player):
		return
	if player.fatigue:
		player.fatigue.clear()
	player.add_buff(BUFF)


func _update_count() -> void:
	pass
