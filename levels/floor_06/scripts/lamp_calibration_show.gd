class_name LampCalibrationShow
extends ErrandWorkStage
## 派对主人的可选委托「脚踏灯轮校准」：她光脚踩两块调光踏板，校准庆功宴的灯轮。台词 data/after/errand_lamp_calibration.json。
##   三阶段各 PER_PHASE 项：单灯（A/D 左灯）→ 双灯（再加 W/S 右灯）→ 图案（再加 Q/E 换圆 / 菱 / 星）；亮斑在目标 ±TOLERANCE 内连稳 STABLE_TIME 秒算一项。
##   踏板刷：踏板滚轮上有细毛刷，踩得越深（灯值越大）刷得越用力——闷笑每秒额外 +PEDAL_RATE × 踩下的深度；踩得深时每 PEDAL_EVERY 秒演一段踏板描写。
##   派对主人的道具按阶段轮换（羽毛 / 彩带流苏 → 流苏 / 灯芯草 → 灯芯草 / 手指）；每次加强让一盏灯平滑地漂开 OFFSET_TIME 秒。
##   errand_lamp_calibration_step 逐项保存（Esc 暂存）；闷笑满 / 魔力释放见 ErrandWorkStage。
## 测试：quiet、fixed_seed、press()、simulate()、target_lamps、pedal_depth()。

const PATH := "res://data/after/errand_lamp_calibration.json"
const SAVE_KEY := "errand_lamp_calibration_step"
const TOTAL := 12
const PER_PHASE := 4
const LIMITS := [4, 8, 12]
const STABLE_TIME := 3.0
const TOLERANCE := 0.09
const TAP := 0.025
const MOVE_RATE := 0.35
const DRIFT := 0.035
const STRONG_DRIFT := 0.055
const OFFSET_TIME := 0.8
const BASE_RATE := 0.004
const STRONG_LAUGH := 0.03
const STRONG_FATIGUE := 0.01
const PEDAL_RATE := 0.006
const PEDAL_SAY_AT := 0.55
const PEDAL_EVERY := 5.0
const COLORS := [Color("f4bf69"), Color("86cbd7"), Color("dbaaed")]

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var progress := 0.0
var lamps := Vector2(0.5, 0.5)
var target_lamps := Vector2.ZERO
var mask_index := 0
var target_mask := 0
var offset_left := 0.0
var held_keys := {}
var _pedal_left := PEDAL_EVERY
var _info: Label
var _stage_info: Label
var _rig: LampRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_text = parsed if parsed is Dictionary else {}
	return _text


static func saved_step() -> int:
	return clampi(int(GameState.vars.get(SAVE_KEY, 0)), 0, TOTAL)


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return LIMITS


func save_progress() -> void:
	GameState.vars[SAVE_KEY] = completed


func panel_title() -> String:
	return str(data()["name"])


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [48, 12], "visual": "normal", "anim": "idle", "dir": "left"},
		"worker": {"kind": "npc:bonfire_host", "at": [72, 2], "dir": "left"}}


## 两块踏板一共踩下去多深（单灯阶段只算左边）
func pedal_depth() -> float:
	return lamps.x + (lamps.y if phase >= 1 else 0.0)


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = saved_step()
	phase = phase_of(completed)
	tickler = "worker"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_enter_game()
	_stage_info = _label(TEXT, 8)
	_stage_info.position = Vector2(8, 8)
	_stage_info.size = Vector2(300, 46)
	overlay.add_child(_stage_info)
	_rig = LampRig.new()
	_rig.stage = self
	_rig.position.y = -12
	view.add_child(_rig)
	view.move_child(_rig, 1)
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	progress = 0.0
	held_keys.clear()
	target_lamps = Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
	target_mask = completed % 3
	busy = false
	_refresh()


func _reset_segment() -> void:
	progress = 0.0


func _stop_input() -> void:
	held_keys.clear()


func _on_phase_changed() -> void:
	rotate_tool()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and playing:
		var key: String = KEY_NAMES.get(event.keycode, "")
		if key in ["A", "D", "W", "S"]:
			if event.pressed and not busy and not _suspended() and recovery_left <= 0.0:
				held_keys[key] = true
			else:
				held_keys.erase(key)
			get_viewport().set_input_as_handled()
			return
	super(event)


func _on_key(key: String) -> void:
	if recovery_left > 0.0:
		return
	match key:
		"A":
			lamps.x = clampf(lamps.x - TAP, 0.0, 1.0)
		"D":
			lamps.x = clampf(lamps.x + TAP, 0.0, 1.0)
		"W":
			lamps.y = clampf(lamps.y - TAP, 0.0, 1.0)
		"S":
			lamps.y = clampf(lamps.y + TAP, 0.0, 1.0)
		"Q":
			mask_index = posmod(mask_index - 1, 3)
		"E":
			mask_index = (mask_index + 1) % 3
	_refresh()


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done:
		return
	if _suspended():
		held_keys.clear()
		return
	simulate(delta * time_scale)
	_update_bars()


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	offset_left = maxf(0.0, offset_left - dt)
	work_laugh(laugh_max() * (BASE_RATE + PEDAL_RATE * pedal_depth()) * dt)
	add_fatigue(fatigue_max() * BASE_RATE * dt)
	_pedal(dt)
	if event["strong"]:
		work_laugh(laugh_max() * STRONG_LAUGH)
		add_fatigue(fatigue_max() * STRONG_FATIGUE)
		offset_left = OFFSET_TIME
	if event["reaction"]:
		work_reaction(data(), phase, active_tool, tickler)
	if _punish_request != "":
		return
	_lamp_tick(dt)
	_refresh()


