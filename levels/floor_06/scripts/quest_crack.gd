class_name QuestCrack
extends QuestRunner
## 支线「夜里的栅栏」第四段「广场底下的裂缝」（floor_06_after_crack，很窄，只能趴着爬）：
##   趴着爬（meta no_dash + 状态 crawl，同排水管）。缝里贴着软苔小球（TaskDrain.MossBall，MOSS）：碰到就贴在腿上蹭（闷笑每秒 +MOSS_RATE），按住 E WIPE 秒擦掉。
##   缝里的手印（CurseHand）每隔 HAND_EVERY 秒从墙缝里伸出来一只，爬过来贴着挠；按攻击（J）把它抖下去。
##   三根松掉的封印钉（NAILS）：爬到旁边（NAIL_R）→ 节拍条敲钉子（RhythmLane，HAMMER_BEATS 个音符命中 HAMMER_PASS 个），没敲好重敲。
##   三根都敲回去 → 这一段做完（尽头的旧门开了：kq_fence_hall）。
## 测试：moss、stuck、wipe、hands、nails_done、hammering、lane、start_hammer()、finish_hammer(命中数)、shake_off()。

## 地图上的点（QuestMaps：裂缝的布局在 tools/build/quest_maps.py；封印钉按爬过去的顺序）
static var MOSS: Array[Vector2i] = QuestMaps.cells("floor_06_after_crack", "moss")
static var NAILS: Array[Vector2i] = QuestMaps.cells("floor_06_after_crack", "nails")
const NAIL_R := 14.0
const MOSS_R := 9.0
const MOSS_RATE := 0.04
const WIPE := 1.0
const HAND_EVERY := 4.5
const HAMMER_BEATS := 8
const HAMMER_PASS := 6

var moss: Array = []
var stuck: Array = []
var wipe := 0.0
var hands: Array = []
var nails_done := 0
var hammering := false
var lane: RhythmLane
var _hand_t := HAND_EVERY
## 离下一根钉子还远的时候她站过的地方（敲歪了退回这里；裂缝拐来拐去，不能直接往左挪）
var _safe := Vector2.ZERO
var _layer: CanvasLayer


func c() -> Dictionary:
	return q.get("crack", {})


