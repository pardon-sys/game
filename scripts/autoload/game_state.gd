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
## Q / R 快捷键绑定的物品改变（HUD 背包栏、背包界面）。
signal hotkeys_changed
## 获得或升级了被动技能（level = 新等级）。
signal passive_changed(id: String, level: int)
## 复活点变了（检查点据此亮 / 暗）。
signal checkpoint_changed(pos: Vector2)
## 剧情标记变了（居民按剧情出现 / 消失等）。
signal flag_changed(flag: String)

## 拿到冒险背包的剧情标记（第四层落脚点旁的储藏室）。
const BACKPACK_FLAG := "got_backpack"
## 快捷键默认绑定：Q 薄荷糖、R 清心花露。拿到背包后可以在背包里改。
const DEFAULT_HOTKEYS := {"use_item": "mint", "use_special": "clear_dew"}
const HOTKEY_LABELS := {"use_item": "Q", "use_special": "R"}

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
## 快捷键 -> 物品 id（use_item = Q，use_special = R）。跨层保留，重新开始时恢复默认。
var hotkeys := DEFAULT_HOTKEYS.duplicate()
var flags := {}
## 对话选择记下的变量（选择记忆，如 f6_attitude = "defiant"）；随存档保存。DialogueRunner 的条件 / 效果读写它。
var vars := {}
## 换地图后要站到的到达点（楼梯 LevelExit.spawn → Level 里同名的 SpawnPoint）。
var pending_spawn := ""
## 主界面选了「继续 / 读取」：main 场景准备好后读这个存档位（SaveSystem.load_slot）。
var pending_load := 0
## 游戏时长（秒，存档显示用；对话、过场中也计时，暂停时不计）。
var play_time := 0.0
## 人物被动技能：{id: 等级}（data/passives/passives.json；换层保留，重新开始清空）。
var passives := {}
var checkpoint := Vector2.ZERO
var in_dialogue := false
## 过场演出（笑倒 CG）进行中：对话一行行结束时不交还控制权，整个演出期间游戏保持冻结。
var in_cutscene := false


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
		"buffs": player.permanent_buffs(),
		"fatigue": player.fatigue.value if player.get("fatigue") else 0.0,
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
	if p.get("fatigue"):
		p.fatigue.set_value(float(s.get("fatigue", 0.0)))
	for id in s.get("buffs", {}):
		p.add_buff(id, -1.0, int(s["buffs"][id]))


func reset() -> void:
	Audio.set_voice_state("")
	princess_reacted.emit("", 0.0)
	inventory.clear()
	hotkeys = DEFAULT_HOTKEYS.duplicate()
	hotkeys_changed.emit()
	flags = {}
	vars = {}
	play_time = 0.0
	passives = {}
	in_dialogue = false
	in_cutscene = false
	checkpoint = Vector2.ZERO
	carried_player_state = {}
	player = null


func has_backpack() -> bool:
	return has_flag(BACKPACK_FLAG)


## 快捷键绑定的物品 id（没有绑定返回 ""）。
func hotkey_item(hotkey: String) -> String:
	return str(hotkeys.get(hotkey, ""))


## 物品绑定在哪个快捷键上："Q" / "R" / ""。
func hotkey_of(id: String) -> String:
	for hk in hotkeys:
		if hotkeys[hk] == id:
			return HOTKEY_LABELS.get(hk, "")
	return ""


## 把物品设到快捷键上；它原来在另一个键上时两边交换。
func set_hotkey(hotkey: String, id: String) -> void:
	if not HOTKEY_LABELS.has(hotkey):
		return
	var old := hotkey_item(hotkey)
	for hk in hotkeys:
		if hk != hotkey and hotkeys[hk] == id:
			hotkeys[hk] = old
	hotkeys[hotkey] = id
	hotkeys_changed.emit()


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


## 设复活点（检查点、存档读取、跳关都用它，检查点图标跟着亮暗）。
func set_checkpoint(pos: Vector2) -> void:
	checkpoint = pos
	checkpoint_changed.emit(pos)


func set_var(key: String, value: Variant) -> void:
	vars[key] = value


func _process(delta: float) -> void:
	if is_instance_valid(player) and not get_tree().paused:
		play_time += delta


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func emote(emotion: String, duration := 2.5, bubble := true) -> void:
	emotion_requested.emit(emotion, duration, bubble)


func show_bubble(kind: String) -> void:
	bubble_requested.emit(kind)


func notify(text: String) -> void:
	toast.emit(text)


# ------------------------------------------------------------------ 被动技能
func passive_level(id: String) -> int:
	return int(passives.get(id, 0))


## 获得被动技能（已有时不变）。返回是否新获得。
func grant_passive(id: String, silent := false) -> bool:
	if PassiveDB.info(id).is_empty() or passives.has(id):
		return false
	passives[id] = 1
	passive_changed.emit(id, 1)
	if not silent:
		notify("获得被动技能：%s" % PassiveDB.name(id))
	return true


## 升级被动技能（没有时先获得 1 级；满级不变）。返回是否升级了。
func upgrade_passive(id: String) -> bool:
	if not passives.has(id):
		return grant_passive(id)
	var lv := passive_level(id)
	if lv >= PassiveDB.max_level(id):
		return false
	passives[id] = lv + 1
	passive_changed.emit(id, lv + 1)
	notify("被动技能升级：%s Lv.%d" % [PassiveDB.name(id), lv + 1])
	return true
