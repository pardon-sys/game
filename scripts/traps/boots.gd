class_name BootsTrap
extends RestraintTrap
## 痒痒长靴：地上摆着一双会动的长靴，走近就自己套到脚上：lock_time 秒内脱不下来，走路变慢、不能冲刺，
## 靴子里的羽毛一直挠脚心。时间到靴子自己跳回原处。露出部位：脚心 ×1.3。


func _restraint_setup() -> void:
	mode = "hobble"


func _on_restrain(_a: Actor) -> void:
	Audio.play("pop", -3.0, 0.05, 1.2)


func _while_held(_delta: float) -> void:
	if sprite:
		sprite.global_position = victim.global_position + Vector2(0, 1)
		sprite.z_index = 3


func _on_free(_a: Actor) -> void:
	if sprite:
		sprite.z_index = 0
		var tw := create_tween()
		tw.tween_property(sprite, "position", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_QUAD)
