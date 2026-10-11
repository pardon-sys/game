class_name SiegeHorn
extends Node2D
## 城门口的号角架（图例 X = siegehorn）：准备阶段按 E 吹响 → 提前开打（SiegeDirector.start_now）。

var _area: Interactable


func _ready() -> void:
	add_child(SiegeArt.sprite("horn"))
	_area = Interactable.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	cs.shape = r
	_area.add_child(cs)
	_area.position = Vector2(0, -6)
	add_child(_area)
	_area.interacted.connect(func(_p: Node): blow())


func _process(_delta: float) -> void:
	var d := SiegeDirector.current
	_area.enabled = d != null and d.state == "prep"


func blow() -> void:
	var d := SiegeDirector.current
	if d == null or d.state != "prep":
		return
	Audio.play("chime", -2.0, 0.0, 0.5)
	GameState.notify("号角吹响了——怪物来了！")
	d.start_now()
