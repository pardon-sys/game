class_name GaleBear
extends SiegeBoss
## 第六波狂风熊统领：七技能；风场复用攻防战陷阱、飞具与协作，部位判定走 HitData。
## 半血前只在下半场；技能冷却是实际秒数，不重复乘 ability_rate。

const WIND := Color(0.45, 0.95, 0.9)
const GOLD := Color(1.0, 0.78, 0.35)
const SKILL_CD := {"tornado": 3.6, "vacuum": 4.2, "chase": 2.4, "pulse": 2.7, "lanes": 4.8, "convoy": 4.8, "paw": 1.8}
const NAMES := {"tornado": "八向羽痒龙卷", "vacuum": "吸痒羽毛风眼", "chase": "羽刷追痒", "pulse": "挠痒风盾震荡", "lanes": "羽痒三岔压城", "convoy": "旋风挠痒运兵", "paw": "熊掌挠挠"}
const MAX_TORNADOES := 48
const WARN_TIME := {"tornado": 0.18, "vacuum": 0.18, "chase": 0.15, "pulse": 0.12, "lanes": 0.18, "convoy": 0.15, "paw": 0.1}
const RAGE_CD_MULT := 0.45
const TORNADO_GAP := 0.18
const CHASE_GAP := 0.18
const PULSE_GAP := 0.18
const PAW_GAP := 0.14
const HIT_GAP := 0.12

@export var sprite_key := "gale_bear"

var cds := {}
var used: Array[String] = []
var rage_count := 0
var _intro_done := false
var _intro_left := 0.0
var _rest := 0.0
var _elapsed := 0.0
var _phase := 0
var _goal := Vector2.ZERO
var _from := Vector2.ZERO
var _heading := Vector2.UP
var _victim_ref: WeakRef
var _blue_zone := 0
var _warns: Array[Node] = []
var _hit_cool := {}
var _last_used := {}
var _fields: Array[WeakRef] = []
var _vortex: GaleVortex
var _round_goals: Array[Vector2] = []
var _next_round := 0.0
var _cast_raged := false
var _wheel: Node2D
var _steam: CPUParticles2D


func _setup() -> void:
	super()
	knockback_resist = 0.9
	grab_max_time = 3.0
	grab_presses = 12
	grab_tickle = 4.0
	grab_interval = 0.5
	stun_time = 1.5
	slam_chance = 0.0
	max_bats = 0
	summon_interval = 99999.0
	for key in SKILL_CD:
		cds[key] = 0.0
	if sprite:
		sprite.texture = SiegeMonster.TEX
		sprite.region_enabled = true
		_frame(0)
		sprite.scale = Vector2.ONE


func _frame(index: int) -> void:
	if sprite:
		sprite.region_rect = SiegeMonster.region("%s_%d" % [sprite_key, index])
		sprite.offset = Vector2(0, -sprite.region_rect.size.y / 2.0 + 2.0)


func intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	_intro_left = 0.25
	_announced = true
	GameState.boss_changed.emit(self)
	SiegeFx.big_title(self, "狂风熊统领", GOLD, "第 6 波：躲开羽痒龙卷，冻结风眼！冰塔伤害只有 25%。")
	SiegeFx.camera_peek(self, global_position + Vector2(0, -40), 1.8, 0.85)
	Audio.play("boss_roar", -1.0)
	_wheel = SiegeFx.wind_wheel(self, Vector2(0, -38), 38.0, WIND, 1.1)
	if director:
		director.intel.discover("gale_bear")
		# 对应生成器在原出怪配额里预留的护卫；只出场一次，不在号令中补怪。
		var keys: Array[String] = []
		for key in director.wave_data().get("boss_escort", {}):
			for _i in int(director.wave_data()["boss_escort"][key]):
				keys.append(str(key))
		for i in keys.size():
			var offset := Vector2.from_angle(TAU * i / keys.size()) * 58.0
			var m := director.spawn(keys[i], "", director.clamp_in_map(global_position + offset))
			if m:
				m.set_meta("escort_of", self)
				m.set_meta("escort_off", offset)


