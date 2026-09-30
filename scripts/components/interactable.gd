class_name Interactable
extends Area2D
## 可交互区域（放在物体下）。公主靠近并面向它时显示 E 提示，按 E 调用父节点的 on_interact(player)。

signal interacted(player: Node)

@export var enabled := true
## 交互提示图标相对本节点的位置。
@export var prompt_offset := Vector2(0, -22)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false


func interact(player: Node) -> void:
	interacted.emit(player)
	var p := get_parent()
	if p and p.has_method("on_interact"):
		p.on_interact(player)
