class_name TaskMine
extends Node2D
## 弥补任务「矿车护送·双人轨道」（第 5 天下午，受损的矿道 floor_06_after_mine）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/mine.json。
##   一条横向的轨道（第 RAIL_ROW 行）。矿车（cart，程序画）上坐着蓝色公主（地图上的 blue_princess，跟着车走）。
##   推车：粉色公主站在车后面（左边）按住 → 推（PUSH 像素/秒 ×(1 - 闷笑×0.6) × 车上每只小鬼 ×IMP_SLOW），人过不去车；
##   上坡段（SLOPE_X 以后）：按住不管用，要连按 →（每下 SLOPE_TAP 像素），不推的时候车往回溜（SLOPE_BACK）。
##   冰封模式：C 换成蓝色公主（车刹住），J 冻住车前方 FREEZE_RANGE 以内的陷阱 FREEZE_TIME 秒（冷却 FREEZE_CD），再按 C 换回来。
##   残党小鬼（上坡段）：从右边跑过来跳上车，挠蓝色公主的大腿（旁白 + 她的反应 + 裤子起哄）；粉色公主在车旁边按 J 把它拍下去。
##   段落：车越过 STAGES 的起点 → 演那一段的开场（上一段的结尾）；到 GOAL_X = 做完。
##   闷笑到 SLIP_AT：车溜回上一个检查点（演一段），溜 SLIPS 次 = 失败（after_fail_mine）。
## 状态：vars.task_mine_slips；检查点 = 已经过的段落起点。
## 测试：直接调 push(秒)、tap()、toggle_freeze()、cast_freeze()、swat()。

signal finished(ok: bool)

const PATH := "res://data/after/mine.json"
const RAIL_ROW := 6
const START_X := 9
## 各段起点（格）：装车 / 喷口 / 刷子 / 上坡
const STAGES := [9, 14, 40, 66]
const SLOPE_X := 66
const GOAL_X := 88
const PUSH := 44.0
const SLOPE_TAP := 11.0
const SLOPE_BACK := 6.0
const IMP_SLOW := 0.75
## 陷阱打到车上的蓝色公主：多近算打到、多久反应一次
const BLUE_HIT_R := 30.0
const BLUE_HIT_EVERY := 0.9
const FREEZE_RANGE := 96.0
const FREEZE_TIME := 5.0
const FREEZE_CD := 4.0
const SLIP_AT := 0.95
const SLIPS := 3
const IMPS := 4

static var _data := {}

var aborted := false
## 开场的话说完了（测试等它）
var started := false
var cart: Node2D
var cart_x := 0.0
var stage := 0
var freeze_mode := false
var freeze_cd := 0.0
var imps: Array = []
var imps_spawned := 0
var imps_swatted := 0
var slips := 0
var _frozen := {}
var _blue: Node2D
var _emitted := false
var _busy := false
var _imp_t := 1.5
var _react_t := 0.0
var _tick_t := 0.0
var _blue_hit_t := 0.0
## 测试用：蓝色公主被陷阱挠到几次
var blue_hits := 0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func reset_items() -> void:
	GameState.vars["task_mine_slips"] = 0


static func status_text() -> String:
	return "车溜回去 %d / %d 次　→ 推车（上坡连按）　C 冰封、J 冻陷阱 / 拍小鬼" % [int(GameState.vars.get("task_mine_slips", 0)), SLIPS]


func _ready() -> void:
	slips = int(GameState.vars.get("task_mine_slips", 0))
	cart = Cart.new()
	cart.name = "MineCart"
	get_parent().add_child(cart)
	cart_x = Cutscene.cell_to_world(Vector2i(START_X, RAIL_ROW)).x
	_place_cart()
	_blue = get_parent().find_child("AfterBlue", true, false) as Node2D
	if _blue == null:
		_blue = _find_blue()
	if _blue:
		_blue.set_physics_process(false)
	_intro.call_deferred()


func _exit_tree() -> void:
	for t in _frozen.keys():
		if is_instance_valid(t):
			_unfreeze(t)
	for i in imps:
		if is_instance_valid(i):
			i.queue_free()
	if is_instance_valid(cart):
		cart.queue_free()
	if is_instance_valid(_blue):
		_blue.set_physics_process(true)


func _find_blue() -> Node2D:
	for n in get_parent().get_parent().find_children("*", "PlayableCharacter", true, false):
		if n != GameState.player:
			return n
	return null


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _stage_start(0)
	started = true


func rail_y() -> float:
	return Cutscene.cell_to_world(Vector2i(0, RAIL_ROW)).y


func cell_x() -> float:
	return cart_x / 16.0


func _place_cart() -> void:
	cart.global_position = Vector2(cart_x, rail_y())
	if is_instance_valid(_blue):
		_blue.global_position = cart.global_position + Vector2(0, -6)


