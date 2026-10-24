class_name StallIceShow
extends ErrandWorkStage
## 庆功宴摊位「冰雕摊」（工匠）：这一摊由蓝色公主上场刻冰雕，粉色公主在旁边捣乱挠她的大腿，千手痒痒裤的小手也来凑热闹。台词 data/after/stall_ice.json。
##   三座冰雕（phases，刀数 strokes）：屏幕上出一个方向（刻刀的走向），PROMPT_TIME 秒内按对就刻一刀（completed +1）；
##     蓝色公主的闷笑（blue_laugh，只在舞台上模拟）越高，提示越抖、时间越短（× (1 − SHRINK × 闷笑)）。按错 / 超时 = 刀一滑（slips +1，这一刀重来）。
##   blue_laugh：每秒 +RATE；加强（粉色公主 / 小手挠她）+STRONG；J 冰封 −FREEZE，冷却 FREEZE_COOL 秒；笑满 = 冰雕笑塌了（这一座从头刻）。
##   粉色公主的闷笑、疲倦不参与。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、blue_laugh、want、freeze()。

const PATH := "res://data/after/stall_ice.json"
const KEYS := ["UP", "DOWN", "LEFT", "RIGHT"]
const ALIAS := {"W": "UP", "S": "DOWN", "A": "LEFT", "D": "RIGHT"}
const GLYPH := {"UP": "↑", "DOWN": "↓", "LEFT": "←", "RIGHT": "→"}
const PROMPT_TIME := 1.8
const SHRINK := 0.45
const RATE := 0.018
const STRONG := 0.12
const SLIP_LAUGH := 0.04
const FREEZE := 0.3
const FREEZE_COOL := 6.0
const COLLAPSE_RESET := 0.3

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var blue_laugh := 0.0
var want := "UP"
var prompt_left := PROMPT_TIME
var slips := 0
var collapses := 0
var freeze_cool := 0.0
var chip_flash := 0.0
var _info: Label
var _rig: IceRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	var out: Array = []
	var n := 0
	for s in data().get("sculptures", []):
		n += int(s["strokes"])
		out.append(n)
	return out


func panel_title() -> String:
	return str(data().get("name", ""))


func phase_info() -> Dictionary:
	return data()["sculptures"][phase]


func stage_cast() -> Dictionary:
	return {"worker": {"kind": "npc:miner", "at": [52, 0], "dir": "left"}}


