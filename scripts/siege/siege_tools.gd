class_name SiegeTools
extends RefCounted
## 魔偶师与新敌塔共用的软指 / 绒刷 / 软垫；命中、抓取、运输仍走原组件。

const COLOR := Color(0.95, 0.65, 0.85)
const KEYS := ["tool_finger", "tool_roller", "tool_pad", "tool_pad"]


static func alive(a: Variant) -> bool:
	return is_instance_valid(a) and a is Actor and a.is_alive() and not a.is_queued_for_deletion() and not (a is PlayableCharacter and Downed.is_downed(a))


## 能不能被陷阱 / 风场 / 泡泡 / 强风带走（吹、卷、吸、弹）：Boss、攻城车不行；在墙上、在空中、在活梯子里、
## 正被配合技运送（team_transfer）、物理被别人接管的也不行。stunned_ok = false 时冻住 / 晕住的也不动。
static func displaceable(m: Variant, stunned_ok := false) -> bool:
	if not alive(m) or not (m is Monster):
		return false
	if m is SiegeBoss or m is SiegeCart or not m.is_physics_processing():
		return false
	if m.get_meta("siege_on_wall", false) or m.get_meta("airborne", false) or m.get_meta("team_transfer", false) or m.has_meta("in_ladder"):
		return false
	return stunned_ok or not m.is_stunned()


static func valid_source(a: Variant) -> bool:
	return alive(a) and not (a is Monster and a.is_stunned())


static func paused() -> bool:
	return GameState.in_dialogue or GameState.in_cutscene or CG.is_busy()


static func zone(c: PlayableCharacter, index: int) -> String:
	return "sole" if c.character_id == "pink" else ("thigh" if index % 4 < 2 else "butt")


static func picture(c: PlayableCharacter, index: int) -> String:
	return "tool_roller" if c.character_id == "pink" else KEYS[index % 4]


static func strike(source: Actor, c: PlayableCharacter, amount: float, index: int, variant: String, cast_power := -1.0) -> bool:
	if not valid_source(source) or not alive(c) or c.is_dashing():
		return false
	var part := zone(c, index)
	var accepted: bool
	if source.has_method("strike_tools"):
		accepted = source.call("strike_tools", c, amount, part, variant)
	else:
		var power: float = cast_power if cast_power >= 0.0 else (source.power if source is EnemyTower else 1.0)
		var h := HitData.make_tickle(source, amount * power)
		h.zone = part
		h.reaction_variant = variant
		accepted = c.receive_hit(h)
	if accepted:
		visual(c.get_parent(), ZoneFx.body_point(c, part), picture(c, index), 0.25, index % 2)
		HitFx.play("brush" if picture(c, index) == "tool_roller" else ("pinch" if part == "butt" else "hand"), c.get_parent(), ZoneFx.body_point(c, part))
	return accepted


static func visual(parent: Node, at: Vector2, key: String, time := 0.5, side := 0) -> ToolVisual:
	var v := ToolVisual.new()
	v.key = key
	v.life = time
	v.side = side
	v.position = at
	parent.add_child(v)
	return v


class ToolVisual extends Node2D:
	var key := "tool_roller"
	var life := 0.5
	var t := 0.0
	var side := 0
	var during_cg := false
	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 18
	func _process(delta: float) -> void:
		if SiegeTools.paused() and not during_cg:
			return
		t += delta
		life -= delta
		queue_redraw()
		if life <= 0.0:
			queue_free()
	func _draw() -> void:
		var off := Vector2(sin(t * 28.0) * 3.0, -absf(sin(t * 20.0)) * 3.0)
		draw_texture_rect_region(IceTower.TEX, Rect2(off + Vector2(-10, -10), Vector2(20, 20)), IceTower.region(key))
		draw_arc(off, 13.0, side * PI + t * 8.0, side * PI + t * 8.0 + 1.8, 12, SiegeTools.COLOR, 1.0)


static func sequence(source: Actor, c: PlayableCharacter, count: int, amount: float, variant: String, interval := 0.18, delay := 0.0) -> Sequence:
	var job := Sequence.new()
	job.source = weakref(source)
	job.actor = weakref(c)
	job.count = count
	job.amount = amount
	job.power = source.power if source is EnemyTower else 1.0
	job.variant = variant
	job.interval = interval
	job.left = delay
	source.get_parent().add_child(job)
	return job


