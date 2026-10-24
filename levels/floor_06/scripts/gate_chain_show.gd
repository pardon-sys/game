class_name GateChainShow
extends ErrandWorkStage
## 工匠的可选委托「城门底下重新穿链」：她仰面躺进检修槽穿链，两只光脚伸在槽口外，工匠一边报位置一边挠她的脚底。台词 data/after/errand_gate_chain.json。
##   穿链 3 步 / 入轮 6 步 / 试拉 3 步：←→ / A D 对准（AIM_STEP），J / K 调力度（FORCE_STEP），两个指针都进绿区按 E。
##   干扰（WorkInterference）：持续的晃动和闷笑；每次加强把链头推偏、力度加重，道具按阶段轮换（清灰刷 / 羽毛掸 → 油刷 / 链环 → 手指 / 齿轮刷）。
##   缩脚：加强的预告亮着时按 S，这一下闷笑 ×TUCK_LAUGH_SCALE，但链头往反方向偏 ×TUCK_PUSH_SCALE。不在预告时按没有效果。
##   失误只退当前这一步；闷笑满 / 魔力释放见 ErrandWorkStage。errand_gate_chain_step 保存完成了几步（0~12）。
## 测试：quiet、fixed_seed、press()、apply_interference()、mistake()、cancel()。

const PATH := "res://data/after/errand_gate_chain.json"
const SAVE_STEP := "errand_gate_chain_step"
const TOTAL := 12
const AIM_STEP := 0.08
const FORCE_STEP := 0.05
const FORCE_DECAY := 0.025
const AIM_DRIFT := 0.035
const SETTLE_RATE := 0.006
const BASE_LAUGH_RATE := 0.01
const BASE_FATIGUE_RATE := 0.004
const BASE_SWAY := 0.045
const FORCE_SWAY := 0.015
const STRONG_PUSH_SCALE := 0.55
const STRONG_LOAD_SCALE := 0.4
const STRONG_LAUGH := 0.03
const STRONG_PHASE_LAUGH := 0.005
const STRONG_FATIGUE := 0.01
const TUCK_LAUGH_SCALE := 0.5
const TUCK_PUSH_SCALE := 1.5
const LIMITS := [3, 9, 12]
const FEET := Vector2(2, 14)

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var errors := 0
var aim := 0.0
var force := 0.0
var feedback := ""
var tool_flash := 0.0
var tucked := false
var tucks := 0
var tuck_flash := 0.0
var _info: Label
var _rig: ChainRig
var _soles: SoleRig
var _gauges: ChainGauges


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
	return str(text().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [FEET.x, FEET.y], "visual": "normal", "anim": "idle", "dir": "up"},
		"worker": {"kind": "npc:miner", "at": [30, 20], "dir": "left"}}


func node_info() -> Dictionary:
	return text()["nodes"][mini(completed, TOTAL - 1)]


func target() -> float:
	return float(node_info()["target"])


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = saved_step()
	phase = phase_of(completed)
	tickler = "worker"
	_build_ui()
	hint_label.text = str(text()["hint"])
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 32)
	panel_body.add_child(_info)
	_gauges = ChainGauges.new()
	_gauges.stage = self
	_gauges.position = Vector2(0, 29)
	panel_body.add_child(_gauges)
	_enter_game()
	(actors["princess"] as CGActor).rotation = -PI / 2.0
	_rig = ChainRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	_soles = SoleRig.new()
	_soles.stage = self
	_soles.z_index = 3
	view.add_child(_soles)
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	if not _alive():
		return
	aim = 0.0
	force = 0.0
	tucked = false
	feedback = str(text()["ready"])
	busy = false
	narrate(str(node_info()["caption"]), 2.8)
	_refresh()


func _reset_segment() -> void:
	errors += 1
	aim = 0.0
	force = 0.0
	tucked = false


func _on_phase_changed() -> void:
	rotate_tool()


func _before_finish() -> void:
	var actor: CGActor = actors.get("princess")
	if actor:
		actor.rotation = 0.0
		actor.position = Vector2(-12, 16)
		actor.set_pose("normal", "idle", "right")
	if _soles:
		_soles.hide()


## 一次加强：链头推偏、力度加重、闷笑和疲倦上涨；预告时缩了脚的话闷笑减半，但链头往反方向偏得更多。
func apply_interference() -> void:
	if not _alive() or completed >= TOTAL:
		return
	var n := node_info()
	tool_flash = 0.7
	var push := float(n["push"]) * STRONG_PUSH_SCALE
	var laugh := laugh_max() * (STRONG_LAUGH + float(phase) * STRONG_PHASE_LAUGH)
	if tucked:
		tucked = false
		push = -push * TUCK_PUSH_SCALE
		laugh *= TUCK_LAUGH_SCALE
		tuck_flash = 0.6
		var t: Array = text().get("tuck_ok", [])
		if not t.is_empty():
			narrate(str(t[rng.randi_range(0, t.size() - 1)]), 2.4, true)
		_pop_random(text().get("tuck_react", []), GOOD, 1.4)
	aim = clampf(aim + push, -1.0, 1.0)
	force = clampf(force + float(n["load"]) * STRONG_LOAD_SCALE, 0.0, 1.0)
	work_laugh(laugh)
	add_fatigue(fatigue_max() * STRONG_FATIGUE)
	_refresh()


