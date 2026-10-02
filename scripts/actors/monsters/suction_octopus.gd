class_name SuctionOctopus
extends LatchMonster
## 吸盘章鱼宝宝：一蹦一蹦地追过来，扑到胸前吸住，八条小腕绕到肋骨和腋下挠（部位：胸 3、腋下 1）。
## 吸着时公主移速 ×0.85，要抖 4 下才掉。数值见 data/monsters/suction_octopus.tres。


func _animate(_delta: float) -> void:
	if is_latched():
		sprite.frame = 2
		sprite.scale = Vector2.ONE * (1.0 + sin(_t * 12.0) * 0.06)
		return
	sprite.scale = Vector2.ONE
	sprite.frame = int(_t * 4.0) % 2
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
