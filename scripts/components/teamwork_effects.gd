class_name TeamworkEffects
extends RefCounted
## 怪物配合技的效果（MonsterTeamwork 按 data/teamwork.json 的 effect.type 分派到这里；新配合技只要加数据和一个效果函数）。
##   throw_onto_wall  巨魔投掷：leader 抓起旁边的小怪扔上城墙（没有城墙的关卡就扔到公主身边）
##   merge            史莱姆合体：几只合成一只大的（血 ×4、个头变大），打倒后分裂成更多小的
##   raise_arms       举手挠腋：手套把公主的手举高（腋下暴露 + 定身），幽灵扑上来挠腋下
##   strip_shoes      脱鞋小队：脚心暴露一阵子，附近的刷子怪都围过来
##   suction_chain    吸盘串串：藤壶一只接一只吸上来：越来越慢、挣脱要多按、余痒
##   feather_dance    精灵羽毛舞会：一大圈范围持续挠痒
##   bubble_trap      泡泡鱼连环泡：公主被困进大泡泡（飘起来动不了），毛毛虫钻进来挠
##   charge           魔力水母充能：附近的怪加速、挠得更重一阵子
##   roll_push        刷子滚球阵：刺猬排成一列滚过去，把公主撞向怪堆
##   living_ladder    壁虎叠罗汉：叠成活梯子，附近的怪顺着爬上墙
##   escort_cart      攻城车护卫阵：螃蟹排在车前挡冰
##   airdrop          蝠群空投：蝙蝠抓起钩索怪 / 小熊飞过城墙扔到墙顶
##   escort_engineer  工兵护送：护卫围着工兵走，护送搭成的塔第一次发动威力加倍
## 攻防战相关的部分（城墙、墙顶）走 SiegeDirector.current；没有的话自动退化成「扔到公主身边」。


static func apply(t: Dictionary, members: Array, ctx: Dictionary) -> void:
	var e: Dictionary = t.get("effect", {})
	var target: PlayableCharacter = ctx.get("target")
	if e.get("joint", false):
		var action := CoordinatedAction.new()
		action.team = t
		action.left = float(t.get("windup", 0.2))
		action.members = members.map(func(m): return weakref(m))
		action.target_ref = weakref(target) if is_instance_valid(target) else null
		members[0].get_parent().add_child(action)
		action.global_position = members[0].global_position
		return
	var leader: Monster = members[0]
	match str(e.get("type", "")):
		"throw_onto_wall": _throw(leader, members.slice(1), target)
		"merge": _merge(leader, members.slice(1), ctx.get("host"))
		"raise_arms": _raise_arms(leader, members.slice(1), target)
		"strip_shoes": _strip_shoes(members, target)
		"suction_chain": _suction(leader, members.slice(1), target)
		"feather_dance": _feather_dance(leader, members)
		"bubble_trap": _bubble_trap(members, target)
		"charge": _charge(leader)
		"roll_push": _roll(members, target)
		"living_ladder": _ladder(members)
		"escort_cart": _escort(leader, members.slice(1), Vector2(0, -18))
		"airdrop": _airdrop(leader, members.slice(1), target)
		"escort_engineer": _escort_engineer(members)
		"sticky_pincer", "hook_relay", "vine_pincer", "escort_bear", "melt_delivery", "jelly_guard", "bear_shield", "bear_airlift", "bear_airlift_rage", "bear_roll", "puppet_relay":
			var action := CoordinatedAction.new()
			action.team = t
			action.left = float(t.get("windup", 0.8))
			action.members = members.map(func(m): return weakref(m))
			action.target_ref = weakref(target) if is_instance_valid(target) else null
			leader.get_parent().add_child(action)
			action.global_position = leader.global_position