## S：预告亮着时把脚缩回槽里
func tuck() -> bool:
	if tucked or not interference.warning():
		feedback = str(text().get("tuck_idle", ""))
		return false
	tucked = true
	tucks += 1
	return true


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	match k:
		"LEFT", "A":
			aim = maxf(-1.0, aim - AIM_STEP)
		"RIGHT", "D":
			aim = minf(1.0, aim + AIM_STEP)
		"J":
			force = minf(1.0, force + FORCE_STEP)
		"K":
			force = maxf(0.0, force - FORCE_STEP)
		"S", "DOWN":
			tuck()
		"E":
			if absf(aim - target()) > float(phase_info()["tolerance"]):
				feedback = str(text()["bad_align"])
				mistake()
			elif force < float(phase_info()["force"][0]) or force > float(phase_info()["force"][1]):
				feedback = str(text()["bad_force"])
				mistake()
			else:
				feedback = str(text()["next"])
				advance_step()
	_refresh()


## 失误只退回当前这一步；full / fatigue 走满值的处理（测试用）。
func mistake(kind := "mistake") -> void:
	if busy or not _alive():
		return
	match kind:
		"full":
			recover()
		"fatigue":
			release()
		_:
			_reset_segment()
			work_reaction(text(), phase, active_tool, tickler, "error_react")
	_refresh()


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
	_tick(delta * time_scale)


