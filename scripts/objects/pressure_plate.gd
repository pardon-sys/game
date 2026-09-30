extends Area2D
## 压力板：公主或友军踩上去时，对 target 组内所有 Triggerable（有 trigger() 方法的节点，如机关手）调用 trigger()。

signal pressed
signal released_plate

@export var target := "hand1"

@onready var sprite: Sprite2D = $Sprite

var _down := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false


func _physics_process(_delta: float) -> void:
	var occupied := false
	for b in get_overlapping_bodies():
		if b is Actor and Faction.of(b) in [Faction.Type.PLAYER, Faction.Type.ALLY]:
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
