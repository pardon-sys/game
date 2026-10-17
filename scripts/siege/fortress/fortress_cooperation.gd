class_name FortressCooperation
extends Node2D
## 第 12 波狂欢要塞上的船员协作（不走 data/teamwork.json）：不生成兵员、用原来的配额，冷却是实际秒数，0.25 秒前摇。
## 六种协作的名字 / 冷却在 data/siege/bosses.json 的 carnival_fortress.cooperation
static var CDS: Dictionary:
	get:
		var out := {}
		for k in _coop():
			out[k] = float(_coop()[k]["cd"])
		return out
static var NAMES: Dictionary:
	get:
		var out := {}
		for k in _coop():
			out[k] = str(_coop()[k]["name"])
		return out
var manager: FortressMechanisms
var cds := {}
var jobs: Array[Dictionary] = []
var counts := {}
var enabled := true


static func _coop() -> Dictionary:
	return SiegeBoss.boss_data().get("carnival_fortress", {}).get("cooperation", {})


func _ready() -> void:
	for key in CDS:
		cds[key] = float(CDS[key])
	add_to_group("siege_temp")


func tick(delta: float) -> void:
	if not manager.valid() or SiegeTools.paused():
		return
	for job in jobs.duplicate():
		if not job["members"].all(func(m): return SiegeTools.valid_source(m)):
			finish(job)
			continue
		job["t"] += delta
		if job["t"] < 0.25:
			continue
		if not job["started"]:
			_activate(job)
		if not jobs.has(job):
			continue
		_update(job, delta)
		if job["t"] >= job["life"]:
			finish(job)
	if not enabled:
		return
	for key in cds:
		cds[key] = maxf(0, float(cds[key]) - delta)
		if cds[key] <= 0:
			cds[key] = float(CDS[key]) if start(key) else 0.25
	queue_redraw()


func _members(key: String) -> Array:
	return manager.nearby(key, 30).filter(func(m): return not m.has_meta("fortress_coop"))


func start(kind: String) -> bool:
	if not manager.valid() or manager.boss.director.wave < 12 or jobs.any(func(j): return j["kind"] == kind):
		return false
	var boss := manager.boss
	var group: Array = []
	var job := {"kind": kind, "t": 0.0, "life": 6.25, "started": false, "saved": [], "controls": [], "repair": 0.0, "healed": 0}
	match kind:
		"escort":
			var carts := _members("cart").filter(func(c): return c.get_meta("fortress_cart", 0) == boss.get_instance_id())
			var crabs := _members("shield_crab")
			if carts.is_empty() or crabs.size() < 2:
				return false
			group = [carts[0], crabs[0], crabs[1]]
		"repair":
			var engineers := _members("goblin_engineer")
			if not manager.jobs.any(func(j): return j["kind"] == "cannon" and j["t"] < 4):
				return false
			if engineers.size() < 2 or boss.healed_total >= 336 or boss.health.hp >= boss.health.max_hp:
				return false
			group = engineers.slice(0, 2)
		"airlift":
			var bats := _members("bat_swarm")
			var crew := boss.crew.map(func(r): return r.get_ref()).filter(func(m): return SiegeTools.valid_source(m) and m.get_meta("rocket_landed", false) and not m.get_meta("airlifted", false) and not m.has_meta("fortress_coop") and m.is_physics_processing())
			if bats.is_empty() or crew.is_empty():
				return false
			group = [bats[0], crew[0]]
			job["life"] = 1.65
		"hook":
			var hooks := _members("hook")
			var zone: Variant = manager.active_grab_zone()
			var chars := manager.people().filter(func(c): return SiegeTools.can_move(boss, c) and not boss.protected(c))
			if hooks.is_empty() or zone == null or chars.is_empty():
				return false
			chars.sort_custom(func(a, b): return a.global_position.distance_squared_to(hooks[0].global_position) < b.global_position.distance_squared_to(hooks[0].global_position))
			group = [hooks[0]]
			job["victim"] = weakref(chars[0])
			job["zone"] = zone
			job["life"] = 4.0
			job["fired"] = false
			job["hit"] = false
		"warm":
			var carts := _members("cart").filter(func(c): return c.get_meta("fortress_cart", 0) == boss.get_instance_id())
			var slimes := _members("warm_slime")
			if carts.is_empty() or slimes.is_empty():
				return false
			group = [carts[0], slimes[0]]
		"resonance":
			# 活梯子等可攻击机关也在这个组，先确认是塔再读取kind。
			var towers := get_tree().get_nodes_in_group("siege_enemy_tower").filter(func(t): return is_instance_valid(t) and t is EnemyTower and SiegeTools.valid_source(t) and t.kind == "resonance" and FortressRules.distance(boss, t.global_position) < 360)
			var carts := _members("cart").filter(func(c): return c.get_meta("fortress_cart", 0) == boss.get_instance_id())
			if towers.is_empty() or carts.is_empty():
				return false
			group = [towers[0]] + carts.slice(0, 4)
			job["life"] = 4.25
		_:
			return false
	job["members"] = group
	for m in group:
		m.set_meta("fortress_coop", self)
	jobs.append(job)
	SpeechBubble.say(group[0], NAMES[kind], 80, 0.8)
	return true


