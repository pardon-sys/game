class_name SiftingShow
extends ErrandWorkStage
## 药剂师奶奶的可选委托「筛叶风选」：跟拍筛松 / 调风分叶 / 装 3 袋。台词 data/after/errand_sifting.json。
##   筛松：节拍 BEAT 秒一拍，±BEAT_WINDOW 内按 J，接够 RHYTHM_GOAL 拍（一拍只算一次，错拍不扣）。
##   风选：A / D 调风向（三档），J 跟拍筛出一片叶；出手时锁定风向，飞 LEAF_LIFE 秒落进对应的篮子才算，最多 MAX_LEAVES 片在空中；收齐 LEAF_GOAL 片。
##   装袋：按住 J 以 BAG_RATE / 秒往袋里送叶，松开时在 BAG_LOW~BAG_HIGH 之间算一袋，否则只重装这一袋。
##   errand_sifting_step 保存完成了几段（0~5）；闷笑满 / 魔力释放见 ErrandWorkStage。
## 测试：quiet、fixed_seed、press()、hold_tool()、simulate()、shake_on_beat()。

const PATH := "res://data/after/errand_sifting.json"
const SAVE_STEP := "errand_sifting_step"
const TOTAL := 5
const BEAT := 0.75
const BEAT_WINDOW := 0.18
const RHYTHM_GOAL := 12
const LEAF_GOAL := 24
const LEAF_LIFE := 1.5
const MAX_LEAVES := 12
const WIND_STEP := 1.0
const BAG_RATE := 0.25
const BAG_LOW := 0.9
const BAG_HIGH := 1.1
const BASE_RATE := 0.004
const STRONG_LAUGH := 0.03
const STRONG_FATIGUE := 0.01
const LEAF_COLORS := [Color("b3dd8a"), Color("f2cb7f"), Color("c9b0ec")]

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var progress := 0.0
var wind := 0.0
var holding_tool := false
var feedback := ""
var collected := 0
var sent := 0
var beat_clock := 0.0
var last_beat := -1
var leaves: Array[Dictionary] = []
var _info: Label
var _rig: SiftingRig
var _stage_count: Label


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
	return {"princess": {"kind": "princess", "at": [74, 23], "visual": "normal", "anim": "idle", "dir": "left"},
		"worker": {"kind": "npc:" + str(data()["actor"]), "at": [74, -15], "dir": "down"}}


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
	_stage_count = _label(TEXT, 9)
	_stage_count.position = to_frame(Vector2(26, -40))
	_stage_count.z_index = 110
	overlay.add_child(_stage_count)
	_rig = SiftingRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	active_tool = "brush"
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	progress = 0.0
	collected = 0
	sent = 0
	beat_clock = 0.0
	last_beat = -1
	leaves.clear()
	holding_tool = false
	feedback = str(data()["steady"])
	busy = false
	_refresh()


func _reset_segment() -> void:
	progress = 0.0
	leaves.clear()
	collected = 0


func _stop_input() -> void:
	holding_tool = false


func hold_tool(on: bool) -> void:
	var was := holding_tool
	holding_tool = on and playing and not busy and not _suspended() and recovery_left <= 0.0
	# 装袋：松开 J 的那一刻看分量
	if was and not on and phase == 2 and not busy and not _suspended():
		if progress >= BAG_LOW and progress <= BAG_HIGH:
			advance_step()
		else:
			progress = 0.0
			feedback = str(data()["bag_retry"])
			work_reaction(data(), phase, active_tool, tickler, "error_react")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and playing and KEY_NAMES.get(event.keycode, "") == "J" and phase == 2:
		if not event.echo:
			hold_tool(event.pressed)
		get_viewport().set_input_as_handled()
		return
	super(event)


func _on_key(key: String) -> void:
	if recovery_left > 0.0:
		return
	if key == "J":
		if phase < 2:
			shake_on_beat()
		else:
			hold_tool(true)
		return
	match key:
		"A", "LEFT":
			wind = clampf(wind - WIND_STEP, -1.0, 1.0)
		"D", "RIGHT":
			wind = clampf(wind + WIND_STEP, -1.0, 1.0)
	_refresh()


