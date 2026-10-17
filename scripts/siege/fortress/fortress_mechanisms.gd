class_name FortressMechanisms
extends FortressJobs
## 狂欢要塞的六个机关本身（调度、预约、命中、取消在 FortressJobs）：
##   missiles 猎笑巡航弹、hands 伸缩追猎巨手、rockets 双线火箭运兵、crane 双钩劫塔、convoy 三批交叉车阵、cannon 三连锁定重炮；
## 以及机关在地上 / 空中的绘制（_draw / _draw_ground）。


func _begin(job: Dictionary) -> bool:
	var persons := people()
	match job["kind"]:
		"missiles":
			if persons.is_empty():
				return false
			job["shots"] = []
			job["count"] = 6 if boss.expanded else 4
			job["fired"] = 0
		"hands":
			if not persons.any(func(c): return not boss.director.is_on_wall(c) and SiegeTools.can_move(boss, c)):
				return false
			job["arms"] = []
			for i in 4 if boss.expanded else 2:
				job["arms"].append({"delay": i * 2.8, "side": -1 if i % 2 == 0 else 1, "p": boss.shoulder(-1 if i % 2 == 0 else 1), "phase": "idle", "t": 0.0, "hunt_t": 0.0, "target": null, "hold": null, "hit": false})
			job["life"] = 16.0 if boss.expanded else 10.8
		"rockets":
			var count := _reserve(job, (8 if boss.expanded else 6) * 2, true)
			if count % 2:
				boss.reserved_crew -= 1
				job["reserved"] -= 1
				boss.director.reinforcements.consume(job["ticket"])
				count -= 1
			if count < 2:
				return false
			job["shots"] = []
			var pods := count / 2
			for i in int(pods):
				var wall := i >= int(ceil(pods / 2.0))
				var launch := (0.9 if boss.expanded else 1.6) if wall else 0.0
				var at := Vector2(clampf(boss.global_position.x + (i - int(pods / 2)) * 100, 80, boss.director.map_size().x - 80), boss.director.wall_top_y() + 2) if wall else boss.safe_exterior(boss.global_position + Vector2(-680 if i % 2 == 0 else 680, -100 + i * 35))
				job["shots"].append({"wall": wall, "at": at, "from": boss.global_position + Vector2(-430 if i % 2 == 0 else 430, -170), "launch": launch, "done": false, "locked": false, "index": i})
		"crane":
			var candidates := get_tree().get_nodes_in_group("siege_tower").filter(func(t): return SiegeTools.alive(t) and not t.has_meta("fortress_lift") and FortressRules.distance(boss, t.global_position) < 320)
			candidates.sort_custom(func(a, b): return a.level > b.level if a.level != b.level else (a.health.max_hp > b.health.max_hp if a.health.max_hp != b.health.max_hp else a.get_instance_id() < b.get_instance_id()))
			if candidates.is_empty():
				return false
			job["lifts"] = []
			for i in mini(2 if boss.expanded else 1, candidates.size()):
				var tower: IceTower = candidates[i]
				tower.set_meta("fortress_lift", self)
				var entry := {"tower": weakref(tower), "from": tower.global_position, "layer": tower.collision_layer, "z": tower.z_index, "delay": i * 0.9, "done": false, "rescued": false, "lifted": false}
				job["lifts"].append(entry)
				make_target("cable", tower.global_position + Vector2(0, -24), job, 6, i).visible = false
		"convoy":
			boss.carts = boss.carts.filter(func(r): return SiegeTools.alive(r.get_ref()))
			var count := _reserve(job, mini(12 if boss.expanded else 10, boss.max_carts - boss.carts.size()))
			if count <= 0:
				return false
			job["cars"] = []
			for i in count:
				var batch: int = i / 4 if boss.expanded else (0 if i < 4 else (1 if i < 7 else 2))
				var side := -1 if i % 2 == 0 else 1
				var from := boss.safe_exterior(boss.global_position + Vector2(side * 650, -80 + (i % 4) * 28))
				var to := Vector2(from.x, boss.director.wall_foot_y() + 18)
				if batch == 1 and boss.footprint().position.y - boss.director.wall_foot_y() > 130:
					from = Vector2(boss.global_position.x + side * 630, boss.footprint().position.y - 65)
					to = Vector2(boss.global_position.x - side * 300, boss.director.wall_foot_y() + 18)
				job["cars"].append({"from": from, "to": to, "launch": 1.4 + batch * 1.8, "done": false, "warn": false})
		"cannon":
			job["shots"] = []
			job["progress"] = 0
			job["charged"] = false
			job["count"] = 4 if boss.empowered else 3
			boss.empowered = false
			job["life"] = 4.0 + job["count"] * 1.6 + 1.5
			for i in job["count"]:
				job["shots"].append({"launch": 4.0 + i * 1.6, "at": _cannon_target(i), "from": boss.global_position + Vector2(0, -190), "locked": false, "fired": false, "done": false, "index": i})
			for side in [-1, 1]:
				make_target("core", boss.global_position + Vector2(side * 600, -170), job, 6)
	return true


