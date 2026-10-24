class_name ShearingShow
extends ErrandWorkStage
## 女仆的可选委托「蘑菇羊剪毛」：她光脚坐在垫子边给咕咕梳 3 结 / 剪 4 区 / 收 3 堆，脚底抹了盐，咕咕一边被剪一边舔她的脚。
## 台词 data/after/errand_shearing.json。
##   操作：←→ / A D 转工具（TURN_STEP），按住 J 沿目标箭头工作，每段累计 SEGMENT_TIME 秒、容差 TOLERANCE；偏了就抬起工具（不扣进度）。
##   盐量 salt（0~1）：每 lick_interval() 秒咕咕舔一下（盐越多越勤），闷笑 +LICK_LAUGH ×(0.5 + 盐)，每舔一下盐 −SALT_PER_LICK；
##     盐越多咕咕越乖：抖毛间隔 sheep_interval()、预告 sheep_warning() 都变长。K 擦掉 SALT_WIPE（冷却 WIPE_CD）；
##     每个阶段开始女仆再抹 SALT_PER_PHASE。第三阶段小羊羔挤过来，和咕咕轮流舔另一只脚。
##   抖毛：目标方向偏开 SHEEP_TURN，装袋阶段散掉当前堆 SCATTER_TIME 秒的进度。女仆的道具（掸子 / 抹盐的手指）由 WorkInterference 轮换。
##   errand_shearing_step 保存完成了几段（0~10）；闷笑满 / 魔力释放见 ErrandWorkStage。
## 测试：quiet、fixed_seed、hold_tool()、press()、simulate()、lick_now()、wipe()。

const PATH := "res://data/after/errand_shearing.json"
const SAVE_STEP := "errand_shearing_step"
const TOTAL := 10
const LIMITS := [3, 7, 10]
const SEGMENT_TIME := 6.0
const TOLERANCE := PI / 9.0
const TURN_STEP := PI / 18.0
const SHEEP_INTERVAL := 9.0
const SHEEP_WARNING := 0.8
const SALT_CALM := 5.0
const SALT_WARN := 0.6
const SALT_START := 0.6
const SALT_PER_PHASE := 0.5
const SALT_WIPE := 0.25
const SALT_PER_LICK := 0.03
const WIPE_CD := 2.0
const LICK_EVERY := 2.0
const LICK_LAUGH := 0.035
const LICK_FATIGUE := 0.006
const BASE_LAUGH_RATE := 0.004
const BASE_FATIGUE_RATE := 0.004
const STRONG_TURN := 0.14
const STRONG_LAUGH := 0.03
const STRONG_FATIGUE := 0.01
const SHEEP_TURN := 0.42
const SCATTER_TIME := 0.75
const TARGET_SWAY := 0.12
const BAG := Vector2(64, 12)
const PILES := [Vector2(4, 22), Vector2(22, 24), Vector2(40, 14)]
const TARGETS := [0.1, -0.8, 0.6, -0.3, 0.9, -0.7, 0.2]
const FEET := Vector2(-12, 17)

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var progress := 0.0
var angle := 0.0
var target_angle := 0.0
var holding_tool := false
var feedback := ""
var shake_count := 0
var salt := SALT_START
var licks := 0
var lick_flash := 0.0
var lick_by := "sheep"
var _sheep_left := 0.0
var _lick_left := 0.0
var _wipe_cd := 0.0
var _target_offset := 0.0
var _shake_flash := 0.0
var _was_off_angle := false
var _info: Label
var _rig: WoolRig


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_text = parsed if parsed is Dictionary else {}
	return _text


static func saved_step() -> int:
	return clampi(int(GameState.vars.get(SAVE_STEP, 0)), 0, TOTAL)


func work_text() -> Dictionary:
	return text()


func phase_limits() -> Array:
	return LIMITS


func save_progress() -> void:
	GameState.vars[SAVE_STEP] = completed


func panel_title() -> String:
	return str(text()["name"])


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [-20, 18], "visual": "normal", "anim": "idle", "dir": "right"},
		"maid": {"kind": "npc:maid", "at": [-55, -10], "dir": "right"},
		"sheep": {"kind": "npc:goat", "at": [28, 0], "dir": "left"},
		"lamb": {"kind": "npc:goat", "at": [4, 31], "dir": "left"}}


