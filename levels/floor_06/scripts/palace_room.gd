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


## 笑脸徽记（第四章追加事件）：每个来源（src）只给一枚；集齐 BADGES_ALL 枚到王座前厅的徽记台换女王的羽毛发饰
const BADGE_SOURCES := ["rat_king", "clockface", "vault", "statue", "scrub", "shade", "lost"]
const BADGES_ALL := 7


static func badge_flag(src: String) -> String:
	return "badge_" + src


static func badges() -> int:
	return BADGE_SOURCES.filter(func(s): return GameState.has_flag(badge_flag(s))).size()


static func give_badge(src: String) -> bool:
	if GameState.has_flag(badge_flag(src)):
		return false
	GameState.set_flag(badge_flag(src))
	var it := ItemDB.get_item("smile_badge")
	if it:
		GameState.give_item(it, 1)
	Audio.play("chime", -3.0, 0.0, 1.3)
	GameState.notify("得到一枚笑脸徽记（%d / %d）" % [badges(), BADGES_ALL])
	return true


## 笑声乐谱（三片：1 钟面暗格 / 2 送餐 / 3 浴场镜子）；王座前厅的笑声地砖要三片都有
static func sheets() -> int:
	return [1, 2, 3].filter(func(i): return GameState.has_flag("palace_sheet_%d" % i)).size()


static func give_sheet(i: int) -> bool:
	if GameState.has_flag("palace_sheet_%d" % i):
		return false
	GameState.set_flag("palace_sheet_%d" % i)
	var it := ItemDB.get_item("music_sheet")
	if it:
		GameState.give_item(it, 1)
	GameState.notify("得到一片笑声乐谱（%d / 3）" % sheets())
	return true


static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 8.0)


func _ready() -> void:
	lv = get_parent()
	while lv and lv.get_node_or_null("Floor") == null and lv.get_parent():
		lv = lv.get_parent()
	if GameState.has_flag("penance_mouse_dev") and not GameState.has_flag(PalaceKitchen.FAREWELL_FLAG) and not PenanceCell.wearing_mouse():
		PenanceCell.wear_mouse()
	_start_duo.call_deferred()
	_add_lost.call_deferred()
	if map_id() in [TRAY_FROM, TRAY_TO]:
		var tc := TrayCarry.new()
		tc.room = self
		add_view(tc)


# ------------------------------------------------------------------ 失物招领（隧道的小鬼丢的五样东西，散在五张图里）
const LOST_ITEMS := {
	"floor_06_palace_library": ["quill", 2], "floor_06_palace_servants": ["bell", 3], "floor_06_palace_wardrobe": ["sock", 4],
	"floor_06_palace_kitchen": ["cheese", 5], "floor_06_palace_clock_2": ["spring", 6]}
const LOST_NAMES := {"quill": "羽毛笔", "bell": "小铃铛", "sock": "一只袜子", "cheese": "一块奶酪", "spring": "钟发条"}
const EVENTS2 := "res://assets/generated/palace_events2.png"


static func lost_flag(key: String) -> String:
	return "palace_lost_" + key


static func lost_found() -> int:
	return LOST_NAMES.keys().filter(func(k): return GameState.has_flag(lost_flag(k))).size()


func _add_lost() -> void:
	if not LOST_ITEMS.has(map_id()) or cells("lost").is_empty():
		return
	var key := str(LOST_ITEMS[map_id()][0])
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = "floor_06/lost_" + key
	sp.done_flag = lost_flag(key)
	add_child(sp)
	sp.global_position = world(cells("lost")[0])
	var v := Events2View.new()
	v.frame = int(LOST_ITEMS[map_id()][1])
	v.hide_flag = lost_flag(key)
	v.position = world(cells("lost")[0])
	add_view(v)


## palace_events2.png 的一帧（0 海绵 / 1 点心托盘 / 2 羽毛笔 / 3 小铃铛 / 4 袜子 / 5 奶酪 / 6 钟发条 / 7 夹着衣架书签的书）；hide_flag 有了就不画
class Events2View extends Node2D:
	var frame := 0
	var hide_flag := ""
	var scale_k := 0.6
	var _s: Sprite2D

	func _ready() -> void:
		if ResourceLoader.exists(PalaceRoom.EVENTS2):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.EVENTS2)
			_s.hframes = 8
			_s.frame = frame
			_s.offset = Vector2(0, -14)
			_s.scale = Vector2.ONE * scale_k
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func _process(_d: float) -> void:
		visible = hide_flag == "" or not GameState.has_flag(hide_flag)
		if _s:
			_s.position.y = sin(Time.get_ticks_msec() / 300.0) * 1.5
		else:
			queue_redraw()

	func _draw() -> void:
		if _s == null:
			draw_circle(Vector2(0, -6), 4.0, Color(1.0, 0.85, 0.5))


# ------------------------------------------------------------------ 送餐潜行（厨房 → 仆人回廊）
## 端着点心（TRAY_FLAG）：头顶一个托盘、不能冲刺（meta no_dash）；被女仆发现 → 试吃惩罚、点心没了
const TRAY_FLAG := "palace_tray_carry"
const TRAY_FROM := "floor_06_palace_kitchen"
const TRAY_TO := "floor_06_palace_servants"


static func carrying_tray() -> bool:
	return GameState.has_flag(TRAY_FLAG)


static func set_tray(on: bool) -> void:
	GameState.set_flag(TRAY_FLAG, on)


class TrayCarry extends Node2D:
	var room: PalaceRoom
	var _s: Sprite2D

	func _ready() -> void:
		z_index = 5
		if ResourceLoader.exists(PalaceRoom.EVENTS2):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.EVENTS2)
			_s.hframes = 8
			_s.frame = 1
			_s.offset = Vector2(0, -42)
			_s.scale = Vector2(0.55, 0.55)
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func _process(_d: float) -> void:
		var on := PalaceRoom.carrying_tray()
		visible = on
		for m in room.members() if room else []:
			if on:
				(m as Node).set_meta(&"no_dash", true)
			elif (m as Node).has_meta(&"no_dash"):
				(m as Node).remove_meta(&"no_dash")
		var p := GameState.player as Node2D
		if on and is_instance_valid(p):
			global_position = p.global_position
		queue_redraw()

	func _draw() -> void:
		if _s == null and visible:
			draw_rect(Rect2(-8, -40, 16, 3), Color(0.85, 0.85, 0.9))
			draw_circle(Vector2(0, -43), 3.0, Color(1.0, 0.8, 0.85))


# ------------------------------------------------------------------ 女王的回忆（徽记台换过发饰 + 王座间通关以后，一次）
const MEMORY_FLAG := "palace_queen_memory"


static func memory_ready() -> bool:
	return GameState.has_flag("palace_badges_done") and GameState.has_flag("palace_boss_done") and not GameState.has_flag(MEMORY_FLAG)


static func try_memory() -> bool:
	if not memory_ready():
		return false
	GameState.set_flag(MEMORY_FLAG)
	await Cutscene.play("palace_queen_memory")
	return true


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
