class_name AfterPlay
extends RefCounted
## 两位公主的玩闹（七日赎罪的小日常）：和蓝色公主说话选「逗她笑一笑」（对话 call after_play）。
##   粉色公主想让寡言的她多笑笑；蓝色公主想躲，千手痒痒裤的小手却按住了她的胳膊，只能任她摆布。
##   最多 TRIES 次：选部位（腰 / 大腿 / 屁股 / 膝盖窝）。今天的弱点（weak_spot，按天变）以外的部位她还忍得住，
##   台词会透露离弱点远近；挠中弱点 → 节奏连击（KeySequenceQTE，按 1~4）→ 成功就破功大笑。
##   失败可重试，当天获胜后不再重玩；首次获胜blue_bond+1并开放当天邀请同行。
##   存档：after_play_day尝试日期、after_play_win_day获胜日期、after_play_bond_day奖励日期。
##   台词在 data/after/play.json（after_text/play.py）。
## 测试：auto_qte = true / false 跳过连击直接给结果；auto_picks = [部位序号…] 依次选。

const PATH := "res://data/after/play.json"
const SPOTS := ["waist", "thigh", "butt", "knee"]
const TRIES := 3
const BLUE := "AfterBlue"

static var auto_qte: Variant = null
static var auto_picks: Array = []
static var running := false
static var _data := {}
static var quiet := false # 专项只跳过台词，仍走实际选点／连击／结算。


static func won_today() -> bool:
	return int(GameState.vars.get("after_play_win_day", 0)) == DayClock.day()


## 旧记录无法判断当天是否赢过；允许重试，但当天不补发不确定的旧关系奖励。
static func _migrate_reward() -> void:
	if not GameState.vars.has("after_play_bond_day"):
		GameState.vars["after_play_bond_day"] = int(GameState.vars.get("after_play_day", 0))


static func settle(won: bool) -> void:
	_migrate_reward()
	GameState.vars["after_play_day"] = DayClock.day()
	if not won: return
	GameState.vars["after_play_win_day"] = DayClock.day()
	GameState.set_flag("after_blue_can_follow")
	if int(GameState.vars.get("after_play_bond_day", 0)) != DayClock.day():
		GameState.vars["after_play_bond_day"] = DayClock.day()
		GameState.vars["blue_bond"] = int(GameState.vars.get("blue_bond", 0)) + 1


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func weak_spot(day := -1) -> String:
	var d := DayClock.day() if day < 0 else day
	return SPOTS[(d * 7 + 3) % SPOTS.size()]


static func played_today() -> bool:
	return int(GameState.vars.get("after_play_day", 0)) == DayClock.day()


static func run() -> bool:
	if running:
		return false
	await TrainingDB.wait_dialogue_free()
	_migrate_reward()
	if won_today():
		await _say(data().get("again", []))
		return true
	running = true
	var origin: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	GameState.in_dialogue = true
	var d := data()
	var weak := weak_spot()
	var names: Array = SPOTS.map(func(s): return str(d["spots"][s]["name"]))
	_act([{"do": "face", "who": BLUE, "dir": "left"}, {"do": "cover", "who": BLUE, "zone": "armpit", "add": 2}, {"do": "sfx", "sound": "hand_grab", "volume": -6.0}])
	await _say(d.get("intro", []))
	var won := false
	for i in TRIES:
		var pick := await _ask(names, "挠哪里？（还能试 %d 次）" % (TRIES - i))
		var spot: String = SPOTS[clampi(pick, 0, SPOTS.size() - 1)]
		var sd: Dictionary = d["spots"][spot]
		_act([{"do": "cover", "who": BLUE, "zone": str(sd.get("zone", "thigh")), "add": 1}, {"do": "crack", "long": false}])
		if spot != weak:
			var near := _near(spot, weak)
			await _say(sd["miss_near"] if near else sd["miss_far"])
			continue
		await _say(sd["hit"])
		var ok: bool = await _combo()
		if ok:
			_act([{"do": "crack", "long": true}, {"do": "pose", "who": BLUE, "laugh": 90}, {"do": "cover", "who": BLUE, "zone": str(sd.get("zone", "thigh")), "add": 2}])
			await _say(sd["break"])
			won = true
			break
		await _say(d.get("combo_fail", []))
	if not is_instance_valid(origin) or not origin.is_inside_tree():
		running = false
		GameState.in_dialogue = Dialogue.is_active()
		return false # 换图／测试跳关后不把旧挑战结果写进新场景。
	_act([{"do": "uncover", "who": BLUE}, {"do": "pose", "who": BLUE, "laugh": 0}])
	settle(won)
	if won:
		await _say(d.get("win", []))
	else:
		await _say(d.get("lose", []))
	running = false
	GameState.in_dialogue = Dialogue.is_active()
	return won


## 弱点旁边的部位（腰 ↔ 屁股 ↔ 大腿 ↔ 膝盖窝 顺着身体往下排，相邻算「近」）
static func _near(spot: String, weak: String) -> bool:
	var order := ["waist", "butt", "thigh", "knee"]
	return absi(order.find(spot) - order.find(weak)) == 1


static func _combo() -> bool:
	if auto_qte != null:
		return bool(auto_qte)
	var p := GameState.player
	if not is_instance_valid(p):
		return false
	var q := KeySequenceQTE.start(p, 4, 3.2)
	var ok: bool = await q.finished
	return ok


static func _ask(texts: Array, prompt: String) -> int:
	if not auto_picks.is_empty():
		return int(auto_picks.pop_front())
	return await Dialogue.runner.choice_menu.ask(texts, prompt)


static func _act(actions: Array) -> void:
	for a in actions:
		Cutscene._do(a, false)


static func _say(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	Dialogue.start_lines(lines, "after_play")
	while Dialogue.is_active():
		await tree.process_frame
	GameState.in_dialogue = running
