class_name HazardMushrooms
extends SiegeHazard
## 弹弹蘑菇阵：一串 COUNT 颗弹弹蘑菇从地里冲出来，排成一条从公主附近通向怪堆的路（每颗离上一颗 STEP 像素）。
## 踩到一颗就被弹到下一颗（force_move「bounce」，在空中，落地才算），连弹几次，最后一颗把人弹进怪堆；
## 每弹一下蘑菇帽喷出羽毛孢子挠一下（粉色公主挠脚心，蓝色公主挠大腿 / 屁股）。弹完这一个人 COOL 秒内不会再被弹。
## 怪踩到也会一颗接一颗被弹到路的尽头，最后一颗把怪弹上城墙顶（第十轮）。
## 吸附：每颗蘑菇把 PULL_R 以内的公主和可推动的怪往帽上吸（冲刺时挣得开）。来源键 hazard_mushroom。

const COUNT := 9
const STEP := 64.0
const MAX_TURNS := 2
const TRIGGER := 12.0
const HOP_TIME := 0.42
const TICKLE := 4.0
const COOL := 4.0
## 吸附：蘑菇帽外一圈一个格子（PULL_R）以内的公主 / 怪往最近的蘑菇帽上吸，吸力很大（走路挣不开，冲刺挣得开）
const PULL_R := TRIGGER + 16.0
const PULL := 360.0
const MOB_PULL := 300.0

var caps: Array[Vector2] = []
var _cool := {}
var _bouncing := {}
## 测试用：弹完整条路（最后一颗把它弹上城墙）的怪有几只
var launched_to_wall := 0
var _pop := []


func _begin() -> void:
	reaction_key = "hazard_mushroom"
	life = 12.0
	_layout()
	# 第一颗蘑菇在 danger 组里（AI 绕开，别自己踩上去）
	add_to_group("danger")
	set_meta("radius", TRIGGER + 2.0)
	for p in caps:
		SiegeFx.ring(get_parent(), p, 12.0, Color(1, 0.55, 0.7, 0.8), WARN)
	Audio.play("pop", -4.0, 0.1, 0.8)


## 路线：从这里出发，朝怪最多的地方一颗一颗排过去（没有怪就朝城墙那边）。
func _layout() -> void:
	caps.clear()
	var start := global_position
	var crowd: Variant = director.densest(60.0, start, 700.0)
	var dir: Vector2 = start.direction_to(crowd) if crowd is Vector2 and (crowd as Vector2).distance_to(start) > 40.0 else Vector2(randf_range(-0.6, 0.6), -1).normalized()
	# 一颗接一颗往前排；快出地图 / 撞到城墙脚时朝地图中间拐弯（最多拐 MAX_TURNS 次）
	var p := start
	var turns := 0
	var center := director.map_size() / 2.0
	for i in COUNT:
		if i > 0:
			var next := p + dir.rotated(sin(i * 1.3) * 0.35) * STEP
			var fixed := director.clamp_in_map(next)
			fixed.y = maxf(fixed.y, director.wall_foot_y() + 50.0)
			if fixed.distance_to(next) > 1.0 and turns < MAX_TURNS:
				turns += 1
				var to_center := p.direction_to(center)
				dir = dir.rotated(PI / 2.0 if dir.rotated(PI / 2.0).dot(to_center) > 0.0 else -PI / 2.0)
				next = p + dir * STEP
				fixed = director.clamp_in_map(next)
				fixed.y = maxf(fixed.y, director.wall_foot_y() + 50.0)
			p = fixed
		caps.append(p - global_position)
	_pop.resize(COUNT)
	_pop.fill(0.0)


func _on_start() -> void:
	for i in caps.size():
		Fx.burst(get_parent(), global_position + caps[i], "dust", 6, 30.0, 0.4, Vector2(0, 30), Color(0.8, 0.6, 0.5))


