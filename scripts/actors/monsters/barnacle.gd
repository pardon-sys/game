class_name Barnacle
extends LatchMonster
## 藤壶贝：粘在地上不会走，公主从旁边 lunge_range 以内走过就弹到身上粘住，壳里伸出纤毛挠肋骨（部位：胸 3、腰 1）。
## 抖掉以后慢慢爬回原处继续等。数值见 data/monsters/barnacle.tres。


func _animate(_delta: float) -> void:
	var p := GameState.player
	var near := is_instance_valid(p) and global_position.distance_to(p.global_position) <= lunge_range * 2.0
	if is_latched() or near:
		sprite.frame = 1 + int(_t * 6.0) % 2
	else:
		sprite.frame = 0
