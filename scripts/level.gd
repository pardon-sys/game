extends Node2D
## 楼层根节点：载入本层对话、设置相机边界、播放开场对话。

## 楼层 id（levels/<floor_id>/），由构建器写入。
@export var floor_id := ""
@export var intro_dialogue := "intro"
## 开场过场动画（data/cutscenes/<id>.json）；写了就代替开场对话。
@export var intro_cutscene := ""

@onready var walls: TileMapLayer = $Walls


func _ready() -> void:
	Dialogue.load_floor(floor_id)
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
	if intro_cutscene != "":
		var cflag := "intro_done_" + intro_cutscene
		if not GameState.has_flag(cflag):
			GameState.set_flag(cflag)
			await get_tree().create_timer(0.6).timeout
			Cutscene.play(intro_cutscene)
		return
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
		"ending_3":
			GameState.set_flag("chapter3_clear")
		"ending_4":
			GameState.set_flag("chapter4_clear")
			GameState.emote("happy", 3.0)
			GameState.notify("第四章通关！感谢游玩（Esc → 重新开始）")
