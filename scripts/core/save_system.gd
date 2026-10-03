class_name SaveSystem
extends RefCounted
## 存档：<数据根目录>saves/slot_<n>.json（SLOTS 个存档位）。数据根目录见 DevConfig.data_root()：
## 导出的正式游戏是 user://saves/，在编辑器里运行 / 测试模式是 user://<dev_config.json 的 dev_data_dir>/saves/。只能在地图上的存档点（SavePoint）存档；主界面读取。
##   save(slot, 地点名)   把当前进度写进存档位
##   info(slot)           存档位的摘要 {floor, place, time, play_time}（空位返回 {}）
##   latest()             最近一次存档的存档位（没有返回 -1）
##   load_slot(slot)      读取：恢复 GameState → 换到存档的关卡 → 站到存档位置
## 保存的内容：楼层 id、关卡场景、位置、检查点、公主状态（生命 / 闷笑 / 战损……，同换层时的 carried_player_state）、
## 剧情标记 flags、对话选择变量 vars、物品、快捷键、被动技能、游戏时长。

## 正式游戏的存档目录。
const DIR := "user://saves/"
const SLOTS := 3
const VERSION := 1

## 当前的存档目录（测试时改到别的目录，不碰玩家的存档）。
static var dir := default_dir()


## 默认存档目录：DevConfig.data_root() + "saves/"。
static func default_dir() -> String:
	var d := DevConfig.data_root() + "saves/"
	if d != DIR:
		copy_old_saves(DIR, d)
	return d


## 第一次隔离调试数据时：以前在编辑器里存的档（还在 user://saves/）复制一份到调试目录，开发中的进度不丢（只复制，不删原来的）。
static func copy_old_saves(from: String, to: String) -> int:
	if DirAccess.dir_exists_absolute(to) or not DirAccess.dir_exists_absolute(from):
		return 0
	DirAccess.make_dir_recursive_absolute(to)
	var n := 0
	for f in DirAccess.get_files_at(from):
		if f.begins_with("slot_") and DirAccess.copy_absolute(from + f, to + f) == OK:
			n += 1
	return n


static func path(slot: int) -> String:
	return dir + "slot_%d.json" % slot


static func save(slot: int, place := "") -> bool:
	var p := GameState.player
	var main := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("main")
	if not is_instance_valid(p) or main == null or main.level == null:
		return false
	GameState.save_player_state()
	var level: Node = main.level
	var data := {
		"version": VERSION,
		"time": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"floor": str(level.get("floor_id")),
		"scene": level.scene_file_path,
		"place": place,
		"position": [p.global_position.x, p.global_position.y],
		"checkpoint": [GameState.checkpoint.x, GameState.checkpoint.y],
		"player": GameState.carried_player_state,
		"flags": GameState.flags,
		"vars": GameState.vars,
		"inventory": GameState.inventory.to_dict(),
		"hotkeys": GameState.hotkeys,
		"passives": GameState.passives,
		"play_time": GameState.play_time,
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return parsed if parsed is Dictionary else {}


static func info(slot: int) -> Dictionary:
	var d := read(slot)
	if d.is_empty():
		return {}
	return {"floor": Floors.display_name(str(d.get("floor", ""))), "place": str(d.get("place", "")),
		"time": str(d.get("time", "")), "play_time": float(d.get("play_time", 0.0))}


static func latest() -> int:
	var best := -1
	var best_t := -1.0
	for s in range(1, SLOTS + 1):
		var d := read(s)
		if not d.is_empty() and float(d.get("unix", 0)) > best_t:
			best_t = float(d.get("unix", 0))
			best = s
	return best


static func delete(slot: int) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))


## 把存档里的进度放回 GameState（不换关卡）。
static func apply_state(d: Dictionary) -> void:
	GameState.reset()
	GameState.flags = d.get("flags", {}).duplicate(true)
	GameState.vars = d.get("vars", {}).duplicate(true)
	GameState.inventory.from_dict(d.get("inventory", {}))
	GameState.hotkeys = d.get("hotkeys", GameState.DEFAULT_HOTKEYS).duplicate()
	GameState.hotkeys_changed.emit()
	GameState.passives = d.get("passives", {}).duplicate()
	GameState.carried_player_state = d.get("player", {}).duplicate(true)
	GameState.play_time = float(d.get("play_time", 0.0))


## 读档：恢复进度、换到存档的关卡、站到存档的位置。
static func load_slot(slot: int) -> bool:
	var d := read(slot)
	var main := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("main")
	if d.is_empty() or main == null:
		return false
	apply_state(d)
	(Engine.get_main_loop() as SceneTree).paused = false
	await main.change_level(str(d.get("scene", "")), true)
	var p := GameState.player
	if is_instance_valid(p):
		var pos: Array = d.get("position", [0, 0])
		p.global_position = Vector2(float(pos[0]), float(pos[1]))
		var cp: Array = d.get("checkpoint", pos)
		GameState.set_checkpoint(Vector2(float(cp[0]), float(cp[1])))
		if p.camera:
			p.camera.reset_smoothing()
	return true
