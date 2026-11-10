class_name TaskSweep
extends Node2D
## 第 2 天晚上 面包店奶奶「羽毛大扫除」（小镇里，烤炉后院 PILES 这几格）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/night.json 的 sweep。
##   扫：走到羽毛堆旁边（SWEEP_R 以内）按住 J，那一堆的量每秒 −SWEEP_RATE；全部扫光 = 做完（演 done：最后一阵风把整袋羽毛吹到她身上）。
##   （第九轮简化）起风：每 GUST_EVERY 秒左右先预警 GUST_WARN 秒——屋檐下的避风处（SHELTERS，Shelter 画的布篷）亮起来；
##     刮风那一下站在避风处（SHELTER_R 以内）= 一根羽毛也不沾；否则脚上的羽毛 +GUST_FEET（越往后越多）。随机一堆羽毛量 +GUST_REFILL。
##   脚上的羽毛：每根每秒闷笑 +FEATHER_RATE，每 FALL_EVERY 秒自己掉一根（不用按键）。
##   奶奶「帮忙」：每 GRANNY_EVERY 秒拿鸡毛掸子掸一下（演几句，挠腋下 / 腰 / 脚心）。闷笑到 FAIL_AT = 掉进羽毛堆（after_fail_sweep）。
##   羽毛堆（Pile）画在地面上面（z_index 1），量越少越小。
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
const SHELTERS := [Vector2i(45, 13), Vector2i(59, 13)]   # 屋檐下的避风处
const SHELTER_R := 20.0
const FALL_EVERY := 3.0
const GRANNY_EVERY := 14.0
const FAIL_AT := 0.95

var aborted := false
var started := false
var piles: Array = []
var feet := 0
var gusts := 0
var _gust_t := GUST_EVERY
var _warned := false
var _fall_t := FALL_EVERY
var shelters: Array = []
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
		p.global_position = Cells.to_world(PILES[i])
		piles.append(p)
	for c in SHELTERS:
		var sh := Shelter.new()
		sh.task = self
		get_parent().add_child(sh)
		sh.global_position = Cells.to_world(c)
		shelters.append(sh)
	_intro.call_deferred()


func _exit_tree() -> void:
	for p in piles + shelters:
		if is_instance_valid(p):
			p.queue_free()
	var pl := GameState.player
	if is_instance_valid(pl) and pl.has_meta(&"busy_hands"):
		pl.remove_meta(&"busy_hands")


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _say(data().get("intro", []))
	started = true


func _process(delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if Input.is_action_pressed("attack"):
		sweep(delta)
	# 脚上的羽毛自己慢慢掉
	if feet > 0:
		_fall_t -= delta
		if _fall_t <= 0.0:
			_fall_t = FALL_EVERY
			shake()
	else:
		_fall_t = FALL_EVERY
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
	var p0 := GameState.player
	if is_instance_valid(p0) and sheltered(p0.global_position):
		var ok: Array = data().get("shelter_ok", [])
		if not ok.is_empty():
			GameState.princess_reacted.emit(str(ok.pick_random()), 2.0)
	else:
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


## 站在避风处
func sheltered(at: Vector2) -> bool:
	return SHELTERS.any(func(c): return at.distance_to(Cells.to_world(c)) <= SHELTER_R)


## 要起风了（避风处亮起来）
func warning() -> bool:
	return _warned


## 脚上的羽毛掉一根（每 FALL_EVERY 秒自己掉）
func shake() -> void:
	if feet <= 0:
		return
	feet = maxi(0, feet - 1)
	GameState.vars["task_sweep_feet"] = feet
	var s: Array = data().get("shake", [])
	if not s.is_empty():
		GameState.princess_reacted.emit(str(s.pick_random()), 1.0)


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
		z_index = 1

	func _draw() -> void:
		if amount <= 0.0:
			return
		var k := 0.45 + 0.55 * amount / 100.0
		# 一小座软软的羽毛山：底下一圈淡影 + 一团白 / 粉 / 蓝的羽毛
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 15.0 * k, Color(0.2, 0.15, 0.25, 0.25))
		draw_circle(Vector2(0, -6), 13.0 * k, Color(1, 0.97, 1))
		draw_circle(Vector2(-6, -9), 7.0 * k, Color(1, 0.86, 0.94))
		draw_circle(Vector2(6, -10), 7.0 * k, Color(0.88, 0.92, 1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var cols := [Color(1, 0.98, 1), Color(1, 0.8, 0.92), Color(0.84, 0.9, 1)]
		for i in 12:
			var a := i * 0.55
			var r := 9.0 * k
			var p := Vector2(cos(a) * r * (0.4 + (i % 3) * 0.3), sin(a) * r * 0.45 - 5.0 * k)
			draw_line(p - Vector2(4, 1.5) * k, p + Vector2(4, -1.5) * k, Color(0.55, 0.45, 0.6), 3.0)
			draw_line(p - Vector2(4, 1.5) * k, p + Vector2(4, -1.5) * k, cols[i % 3], 2.0)


## 屋檐下的避风处：一块条纹布篷投下的影子；要起风时一闪一闪地亮
class Shelter extends Node2D:
	var task: Node
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var warn := task != null and bool(task.call("warning"))
		var a := 0.35 + (0.35 * (0.5 + 0.5 * sin(_t * 10.0)) if warn else 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 18.0, Color(0.95, 0.85, 0.5, a * 0.6) if warn else Color(0.1, 0.1, 0.15, 0.3))
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color(1, 0.9, 0.5, a + 0.2) if warn else Color(1, 1, 1, 0.25), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 布篷：红白条纹，撑在两根小木杆上
		draw_line(Vector2(-14, 0), Vector2(-14, -24), Color(0.45, 0.3, 0.2), 2.0)
		draw_line(Vector2(14, 0), Vector2(14, -24), Color(0.45, 0.3, 0.2), 2.0)
		for i in 4:
			var x0 := -16.0 + i * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x0, -28), Vector2(x0 + 8, -28), Vector2(x0 + 8, -22), Vector2(x0, -22)]),
				Color(0.85, 0.3, 0.35) if i % 2 == 0 else Color(1, 0.95, 0.9))