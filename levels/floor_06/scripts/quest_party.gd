class_name QuestParty
extends QuestRunner
## 支线「没有名字的生日」第五、六段（骑士篇的小镇，篝火边 FIRE）：走到篝火边 → 生日舞排练（PartyShow dance）/ 忍笑许愿（PartyShow wish）。
##   赢了这一段做完（许愿那一段做完 = 支线做完：过场 kq_host_done）；输了 / 中途退出就站在原地，走开再走回来可以再来。
## 测试：play_show()、mode()。

const FIRE := Vector2i(44, 26)
const FIRE_R := 22.0

var playing := false
var mark: Node2D


func mode() -> String:
	return "dance" if stage() == 4 else "wish"


func setup() -> void:
	mark = put(QuestBrew.PotMark.new(), Cells.to_world(FIRE) + Vector2(0, 16)) as Node2D


func _process(_delta: float) -> void:
	if playing or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if pink.global_position.distance_to(mark.global_position) <= FIRE_R:
		play_show()


func play_show() -> bool:
	if playing:
		return false
	playing = true
	var show := PartyShow.new()
	show.mode = mode()
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	if ok:
		await advance()
	elif is_instance_valid(pink):
		pink.global_position = mark.global_position + Vector2(0, 34)
	playing = false
	return ok
