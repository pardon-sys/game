class_name RhythmLane
extends Control
## 音游音符条（篝火舞会排练用，以后的篝火跳舞也用它）：一条横向的轨道，↑↓←→ 的音符按谱面从右往左滑向左边的判定圈。
##   音符滑到判定圈时按对应的键（UP / DOWN / LEFT / RIGHT，也认 W / S / A / D）：差 PERFECT 秒以内 = perfect、GOOD 以内 = good；
##   按错键（判定窗口里最近的音符不是这个键）或者音符滑过判定圈都没按 = miss。每个判定发 judged(结果, 音符)。
##   谱面：chart = [{t 秒, key}]，用 make_chart(bpm, 拍数, 种子) 生成；advance(秒) 推进（暂停时不调就停住）。
##   jitter(秒)：音符上下抖一会儿（被羽毛围巾扫到时）。

signal judged(result: String, note: Dictionary)

const KEYS := ["LEFT", "DOWN", "UP", "RIGHT"]
const ALIAS := {"A": "LEFT", "S": "DOWN", "W": "UP", "D": "RIGHT"}
const GLYPH := {"LEFT": "←", "DOWN": "↓", "UP": "↑", "RIGHT": "→"}
const COLORS := {"LEFT": Color(1, 0.55, 0.7), "DOWN": Color(0.55, 0.8, 1), "UP": Color(0.6, 1, 0.65), "RIGHT": Color(1, 0.85, 0.45)}
const PERFECT := 0.07
const GOOD := 0.15
const JUDGE_X := 18.0

var chart: Array = []
var time := 0.0
## 音符从右边滑到判定圈要几秒
var travel := 1.6
var counts := {"perfect": 0, "good": 0, "miss": 0}
var _next := 0
var _jitter := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 谱面：bpm 拍速、beats 个音符；节奏型按种子在「一拍 / 半拍 / 两拍」里挑，开头留 lead 秒。
static func make_chart(bpm: float, beats: int, seed_v: int, lead := 1.2) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var beat := 60.0 / bpm
	var t := lead
	var out: Array = []
	var last := ""
	for i in beats:
		var k := str(KEYS[r.randi() % KEYS.size()])
		if k == last and r.randf() < 0.6:
			k = str(KEYS[(KEYS.find(k) + 1 + r.randi() % 3) % KEYS.size()])
		out.append({"t": t, "key": k, "hit": false})
		last = k
		var step := r.randf()
		t += beat * (0.5 if step < 0.2 and i > 2 else (2.0 if step > 0.85 else 1.0))
	return out


func load_chart(c: Array) -> void:
	chart = c.duplicate(true)
	time = 0.0
	_next = 0
	counts = {"perfect": 0, "good": 0, "miss": 0}
	queue_redraw()


func finished() -> bool:
	return _next >= chart.size()


func end_time() -> float:
	return float(chart[-1]["t"]) + GOOD + 0.4 if not chart.is_empty() else 0.0


func score() -> int:
	return int(counts["perfect"]) * 2 + int(counts["good"])


func max_score() -> int:
	return chart.size() * 2


func jitter(sec: float) -> void:
	_jitter = maxf(_jitter, sec)


func advance(delta: float) -> void:
	time += delta
	_jitter = maxf(0.0, _jitter - delta)
	_flash = maxf(0.0, _flash - delta)
	# 滑过判定圈没按：miss
	while _next < chart.size() and time - float(chart[_next]["t"]) > GOOD:
		_judge(_next, "miss")
	queue_redraw()


## 按键：返回判定结果（""= 判定窗口里没有音符，不算）
func press(k: String) -> String:
	k = str(ALIAS.get(k, k))
	if k not in KEYS or _next >= chart.size():
		return ""
	var n: Dictionary = chart[_next]
	var dt := absf(time - float(n["t"]))
	if dt > GOOD * 1.6:
		return ""
	if str(n["key"]) != k or dt > GOOD:
		_judge(_next, "miss")
		return "miss"
	var res := "perfect" if dt <= PERFECT else "good"
	_judge(_next, res)
	return res


func _judge(i: int, res: String) -> void:
	var n: Dictionary = chart[i]
	n["hit"] = res != "miss"
	n["res"] = res
	_next = i + 1
	counts[res] = int(counts[res]) + 1
	_flash = 0.18
	_flash_col = {"perfect": Color(1, 0.95, 0.5), "good": Color(0.6, 1, 0.7), "miss": Color(1, 0.4, 0.45)}[res]
	judged.emit(res, n)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cy := h * 0.5
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.06, 0.14, 0.85))
	draw_line(Vector2(0, 0), Vector2(w, 0), Color(0.5, 0.35, 0.55))
	draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color(0.5, 0.35, 0.55))
	# 判定圈
	var ring_col := _flash_col if _flash > 0.0 else Color(1, 1, 1, 0.7)
	draw_arc(Vector2(JUDGE_X, cy), h * 0.38, 0, TAU, 20, ring_col, 1.5)
	var span := w - JUDGE_X - 4.0
	for i in range(_next, chart.size()):
		var n: Dictionary = chart[i]
		var dt := float(n["t"]) - time
		if dt > travel:
			break
		var x := JUDGE_X + dt / travel * span
		var y := cy + (randf_range(-3.0, 3.0) if _jitter > 0.0 else 0.0)
		var k := str(n["key"])
		var col: Color = COLORS.get(k, Color.WHITE)
		draw_circle(Vector2(x, y), h * 0.32, col.darkened(0.55))
		draw_arc(Vector2(x, y), h * 0.32, 0, TAU, 16, col, 1.0)
		if _font:
			var g := str(GLYPH.get(k, "?"))
			var fs := int(h * 0.55)
			var sz := _font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(_font, Vector2(x - sz.x * 0.5, y + fs * 0.36), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
