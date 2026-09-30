extends Area2D
## 检查点：公主经过时记录复活位置。


func _ready() -> void:
	body_entered.connect(func(body: Node):
		if body.is_in_group("player"):
			GameState.checkpoint = global_position)
