extends Area2D
## 关卡出口 / 楼梯：公主走进来时（可先播放一段对话）切换到 target_level。
## target_level 为 "next" 时按 data/floors.json 进入当前楼层的下一层。
## spawn：到了新地图站在同名的到达点（SpawnPoint）上（第六层小镇的楼梯用）；down：楼梯的样子（往下 / 往上）。
## locked：封住的出口（只播 dialogue，不走）。

@export var target_level := ""
@export var dialogue := ""
@export var size := Vector2(16, 16)
@export var spawn := ""
@export var down := true:
	set(v):
		down = v
		var look := get_node_or_null("Look")
		if look:
			look.set("kind", "stairs_down" if v else "stairs_up")
@export var locked := false

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
	if locked:
		await get_tree().create_timer(1.0).timeout
		_used = false
		return
	GameState.pending_spawn = spawn
	var path := resolve_target()
	var main := get_tree().get_first_node_in_group("main")
	if main and path != "":
		main.change_level(path)


func resolve_target() -> String:
	if target_level != "next":
		return target_level
	var next := Floors.next_of(str(owner.get("floor_id")) if owner else "")
	return Floors.scene(next) if next != "" else ""
