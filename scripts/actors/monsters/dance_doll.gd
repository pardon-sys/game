class_name DanceDoll
extends Monster
## 舞会人偶（王座前厅的人偶舞会）：踮着脚转圈追人，用蕾丝扇和羽毛挠。图：assets/generated/npcs/dance_doll.png（4×4 走路图，女仆人偶换成舞会配色）。

var _anim_t := 0.0
var _row := 0


func _animate(delta: float) -> void:
	_anim_t += delta * (8.0 if velocity.length() > 5.0 else 2.0)
	if velocity.length() > 5.0:
		var sd := IsoView.screen_dir(velocity)
		_row = (1 if sd.x < 0 else 2) if absf(sd.x) > absf(sd.y) else (0 if sd.y > 0 else 3)
	sprite.frame = _row * 4 + int(_anim_t) % 4
