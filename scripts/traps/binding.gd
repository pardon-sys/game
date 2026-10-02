class_name BindingTrap
extends RestraintTrap
## 羽毛绑腿：地上的缎带一碰就把两条腿缠在一起，只能兔子跳（很慢、不能冲刺），每跳一下缎带里的羽毛就蹭一下大腿；
## 连按 presses 次或 lock_time 秒后松开。露出部位：大腿 ×1.3。


func _restraint_setup() -> void:
	mode = "hobble"


func _on_restrain(_a: Actor) -> void:
	Audio.play("cloth", -2.0, 0.05, 1.1)


func _while_held(_delta: float) -> void:
	if sprite:
		sprite.global_position = victim.global_position + Vector2(0, -2)
		sprite.z_index = 3
	if victim is PlayableCharacter:
		(victim as PlayableCharacter).pose_offset = Vector2(0, -absf(sin(_t * 7.0)) * 3.0)


func _on_free(_a: Actor) -> void:
	if sprite:
		sprite.z_index = 0
		sprite.position = Vector2.ZERO
