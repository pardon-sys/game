class_name PlayerInputController
extends CharacterController
## 键盘 / 手柄输入（使用 Input Map 中的动作）。


func get_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func is_action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)
