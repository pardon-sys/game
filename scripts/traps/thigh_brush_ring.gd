class_name ThighBrushRing
extends LegTrap
## 大腿刷环：踩到中心时一圈刷环从地下升起套住双腿，边转边刷大腿内侧，困得越久转得越快。
## 露出部位：thigh ×1.4。共用行为见 LegTrap。


func _while_held(delta: float) -> void:
	super(delta)
	if sprite:
		sprite.frame_coords.x = 1 + int(_hold_t / maxf(self_interval, 0.1)) % 2
