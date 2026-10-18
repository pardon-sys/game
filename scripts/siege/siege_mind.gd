class_name SiegeMind
extends RefCounted
## 攻防战里怪物的「行军」大脑（Monster.mind）：没有目标时朝城墙走，走到墙下就停住（HitArea 碰到城墙就会自己攻击）。
## 每 THINK 秒（不是每帧）在 SiegeDirector 维护的目标表里找最近的活物（两位公主、小雪人、诱饵冰雕……）：
##   在 detect 范围内 → 锁定它（Monster 进入 CHASE），追丢了再回到行军。
## 屏幕外的怪：思考间隔拉长（FAR_THINK），不放动画（Monster 的 _animate 由导演关掉）。
## 子类（攻城车、钩索怪、爬墙壁虎……）重写 wander 做自己的行动。

const THINK := 0.35
## 离墙脚还有这么远时才会换目标墙段（快到墙下就不换了）
const REPICK_Y := 140.0
const FAR_THINK := 0.9

var director: Node
var _think := randf() * THINK
## 行军时的横向偏移（大家不挤成一条线）
var drift := randf_range(-0.25, 0.25)


func _init(d: Node = null) -> void:
	director = d


## 先在某个地方转一会儿（从敌塔地基出来的怪：聚集起来才会搭敌塔）。
var hold_at := Vector2.ZERO
var hold_left := 0.0


func hold(at: Vector2, sec: float) -> void:
	hold_at = at
	hold_left = sec


## 返回 true = 这一帧的移动由它决定了。
func wander(m: Monster, delta: float) -> bool:
	# 被空投 / 在活梯子里：不动
	if m.get_meta("airborne", false) or m.has_meta("in_ladder"):
		return true
	# 已经在墙顶上（被扔上来 / 爬上来）：通用的墙顶行为
	if m.get_meta("siege_on_wall", false):
		wall_top(m, delta)
		return true
	# 护卫：跟着 leader（工兵、攻城车……），有公主靠近时照常打
	if m.has_meta("escort_of"):
		var lead: Variant = m.get_meta("escort_of")
		if lead != null and is_instance_valid(lead) and (lead as Actor).is_alive():
			_think -= delta
			if _think <= 0.0:
				_think = THINK
				var t0: Actor = director.nearest_target(m, m.stats.detect_range * 0.7) if director else null
				if t0:
					m.target = t0
					m.state = Monster.State.CHASE
					return true
			var goal: Vector2 = (lead as Node2D).global_position + m.get_meta("escort_off", Vector2.ZERO)
			var to := goal - m.global_position
			var lead_speed := (lead as CharacterBody2D).velocity.length() if lead is CharacterBody2D else 0.0
			var spd := maxf(m.stats.chase_speed, lead_speed * 1.15 + 12.0)
			if to.length() > 4.0:
				m.velocity = to.normalized() * spd * m.stat_mul("speed")
			else:
				m.velocity = (lead as CharacterBody2D).velocity if lead is CharacterBody2D else Vector2.ZERO
			return true
		m.remove_meta("escort_of")
	# 号手倒下后乱成一团：SCATTER 秒里乱走，之后重新挑墙段
	if m.has_meta("scatter_until"):
		if Time.get_ticks_msec() / 1000.0 < float(m.get_meta("scatter_until")):
			m._move(Vector2.from_angle(m._t * 2.3 + float(m.get_instance_id() % 7)), m.stats.wander_speed, delta)
			return true
		m.remove_meta("scatter_until")
		m.remove_meta("march_x")
	if hold_left > 0.0:
		hold_left -= delta
		var to := hold_at - m.global_position
		m._move(to.normalized() if to.length() > 28.0 else Vector2.from_angle(m._t), m.stats.wander_speed, delta)
		return true
	_think -= delta
	if _think <= 0.0:
		_think = THINK if director == null or director.on_screen(m.global_position) else FAR_THINK
		var t: Actor = director.nearest_target(m, m.stats.detect_range) if director else null
		if t:
			m.target = t
			m.state = Monster.State.CHASE
			return true
	march(m, delta)
	return true


