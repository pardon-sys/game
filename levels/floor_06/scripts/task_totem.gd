class_name TaskTotem
extends Node2D
## 弥补任务「修补狂欢图腾柱」（第 7 天，图腾柱废地 floor_06_after_totem）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/totem.json。
##   三块封印石（采石角 QUARRY）一块一块扛到图腾柱底座（TOTEM 附近 PLACE_R 以内）：走到石头旁边按 E 扛起 / 到底座自动放下。
##   扛着：粉色公主身上挂 meta busy_hands（不能攻击 / 冲刺 / 施法）+ 状态 carry_stone（走得慢），石头画在头顶。
##   痒痒草（TickleGrass）：第一块零星几丛；第二块起每 SPREAD_EVERY 秒从离她最近的草丛往她那边长出一丛新的（最多 SPREAD_MAX 丛）；
##   第三块再加千手痒痒裤失控（surge）：平静 → 发光预警 WARN_TIME 秒 → 小手伸长挠粉色公主 SURGE_TIME 秒（闷笑每秒 +SURGE_RATE）；
##     换成蓝色公主（C）按住 E 累计 SOOTHE_TIME 秒 → 小手转过来挠她自己（她的闷笑上涨）→ 安静 CALM_TIME 秒。
##   闷笑到 DROP_AT：石头摔在原地（重新扛，闷笑回到 40%）；同一块摔 DROPS 次 = 失败（after_fail_totem，放好的不用重放）。
## 状态：vars.task_totem_placed（放好几块）、task_totem_drops（这一块摔了几次）。
## 测试：pick() / place() / drop() / surge_now() / soothe(秒)。

signal finished(ok: bool)

const PATH := "res://data/after/totem.json"
const QUARRY := [Vector2i(6, 8), Vector2i(6, 12), Vector2i(6, 16)]
const TOTEM := Vector2i(34, 11)
const PLACE_R := 26.0
const PICK_R := 18.0
const GRASS := [
	[Vector2i(13, 9), Vector2i(17, 14), Vector2i(21, 8), Vector2i(24, 15), Vector2i(28, 11), Vector2i(15, 18)],
	[Vector2i(11, 12), Vector2i(19, 11), Vector2i(26, 9), Vector2i(23, 18), Vector2i(30, 15)],
	[Vector2i(12, 15), Vector2i(20, 16), Vector2i(27, 13), Vector2i(17, 7), Vector2i(31, 8)],
]
const SPREAD_EVERY := 2.6
const SPREAD_MAX := 12
const DROP_AT := 0.95
const DROPS := 3
const CALM_TIME := [9.0, 12.0]
const WARN_TIME := 2.0
const SURGE_TIME := 6.0
const SURGE_RATE := 0.09
const SOOTHE_TIME := 2.0
const SOOTHE_COOL := 12.0

static var _data := {}

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var carrying := false
var stone: Node2D
var surge := "off"
var surge_t := 0.0
var soothe_t := 0.0
var spread := 0
var grass: Array = []
var _hands: Node2D
var _emitted := false
var _busy := false
var _spread_t := 0.0
var _say_t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func placed() -> int:
	return int(GameState.vars.get("task_totem_placed", 0))


static func drops() -> int:
	return int(GameState.vars.get("task_totem_drops", 0))


## 失败后：这一块重新扛（放好的不用重放）
static func reset_items() -> void:
	GameState.vars["task_totem_drops"] = 0


static func status_text() -> String:
	return "封印石 %d / 3　这一块摔了 %d / %d 次" % [placed(), drops(), DROPS]


func _ready() -> void:
	pink = GameState.player
	for n in get_parent().get_parent().find_children("*", "PlayableCharacter", true, false):
		if n != pink:
			blue = n
	stone = Stone.new()
	stone.name = "SealStone"
	get_parent().add_child(stone)
	_hands = Hands.new()
	_hands.task = self
	get_parent().add_child(_hands)
	_intro.call_deferred()


func _exit_tree() -> void:
	_release()
	for g in grass:
		if is_instance_valid(g):
			g.queue_free()
	for n in [stone, _hands]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(blue):
		blue.modulate = Color.WHITE


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _start_stone()
	started = true


## 摆这一块的石头和草，演开扛前的话
func _start_stone() -> void:
	var i := placed()
	carrying = false
	stone.global_position = Cutscene.cell_to_world(QUARRY[mini(i, QUARRY.size() - 1)])
	stone.visible = true
	for k in range(0, mini(i + 1, GRASS.size())):
		for c in GRASS[k]:
			_grass_at(Cutscene.cell_to_world(c))
	surge = "calm" if i >= 2 else "off"
	surge_t = randf_range(CALM_TIME[0], CALM_TIME[1]) * 0.5
	var st: Array = data().get("stones", [])
	if i < st.size():
		await _say(st[i].get("start", []))
	if i == 0:
		await _say(data().get("intro_lines", []))


func _grass_at(at: Vector2) -> TickleGrass:
	for g in grass:
		if is_instance_valid(g) and g.global_position.distance_to(at) < 10.0:
			return g
	var g := TickleGrass.new()
	g.on_catch = _on_grass
	get_parent().add_child(g)
	g.global_position = at
	grass.append(g)
	return g


