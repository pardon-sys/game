class_name FootThighRack
extends LegTrap
## 足腿刑架：脚踝锁进横板、脚心朝外，软垫杆把大腿分开；架子上的两组羽毛刷轮流刷脚心和大腿内侧。越挣扎刷子换得越快，还会多困一会儿（越挣扎越难挣脱）。
## 露出部位：sole ×1.4、thigh ×1.4。共用行为见 LegTrap。


func _fx_cycle(zone: String) -> void:
	TrapFx.stroke(fx_parent(), body_point(zone), Vector2.RIGHT if zone == "sole" else Vector2.LEFT)


func _fx_struggle(_n: int) -> void:
	if victim:
		TrapFx.speed_lines(fx_parent(), victim.global_position + Vector2(0, -10))