# ------------------------------------------------------------------ 每帧
func _process(delta: float) -> void:
	if _emitted or _busy or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	freeze_cd = maxf(0.0, freeze_cd - delta)
	_tick_frozen(delta)
	# 冰封模式：粉色公主站着不动（车刹住）
	if freeze_mode:
		p.velocity = Vector2.ZERO
	else:
		if cell_x() >= SLOPE_X:
			if Input.is_action_just_pressed("move_right") and _behind(p):
				tap()
			elif cart_x > Cutscene.cell_to_world(Vector2i(SLOPE_X, 0)).x:
				cart_x -= SLOPE_BACK * delta
		elif Input.is_action_pressed("move_right") and _behind(p):
			push(delta)
	# 人过不去车
	if absf(p.global_position.y - rail_y()) < 14.0 and p.global_position.x > cart_x - 12.0 and p.global_position.x < cart_x + 10.0:
		p.global_position.x = cart_x - 12.0
	_place_cart()
	_imps(delta)
	_blue_traps(delta)
	if Input.is_action_just_pressed("attack"):
		if freeze_mode:
			cast_freeze()
		else:
			swat()
	_check_stage()
	if p.laugh and p.laugh.value >= p.laugh.max_value * SLIP_AT:
		_slip()


func _unhandled_input(event: InputEvent) -> void:
	if _emitted or _busy or GameState.in_dialogue:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_C:
		toggle_freeze()
		get_viewport().set_input_as_handled()


func _behind(p: Node2D) -> bool:
	return absf(p.global_position.y - rail_y()) < 16.0 and p.global_position.x <= cart_x - 6.0 and p.global_position.x >= cart_x - 28.0


func _power() -> float:
	var p := GameState.player
	var lr := p.laugh.ratio() if is_instance_valid(p) and p.laugh else 0.0
	return (1.0 - lr * 0.6) * pow(IMP_SLOW, _imps_on())


## 平地上推一下（秒）
func push(delta: float) -> void:
	cart_x += PUSH * _power() * delta
	_say_push()


## 上坡连按一下
func tap() -> void:
	cart_x += SLOPE_TAP * _power()
	Audio.play("step", -10.0, 0.2)
	_say_push()


func _say_push() -> void:
	_react_t -= get_process_delta_time()
	if _react_t > 0.0:
		return
	_react_t = 4.0
	var p := GameState.player
	var lr := p.laugh.ratio() if is_instance_valid(p) and p.laugh else 0.0
	var tier := "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")
	var pool: Array = data().get("push_react", {}).get(tier, [])
	if not pool.is_empty() and is_instance_valid(p):
		SpeechBubble.say(p, str(pool.pick_random()), 30.0, 1.4)


# ------------------------------------------------------------------ 冰封模式
func toggle_freeze() -> void:
	freeze_mode = not freeze_mode
	var f: Dictionary = data().get("freeze", {})
	GameState.notify(str(f.get("mode_on" if freeze_mode else "mode_off", "")), 2.0)
	if is_instance_valid(_blue):
		_blue.modulate = Color(0.8, 0.95, 1.2) if freeze_mode else Color.WHITE
	Audio.play("pickup", -10.0, 0.1)


## J：冻住车前方的陷阱（返回冻住了几个）
func cast_freeze() -> int:
	var f: Dictionary = data().get("freeze", {})
	if freeze_cd > 0.0:
		_blue_say(str(f.get("cooldown", "……")))
		return 0
	var n := 0
	for t in get_tree().get_nodes_in_group("trap"):
		var tr := t as Trap
		if tr == null:
			continue
		var dx := tr.global_position.x - cart_x
		if dx > -16.0 and dx < FREEZE_RANGE:
			_freeze(tr)
			n += 1
	for c in get_parent().find_children("*", "TickleCloud", true, false):
		var dx2: float = (c as Node2D).global_position.x - cart_x
		if dx2 > -16.0 and dx2 < FREEZE_RANGE:
			c.queue_free()
	if n == 0:
		_blue_say(str(f.get("nothing", "……")))
		return 0
	freeze_cd = FREEZE_CD
	var on: Array = f.get("on", ["……冻住。"])
	_blue_say(str(on.pick_random()))
	Audio.play("ice_crack", -4.0, 0.1)
	if is_instance_valid(cart):
		Fx.burst(get_parent(), cart.global_position + Vector2(24, -8), "crystal", 14, 70.0, 0.6, Vector2(0, 40), Color(0.75, 0.92, 1.0))
	return n


func _freeze(t: Trap) -> void:
	_frozen[t] = FREEZE_TIME
	t.active = false
	t._enter(Trap.Phase.IDLE)
	t.modulate = Color(0.6, 0.85, 1.3)


