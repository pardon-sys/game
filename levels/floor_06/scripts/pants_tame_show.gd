class_name PantsTameShow
extends DrillShow
## 特训第二课「驯裤」：千手痒痒裤的小手出手前先比手势（gestures：抖 / 并拢 / 张开 / 打拍子，飘一句描写），
##   在窗口 window 秒内按对应的指令键（W 按住 / A 安抚 / S 冻住 / D 随它去）：
##     对了 → 听话度 +RIGHT_GAIN（「随它去」会被轻轻挠一下，然后小手安静 LET_QUIET 秒）；
##     错了 / 超时 → 小手当场挠（描写飘在小手旁边），听话度 −MISS。
##   越往后窗口越短、假手势（先比一个、半路换成另一个）越多；释放后敏感时假手势再多一些、窗口再短。
##   听话度到 goal = 出师。闷笑满 = 破功（演 break，听话度归零）。

const RIGHT_GAIN := 12.0
const MISS := 8.0
const LET_QUIET := 2.5

var obedience := 0.0
var gesture := {}
var fake := {}
var window := 1.6
var left := 0.0
var gap_t := 1.4
var rights := 0
var wrongs := 0
var breaks := 0
var _hand: Control


func lesson_id() -> String:
	return "tame"


func hint_text() -> String:
	return "看手势下指令：W 按住 / A 安抚 / S 冻住 / D 随它去"


class Hand extends Control:
	var show_ref: PantsTameShow
	func _draw() -> void:
		var g: Dictionary = show_ref.fake if not show_ref.fake.is_empty() else show_ref.gesture
		var w := size.x
		draw_rect(Rect2(0, 0, w, 6), Color(0.2, 0.14, 0.24))
		draw_rect(Rect2(0, 0, w * show_ref.obedience / show_ref.goal(), 6), Color(0.55, 0.85, 1.0))
		if g.is_empty():
			return
		var c := Vector2(w * 0.5, 22)
		var tt := Time.get_ticks_msec() * 0.012
		var col := Color(1, 0.75, 0.88)
		match str(g.get("id", "")):
			"shake":
				for i in 4:
					draw_line(c + Vector2(-12 + i * 8 + sin(tt * 3 + i) * 2, 6), c + Vector2(-12 + i * 8 + sin(tt * 3 + i) * 2, -6), col, 2.0)
			"close":
				for i in 4:
					draw_line(c + Vector2(-4 + i * 2.5, 6), c + Vector2(-4 + i * 2.5, -6), col, 2.0)
			"open":
				for i in 5:
					var a := -PI / 2 + (i - 2) * 0.5
					draw_line(c + Vector2(0, 6), c + Vector2(cos(a), sin(a)) * 10 + Vector2(0, 2), col, 2.0)
			"clap":
				var o := 3.0 + absf(sin(tt * 2)) * 6.0
				draw_line(c + Vector2(-o, 6), c + Vector2(-o, -6), col, 2.0)
				draw_line(c + Vector2(o, 6), c + Vector2(o, -6), col, 2.0)
		draw_rect(Rect2(0, 34, w * clampf(show_ref.left / maxf(0.01, show_ref.window), 0.0, 1.0), 3), Color(1, 0.85, 0.4))


func goal() -> float:
	return float(lesson().get("goal", 100))


func _build_extra() -> void:
	_hand = Hand.new()
	_hand.show_ref = self
	_hand.position = Vector2(2, 48)
	_hand.size = Vector2(panel_body.size.x - 4, 40)
	panel_body.add_child(_hand)


func _begin() -> void:
	super()
	obedience = 0.0
	gesture = {}
	fake = {}
	gap_t = 1.4
	_refresh()


func _refresh() -> void:
	if _info:
		_info.text = "听话度 %d / %d%s" % [int(obedience), int(goal()), ("\n释放后敏感！%d 秒" % ceili(sensitive_t)) if sensitive_t > 0.0 else ""]
	if _hand:
		_hand.queue_redraw()


func _gestures() -> Array:
	return lesson().get("gestures", [])


func _tick(delta: float) -> void:
	_common_tick(delta)
	if obedience >= goal():
		_done = true
		return
	if gesture.is_empty():
		gap_t -= delta
		if gap_t <= 0.0:
			_next_gesture()
	else:
		left -= delta
		if not fake.is_empty() and left <= window * 0.55:
			fake = {}
			narrate(str(gesture.get("show", "")), 1.4)   # 半路换成真的
		if left <= 0.0:
			_wrong()
	_refresh()


func _next_gesture() -> void:
	var gs := _gestures()
	var p := obedience / goal()
	gesture = gs[rng.randi() % gs.size()]
	window = lerpf(1.7, 0.85, p) * (0.8 if sensitive_t > 0.0 else 1.0)
	left = window
	fake = {}
	if rng.randf() < 0.12 + 0.28 * p + (0.2 if sensitive_t > 0.0 else 0.0):
		var others := gs.filter(func(g): return g != gesture)
		fake = others.pick_random()
	var g: Dictionary = fake if not fake.is_empty() else gesture
	narrate(str(g.get("show", "")), 1.4)


func _on_key(k: String) -> void:
	if gesture.is_empty() or k not in ["W", "A", "S", "D"]:
		return
	if not fake.is_empty():
		# 看着假手势就下了指令：按假手势判
		if str(fake.get("key", "")) == k and k != str(gesture.get("key", "")):
			_wrong()
			return
	if k == str(gesture.get("key", "")):
		_right()
	else:
		_wrong()


func _right() -> void:
	rights += 1
	obedience = minf(goal(), obedience + RIGHT_GAIN)
	if str(gesture.get("id", "")) == "clap":
		var lt: Array = lesson().get("let", [])
		hit("princess", "thigh", str(lt.pick_random()) if not lt.is_empty() else "", 0.03)
		gap_t = LET_QUIET
	else:
		var ob: Array = lesson().get("obey", ["……乖。"])
		say("princess", str(ob.pick_random()))
		Audio.play("pickup", -10.0, 0.1)
		gap_t = rng.randf_range(0.6, 1.2)
	gesture = {}
	fake = {}
	_refresh()


func _wrong() -> void:
	wrongs += 1
	var g := gesture
	gesture = {}
	fake = {}
	obedience = maxf(0.0, obedience - MISS)
	var hs: Array = g.get("hit", [])
	var wr: Array = lesson().get("wrong", [])
	if not wr.is_empty():
		narrate(str(wr.pick_random()), 1.2)
	if str(g.get("id", "")) == "clap":
		for z in ["thigh", "butt", "waist"]:
			tickle("princess", z)
	hit("princess", str(g.get("zone", "thigh")), str(hs.pick_random()) if not hs.is_empty() else "", 0.09)
	gap_t = rng.randf_range(0.8, 1.4)
	_refresh()



func _on_break() -> void:
	super()
	breaks += 1
	obedience = 0.0
	await _lines(lesson().get("break", []))
