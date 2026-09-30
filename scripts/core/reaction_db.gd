class_name ReactionDB
extends RefCounted
## 受挠台词数据（data/princess_reactions.json）的读取入口。
##   lines(key, stage)      公主台词：先找 sources[key][stage]，没有则回退到通用 lines[stage]
##   first_encounter(key)   第一次被该来源挠痒时的剧情对话（对话行数组，格式同 dialogues.json）
##   taunts(key)            怪物回嘴短句
##   key_of(node)           由挠痒来源节点得到键：reaction_key 属性 / MonsterStats.reaction_key / 投射物的发射者

const PATH := "res://data/princess_reactions.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func setting(name: String, fallback: Variant) -> Variant:
	return data().get(name, fallback)


static func hint(name: String) -> String:
	return str(data().get("hints", {}).get(name, ""))


static func source(key: String) -> Dictionary:
	return data().get("sources", {}).get(key, {})


static func source_keys() -> Array:
	return data().get("sources", {}).keys()


## 魔法台词：magic[event]（channel / interrupted / fizzle / burst / burst_full / exposed_hint）。
static func magic(event: String) -> Array:
	return data().get("magic", {}).get(event, [])


static func lines(key: String, stage: String) -> Array:
	var own: Array = source(key).get(stage, [])
	return own if not own.is_empty() else data().get("lines", {}).get(stage, [])


static func first_encounter(key: String) -> Array:
	return source(key).get("first_encounter", [])


static func taunts(key: String) -> Array:
	return source(key).get("taunts", [])


static func key_of(node: Object) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var k: Variant = node.get("reaction_key")
	if k is String and k != "":
		return k
	if node is Monster and (node as Monster).stats:
		return (node as Monster).stats.reaction_key
	if node is Projectile:
		return key_of((node as Projectile).shooter)
	return ""
