class_name TaskSweep
extends Node2D
## 第 2 天晚上 面包店奶奶「羽毛大扫除」（小镇里，烤炉后院 PILES 这几格）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/night.json 的 sweep。
##   扫：站在羽毛堆旁边（SWEEP_R 以内）按住 J，那一堆的量每秒 −SWEEP_RATE；全部扫光 = 做完（演 done：最后一阵风把整袋羽毛吹到她身上）。
##   起风：每 GUST_EVERY 秒左右先预警 GUST_WARN 秒，再刮一阵：脚上的羽毛 +GUST_FEET（越往后越多），随机一堆羽毛量 +GUST_REFILL。
##   脚上的羽毛：每根每秒闷笑 +FEATHER_RATE；K 抖脚（掉 SHAKE_DROP 根，冷却 SHAKE_CD），按住 E PICK_TIME 秒抠出 PICK_DROP 根。
##   奶奶「帮忙」：每 GRANNY_EVERY 秒拿鸡毛掸子掸一下（演几句，挠腋下 / 腰 / 脚心）。
##   扫的时候两只手拿着扫帚（meta busy_hands：不攻击 / 冲刺）。闷笑到 FAIL_AT = 掉进羽毛堆（after_fail_sweep）。
## 状态：vars.task_sweep_left（每堆剩的量，失败不清）。测试：sweep(秒)、gust_now()、shake()、pick()。

signal finished(ok: bool)

const PILES := [Vector2i(47, 12), Vector2i(50, 14), Vector2i(53, 12), Vector2i(56, 14), Vector2i(49, 16), Vector2i(54, 16)]
const SWEEP_R := 20.0
const SWEEP_RATE := 34.0
const GUST_EVERY := 7.0
const GUST_WARN := 2.0
const GUST_FEET := 2
const GUST_REFILL := 25.0
const FEATHER_RATE := 0.012
const SHAKE_DROP := 1
const SHAKE_CD := 0.5
const PICK_TIME := 0.8
const PICK_DROP := 2
const GRANNY_EVERY := 14.0
const FAIL_AT := 0.95

var aborted := false
var started := false
var piles: Array = []
var feet := 0
var gusts := 0
var _gust_t := GUST_EVERY
var _warned := false
var _shake_cd := 0.0
var _pick_t := 0.0
var _granny_t := GRANNY_EVERY
var _granny_i := 0
var _say_t := 0.0
var _busy := false
var _emitted := false


static func data() -> Dictionary:
	return AfterNight.data().get("sweep", {})


static func reset_items() -> void:
	pass


static func status_text() -> String:
	var left: Array = GameState.vars.get("task_sweep_left", [])
	var n := left.filter(func(v): return float(v) > 0.0).size()
	return "还剩 %d 堆羽毛　脚上 %d 根　J 扫 / K 抖脚 / 按住 E 抠" % [n, int(GameState.vars.get("task_sweep_feet", 0))]


func _ready() -> void:
	if not GameState.vars.has("task_sweep_left"):
		GameState.vars["task_sweep_left"] = PILES.map(func(_c): return 100.0)
	for i in PILES.size():
		var p := Pile.new()
		p.amount = float(GameState.vars["task_sweep_left"][i])
		get_parent().add_child(p)
		p.global_position = Cutscene.cell_to_world(PILES[i])
		piles.append(p)
	_intro.call_deferred()


func _exit_tree() -> void:
	for p in piles:
		if is_instance_valid(p):
			p.queue_free()
	var pl := GameState.player
	if is_instance_valid(pl) and pl.has_meta(&"busy_hands"):
		pl.remove_meta(&"busy_hands")


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _say(data().get("intro", []))
	var pl := GameState.player
	if is_instance_valid(pl):
		pl.set_meta(&"busy_hands", true)
	started = true


func _process(delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if Input.is_action_pressed("attack"):
		sweep(delta)
	_shake_cd = maxf(0.0, _shake_cd - delta)
	if Input.is_action_just_pressed("dash"):
		shake()
	if Input.is_action_pressed("interact"):
		_pick_t += delta
		if _pick_t >= PICK_TIME:
			_pick_t = 0.0
			pick()
	else:
		_pick_t = 0.0
	# 脚上的羽毛一直挠
	if feet > 0 and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * FEATHER_RATE * feet * delta, p.laugh.max_value))
		_say_t -= delta
		if _say_t <= 0.0:
			_say_t = 2.0
			var fe: Dictionary = data().get("feet", {})
			var pool: Array = fe.get(_tier(), [])
			if not pool.is_empty():
				SpeechBubble.say(p, str(pool.pick_random()), 30.0, 1.4)
			ZoneFx.play("sole", p.get_parent(), ZoneFx.body_point(p, "sole"), 1.0, false)
	# 起风
	_gust_t -= delta
	if not _warned and _gust_t <= GUST_WARN:
		_warned = true
		var w: Array = data().get("gust_warn", [])
		if not w.is_empty():
			GameState.princess_reacted.emit(str(w.pick_random()), GUST_WARN)
	if _gust_t <= 0.0:
		gust_now()
	# 奶奶来帮忙
	_granny_t -= delta
	if _granny_t <= 0.0:
		_granny_t = GRANNY_EVERY
		_granny()
		return
	if p.laugh and p.laugh.value >= p.laugh.max_value * FAIL_AT:
		_emit(false)
		return
	_save()
	if piles.all(func(pl): return not is_instance_valid(pl) or pl.amount <= 0.0):
		_finish()


