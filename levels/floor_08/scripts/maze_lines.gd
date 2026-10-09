class_name MazeLines
extends RefCounted
## 夜迷宫里她被看不见的手盖住时的反应台词（data/characters/blue/maze_lines.json，gen_blue_character.py 生成）：
##   for_zone(部位, 这个部位的手数)：普通部位一句；大腿 / 屁股按只数分档（1、2~3、4~5、6 只以上），越多越崩。
##   pick(键)：lamp_clear（月光灯清掉手）、rhythm_charge / rhythm_hit / rhythm_miss（节奏）、shake_off（冰晶震掉）……

const PATH := "res://data/characters/blue/maze_lines.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func pick(key: String) -> String:
	var arr: Array = data().get(key, [])
	return str(arr.pick_random()) if not arr.is_empty() else ""


static func tier(n: int) -> String:
	return "6" if n >= 6 else ("4" if n >= 4 else ("2" if n >= 2 else "1"))


static func for_zone(zone: String, n: int) -> String:
	var weak: Dictionary = data().get("weak", {})
	if weak.has(zone):
		var arr: Array = weak[zone].get(tier(n), [])
		return str(arr.pick_random()) if not arr.is_empty() else ""
	var arr2: Array = data().get("zones", {}).get(zone, [])
	return str(arr2.pick_random()) if not arr2.is_empty() else ""
