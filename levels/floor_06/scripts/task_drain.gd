class_name TaskDrain
extends Node2D
## 弥补任务「疏通排水管」（第 4 天早上，排水管 floor_06_after_drain）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/drain.json。
##   趴着爬：粉色公主挂 meta no_dash（不能冲刺，能攻击——可以打退老鼠）+ 状态 crawl（移速 ×0.45）。
##   三段：走到 SEG_AT[i] 演那一段的开场（第二段是管壁涂鸦）；走到堵塞（CLOGS，挡路的一团杂物）旁边按住 E 擦 SCRUB 秒 → 通了。
##   绒苔球（MossBall，MOSS 这些格）：碰到就贴在腿上蹭（闷笑上涨），按住 E WIPE 秒擦掉；第一次碰到演几句。
##   管口外的小孩抓脚（GRABS 这些格，各一次）：定身 + 挠（闷笑每秒 +GRAB_RATE），按 J 蹬 KICKS 下挣开（或者 GRAB_TIME 秒后松手）。
##   三处都通了 → 走到总闸 LEVER 按 E → 放水冲出去（演一段）→ 做完。闷笑到 FAIL_AT = 失败（after_fail_drain：被拖出管子）。
## 状态：vars.task_drain_cleared（通了几处，失败不清：从通到的地方接着来）。
## 测试：scrub(秒)、wipe(秒)、kick()、grab_now()、pull_lever()。

signal finished(ok: bool)

const PATH := "res://data/after/drain.json"
const SEG_AT := [Vector2i(5, 12), Vector2i(14, 7), Vector2i(26, 11)]
const CLOGS := [Vector2i(12, 12), Vector2i(24, 6), Vector2i(34, 17)]
const LEVER := Vector2i(36, 12)
const MOSS := [Vector2i(9, 12), Vector2i(14, 9), Vector2i(18, 6), Vector2i(21, 6), Vector2i(26, 9), Vector2i(26, 14), Vector2i(29, 17), Vector2i(31, 17)]
const GRABS := [Vector2i(7, 12), Vector2i(14, 10), Vector2i(20, 6), Vector2i(26, 13), Vector2i(32, 17)]
const SCRUB := 2.5
const WIPE := 0.8
const KICKS := 5
const GRAB_TIME := 4.0
const GRAB_RATE := 0.1
const MOSS_RATE := 0.08
const FAIL_AT := 0.95
const NEAR := 16.0

static var _data := {}

var aborted := false
var started := false
var clogs: Array = []
var moss: Array = []
var grabbed := false
var grabs_done := 0
var kicks := 0
var moss_seen := false
var scrub_t := 0.0
var _seg_seen := {}
var _grabs_left: Array = []
var _grab_t := 0.0
var _say_t := 0.0
var _clog_lines := {}
var _emitted := false
var _busy := false


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func cleared() -> int:
	return int(GameState.vars.get("task_drain_cleared", 0))


static func reset_items() -> void:
	pass   # 通了的地方不用重通


static func status_text() -> String:
	return "通了 %d / 3 处%s" % [cleared(), "　去最里面拉总闸！" if cleared() >= 3 else ""]


func _ready() -> void:
	for i in CLOGS.size():
		if i >= cleared():
			var c := Clog.new()
			c.name = "Clog_%d" % i
			get_parent().add_child(c)
			c.global_position = Cells.to_world(CLOGS[i])
			clogs.append(c)
		else:
			clogs.append(null)
	for m in MOSS:
		var b := MossBall.new()
		get_parent().add_child(b)
		b.global_position = Cells.to_world(m)
		moss.append(b)
	_grabs_left = GRABS.duplicate()
	_crawl(true)
	_intro.call_deferred()


func _exit_tree() -> void:
	_crawl(false)
	for n in clogs + moss:
		if is_instance_valid(n):
			n.queue_free()


func _crawl(on: bool) -> void:
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if on:
		p.set_meta(&"no_dash", true)
		p.add_buff("crawl", -1.0)
	else:
		if p.has_meta(&"no_dash"):
			p.remove_meta(&"no_dash")
		p.remove_buff("crawl")


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _say(data().get("intro_lines", []))
	started = true


