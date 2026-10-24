class_name FestivalDanceShow
extends TrainingStage
## 庆功宴的「篝火领舞」（借训练小游戏的画面 + 下方的 RhythmLane 音符条）。台词 data/after/festival_night.json 的 dance。
##   sections 依次：领舞（lane，失误 → 围观的人挠脚心）→ 邀舞（invite）→ 双人舞（lane，失误 → 千手痒痒裤的小手挠粉色或蓝色）→ 全镇一起跳（lane）。
##   lane 段：bpm、notes 一张谱面；段末得分 < PASS 比例这一段重跳；闷笑满 = 脚下一绊（这一段重跳）。
##   邀舞：蓝色公主的嘴硬值 resolve；选部位（ChoiceMenu）减 power，写了 combo 的部位接一串 COMBO_NOTES 个音符（失误 ≤ COMBO_MISS 再减一截）；
##     每次挠完小手帮倒忙（挠粉色公主一下，闷笑上涨）；嘴硬值到 0 → 她服软，进双人舞。
##   蓝色公主在舞台上（id blue），被挠时她冒自己的反应（react_blue）。
## await play() → true。测试：quiet、auto_picks（邀舞依次选的部位序号）、auto_combo（连击直接给结果）、lane、resolve。

const PATH := "res://data/after/festival_night.json"
const PASS := 0.5
const MISS_LAUGH := 0.1
const HELP_LAUGH := 0.08
const COMBO_NOTES := 6
const COMBO_MISS := 1
const COMBO_POWER := 20

static var quiet := false
static var auto_picks: Array = []
static var auto_combo: Variant = null
static var _text := {}

var lane: RhythmLane
var section := -1
var stumbles := 0
var misses := 0
var resolve := 0
var _done := false
var _info: Label
var _seed := 0
var _combo := false


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


static func text() -> Dictionary:
	return data().get("dance", {})


func panel_title() -> String:
	return str(text().get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"host": {"kind": "npc:bonfire_host", "at": [34, 2], "dir": "left"},
		"granny": {"kind": "npc:granny", "at": [-36, 2], "dir": "right"},
		"kid1": {"kind": "npc:kid", "at": [-30, 26], "dir": "right"},
		"kid2": {"kind": "npc:kid", "at": [30, 26], "dir": "left"}}


## 两位公主都用公主的精灵图：粉色 id princess 在中间，蓝色 id blue 在旁边（邀舞以后走到她对面）
func _build_cast(cast: Dictionary) -> void:
	super(cast)
	for spec in [["princess", "pink", Vector2(-8, 10), "down"], ["blue", "blue", Vector2(56, 4), "left"]]:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose("normal", "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a


func play() -> bool:
	player = GameState.player
	rng.randomize()
	_seed = rng.randi()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = str(text().get("hint", ""))
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
	await _start_section(0)
	busy = false
	while not _done and is_inside_tree():
		await get_tree().process_frame
	await _exit_game()
	finished.emit()
	return true


## 反应框占下方 112,218 ~ 350,263：计数和操作提示挪到右边（和 ErrandWorkStage 一样）
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
	Dialogue.start_lines(lines, "festival_dance")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func cur() -> Dictionary:
	var ss: Array = text().get("sections", [])
	return ss[section] if section >= 0 and section < ss.size() else {}


func _start_section(i: int) -> void:
	section = i
	var s := cur()
	if str(s.get("kind", "lane")) == "invite":
		await _invite()
		await _start_section(i + 1)
		return
	if i >= 2:
		_pair_up()
	await _lines(s.get("start", []))
	lane.load_chart(RhythmLane.make_chart(float(s.get("bpm", 100)), int(s.get("notes", 16)), _seed + i * 31 + stumbles * 7))
	_refresh()


## 邀舞以后蓝色公主走到她对面
func _pair_up() -> void:
	var b: CGActor = actors.get("blue")
	var p: CGActor = actors.get("princess")
	if b and p:
		b.position = Vector2(14, 10)
		b.set_dir("left")
		p.set_dir("right")


func _refresh() -> void:
	if _info == null:
		return
	if str(cur().get("kind", "lane")) == "invite":
		_info.text = "%s\n嘴硬 %d" % [cur().get("name", ""), resolve]
		return
	var c := lane.counts
	_info.text = "%s\n完美 %d　不错 %d　失误 %d\n得分 %d / %d" % [cur().get("name", ""), int(c["perfect"]), int(c["good"]), int(c["miss"]),
		lane.score(), lane.max_score()]


func _on_key(k: String) -> void:
	lane.press(k)


func _on_judged(res: String, _n: Dictionary) -> void:
	var pr: CGActor = actors.get("princess")
	if _combo:
		pop(pr, "挠！" if res != "miss" else "失手", GOOD if res != "miss" else BAD, 0.5)
		return
	if res == "miss":
		pop(pr, "失误", BAD, 0.6)
		misses += 1
		_miss_tickle()
	else:
		pop(pr, "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.6)
		var pool: Array = text().get("praise", {}).get(res, [])
		if rng.randf() < 0.2 and not pool.is_empty():
			say("host", str(pool.pick_random()))
		if pr and section == 0:
			pr.set_dir(["left", "right", "down", "up"][rng.randi() % 4])
	_refresh()


## 失误：这一段的 miss 里挑一条（who = pink / blue），被挠的人冒反应；挠粉色的闷笑上涨
func _miss_tickle() -> void:
	var s := cur()
	var pool: Array = s.get("miss", [])
	if pool.is_empty():
		return
	var m: Dictionary = pool[rng.randi() % pool.size()]
	narrate(str(m["caption"]))
	if str(m.get("who", "pink")) == "blue":
		tickle("", "thigh", false, "blue", "hand")
		var rb: Dictionary = s.get("react_blue", {})
		var lines: Array = rb.get(["light", "mid", "heavy"][mini(2, misses / 4)], [])
		if not lines.is_empty():
			say("blue", str(lines.pick_random()))
		return
	tickle("kid1" if section == 0 else "", str(s.get("zone", "sole")), rng.randf() < 0.12, "princess", "hand")
	add_laugh(laugh_max() * MISS_LAUGH)
	var react: Array = s.get("react", {}).get(_tier(), [])
	if not react.is_empty():
		say("princess", str(react.pick_random()))


func _tier() -> String:
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	return "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")


func _tick(delta: float) -> void:
	if section < 0 or str(cur().get("kind", "lane")) == "invite":
		return
	lane.advance(delta)
	if lane.finished() and lane.time >= lane.end_time():
		_section_end()


func _section_end() -> void:
	busy = true
	if float(lane.score()) < float(lane.max_score()) * PASS:
		await _lines(text().get("retry", []))
		await _start_section(section)
		busy = false
		return
	await _lines(cur().get("end", []))
	if section + 1 < (text().get("sections", []) as Array).size():
		await _start_section(section + 1)
		busy = false
		return
	await _lines(text().get("done", []))
	_done = true
	busy = false


## 闷笑满：脚下一绊，这一段重跳
func _punish(kind: String) -> void:
	if kind != "laugh":
		if player.fatigue:
			player.fatigue.clear()
		return
	busy = true
	stumbles += 1
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.shake(0.6)
	await _lines(text().get("stumble", []))
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.35)
	await _start_section(section)
	busy = false