## 成套生成后马上组队（formation）：按 effect.type 把成员连起来，不需要公主在旁边。
static func on_spawn(t: Dictionary, made: Array, _ctx: Dictionary) -> void:
	var e: Dictionary = t.get("effect", {})
	var keyed := {}
	for m in made:
		var k := MonsterTeamwork.key_of(m)
		if not keyed.has(k):
			keyed[k] = []
		keyed[k].append(m)
	var first_key := str(t.get("members", [{}])[0].get("key", "")) if t.get("members", []).size() > 0 else ""
	var leaders: Array = keyed.get(first_key, [made[0]])
	var leader: Monster = leaders[0]
	var rest := made.filter(func(m): return m != leader)
	match str(e.get("type", "")):
		"escort_cart": _escort(leader, rest, Vector2(0, -18))
		"escort_engineer": _escort_engineer(made)
		"living_ladder":
			# 壁虎小队：一起奔同一段墙
			var x: float = leader.global_position.x
			for m in made:
				m.set_meta("march_x", x + randf_range(-10, 10))
		"airdrop":
			if not rest.is_empty():
				_airdrop(leader, [rest[0]], null)
		"sticky_pincer", "hook_relay", "vine_pincer", "escort_bear", "melt_delivery", "jelly_guard":
			# 新队形先聚集，扫描凑齐且预警后才施加效果。
			_escort(leader, rest, Vector2(0, 18))
		_:
			for m in rest:
				m.set_meta("escort_of", leader)
				m.set_meta("escort_off", Vector2(randf_range(-20, 20), randf_range(-14, 14)))


static func _alive(m: Variant) -> bool:
	return m != null and is_instance_valid(m) and m is Actor and (m as Actor).is_alive()


## 沿用现有效果的临时节点风格（如 DanceZone）：统一预警、冻结取消和来源生命周期。
class CoordinatedAction extends Node2D:
	var team := {}
	var members: Array = []
	var target_ref: WeakRef
	var warning: Node
	var left := 0.8
	var wall_spot: Variant

	func _ready() -> void:
		add_to_group("siege_temp")
		# add_child 后宿主会设置位置，延后一帧初始化预警。
		_begin.call_deferred()

	func _begin() -> void:
		var group := _group()
		if group.is_empty():
			queue_free()
			return
		global_position = group[0].global_position
		var kind := str(team.get("effect", {}).get("type", ""))
		var col := Color(str(team.get("color", "#9fe8e0")))
		var at := global_position
		if kind in ["hook_relay", "bear_airlift", "bear_airlift_rage"]:
			wall_spot = TeamworkEffects._wall_spot(global_position.x)
			if wall_spot is Vector2:
				at = wall_spot
		elif target_ref and TeamworkEffects._alive(target_ref.get_ref()) and kind in ["sticky_pincer", "vine_pincer", "bear_roll"]:
			at = (target_ref.get_ref() as Node2D).global_position
		warning = SiegeFx.warn(get_parent(), at, "shadow" if kind in ["hook_relay", "bear_airlift", "bear_airlift_rage"] else "circle", 42.0, left, col, 0.0, 1.2, true)
		SiegeFx.wind_wheel(get_parent(), global_position, 45.0, col, left)

	func _group() -> Array:
		var out := []
		for ref in members:
			var m: Variant = ref.get_ref()
			if not TeamworkEffects._alive(m) or (m is Monster and m.is_stunned()):
				return []
			out.append(m)
		return out

	func _process(delta: float) -> void:
		var d := SiegeDirector.current
		if d == null or d.state != "fight":
			queue_free()
			return
		if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
			return
		var group := _group()
		if group.is_empty():
			if is_instance_valid(warning):
				warning.queue_free()
			queue_free()
			return
		left -= delta
		if left > 0.0:
			return
		var target := target_ref.get_ref() as PlayableCharacter if target_ref else null
		if not TeamworkEffects._alive(target) or Downed.is_downed(target):
			target = null
		if team.get("effect", {}).get("joint", false):
			SiegeCooperation.perform(team, group, target)
		else:
			TeamworkEffects._coordinated(str(team.get("effect", {}).get("type", "")), group, target, wall_spot)
		queue_free()


