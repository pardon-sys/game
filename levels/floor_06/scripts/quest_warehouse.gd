class_name QuestWarehouse
extends QuestRunner
## 支线「没有名字的生日」第三段「旧仓库」（floor_06_after_warehouse）：找四个八音盒零件（PARTS 里随机 NEED 处，一闪一闪），走过去按 E 捡。
##   仓库角落里的旧八音盒一阵一阵地响（PLAY 秒响、STOP 秒停）：响的时候发条小手（WindupHand，HANDS）一动不动；
##   一停，看得见她的小手就爬过来挠脚心。躲在箱子 / 木桶旁边（COVERS，COVER_R 以内）它们就看不见她。
##   捡齐 → 这一段做完。
## 测试：hands、parts、got、music、take_near(角色)、set_music(on)。

## 地图上的点（QuestMaps：旧仓库的布局在 tools/build/quest_maps.py）
static var PARTS: Array[Vector2i] = QuestMaps.cells("floor_06_after_warehouse", "parts")
static var HANDS: Array[Vector2i] = QuestMaps.cells("floor_06_after_warehouse", "hands")
static var COVERS: Array[Vector2i] = QuestMaps.cells("floor_06_after_warehouse", "covers")
const COVER_R := 16.0
const PLAY := 2.8
const STOP := 3.0
## 音乐快停的时候（最后 WARN_LEFT 秒）：曲子变慢、状态栏提醒——发条小手比人快得多，要提前躲
const WARN_LEFT := 1.0
const PICK_R := 14.0
const NEED := 4

var hands: Array = []
var parts: Array = []
var got := 0
var music := true
var _left := PLAY


func setup() -> void:
	hands.clear()
	parts.clear()
	got = 0
	for c in HANDS:
		var h := put(WindupHand.new(), Cells.to_world(c)) as WindupHand
		h.target = pink
		hands.append(h)
	var pool := PARTS.duplicate()
	pool.shuffle()
	for i in NEED:
		parts.append(put(PartMark.new(), Cells.to_world(pool[i])))
	set_music(true)
	_intro()


## 第一次进旧仓库：开场（q.warehouse_intro）
func _intro() -> void:
	if GameState.has_flag("kq_host_wh_intro"):
		return
	GameState.set_flag("kq_host_wh_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(q.get("warehouse_intro", []), "kq_warehouse_intro")


func status() -> String:
	var st := ("♪ 曲子慢下来了——快躲！" if _left <= WARN_LEFT else "♪ 音乐响着") if music else "音乐停了！"
	return "零件 %d / %d　%s" % [got, NEED, st]


func set_music(on: bool) -> void:
	music = on
	_left = PLAY if on else STOP
	for h in hands:
		if is_instance_valid(h):
			h.music = on
	if on:
		Audio.play("music_box", -8.0)


func hidden_now() -> bool:
	return COVERS.any(func(c): return pink.global_position.distance_to(Cells.to_world(c)) <= COVER_R)


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	tick(delta)
	if Input.is_action_just_pressed("interact"):
		take_near(GameState.player)


func tick(delta: float) -> void:
	var was := _left
	_left -= delta
	if music and was > WARN_LEFT and _left <= WARN_LEFT:
		Audio.play("music_box", -14.0, 0.0, 0.7)   # 曲子慢下来：快停了
	if _left <= 0.0:
		set_music(not music)
	var hid := hidden_now()
	for h in hands:
		if is_instance_valid(h):
			h.unseen = hid


func take_near(who: Node2D) -> bool:
	for p in parts:
		if is_instance_valid(p) and not p.taken and who.global_position.distance_to(p.global_position) <= PICK_R:
			p.taken = true
			got += 1
			Audio.play("pickup", -4.0)
			GameState.notify("零件 %d / %d" % [got, NEED], 1.2)
			if got >= NEED:
				say("（零件都找到了。角落里的八音盒「叮」地停住了）", 2.4)
				advance()
			return true
	return false


## 一个八音盒零件（小齿轮），一闪一闪
class PartMark extends Node2D:
	var taken := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if taken:
			return
		draw_circle(Vector2(0, -3), 3.5, Color(0.86, 0.78, 0.5))
		for i in 6:
			draw_rect(Rect2(Vector2(0, -3) + Vector2.from_angle(i * TAU / 6.0 + _t) * 3.5 - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), Color(0.86, 0.78, 0.5))
		draw_circle(Vector2(0, -3), 1.2, Color(0.4, 0.32, 0.2))
		draw_circle(Vector2(5, -9), 0.8 + 0.4 * sin(_t * 6.0), Color(1, 1, 0.8, 0.9))
