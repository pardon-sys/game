class_name TickleZones
extends RefCounted
## 部位挠痒：部位表 data/actors/princess_ticklish.json（敏感值），来源 -> 部位权重 data/tickle_zones.json。
## 全部数据驱动，代码里不写死部位 id：新增部位只改部位表，给来源分配部位只改 tickle_zones.json
## （或单个怪物 / 陷阱的导出属性 tickle_zones）。
##   pick(来源节点, 露出部位)   按权重抽一个部位（露出的部位优先；follow_exposed 的来源只挠露出的部位；
##                             来源有 zone_focus（部位列表）时专挑第一个露出的，都没露出就挠列表最后一个——肚脐羽毛钻）
##   zone_multiplier(部位)      部位 sensitivity × modifier（被动等）
##   body_multiplier(阶段, 战损) base_sensitivity × by_stage × damaged
## 每个角色的连续部位加成、露出部位在 Sensitivity（PlayableCharacter.sensitivity）里。

const TICKLISH_PATH := "res://data/actors/princess_ticklish.json"
const ZONES_PATH := "res://data/tickle_zones.json"

## 测试里需要精确数值时关掉（和 Monster.random_specials 同样做法）。
static var enabled := true
static var _ticklish := {}
static var _table := {}


static func ticklish() -> Dictionary:
	if _ticklish.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TICKLISH_PATH))
		_ticklish = parsed if parsed is Dictionary else {}
	return _ticklish


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ZONES_PATH))
		_table = parsed if parsed is Dictionary else {}
	return _table


static func zones() -> Dictionary:
	return ticklish().get("zones", {})


static func zone_ids() -> Array:
	return zones().keys()


static func info(zone: String) -> Dictionary:
	return zones().get(zone, {})


static func zone_name(zone: String) -> String:
	return str(info(zone).get("name", zone))


## 来源节点的部位权重：实例导出属性 tickle_zones > tickle_zones.json 的来源键 > 部位表的 chance。
static func weights_for(source: Variant) -> Dictionary:
	if source != null and is_instance_valid(source):
		var own: Variant = source.get("tickle_zones")
		if own is Dictionary and not own.is_empty():
			return own
	var key := ReactionDB.key_of(source)
	var w: Variant = table().get("sources", {}).get(key, null)
	if w is Dictionary and not w.is_empty():
		return w
	return default_weights()


static func default_weights() -> Dictionary:
	var out := {}
	for z in zones():
		out[z] = float(zones()[z].get("chance", 1.0))
	return out


static func follows_exposed(source: Variant) -> bool:
	return table().get("follow_exposed", []).has(ReactionDB.key_of(source))


## 抽一个部位。exposed = {部位: 倍率}（被束缚露出的部位）。
static func pick(source: Variant, exposed := {}) -> String:
	var focus := focus_of(source)
	if not focus.is_empty():
		for z in focus:
			if exposed.has(z):
				return str(z)
		return str(focus.back())
	var w := weights_for(source)
	if not exposed.is_empty():
		if follows_exposed(source):
			w = {}
			for z in exposed:
				w[z] = float(exposed[z])
		else:
			var both := {}
			for z in w:
				if exposed.has(z):
					both[z] = w[z]
			if not both.is_empty():
				w = both
	return _weighted(w)


## 来源的专挑部位（导出属性 zone_focus，没有时为空）。
static func focus_of(source: Variant) -> Array:
	if source == null or not is_instance_valid(source):
		return []
	var f: Variant = source.get("zone_focus")
	return (f as Array).filter(func(z): return zones().has(z)) if f is Array else []


static func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for z in w:
		if zones().has(z):
			total += maxf(float(w[z]), 0.0)
	if total <= 0.0:
		return ""
	var r := randf() * total
	for z in w:
		if not zones().has(z):
			continue
		r -= maxf(float(w[z]), 0.0)
		if r <= 0.0:
			return z
	return ""


## 部位敏感倍率（含被动等修正）。
static func zone_multiplier(zone: String) -> float:
	if zone == "":
		return 1.0
	return maxf(float(info(zone).get("sensitivity", 1.0)) + modifier(zone), 0.0)


## 以后的被动 / 道具对部位敏感值的修正（加减）。被动数据里写 {"zone_sensitivity": {"sole": -0.1}}。
static func modifier(zone: String) -> float:
	var total := 0.0
	for id in GameState.passives:
		var v: Variant = PassiveDB.value_dict(id, "zone_sensitivity")
		if v is Dictionary:
			total += float(v.get(zone, 0.0))
	return total


## 全身项：基础敏感值 × 闷笑阶段 × 战损。
static func body_multiplier(stage: String, damaged: bool) -> float:
	var t := ticklish()
	var k := float(t.get("base_sensitivity", 1.0)) * float(t.get("by_stage", {}).get(stage, 1.0))
	return k * (float(t.get("damaged", 1.0)) if damaged else 1.0)


static func streak_rule() -> Dictionary:
	return ticklish().get("streak", {"window": 2.0, "step": 0.03, "max": 0.3, "recover": 0.1})


## 立绘上这个部位的位置（0~1 比例），没有时返回 null。
static func anchor(zone: String) -> Variant:
	var a: Array = info(zone).get("anchor", [])
	if a.is_empty():
		return null
	var p: Variant = a.pick_random() if a[0] is Array else a
	return Vector2(float(p[0]), float(p[1]))


static func words(zone: String, stage: String) -> Array:
	var w: Variant = info(zone).get("words", {})
	if w is Dictionary:
		return w.get(stage, w.get("helpless_1", []))
	return w if w is Array else []


## 校验：每个挠痒来源都分配了部位、用到的部位都在部位表里、权重 > 0、anchor 在 0~1。返回问题列表。
static func validate() -> Array[String]:
	var errors: Array[String] = []
	if zones().is_empty():
		errors.append("部位表是空的")
	for z in zones():
		for p in zones()[z].get("anchor", []):
			if not (p is Array) or p.size() != 2 or float(p[0]) < 0.0 or float(p[0]) > 1.0 or float(p[1]) < 0.0 or float(p[1]) > 1.0:
				errors.append("部位 %s 的 anchor 不在 0~1" % z)
	var sources: Dictionary = table().get("sources", {})
	for key in sources:
		for z in sources[key]:
			if not zones().has(z):
				errors.append("来源 %s 用了不存在的部位 %s" % [key, z])
			elif float(sources[key][z]) <= 0.0:
				errors.append("来源 %s 的部位 %s 权重不大于 0" % [key, z])
	for key in ReactionDB.source_keys():
		if ReactionDB.source(key).get("no_tickle", false):
			continue
		if not sources.has(key):
			errors.append("来源 %s 还没分配部位" % key)
	return errors
