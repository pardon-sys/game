class_name TrapRoomZone
extends Area2D
## 无解陷阱房（第五层最后）：公主走进范围 → 同组（group_name）的铁栅关上，满屋束缚陷阱，出不去；
## 在房里倒下就开门重置（在门口的检查点复活），倒下次数记在剧情标记 <group_name>_deaths。
## 第 ending_after 次倒下复活后立即播过场 ending_cutscene（data/cutscenes/<楼层组>/<id>.json）。
## 地图图例：X = traproom group=<铁栅组> w=<格> h=<格> cutscene=<过场 id>（放在房间中央）。

signal locked
signal ending_started

@export var group_name := "trap_room"
@export var size := Vector2(64, 64)
@export var ending_after := 4
@export var cutscene := ""

var active := false
var _waiting_respawn := false
var _ended := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	add_to_group("trap_room_zone")
	body_entered.connect(_on_body_entered)


func deaths() -> int:
	return int(GameState.flags.get(group_name + "_deaths", 0))


func _on_body_entered(body: Node) -> void:
	if active or _ended or GameState.in_cutscene or not body.is_in_group("player") or not (body as Actor).is_alive():
		return
	active = true
	_set_gates(false)
	Audio.play("gate", 0.0, 0.05, 0.7)
	GameState.notify("铁栅落下了……这个房间没有出口！")
	var p := body as Actor
	if not p.died.is_connected(_on_player_died):
		p.died.connect(_on_player_died)
	locked.emit()


func _on_player_died(_a: Actor) -> void:
	if not active:
		return
	active = false
	GameState.flags[group_name + "_deaths"] = deaths() + 1
	_set_gates(true)
	_waiting_respawn = true


func _process(_delta: float) -> void:
	if not _waiting_respawn:
		return
	var p := GameState.player
	if not is_instance_valid(p) or not p.is_alive() or CG.is_playing():
		return
	_waiting_respawn = false
	if deaths() >= ending_after and not _ended and cutscene != "":
		_ended = true
		ending_started.emit()
		Cutscene.play(cutscene)


func _set_gates(open: bool) -> void:
	for n in get_tree().get_nodes_in_group(group_name):
		if n != self and Contracts.is_switchable(n):
			n.set_active(open)
