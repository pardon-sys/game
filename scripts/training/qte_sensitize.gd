extends TrainingStage
## 训练四：敏感部位强化（反射克制）。公主被选定部位的刑具固定，卫兵一直挠这个部位（闷笑持续上涨，这个训练就是要习惯被挠）。
## 身体会本能地想躲：左边面板弹出方向冲动（「想往左边躲！」←），要在限时内按相反的方向键（→，WASD 也行）把身体按住。
## 一段（约 3 秒）里会来 1 ~ 4 个冲动，全部按住算一次成功：train_sens_<部位> + per_success（一阶段每次 0.003，100 次练满 0.3）。
## 按错或超时 → 挣开了一下，这一段失败，闷笑上涨。越练冲动越多、限时越短、方向连着变。闷笑满 → 惩罚小剧场 → 继续。

const DIRS := {
	"LEFT": {"text": "想往左边躲！", "arrow": "←", "opposite": "RIGHT", "lean": Vector2(-4, 0)},
	"RIGHT": {"text": "想往右边躲！", "arrow": "→", "opposite": "LEFT", "lean": Vector2(4, 0)},
	"UP": {"text": "想缩起来！", "arrow": "↑", "opposite": "DOWN", "lean": Vector2(0, -3)},
	"DOWN": {"text": "想蹲下去！", "arrow": "↓", "opposite": "UP", "lean": Vector2(0, 3)},
}
const WASD := {"A": "LEFT", "D": "RIGHT", "W": "UP", "S": "DOWN"}
const SEGMENT_TIME := 3.0
const FAIL_RATIO := 0.12
## 卫兵一直挠：每 0.5 秒涨上限的这个比例（再乘部位倍率）。
const PASSIVE_RATIO := 0.008

## 这一段还没来的冲动（每项 {dir, at 第几秒出现}）、正在处理的冲动。
var pending: Array[Dictionary] = []
var current := {}
var seg_t := 0.0
var rest_t := 1.0
var fails := 0
var _passive_t := 0.0
var _arrow: Label
var _text: Label
var _timer_bar: ColorRect
var _dots: Label
var _seg_total := 0
var _seg_done := 0


func stage_cast() -> Dictionary:
	return {
		"princess": {"kind": "princess", "at": [PRINCESS_AT.x, PRINCESS_AT.y], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"device": {"kind": "trap:" + device_key, "at": device_at(device_key)},
		"g1": {"kind": "npc:guard", "at": [30, PRINCESS_AT.y - 2], "dir": "left"},
	}


func intro_lines() -> Array:
	var zn := TickleZones.zone_name(zone)
	return [["保卫队员", "敏感部位强化训练——我会一直挠%s，让身体记住这种感觉。" % zn],
		["保卫队员", "你的身体会忍不住想躲。想往哪边躲，就按反方向的键把自己按住，别乱动！"],
		["公主", "一、一直挠？！……我、我试试……"]]


func key_hint() -> String:
	return "按冲动的反方向（方向键 / WASD）把身体按住"


func impulse_time() -> float:
	return maxf(0.45, 1.1 * pow(0.98, successes))


func impulses_per_segment() -> int:
	return rng.randi_range(1, mini(4, 1 + successes / 5))


func _enter_game() -> void:
	super()
	_text = _label(TEXT, 8)
	_text.position = Vector2(0, 0)
	_text.size = Vector2(panel_body.size.x, 14)
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_text)
	_arrow = _label(GOLD, 24)
	_arrow.position = Vector2(30, 14)
	_arrow.size = Vector2(40, 32)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_body.add_child(_arrow)
	_timer_bar = ColorRect.new()
	_timer_bar.position = Vector2(0, 52)
	_timer_bar.size = Vector2(0, 3)
	panel_body.add_child(_timer_bar)
	_dots = _label(DIM, 8)
	_dots.position = Vector2(0, 62)
	panel_body.add_child(_dots)
	_show_idle()


func _start_segment() -> void:
	pending.clear()
	_seg_total = impulses_per_segment()
	_seg_done = 0
	var slot := SEGMENT_TIME / _seg_total
	var last := ""
	for i in _seg_total:
		var dirs := DIRS.keys()
		if last != "" and rng.randf() < 0.6:
			dirs.erase(last)   # 方向连着变
		var d := str(dirs[rng.randi() % dirs.size()])
		last = d
		pending.append({"dir": d, "at": i * slot + rng.randf_range(0.0, maxf(0.0, slot - impulse_time()) * 0.5)})
	seg_t = 0.0
	_update_dots()


