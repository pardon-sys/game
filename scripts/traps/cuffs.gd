class_name CuffsTrap
extends RestraintTrap
## 举手铐柱：走到石柱前，柱子伸出铐环扣住手腕举过头顶（腋下露在外面）。露出部位：腋下 ×1.5。


func _hold_point() -> Vector2:
	return global_position + Vector2(0, 6)


func _on_restrain(_a: Actor) -> void:
	Audio.play("unlock", -2.0, 0.05, 0.8)
