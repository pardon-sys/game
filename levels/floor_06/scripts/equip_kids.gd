class_name EquipKids
extends RefCounted
## 弥补任务「装备回收」里小孩按身上穿着的临时装备选的配合挠法（data/after/equip_kids.json ← after_text/equip_kids.py）。
##   caption(穿着的 id 列表)   详细描写：两件以上有组合挠法时用组合的，没有就挑一件；什么都没穿用 bare
##   zone_for(穿着的 id 列表)  小孩挠哪里（跟着那件装备的部位）

const PATH := "res://data/after/equip_kids.json"
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func combo_key(a: String, b: String) -> String:
	var ids := [a, b]
	ids.sort()
	return "%s+%s" % ids


static func caption(worn: Array) -> String:
	var combos: Dictionary = data().get("combos", {})
	for i in worn.size():
		for j in range(i + 1, worn.size()):
			var k := combo_key(str(worn[i]), str(worn[j]))
			if combos.has(k):
				return str((combos[k] as Array).pick_random())
	var items: Dictionary = data().get("items", {})
	var have := worn.filter(func(id): return items.has(str(id)))
	if have.is_empty():
		return str((data().get("bare", [""]) as Array).pick_random())
	return str((items[str(have.pick_random())]["captions"] as Array).pick_random())


static func zone_for(worn: Array) -> String:
	var items: Dictionary = data().get("items", {})
	var have := worn.filter(func(id): return items.has(str(id)))
	if have.is_empty():
		return "waist"
	return str(items[str(have.pick_random())].get("zone", "sole"))


static func wear_line(id: String) -> String:
	return str(data().get("items", {}).get(id, {}).get("wear", "穿、穿上了……！"))


static func chase_words() -> Array:
	return data().get("chase", ["姐姐！"])


static func tickle_words() -> Array:
	return data().get("tickle", ["咯吱咯吱～"])
