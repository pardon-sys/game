class_name LaughReliefItem
extends ItemData
## 降低闷笑值（例如薄荷糖）：按闷笑上限的比例降低。

@export_range(0.0, 1.0) var ratio := 0.27


func can_use(user: Node) -> bool:
	return user is Actor and user.laugh != null and user.laugh.value > 0.0


func use(user: Node) -> bool:
	if not can_use(user):
		return false
	user.laugh.reduce_ratio(ratio)
	Audio.play("pickup")
	GameState.notify("吃了%s，清凉的感觉让人冷静下来。" % display_name)
	return true
