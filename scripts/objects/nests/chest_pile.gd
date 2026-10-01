class_name ChestPile
extends MonsterNest
## 宝箱堆：生成宝箱怪，生成出来就是醒着的（不伪装，直接扑人）。


func _configure() -> void:
	kind = "chest_pile"
	monster_scene = "res://scenes/actors/monsters/mimic.tscn"
	sheet_row = 4


func _prepare(m: Monster) -> void:
	if m is Mimic:
		(m as Mimic).awake = true
