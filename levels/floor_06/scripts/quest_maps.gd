class_name QuestMaps
## 骑士篇支线小地图的标记点（data/after/quest_maps.json，tools/build/quest_maps.py 画图时写出）：
##   cells(图, 名字) → Array[Vector2i]（按从入口走过去的远近排）；cell(图, 名字) → 第一个。
##   名字：start / exit / blue（每张图都有），其余见 quest_maps.py 的 MARKS（spots、nails、candles……）。

const PATH := "res://data/after/quest_maps.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func cells(map_id: String, key: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in data().get(map_id, {}).get(key, []):
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


static func cell(map_id: String, key: String) -> Vector2i:
	var all := cells(map_id, key)
	return all[0] if not all.is_empty() else Vector2i.ZERO