## 踩得深时，踏板的毛刷隔一会儿演一段
func _pedal(dt: float) -> void:
	if pedal_depth() < PEDAL_SAY_AT * (2.0 if phase >= 1 else 1.0):
		return
	_pedal_left -= dt
	if _pedal_left > 0.0:
		return
	_pedal_left = PEDAL_EVERY
	var events: Array = data().get("pedal", []).filter(func(e): return int(e["phase"]) == phase)
	_play_event(events, "")
	tickle("", "sole")


func _lamp_tick(dt: float) -> void:
	var dir := Vector2(float(held_keys.has("D")) - float(held_keys.has("A")), float(held_keys.has("S")) - float(held_keys.has("W")))
	lamps += dir * MOVE_RATE * dt
	var side := 0 if phase == 0 else (1 if phase == 1 else interference.strong_count % 2)
	# 持续轻漂与预告后的平滑偏移；没有瞬移踏板或禁用操作。
	lamps[side] += sin(elapsed * 2.1) * DRIFT * dt
	if offset_left > 0.0:
		lamps[side] += STRONG_DRIFT * sin(PI * offset_left / OFFSET_TIME) * dt / OFFSET_TIME
	lamps = lamps.clamp(Vector2.ZERO, Vector2.ONE)
	var safe := absf(lamps.x - target_lamps.x) <= TOLERANCE
	if phase >= 1:
		safe = safe and absf(lamps.y - target_lamps.y) <= TOLERANCE
	if phase >= 2:
		safe = safe and mask_index == target_mask
	progress = progress + dt if safe else 0.0
	if progress >= STABLE_TIME:
		advance_step()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	var labels: Array = data()["labels"]
	_info.text = str(data()["panel"]) % [phase_info()["name"], mini(completed - phase_start(), PER_PHASE), completed]
	if phase == 2:
		_info.text += "\n%s：%s\n%s：%s" % [labels[2], labels[5 + target_mask], labels[3], labels[5 + mask_index]]
	count_label.text = str(data()["count"]) % [completed, TOTAL]
	_stage_info.text = str(labels[0]) + ("    " + str(labels[1]) if phase > 0 else "") + "\n" + str(labels[4]) % progress
	if interference.warning():
		_stage_info.text += "\n" + str(data()["warning"])
	if _rig:
		_rig.queue_redraw()


## 两盏灯的刻度、图案卡、她脚下的两块踏板（滚轮毛刷随踩下的深度转）和派对主人手里的道具
class LampRig extends Node2D:
	var stage: LampCalibrationShow

	func _draw() -> void:
		for i in (1 if stage.phase == 0 else 2):
			var y := -12.0 + i * 22
			draw_rect(Rect2(-58, y - 5, 101, 10), Color("382b45"))
			draw_rect(Rect2(-58 + (stage.target_lamps[i] - TOLERANCE) * 100, y - 5, TOLERANCE * 200, 10), Color("547f6e"))
			draw_rect(Rect2(-58 + stage.lamps[i] * 100 - 2, y - 7, 4, 14), COLORS[i])
			draw_circle(Vector2(-65, y), 5, COLORS[i])
			draw_line(Vector2(-65, y + 5), Vector2(-65, 33), Color("ac865e"), 2)
		if stage.phase == 2:
			ErrandWorkStage.draw_shape(self, Vector2(-43, 31), stage.target_mask, Color("e1ba7c"))
			ErrandWorkStage.draw_shape(self, Vector2(-15, 31), stage.mask_index, Color("c5e8db"))
		for i in TOTAL:
			draw_rect(Rect2(-55 + i * 9, 43, 6, 3), Color("a2dabc") if i < stage.completed else Color("584252"))
		# 踏板：越踩越低、滚轮转得越快
		var feet: Vector2 = (stage.actors["princess"] as Node2D).position - position
		for i in 2:
			var depth: float = stage.lamps[i] if (i == 0 or stage.phase >= 1) else 0.0
			var at: Vector2 = feet + Vector2(-7 + i * 9, 2 + depth * 3)
			draw_rect(Rect2(at - Vector2(4, 1), Vector2(8, 3)), Color("c29570"))
			draw_circle(at + Vector2(0, 3), 2, Color("6d5747"))
			for j in 4:
				var a := stage.elapsed * (2.0 + depth * 14.0) + j * PI / 2.0
				draw_line(at + Vector2(0, 3), at + Vector2(0, 3) + Vector2.from_angle(a) * 3.0, Color("f0dcb5"), 1)
		if stage.playing and not stage.busy and stage.recovery_left <= 0.0:
			var tip: Vector2 = feet + Vector2(-3 + sin(stage.elapsed * 14) * 2, 1)
			draw_line(stage.actors["worker"].position - position + Vector2(-5, -8), tip, Color("c49c73"), 2)
			match stage.active_tool:
				"feather":
					draw_line(tip - Vector2(3, 3), tip + Vector2(3, 3), Color("f6ddbd"), 3)
				"tassel":
					for j in 3:
						draw_line(tip, tip + Vector2(-2 + j * 2, 4), Color("f28aa5"), 1)
				"rush":
					draw_line(tip, tip + Vector2(-5, 1), Color("b4cf7a"), 1)
				_:
					draw_circle(tip, 2, Color("f1c4b5"))
