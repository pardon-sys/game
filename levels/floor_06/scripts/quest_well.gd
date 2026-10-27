class_name QuestWell
extends QuestRunner
## 支线「点灯笼的小姑娘」第三段「井边的冰面」（夜里的小镇，井 (30,18) 旁边）：她小时候练冰魔法冻出来的冰面（滑溜地板 SoapFloor，RINK）。
##   冰面上散着 BELLS 个笑声铃铛（Bell），滑过去就收到；滑过头冲出冰面会一头扎进两头的雪堆（SnowBank）——冰晶钻进脚心（闷笑 +SNOW_LAUGH），被弹回来。
##   铃铛收齐 → 回忆的台词（有人在旁边看着她练、笑得比她还大声）→ 这一段做完。
## 测试：bells、got、snow、rink、tick(秒)。

const RINK := Vector2i(22, 13)
const RINK_SIZE := Vector2i(8, 3)
const BELLS := [Vector2i(23, 14), Vector2i(26, 13), Vector2i(29, 15), Vector2i(24, 15), Vector2i(28, 14)]
const SNOW := [Vector2i(21, 14), Vector2i(30, 14), Vector2i(21, 13), Vector2i(30, 15)]
const BELL_R := 9.0
const SNOW_R := 10.0
const SNOW_LAUGH := 0.08

var bells: Array = []
var snow: Array = []
var got := 0
var rink: Node
var _done := false


func w() -> Dictionary:
	return q.get("well", {})


func setup() -> void:
	bells.clear()
	snow.clear()
	got = 0
	var scn := load("res://scenes/traps/soap_floor.tscn") as PackedScene
	rink = scn.instantiate()
	rink.set("tiles_w", RINK_SIZE.x)
	rink.set("tiles_h", RINK_SIZE.y)
	put(rink, Cutscene.cell_to_world(RINK))
	for c in BELLS:
		bells.append(put(Bell.new(), Cutscene.cell_to_world(c)))
	for c in SNOW:
		snow.append(put(SnowBank.new(), Cutscene.cell_to_world(c)))
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_blue_well_intro"):
		return
	GameState.set_flag("kq_blue_well_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(w().get("intro", []), "kq_well_intro")


func status() -> String:
	return str(w().get("status", "%d / %d")) % [got, BELLS.size()]


func _process(delta: float) -> void:
	if _done or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	tick(delta)


func tick(_delta: float) -> void:
	for b in bells:
		if is_instance_valid(b) and not b.taken and pink.global_position.distance_to(b.global_position) <= BELL_R:
			b.taken = true
			got += 1
			say(w().get("bell", []), 1.0)
			Audio.play("bell_jingle", -6.0)
	for s in snow:
		if is_instance_valid(s) and s.cool <= 0.0 and pink.global_position.distance_to(s.global_position) <= SNOW_R:
			s.cool = 1.2
			say(w().get("snow", []), 1.6)
			if pink.laugh:
				pink.laugh.add(pink.laugh.max_value * SNOW_LAUGH)
			ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 0.8, false)
			pink.global_position += s.global_position.direction_to(Cutscene.cell_to_world(RINK) + Vector2(RINK_SIZE.x * 8, RINK_SIZE.y * 8)) * 14.0
	if got >= BELLS.size():
		_finish()


func _finish() -> void:
	_done = true
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(w().get("memory", []), "kq_well_memory")
	while Dialogue.is_active():
		await get_tree().process_frame
	advance()


## 冰面上的笑声铃铛
class Bell extends Node2D:
	var taken := false
	var _t := randf() * 3.0

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if taken:
			return
		var sway := sin(_t * 5.0) * 0.3
		draw_set_transform(Vector2(0, -6), sway)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 2), Vector2(-2, -3), Vector2(2, -3), Vector2(3, 2)]), Color(1, 0.88, 0.45))
		draw_circle(Vector2(0, 3), 1.0, Color(0.85, 0.65, 0.3))
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(5, -10), 0.8 + 0.4 * sin(_t * 6.0), Color(1, 1, 0.8, 0.9))


## 冰面两头的雪堆（冲出冰面一头扎进去）
class SnowBank extends Node2D:
	var cool := 0.0

	func _process(delta: float) -> void:
		cool = maxf(0.0, cool - delta)

	func _draw() -> void:
		draw_circle(Vector2(0, -2), 7.0, Color(0.92, 0.96, 1.0))
		draw_circle(Vector2(-4, 0), 4.5, Color(0.85, 0.9, 0.98))
		draw_circle(Vector2(4, 0), 4.0, Color(0.88, 0.93, 1.0))
