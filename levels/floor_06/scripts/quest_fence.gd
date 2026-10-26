class_name QuestFence
extends QuestRunner
## 支线「夜里的栅栏」的玩法（夜里的骑士篇小镇 floor_06_knight_night）：在营地通往小镇的三个路口装栅栏门（就是追逃里镇民拉上的那三道，TaskArmorChase.GATES）。
##   城墙脚下的木板堆（q.lumber）旁按 E 扛起一捆木板（两手占着 busy_hands、走得慢 carry_stone）→ 走到这一段的路口（GATE_R 以内）→ 钉门：
##   跟节拍按方向键（RhythmLane，HAMMER_BEATS 个音符，perfect / good 够 HAMMER_PASS 个就钉好；不够重钉，木板还在手上）→ 这一段做完。
##   路上的房檐有爬墙手印（EaveHand）：从底下走会掉下来抓脚。三道都钉好 → 回去找工匠说话（最后一段 report）。
## 测试：carrying、hammering、lane、pick()、start_hammer()、finish_hammer(命中数)、eaves。

const PICK_R := 20.0
const GATE_R := 18.0
const HAMMER_BEATS := 6
const HAMMER_PASS := 4
## 小镇道具的图集（prop.gd 没有 class_name）
const PROP := preload("res://scripts/objects/prop.gd")
const EAVES := [Vector2i(50, 33), Vector2i(47, 37), Vector2i(41, 34), Vector2i(39, 30), Vector2i(56, 36)]

var carrying := false
var hammering := false
var lane: RhythmLane
var eaves: Array = []
var _layer: CanvasLayer
var _rig: FenceRig


static func runs_on(floor_id: String, st: int) -> bool:
	return floor_id == KnightStory.KNIGHT_N and st < 3


static func reset_items() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for c in tree.get_nodes_in_group("player_chars"):
		_drop(c)


static func _drop(c: Node) -> void:
	if c.has_meta(&"busy_hands"):
		c.remove_meta(&"busy_hands")
	if c.has_method("remove_buff"):
		c.remove_buff("carry_stone")


static func objective_text(text: String) -> String:
	return text % KnightQuests.stage("fence") if text.contains("%d") else text


func setup() -> void:
	eaves.clear()
	for c in EAVES:
		var e := EaveHand.new()
		e.lines = q
		put(e, Cutscene.cell_to_world(c))
		eaves.append(e)
	_rig = put(FenceRig.new(), Vector2.ZERO) as FenceRig
	_rig.runner = self
	# 木板堆自己带「E」提示（以前木板点和地图上会调查的木料道具重在一起，按 E 先开了调查的对话，扛不起来）
	var pile := LumberPile.new()
	pile.runner = self
	put(pile, lumber_at())


func cleanup() -> void:
	_end_lane()
	if is_instance_valid(pink):
		_drop(pink)
	carrying = false


func lumber_at() -> Vector2:
	return cell(q.get("lumber", [45, 40]))


func gate_at(i: int) -> Vector2:
	var st: Array = q.get("stages", [])
	return cell(st[i]["cell"]) if i < st.size() else Vector2.ZERO


## 扛起一捆木板
func pick() -> bool:
	if carrying or not is_instance_valid(pink):
		return false
	carrying = true
	pink.set_meta(&"busy_hands", true)
	pink.add_buff("carry_stone", -1.0)
	say(q.get("pick", ""), 2.0)
	return true


func _process(delta: float) -> void:
	if hammering:
		if is_instance_valid(lane):
			lane.advance(delta)
			if lane.finished():
				finish_hammer(int(lane.counts["perfect"]) + int(lane.counts["good"]))
		return
	if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if carrying and pink.global_position.distance_to(gate_at(stage())) <= GATE_R:
		start_hammer()


## 到了路口：放下木板，跟着节拍钉
func start_hammer() -> void:
	if hammering:
		return
	hammering = true
	pink.status.apply_root(30.0)
	var h: Dictionary = q.get("hammer", {})
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	lane = RhythmLane.new()
	lane.position = Vector2(130, 176)
	lane.size = Vector2(330, 24)
	_layer.add_child(lane)
	lane.load_chart(RhythmLane.make_chart(100.0, HAMMER_BEATS, randi()))
	GameState.notify(str(h.get("hint", "")), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not hammering or not is_instance_valid(lane) or not event is InputEventKey or not event.pressed or event.echo:
		return
	var names := {KEY_UP: "UP", KEY_DOWN: "DOWN", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_W: "UP", KEY_S: "DOWN", KEY_A: "LEFT", KEY_D: "RIGHT"}
	var kc: int = (event as InputEventKey).keycode
	if names.has(kc):
		var res := lane.press(str(names[kc]))
		var h: Dictionary = q.get("hammer", {})
		if res in ["perfect", "good"]:
			Audio.play("hit", -8.0, 0.1)
		elif res == "miss":
			GameState.notify(str(h.get("miss", "")), 0.8)
		get_viewport().set_input_as_handled()


## 一道门钉完：命中够了就做完这一段，不够重钉（木板还在手上）
func finish_hammer(hits: int) -> bool:
	_end_lane()
	hammering = false
	if is_instance_valid(pink):
		pink.status.clear_root()
	var h: Dictionary = q.get("hammer", {})
	if hits < HAMMER_PASS:
		say(h.get("miss", ""), 1.6)
		if is_instance_valid(pink):
			pink.global_position = gate_at(stage()) + Vector2(0, GATE_R + 8.0)
		return false
	say(h.get("done", ""), 2.0)
	Audio.play("star_burst", -8.0)
	carrying = false
	if is_instance_valid(pink):
		_drop(pink)
	advance()
	return true


func _end_lane() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	lane = null


## 城墙脚下的木板堆：靠近面向它出「E」，按 E 扛起一捆
class LumberPile extends Node2D:
	var runner: QuestFence
	var area: Interactable

	func _ready() -> void:
		area = Interactable.new()
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = QuestFence.PICK_R * 0.7
		shape.shape = c
		area.add_child(shape)
		add_child(area)

	func _process(_delta: float) -> void:
		area.enabled = is_instance_valid(runner) and not runner.carrying and not runner.hammering

	func on_interact(_player: Node) -> void:
		if is_instance_valid(runner) and runner.pink == GameState.player:
			runner.pick()


## 木板堆、这一段的路口（一闪一闪）、已经钉好的门
class FenceRig extends Node2D:
	var runner: QuestFence
	var _t := 0.0

	func _ready() -> void:
		# 节点在 (0, 0)：按 y 排序会排到最后面，抬一层，扛着的木板才画在人物上面
		z_index = 2

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not runner:
			return
		_prop("plank_bundle", runner.lumber_at() + Vector2(0, -4))
		for i in runner.stage():
			_prop("fence_gate", runner.gate_at(i) + Vector2(0, -8))
		var g := runner.gate_at(runner.stage())
		draw_arc(g, QuestFence.GATE_R * (0.8 + 0.1 * sin(_t * 4.0)), 0, TAU, 24, Color(1, 0.85, 0.4, 0.8), 1.5)
		if runner.carrying and is_instance_valid(runner.pink):
			_prop("plank_bundle", runner.pink.global_position + Vector2(0, -26))

	func _prop(kind: String, at: Vector2) -> void:
		var r: Array = PROP.meta().get(kind, {}).get("region", [])
		if r.size() == 4:
			draw_texture_rect_region(PROP.SHEET, Rect2(at - Vector2(r[2], r[3]) * 0.5, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]))
