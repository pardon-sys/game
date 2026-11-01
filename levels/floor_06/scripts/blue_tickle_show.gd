class_name BlueTickleShow
extends TrainingStage
## 支线「点灯笼的小姑娘」在旧石灯笼前的两个小游戏（台词 knight_quests.json 的 blue.tickle / blue.both）：
##   tickle 找痒点（背靠背互挠）：A / D 在她身上移动光标（SPOTS：膝盖窝 / 大腿内侧 / 腿根 / 屁股 / 腰），光标离她最怕痒的地方（weak，藏着的）
##     越近，光点闪得越快；S 挠：正中 +HIT、旁边一格 +NEAR、别的地方 +MISS。挠中 HITS_PER_SPOT 下她就换一处藏。
##     她也会回挠：亮「！」WARN 秒，按 J 护住；没护 = 闷笑 +POKE。比谁先笑满：她先满 → 灯笼亮一下又暗（返回 true，台词 short）；你先满 → 重来。
##   both 一起笑（共鸣，照七日赎罪修图腾的玩法，ResonanceMeter）：两个人的笑声都停在金线区间（lo~hi）里才攒满；
##     A 让她挠轻一点 / D 挠重一点（你的笑声），J 你挠轻一点 / K 挠重一点（她的笑声）；同一个键再按一次回到平常（PINK_RATES / BLUE_RATES）。
##     笑声还会自己晃（DRIFT）。攒满 = 两个人一起笑出声，灯笼亮了（返回 true）；有人笑过裂开线 = 攒的掉一截（CRACK_LOSS）。
##   follow_laugh：两个木偶跟着各自的笑声换姿势。
## 测试：quiet、mode、cursor、weak、blue_laugh、warn_left、move(±1)、tickle_now()、pull()、meter、set_mode(谁, -1/0/1)、simulate(秒)。

const SPOT_ZONES := ["thigh", "thigh", "thigh", "butt", "waist"]
const HIT := 0.12
const NEAR := 0.04
const MISS := 0.0
const HITS_PER_SPOT := 3
const PRESS_COOL := 0.22
const WARN := 0.8
const WARN_EVERY := 2.6
const POKE := 0.09
const PINK_RATES := {-1: -0.07, 0: 0.02, 1: 0.085}
const BLUE_RATES := {-1: -0.07, 0: 0.02, 1: 0.085}
const DRIFT := 0.035
const HOLD := 12.0
const CRACK_LOSS := 0.35

static var quiet := false

var mode := "tickle"
var cursor := 2
var weak := 0
var blue_laugh := 0.0
var warn_left := 0.0
var meter := ResonanceMeter.new()
var pink_mode := 0
var blue_mode := 0
var _hits := 0
var _warn_t := WARN_EVERY
var _press := 0.0
var _t := 0.0
var _done := false
var _ok := false
var _info: Label
var _panel: Control


func _init() -> void:
	follow_laugh = true   # 两个木偶跟着各自的笑声换姿势


## 蓝色公主的木偶跟她自己的笑声（blue_laugh）走
func actor_laugh_ratio(id: String) -> float:
	if id == "blue":
		return clampf(blue_laugh, 0.0, 1.0)
	return super(id)


func tx() -> Dictionary:
	return KnightQuests.info("blue").get(mode, {})


func spots() -> Array:
	return KnightQuests.info("blue").get("tickle", {}).get("spots", ["膝盖窝", "大腿内侧", "腿根", "屁股", "腰"])


func panel_title() -> String:
	return str(tx().get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"lantern": {"kind": "npc:granny", "at": [60, -40], "dir": "down"}}


