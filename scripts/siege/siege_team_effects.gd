class_name SiegeTeamEffects
extends RefCounted
## 攻防战专属的配合技效果（MonsterTeamwork / TeamworkEffects 是通用组件，这些登记进 TeamworkEffects.handlers）：
##   sticky_pincer / vine_pincer 黏住 / 缠住领头的围上来、hook_relay 钩索接力上墙、escort_bear / bear_shield / jelly_guard 护卫阵、
##   melt_delivery 搬运小鬼送暖炉史莱姆去冰塔、bear_airlift(_rage) 熊统领用风把怪送到公主身边 / 墙顶、bear_roll 熊统领滚球、
##   puppet_relay(_rage) 魔偶师的挠痒接力；
##   crab_rat 夹脚脱鞋（钳钳蟹夹住脚踝 + 挠脚鼠扒鞋挠脚心）、crab_tentacle 夹脚缠腿（钳钳蟹 + 小触手顺着腿往上缠）、
##   imp_slime 史莱姆弹射（机械小鬼把分裂史莱姆弹到身上）、bear_tentacle 熊抱触手（拥抱小熊从背后抱住 + 小触手从前面挠）；
##   effect.joint 的联合配合（怪物 + 敌塔）交给 SiegeCooperation.perform。
## 这些都先放预警（CoordinatedAction，windup 秒），凑齐的人还在、没被冻住才发动；运送走 _transfer（冻住 / 打倒领队就取消、乘客回到起点）。
## SiegeDirector 开场时调用 register()。

const TYPES := ["sticky_pincer", "hook_relay", "vine_pincer", "escort_bear", "melt_delivery", "jelly_guard", "bear_shield",
	"bear_airlift", "bear_airlift_rage", "bear_roll", "puppet_relay", "crab_rat", "crab_tentacle", "imp_slime", "bear_tentacle"]
## 成套生成后先聚成一团的（扫描凑齐、预警后才发动）
const GATHER := ["sticky_pincer", "hook_relay", "vine_pincer", "escort_bear", "melt_delivery", "jelly_guard",
	"crab_rat", "crab_tentacle", "imp_slime", "bear_tentacle"]
## 这几种预警落在目标身上（不是领队脚下）
const AT_TARGET := ["sticky_pincer", "vine_pincer", "bear_roll", "crab_rat", "crab_tentacle", "imp_slime", "bear_tentacle"]


static func register() -> void:
	for kind in TYPES:
		TeamworkEffects.handlers[kind] = func(t: Dictionary, members: Array, ctx: Dictionary): start(t, members, ctx, 0.8)
	for kind in GATHER:
		TeamworkEffects.spawn_handlers[kind] = func(_t: Dictionary, leader: Monster, rest: Array): TeamworkEffects._escort(leader, rest, Vector2(0, 18))
	TeamworkEffects.joint_handler = func(t: Dictionary, members: Array, ctx: Dictionary): start(t, members, ctx, 0.2)
	TeamworkEffects.spawn_handlers["bugler_squad"] = func(_t: Dictionary, leader: Monster, rest: Array): _bugler_formation(leader, rest)
	TeamworkEffects.handlers["bugler_squad"] = func(_t: Dictionary, members: Array, ctx: Dictionary): _bugler_call(members, ctx.get("target"))


const SAY_GAP := 1.5
## 「怪物配合：XX！」横幅先飘一会儿，她再说（不然两行字叠在一起）
const SAY_DELAY := 0.8


## 配合技发动在她身上：等横幅飘过 SAY_DELAY 秒后说一句（SiegeDirector 接 MonsterTeamwork.fired 调用）。
static func say_later(c: PlayableCharacter, team_id: String) -> void:
	if not SiegeTools.alive(c):
		return
	var wr: WeakRef = weakref(c)
	c.get_tree().create_timer(SAY_DELAY, false).timeout.connect(func():
		var who := wr.get_ref() as PlayableCharacter
		if who:
			say(who, team_id))


## 配合技发动时被盯上的公主走字幕说一句（来源 team_<id> 的 trigger，粉 / 蓝各一套，在受挠反应里）。
static func say(c: PlayableCharacter, team_id: String) -> void:
	if not SiegeTools.alive(c):
		return
	# 同一个配合技有好几处会叫她说（导演发动时、效果落下时），SAY_GAP 秒内只说一次
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(c.get_meta("siege_team_said", -99.0)) < SAY_GAP:
		return
	c.set_meta("siege_team_said", now)
	Characters.scope(c.character_id)
	var lines := ReactionDB.lines("team_" + team_id, "trigger")
	Characters.unscope()
	if not lines.is_empty():
		SpeechBubble.say(c, str(lines.pick_random()), 28.0, 1.5)


## 先放预警，windup 秒后发动。
static func start(t: Dictionary, members: Array, ctx: Dictionary, default_windup: float) -> void:
	var target: PlayableCharacter = ctx.get("target")
	var action := CoordinatedAction.new()
	action.team = t
	action.left = float(t.get("windup", default_windup))
	action.members = members.map(func(m): return weakref(m))
	action.target_ref = weakref(target) if is_instance_valid(target) else null
	members[0].get_parent().add_child(action)
	action.global_position = members[0].global_position


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
		elif target_ref and TeamworkEffects._alive(target_ref.get_ref()) and kind in SiegeTeamEffects.AT_TARGET:
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
			SiegeTeamEffects._coordinated(str(team.get("effect", {}).get("type", "")), group, target, wall_spot)
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
				var wall := i % 2 == 1 and SiegeTools.alive(d.blue) and d.is_on_wall(d.blue)
				var to: Vector2 = wall_spot if wall and wall_spot is Vector2 else (d.pink.global_position if SiegeTools.alive(d.pink) else d.blue.global_position)
				to += Vector2((i - 1) * 16.0, 0)
				if wall and not d.segment_at(to.x).climbable():
					continue
				SiegeFx.warn(leader.get_parent(), to, "shadow", 30.0, 0.12, GaleBear.WIND, 0.0, 1.2, true)
				_transfer(leader, passenger, to, wall, true)
		"escort_bear", "bear_shield":
			TeamworkEffects._escort(leader, group.slice(1), Vector2(0, -32))
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
			TeamworkEffects._escort(leader, group.slice(1), Vector2(0, -16))
			var d := SiegeDirector.current
			if d and TeamworkEffects._alive(d.blue) and not Downed.is_downed(d.blue):
				leader.rally_to(d.blue)
		"bear_roll":
			if target:
				for m in group.slice(1):
					if m.has_meta("escort_of"):
						m.remove_meta("escort_of")
				TeamworkEffects._roll(group.slice(1), target, true)
		"crab_rat", "crab_tentacle", "imp_slime", "bear_tentacle":
			_ankle_team(kind, group, target)


