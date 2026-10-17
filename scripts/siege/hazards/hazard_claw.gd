class_name HazardClaw
extends SiegeHazard
## 天降抓娃娃机：一个巨大的机械爪从天上降下来。
##   1. 追：地上的影子跟着目标（粉色公主；蓝色公主在墙上时也可能是她）HUNT 秒（影子在 danger 组里，AI 会躲）；
##   2. 落：爪子落下 DROP 秒，影子里的人被抓住（status.grab，连按 BREAK_PRESSES 下挣脱）；没抓到就收回去；
##   3. 运：吊起来运到怪最多的地方（director.densest），路上爪子内侧的刷子一直挠（粉色公主刮脚心，蓝色公主刷大腿 / 屁股）；
##      挣脱了就当场掉下来；墙顶的蓝色公主被抓下城墙；
##   4. 放：在怪堆里松开（轻轻弹一下），这一个人 COOL 秒内不会再被抓。
## 没抓到公主时改抓一把怪（最多 MOB_CARGO 只），运到城墙顶（蓝色公主在墙上时）或粉色公主头顶扔下（第十轮）。
## 来源键 hazard_claw。

const HUNT := 1.6
const DROP := 0.4
const CARRY := 2.6
const RADIUS := 28.0
const HUNT_SPEED := 70.0
const BREAK_PRESSES := 14
const TICKLE_GAP := 0.35
const TICKLE := 5.0
const COOL := 5.0
const HEIGHT := 70.0
const MOB_CARGO := 5
const MOB_CARRY := 1.6

var phase := "hunt"
var target: PlayableCharacter
var caught: PlayableCharacter
var _phase_t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _lift := 0.0
var _tick := 0.0
var _hits := 0
var _owned_physics := true
var _cool := {}
var _mob_cargo: Array = []
var _cargo_to_wall := false
## 测试用：运过去扔下的怪有几只
var dropped_mobs := 0


func _begin() -> void:
	reaction_key = "hazard_claw"
	life = HUNT + DROP + maxf(CARRY, MOB_CARRY) + 2.0
	_pick_target()
	if target:
		global_position = target.global_position
	add_to_group("danger")
	set_meta("radius", RADIUS)
	Audio.play("cart_rumble", -6.0, 0.1, 1.6)


func _pick_target() -> void:
	var options: Array[PlayableCharacter] = []
	for c in chars():
		if float(_cool.get(c.character_id, 0.0)) <= 0.0 and SiegeTools.can_move(null, c):
			options.append(c)
	if options.is_empty():
		target = null
		return
	var pink := director.pink
	target = pink if options.has(pink) and randf() < 0.7 else options.pick_random()