func _tick(delta: float) -> void:
	if not _alive() or busy or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	tuck_flash = maxf(0.0, tuck_flash - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		_refresh()
		return
	var event := work_clock(dt)
	tool_flash = maxf(0.0, tool_flash - dt)
	var ratio := player.laugh.ratio() if player.laugh else 0.0
	aim = clampf(aim + sin(elapsed * 4.2) * (BASE_SWAY + AIM_DRIFT * ratio) * dt, -1.0, 1.0)
	force = clampf(force - FORCE_DECAY * dt + sin(elapsed * 3.0) * FORCE_SWAY * dt, 0.0, 1.0)
	work_laugh(laugh_max() * (BASE_LAUGH_RATE - SETTLE_RATE) * dt)
	add_fatigue(fatigue_max() * BASE_FATIGUE_RATE * dt)
	if event["strong"]:
		apply_interference()
	if event["reaction"]:
		work_reaction(text(), phase, active_tool, tickler)
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(text()["panel"]) % [phase_info()["name"], completed - phase_start(), phase_info()["steps"], completed, errors]
	count_label.text = str(text()["short_count"]) % completed
	if interference.warning() and not tucked:
		narrate(str(text()["warning"]), 1.0)
	if _gauges:
		_gauges.queue_redraw()
	if _rig:
		_rig.queue_redraw()
	if _soles:
		_soles.queue_redraw()


## 左上面板的两根判定表（对准 / 力度）
class ChainGauges extends Control:
	var stage: GateChainShow

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for row in 2:
			var y := float(row * 25)
			draw_string(font, Vector2(0, y + 7), str(stage.text()["align" if row == 0 else "force"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
			draw_rect(Rect2(0, y + 11, 98, 7), Color("33273f"))
			var band: Array = stage.phase_info()["force"]
			var tolerance := float(stage.phase_info()["tolerance"])
			var left := (stage.target() - tolerance + 1.0) * 49.0 if row == 0 else float(band[0]) * 98.0
			var width := tolerance * 98.0 if row == 0 else (float(band[1]) - float(band[0])) * 98.0
			draw_rect(Rect2(left, y + 11, width, 7), Color("467c66"))
			var x := (stage.aim + 1.0) * 49.0 if row == 0 else stage.force * 98.0
			draw_rect(Rect2(x - 1, y + 9, 2, 11), Color("ffe59a"))


## 城门检修图：门、支架、导轮、链条、已扣好的节点，以及链头的实际位置。
class ChainRig extends Node2D:
	var stage: GateChainShow

	func draw_chain(a: Vector2, b: Vector2) -> void:
		var count := maxi(1, int(a.distance_to(b) / 4.0))
		draw_line(a, b, Color("282330"), 3)
		for i in count + 1:
			var p := a.lerp(b, float(i) / float(count)).round()
			var r := Rect2(p - Vector2(2, 1), Vector2(4, 3)) if i % 2 == 0 else Rect2(p - Vector2(1, 2), Vector2(3, 4))
			draw_rect(r, Color("ddd1c4"), false, 1)

	func _draw() -> void:
		draw_rect(Rect2(-78, -58, 153, 48), Color("403343"))
		for x in range(-73, 74, 12):
			draw_rect(Rect2(x, -55, 9, 40), Color("795a52"))
		for x in [-77, 69]:
			draw_rect(Rect2(x, -58, 7, 83), Color("ac8056"))
			draw_rect(Rect2(x - 4, 23, 15, 5), Color("5d4841"))
		# 检修槽：她躺在里面，脚从右边的槽口伸出来
		draw_rect(Rect2(-67, -2, 70, 29), Color("392c39"))
		draw_rect(Rect2(-69, 25, 75, 4), Color("b9906d"))
		draw_rect(Rect2(-72, -19, 140, 7), Color("c2a07d"))
		var points := PackedVector2Array([Vector2(-68, -36), Vector2(-32, -36), Vector2(-32, -48), Vector2(28, -48), Vector2(28, -36), Vector2(63, -36)])
		for i in points.size() - 1:
			draw_chain(points[i], points[i + 1])
		for p in [Vector2(-32, -40), Vector2(28, -40)]:
			draw_circle(p, 10, Color("302c3d"))
			draw_arc(p, 9, 0, TAU, 16, Color("cab9ad"), 2)
			for i in 4:
				var angle := stage.force * 3.0 + float(i) * PI / 2.0
				draw_line(p, p + Vector2.from_angle(angle) * 7.0, Color("9a8790"), 1)
		for i in TOTAL:
			draw_rect(Rect2(-67 + i * 11, -7, 8, 4), Color("8ccaaa") if i < stage.completed else Color("64535e"))
		var tx := stage.target() * 48.0
		draw_rect(Rect2(tx - 5, -30, 10, 8), Color("69b99b"))
		var tip := Vector2(stage.aim * 48.0, -24)
		draw_chain(Vector2(-40, 3), tip)
		draw_rect(Rect2(tip - Vector2(2, 2), Vector2(5, 5)), Color("ffe59a"))


## 槽口外的两只光脚和工匠手里的道具（画在演员前面）
class SoleRig extends Node2D:
	var stage: GateChainShow
	const SKIN := Color("f6d3c4")
	const SKIN_DARK := Color("e7ae9f")

	func draw_sole(at: Vector2, oiled: bool) -> void:
		draw_circle(at, 2.5, SKIN)
		draw_rect(Rect2(at + Vector2(0, -3), Vector2(5, 6)), SKIN)
		draw_circle(at + Vector2(5, 0), 3.2, SKIN)
		for i in 5:
			draw_circle(at + Vector2(8.5, -3.0 + i * 1.5), 0.9, SKIN_DARK)
		draw_line(at + Vector2(1, 0), at + Vector2(5, 0), SKIN_DARK, 1)
		if oiled:
			draw_line(at + Vector2(1, -2), at + Vector2(4, -2), Color(1, 1, 1, 0.7), 1)

	func _draw() -> void:
		if not stage.playing:
			return
		var pull := 3.0 if stage.tuck_flash > 0.0 or stage.tucked else 0.0
		var oiled := stage.phase >= 1
		var feet := [FEET + Vector2(1 - pull, -4), FEET + Vector2(1 - pull, 3)]
		for f in feet:
			draw_sole(f, oiled)
		if stage.busy or stage.recovery_left > 0.0:
			return
		var wobble := sin(stage.elapsed * (16.0 if stage.tool_flash > 0.0 else 9.0))
		var target: Vector2 = feet[int(stage.elapsed * 0.7) % 2] + Vector2(5, wobble * 2.5)
		var hand := Vector2(25, 8)
		match stage.active_tool:
			"brush", "oil":
				draw_line(hand, target + Vector2(4, 0), Color("c7a371"), 2)
				draw_rect(Rect2(target + Vector2(1, -2), Vector2(4, 5)), Color("e4c89e"))
				for i in 4:
					draw_line(target + Vector2(1, -2 + i * 1.5), target + Vector2(-1, -2 + i * 1.5), Color("d6b07c"), 1)
				if stage.active_tool == "oil":
					draw_circle(target + Vector2(2, 4 + wobble), 0.9, Color("f3c56a"))
			"feather":
				draw_line(hand, target + Vector2(6, -1), Color("c7a371"), 1)
				draw_line(target + Vector2(6, -1), target, Color(1, 1, 1), 2)
				for i in 3:
					draw_line(target + Vector2(1.5 + i * 1.5, -1), target + Vector2(1 + i * 1.5, -3), Color(0.95, 0.95, 1), 1)
			"chain":
				draw_line(hand, target + Vector2(4, 0), Color("efbdab"), 2)
				for i in 3:
					draw_rect(Rect2(target + Vector2(3 - i * 2, -1 + wobble * 0.5), Vector2(2, 2)), Color("ddd1c4"), false, 1)
			"finger":
				draw_line(hand, target + Vector2(3, 0), Color("efbdab"), 3)
				draw_circle(target + Vector2(2, 0), 1.5, Color("f4c6b4"))
			"gear":
				draw_line(hand, target + Vector2(4, 0), Color("c7a371"), 2)
				draw_circle(target + Vector2(2, 0), 2.5, Color("b9b0a6"))
				for i in 6:
					var a := stage.elapsed * 8.0 + i * TAU / 6.0
					draw_line(target + Vector2(2, 0), target + Vector2(2, 0) + Vector2.from_angle(a) * 3.5, Color("8f857d"), 1)
