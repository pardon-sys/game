class_name ReactionDB
extends RefCounted
## 受挠台词数据（data/princess_reactions.json）的读取入口。
##   lines(key, stage)      公主台词：先找 sources[key][stage]，没有则回退到通用 lines[stage]
##   first_encounter(key)   第一次被该来源挠痒时的剧情对话（对话行数组，格式同 dialogues.json）
##   taunts(key)            怪物回嘴短句
##   portrait_words(key, stage)  失控后被挠时立绘旁飘出的小字：先找 sources[key].portrait_words（数组 = 各阶段通用，
##                          或按阶段的字典），没有则用顶层 portrait_words[stage]
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


## 立绘飘字（PortraitFx）：stage = helpless_1 / helpless_2。
## 立绘飘字。查找顺序：来源按部位写的 → 来源自己的 → 部位默认（princess_ticklish.json）→ 全局。
static func portrait_words(key: String, stage: String, zone := "") -> Array:
	var own: Variant = source(key).get("portrait_words", null)
	if zone != "" and own is Dictionary and own.has(zone):
		var zw: Variant = own[zone]
		if zw is Array and not zw.is_empty():
			return zw
		if zw is Dictionary and not zw.get(stage, []).is_empty():
			return zw[stage]
	if own is Array and not own.is_empty():
		return own
	if own is Dictionary and own.get(stage, []) is Array and not own.get(stage, []).is_empty():
		return own[stage]
	if zone != "":
		var w := TickleZones.words(zone, stage)
		if not w.is_empty():
			return w
	var global: Variant = data().get("portrait_words", {})
	if global is Dictionary:
		return global.get(stage, global.get("helpless_1", []))
	return global if global is Array else []


static func first_encounter(key: String) -> Array:
	return source(key).get("first_encounter", [])


static func taunts(key: String) -> Array:
	return source(key).get("taunts", [])


## 参数不标类型：挠痒来源可能已经被释放（投射物的发射者、打倒的怪物）。
static func key_of(node: Variant) -> String:
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


const FATIGUE_PATH := "res://data/princess_fatigue.json"
static var _fatigue := {}


## 魔力疲倦爆发的台词（单独文件 data/princess_fatigue.json）：burst / after / warning 为句子数组，first 为剧情对话行。
static func fatigue(section: String) -> Array:
	if _fatigue.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FATIGUE_PATH))
		_fatigue = parsed if parsed is Dictionary else {}
	return _fatigue.get(section, [])


## 特殊挠痒（暴击）时公主的台词：sources[key].special，没有则用通用 lines.special。
static func special(key: String) -> Array:
	var own: Array = source(key).get("special", [])
	return own if not own.is_empty() else data().get("lines", {}).get("special", [])


## 组合技文本：combos[id] = {name, description, lines}。
static func combo(id: String) -> Dictionary:
	return data().get("combos", {}).get(id, {})
