class_name MusicBoxItem
extends ItemData
## 女王的八音盒（石像问答的奖励）：只在王座间的 Boss 战里能用（PalaceThrone.use_music_box），不消耗；每场 PalaceThrone.BOX_USES 次。


func _throne(user: Node) -> Node:
	if user == null or not user.is_inside_tree():
		return null
	for n in user.get_tree().root.find_children("*", "", true, false):
		if n.get_script() and str(n.get_script().get_global_name()) == "PalaceThrone":
			return n
	return null


func can_use(user: Node) -> bool:
	return _throne(user) != null


func use(user: Node) -> bool:
	var t := _throne(user)
	if t:
		t.use_music_box()
	return false
