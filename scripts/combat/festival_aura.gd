class_name FestivalAura
extends Node2D
## 随身祭典：仅维护既有 Buff，不另设属性／控制系统。每 0.2 秒刷新 0.3 秒限时状态。
## 友方移动单位：speed ×1.2、damage_dealt ×1.4；敌怪与 Boss：speed ×1.2、tickle_power ×1.35。
## 范围／时长由 cast、refresh 配置；暂停冻结，死亡／换图结束。F2 不结束。

const ALLY_BUFF := "festival_ally"
const ENEMY_BUFF := "festival_enemy"
const INTERVAL := 0.2
const GRACE := 0.3
const TIERS := [{}, {"radius": 64.0, "duration": 4.0}, {"radius": 88.0, "duration": 6.0}, {"radius": 112.0, "duration": 8.0}]
var caster: WeakRef
var radius := 64.0
var time_left := 4.0
var _scan := 0.0
var _phase := 0.0
var _touched: Array[WeakRef] = []


static func params(tier: int) -> Dictionary:
	return TIERS[clampi(tier, 1, 3)]


static func cast(who: PlayableCharacter, r: float, duration: float) -> FestivalAura:
	var a := FestivalAura.new()
	a.caster = weakref(who)
	a.radius = r
	a.time_left = duration
	who.get_parent().add_child(a)
	a.global_position = who.global_position
	a.scan()
	return a


func refresh(r: float, duration: float) -> void:
	radius = maxf(radius, r)
	time_left = maxf(time_left, duration)
	_scan = 0.0


func eligible(a: Actor, who: Actor) -> bool:
	if not a.is_alive() or a is IceTower or a is EnemyTower:
		return false
	if Faction.are_hostile(who, a):
		return a is Monster
	return a is PlayableCharacter or a is SiegeSoldier or a is Snowman


func scan() -> void:
	var who := caster.get_ref() as PlayableCharacter
	if not is_instance_valid(who):
		return
	for n in get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a == null or not eligible(a, who) or FortressRules.distance(a, global_position) > radius:
			continue
		a.add_buff(ENEMY_BUFF if Faction.are_hostile(who, a) else ALLY_BUFF, GRACE)
		if not _touched.any(func(w): return w.get_ref() == a):
			_touched.append(weakref(a))


func _process(delta: float) -> void:
	var who := caster.get_ref() as PlayableCharacter
	if not is_instance_valid(who) or not who.is_alive() or not who.is_inside_tree():
		queue_free()
		return
	global_position = who.global_position
	if SiegeTools.paused():
		return
	time_left -= delta
	_phase += delta
	if time_left <= 0.0:
		queue_free()
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = INTERVAL
		scan()
	queue_redraw()


func _ready() -> void:
	z_index = 0 # 地板也是z=0，不能放到负层被整张地板遮住。
	add_to_group("festival_aura")


func _draw() -> void:
	var ring := IceBarrier.ring_points(radius, 48)
	draw_colored_polygon(ring, Color(1, 0.57, 0.16, 0.07))
	draw_polyline(ring, Color(1, 0.77, 0.34, 0.65), 1.5)
	for i in 8:
		var ang := TAU * i / 8.0 + _phase * 0.7
		var at := Vector2(cos(ang) * radius, sin(ang) * radius * 0.55)
		draw_circle(at, 2.0, Color(1, 0.9, 0.5, 0.85))
		draw_line(at, at + Vector2(-4, -6), Color(1, 0.45, 0.25, 0.8), 1.0)


func _exit_tree() -> void:
	# 同类光环均为 1 层；其它实例还在覆盖的目标留给它继续刷新。
	for w in _touched:
		var a := w.get_ref() as Actor
		if not is_instance_valid(a):
			continue
		var covered := false
		for other in get_tree().get_nodes_in_group("festival_aura"):
			if other != self and not other.is_queued_for_deletion() and FortressRules.distance(a, other.global_position) <= other.radius:
				covered = true
				break
		if not covered:
			a.remove_buff(ALLY_BUFF)
			a.remove_buff(ENEMY_BUFF)