## J 跟拍：筛松时接一拍，风选时筛出一片叶（风向在出手时锁定）
func shake_on_beat() -> bool:
	if busy or _suspended() or recovery_left > 0.0:
		return false
	var beat := roundi(beat_clock / BEAT)
	if beat < 1 or beat == last_beat or absf(beat_clock - beat * BEAT) > BEAT_WINDOW:
		feedback = str(data()["beat_miss"])
		return false
	last_beat = beat
	feedback = str(data()["beat_ok"])
	if phase == 0:
		collected += 1
		if collected >= RHYTHM_GOAL:
			advance_step()
	elif leaves.size() < MAX_LEAVES:
		leaves.append({"age": 0.0, "kind": sent % 3, "wind": wind})
		sent += 1
	_refresh()
	return true


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
	beat_clock += dt
	work_laugh(laugh_max() * BASE_RATE * dt)
	add_fatigue(fatigue_max() * BASE_RATE * dt)
	if event["strong"]:
		wind = clampf(wind + (0.12 if interference.strong_count % 2 else -0.12), -1.0, 1.0)
		work_laugh(laugh_max() * STRONG_LAUGH)
		add_fatigue(fatigue_max() * STRONG_FATIGUE)
	if event["reaction"]:
		work_reaction(data(), phase, active_tool, tickler)
	if _punish_request != "":
		return
	if phase == 1:
		for leaf in leaves.duplicate():
			leaf["age"] += dt
			if leaf["age"] >= LEAF_LIFE:
				if absf(float(leaf["wind"]) * 48.0 - (int(leaf["kind"]) - 1) * 48.0) <= 12:
					collected += 1
				leaves.erase(leaf)
		if collected >= LEAF_GOAL:
			advance_step()
	elif phase == 2 and holding_tool:
		progress = minf(1.2, progress + BAG_RATE * dt)
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [phase_info()["name"], completed - phase_start(), phase_info()["steps"], completed, TOTAL]
	count_label.text = str(data()["count"]) % [completed, TOTAL]
	if _stage_count:
		_stage_count.visible = phase < 2
		_stage_count.text = "%d/%d" % [collected, RHYTHM_GOAL if phase == 0 else LEAF_GOAL]
	if _rig:
		_rig.queue_redraw()


## 晒架、筛盘、三只篮子、节拍条、飞着的叶子、袋子的分量，以及药剂师伸过来的手
class SiftingRig extends Node2D:
	var stage: SiftingShow

	func leaf_icon(at: Vector2, kind: int) -> void:
		var color: Color = LEAF_COLORS[kind]
		if kind == 0:
			draw_circle(at, 3, color)
		elif kind == 1:
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), color)
		else:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 3), at + Vector2(-4, 3)]), color)

	func _draw() -> void:
		draw_rect(Rect2(-56, -24, 112, 5), Color("b38b5e"))
		for x in [-52, 48]:
			draw_rect(Rect2(x, -19, 4, 43), Color("916b4c"))
		draw_arc(Vector2(0, -22), 19, 0, PI, 16, Color("d5bb88"), 3)
		for i in 3:
			var at := Vector2((i - 1) * 48, 13)
			draw_rect(Rect2(at - Vector2(12, 0), Vector2(24, 10)), Color("967452"))
			leaf_icon(at + Vector2(0, 4), i)
		var t := fmod(stage.beat_clock, BEAT) / BEAT
		draw_rect(Rect2(-45, -52, 90, 5), Color("3a3043"))
		draw_rect(Rect2(-45, -52, 90 * BEAT_WINDOW / BEAT, 5), Color("63a48b"))
		draw_rect(Rect2(45 - 90 * BEAT_WINDOW / BEAT, -52, 90 * BEAT_WINDOW / BEAT, 5), Color("63a48b"))
		draw_rect(Rect2(-45 + t * 90, -54, 2, 9), Color("ffda8b"))
		if stage.phase == 1:
			leaf_icon(Vector2(0, -36), stage.sent % 3)
			draw_line(Vector2(0, -30), Vector2(stage.wind * 22, -30), Color("9bd5e3"), 2)
			for leaf in stage.leaves:
				var ratio: float = leaf["age"] / LEAF_LIFE
				leaf_icon(Vector2(float(leaf["wind"]) * 48 * ratio, lerpf(-40, 12, ratio)), int(leaf["kind"]))
		elif stage.phase == 2:
			draw_rect(Rect2(-15, -12, 30, 35), Color("b89c73"))
			draw_rect(Rect2(-12, 18 - stage.progress * 25, 24, stage.progress * 25), Color("92b27c"))
			draw_line(Vector2(-20, 18 - BAG_LOW * 25), Vector2(20, 18 - BAG_LOW * 25), Color("96e2b1"), 1)
			draw_line(Vector2(-20, 18 - BAG_HIGH * 25), Vector2(20, 18 - BAG_HIGH * 25), Color("96e2b1"), 1)
		if stage.playing and not stage.busy and stage.recovery_left <= 0.0:
			var tip: Vector2 = stage.actors["princess"].position + Vector2(sin(stage.elapsed * 14) * 2, -14)
			draw_line(stage.actors["worker"].position + Vector2(6, -10), tip, Color("bc976b"), 2)
			draw_rect(Rect2(tip - Vector2(3, 2), Vector2(6, 4)), Color("e6d3ad") if stage.active_tool == "brush" else Color("efbbab"))
