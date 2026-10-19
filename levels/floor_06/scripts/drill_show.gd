class_name DrillShow
extends TrainingStage
## 蓝色公主特训的小游戏底子（借训练小游戏的画面；操控的是蓝色公主——TaskDrill 开演前已经 switch_control 过去）。台词 data/after/drill.json。
## 子类：IceSitShow（第一课 冰封静坐）、PantsTameShow（第二课 驯裤）。子类实现 lesson_id()、_begin()（这节课从头开始）、_tick / _on_key。
## 共同规则：
##   魔力疲倦满 → 自动释放（演一小段 release）→「释放后敏感」SENSITIVE_TIME 秒（sensitive_t：挠痒 ×2、反应字换 sensitive 那套、队长加码）；
##   一节课释放超过 MAX_RELEASE 次 = 这节课重来（redo：先播「补课」小剧场 after_fail_drill，再演 redo 的几句，_begin()）。
##   闷笑满 = 破功（子类 _on_break）。
##   反应字飘在人物旁边（say），挠法描写飘在挠的人旁边（pop），不用画面下方的反应框。
## await play() → true。测试：quiet（不演对话、不播小剧场）、press(键)。

const TEXT_PATH := "res://data/after/drill.json"
const SENSITIVE_TIME := 15.0
const MAX_RELEASE := 3

static var quiet := false
static var _text := {}

var releases := 0
var redos := 0
var sensitive_t := 0.0
var _done := false
var _info: Label
var _chat_t := 4.0


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func lesson_id() -> String:
	return ""


func lesson() -> Dictionary:
	return text().get("lessons", {}).get(lesson_id(), {})


func panel_title() -> String:
	return str(lesson().get("name", "特训"))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"cap": {"kind": "npc:captain", "at": [-34, 4], "dir": "right"}}


## 两位公主用公主的精灵图（行列格式不同于普通居民）：蓝色公主在正中间（id princess，挠痒特效对着她），粉色公主在右边
func _build_cast(cast: Dictionary) -> void:
	super(cast)
	for spec in [["princess", "blue", Vector2(0, 8), "down", "helpless_1"], ["pink", "pink", Vector2(34, 6), "left", "normal"]]:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose(str(spec[4]), "helpless" if str(spec[4]) != "normal" else "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a


func hint_text() -> String:
	return ""


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = hint_text()
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 46)
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_build_extra()
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
		if player.fatigue:
			player.fatigue.clear()
	_enter_game()
	busy = true
	await _lines(lesson().get("intro", []))
	await _lines(lesson().get("tutorial", []))
	_begin()
	busy = false
	while not _done:
		await get_tree().process_frame
	busy = true
	await _lines(lesson().get("end", []))
	await _exit_game()
	finished.emit()
	return true


## 子类在面板里加自己的图
func _build_extra() -> void:
	pass


func _begin() -> void:
	releases = 0
	sensitive_t = 0.0


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var was := busy
	busy = true
	Dialogue.start_lines(lines, "drill_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


## 每帧共同的部分（子类的 _tick 先调它）
func _common_tick(delta: float) -> void:
	sensitive_t = maxf(0.0, sensitive_t - delta)
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = rng.randf_range(4.0, 7.0)
		if sensitive_t > 0.0:
			var cs: Array = text().get("cap_sensitive", [])
			if not cs.is_empty():
				say("cap", str(cs.pick_random()))
		elif rng.randf() < 0.5:
			var c: Array = text().get("cap", [])
			if not c.is_empty():
				say("cap", str(c.pick_random()))
		else:
			var pk: Array = text().get("pink", [])
			if not pk.is_empty():
				say("pink", str(pk.pick_random()))


## 挠蓝色公主一下：by 谁挠、zone 部位、caption 描写（飘在挠的人旁边）；返回这一下涨了多少闷笑（比例）
func hit(by: String, zone: String, caption := "", ratio := 0.08) -> float:
	var k := 2.0 if sensitive_t > 0.0 else 1.0
	tickle(by, zone, sensitive_t > 0.0 and rng.randf() < 0.3)
	add_laugh(laugh_max() * ratio * k)
	add_fatigue(fatigue_max() * 0.07 * k)
	if caption != "":
		narrate(caption)
	say("princess", react_line())
	return ratio * k


func react_line() -> String:
	var r: Dictionary = text().get("react", {})
	if sensitive_t > 0.0:
		var sp: Array = r.get("sensitive", [])
		if not sp.is_empty():
			return str(sp.pick_random())
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	var pool: Array = r.get("light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy"), ["……"])
	return str(pool.pick_random())


func _punish(kind: String) -> void:
	busy = true
	if kind == "fatigue":
		releases += 1
		flash(Color(0.75, 0.92, 1.0, 0.9), 0.6)
		Audio.play("ice_crack", -2.0)
		var pr: CGActor = actors.get("princess")
		if pr:
			pr.shake(0.5)
		var rel: Array = text().get("release", [])
		if not rel.is_empty():
			await _lines(rel[mini(releases - 1, rel.size() - 1)])
		if player.fatigue:
			player.fatigue.clear()
		sensitive_t = SENSITIVE_TIME
		if releases > MAX_RELEASE:
			await redo()
	else:
		await _on_break()
	busy = false


## 闷笑满：破功（子类决定怎么算）
func _on_break() -> void:
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.4)


## 这节课重来：补课小剧场 → redo 的几句 → 从头开始
func redo() -> void:
	redos += 1
	if not quiet and CG.has_theater("after_fail_drill"):
		await CG.play_theater("after_fail_drill")
		GameState.in_dialogue = true
	await _lines(lesson().get("redo", []))
	if is_instance_valid(player):
		if player.laugh:
			player.laugh.set_value(0.0)
		if player.fatigue:
			player.fatigue.clear()
	_begin()


func _update_count() -> void:
	pass
