class_name ScoreItem
extends ItemData
## 完整的笑声乐谱（三片笑声乐谱自动合成）：使用 = 打开 ScoreView，看王座前厅笑声地砖的踩法（PalaceAnte.TILE_SEQ）；不消耗。


func can_use(_user: Node) -> bool:
	return true


func use(user: Node) -> bool:
	if user and user.is_inside_tree():
		ScoreView.open(user.get_tree())
	return false
