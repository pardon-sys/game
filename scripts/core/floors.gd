class_name Floors
extends RefCounted
## 楼层表（data/floors.json）的读取入口。每层一个文件夹 levels/<id>/：
##   map.txt         ASCII 地图（tools/build/build_level.gd 构建）
## 本层的对话在 data/dialogues/<楼层组>/（dialogue_dir），过场在 data/cutscenes/<楼层组>/，小剧场在 data/theater/<楼层组>/。
## 楼层组：楼层表里的 group（第六层的四张地图都属于 floor_06），没写就是楼层 id 本身。
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


## 楼层组（第六层四张地图共用 floor_06）。
static func group(id: String) -> String:
	return str(info(id).get("group", id))


## 本层对话所在的文件夹。
static func dialogue_dir(id: String) -> String:
	return "res://data/dialogues/%s/" % group(id)
