class_name ProneTrap
extends RestraintTrap
## 俯卧刑凳：被按趴在长凳上，双脚翘起来（屁股、脚心 ×1.3）。旁边常装着痒痒转轮。


func _on_restrain(_a: Actor) -> void:
	Audio.play("stocks", -3.0, 0.08, 0.8)
