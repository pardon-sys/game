class_name GaleWind
extends RefCounted
## 熊的短风效：飞具沿用 SiegeProjectile；范围效果沿用 SiegeHazard。


static func shoot(bear: GaleBear, at: Vector2, dir: Vector2, amount: float, variant: String, feather: bool) -> Shot:
	var n := Shot.new()
	n.boss_ref = weakref(bear)
	n.heading = dir.normalized()
	n.amount = amount
	n.variant = variant
	n.texture = Fx.PARTICLES["feather"] if feather else IceTower.TEX
	n.region_enabled = not feather
	if not feather:
		n.region_rect = IceTower.region("proj_brush")
	n.speed = 310.0
	n.windable = true
	n.add_to_group("siege_wind_projectile")
	n.position = at
	n.add_to_group("siege_temp")
	n.add_to_group("trap")
	n.add_to_group("magic_reactive")
	n.add_to_group("danger")
	n.set_meta("radius", 10.0)
	n.set_meta("velocity", n.heading * n.speed)
	n.z_index = 6
	bear.get_parent().add_child(n)
	bear.register_field(n)
	return n


static func pulse(bear: GaleBear, at: Vector2) -> Field:
	var n := Field.new()
	n.boss_ref = weakref(bear)
	n.kind = "pulse"
	n.life = 0.8
	n.position = at
	bear.get_parent().add_child(n)
	bear.register_field(n)
	return n


static func lane(bear: GaleBear, from: Vector2, to: Vector2, duration: float) -> Field:
	var n := Field.new()
	n.boss_ref = weakref(bear)
	n.kind = "lanes"
	n.goal = to
	n.life = duration
	n.position = from
	bear.get_parent().add_child(n)
	bear.register_field(n)
	return n


class Shot extends SiegeProjectile:
	var boss_ref: WeakRef
	var heading := Vector2.UP
	var amount := 8.0
	var variant := "chase"
	var active := true
	var _trail := 0.0

	func _process(delta: float) -> void:
		if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
			return
		var bear := boss_ref.get_ref() as GaleBear
		if not SiegeTools.alive(bear) or bear.director.state != "fight":
			_end()
			return
		if _wind_ref and is_instance_valid(_wind_ref.get_ref()):
			return
		_wind_ref = null
		_life -= delta
		if _life <= 0.0:
			_end()
			return
		set_meta("velocity", heading * speed if active else Vector2.ZERO)
		if not active:
			if is_in_group("danger"):
				remove_from_group("danger")
			return
		if not is_in_group("danger"):
			add_to_group("danger")
		var from := global_position
		global_position += heading * speed * delta
		rotation = heading.angle() + PI / 2.0
		for a in bear._targets():
			var along := clampf((a.global_position - from).dot(heading), 0.0, speed * delta)
			if a.global_position.distance_to(from + heading * along) < 14.0 and bear.strike(a, amount, variant, 0.0, from):
				_end()
				return
		_trail -= delta
		if _trail <= 0.0 and bear.director.on_screen(global_position):
			_trail = 0.15
			Fx.burst(get_parent(), global_position, "feather", 1, 8.0, 0.25, Vector2.ZERO, GaleBear.WIND)

	func on_magic_burst(tier: int, _caster: Node) -> void:
		if tier >= 3:
			_end()

	func _end() -> void:
		active = false
		if is_in_group("danger"):
			remove_from_group("danger")
		queue_free()


