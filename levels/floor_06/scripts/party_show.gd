class_name PartyShow
extends TrainingStage
## 支线「没有名字的生日」（派对主人）的几个小游戏，同一个画面换玩法（mode）。台词 knight_quests.json 的 host.shows[mode]。
##   duster 借彩带（商人试新羽毛掸子）：站着不能躲，掸子一下一下扫脚心——屏幕上冒 A / S / D（脚趾 / 脚心 / 脚跟），
##     PROMPT_TIME 秒内按对 = 绷住那一处；按错 / 没按 = 扫个正着（闷笑 +HIT_LAUGH）。忍过 COUNT 下就算借到。
##   taste 借点心（女仆的「不许笑的试吃」）：按 E 吃一口（间隔 BITE_COOL），吃完 BITES 口；女仆的小刷子时不时亮「！」（WARN 秒）要刷脚了——
##     亮的时候按 J 缩脚躲开；没躲 = 刷个正着；亮着的时候还在吃 = 一口呛笑出来（闷笑多涨一截）。
##   wheel 借蜡烛（矿工的脚底按摩器）：踩着转轮跟节拍（RhythmLane），失误 = 转轮上的软刺挠一下。
##   dance 生日舞排练：三个人一起跳（RhythmLane，两段），失误 = 围观的人挠。
##   wish 忍笑许愿：大家挠寿星和两位公主——她要撑到蓝色公主先笑出来（蓝色的笑条到顶），然后把许愿让给寿星：
##     亮「！」时按 J 缩脚，没缩 = 狠狠一下；一直在慢慢涨。
##   闷笑满 = 这一局输，重来。赢了 await play() 返回 true。
## 测试：quiet、mode、score、need、prompt、warn_left、blue_laugh、press_key(键)、lane。

const PROMPT_TIME := 1.0
const HIT_LAUGH := 0.12
const DUSTER_COUNT := 10
const BITES := 8
const BITE_COOL := 0.35
const WARN := 0.7
const WARN_EVERY := 2.2
const TUCK_MISS := 0.1
const CHOKE := 0.16
const LANE_MISS := 0.1
const PASSIVE := 0.02
const WISH_BLUE_RATE := 0.07
const KEYS := {"A": "脚趾", "S": "脚心", "D": "脚跟"}

static var quiet := false

var mode := "duster"
var score := 0
var need := 1
var prompt := ""
var prompt_left := 0.0
var warn_left := 0.0
var blue_laugh := 0.0
var lane: RhythmLane
var section := 0
var _warn_t := WARN_EVERY
var _bite := 0.0
var _gap := 0.8
var _done := false
var _ok := false
var _info: Label


static func text() -> Dictionary:
	return KnightQuests.info("host").get("shows", {})


func tx() -> Dictionary:
	return text().get(mode, {})


