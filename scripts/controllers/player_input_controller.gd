class_name PlayerInputController
extends CharacterController
## 键盘 / 手柄输入（使用 Input Map 中的动作）。
## wasd_only：只用 WASD（和手柄）移动——第八层同时操作两个角色时，方向键留给右边小窗里的角色。

static var wasd_only := false
## actions_locked：只能移动，别的动作（攻击 / 魔法 / 冲刺 / 交互……）都不算按下——头顶的 QTE（J K L U I O）期间用。
static var actions_locked := false
## movement_locked：也不能移动（头顶的 QTE 期间：被紫手盯住了，站着按键）。
static var movement_locked := false


func get_move_vector() -> Vector2:
	if movement_locked:
		return Vector2.ZERO
	if wasd_only:
		var v := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if v == Vector2.ZERO and pad.length() > 0.3:
			v = pad
		return IsoMover.from_screen(get_parent(), v.limit_length(1.0))
	# 等距楼层：方向键按屏幕方向，换算成逻辑方向 + 走廊辅助（IsoMover）
	return IsoMover.from_screen(get_parent(), Input.get_vector("move_left", "move_right", "move_up", "move_down"))


func is_action_just_pressed(action: StringName) -> bool:
	if actions_locked:
		return false
	return Input.is_action_just_pressed(action)


func is_action_pressed(action: StringName) -> bool:
	if actions_locked:
		return false
	return Input.is_action_pressed(action)
