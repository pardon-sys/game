extends SceneTree
## 写入工程设置（显示、像素渲染、Autoload、物理层命名、输入映射）。
## 用法：Godot --headless --path . --script res://tools/build/setup_project.gd


func _initialize() -> void:
	var s := {
		"application/config/name": "公主地牢冒险",
		"application/run/main_scene": "res://scenes/main.tscn",
		"display/window/size/viewport_width": 480,
		"display/window/size/viewport_height": 270,
		"display/window/size/window_width_override": 1440,
		"display/window/size/window_height_override": 810,
		"display/window/stretch/mode": "canvas_items",
		"display/window/stretch/aspect": "keep",
		"display/window/stretch/scale_mode": "integer",
		"rendering/textures/canvas_textures/default_texture_filter": 0,
		"rendering/2d/snap/snap_2d_transforms_to_pixel": true,
		"rendering/2d/snap/snap_2d_vertices_to_pixel": true,
		"rendering/environment/defaults/default_clear_color": Color(0.078, 0.047, 0.07),
		"autoload/GameState": "*res://scripts/autoload/game_state.gd",
		"autoload/Audio": "*res://scripts/autoload/audio.gd",
		"autoload/Dialogue": "*res://scenes/ui/dialogue_box.tscn",
		"layer_names/2d_physics/layer_1": "world",
		"layer_names/2d_physics/layer_2": "player_ally",
		"layer_names/2d_physics/layer_3": "enemy",
		"layer_names/2d_physics/layer_4": "interact",
		"layer_names/2d_physics/layer_6": "breakable",
	}
	if FileAccess.file_exists("res://ui/theme.tres"):
		s["gui/theme/custom"] = "res://ui/theme.tres"
	for k in s:
		ProjectSettings.set_setting(k, s[k])

	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)])
	_action("interact", [_key(KEY_E), _btn(JOY_BUTTON_A)])
	_action("attack", [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _btn(JOY_BUTTON_X)])
	_action("dash", [_key(KEY_K), _key(KEY_SHIFT), _btn(JOY_BUTTON_B), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("use_item", [_key(KEY_Q), _btn(JOY_BUTTON_Y)])
	_action("pause", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)])
	var err := ProjectSettings.save()
	print("project.godot 已更新: ", err)
	quit(err)


func _action(name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": 0.3, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = a
	e.axis_value = v
	return e


func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = b
	return e