func _save(job: Dictionary, m: Monster, controlled := false) -> void:
	job["saved"].append({"ref": weakref(m), "physics": m.is_physics_processing(), "from": m.global_position, "mask": m.collision_mask, "escort": m.get_meta("escort_of") if m.has_meta("escort_of") else null, "off": m.get_meta("escort_off", Vector2.ZERO), "controlled": controlled})
	if controlled:
		m.set_physics_process(false)
		m.set_meta("team_transfer", true)


func _activate(job: Dictionary) -> void:
	job["started"] = true
	counts[job["kind"]] = int(counts.get(job["kind"], 0)) + 1
	var group: Array = job["members"]
	var boss := manager.boss
	match job["kind"]:
		"escort":
			job["old_guards"] = group[0].get_meta("escorts", [])
			for i in [1, 2]:
				_save(job, group[i])
				group[i].set_meta("escort_of", group[0])
				group[i].set_meta("escort_off", Vector2((i * 2 - 3) * 20, -20))
			group[0].set_meta("escorts", group.slice(1))
		"repair":
			for m in group:
				_save(job, m, true)
				if m is GoblinEngineer and is_instance_valid(m.site):
					m.site.unregister_builder(m)
		"airlift":
			_save(job, group[1], true)
			group[1].set_meta("airborne", true)
			job["from"] = group[1].global_position
			var wall := boss.director.segment_at(group[1].global_position.x)
			job["on_wall"] = wall != null and wall.climbable()
			job["to"] = Vector2(group[1].global_position.x, boss.director.wall_top_y() + 4 if job["on_wall"] else boss.director.wall_foot_y() + 28)
		"hook":
			_save(job, group[0], true)
			job["p"] = group[0].global_position + Vector2(0, -10)
			job["from"] = job["p"]
		"warm":
			_save(job, group[1], true)
		"resonance":
			for m in group.slice(1):
				m.set_meta("fortress_speed_source", weakref(group[0]))


