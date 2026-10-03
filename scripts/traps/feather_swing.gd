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


var _extreme := -1


## 每荡到最高点：一道弧形轨迹 + 飘下一片羽毛。
func _fx_tick(_delta: float) -> void:
	if victim == null:
		return
	var phase := _hold_t * (5.0 + struggles * 0.4)
	var k := int(floor((phase - PI / 2.0) / PI))
	if k != _extreme:
		_extreme = k
		var amp := swing * (1.0 + 0.12 * struggles)
		var dir := 1.0 if sin(phase) > 0.0 else -1.0
		TrapFx.arc_trail(fx_parent(), victim.global_position + Vector2(0, -34), 34.0, -amp * dir, amp * dir)
		TrapFx.feather_puff(fx_parent(), victim.global_position + Vector2(0, 2), 1)


func _fx_free(_a: Actor) -> void:
	_extreme = -1
