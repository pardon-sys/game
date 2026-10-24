class_name CanopyShow
extends ErrandWorkStage
## 商贩的可选委托「棚布补漏」：挂 3 角 / 描 4 道缝 / 张紧 3 次。台词 data/after/errand_canopy.json。
##   挂角：方向键把工具移到挂点 TOLERANCE 以内，按住 J 累计 HANG_TIME 秒。
##   补缝：按住 J 跟着引导点（STITCH_SPEED）沿缝线走，偏离 TOLERANCE 停止推进，松 J 收针。
##   张紧：A / D 调张力（TENSION_STEP），保持 SAFE_LOW~SAFE_HIGH 按住 J 累计 TENSION_TIME 秒。
##   errand_canopy_step 保存完成了几段（0~10），当前段的部分计时不入档；闷笑满 / 魔力释放见 ErrandWorkStage。
## 测试：quiet、fixed_seed、press()、hold_tool()、simulate()、guide()。

const PATH := "res://data/after/errand_canopy.json"
const SAVE_STEP := "errand_canopy_step"
const TOTAL := 10
const MOVE_SPEED := 42.0
const TAP_MOVE := 4.0
const TOLERANCE := 6.0
const HANG_TIME := 1.0
const STITCH_SPEED := 22.0
const TENSION_TIME := 3.0
const TENSION_STEP := 0.06
const SAFE_LOW := 0.35
const SAFE_HIGH := 0.65
const BASE_RATE := 0.004
const STRONG_LAUGH := 0.03
const STRONG_FATIGUE := 0.01
const HOOKS := [Vector2(-48, -32), Vector2(0, -40), Vector2(48, -32)]
const AREA_MIN := Vector2(-58, -48)
const AREA_MAX := Vector2(58, 8)

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var progress := 0.0
var cursor := Vector2.ZERO
var tension := 0.5
var holding_tool := false
var feedback := ""
var held_keys := {}
var _info: Label
var _rig: CanopyRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_text = parsed if parsed is Dictionary else {}
	return _text


static func saved_step() -> int:
	return clampi(int(GameState.vars.get(SAVE_STEP, 0)), 0, TOTAL)


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return data()["limits"]


func save_progress() -> void:
	GameState.vars[SAVE_STEP] = completed


func panel_title() -> String:
	return str(data()["name"])


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [-40, 23], "visual": "normal", "anim": "idle", "dir": "right"},
		"worker": {"kind": "npc:" + str(data()["actor"]), "at": [-62, 12], "dir": "right"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = saved_step()
	phase = phase_of(completed)
	tickler = "worker"
	tickle_zone = "waist"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	_rig = CanopyRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	active_tool = "brush"
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	progress = 0.0
	holding_tool = false
	held_keys.clear()
	tension = 0.5
	cursor = HOOKS[mini(completed, 2)] + Vector2(0, 12) if phase == 0 else seam()[0]
	feedback = str(data()["steady"])
	busy = false
	_refresh()


func _reset_segment() -> void:
	progress = 0.0


func _stop_input() -> void:
	holding_tool = false
	held_keys.clear()


## 这一道破口的缝线（单数道上下翻过来）
func seam() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(-48, -26), Vector2(-20, -8), Vector2(10, -28), Vector2(45, -10)])
	if completed % 2:
		for i in points.size():
			points[i].y = -38.0 - points[i].y
	return points


func seam_length() -> float:
	var points := seam()
	var length := 0.0
	for i in points.size() - 1:
		length += points[i].distance_to(points[i + 1])
	return length


## 挂角时是挂点；补缝时是沿缝线走到的引导点
func guide() -> Vector2:
	if phase == 0:
		return HOOKS[mini(completed, 2)]
	var points := seam()
	var distance := progress * STITCH_SPEED
	for i in points.size() - 1:
		var length := points[i].distance_to(points[i + 1])
		if distance <= length:
			return points[i].lerp(points[i + 1], distance / length)
		distance -= length
	return points[-1]


func hold_tool(on: bool) -> void:
	holding_tool = on and playing and not busy and not _suspended() and recovery_left <= 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and playing:
		var key: String = KEY_NAMES.get(event.keycode, "")
		if key == "J":
			if not event.echo:
				hold_tool(event.pressed)
			get_viewport().set_input_as_handled()
			return
		if key in ["A", "D", "W", "S", "LEFT", "RIGHT", "UP", "DOWN"] and phase < 2:
			if event.pressed and not busy and not _suspended():
				held_keys[key] = true
			else:
				held_keys.erase(key)
			get_viewport().set_input_as_handled()
			return
	super(event)


