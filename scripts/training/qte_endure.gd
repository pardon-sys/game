extends TrainingStage
## 训练一：魔力疲倦忍耐（QTE）。公主被足枷台、夹腿枷台、刑床、挠痒坐垫固定，刑具本身一直在挠（魔力疲倦缓慢上涨）；
## 两名卫兵（左边的管左脚心 / 左大腿、右边的管右边）随机喊下一个挠的部位，可以连着喊好几个。
## 左边面板是要按的按键队列：按顺序按对（A 左脚心、D 右脚心、Q/J 左大腿内侧、E/K 右大腿内侧）就抵抗住，
## 队首的那一项有限时（start_time 秒，随成功次数缩短到 min_time）；按错或超时 → 卫兵挠中（必定暴击），魔力疲倦大涨。
## 成功越多，卫兵喊得越快、一次喊得越多。魔力疲倦满 → 惩罚小剧场 → 继续。成功一次 train_fatigue_up +1。

const PARTS := {
	"ls": {"name": "左脚心", "zone": "sole", "keys": ["A"], "label": "A", "guard": "g1"},
	"rs": {"name": "右脚心", "zone": "sole", "keys": ["D"], "label": "D", "guard": "g2"},
	"lt": {"name": "左大腿内侧", "zone": "thigh", "keys": ["Q", "J"], "label": "Q", "guard": "g1"},
	"rt": {"name": "右大腿内侧", "zone": "thigh", "keys": ["E", "K"], "label": "E", "guard": "g2"},
}
const CALLS := {
	"ls": ["左脚心！", "左边脚底——", "这边的脚心！"],
	"rs": ["右脚心！", "右边脚底——", "右脚，看招！"],
	"lt": ["左大腿！", "左边大腿内侧——", "这边的腿！"],
	"rt": ["右大腿！", "右边大腿内侧——", "右腿，看招！"],
}
## 刑具一直在挠：每秒涨上限的这个比例。
const PASSIVE_RATE := 0.004
## 按错 / 超时：魔力疲倦涨上限的这个比例（必定暴击）。
const CRIT_RATIO := 0.07
const MAX_QUEUE := 6

## 按键队列：每项 {part, time, max}；只有队首在倒计时。
var queue: Array[Dictionary] = []
## 还没喊出来的部位（一个卫兵连着喊时，按间隔一个个喊出来）。
var to_call: Array[String] = []
var fails := 0
var _call_t := 1.0
var _gap_t := 0.0
var _passive_t := 0.0
var _rows: VBoxContainer
var _timer_bar: ColorRect
var _shake_t := 0.0


func world_devices() -> Array:
	return ["stocks", "clamp", "supine", "cushion"]


