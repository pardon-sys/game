class_name LampImp
extends Monster
## 偷灯小鬼（第八层夜迷宫）：戴灭烛帽的小黑鬼。去找最近的亮着的月光灯，走到旁边就吹灭它（MoonLamp.extinguish），然后去找下一盏。
## 碰到她：挠一下脚心（来源键 lamp_imp），顺手吹暗她的冷光 DIM 秒（CarryLight.dim，紫手的 QTE 提示变晚）。
## 它在灯旁边时那盏灯点不着（MoonLamp.on_interact 里检查）。

const SHEET := preload("res://assets/generated/maze/lamp_imp.png")
const DIM := 4.0
const LAMP_RANGE := 260.0

var _lamp: MoonLamp
var _look := 0.0


func _setup() -> void:
	super()
	add_to_group("lamp_imp")
	sprite.texture = SHEET
	sprite.hframes = 2
	sprite.region_enabled = false


func _tick(delta: float) -> void:
	_look -= delta
	if _look <= 0.0:
		_look = 1.0
		_lamp = _nearest_lit_lamp()
	# 有亮着的灯就先去吹灯（她没贴脸时）
	if _lamp and state != State.HURT and not GameState.in_dialogue:
		var p := GameState.player as Node2D
		var near_player := is_instance_valid(p) and p.global_position.distance_to(global_position) < 28.0
		if not near_player:
			var to := _lamp.global_position - global_position
			if to.length() < 14.0:
				_lamp.extinguish()
				SpeechBubble.say(self, "呼～", 18.0)
				_lamp = null
			else:
				_t += delta
				_move(to.normalized(), stats.chase_speed, delta)
				move_with_push()
				_animate(delta)
				return
	super(delta)


func _nearest_lit_lamp() -> MoonLamp:
	var best: MoonLamp = null
	var best_d := LAMP_RANGE
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		var lamp := l as MoonLamp
		if lamp and lamp.lit:
			var d := lamp.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = lamp
	return best


func _on_tickle_performed(t: Node) -> void:
	var cl := t.get_node_or_null("CarryLight") as CarryLight
	if cl:
		cl.dim(DIM)
		cl.spend(0.05)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 6.0) % 2
