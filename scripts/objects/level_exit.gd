extends Area2D
## 关卡出口：公主走进来时（可先播放一段对话）切换到 target_level。
## target_level 为 "next" 时按 data/floors.json 进入当前楼层的下一层。

@export var target_level := ""
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
	var path := resolve_target()
	var main := get_tree().get_first_node_in_group("main")
	if main and path != "":
		main.change_level(path)


func resolve_target() -> String:
	if target_level != "next":
		return target_level
	var next := Floors.next_of(str(owner.get("floor_id")) if owner else "")
	return Floors.scene(next) if next != "" else ""
