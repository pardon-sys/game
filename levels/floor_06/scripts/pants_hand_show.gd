class_name PantsHandShow
extends DrillShow
## 特训第三课「借手」：蓝色公主站在训练台上，队长从两边丢状况，按键指挥千手痒痒裤的小手去处理（events）：
##   羽毛从左 / 右 / 上飞来 → ← / → / ↑ 挡；拉杆亮起 → 左 A、右 D 去拉；粉色公主从背后偷袭 → ↓ 抓住她。
##   每个状况有反应时间 window（越往后越短，释放后敏感时更短）；每下一次指令听话度 −COST（每秒回 REGEN）；
##   听话度不够时下指令 = 造反（小手挠自己，这个状况也算漏）。按错键 / 超时 = 漏：被挠（部位按状况）。
##   处理够 goal 个过关；闷笑满 = 破功（演 break，进度退 BREAK_BACK）。

const COST := 18.0
const REGEN := 9.0
const BREAK_BACK := 3

var obedience := 100.0
var handled := 0
var missed := 0
var rebels := 0
var event_id := ""
var left := 0.0
var window := 1.6
var gap_t := 1.2
var _panel_draw: Control


func lesson_id() -> String:
	return "hand"


func hint_text() -> String:
	return "← → ↑ 挡羽毛　A / D 拉拉杆　↓ 抓偷袭"


func goal() -> int:
	return int(lesson().get("goal", 12))


class Panel2 extends Control:
	var stage: PantsHandShow
	const GLYPH := {"LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓", "A": "A", "D": "D"}
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 5), Color(0.2, 0.14, 0.24))
		draw_rect(Rect2(0, 0, w * stage.obedience / 100.0, 5), Color(0.55, 0.85, 1.0))
		if stage.event_id == "":
			return
		var ev: Dictionary = stage.lesson().get("events", {}).get(stage.event_id, {})
		var g := str(GLYPH.get(str(ev.get("key", "")), "?"))
		var f := get_theme_default_font()
		draw_string(f, Vector2(w * 0.5 - 6, 30), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.86, 0.4))
		draw_rect(Rect2(0, 36, w * clampf(stage.left / maxf(0.01, stage.window), 0.0, 1.0), 3), Color(1, 0.6, 0.7))


func _build_extra() -> void:
	_panel_draw = Panel2.new()
	_panel_draw.stage = self
	_panel_draw.position = Vector2(2, 48)
	_panel_draw.size = Vector2(panel_body.size.x - 4, 40)
	panel_body.add_child(_panel_draw)


func _begin() -> void:
	super()
	obedience = 100.0
	handled = 0
	event_id = ""
	gap_t = 1.2
	_refresh()


func _refresh() -> void:
	if _info:
		_info.text = "处理 %d / %d　听话度 %d%s" % [handled, goal(), int(obedience), ("\n释放后敏感！") if sensitive_t > 0.0 else ""]
	if _panel_draw:
		_panel_draw.queue_redraw()


func _tick(delta: float) -> void:
	_common_tick(delta)
	obedience = minf(100.0, obedience + REGEN * delta)
	if handled >= goal():
		_done = true
		return
	if event_id == "":
		gap_t -= delta
		if gap_t <= 0.0:
			_next_event()
	else:
		left -= delta
		if left <= 0.0:
			_miss()
	_refresh()


func _next_event() -> void:
	var ids: Array = lesson().get("events", {}).keys()
	event_id = str(ids.pick_random())
	var p := float(handled) / float(goal())
	window = lerpf(1.8, 0.9, p) * (0.8 if sensitive_t > 0.0 else 1.0)
	left = window
	narrate(str(lesson().get("events", {}).get(event_id, {}).get("show", "")), window + 0.3)


func _on_key(k: String) -> void:
	if event_id == "" or k not in ["LEFT", "RIGHT", "UP", "DOWN", "A", "D"]:
		return
	if obedience < COST:
		rebels += 1
		var rb: Array = lesson().get("rebel", [])
		hit("princess", ["thigh", "butt"].pick_random(), str(rb.pick_random()) if not rb.is_empty() else "", 0.06)
		_miss()
		return
	obedience -= COST
	var ev: Dictionary = lesson().get("events", {}).get(event_id, {})
	if k == str(ev.get("key", "")):
		handled += 1
		narrate(str(ev.get("ok", "")), 1.2)
		say("princess", ["……挡。", "……去。", "……抓住。", "……乖。"].pick_random())
		if event_id == "sneak":
			var cp: Array = lesson().get("caught_pink", [])
			if not cp.is_empty():
				say("pink", str(cp.pick_random()))
		Audio.play("pickup", -10.0, 0.1)
		event_id = ""
		gap_t = rng.randf_range(0.5, 1.1)
		_refresh()
	else:
		_miss()


func _miss() -> void:
	missed += 1
	var ev: Dictionary = lesson().get("events", {}).get(event_id, {})
	var by := "pink" if event_id == "sneak" else "cap"
	var ms: Array = ev.get("miss", [])
	if event_id == "sneak":
		var sp: Array = lesson().get("sneak_ok_pink", [])
		if not sp.is_empty():
			say("pink", str(sp.pick_random()))
	hit(by, str(ev.get("zone", "thigh")), str(ms.pick_random()) if not ms.is_empty() else "", 0.08)
	event_id = ""
	gap_t = rng.randf_range(0.8, 1.3)
	_refresh()


func _on_break() -> void:
	super()
	handled = maxi(0, handled - BREAK_BACK)
	await _lines(lesson().get("break", []))
