class_name FeatherSwing
extends LegTrap
## 羽毛秋千：走过时被吊起来坐在秋千上、双腿悬空；往前摆时下面的羽毛扫脚心，往回摆时两侧的刷子刷大腿内侧。挣扎让秋千摆得更高、挠得更重。
## 露出部位：sole ×1.3、thigh ×1.3。共用行为见 LegTrap。


func _while_held(delta: float) -> void:
	super(delta)
	_rope_to(victim.global_position + Vector2(0, -14), Vector2(0, -44))


func _on_free(a: Actor) -> void:
	super(a)
	_hide_rope()
