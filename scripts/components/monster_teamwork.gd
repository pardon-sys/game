class_name MonsterTeamwork
extends Node
## 怪物配合技（可复用组件：挂在任何关卡上就能用；攻防战由 SiegeDirector 挂）。
## 配合技写在 data/teamwork.json（tools/build/gen_teamwork.py 生成）：
##   {id, name, color, members: [{key: 来源键或 [键…], count, role}], radius, cooldown, trigger: near / on_spawn,
##    need_princess（公主要在 leader 的多少像素内才发动；0 = 不用）, effect: {type, …参数}, formation: [[怪物键, 只数], …], intel}
## 每 SCAN 秒扫一次：把场上的怪按来源键分桶，对每个配合技找「leader」（members[0] 的怪），半径内凑齐其余成员就发动
## （TeamworkEffects.apply 按 effect.type 分派）；同一只怪发动后 BUSY 秒内不再参加别的配合，同一个配合技有冷却。
## spawn_formation(id, at)：一次生成一整套怪（formation），生成后马上组队（on_spawn 效果，比如护卫跟着工兵、螃蟹排在车前）。
## 宿主可以设置：spawn_func（键, 位置 → 怪物）、monsters_func（→ 场上的怪）；不设就用 "enemy" 组。
## 发动时在发动处冒一行彩色大字（「怪物配合：××！」），发 triggered(id, 位置) 信号（宿主据此弹情报、放音效）。

signal triggered(id: String, at: Vector2)
## 配合技真正发动（不含成套出现）：target 是被盯上的公主（可能为 null）
signal fired(id: String, at: Vector2, target: Node)

const PATH := "res://data/teamwork.json"
const SCAN := 0.5
const BUSY := 6.0

static var _data := {}

var spawn_func: Callable
var monsters_func: Callable
## 可选非怪物协作成员（攻防战敌塔）；旧关卡不设置时行为不变。
var partners_func: Callable
## 冷却：{配合技 id: 剩余秒}
var _cd := {}
var _scan := 0.0
var enabled := true
## 冷却再乘这个（攻防战：随波次越来越小，配合技越来越频繁；SiegeDirector 每波设）
var cd_scale := 1.0
## 冷却再除以这个（攻防战：特殊能力频率 ability_rate）
var cd_divisor := 1.0
## 关卡注入的条件（不设 = 都允许）：
##   allowed_func(team) -> bool            带 siege_only 的配合技现在能不能发动（攻防战：战斗中、到了 min_wave）
##   can_start_func(team, group) -> bool   联合配合（effect.joint）凑齐的这一组能不能开始
##   formation_gate_func(team, n) -> bool  成套生成 n 只之前问一下（攻防战最终波：增援上限）
var allowed_func: Callable
var can_start_func: Callable
var formation_gate_func: Callable
## 发动过的（测试 / 调试用）：[id, …]
var history: Array[String] = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
		_data = parsed if parsed is Dictionary else {}
	return _data


static func team(id: String) -> Dictionary:
	for t in data().get("teams", []):
		if str(t.get("id", "")) == id:
			return t
	return {}


static func key_of(m: Node) -> String:
	return ReactionDB.key_of(m)


func _ready() -> void:
	name = "MonsterTeamwork"


func _monsters() -> Array:
	var out: Array = monsters_func.call() if monsters_func.is_valid() else get_tree().get_nodes_in_group("enemy").filter(func(n): return n is Monster)
	if partners_func.is_valid():
		out = out + partners_func.call()
	return out.filter(func(n): return is_instance_valid(n) and n is Actor and not n.is_queued_for_deletion())


func _process(delta: float) -> void:
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta
	if not enabled or GameState.in_dialogue or CG.is_busy():
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN
	scan()


## 扫一遍，凑齐的就发动。返回这次发动的 id。
func scan() -> Array[String]:
	var fired: Array[String] = []
	var buckets := {}
	var now := Time.get_ticks_msec() / 1000.0
	for m in _monsters():
		if not is_instance_valid(m) or not (m as Actor).is_alive() or float(m.get_meta("team_busy", 0.0)) > now:
			continue
		var k := key_of(m)
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(m)
	for t in data().get("teams", []):
		if not _allowed(t) or str(t.get("trigger", "near")) != "near" or float(_cd.get(t["id"], 0.0)) > 0.0:
			continue
		var members := _find(t, buckets)
		if members.is_empty():
			continue
		fire(t, members)
		fired.append(str(t["id"]))
	return fired


