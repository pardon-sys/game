class_name QuestStorage
extends QuestRunner
## 支线「点灯笼的小姑娘」第四段「储物间」（floor_06_knight_storage）：她小时候躲起来哭的地方。墙上挂满旧痒痒刷（OldBrush，BRUSHES），看准间隔走过去，
##   走到最里面的箱子旁（DOLL，DOLL_R）按 E 找到旧布偶 → 回忆的台词（「抱着它，就不怕了」）→ 这一段做完。
## 测试：brushes、take()。

const BRUSHES := [[Vector2i(6, 2), true, 0.0], [Vector2i(8, 5), false, 0.8], [Vector2i(10, 2), true, 1.6], [Vector2i(12, 5), false, 0.4]]
const DOLL := Vector2i(14, 4)
const DOLL_R := 16.0

var brushes: Array = []
var _done := false


func s() -> Dictionary:
	return q.get("storage", {})


func setup() -> void:
	brushes.clear()
	for spec in BRUSHES:
		var b := OldBrush.new()
		b.down = bool(spec[1])
		b.phase_offset = float(spec[2])
		put(b, Cutscene.cell_to_world(spec[0]) + Vector2(0, -8 if b.down else 6))
		brushes.append(b)
	put(DollMark.new(), Cutscene.cell_to_world(DOLL))
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_blue_storage_intro"):
		return
	GameState.set_flag("kq_blue_storage_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(s().get("intro", []), "kq_storage_intro")


func _process(_delta: float) -> void:
	if _done or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	if Input.is_action_just_pressed("interact"):
		take(GameState.player)


func take(who: Node2D) -> bool:
	if _done or who.global_position.distance_to(Cutscene.cell_to_world(DOLL)) > DOLL_R:
		return false
	_done = true
	_finish()
	return true


func _finish() -> void:
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(s().get("found", []), "kq_storage_found")
	while Dialogue.is_active():
		await get_tree().process_frame
	advance()


## 角落箱子里露出一角的旧布偶（一闪一闪）
class DollMark extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2(0, -6), 3.0, Color(0.95, 0.85, 0.8))
		draw_rect(Rect2(-3, -4, 6, 5), Color(0.7, 0.5, 0.65))
		draw_line(Vector2(-1, -7), Vector2(1, -7), Color(0.3, 0.2, 0.25), 1.0)
		draw_circle(Vector2(6, -11), 0.8 + 0.4 * sin(_t * 6.0), Color(1, 1, 0.8, 0.9))