# ------------------------------------------------------------------ 邀舞
func _invite() -> void:
	var inv: Dictionary = text().get("invite", {})
	resolve = int(inv.get("resolve", 100))
	_refresh()
	await _lines(inv.get("intro", []))
	var spots: Array = inv.get("spots", [])
	while resolve > 0 and is_inside_tree():
		var pick := await _ask(spots.map(func(s): return str(s["name"])), str(inv.get("prompt", "")) % resolve)
		var spot: Dictionary = spots[clampi(pick, 0, spots.size() - 1)]
		await _lines(spot.get("lines", []))
		tickle("princess", str(spot.get("zone", "thigh")), false, "blue", "hand")
		resolve -= int(spot.get("power", 0))
		if bool(spot.get("combo", false)) and resolve > 0:
			if await _combo_ok():
				resolve -= COMBO_POWER
				await _lines(inv.get("combo_ok", []))
			else:
				await _lines(inv.get("combo_fail", []))
		resolve = maxi(0, resolve)
		_refresh()
		if resolve > 0:
			_pants_help(inv.get("help", {}))
	await _lines(inv.get("agree", []))


## 挠对了地方：接一串短谱面，失误不超过 COMBO_MISS 算成功
func _combo_ok() -> bool:
	if auto_combo != null:
		return bool(auto_combo)
	_combo = true
	lane.load_chart(RhythmLane.make_chart(120, COMBO_NOTES, _seed + resolve, 0.8))
	busy = false
	while is_inside_tree() and not (lane.finished() and lane.time >= lane.end_time()):
		lane.advance(get_process_delta_time())
		await get_tree().process_frame
	busy = true
	_combo = false
	return int(lane.counts["miss"]) <= COMBO_MISS


## 千手痒痒裤的小手帮倒忙：挠到粉色公主
func _pants_help(help: Dictionary) -> void:
	var caps: Array = help.get("caption", [])
	if not caps.is_empty():
		narrate(str(caps.pick_random()))
	tickle("", "sole", false, "princess", "hand")
	add_laugh(laugh_max() * HELP_LAUGH, 0.9)
	var rs: Array = help.get("react", [])
	if not rs.is_empty():
		say("princess", str(rs.pick_random()))


func _ask(texts: Array, prompt: String) -> int:
	if not auto_picks.is_empty():
		return int(auto_picks.pop_front())
	if quiet:
		return 2
	return await Dialogue.runner.choice_menu.ask(texts, prompt)


func _update_count() -> void:
	pass