func _tick(delta: float) -> void:
	if director == null or director.state != "fight" or GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		velocity = Vector2.ZERO
		return
	if not _intro_done:
		intro()
		return
	_t += delta
	if _intro_left > 0.0:
		_intro_left -= delta
		return
	for key in cds:
		cds[key] = maxf(0.0, float(cds[key]) - delta)
	if not raged and health.hp <= health.max_hp / 2:
		_rage()
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
		if _stun_left <= 0.0:
			state = State.WANDER
			if sprite:
				sprite.modulate = Color.WHITE
		return
	if mode == Mode.GRABBING or mode == Mode.STUNNED:
		super(delta)
		_bound()
		return
	if skill != "":
		_skill_tick(delta)
	else:
		_walk(delta)
		_rest = maxf(0.0, _rest - delta)
		if _rest <= 0.0 and global_position.y >= min_y():
			_choose()
	_unstick(delta)
	move_with_push()
	_bound()
	_animate(delta)
	if raged and director.on_screen(global_position) and randf() < delta * 8.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-20, 20), -8), "dust", 2, 45.0, 0.5, Vector2(0, -35), WIND)


func _bound() -> void:
	if not raged:
		global_position.y = maxf(global_position.y, min_y())
	global_position = director.clamp_in_map(global_position)


func _walk(delta: float) -> void:
	var goal := Vector2(global_position.x, min_y() + 30.0)
	if global_position.y < min_y():
		goal.y = min_y() + 40.0
	else:
		var near := director.nearest_target(self, 360.0)
		if near:
			target = near
			goal = near.global_position
		else:
			goal = Vector2(director.blue.global_position.x if _alive(director.blue) else director.gate_pos.x,
				maxf(director.wall_foot_y() + 28.0, min_y() + 30.0))
	goal.y = maxf(goal.y, min_y())
	var offset := goal - global_position
	var speed := stats.chase_speed * (1.35 if raged else 1.0) * stat_mul("speed")
	velocity = offset.normalized() * speed if offset.length() > 30.0 else velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	if velocity.length() > 1.0:
		facing = velocity.normalized()


static func _alive(c: Variant) -> bool:
	return is_instance_valid(c) and c is Actor and c.is_alive() and not (c is PlayableCharacter and Downed.is_downed(c))


func _choose() -> void:
	if _rest > 0.0:
		return
	var candidates: Array[String] = []
	if not (_alive(director.pink) or _alive(director.blue)):
		return
	for key in SKILL_CD:
		if float(cds[key]) > 0.0 or (not used.is_empty() and used[-1] == key):
			continue
		if key == "paw" and _near_princess(56.0) == null:
			continue
		if key == "vacuum" and is_instance_valid(_vortex):
			continue
		if key == "convoy" and director.enemies_near(global_position, 224.0).size() < (5 if raged else 3):
			continue
		if key == "tornado" and tornado_count() + (16 if raged else 8) > MAX_TORNADOES:
			continue
		candidates.append(key)
	if candidates.is_empty():
		return
	if used.is_empty() and candidates.has("tornado"):
		_start("tornado")
	elif tornado_count() > 0 and candidates.has("vacuum"):
		_start("vacuum")
	elif not used.is_empty() and used[-1] == "vacuum" and candidates.has("paw"):
		_start("paw")
	elif not used.is_empty() and used[-1] == "vacuum" and candidates.has("convoy"):
		_start("convoy")
	else:
		candidates.sort_custom(func(a, b): return float(_last_used.get(a, -INF)) < float(_last_used.get(b, -INF)))
		_start(candidates[0])


func _near_princess(radius: float) -> PlayableCharacter:
	var nearest: PlayableCharacter
	for c in [director.pink, director.blue]:
		if _alive(c) and global_position.distance_to(c.global_position) <= radius:
			radius = global_position.distance_to(c.global_position)
			nearest = c
	return nearest