func _unfreeze(t: Trap) -> void:
	_frozen.erase(t)
	t.active = true
	if t.trigger_mode == Trap.TriggerMode.CONTINUOUS:
		t._enter(Trap.Phase.ACTIVE)
	t.modulate = Color.WHITE


func _tick_frozen(delta: float) -> void:
	for t in _frozen.keys():
		if not is_instance_valid(t):
			_frozen.erase(t)
			continue
		_frozen[t] = float(_frozen[t]) - delta
		if float(_frozen[t]) <= 0.0:
			_unfreeze(t)


func is_frozen(t: Trap) -> bool:
	return _frozen.has(t)


func _blue_say(s: String) -> void:
	if is_instance_valid(_blue):
		SpeechBubble.say(_blue, s, 30.0, 1.4)


## 车经过陷阱时，坐在车上的蓝色公主也会被挠到（喷口的粉雾、扫过来的羽毛刷）：冒字 + 部位特效
func _blue_traps(delta: float) -> void:
	_blue_hit_t -= delta
	if _blue_hit_t > 0.0 or not is_instance_valid(_blue):
		return
	var at := _blue.global_position
	var hit := false
	for c in get_parent().find_children("*", "TickleCloud", true, false):
		if (c as Node2D).global_position.distance_to(at) < float(c.get("radius")) + 6.0:
			hit = true
			break
	if not hit:
		for t in get_tree().get_nodes_in_group("trap"):
			var tr := t as Trap
			if tr and not is_frozen(tr) and tr.is_dangerous() and tr.global_position.distance_to(at) < BLUE_HIT_R + (32.0 if tr is FeatherBrush else 0.0):
				hit = true
				break
	if not hit:
		return
	_blue_hit_t = BLUE_HIT_EVERY
	blue_hits += 1
	var bl: Array = data().get("imp", {}).get("blue", ["……！"])
	_blue_say(str(bl.pick_random()))
	var z: String = ["thigh", "waist", "butt"].pick_random()
	ZoneFx.play(z, get_parent(), _blue.global_position + Vector2(0, -6), 1.0, false)
	HitFx.play("feather", get_parent(), _blue.global_position + Vector2(randf_range(-4, 4), -8))
	if _blue.laugh:
		_blue.laugh.set_value(minf(_blue.laugh.value + _blue.laugh.max_value * 0.04, _blue.laugh.max_value * 0.9))


# ------------------------------------------------------------------ 残党小鬼
func _imps(delta: float) -> void:
	if cell_x() < SLOPE_X or stage < 3:
		return
	_imp_t -= delta
	if _imp_t <= 0.0 and imps_spawned < IMPS and _imps_on() < 2:
		_imp_t = randf_range(3.0, 5.0)
		spawn_imp()
	for i in imps.duplicate():
		if not is_instance_valid(i):
			imps.erase(i)
			continue
		(i as CartImp).cart_pos = cart.global_position


func spawn_imp() -> CartImp:
	var i := CartImp.new()
	i.task = self
	get_parent().add_child(i)
	i.global_position = Vector2(cart_x + 110.0, rail_y() + randf_range(-20, 20))
	i.cart_pos = cart.global_position
	imps.append(i)
	imps_spawned += 1
	var j: Array = data().get("imp", {}).get("jump", [])
	if not j.is_empty():
		SpeechBubble.say(i, str(j.pick_random()), 18.0, 1.2)
	return i


func _imps_on() -> int:
	return imps.filter(func(i): return is_instance_valid(i) and i.on_cart).size()


## 车上的小鬼挠蓝色公主一下（CartImp 调）
func imp_tickle(i: CartImp) -> void:
	var im: Dictionary = data().get("imp", {})
	var caps: Array = im.get("caption", [])
	if not caps.is_empty():
		GameState.princess_reacted.emit(str(caps.pick_random()), 2.4)
	var bl: Array = im.get("blue", [])
	if not bl.is_empty():
		_blue_say(str(bl.pick_random()))
	if randf() < 0.4:
		var pa: Array = im.get("pants", [])
		if not pa.is_empty():
			GameState.notify(str(pa.pick_random()), 1.6)
	if is_instance_valid(_blue):
		HitFx.play("hand", get_parent(), _blue.global_position + Vector2(randf_range(-4, 4), -4))
		ZoneFx.play("thigh", get_parent(), _blue.global_position + Vector2(0, -4), 1.0, false)
	Audio.play("tickle", -8.0, 0.1)


