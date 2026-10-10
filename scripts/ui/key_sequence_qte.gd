class_name KeySequenceQTE
extends Node2D
## 按键序列 QTE（可复用；第八层夜迷宫的紫手靠近时弹出）：
##   KeySequenceQTE.start(目标角色, 按键个数, 限时, 提示晚出现的秒数) → await 它的 finished(成功)
##   一排大按键（数字 1~4 随机，小键盘的 1~4 也算），按顺序按：按对一个爆一圈光；按错一个或超时就失败。下面一条粗的限时条。
##   画在屏幕空间（自己的 CanvasLayer），跟着目标在屏幕上的位置（等距画面也对），在她头顶上方。
##   紧急感：按键一个个弹出、当前键脉动；剩 40% 起限时条变红闪烁、整排越抖越厉害、屏幕四周泛红，心跳声越来越快。
##   期间角色不能移动、别的动作也不触发（PlayerInputController.movement_locked / actions_locked）；结束或被提前释放时都会解开。
## delay：冷光很暗时提示晚一点才出现（这段时间也算在限时里）。

signal finished(ok: bool)

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const KEY_NAMES := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4"}
## 小键盘也算
const KEYPAD := {KEY_KP_1: KEY_1, KEY_KP_2: KEY_2, KEY_KP_3: KEY_3, KEY_KP_4: KEY_4}
const BOX := 26.0
const GAP := 6.0
const LAYER := 11
## 剩多少比例的时间开始「紧急」
const URGENT := 0.4
const POP_TIME := 0.08

static var current: KeySequenceQTE

var target: Node2D
var keys: Array[int] = []
var index := 0
var time_limit := 2.0
var time_left := 2.0
var delay := 0.0
var _done := false
var _shake := 0.0
var _font: Font
var _age := 0.0
var _beat_t := 0.0
## 按对时每个键的光圈（0 → 1 扩散）
var _bursts := {}
var _layer: CanvasLayer


static func start(t: Node2D, count: int, limit: float, hint_delay := 0.0) -> KeySequenceQTE:
	var q := KeySequenceQTE.new()
	q.target = t
	for i in count:
		q.keys.append(KEYS.pick_random())
	q.time_limit = limit + hint_delay
	q.time_left = q.time_limit
	q.delay = hint_delay
	var layer := CanvasLayer.new()
	layer.name = "QTELayer"
	layer.layer = LAYER
	q._layer = layer
	layer.add_child(q)
	t.get_parent().add_child(layer)
	return q


static func is_running() -> bool:
	return is_instance_valid(current) and not current._done


func _ready() -> void:
	current = self
	_font = ThemeDB.fallback_font
	PlayerInputController.actions_locked = true
	PlayerInputController.movement_locked = true
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	Audio.play("chime", -6.0, 0.0, 1.4)
	_follow()


func _exit_tree() -> void:
	if current == self:
		current = null
	if not _done:
		_unlock()
	# 自己的图层跟着走（被提前释放时也是）
	if is_instance_valid(_layer) and not _layer.is_queued_for_deletion():
		_layer.queue_free()


static func _unlock() -> void:
	PlayerInputController.actions_locked = false
	PlayerInputController.movement_locked = false


## 当前要按的键（测试用）。
func expected() -> int:
	return keys[index] if index < keys.size() else 0


## 按下一个键（测试也直接调它）。小键盘的键按数字算。
func press(key: int) -> void:
	if _done or delay > 0.0:
		return
	key = KEYPAD.get(key, key)
	if key == expected():
		_bursts[index] = 0.0
		index += 1
		Audio.play("pop", -6.0, 0.05, 1.0 + index * 0.12)
		if index >= keys.size():
			_finish(true)
	else:
		_shake = 0.35
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if _done or k == null or not k.pressed or k.echo:
		return
	var code := int(KEYPAD.get(k.physical_keycode, k.physical_keycode))
	if not KEY_NAMES.has(code):
		code = int(KEYPAD.get(k.keycode, k.keycode))
	if KEY_NAMES.has(code):
		get_viewport().set_input_as_handled()
		press(code)


## 剩下的时间比例（0~1）
func ratio() -> float:
	return clampf(time_left / time_limit, 0.0, 1.0)


func is_urgent() -> bool:
	return ratio() < URGENT


func _follow() -> void:
	if not is_instance_valid(target):
		return
	var vp := get_viewport().get_visible_rect().size
	var p := IsoView.canvas_pos(target) + Vector2(0, -62)
	var half := (keys.size() * (BOX + GAP)) / 2.0 + 8.0
	position = Vector2(clampf(p.x, half, vp.x - half), clampf(p.y, 30.0, vp.y - 40.0))


