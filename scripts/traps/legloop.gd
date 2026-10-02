class_name LegLoopTrap
extends RestraintTrap
## 单腿吊环：天花板垂下的绳环套住一条腿吊高，只能单脚跳着原地打转。露出部位：脚心 + 大腿 ×1.3。


func _on_restrain(_a: Actor) -> void:
	Audio.play("swish", -3.0, 0.05, 0.9)


func _while_held(_delta: float) -> void:
	_rope_to(victim.global_position + Vector2(4, -4), Vector2(4, -48))
	if victim is PlayableCharacter:
		(victim as PlayableCharacter).pose_rotation = 0.2 + sin(_t * 6.0) * 0.12


func _on_free(_a: Actor) -> void:
	_hide_rope()
