class_name TaskTag
extends Node2D
## 第 4 天晚上 小孩们「挠痒捉人」（小镇广场 AREA 一带）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）。台词 data/after/night.json 的 tag。
##   四个孩子（TagKid，用居民 kid 的行走图）。三轮（rounds）：
##     （孩子们跑动没有边界：整个小镇能走的地方都能跑，撞墙沿墙滑——TagKid._ok）
##     seek 姐姐当鬼：孩子们躲着她跑；追上去（KID_R 以内）按 J 挠——孩子笑倒算抓到；时限内四个都抓到过关（没抓完：被孩子们笑话、挠一下、这一轮重来）。
##     run  两个孩子当鬼追她：被摸到 = 按倒挠 PIN_TIME 秒（定身、闷笑上涨）；撑到时间、被抓不超过 MAX_CAUGHT 次过关（超过这一轮重来）。
##     all  四个孩子一起追，撑到时间过关。
##   闷笑到 FAIL_AT = 失败（after_fail_tag：被大家压在下面）。
## 测试：tickle_kid(孩子)、catch_by(孩子)、round_i / caught / pinned。

signal finished(ok: bool)

const AREA := Rect2i(22, 25, 19, 12)
const KID_R := 16.0
const PIN_TIME := 2.2
const PIN_RATE := 0.1
const MAX_CAUGHT := 3
const FAIL_AT := 0.95
const NAMES := ["小汤姆", "小莉莉", "小胖", "小芽"]
const SPAWN := [Vector2i(26, 28), Vector2i(36, 28), Vector2i(26, 34), Vector2i(36, 34)]

var aborted := false
var started := false
var kids: Array = []
var round_i := 0
var time_left := 0.0
var caught := 0
var times_caught := 0
var pinned_by: TagKid
var pin_t := 0.0
var _busy := false
var _emitted := false
var _say_t := 0.0


static func data() -> Dictionary:
	return AfterNight.data().get("tag", {})


static func reset_items() -> void:
	pass


static func status_text() -> String:
	return str(GameState.vars.get("task_tag_text", ""))


func _ready() -> void:
	for i in NAMES.size():
		var k := TagKid.new()
		k.kid_name = NAMES[i]
		k.area = Rect2(Cells.to_world(AREA.position), Vector2(AREA.size) * 16.0)
		get_parent().add_child(k)
		k.global_position = Cells.to_world(SPAWN[i])
		kids.append(k)
	_intro.call_deferred()


func _exit_tree() -> void:
	for k in kids:
		if is_instance_valid(k):
			k.queue_free()
	GameState.vars.erase("task_tag_text")


func _intro() -> void:
	await TrainingDB.wait_dialogue_free()
	await _say(data().get("intro", []))
	await _start_round(0)
	started = true


func rnd() -> Dictionary:
	var rs: Array = data().get("rounds", [])
	return rs[round_i] if round_i < rs.size() else {}


func _start_round(i: int) -> void:
	round_i = i
	caught = 0
	times_caught = 0
	time_left = float(rnd().get("time", 35.0))
	var id := str(rnd().get("id", ""))
	for j in kids.size():
		var k: TagKid = kids[j]
		k.down_t = 0.0
		k.out = false
		k.global_position = Cells.to_world(SPAWN[j])
		match id:
			"seek":
				k.mode = TagKid.Mode.FLEE
			"run":
				k.mode = TagKid.Mode.CHASE if j in [0, 2] else TagKid.Mode.IDLE
				k.speed = 60.0
			_:
				k.mode = TagKid.Mode.CHASE
				k.speed = 56.0 + j * 2.0
	await _say(rnd().get("start", []))


