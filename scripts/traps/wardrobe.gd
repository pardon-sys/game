class_name WardrobeTrap
extends RestraintTrap
## 挠痒衣柜（墙面）：从门口走过就被拉进柜子关上门，只露出两只脚；柜里很多只手挠腰和腋下，
## 露在外面的脚还会被别的怪物挠。露出部位：脚心 ×1.3。


func _hold_point() -> Vector2:
	return global_position + Vector2(0, 10)


func _on_restrain(a: Actor) -> void:
	Audio.play("door_close", -2.0, 0.05, 1.2)
	if "sprite_hidden" in a:
		a.set("sprite_hidden", true)
	if sprite:
		sprite.frame = 2


func _on_free(a: Actor) -> void:
	if is_instance_valid(a) and "sprite_hidden" in a:
		a.set("sprite_hidden", false)
	Audio.play("door", -4.0, 0.05, 1.2)
