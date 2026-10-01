class_name BackpackItem
extends ItemData
## 冒险背包：拾取即生效（不进背包栏）。之后按 Tab / I 打开背包界面：查看物品、设定 Q / R 快捷键、查看当前状态。


func can_use(_user: Node) -> bool:
	return not GameState.has_backpack()


func use(_user: Node) -> bool:
	GameState.set_flag(GameState.BACKPACK_FLAG)
	Audio.play("chime", -2.0, 0.02, 1.1)
	if Dialogue.has_dialogue("got_backpack"):
		Dialogue.start.call_deferred("got_backpack")
	else:
		GameState.notify("得到了冒险背包！按 Tab / I 打开。")
	return true
