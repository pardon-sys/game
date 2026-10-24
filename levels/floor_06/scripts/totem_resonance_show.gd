class_name TotemResonanceShow
extends ErrandWorkStage
## 第 7 天弥补任务「修补狂欢图腾柱」的小游戏「图腾共鸣·双人符文」：两人并排站在图腾前的符文圈里，图腾靠两个人的笑声充能。台词 data/after/totem.json。
##   粉色公主光脚踩「足印符文」（闷笑 = 玩家的闷笑条），蓝色公主站「腿环符文」（闷笑 blue_laugh，只在舞台上模拟）。
##   共鸣（ResonanceMeter）：两人的闷笑同时停在 [LO, HI] 里才充能，满了刻好一道符文；任意一人到 CRACK 以上 → 符文裂开（crack）：
##     这道从头刻、两人闷笑回到 CRACK_RESET；同一道裂开 CRACKS 次 = 失败（after_fail_totem，刻好的不用重刻）。
##   调节：A 绷紧脚趾 / D 张开脚趾（粉色），J 冰封 / K 松开裤子（蓝色）；同一个键再按一次回到平常。每秒的涨落见 PINK_RATES / BLUE_RATES。
##   干扰（WorkInterference）：道具按阶段轮换（phases[].tools），道具挠谁见 tool_who；每次加强挠那个人 STRONG，痒感连线让另一个人跟着涨 LINK 倍。
##   三道符文：羽毛符文 → 交叉符文 → 笑脸符文（充到 FINAL_AT 以后「持续加强」：涨得 ×FINAL_MULT）。
##   魔力疲倦满 → ErrandWorkStage.release（舒服的释放）+ 共鸣爆发：符文一次充 RELEASE_CHARGE。
## 存档：task_totem_runes（刻好几道，0~3）、task_totem_cracks（这一道裂了几次）。
## 测试：quiet、fixed_seed、press()、simulate()、set_mode()、blue_laugh、meter、cracks、strike()。

const PATH := "res://data/after/totem.json"
const SAVE_KEY := "task_totem_runes"
const CRACK_KEY := "task_totem_cracks"
const LIMITS := [1, 2, 3]
const HOLD := [8.0, 10.0, 12.0]
const PHASE_RATE := [1.0, 1.15, 1.3]
const PINK_RATES := {-1: -0.07, 0: 0.025, 1: 0.085}
const BLUE_RATES := {-1: -0.07, 0: 0.02, 1: 0.085}
const STRONG := 0.11
const LINK := 0.5
const FATIGUE_RATE := 0.006
const STRONG_FATIGUE := 0.02
const FINAL_AT := 0.7
const FINAL_MULT := 1.5
const CRACKS := 3
const CRACK_RESET := 0.3
const RELEASE_CHARGE := 0.25
const PINK_AT := Vector2(-28, 8)
const BLUE_AT := Vector2(28, 8)
const TOTEM_AT := Vector2(0, -26)

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var meter := ResonanceMeter.new()
var blue_laugh := 0.0
var pink_mode := 0
var blue_mode := 0
var cracks := 0
var failed := false
var final_surge := false
var target := "pink"
var link_flash := 0.0
var crack_flash := 0.0
var last_state := "low"
var _info: Label
var _gauge: ResonanceGauge
var _rig: RuneRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_text = parsed if parsed is Dictionary else {}
	return _text


static func saved_runes() -> int:
	return clampi(int(GameState.vars.get(SAVE_KEY, 0)), 0, LIMITS[-1])


static func saved_cracks() -> int:
	return int(GameState.vars.get(CRACK_KEY, 0))


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return LIMITS


func save_progress() -> void:
	GameState.vars[SAVE_KEY] = completed
	GameState.vars[CRACK_KEY] = 0
	cracks = 0


func panel_title() -> String:
	return str(data().get("name", ""))


func quit() -> void:
	pass   # 弥补任务：不能中途退出


func stage_cast() -> Dictionary:
	return {}


