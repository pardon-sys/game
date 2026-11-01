class_name PartyShow
extends TrainingStage
## 支线「没有名字的生日」（派对主人）的几个小游戏，同一个画面换玩法（mode）。台词 knight_quests.json 的 host.shows[mode]。
##   duster 借彩带（商人试新羽毛掸子）：站着不能躲，掸子一下一下扫脚心——屏幕上冒 A / S / D（脚趾 / 脚心 / 脚跟），
##     PROMPT_TIME 秒内按对 = 绷住那一处；按错 / 没按 = 扫个正着（闷笑 +HIT_LAUGH）。忍过 COUNT 下就算借到。
##   taste 借点心（女仆的「不许笑的试吃」）：按 E 吃一口（间隔 BITE_COOL），吃完 BITES 口；女仆的小刷子时不时亮「！」（WARN 秒）要刷脚了——
##     亮的时候按 J 缩脚躲开；没躲 = 刷个正着；亮着的时候还在吃 = 一口呛笑出来（闷笑多涨一截）。
##   wheel 借蜡烛（矿工的脚底按摩器）：踩着转轮跟节拍（RhythmLane），失误 = 转轮上的软刺挠一下。
##   dance 生日舞排练：三个人一起跳（RhythmLane，两段），失误 = 围观的人挠。
##   wish 蜡烛许愿：寿星捧着蛋糕许愿，风一阵一阵吹来（GUSTS 阵）——每阵风来时屏幕上突然冒出音游条（RhythmLane，像夜里栅栏那样），
##     跟着节拍按方向键护住火苗；按错 = 火苗变小（flame −FLAME_MISS）、围着的大家趁机挠一下；完美 = 火苗回一点。
##     风停的空当里大家挠两位公主（蓝色公主的笑 blue_laugh 跟着涨，木偶跟着换姿势）。三阵风都挺过去、火苗还亮着 = 许愿成功；火苗灭了 = 重来。
##   闷笑满 = 这一局输，重来。赢了 await play() 返回 true。
## 测试：quiet、mode、score、need、prompt、warn_left、blue_laugh、flame、gust_on()、press_key(键)、lane。

const PROMPT_TIME := 0.85
const HIT_LAUGH := 0.12
const DUSTER_COUNT := 12
const BITES := 10
const BITE_COOL := 0.35
const WARN := 0.7
const WARN_EVERY := 1.9
const TUCK_MISS := 0.1
const CHOKE := 0.16
const LANE_MISS := 0.1
const PASSIVE := 0.02
const WISH_BLUE_RATE := 0.03
const GUSTS := 3
const FLAME_MISS := 0.22
const FLAME_PERFECT := 0.04
const GUST_GAP := 2.2
const KEYS := {"A": "脚趾", "S": "脚心", "D": "脚跟"}

static var quiet := false

var mode := "duster"
var score := 0
var need := 1
var prompt := ""
var prompt_left := 0.0
var warn_left := 0.0
var blue_laugh := 0.0
var flame := 1.0
var lane: RhythmLane
var candle: CandleRig
var _gust_t := 1.5
var section := 0
var _warn_t := WARN_EVERY
var _bite := 0.0
var _gap := 0.8
var _done := false
var _ok := false
var _info: Label


static func text() -> Dictionary:
	return KnightQuests.info("host").get("shows", {})



func _init() -> void:
	follow_laugh = true   # 木偶跟着闷笑换姿势


## 蓝色公主的木偶跟她自己的笑声（blue_laugh）走
func actor_laugh_ratio(id: String) -> float:
	if id == "blue":
		return clampf(blue_laugh, 0.0, 1.0)
	return super(id)


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
	if mode in ["wheel", "dance", "wish"]:
		lane = RhythmLane.new()
		lane.position = Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y - 22)
		lane.size = Vector2(FRAME_RECT.size.x, 20)
		root.add_child(lane)
		lane.judged.connect(_on_judged)
	if mode == "wish":
		candle = CandleRig.new()
		candle.show_ref = self
		candle.position = Vector2(28, -22)
		cast_root.add_child(candle)
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
			need = GUSTS
			flame = 1.0
			_gust_t = 1.5
			lane.visible = false
			lane.load_chart([])
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
			s += "第 %d / %d 阵风　火苗 %d%%" % [mini(section + 1, need), need, int(flame * 100.0)]
			if gust_on():
				s += "\n风来了——护住火苗！"
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
			if gust_on():
				lane.press(k)
		"wheel", "dance":
			lane.press(k)
	_refresh()