## 第九轮的四个配合：都要目标在附近（REACH 以内）。
const REACH := 110.0


static func _ankle_team(kind: String, group: Array, target: PlayableCharacter) -> void:
	var leader: Monster = group[0]
	var rest: Array = group.slice(1)
	if target == null or leader.global_position.distance_to(target.global_position) > (260.0 if kind == "imp_slime" else REACH):
		return
	# 地面配合：够不着城墙上的人
	var d := SiegeDirector.current
	if d and (d.is_on_wall(target) or d.is_on_wall(leader)):
		return
	for m in group:
		if m.has_meta("escort_of"):
			m.remove_meta("escort_of")
	match kind:
		"crab_rat":
			# 钳钳蟹夹住脚踝，挠脚鼠扒鞋（脚心暴露），围上来挠
			if target.status:
				target.status.apply_root(2.0)
			Fx.burst(target.get_parent(), target.global_position, "chip", 5, 30.0, 0.3, Vector2(0, 30), Color(1, 0.6, 0.5))
			TeamworkEffects._strip_shoes(group, target)
			for m in rest:
				(m as Monster).rally_to(target)
		"crab_tentacle":
			# 夹住脚踝，小触手顺着腿往上缠：余痒、挣脱要多按
			if target.status:
				target.status.apply_root(2.0)
				target.status.add_dot(3.0, 4.0, rest[0] if not rest.is_empty() else leader)
			for m in rest:
				(m as Monster).rally_to(target)
				Fx.burst(target.get_parent(), target.global_position + Vector2(randf_range(-6, 6), -4), "goo", 4, 25.0, 0.4, Vector2(0, 20), Color(0.85, 0.6, 1.0))
		"imp_slime":
			# 小鬼把史莱姆当弹药弹射过来，粘在身上挠
			if target.status:
				target.status.apply_slow(0.6, 3.0)
			for i in rest.size():
				var m: Monster = rest[i]
				var to := target.global_position + Vector2(-10.0 + 20.0 * i, 4.0)
				var tr: WeakRef = weakref(target)
				var mr: WeakRef = weakref(m)
				Audio.play("pop", -4.0, 0.1, 1.2)
				TeamworkEffects._arc(m, to, 0.5, 40.0, func():
					var who := tr.get_ref() as PlayableCharacter
					var slime := mr.get_ref() as Monster
					if TeamworkEffects._alive(who) and TeamworkEffects._alive(slime):
						slime.deliver_tickle(who, 5.0)
						slime.rally_to(who)
						Fx.burst(slime.get_parent(), who.global_position + Vector2(0, -8), "goo", 6, 30.0, 0.4, Vector2(0, 30), Color(0.6, 0.9, 1.0)))
		"bear_tentacle":
			# 小熊从背后抱住（连按挣脱），小触手从前面挠
			if target.status and target.status.grab(leader, 2.5, 10):
				target.status.add_dot(4.0, 2.5, rest[0] if not rest.is_empty() else leader)
			for m in rest:
				(m as Monster).rally_to(target)


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
	var flight := TeamworkEffects._arc(passenger, to, 0.45 if windy or puppet else 0.9, 70.0, func():
		var m := rider.get_ref() as Monster
		var lead := source.get_ref() as Monster
		if not TeamworkEffects._alive(m):
			return
		m.set_meta("team_transfer", false)
		m.set_meta("airborne", false)
		var d := SiegeDirector.current
		if not TeamworkEffects._alive(lead) or lead.is_stunned() or m.is_stunned() or d == null or d.state != "fight":
			m.global_position = from
			if puppet:
				m.remove_meta("puppet_victim")
			return
		if wall:
			var segment := d.segment_at(to.x)
			if segment and segment.climbable():
				TeamworkEffects.put_on_wall(m, to)
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


# ------------------------------------------------------------------ 号手指挥官（bugler_squad）
## 成套生成：号手在最前，其余的人排成每排 4 个跟在后面（下方 = 后面）。
static func _bugler_formation(leader: Monster, rest: Array) -> void:
	var bugler := leader as HornBugler
	for i in rest.size():
		var m: Monster = rest[i]
		if not TeamworkEffects._alive(m):
			continue
		m.set_meta("escort_of", leader)
		m.set_meta("escort_off", Vector2((i % 4 - 1.5) * 16.0, 20.0 + float(i / 4) * 16.0))
		if bugler:
			bugler.squad.append(m)


## 凑齐时碰到公主：号手吹一声，整组朝她围过去。
static func _bugler_call(members: Array, target: Variant) -> void:
	if not (target is PlayableCharacter) or not SiegeTools.alive(target):
		return
	for m in members:
		if TeamworkEffects._alive(m) and not (m is HornBugler):
			(m as Monster).rally_to(target)