## 两位公主都用公主的精灵图：粉色公主 id princess（玩家的闷笑、立绘特效对着她），蓝色公主 id blue
func _build_cast(cast: Dictionary) -> void:
	super(cast)
	for spec in [["princess", "pink", PINK_AT, "down"], ["blue", "blue", BLUE_AT, "down"]]:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose("normal", "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = saved_runes()
	cracks = saved_cracks()
	phase = phase_of(completed)
	tickler = ""
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 22)
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_gauge = ResonanceGauge.new()
	_gauge.stage = self
	_gauge.position = Vector2(0, 24)
	_gauge.size = Vector2(panel_body.size.x, panel_body.size.y - 24)
	panel_body.add_child(_gauge)
	_enter_game()
	_rig = RuneRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func pink_ratio() -> float:
	return player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0


## 道具挠的是谁（pink / blue）
func tool_who(tool: String) -> String:
	return str(data().get("tool_who", {}).get(tool, "pink"))


func set_mode(who: String, mode: int) -> void:
	if who == "pink":
		pink_mode = 0 if pink_mode == mode else mode
	else:
		blue_mode = 0 if blue_mode == mode else mode
	_refresh()


func _begin_segment() -> void:
	if not _alive():
		return
	meter.reset()
	meter.rate = 1.0 / float(HOLD[phase])
	pink_mode = 0
	blue_mode = 0
	final_surge = false
	target = tool_who(active_tool)
	busy = false
	_refresh()


func _reset_segment() -> void:
	meter.reset()
	final_surge = false


func _stop_input() -> void:
	pink_mode = 0
	blue_mode = 0


