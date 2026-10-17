class_name SiegeHazard
extends Node2D
## 攻防战的大范围陷阱基类（SiegeDirector 按波次的 hazards 时间表放出来：{t, kind}）。
## 先有 WARN 秒预警（地上的圈 / 线），然后生效 life 秒，到时间淡出删掉。挠痒的来源键 = hazard_<种类>（reaction_key），三来源组合认它。
## 子类：tornado 痒痒龙卷风 / bubbles 痒痒泡泡潮 / link_rune 痒感连线符文 / broom 城墙羽毛扫帚 / fog 痒痒迷雾 /
##       wall_vine 城墙爬藤（牺牲互救）/ sticky_net 黏网（牺牲互救）/
##       大型强制位移：claw 天降抓娃娃机 / quicksand 挠痒流沙旋涡 / mushrooms 弹弹蘑菇阵 / portal_pair 挠痒传送门
## 法术落点：SiegeSpells 施法后调用 notify_spell，有 on_spell(point, radius) 的陷阱（传送门会被冰封）接着处理。

const WARN := 1.2

var director: SiegeDirector
var reaction_key := ""
var life := 15.0
var warned := false
var _warn_left := WARN
var _t := 0.0


static func make(kind: String) -> SiegeHazard:
	match kind:
		"tornado": return HazardTornado.new()
		"bubbles": return HazardBubbles.new()
		"link_rune": return HazardLinkRune.new()
		"broom": return HazardBroom.new()
		"fog": return HazardFog.new()
		"wall_vine": return HazardWallVine.new()
		"sticky_net": return HazardStickyNet.new()
		"claw": return HazardClaw.new()
		"quicksand": return HazardQuicksand.new()
		"mushrooms": return HazardMushrooms.new()
		"portal_pair": return HazardPortalPair.new()
	return null


## 法术落在 point（半径 radius）：通知场上的陷阱。返回有几个陷阱接住了。
static func notify_spell(tree: SceneTree, point: Vector2, radius: float) -> int:
	var n := 0
	for h in tree.get_nodes_in_group("siege_hazard"):
		if h.has_method("on_spell") and int(h.call("on_spell", point, radius)) > 0:
			n += 1
	return n


func _ready() -> void:
	add_to_group("siege_temp")
	add_to_group("siege_hazard")
	director = SiegeDirector.current
	_begin()


## 子类：出现时（画预警）。
func _begin() -> void:
	pass


## 子类：生效后每帧。
func _active(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if SiegeTools.paused():
		return
	if director == null or director.state != "fight" and director.state != "prep":
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		if _warn_left <= 0.0:
			warned = true
			_on_start()
		queue_redraw()
		return
	life -= delta
	_t += delta
	_active(delta)
	queue_redraw()
	if life <= 0.0:
		_end()


func _on_start() -> void:
	pass


func _end() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	set_process(false)


func tickle(c: PlayableCharacter, amount: float, zone := "") -> void:
	if c == null or not is_instance_valid(c) or not c.is_alive() or Downed.is_downed(c):
		return
	var h := HitData.make_tickle(self, amount)
	h.zone = zone
	c.receive_hit(h)


func chars() -> Array[PlayableCharacter]:
	var out: Array[PlayableCharacter] = []
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c) and c.is_alive() and not Downed.is_downed(c):
			out.append(c)
	return out


# ------------------------------------------------------------------ 陷阱和怪物的配合（龙卷风 / 抓娃娃机 / 蘑菇把怪送上墙，流沙 / 传送门 / 黏网放伏兵）
## 把怪甩上城墙顶（落点靠近蓝色公主，见 TeamworkEffects._wall_spot）；那段墙爬不上去就不甩，返回 false。
static func fling_to_wall(m: Monster, time := 0.6, height := 60.0) -> bool:
	var d := SiegeDirector.current
	var spot: Variant = TeamworkEffects._wall_spot(m.global_position.x)
	if d == null or not (spot is Vector2):
		return false
	var wall := d.segment_at((spot as Vector2).x)
	if wall == null or not wall.climbable():
		return false
	var wr: WeakRef = weakref(m)
	m.set_meta("airborne", true)
	TeamworkEffects._arc(m, spot, time, height, func():
		var mm := wr.get_ref() as Monster
		if TeamworkEffects._alive(mm):
			mm.remove_meta("airborne")
			TeamworkEffects.put_on_wall(mm, mm.global_position))
	return true


## 把怪甩到 to（落地扬尘）。
static func fling_to(m: Monster, to: Vector2, time := 0.5, height := 40.0) -> void:
	var wr: WeakRef = weakref(m)
	m.set_meta("airborne", true)
	TeamworkEffects._arc(m, to, time, height, func():
		var mm := wr.get_ref() as Monster
		if TeamworkEffects._alive(mm):
			mm.remove_meta("airborne")
			Fx.burst(mm.get_parent(), mm.global_position, "dust", 4, 30.0, 0.4, Vector2(0, 20)))


## 在 at 附近放出 n 只伏兵（keys 里轮流挑；最终波受增援配额限制，spawn 不出来就少几只）；target 给了就围过去。
func ambush(at: Vector2, keys: Array, n: int, target: PlayableCharacter = null) -> Array[Monster]:
	var made: Array[Monster] = []
	for i in n:
		var pos := director.clamp_in_map(at + Vector2.from_angle(randf() * TAU) * randf_range(6.0, 18.0))
		var m := director.spawn(str(keys[i % keys.size()]), "", pos)
		if m == null:
			continue
		m.set_meta("siege_hazard_spawn", true)
		if target and SiegeTools.alive(target):
			m.rally_to(target)
		made.append(m)
	if not made.is_empty():
		Fx.burst(get_parent(), at, "dust", 10, 40.0, 0.5, Vector2(0, 30), Color(0.8, 0.7, 0.5))
	return made