## 蓝色公主 id blue（刻冰雕），粉色公主 id pink（捣乱）
func _build_cast(cast: Dictionary) -> void:
	super(cast)
	for spec in [["blue", "blue", Vector2(-14, 8), "right"], ["pink", "pink", Vector2(-34, 10), "right"]]:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose("normal", "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "pink"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_enter_game()
	_rig = IceRig.new()
	_rig.stage = self
	view.add_child(_rig)
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	if not _alive():
		return
	_next_prompt()
	busy = false
	_refresh()


func _next_prompt() -> void:
	want = str(KEYS[rng.randi_range(0, KEYS.size() - 1)])
	prompt_left = prompt_time()


func prompt_time() -> float:
	return PROMPT_TIME * (1.0 - SHRINK * blue_laugh)


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	var key := str(ALIAS.get(k, k))
	if key in KEYS:
		carve(key)
	elif k in ["J", "E"]:
		freeze()
	_refresh()


## 刻一刀：方向对就算，不对刀滑
func carve(key: String) -> void:
	if busy:
		return
	chip_flash = 0.3
	if key == want:
		advance_step()
	else:
		slip()


func slip() -> void:
	slips += 1
	blue_laugh = minf(1.0, blue_laugh + SLIP_LAUGH)
	var caps: Array = data().get("slip", [])
	narrate(str(caps[rng.randi_range(0, caps.size() - 1)]), 2.0, true)
	_say_blue(data().get("slip_react", []))
	_next_prompt()


## J 冰封：自己冻住大腿，闷笑压下去一截
func freeze() -> bool:
	if freeze_cool > 0.0:
		narrate(str(data()["freeze_cool"]), 1.0)
		return false
	freeze_cool = FREEZE_COOL
	blue_laugh = maxf(0.0, blue_laugh - FREEZE)
	var caps: Array = data().get("freeze", [])
	narrate(str(caps[rng.randi_range(0, caps.size() - 1)]), 2.0, true)
	_say_blue(data().get("freeze_react", []))
	flash(Color(0.7, 0.9, 1.0, 0.4), 0.3)
	return true


## 笑满：冰雕笑塌了，这一座从头刻
func collapse() -> void:
	collapses += 1
	completed = phase_start()
	blue_laugh = COLLAPSE_RESET
	recovery_left = RECOVER_TIME
	var c: Dictionary = data().get("collapse", {})
	narrate(str(c.get("desc", "")), 2.6, true)
	_say_blue(c.get("react", []))
	flash(Color(0.8, 0.95, 1.0, 0.6), 0.4)
	_next_prompt()


func _say_blue(lines: Array) -> void:
	if not lines.is_empty():
		pop(actors.get("blue"), str(lines[rng.randi_range(0, lines.size() - 1)]), Color(0.7, 0.85, 1.0), 1.6)


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done or _suspended():
		return
	if handle_overflow():
		return
	simulate(delta * time_scale)


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	chip_flash = maxf(0.0, chip_flash - dt)
	freeze_cool = maxf(0.0, freeze_cool - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		_refresh()
		return
	var event := interference.advance(dt)
	elapsed = interference.elapsed
	if event["strong"]:
		rotate_tool()
		blue_laugh = minf(1.0, blue_laugh + STRONG)
	if event["fx"]:
		tickle(active_tool, tickle_zone, false, "blue", "pinch" if tickle_zone == "butt" else "hand")
	if event["reaction"]:
		_react()
	blue_laugh = minf(1.0, blue_laugh + RATE * dt)
	if blue_laugh >= 1.0:
		collapse()
		return
	prompt_left -= dt
	if prompt_left <= 0.0:
		slip()
	_refresh()


## 粉色公主 / 小手的一组挠法：描写进反应框，蓝色公主按自己的闷笑冒反应
func _react() -> void:
	var events: Array = data().get("feedback", []).filter(func(e): return int(e["phase"]) == phase and str(e["tool"]) == active_tool)
	if events.is_empty():
		return
	var e: Dictionary = events[rng.randi_range(0, events.size() - 1)]
	var tier := "light" if blue_laugh < 0.4 else ("mid" if blue_laugh < 0.75 else "heavy")
	narrate(str(e["caption"]), 3.0)
	_say_blue(e["react"][tier])
	tickle_zone = str(e.get("zone", "thigh"))


## 这一座的工具轮换：粉色公主 / 小手
func rotate_tool() -> void:
	active_tool = "pink" if interference.strong_count % 2 == 0 else "hands"


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [phase_info()["name"], completed - phase_start() + 1, int(phase_info()["strokes"]), slips]
	count_label.text = str(data()["count"]) % phase
	if _rig:
		_rig.queue_redraw()


## 冰块（刻好的部分越来越像样）、刻刀方向提示（越笑越抖）、蓝色公主的闷笑条
class IceRig extends Node2D:
	var stage: StallIceShow

	func _draw() -> void:
		var at := Vector2(18, -14)
		draw_rect(Rect2(at - Vector2(16, 18), Vector2(32, 36)), Color(0.75, 0.9, 1.0, 0.85))
		var done := float(stage.completed - stage.phase_start()) / maxf(1.0, float(stage.phase_info()["strokes"]))
		for i in int(done * 12.0):
			var a := i * TAU / 12.0
			draw_line(at, at + Vector2.from_angle(a) * (6 + i % 3 * 3), Color(1, 1, 1, 0.8), 1)
		draw_rect(Rect2(at + Vector2(-20, 18), Vector2(40, 4)), Color("8b6644"))
		var shake := Vector2(sin(stage.elapsed * 23.0), cos(stage.elapsed * 19.0)) * 3.0 * stage.blue_laugh
		var p := Vector2(18, -44) + shake
		var font := ThemeDB.fallback_font
		draw_circle(p, 9, Color(0.2, 0.25, 0.4, 0.8))
		draw_arc(p, 9, -PI / 2, -PI / 2 + TAU * stage.prompt_left / maxf(0.1, stage.prompt_time()), 20, Color("9fd8ff"), 2)
		draw_string(font, p + Vector2(-5, 5), str(GLYPH[stage.want]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		# 蓝色公主的闷笑条
		draw_rect(Rect2(-24, -26, 20, 3), Color("2c2236"))
		draw_rect(Rect2(-24, -26, 20 * stage.blue_laugh, 3), Color("8fc6ff"))
		if stage.freeze_cool > 0.0:
			draw_rect(Rect2(-24, -22, 20 * stage.freeze_cool / FREEZE_COOL, 2), Color(0.7, 0.9, 1.0, 0.6))
