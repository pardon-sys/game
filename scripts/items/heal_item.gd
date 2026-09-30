class_name HealItem
extends ItemData
## 回复血量（1 = 半颗心）。

@export var amount := 2


func can_use(user: Node) -> bool:
	return user is Actor and user.health != null and not user.health.is_full()


func use(user: Node) -> bool:
	if not (user is Actor) or user.health == null:
		return false
	user.health.heal(amount)
	return true
