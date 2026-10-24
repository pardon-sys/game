class_name AfterFestival
extends RefCounted
## 第 7 天晚上的庆功宴（AfterStory 的事件 d7_festival 开场以后）：广场自由活动。台词 data/after/festival_night.json（← after_text/festival_night.py）。
##   必做：派对主人那里领舞（call: festival_dance → FestivalDanceShow）→ festival_dance_done。
##   可选：五个摊位（call: festival_stall，vars.stall_req = guess / ring / ice / fish / lick → STALLS 里的小游戏）→ stall_<id>_done。
##   领舞以后找镇长放烟花（call: festival_finale）：烟花（FestivalFireworks）+ 过场 after_d7_finale（哼歌、「七日赎罪 完」）→ 回小屋的床。
## 标记：after_festival_on（庆功宴进行中，对话的入口读它）、festival_finale_done。

const PATH := "res://data/after/festival_night.json"
const ON := "after_festival_on"
const DANCE_DONE := "festival_dance_done"
const FINALE_DONE := "festival_finale_done"
const STALLS := {"guess": "res://levels/floor_06/scripts/stall_guess_show.gd", "ring": "res://levels/floor_06/scripts/stall_ring_show.gd",
	"ice": "res://levels/floor_06/scripts/stall_ice_show.gd", "fish": "res://levels/floor_06/scripts/stall_fish_show.gd",
	"lick": "res://levels/floor_06/scripts/stall_lick_show.gd"}

static var _data := {}
static var running := false


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func active() -> bool:
	return GameState.has_flag(ON) and not GameState.has_flag(FINALE_DONE)


static func stall_done(id: String) -> bool:
	return GameState.has_flag("stall_%s_done" % id)


## 庆功宴开场（AfterStory 的 d7_festival 演完开场过场以后）
static func begin() -> void:
	GameState.set_flag(ON)
	GameState.set_flag(AfterStory.NIGHT_BUSY)
	GameState.hint(str(data()["objective"]["dance"]))


static func objective_text() -> String:
	return str(data()["objective"]["free" if GameState.has_flag(DANCE_DONE) else "dance"])


static func run_dance() -> void:
	if running or not active() or GameState.has_flag(DANCE_DONE):
		return
	if await _play(FestivalDanceShow.new()):
		GameState.set_flag(DANCE_DONE)
		GameState.hint(objective_text())


static func run_stall(id: String) -> void:
	if running or not active() or not STALLS.has(id):
		return
	if await _play(load(STALLS[id]).new()):
		GameState.set_flag("stall_%s_done" % id)
		GameState.notify(str(data()["stall_done"]) % str(data()["stall_names"].get(id, id)))


## 放烟花 → 结局过场（chapter_end 进小屋）→ 这一晚算做完
static func run_finale() -> void:
	if running or not active():
		return
	if not GameState.has_flag(DANCE_DONE):
		GameState.notify(str(data()["dance_first"]))
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	var tree := Engine.get_main_loop() as SceneTree
	var lv: Node = tree.get_first_node_in_group("main").get("level") if tree.get_first_node_in_group("main") else null
	var fw: FestivalFireworks = null
	if lv:
		fw = FestivalFireworks.new()
		fw.global_position = Cutscene.cell_to_world([41, 18])
		lv.add_child(fw)
	GameState.set_flag(FINALE_DONE)
	GameState.set_flag(AfterStory.NIGHT_BUSY, false)
	DayClock.mark_done()
	GameState.pending_spawn = "bed"
	await Cutscene.play("after_d7_finale")
	if is_instance_valid(fw):
		fw.queue_free()
	running = false


static func _play(show: Node) -> bool:
	running = true
	await TrainingDB.wait_dialogue_free()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	running = false
	return ok
