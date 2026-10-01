class_name MagicResetItem
extends ItemData
## 星光糖：星光爆发的冷却立即清零。需要已经学会魔法、并且正在冷却中。


func can_use(user: Node) -> bool:
	return user is PlayableCharacter and (user as PlayableCharacter).is_magic_unlocked() \
			and (user as PlayableCharacter).magic_cooldown_left() > 0.0


func use(user: Node) -> bool:
	if not can_use(user):
		return false
	(user as PlayableCharacter).reset_magic_cooldown()
	Audio.play("chime", -2.0, 0.02, 1.4)
	GameState.notify("吃了%s，星光又亮起来了！" % display_name)
	return true