func _start(key: String) -> bool:
	if not SKILL_CD.has(key) or skill != "" or mode != Mode.NORMAL or is_stunned() or not is_alive():
		return false
	var chosen: PlayableCharacter = _near_princess(56.0) if key == "paw" else null
	if key == "paw" and chosen == null:
		return false
	if key == "vacuum" and is_instance_valid(_vortex):
		return false
	if chosen == null:
		chosen = director.pink if _alive(director.pink) else director.blue
	if not _alive(chosen):
		return false
	if key == "tornado" and tornado_count() + (16 if raged else 8) > MAX_TORNADOES:
		return false
	_warns = _warns.filter(func(n): return is_instance_valid(n))
	skill = key
	used.append(key)
	_last_used[key] = _t
	_elapsed = 0.0
	_phase = 0
	_cast_raged = raged
	_from = global_position
	_goal = chosen.global_position
	_heading = _from.direction_to(_goal)
	if _heading == Vector2.ZERO:
		_heading = Vector2.UP
	_victim_ref = weakref(chosen)
	facing = _heading
	velocity = Vector2.ZERO
	cds[key] = float(SKILL_CD[key]) * 2.0 * (RAGE_CD_MULT if raged else 1.0)
	_frame(5 if key == "paw" else 4)
	var warning := float(WARN_TIME[key])
	match key:
		"tornado": _tornado_warning(0.0, warning)
		"vacuum":
			_track(SiegeFx.warn(get_parent(), _from, "circle", 256.0 if raged else 224.0, warning, WIND, 0.0, 1.2, true))
			_track(SiegeFx.wind_eye(get_parent(), _from, 256.0 if raged else 224.0, warning, true))
			director.teamwork.try_fire("bear_shield", self)
		"chase": _chase_warning(warning)
		"lanes":
			var x: float = director.blue.global_position.x if _alive(director.blue) else _goal.x
			_goal = Vector2(x, director.wall_top_y() + 4.0)
			for i in 3:
				_track(SiegeFx.lane(get_parent(), _from, _goal + Vector2((i - 1) * 72.0, 0), 32.0, WIND, warning, true))
		"paw": _paw_warning(warning)
		"convoy": _track(SiegeFx.warn(get_parent(), _from, "circle", 80.0, warning, GOLD, 0.0, 1.2, true))
		_: _track(SiegeFx.warn(get_parent(), _from, "circle", 160.0, warning, GOLD, 0.0, 1.2, true))
	_track(SiegeFx.wind_wheel(get_parent(), _from + Vector2(0, -36), 28.0, WIND, warning))
	SpeechBubble.say(self, "熊掌挠脚心！" if key == "paw" and chosen.character_id == "pink" else str(NAMES[key]), 108.0, warning + 0.4)
	Audio.play("wind", -5.0)
	return true


func _track(n: Node) -> void:
	if is_instance_valid(n):
		_warns.append(n)


func register_field(n: Node) -> void:
	_fields = _fields.filter(func(ref): return is_instance_valid(ref.get_ref()))
	_fields.append(weakref(n))


func tornado_count() -> int:
	var count := 0
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n) and n is HazardTornado and not n.is_queued_for_deletion() and n.is_processing():
			count += 1
	return count


func _tornado_warning(offset: float, time: float) -> void:
	for i in 8:
		var dir := _heading.rotated(TAU * i / 8.0 + offset)
		_track(SiegeFx.lane(get_parent(), _from, director.clamp_in_map(_from + dir * 660.0, 24), 48.0, WIND, time, true))


func _release_tornadoes(offset := 0.0) -> void:
	for i in 8:
		if tornado_count() >= MAX_TORNADOES:
			break
		var n := HazardTornado.new()
		n.boss_ref = weakref(self)
		n.wind_direction = _heading.rotated(TAU * i / 8.0 + offset)
		n.position = _from
		get_parent().add_child(n)
		register_field(n)
	Fx.burst(get_parent(), _from, "feather", 18, 95.0, 0.8, Vector2.ZERO)