## 朝城墙走：挑一个目标墙段 x（march_x，SiegeDirector.pick_weak_x：冰塔少、没加固、蓝色公主不在的墙段更容易被挑），
## 离墙还远时每 WEAK_GAP 秒重新挑一次（蓝色公主换墙段 / 新造了塔，怪群会跟着转向）；成套的小队（march_lock）共用一个 march_x。到墙下就停——旁边有活梯子的话顺着爬上去。路上被道具 / 塔挡住会自动绕开（avoid）。
func march(m: Monster, delta: float) -> void:
	if director == null:
		return
	var foot: float = director.wall_foot_y()
	# 墙脚有一条挡人的窄条（SiegeWall.FOOT_STRIP），走到它下面就算到了墙下
	if m.global_position.y <= foot + SiegeWall.FOOT_STRIP + 8.0:
		m.velocity = m.velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		var lad := LivingLadder.near(m.get_tree(), m.global_position.x)
		if lad and not (m is SiegeMonster and (m as SiegeMonster).climbing):
			climb_ladder(m, lad)
		return
	# 挑薄弱处：没定目标时挑一段墙；离墙还远的时候每 WEAK_GAP 秒按最新的薄弱分重新挑（成套的小队锁着不换）
	var now := Time.get_ticks_msec() / 1000.0
	var far := m.global_position.y - foot > REPICK_Y
	if not m.has_meta("march_x") or (far and not m.has_meta("march_lock") and now - float(m.get_meta("march_pick", -INF)) > SiegeDirector.WEAK_GAP):
		m.set_meta("march_x", director.pick_weak_x(m.global_position.x))
		m.set_meta("march_pick", now)
	# 附近有活梯子：快到墙下时改道去梯子那里（不然斜着走到墙下时多半差几步够不着）
	if m.global_position.y - foot < LivingLadder.ATTRACT_Y:
		var near_lad := LivingLadder.near(m.get_tree(), m.global_position.x, LivingLadder.ATTRACT_X)
		if near_lad:
			m.set_meta("march_x", near_lad.global_position.x)
	var dir := Vector2(0.0, -1.0)
	var dx := float(m.get_meta("march_x")) - m.global_position.x
	var dy := m.global_position.y - foot
	# 斜着走：剩下的横向距离按剩下的纵向距离分摊（离墙越近越要往目标 x 拐）
	dir.x = clampf(dx / maxf(dy * 0.8, 40.0), -1.2, 1.2) + drift * 0.3
	# 离墙很近时不探测（墙面本身是 world 层的砖，探到会以为被挡住）
	m._move(avoid(m, dir.normalized(), delta) if dy > LOOK + 10.0 else dir.normalized(), m.stats.chase_speed * 0.8, delta)


## 「触须」避障：前方 LOOK 像素有挡路的（world 层：道具、冰塔、敌塔、木桩……）就往两边较空的一侧拐，
## 记住拐的方向 TURN_KEEP 秒；被卡住（几乎没动）超过 STUCK 秒就换一边。远处的怪探测得稀一点。
const LOOK := 18.0
const TURN_KEEP := 1.0
const STUCK := 0.4
var _turn := 0.0
var _turn_t := 0.0
var _probe_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.INF


func avoid(m: Monster, dir: Vector2, delta: float) -> Vector2:
	_turn_t -= delta
	_probe_t -= delta
	# 卡住检测
	if _last_pos != Vector2.INF and m.global_position.distance_to(_last_pos) < 5.0 * delta:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = m.global_position
	if _stuck_t > STUCK:
		_stuck_t = 0.0
		_turn = -_turn if _turn != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		_turn_t = TURN_KEEP
	if _turn_t > 0.0 and _turn != 0.0:
		return dir.rotated(_turn * 1.1)
	if _probe_t > 0.0:
		return dir
	_probe_t = 0.15 if director.on_screen(m.global_position) else 0.5
	if not _blocked(m, dir):
		_turn = 0.0
		return dir
	for k in [0.7, 1.3, 2.0]:
		for side in [1.0, -1.0]:
			if not _blocked(m, dir.rotated(side * k)):
				_turn = side
				_turn_t = TURN_KEEP
				return dir.rotated(side * k)
	return dir


func _blocked(m: Monster, dir: Vector2) -> bool:
	var space := m.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(m.global_position + Vector2(0, -3), m.global_position + Vector2(0, -3) + dir * LOOK, 1)
	q.exclude = [m.get_rid()]
	return not space.intersect_ray(q).is_empty()


## 顺着活梯子爬上墙顶。
func climb_ladder(m: Monster, lad: LivingLadder) -> void:
	var to := Vector2(lad.global_position.x + randf_range(-6, 6), director.wall_top_y() + randf_range(-2, 6))
	m.set_physics_process(false)
	m.collision_mask = 0
	m.set_meta("ladder_of", lad)   # 爬的途中打梯子能打到它
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", to, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(m):
			m.remove_meta("ladder_of")
			m.set_physics_process(true)
			TeamworkEffects.put_on_wall(m, to))


## 墙顶上的通用行为：找蓝色公主挠，她不在墙上就从上面拆墙。
func wall_top(m: Monster, delta: float) -> void:
	if director == null:
		return
	if m is SiegeMonster:
		(m as SiegeMonster).wall_hunt(delta)
		return
	var b: PlayableCharacter = director.wall_target()
	if b and is_instance_valid(b) and b.is_alive() and not Downed.is_downed(b) and director.is_on_wall(b):
		m.target = b
		var d := b.global_position - m.global_position
		m._move(Vector2(d.x, d.y * 0.3).normalized(), m.stats.chase_speed, delta)
	else:
		m.velocity = m.velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		_wall_hit -= delta
		if _wall_hit <= 0.0:
			_wall_hit = m.stats.attack_cooldown
			var w: SiegeWall = director.segment_at(m.global_position.x)
			if w:
				w.take(float(m.stats.attack_damage) * SiegeWall.DAMAGE_MULT)


var _wall_hit := 0.0
