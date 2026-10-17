class_name SiegeCooperation
extends RefCounted
## 攻防战的十种「怪物 + 敌塔」联合配合（data/teamwork.json 里 effect.joint 的，数据来自 tools/build/siege_cooperation_data.py）：
## 只负责效果（perform 返回一个 JointAction 场地），成员匹配 / 冷却 / 前摇仍由 MonsterTeamwork 管理（can_start 是注入给它的条件）。

const LIFE := {"hook_haunt": 1.6, "bubble_roll": 1.6, "shield_melt": 6.0, "magic_recoil": 1.8,
	"twin_relay": 1.6, "glue_roll": 2.0, "wind_transport": 1.2, "drop_hook": 1.4, "web_battery": 2.0, "bell_repair": 1.8}


static func repair_target(bell: Actor) -> EnemyTower:
	var best: EnemyTower
	var fraction := 1.0
	for n in bell.get_tree().get_nodes_in_group("siege_enemy_tower"):
		if not SiegeTools.alive(n) or n.health == null or n.global_position.distance_to(bell.global_position) > 260.0:
			continue
		var ratio: float = float(n.health.hp) / n.health.max_hp
		if ratio < fraction:
			fraction = ratio
			best = n
	return best


static func melt_target(leader: Actor) -> IceTower:
	var best: IceTower
	var distance := WarmSlime.SEEK
	for n in leader.get_tree().get_nodes_in_group("siege_tower"):
		if not SiegeTools.alive(n):
			continue
		var gap: float = leader.global_position.distance_to(n.global_position)
		if gap < distance:
			distance = gap
			best = n
	return best


static func can_start(team: Dictionary, group: Array) -> bool:
	var kind := str(team["effect"]["type"])
	if kind == "bell_repair":
		return repair_target(group[0]) != null
	if kind == "shield_melt":
		return melt_target(group[0]) != null
	if kind == "twin_relay":
		return group[0] is TwinGhost and group[1] == group[0].twin and group[0].global_position.distance_to(group[1].global_position) <= TwinGhost.MAX_DISTANCE
	return true


static func perform(team: Dictionary, group: Array, target: PlayableCharacter) -> JointAction:
	var kind := str(team["effect"]["type"])
	if not can_start(team, group) or (not kind in ["bell_repair", "shield_melt"] and not SiegeTools.alive(target)):
		return null
	var job := JointAction.new()
	job.kind = kind
	job.color = Color(str(team["color"]))
	job.members = group.map(func(m): return weakref(m))
	job.target_ref = weakref(target) if is_instance_valid(target) else null
	job.life = float(LIFE[kind])
	group[0].get_parent().add_child(job)
	job.global_position = group[0].global_position
	if group[0] is EnemyTower:
		group[0].register_tools(job)
	return job


