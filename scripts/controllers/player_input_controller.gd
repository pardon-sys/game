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
	if Input.is_action_just_pressed(action):
		return true
	# 卡键兜底：这个动作绑定的某个键这一帧刚按下，可动作还「卡在按住」（别的绑定键的松开事件丢了——
	# 比如 macOS 中文输入法用 Shift 切中英文时吞掉了 Shift 的松开，闪避 K / Shift 共用一个动作，K 就再也按不出「刚按下」；
	# 切出游戏再切回来 Godot 会把所有键松开，所以那样能好）。这时当成新按下，顺手把卡住的动作松开。
	if Input.is_action_pressed(action) and KeyEdges.pressed_now(action):
		Input.action_release(action)
		return true
	return false


## 动作绑定的键（键盘）这一帧有没有「刚按下」的：每个物理帧记一次每个键的状态，和上一帧比
class KeyEdges:
	static var _frame := -1
	static var _prev := {}     # 键码 → 上一帧按着没
	static var _now := {}      # 键码 → 这一帧按着没

	static func pressed_now(action: StringName) -> bool:
		var f := Engine.get_physics_frames()
		if f != _frame:
			_frame = f
			for k in _now:
				_prev[k] = _now[k]
				_now[k] = Input.is_physical_key_pressed(k) or Input.is_key_pressed(k)
		var hit := false
		for ev in InputMap.action_get_events(action):
			var kev := ev as InputEventKey
			if kev == null:
				continue
			var code := kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
			if not _now.has(code):
				# 第一次看这个键：先记下现在的状态（不算刚按下）
				var down := Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)
				_now[code] = down
				_prev[code] = down
				continue
			if bool(_now[code]) and not bool(_prev.get(code, false)):
				hit = true
		return hit


func is_action_pressed(action: StringName) -> bool:
	if actions_locked:
		return false
	return Input.is_action_pressed(action)
