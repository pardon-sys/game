class_name Snowman
extends Actor
## 雪人召唤塔放出来的小雪人（友军）：走向最近的怪，碰到就挠 / 推它一下（小伤害 + 击退）；有血量，LIFE 秒后自己化掉。
## 是怪物的目标之一（SiegeDirector.extra_targets），能帮公主分担火力。

const SPEED := 46.0
const LIFE := 30.0
const RANGE := 240.0

var hp := 4
var _life := LIFE
var _hit_cd := 0.0
var _spr: Sprite2D
var _anim := 0.0
var _home := Vector2.ZERO
var _idle_t := 0.0
var _idle_dir := Vector2.ZERO


func _setup() -> void:
	set_faction(Faction.Type.ALLY)
	add_to_group("siege_temp")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	shape.shape = c
	add_child(shape)
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = hp
	add_child(hc)
	health = hc
	hc.fill()
	hc.died.connect(_die)
	_spr = Sprite2D.new()
	_spr.texture = IceTower.TEX
	_spr.region_enabled = true
	_spr.region_rect = IceTower.region("snowman_0")
	_spr.offset = Vector2(0, -8)
	add_child(_spr)
	hurt_invuln_time = 0.4
	_home = global_position
	(func(): _home = global_position).call_deferred()


func _tick(delta: float) -> void:
	_life -= delta
	_hit_cd -= delta
	_anim += delta
	if _life <= 0.0:
		_melt()
		return
	var d := SiegeDirector.current
	if d == null:
		return
	var best: Monster = null
	var best_d := RANGE
	for m in d.enemies_near(global_position, RANGE, false):
		var dist := global_position.distance_to(m.global_position)
		if dist < best_d:
			best_d = dist
			best = m
	if best == null:
		# 没有怪：在出生的地方附近随机走
		_idle_t -= delta
		if _idle_t <= 0.0:
			_idle_t = randf_range(1.5, 3.0)
			_idle_dir = Vector2.ZERO if randf() < 0.15 else Vector2.from_angle(randf() * TAU)
			if global_position.distance_to(_home) > 50.0:
				_idle_dir = global_position.direction_to(_home)
		velocity = _idle_dir * SPEED * 0.5
		# 撞到东西（冰塔、墙脚）走不动：马上换个方向
		if _idle_dir != Vector2.ZERO and get_real_velocity().length() < 2.0 and _idle_t < 1.2:
			_idle_t = 0.0
	else:
		velocity = global_position.direction_to(best.global_position) * SPEED
		if best_d < 14.0 and _hit_cd <= 0.0:
			_hit_cd = 1.0
			best.receive_hit(HitData.make_attack(self, 1, 90.0))
			Fx.burst(get_parent(), best.global_position + Vector2(0, -8), "snow", 4, 30.0, 0.4, Vector2(0, 30))
	velocity *= stat_mul("speed")
	move_with_push()
	_spr.region_rect = IceTower.region("snowman_%d" % (int(_anim * 4.0) % 2 if velocity != Vector2.ZERO else 0))


func _melt() -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "snow", 8, 30.0, 0.6, Vector2(0, 40))
	queue_free()


func _on_died() -> void:
	_melt()
