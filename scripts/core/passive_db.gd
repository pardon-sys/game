class_name PassiveDB
extends RefCounted
## 人物被动技能的数据：data/passives/passives.json。当前等级存在 GameState.passives（{id: 等级}）。
##   PassiveDB.info(id) / name(id) / max_level(id) / level_info(id, 等级) / value(id)（当前等级的 value，没有为 0）

const PATH := "res://data/passives/passives.json"
const ICONS := preload("res://assets/generated/passive_icons.png")
const ICON_SIZE := 16

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func ids() -> Array:
	return data().get("passives", {}).keys()


static func info(id: String) -> Dictionary:
	return data().get("passives", {}).get(id, {})


static func name(id: String) -> String:
	return str(info(id).get("name", id))


static func max_level(id: String) -> int:
	return int(info(id).get("max_level", info(id).get("levels", []).size()))


## 第 lv 级（1 起）的数据。
static func level_info(id: String, lv: int) -> Dictionary:
	var levels: Array = info(id).get("levels", [])
	if lv < 1 or levels.is_empty():
		return {}
	return levels[mini(lv, levels.size()) - 1]


## 当前等级的 value（没学会为 0）。
static func value(id: String) -> float:
	return float(level_info(id, int(GameState.passives.get(id, 0))).get("value", 0.0))


## 当前等级的某个字段（没学会为 null）。
static func value_dict(id: String, field: String) -> Variant:
	return level_info(id, int(GameState.passives.get(id, 0))).get(field, null)


static func icon(id: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = ICONS
	at.region = Rect2(int(info(id).get("icon", 0)) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	return at
