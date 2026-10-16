class_name FortressOrdnance
extends RefCounted
## Guided flight is independent of the instant-turn shared tower projectile.
static func missile(from: Vector2, victim: PlayableCharacter) -> Dictionary:
	return {"p":from,"previous":from,"target":weakref(victim),"speed":victim.move_speed,"angle":from.angle_to_point(victim.global_position),"t":0.0,"done":false,"state":"hunt","trail":[]}

static func tick_missile(manager: FortressMechanisms, shot: Dictionary, delta: float) -> void:
	if shot["done"]: return
	var before := float(shot["t"])
	shot["t"] += delta
	var victim: Variant = shot["target"].get_ref()
	if shot["t"]<2 and SiegeTools.alive(victim):
		var wanted: float = (shot["p"] as Vector2).angle_to_point(victim.global_position)
		shot["angle"] = float(shot["angle"])+clampf(angle_difference(shot["angle"],wanted),-PI*0.5*delta,PI*0.5*delta)
	elif shot["t"]<2.6:
		shot["state"] = "lock"
	else: shot["state"] = "dash"
	if not SiegeTools.alive(victim) and shot["state"]=="hunt": shot["state"]="dash"
	var speed: float = shot["speed"]*(2.2 if shot["state"]=="dash" else (0.0 if shot["state"]=="lock" else 0.85))
	shot["previous"] = shot["p"]
	shot["p"] += Vector2.from_angle(shot["angle"])*speed*delta
	var trail: Array = shot["trail"]
	trail.append(shot["p"])
	if trail.size()>12: trail.pop_front()
	var ray := PhysicsRayQueryParameters2D.create(shot["previous"],shot["p"],1)
	ray.exclude = [manager.boss._blocker.get_rid()]
	var blocked := not manager.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	var touched := false
	for c in manager.people():
		var nearest := Geometry2D.get_closest_point_to_segment(c.global_position,shot["previous"],shot["p"])
		if c.global_position.distance_to(nearest)<15:
			touched = true
	if touched or blocked:
		manager.explode(shot["p"],48,22,"missiles",120)
		shot["done"] = true
	elif shot["t"]>=3.4 or before>5:
		manager.burst(shot["p"],20,"missiles")
		shot["done"] = true
