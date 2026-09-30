class_name HealthComponent
extends Node
## 血量组件（1 点 = 半颗心）。挂在 Actor 下，节点名 "Health"。

signal changed(hp: int, max_hp: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_hp := 10

var hp := 0


func _ready() -> void:
	if hp <= 0:
		hp = max_hp


func damage(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(amount)
	changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	var before := hp
	hp = mini(hp + amount, max_hp)
	if hp != before:
		healed.emit(hp - before)
	changed.emit(hp, max_hp)


## 回满（复活时用）。
func fill() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0


func is_full() -> bool:
	return hp >= max_hp
