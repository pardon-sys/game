extends Node
## 主场景：持有当前关卡、HUD、暂停菜单；负责关卡切换（淡出 → 换关卡 → 淡入）。
## 切换时把公主的血量 / 闷笑值 / 战损等保存到 GameState，新关卡的公主在 _setup 时恢复。

signal level_changed(level: Node)

var level: Node
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	add_to_group("main")
	var director := StoryDirector.new()
	director.name = "StoryDirector"
	add_child(director)
	for c in get_children():
		if c.has_node("Walls"):
			level = c
			break
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.03, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	# 主界面选了「继续 / 读取存档」：读档（换到存档的关卡、站到存档位置）
	if GameState.pending_load > 0:
		var slot := GameState.pending_load
		GameState.pending_load = 0
		_fade.color.a = 1.0
		SaveSystem.load_slot.call_deferred(slot)


## keep_state：不把当前公主的状态带过去（读档时已经从存档设好了）。
## 测试模式：F2 在公主和蓝色公主（同一关卡里的其它可操作角色）之间切换操控。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") and DevConfig.enabled() and not GameState.in_dialogue:
		switch_character()
		get_viewport().set_input_as_handled()


func switch_character() -> bool:
	if level == null:
		return false
	var others: Array = []
	for n in level.find_children("*", "", true, false):
		if n is PlayableCharacter and n != GameState.player and n.visible and n.is_alive():
			others.append(n)
	if others.is_empty():
		GameState.notify("这里没有可以切换的角色")
		return false
	GameState.switch_control(others[0])
	GameState.notify("现在操控：%s" % (others[0].call("display_name") if others[0].has_method("display_name") else "公主"))
	return true


## 换关卡前换回公主（关卡之间只带公主的状态）。
func _restore_main_character() -> void:
	if GameState.has_flag("blue_is_hero"):
		return   # 蓝色公主是主角了：不切回粉色公主
	if GameState.player is BluePrincess and level:
		for n in level.find_children("*", "", true, false):
			if n is Princess and not (n is BluePrincess):
				GameState.switch_control(n)
				return


func change_level(path: String, keep_state := false) -> void:
	if _busy:
		return
	_busy = true
	_restore_main_character()
	if not keep_state:
		GameState.save_player_state()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	await tw.finished
	if level:
		remove_child(level)
		level.queue_free()
	GameState.checkpoint = Vector2.ZERO
	GameState.in_dialogue = false
	level = load(path).instantiate()
	add_child(level)
	move_child(level, 0)
	level_changed.emit(level)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw.finished
	_busy = false
