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
	# P 键设置菜单（角色画风、显示常驻立绘）
	var settings := SettingsMenu.new()
	settings.name = "SettingsMenu"
	add_child(settings)
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
## 测试模式：F2 在同一关卡的可操作角色间循环；业务场景仍由no_switch等原规则限制，候选只在同行的人里（Party）。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") and not GameState.in_dialogue:
		if level and level.get("no_switch") == true:
			GameState.notify("现在不能切换")
			get_viewport().set_input_as_handled()
		elif Duo.active:
			if Duo.can_switch():
				switch_character()
			get_viewport().set_input_as_handled()
		elif DevConfig.enabled() or (level and level.get_meta(&"free_switch", false)):
			# 测试模式 / 允许随时换人的图（七日赎罪的小场景：AfterRoom 设 free_switch）
			switch_character()
			get_viewport().set_input_as_handled()


func switch_character() -> bool:
	if level == null:
		return false
	var candidates: Array[PlayableCharacter] = []
	if DevConfig.enabled():
		# 测试模式：同一关卡的所有可操作角色
		for n in level.find_children("*", "", true, false):
			if n is PlayableCharacter and n.visible and n.is_alive() and not Downed.is_downed(n) and not n.has_meta(&"no_switch"):
				candidates.append(n)
	else:
		# 正常游戏：只在同行的人里换（Party：跟着走的、地图 party 里列出的、允许换人的场景里能换的）
		for c in Party.members(GameState.player):
			if Party.can_switch_to(GameState.player, c):
				candidates.append(c)
	if candidates.size() < 2:
		GameState.notify("这里没有可以切换的角色")
		return false
	var next := candidates[(candidates.find(GameState.player)+1)%candidates.size()]
	GameState.switch_control(next)
	GameState.notify("现在操控：%s" % next.display_name())
	return true


## 换关卡前换回公主（关卡之间只带公主的状态）。
func _restore_main_character() -> void:
	var main_id := "blue" if GameState.has_flag("blue_is_hero") else "pink"
	if is_instance_valid(GameState.player) and GameState.player.character_id != main_id and level:
		for n in level.find_children("*", "", true, false):
			if n is PlayableCharacter and n.character_id == main_id:
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
	path = StoryDirector.redirect_level(path)
	level = load(path).instantiate()
	add_child(level)
	move_child(level, 0)
	level_changed.emit(level)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw.finished
	_busy = false
