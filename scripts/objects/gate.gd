extends StaticBody2D
## 铁栅门（Switchable）：拉杆的 target 与本门的 group_name 相同时由拉杆控制。

@export var group_name := "gate1"
@export var is_open := false
## 反接：通电时关上、断电时打开（用来做拉杆顺序谜题）。
@export var inverted := false

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var interactable: Interactable = $Interactable

## 关着 / 开着时图的纵向偏移（等距楼层换成方块栅栏门：开的时候沉进地面）
var _closed_y := -8.0
var _open_y := -14.0


func _ready() -> void:
	add_to_group(group_name)
	if IsoView.enabled:
		var t := IsoTheme.for_node(self)
		t.dress_cube(sprite, t.gate, t.gate_normal, 0)
		IsoView.anchor(sprite, Vector2(0, -8))
		_closed_y = sprite.offset.y
		_open_y = _closed_y + 12.0
	_apply(false)


## Switchable：通电 = 打开（inverted 时相反）。
func set_active(on: bool) -> void:
	set_open(on != inverted)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	Audio.play("gate")
	_apply(true)


func _apply(animated: bool) -> void:
	shape.set_deferred("disabled", is_open)
	interactable.enabled = not is_open
	var y := _open_y if is_open else _closed_y
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
