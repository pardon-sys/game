class_name SiegeMind
extends RefCounted
## 攻防战里怪物的「行军」大脑（Monster.mind）：没有目标时朝城墙走，走到墙下就停住（HitArea 碰到城墙就会自己攻击）。
## 每 THINK 秒（不是每帧）在 SiegeDirector 维护的目标表里找最近的活物（两位公主、小雪人、诱饵冰雕……）：
##   在 detect 范围内 → 锁定它（Monster 进入 CHASE），追丢了再回到行军。
## 屏幕外的怪：思考间隔拉长（FAR_THINK），不放动画（Monster 的 _animate 由导演关掉）。
## 子类（攻城车、钩索怪、爬墙壁虎……）重写 wander 做自己的行动。

const THINK := 0.35
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


## 朝城墙走（成套生成的小队有 march_x：奔同一段墙）；到墙下就停——旁边有活梯子的话顺着爬上去。
func march(m: Monster, delta: float) -> void:
	if director == null:
		return
	var foot: float = director.wall_foot_y()
	if m.global_position.y <= foot + 6.0:
		m.velocity = m.velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		var lad := LivingLadder.near(m.get_tree(), m.global_position.x)
		if lad and not (m is SiegeMonster and (m as SiegeMonster).climbing):
			climb_ladder(m, lad)
		return
	var dir := Vector2(drift, -1.0)
	if m.has_meta("march_x"):
		dir.x = clampf((float(m.get_meta("march_x")) - m.global_position.x) / 60.0, -1.0, 1.0)
	m._move(dir.normalized(), m.stats.chase_speed * 0.8, delta)


## 顺着活梯子爬上墙顶。
func climb_ladder(m: Monster, lad: LivingLadder) -> void:
	var to := Vector2(lad.global_position.x + randf_range(-6, 6), director.wall_top_y() + randf_range(-2, 6))
	m.set_physics_process(false)
	m.collision_mask = 0
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", to, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(m):
			m.set_physics_process(true)
			TeamworkEffects.put_on_wall(m, to))


## 墙顶上的通用行为：找蓝色公主挠，她不在墙上就从上面拆墙。
func wall_top(m: Monster, delta: float) -> void:
	if director == null:
		return
	if m is SiegeMonster:
		(m as SiegeMonster).wall_hunt(delta)
		return
	var b: PlayableCharacter = director.blue
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