class Sequence extends Node2D:
	var source: WeakRef
	var guard: WeakRef
	var actor: WeakRef
	var count := 4
	var index := 0
	var amount := 4.0
	var power := 1.0
	var interval := 0.18
	var left := 0.0
	var variant := "brush"
	var root_on_start := 0.0
	func _ready() -> void:
		add_to_group("siege_temp")
	func _physics_process(delta: float) -> void:
		if guard and (not is_instance_valid(guard.get_ref()) or not guard.get_ref().sources_alive()):
			queue_free()
			return
		var s := source.get_ref() as Actor
		var c := actor.get_ref() as PlayableCharacter
		if not SiegeTools.valid_source(s) or not SiegeTools.alive(c) or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			queue_free()
			return
		if SiegeTools.paused():
			return
		left -= delta
		if left > 0.0:
			return
		if index == 0 and root_on_start > 0.0 and c.status:
			c.status.apply_root(root_on_start)
		SiegeTools.strike(s, c, amount, index, variant, power)
		index += 1
		left += interval
		if index >= count:
			queue_free()


static func hold(source: Actor, c: PlayableCharacter, at: Vector2, lifted := false, duration := 4.0) -> Hold:
	if not can_move(source, c):
		return null
	release_own(source, c)
	var h := Hold.new()
	h.source = weakref(source)
	h.actor = weakref(c)
	h.goal = at
	h.lifted = lifted
	h.life = duration
	source.get_parent().add_child(h)
	if c.status == null or not c.status.grab(h, duration, 16):
		h.queue_free()
		return null
	c.set_meta("siege_dragged", true)
	c.set_meta("siege_dragger", h)
	if lifted:
		c.add_buff("lifted", duration)
	return h


static func can_move(source: Actor, c: PlayableCharacter) -> bool:
	# 泡泡 / 龙卷 / 关塔等可能不用 Status 抓取，却已接管角色物理更新。
	# 接管这种角色会保存 physics=false，旧机关先结束时再把 false 写回，导致永久卡死。
	if not alive(c) or not c.visible or not c.is_physics_processing() or c.status == null or c.is_dashing() or c.is_force_moving():
		return false
	for key in ["siege_climbing", "siege_falling", "siege_beaming", "siege_puppet_move", "siege_chained"]:
		if c.get_meta(key, false):
			return false
	return not c.status.is_grabbed() or own_hold(source, c) != null


## 抓取节点可先于 Status 的下一帧清理被释放；先验实例，再做类型判断。
static func own_hold(source: Actor, c: PlayableCharacter) -> Hold:
	if not is_instance_valid(source) or not is_instance_valid(c) or not is_instance_valid(c.status):
		return null
	var grabber := c.status.grabber
	if not is_instance_valid(grabber) or not (grabber is Hold):
		return null
	var h := grabber as Hold
	return h if h.source != null and h.source.get_ref() == source else null


static func release_own(source: Actor, c: PlayableCharacter) -> void:
	var h := own_hold(source, c)
	if h != null:
		h._end(false)
		# 同一机关的交接不是玩家挣脱，直接接回原 force_move，不制造逃脱无敌。
		if c.state == PlayableCharacter.State.GRABBED:
			c._set_state(PlayableCharacter.State.HELPLESS if c.laugh and c.laugh.is_helpless() else PlayableCharacter.State.IDLE)


