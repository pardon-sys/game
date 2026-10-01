class_name JellyEgg
extends MonsterNest
## 水母卵：生成魔力水母。


func _configure() -> void:
	kind = "jelly_egg"
	monster_scene = "res://scenes/actors/monsters/mana_jelly.tscn"
	sheet_row = 3
