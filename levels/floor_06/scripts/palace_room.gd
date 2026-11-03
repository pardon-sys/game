class_name PalaceRoom
extends Node2D
## 反省篇第四章·旧王宫各张图导演的公共部分（PalaceBath / PalaceServants / PalaceKitchen 继承）：
##   两人同行（Duo：按 C 换人、AI 搭档；倒地搭档按住 E 扶起；两个都倒下 → on_defeat → 小剧场 palace_down → 回检查点）；
##   检查点（map_id() 那张图的 checkpoints 标记，没有就用进图的位置）；跳关进来补穿鼠鼠装（penance_mouse_dev，挠脚鼠还没在厨房告别时）；
##   短台词 data/after/palace.json（data()）；等距：要单独投影的画面节点挂在 Entities（导演的父节点）下面（add_view）。

const PALACE_DATA := "res://data/after/palace.json"

var lv: Node
var pink: PlayableCharacter
var blue: PlayableCharacter
var checkpoint := Vector2.ZERO
var _tick := {}
var _defeat_busy := false
static var _data := {}


func map_id() -> String:
	return ""


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALACE_DATA))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func say_random(who: Node2D, key: String) -> void:
	var lines: Array = data().get(key, [])
	if not lines.is_empty() and is_instance_valid(who):
		SpeechBubble.say(who, str(lines.pick_random()), 28.0, 1.6)


static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 8.0)


func _ready() -> void:
	lv = get_parent()
	while lv and lv.get_node_or_null("Floor") == null and lv.get_parent():
		lv = lv.get_parent()
	if GameState.has_flag("penance_mouse_dev") and not GameState.has_flag(PalaceKitchen.FAREWELL_FLAG) and not PenanceCell.wearing_mouse():
		PenanceCell.wear_mouse()
	_start_duo.call_deferred()


func _start_duo() -> void:
	pink = GameState.player as PlayableCharacter
	for n in get_tree().get_nodes_in_group("player_chars"):
		if n is PlayableCharacter and (n as PlayableCharacter).character_id == "blue":
			blue = n
	if is_instance_valid(pink):
		checkpoint = pink.global_position
	if is_instance_valid(pink) and is_instance_valid(blue):
		Duo.start([pink, blue], self, ai_hooks())


func ai_hooks() -> BattleAIHooks:
	return BattleAIHooks.new()


func _exit_tree() -> void:
	if Duo.active and Duo.director == self:
		Duo.stop()


func members() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func busy() -> bool:
	return GameState.in_dialogue or GameState.in_cutscene or CG.is_busy() or Dialogue.is_active()


func add_view(n: Node2D) -> void:
	get_parent().add_child.call_deferred(n)


func cells(key: String) -> Array[Vector2i]:
	return QuestMaps.cells(map_id(), key)


func world(c: Vector2i) -> Vector2:
	return Cutscene.cell_to_world(c)


func tickle(pc: PlayableCharacter, key: String, every: float, amount: float, zone: String, delta: float, src: Node = null) -> void:
	var k := str(pc.get_instance_id()) + key
	_tick[k] = float(_tick.get(k, 0.0)) - delta
	if float(_tick[k]) <= 0.0:
		_tick[k] = every
		var h := HitData.make_tickle(src if src else self, amount)
		h.zone = zone
		pc.receive_hit(h)


func update_checkpoints(r := 16.0) -> void:
	for c in cells("checkpoints"):
		for m in members():
			if (m as Node2D).global_position.distance_to(world(c)) <= r:
				checkpoint = world(c)


## 走到某处自动演一次的小剧场（标记点 key，theater_id）
func auto_theater(key: String, theater_id: String, r := 16.0) -> bool:
	if GameState.has_flag("cg_seen_theater:" + theater_id):
		return false
	for c in cells(key):
		for m in members():
			if (m as Node2D).global_position.distance_to(world(c)) <= r:
				CG.play_theater(theater_id)
				return true
	return false


## 两个都倒下：小剧场 → 都扶起来、回检查点
func on_defeat(_reason: String) -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	await CG.play_theater(defeat_theater())
	reset_to(checkpoint)
	_defeat_busy = false


func defeat_theater() -> String:
	return "palace_down"


func reset_to(at: Vector2) -> void:
	for c in members():
		var pc := c as PlayableCharacter
		if Downed.is_downed(pc):
			(pc.get_node("Downed") as Downed).revive_now()
		pc.status.clear_root()
		pc.laugh.set_value(0.0)
		pc.global_position = at + (Vector2(10, 0) if pc.character_id == "blue" else Vector2.ZERO)
	var p := GameState.player
	if is_instance_valid(p) and p.get("camera"):
		p.camera.reset_smoothing()
