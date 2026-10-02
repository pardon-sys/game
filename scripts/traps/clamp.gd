class_name ClampTrap
extends RestraintTrap
## 夹腿枷台：两块带绒毛的木板从两边合拢把大腿夹住、人坐倒在台上；绒毛轻轻蹭大腿内侧。露出部位：大腿 ×1.5。


func _on_restrain(_a: Actor) -> void:
	Audio.play("stocks", -2.0, 0.05, 0.9)
	Fx.burst(get_parent(), global_position, "chip", 6, 35.0, 0.4)