static func _coordinated(kind: String, group: Array, target: PlayableCharacter, wall_spot: Variant) -> void:
	var leader: Monster = group[0]
	match kind:
		"puppet_relay":
			var d := SiegeDirector.current
			if d == null:
				return
			var people: Array = [d.pink, d.blue].filter(func(c): return SiegeTools.alive(c))
			people.sort_custom(func(a, b): return a.status.is_grabbed() and not b.status.is_grabbed())
			if people.is_empty():
				return
			for i in range(1, group.size()):
				var c: PlayableCharacter = people[(i - 1) % people.size()]
				var m: Monster = group[i]
				var to := c.global_position + Vector2((i % 2 * 2 - 1) * 18, 0)
				var wall := d.is_on_wall(c)
				if wall and (d.segment_at(to.x) == null or not d.segment_at(to.x).climbable()):
					to.y = d.wall_foot_y() + 28
					wall = false
				m.remove_meta("escort_of")
				m.set_meta("puppet_victim", weakref(c))
				_transfer(leader, m, to, wall, false, true)
			var towers: Array = leader.get_tree().get_nodes_in_group("siege_enemy_tower").filter(func(t): return t is EnemyTower and SiegeTools.alive(t) and t.kind in ["airdrop", "brush_battery", "resonance"] and t.global_position.distance_to(leader.global_position) < 360)
			towers.sort_custom(func(a, b): return a.global_position.distance_squared_to(leader.global_position) < b.global_position.distance_squared_to(leader.global_position))
			for tower in towers.slice(0, 2):
				tower.command_fire()
		"sticky_pincer", "vine_pincer":
			if target == null or leader.global_position.distance_to(target.global_position) > 90.0:
				return
			if target.status:
				if kind == "sticky_pincer":
					target.status.apply_slow(0.65, 2.0)
				elif not target.status.is_immobile():
					target.status.apply_root(1.0)
			for m in group:
				if m.has_meta("escort_of"):
					m.remove_meta("escort_of")
				m.rally_to(target)
			SpeechBubble.say(target, "脚步乱了！先打领头的！" if target.character_id == "pink" else "……包围。先打领头的。", 28.0, 1.4)
		"hook_relay":
			if wall_spot is Vector2:
				_send_to_wall(leader, group.slice(1), wall_spot)
		"bear_airlift", "bear_airlift_rage":
			var d := SiegeDirector.current
			if d == null:
				return
			for i in range(1, group.size()):
				var passenger: Monster = group[i]
				if passenger.has_meta("escort_of"):
					passenger.remove_meta("escort_of")
				var wall := i % 2 == 1 and GaleBear._alive(d.blue) and d.is_on_wall(d.blue)
				var to: Vector2 = wall_spot if wall and wall_spot is Vector2 else (d.pink.global_position if GaleBear._alive(d.pink) else d.blue.global_position)
				to += Vector2((i - 1) * 16.0, 0)
				if wall and not d.segment_at(to.x).climbable():
					continue
				SiegeFx.warn(leader.get_parent(), to, "shadow", 30.0, 0.12, GaleBear.WIND, 0.0, 1.2, true)
				_transfer(leader, passenger, to, wall, true)
		"escort_bear", "bear_shield":
			_escort(leader, group.slice(1), Vector2(0, -32))
		"melt_delivery":
			var d := SiegeDirector.current
			var nearest: Node2D
			var distance := 400.0
			for tower in leader.get_tree().get_nodes_in_group("siege_tower"):
				var span := leader.global_position.distance_to(tower.global_position)
				if span < distance:
					distance = span
					nearest = tower
			if nearest == null or d == null:
				return
			for i in range(1, group.size()):
				var m: Monster = group[i]
				if m.has_meta("escort_of"):
					m.remove_meta("escort_of")
				var to := d.clamp_in_map(nearest.global_position + Vector2((i * 2 - 3) * 18.0, 10.0))
				_transfer(leader, m, to, false)
		"jelly_guard":
			_escort(leader, group.slice(1), Vector2(0, -16))
			var d := SiegeDirector.current
			if d and _alive(d.blue) and not Downed.is_downed(d.blue):
				leader.rally_to(d.blue)
		"bear_roll":
			if target:
				for m in group.slice(1):
					if m.has_meta("escort_of"):
						m.remove_meta("escort_of")
				_roll(group.slice(1), target, true)


static func _send_to_wall(leader: Monster, passengers: Array, spot: Vector2) -> void:
	var d := SiegeDirector.current
	if d == null:
		return
	var wall := d.segment_at(spot.x)
	if wall == null or not wall.climbable():
		return
	for i in passengers.size():
		var m: Monster = passengers[i]
		if m.has_meta("escort_of"):
			m.remove_meta("escort_of")
		_transfer(leader, m, spot + Vector2(i * 14.0, 0), true)


