class_name TaskStretcher
extends Node2D
## 骑士篇 A「抬担架」（小镇 floor_06_after）：和一个保卫队员把昏迷的骑士从地牢入口抬到药剂师工房门口。台词 data/after/knight.json 的 stretcher。
##   队员抬前面，沿 PATH（格子）往前走（SPEED）；粉色公主抬后面——两手占着（busy_hands）、走得慢（carry_stone），离队员超过 LEASH 他就停下来等。
##   诅咒手印：每 SPAWN_EVERY 秒从骑士身上爬出来一只（CurseHand），直奔前面的队员。挡在中间：手印碰到粉色公主就变得很温和，
##     轻轻拍拍她的脚背就散了（伏笔：手印认得她；闷笑 / 疲倦各涨一点）；碰到队员：他笑倒、担架一歪（drops +1），停 DROP_TIME 秒，又多爬出 SPILL 只。
##   担架歪 DROPS 次 = 失败（knight_fail_stretcher），从地牢入口重新抬。走到工房门口 = 完成。
##   不会一口气歪好几次：歪了以后队员笑 DROP_TIME 秒 + DROP_GRACE 秒内不再算；新爬出来的手印要过 ARM_TIME 秒才算数
##   （她有时间去拦）；歪了以后多爬出来的那只等这段时间过了才扑。
## 状态 vars.task_stretcher_drops。测试：spawn_hand()、hands、drops()、walker、advance(秒)。

signal finished(ok: bool)

const PATH := [Vector2i(53, 9), Vector2i(52, 13), Vector2i(40, 14), Vector2i(28, 13), Vector2i(18, 13), Vector2i(16, 11)]
const SPEED := 26.0
const LEASH := 40.0
const SPAWN_EVERY := 4.5
const DROP_TIME := 2.5
const SPILL := 1
const DROPS := 3
const DROP_GRACE := 1.0
const ARM_TIME := 1.5
const PAT_LAUGH := 0.04
const PAT_FATIGUE := 0.06
const HAND_SPEED := 0.75
const PATH_KEY := "task_stretcher_drops"

static var _data := {}

var aborted := false
var started := false
var pink: PlayableCharacter
var walker: Node2D
var hands: Array[CurseHand] = []
var leg := 0
var dropped_left := 0.0
## 歪了以后多久内不再算歪
var grace_left := 0.0
var _spawn_t := 2.0
var _emitted := false
var _say_t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/knight.json")) if FileAccess.file_exists("res://data/after/knight.json") else null
		_data = parsed if parsed is Dictionary else {}
	return _data.get("stretcher", {})


static func drops() -> int:
	return int(GameState.vars.get(PATH_KEY, 0))


static func reset_items() -> void:
	GameState.vars[PATH_KEY] = 0


static func status_text() -> String:
	return "担架歪了 %d / %d 次" % [drops(), DROPS]


func _ready() -> void:
	pink = GameState.player
	walker = Walker.new()
	walker.task = self
	walker.global_position = Cutscene.cell_to_world(PATH[0]) + Vector2(0, -10)
	get_parent().add_child(walker)
	if is_instance_valid(pink):
		pink.set_meta(&"busy_hands", true)
		pink.add_buff("carry_stone", -1.0)
		pink.global_position = walker.global_position + Vector2(0, 26)
	started = true


func _exit_tree() -> void:
	_release()
	for h in hands:
		if is_instance_valid(h):
			h.queue_free()
	if is_instance_valid(walker):
		walker.queue_free()


func _release() -> void:
	if is_instance_valid(pink):
		if pink.has_meta(&"busy_hands"):
			pink.remove_meta(&"busy_hands")
		pink.remove_buff("carry_stone")


## 骑士躺着的地方（担架中间）
func stretcher_mid() -> Vector2:
	return walker.global_position.lerp(pink.global_position, 0.5)


func _process(delta: float) -> void:
	if _emitted or not started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)


## 一帧：队员往前走、手印爬、碰撞判定
func advance(delta: float) -> void:
	dropped_left = maxf(0.0, dropped_left - delta)
	grace_left = maxf(0.0, grace_left - delta)
	if dropped_left <= 0.0 and walker.global_position.distance_to(pink.global_position) <= LEASH:
		_walk(delta)
	elif dropped_left <= 0.0:
		_say_t -= delta
		if _say_t <= 0.0:
			_say_t = 3.0
			_bubble(walker, data().get("wait", []))
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = SPAWN_EVERY
		spawn_hand()
	for h in hands.duplicate():
		if not is_instance_valid(h) or h.state == "gone":
			hands.erase(h)
			continue
		h.set_meta(&"age", float(h.get_meta(&"age", 0.0)) + delta)
		if h.global_position.distance_to(pink.global_position) <= CurseHand.LATCH_R + 3.0:
			_pat(h)
		elif grace_left <= 0.0 and float(h.get_meta(&"age")) >= ARM_TIME \
				and h.global_position.distance_to(walker.global_position) <= CurseHand.LATCH_R:
			_drop(h)
	if leg >= PATH.size() - 1 and walker.global_position.distance_to(Cutscene.cell_to_world(PATH[-1])) < 4.0:
		_emit(true)


