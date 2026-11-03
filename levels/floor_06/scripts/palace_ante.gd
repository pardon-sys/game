class_name PalaceAnte
extends PalaceRoom
## 第四章⑦·王座前厅（floor_06_palace_ante，中转；台词 penance_text/palace3.py）：
##   南 → 训练场、西 → 钟楼、北 → 王座间（exit，unlock_flag = palace_bells_done：钟顶敲十三下才开）、东墙的画后 → 隧道（第一次从这里进）；
##   门口的骑士石像（statue，线索）；画后面的入口画成一幅歪掉的画（PaintingDoor）。

const MAP := "floor_06_palace_ante"


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = "floor_06/ante_statue"
	add_child(sp)
	sp.global_position = world(cells("statue")[0])
	var d := PaintingDoor.new()
	d.position = world(cells("painting")[0])
	add_view(d)


## 歪挂在墙上的大画（画后面是密道）——各个房间的密道入口都用这个画
class PaintingDoor extends Node2D:
	var tint := Color(0.55, 0.35, 0.45)

	func _draw() -> void:
		var r := Rect2(-9, -30, 18, 22)
		draw_set_transform(Vector2.ZERO, 0.08, Vector2.ONE)
		draw_rect(r.grow(2), Color(0.75, 0.58, 0.25))
		draw_rect(r, tint)
		draw_circle(Vector2(0, -22), 4.0, Color(0.85, 0.75, 0.7))
		draw_rect(Rect2(-5, -18, 10, 9), tint.lightened(0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-8, -8, 16, 2), Color(0, 0, 0, 0.35))
