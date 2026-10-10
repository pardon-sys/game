class_name StalkerZone
extends Area2D
## 固定追逐的触发区（第八层夜迷宫第三段：主路上一条长走廊）：她走进来 → 夜啼追手从她身后（spawn 格）冒出来，
## 屏幕中间黄字「跑！去月光灯！」，一直追到她走进下一盏月光灯（NightStalker.scripted_chase）。只触发一次（旗标 f8m_chase_<段>）。
## 图例：X = stalkerzone spawn=x,y

const STALKER := preload("res://levels/floor_08/scenes/night_stalker.tscn")

@export var spawn := ""

var done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 14)
	shape.shape = r
	add_child(shape)
	body_entered.connect(_on_body)


func flag() -> String:
	var d := MazeDirector.instance
	return "f8m_chase_%d" % (d.section if d else 0)


func spawn_point() -> Vector2:
	var xy := spawn.split(",")
	if xy.size() == 2:
		return Vector2(int(xy[0]) * 16 + 8, int(xy[1]) * 16 + 12)
	return global_position + Vector2(0, 64)


func _on_body(b: Node) -> void:
	if done or b != GameState.player or GameState.has_flag(flag()):
		return
	start()


func start() -> NightStalker:
	done = true
	GameState.set_flag(flag())
	var ns: NightStalker = null
	for n in get_tree().get_nodes_in_group("night_stalker"):
		if MazeDirector.instance and MazeDirector.instance.level().is_ancestor_of(n):
			ns = n
			break
	if ns == null:
		ns = STALKER.instantiate()
		get_parent().add_child(ns)
	ns.scripted_chase(spawn_point())
	GameState.hint("跑！去月光灯！")
	ScreenFx.flash(Color(0.5, 0.1, 0.7), 0.3)
	return ns
