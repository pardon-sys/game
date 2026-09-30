extends Node2D
## 拉杆（Interactable）：按 E 切换，对 target 组内所有 Switchable 调用 set_active(on)。
## target 可以写多个组，用逗号分隔（如 "pA,pB"）。

@export var target := "gate1"
@export var on := false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.frame = 5 if on else 4


func on_interact(_actor: Node) -> void:
	on = not on
	sprite.frame = 5 if on else 4
	Audio.play("lever")
	var count := 0
	for group in target.split(",", false):
		for n in get_tree().get_nodes_in_group(group.strip_edges()):
			if Contracts.is_switchable(n):
				n.set_active(on)
				count += 1
	if count > 0:
		GameState.notify("远处传来机关转动的声音……")
		GameState.emote("happy" if on else "sad", 1.5)