func _on_grass(_g: TickleGrass) -> void:
	var gr: Dictionary = data().get("grass", {})
	var caps: Array = gr.get("caption", [])
	if not caps.is_empty():
		GameState.princess_reacted.emit(str(caps.pick_random()), 2.6)
	var pool: Array = gr.get("react", {}).get(_tier(), [])
	if not pool.is_empty() and is_instance_valid(pink):
		SpeechBubble.say(pink, str(pool.pick_random()), 30.0, 1.4)


func _tier() -> String:
	var lr := pink.laugh.ratio() if is_instance_valid(pink) and pink.laugh else 0.0
	return "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")


# ------------------------------------------------------------------ 每帧
func _process(delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	if carrying:
		stone.global_position = pink.global_position + Vector2(0, -34)
		if pink.global_position.distance_to(Cutscene.cell_to_world(TOTEM)) < PLACE_R:
			place()
			return
	elif GameState.player == pink and Input.is_action_just_pressed("interact") and pink.global_position.distance_to(stone.global_position) < PICK_R:
		pick()
	# 蔓延
	if placed() >= 1:
		_spread_t -= delta
		if _spread_t <= 0.0:
			_spread_t = SPREAD_EVERY * (1.3 if placed() >= 2 else 1.0)
			_spread()
	_surge(delta)
	if pink.laugh and pink.laugh.value >= pink.laugh.max_value * DROP_AT:
		if carrying:
			drop()
		else:
			pink.laugh.set_value(pink.laugh.max_value * 0.6)


func pick() -> void:
	carrying = true
	pink.set_meta(&"busy_hands", true)
	pink.add_buff("carry_stone", -1.0)
	var pk: Array = data().get("pick", [])
	if not pk.is_empty():
		SpeechBubble.say(pink, str(pk.pick_random()), 30.0, 1.2)
	Audio.play("pickup", -6.0)


func _release() -> void:
	if is_instance_valid(pink):
		if pink.has_meta(&"busy_hands"):
			pink.remove_meta(&"busy_hands")
		pink.remove_buff("carry_stone")


## 闷笑满：石头摔在原地
func drop() -> void:
	_busy = true
	carrying = false
	_release()
	stone.global_position = pink.global_position + Vector2(10, 4)
	var n := drops() + 1
	GameState.vars["task_totem_drops"] = n
	Audio.play("drop", -2.0)
	if pink.camera:
		pink.shake(0.4)
	var ds: Array = data().get("drop", [])
	if n >= DROPS:
		_emit(false)
		return
	if not ds.is_empty():
		await _say(ds[mini(n - 1, ds.size() - 1)])
	if pink.laugh:
		pink.laugh.set_value(pink.laugh.max_value * 0.4)
	_busy = false


## 放到底座上
func place() -> void:
	_busy = true
	carrying = false
	_release()
	stone.visible = false
	var i := placed()
	GameState.vars["task_totem_placed"] = i + 1
	GameState.vars["task_totem_drops"] = 0
	surge = "off"
	_hands.visible = false
	if is_instance_valid(blue):
		blue.modulate = Color.WHITE
	Audio.play("star_burst", -4.0)
	var st: Array = data().get("stones", [])
	if i < st.size():
		await _say(st[i].get("placed", []))
	if i + 1 >= QUARRY.size():
		await _say(data().get("finish", []))
		_emit(true)
		return
	if pink.laugh:
		pink.laugh.set_value(0.0)
	if i < st.size():
		await _say(st[i].get("rest", []))
	await _start_stone()
	_busy = false


## 从离她最近的草丛往她那边长一丛
func _spread() -> void:
	if spread >= SPREAD_MAX * (2 if placed() >= 2 else 1):
		return
	var best: TickleGrass = null
	var bd := INF
	for g in grass:
		if is_instance_valid(g):
			var d: float = g.global_position.distance_to(pink.global_position)
			if d < bd:
				bd = d
				best = g
	if best == null or bd < 20.0:
		return
	var at := best.global_position + best.global_position.direction_to(pink.global_position) * 16.0
	var g := _grass_at(at)
	if g != best:
		spread += 1
		g.scale = Vector2(0.3, 0.3)
		g.create_tween().tween_property(g, "scale", Vector2.ONE, 0.5)
		if randf() < 0.3:
			var sp: Array = data().get("spread", [])
			if not sp.is_empty():
				GameState.notify(str(sp.pick_random()), 1.6)


# ------------------------------------------------------------------ 千手痒痒裤失控
func surge_now() -> void:
	surge = "warn"
	surge_t = WARN_TIME
	_warn_text()


func _warn_text() -> void:
	var w: Array = data().get("surge", {}).get("warn", [])
	if not w.is_empty():
		GameState.notify(str(w.pick_random()), 1.8)


func _surge(delta: float) -> void:
	if surge == "off":
		return
	var sg: Dictionary = data().get("surge", {})
	# 安抚：换成蓝色公主、按住 E
	var soothing := surge in ["warn", "surge"] and is_instance_valid(blue) and GameState.player == blue and Input.is_action_pressed("interact")
	if soothing:
		soothe(delta)
	surge_t -= delta
	match surge:
		"calm":
			if surge_t <= 0.0:
				surge_now()
		"warn":
			if is_instance_valid(blue):
				blue.modulate = Color(1.2, 0.85, 1.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
			if surge_t <= 0.0:
				surge = "surge"
				surge_t = SURGE_TIME
				_hands.visible = true
		"surge":
			_say_t -= delta
			if pink.laugh:
				pink.laugh.set_value(minf(pink.laugh.value + pink.laugh.max_value * SURGE_RATE * delta, pink.laugh.max_value * 0.99))
			if _say_t <= 0.0:
				_say_t = 1.4
				var caps: Array = sg.get("caption", [])
				if not caps.is_empty():
					GameState.princess_reacted.emit(str(caps.pick_random()), 1.6)
				var pk: Array = sg.get("pink", [])
				if not pk.is_empty():
					SpeechBubble.say(pink, str(pk.pick_random()), 30.0, 1.2)
				ZoneFx.play(["sole", "waist"].pick_random(), pink.get_parent(), ZoneFx.body_point(pink, "sole"), 1.0, false)
				HitFx.play("hand", pink.get_parent(), pink.global_position + Vector2(randf_range(-5, 5), -6))
				Audio.play("tickle", -6.0, 0.1)
			if surge_t <= 0.0:
				_calm()


## 蓝色公主按住裤子（秒）：小手转过来挠她自己；累计够了 → 安静一阵
func soothe(delta: float) -> void:
	soothe_t += delta
	_say_t -= delta
	if is_instance_valid(blue) and blue.laugh:
		blue.laugh.set_value(minf(blue.laugh.value + blue.laugh.max_value * 0.12 * delta, blue.laugh.max_value * 0.9))
	if _say_t <= 0.0 and is_instance_valid(blue):
		_say_t = 1.0
		var sg: Dictionary = data().get("surge", {})
		var caps: Array = sg.get("soothe_caption", [])
		if not caps.is_empty():
			GameState.princess_reacted.emit(str(caps.pick_random()), 1.6)
		var bl: Array = sg.get("blue", [])
		if not bl.is_empty():
			SpeechBubble.say(blue, str(bl.pick_random()), 30.0, 1.2)
		ZoneFx.play(["thigh", "butt"].pick_random(), blue.get_parent(), ZoneFx.body_point(blue, "thigh"), 1.0, false)
	if soothe_t >= SOOTHE_TIME:
		_calm(SOOTHE_COOL)


func _calm(t := -1.0) -> void:
	surge = "calm"
	surge_t = t if t > 0.0 else randf_range(CALM_TIME[0], CALM_TIME[1])
	soothe_t = 0.0
	_hands.visible = false
	if is_instance_valid(blue):
		blue.modulate = Color.WHITE
	var c: Array = data().get("surge", {}).get("calm", [])
	if not c.is_empty():
		GameState.notify(str(c.pick_random()), 1.6)


# ------------------------------------------------------------------ 工具
func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_totem")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	_release()
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 封印石（程序画：刻着笑脸花纹的灰色石块，微微发光）
class Stone extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var glow := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(0, -5), 9.0, Color(0.85, 0.6, 1.0, 0.18 * glow))
		draw_rect(Rect2(-7, -11, 14, 11), Color(0.55, 0.53, 0.6))
		draw_rect(Rect2(-7, -11, 14, 11), Color(0.32, 0.3, 0.38), false, 1.0)
		draw_arc(Vector2(0, -6), 3.0, 0.2, PI - 0.2, 8, Color(0.9, 0.7, 1.0, 0.6 + 0.4 * glow), 1.0)
		draw_circle(Vector2(-2, -8), 0.8, Color(0.9, 0.7, 1.0))
		draw_circle(Vector2(2, -8), 0.8, Color(0.9, 0.7, 1.0))


## 失控的小手：从蓝色公主身上伸到粉色公主身上的几条弯弯的粉色手臂
class Hands extends Node2D:
	var task: TaskTotem

	func _ready() -> void:
		visible = false
		z_index = 5

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if task == null or not is_instance_valid(task.blue) or not is_instance_valid(task.pink):
			return
		var a := to_local(task.blue.global_position + Vector2(0, -8))
		var b := to_local(task.pink.global_position + Vector2(0, -6))
		var t := Time.get_ticks_msec() * 0.01
		for k in 3:
			var pts := PackedVector2Array()
			for i in 11:
				var f := i / 10.0
				var p := a.lerp(b + Vector2(-6 + k * 6, k * 3), f)
				var n := (b - a).normalized().orthogonal()
				pts.append(p + n * sin(f * 9.0 + t + k) * 3.0 * (1.0 - absf(f - 0.5)))
			draw_polyline(pts, Color(1.0, 0.7, 0.85, 0.9), 1.5)
			draw_circle(pts[pts.size() - 1], 2.0, Color(1.0, 0.85, 0.9))