func _walk(delta: float) -> void:
	if leg >= PATH.size() - 1:
		return
	var to := Cutscene.cell_to_world(PATH[leg + 1])
	var d := to - walker.global_position
	if d.length() < 2.0:
		leg += 1
		return
	walker.global_position += d.normalized() * minf(SPEED * delta, d.length())


## 骑士身上爬出一只手印，直奔前面的队员（wait 秒以后才扑；armed：测试里直接算数）
func spawn_hand(wait := 0.0, armed := false) -> CurseHand:
	var h := CurseHand.new()
	get_parent().add_child(h)
	h.global_position = stretcher_mid() + Vector2(randf_range(-4, 4), -4)
	h.speed_mult = HAND_SPEED
	h.set_meta(&"age", ARM_TIME if armed else 0.0)
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(func():
			if is_instance_valid(h) and h.state != "gone":
				h.seek(walker))
	else:
		h.seek(walker)
	hands.append(h)
	return h


## 碰到粉色公主：很温和，拍拍脚背就散了
func _pat(h: CurseHand) -> void:
	var lines: Array = data().get("pat", [])
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines.pick_random()), 2.4)
	_bubble(pink, data().get("pat_react", []))
	if pink.laugh:
		pink.laugh.add(pink.laugh.max_value * PAT_LAUGH)
	if pink.fatigue:
		pink.fatigue.add(pink.fatigue.max_value * PAT_FATIGUE)
	ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 0.6, true)
	hands.erase(h)
	h.dispel()


## 碰到队员：他笑倒，担架一歪，又多爬出几只
func _drop(h: CurseHand) -> void:
	hands.erase(h)
	h.dispel()
	var n := drops() + 1
	GameState.vars[PATH_KEY] = n
	dropped_left = DROP_TIME
	grace_left = DROP_TIME + DROP_GRACE
	(walker as Walker).laugh_t = DROP_TIME
	var lines: Array = data().get("drop", [])
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines.pick_random()), 2.4)
	_bubble(walker, data().get("guard_laugh", []))
	Audio.play("laugh", -6.0)
	if n >= DROPS:
		_emit(false)
		return
	for i in SPILL:
		spawn_hand(grace_left)


func _bubble(who: Node2D, pool: Array) -> void:
	if is_instance_valid(who) and not pool.is_empty():
		SpeechBubble.say(who, str(pool.pick_random()), 30.0, 1.6)


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


## 抬前面的队员 + 担架上的骑士（程序画：队员用保卫队员的行走图，担架和骑士是简单的图形）
class Walker extends Node2D:
	const GUARD := preload("res://assets/generated/npcs/guard.png")
	const KNIGHT := preload("res://assets/generated/npcs/knight.png")
	var task: TaskStretcher
	var laugh_t := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		laugh_t = maxf(0.0, laugh_t - delta)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(task) or not is_instance_valid(task.pink):
			return
		var back := task.pink.global_position - global_position
		var shake := Vector2(sin(_t * 30.0) * 1.5, 0) if laugh_t > 0.0 else Vector2.ZERO
		# 担架：两根杆子 + 布，骑士横躺在上面
		var a := Vector2(0, 4) + shake
		var b := back + Vector2(0, -12)
		var side := (b - a).orthogonal().normalized() * 5.0
		draw_line(a + side, b + side, Color("8b6644"), 2)
		draw_line(a - side, b - side, Color("8b6644"), 2)
		draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), Color(0.85, 0.8, 0.7, 0.9))
		var mid := a.lerp(b, 0.5)
		draw_texture_rect_region(KNIGHT, Rect2(mid - Vector2(16, 22), Vector2(32, 32)), Rect2(0, 0, 32, 32))
		# 前面的队员
		var row := 3 if back.y > 0 else 0
		var frame := int(_t * 6.0) % 4 if task.dropped_left <= 0.0 else 0
		draw_texture_rect_region(GUARD, Rect2(Vector2(-16, -28) + shake, Vector2(32, 32)), Rect2(frame * 32, row * 32, 32, 32))
		if laugh_t > 0.0:
			draw_string(ThemeDB.fallback_font, Vector2(-8, -32), "哈哈哈", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.7, 0.85))
