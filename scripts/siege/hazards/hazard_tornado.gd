class_name HazardTornado
extends SiegeHazard
## 痒痒龙卷风：在战场上慢慢游走；卷到公主就把她卷起来转着圈挠（SPIN 秒），然后甩出去。
## 龙卷风卷怪（怪物 + 陷阱）：经过的小怪（最多 MAX_MOBS 只）也被卷进去一起转，过一会儿甩到公主身边；卷着公主时里面的怪也在挠。
## 陷阱组合：orbit_center 有值时绕着它转（双龙卷）；hidden_in（迷雾龙卷）时只在雾里游走、只看得到卷起的粉尘。

const RADIUS := 36.0   # 第三轮放大（原来 22）
const SPEED := 34.0
const SPIN := 2.2

## 召唤者模式（例：狂风熊统领的八向龙卷）：owner_ref 指向放出它的怪（要有 _targets() 和 strike(目标, 量, 变体, 击退, 来源点)），
## 沿 wind_direction 直线吹过去、不抓人、每 0.5 秒挠一下范围里的人；召唤者没了就消失。颜色 tint、台词来源 owner_key。
## 没设 owner_ref 时是原来的游走 / 抓取龙卷风。
var owner_ref: WeakRef
var owner_key := ""
var tint := Color(0.85, 0.75, 1.0, 0.55)
var wind_direction := Vector2.ZERO
var radius := RADIUS
var active := true
var _travel := 0.0
var _wind_tick := 0.0
var _stopped := false

var _dir := Vector2.ZERO
var _turn := 0.0
const MAX_MOBS := 6
var orbit_center := Vector2.INF
var orbit_dir := 1.0
var hidden_in: Node2D
var _mobs: Array = []
var _mob_fling := 3.0
var _caught: PlayableCharacter
var _spin_left := 0.0
var _cool := {}
var _last_safe := Vector2.ZERO
var _caught_on_wall := false
var _owned_physics := true


func _begin() -> void:
	if owner_ref:
		reaction_key = owner_key
		radius = 24.0
		life = 9.5
		_warn_left = 0.0
		warned = true
		add_to_group("trap")
		add_to_group("magic_reactive")
		add_to_group("danger")
		set_meta("radius", radius)
		set_meta("velocity", wind_direction * 110.0)
		return
	reaction_key = "hazard_tornado"
	life = 18.0
	SiegeFx.ring(get_parent(), global_position, RADIUS * 1.6, Color(0.9, 0.6, 1.0, 0.8), WARN)


func _active(delta: float) -> void:
	if owner_ref:
		_wind_active(delta)
		return
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
		if director.is_on_wall(c) or float(_cool.get(c.character_id, 0.0)) > 0.0 or not SiegeTools.can_move(null, c):
			continue
		if c.global_position.distance_to(global_position) < RADIUS:
			if not c.status.grab(self, SPIN + 0.5, 16):
				continue
			_caught = c
			_last_safe = c.global_position
			_caught_on_wall = director.is_on_wall(c)
			_owned_physics = c.is_physics_processing()
			c.set_meta("siege_tornado_owner", self)
			_spin_left = SPIN
			c.set_physics_process(false)
			SpeechBubble.say(c, "转、转起来了——！" if c.character_id == "pink" else "……转……转……", 28.0, 1.4)
			Audio.play("wind", -2.0, 0.1)
			break


func _spin(delta: float) -> void:
	var c := _caught
	if not SiegeTools.alive(c) or not c.status.is_grabbed_by(self):
		_release_caught()
		return
	_spin_left -= delta
	# 保持角色真实碰撞，旋转目标落进墙／塔时只移动到接触面。
	var goal := global_position + Vector2.from_angle(_t * 9.0) * 10.0 + Vector2(0, -6)
	c.move_and_collide((goal - c.global_position).limit_length(180.0 * delta))
	var safe := SiegeTools.safe_spot(c, c.global_position)
	if safe != Vector2.INF:
		_last_safe = safe
	if randf() < delta * 4.0:
		tickle(c, 5.0, ["waist", "armpit", "sole", "belly"].pick_random())
	for m in _mobs:
		if is_instance_valid(m) and randf() < delta * 2.0:
			c.receive_hit(HitData.make_tickle(m, 3.0))
	if _spin_left <= 0.0:
		_release_caught(true)