## 运输复用 _arc；冻结或击败领队会取消落地效果，乘客回到起点并恢复正常 AI。
static func _transfer(leader: Monster, passenger: Monster, to: Vector2, wall: bool, windy := false, puppet := false) -> void:
	var source: WeakRef = weakref(leader)
	var rider: WeakRef = weakref(passenger)
	var from := passenger.global_position
	passenger.set_meta("team_transfer", true)
	passenger.set_meta("airborne", true)
	var flight := _arc(passenger, to, 0.45 if windy or puppet else 0.9, 70.0, func():
		var m := rider.get_ref() as Monster
		var lead := source.get_ref() as Monster
		if not _alive(m):
			return
		m.set_meta("team_transfer", false)
		m.set_meta("airborne", false)
		var d := SiegeDirector.current
		if not _alive(lead) or lead.is_stunned() or m.is_stunned() or d == null or d.state != "fight":
			m.global_position = from
			if puppet:
				m.remove_meta("puppet_victim")
			return
		if wall:
			var segment := d.segment_at(to.x)
			if segment and segment.climbable():
				put_on_wall(m, to)
			else:
				m.global_position = from
		if puppet and lead is PuppetMaster and m.has_meta("puppet_victim"):
			var c := (m.get_meta("puppet_victim") as WeakRef).get_ref() as PlayableCharacter
			m.remove_meta("puppet_victim")
			if SiegeTools.alive(c) and m.global_position.distance_to(c.global_position) < 48.0:
				m.rally_to(c)
				lead.register_field(SiegeTools.sequence(lead, c, 2, 3.0, "relay")))
	if windy or puppet:
		var guard := WindTransport.new()
		guard.source = source
		guard.rider = rider
		guard.from = from
		guard.flight = flight
		guard.puppet = puppet
		leader.get_parent().add_child(guard)
		if leader.has_method("register_field"):
			leader.call("register_field", guard)


## 放到墙顶（攻防战）：之后用通用的墙顶行为（找蓝色公主 / 拆墙）。
static func put_on_wall(m: Monster, at: Vector2) -> void:
	m.global_position = at
	m.collision_mask = 0
	m.set_meta("siege_on_wall", true)
	if m is SiegeMonster:
		(m as SiegeMonster).on_wall = true
	m.state = Monster.State.WANDER
	Fx.burst(m.get_parent(), at, "dust", 8, 40.0, 0.5, Vector2(0, 20))


static func _wall_spot(near_x: float) -> Variant:
	var d := SiegeDirector.current
	if d == null:
		return null
	var x := near_x
	if d.blue and is_instance_valid(d.blue) and d.is_on_wall(d.blue):
		x = d.blue.global_position.x + randf_range(-30, 30)
	return Vector2(x, d.wall_top_y() + randf_range(-2, 6))


static func _arc(m: Node2D, to: Vector2, time: float, height: float, done: Callable) -> Tween:
	var from := m.global_position
	if m is Monster:
		(m as Monster).set_physics_process(false)
	var tw := m.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(m):
			m.global_position = from.lerp(to, v) + Vector2(0, -sin(v * PI) * height), 0.0, 1.0, time)
	tw.tween_callback(func():
		if is_instance_valid(m):
			if m is Monster:
				(m as Monster).set_physics_process(true)
			done.call())
	return tw


## 运输仍走原 _arc / _transfer；这个薄守卫只管风效、暂停、计时与立即取消。
class WindTransport extends Node2D:
	var source: WeakRef
	var rider: WeakRef
	var flight: Tween
	var from := Vector2.ZERO
	var t := 0.0
	var puppet := false

	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 4

	func _process(delta: float) -> void:
		var p := rider.get_ref() as Monster
		var lead := source.get_ref() as Monster
		if not TeamworkEffects._alive(p) or not TeamworkEffects._alive(lead) or lead.is_stunned() or p.is_stunned() or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			_end()
			return
		if not p.get_meta("team_transfer", false):
			queue_free()
			return
		if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
			flight.pause()
			return
		if not flight.is_running():
			flight.play()
		t += delta
		global_position = p.global_position
		queue_redraw()

	func _physics_process(delta: float) -> void:
		var p := rider.get_ref() as Monster
		if TeamworkEffects._alive(p) and not p.is_physics_processing() and not GameState.in_dialogue and not GameState.in_cutscene and not CG.is_busy():
			p.tick_timers(delta)

	func _draw() -> void:
		if puppet:
			draw_arc(Vector2.ZERO, 20, t * 5, t * 5 + 4, 20, SiegeTools.COLOR, 2)
			draw_line(Vector2(-24, -8), Vector2(24, -8), SiegeTools.COLOR, 1.5)
		else:
			SiegeFx.draw_tornado(self, Vector2.ZERO, 18.0, t, GaleBear.WIND)

	func _end() -> void:
		if flight and flight.is_valid():
			flight.kill()
		var p := rider.get_ref() as Monster
		if TeamworkEffects._alive(p) and p.get_meta("team_transfer", false):
			p.global_position = from
			p.set_meta("team_transfer", false)
			p.set_meta("airborne", false)
			p.set_physics_process(true)
			if puppet:
				p.remove_meta("puppet_victim")
		queue_free()


