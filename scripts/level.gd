extends Node2D
## 关卡根节点：设置相机边界、播放开场对话。

@export var intro_dialogue := "intro"

@onready var walls: TileMapLayer = $Walls


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayableCharacter
	if player:
		var rect := walls.get_used_rect()
		var ts := walls.tile_set.tile_size
		var cam := player.camera
		cam.limit_left = rect.position.x * ts.x
		cam.limit_top = rect.position.y * ts.y
		cam.limit_right = rect.end.x * ts.x
		cam.limit_bottom = rect.end.y * ts.y
		cam.reset_smoothing()
	Dialogue.finished.connect(_on_dialogue_finished)
	var flag := "intro_done_" + intro_dialogue
	if intro_dialogue != "" and not GameState.has_flag(flag):
		GameState.set_flag(flag)
		await get_tree().create_timer(0.8).timeout
		Dialogue.start(intro_dialogue)


func _on_dialogue_finished(id: String) -> void:
	match id:
		"ending":
			GameState.set_flag("chapter1_clear")
		"ending_2":
			GameState.set_flag("chapter2_clear")
			GameState.emote("happy", 3.0)
			GameState.notify("第二章通关！感谢游玩（Esc → 重新开始）")
