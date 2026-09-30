extends Node
## 全局状态：玩家引用、背包、剧情标记、检查点，以及跨对象的事件总线。
## 血量、闷笑值等角色数值由角色自己的组件（HealthComponent / LaughMeter）管理。

signal player_registered(player: PlayableCharacter)
signal enemy_defeated(enemy: Node)
## Boss 出现（monster）或结束（null），HUD 显示 / 隐藏 Boss 血条。
signal boss_changed(monster: Node)
signal toast(text: String)
## 请求玩家角色做表情。duration <= 0 表示一直保持直到下一次请求；emotion 为 "" 表示松开。
signal emotion_requested(emotion: String, duration: float, bubble: bool)
## 玩家角色当前表情已改变（HUD 头像监听）。
signal emotion_changed(emotion: String)
signal bubble_requested(kind: String)
## Non-blocking princess reaction captions; empty text clears the current caption.
signal princess_reacted(text: String, duration: float)
## 组合技触发（HUD 横幅）。
signal combo_triggered(id: String, combo_name: String)

# Source of truth shared with the art importer.
## 11 种表情 / 状态（剧情、事件可以请求的）。
var EMOTIONS: Array[String] = _load_visuals("order")
## 6 种魔法姿态（吟诵 / 释放 × 普通 / 战损 / 战损闷笑），只由 Princess.resolve_visual 在施法时选用。
var MAGIC_VISUALS: Array[String] = _load_visuals("magic_order")
## 全部视觉状态 = 立绘 / 头像的顺序。
var VISUALS: Array[String] = EMOTIONS + MAGIC_VISUALS


func _load_visuals(key: String) -> Array[String]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/actors/princess_visuals.json"))
	var names: Array[String] = []
	names.assign(data.get(key, []))
	return names

var player: PlayableCharacter
var inventory := Inventory.new()
var flags := {}
var checkpoint := Vector2.ZERO
var in_dialogue := false


## 关卡切换时暂存的公主状态（血量、闷笑值、战损）。
var carried_player_state := {}


func register_player(p: PlayableCharacter) -> void:
	player = p
	restore_player_state(p)
	player_registered.emit(p)


func save_player_state() -> void:
	if not is_instance_valid(player):
		return
	carried_player_state = {
		"hp": player.health.hp if player.health else 0,
		"laugh": player.laugh.value if player.laugh else 0.0,
		"battle_damaged": player.get("battle_damaged") == true,
	}


func restore_player_state(p: PlayableCharacter) -> void:
	if carried_player_state.is_empty():
		return
	var s := carried_player_state
	carried_player_state = {}
	if p.health:
		p.health.set_hp(s["hp"])
	if p.laugh:
		p.laugh.set_value(s["laugh"])
	if "battle_damaged" in p:
		p.battle_damaged = s["battle_damaged"]


func reset() -> void:
	Audio.set_voice_state("")
	princess_reacted.emit("", 0.0)
	inventory.clear()
	flags = {}
	in_dialogue = false
	checkpoint = Vector2.ZERO
	carried_player_state = {}
	player = null


## 把物品交给角色：auto_use_on_pickup 的立即使用，其余放入背包。announce 时弹提示。
func give_item(item: ItemData, amount := 1, user: Node = null, announce := false) -> void:
	if item == null:
		return
	user = user if user else player
	if item.auto_use_on_pickup:
		for i in amount:
			item.use(user)
	else:
		inventory.add(item, amount)
	Audio.play(item.pickup_sound, -4.0 if item.category == ItemData.Category.CURRENCY else 0.0)
	if announce:
		notify("获得了%s%s！" % [item.display_name, " ×%d" % amount if amount > 1 else ""])
	if item.pickup_emotion != "":
		emote(item.pickup_emotion)


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func emote(emotion: String, duration := 2.5, bubble := true) -> void:
	emotion_requested.emit(emotion, duration, bubble)


func show_bubble(kind: String) -> void:
	bubble_requested.emit(kind)


func notify(text: String) -> void:
	toast.emit(text)
