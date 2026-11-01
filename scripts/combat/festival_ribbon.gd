class_name FestivalRibbon
extends Projectile
## 彩带回旋：原 Projectile 子类，去／回程各命中一次；2.5 秒寿命、144 射程、240 速度。
## 来源弱引用；每程按 Actor 实例去重。墙阻挡去程折返、回程消散；不穿墙瞬移。

const REACH := 144.0
const FLIGHT_SPEED := 240.0
const LIFE := 2.5
const DAMAGE := 2
const PUSH := 45.0
var owner_ref: WeakRef
var returning := false
var travelled := 0.0
var _phase_hits := {}
var _spin := 0.0
var _flight_hit: HitData


static func launch(who: PlayableCharacter, aim: Vector2) -> FestivalRibbon:
	var r := FestivalRibbon.new()
	r.owner_ref = weakref(who)
	r.shooter = who
	r.shooter_faction = Faction.of(who)
	r.direction = aim.normalized() if aim != Vector2.ZERO else Vector2.DOWN
	r._flight_hit = HitData.make_attack(who, DAMAGE, PUSH)
	who.get_parent().add_child(r)
	r.global_position = who.global_position + Vector2(0, -8)
	return r


func _ready() -> void:
	super()
	# 本体使用逐帧扫掠，避免高速弹漏碰撞；碰撞形状无需持久注册到物理空间。
	monitoring = false
	z_index = 8
	add_to_group("festival_ribbon")


func _physics_process(delta: float) -> void:
	var who := owner_ref.get_ref() as PlayableCharacter
	if not is_instance_valid(who) or not who.is_alive():
		queue_free()
		return
	if SiegeTools.paused():
		return
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var destination := who.global_position + Vector2(0, -8)
	if returning:
		if global_position.distance_to(destination) <= 10.0:
			queue_free()
			return
		direction = global_position.direction_to(destination)
	var distance := minf(FLIGHT_SPEED * delta, global_position.distance_to(destination)) if returning else minf(FLIGHT_SPEED * delta, REACH - travelled)
	var end := global_position + direction * distance
	# 射线检测实体墙；角色碰撞由下方扫掠处理。
	var query := PhysicsRayQueryParameters2D.create(global_position, end, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		end = wall["position"]
	_sweep(global_position, end, who)
	if not wall.is_empty():
		var body: Node = wall["collider"]
		# 保留 Projectile 原有的中立 Damageable 行为；敌塔代理归并到原塔去重。
		var target: Node = body.tower if body is EnemyTower.HurtProxy else body
		if not target is IceTower and Contracts.is_damageable(target) and (Faction.of(target) == Faction.Type.NEUTRAL or Faction.are_hostile(who, target)):
			_hit_target(target, who, global_position)
	global_position = end
	travelled += distance
	_spin += delta * 14.0
	queue_redraw()
	if not wall.is_empty():
		if returning:
			queue_free()
		else:
			_turn()
	elif not returning and travelled >= REACH:
		_turn()


func _turn() -> void:
	returning = true
	_phase_hits.clear()


func _sweep(from: Vector2, to: Vector2, who: PlayableCharacter) -> void:
	for n in get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a == null or a == who or not a.is_alive() or not Faction.are_hostile(who, a):
			continue
		var at := FortressRules.point(a, from)
		var near := Geometry2D.get_closest_point_to_segment(at, from, to)
		if FortressRules.distance(a, near) > 10.0 or _phase_hits.has(a.get_instance_id()):
			continue
		_hit_target(a, who, from)


	# 不是 Actor 的敌方部件（骑士 Boss 的盔甲部件 BossPart：enemy 组、有 receive_hit、meta hit_radius）
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Actor or not n is Node2D or not n.has_method("receive_hit") or (n.has_method("is_alive") and not n.is_alive()):
			continue
		var at: Vector2 = (n as Node2D).global_position
		var r := float(n.get_meta("hit_radius", 8.0)) + 6.0
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to)) <= r:
			_hit_target(n, who, from)


func _hit_target(target: Node, who: PlayableCharacter, from: Vector2) -> void:
	if _phase_hits.has(target.get_instance_id()):
		return
	_phase_hits[target.get_instance_id()] = true
	var h := _flight_hit.copy()
	h.origin = from
	if target.receive_hit(h):
		var box := who.get_node_or_null("Hitbox") as HitboxComponent
		if box:
			box.hit_landed.emit(target)


func _draw() -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := _spin + TAU * i / 12.0
		points.append(Vector2(cos(a) * 9, sin(a) * 5))
	draw_polyline(points, Color(1, 0.65, 0.2), 2.0)
	draw_line(points[0], points[0] - direction * 12, Color(1, 0.87, 0.55, 0.8), 1.5)
