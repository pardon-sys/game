class_name CushionTrap
extends RestraintTrap
## 痒痒坐垫：地上的软垫，踩上去被拉坐下扣住，垫子里的刷毛来回刷（屁股 ×1.5）。


func _on_restrain(_a: Actor) -> void:
	Audio.play("puddle", -4.0, 0.08, 1.4)


func _while_held(_delta: float) -> void:
	if victim is PlayableCharacter:
		(victim as PlayableCharacter).pose_offset = Vector2(roundf(sin(_t * 9.0)), 3.0)
