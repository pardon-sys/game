class_name TaskTotem
extends TaskShow
## 第 7 天弥补任务「修补狂欢图腾柱」（图腾柱废地 floor_06_after_totem）：TotemResonanceShow「图腾共鸣·双人符文」。
## 开演前把控制换回粉色公主（小游戏的闷笑 / 疲倦是她的）。失败（同一道符文裂开 3 次）→ AfterStory 演 after_fail_totem → reset_items → 从那一道重刻。
## 状态：vars.task_totem_runes（刻好几道）、task_totem_cracks（这一道裂了几次）。


static func runes() -> int:
	return TotemResonanceShow.saved_runes()


static func cracks() -> int:
	return TotemResonanceShow.saved_cracks()


## 失败后：这一道重新刻（刻好的不用重刻）
static func reset_items() -> void:
	GameState.vars[TotemResonanceShow.CRACK_KEY] = 0


static func status_text() -> String:
	return "符文 %d / 3　这一道裂了 %d / %d 次" % [runes(), cracks(), TotemResonanceShow.CRACKS]


func make_show() -> Node:
	var p := GameState.player
	if p is BluePrincess:
		for n in get_tree().get_nodes_in_group("player_chars"):
			if n is PlayableCharacter and not n is BluePrincess:
				GameState.switch_control(n)
				break
	return TotemResonanceShow.new()