func _build_cast(cast: Dictionary) -> void:
	cast.erase("lantern")
	super(cast)
	# 背靠背坐在灯笼底下
	for spec in [["princess", "pink", Vector2(-12, 8), "left"], ["blue", "blue", Vector2(12, 8), "right"]]:
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
	_panel = SpotPanel.new() if mode == "tickle" else ResonanceBars.new()
	_panel.set("show_ref", self)
	_panel.position = Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y - 30)
	_panel.size = Vector2(FRAME_RECT.size.x, 28)
	root.add_child(_panel)
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
	blue_laugh = 0.0 if mode == "tickle" else 0.2
	warn_left = 0.0
	_warn_t = WARN_EVERY
	cursor = 2
	_hits = 0
	weak = rng.randi_range(0, spots().size() - 1)
	meter.charge = 0.0
	meter.rate = 1.0 / HOLD
	pink_mode = 0
	blue_mode = 0
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(0.0 if mode == "tickle" else player.laugh.max_value * 0.2)
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var r := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	if mode == "both":
		_info.text = str(tx().get("panel", "%s\n你 %d%%　她 %d%%\n攒的笑声 %d%%")) % [panel_title(), int(r * 100.0), int(blue_laugh * 100.0), int(meter.charge * 100.0)]
	else:
		_info.text = str(tx().get("panel", "%s\n你 %d%%　她 %d%%\n光标：%s")) % [panel_title(), int(r * 100.0), int(blue_laugh * 100.0), str(spots()[cursor])]


func _update_count() -> void:
	count_label.text = ("%d%%" % int(meter.charge * 100.0)) if mode == "both" else ("%d%%" % int(blue_laugh * 100.0))


func _on_key(k: String) -> void:
	if busy:
		return
	if mode == "tickle":
		match k:
			"A": move(-1)
			"D": move(1)
			"S": tickle_now()
			"J": pull()
	else:
		match k:
			"A": set_mode("pink", -1)
			"D": set_mode("pink", 1)
			"J": set_mode("blue", -1)
			"K": set_mode("blue", 1)


# ------------------------------------------------------------------ tickle：找痒点
func move(dir: int) -> void:
	cursor = clampi(cursor + dir, 0, spots().size() - 1)
	_refresh()


## 光标离痒点几格（0 = 正中）
func distance() -> int:
	return absi(cursor - weak)


## S：挠光标那一处
func tickle_now() -> String:
	if _press > 0.0 or mode != "tickle":
		return ""
	_press = PRESS_COOL
	var d := distance()
	var res := "hit" if d == 0 else ("near" if d == 1 else "miss")
	blue_laugh = minf(1.0, blue_laugh + (HIT if d == 0 else (NEAR if d == 1 else MISS)))
	var pool: Array = KnightQuests.info("blue").get("tickle", {}).get(res, [])
	if not pool.is_empty():
		narrate(str(pool.pick_random()), 1.0)
	tickle("princess", str(SPOT_ZONES[cursor]), false, "blue", "hand")
	if d == 0:
		_hits += 1
		if _hits >= HITS_PER_SPOT:
			# 她换一处藏：别的地方
			_hits = 0
			var w := weak
			while w == weak:
				w = rng.randi_range(0, spots().size() - 1)
			weak = w
			var moved: Array = KnightQuests.info("blue").get("tickle", {}).get("moved", [])
			if not moved.is_empty():
				say("blue", str(moved.pick_random()))
	if blue_laugh >= 1.0:
		_ok = true
		_done = true
	_refresh()
	return res


## J：她回挠的时候护住
func pull() -> bool:
	if warn_left <= 0.0:
		return false
	warn_left = 0.0
	var pool: Array = KnightQuests.info("blue").get("tickle", {}).get("pull", ["（护住了！）"])
	narrate(str(pool.pick_random()), 0.8)
	return true


# ------------------------------------------------------------------ both：共鸣
func set_mode(who: String, m: int) -> void:
	if who == "pink":
		pink_mode = 0 if pink_mode == m else m
	else:
		blue_mode = 0 if blue_mode == m else m
	_refresh()


func _tick(delta: float) -> void:
	simulate(delta)


func simulate(delta: float) -> void:
	if _done:
		return
	_t += delta
	_press = maxf(0.0, _press - delta)
	if mode == "both":
		_tick_both(delta)
	else:
		_tick_tickle(delta)
	_refresh()


func _tick_tickle(delta: float) -> void:
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left <= 0.0:
			add_laugh(laugh_max() * POKE)
			tickle("blue", "sole", false, "princess", "hand")
			var pool: Array = KnightQuests.info("blue").get("tickle", {}).get("poke", [])
			if not pool.is_empty():
				narrate(str(pool.pick_random()), 1.0)
	else:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_warn_t = WARN_EVERY + rng.randf_range(-0.8, 0.8)
			warn_left = WARN
			pop(actors.get("princess"), "！", GOLD, WARN)


