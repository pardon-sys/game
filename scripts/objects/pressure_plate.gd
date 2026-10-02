class_name PressurePlate
extends Area2D
## 压力板：公主或友军踩上去时，对 target 组内所有 Triggerable（有 trigger() 方法的节点，如机关手）调用 trigger()。
## by_monsters = true：怪物踩上去也会触发（加入 monster_switch 组，机关小工匠会专门跑来踩）。

signal pressed
signal released_plate

@export var target := "hand1"
@export var by_monsters := false

@onready var sprite: Sprite2D = $Sprite

var _down := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 6 if by_monsters else 2
	monitorable = false
	if by_monsters:
		add_to_group("monster_switch")


func _physics_process(_delta: float) -> void:
	var occupied := false
	for b in get_overlapping_bodies():
		if b is Actor and (Faction.of(b) in [Faction.Type.PLAYER, Faction.Type.ALLY] or (by_monsters and b is Monster)):
			occupied = true
			break
	if occupied and not _down:
		_down = true
		sprite.frame = 1
		Audio.play("locked", -8.0, 0.1, 0.8)
		pressed.emit()
		for n in get_tree().get_nodes_in_group(target):
			if n.has_method("trigger"):
				n.trigger()
	elif not occupied and _down:
		_down = false
		sprite.frame = 0
		released_plate.emit()
