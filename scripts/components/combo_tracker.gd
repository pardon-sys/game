class_name ComboTracker
extends Node
## 组合技追踪（节点名 "Combo"，挂在会被挠痒的角色下，目前是公主）。
## 监听父节点的 tickled(hit)，记录最近挠到她的来源（ReactionDB.key_of），
## 与 data/combos.json 的 keys 匹配后触发：施加效果、HUD 横幅（GameState.combo_triggered）、公主说组合技台词。
##   两来源 / 三来源：keys 有 2 个或 3 个槽位；三来源默认 window 2.5 秒、cooldown 8 秒（每个组合可单独写）。
##   匹配优先级：三来源 > 指定来源的两来源 > 带通配符（"*" 任意怪物 / "*trap" 任意陷阱）的两来源。
##   连锁升级：两来源组合用过的挠痒记录标成 chained，不能再凑两来源组合，但还能和新来源凑成三来源组合。
##   连锁加成：上一个组合 CHAIN_WINDOW 秒内再触发组合，chain +1，burst / dot 按 ×(1 + 0.2 ×(chain − 1)) 加强。
##   trigger(id, source, force_effects)   条件型组合技由代码直接触发；冷却中返回 false，
##                                        force_effects = true 时冷却中也施加效果（只是不再弹横幅）
##   hit_multiplier(hit)                  条件型"本次挠痒倍率"（趁手打劫），由角色的 _tickle_multiplier 调用
## 组合技自己造成的额外挠痒 / 余痒来源是本节点，reaction_key 为空，不会被再次记录。
## 条件型：狂热连击（被带狂热 / 力量增益的怪物暴击）、牢笼里的暴击（被困住时被暴击）在这里检测；
## 魔力反噬（疲倦爆发时身边有怪物）由 PlayableCharacter.fatigue_burst 调用 trigger("mana_backlash")。
## 三来源组合第一次触发时播放 data/combo_scenes.json 里的小演出（CG.play_scene）。

signal triggered(id: String)

const PATH := "res://data/combos.json"
const CHAIN_WINDOW := 10.0
const CHAIN_BONUS := 0.2
const TRIPLE_WINDOW := 2.5
const TRIPLE_COOLDOWN := 8.0
## 三来源组合触发后多久开始播小演出（秒）。
const SCENE_DELAY := 1.2
## 抬起期间的余痒（每秒）。
const LIFT_DOT := 4.0
## 抬起是本节点抓住公主：挣脱次数设得很大 = 挣扎无效。
const LIFT_PRESSES := 9999

## 三来源组合第一次触发时是否播小演出（测试里关掉，避免演出暂停战斗）。
static var play_scenes := true

## 空键：自己施加的挠痒不参与匹配。
var reaction_key := ""
## 当前连锁数（0 = 没有连锁）。
var chain := 0
## 最近一次触发的组合是不是由两来源连锁升级成的三来源。
var last_upgraded := false

static var _data := {}
static var _sorted: Array = []
var _recent: Array[Dictionary] = []
var _ready_at := {}
var _time := 0.0
var _last_fire := -INF
var _actor: Actor


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
		_sorted = []
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


static func is_triple(c: Dictionary) -> bool:
	return c.get("keys", []).size() >= 3


static func has_wildcard(c: Dictionary) -> bool:
	for slot in c.get("keys", []):
		if slot.has("*") or slot.has("*trap"):
			return true
	return false


## 按匹配优先级排好的来源组合（不含条件型）。
static func sorted_combos() -> Array:
	data()
	if _sorted.is_empty():
		var keyed: Array = _data.get("combos", []).filter(func(c: Dictionary): return c.has("keys") and not c.has("condition"))
		var rank := func(c: Dictionary) -> int:
			return 0 if is_triple(c) else (2 if has_wildcard(c) else 1)
		for r in 3:
			_sorted += keyed.filter(func(c: Dictionary): return rank.call(c) == r)
	return _sorted


static func combo_window(c: Dictionary) -> float:
	return float(c.get("window", TRIPLE_WINDOW if is_triple(c) else data().get("window", 1.5)))


static func combo_cooldown(c: Dictionary) -> float:
	return float(c.get("cooldown", TRIPLE_COOLDOWN if is_triple(c) else data().get("cooldown", 4.0)))


func _ready() -> void:
	_actor = get_parent() as Actor
	if _actor:
		_actor.tickled.connect(_on_tickled)


func _process(delta: float) -> void:
	if not GameState.in_dialogue:
		_time += delta
		if chain > 0 and _time - _last_fire > CHAIN_WINDOW:
			chain = 0


func window() -> float:
	return float(data().get("window", 1.5))


func is_on_cooldown(id: String) -> bool:
	return _time < float(_ready_at.get(id, -1.0))


func reset() -> void:
	_recent.clear()
	_ready_at.clear()
	chain = 0
	_last_fire = -INF


## 最近记录的来源键（测试 / 调试用）。
func recent_keys() -> Array:
	return _recent.map(func(e: Dictionary): return e["key"])


## 连锁加成倍率（burst / dot）。
func chain_mult() -> float:
	return 1.0 + CHAIN_BONUS * maxf(chain - 1, 0)