func stage_cast() -> Dictionary:
	return {
		"princess": {"kind": "princess", "at": [PRINCESS_AT.x, PRINCESS_AT.y], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"supine": {"kind": "trap:supine", "at": device_at("supine")},
		"cushion": {"kind": "trap:cushion", "at": [0, PRINCESS_AT.y + 6]},
		"clamp": {"kind": "trap:clamp", "at": [0, PRINCESS_AT.y + 9]},
		"stocks": {"kind": "trap:stocks", "at": [0, PRINCESS_AT.y + 15]},
		"g1": {"kind": "npc:guard", "at": [-34, PRINCESS_AT.y + 2], "dir": "right"},
		"g2": {"kind": "npc:guard", "at": [34, PRINCESS_AT.y + 2], "dir": "left"},
	}


func intro_lines() -> Array:
	return [["保卫队员", "魔力疲倦忍耐训练，开始！刑具本身就会挠，我们俩再用特制的工具挠脚心和大腿内侧。"],
		["保卫队员", "听清我们喊哪里，就按对应的键绷住——A 左脚心、D 右脚心、Q 左大腿、E 右大腿（J / K 也行）。"],
		["公主", "……来、来吧！我会忍住的！"]]


func key_hint() -> String:
	return "A 左脚心　D 右脚心　Q/J 左大腿　E/K 右大腿"


func mood_ratio() -> float:
	return player.fatigue.ratio() if is_instance_valid(player) and player.fatigue else 0.0


func item_time() -> float:
	return maxf(float(stage_info.get("min_time", 0.35)), float(stage_info.get("start_time", 1.2)) * decay(0.975))


func call_gap() -> float:
	return maxf(0.12, 0.45 * decay(0.98))


func rest_time() -> float:
	return maxf(0.25, 1.4 * decay(0.97))


## 一次连喊几个：1 ~ (1 + 成功次数 × ramp / 6)，最多 4 个。
func burst_len() -> int:
	return rng.randi_range(1, mini(4, 1 + grow(6.0)))


func _enter_game() -> void:
	super()
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.size = panel_body.size
	panel_body.add_child(_rows)
	_timer_bar = ColorRect.new()
	_timer_bar.color = GOLD
	_timer_bar.size = Vector2(0, 2)
	panel_body.add_child(_timer_bar)
	_render()


func _tick(delta: float) -> void:
	# 刑具一直挠
	add_fatigue(PASSIVE_RATE * fatigue_max() * delta)
	_passive_t -= delta
	if _passive_t <= 0.0:
		_passive_t = 0.9
		var by: String = ["stocks", "clamp", "cushion", "supine"][rng.randi() % 4]
		tickle(by, {"stocks": "sole", "clamp": "thigh", "cushion": "butt", "supine": "waist"}[by])
		add_laugh(0.015 * laugh_max(), 0.9)
	# 卫兵喊部位
	if not to_call.is_empty():
		_gap_t -= delta
		if _gap_t <= 0.0:
			_call(to_call.pop_front())
			_gap_t = call_gap()
	elif queue.size() < MAX_QUEUE:
		_call_t -= delta
		if _call_t <= 0.0:
			var side := "g1" if rng.randf() < 0.5 else "g2"
			var n := burst_len()
			for i in n:
				var parts := PARTS.keys().filter(func(k): return PARTS[k]["guard"] == side) if rng.randf() < 0.7 else PARTS.keys()
				to_call.append(str(parts[rng.randi() % parts.size()]))
			_gap_t = 0.0
			_call_t = rest_time() + n * call_gap()
	# 队首倒计时
	if not queue.is_empty():
		queue[0]["time"] = float(queue[0]["time"]) - delta
		if float(queue[0]["time"]) <= 0.0:
			_fail("太慢了！")
	_update_timer()
	if _shake_t > 0.0:
		_shake_t -= delta
		panel.position.x = PANEL_RECT.position.x + (roundf(sin(_shake_t * 60.0) * 2.0) if _shake_t > 0.0 else 0.0)


func _call(part: String) -> void:
	var info: Dictionary = PARTS[part]
	var lines: Array = CALLS[part]
	say(str(info["guard"]), str(lines[rng.randi() % lines.size()]))
	Audio.play("swish", -8.0, 0.1, 1.2)
	queue.append({"part": part, "time": item_time(), "max": item_time()})
	_render()


func _on_key(k: String) -> void:
	var valid := false
	for p in PARTS.values():
		if k in p["keys"]:
			valid = true
	if not valid:
		return
	if queue.is_empty():
		return   # 卫兵还没喊：空按不算
	var head: Dictionary = queue[0]
	if k in PARTS[head["part"]]["keys"]:
		_success()
	else:
		_fail("按错了！")


func _success() -> void:
	var head: Dictionary = queue.pop_front()
	var info: Dictionary = PARTS[head["part"]]
	var g: CGActor = actors.get(info["guard"])
	if g:
		g.shake(0.15)
	pop(actors.get("princess"), "抵抗！", GOOD)
	Audio.play("chime", -8.0, 0.05, 1.0 + minf(successes, 40) * 0.01)
	_fly_out(str(info["label"]), GOOD, "✓")
	succeed("train_fatigue_up", float(t.get("per_success", {}).get("train_fatigue_up", 1)))
	_render()


func _fail(why: String) -> void:
	var head: Dictionary = queue.pop_front()
	var info: Dictionary = PARTS[head["part"]]
	fails += 1
	tickle(str(info["guard"]), str(info["zone"]), true)
	pop(actors.get(str(info["guard"])), why, BAD)
	add_fatigue(CRIT_RATIO * fatigue_max())
	add_laugh(0.06 * laugh_max(), 0.95)
	_fly_out(str(info["label"]), BAD, "✗")
	_shake_t = 0.25
	var pr: CGActor = actors.get("princess")
	if pr:
		pr.set_pose("helpless_2" if player.fatigue and player.fatigue.ratio() > 0.6 else "helpless_1", "helpless")
	_render()


func _after_punish(_kind: String) -> void:
	queue.clear()
	to_call.clear()
	_call_t = 1.5
	_render()


# ------------------------------------------------------------------ 面板
func _key_box(label: String, col: Color) -> Panel:
	var box := _border(Rect2(0, 0, 14, 12), col, Color(0.2, 0.14, 0.26))
	box.custom_minimum_size = Vector2(14, 12)
	var l := _label(col, 8)
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, -1)
	l.size = Vector2(14, 12)
	box.add_child(l)
	return box


func _render() -> void:
	if _rows == null:
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	if queue.is_empty():
		var w := _label(DIM, 8)
		w.text = "……等卫兵喊"
		_rows.add_child(w)
	for i in mini(queue.size(), MAX_QUEUE):
		var info: Dictionary = PARTS[queue[i]["part"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var col := GOLD if i == 0 else TEXT
		row.add_child(_key_box(str(info["label"]), col))
		var l := _label(col if i == 0 else DIM, 8)
		l.text = str(info["name"])
		row.add_child(l)
		_rows.add_child(row)
	_update_timer()


func _update_timer() -> void:
	if _timer_bar == null:
		return
	if queue.is_empty():
		_timer_bar.size.x = 0
		return
	var r := clampf(float(queue[0]["time"]) / maxf(float(queue[0]["max"]), 0.01), 0.0, 1.0)
	_timer_bar.position = Vector2(0, 13)
	_timer_bar.size.x = roundf((panel_body.size.x) * r)
	_timer_bar.color = GOOD.lerp(BAD, 1.0 - r)


## 处理完的那一项：带 ✓ / ✗ 从面板右边飞出去。
func _fly_out(label: String, col: Color, mark: String) -> void:
	var l := _label(col, 8)
	l.text = "%s %s" % [mark, label]
	l.position = PANEL_RECT.position + Vector2(PANEL_RECT.size.x - 30, 16)
	root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:x", l.position.x + 24, 0.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