func _update(job: Dictionary, delta: float) -> void:
	match job["kind"]:
		"missiles":
			_missiles(job, delta)
		"hands":
			_hands(job, delta)
		"rockets":
			_rockets(job)
		"crane":
			_crane(job)
		"convoy":
			_convoy(job)
		"cannon":
			_cannon(job)


func _missiles(job: Dictionary, delta: float) -> void:
	var persons := people()
	while job["fired"] < job["count"] and job["t"] >= job["fired"] * 0.4:
		if persons.is_empty():
			break
		var i: int = job["fired"]
		job["shots"].append(FortressOrdnance.missile(boss.global_position + Vector2(-460 if i % 2 == 0 else 460, -180), persons[i % persons.size()]))
		burst(job["shots"][-1]["p"], 28, "launch")
		job["fired"] += 1
	for shot in job["shots"]:
		FortressOrdnance.tick_missile(self, shot, delta)
	if job["fired"] >= job["count"] and job["shots"].all(func(s): return s["done"]):
		finish(job)


func _hands(job: Dictionary, delta: float) -> void:
	for arm in job["arms"]:
		if job["t"] < arm["delay"]:
			continue
		arm["t"] += delta
		var at := boss.shoulder(arm["side"])
		if arm["phase"] == "idle":
			var candidates := people().filter(func(c): return not boss.director.is_on_wall(c) and SiegeTools.can_move(boss, c) and c.global_position.distance_to(at) <= 560)
			if candidates.is_empty():
				arm["phase"] = "done"
				continue
			candidates.sort_custom(func(a, b): return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
			arm["target"] = weakref(candidates[0])
			arm["phase"] = "extend"
			arm["extension"] = boss.safe_exterior(candidates[0].global_position)
			arm["extension"] = at + (arm["extension"] - at).limit_length(560)
		if arm["phase"] == "extend":
			arm["p"] = at.lerp(arm["extension"], clampf(arm["t"], 0, 1))
			if arm["t"] >= 1:
				arm["phase"] = "hunt"
		if arm["phase"] == "hunt":
			arm["hunt_t"] += delta
			var c: Variant = arm["target"].get_ref()
			if SiegeTools.alive(c):
				var goal := boss.safe_exterior(c.global_position)
				goal = at + (goal - at).limit_length(560)
				arm["p"] = (arm["p"] as Vector2).move_toward(goal, c.move_speed * 0.9 * delta)
			if arm["hunt_t"] >= 1.5:
				arm["phase"] = "lock"
				arm["locked"] = arm["p"]
				arm["lock_t"] = arm["t"]
		elif arm["phase"] == "lock" and arm["t"] - arm["lock_t"] >= 0.7:
			arm["phase"] = "return"
			burst(arm["p"], 60, "hands")
			for c in people():
				if c.global_position.distance_to(arm["p"]) < 60 and SiegeTools.can_move(boss, c) and strike(c, 30, "hands", job):
					var goal := boss.safe_exterior(c.global_position + (at - c.global_position).limit_length(180))
					var hold := SiegeTools.hold(boss, c, goal, false, 1.2)
					if hold:
						hold.set_physics_process(false)
						arm["hold"] = weakref(hold)
						arm["victim"] = weakref(c)
						arm["hold_left"] = 1.2
						boss.protect(c, 2.0)
						arm["phase"] = "drag"
						arm["hit"] = true
					break
		elif arm["phase"] == "drag":
			var hold: Variant = arm["hold"].get_ref()
			var c: Variant = arm["victim"].get_ref()
			if is_instance_valid(hold) and not hold.ended:
				hold._physics_process(delta)
				if SiegeTools.alive(c):
					arm["p"] = c.global_position
			else:
				_release_arm(arm, true)
			arm["hold_left"] -= delta
			if arm["hold_left"] <= 0 or not SiegeTools.alive(c):
				_release_arm(arm, true)
		elif arm["phase"] == "return":
			arm["p"] = (arm["p"] as Vector2).move_toward(at, 360 * delta)
			if (arm["p"] as Vector2).distance_to(at) < 4:
				arm["phase"] = "done"
	if job["arms"].all(func(a): return a["phase"] == "done"):
		finish(job)


func _release_arm(arm: Dictionary, fling: bool) -> void:
	if arm.get("hold") != null:
		var hold: Variant = arm["hold"].get_ref()
		if is_instance_valid(hold):
			hold._end(false)
		var c: Variant = arm.get("victim").get_ref()
		if SiegeTools.alive(c):
			boss.protect(c, 0.8)
			if fling and not c.is_force_moving():
				var dir := boss.global_position.direction_to(c.global_position)
				c.force_move(dir * 200, 0.6, "slide")
	arm["hold"] = null
	arm["phase"] = "return"


func _rockets(job: Dictionary) -> void:
	for shot in job["shots"]:
		if shot["done"]:
			continue
		var t: float = job["t"] - shot["launch"]
		if t < 0:
			continue
		if not shot.get("launched", false):
			shot["launched"] = true
			burst(shot["from"], 36, "launch")
		if t < 0.8 and not shot["wall"]:
			var persons := people()
			if not persons.is_empty():
				var c: PlayableCharacter = persons[shot["index"] % persons.size()]
				shot["at"] = boss.safe_exterior(c.global_position + Vector2(-90 if shot["index"] % 2 == 0 else 90, 35))
		elif not shot["locked"]:
			shot["locked"] = true
		if t >= 2.0:
			shot["done"] = true
			var at: Vector2 = shot["at"]
			explode(at, 48, 18, "rockets")
			var wall := boss.director.segment_at(at.x)
			var on_wall: bool = shot["wall"] and wall != null and wall.climbable()
			if shot["wall"] and not on_wall:
				at.y = boss.director.wall_foot_y() + 28
			var kinds: Array = ["rat", "gecko"] if on_wall else [["shield_crab", "squirrel"], ["hook", "rat"], ["warm_slime", "goblin_engineer"]][shot["index"] % 3]
			boss.land_crew(at, 2, on_wall, job["ticket"], kinds)
			job["reserved"] -= 2
	if job["shots"].all(func(s): return s["done"]):
		finish(job)


func _crane(job: Dictionary) -> void:
	for i in job["lifts"].size():
		var lift: Dictionary = job["lifts"][i]
		if lift["done"]:
			continue
		var tower: Variant = lift["tower"].get_ref()
		var cable := live_target(job, i)
		if not SiegeTools.alive(tower):
			_return_lift(lift, cable)
			continue
		var t: float = job["t"] - lift["delay"]
		var anchor := boss.global_position + Vector2(-360 if i == 0 else 360, -130)
		if t < 1.8:
			if cable:
				cable.global_position = anchor.lerp(lift["from"], clampf((t - 1.2) / 0.6, 0, 1)) + Vector2(0, -24)
			if cable:
				cable.visible = t >= 1.2
			continue
		if not cable:
			_return_lift(lift, null)
			continue
		if not lift["lifted"]:
			burst(tower.global_position, 28, "crane")
		lift["lifted"] = true
		tower.collision_layer = 0
		tower.z_index = 18
		var f := clampf((t - 1.8) / 6, 0, 1)
		tower.global_position = (lift["from"] as Vector2).lerp(anchor, f) + Vector2(0, -sin(f * PI) * 65)
		cable.global_position = tower.global_position + Vector2(0, -24)
		if f >= 1:
			lift["done"] = true
			boss.empowered = true
			burst(tower.global_position, 45, "crane")
			tower.collapse(true)
			cable.close()
			GameState.notify(boss.notice("tower_dismantled"))
	if job["lifts"].all(func(l): return l["done"]):
		finish(job)


func _return_lift(lift: Dictionary, cable: FortressTarget) -> void:
	if lift["done"]:
		return
	lift["done"] = true
	lift["rescued"] = true
	var tower: Variant = lift["tower"].get_ref()
	if is_instance_valid(tower) and not tower.is_queued_for_deletion():
		if lift["lifted"]:
			burst(tower.global_position, 34, "rescue")
		tower.global_position = lift["from"]
		tower.collision_layer = lift["layer"]
		tower.z_index = lift["z"]
		tower.remove_meta("fortress_lift")
	if is_instance_valid(cable):
		cable.close()


func _convoy(job: Dictionary) -> void:
	for car in job["cars"]:
		if car["done"]:
			continue
		if job["t"] >= car["launch"] - 1.4:
			car["warn"] = true
		if job["t"] >= car["launch"]:
			car["done"] = true
			var m := boss.director.spawn("cart", "", car["from"], job["ticket"]) as SiegeCart
			if m:
				m.configure_fortress(self, car["to"], boss.expanded)
				boss.carts.append(weakref(m))
				burst(car["from"], 24, "launch")
	if job["cars"].all(func(c): return c["done"]):
		finish(job)


func _cannon_target(index: int) -> Vector2:
	var persons := people()
	if not persons.is_empty():
		if index >= 2:
			persons.sort_custom(func(a, b): return a.laugh.value / a.laugh.max_value > b.laugh.value / b.laugh.max_value)
		return persons[index % persons.size()].global_position if index < 2 else persons[0].global_position
	var towers := get_tree().get_nodes_in_group("siege_tower").filter(func(t): return SiegeTools.alive(t))
	if not towers.is_empty():
		return towers[0].global_position
	return Vector2(boss.global_position.x, boss.director.wall_top_y())


func _cannon(job: Dictionary) -> void:
	for i in job["objects"].size():
		var target := live_target(job, i)
		if target:
			target.global_position = boss.global_position + Vector2(-600 if i == 0 else 600, -170)
	if job["t"] >= 4 and not job["charged"]:
		job["charged"] = true
		for i in job["objects"].size():
			var core := live_target(job, i)
			if core:
				core.close()
	for shot in job["shots"]:
		if shot["done"]:
			continue
		var until: float = shot["launch"] - job["t"]
		if until > 1.5:
			continue
		if until > 0.8:
			shot["at"] = _cannon_target(shot["index"])
		else:
			shot["locked"] = true
		if until <= 0 and not shot["fired"]:
			shot["fired"] = true
			shot["from"] = boss.global_position + Vector2(0, -190)
			burst(shot["from"], 64, "launch")
			Audio.play("cart_rumble", -3)
		if until <= -0.8:
			shot["done"] = true
			var at: Vector2 = shot["at"]
			var radius := 88.0 if boss.expanded else 72.0
			explode(at, radius, 30 if boss.expanded else 26, "cannon")
			if at.y <= boss.director.wall_foot_y() + radius:
				boss.director.damage_wall(boss.director.segment_at(at.x), 120)
			for tower in get_tree().get_nodes_in_group("siege_tower"):
				if SiegeTools.alive(tower) and tower.global_position.distance_to(at) <= radius:
					tower.raid_hit(int(ceil(tower.health.max_hp * 0.35)), boss)
	if not job["shots"].is_empty() and job["shots"].all(func(s): return s["done"]):
		boss._stun_left = maxf(boss._stun_left, 2)
		finish(job)


func _draw() -> void:
	if not valid():
		return
	for job in jobs:
		match job["kind"]:
			"missiles":
				for shot in job["shots"]:
					if shot["done"]:
						continue
					var trail: Array = shot["trail"]
					for i in range(1, trail.size()):
						draw_line(to_local(trail[i - 1]), to_local(trail[i]), Color(1, 0.5, 0.25, float(i) / trail.size()), 3)
					if shot["state"] != "lock":
						_exhaust(shot["p"], Vector2.from_angle(shot["angle"]), shot["t"])
					_sprite("missile", shot["p"], shot["angle"] + PI / 2)
					if shot["state"] == "lock":
						draw_line(to_local(shot["p"]), to_local(shot["p"] + Vector2.from_angle(shot["angle"]) * 180), Color(1, 0.9, 0.3), 3)
			"hands":
				for arm in job["arms"]:
					if arm["phase"] in ["idle", "done"]:
						continue
					var from := boss.shoulder(arm["side"])
					draw_line(to_local(from), to_local(arm["p"]), Color(0.13, 0.12, 0.18), 20)
					draw_line(to_local(from), to_local(arm["p"]), boss.GOLD, 8)
					_sprite("hand_closed" if arm["hit"] else "hand", arm["p"], from.angle_to_point(arm["p"]) + PI / 2, 1.2 if arm["phase"] == "lock" else 1.0)
					if arm["phase"] == "lock":
						_warning(arm["p"], 20, "合拢", Color(1, 0.55, 0.8))
			"rockets":
				for shot in job["shots"]:
					var t: float = job["t"] - shot["launch"]
					if t < 0 or shot["done"]:
						continue
					pass  # landing geometry is rendered below actors
					_flight(shot, t, "pod", 2, 180)
			"crane":
				for i in job["lifts"].size():
					var lift: Dictionary = job["lifts"][i]
					if lift["done"]:
						continue
					var t: float = job["t"] - lift["delay"]
					if t < 0:
						continue
					var anchor := boss.global_position + Vector2(-360 if i == 0 else 360, -130)
					var cable := live_target(job, i)
					if t < 1.2:
						pass
					elif cable:
						draw_line(to_local(anchor), to_local(cable.global_position), Color(1, 0.8, 0.4), 3)
			"cannon":
				if job["t"] < 4:
					_warning(boss.global_position + Vector2(0, -190), 50 + job["t"] * 8, "蓄力 %d 连 · 攻击核心" % job["count"], boss.GOLD)
					for i in 8:
						var a: float = job["t"] * 4 + i * TAU / 8
						var r: float = 90 - fmod(job["t"] * 45 + i * 11, 65)
						var at := to_local(boss.global_position + Vector2(0, -190)) + Vector2.from_angle(a) * r
						draw_line(at, at - Vector2.from_angle(a) * 12, Color(1, 0.85, 0.35, 0.85), 4)
				for shot in job["shots"]:
					if shot["done"] or job["t"] < shot["launch"] - 1.5:
						continue
					pass  # ground reticle
					if shot["fired"]:
						_flight(shot, job["t"] - shot["launch"], "shell", 0.8, 140)


func _floor_circle(at: Vector2, radius: float, label: String, col: Color) -> void:
	ground.draw_circle(at, radius, Color(col, 0.16))
	ground.draw_arc(at, radius, 0, TAU, 40, col, 3)
	ground.draw_line(at - Vector2(14, 0), at + Vector2(14, 0), col, 2)
	ground.draw_line(at - Vector2(0, 14), at + Vector2(0, 14), col, 2)
	ground.draw_string_outline(ThemeDB.fallback_font, at + Vector2(-30, -radius - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
	ground.draw_string(ThemeDB.fallback_font, at + Vector2(-30, -radius - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


func _draw_ground() -> void:
	if not valid():
		return
	for job in jobs:
		match job["kind"]:
			"hands":
				for arm in job["arms"]:
					if arm["phase"] in ["hunt", "lock"]:
						_floor_circle(arm["p"], 60, "巨手合拢" if arm["phase"] == "lock" else "追猎", Color(1, 0.5, 0.8))
			"rockets":
				for shot in job["shots"]:
					if not shot["done"] and job["t"] >= shot["launch"]:
						_floor_circle(shot["at"], 48, "墙顶空降" if shot["wall"] else "侧翼空降", Color(0.5, 0.9, 1))
			"crane":
				for lift in job["lifts"]:
					if not lift["done"] and job["t"] >= lift["delay"]:
						_floor_circle(lift["from"], 28, "吊塔", Color(0.5, 0.9, 1))
			"convoy":
				for car in job["cars"]:
					if car["warn"] and not car["done"]:
						ground.draw_line(car["from"], car["to"], Color(1, 0.4, 0.25, 0.25), 44)
						ground.draw_line(car["from"], car["to"], Color(1, 0.8, 0.4), 3)
						var to: Vector2 = car["to"]
						var dir: Vector2 = (car["to"] - car["from"]).normalized()
						ground.draw_line(to, to - dir.rotated(0.5) * 30, Color(1, 0.8, 0.4), 4)
						ground.draw_line(to, to - dir.rotated(-0.5) * 30, Color(1, 0.8, 0.4), 4)
			"cannon":
				for shot in job["shots"]:
					if not shot["done"] and job["t"] >= shot["launch"] - 1.5:
						_floor_circle(shot["at"], 88 if boss.expanded else 72, "重炮 %d/%d" % [shot["index"] + 1, job["count"]], Color(1, 0.35, 0.25))
