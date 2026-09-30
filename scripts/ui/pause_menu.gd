extends CanvasLayer
## 暂停菜单（Esc）。

@onready var root: Control = $Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()
	$Root/Box/Resume.pressed.connect(toggle)
	$Root/Box/Restart.pressed.connect(_restart)
	$Root/Box/Quit.pressed.connect(func(): get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	root.visible = paused
	if paused:
		Audio.stop_voice()
		$Root/Box/Resume.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	GameState.reset()
	GameState.checkpoint = Vector2.ZERO
	get_tree().reload_current_scene()
