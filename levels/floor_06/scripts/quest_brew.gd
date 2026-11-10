class_name QuestBrew
extends QuestRunner
## 支线「手印样本」第六段「熬药」（药剂师工房 floor_06_after_pharmacy）：走到药锅旁边（POT，POT_R 以内）→ 熬药（BrewShow）。
##   熬完 → 这一段做完（支线做完：过场 kq_samples_done、安神香）；中途退出就站在原地，走开再走回来可以再熬。
## 测试：brew()、pot。

const POT := Vector2i(11, 7)
const POT_R := 12.0

var pot: Node2D
var brewing := false


func setup() -> void:
	pot = put(PotMark.new(), Cells.to_world(POT)) as Node2D


func _process(_delta: float) -> void:
	if brewing or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if pink.global_position.distance_to(pot.global_position) <= POT_R:
		brew()


func brew() -> bool:
	if brewing:
		return false
	brewing = true
	var show := BrewShow.new()
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	if ok:
		await advance()
	elif is_instance_valid(pink):
		pink.global_position = pot.global_position + Vector2(0, 30)
	brewing = false
	return ok


## 炉子上的药锅（一闪一闪：走过来熬）
class PotMark extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# 药锅本身是地图上的道具（cauldron）：这里只画「走过来熬」的一闪一闪和冒的泡
		for i in 2:
			var k := fmod(_t + i * 0.5, 1.0)
			draw_circle(Vector2(-2 + i * 4, -22 - k * 8.0), 1.4, Color(0.8, 0.7, 1.0, 1.0 - k))
		draw_circle(Vector2(0, -6), 9.0 + sin(_t * 4.0), Color(1, 0.9, 0.5, 0.18))
