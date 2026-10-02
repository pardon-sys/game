class_name VestTrap
extends RestraintTrap
## 羽毛背心：地上叠着的小背心，一碰就套到身上（绊住：还能慢慢走、不能冲刺），背心里的羽毛一直挠肋骨和锁骨（胸 ×1.3）；
## 连按 presses 次或 lock_time 秒后脱掉。


func _restraint_setup() -> void:
	mode = "hobble"


func _on_restrain(_a: Actor) -> void:
	Audio.play("cloth", -2.0, 0.05, 1.3)


func _while_held(_delta: float) -> void:
	if sprite:
		sprite.global_position = victim.global_position + Vector2(0, -14)
		sprite.z_index = 3
		sprite.frame = 1 if int(_t * 8.0) % 2 == 0 else 0


func _on_free(_a: Actor) -> void:
	if sprite:
		sprite.z_index = 0
		sprite.position = Vector2.ZERO
