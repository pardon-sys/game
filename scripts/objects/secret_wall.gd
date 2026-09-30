class_name SecretWall
extends Node2D
## 暗墙（Switchable）：所在格是一块普通的墙。同组的机关（如点亮的火把）激活后显出裂缝，
## 这时按 E 推倒，墙格变成通路。

@export var group_name := "secret1"
@export var revealed := false

var opened := false

@onready var crack: Sprite2D = $Crack
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(group_name)
	crack.visible = revealed
	interactable.enabled = revealed


## Switchable：通电 = 显出裂缝（不会再隐藏）。
func set_active(on: bool) -> void:
	if not on or revealed or opened:
		return
	revealed = true
	interactable.enabled = true
	crack.modulate.a = 0.0
	crack.show()
	# 裂缝不受黑暗影响，微微闪烁提示可以推开
	var tw := create_tween().set_loops()
	tw.tween_property(crack, "modulate:a", 1.0, 0.6)
	tw.tween_property(crack, "modulate:a", 0.55, 0.6)
	GameState.notify("火光照出墙上的一道裂缝……好像能推开？")
	GameState.emote("surprise", 1.5)


func on_interact(_actor: Node) -> void:
	if opened:
		return
	opened = true
	interactable.enabled = false
	crack.hide()
	var walls := _walls()
	if walls:
		walls.erase_cell(walls.local_to_map(walls.to_local(global_position + Vector2(0, -8))))
	Fx.puff(get_parent(), global_position + Vector2(0, -8))
	Audio.play("break")
	GameState.emote("happy", 1.5)


func _walls() -> TileMapLayer:
	var level := owner if owner else get_tree().current_scene
	return level.get_node_or_null("Walls") as TileMapLayer if level else null
