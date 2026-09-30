extends Node2D
## 墙上火把：未点燃时按 E 点亮，点亮后发光并闪烁。
## target 非空时，点亮会对该组的 Switchable 调用 set_active(true)（例如照出暗墙）。

@export var lit := false
@export var target := ""

@onready var sprite: Sprite2D = $Sprite
@onready var light: PointLight2D = $Light
@onready var interactable: Interactable = $Interactable

var _t := 0.0
var _base_energy := 1.0


func _ready() -> void:
	add_to_group("torch")
	_t = randf() * 10.0
	_refresh()


func _refresh() -> void:
	light.enabled = lit
	interactable.enabled = not lit
	if not lit:
		sprite.frame = 0


func on_interact(_player: Node) -> void:
	if lit:
		return
	lit = true
	Audio.play("torch", -6.0)
	light.energy = 0.0
	_refresh()
	create_tween().tween_property(light, "energy", _base_energy, 0.3)
	GameState.emote("happy", 1.2)
	if target != "":
		for n in get_tree().get_nodes_in_group(target):
			if Contracts.is_switchable(n):
				n.set_active(true)


func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	sprite.frame = 1 + int(_t * 8.0) % 3
	light.texture_scale = 1.1 + sin(_t * 7.0) * 0.04 + sin(_t * 13.0) * 0.03
