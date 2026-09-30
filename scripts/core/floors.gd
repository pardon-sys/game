class_name Floors
extends RefCounted
## 楼层表（data/floors.json）的读取入口。每层一个文件夹 levels/<id>/：
##   map.txt         ASCII 地图（tools/build/build_level.gd 构建）
##   dialogues.json  本层专属对话（进入该层时由 Dialogue.load_floor 合并）
##   floor.tscn      构建产物
##   ids()           按顺序的楼层 id
##   scene(id)       场景路径
##   next_of(id)     下一层 id（最后一层返回 ""）

const PATH := "res://data/floors.json"
const DIR := "res://levels/%s/"

static var _floors: Array = []


static func all() -> Array:
	if _floors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_floors = parsed.get("floors", []) if parsed is Dictionary else []
	return _floors


static func ids() -> Array:
	return all().map(func(f: Dictionary): return f["id"])


static func info(id: String) -> Dictionary:
	for f in all():
		if f["id"] == id:
			return f
	return {}


static func scene(id: String) -> String:
	return info(id).get("scene", DIR % id + "floor.tscn")


static func display_name(id: String) -> String:
	return info(id).get("name", id)


static func next_of(id: String) -> String:
	var list := ids()
	var i := list.find(id)
	return list[i + 1] if i >= 0 and i + 1 < list.size() else ""


static func map_path(id: String) -> String:
	return DIR % id + "map.txt"


static func dialogues_path(id: String) -> String:
	return DIR % id + "dialogues.json"
