class_name ArenaZone
extends Area2D
## 锁门战斗房：公主走进范围 → 同组（group_name）的铁栅全部关上，被困在房间里；
## 范围内（外扩 margin）的怪物全部倒下 → 开门，提示后不再触发。
## 战斗中新出现在范围里的怪物（分裂的小史莱姆、召唤的精灵）也要打倒。
## 公主倒下（包括笑倒 CG）→ 重置：开门，下次进入重新布防；已经打倒的怪物不复活。
## 地图图例：X = arena group=<铁栅组> w=<格> h=<格>（放在房间中央；铁栅用 gate group=<同组> is_open=true）。

signal locked
signal cleared_room

@export var group_name := "arena1"
## 触发范围（像素）。比房间内部小一圈，保证公主已经走过门口才关门。
@export var size := Vector2(64, 64)
## 统计怪物时在触发范围外再扩出的距离（像素）。
@export var margin := 24.0

var active := false
var cleared := false
var _tracked: Array[Node] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	add_to_group("arena")
	body_entered.connect(_on_body_entered)


func room_rect() -> Rect2:
	return Rect2(global_position - size / 2.0 - Vector2(margin, margin), size + Vector2(margin, margin) * 2.0)


func _on_body_entered(body: Node) -> void:
	if active or cleared or not body.is_in_group("player") or not (body as Actor).is_alive():
		return
	lock(body as Actor)


func lock(player: Actor) -> void:
	_tracked.clear()
	_collect()
	if _tracked.is_empty():
		cleared = true
		return
	active = true
	_set_gates(false)
	Audio.play("gate", 0.0, 0.05, 0.8)
	GameState.notify("被困住了！打倒房间里所有的怪物")
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	locked.emit()


func remaining() -> int:
	return _tracked.filter(func(m): return is_instance_valid(m) and m.is_alive()).size()


func _collect() -> void:
	var rect := room_rect()
	for n in get_tree().get_nodes_in_group("enemy"):
		var m := n as Monster
		if m and m.is_alive() and not _tracked.has(m) and rect.has_point(m.global_position):
			_tracked.append(m)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	_collect()
	if remaining() == 0:
		_unlock()


func _unlock() -> void:
	active = false
	cleared = true
	_set_gates(true)
	GameState.notify("门打开了！")
	GameState.emote("happy", 1.5)
	cleared_room.emit()


## 公主倒下：开门、解除，下次进入重新布防。
func _on_player_died(_a: Actor) -> void:
	if active:
		active = false
		_tracked.clear()
		_set_gates(true)


func _set_gates(open: bool) -> void:
	for n in get_tree().get_nodes_in_group(group_name):
		if n != self and Contracts.is_switchable(n):
			n.set_active(open)