func _active(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	for i in _pop.size():
		_pop[i] = maxf(0.0, float(_pop[i]) - delta)
	for c in chars():
		var id := c.get_instance_id()
		if _bouncing.has(id) or director.is_on_wall(c) or float(_cool.get(id, 0.0)) > 0.0 or not SiegeTools.can_move(null, c) or c.is_airborne():
			continue
		var bounced := false
		for i in caps.size():
			if (global_position + caps[i]).distance_to(c.global_position) <= TRIGGER:
				_bounce(c, i)
				bounced = true
				break
		# 吸附：冲刺时挣得开
		if not bounced and c.state != PlayableCharacter.State.DASH:
			_suck(c, PULL)
	for m in director.enemies_near(global_position + caps[caps.size() / 2], STEP * COUNT * 0.6 + PULL_R):
		if not SiegeTools.displaceable(m) or m.has_meta("siege_mushroom_hop"):
			continue
		var hopped := false
		for i in caps.size():
			if (global_position + caps[i]).distance_to(m.global_position) <= TRIGGER:
				_hop_mob(m, i)
				hopped = true
				break
		if not hopped:
			_suck(m, MOB_PULL)


## 把 a 往最近的蘑菇帽吸（PULL_R 以内，越近越强）。返回吸没吸。
func _suck(a: Actor, strength: float) -> bool:
	var best := Vector2.INF
	var best_d := PULL_R
	for cap in caps:
		var at := global_position + cap
		var dist := at.distance_to(a.global_position)
		if dist < best_d:
			best_d = dist
			best = at
	if best == Vector2.INF:
		return false
	a.add_push(a.global_position.direction_to(best) * strength * (1.3 - best_d / PULL_R))
	return true


## 公主：从第 i 颗弹到下一颗，一直弹到最后，最后一颗弹进怪堆。
func _bounce(c: PlayableCharacter, i: int) -> void:
	var id := c.get_instance_id()
	_bouncing[id] = true
	var wr: WeakRef = weakref(self)
	var cr: WeakRef = weakref(c)
	var hits := 0
	for k in range(i, caps.size()):
		var me := wr.get_ref() as HazardMushrooms
		var who := cr.get_ref() as PlayableCharacter
		if me == null or not SiegeTools.alive(who) or not who.can_be_moved():
			break
		var from := who.global_position
		var to: Vector2 = me.global_position + me.caps[k + 1] if k + 1 < me.caps.size() else me._landing(from)
		me._pop[k] = 0.3
		Audio.play("pop", -4.0, 0.1, 1.0 + k * 0.08)
		Fx.burst(me.get_parent(), me.global_position + me.caps[k] + Vector2(0, -6), "feather", 5, 40.0, 0.5, Vector2(0, 30), Color(1, 0.8, 0.9))
		me.tickle(who, TICKLE, SiegeTools.zone(who, hits))
		hits += 1
		if not who.force_move((to - from) / HOP_TIME, HOP_TIME, "bounce"):
			break
		await me.get_tree().create_timer(HOP_TIME + 0.05, false).timeout
	var me2 := wr.get_ref() as HazardMushrooms
	if me2:
		me2._bouncing.erase(id)
		me2._cool[id] = COOL


## 最后一颗：弹进怪最多的地方（没有怪就再往前一步）。
func _landing(from: Vector2) -> Vector2:
	var crowd: Variant = director.densest(50.0, from, 260.0)
	var to: Vector2 = crowd if crowd is Vector2 else from + (caps[-1] - caps[-2]).normalized() * STEP
	to = director.clamp_in_map(to)
	to.y = maxf(to.y, director.wall_foot_y() + 30.0)
	return to


## 怪：一颗接一颗弹到路的尽头，最后一颗把它弹上城墙顶（那段墙上不去就落在最后一颗旁边）。
func _hop_mob(m: Monster, i: int) -> void:
	m.set_meta("siege_mushroom_hop", true)
	_pop[i] = 0.3
	if i >= caps.size() - 1:
		if not SiegeHazard.fling_to_wall(m, 0.7, 90.0):
			SiegeHazard.fling_to(m, global_position + caps[i] + Vector2(randf_range(-20, 20), -30), HOP_TIME, 30.0)
		m.remove_meta("siege_mushroom_hop")
		launched_to_wall += 1
		return
	var wr: WeakRef = weakref(self)
	var mr: WeakRef = weakref(m)
	TeamworkEffects._arc(m, global_position + caps[i + 1], HOP_TIME, 26.0, func():
		var me := wr.get_ref() as HazardMushrooms
		var mob := mr.get_ref() as Monster
		if mob == null:
			return
		if me and me.is_processing() and TeamworkEffects._alive(mob):
			me._hop_mob(mob, i + 1)
		else:
			mob.remove_meta("siege_mushroom_hop"))


func _draw() -> void:
	for i in caps.size():
		var p := caps[i]
		var squash := 1.0 - float(_pop[i]) * 1.5 if i < _pop.size() else 1.0
		var rise := 1.0 if warned else 0.4
		if warned:
			# 吸附圈：淡粉色、往里转的旋涡
			draw_set_transform(p, 0.0, Vector2(1, 0.55))
			draw_circle(Vector2.ZERO, PULL_R, Color(1, 0.45, 0.75, 0.16))
			for k in 2:
				var a0 := -_t * (3.0 + k) + k * PI
				draw_arc(Vector2.ZERO, PULL_R * (0.55 + 0.4 * k), a0, a0 + 2.2, 14, Color(1, 0.5, 0.8, 0.55), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 蘑菇柄 + 蘑菇帽（踩到时压扁一下）
		draw_rect(Rect2(p + Vector2(-3, -8 * rise), Vector2(6, 8 * rise)), Color(0.98, 0.92, 0.85))
		draw_set_transform(p + Vector2(0, -9 * rise), 0.0, Vector2(1.0 / maxf(squash, 0.5), squash))
		draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.35, 0.5))
		draw_circle(Vector2(-4, -2), 2.0, Color(1, 0.9, 0.95))
		draw_circle(Vector2(3, -4), 1.5, Color(1, 0.9, 0.95))
		draw_circle(Vector2(4, 1), 1.5, Color(1, 0.9, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if i + 1 < caps.size() and warned:
			# 弹跳路线的虚线
			var a := p + Vector2(0, -10)
			var b := caps[i + 1] + Vector2(0, -10)
			for k in 6:
				var t0 := k / 6.0
				var mid := a.lerp(b, t0 + 0.04) + Vector2(0, -sin((t0 + 0.04) * PI) * 18.0)
				draw_circle(mid, 1.0, Color(1, 0.75, 0.85, 0.5))
