extends Node2D
## 楼层根节点：载入本层对话、设置相机边界、播放开场对话。

## 楼层 id（levels/<floor_id>/），由构建器写入。
@export var floor_id := ""
@export var intro_dialogue := "intro"
## 开场过场动画（data/cutscenes/<楼层组>/<id>.json）；写了就代替开场对话。
@export var intro_cutscene := ""
## 夜晚的环境光（a = 0 表示这张地图没有昼夜之分）；剧情标记 night 打开时换上，关掉时换回白天的。
@export var night_ambient := Color(0, 0, 0, 0)

var _day_ambient := Color.WHITE

@onready var walls: TileMapLayer = $Walls


func _ready() -> void:
	Dialogue.load_floor(floor_id)
	var dark := get_node_or_null("Darkness") as CanvasModulate
	if dark:
		_day_ambient = dark.color
	_apply_time_of_day()
	GameState.flag_changed.connect(_on_flag_changed)
	var player := get_tree().get_first_node_in_group("player") as PlayableCharacter
	# 从楼梯过来：站到同名的到达点上
	if player and GameState.pending_spawn != "":
		for sp in get_tree().get_nodes_in_group("spawn_point"):
			if str(sp.get("id")) == GameState.pending_spawn and is_ancestor_of(sp):
				player.global_position = (sp as Node2D).global_position
				GameState.set_checkpoint(player.global_position)
				break
		GameState.pending_spawn = ""
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
	if GameState.pending_load > 0:
		return  # 马上要读档换关卡：不播开场
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


func _on_flag_changed(f: String) -> void:
	if f == "night":
		_apply_time_of_day()


## 昼夜：有 night_ambient 的地图在剧情标记 night 时变暗。
func _apply_time_of_day() -> void:
	var dark := get_node_or_null("Darkness") as CanvasModulate
	if dark == null or night_ambient.a <= 0.0:
		return
	var target := night_ambient if GameState.has_flag("night") else _day_ambient
	if is_inside_tree() and dark.color != target:
		create_tween().tween_property(dark, "color", target, 1.2)
	else:
		dark.color = target


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
			GameState.notify("第四章通关！楼梯继续往下……")
		"ending_5":
			GameState.set_flag("chapter5_clear")