## J：拍下车旁边最近的一只小鬼（返回拍没拍到）
func swat() -> bool:
	var p := GameState.player
	if not is_instance_valid(p) or p.global_position.distance_to(cart.global_position) > 30.0:
		return false
	for i in imps:
		if is_instance_valid(i) and i.on_cart:
			(i as CartImp).knock()
			imps_swatted += 1
			var sw: Array = data().get("imp", {}).get("swat", ["拍飞！"])
			SpeechBubble.say(p, str(sw.pick_random()), 30.0, 1.0)
			Audio.play("hit", -4.0, 0.1)
			return true
	return false


# ------------------------------------------------------------------ 段落 / 溜车 / 终点
func _check_stage() -> void:
	if stage + 1 < STAGES.size() and cell_x() >= float(STAGES[stage + 1]):
		var prev := stage
		stage += 1
		_busy = true
		await _say(data().get("stages", [])[prev].get("end", []))
		await _stage_start(stage)
		_busy = false
		return
	if cell_x() >= float(GOAL_X) and imps.filter(func(i): return is_instance_valid(i) and i.on_cart).is_empty():
		_busy = true
		await _say(data().get("stages", [])[STAGES.size() - 1].get("end", []))
		_emit(true)


func _stage_start(i: int) -> void:
	var ss: Array = data().get("stages", [])
	if i < ss.size():
		await _say(ss[i].get("start", []))


func _slip() -> void:
	_busy = true
	slips += 1
	GameState.vars["task_mine_slips"] = slips
	await _say(data().get("slip", []))
	var p := GameState.player
	if slips >= SLIPS:
		_emit(false)
		return
	cart_x = Cutscene.cell_to_world(Vector2i(int(STAGES[stage]), RAIL_ROW)).x
	for i in imps:
		if is_instance_valid(i):
			i.queue_free()
	imps.clear()
	if is_instance_valid(p):
		p.global_position = Vector2(cart_x - 18.0, rail_y())
		if p.laugh:
			p.laugh.set_value(p.laugh.max_value * 0.35)
	freeze_mode = false
	if is_instance_valid(_blue):
		_blue.modulate = Color.WHITE
	_place_cart()
	_busy = false


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_mine")
	while Dialogue.is_active():
		await get_tree().process_frame


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


# ------------------------------------------------------------------ 矿车（程序画：木箱车身 + 两个铁轮 + 一堆补给）
class Cart extends Node2D:
	func _ready() -> void:
		z_index = 0
		y_sort_enabled = false

	func _draw() -> void:
		var wood := Color(0.52, 0.34, 0.2)
		var iron := Color(0.35, 0.34, 0.4)
		draw_rect(Rect2(-12, -10, 24, 9), wood)
		draw_rect(Rect2(-12, -10, 24, 9), wood.darkened(0.35), false, 1.0)
		draw_line(Vector2(-12, -6), Vector2(12, -6), wood.darkened(0.25), 1.0)
		draw_rect(Rect2(-9, -14, 8, 5), Color(0.86, 0.78, 0.6))   # 补给箱
		draw_rect(Rect2(1, -13, 7, 4), Color(0.7, 0.5, 0.36))
		draw_circle(Vector2(-7, 0), 3.0, iron)
		draw_circle(Vector2(7, 0), 3.0, iron)
		draw_circle(Vector2(-7, 0), 1.0, Color(0.7, 0.7, 0.75))
		draw_circle(Vector2(7, 0), 1.0, Color(0.7, 0.7, 0.75))


# ------------------------------------------------------------------ 残党小鬼（机关小工匠的贴图染成暗红色）
class CartImp extends Node2D:
	var task: TaskMine
	var cart_pos := Vector2.ZERO
	var on_cart := false
	var _t := 0.0
	var _hit := 1.0
	var _gone := false
	var _spr: Sprite2D
	var _seat := Vector2(randf_range(-8, 8), -16)

	func _ready() -> void:
		_spr = Sprite2D.new()
		_spr.texture = load("res://assets/generated/machine_imp.png")
		_spr.hframes = 4
		_spr.offset = Vector2(0, -8)
		_spr.modulate = Color(1.0, 0.55, 0.55)
		add_child(_spr)

	func _process(delta: float) -> void:
		if _gone or GameState.in_dialogue or GameState.in_cutscene:
			return
		_t += delta
		_spr.frame = int(_t * 6.0) % 4
		if on_cart:
			global_position = cart_pos + _seat
			_hit -= delta
			if _hit <= 0.0:
				_hit = randf_range(1.0, 1.6)
				if task:
					task.imp_tickle(self)
			return
		var to := cart_pos + _seat - global_position
		if to.length() < 6.0:
			on_cart = true
			return
		global_position += to.normalized() * minf(70.0 * delta, to.length())
		_spr.flip_h = to.x < 0.0

	func knock() -> void:
		on_cart = false
		_gone = true
		var tw := create_tween()
		tw.tween_property(self, "global_position", global_position + Vector2(randf_range(30, 50), -30), 0.4)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