# ------------------------------------------------------------------ 各个效果
static func _throw(troll: Monster, ammo: Array, target: PlayableCharacter) -> void:
	if ammo.is_empty():
		return
	var a: Monster = ammo[0]
	if not _alive(a):
		return
	var spot: Variant = _wall_spot(troll.global_position.x)
	var to: Vector2 = spot if spot is Vector2 else (target.global_position + Vector2(randf_range(-10, 10), 0) if target else troll.global_position)
	SpeechBubble.say(troll, "飞——过——去！", 26.0, 1.2)
	Audio.play("swish", -4.0, 0.1, 0.6)
	_arc(a, to, 0.9, 90.0, func():
		if spot is Vector2:
			put_on_wall(a, to)
		else:
			Fx.burst(a.get_parent(), to, "dust", 8, 40.0, 0.5, Vector2(0, 20)))


static func _merge(leader: Monster, others: Array, host: Variant) -> void:
	var at := leader.global_position
	for m in others:
		if not _alive(m):
			continue
		var tw := (m as Node2D).create_tween()
		tw.tween_property(m, "global_position", at, 0.35)
		tw.tween_callback((m as Node).queue_free)
	leader.set_meta("giant", true)
	if leader.sprite:
		leader.create_tween().tween_property(leader.sprite, "scale", Vector2(2.0, 2.0), 0.4).set_trans(Tween.TRANS_BACK)
	if leader.health:
		leader.health.max_hp *= 4
		leader.health.fill()
	leader.add_buff("siege_frenzy", 9999.0)
	Fx.burst(leader.get_parent(), at + Vector2(0, -10), "goo", 18, 60.0, 0.6, Vector2(0, 60), Color(0.6, 1.0, 0.7))
	Audio.play("pop", -2.0, 0.0, 0.6)
	leader.died.connect(func(_a: Actor):
		var h: Variant = host
		if h == null or not is_instance_valid(h) or not h.spawn_func.is_valid():
			return
		for i in 6:
			h.spawn_func.call("slime", at + Vector2.from_angle(TAU * i / 6.0) * 14.0))


static func _raise_arms(glove: Monster, ghosts: Array, target: PlayableCharacter) -> void:
	if target == null:
		return
	if target.status:
		target.status.apply_root(1.2)
	if target.combo:
		target.combo._expose("armpit", 1.6, 5.0)
	SpeechBubble.say(target, "手、手被举起来了——腋下！" if target.character_id == "pink" else "……手。……举起来了。", 28.0, 1.6)
	glove.global_position = target.global_position + Vector2(0, -14)
	for g in ghosts:
		if _alive(g):
			(g as Monster).rally_to(target)
			(g as Node2D).global_position = (g as Node2D).global_position.move_toward(target.global_position, 40.0)
	var h := HitData.make_tickle(glove, 8.0)
	h.zone = "armpit"
	h.special = true
	target.receive_hit(h)


static func _strip_shoes(members: Array, target: PlayableCharacter) -> void:
	if target == null:
		return
	if target.combo:
		target.combo._expose("sole", 1.7, 8.0)
	target.set_meta("shoeless_until", Time.get_ticks_msec() / 1000.0 + 8.0)
	SpeechBubble.say(target, "鞋、鞋子被扒掉了——！" if target.character_id == "pink" else "……鞋子。……没了。", 28.0, 1.6)
	Fx.burst(target.get_parent(), target.global_position + Vector2(0, -4), "dust", 6, 30.0, 0.4, Vector2(0, 30))
	for m in members[0].get_tree().get_nodes_in_group("enemy"):
		if m is Monster and (m as Node2D).global_position.distance_to(target.global_position) < 220.0 \
				and MonsterTeamwork.key_of(m) in ["squirrel", "hedgehog", "rat"]:
			(m as Monster).rally_to(target)


