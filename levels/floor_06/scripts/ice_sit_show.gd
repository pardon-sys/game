class_name IceSitShow
extends DrillShow
## 特训第一课「冰封静坐」：蓝色公主坐在冰台上，队长拿羽毛挠（粉色公主偶尔「帮忙加油」）。
##   队长要挠哪里，身体图（2 × 3 格，键 Q W E / A S D）上那里就先亮 warn 秒；按对应的键用冰魔法把那里冻住 FREEZE_TIME 秒（冻住的地方挠了没感觉）。
##   冻一次寒冷值 +FREEZE_COLD，挠到冻住的地方也 +HIT_COLD；寒冷值满 = 发抖（演一段）：冻住的地方全化开、表情 −SHIVER。
##   挠到没冻的地方：表情 −HIT_FACE（释放后敏感 ×1.6），闷笑 / 疲倦上涨。表情掉光 = 破功记一笔（break），三笔这节课重来（redo）。
##   假动作（feint）：先亮一处，半路换成另一处。释放后敏感时冻住的地方化得快一倍。撑够 time 秒过关。

const FREEZE_TIME := 6.0
const FREEZE_COLD := 14.0
const HIT_COLD := 4.0
const COLD_DECAY := 4.0
const HIT_FACE := 18.0
const SHIVER := 30.0
const MARKS := 3

var time_left := 55.0
var frozen := {}
var cold := 0.0
var face := 100.0
var marks := 0
var target := ""
var decoy := ""
var warn_t := 0.0
var warn_len := 1.0
var gap_t := 1.5
var hits := 0
var blocked := 0
var shivers := 0
var _pink_t := 9.0
var _chart: Control


func lesson_id() -> String:
	return "ice"


func hint_text() -> String:
	return "亮起来的地方：Q W E / A S D 冻住它"


func stage_cast() -> Dictionary:
	var c := super()
	c["seat"] = {"kind": "trap:cushion", "at": [0, 10]}
	return c


class Chart extends Control:
	var show_ref: IceSitShow
	func _draw() -> void:
		var spots: Array = show_ref.lesson().get("spots", [])
		var cw := size.x / 3.0
		for i in spots.size():
			var sp: Dictionary = spots[i]
			var r := Rect2((i % 3) * cw + 1, (i / 3) * 15 + 1, cw - 2, 13)
			var id := str(sp["id"])
			var col := Color(0.2, 0.16, 0.26)
			if show_ref.frozen.has(id):
				col = Color(0.45, 0.7, 1.0)
			if id == show_ref.target and show_ref.decoy == "":
				col = Color(1, 0.8, 0.35) if not show_ref.frozen.has(id) else Color(0.6, 0.9, 0.7)
			elif id == show_ref.decoy:
				col = Color(1, 0.8, 0.35)
			draw_rect(r, col)
			var f := get_theme_default_font()
			draw_string(f, r.position + Vector2(2, 10), "%s %s" % [sp["key"], sp["name"]], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2, 7, Color.WHITE)


func _build_extra() -> void:
	_chart = Chart.new()
	_chart.show_ref = self
	_chart.position = Vector2(2, 50)
	_chart.size = Vector2(panel_body.size.x - 4, 32)
	panel_body.add_child(_chart)


func _begin() -> void:
	super()
	time_left = float(lesson().get("time", 55.0))
	frozen.clear()
	cold = 0.0
	face = 100.0
	marks = 0
	target = ""
	decoy = ""
	gap_t = 1.5
	_refresh()


func _spot_info(id: String) -> Dictionary:
	for sp in lesson().get("spots", []):
		if str(sp["id"]) == id:
			return sp
	return {}


func _refresh() -> void:
	if _info:
		_info.text = "剩余 %d 秒　破功 %d / %d\n表情 %d%%　寒冷 %d%%%s" % [ceili(time_left), marks, MARKS, int(face), int(cold),
			("\n释放后敏感！%d 秒" % ceili(sensitive_t)) if sensitive_t > 0.0 else ""]
	if _chart:
		_chart.queue_redraw()