func _chase_warning(time: float) -> void:
	_round_goals.clear()
	for c in [director.pink, director.blue]:
		if not _alive(c):
			continue
		_round_goals.append(c.global_position)
		_track(SiegeFx.lane(get_parent(), _from, c.global_position, 32.0, GOLD, time, true))


func _chase_round() -> void:
	for goal in _round_goals:
		var dir := _from.direction_to(goal)
		var count := 5 if _cast_raged else 3
		for i in count:
			GaleWind.shoot(self, _from + Vector2(0, -8), dir.rotated((i - (count - 1) / 2.0) * 0.14), 10.0 if _cast_raged else 8.0, "chase", i % 2 == 0)


func _paw_warning(time: float) -> void:
	var c := _victim_ref.get_ref() as PlayableCharacter if _victim_ref else null
	if _alive(c):
		_heading = global_position.direction_to(c.global_position)
	_track(SiegeFx.warn(get_parent(), global_position, "sector", 60.0, time, GOLD, _heading.angle(), 1.6, true))


func _skill_tick(delta: float) -> void:
	_elapsed += delta
	velocity = Vector2.ZERO
	var warning := float(WARN_TIME[skill])
	if _elapsed < warning:
		return
	if _phase == 0:
		_phase = 1
		match skill:
			"tornado":
				_release_tornadoes()
				director.teamwork.try_fire("bear_roll", self)
				if not _cast_raged:
					_end_skill()
					return
				_tornado_warning(PI / 8.0, TORNADO_GAP)
			"vacuum":
				_vortex = GaleVortex.spawn(self, _cast_raged)
				# 风眼独立持续，本体立即接下一招；冻结 / 清场仍释放飞具。
				_end_skill()
				return
			"chase":
				_chase_round()
				_next_round = _elapsed + CHASE_GAP
				_chase_warning(CHASE_GAP)
			"pulse":
				GaleWind.pulse(self, _from)
				if not _cast_raged:
					_end_skill()
					return
				_track(SiegeFx.warn(get_parent(), _from, "circle", 160.0, PULSE_GAP, GOLD, 0.0, 1.2, true))
			"lanes":
				for i in 3:
					GaleWind.lane(self, _from, _goal + Vector2((i - 1) * 72.0, 0), 6.0 if _cast_raged else 4.5)
				_end_skill()
				return
			"convoy":
				director.teamwork.try_fire("bear_airlift_rage" if _cast_raged else "bear_airlift", self)
				_end_skill()
				return
			"paw":
				_paw_hit(0)
				_next_round = _elapsed + PAW_GAP
				_paw_warning(PAW_GAP)
	match skill:
		"tornado":
			if _elapsed >= warning + TORNADO_GAP:
				_release_tornadoes(PI / 8.0)
				_end_skill()
		"chase":
			if _elapsed >= _next_round:
				_chase_round()
				_phase += 1
				if _phase >= 3:
					_end_skill()
				else:
					_next_round = _elapsed + CHASE_GAP
					_chase_warning(CHASE_GAP)
		"pulse":
			if _elapsed >= warning + PULSE_GAP:
				GaleWind.pulse(self, _from)
				_end_skill()
		"paw":
			if _elapsed >= _next_round:
				_paw_hit(_phase)
				_phase += 1
				if _phase >= 3:
					_end_skill()
				else:
					_next_round = _elapsed + PAW_GAP
					_paw_warning(PAW_GAP)


func _paw_hit(index: int) -> void:
	var c := _victim_ref.get_ref() as PlayableCharacter if _victim_ref else null
	if not _alive(c):
		return
	_frame(5)
	var to := c.global_position - global_position
	if to.length() > 60.0 or absf(_heading.angle_to(to)) > 0.8:
		return
	strike(c, [7.0, 9.0, 12.0][index], "paw", 0.0, global_position)
	TrapFx.stroke(get_parent(), c.global_position + Vector2(0, -4), _heading)
	TrapFx.feather_puff(get_parent(), c.global_position + Vector2(0, -4), 4)