func _tick_both(delta: float) -> void:
	# 两个人互相挠：力度按键调，笑声还会自己晃
	var dp := float(PINK_RATES[pink_mode]) + DRIFT * sin(_t * 1.3)
	var db := float(BLUE_RATES[blue_mode]) + DRIFT * sin(_t * 1.7 + 1.0)
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(clampf(player.laugh.value + player.laugh.max_value * dp * delta, 0.0, player.laugh.max_value * 0.99))
	blue_laugh = clampf(blue_laugh + db * delta, 0.0, 1.0)
	if fmod(_t, 0.8) < delta:
		tickle("blue", "sole", false, "princess", "hand")
		tickle("princess", "thigh", false, "blue", "hand")
	var pr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	match meter.step(delta, pr, blue_laugh):
		"full":
			_ok = true
			_done = true
		"crack":
			meter.charge = maxf(0.0, meter.charge - CRACK_LOSS)
			narrate(str(tx().get("crack", "（笑过头了——两个人笑得差点从灯笼底下滚下去！）")), 1.2)
			if pr >= meter.crack and player.laugh:
				player.laugh.set_value(player.laugh.max_value * 0.5)
			if blue_laugh >= meter.crack:
				blue_laugh = 0.5


## 你先笑满（找痒点）：这一局重来
func _punish(kind: String) -> void:
	if kind != "laugh":
		if player.fatigue:
			player.fatigue.clear()
		return
	if mode == "both":
		return
	busy = true
	narrate(str(tx().get("fail", "（你先笑倒了——她拍拍你：「……再来。」）")), 1.2)
	await get_tree().create_timer(0.1 if quiet else 1.0).timeout
	_reset()
	busy = false


## 找痒点的面板：她身上五处，光标所在那处亮；离痒点越近，光点闪得越快
class SpotPanel extends Control:
	var show_ref: BlueTickleShow
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(show_ref):
			return
		var n := show_ref.spots().size()
		var w := size.x / n
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.12, 0.8))
		for i in n:
			var x := i * w
			var on := i == show_ref.cursor
			draw_rect(Rect2(x + 2, 2, w - 4, size.y - 4), Color(0.55, 0.75, 1.0, 0.35) if on else Color(0.3, 0.3, 0.4, 0.25), on)
			draw_string(font, Vector2(x + 4, size.y - 6), str(show_ref.spots()[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 6, 7, Color.WHITE if on else Color(0.75, 0.75, 0.85))
		# 光标上的光点：离痒点 0 格闪得最快，越远越慢
		var d := show_ref.distance()
		var speed := 14.0 / float(1 + d * 2)
		var a := 0.5 + 0.5 * sin(_t * speed)
		draw_circle(Vector2(show_ref.cursor * w + w * 0.5, 8), 3.0, Color(1.0, 0.85, 0.4, a))


## 共鸣面板：两条横着的笑声条（金线区间、红色裂开线）和攒的笑声
class ResonanceBars extends Control:
	var show_ref: BlueTickleShow

	func _process(_delta: float) -> void:
		queue_redraw()

	func bar(y: float, ratio: float, col: Color, label: String) -> void:
		var m := show_ref.meter
		var x0 := 26.0
		var w := size.x - x0 - 60.0
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(2, y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)
		draw_rect(Rect2(x0, y, w, 8), Color("2c2236"))
		draw_rect(Rect2(x0, y, w * ratio, 8), col if m.in_zone(ratio) else col.darkened(0.35))
		draw_rect(Rect2(x0 + w * m.lo, y - 1, w * (m.hi - m.lo), 10), Color("ffd27a"), false, 1.0)
		draw_line(Vector2(x0 + w * m.crack, y - 1), Vector2(x0 + w * m.crack, y + 9), Color("ff6f8e"), 1.0)

	func _draw() -> void:
		if not is_instance_valid(show_ref):
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.12, 0.8))
		var pr := show_ref.player.laugh.ratio() if is_instance_valid(show_ref.player) and show_ref.player.laugh else 0.0
		bar(3, pr, Color("ff9cc6"), "你")
		bar(16, show_ref.blue_laugh, Color("8fc6ff"), "她")
		var cx := size.x - 50.0
		draw_rect(Rect2(cx, 4, 44, 20), Color("2c2236"))
		draw_rect(Rect2(cx, 4, 44 * show_ref.meter.charge, 20), Color("ffd27a"))
		draw_string(ThemeDB.fallback_font, Vector2(cx + 4, 17), "一起笑", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