func _on_key(k: String) -> void:
	for sp in lesson().get("spots", []):
		if str(sp["key"]) == k:
			freeze(str(sp["id"]))
			return


## 冻住一处
func freeze(id: String) -> void:
	frozen[id] = FREEZE_TIME
	cold += FREEZE_COLD
	Audio.play("ice_crack", -12.0, 0.2)
	pop(actors.get("princess"), "冻住：%s" % str(_spot_info(id).get("name", id)), Color(0.7, 0.9, 1.0), 0.7)
	if cold >= 100.0:
		_shiver()
	_refresh()


func _tick(delta: float) -> void:
	_common_tick(delta)
	time_left -= delta
	if time_left <= 0.0:
		_done = true
		return
	cold = maxf(0.0, cold - COLD_DECAY * delta)
	for id in frozen.keys():
		frozen[id] = float(frozen[id]) - delta * (2.0 if sensitive_t > 0.0 else 1.0)
		if float(frozen[id]) <= 0.0:
			frozen.erase(id)
	# 队长挑地方
	if target == "":
		gap_t -= delta
		if gap_t <= 0.0:
			_pick_target()
	else:
		warn_t -= delta
		if decoy != "" and warn_t <= warn_len * 0.55:
			decoy = ""    # 假动作：半路换成真的那处
			var fe: Array = lesson().get("feint", [])
			if not fe.is_empty():
				narrate(str(fe.pick_random()), 1.2)
		if warn_t <= 0.0:
			_strike(target, "cap")
			target = ""
			gap_t = rng.randf_range(0.6, 1.3) * lerpf(1.0, 0.6, _progress())
	# 粉色公主「帮忙加油」
	_pink_t -= delta
	if _pink_t <= 0.0:
		_pink_t = rng.randf_range(8.0, 12.0)
		var ids: Array = lesson().get("spots", []).map(func(s): return str(s["id"]))
		_strike(str(ids.pick_random()), "pink")
	_refresh()


func _progress() -> float:
	return clampf(1.0 - time_left / float(lesson().get("time", 55.0)), 0.0, 1.0)


func _pick_target() -> void:
	var ids: Array = lesson().get("spots", []).map(func(s): return str(s["id"]))
	# 队长挑没冻住的地方
	var open := ids.filter(func(i): return not frozen.has(i))
	target = str((open if not open.is_empty() else ids).pick_random())
	decoy = ""
	warn_len = lerpf(1.0, 0.55, _progress())
	warn_t = warn_len
	if rng.randf() < 0.15 + 0.25 * _progress():
		var others := ids.filter(func(i): return i != target)
		decoy = str(others.pick_random())


## 挠一处：冻住了就没感觉；没冻就掉表情
func _strike(id: String, by: String) -> void:
	var sp := _spot_info(id)
	if frozen.has(id):
		blocked += 1
		cold += HIT_COLD
		var fr: Array = lesson().get("frozen", ["……"])
		say("princess", str(fr.pick_random()))
		tickle(by, str(sp.get("zone", "thigh")))
		if cold >= 100.0:
			_shiver()
		return
	hits += 1
	var caps: Array = lesson().get("hit", {}).get(id, [])
	hit(by, str(sp.get("zone", "thigh")), str(caps.pick_random()) if not caps.is_empty() else "")
	face -= HIT_FACE * (1.6 if sensitive_t > 0.0 else 1.0)
	if face <= 0.0:
		_mark()


func _shiver() -> void:
	shivers += 1
	frozen.clear()
	cold = 45.0
	face -= SHIVER
	busy = true
	await _lines(lesson().get("shiver", []))
	busy = false
	if face <= 0.0:
		_mark()


## 表情掉光：破功记一笔；三笔重来
func _mark() -> void:
	marks += 1
	face = 100.0
	busy = true
	await _lines(lesson().get("break", []))
	if marks >= MARKS:
		await redo()
	busy = false


func _on_break() -> void:
	super()
	await _mark()
