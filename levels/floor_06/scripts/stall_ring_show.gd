class_name StallRingShow
extends ErrandWorkStage
## 庆功宴摊位「忍笑套圈」（商人）：站在柜台后面扔竹圈，柜台下面的小孩挠她的光脚。台词 data/after/stall_ring.json。
##   准星在一排 PEGS 根木桩上左右晃（AIM_SPEED），闷笑越高晃得越乱（JITTER × 闷笑）；J 扔：准星离最近的木桩不到 PEG_TOL 算套中（completed +1）。
##   一共 THROWS 个圈，套中 GOAL 个通关；圈用完还不够 → retry，从头再来。
##   干扰（WorkInterference）：小孩的挠法按 phases[].tools 轮换；每次加强准星猛地一偏（JOLT），闷笑上涨。
##   闷笑满：手一抖，圈掉了（算用掉一个）；魔力释放见 ErrandWorkStage。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、aim、throw()。

const PATH := "res://data/after/stall_ring.json"
const GOAL := 6
const THROWS := 12
const PEGS := [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]
const PEG_TOL := 4.0
const AIM_SPEED := 1.6
const AIM_RANGE := 52.0
const JITTER := 10.0
const JOLT := 14.0
const JOLT_TIME := 0.5
const RATE := 0.012
const STRONG_LAUGH := 0.07
const FATIGUE_RATE := 0.01
const FLIGHT := 0.45

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var aim := 0.0
var thrown := 0
var jolt := 0.0
var jolt_left := 0.0
var flying := 0.0
var landed: Array = []
var _info: Label
var _rig: RingRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [GOAL]


func panel_title() -> String:
	return str(data().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [0, 26], "visual": "normal", "anim": "idle", "dir": "up"},
		"keeper": {"kind": "npc:merchant", "at": [-62, 6], "dir": "right"},
		"kid": {"kind": "npc:kid", "at": [16, 34], "dir": "left"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "kid"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	_rig = RingRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	busy = false
	_refresh()


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	if k in ["J", "E", "SPACE"]:
		throw()


## 扔一个圈：看准星离最近的木桩有多远
func throw() -> bool:
	if busy or flying > 0.0 or thrown >= THROWS:
		return false
	thrown += 1
	flying = FLIGHT
	var x := aim_x()
	var best := 999.0
	var peg := 0
	for i in PEGS.size():
		if absf(x - float(PEGS[i])) < best:
			best = absf(x - float(PEGS[i]))
			peg = i
	var hit := best <= PEG_TOL
	landed.append({"x": x, "hit": hit, "peg": peg})
	if hit:
		var prizes: Array = data().get("prizes", [])
		narrate(str(data()["prize_line"]) % str(prizes[peg % prizes.size()]), 2.0)
		_pop_random(data().get("hit", []), GOOD, 1.2)
		advance_step()
	else:
		_pop_random(data().get("miss", []), BAD, 1.2)
		_check_out()
	_refresh()
	return hit


## 圈用完还不够：从头再来
func _check_out() -> void:
	if thrown < THROWS or completed >= GOAL:
		return
	busy = true
	await _lines(data().get("retry", []))
	if not _alive():
		return
	thrown = 0
	completed = 0
	landed.clear()
	busy = false
	_refresh()


## 准星的实际位置：左右晃 + 闷笑越高越乱 + 加强时猛地一偏
func aim_x() -> float:
	var ratio := player.laugh.ratio() if player.laugh else 0.0
	var j := sin(elapsed * 13.0) * JITTER * ratio + (jolt * jolt_left / JOLT_TIME if jolt_left > 0.0 else 0.0)
	return clampf(aim + j, -AIM_RANGE, AIM_RANGE)


func recover() -> void:
	super()
	thrown = mini(THROWS, thrown + 1)
	_check_out()


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
	flying = maxf(0.0, flying - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	aim = sin(elapsed * AIM_SPEED) * AIM_RANGE
	jolt_left = maxf(0.0, jolt_left - dt)
	work_laugh(laugh_max() * RATE * dt)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	if event["strong"]:
		jolt = JOLT * (1.0 if rng.randf() < 0.5 else -1.0)
		jolt_left = JOLT_TIME
		work_laugh(laugh_max() * STRONG_LAUGH)
	if event["reaction"]:
		work_reaction(data(), 0, active_tool, tickler)
	if interference.warning():
		narrate(str(data()["warning"]), 0.8)
	if _rig:
		_rig.queue_redraw()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [completed, GOAL, THROWS - thrown]
	count_label.text = str(data()["count"]) % [completed, GOAL]
	if _rig:
		_rig.queue_redraw()


## 柜台、一排木桩和奖品、准星、飞出去的圈
class RingRig extends Node2D:
	var stage: StallRingShow

	func _draw() -> void:
		draw_rect(Rect2(-60, -40, 120, 6), Color("8b6644"))
		for i in PEGS.size():
			var x := float(PEGS[i])
			draw_rect(Rect2(x - 1.5, -48, 3, 10), Color("c39a6b"))
			draw_circle(Vector2(x, -50), 2.5, Color("f3c77a") if i % 2 else Color("e7a0c4"))
		for l in stage.landed:
			var c: Color = Color("8fe0a6") if l["hit"] else Color(1, 1, 1, 0.35)
			draw_arc(Vector2(float(l["x"]), -42), 4, 0, TAU, 12, c, 1.5)
		var ax := stage.aim_x()
		draw_line(Vector2(ax, -58), Vector2(ax, -34), Color("ffe08a"), 1)
		draw_arc(Vector2(ax, -46), 5, 0, TAU, 12, Color("ffe08a"), 1)
		if stage.flying > 0.0:
			var r := 1.0 - stage.flying / FLIGHT
			var last: Dictionary = stage.landed.back() if not stage.landed.is_empty() else {"x": 0.0}
			draw_arc(Vector2(0, 16).lerp(Vector2(float(last["x"]), -42), r) + Vector2(0, -sin(r * PI) * 16), 4, 0, TAU, 12, Color("e8c98f"), 2)
		# 柜台挡住她的下半身，柜台下面的小孩
		draw_rect(Rect2(-24, 22, 48, 14), Color("9b7350"))
		draw_rect(Rect2(-24, 22, 48, 2), Color("c49a6c"))