class Field extends SiegeHazard:
	var boss_ref: WeakRef
	var kind := "pulse"
	var active := true
	var goal := Vector2.ZERO
	var _hits := {}
	var _interval := 0.0
	var _wall_hit := false
	var _wind: CPUParticles2D

	func _begin() -> void:
		reaction_key = "gale_bear"
		_warn_left = 0.0
		warned = true
		add_to_group("trap")
		add_to_group("magic_reactive")
		add_to_group("danger")
		if kind == "pulse":
			set_meta("radius", 0.0)
		else:
			set_meta("rect", Rect2(global_position, Vector2.ZERO).expand(goal).grow(16.0))
			var dir := global_position.direction_to(goal)
			_wind = Fx.emitter(self, "feather", 20, 1.0, {"dir": dir, "spread": 8.0, "speed": [130.0, 190.0], "color": GaleBear.WIND, "z": 4})
			_wind.emitting = true

	func _process(delta: float) -> void:
		if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
			return
		var bear := boss_ref.get_ref() as GaleBear
		if not SiegeTools.alive(bear) or director == null or director.state != "fight":
			_end()
			return
		super(delta)

	func _active(delta: float) -> void:
		if not active:
			if is_in_group("danger"):
				remove_from_group("danger")
			if _wind:
				_wind.emitting = false
			return
		if not is_in_group("danger"):
			add_to_group("danger")
		var bear := boss_ref.get_ref() as GaleBear
		if kind == "pulse":
			var radius := minf(160.0, _t * 270.0)
			set_meta("radius", radius)
			for a in bear._targets():
				if not _hits.has(a.get_instance_id()) and a.global_position.distance_to(global_position) <= radius:
					if bear.strike(a, 12.0, "pulse", 200.0, global_position):
						_hits[a.get_instance_id()] = true
		else:
			_interval -= delta
			var dir := global_position.direction_to(goal)
			var length := global_position.distance_to(goal)
			var front := minf(length, _t * maxf(180.0, length / maxf((_t + life) * 0.65, 0.1)))
			if _wind:
				_wind.emitting = director.on_screen(global_position.lerp(goal, 0.5), length / 2.0)
			for a in bear._targets():
				if _in_lane(a.global_position, dir, front) and _interval <= 0.0:
					bear.strike(a, 5.0, "lanes", 70.0, a.global_position - dir * 16.0)
			for m in director.enemies_near(global_position.lerp(goal, 0.5), length / 2.0 + 32.0):
				if not SiegeTools.displaceable(m):
					continue
				if _in_lane(m.global_position, dir, front):
					m.add_push(dir * 70.0)
			if _interval <= 0.0:
				_interval = 0.6
			if not _wall_hit and front >= length:
				_wall_hit = true
				var wall := director.segment_at(goal.x)
				if wall:
					wall.take(12.0 * SiegeWall.DAMAGE_MULT)
				SiegeFx.impact(get_parent(), goal, 35.0, false, GaleBear.WIND)

	func _in_lane(p: Vector2, dir: Vector2, front: float) -> bool:
		var rel := p - global_position
		return rel.dot(dir) >= 0.0 and rel.dot(dir) <= front and absf(rel.cross(dir)) <= 16.0

	func _end() -> void:
		if not is_processing():
			return
		active = false
		if _wind:
			_wind.emitting = false
		if is_in_group("danger"):
			remove_from_group("danger")
		super()

	func on_magic_burst(tier: int, _caster: Node) -> void:
		if tier >= 3:
			_end()

	func _draw() -> void:
		if not active:
			return
		if kind == "pulse":
			var r := roundf(minf(160.0, _t * 270.0))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(GaleBear.GOLD, 0.8), 3.0)
			draw_arc(Vector2.ZERO, maxf(1.0, r - 7.0), 0.0, TAU, 48, Color(1, 1, 1, 0.55), 1.0)
		else:
			var dir := global_position.direction_to(goal)
			var length := global_position.distance_to(goal)
			var front := minf(length, _t * maxf(180.0, length / maxf((_t + life) * 0.65, 0.1)))
			draw_line(Vector2.ZERO, dir * front, Color(0.45, 0.95, 0.9, 0.12), 32.0)
			for i in 8:
				var p := dir * fmod(_t * 140.0 + i * 55.0, maxf(front, 1.0))
				draw_line(p.round(), (p + dir * 16.0).round(), Color(0.8, 1, 1, 0.6), 1.5)
