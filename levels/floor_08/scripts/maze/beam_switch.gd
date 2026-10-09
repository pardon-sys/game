class_name BeamSwitch
extends Node2D
## 光开关（第八层夜迷宫）：一块月光水晶。月光镜的光带照着它 HOLD 秒 → 打开同组（group_name）的门（Gate.set_open），之后一直开着。
## 图例：X = beamswitch group=<门的组名>

const HOLD := 0.6

@export var group_name := "beam1"

var lit := false
var opened := false
var _t := 0.0
var _hold := 0.0


func _ready() -> void:
	add_to_group("beam_switch")


func set_lit(on: bool) -> void:
	lit = on


func _process(delta: float) -> void:
	_t += delta
	if lit and not opened:
		_hold += delta
		if _hold >= HOLD:
			opened = true
			for g in get_tree().get_nodes_in_group(group_name):
				if g.has_method("set_open"):
					g.set_open(true)
			Audio.play("unlock", -4.0)
			Fx.burst(get_parent(), global_position + Vector2(0, -8), "crystal", 10, 40.0, 0.6, Vector2(0, 30), Color(0.8, 0.9, 1.0))
	elif not lit:
		_hold = 0.0
	queue_redraw()


func _draw() -> void:
	var glow := 1.0 if opened else (0.6 + 0.4 * sin(_t * 8.0) if lit else 0.35)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(5, -8), Vector2(0, 0), Vector2(-5, -8)]),
		Color(0.6 * glow + 0.3, 0.8 * glow + 0.15, 1.0, 0.95))
	draw_circle(Vector2(0, 2), 4.0, Color(0, 0, 0, 0.3))