func _max_window() -> float:
	var w := window()
	for c in sorted_combos():
		w = maxf(w, combo_window(c))
	return w


func _on_tickled(hit: HitData) -> void:
	var key := ReactionDB.key_of(hit.source)
	if key == "":
		return
	if hit.special:
		if hit.source is Monster and ((hit.source as Monster).has_buff("frenzy") or (hit.source as Monster).has_buff("strength")):
			trigger("frenzy_strike", hit.source)
		if _actor.status and _actor.status.is_grabbed():
			trigger("cage_crit", hit.source)
	# 来源还可以额外算作别的来源（痒痒转轮当前的面、刷子 / 史莱姆 / 小触手版的逗弄器和喷口）
	var keys: Array[String] = [key]
	if is_instance_valid(hit.source) and hit.source.has_method("extra_combo_keys"):
		for k in hit.source.extra_combo_keys():
			if not keys.has(str(k)):
				keys.append(str(k))
	var added: Array[Dictionary] = []
	for k in keys:
		var e := {"key": k, "time": _time, "source": hit.source, "chained": false}
		_recent.append(e)
		added.append(e)
	var since := _time - _max_window()
	_recent = _recent.filter(func(e: Dictionary): return e["time"] >= since)
	for e in added:
		if _recent.has(e):
			_check(e)


func _check(newest: Dictionary) -> void:
	for c in sorted_combos():
		if is_on_cooldown(c["id"]):
			continue
		var triple := is_triple(c)
		var since := _time - combo_window(c)
		# 每个来源键只保留最近一次；两来源组合不用已经连锁过的记录
		var latest := {}
		for e in _recent:
			if e["time"] >= since and (triple or not e["chained"]):
				latest[e["key"]] = e
		if not is_same(latest.get(newest["key"]), newest):
			continue
		var used := _assign(c["keys"], latest.values(), newest)
		if used.is_empty():
			continue
		var upgraded := false
		for e in used:
			upgraded = upgraded or e["chained"]
			if triple:
				_recent.erase(e)
			else:
				e["chained"] = true
		_fire(c, used[0]["source"], upgraded)
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
	return slot.has(key) or (slot.has("*") and group("monster").has(key)) or (slot.has("*trap") and group("trap").has(key))


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


func _fire(c: Dictionary, source: Node, upgraded := false) -> void:
	var id: String = c["id"]
	chain = chain + 1 if _time - _last_fire <= CHAIN_WINDOW else 1
	_last_fire = _time
	last_upgraded = upgraded
	_ready_at[id] = _time + combo_cooldown(c)
	_apply_effects(c, source)
	Audio.play("combo", -2.0, 0.02, 1.15 if is_triple(c) else 1.0)
	GameState.combo_triggered.emit(id, str(ReactionDB.combo(id).get("name", id)))
	if not GameState.has_flag("hint_first_combo"):
		GameState.set_flag("hint_first_combo")
		GameState.notify(ReactionDB.hint("first_combo"))
	triggered.emit(id)
	if _actor and _actor.has_method("say_combo"):
		_actor.say_combo(id)
	if play_scenes and is_triple(c) and not GameState.has_flag("combo_scene_" + id):
		# 标记由 CG 在真正开始播时设置；正在播别的就排队，不会被吞掉
		var cg := get_node_or_null("/root/CG")
		if cg and cg.has_method("play_scene"):
			# 先让 HUD 的大字标题和慢动作演完，再切到小演出
			get_tree().create_timer(SCENE_DELAY, false).timeout.connect(cg.play_scene.bind(id))


func _apply_effects(c: Dictionary, source: Node) -> void:
	var st := _actor.status if _actor else null
	var k := chain_mult()
	for e in c.get("effects", []):
		match str(e["type"]):
			"burst":
				_actor.receive_hit(HitData.make_tickle(self, float(e["amount"]) * k))
			"dot":
				if st:
					st.add_dot(float(e["rate"]) * k, float(e["duration"]), self)
			"root":
				if st:
					if e.get("after_release", false):
						st.root_after_release(float(e["duration"]))
					elif e.get("extend", false):
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
			"grab_extend":
				if st:
					st.extend_grab(float(e["seconds"]))
			"grab_presses":
				if st:
					st.extend_grab(0.0, int(e["count"]))
			"lift":
				_lift(float(e.get("duration", 2.0)), k)
			"confuse":
				_actor.add_buff("dizzy", float(e.get("duration", 3.0)))
			"crit_storm":
				_actor.add_buff("crit_storm", float(e.get("duration", 3.0)))
			"rally":
				for m in monsters_near(float(e.get("radius", 160.0))):
					m.rally_to(_actor)
			"focus":
				if _actor.has_method("focus_camera"):
					_actor.focus_camera()


## 抬起：举到半空（本节点抓住她，挣扎无效），期间持续余痒。已经被抓着时延长抓取。
func _lift(duration: float, k: float) -> void:
	var st := _actor.status
	if st == null or _actor.is_fully_invulnerable():
		return
	_actor.add_buff("lifted", duration)
	if st.is_grabbed():
		st.extend_grab(duration)
	else:
		st.grab(self, duration, LIFT_PRESSES)
	st.add_dot(LIFT_DOT * k, duration, self)


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