func _on_key(key: String) -> void:
	if recovery_left > 0.0:
		return
	if key == "J":
		hold_tool(true)
		return
	var direction := Vector2.ZERO
	match key:
		"A", "LEFT":
			direction = Vector2.LEFT
		"D", "RIGHT":
			direction = Vector2.RIGHT
		"W", "UP":
			direction = Vector2.UP
		"S", "DOWN":
			direction = Vector2.DOWN
	if phase == 2:
		tension = clampf(tension + direction.x * TENSION_STEP, 0.0, 1.0)
	else:
		cursor = (cursor + direction * TAP_MOVE).clamp(AREA_MIN, AREA_MAX)
	_refresh()


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done:
		return
	if _suspended():
		holding_tool = false
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
	work_laugh(laugh_max() * BASE_RATE * dt)
	add_fatigue(fatigue_max() * BASE_RATE * dt)
	if event["strong"]:
		cursor += Vector2(3 if interference.strong_count % 2 else -3, 2)
		tension = clampf(tension + 0.1, 0.0, 1.0)
		work_laugh(laugh_max() * STRONG_LAUGH)
		add_fatigue(fatigue_max() * STRONG_FATIGUE)
	if event["reaction"]:
		work_reaction(data(), phase, active_tool, tickler)
	if _punish_request != "":
		return
	_work(dt)
	_refresh()


func _work(dt: float) -> void:
	var direction := Vector2.ZERO
	for key in held_keys:
		if key in ["A", "LEFT"]:
			direction.x -= 1
		if key in ["D", "RIGHT"]:
			direction.x += 1
		if key in ["W", "UP"]:
			direction.y -= 1
		if key in ["S", "DOWN"]:
			direction.y += 1
	cursor = (cursor + direction.normalized() * MOVE_SPEED * dt).clamp(AREA_MIN, AREA_MAX)
	if phase == 2:
		tension = clampf(tension + sin(elapsed * 2.1) * 0.05 * dt, 0.0, 1.0)
	if not holding_tool:
		return
	var safe := tension >= SAFE_LOW and tension <= SAFE_HIGH if phase == 2 else cursor.distance_to(guide()) <= TOLERANCE
	feedback = str(data()["steady"] if safe else data()["off"])
	if not safe:
		return
	progress += dt
	var need := HANG_TIME if phase == 0 else (seam_length() / STITCH_SPEED if phase == 1 else TENSION_TIME)
	if progress >= need:
		advance_step()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [phase_info()["name"], completed - phase_start(), phase_info()["steps"], completed, TOTAL]
	count_label.text = str(data()["count"]) % [completed, TOTAL]
	if _rig:
		_rig.queue_redraw()


## 摊棚、挂点、缝线（已缝的变绿）、张力表，以及商贩伸过来的手
class CanopyRig extends Node2D:
	var stage: CanopyShow

	func _draw() -> void:
		draw_rect(Rect2(-58, -48, 116, 59), Color("775e74"))
		for x in [-62, 60]:
			draw_rect(Rect2(x, -48, 4, 72), Color("a47d54"))
		for i in 3:
			draw_circle(HOOKS[i], 3, Color("96d8c4") if stage.completed > i else Color("c09a68"))
		var seam := stage.seam()
		for i in seam.size() - 1:
			draw_line(seam[i], seam[i + 1], Color("efcaa2"), 1)
		if stage.phase == 1:
			var remaining := stage.progress * STITCH_SPEED
			for i in seam.size() - 1:
				var length := seam[i].distance_to(seam[i + 1])
				if remaining <= 0:
					break
				draw_line(seam[i], seam[i].lerp(seam[i + 1], minf(1, remaining / length)), Color("9bdfb4"), 2)
				remaining -= length
		if stage.phase < 2:
			draw_arc(stage.guide(), TOLERANCE, 0, TAU, 12, Color("9bdfb4"), 1)
			draw_line(stage.cursor - Vector2(3, 0), stage.cursor + Vector2(3, 0), Color("ffdf80"), 1)
			draw_line(stage.cursor - Vector2(0, 3), stage.cursor + Vector2(0, 3), Color("ffdf80"), 1)
			if stage.holding_tool:
				draw_line(stage.cursor, stage.cursor + Vector2(4, -4), Color("ffffff"), 1)
		else:
			draw_rect(Rect2(-48, -20, 96, 9), Color("3c3046"))
			draw_rect(Rect2(-48 + 96 * SAFE_LOW, -20, 96 * (SAFE_HIGH - SAFE_LOW), 9), Color("538f77"))
			draw_rect(Rect2(-48 + 96 * stage.tension, -23, 2, 15), Color("ffe08c"))
			for i in 3:
				draw_line(Vector2(-45 + i * 45, -3), Vector2(-50 + i * 50, 22), Color("e1ccaa"), 2)
		for i in TOTAL:
			draw_rect(Rect2(-49 + i * 10, 17, 7, 3), Color("91d9ba") if i < stage.completed else Color("514458"))
		if stage.playing and not stage.busy and stage.recovery_left <= 0.0:
			var tip: Vector2 = stage.actors["princess"].position + Vector2(sin(stage.elapsed * 14) * 2, -14)
			draw_line(stage.actors["worker"].position + Vector2(6, -10), tip, Color("bc976b"), 2)
			draw_rect(Rect2(tip - Vector2(3, 2), Vector2(6, 4)), Color("e6d3ad") if stage.active_tool == "brush" else Color("efbbab"))
