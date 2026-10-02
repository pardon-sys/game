extends Area2D
## 进入区域时播放对话（默认只触发一次）。

signal triggered

@export var dialogue := ""
## 播放地图内过场动画（data/cutscenes/<id>.json）；写了就不播对话。
@export var cutscene := ""
@export var once := true
## 触发区域大小（像素）。
@export var size := Vector2(16, 16)


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or Dialogue.is_active():
		return
	if once:
		set_deferred("monitoring", false)
	triggered.emit()
	if cutscene != "":
		GameState.set_flag("seen_cutscene_" + cutscene)
		Cutscene.play(cutscene)
		return
	GameState.set_flag("seen_" + dialogue)
	Dialogue.start(dialogue)