func _process(delta: float) -> void:
	for i in _bursts.keys():
		_bursts[i] += delta * 3.0
		if _bursts[i] >= 1.0:
			_bursts.erase(i)
	if _done:
		queue_redraw()
		return
	_follow()
	if GameState.in_dialogue:
		return
	_age += delta
	delay = maxf(0.0, delay - delta)
	time_left -= delta
	_shake = maxf(0.0, _shake - delta)
	# 心跳：越到后面越快（0.55 秒 → 0.2 秒一下）
	if delay <= 0.0:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = lerpf(0.2, 0.55, ratio())
			Audio.play("heartbeat", lerpf(-2.0, -10.0, ratio()), 0.0, lerpf(1.25, 1.0, ratio()))
	if time_left <= 0.0:
		_finish(false)
	queue_redraw()


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	_unlock()
	Audio.play("chime" if ok else "fizzle", -6.0, 0.0, 1.6 if ok else 1.0)
	finished.emit(ok)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _draw() -> void:
	_draw_vignette()
	if delay > 0.0:
		return
	var n := keys.size()
	var w := n * (BOX + GAP) - GAP
	var x0 := -w / 2.0
	var urgent := is_urgent()
	var shake_amt := _shake * 10.0 + (pow(1.0 - ratio() / URGENT, 2.0) * 3.0 if urgent else 0.0)
	var off := Vector2(randf_range(-1, 1), randf_range(-0.4, 0.4)) * shake_amt
	# 底板
	var panel := Rect2(Vector2(x0 - 8, -BOX / 2.0 - 8) + off, Vector2(w + 16, BOX + 26))
	var flash := urgent and int(_age * 8.0) % 2 == 0
	draw_rect(panel, Color(0.1, 0.03, 0.12, 0.82))
	draw_rect(panel, Color(1, 0.3, 0.35) if flash else Color(0.85, 0.55, 1.0), false, 2.0)
	# 「!!」
	var bang := "!!" if urgent else "!"
	draw_string(_font, panel.position + Vector2(panel.size.x / 2.0 - 8, -4), bang, HORIZONTAL_ALIGNMENT_CENTER, 16, 16,
		Color(1, 0.35, 0.35) if flash or not urgent else Color(1, 0.9, 0.4))
	for i in n:
		# 一个个弹出：第 i 个在 i * POP_TIME 秒后长出来（带回弹）
		var t := clampf((_age - i * POP_TIME) / 0.16, 0.0, 1.0)
		if t <= 0.0:
			continue
		var s := _back_out(t)
		var done := i < index
		var cur := i == index and not _done
		if cur:
			s *= 1.0 + 0.1 * sin(_age * 18.0)
		var c := Vector2(x0 + i * (BOX + GAP) + BOX / 2.0, 0) + off
		var size := Vector2(BOX, BOX) * s
		var r := Rect2(c - size / 2.0, size)
		var fill := Color(0.95, 0.75, 1.0) if done else (Color(0.55, 0.15, 0.6) if cur else Color(0.22, 0.08, 0.3))
		if cur and urgent:
			fill = Color(0.75, 0.12, 0.25) if flash else Color(0.55, 0.12, 0.45)
		draw_rect(r, fill)
		draw_rect(r, Color(1, 0.95, 1.0) if cur else Color(0.7, 0.5, 0.9), false, 2.0 if cur else 1.0)
		if s > 0.4:
			var fs := int(round(18.0 * s))
			draw_string_outline(_font, c + Vector2(-size.x / 2.0, fs * 0.36), KEY_NAMES[keys[i]], HORIZONTAL_ALIGNMENT_CENTER, size.x, fs,
				3, Color(0.12, 0.02, 0.15))
			draw_string(_font, c + Vector2(-size.x / 2.0, fs * 0.36), KEY_NAMES[keys[i]], HORIZONTAL_ALIGNMENT_CENTER, size.x, fs,
				Color(0.2, 0.05, 0.25) if done else Color(1, 0.97, 1.0))
		if _bursts.has(i):
			var b: float = _bursts[i]
			draw_arc(c, BOX * (0.6 + b * 0.9), 0, TAU, 24, Color(1, 0.9, 1.0, 1.0 - b), 2.0)
	# 限时条
	var bar := Rect2(Vector2(x0, BOX / 2.0 + 5.0) + off, Vector2(w, 5))
	draw_rect(bar, Color(0.18, 0.06, 0.2, 0.95))
	var col := Color(0.9, 0.5, 1.0)
	if urgent:
		col = Color(1, 0.25, 0.3) if flash else Color(1, 0.55, 0.3)
	draw_rect(Rect2(bar.position, Vector2(w * ratio(), 5)), col)


## 紧急时屏幕四周泛红（越到后面越红）。
func _draw_vignette() -> void:
	if _done or delay > 0.0:
		return
	var k := 0.25 + 0.75 * (1.0 - ratio())
	var a := k * (0.32 + 0.12 * sin(_age * 14.0))
	var vp := get_viewport().get_visible_rect().size
	var o := -position
	for i in 6:
		var inset := i * 5.0
		draw_rect(Rect2(o + Vector2(inset, inset), vp - Vector2(inset, inset) * 2.0), Color(0.9, 0.05, 0.15, a * (1.0 - i / 6.0) * 0.5), false, 5.0)


static func _back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
