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


## 朝最近的那段城墙走；到墙下就停。
func march(m: Monster, delta: float) -> void:
	if director == null:
		return
	var foot: float = director.wall_foot_y()
	if m.global_position.y <= foot + 4.0:
		m.velocity = m.velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		return
	m._move(Vector2(drift, -1.0).normalized(), m.stats.chase_speed * 0.8, delta)
