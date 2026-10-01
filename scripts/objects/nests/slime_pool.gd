class_name SlimePool
extends MonsterNest
## 史莱姆池：生成史莱姆（split = true 时生成分裂史莱姆）。

@export var split := false


func _configure() -> void:
	kind = "slime_pool"
	monster_scene = "res://scenes/actors/monsters/%s.tscn" % ("split_slime" if split else "slime")
	sheet_row = 2