## 找一组凑齐的成员（members[0] 当 leader）；凑不齐返回 []。
func _find(t: Dictionary, buckets: Dictionary, required_leader: Actor = null) -> Array:
	var specs: Array = t.get("members", [])
	if specs.is_empty():
		return []
	var r := float(t.get("radius", 60.0))
	var need_p := float(t.get("need_princess", 0.0))
	for leader in _bucket(buckets, specs[0]["key"]):
		if (required_leader != null and leader != required_leader) or not _available(leader, t):
			continue
		if t.get("paired_twins", false) and (not leader is TwinGhost or leader.half != "a" or not is_instance_valid(leader.twin)):
			continue
		var at: Vector2 = (leader as Node2D).global_position
		if need_p > 0.0 and _princess_near(at, need_p) == null:
			continue
		var group := [leader]
		var ok := true
		for i in range(specs.size()):
			var sp: Dictionary = specs[i]
			var want := int(sp.get("count", 1)) - (1 if i == 0 else 0)
			if want <= 0:
				continue
			var got := 0
			for m in _bucket(buckets, sp["key"]):
				if got >= want:
					break
				if group.has(m) or not _available(m, t) or (m as Node2D).global_position.distance_to(at) > r:
					continue
				if i == 0 and t.get("paired_twins", false) and m != leader.twin:
					continue
				group.append(m)
				got += 1
			if got < want:
				ok = false
				break
		if ok:
			if t.get("effect", {}).get("joint", false) and can_start_func.is_valid() and not can_start_func.call(t, group):
				continue
			return group
	return []


## 新攻防战配合的条件；旧数据不写字段时沿用原有行为。
func _allowed(t: Dictionary) -> bool:
	if not bool(t.get("siege_only", false)):
		return true
	return allowed_func.is_valid() and allowed_func.call(t)


func _available(m: Actor, t: Dictionary) -> bool:
	if not bool(t.get("siege_only", false)):
		return true
	return is_instance_valid(m) and m.is_alive() and not (m is Monster and m.is_stunned()) and not m.get_meta("airborne", false) \
		and not m.has_meta("in_ladder") and not m.has_meta("fortress_coop") and not m.get_meta("team_transfer", false) \
		and float(m.get_meta("team_busy", 0.0)) <= Time.get_ticks_msec() / 1000.0


## Boss 号令也走同一套成员匹配 / 冷却 / 忙碌锁，避免另一套协作系统。
func try_fire(id: String, leader: Actor) -> bool:
	var t := team(id)
	if t.is_empty() or not _allowed(t) or float(_cd.get(id, 0.0)) > 0.0:
		return false
	var buckets := {}
	var now := Time.get_ticks_msec() / 1000.0
	for m in _monsters():
		if not is_instance_valid(m) or not m.is_alive() or float(m.get_meta("team_busy", 0.0)) > now:
			continue
		var key := key_of(m)
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(m)
	var members := _find(t, buckets, leader)
	if members.is_empty():
		return false
	fire(t, members)
	return true


func _bucket(buckets: Dictionary, key: Variant) -> Array:
	if key is Array:
		var out := []
		for k in key:
			out += buckets.get(str(k), [])
		return out
	return buckets.get(str(key), [])


func _princess_near(at: Vector2, r: float) -> PlayableCharacter:
	var best: PlayableCharacter = null
	var best_d := r
	for n in get_tree().get_nodes_in_group("player_chars"):
		var c := n as PlayableCharacter
		if c and c.is_alive() and c.global_position.distance_to(at) < best_d:
			best_d = c.global_position.distance_to(at)
			best = c
	return best


## 发动一个配合技（members[0] 是 leader）。
func fire(t: Dictionary, members: Array) -> void:
	var id := str(t["id"])
	_cd[id] = float(t.get("cooldown", 10.0)) / cd_divisor * cd_scale
	var until := Time.get_ticks_msec() / 1000.0 + float(t.get("busy_time", BUSY))
	for m in members:
		m.set_meta("team_busy", until)
	var at: Vector2 = (members[0] as Node2D).global_position
	var ctx := {"host": self, "target": _princess_near(at, float(t.get("need_princess", 0.0)) if float(t.get("need_princess", 0.0)) > 0.0 else 400.0)}
	TeamworkEffects.apply(t, members, ctx)
	history.append(id)
	announce(str(t.get("name", id)), at, Color(str(t.get("color", "#ffd966"))))
	triggered.emit(id, at)
	fired.emit(id, at, ctx.get("target"))


## 发动处冒一行彩色大字。
func announce(title: String, at: Vector2, col: Color, prefix := "怪物配合：") -> void:
	var lv := get_parent()
	if lv == null:
		return
	var l := Label.new()
	l.text = prefix + title + "！"
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 5)
	l.z_index = 60
	l.add_to_group("siege_temp")
	lv.add_child(l)
	l.global_position = at + Vector2(-50, -46)
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", l.position.y - 18.0, 2.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.4)
	tw.tween_callback(l.queue_free)


## 成套生成一整套怪（formation），生成后马上组队。返回生成的怪。
func spawn_formation(id: String, at: Vector2) -> Array:
	var t := team(id)
	if t.is_empty() or not spawn_func.is_valid():
		return []
	if formation_gate_func.is_valid():
		var members := 0
		for row in t.get("formation", []):
			members += int(row[1])
		if not formation_gate_func.call(t, members):
			return []
	var made := []
	var i := 0
	for row in t.get("formation", []):
		for k in int(row[1]):
			var off := Vector2.from_angle(i * 2.4) * (6.0 + i * 3.5)
			var m: Variant = spawn_func.call(str(row[0]), at + off)
			if m is Monster:
				made.append(m)
			i += 1
	if not made.is_empty():
		TeamworkEffects.on_spawn(t, made, {"host": self})
		announce(str(t.get("name", id)), at, Color(str(t.get("color", "#ffd966"))), "成套出现：")
		triggered.emit(id, at)
	return made