func _process(delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	var pos := p.global_position
	# 段落开场
	for i in SEG_AT.size():
		if not _seg_seen.has(i) and pos.distance_to(Cells.to_world(SEG_AT[i])) < NEAR:
			_seg_seen[i] = true
			_busy = true
			await _say(_seg(i).get("start", []))
			_busy = false
			return
	# 被抓脚
	if grabbed:
		_grab_tick(delta)
	else:
		for g in _grabs_left.duplicate():
			if pos.distance_to(Cells.to_world(g)) < NEAR * 0.8:
				_grabs_left.erase(g)
				grab_now()
				return
	# 绒苔球
	var stuck := false
	for b in moss:
		if not is_instance_valid(b):
			continue
		var mb := b as MossBall
		if mb.stuck:
			stuck = true
			mb.global_position = pos + Vector2(-6, 2)
			_tick_laugh(MOSS_RATE * delta)
			_say_t -= delta
			if _say_t <= 0.0:
				_say_t = 1.6
				var mo: Dictionary = data().get("moss", {})
				var caps: Array = mo.get("caption", [])
				if not caps.is_empty():
					SpeechBubble.say(mb, str(caps.pick_random()), 16.0, 1.6)
				var rs: Array = mo.get("react", [])
				if not rs.is_empty():
					SpeechBubble.say(p, str(rs.pick_random()), 30.0, 1.2)
			if Input.is_action_pressed("interact"):
				wipe(delta)
		elif pos.distance_to(mb.global_position) < 10.0:
			mb.stuck = true
			if not moss_seen:
				moss_seen = true
				_busy = true
				await _say(data().get("moss", {}).get("first", []))
				_busy = false
				return
	# 擦堵塞
	if not stuck:
		for i in clogs.size():
			var c: Node2D = clogs[i]
			if not is_instance_valid(c) or pos.distance_to(c.global_position) > NEAR + 4.0:
				continue
			if not _clog_lines.has(i):
				_clog_lines[i] = true
				_busy = true
				await _say(_seg(i).get("clog", []))
				_busy = false
				return
			if Input.is_action_pressed("interact"):
				scrub(delta)
	# 总闸
	if cleared() >= CLOGS.size() and Input.is_action_just_pressed("interact") and pos.distance_to(Cells.to_world(LEVER)) < NEAR + 6.0:
		pull_lever()
		return
	if p.laugh and p.laugh.value >= p.laugh.max_value * FAIL_AT:
		_emit(false)


func _seg(i: int) -> Dictionary:
	var ss: Array = data().get("segments", [])
	return ss[i] if i < ss.size() else {}


func _tick_laugh(ratio: float) -> void:
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * ratio, p.laugh.max_value))


## 擦最近的堵塞（秒）；擦够了 → 通了
func scrub(delta: float) -> void:
	var p := GameState.player
	var c: Clog = null
	for i in clogs.size():
		var cc: Node2D = clogs[i]
		if is_instance_valid(cc) and (c == null or cc.global_position.distance_to(p.global_position) < c.global_position.distance_to(p.global_position)):
			c = cc
	if c == null:
		return
	c.progress += delta / SCRUB
	c.queue_redraw()
	if randf() < delta * 3.0:
		Audio.play("brush", -12.0, 0.2)
	if c.progress >= 1.0:
		var i := clogs.find(c)
		clogs[i] = null
		c.queue_free()
		GameState.vars["task_drain_cleared"] = cleared() + 1
		Audio.play("water_release", -6.0)
		_busy = true
		await _say(_seg(i).get("done", []))
		_busy = false


## 擦掉贴着的绒苔球（秒）
func wipe(delta: float) -> void:
	for b in moss:
		if is_instance_valid(b) and (b as MossBall).stuck:
			var mb := b as MossBall
			mb.wipe += delta
			if mb.wipe >= WIPE:
				var w: Array = data().get("moss", {}).get("wipe", ["擦掉了！"])
				SpeechBubble.say(GameState.player, str(w.pick_random()), 30.0, 1.0)
				mb.queue_free()
			return