class Hold extends Node2D:
	var source: WeakRef
	var actor: WeakRef
	var goal := Vector2.ZERO
	var lifted := false
	var life := 4.0
	var t := 0.0
	var ended := false
	## 拖人的速度（像素 / 秒）；slide = true：碰到墙 / 塔就顺着滑开，不会被卡住不动（要塞巨手的强制位移）
	var speed := 160.0
	var slide := false
	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 17
	func _physics_process(delta: float) -> void:
		var s := source.get_ref() as Actor
		var c := actor.get_ref() as PlayableCharacter
		if not SiegeTools.valid_source(s) or not SiegeTools.alive(c) or not c.status.is_grabbed_by(self) or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			_end()
			return
		if SiegeTools.paused():
			return
		life -= delta
		t += delta
		if life <= 0.0:
			_end()
			return
		global_position = c.global_position
		if not c.get_meta("siege_chained", false):
			var col := c.move_and_collide((goal - c.global_position).limit_length(speed * delta))
			if col and slide:
				c.move_and_collide(col.get_remainder().slide(col.get_normal()))
		queue_redraw()
	func _draw() -> void:
		var s := source.get_ref() as Node2D
		if is_instance_valid(s):
			draw_line(to_local(s.global_position + Vector2(0, -48)), Vector2(0, -12), SiegeTools.COLOR, 2.0)
		for i in 2:
			draw_arc(Vector2(0, -8 - i * 6), 12.0, t, t + 4.0, 16, SiegeTools.COLOR, 1.5)
	func release_drag() -> void:
		_end()
	func _end(broke_free := true) -> void:
		if ended:
			return
		ended = true
		var c := actor.get_ref() as PlayableCharacter
		if is_instance_valid(c):
			if c.status and c.status.is_grabbed_by(self):
				c.status.release(broke_free)
			if c.get_meta("siege_dragger", null) == self:
				c.set_meta("siege_dragged", false)
				c.set_meta("siege_dragger", null)
			if lifted:
				c.remove_buff("lifted")
				c._update_lift(0.0)
		queue_free()
	func _exit_tree() -> void:
		_end()


## 落点用角色原 Shape 检查；换位可跨墙，一般拖行仍碰撞移动。
static func safe_spot(c: PlayableCharacter, at: Vector2) -> Vector2:
	var shape := c.get_node_or_null("Collision") as CollisionShape2D
	if shape == null:
		shape = c.get_node_or_null("Shape") as CollisionShape2D
	if shape == null:
		return Vector2.INF
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape.shape
	q.collision_mask = 1
	q.exclude = [c.get_rid()]
	for off in [Vector2.ZERO, Vector2(16, 0), Vector2(-16, 0), Vector2(32, 0), Vector2(-32, 0), Vector2(0, 8), Vector2(0, 16), Vector2(0, 32), Vector2(16, 32), Vector2(-16, 32), Vector2(0, 48), Vector2(0, -8)]:
		var spot: Vector2 = at + off
		var xf := c.global_transform
		xf.origin = spot
		q.transform = xf * shape.transform
		if c.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			return spot
	return Vector2.INF


static func move(source: Actor, people: Array, goals: Array, swap := false) -> Move:
	for c in people:
		if not can_move(source, c):
			return null
	var destinations: Array[Vector2] = []
	for i in people.size():
		var spot: Vector2 = safe_spot(people[i], goals[i]) if swap else goals[i]
		if spot == Vector2.INF:
			return null
		destinations.append(spot)
	var m := Move.new()
	m.source = weakref(source)
	m.swapping = swap
	m.duration = 0.45 if swap else 0.6
	for i in people.size():
		var c: PlayableCharacter = people[i]
		release_own(source, c)
		m.people.append({"actor": weakref(c), "from": c.global_position, "to": destinations[i], "mask": c.collision_mask, "physics": c.is_physics_processing()})
	source.get_parent().add_child(m)
	for entry in m.people:
		var c := entry["actor"].get_ref() as PlayableCharacter
		if swap:
			if not c.status.grab(m, m.duration + 0.1, 16):
				m._end(false)
				return null
			entry["flight"] = TeamworkEffects._arc(c, entry["to"], m.duration, 28.0, func(): entry["arrived"] = true)
		else:
			# 复用角色现成的滑行、碰撞、动作中断和结束恢复。
			if not c.force_move((entry["to"] - c.global_position).limit_length(160.0) / m.duration, m.duration, "slide"):
				m._end(false)
				return null
		c.set_meta("siege_puppet_move", true)
		c.set_meta("siege_dragged", true)
		c.set_meta("siege_dragger", m)
		if swap:
			c.set_physics_process(false)
			c.velocity = Vector2.ZERO
			c.collision_mask = 0
	return m