func _targets() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in [director.pink, director.blue] + director.soldiers + director.extra_targets:
		if _alive(a):
			out.append(a)
	return out


## 各风场共享短命中保护；伤害仍由 Actor / HitData / Sensitivity 结算。
func strike(a: Actor, amount: float, variant: String, push := 0.0, origin := Vector2.INF) -> bool:
	if not _alive(a) or (a is PlayableCharacter and (a.is_dashing() or a.is_airborne())):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_hit_cool.get(a.get_instance_id(), 0.0)):
		return false
	var hit := make_tickle(a, amount, false, push) if a is PlayableCharacter else HitData.make_attack(self, 2, push)
	hit.reaction_variant = variant
	if origin != Vector2.INF:
		hit.origin = origin
	var accepted := a.receive_hit(hit)
	if accepted:
		_hit_cool[a.get_instance_id()] = now + HIT_GAP
	return accepted


func make_tickle(t: Node, amount: float, force_special := false, kb := 0.0) -> HitData:
	var hit := super(t, amount, force_special, kb)
	if t is PlayableCharacter:
		if t.character_id == "pink":
			hit.zone = "sole"
		else:
			hit.zone = "thigh" if _blue_zone % 2 == 0 else "butt"
			_blue_zone += 1
	return hit


func _end_skill(rest := -1.0) -> void:
	skill = ""
	velocity = Vector2.ZERO
	_rest = maxf(rest, 0.7 if raged else 1.2)
	_frame(7 if raged else 0)


func _on_stunned(duration: float) -> void:
	super(duration)
	_cancel()


func _cancel() -> void:
	if is_instance_valid(_vortex):
		_vortex._end()
	_vortex = null
	for n in _warns:
		if is_instance_valid(n):
			n.queue_free()
	_warns.clear()
	_end_skill()
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		_end_grab()


func _rage() -> void:
	raged = true
	rage_count += 1
	SiegeFx.big_title(self, "熊统领：狂风推进！", GOLD, "半血后向城墙推进，技能与协作加快！")
	SiegeFx.screen_flash(self, Color(0.2, 0.9, 0.8, 0.3), 0.4)
	SiegeFx.wind_wheel(get_parent(), global_position, 130.0, WIND, 1.0)
	Audio.play("boss_roar", -1.0, 0.0, 0.9)
	if sprite:
		sprite.self_modulate = Color(1.15, 1.05, 0.9)
	_steam = Fx.emitter(self, "steam", 12, 1.0, {"offset": Vector2(0, -40), "dir": Vector2.UP, "speed": [14.0, 30.0], "color": WIND, "extents": Vector2(20, 10)})
	_steam.emitting = true
	for key in cds:
		cds[key] = minf(float(cds[key]), float(SKILL_CD[key]) * RAGE_CD_MULT)


func _animate(_delta: float) -> void:
	if sprite == null or skill != "":
		return
	if velocity.length() > 2.0:
		_frame(2 + int(_t / 0.22) % 2)
	else:
		_frame(7 if raged else int(_t / 0.4) % 2)
	sprite.flip_h = facing.x < -0.1
	sprite.scale = Vector2.ONE


func _on_died() -> void:
	_clear_fields()
	_cancel()
	if is_instance_valid(_steam):
		_steam.emitting = false
	GameState.boss_changed.emit(null)
	SiegeFx.impact(get_parent(), global_position, 110.0, true, GOLD)
	SiegeFx.big_title(self, "狂风熊统领被打倒了！", GOLD)
	if director:
		director.add_crystals(40, global_position)
	super()


func _clear_fields() -> void:
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n):
			if n.has_method("_end"):
				n.call("_end")
			n.queue_free()
	_fields.clear()


func _exit_tree() -> void:
	_clear_fields()
	_cancel()