func _tick(delta: float) -> void:
	# 卫兵一直挠
	_passive_t -= delta
	if _passive_t <= 0.0:
		_passive_t = 0.5
		tickle("g1" if rng.randf() < 0.6 else "device", zone)
		add_laugh(PASSIVE_RATIO * laugh_max() * TickleZones.zone_multiplier(zone))
	if rest_t > 0.0:
		rest_t -= delta
		if rest_t <= 0.0:
			_start_segment()
		return
	seg_t += delta
	if current.is_empty() and not pending.is_empty() and seg_t >= float(pending[0]["at"]):
		current = pending.pop_front()
		current["time"] = impulse_time()
		current["max"] = impulse_time()
		_show_impulse()
	if not current.is_empty():
		current["time"] = float(current["time"]) - delta
		var r := clampf(float(current["time"]) / float(current["max"]), 0.0, 1.0)
		_timer_bar.size.x = roundf(panel_body.size.x * r)
		_timer_bar.color = GOOD.lerp(BAD, 1.0 - r)
		if float(current["time"]) <= 0.0:
			_fail("来不及了……")
	elif pending.is_empty():
		_segment_success()


func _show_impulse() -> void:
	var info: Dictionary = DIRS[current["dir"]]
	_text.text = str(info["text"])
	_text.add_theme_color_override("font_color", PINK)
	_arrow.text = str(info["arrow"])
	_arrow.add_theme_color_override("font_color", GOLD)
	Audio.play("pop", -8.0, 0.1, 1.2)
	var p: CGActor = actors.get("princess")
	if p:
		var tw := p.create_tween()
		tw.tween_property(p, "position", PRINCESS_AT + Vector2(info["lean"]), 0.08)
		tw.tween_property(p, "position", PRINCESS_AT, 0.25)


func _show_idle() -> void:
	_text.text = "……忍住，别动"
	_text.add_theme_color_override("font_color", DIM)
	_arrow.text = ""
	_timer_bar.size.x = 0


func _update_dots() -> void:
	var s := ""
	for i in _seg_total:
		s += "●" if i < _seg_done else "○"
	_dots.text = "这一段 " + s


func _on_key(k: String) -> void:
	if WASD.has(k):
		k = WASD[k]
	if not DIRS.has(k) or current.is_empty():
		return
	if k == str(DIRS[current["dir"]]["opposite"]):
		_seg_done += 1
		_update_dots()
		_arrow.add_theme_color_override("font_color", GOOD)
		Audio.play("chime", -12.0, 0.05, 1.3)
		current = {}
		_text.text = "按住了！"
		_text.add_theme_color_override("font_color", GOOD)
		_timer_bar.size.x = 0
	else:
		_fail("往%s躲开了！" % {"LEFT": "左", "RIGHT": "右", "UP": "上", "DOWN": "下"}[str(current["dir"])] if k == str(current["dir"]) else "按错方向了！")


func _segment_success() -> void:
	pop(actors.get("princess"), "忍住了！", GOOD)
	Audio.play("chime", -8.0, 0.05, 1.0 + minf(successes, 40) * 0.01)
	succeed(TrainingStats.zone_key("train_sens", zone), float(t.get("per_success", {}).get("train_sens", 0.003)))
	_show_idle()
	rest_t = maxf(0.3, 0.9 * pow(0.97, successes))


func _fail(why: String) -> void:
	fails += 1
	current = {}
	pending.clear()
	tickle("g1", zone, true)
	pop(actors.get("g1"), why, BAD)
	add_laugh(FAIL_RATIO * laugh_max() * TickleZones.zone_multiplier(zone))
	_text.text = why
	_text.add_theme_color_override("font_color", BAD)
	_arrow.add_theme_color_override("font_color", BAD)
	_timer_bar.size.x = 0
	var p: CGActor = actors.get("princess")
	if p:
		p.shake(0.4)
		if player.laugh:
			p.set_pose("helpless_2" if player.laugh.ratio() > 0.7 else "helpless_1", "helpless")
	rest_t = 1.0


func _after_punish(_kind: String) -> void:
	current = {}
	pending.clear()
	rest_t = 1.2
	_show_idle()
