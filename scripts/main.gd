extends Node
## 主场景：持有当前关卡、HUD、暂停菜单；负责关卡切换（淡出 → 换关卡 → 淡入）。
## 切换时把公主的血量 / 闷笑值 / 战损等保存到 GameState，新关卡的公主在 _setup 时恢复。

signal level_changed(level: Node)

var level: Node
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	add_to_group("main")
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
func change_level(path: String, keep_state := false) -> void:
	if _busy:
		return
	_busy = true
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
