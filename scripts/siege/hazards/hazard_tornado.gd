class_name HazardTornado
extends SiegeHazard
## 痒痒龙卷风：在战场上慢慢游走；卷到公主就把她卷起来转着圈挠（SPIN 秒），然后甩出去。
## 龙卷风卷怪（怪物 + 陷阱）：经过的小怪（最多 MAX_MOBS 只）也被卷进去一起转，过一会儿甩到公主身边；卷着公主时里面的怪也在挠。
## 陷阱组合：orbit_center 有值时绕着它转（双龙卷）；hidden_in（迷雾龙卷）时只在雾里游走、只看得到卷起的粉尘。

const RADIUS := 22.0
const SPEED := 34.0
const SPIN := 2.2

var _dir := Vector2.ZERO
var _turn := 0.0
const MAX_MOBS := 4
var orbit_center := Vector2.INF
var orbit_dir := 1.0
var hidden_in: Node2D
var _mobs: Array = []
var _mob_fling := 3.0
var _caught: PlayableCharacter
var _spin_left := 0.0
var _cool := {}


func _begin() -> void:
	reaction_key = "hazard_tornado"
	life = 18.0
	SiegeFx.ring(get_parent(), global_position, RADIUS * 1.6, Color(0.9, 0.6, 1.0, 0.8), WARN)


func _active(delta: float) -> void:
	_turn -= delta
	if _turn <= 0.0:
		_turn = randf_range(1.0, 2.5)
		var p := director.pink
		_dir = Vector2.from_angle(randf() * TAU)
		if p and randf() < 0.5:
			_dir = global_position.direction_to(p.global_position).rotated(randf_range(-0.6, 0.6))
	if orbit_center != Vector2.INF:
		var off := global_position - orbit_center
		global_position = orbit_center + off.rotated(orbit_dir * delta * 0.9).normalized() * maxf(off.length(), 60.0)
	elif hidden_in and is_instance_valid(hidden_in):
		global_position += _dir * SPEED * delta
		if global_position.distance_to(hidden_in.global_position) > HazardFog.RADIUS * 0.7:
			_dir = global_position.direction_to(hidden_in.global_position)
	else:
		global_position += _dir * SPEED * delta
	_mob_tick(delta)
	var ms := director.map_size()
	global_position = global_position.clamp(Vector2(40, director.wall_foot_y() + 40), ms - Vector2(40, 40))
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	if randf() < delta * 6.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), 0), "dust", 2, 50.0, 0.5, Vector2(0, -60), Color(0.9, 0.8, 1.0, 0.6))
	if randf() < delta * 4.0:
		Fx.burst(get_parent(), global_position + Vector2.from_angle(_t * 5.0) * 12.0 + Vector2(0, -14), "feather", 1, 40.0, 0.6, Vector2(0, -40))
	if _caught:
		_spin(delta)
		return
	for c in chars():
		if director.is_on_wall(c) or float(_cool.get(c.character_id, 0.0)) > 0.0:
			continue
		if c.global_position.distance_to(global_position) < RADIUS:
			_caught = c
			_spin_left = SPIN
			c.set_physics_process(false)
			SpeechBubble.say(c, "转、转起来了——！" if c.character_id == "pink" else "……转……转……", 28.0, 1.4)
			Audio.play("wind", -2.0, 0.1)
			break


func _spin(delta: float) -> void:
	var c := _caught
	if not is_instance_valid(c):
		_caught = null
		return
	_spin_left -= delta
	c.global_position = global_position + Vector2.from_angle(_t * 9.0) * 10.0 + Vector2(0, -6)
	if randf() < delta * 4.0:
		tickle(c, 5.0, ["waist", "armpit", "sole", "belly"].pick_random())
	# 卷在里面的怪也在挠
	for m in _mobs:
		if is_instance_valid(m) and randf() < delta * 2.0:
			c.receive_hit(HitData.make_tickle(m, 3.0))
	if _spin_left <= 0.0:
		_caught = null
		c.set_physics_process(true)
		c.apply_knockback(global_position, 280.0)
		_cool[c.character_id] = 3.0


## 卷怪：附近的小怪卷进来一起转，过一会儿甩到公主身边。
func _mob_tick(delta: float) -> void:
	_mobs = _mobs.filter(func(m): return is_instance_valid(m) and (m as Actor).is_alive())
	if _mobs.size() < MAX_MOBS:
		for m in director.enemies_near(global_position, RADIUS):
			if _mobs.size() >= MAX_MOBS:
				break
			if _mobs.has(m) or m.get_meta("siege_on_wall", false) or m.get_meta("airborne", false) or m.has_meta("in_ladder") or m is SiegeCart:
				continue
			_mobs.append(m)
			m.set_physics_process(false)
	for i in _mobs.size():
		var m: Node2D = _mobs[i]
		m.global_position = global_position + Vector2.from_angle(_t * 7.0 + i * TAU / maxf(_mobs.size(), 1)) * 14.0 + Vector2(0, -10 - i * 3)
	_mob_fling -= delta
	if _mob_fling <= 0.0 and not _mobs.is_empty():
		_mob_fling = 3.0
		_fling_mobs()


func _fling_mobs() -> void:
	var p := director.pink
	for m in _mobs:
		if not is_instance_valid(m):
			continue
		var to: Vector2 = (p.global_position if p and is_instance_valid(p) else global_position) + Vector2.from_angle(randf() * TAU) * 20.0
		var tw := (m as Node2D).create_tween()
		tw.tween_property(m, "global_position", to, 0.5)
		tw.tween_callback(func():
			if is_instance_valid(m):
				(m as Monster).set_physics_process(true)
				Fx.burst(m.get_parent(), (m as Node2D).global_position, "dust", 4, 30.0, 0.4, Vector2(0, 20)))
	_mobs.clear()


func _end() -> void:
	if _caught and is_instance_valid(_caught):
		_caught.set_physics_process(true)
	_caught = null
	_fling_mobs()
	super()


func _draw() -> void:
	if not warned:
		return
	# 地上的影子
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, RADIUS * 0.8, Color(0.2, 0.1, 0.25, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hidden_in and is_instance_valid(hidden_in):
		return  # 迷雾龙卷：只看得到卷起的粉尘
	for i in 5:
		var r := 6.0 + i * 4.0
		var y := -i * 7.0
		var a := _t * 8.0 + i
		draw_arc(Vector2(sin(a) * 2.0, y), r, 0.0, TAU, 20, Color(0.85, 0.75, 1.0, 0.55), 1.5)
