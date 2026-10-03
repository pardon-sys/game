class_name ScissorStand
extends LegTrap
## 剪刀刷台：站上去时两块带刷毛的台板从两侧合拢夹住大腿内侧，下方的刷杆来回扫屁股；台板一开一合（合上的那半拍不抓人）。
## 露出部位：thigh ×1.4、butt ×1.2。共用行为见 LegTrap。


func _fx_restrain(_a: Actor) -> void:
	TrapFx.snap(fx_parent(), body_point("thigh"), true)


func _fx_close() -> void:
	TrapFx.snap(fx_parent(), global_position + Vector2(0, -4), true, 4.0)
