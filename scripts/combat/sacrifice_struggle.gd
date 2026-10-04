class_name SacrificeStruggle
extends Node
## 献祭挣扎（第八层阶段三，被抓进巢穴的那个人）：挂在她身上，玩家在右边小窗里按 ← → 交替连按挣扎。
##   闷笑值（她自己的 LaughMeter）按时间上涨，被抓越久涨得越快：每秒 BASE_RATE × (1 + ACCEL × 被抓秒数)。
##   ← → 交替按一次降 PRESS（同一个键连按不算）。
##   降到憋笑以下（giggle_threshold）→ escaped（挣脱）；涨满（max_value）→ broke（她笑倒，阶段三直接战败）。
##   开始时闷笑值至少是憋笑线 + START_MARGIN（一被抓就在憋笑段里）。
## overlay() 返回小窗里叠的界面：三段条（闷笑 / 失控 1 / 失控 2）+ 按键提示。

signal escaped
signal broke

const BASE_RATE := 5.0
const ACCEL := 0.08
const PRESS := 2.6
const START_MARGIN := 12.0

var who: PlayableCharacter
var held_time := 0.0
var presses := 0
var _last_dir := 0
var _prev_l := false
var _prev_r := false
var _fx := 0.0
var _done := false
var _bar: Control


static func start(c: PlayableCharacter) -> SacrificeStruggle:
	var s := SacrificeStruggle.new()
	s.name = "SacrificeStruggle"
	s.who = c
	c.add_child(s)
	return s


func _ready() -> void:
	var lm := who.laugh
	if lm:
		lm.set_value(maxf(lm.value, lm.giggle_threshold + START_MARGIN))


## 一次挣扎输入：dir = -1（←）或 1（→）。和上一次方向相同不算。测试也直接调它。
func press(dir: int) -> bool:
	if _done or dir == _last_dir or dir == 0:
		return false
	_last_dir = dir
	presses += 1
	who.laugh.set_value(who.laugh.value - PRESS)
	who.shake(0.05)
	return true


func rate() -> float:
	return BASE_RATE * (1.0 + ACCEL * held_time)


func _process(delta: float) -> void:
	if _done or not is_instance_valid(who) or GameState.in_dialogue or get_tree().paused:
		return
	held_time += delta
	var l := Input.is_physical_key_pressed(KEY_LEFT)
	var r := Input.is_physical_key_pressed(KEY_RIGHT)
	if l and not _prev_l:
		press(-1)
	if r and not _prev_r:
		press(1)
	_prev_l = l
	_prev_r = r
	var lm := who.laugh
	lm.notify_attacked()   # 一直在被挠：不自然回落
	var v := lm.value + rate() * delta
	if v >= lm.max_value:
		lm.set_value(lm.max_value - 0.01)
		_finish(false)
		return
	lm.set_value(v)
	# 被挠的表现：羽毛、手指、她自己的反应
	_fx -= delta
	if _fx <= 0.0:
		_fx = 0.5
		Fx.burst(who.get_parent(), who.global_position + Vector2(randf_range(-8, 8), -10), "feather", 2, 30.0, 0.4, Vector2(0, 20))
		Characters.scope(who.character_id)
		var lines := ReactionDB.lines("thousand_hand", lm.stage())
		Characters.unscope()
		if not lines.is_empty() and randf() < 0.3:
			SpeechBubble.say(who, str(lines.pick_random()).left(10), 26.0)
		if who.emotion:
			who.emotion.request(lm.stage() if lm.stage() != "calm" else "giggle", 0.6, false)
	if lm.value < lm.giggle_threshold:
		_finish(true)


func _finish(ok: bool) -> void:
	_done = true
	if ok:
		escaped.emit()
	else:
		broke.emit()
	queue_free()


## 小窗里叠的界面：上面一行三段条（憋笑 / 失控 1 / 失控 2）+ 当前位置的指针。
func overlay() -> Control:
	var root := Control.new()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 0.75)
	bg.position = Vector2(6, 4)
	bg.size = Vector2(164, 14)
	root.add_child(bg)
	_bar = Control.new()
	_bar.position = Vector2(8, 6)
	_bar.size = Vector2(160, 10)
	_bar.draw.connect(_draw_bar)
	root.add_child(_bar)
	root.set_process(true)
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(func(): if is_instance_valid(_bar): _bar.queue_redraw())
	root.add_child(timer)
	return root


func _draw_bar() -> void:
	if not is_instance_valid(who) or who.laugh == null:
		return
	var lm := who.laugh
	var w := _bar.size.x
	var segs := [[lm.giggle_threshold, lm.helpless_threshold, Color(1, 0.75, 0.4), "憋笑"],
		[lm.helpless_threshold, lm.helpless_stage2_threshold, Color(1, 0.5, 0.6), "失控1"],
		[lm.helpless_stage2_threshold, lm.max_value, Color(0.95, 0.25, 0.4), "失控2"]]
	var lo := lm.giggle_threshold
	var span := lm.max_value - lo
	for s in segs:
		var x0 := (float(s[0]) - lo) / span * w
		var x1 := (float(s[1]) - lo) / span * w
		_bar.draw_rect(Rect2(x0, 0, x1 - x0 - 1, 10), (s[2] as Color).darkened(0.45))
		_bar.draw_string(ThemeDB.fallback_font, Vector2(x0 + 2, 8), str(s[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))
	var x := clampf((lm.value - lo) / span, 0.0, 1.0) * w
	_bar.draw_rect(Rect2(0, 8, x, 2), Color(1, 0.9, 0.95))
	_bar.draw_rect(Rect2(x - 1, -2, 2, 14), Color(1, 1, 1))
