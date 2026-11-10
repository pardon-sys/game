class_name QuestBlueLantern
extends QuestRunner
## 支线「点灯笼的小姑娘」第二、六段（夜里的小镇，西南角的旧石灯笼 LANTERN）：走到灯笼旁 → BlueTickleShow。
##   第二段 tickle：逗她笑——灯笼亮一下又暗下去（笑声不够亮），去找「以前」；第六段 both：两个人一起笑，灯笼亮了 → 支线做完。
## 测试：play_show()、mode()、lantern。

const LANTERN := Vector2i(7, 31)
const LANTERN_R := 22.0

var playing := false
var lantern: OldLantern


func mode() -> String:
	return "tickle" if stage() == 1 else "both"


func setup() -> void:
	lantern = put(OldLantern.new(), Cells.to_world(LANTERN)) as OldLantern


func _process(_delta: float) -> void:
	if playing or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if pink.global_position.distance_to(lantern.global_position) <= LANTERN_R:
		play_show()


func play_show() -> bool:
	if playing:
		return false
	playing = true
	var show := BlueTickleShow.new()
	show.mode = mode()
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	if ok:
		if mode() == "both" and is_instance_valid(lantern):
			lantern.lit = true
		await advance()
	elif is_instance_valid(pink):
		pink.global_position = lantern.global_position + Vector2(0, 34)
	playing = false
	return ok


## 广场西南角的旧石灯笼：石头底座、四方的灯罩；点亮以后暖光一圈
class OldLantern extends Node2D:
	var lit := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 1
		lit = KnightQuests.is_done("blue")

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if lit:
			draw_circle(Vector2(0, -16), 18.0 + sin(_t * 3.0) * 1.5, Color(1, 0.85, 0.5, 0.2))
		draw_rect(Rect2(-6, -4, 12, 6), Color("7c7684"))
		draw_rect(Rect2(-2, -12, 4, 8), Color("8d8796"))
		draw_rect(Rect2(-6, -22, 12, 10), Color("6d6775"))
		draw_rect(Rect2(-4, -20, 8, 6), Color(1, 0.85, 0.45) if lit else Color("2c2633"))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -22), Vector2(0, -28), Vector2(8, -22)]), Color("5d5765"))
		# 底座上被磨掉的一行小字
		draw_line(Vector2(-4, -1), Vector2(4, -1), Color(0.55, 0.5, 0.6), 1.0)
