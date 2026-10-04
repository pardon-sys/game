class_name BossLimb
extends CharacterBody2D
## 千手痒痒魔下来的手臂（阶段三献祭时伸到场地里）：从天花板垂下来的一串臂段 + 手掌，挨打时把伤害转给本体（ThousandHand.apply_hit）。
## 每隔一阵子朝身边的人抓挠一下（砸地预警），不能一直站着贴脸打。导演在献祭结束时 retract() 收回。

const ARM := preload("res://assets/generated/thousand_hand_arm.png")

var boss: ThousandHand
var faction := Faction.Type.ENEMY
var hand := 2
var _t := 0.0
var _swipe_cd := 2.5
var _flash := 0.0
var _gone := false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss_limb")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	shape.shape = c
	shape.position = Vector2(0, -8)
	add_child(shape)
	z_index = 3
	set_meta("hit_radius", 8.0)
	_t = randf() * TAU
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func is_alive() -> bool:
	return not _gone and is_instance_valid(boss) and boss.is_alive()


func receive_hit(hit: HitData) -> bool:
	if not is_alive() or not is_instance_valid(boss):
		return false
	var ok := boss.apply_hit(hit)
	if ok:
		_flash = 0.12
		Fx.burst(get_parent(), global_position + Vector2(0, -8), "dust", 3, 30.0, 0.3)
	return ok


func retract() -> void:
	_gone = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if not _gone and is_instance_valid(boss) and not GameState.in_dialogue:
		_swipe_cd -= delta
		if _swipe_cd <= 0.0:
			_swipe_cd = randf_range(2.2, 3.2)
			for m in Duo.members:
				if is_instance_valid(m) and m.is_alive() and m.global_position.distance_to(global_position) < 40.0:
					boss.begin_slam(m.global_position)
					break
	queue_redraw()


func _draw() -> void:
	var tip := Vector2(sin(_t * 2.3) * 4.0, -8.0)
	var top := Vector2(tip.x * 0.3, -150.0)
	var n := 16
	for i in n:
		var p := top.lerp(tip, float(i) / n) + Vector2(sin(_t * 3.0 + i * 0.5) * 3.0, 0)
		draw_texture_rect_region(ARM, Rect2(p - Vector2(12, 12), Vector2(24, 24)), Rect2((i % 2) * 24, 0, 24, 24))
	var f := hand + int(_t * 8.0) % 2
	var col := Color(1.6, 1.6, 1.6) if _flash > 0.0 else Color.WHITE
	draw_texture_rect_region(ARM, Rect2(tip - Vector2(12, 12), Vector2(24, 24)), Rect2(f * 24, 0, 24, 24), col)
