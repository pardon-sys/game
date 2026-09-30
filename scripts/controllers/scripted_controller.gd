class_name ScriptedController
extends CharacterController
## 由代码驱动的输入（测试、过场动画、演示）。
##   ctrl.move = Vector2.RIGHT   持续移动
##   ctrl.press(&"attack")       下一帧触发一次动作
##   ctrl.hold(&"magic", true)   按住（蓄力），hold(&"magic", false) 松开

var move := Vector2.ZERO
var _pressed := {}
var _held := {}


func press(action: StringName) -> void:
	_pressed[action] = true


## 按住 / 松开；按下的那一帧同时算一次 just_pressed。
func hold(action: StringName, on: bool) -> void:
	if on and not _held.get(action, false):
		_pressed[action] = true
	_held[action] = on


func is_action_pressed(action: StringName) -> bool:
	return _held.get(action, false)


func get_move_vector() -> Vector2:
	return move


func is_action_just_pressed(action: StringName) -> bool:
	return _pressed.get(action, false)


func end_frame() -> void:
	_pressed.clear()
