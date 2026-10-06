class_name Duo
extends RefCounted
## 双人模式（第八层：粉色公主和蓝色公主同场）。
##   Duo.start([粉色, 蓝色], director)  开始：Tab（switch_character）切换操控，没操控的那个用 CompanionController（AI）；
##                                       倒下不放笑倒 CG，改成倒地（Downed），搭档按住 E 救起。
##   Duo.stop()                          结束（离开第八层时）
##   Duo.partner_of(角色)                另一个人
##   Duo.sacrifice_lock                  阶段三有人被抓去献祭时不能切换

static var active := false
static var members: Array[PlayableCharacter] = []
## 第八层的导演（Floor8Director）：倒地超时 / 两人都倒下时调用它的 on_defeat(reason)。
static var director: Node
## 给 AI 搭档的导演提示（BattleAIHooks；没给就是什么提示都没有）
static var hooks: BattleAIHooks
static var sacrifice_lock := false


static func start(chars: Array, dir: Node = null, ai_hooks: BattleAIHooks = null) -> void:
	active = true
	members.clear()
	for c in chars:
		if c is PlayableCharacter:
			members.append(c)
	director = dir
	hooks = ai_hooks
	sacrifice_lock = false
	_bind_tab()
	for c in members:
		if c != GameState.player:
			c.set_faction(Faction.Type.ALLY)
			c.set_controller(CompanionController.new())


static func stop() -> void:
	active = false
	members.clear()
	director = null
	hooks = null
	sacrifice_lock = false
	PlayerInputController.wasd_only = false


static func partner_of(c: Node) -> PlayableCharacter:
	for m in members:
		if is_instance_valid(m) and m != c:
			return m
	return null


static func can_switch() -> bool:
	if sacrifice_lock:
		return false
	var other := partner_of(GameState.player)
	return other != null and other.is_alive() and not Downed.is_downed(other)


## 两个人都倒下了吗。
static func all_down() -> bool:
	for m in members:
		if is_instance_valid(m) and not Downed.is_downed(m) and m.is_alive():
			return false
	return true


## Tab 也能切换（switch_character 原来只有测试模式的 F2）。
static func _bind_tab() -> void:
	if not InputMap.has_action("switch_character"):
		InputMap.add_action("switch_character")
	for ev in InputMap.action_get_events("switch_character"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_C:
			return
	var c := InputEventKey.new()
	c.physical_keycode = KEY_C
	InputMap.action_add_event("switch_character", c)