func _on_phase_changed() -> void:
	rotate_tool()
	target = tool_who(active_tool)


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	match k:
		"A":
			set_mode("pink", -1)
		"D":
			set_mode("pink", 1)
		"J":
			set_mode("blue", -1)
		"K":
			set_mode("blue", 1)


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	_update_bars()
	simulate(delta * time_scale)


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	link_flash = maxf(0.0, link_flash - dt)
	crack_flash = maxf(0.0, crack_flash - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		_refresh()
		return
	var event := interference.advance(dt)
	elapsed = interference.elapsed
	sensitive_left = maxf(0.0, sensitive_left - float(event["dt"]))
	var mult := float(PHASE_RATE[phase]) * (FINAL_MULT if final_surge else 1.0)
	_shift_pink(float(PINK_RATES[pink_mode]) * dt, mult)
	var b := float(BLUE_RATES[blue_mode]) * dt
	blue_laugh = clampf(blue_laugh + (b * mult if b > 0.0 else b), 0.0, 1.0)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	if event["strong"]:
		rotate_tool()
		strike()
	if event["fx"]:
		_hit(target)
	if event["reaction"]:
		_react(target)
	if _punish_request != "":
		return
	var st := meter.step(dt, pink_ratio(), blue_laugh)
	if st != last_state and st in ["charging", "high"]:
		var pool: Array = data().get("state", {}).get(st, [])
		if not pool.is_empty():
			narrate(str(pool[rng.randi_range(0, pool.size() - 1)]), 1.6)
	last_state = st
	if st == "crack":
		crack()
	elif st == "full":
		advance_step()
	elif phase == LIMITS.size() - 1 and not final_surge and meter.charge >= FINAL_AT:
		final_surge = true
		var lines: Array = data().get("final", [])
		if not lines.is_empty():
			narrate(str(lines[rng.randi_range(0, lines.size() - 1)]), 3.0, true)
		flash(Color(1, 0.75, 0.9, 0.35), 0.3)
	_refresh()


## 粉色公主的闷笑：往上涨的部分算挠痒（敏感时加倍），往下的是绷紧脚趾自己压下去的
func _shift_pink(amount: float, mult: float) -> void:
	if not is_instance_valid(player) or player.laugh == null:
		return
	if amount > 0.0:
		work_laugh(laugh_max() * amount * mult)
	else:
		player.laugh.set_value(maxf(0.0, player.laugh.value + laugh_max() * amount))


## 一次加强：挠道具对着的那个人，痒感顺着连线传一半给另一个人
func strike() -> void:
	target = tool_who(active_tool)
	var amount := STRONG * float(PHASE_RATE[phase])
	if target == "pink":
		_shift_pink(amount, 1.0)
		blue_laugh = minf(1.0, blue_laugh + amount * LINK)
	else:
		blue_laugh = minf(1.0, blue_laugh + amount)
		_shift_pink(amount * LINK, 1.0)
	add_fatigue(fatigue_max() * STRONG_FATIGUE)
	link_flash = 0.6
	var pool: Array = data().get("link", {}).get(target, [])
	if not pool.is_empty() and rng.randf() < 0.5:
		narrate(str(pool[rng.randi_range(0, pool.size() - 1)]), 2.4)
	_react(target)


func _hit(who: String) -> void:
	tickle("", tickle_zone, false, "princess" if who == "pink" else "blue", _tool_fx(active_tool))


## 挑一组这个道具的挠痒事件：描写进反应框，被挠的人按自己的闷笑分档冒反应（粉色释放后敏感时换 sensitive）
func _react(who: String) -> void:
	var events: Array = data().get("feedback", []).filter(func(e): return int(e["phase"]) == phase and str(e["tool"]) == active_tool)
	if events.is_empty():
		return
	if _event_phase != phase:
		_event_phase = phase
		_event_last = -1
	var index := rng.randi_range(0, events.size() - 1)
	if index == _event_last and events.size() > 1:
		index = (index + 1) % events.size()
	_event_last = index
	var e: Dictionary = events[index]
	var ratio := pink_ratio() if who == "pink" else blue_laugh
	var tier := "light" if ratio < 0.4 else ("mid" if ratio < 0.75 else "heavy")
	var replies: Array = e["react"][tier]
	if who == "pink" and sensitive_left > 0.0:
		replies = data().get("sensitive", {}).get(tier, replies)
	if not replies.is_empty():
		pop(actors.get("princess" if who == "pink" else "blue"), str(replies[rng.randi_range(0, replies.size() - 1)]), PINK if who == "pink" else Color(0.7, 0.85, 1.0), 1.8)
	narrate(str(e["caption"]), 3.2)
	tickle_zone = str(e.get("zone", tickle_zone))


## 有人笑过了头：符文裂开，这一道从头刻；同一道裂开 CRACKS 次 = 失败
func crack() -> void:
	cracks += 1
	GameState.vars[CRACK_KEY] = cracks
	_stop_input()
	meter.reset()
	final_surge = false
	crack_flash = 0.8
	if player.laugh:
		player.laugh.set_value(laugh_max() * CRACK_RESET)
	blue_laugh = CRACK_RESET
	flash(Color(1, 0.4, 0.55, 0.6), 0.4)
	Audio.play("laugh", -4.0)
	var c: Dictionary = data().get("crack", {})
	var desc: Array = c.get("desc", [])
	if not desc.is_empty():
		narrate(str(desc[rng.randi_range(0, desc.size() - 1)]), 2.6, true)
	_pop_random(c.get("pink", []), PINK, 1.6)
	var bl: Array = c.get("blue", [])
	if not bl.is_empty():
		pop(actors.get("blue"), str(bl[rng.randi_range(0, bl.size() - 1)]), Color(0.7, 0.85, 1.0), 1.6)
	if cracks >= CRACKS:
		fail()
		return
	recovery_left = RECOVER_TIME
	_refresh()


## 闷笑满（正常会先裂开；直接满了也按裂开算）
func recover() -> void:
	crack()


## 魔力释放：舒服的释放 + 共鸣爆发（符文一次充一截），蓝色公主说一句
func release() -> void:
	super()
	meter.burst(RELEASE_CHARGE)
	var lines: Array = data().get("release", {}).get("blue", [])
	if not lines.is_empty():
		say("blue", str(lines[rng.randi_range(0, lines.size() - 1)]))
	pop(actors.get("princess"), str(data().get("burst", "共鸣爆发！")), GOLD, 1.4)
	if meter.charge >= 1.0 and not busy:
		advance_step()


func fail() -> void:
	failed = true
	busy = true
	_stop_input()
	clear_feedback()
	await _lines(data().get("fail", []))
	_success = false
	_done = true
	playing = false


func _before_finish() -> void:
	for id in ["princess", "blue"]:
		var a: CGActor = actors.get(id)
		if a:
			a.set_pose("normal", "idle", "down")
	if _rig:
		_rig.queue_redraw()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	var modes: Array = data()["modes"]
	_info.text = str(data()["panel"]) % [phase_info()["name"], cracks, CRACKS]
	count_label.text = str(data()["count"]) % [completed, LIMITS[-1], roundi(meter.charge * 100)]
	hint_label.text = str(data()["hint"]) + "\n" + str(data()["mode_line"]) % [modes[pink_mode + 1], modes[blue_mode + 4]]
	if interference.warning():
		var who := tool_who(str(phase_info()["tools"][(interference.strong_count + 1) % phase_info()["tools"].size()]))
		narrate(str(data()["warning"][who]), 1.0)
	if _gauge:
		_gauge.queue_redraw()
	if _rig:
		_rig.queue_redraw()


## 左上面板：两根竖着的闷笑条（共鸣区、裂开线）和这道符文的充能
class ResonanceGauge extends Control:
	var stage: TotemResonanceShow

	func bar(x: float, ratio: float, col: Color, label: String) -> void:
		var h := size.y - 22
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(x, 0, 12, h), Color("2c2236"))
		var m := stage.meter
		draw_rect(Rect2(x, h * (1.0 - ratio), 12, h * ratio), col if m.in_zone(ratio) or ratio < m.lo else col.darkened(0.35))
		# 共鸣区画在闷笑上面：两条金线 + 两边的小刻度
		for r in [m.lo, m.hi]:
			draw_line(Vector2(x - 3, h * (1.0 - r)), Vector2(x + 15, h * (1.0 - r)), Color("ffd27a"), 1)
		draw_rect(Rect2(x - 3, h * (1.0 - m.hi), 2, h * (m.hi - m.lo)), Color("ffd27a"))
		draw_rect(Rect2(x + 13, h * (1.0 - m.hi), 2, h * (m.hi - m.lo)), Color("ffd27a"))
		draw_line(Vector2(x - 3, h * (1.0 - m.crack)), Vector2(x + 15, h * (1.0 - m.crack)), Color("ff6f8e"), 1)
		draw_string(font, Vector2(x - 2, h + 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)

	func _draw() -> void:
		bar(4, stage.pink_ratio(), Color("ff9cc6"), str(stage.data()["labels"][0]))
		bar(30, stage.blue_laugh, Color("8fc6ff"), str(stage.data()["labels"][1]))
		var font := ThemeDB.fallback_font
		var x := 58.0
		var h := size.y - 22
		draw_string(font, Vector2(x, 8), str(stage.data()["labels"][2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
		draw_rect(Rect2(x, 12, 36, h - 12), Color("2c2236"))
		var fill := (h - 12) * stage.meter.charge
		draw_rect(Rect2(x, 12 + h - 12 - fill, 36, fill), Color("ffd27a") if not stage.final_surge else Color("ff9fd0"))
		for i in LIMITS[-1]:
			ErrandWorkStage.draw_shape(self, Vector2(x + 6 + i * 12, h + 6), i, Color("ffd27a") if i < stage.completed else Color("5e4d63"))


## 图腾、两个符文圈、痒感连线，以及每种道具挠在哪里（画在演员后面 / 前面各一部分）
class RuneRig extends Node2D:
	var stage: TotemResonanceShow
	const GLOW := Color(1, 0.8, 0.45)
	const ZONE := Color(1, 0.85, 0.45)

	func circle_col(ratio: float) -> Color:
		if ratio >= stage.meter.crack:
			return Color("ff6f8e")
		if stage.meter.in_zone(ratio):
			return ZONE
		return Color(0.6, 0.5, 0.75) if ratio < stage.meter.lo else Color("ffa36f")

	func _draw() -> void:
		# 图腾柱和三张笑脸，笑脸随刻好的符文亮起来
		var t := TOTEM_AT
		draw_rect(Rect2(t + Vector2(-9, -20), Vector2(18, 44)), Color("7a5b46"))
		for i in 3:
			var c := t + Vector2(0, -12 + i * 13)
			var lit := i < stage.completed or (i == stage.completed and stage.meter.charge > 0.0)
			var col := GLOW if i < stage.completed else (Color(1, 0.8, 0.45, 0.25 + stage.meter.charge * 0.6) if lit else Color("4f3d3f"))
			draw_circle(c, 5, col)
			draw_arc(c + Vector2(0, 1), 3, 0.2, PI - 0.2, 6, Color("3a2a2a"), 1)
		var flare := 0.5 + 0.5 * sin(stage.elapsed * 6.0)
		draw_arc(t, 26, -PI / 2, -PI / 2 + TAU * stage.meter.charge, 32, Color(1, 0.8, 0.45, 0.5 + 0.3 * flare), 2)
		# 两个符文圈
		for spec in [[PINK_AT, stage.pink_ratio()], [BLUE_AT, stage.blue_laugh]]:
			var at: Vector2 = spec[0] + Vector2(0, 2)
			var col := circle_col(float(spec[1]))
			draw_arc(at, 14, 0, TAU, 24, col, 1.5)
			draw_arc(at, 10, 0, TAU, 20, Color(col, 0.5), 1)
			for i in 6:
				var a := stage.elapsed * 0.8 + i * TAU / 6.0
				draw_line(at + Vector2.from_angle(a) * 10, at + Vector2.from_angle(a) * 14, col, 1)
		# 痒感连线
		var link_col := Color(1, 0.6, 0.85, 0.35 + stage.link_flash)
		draw_line(PINK_AT + Vector2(0, -8), BLUE_AT + Vector2(0, -8), link_col, 1.0 + stage.link_flash * 3.0)
		if stage.crack_flash > 0.0:
			for i in 5:
				var a := i * TAU / 5.0
				draw_line(t, t + Vector2.from_angle(a) * (20 + stage.crack_flash * 20), Color("ff6f8e"), 1)
		if not stage.playing or stage.busy or stage.recovery_left > 0.0:
			return
		_draw_tool()

	func _draw_tool() -> void:
		var wob := sin(stage.elapsed * 14.0) * 2.0
		var feet := PINK_AT + Vector2(0, 0)
		var thigh := BLUE_AT + Vector2(0, -9)
		# 足印符文的光线缠着脚踝和脚趾
		for i in 3:
			draw_line(feet + Vector2(-5 + i * 5, -2), feet + Vector2(-4 + i * 5, 1), Color(1, 0.8, 0.45, 0.6), 1)
		match stage.active_tool:
			"feather":
				var tip := feet + Vector2(6 + wob, 2)
				draw_line(tip + Vector2(6, -6), tip, Color(1, 0.92, 0.7), 2)
				for i in 3:
					draw_line(tip + Vector2(2 + i * 1.5, -2 - i * 1.5), tip + Vector2(i * 1.5, -4 - i * 1.5), Color(1, 0.95, 0.85), 1)
			"finger":
				var path := (feet + Vector2(4, 0)).lerp(BLUE_AT + Vector2(0, -8), 0.5 + 0.5 * sin(stage.elapsed * 2.0))
				draw_circle(path, 2, Color("c8a6d8"))
				draw_circle(feet + Vector2(4 + wob * 0.5, 1), 1.5, Color("c8a6d8"))
			"tongue":
				var from := TOTEM_AT + Vector2(0, 14)
				var pts := PackedVector2Array()
				for i in 9:
					var r := float(i) / 8.0
					pts.append(from.lerp(feet + Vector2(3, 2), r) + Vector2(0, sin(stage.elapsed * 9.0 + r * 6.0) * 3.0 * (1.0 - r)))
				draw_polyline(pts, Color(1, 0.65, 0.8, 0.85), 2)
			"hand":
				for i in 2:
					var h := thigh + Vector2(-4 + i * 8, wob * 0.6)
					draw_circle(h, 2, Color("c8a6d8"))
					draw_line(h, h + Vector2(0, -3), Color("c8a6d8"), 1)
			"brush":
				var b := thigh + Vector2(-2, wob)
				draw_rect(Rect2(b - Vector2(1, 4), Vector2(3, 8)), Color(1, 0.8, 0.45, 0.8))
			"pinch":
				for side in [-1, 1]:
					var p: Vector2 = BLUE_AT + Vector2(side * 5, -6 + wob * 0.4)
					draw_circle(p, 2, Color("c8a6d8"))