## 盐越多，咕咕越乖（抖毛隔得越久、预告越早），也舔得越勤
func sheep_interval() -> float:
	return SHEEP_INTERVAL + salt * SALT_CALM


func sheep_warning() -> float:
	return SHEEP_WARNING + salt * SALT_WARN


func lick_interval() -> float:
	return LICK_EVERY / (0.4 + salt)


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = saved_step()
	phase = phase_of(completed)
	tickler = "maid"
	_build_ui()
	hint_label.text = str(text()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	(actors["sheep"] as CGActor).scale = Vector2(1.6, 1.6)
	(actors["lamb"] as CGActor).visible = phase >= 2
	var fence := WoolFence.new()
	fence.z_index = 1
	view.add_child(fence)
	_rig = WoolRig.new()
	_rig.stage = self
	_rig.z_index = 3
	view.add_child(_rig)
	_sheep_left = sheep_interval()
	_lick_left = lick_interval()
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	progress = 0.0
	holding_tool = false
	feedback = str(text()["ready"])
	_update_target()
	busy = false
	_refresh()


func _reset_segment() -> void:
	progress = 0.0


func _stop_input() -> void:
	holding_tool = false


## 每个阶段开始女仆再抹一次盐；装袋阶段小羊羔挤过来
func _on_phase_changed() -> void:
	salt = minf(1.0, salt + SALT_PER_PHASE)
	rotate_tool()
	if phase >= 2:
		(actors["lamb"] as CGActor).visible = true
		narrate(str(text().get("lamb_come", "")), 2.4, true)


func _update_target() -> void:
	var base: float = (BAG - PILES[mini(completed - 7, 2)]).angle() if phase == 2 else float(TARGETS[mini(completed, 6)])
	target_angle = wrapf(base + sin(elapsed * 0.65) * TARGET_SWAY + _target_offset, -PI, PI)


func angle_error() -> float:
	return absf(angle_difference(angle, target_angle))


func hold_tool(on: bool) -> void:
	holding_tool = on and playing and not busy and recovery_left <= 0.0 and not _suspended()
	if not holding_tool:
		_was_off_angle = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_J:
		if not event.pressed:
			holding_tool = false
		elif not event.echo:
			hold_tool(true)
		if playing:
			get_viewport().set_input_as_handled()
		return
	super(event)


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	match k:
		"LEFT", "A":
			angle = wrapf(angle - TURN_STEP, -PI, PI)
		"RIGHT", "D":
			angle = wrapf(angle + TURN_STEP, -PI, PI)
		"J":
			hold_tool(true)
		"K":
			wipe()
	_refresh()


## K：擦掉脚底的一些盐（咕咕舔得少了，但也更容易抖毛）
func wipe() -> bool:
	if _wipe_cd > 0.0 or salt <= 0.0:
		return false
	salt = maxf(0.0, salt - SALT_WIPE)
	_wipe_cd = WIPE_CD
	var w: Array = text().get("wipe", [])
	if not w.is_empty():
		narrate(str(w[rng.randi_range(0, w.size() - 1)]), 2.0, true)
	_pop_random(text().get("wipe_react", []), PINK, 1.4)
	return true


## 咕咕（第三阶段和小羊羔轮流）舔一下脚
func lick_now() -> void:
	licks += 1
	lick_by = "lamb" if phase >= 2 and licks % 2 == 0 else "sheep"
	lick_flash = 0.5
	var events: Array = text().get("licks", []).filter(func(e): return int(e["phase"]) == phase and str(e["tool"]) == lick_by)
	_play_event(events, lick_by)
	tickle(lick_by, "sole")
	work_laugh(laugh_max() * LICK_LAUGH * (0.5 + salt))
	add_fatigue(fatigue_max() * LICK_FATIGUE)
	salt = maxf(0.0, salt - SALT_PER_LICK)
	_lick_left = lick_interval()
	_refresh()


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done:
		return
	if _suspended():
		holding_tool = false
		return
	simulate(delta * time_scale)
	_update_bars()


## 与真实 _process 共用，不能越过暂停、对白或来源检查。
func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	_wipe_cd = maxf(0.0, _wipe_cd - dt)
	lick_flash = maxf(0.0, lick_flash - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		_refresh()
		return
	var event := work_clock(dt)
	_sheep_left -= dt
	_shake_flash = maxf(0.0, _shake_flash - dt)
	if _sheep_left <= 0.00001:
		_shake()
	_lick_left -= dt
	if _lick_left <= 0.00001:
		lick_now()
	_update_target()
	work_laugh(laugh_max() * BASE_LAUGH_RATE * dt)
	add_fatigue(fatigue_max() * BASE_FATIGUE_RATE * dt)
	if event["strong"]:
		angle = wrapf(angle + (STRONG_TURN if interference.strong_count % 2 else -STRONG_TURN), -PI, PI)
		work_laugh(laugh_max() * STRONG_LAUGH)
		add_fatigue(fatigue_max() * STRONG_FATIGUE)
	if event["reaction"] and _shake_flash <= 0.0:
		work_reaction(text(), phase, active_tool, tickler)
	feedback = str(text()["ready"])
	if holding_tool and _punish_request == "":
		if angle_error() <= TOLERANCE:
			_was_off_angle = false
			feedback = str(text()["working"])
			progress += dt
			if progress >= SEGMENT_TIME - 0.00001:
				advance_step()
		else:
			feedback = str(text()["off_angle"])
			if not _was_off_angle:
				work_reaction(text(), phase, active_tool, tickler, "error_react")
			_was_off_angle = true
	_refresh()


func _shake() -> void:
	_sheep_left = sheep_interval()
	shake_count += 1
	_target_offset = -SHEEP_TURN if shake_count % 2 else SHEEP_TURN
	_shake_flash = 0.8
	if phase == 2:
		progress = maxf(0.0, progress - SCATTER_TIME)
	var s: Array = text()["shake"]
	narrate(str(s[rng.randi_range(0, s.size() - 1)]), 2.5, true)
	work_reaction(text(), phase, active_tool, tickler, "sheep_react")
	(actors["sheep"] as CGActor).shake(0.6)


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(text()["panel"]) % [phase_info()["name"], completed - phase_start(), phase_info()["steps"], completed,
		roundi(rad_to_deg(angle_error())), roundi(salt * 100.0)]
	count_label.text = str(text()["short_count"]) % completed
	if _sheep_left <= sheep_warning():
		narrate(str(text()["warning"]), 1.0)
	if _rig:
		_rig.queue_redraw()


class WoolFence extends Node2D:
	func _draw() -> void:
		for x in range(-75, 80, 15):
			draw_rect(Rect2(x, -38, 4, 23), Color("ad8558"))
		draw_rect(Rect2(-77, -33, 158, 4), Color("8c644a"))


## 羊圈、垫子、羊毛、袋子、方向箭头、她的光脚和舔脚的舌头（复用蘑菇羊的像素演员，其余现场画）
class WoolRig extends Node2D:
	var stage: ShearingShow
	const SKIN := Color("f6d3c4")
	const SKIN_DARK := Color("e7ae9f")
	const TONGUE := Color("e8788f")

	func arrow(at: Vector2, angle_value: float, length: float, color: Color) -> void:
		var direction := Vector2.from_angle(angle_value)
		var tip := at + direction * length
		draw_line(at, tip, color, 2)
		draw_line(tip, tip - direction.rotated(0.6) * 6, color, 2)
		draw_line(tip, tip - direction.rotated(-0.6) * 6, color, 2)

	func draw_sole(at: Vector2) -> void:
		draw_circle(at, 2.2, SKIN)
		draw_rect(Rect2(at + Vector2(0, -2.5), Vector2(4, 5)), SKIN)
		draw_circle(at + Vector2(4.5, 0), 2.8, SKIN)
		for i in 5:
			draw_circle(at + Vector2(7.5, -2.4 + i * 1.2), 0.8, SKIN_DARK)
		# 脚底的盐粒
		for i in int(stage.salt * 6.0):
			draw_rect(Rect2(at + Vector2(1 + (i % 3) * 2, -1.5 + (i / 3) * 2), Vector2(1, 1)), Color(1, 1, 1, 0.9))

	func _draw() -> void:
		draw_rect(Rect2(-12, 2, 63, 22), Color("7b7363"))
		draw_rect(Rect2(-9, 5, 57, 16), Color("a59b7a"), false)
		draw_rect(Rect2(BAG - Vector2(9, 0), Vector2(18, 12)), Color("af875b"))
		draw_rect(Rect2(BAG - Vector2(7, 2), Vector2(14, 4)), Color("443947"))
		for i in 4:
			var wool_at := Vector2(16 + (i % 2) * 12, -15 + (i / 2) * 9)
			var cut := stage.completed >= 3 + i + 1
			draw_circle(wool_at, 5 if cut else 8, Color("c2bcaa") if cut else Color("fff0cf"))
			if stage.phase == 1 and i == stage.completed - 3:
				draw_arc(wool_at, 10, 0, TAU, 12, Color("ffe181"), 1)
		for i in 3:
			var pile: Vector2 = PILES[i]
			if stage.completed < 8 + i:
				for j in 4:
					draw_circle(pile + Vector2(j * 3 - 4, sin(float(j)) * 3), 3, Color("e9e1cf"))
			else:
				draw_rect(Rect2(53 + i * 7, 15, 6, 8), Color("d5b07d"))
		if stage.phase == 0:
			for i in range(stage.completed, 3):
				draw_arc(Vector2(12 + i * 13, -17), 4, 0.2, TAU * 1.7, 12, Color("9c7894"), 1)
		# 她伸出去的两只光脚
		var feet := [FEET + Vector2(0, -2), FEET + Vector2(1, 3)]
		for f in feet:
			draw_sole(f)
		# 舔脚：咕咕从上面、小羊羔从下面伸舌头
		if stage.lick_flash > 0.0:
			var foot: Vector2 = feet[0] if stage.lick_by == "sheep" else feet[1]
			var mouth := Vector2(15, -2) if stage.lick_by == "sheep" else Vector2(-3, 26)
			var tip := foot + Vector2(4 + sin(stage.lick_flash * 30.0) * 2.0, 0)
			draw_line(mouth, tip, TONGUE, 3)
			draw_circle(tip, 1.8, TONGUE)
			for i in 3:
				draw_circle(tip + Vector2(-2 + i * 2, -3 + (i % 2) * 6), 0.7, Color(0.85, 0.95, 1, 0.9))
		var origin := Vector2(24, -48)
		arrow(origin, stage.target_angle, 22, Color("8ee4ac"))
		arrow(origin, stage.angle, 18, Color("ffe181"))
		var safe := stage.angle_error() <= TOLERANCE
		var tool_at: Vector2 = PILES[mini(stage.completed - 7, 2)] if stage.phase == 2 else Vector2(20, -12)
		tool_at += Vector2(0, -3) if not stage.holding_tool or not safe else Vector2(sin(stage.elapsed * 15) * 3, 0)
		var tool_tip := tool_at + Vector2.from_angle(stage.angle) * 13
		draw_line(tool_at, tool_tip, Color("d9ac72"), 3)
		if stage.phase == 1:
			draw_line(tool_tip, tool_tip + Vector2(6, -4), Color("e4e8ec"), 2)
			draw_line(tool_tip, tool_tip + Vector2(6, 4), Color("e4e8ec"), 2)
		else:
			draw_rect(Rect2(tool_tip - Vector2(3, 2), Vector2(7, 5)), Color("e3c59b"))
		# 女仆的掸子 / 抹盐的手指在她脚边
		if stage.playing and not stage.busy and stage.recovery_left <= 0.0:
			var p: Vector2 = feet[int(stage.elapsed * 0.5) % 2] + Vector2(2 + sin(stage.elapsed * 14) * 2, -3)
			draw_line(Vector2(-48, -15), p, Color("c29c6c"), 2)
			if stage.active_tool == "duster":
				draw_circle(p, 3, Color("ebe0c9"))
			else:
				draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 3)), Color("edb5a6"))
			# 固定数量的绒毛轨迹，不逐帧创建节点。
			for i in 10:
				var t := fmod(stage.elapsed * 0.5 + float(i) * 0.13, 1.0)
				var p2 := Vector2(12 + i * 4, -15) + Vector2(t * 12, -t * (24 if stage._shake_flash > 0 else 10))
				draw_line(p2, p2 + Vector2(2, 1), Color("e5d6c4"), 1)
		if stage._sheep_left <= stage.sheep_warning() or stage.interference.warning():
			draw_circle(Vector2(50, -42), 4, Color("f6b071"))
		draw_rect(Rect2(-62, 27, 110, 3), Color("393443"))
		draw_rect(Rect2(-62, 27, 110 * minf(1, stage.progress / SEGMENT_TIME), 3), Color("8ee4ac"))
		# 盐量条
		draw_rect(Rect2(-62, 31, 40, 2), Color("393443"))
		draw_rect(Rect2(-62, 31, 40 * stage.salt, 2), Color(1, 1, 1, 0.85))