class JointAction extends Node2D:
	var kind := ""
	var color := Color.WHITE
	var members: Array = []
	var target_ref: WeakRef
	var life := 1.6
	var t := 0.0
	var active := false
	var ended := false
	var successful := false
	var tick := 0
	var next_hit := 0.0
	var entries: Array[Dictionary] = []
	var controls: Array[WeakRef] = []
	var flights: Array[Tween] = []
	var flight_done: Array[bool] = []
	var destination := Vector2.ZERO
	var repair_ref: WeakRef
	var origin := Vector2.ZERO

	func _ready() -> void:
		add_to_group("siege_temp")
		add_to_group("siege_cooperation")
		z_index = 16
		_start.call_deferred()

	func sources_alive() -> bool:
		return not ended and members.all(func(ref): return SiegeTools.valid_source(ref.get_ref()))

	func _group() -> Array:
		return members.map(func(ref): return ref.get_ref()) if sources_alive() else []

	func _target() -> PlayableCharacter:
		return target_ref.get_ref() as PlayableCharacter if target_ref else null

	func _capture(m: Monster) -> void:
		if entries.any(func(e): return e["actor"].get_ref() == m):
			return
		entries.append({"actor": weakref(m), "physics": m.is_physics_processing(), "mask": m.collision_mask,
			"from": m.global_position, "escort": m.get_meta("escort_of") if m.has_meta("escort_of") else null, "offset": m.get_meta("escort_off", Vector2.ZERO), "moving": false, "buff": false, "wall": m.get_meta("siege_on_wall", false), "on_wall": m.on_wall if m is SiegeMonster else false, "escorts": m.get_meta("escorts", [])})

	func _move_actor(m: Monster, to: Vector2, time := 0.45, height := 20.0) -> void:
		_capture(m)
		for e in entries:
			if e["actor"].get_ref() == m:
				e["moving"] = true
		m.remove_meta("escort_of")
		m.set_meta("team_transfer", true)
		m.set_meta("airborne", true)
		var entry := entries.filter(func(e): return e["actor"].get_ref() == m)[0] as Dictionary
		var physics: bool = entry["physics"]
		var index := flights.size()
		flight_done.append(false)
		var completed := flight_done
		var ref: WeakRef = weakref(m)
		flights.append(TeamworkEffects._arc(m, to, time, height, func():
			completed[index] = true
			var actor := ref.get_ref() as Monster
			if SiegeTools.alive(actor):
				actor.set_physics_process(physics)
				actor.set_meta("team_transfer", false)
				actor.set_meta("airborne", false)))


	func _hold(c: PlayableCharacter, source: Actor, lifted: bool, duration: float) -> bool:
		var hold := SiegeTools.hold(source, c, c.global_position, lifted, duration)
		if hold == null:
			return false
		controls.append(weakref(hold))
		return true

	func _start() -> void:
		var group := _group()
		var c := _target()
		if group.is_empty() or SiegeDirector.current == null or not SiegeCooperation.can_start({"effect": {"type": kind}}, group):
			_end()
			return
		var lead: Actor = group[0]
		origin = lead.global_position
		if not kind in ["shield_melt", "bell_repair"] and not SiegeTools.alive(c):
			_end()
			return
		destination = c.global_position if SiegeTools.alive(c) else origin
		match kind:
			"hook_haunt":
				var goal := c.global_position + c.global_position.direction_to((group[1].global_position + group[2].global_position) / 2.0) * 96.0
				var drag := SiegeTools.move(lead, [c], [goal])
				if drag == null:
					_end()
					return
				controls.append(weakref(drag))
				destination = goal
				for i in range(1, 3):
					_move_actor(group[i], goal + Vector2((i * 2 - 3) * 24, 0))
				next_hit = 0.65
			"bubble_roll":
				if not _hold(c, lead, true, life):
					_end()
					return
				for m in group.slice(2):
					_capture(m)
					m.set_physics_process(false)
				Audio.play("bubble", -4.0)
				SiegeFx.ring(get_parent(), destination + Vector2(0, -10), 24.0, color, life, 0.3)
			"shield_melt":
				var tower := SiegeCooperation.melt_target(lead)
				destination = tower.global_position
				for m in group:
					_capture(m)
					if not m.has_buff("siege_frenzy"):
						m.add_buff("siege_frenzy", life)
						entries.back()["buff"] = true
				TeamworkEffects._escort(lead, group.slice(1), Vector2(0, -18))
			"magic_recoil":
				for i in range(1, 3):
					_capture(group[i])
					SiegeFx.beam(get_parent(), origin + Vector2(0, -16), group[i].global_position, color, 0.3)
					_move_actor(group[i], destination + Vector2((i * 2 - 3) * 18, 0), 0.45, 12)
				next_hit = 0.45
				Audio.play("roll", -4.0)
			"twin_relay":
				for i in range(2, 4):
					_move_actor(group[i], destination + Vector2((i * 2 - 5) * 24, 0))
				next_hit = 0.3
			"glue_roll":
				if not lead.command_fire({"owner": weakref(self), "focus": weakref(c), "at": destination}):
					_end()
					return
				for i in range(1, 3):
					_move_actor(group[i], destination + Vector2((i * 2 - 3) * 28, 0), 0.7)
				next_hit = 0.75
			"wind_transport":
				_move_actor(group[1], destination + Vector2(0, -28), 0.45, 70)
				if not lead.command_fire({"owner": weakref(self), "focus": weakref(c)}):
					_end()
					return
				for i in range(2, 4):
					var at := destination + Vector2((i * 2 - 5) * 20, 0)
					var d := SiegeDirector.current
					if d.is_on_wall(c) and (d.segment_at(at.x) == null or not d.segment_at(at.x).climbable()):
						at.y = d.wall_foot_y() + 28
					_move_actor(group[i], at, 0.45, 70)
				next_hit = 0.5
			"drop_hook":
				destination = SiegeDirector.current.clamp_in_map(c.global_position + c.global_position.direction_to(origin) * 72, 24, SiegeDirector.current.is_on_wall(c))
				var move := SiegeTools.move(group[1], [c], [destination])
				if move == null:
					_end()
					return
				controls.append(weakref(move))
				if not lead.command_fire({"owner": weakref(self), "focus": weakref(c), "at": destination}):
					_end()
					return
				SiegeFx.warn(get_parent(), destination, "shadow", 32.0, 0.6, color, 0, 1.2, true)
			"web_battery":
				if not _hold(c, lead, false, 1.2):
					_end()
					return
				if not lead.command_fire({"owner": weakref(self), "focus": weakref(c)}):
					_end()
					return
				for m in group.slice(1):
					m.rally_to(c)
				Fx.burst(get_parent(), destination, "thread", 16, 40, 0.7, Vector2.ZERO, color)
			"bell_repair":
				var repair := SiegeCooperation.repair_target(lead)
				repair_ref = weakref(repair)
				destination = repair.global_position
				_capture(group[1])
				_move_actor(group[1], destination + Vector2(22, 12), 0.3)
				next_hit = 0.3
		active = true
		SiegeTeamEffects.say(c, kind)
		Fx.burst(get_parent(), origin + Vector2(0, -12), "spark", 10, 45, 0.45, Vector2.ZERO, color)
		Audio.play("chime", -8.0)

	func _process(delta: float) -> void:
		if ended:
			return
		var d := SiegeDirector.current
		var group := _group()
		if d == null or d.state != "fight" or group.is_empty():
			_end()
			return
		if SiegeTools.paused():
			for i in flights.size():
				if not flight_done[i] and flights[i].is_valid():
					flights[i].pause()
			return
		if not active:
			return
		for i in flights.size():
			if not flight_done[i] and flights[i].is_valid() and not flights[i].is_running():
				flights[i].play()
		for e in entries:
			var m := e["actor"].get_ref() as Monster
			if SiegeTools.alive(m) and not m.is_physics_processing():
				m.tick_timers(delta)
		t += delta
		var c := _target()
		if not kind in ["shield_melt", "bell_repair"] and not SiegeTools.alive(c):
			_end()
			return
		if kind == "bubble_roll":
			for i in range(2, 4):
				group[i].global_position = destination + Vector2.from_angle(t * 8.0 + i * PI) * 28
		if kind == "bell_repair" and not SiegeTools.alive(repair_ref.get_ref()):
			_end()
			return
		if t >= next_hit:
			_pulse(group, c)
		queue_redraw()
		if t >= life:
			if kind == "bell_repair":
				var repaired := repair_ref.get_ref() as EnemyTower
				repaired.health.heal(maxi(1, int(round(repaired.health.max_hp * 0.15))))
				SiegeFx.ring(get_parent(), repaired.global_position, 28, color, 0.4)
			successful = true
			_end()

	func _pulse(group: Array, c: PlayableCharacter) -> void:
		next_hit += 0.3 if kind == "hook_haunt" else 0.4
		tick += 1
		if tick > 4 and not kind in ["bell_repair", "shield_melt"]:
			return
		match kind:
			"hook_haunt", "bubble_roll", "magic_recoil", "twin_relay", "glue_roll", "wind_transport":
				var first := 2 if kind in ["bubble_roll", "twin_relay", "wind_transport"] else 1
				var m: Monster = group[first + (tick - 1) % 2]
				if m.global_position.distance_to(c.global_position) < 72.0:
					SiegeTools.strike(m, c, 4.0, tick - 1, kind)
				if kind == "magic_recoil" and tick == 1:
					for i in range(1, 3):
						_move_actor(group[i], destination + Vector2((3 - i * 2) * 18, 0), 0.45, 22)
				if kind == "wind_transport" and tick == 1:
					for m2 in group.slice(2):
						if SiegeDirector.current.is_on_wall(m2):
							TeamworkEffects.put_on_wall(m2, m2.global_position)
						m2.rally_to(c)
				Fx.burst(get_parent(), destination, "bristle", 5, 35, 0.3, Vector2.ZERO, color)
			"bell_repair":
				var repaired := repair_ref.get_ref() as EnemyTower
				Fx.burst(get_parent(), repaired.global_position + Vector2(0, -12), "chip", 5, 30, 0.4, Vector2(0, -12), color)
				Audio.play("break", -14.0)
			"shield_melt":
				Fx.burst(get_parent(), group[0].global_position, "drop", 4, 25, 0.4, Vector2(0, -20), color)
			_:
				pass

	func _draw() -> void:
		if not active or ended:
			return
		var group := _group()
		if group.is_empty():
			return
		for m in group.slice(1):
			draw_line(to_local(group[0].global_position + Vector2(0, -12)), to_local(m.global_position + Vector2(0, -12)), Color(color, 0.6), 1.5)
		if kind == "bell_repair":
			var at := to_local(destination + Vector2(0, -38))
			draw_rect(Rect2(at - Vector2(20, 0), Vector2(40, 4)), Color(0.12, 0.05, 0.15))
			draw_rect(Rect2(at - Vector2(20, 0), Vector2(40 * clampf((t - 0.3) / 1.5, 0, 1), 4)), color)
		elif kind in ["wind_transport", "magic_recoil"]:
			SiegeFx.draw_tornado(self, to_local(destination), 18, t, color)
		elif kind == "twin_relay":
			draw_line(to_local(group[0].global_position), to_local(group[1].global_position), Color(color, 0.7 + sin(t * 20) * 0.2), 2)
		else:
			draw_arc(to_local(destination), 30, t * 6, t * 6 + PI * 1.5, 24, Color(color, 0.7), 1.5)

	func _end() -> void:
		if ended:
			return
		ended = true
		for flight in flights:
			if flight.is_valid():
				flight.kill()
		for ref in controls:
			var control: Variant = ref.get_ref()
			if is_instance_valid(control):
				control._end(false)
		for e in entries:
			var m := e["actor"].get_ref() as Monster
			if not SiegeTools.alive(m):
				continue
			if e["moving"]:
				if not successful:
					m.global_position = e["from"]
					m.collision_mask = e["mask"]
					m.set_meta("siege_on_wall", e["wall"])
					if m is SiegeMonster:
						m.on_wall = e["on_wall"]
				m.set_meta("team_transfer", false)
				m.set_meta("airborne", false)
			m.set_physics_process(e["physics"])
			m.velocity = Vector2.ZERO
			if is_instance_valid(e["escort"]):
				m.set_meta("escort_of", e["escort"])
				m.set_meta("escort_off", e["offset"])
			else:
				m.remove_meta("escort_of")
			m.set_meta("escorts", e["escorts"])
			if e["buff"]:
				m.remove_buff("siege_frenzy")
		for ref in members:
			var m: Variant = ref.get_ref()
			if is_instance_valid(m) and m is EnemyTower:
				m.cancel_cooperation(self)
		if kind == "bubble_roll" and is_inside_tree():
			Fx.burst(get_parent(), destination, "bubble", 12, 40, 0.5, Vector2.ZERO, color)
		queue_free()

	func _exit_tree() -> void:
		_end()