func _tier() -> String:
	var p := GameState.player
	var lr := p.laugh.ratio() if is_instance_valid(p) and p.laugh else 0.0
	return "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")


## 扫最近的一堆（秒）
func sweep(delta: float) -> void:
	var p := GameState.player
	var best: Pile = null
	for pl in piles:
		if is_instance_valid(pl) and pl.amount > 0.0 and pl.global_position.distance_to(p.global_position) < SWEEP_R:
			best = pl
	if best == null:
		return
	best.amount = maxf(0.0, best.amount - SWEEP_RATE * delta)
	best.queue_redraw()
	if randf() < delta * 4.0:
		Audio.play("brush", -14.0, 0.2)
	if best.amount <= 0.0:
		var d: Array = data().get("pile_done", [])
		if not d.is_empty():
			SpeechBubble.say(p, str(d.pick_random()), 30.0, 1.0)


func gust_now() -> void:
	gusts += 1
	_warned = false
	_gust_t = maxf(4.0, GUST_EVERY - gusts * 0.4)
	feet += GUST_FEET + gusts / 3
	GameState.vars["task_sweep_feet"] = feet
	var alive := piles.filter(func(pl): return is_instance_valid(pl))
	if not alive.is_empty():
		var pl: Pile = alive.pick_random()
		pl.amount = minf(100.0, pl.amount + GUST_REFILL)
		pl.queue_redraw()
	var g: Array = data().get("gust", [])
	if not g.is_empty():
		GameState.princess_reacted.emit(str(g.pick_random()), 2.4)
	Audio.play("wind", -6.0, 0.1)
	var p := GameState.player
	if is_instance_valid(p):
		Fx.burst(p.get_parent(), p.global_position + Vector2(0, -4), "feather", 10, 60.0, 0.6, Vector2(40, 10), Color(1, 0.95, 1))


## K：抖脚
func shake() -> void:
	if _shake_cd > 0.0 or feet <= 0:
		return
	_shake_cd = SHAKE_CD
	feet = maxi(0, feet - SHAKE_DROP)
	GameState.vars["task_sweep_feet"] = feet
	var s: Array = data().get("shake", [])
	if not s.is_empty():
		GameState.princess_reacted.emit(str(s.pick_random()), 1.0)


## 按住 E：把趾缝里的羽毛抠出来（自己也痒一下）
func pick() -> void:
	if feet <= 0:
		return
	feet = maxi(0, feet - PICK_DROP)
	GameState.vars["task_sweep_feet"] = feet
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * 0.03, p.laugh.max_value))
	var s: Array = data().get("pick", [])
	if not s.is_empty():
		GameState.princess_reacted.emit(str(s.pick_random()), 1.4)


func _granny() -> void:
	var gs: Array = data().get("granny", [])
	if gs.is_empty():
		return
	_busy = true
	await _say(gs[_granny_i % gs.size()])
	_granny_i += 1
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * 0.08, p.laugh.max_value * 0.94))
	_busy = false


func _save() -> void:
	GameState.vars["task_sweep_left"] = piles.map(func(pl): return pl.amount if is_instance_valid(pl) else 0.0)


func _finish() -> void:
	_busy = true
	await _say(data().get("done", []))
	_emit(true)


func _on_line(line: Dictionary) -> void:
	if line.has("tickle"):
		Cutscene._do({"do": "tickle", "who": "princess", "by": "after_granny", "zone": str(line["tickle"]), "fx": "feather", "repeat": 5, "interval": 0.2}, false)


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	if not Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.connect(_on_line)
	Dialogue.start_lines(lines, "task_sweep")
	while Dialogue.is_active():
		await get_tree().process_frame
	if Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.disconnect(_on_line)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	var pl := GameState.player
	if is_instance_valid(pl) and pl.has_meta(&"busy_hands"):
		pl.remove_meta(&"busy_hands")
	if ok:
		GameState.vars.erase("task_sweep_left")
		GameState.vars.erase("task_sweep_feet")
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 一堆羽毛（程序画：一团白 / 粉 / 蓝的羽毛，量越少越小）
class Pile extends Node2D:
	var amount := 100.0

	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		if amount <= 0.0:
			return
		var k := 0.35 + 0.65 * amount / 100.0
		var cols := [Color(1, 0.98, 1), Color(1, 0.82, 0.92), Color(0.86, 0.9, 1)]
		for i in 9:
			var a := i * 0.7
			var r := 7.0 * k
			var p := Vector2(cos(a) * r * (0.4 + (i % 3) * 0.3), sin(a) * r * 0.5 - 2)
			draw_line(p - Vector2(3, 1) * k, p + Vector2(3, -1) * k, cols[i % 3], 2.0)