func _on_judged(res: String, _n: Dictionary) -> void:
	if mode == "wish":
		if res == "miss":
			flame = maxf(0.0, flame - FLAME_MISS)
			blue_laugh = minf(1.0, blue_laugh + 0.06)
			_hit(LANE_MISS)
			if flame <= 0.0:
				_candle_out()
		else:
			flame = minf(1.0, flame + FLAME_PERFECT * (1.0 if res == "perfect" else 0.5))
			pop(actors.get("princess"), "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.5)
		return
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
		"wish":
			_tick_wish(delta)
		"taste":
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
		"wheel", "dance":
			lane.advance(delta)
			if lane.finished() and lane.time >= lane.end_time():
				if mode == "dance" and section == 0:
					section = 1
					lane.load_chart(RhythmLane.make_chart(124.0, 16, rng.randi()))
				else:
					_win()
	_refresh()


## wish：现在有没有风（音游条亮着）
func gust_on() -> bool:
	return lane != null and lane.visible


func _tick_wish(delta: float) -> void:
	blue_laugh = minf(1.0, blue_laugh + WISH_BLUE_RATE * delta)
	if not gust_on():
		_gust_t -= delta
		if _gust_t <= 0.0:
			# 一阵风：音游条突然冒出来
			lane.load_chart(RhythmLane.make_chart(98.0 + section * 12.0, 8 + section * 2, rng.randi(), 0.9))
			lane.visible = true
			narrate(str((tx().get("gust", ["（一阵风吹过来——火苗一歪！）"]) as Array).pick_random()), 1.4)
		elif fmod(_gust_t, 0.7) < delta:
			# 风停的空当：大家挠两位公主
			tickle("", "sole", false, "princess", "feather")
			tickle("", "thigh", false, "blue", "feather")
		return
	lane.advance(delta)
	if lane.finished() and lane.time >= lane.end_time():
		lane.visible = false
		section += 1
		if section >= need:
			_win()
			return
		_gust_t = GUST_GAP
		narrate(str((tx().get("calm", ["（风停了一下。大家的羽毛趁机伸了过来）"]) as Array).pick_random()), 1.4)


## 火苗灭了：这一局重来
func _candle_out() -> void:
	busy = true
	lane.visible = false
	narrate(str(tx().get("out", "（火苗「噗」地灭了——「重来重来！」大家笑着又点上了）")), 1.6)
	await get_tree().create_timer(0.1 if quiet else 1.2).timeout
	_reset_round()
	busy = false


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


## 许愿的蜡烛（舞台上寿星手边）：火苗大小跟 flame 走，一闪一闪；有风的时候歪向一边
class CandleRig extends Node2D:
	var show_ref: PartyShow
	var _t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-6, 2, 12, 5), Color(0.95, 0.85, 0.75))          # 蛋糕
		draw_rect(Rect2(-6, 2, 12, 1), Color(1.0, 0.6, 0.75))
		draw_rect(Rect2(-1, -6, 2, 8), Color(1.0, 0.95, 0.85))           # 蜡烛
		if not is_instance_valid(show_ref) or show_ref.flame <= 0.0:
			return
		var f := show_ref.flame
		var lean := (sin(_t * 9.0) * 2.0 + 2.5) if show_ref.gust_on() else sin(_t * 3.0) * 0.5
		var h := (3.0 + 4.0 * f) * (1.0 + 0.12 * sin(_t * 17.0))
		var top := Vector2(lean, -6.0 - h)
		draw_colored_polygon(PackedVector2Array([Vector2(-1.8 * f - 0.6, -6), top, Vector2(1.8 * f + 0.6, -6)]), Color(1.0, 0.65, 0.2, 0.9))
		draw_circle(Vector2(lean * 0.4, -7.0 - h * 0.3), 0.9 + f, Color(1.0, 0.95, 0.6))