func _release_caught(fling := false) -> void:
	var c := _caught
	_caught = null
	if not is_instance_valid(c):
		return
	if c.get_meta("siege_tornado_owner", null) != self:
		return
	c.remove_meta("siege_tornado_owner")
	var at := c.global_position
	if is_instance_valid(director):
		at.y = minf(at.y, director.wall_top_y()) if _caught_on_wall else maxf(at.y, director.wall_foot_y() + 24.0)
	var safe := SiegeTools.safe_spot(c, at)
	c.global_position = safe if safe != Vector2.INF else _last_safe
	if c.status and c.status.is_grabbed_by(self):
		c.status.release(false)
	c.velocity = Vector2.ZERO
	c.set_physics_process(_owned_physics)
	_cool[c.character_id] = 3.0
	if fling and SiegeTools.alive(c):
		c.apply_knockback(global_position, 280.0)


func _exit_tree() -> void:
	_release_caught()
	for m in _mobs:
		if is_instance_valid(m):
			m.set_physics_process(true)
	_mobs.clear()


## 卷怪：附近的小怪卷进来一起转，过一会儿甩到公主身边。
func _mob_tick(delta: float) -> void:
	_mobs = _mobs.filter(func(m): return is_instance_valid(m) and (m as Actor).is_alive())
	if _mobs.size() < MAX_MOBS:
		for m in director.enemies_near(global_position, RADIUS):
			if _mobs.size() >= MAX_MOBS:
				break
			if _mobs.has(m) or not SiegeTools.displaceable(m):
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
	active = false
	if is_in_group("danger"):
		remove_from_group("danger")
	if not is_processing():
		return
	_release_caught()
	_fling_mobs()
	super()


func _draw() -> void:
	if not warned:
		return
	# 地上的影子
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, radius * 0.8, Color(0.2, 0.1, 0.25, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hidden_in and is_instance_valid(hidden_in):
		return  # 迷雾龙卷：只看得到卷起的粉尘
	SiegeFx.draw_tornado(self, Vector2.ZERO, radius, _t, tint, owner_ref != null)


func _process(delta: float) -> void:
	if director == null or director.state not in ["fight", "prep"]:
		_end()
		return
	if SiegeTools.paused():
		return
	if owner_ref:
		var summoner: Variant = owner_ref.get_ref()
		if not SiegeTools.alive(summoner) or director == null or director.state != "fight":
			_end()
			return
		if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
			return
	super(delta)


func _wind_active(delta: float) -> void:
	if not active:
		set_meta("velocity", Vector2.ZERO)
		if is_in_group("danger"):
			remove_from_group("danger")
		return
	if not is_in_group("danger"):
		add_to_group("danger")
	_travel += delta
	if _travel <= 6.0 and not _stopped:
		var next := global_position + wind_direction * 110.0 * delta
		var bound := next.clamp(Vector2(radius, director.wall_foot_y() + radius), director.map_size() - Vector2.ONE * radius)
		_stopped = not next.is_equal_approx(bound)
		global_position = bound
	set_meta("velocity", Vector2.ZERO if _stopped or _travel > 6.0 else wind_direction * 110.0)
	_wind_tick -= delta
	if _wind_tick <= 0.0:
		_wind_tick = 0.5
		var summoner: Variant = owner_ref.get_ref()
		if SiegeTools.alive(summoner):
			for a in summoner.call("_targets"):
				if a.global_position.distance_to(global_position) <= radius:
					summoner.call("strike", a, 6.0, "tornado", 0.0, global_position)
	if director.on_screen(global_position) and randf() < delta * 4.0:
		Fx.burst(get_parent(), global_position + Vector2(0, -12), "feather", 1, 35.0, 0.5, Vector2(0, -30))


func on_magic_burst(tier: int, _caster: Node) -> void:
	if owner_ref and tier >= 3:
		_end()