func setup() -> void:
	moss.clear()
	for m in MOSS:
		moss.append(put(TaskDrain.MossBall.new(), Cells.to_world(m)))
	for i in NAILS.size():
		var n := put(NailMark.new(), Cells.to_world(NAILS[i])) as NailMark
		n.index = i
		n.runner = self
	_crawl(true)
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_fence_crack_intro"):
		return
	GameState.set_flag("kq_fence_crack_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(c().get("intro", []), "kq_crack_intro")


func cleanup() -> void:
	_crawl(false)
	_end_lane()
	for h in hands:
		if is_instance_valid(h):
			h.queue_free()


func _crawl(on: bool) -> void:
	if not is_instance_valid(pink):
		return
	if on:
		pink.set_meta(&"no_dash", true)
		pink.add_buff("crawl", -1.0)
	else:
		if pink.has_meta(&"no_dash"):
			pink.remove_meta(&"no_dash")
		pink.remove_buff("crawl")


func status() -> String:
	return str(c().get("status", "%d / 3")) % nails_done


func _process(delta: float) -> void:
	if not live() or hammering or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	tick(delta, Input.is_action_pressed("interact"))
	if Input.is_action_just_pressed("attack"):
		shake_off()


func tick(delta: float, holding: bool) -> void:
	# 软苔小球：碰到就贴上来
	for m in moss.duplicate():
		if is_instance_valid(m) and not stuck.has(m) and (m as Node2D).global_position.distance_to(pink.global_position) <= MOSS_R:
			stuck.append(m)
			m.visible = false
			say(c().get("moss", []), 1.6)
	if not stuck.is_empty():
		if pink.laugh:
			pink.laugh.add(pink.laugh.max_value * MOSS_RATE * stuck.size() * delta)
		if randf() < delta * 1.5:
			ZoneFx.play("thigh", pink.get_parent(), ZoneFx.body_point(pink, "thigh"), 0.6, false)
		if holding:
			wipe += delta
			if wipe >= WIPE:
				wipe = 0.0
				var m: Node = stuck.pop_back()
				moss.erase(m)
				if is_instance_valid(m):
					m.queue_free()
		else:
			wipe = maxf(0.0, wipe - delta)
	# 墙缝里的手印
	_hand_t -= delta
	if _hand_t <= 0.0:
		_hand_t = HAND_EVERY
		var at := pink.global_position + Vector2(randf_range(-30, 30), -18)
		for i in 8:
			if GridPath.walkable(_lv, GridPath.cell(at)):
				break
			at = pink.global_position + Vector2(randf_range(-30, 30), randf_range(-24, 24))
		var h := put(CurseHand.new(), at) as CurseHand
		h.seek(pink)
		h.life = 12.0
		hands.append(h)
		say(c().get("hand", []), 1.4)
	# 封印钉
	if nails_done < NAILS.size():
		var d := pink.global_position.distance_to(Cells.to_world(NAILS[nails_done]))
		if d <= NAIL_R:
			start_hammer()
		elif d >= NAIL_R + 10.0:
			_safe = pink.global_position


## 按 J：把贴着的手印抖下去
func shake_off() -> int:
	var n := 0
	for h in hands:
		if is_instance_valid(h) and h.state == "latched" and h.target == pink:
			h.release()
			h.flee(pink.global_position)
			n += 1
	return n


func start_hammer() -> void:
	if hammering:
		return
	hammering = true
	pink.status.apply_root(30.0)
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	lane = RhythmLane.new()
	lane.position = Vector2(130, 176)
	lane.size = Vector2(330, 24)
	_layer.add_child(lane)
	lane.load_chart(RhythmLane.make_chart(100.0, HAMMER_BEATS, randi()))
	GameState.notify(str(c().get("hammer", {}).get("hint", "")), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not hammering or not is_instance_valid(lane) or not event is InputEventKey or not event.pressed or event.echo:
		return
	var names := {KEY_UP: "UP", KEY_DOWN: "DOWN", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_W: "UP", KEY_S: "DOWN", KEY_A: "LEFT", KEY_D: "RIGHT"}
	var kc: int = (event as InputEventKey).keycode
	if names.has(kc):
		var res := lane.press(str(names[kc]))
		if res in ["perfect", "good"]:
			Audio.play("hit", -8.0, 0.1)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if hammering and is_instance_valid(lane):
		lane.advance(delta)
		if lane.finished() and lane.time >= lane.end_time():
			finish_hammer(int(lane.counts["perfect"]) + int(lane.counts["good"]))


func finish_hammer(hits: int) -> bool:
	_end_lane()
	hammering = false
	if is_instance_valid(pink):
		pink.status.clear_root()
	if hits < HAMMER_PASS:
		say(c().get("nail_miss", ""), 1.6)
		if is_instance_valid(pink):
			pink.global_position = _safe if _safe != Vector2.ZERO else Cells.to_world(QuestMaps.cell("floor_06_after_crack", "start"))
		return false
	nails_done += 1
	say(c().get("nail_ok", ""), 1.6)
	Audio.play("star_burst", -8.0)
	if nails_done >= NAILS.size():
		say(c().get("done", ""), 3.0)
		_crawl(false)
		advance()
	return true


func _end_lane() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	lane = null


## 松掉的封印钉：一根歪着的大钉子，敲回去以后发一下光
class NailMark extends Node2D:
	var index := 0
	var runner: QuestCrack
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var done := is_instance_valid(runner) and runner.nails_done > index
		var tilt := 0.0 if done else 0.4
		draw_set_transform(Vector2.ZERO, tilt)
		draw_rect(Rect2(-1.5, -10, 3, 10), Color("8f8a9c"))
		draw_rect(Rect2(-3.5, -12, 7, 2), Color("b8b2c6"))
		draw_set_transform(Vector2.ZERO)
		if done:
			draw_circle(Vector2(0, -6), 5.0, Color(1, 0.9, 0.6, 0.25))
		else:
			draw_circle(Vector2(0, -6), 6.0 + sin(_t * 5.0), Color(0.75, 0.4, 1.0, 0.25))
