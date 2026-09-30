class_name ScriptedController
extends CharacterController
## 由代码驱动的输入（测试、过场动画、演示）。
##   ctrl.move = Vector2.RIGHT   持续移动
##   ctrl.press(&"attack")       下一帧触发一次动作

var move := Vector2.ZERO
var _pressed := {}


func press(action: StringName) -> void:
	_pressed[action] = true


func get_move_vector() -> Vector2:
	return move


func is_action_just_pressed(action: StringName) -> bool:
	return _pressed.get(action, false)


func end_frame() -> void:
	_pressed.clear()
