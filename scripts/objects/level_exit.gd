extends Area2D
## 关卡出口：公主走进来时（可先播放一段对话）切换到 target_level。

@export_file("*.tscn") var target_level := ""
@export var dialogue := ""
@export var size := Vector2(16, 16)

var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player") or Dialogue.is_active():
		return
	_used = true
	if dialogue != "":
		Dialogue.start(dialogue)
		await Dialogue.finished
	var main := get_tree().get_first_node_in_group("main")
	if main and target_level != "":
		main.change_level(target_level)