func _process(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	# 预警阶段（父类）里影子就开始追
	if not warned and SiegeTools.alive(target) and not SiegeTools.paused():
		global_position = global_position.move_toward(target.global_position, HUNT_SPEED * delta)
	super(delta)


func _active(delta: float) -> void:
	_phase_t += delta
	match phase:
		"hunt":
			if not SiegeTools.alive(target):
				_pick_target()
			if target:
				global_position = global_position.move_toward(target.global_position, HUNT_SPEED * delta)
			if _phase_t >= HUNT:
				_set_phase("drop")
		"drop":
			_lift = HEIGHT * (1.0 - _phase_t / DROP)
			if _phase_t >= DROP:
				_lift = 0.0
				_try_grab()
		"carry":
			_carry(delta)
		"carry_mobs":
			_carry_mobs()
		"rise":
			_lift = HEIGHT * minf(1.0, _phase_t / 0.6)
			if _phase_t >= 0.6:
				_end()


func _set_phase(p: String) -> void:
	phase = p
	_phase_t = 0.0
	if p != "hunt" and is_in_group("danger"):
		remove_from_group("danger")


func _try_grab() -> void:
	SiegeFx.impact(get_parent(), global_position, 26.0, false, Color(1, 0.85, 0.5))
	Audio.play("hit", -4.0, 0.1, 0.7)
	for c in chars():
		if c.global_position.distance_to(global_position) > RADIUS or not SiegeTools.can_move(null, c) or float(_cool.get(c.character_id, 0.0)) > 0.0:
			continue
		if not c.status.grab(self, CARRY + 1.0, BREAK_PRESSES):
			continue
		caught = c
		_owned_physics = c.is_physics_processing()
		c.set_physics_process(false)
		c.set_meta("siege_claw_owner", self)
		_from = global_position
		var crowd: Variant = director.densest(60.0, global_position, 600.0)
		var goal: Vector2 = crowd if crowd is Vector2 else global_position + Vector2(randf_range(-200, 200), 160)
		_to = director.clamp_in_map(goal)
		_to.y = maxf(_to.y, director.wall_foot_y() + 40.0)
		SpeechBubble.say(c, "被、被抓起来了——放我下来！" if c.character_id == "pink" else "……吊、吊起来了。", 28.0, 1.4)
		Audio.play("swish", -3.0, 0.1, 0.8)
		_set_phase("carry")
		return
	# 没抓到公主：抓起一把怪，运到城墙顶（蓝色公主在墙上时）或粉色公主头顶扔下
	_grab_mobs()


func _carry(delta: float) -> void:
	var c := caught
	if not SiegeTools.alive(c) or not c.status.is_grabbed_by(self):
		# 挣脱了：当场掉下来
		_drop(false)
		return
	var k := clampf(_phase_t / CARRY, 0.0, 1.0)
	_lift = HEIGHT * sin(minf(k * 2.0, 1.0) * PI * 0.5) * (1.0 if k < 0.85 else (1.0 - k) / 0.15)
	global_position = _from.lerp(_to, k)
	c.global_position = global_position + Vector2(0, -_lift * 0.5)
	if c.sprite:
		c.sprite.position.y = -_lift * 0.5
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICKLE_GAP
		tickle(c, TICKLE, SiegeTools.zone(c, _hits))
		_hits += 1
		Fx.burst(get_parent(), c.global_position + Vector2(0, -6), "bristle", 3, 25.0, 0.3, Vector2(0, 30))
	if k >= 1.0:
		_drop(true)


func _grab_mobs() -> void:
	_mob_cargo.clear()
	for m in director.enemies_near(global_position, RADIUS + 16.0):
		if _mob_cargo.size() >= MOB_CARGO:
			break
		if SiegeTools.displaceable(m):
			_mob_cargo.append(m)
			m.set_physics_process(false)
	if _mob_cargo.is_empty():
		_set_phase("rise")
		return
	_from = global_position
	var blue := director.blue
	_cargo_to_wall = SiegeTools.alive(blue) and director.is_on_wall(blue) and randf() < 0.6
	if _cargo_to_wall:
		_to = Vector2(blue.global_position.x + randf_range(-40, 40), director.wall_foot_y() + 30.0)
	else:
		var pink := director.pink
		_to = pink.global_position if SiegeTools.alive(pink) else global_position + Vector2(0, 120)
	Audio.play("swish", -3.0, 0.1, 0.8)
	_set_phase("carry_mobs")


func _carry_mobs() -> void:
	var k := clampf(_phase_t / MOB_CARRY, 0.0, 1.0)
	_lift = HEIGHT * sin(minf(k * 2.0, 1.0) * PI * 0.5)
	global_position = _from.lerp(_to, k)
	_mob_cargo = _mob_cargo.filter(func(m): return TeamworkEffects._alive(m))
	for i in _mob_cargo.size():
		(_mob_cargo[i] as Node2D).global_position = global_position + Vector2(-8.0 + i * 4.0, -_lift * 0.5 - 4.0)
	if k < 1.0:
		return
	for m in _mob_cargo:
		var mob := m as Monster
		mob.set_physics_process(true)
		if _cargo_to_wall and SiegeHazard.fling_to_wall(mob, 0.4, 40.0):
			dropped_mobs += 1
			continue
		SiegeHazard.fling_to(mob, global_position + Vector2(randf_range(-18, 18), randf_range(-6, 10)), 0.35, 20.0)
		dropped_mobs += 1
	_mob_cargo.clear()
	SiegeFx.ring(get_parent(), global_position, 24.0, Color(1, 0.85, 0.5, 0.8), 0.3)
	_set_phase("rise")


func _drop(arrived: bool) -> void:
	var c := caught
	caught = null
	if is_instance_valid(c) and c.get_meta("siege_claw_owner", null) == self:
		c.remove_meta("siege_claw_owner")
		if c.sprite:
			c.sprite.position.y = 0.0
		var at := c.global_position
		at.y = maxf(at.y, director.wall_foot_y() + 24.0)
		var safe := SiegeTools.safe_spot(c, at)
		c.global_position = safe if safe != Vector2.INF else at
		if c.status and c.status.is_grabbed_by(self):
			c.status.release(false)
		c.set_physics_process(_owned_physics)
		c.velocity = Vector2.ZERO
		_cool[c.character_id] = COOL
		if arrived:
			SiegeFx.ring(get_parent(), c.global_position, 30.0, Color(1, 0.85, 0.5, 0.8), 0.3)
			Fx.burst(get_parent(), c.global_position, "dust", 8, 40.0, 0.4, Vector2(0, 30))
	_set_phase("rise")


func _end() -> void:
	if caught:
		_drop(false)
	for m in _mob_cargo:
		if is_instance_valid(m):
			(m as Monster).set_physics_process(true)
	_mob_cargo.clear()
	super()


func _exit_tree() -> void:
	if caught:
		_drop(false)


func _draw() -> void:
	# 地上的影子（追的时候越落越实）
	var shade := 0.25 + (0.35 if phase == "drop" else 0.0)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.15, 0.08, 0.2, shade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(1, 0.8, 0.4, 0.6 if phase == "hunt" else 0.3), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not warned:
		return
	# 吊索 + 爪子
	var lift := _lift if phase != "hunt" else HEIGHT
	var top := Vector2(0, -lift - 140.0)
	var claw := Vector2(0, -lift - 18.0)
	draw_line(top, claw, Color(0.55, 0.5, 0.6), 2.0)
	draw_rect(Rect2(claw + Vector2(-8, -6), Vector2(16, 8)), Color(0.75, 0.7, 0.8))
	var open := 0.6 if phase in ["hunt", "rise"] else 0.15
	for side in [-1.0, 1.0]:
		var a := claw + Vector2(side * 7, 2)
		var b := a + Vector2(side * 10, 8).rotated(side * open)
		var c := b + Vector2(-side * 6, 9).rotated(side * open)
		draw_polyline(PackedVector2Array([a, b, c]), Color(0.85, 0.8, 0.9), 2.5)
		# 爪子内侧的刷子
		draw_line(b + Vector2(-side * 2, 0), c + Vector2(side * 1, -2), Color(1, 0.75, 0.85), 2.0)
	draw_line(claw + Vector2(0, 2), claw + Vector2(0, 14), Color(0.85, 0.8, 0.9), 2.0)
