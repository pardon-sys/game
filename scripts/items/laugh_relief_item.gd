class_name LaughReliefItem
extends ItemData
## 降低闷笑值（例如薄荷糖）。

@export var amount := 40.0


func can_use(user: Node) -> bool:
	return user is Actor and user.laugh != null and user.laugh.value > 0.0


func use(user: Node) -> bool:
	if not can_use(user):
		return false
	user.laugh.reduce(amount)
	Audio.play("pickup")
	GameState.notify("吃了%s，清凉的感觉让人冷静下来。" % display_name)
	return true
