class_name SpringSeat
extends LegTrap
## 弹簧刷座：地上的翻板，踩上去一把弹出矮凳把人「坐」住、双脚悬空，凳面的刷毛上下弹着刷屁股。
## 露出部位：butt ×1.4。共用行为见 LegTrap。


var _bounce_t := 0.0


func _fx_restrain(_a: Actor) -> void:
	TrapFx.boing(fx_parent(), global_position + Vector2(0, 6), 7.0)
	Audio.play("pop", -6.0, 0.1, 0.7)
	_bounce_t = 1.2


## 坐着的时候每弹一阵冒一圈小「嘣」。
func _fx_tick(delta: float) -> void:
	_bounce_t -= delta
	if _bounce_t <= 0.0:
		_bounce_t = 1.2
		TrapFx.boing(fx_parent(), global_position + Vector2(0, 6), 4.0)
