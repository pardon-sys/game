class_name CleanseItem
extends ItemData
## 清心花露：清掉全部「疲倦印记」（疲倦爆发留下的永久闷笑积累 +1% 减益）。只由 Boss 掉落，R 键使用。

@export var buff_id := "fatigue_scar"


func can_use(user: Node) -> bool:
	return user is Actor and (user as Actor).buff_stacks(buff_id) > 0


func use(user: Node) -> bool:
	if not can_use(user):
		return false
	var n: int = (user as Actor).buff_stacks(buff_id)
	(user as Actor).remove_buff(buff_id)
	Audio.play("chime", -2.0, 0.02, 1.2)
	GameState.notify("喝下%s，%d 层疲倦印记全部消散了。" % [display_name, n])
	GameState.emote("happy", 1.5)
	return true