func _update(job: Dictionary, delta: float) -> void:
	var group: Array = job["members"]
	var boss := manager.boss
	for entry in job["saved"]:
		if entry["controlled"] and is_instance_valid(entry["ref"].get_ref()):
			entry["ref"].get_ref().tick_timers(delta)
	match job["kind"]:
		"repair":
			if not manager.jobs.any(func(j): return j["kind"] == "cannon" and j["t"] < 4):
				finish(job)
				return
			var close := true
			for i in 2:
				var m: Monster = group[i]
				var goal := boss.global_position + Vector2((i * 2 - 1) * 620, 14)
				m.move_and_collide((goal - m.global_position).limit_length(55 * delta))
				close = close and m.global_position.distance_to(goal) < 25
			job["repair"] = job["repair"] + delta if close else 0.0
			if job["repair"] >= 3 and job["healed"] < 84:
				job["repair"] = 0.0
				job["healed"] += boss.heal_from_engineers(mini(42, 84 - job["healed"]))
				Fx.burst(boss.get_parent(), boss.global_position, "spark", 8, 60, 0.5, Vector2.ZERO, boss.GOLD)
		"airlift":
			var f := clampf((job["t"] - 0.25) / 1.4, 0, 1)
			group[1].global_position = (job["from"] as Vector2).lerp(job["to"], f) + Vector2(0, -sin(f * PI) * 70)
			if f >= 1:
				group[1].set_meta("airlifted", true)
				job["landed"] = true
				if job["on_wall"]:
					TeamworkEffects.put_on_wall(group[1], job["to"])
		"hook":
			var victim: Variant = job["victim"].get_ref()
			if job["zone"]["job"]["ended"] or job["zone"]["arm"]["phase"] not in ["hunt", "lock"] or not SiegeTools.alive(victim):
				finish(job)
				return
			if job["t"] < 0.6 or job["hit"]:
				return
			if not job["fired"]:
				job["fired"] = true
				job["goal"] = victim.global_position
			var previous: Vector2 = job["p"]
			job["p"] = (job["p"] as Vector2).move_toward(job["goal"], 220 * delta)
			var ray := PhysicsRayQueryParameters2D.create(previous, job["p"], 1)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				finish(job)
				return
			if victim.global_position.distance_to(Geometry2D.get_closest_point_to_segment(victim.global_position, previous, job["p"])) < 16 and SiegeTools.can_move(boss, victim) and not boss.protected(victim):
				var desired: Vector2 = job["zone"]["arm"]["p"]
				var goal := boss.safe_exterior(victim.global_position + (desired - victim.global_position).limit_length(180))
				var control := SiegeTools.move(group[0], [victim], [goal])
				if control:
					control.duration = 0.8
					job["controls"].append(weakref(control))
				job["hit"] = true
			elif (job["p"] as Vector2).distance_to(job["goal"]) < 2:
				finish(job)
		"warm":
			var slime: Monster = group[1]
			var candidates := get_tree().get_nodes_in_group("siege_tower").filter(func(t): return SiegeTools.alive(t) and not t.has_meta("fortress_lift") and absf(t.global_position.x - group[0].global_position.x) < 70 and t.global_position.distance_to(group[0].global_position) < 220)
			var goal: Vector2 = group[0].global_position + Vector2(24, 25)
			if not candidates.is_empty():
				goal = candidates[0].global_position
				if slime.global_position.distance_to(goal) < 24:
					candidates[0].melt(WarmSlime.MELT * delta)
			slime.move_and_collide((goal - slime.global_position).limit_length(70 * delta))


func finish(job: Dictionary) -> void:
	if not jobs.has(job):
		return
	jobs.erase(job)
	for control in job["controls"]:
		if is_instance_valid(control.get_ref()):
			control.get_ref()._end(false)
	for entry in job["saved"]:
		var m := entry["ref"].get_ref() as Monster
		if not is_instance_valid(m):
			continue
		if entry["controlled"]:
			m.set_physics_process(entry["physics"])
			m.set_meta("team_transfer", false)
			m.set_meta("airborne", false)
			if job["kind"] == "airlift" and not job.get("landed", false):
				m.global_position = entry["from"]
				m.collision_mask = entry["mask"]
		if is_instance_valid(entry["escort"]):
			m.set_meta("escort_of", entry["escort"])
			m.set_meta("escort_off", entry["off"])
		else:
			m.remove_meta("escort_of")
	for m in job["members"]:
		if not is_instance_valid(m):
			continue
		if (m.get_meta("fortress_coop") if m.has_meta("fortress_coop") else null) == self:
			m.remove_meta("fortress_coop")
		if job["kind"] == "resonance":
			m.remove_meta("fortress_speed_source")
	if job["kind"] == "escort" and is_instance_valid(job["members"][0]):
		job["members"][0].set_meta("escorts", job.get("old_guards", []))


func cancel_all() -> void:
	for job in jobs.duplicate():
		finish(job)


func _exit_tree() -> void:
	cancel_all()


func _draw() -> void:
	for job in jobs:
		var group: Array = job["members"]
		if not group.all(func(m): return is_instance_valid(m)):
			continue
		if job["kind"] == "hook" and job["started"]:
			var end: Vector2 = job["p"] if job["fired"] else (job["victim"].get_ref().global_position if SiegeTools.alive(job["victim"].get_ref()) else job["p"])
			draw_line(to_local(group[0].global_position), to_local(end), Color(1, 0.7, 0.4), 3 if job["fired"] else 1)
			if job["fired"]:
				draw_circle(to_local(end), 6, Color(1, 0.85, 0.5))
		for m in group.slice(1):
			draw_line(to_local(group[0].global_position), to_local(m.global_position), Color(1, 0.8, 0.3, 0.65), 1.5)
