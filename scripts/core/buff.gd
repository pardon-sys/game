class_name Buff
extends RefCounted
## 一个增益 / 减益状态的实例（挂在 Actor.buffs 上）。种类定义在 data/buffs.json（Buff.info(id)）。
##   time_left   剩余秒数（INF = 永久）
##   stacks      层数（不超过 max_stacks）

const PATH := "res://data/buffs.json"

static var _data := {}

var id := ""
var time_left := INF
var stacks := 0


func _init(buff_id := "") -> void:
	id = buff_id


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func info(buff_id: String) -> Dictionary:
	return data().get("buffs", {}).get(buff_id, {})


static func stat_kind(stat: String) -> String:
	return str(data().get("stat_kinds", {}).get(stat, "add"))


func is_permanent() -> bool:
	return time_left == INF


func is_debuff() -> bool:
	return info(id).get("debuff", false)


func modifier(stat: String) -> Variant:
	return info(id).get("modifiers", {}).get(stat)
