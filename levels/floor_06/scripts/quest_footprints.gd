class_name QuestFootprints
extends QuestRunner
## 支线「点灯笼的小姑娘」第一段（夜里的小镇）：蓝色公主不见了，地上一串淡淡的冰晶脚印（IcePrint，PATH）从广场一直通到西南角的旧石灯笼（LANTERN）。
##   跟着走到灯笼旁（LANTERN_R）→ 过场 kq_blue_lantern（「小时候，每年都是我点它」）→ 这一段做完。这一段里蓝色公主站在灯笼那边（AfterBlueRoutine）。
## 测试：prints。

const PATH := [Vector2i(38, 26), Vector2i(34, 27), Vector2i(30, 28), Vector2i(26, 29), Vector2i(22, 30), Vector2i(18, 30), Vector2i(14, 31), Vector2i(10, 31)]
const LANTERN := Vector2i(7, 31)
const LANTERN_R := 24.0

var prints: Array = []
var _found := false


func setup() -> void:
	prints.clear()
	for i in PATH.size():
		var p := put(IcePrint.new(), Cells.to_world(PATH[i])) as IcePrint
		p.index = i
		prints.append(p)
	put(QuestBlueLantern.OldLantern.new(), Cells.to_world(LANTERN))


func _process(_delta: float) -> void:
	if _found or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if pink.global_position.distance_to(Cells.to_world(LANTERN)) <= LANTERN_R:
		found()


func found() -> void:
	_found = true
	var cut := str(q.get("found_cut", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()


## 一个淡淡的冰晶脚印（一闪一闪，越往前越新）
class IcePrint extends Node2D:
	var index := 0
	var _t := 0.0

	func _ready() -> void:
		z_index = 0
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a := 0.35 + 0.25 * sin(_t * 3.0 - index * 0.6)
		for side in [-1.0, 1.0]:
			var o := Vector2(side * 3.0, side * 2.0)
			draw_circle(o, 2.2, Color(0.7, 0.9, 1.0, a))
			for k in 3:
				draw_circle(o + Vector2(-1.5 + k * 1.5, -2.6), 0.8, Color(0.8, 0.95, 1.0, a))