class Move extends Node2D:
	var source: WeakRef
	var people: Array[Dictionary] = []
	var duration := 0.6
	var t := 0.0
	var swapping := false
	var ended := false
	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 17
	func _physics_process(delta: float) -> void:
		var s := source.get_ref() as Actor
		if not SiegeTools.valid_source(s) or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			_end(false)
			return
		for entry in people:
			var c := entry["actor"].get_ref() as PlayableCharacter
			if not SiegeTools.alive(c) or (swapping and not c.status.is_grabbed_by(self)) or (not swapping and c.status.is_grabbed()):
				_end(false)
				return
		if SiegeTools.paused():
			for entry in people:
				var c := entry["actor"].get_ref() as PlayableCharacter
				c.set_physics_process(false)
				if entry.has("flight") and entry["flight"].is_valid() and not entry.get("arrived", false):
					entry["flight"].pause()
			return
		t += delta
		for entry in people:
			var c := entry["actor"].get_ref() as PlayableCharacter
			if swapping:
				c.tick_timers(delta)
				if entry["flight"].is_valid() and not entry["flight"].is_running() and not entry.get("arrived", false):
					entry["flight"].play()
			else:
				c.set_physics_process(entry["physics"])
				if not c.is_force_moving():
					_end(true)
					return
		queue_redraw()
		if t >= duration or (swapping and people.all(func(entry): return entry.get("arrived", false))):
			_end(true)
	func _draw() -> void:
		var s := source.get_ref() as Node2D
		for entry in people:
			var c := entry["actor"].get_ref() as Node2D
			if is_instance_valid(s) and is_instance_valid(c):
				draw_line(s.global_position + Vector2(0, -48), c.global_position + Vector2(0, -10), SiegeTools.COLOR, 2.0)
	func release_drag() -> void:
		_end(false)
	func _end(done := false) -> void:
		if ended:
			return
		ended = true
		if done and swapping:
			for entry in people:
				var c := entry["actor"].get_ref() as PlayableCharacter
				var spot := SiegeTools.safe_spot(c, entry["to"]) if is_instance_valid(c) else Vector2.INF
				if spot == Vector2.INF:
					done = false
					break
				entry["to"] = spot
		var s := source.get_ref() as Actor
		for entry in people:
			var c := entry["actor"].get_ref() as PlayableCharacter
			if not is_instance_valid(c):
				continue
			if swapping:
				if entry.has("flight") and entry["flight"].is_valid():
					entry["flight"].kill()
				c.global_position = entry["to"] if done else entry["from"]
			else:
				c.end_forced_move()
			c.collision_mask = entry["mask"]
			c.set_physics_process(entry["physics"])
			c.set_meta("siege_puppet_move", false)
			if c.get_meta("siege_dragger", null) == self:
				c.set_meta("siege_dragged", false)
				c.set_meta("siege_dragger", null)
			if c.status and c.status.is_grabbed_by(self):
				c.status.release(true)
			if swapping and done:
				c.set_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0)
				if SiegeTools.valid_source(s) and SiegeTools.alive(c):
					SiegeTools.sequence(s, c, 4, 4.0, "swap")
		queue_free()
	func _exit_tree() -> void:
		_end(false)


class BrushField extends SiegeHazard:
	var source: WeakRef
	var next_hit := {}
	var key := "tool_roller"
	func _begin() -> void:
		_warn_left = 0.18
		reaction_key = "puppet_master"
		z_index = 1
		SiegeFx.warn(get_parent(), global_position, "circle", 26.0, _warn_left, SiegeTools.COLOR, 0.0, 1.2, true)
	func _active(delta: float) -> void:
		var s := source.get_ref() as Actor
		if not SiegeTools.valid_source(s) or director.state != "fight":
			_end()
			return
		for c in chars():
			if c.global_position.distance_to(global_position) < 26.0 and _t >= float(next_hit.get(c.get_instance_id(), -INF)):
				if SiegeTools.strike(s, c, 3.0, int(_t / 0.25), "cross"):
					next_hit[c.get_instance_id()] = _t + 0.25
	func _process(delta: float) -> void:
		if SiegeTools.paused():
			return
		super(delta)
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 24, SiegeTools.COLOR, 1.0)
		draw_texture_rect_region(IceTower.TEX, Rect2(-14, -14, 28, 28), IceTower.region(key))
		for i in 4:
			var dir := Vector2.from_angle(_t * 4.0 + i * PI / 2.0)
			draw_line(dir * 14.0, dir * 25.0, Color(1, 0.85, 0.5, 0.8), 2.0)