static func _suction(octo: Monster, barnacles: Array, target: PlayableCharacter) -> void:
	if target == null:
		return
	if target.status:
		if target.status.is_grabbed():
			target.status.extend_grab(2.0, 6)
		target.status.apply_slow(0.5, 4.0)
		target.status.add_dot(3.0, 4.0, octo)
	for b in barnacles:
		if _alive(b):
			var tw := (b as Node2D).create_tween()
			tw.tween_property(b, "global_position", target.global_position + Vector2(randf_range(-8, 8), randf_range(-4, 4)), 0.5)
	SpeechBubble.say(target, "吸、吸住了一串……走不动！", 28.0, 1.4)


static func _feather_dance(leader: Monster, members: Array) -> void:
	var zone := DanceZone.new()
	zone.add_to_group("siege_temp")
	leader.get_parent().add_child(zone)
	zone.global_position = leader.global_position
	zone.source = leader
	for m in members:
		if _alive(m):
			(m as Monster).stun(0.0)


static func _bubble_trap(members: Array, target: PlayableCharacter) -> void:
	if target == null:
		return
	if target.status:
		target.status.apply_root(3.0)
	target.add_buff("lifted", 3.0)
	var b := SiegeFx.ring(target.get_parent(), target.global_position + Vector2(0, -8), 14.0, Color(0.7, 0.9, 1.0, 0.9), 3.0, 0.3)
	if b:
		b.z_index = 20
	Audio.play("bubble", -2.0, 0.1)
	for m in members[0].get_tree().get_nodes_in_group("enemy"):
		if m is Monster and (m as Node2D).global_position.distance_to(target.global_position) < 200.0 and MonsterTeamwork.key_of(m) == "caterpillar":
			(m as Monster).rally_to(target)
	# 用 weakref：闭包直接抓着的怪被打倒释放后，再调用闭包 Godot 会报「Lambda capture was freed」
	var src_ref: WeakRef = weakref(members[0])
	var tgt_ref: WeakRef = weakref(target)
	var tw := target.create_tween().set_loops(6)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		var t := tgt_ref.get_ref() as Actor
		var src := src_ref.get_ref() as Node
		if t and src:
			t.receive_hit(HitData.make_tickle(src, 3.0)))


static func _charge(jelly: Monster) -> void:
	for m in jelly.get_tree().get_nodes_in_group("enemy"):
		if m is Monster and (m as Node2D).global_position.distance_to(jelly.global_position) < 90.0:
			(m as Monster).add_buff("siege_frenzy", 6.0)
			Fx.burst(m.get_parent(), (m as Node2D).global_position + Vector2(0, -10), "crystal", 3, 30.0, 0.4, Vector2(0, -20), Color(0.8, 0.6, 1.0))
	SiegeFx.ring(jelly.get_parent(), jelly.global_position, 90.0, Color(0.8, 0.55, 1.0, 0.7), 0.6, 0.06)


static func _roll(members: Array, target: PlayableCharacter, fast := false) -> void:
	if target == null:
		return
	var dir := (members[0] as Node2D).global_position.direction_to(target.global_position)
	for i in members.size():
		var m: Monster = members[i]
		if not _alive(m):
			continue
		m.global_position = (members[0] as Node2D).global_position - dir * (i * 12.0)
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", target.global_position + dir * 30.0 - dir * (i * 12.0), 0.35 if fast else 0.8)
	var d := SiegeDirector.current
	var crowd: Variant = d.densest(40.0, target.global_position, 220.0) if d else null
	var push := target.global_position + (target.global_position.direction_to(crowd) if crowd is Vector2 else dir) * 10.0
	var tgt_ref: WeakRef = weakref(target)
	var lead_ref: WeakRef = weakref(members[0])
	target.get_tree().create_timer(0.18 if fast else 0.5).timeout.connect(func():
		var t := tgt_ref.get_ref() as PlayableCharacter
		if t:
			t.apply_knockback(t.global_position - (push - t.global_position), 320.0)
			t.receive_hit(HitData.make_tickle(lead_ref.get_ref() as Node, 6.0)))
	Audio.play("roll", -2.0, 0.1)


