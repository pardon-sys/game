class_name ComboTracker
extends Node
## 组合技追踪（节点名 "Combo"，挂在会被挠痒的角色下，目前是公主）。
## 监听父节点的 tickled(hit)，记录最近 window 秒内挠到她的来源（ReactionDB.key_of），
## 与 data/combos.json 的 keys 匹配后触发：施加效果、HUD 横幅（GameState.combo_triggered）、公主说组合技台词。
##   trigger(id, source, force_effects)   条件型组合技由代码直接触发；冷却中返回 false，
##                                        force_effects = true 时冷却中也施加效果（只是不再弹横幅）
##   hit_multiplier(hit)                  条件型"本次挠痒倍率"（趁手打劫），由角色的 _tickle_multiplier 调用
## 组合技自己造成的额外挠痒 / 余痒来源是本节点，reaction_key 为空，不会被再次记录。
## 条件型：狂热连击（被带狂热 / 力量增益的怪物暴击）在这里检测；魔力反噬（疲倦爆发时身边有怪物）由
## PlayableCharacter.fatigue_burst 调用 trigger("mana_backlash")。

signal triggered(id: String)

const PATH := "res://data/combos.json"

## 空键：自己施加的挠痒不参与匹配。
var reaction_key := ""

static var _data := {}
var _recent: Array[Dictionary] = []
var _ready_at := {}
var _time := 0.0
var _actor: Actor


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func combo_def(id: String) -> Dictionary:
	for c in data().get("combos", []):
		if c["id"] == id:
			return c
	return {}


static func ids() -> Array:
	return data().get("combos", []).map(func(c: Dictionary): return c["id"])


static func group(name: String) -> Array:
	return data().get("groups", {}).get(name, [])


func _ready() -> void:
	_actor = get_parent() as Actor
	if _actor:
		_actor.tickled.connect(_on_tickled)


func _process(delta: float) -> void:
	if not GameState.in_dialogue:
		_time += delta


func window() -> float:
	return float(data().get("window", 1.5))


func is_on_cooldown(id: String) -> bool:
	return _time < float(_ready_at.get(id, -1.0))


func reset() -> void:
	_recent.clear()
	_ready_at.clear()


## 最近记录的来源键（测试 / 调试用）。
func recent_keys() -> Array:
	return _recent.map(func(e: Dictionary): return e["key"])


func _on_tickled(hit: HitData) -> void:
	var key := ReactionDB.key_of(hit.source)
	if key == "":
		return
	if hit.special and hit.source is Monster and ((hit.source as Monster).has_buff("frenzy") or (hit.source as Monster).has_buff("strength")):
		trigger("frenzy_strike", hit.source)
	_recent.append({"key": key, "time": _time, "source": hit.source})
	var since := _time - window()
	_recent = _recent.filter(func(e: Dictionary): return e["time"] >= since)
	_check(_recent.back())


func _check(newest: Dictionary) -> void:
	# 每个来源键只保留最近一次
	var latest := {}
	for e in _recent:
		latest[e["key"]] = e
	var entries: Array = latest.values()
	for c in data().get("combos", []):
		if c.has("condition") or not c.has("keys") or is_on_cooldown(c["id"]):
			continue
		var used := _assign(c["keys"], entries, latest[newest["key"]])
		if used.is_empty():
			continue
		for e in used:
			_recent.erase(e)
		_fire(c, used[0]["source"])
		return


## 给每个槽位分配一个不同的来源；最新的那次挠痒必须用上。失败返回空数组。
func _assign(slots: Array, entries: Array, newest: Dictionary) -> Array:
	for i in slots.size():
		if not _accepts(slots[i], newest["key"]):
			continue
		var rest: Array = slots.duplicate()
		rest.remove_at(i)
		var others := entries.filter(func(e: Dictionary): return e != newest)
		var filled: Variant = _fill(rest, others)
		if filled != null:
			return [newest] + filled
	return []


