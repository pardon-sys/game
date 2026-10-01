class_name FairyFlower
extends MonsterNest
## 精灵花：生成羽毛小精灵群。


func _configure() -> void:
	kind = "fairy_flower"
	monster_scene = "res://scenes/actors/monsters/fairy_swarm.tscn"
	sheet_row = 1
