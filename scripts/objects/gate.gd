extends StaticBody2D
## 铁栅门（Switchable）：拉杆的 target 与本门的 group_name 相同时由拉杆控制。

@export var group_name := "gate1"
@export var is_open := false

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(group_name)
	_apply(false)


## Switchable：通电 = 打开。
func set_active(on: bool) -> void:
	set_open(on)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	Audio.play("gate")
	_apply(true)


func _apply(animated: bool) -> void:
	shape.set_deferred("disabled", is_open)
	interactable.enabled = not is_open
	var y := -14.0 if is_open else -8.0
	var a := 0.0 if is_open else 1.0
	if animated:
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "offset:y", y, 0.4)
		tw.tween_property(sprite, "modulate:a", a, 0.4)
	else:
		sprite.offset.y = y
		sprite.modulate.a = a


func on_interact(_actor: Node) -> void:
	Audio.play("locked")
	Dialogue.start("gate_closed")
