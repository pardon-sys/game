class_name SiegeCart
extends SiegeMonster
## 攻城痒痒车：从地图下边出来，地上先亮红色预警线（WARN 秒），然后沿直线加速撞向城墙——
## 城墙大扣血（IMPACT），撞到的那一段墙上的蓝色公主被震下城墙；路线附近有诱饵冰雕时改撞冰雕（撞碎自己）。
## 寒霜塔 / 冰晶结界能让它变慢 / 停下；不吃击退。路上撞到粉色公主：撞开 + 挠一下。

const WARN := 1.4
const TOP_SPEED := 150.0
const ACCEL := 90.0
const IMPACT := 220.0
const LURE_PATH := 160.0

var _phase := "warn"
var _warn_t := WARN
var _speed := 0.0
var _goal := Vector2.ZERO
var _hit_pink := false


func _setup() -> void:
	super()
	knockback_resist = 1.0
	set_meta("siege_alert", true)


## 攻城车护卫阵：车前（靠城墙那边）有活着的盾甲螃蟹时，从前面 / 上面来的攻击打不到车。
func block_hit(hit: HitData) -> bool:
	if hit.source == null or not is_instance_valid(hit.source) or not (hit.source is Node2D):
		return false
	if (hit.source as Node2D).global_position.y >= global_position.y - 6.0:
		return false
	for g in get_meta("escorts", []):
		if g != null and is_instance_valid(g) and (g as Actor).is_alive() and (g as Node2D).global_position.y < global_position.y \
				and (g as Node2D).global_position.distance_to(global_position) < 34.0:
			Fx.burst(get_parent(), (g as Node2D).global_position + Vector2(0, -10), "chip", 4, 40.0, 0.3, Vector2(0, 40), Color(1, 0.9, 0.5))
			return true
	return false


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if director == null:
		return true
	match _phase:
		"warn":
			if _warn_t == WARN:
				_goal = _pick_goal()
				SiegeFx.lane(get_parent(), global_position, _goal, 18.0, Color(1, 0.3, 0.3), WARN)
				Audio.play("cart_rumble", -3.0)
			_warn_t -= delta
			velocity = Vector2.ZERO
			if _warn_t <= 0.0:
				_phase = "charge"
		"charge":
			_speed = minf(TOP_SPEED, _speed + ACCEL * delta)
			# 车轮扬尘拖尾、车身颠
			if randf() < delta * 14.0:
				Fx.burst(get_parent(), global_position + Vector2(randf_range(-12, 12), 2), "dust", 2, 25.0, 0.6, Vector2(0, 10), Color(0.75, 0.65, 0.55))
			if sprite:
				sprite.position.y = -absf(sin(_t * 22.0)) * 1.5
			var dir := global_position.direction_to(_goal)
			velocity = dir * _speed * stat_mul("speed")
			var p := director.pink
			if not _hit_pink and p and is_instance_valid(p) and p.global_position.distance_to(global_position) < 16.0:
				_hit_pink = true
				p.apply_knockback(global_position, 280.0)
				p.receive_hit(HitData.make_tickle(self, 10.0))
			if global_position.distance_to(_goal) < 10.0 or global_position.y <= director.wall_foot_y() + 6.0:
				_impact()
	return true


func _pick_goal() -> Vector2:
	for t in director.extra_targets:
		if is_instance_valid(t) and t is IceTower and (t as IceTower).kind == "decoy" and absf(t.global_position.x - global_position.x) < LURE_PATH:
			return t.global_position
	return Vector2(global_position.x, director.wall_foot_y() + 4.0)


func _impact() -> void:
	_phase = "done"
	var hit_decoy := false
	for t in director.extra_targets:
		if is_instance_valid(t) and t is IceTower and t.global_position.distance_to(global_position) < 24.0:
			(t as IceTower).receive_hit(HitData.make_attack(self, 40, 0.0))
			hit_decoy = true
	if not hit_decoy:
		var w := director.segment_at(global_position.x)
		if w:
			w.take(IMPACT)
		var b := director.blue
		if b and is_instance_valid(b) and director.is_on_wall(b) and absf(b.global_position.x - global_position.x) < 90.0:
			director.knock_off(b, "攻城痒痒车")
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "dust", 24, 90.0, 0.8, Vector2(0, 30), Color(0.8, 0.7, 0.6))
	# 冲击波圆环
	var ring := SiegeFx.ring(get_parent(), global_position + Vector2(0, -4), 14.0, Color(1, 0.85, 0.6, 0.9), 0.5, 0.1)
	if ring:
		ring.create_tween().tween_property(ring, "scale", Vector2(4, 2.5), 0.45)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "chip", 14, 80.0, 0.7, Vector2(0, 120), Color(0.6, 0.4, 0.3))
	Audio.play("wall_crash", 0.0)
	if director.on_screen(global_position):
		SiegeFx.screen_shake(self, 4.0, 0.45)
	health.damage(health.hp)
