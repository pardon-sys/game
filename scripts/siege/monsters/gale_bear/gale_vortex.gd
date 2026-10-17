class_name GaleVortex
extends TickleVortex
## 熊的薄漩涡子类：沿用原陷阱、can_pull / pull_for，仅补寿命、中心挠痒与可移动物。

const BURST_WARN := 0.12

var boss_ref: WeakRef
var life := 3.5
var age := 0.0
var tools := 6
var _scan := 0.0
var _burst_warned := false
var _ending := false
var _captured: Array[WeakRef] = []
var _eye: Node2D
var _warnings: Array[Node] = []


static func spawn(bear: GaleBear, rage: bool) -> GaleVortex:
	var n := GaleVortex.new()
	n.boss_ref = weakref(bear)
	n.radius = 16 if rage else 14
	n.life = 4.5 if rage else 3.5
	n.pull_edge = 70.0 if rage else 55.0
	n.pull_center = 190.0 if rage else 160.0
	n.repeat_interval = 0.5
	n.reaction_key = "gale_bear"
	n.collision_layer = 0
	n.collision_mask = 6
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	n.add_child(shape)
	n.position = bear.global_position
	bear.get_parent().add_child(n)
	bear.register_field(n)
	return n


func _setup() -> void:
	super()
	add_to_group("siege_temp")
	add_to_group("danger")
	set_meta("radius", radius * 16.0)
	_sprite.modulate = Color(0.45, 0.95, 0.9, 0.28)
	_sprite.visible = false  # 大范围用风纹表达，避免把 48px 小底图放大盖住人物。
	_particles.color = Color(0.45, 0.95, 0.9)
	_eye = SiegeFx.wind_eye(self, global_position, radius * 16.0, life + BURST_WARN, true)
	_eye.z_index = 3


func _bear() -> GaleBear:
	return boss_ref.get_ref() as GaleBear if boss_ref else null


func _victims() -> Array:
	var bear := _bear()
	if bear == null:
		return []
	var out: Array = bear._targets()
	out.append_array(bear.director.enemies_near(global_position, radius * 16.0))
	return out.filter(func(a): return SiegeTools.alive(a) and a.global_position.distance_to(global_position) <= radius * 16.0)


func can_pull(a: Actor) -> bool:
	if a is PlayableCharacter and not SiegeTools.can_move(null, a):
		return false
	if a is Monster:
		return SiegeTools.displaceable(a)
	if a is EnemyTower or a is IceTower or not a.is_physics_processing():
		return false
	if a.get_meta("airborne", false) or a.get_meta("team_transfer", false) or a.has_meta("in_ladder"):
		return false
	if a is SiegeMonster and (a.on_wall or a.climbing):
		return false
	if a.has_method("is_airborne") and a.is_airborne():
		return false
	return super(a)


func _physics_process(delta: float) -> void:
	if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	var bear := _bear()
	if not SiegeTools.alive(bear) or bear.is_stunned() or bear.director.state != "fight":
		_end()
		return
	if _burst_warned:
		return
	global_position = bear.global_position  # 本体能继续出招 / 移动，吸引仍以熊为中心。
	super(delta)


func _apply_effect(target: Node) -> bool:
	var bear := _bear()
	if bear == null or not target is PlayableCharacter or target.is_airborne():
		return false
	var core := 112.0 if radius == 16 else 96.0
	if target.global_position.distance_to(global_position) > core:
		return false
	return bear.strike(target, 4.0 + 0.5 * mini(tools, 12), "vacuum", 0.0, global_position)


func _process(delta: float) -> void:
	if _ending or GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	var bear := _bear()
	if not SiegeTools.alive(bear) or bear.is_stunned() or bear.director.state != "fight":
		_end()
		return
	age += delta
	if not active and not _burst_warned:
		_release_projectiles()
		_particles.emitting = false
		_sound.stop()
		if age >= life:
			_end()
		return
	if not _burst_warned:
		super(delta)
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.1
			_gather()
		_orbit()
		tools = mini(12, 6 + int(age * 2.0) + _captured.size())
		if age >= life:
			_burst_warned = true
			active = false
			_particles.emitting = false
			_release_projectiles()
			_warnings.append(SiegeFx.warn(get_parent(), global_position, "circle", 112.0, BURST_WARN, GaleBear.GOLD, 0.0, 1.2, true))
			for i in 8:
				_warnings.append(SiegeFx.lane(get_parent(), global_position, global_position + Vector2.from_angle(TAU * i / 8.0) * 350.0, 24.0, GaleBear.GOLD, BURST_WARN, true))
	elif age >= life + BURST_WARN:
		for i in 8:
			GaleWind.shoot(bear, global_position, Vector2.from_angle(TAU * i / 8.0), 10.0, "vacuum", i % 2 == 0)
		Fx.burst(get_parent(), global_position, "feather", 24, 130.0, 0.8, Vector2.ZERO)
		SiegeFx.screen_shake(self, 2.0, 0.2)
		_end()


func _gather() -> void:
	for n in get_tree().get_nodes_in_group("world_item"):
		var item := n as WorldItem
		if item == null or item.is_queued_for_deletion() or item._ready_time > 0.0:
			continue
		var to := global_position - item.global_position
		if to.length() > radius * 16.0 or to.length() < 4.0:
			continue
		var next := item.global_position.move_toward(global_position, pull_center * 0.1)
		# 掉落物不穿过实体墙或建筑，不销毁、不更改物品内容。
		var ray := PhysicsRayQueryParameters2D.create(item.global_position, next, 1)
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			item.global_position = next
	for n in get_tree().get_nodes_in_group("siege_wind_projectile"):
		var p := n as SiegeProjectile
		if p == null or p.is_queued_for_deletion() or p._spent or (p._wind_ref and is_instance_valid(p._wind_ref.get_ref())):
			continue
		var distance := p.global_position.distance_to(global_position)
		if distance > radius * 16.0:
			continue
		p.global_position = p.global_position.move_toward(global_position, pull_center * 0.1)
		if distance <= 72.0 and _captured.size() < 8 and p.begin_wind_capture(self):
			_captured.append(weakref(p))


func _orbit() -> void:
	_captured = _captured.filter(func(ref): return is_instance_valid(ref.get_ref()) and not ref.get_ref().is_queued_for_deletion())
	for i in _captured.size():
		var p := _captured[i].get_ref() as SiegeProjectile
		var a := _anim * 2.0 + i * TAU / maxf(1.0, _captured.size())
		p.global_position = global_position + Vector2.from_angle(a) * 48.0 + Vector2(0, -8)
		p.rotation = a + PI / 2.0
		# 原装备的命中回调只执行一次；沿用原本目标，保持角色适配。
		if SiegeTools.alive(p.target) and p.global_position.distance_to(p.target.global_position + Vector2(0, -8)) < 16.0:
			p.wind_hit(p.target)


func _release_projectiles() -> void:
	for ref in _captured:
		var p := ref.get_ref() as SiegeProjectile
		if is_instance_valid(p):
			p.release_wind_capture(self)
	_captured.clear()


func _end() -> void:
	if _ending:
		return
	_ending = true
	active = false
	_release_projectiles()
	for n in _warnings:
		if is_instance_valid(n):
			n.queue_free()
	_warnings.clear()
	set_physics_process(false)
	set_process(false)
	if is_instance_valid(_eye):
		_eye.queue_free()
	if is_instance_valid(_sound):
		_sound.stop()
	queue_free()


func _exit_tree() -> void:
	_release_projectiles()
