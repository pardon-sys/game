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


## 显示用的信息：通用状态 exposed 按角色当前露出的部位动态显示名字、图标和倍率；latched 显示吸着的怪物。
static func display(buff_id: String, actor: Object) -> Dictionary:
	var out := info(buff_id).duplicate()
	if buff_id == "exposed" and actor != null and actor.get("sensitivity") is Sensitivity:
		var sens: Sensitivity = actor.get("sensitivity")
		out["name"] = sens.exposed_label()
		out["icon"] = sens.exposed_icon()
		var parts: Array[String] = []
		var ex := sens.exposed()
		for z in ex:
			parts.append("%s ×%.1f" % [TickleZones.zone_name(z), float(ex[z])])
		out["desc"] = "被束缚陷阱困住，部位露在外面：%s。" % "、".join(parts)
	elif buff_id == "latched" and actor != null and actor.has_method("latch_label"):
		out["name"] = actor.latch_label()
	return out


static func stat_kind(stat: String) -> String:
	return str(data().get("stat_kinds", {}).get(stat, "add"))


func is_permanent() -> bool:
	return time_left == INF


func is_debuff() -> bool:
	return info(id).get("debuff", false)


func modifier(stat: String) -> Variant:
	return info(id).get("modifiers", {}).get(stat)