## 管口外的小孩抓住脚
func grab_now() -> void:
	var p := GameState.player
	grabbed = true
	kicks = 0
	_grab_t = GRAB_TIME
	var gs: Array = data().get("feet", {}).get("grab", [])
	if is_instance_valid(p) and p.status:
		p.status.apply_root(GRAB_TIME + 0.5)
	if not gs.is_empty():
		_busy = true
		await _say(gs[grabs_done % gs.size()])
		_busy = false
	grabs_done += 1


func _grab_tick(delta: float) -> void:
	var p := GameState.player
	_grab_t -= delta
	_tick_laugh(GRAB_RATE * delta)
	_say_t -= delta
	if _say_t <= 0.0:
		_say_t = 1.4
		var fe: Dictionary = data().get("feet", {})
		var lr := p.laugh.ratio() if p.laugh else 0.0
		var pool: Array = fe.get("react", {}).get("light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy"), [])
		if not pool.is_empty():
			SpeechBubble.say(p, str(pool.pick_random()), 30.0, 1.2)
		ZoneFx.play("sole", p.get_parent(), ZoneFx.body_point(p, "sole"), 1.0, false)
		HitFx.play("hand", p.get_parent(), p.global_position + Vector2(randf_range(-4, 4), 0))
		Audio.play("tickle", -8.0, 0.1)
	if Input.is_action_just_pressed("attack"):
		kick()
	if _grab_t <= 0.0:
		_release_grab()


## J：蹬一下
func kick() -> void:
	if not grabbed:
		return
	kicks += 1
	GameState.player.shake(0.12)
	if kicks >= KICKS:
		var k: Array = data().get("feet", {}).get("kick", ["（蹬开了）"])
		SpeechBubble.say(GameState.player, str(k.pick_random()), 30.0, 1.2)
		_release_grab()


func _release_grab() -> void:
	grabbed = false
	var p := GameState.player
	if is_instance_valid(p) and p.status:
		p.status.clear_root()


## 拉总闸：放水冲出去 → 做完
func pull_lever() -> void:
	_busy = true
	Audio.play("water_release", -2.0)
	await _say(data().get("flush", []))
	_emit(true)


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_drain")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	_crawl(false)
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 堵塞（一团杂物，挡路；擦的时候画进度）
class Clog extends StaticBody2D:
	var progress := 0.0

	func _ready() -> void:
		collision_layer = 1
		var sh := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 12)
		sh.shape = r
		add_child(sh)

	func _draw() -> void:
		var k := 1.0 - progress * 0.7
		draw_circle(Vector2(0, -2), 8.0 * k, Color(0.36, 0.3, 0.24))
		draw_circle(Vector2(-4, -4), 4.0 * k, Color(0.5, 0.42, 0.34))
		draw_circle(Vector2(4, 0), 3.5 * k, Color(0.9, 0.7, 0.85))     # 痒痒粉泡沫
		draw_line(Vector2(-6, 2), Vector2(6, -6), Color(0.95, 0.92, 0.85), 1.0)   # 羽毛
		if progress > 0.0:
			draw_rect(Rect2(-8, -14, 16, 2), Color(0.2, 0.15, 0.25))
			draw_rect(Rect2(-8, -14, 16 * progress, 2), Color(0.5, 0.9, 0.6))


## 绒苔球（毛茸茸的绿色毛团，碰到就贴上来）
class MossBall extends Node2D:
	var stuck := false
	var wipe := 0.0
	var _t := randf() * 3.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := 1.0 + sin(_t * 4.0) * 0.08
		draw_circle(Vector2(0, -4), 5.5 * s, Color(0.36, 0.62, 0.32))
		for i in 10:
			var a := TAU * i / 10.0 + _t * 0.6
			draw_line(Vector2(0, -4) + Vector2(cos(a), sin(a)) * 4.0 * s, Vector2(0, -4) + Vector2(cos(a), sin(a)) * 7.0 * s, Color(0.55, 0.82, 0.45), 1.0)
		draw_circle(Vector2(-1.5, -5), 0.8, Color(0.1, 0.15, 0.1))
		draw_circle(Vector2(1.5, -5), 0.8, Color(0.1, 0.15, 0.1))
