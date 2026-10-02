class_name Sensitivity
extends RefCounted
## 一个角色的挠痒敏感状态（PlayableCharacter.sensitivity）：
##   连续部位加成  同一部位 streak.window 秒内连续被挠，每次 +step（最多 +max），停下后每秒恢复 recover
##   露出部位      束缚陷阱困住时 expose(来源, {部位: 倍率})，放开时 unexpose(来源)；同时挂通用状态 exposed
##   战损          本条命里失控过（damaged），复活 reset()
## apply(hit, actor) 在受到挠痒时调用：抽部位（写进 hit.zone）、更新连续加成，返回总敏感倍率。

signal weak_point(zone: String)

var damaged := false
## 部位 -> 当前连续加成
var streak := {}
## 部位 -> 最后一次被挠的时间
var _last := {}
## 来源实例 id -> {部位: 倍率}
var _exposed := {}
var _time := 0.0


func tick(delta: float) -> void:
	_time += delta
	var rule := TickleZones.streak_rule()
	for z in streak.keys():
		if _time - float(_last.get(z, -INF)) > float(rule.get("window", 2.0)):
			streak[z] = maxf(float(streak[z]) - float(rule.get("recover", 0.1)) * delta, 0.0)
			if streak[z] <= 0.0:
				streak.erase(z)


func reset() -> void:
	damaged = false
	streak.clear()
	_last.clear()
	_exposed.clear()


## 当前露出的部位 {部位: 倍率}（多个来源取最大）。
func exposed() -> Dictionary:
	var out := {}
	for src in _exposed:
		for z in _exposed[src]:
			out[z] = maxf(float(out.get(z, 1.0)), float(_exposed[src][z]))
	return out


func expose(src: Object, zones: Dictionary, actor: Actor = null) -> void:
	_exposed[src.get_instance_id()] = zones.duplicate()
	if actor:
		actor.add_buff("exposed")


func unexpose(src: Object, actor: Actor = null) -> void:
	_exposed.erase(src.get_instance_id())
	if actor and _exposed.is_empty():
		actor.remove_buff("exposed")


## 露出状态的显示名，例如「露出：脚心、大腿」。
func exposed_label() -> String:
	var names: Array[String] = []
	for z in exposed():
		names.append(TickleZones.zone_name(z))
	return "露出：" + "、".join(names) if not names.is_empty() else "露出部位"


func exposed_icon() -> int:
	for z in exposed():
		return int(TickleZones.info(z).get("icon", 9))
	return 9


## 某部位的连续加成。
func streak_of(zone: String) -> float:
	return float(streak.get(zone, 0.0))


## 某部位现在的总敏感倍率（不含全身项）：部位 sensitivity × (1 + 连续加成) × 露出倍率。
func zone_total(zone: String) -> float:
	return TickleZones.zone_multiplier(zone) * (1.0 + streak_of(zone)) * float(exposed().get(zone, 1.0))


## 受到挠痒时调用：有来源键的挠痒抽一个部位，返回总敏感倍率（全身项 × 部位项）。
func apply(hit: HitData, actor: Actor) -> float:
	var stage := actor.laugh.stage() if actor.laugh else "calm"
	if actor.laugh and actor.laugh.is_helpless():
		damaged = true
	var k := TickleZones.body_multiplier(stage, damaged)
	if ReactionDB.key_of(hit.source) == "":
		return k
	var ex := exposed()
	var zone := TickleZones.pick(hit.source, ex)
	hit.zone = zone
	if zone == "":
		return k
	k *= zone_total(zone)
	# 更新连续加成（这一下之后才加，下一下更痒）
	var rule := TickleZones.streak_rule()
	if _time - float(_last.get(zone, -INF)) <= float(rule.get("window", 2.0)):
		streak[zone] = minf(streak_of(zone) + float(rule.get("step", 0.03)), float(rule.get("max", 0.3)))
	_last[zone] = _time
	if ex.has(zone):
		weak_point.emit(zone)
	return k