static func _ladder(geckos: Array) -> void:
	var d := SiegeDirector.current
	if d == null:
		return
	var x: float = (geckos[0] as Node2D).global_position.x
	var lad := LivingLadder.new()
	lad.geckos = geckos.duplicate()
	# 先定好位置再加进场景（_ready 里按自己的位置把壁虎一只只叠上去）
	var ent := d.entities()
	lad.position = (ent as Node2D).to_local(Vector2(x, d.wall_foot_y())) if ent is Node2D else Vector2(x, d.wall_foot_y())
	ent.add_child(lad)
	for g in geckos:
		if _alive(g):
			(g as Monster).set_meta("in_ladder", lad)


static func _escort(leader: Monster, guards: Array, front: Vector2) -> void:
	var escorts := []
	for i in guards.size():
		var g: Monster = guards[i]
		if not _alive(g):
			continue
		g.set_meta("escort_of", leader)
		g.set_meta("escort_off", front + Vector2((i - (guards.size() - 1) / 2.0) * 14.0, 0))
		escorts.append(g)
	leader.set_meta("escorts", escorts)


static func _airdrop(bats: Monster, passengers: Array, _target: PlayableCharacter) -> void:
	if passengers.is_empty():
		return
	var p: Monster = passengers[0]
	if not _alive(p) or p.get_meta("siege_on_wall", false):
		return
	var spot: Variant = _wall_spot(bats.global_position.x)
	if not (spot is Vector2):
		return
	p.set_meta("airborne", true)
	SpeechBubble.say(bats, "吱吱——空投！", 26.0, 1.2)
	var time := clampf(p.global_position.distance_to(spot) / 90.0, 1.0, 5.0)
	bats.set_physics_process(false)
	_arc(p, spot, time, 30.0, func():
		p.set_meta("airborne", false)
		put_on_wall(p, spot))
	var tw := bats.create_tween()
	tw.tween_property(bats, "global_position", (spot as Vector2) + Vector2(0, -14), time)
	tw.tween_callback(func():
		if is_instance_valid(bats):
			bats.set_physics_process(true))


static func _escort_engineer(members: Array) -> void:
	var engineers := members.filter(func(m): return m is GoblinEngineer)
	if engineers.is_empty():
		return
	var squad := randi_range(1, 1 << 30)
	var lead: Monster = engineers[0]
	for e in engineers:
		(e as GoblinEngineer).squad = squad
		(e as GoblinEngineer).escorted = true
	var guards := members.filter(func(m): return not (m is GoblinEngineer))
	for i in guards.size():
		var g: Monster = guards[i]
		g.set_meta("escort_of", lead)
		g.set_meta("escort_off", Vector2.from_angle(TAU * i / maxf(guards.size(), 1)) * 24.0)


## 精灵羽毛舞会的范围：DURATION 秒内，圈里的公主每 TICK 秒挨一下。
class DanceZone extends Node2D:
	const R := 70.0
	const DURATION := 3.0
	const TICK := 0.4
	var source: Node
	var _t := 0.0
	var _tick := 0.0

	func _ready() -> void:
		Audio.play("chime", -4.0, 0.1, 1.7)

	func _process(delta: float) -> void:
		_t += delta
		_tick -= delta
		queue_redraw()
		if _tick <= 0.0:
			_tick = TICK
			Fx.burst(get_parent(), global_position + Vector2.from_angle(randf() * TAU) * randf() * R, "feather", 3, 30.0, 0.6, Vector2(0, 20))
			for n in get_tree().get_nodes_in_group("player_chars"):
				var c := n as PlayableCharacter
				if c and c.is_alive() and c.global_position.distance_to(global_position) < R:
					c.receive_hit(HitData.make_tickle(source if is_instance_valid(source) else self, 3.0))
		if _t >= DURATION:
			queue_free()

	func _draw() -> void:
		var a := 0.5 * (1.0 - _t / DURATION)
		draw_circle(Vector2.ZERO, R, Color(1, 0.75, 0.9, a * 0.25))
		draw_arc(Vector2.ZERO, R, _t * 2.0, _t * 2.0 + TAU * 0.8, 40, Color(1, 0.85, 0.95, a), 2.0)