func _fill(slots: Array, entries: Array) -> Variant:
	if slots.is_empty():
		return []
	for e in entries:
		if _accepts(slots[0], e["key"]):
			var sub: Variant = _fill(slots.slice(1), entries.filter(func(x: Dictionary): return x != e))
			if sub != null:
				return [e] + sub
	return null


func _accepts(slot: Array, key: String) -> bool:
	return slot.has(key) or (slot.has("*") and group("monster").has(key))


## 条件型组合技（或测试）直接触发。
func trigger(id: String, source: Node = null, force_effects := false) -> bool:
	var c := combo_def(id)
	if c.is_empty():
		push_warning("没有组合技: " + id)
		return false
	if is_on_cooldown(id):
		if force_effects:
			_apply_effects(c, source)
		return false
	_fire(c, source)
	return true


## 条件型"本次挠痒倍率"。趁手打劫：被机关手抓着时，怪物的挠痒 ×value。
func hit_multiplier(hit: HitData) -> float:
	var st := _actor.status if _actor else null
	if st == null or not st.is_grabbed() or ReactionDB.key_of(st.grabber) != "hand":
		return 1.0
	if not group("monster").has(ReactionDB.key_of(hit.source)):
		return 1.0
	var k := 1.0
	for e in combo_def("hand_heist").get("effects", []):
		if e["type"] == "hit_multiplier":
			k = float(e["value"])
	trigger("hand_heist", hit.source)
	return k


func _fire(c: Dictionary, source: Node) -> void:
	var id: String = c["id"]
	_ready_at[id] = _time + float(data().get("cooldown", 4.0))
	_apply_effects(c, source)
	Audio.play("combo", -2.0, 0.02)
	GameState.combo_triggered.emit(id, str(ReactionDB.combo(id).get("name", id)))
	if not GameState.has_flag("hint_first_combo"):
		GameState.set_flag("hint_first_combo")
		GameState.notify(ReactionDB.hint("first_combo"))
	triggered.emit(id)
	if _actor and _actor.has_method("say_combo"):
		_actor.say_combo(id)


func _apply_effects(c: Dictionary, source: Node) -> void:
	var st := _actor.status if _actor else null
	for e in c.get("effects", []):
		match str(e["type"]):
			"burst":
				_actor.receive_hit(HitData.make_tickle(self, float(e["amount"])))
			"dot":
				if st:
					st.add_dot(float(e["rate"]), float(e["duration"]), self)
			"root":
				if st:
					if e.get("extend", false):
						st.extend_root(float(e["duration"]))
					else:
						st.apply_root(float(e["duration"]))
			"multiplier":
				if st:
					st.add_tickle_multiplier(float(e["value"]), float(e["duration"]))
			"slow":
				if st:
					st.apply_slow(float(e["value"]), float(e["duration"]))
			"pull":
				if st and source is Node2D:
					st.add_pull(source, float(e["speed"]), float(e["duration"]))
			"fatigue":
				var pc := _actor as PlayableCharacter
				if pc and pc.fatigue and MagicFatigue.accumulate:
					pc.fatigue.add_percent(float(e["percent"]))
			"debuff":
				_actor.add_buff(str(e["buff"]), float(e.get("duration", -2.0)))
			"seal":
				_actor.add_buff("sealed", float(e["duration"]))
			"special_next":
				_actor.forced_specials += int(e.get("count", 1))
			"buff_monsters":
				for m in monsters_near(float(e.get("radius", 96.0))):
					m.add_buff(str(e["buff"]), float(e.get("duration", -2.0)))
			"puddle":
				FatiguePuddle.spawn(_actor.get_parent(), _actor.global_position, float(e.get("life", 12.0)), float(e.get("radius", 20.0)))


## 角色身边 radius 内活着的怪物。
func monsters_near(radius: float) -> Array[Monster]:
	var out: Array[Monster] = []
	if _actor == null:
		return out
	for n in _actor.get_tree().get_nodes_in_group("enemy"):
		var m := n as Monster
		if m and m.is_alive() and m.global_position.distance_to(_actor.global_position) <= radius:
			out.append(m)
	return out
