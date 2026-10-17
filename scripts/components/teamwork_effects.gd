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
## 关卡专属的配合技（攻防战的联合配合、Boss 配合）不写在这里：关卡用 handlers / spawn_handlers / joint_handler 登记（SiegeTeamEffects）。


## 关卡自己的配合技效果（攻防战的 SiegeTeamEffects.register 登记）：effect.type → Callable(team, members, ctx)；
## spawn_handlers：成套生成后组队的处理。登记过的类型（以及 effect.joint 的联合配合）不走下面的通用效果。
static var handlers := {}
static var spawn_handlers := {}
## effect.joint = true 的联合配合交给它（攻防战：SiegeTeamEffects）
static var joint_handler: Callable


static func apply(t: Dictionary, members: Array, ctx: Dictionary) -> void:
	var e: Dictionary = t.get("effect", {})
	var target: PlayableCharacter = ctx.get("target")
	var kind := str(e.get("type", ""))
	if e.get("joint", false) and joint_handler.is_valid():
		joint_handler.call(t, members, ctx)
		return
	if handlers.has(kind):
		(handlers[kind] as Callable).call(t, members, ctx)
		return
	var leader: Monster = members[0]
	match kind:
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
	var kind := str(e.get("type", ""))
	if spawn_handlers.has(kind):
		(spawn_handlers[kind] as Callable).call(t, leader, rest)
		return
	match kind:
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
		_:
			for m in rest:
				m.set_meta("escort_of", leader)
				m.set_meta("escort_off", Vector2(randf_range(-20, 20), randf_range(-14, 14)))


static func _alive(m: Variant) -> bool:
	return m != null and is_instance_valid(m) and m is Actor and (m as Actor).is_alive()


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