func _process(delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	time_left -= delta
	GameState.vars["task_tag_text"] = "%s　剩 %d 秒　%s" % [rnd().get("name", ""), ceili(maxf(time_left, 0.0)),
		("抓到 %d / 4（J 挠）" % caught) if str(rnd().get("id", "")) == "seek" else ("被抓 %d 次" % times_caught)]
	for k in kids:
		(k as TagKid).target = p
	if pinned_by:
		_pinned(delta)
	elif str(rnd().get("id", "")) == "seek":
		if Input.is_action_just_pressed("attack"):
			for k in kids:
				if not k.out and k.global_position.distance_to(p.global_position) < KID_R:
					tickle_kid(k)
					break
		if caught >= kids.size():
			_round_won()
			return
	else:
		for k in kids:
			var tk := k as TagKid
			if tk.mode == TagKid.Mode.CHASE and tk.cool <= 0.0 and tk.global_position.distance_to(p.global_position) < 12.0:
				catch_by(tk)
				break
	if time_left <= 0.0:
		if str(rnd().get("id", "")) == "seek":
			_round_lost("（时间到——还有孩子没抓到。孩子们围上来笑话她，顺手挠了一下）")
		elif str(rnd().get("id", "")) == "run" and times_caught > MAX_CAUGHT:
			_round_lost("（被抓了太多次——这一轮重来）")
		else:
			_round_won()
		return
	if p.laugh and p.laugh.value >= p.laugh.max_value * FAIL_AT:
		_emit(false)


## 姐姐当鬼：挠一个孩子（笑倒 = 抓到）
func tickle_kid(k: TagKid) -> void:
	if k.out:
		return
	k.out = true
	k.down_t = 99.0
	caught += 1
	var tk: Array = data().get("tickle_kid", [])
	if not tk.is_empty():
		GameState.princess_reacted.emit(str(tk.pick_random()), 1.8)
	var kl: Array = data().get("kid_laugh", [])
	if not kl.is_empty():
		SpeechBubble.say(k, str(kl.pick_random()), 22.0, 1.2)
	Audio.play("giggle", -8.0)


## 孩子当鬼：被摸到 → 按倒挠
func catch_by(k: TagKid) -> void:
	var p := GameState.player
	pinned_by = k
	pin_t = PIN_TIME
	times_caught += 1
	k.cool = PIN_TIME + 2.0
	if p.status:
		p.status.apply_root(PIN_TIME)
	var c: Dictionary = data().get("caught", {}).get(k.kid_name, {})
	if c.has("desc"):
		GameState.princess_reacted.emit(str(c["desc"]), PIN_TIME)
	SpeechBubble.say(k, "抓到啦！", 22.0, 1.0)


func _pinned(delta: float) -> void:
	var p := GameState.player
	pin_t -= delta
	var c: Dictionary = data().get("caught", {}).get(pinned_by.kid_name, {})
	var z := str(c.get("zone", "sole"))
	if p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * PIN_RATE * delta, p.laugh.max_value))
	_say_t -= delta
	if _say_t <= 0.0:
		_say_t = 0.8
		ZoneFx.play(z, p.get_parent(), ZoneFx.body_point(p, z), 1.0, false)
		SpeechBubble.say(p, AfterNight.react(p.laugh.ratio() if p.laugh else 0.0), 30.0, 1.0)
		Audio.play("tickle", -6.0, 0.1)
	pinned_by.global_position = p.global_position + Vector2(10, 2)
	if pin_t <= 0.0:
		pinned_by = null


func _round_won() -> void:
	_busy = true
	pinned_by = null
	await _say(rnd().get("end", []))
	if round_i + 1 >= (data().get("rounds", []) as Array).size():
		await _say(data().get("done", []))
		_emit(true)
		return
	await _start_round(round_i + 1)
	_busy = false


func _round_lost(why: String) -> void:
	_busy = true
	pinned_by = null
	GameState.princess_reacted.emit(why, 2.4)
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * 0.12, p.laugh.max_value * 0.9))
	await get_tree().create_timer(1.0).timeout
	await _start_round(round_i)
	_busy = false


func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	Dialogue.start_lines(lines, "task_tag")
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


## 捉人游戏里的孩子（用居民 kid 的行走图；不撞墙，夹在广场范围里）
class TagKid extends Node2D:
	enum Mode { IDLE, FLEE, CHASE }
	var kid_name := ""
	var mode := Mode.IDLE
	var speed := 54.0
	var target: Node2D
	var area := Rect2()
	var out := false
	var down_t := 0.0
	var cool := 0.0
	var _spr: Sprite2D
	var _t := 0.0
	var _wiggle := Vector2.ZERO

	## 这一点能不能站：脚下的格子是地板、不是墙，而且没压着房子 / 摊位 / 栅栏这些有碰撞的东西（物理层 1 world）
	func _ok(p: Vector2) -> bool:
		var main := get_tree().get_first_node_in_group("main")
		var lv: Node = main.get("level") if main else null
		if lv != null and not GridPath.walkable(lv, Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))):
			return false
		var space := get_world_2d().direct_space_state
		var q := PhysicsShapeQueryParameters2D.new()
		var c := CircleShape2D.new()
		c.radius = 4.0
		q.shape = c
		q.transform = Transform2D(0.0, p)
		q.collision_mask = 1
		q.collide_with_areas = false
		return space.intersect_shape(q, 1).is_empty()

	func _ready() -> void:
		_spr = Sprite2D.new()
		_spr.texture = load("res://assets/generated/npcs/kid.png")
		_spr.hframes = 4
		_spr.vframes = 4
		_spr.offset = Vector2(0, -14)
		add_child(_spr)

	func _process(delta: float) -> void:
		_t += delta
		cool = maxf(0.0, cool - delta)
		if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(target):
			return
		if out:
			_spr.rotation = 1.5    # 笑倒在地上
			return
		_spr.rotation = 0.0
		var v := Vector2.ZERO
		var d := target.global_position - global_position
		match mode:
			Mode.FLEE:
				if d.length() < 80.0:
					v = -d.normalized() * speed
				if int(_t * 2.0) % 3 == 0:
					_wiggle = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				v += _wiggle * 18.0
			Mode.CHASE:
				if cool <= 0.0:
					v = d.normalized() * speed
		# 没有边界：哪里能走就往哪里跑；撞墙就沿着墙滑，滑不动换个方向
		var step := v * delta
		if _ok(global_position + step):
			global_position += step
		elif _ok(global_position + Vector2(step.x, 0)):
			global_position += Vector2(step.x, 0)
		elif _ok(global_position + Vector2(0, step.y)):
			global_position += Vector2(0, step.y)
		elif v.length() > 1.0:
			_wiggle = -_wiggle if _wiggle != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
		var row := 0
		if absf(v.x) > absf(v.y):
			row = 1 if v.x < 0 else 2
		elif v.y < 0:
			row = 3
		_spr.frame = row * 4 + (int(_t * 8.0) % 4 if v.length() > 1.0 else 0)
