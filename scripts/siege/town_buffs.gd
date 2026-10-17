class_name TownBuffs
extends RefCounted
## 攻防战的镇民支援（SiegeDirector.town）：每进一波固定给一个 buff，整局叠加；派对者的激励（after_wave = 0）第 1 波开打前给。
## 数据 data/siege/town_buffs.json（gen_floor06_siege.py 生成）：
##   [{id, name, who（镇民）, sheet（镇民行走图）, line（喊话）, desc（规则说明）, icon（buff 图标）, after_wave,
##     buff（data/buffs.json 里的 town_<id>：给公主 / 士兵 / 雪人的属性）, mul: {键: 倍数}, add: {键: 加值}, once: {…}, per_wave: {…}}]
## 导演和各单位读 mul(键) / add(键)：
##   tower_dmg 冰塔伤害、tower_range 冰塔射程、spell_cd 城墙法术冷却、ally_cd 友军攻击间隔、soldier_atk 士兵攻击、soldier_hp 士兵血量、
##   soldier_return 撤退回来的时间、detect 友军索敌、build_speed 怪物搭敌塔速度、engineer_speed 工兵移速、
##   equip_power 临时装备发作力度、fatigue 蓝色公主魔力疲倦增长；add：pink_melee 粉色公主近战、snowmen 雪人多召几只、lantern 灯笼光圈半径。
## once（拿到时一次）：wall_max_mul 城墙上限倍数、wall_repair 修百分比、wall_full 回满、mints 薄荷糖、spears 增派长矛兵、fireworks 烟花过场。
## per_wave（之后每进一波）：wall_repair、mints。
## 已获得的 id 存 GameState.vars.siege_town_buffs（失败重来保留；离开攻防战时公主身上的 town_* 状态会去掉）。

const PATH := "res://data/siege/town_buffs.json"

static var _data: Array = []

var director: SiegeDirector
var owned: Array[String] = []


static func all() -> Array:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else []
		_data = parsed if parsed is Array else []
	return _data


static func info(id: String) -> Dictionary:
	for e in all():
		if str(e.get("id", "")) == id:
			return e
	return {}


## 第 n 波打完后给的那个（n = 0：开局）。
static func for_wave(n: int) -> Dictionary:
	for e in all():
		if int(e.get("after_wave", -1)) == n:
			return e
	return {}


func _init(d: SiegeDirector) -> void:
	director = d


func restore() -> void:
	owned.clear()
	for id in GameState.vars.get("siege_town_buffs", []):
		owned.append(str(id))
	apply_all()


func has(id: String) -> bool:
	return owned.has(id)


## 测试跳波：补齐进入目标波次前应有的永久支援，不重播过场或历史周期补给。
func grant_missing_for_wave(wave: int) -> void:
	for e in all():
		var after := int(e.get("after_wave", -1))
		if after >= 0 and after < wave:
			await grant(str(e["id"]), false)
	# 已领取条目也要补挂到复位后的友军，不能只更新owned列表。
	apply_all()


## 开局那个还没给（第 1 波开打前要放过场）。
func has_pending_start() -> bool:
	var e := for_wave(0)
	return not e.is_empty() and not owned.has(str(e["id"]))


## 所有已拿到的 buff 的 mul[键] 相乘。
func mul(key: String) -> float:
	var m := 1.0
	for id in owned:
		var v: Variant = info(id).get("mul", {}).get(key)
		if v != null:
			m *= float(v)
	return m


func add(key: String) -> float:
	var a := 0.0
	for id in owned:
		var v: Variant = info(id).get("add", {}).get(key)
		if v != null:
			a += float(v)
	return a


## 第 n 波打完：给对应的 buff（有过场就放过场，放完才返回）。没有就直接返回。
func grant_for(n: int) -> void:
	_per_wave()
	var e := for_wave(n)
	if e.is_empty() or owned.has(str(e["id"])):
		return
	await grant(str(e["id"]))


func grant(id: String, show := true) -> void:
	if owned.has(id):
		return
	owned.append(id)
	GameState.vars["siege_town_buffs"] = owned.duplicate()
	var e := info(id)
	if show and director and director.is_inside_tree() and TownBuffShow.enabled:
		var s := TownBuffShow.new()
		s.director = director
		s.entry = e
		director.add_child(s)
		await s.finished
	_once(e)
	apply_all()
	director.intel.discover("town_" + id)
	GameState.rule("镇民支援「%s」：%s" % [str(e.get("name", id)), str(e.get("desc", ""))])


## 给友军（两位公主、士兵、雪人）挂上所有已拿到的 town_* 状态。
func apply_all() -> void:
	if director == null:
		return
	for a in allies():
		apply_to(a)


func apply_to(a: Actor) -> void:
	for id in owned:
		var b := str(info(id).get("buff", ""))
		if b != "" and not a.buffs.has(b):
			a.add_buff(b, -1.0)


func allies() -> Array[Actor]:
	var out: Array[Actor] = []
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c):
			out.append(c)
	for s in director.soldiers:
		if is_instance_valid(s):
			out.append(s)
	for n in director.get_tree().get_nodes_in_group("siege_temp"):
		if n is Snowman:
			out.append(n)
	return out


## 离开攻防战：公主身上的 town_* 都去掉（不带回战时小镇）。
func strip() -> void:
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c):
			for id in c.buffs.keys():
				if str(id).begins_with("town_"):
					c.remove_buff(id)


func _once(e: Dictionary) -> void:
	var o: Dictionary = e.get("once", {})
	if o.is_empty():
		return
	var d := director
	if o.has("wall_max_mul"):
		var old := d.wall_max
		d.wall_max *= float(o["wall_max_mul"])
		d.wall_hp += d.wall_max - old
	if o.has("wall_repair"):
		d.repair_wall(null, d.wall_max * float(o["wall_repair"]))
	if o.get("wall_full", false):
		d.repair_wall(null, d.wall_max)
	if o.has("mints"):
		_give_mints(int(o["mints"]))
	if o.has("spears"):
		d.add_soldiers("spear", int(o["spears"]))


func _per_wave() -> void:
	for id in owned:
		var o: Dictionary = info(id).get("per_wave", {})
		if o.has("wall_repair"):
			director.repair_wall(null, director.wall_max * float(o["wall_repair"]))
		if o.has("mints"):
			_give_mints(int(o["mints"]))


func _give_mints(n: int) -> void:
	var mint := load("res://data/items/mint.tres") as ItemData
	if GameState.inventory and mint:
		GameState.inventory.add(mint, n)
	GameState.notify("药剂师送来了 %d 颗薄荷糖" % n)