func panel_title() -> String:
	return str(tx().get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	var c := {"host": {"kind": "npc:bonfire_host", "at": [28, 2], "dir": "left"}}
	match mode:
		"duster":
			c["merchant"] = {"kind": "npc:merchant", "at": [18, 6], "dir": "left"}
		"taste":
			c["maid"] = {"kind": "npc:maid", "at": [18, 6], "dir": "left"}
		"wheel":
			c["miner"] = {"kind": "npc:miner", "at": [18, 6], "dir": "left"}
		_:
			c["granny"] = {"kind": "npc:granny", "at": [-36, 2], "dir": "right"}
			c["kid1"] = {"kind": "npc:kid", "at": [-30, 26], "dir": "right"}
			c["kid2"] = {"kind": "npc:kid", "at": [30, 26], "dir": "left"}
	return c


func _build_cast(cast: Dictionary) -> void:
	super(cast)
	var who := [["princess", "pink", Vector2(-8, 10), "right"]]
	if mode in ["dance", "wish"]:
		who.append(["blue", "blue", Vector2(-34, 8), "right"])
	for spec in who:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose("normal", "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = str(tx().get("hint", ""))
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	if mode in ["wheel", "dance"]:
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
	await _lines(tx().get("intro", []))
	_reset_round()
	busy = false
	while not _done and is_inside_tree():
		await get_tree().process_frame
	await _lines(tx().get("win" if _ok else "lose", []))
	await _exit_game()
	finished.emit()
	return _ok


func _build_ui() -> void:
	super()
	count_label.position = Vector2(356, 218)
	count_label.size = Vector2(116, 14)
	count_label.add_theme_font_size_override("font_size", 7)
	hint_label.position = Vector2(356, 232)
	hint_label.size = Vector2(116, 37)
	hint_label.add_theme_font_size_override("font_size", 7)


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var was := busy
	busy = true
	Dialogue.start_lines(lines, "party_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


## 这一局从头来
func _reset_round() -> void:
	score = 0
	prompt = ""
	warn_left = 0.0
	blue_laugh = 0.0
	section = 0
	_warn_t = WARN_EVERY
	_gap = 0.8
	match mode:
		"duster":
			need = DUSTER_COUNT
		"taste":
			need = BITES
		"wheel":
			need = 1
			lane.load_chart(RhythmLane.make_chart(104.0, 14, rng.randi()))
		"dance":
			need = 2
			lane.load_chart(RhythmLane.make_chart(110.0, 14, rng.randi()))
		"wish":
			need = 1
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(0.0)
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var s := "%s\n" % panel_title()
	match mode:
		"duster":
			s += "忍过 %d / %d" % [score, need]
		"taste":
			s += "吃了 %d / %d 口" % [score, need]
		"wheel", "dance":
			var c := lane.counts
			s += "完美 %d　不错 %d　失误 %d" % [int(c["perfect"]), int(c["good"]), int(c["miss"])]
			if mode == "dance":
				s += "\n第 %d / 2 段" % (section + 1)
		"wish":
			s += "蓝色公主的笑 %d%%" % int(blue_laugh * 100.0)
	_info.text = s


func _update_count() -> void:
	count_label.text = "%d / %d" % [score, need]


func _on_key(k: String) -> void:
	press_key(k)


## 按键（测试也直接调）：A/S/D 绷住、E 吃一口、J 缩脚、方向键踩节拍
func press_key(k: String) -> void:
	if busy:
		return
	match mode:
		"duster":
			if prompt != "" and KEYS.has(k):
				if k == prompt:
					score += 1
					narrate(str((tx().get("ok", [""]) as Array).pick_random()), 0.8)
				else:
					_hit(HIT_LAUGH)
				prompt = ""
				_gap = 0.6
				_check()
		"taste":
			if k == "E" and _bite <= 0.0:
				_bite = BITE_COOL
				if warn_left > 0.0:
					_hit(CHOKE)
					narrate(str(tx().get("choke", "")), 1.0)
				else:
					score += 1
					_check()
			elif k == "J" and warn_left > 0.0:
				warn_left = 0.0
				narrate(str((tx().get("tuck", [""]) as Array).pick_random()), 0.8)
		"wish":
			if k == "J" and warn_left > 0.0:
				warn_left = 0.0
				narrate(str((tx().get("tuck", [""]) as Array).pick_random()), 0.8)
		"wheel", "dance":
			lane.press(k)
	_refresh()


func _on_judged(res: String, _n: Dictionary) -> void:
	if res == "miss":
		_hit(LANE_MISS)
	else:
		pop(actors.get("princess"), "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.5)
		if mode == "dance":
			for i in ["princess", "blue", "host"].size():
				var a: CGActor = actors.get(["princess", "blue", "host"][i])
				if a:
					a.dance_move(score + i, res == "perfect")
			score += 1


func _hit(amount: float) -> void:
	var zone := "sole"
	tickle("", zone, false, "princess", "feather" if mode == "duster" else "hand")
	add_laugh(laugh_max() * amount)
	var r: Array = tx().get("react", [])
	if not r.is_empty():
		say("princess", str(r.pick_random()))
	var caps: Array = tx().get("hit", [])
	if not caps.is_empty():
		narrate(str(caps.pick_random()), 1.0)


func _check() -> void:
	if score >= need and mode in ["duster", "taste"]:
		_win()


func _win() -> void:
	_ok = true
	_done = true


func _tick(delta: float) -> void:
	if _done:
		return
	_bite = maxf(0.0, _bite - delta)
	add_laugh(laugh_max() * PASSIVE * delta)
	match mode:
		"duster":
			if prompt != "":
				prompt_left -= delta
				if prompt_left <= 0.0:
					prompt = ""
					_hit(HIT_LAUGH)
					_gap = 0.6
			else:
				_gap -= delta
				if _gap <= 0.0:
					next_prompt()
		"taste", "wish":
			if warn_left > 0.0:
				warn_left -= delta
				if warn_left <= 0.0:
					_hit(TUCK_MISS)
			else:
				_warn_t -= delta
				if _warn_t <= 0.0:
					_warn_t = WARN_EVERY + rng.randf_range(-0.6, 0.6)
					warn_left = WARN
					pop(actors.get("princess"), "！", GOLD, WARN)
			if mode == "wish":
				blue_laugh = minf(1.0, blue_laugh + WISH_BLUE_RATE * delta)
				if blue_laugh >= 1.0:
					_win()
		"wheel", "dance":
			lane.advance(delta)
			if lane.finished() and lane.time >= lane.end_time():
				if mode == "dance" and section == 0:
					section = 1
					lane.load_chart(RhythmLane.make_chart(124.0, 16, rng.randi()))
				else:
					_win()
	_refresh()


## duster：冒下一个要绷住的地方（测试也直接调）
func next_prompt(k := "") -> String:
	prompt = k if k != "" else KEYS.keys()[rng.randi() % KEYS.size()]
	prompt_left = PROMPT_TIME
	pop(actors.get("princess"), "%s %s" % [prompt, KEYS[prompt]], GOLD, PROMPT_TIME)
	return prompt


## 闷笑满：这一局输了，重来
func _punish(kind: String) -> void:
	if kind != "laugh":
		if player.fatigue:
			player.fatigue.clear()
		return
	busy = true
	narrate(str(tx().get("fail", "")), 1.6)
	await get_tree().create_timer(0.1 if quiet else 1.2).timeout
	_reset_round()
	busy = false
