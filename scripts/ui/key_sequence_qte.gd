class_name KeySequenceQTE
extends Node2D
## 头顶的按键序列 QTE（可复用；第八层夜迷宫的紫手靠近时弹出）：
##   KeySequenceQTE.start(目标角色, 按键个数, 限时, 提示晚出现的秒数) → await 它的 finished(成功)
##   一排按键（J / K / L / U / I / O 随机），按顺序按：按对一个亮一个；按错一个或超时就失败。下面一条限时条。
##   期间角色不能移动、别的动作也不触发（PlayerInputController.movement_locked / actions_locked）；结束或被提前释放时都会解开。
## delay：冷光很暗时提示晚一点才出现（这段时间也算在限时里）。

signal finished(ok: bool)

const KEYS := [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O]
const KEY_NAMES := {KEY_J: "J", KEY_K: "K", KEY_L: "L", KEY_U: "U", KEY_I: "I", KEY_O: "O"}
const BOX := 12.0

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


static func start(t: Node2D, count: int, limit: float, hint_delay := 0.0) -> KeySequenceQTE:
	var q := KeySequenceQTE.new()
	q.target = t
	for i in count:
		q.keys.append(KEYS.pick_random())
	q.time_limit = limit + hint_delay
	q.time_left = q.time_limit
	q.delay = hint_delay
	t.get_parent().add_child(q)
	return q


static func is_running() -> bool:
	return is_instance_valid(current) and not current._done


func _ready() -> void:
	current = self
	z_index = 20
	_font = ThemeDB.fallback_font
	PlayerInputController.actions_locked = true
	PlayerInputController.movement_locked = true
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	Audio.play("chime", -6.0, 0.0, 1.4)


func _exit_tree() -> void:
	if current == self:
		current = null
	if not _done:
		_unlock()


static func _unlock() -> void:
	PlayerInputController.actions_locked = false
	PlayerInputController.movement_locked = false


## 当前要按的键（测试用）。
func expected() -> int:
	return keys[index] if index < keys.size() else 0


## 按下一个键（测试也直接调它）。
func press(key: int) -> void:
	if _done or delay > 0.0:
		return
	if key == expected():
		index += 1
		Audio.play("pop", -8.0, 0.05, 1.0 + index * 0.1)
		if index >= keys.size():
			_finish(true)
	else:
		_shake = 0.3
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if _done or k == null or not k.pressed or k.echo:
		return
	if KEY_NAMES.has(k.physical_keycode):
		get_viewport().set_input_as_handled()
		press(k.physical_keycode)


func _process(delta: float) -> void:
	if _done:
		return
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -40)
	if GameState.in_dialogue:
		return
	delay = maxf(0.0, delay - delta)
	time_left -= delta
	_shake = maxf(0.0, _shake - delta)
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
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if delay > 0.0:
		return
	var w := keys.size() * (BOX + 3.0) - 3.0
	var x0 := -w / 2.0
	var off := Vector2(randf_range(-1, 1), 0) * (_shake * 6.0)
	for i in keys.size():
		var r := Rect2(Vector2(x0 + i * (BOX + 3.0), -BOX / 2.0) + off, Vector2(BOX, BOX))
		var done := i < index
		var cur := i == index
		draw_rect(r, Color(0.85, 0.6, 1.0, 0.95) if done else (Color(0.18, 0.1, 0.28, 0.92) if not cur else Color(0.35, 0.18, 0.5, 0.95)))
		draw_rect(r, Color(1, 0.85, 1.0) if cur else Color(0.6, 0.45, 0.8), false, 1.0)
		draw_string(_font, r.position + Vector2(3, 10), KEY_NAMES[keys[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.15, 0.05, 0.2) if done else Color(1, 0.95, 1.0))
	var bw := w * clampf(time_left / time_limit, 0.0, 1.0)
	draw_rect(Rect2(Vector2(x0, BOX / 2.0 + 2.0), Vector2(w, 2)), Color(0.2, 0.1, 0.25, 0.9))
	draw_rect(Rect2(Vector2(x0, BOX / 2.0 + 2.0), Vector2(bw, 2)), Color(0.9, 0.5, 1.0) if time_left > time_limit * 0.3 else Color(1, 0.4, 0.5))
