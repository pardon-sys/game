class_name BlueTickleShow
extends TrainingStage
## 支线「点灯笼的小姑娘」在旧石灯笼前的两个小游戏（台词 knight_quests.json 的 blue.tickle / blue.both）：
##   tickle 逗她笑：她的弱点每轮换一处（大腿 / 屁股 / 腰），回合开始时她会漏嘴（weak_hint）；A / S / D 挠：中了她的忍笑 +HIT，错了 +MISS。
##     她时不时手一挥要冻你的手（亮「！」WARN 秒）：按 J 缩回来；没缩 = 手被冻住 FROZEN 秒，这几秒挠不了。
##     她的忍笑满了 → 灯笼亮了一下又暗下去（笑声不够亮）→ 这一局算完（返回 true，台词 short）。
##   both 一起笑：轮流挠（TURN 秒一换）。轮到你挠同 tickle；轮到她挠你：闷笑每秒 +DEFEND_RATE，亮「！」时按 J 缩脚，没缩 = 狠狠一下。
##     她的忍笑满了而你还没笑翻 = 两个人一起笑出声，灯笼亮了（返回 true）。你先笑翻 = 这一局重来。
## 测试：quiet、mode、weak、blue_laugh、warn_left、frozen_left、turn、tickle_blue(处)、pull()、simulate(秒)。

const SPOTS := {"A": 0, "S": 1, "D": 2}
const ZONES := ["thigh", "butt", "waist"]
const HIT := 0.11
const MISS := 0.03
const PRESS_COOL := 0.3
const WARN := 0.8
const WARN_EVERY := 2.5
const FROZEN := 1.5
const TURN := 6.0
const DEFEND_RATE := 0.03
const POKE := 0.1

static var quiet := false

var mode := "tickle"
var weak := 0
var blue_laugh := 0.0
var warn_left := 0.0
var frozen_left := 0.0
var turn := "attack"
var turn_left := TURN
var _warn_t := WARN_EVERY
var _press := 0.0
var _done := false
var _ok := false
var _info: Label


func tx() -> Dictionary:
	return KnightQuests.info("blue").get(mode, {})


func spots() -> Array:
	return KnightQuests.info("blue").get("tickle", {}).get("spots", ["大腿", "屁股", "腰"])


func panel_title() -> String:
	return str(tx().get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"lantern": {"kind": "npc:granny", "at": [60, -40], "dir": "down"}}


func _build_cast(cast: Dictionary) -> void:
	cast.erase("lantern")
	super(cast)
	for spec in [["princess", "pink", Vector2(-16, 8), "right"], ["blue", "blue", Vector2(16, 8), "left"]]:
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
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	busy = true
	await _lines(tx().get("intro", []))
	_reset()
	busy = false
	while not _done and is_inside_tree():
		await get_tree().process_frame
	await _lines(tx().get("short" if mode == "tickle" else "lit", []))
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
	Dialogue.start_lines(lines, "blue_tickle")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func _reset() -> void:
	blue_laugh = 0.0
	warn_left = 0.0
	frozen_left = 0.0
	_start_turn("attack")
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(0.0)


func _start_turn(t2: String) -> void:
	turn = t2
	turn_left = TURN
	warn_left = 0.0
	_warn_t = WARN_EVERY
	if turn == "attack":
		weak = rng.randi_range(0, 2)
		var hints: Array = KnightQuests.info("blue").get("tickle", {}).get("weak_hint", {}).get(str(spots()[weak]), [])
		if not hints.is_empty():
			say("blue", str(hints.pick_random()))
		if mode == "both":
			narrate(str(tx().get("turn_attack", "")), 1.2)
	else:
		narrate(str(tx().get("turn_defend", "")), 1.2)
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	if mode == "both":
		var r := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
		_info.text = str(tx().get("panel", "%s %d %d")) % [panel_title(), int(r * 100.0), int(blue_laugh * 100.0)]
	else:
		_info.text = str(tx().get("panel", "%s %d")) % [panel_title(), int(blue_laugh * 100.0)]


func _update_count() -> void:
	count_label.text = "%d%%" % int(blue_laugh * 100.0)


func _on_key(k: String) -> void:
	if busy:
		return
	if SPOTS.has(k) and turn == "attack":
		tickle_blue(int(SPOTS[k]))
	elif k == "J":
		pull()


## 挠她的一处（0 大腿 / 1 屁股 / 2 腰）
func tickle_blue(spot: int) -> bool:
	if _press > 0.0 or frozen_left > 0.0 or turn != "attack":
		return false
	_press = PRESS_COOL
	var good := spot == weak
	blue_laugh = minf(1.0, blue_laugh + (HIT if good else MISS))
	var lines: Array = KnightQuests.info("blue").get("tickle", {}).get("hit" if good else "miss", [])
	if not lines.is_empty():
		narrate(str(lines.pick_random()), 1.0)
	tickle("princess", str(ZONES[spot]), false, "blue", "hand")
	if blue_laugh >= 1.0:
		_ok = true
		_done = true
	_refresh()
	return good


## J：她要冻你的手的时候缩回来 / 她挠你的时候缩脚
func pull() -> bool:
	if warn_left <= 0.0:
		return false
	warn_left = 0.0
	var pool: Array = KnightQuests.info("blue").get("tickle", {}).get("pull", ["（缩回来了！）"])
	narrate(str(pool.pick_random()), 0.8)
	return true


func _tick(delta: float) -> void:
	simulate(delta)


func simulate(delta: float) -> void:
	if _done:
		return
	_press = maxf(0.0, _press - delta)
	frozen_left = maxf(0.0, frozen_left - delta)
	if mode == "both":
		turn_left -= delta
		if turn_left <= 0.0:
			_start_turn("defend" if turn == "attack" else "attack")
		if turn == "defend":
			add_laugh(laugh_max() * DEFEND_RATE * delta)
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left <= 0.0:
			_warn_hit()
	else:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_warn_t = WARN_EVERY + rng.randf_range(-0.8, 0.8)
			warn_left = WARN
			pop(actors.get("princess"), "！", GOLD, WARN)
	_refresh()


## 没缩：挠你的时候狠狠一下 / 逗她的时候手被冻住
func _warn_hit() -> void:
	if mode == "both" and turn == "defend":
		add_laugh(laugh_max() * POKE)
		tickle("blue", "sole", false, "princess", "hand")
		var pool: Array = tx().get("pink_hit", [])
		if not pool.is_empty():
			narrate(str(pool.pick_random()), 1.0)
	else:
		frozen_left = FROZEN
		var pool2: Array = KnightQuests.info("blue").get("tickle", {}).get("freeze", [])
		if not pool2.is_empty():
			narrate(str(pool2.pick_random()), 1.2)


## 你先笑翻：这一局重来
func _punish(kind: String) -> void:
	if kind != "laugh":
		if player.fatigue:
			player.fatigue.clear()
		return
	busy = true
	await get_tree().create_timer(0.1 if quiet else 1.0).timeout
	_reset()
	busy = false
