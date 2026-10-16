class_name PuppetMaster
extends SiegeBoss
## 第九波魔偶师：机关独立运行；实际位置决定追击路径，角色身份决定弱点与工具。

const SKILL_CD := {"tether": 3.2, "swap": 6.0, "brush": 2.4, "cross": 4.2, "link": 6.0, "lift": 3.6, "relay": 4.5, "winch": 3.0}
const WARN := {"tether": 0.18, "swap": 0.18, "brush": 0.12, "cross": 0.18, "link": 0.12, "lift": 0.12, "relay": 0.12, "winch": 0.1}
const NAMES := {"tether": "缎带提线", "swap": "缎带换位", "brush": "双路机关刷挠", "cross": "十字刷具阵", "link": "双子痒感线", "lift": "吊起刷挠", "relay": "挠痒接力号令", "winch": "缎带绞盘拖行"}
const RAGE_CD_MULT := 0.45

@export var sprite_key := "puppet_master"
var cds := {}
var used: Array[String] = []
var _last := {}
var _fields: Array[WeakRef] = []
var _hits := {}
var _warns: Array[Node] = []
var _elapsed := 0.0
var _rest := 0.0
var _intro_done := false
var _intro_left := 0.0
var _cast_raged := false
var _link: HazardLinkRune


func _setup() -> void:
	super()
	knockback_resist = 0.9
	slam_chance = 0.0
	max_bats = 0
	summon_interval = 99999.0
	for key in SKILL_CD:
		cds[key] = 0.0
	if sprite:
		sprite.texture = SiegeMonster.TEX
		sprite.region_enabled = true
		_frame(0)


func _frame(index: int) -> void:
	if sprite:
		sprite.region_rect = SiegeMonster.region("%s_%d" % [sprite_key, index])
		sprite.offset = Vector2(0, -sprite.region_rect.size.y / 2.0 + 2.0)
		sprite.scale = Vector2.ONE


func intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	_intro_left = 0.25
	_announced = true
	GameState.boss_changed.emit(self)
	SiegeFx.big_title(self, "狂欢挠痒魔偶师", SiegeTools.COLOR, "第 9 波：缎带换位、刷轮拖行！塔伤害只有 25%。")
	SiegeFx.camera_peek(self, global_position + Vector2(0, -40), 1.8, 0.85)
	Audio.play("boss_roar", -2.0, 0.0, 1.15)
	director.intel.discover("puppet_master")
	var keys: Array[String] = []
	for key in director.wave_data().get("boss_escort", {}):
		for _i in int(director.wave_data()["boss_escort"][key]):
			keys.append(key)
	for i in keys.size():
		var at := director.clamp_in_map(global_position + Vector2.from_angle(TAU * i / keys.size()) * 58.0)
		var m := director.spawn(keys[i], "", at)
		if m:
			m.set_meta("escort_of", self)
			m.set_meta("escort_off", at - global_position)


func _tick(delta: float) -> void:
	if director == null or director.state != "fight" or SiegeTools.paused():
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
	if is_stunned():
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
		return
	if skill != "":
		_elapsed += delta
		velocity = Vector2.ZERO
		if _elapsed >= float(WARN[skill]):
			_execute(skill)
			skill = ""
			_rest = 0.7 if raged else 1.2
	else:
		_walk(delta)
		_rest = maxf(0.0, _rest - delta)
		_choose()
	_unstick(delta)
	move_with_push()
	global_position = director.clamp_in_map(global_position)
	if not raged:
		global_position.y = maxf(global_position.y, min_y())
	_animate(delta)


func _walk(_delta: float) -> void:
	var c := director.pink if SiegeTools.alive(director.pink) else director.blue
	if not SiegeTools.alive(c):
		velocity = Vector2.ZERO
		return
	var goal := c.global_position
	goal.y = maxf(goal.y, min_y())
	var offset := goal - global_position
	velocity = offset.normalized() * stats.chase_speed * (1.35 if raged else 1.0) * stat_mul("speed") if offset.length() > 42 else Vector2.ZERO
	if velocity.length() > 1.0:
		facing = velocity.normalized()


func people() -> Array[PlayableCharacter]:
	var out: Array[PlayableCharacter] = []
	for c in [director.pink, director.blue]:
		if SiegeTools.alive(c):
			out.append(c)
	return out


func _choose() -> void:
	if _rest > 0.0:
		return
	var order: Array = ["cross", "tether", "winch", "brush", "lift", "relay", "swap", "link"]
	if not used.is_empty():
		var next := {"cross": "tether", "tether": "winch", "winch": "brush", "brush": "lift", "lift": "relay", "swap": "link"}
		var key: String = next.get(used[-1], "")
		if key != "" and float(cds[key]) <= 0.0 and _start(key):
			return
		order.sort_custom(func(a, b): return float(_last.get(a, -INF)) < float(_last.get(b, -INF)))
	for key in order:
		if float(cds[key]) <= 0.0 and (used.is_empty() or key != used[-1]) and _start(key):
			return


func _start(key: String) -> bool:
	if not SKILL_CD.has(key) or skill != "" or not SiegeTools.valid_source(self) or people().is_empty():
		return false
	if key == "swap" and (people().size() != 2 or not SiegeTools.can_move(self, director.pink) or not SiegeTools.can_move(self, director.blue)):
		return false
	if key == "link" and is_instance_valid(_link) and _link.is_processing() and _link.life > 0.0:
		return false
	if key in ["tether", "lift", "winch"] and not people().any(func(c): return SiegeTools.can_move(self, c) and (key != "winch" or not c.status.is_rooted())):
		return false
	if key == "relay" and director.enemies_near(global_position, 360.0).filter(func(m): return m != self and not m.is_stunned() and MonsterTeamwork.key_of(m) in ["bind_vine", "hug_bear", "thigh_spider", "ghost"]).size() < (4 if raged else 2):
		return false
	skill = key
	_elapsed = 0.0
	_cast_raged = raged
	cds[key] = float(SKILL_CD[key]) * 2.0 * (RAGE_CD_MULT if raged else 1.0)
	used.append(key)
	_last[key] = _t
	_frame(4 if key != "winch" else 5)
	for c in people():
		_warns.append(SiegeFx.warn(get_parent(), c.global_position, "circle", 30.0, WARN[key], SiegeTools.COLOR, 0.0, 1.2, true))
		if key in ["tether", "swap", "winch"]:
			_warns.append(SiegeFx.lane(get_parent(), global_position + Vector2(0, -40), c.global_position, 6, SiegeTools.COLOR, WARN[key], true))
	_warns = _warns.filter(func(n): return is_instance_valid(n))
	SpeechBubble.say(self, NAMES[key], 100.0, 0.6)
	Audio.play("swish", -5.0, 0.0, 1.2)
	return true


func register_field(n: Node) -> void:
	if n == null:
		return
	_fields = _fields.filter(func(ref): return is_instance_valid(ref.get_ref()))
	_fields.append(weakref(n))


func brush_fields() -> Array:
	var out: Array = []
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n) and n is SiegeTools.BrushField and n.is_processing() and not n.is_queued_for_deletion():
			out.append(n)
	return out


func drag_goal(c: PlayableCharacter) -> Vector2:
	var goal := c.global_position + Vector2(96.0 if c.global_position.x < global_position.x else -96.0, 0)
	var best := INF
	for field in brush_fields():
		if director.is_on_wall(c) != (field.global_position.y < director.wall_foot_y()):
			continue
		var dist: float = c.global_position.distance_to(field.global_position)
		if dist < best:
			best = dist
			goal = field.global_position + (field.global_position - c.global_position).normalized() * 30.0
	var to := (goal - c.global_position).limit_length(160.0)
	if director.is_on_wall(c):
		to.y = 0.0
	else:
		goal = director.clamp_in_map(c.global_position + to)
		to = goal - c.global_position
	return c.global_position + to


func _execute(key: String) -> void:
	match key:
		"cross":
			while brush_fields().size() > 4:
				var old: Node = brush_fields()[0]
				old._end()
				old.queue_free()
			for c in people():
				for side in [-1, 1]:
					var f := SiegeTools.BrushField.new()
					f.source = weakref(self)
					f.life = 8.0 if _cast_raged else 6.0
					f.key = "tool_pad" if c.character_id == "blue" and side > 0 else "tool_roller"
					f.position = c.global_position + Vector2(side * 44.0, 0)
					get_parent().add_child(f)
					register_field(f)
		"tether":
			for c in people():
				var held := SiegeTools.hold(self, c, drag_goal(c))
				register_field(held)
				if held:
					register_field(SiegeTools.sequence(self, c, 1, 4.0, "tether"))
		"swap":
			if people().size() == 2:
				register_field(SiegeTools.move(self, [director.pink, director.blue], [director.blue.global_position, director.pink.global_position], true))
		"winch":
			var chosen: Array = people().filter(func(c): return SiegeTools.can_move(self, c) and not c.status.is_rooted())
			if not _cast_raged and chosen.size() > 1:
				chosen.resize(1)
			for c in chosen:
				var moved := SiegeTools.move(self, [c], [drag_goal(c)])
				register_field(moved)
				if moved:
					register_field(SiegeTools.sequence(self, c, 1, 3.0, "winch"))
		"brush":
			for c in people():
				register_field(SiegeTools.sequence(self, c, 6 if _cast_raged else 4, 4.0, "brush"))
		"lift":
			var chosen := people()
			if not _cast_raged and chosen.size() > 1:
				# 轮换，避免一直只针对粉色。
				chosen = [chosen[used.count("lift") % 2]]
			for c in chosen:
				var h := SiegeTools.hold(self, c, c.global_position, true, 3.0)
				register_field(h)
				if h:
					register_field(SiegeTools.sequence(self, c, 16, 4.0, "lift"))
		"link":
			if people().size() == 2:
				_link = HazardLinkRune.new()
				_link.share = 0.35
				_link.role_zones = true
				_link.auto_link = true
				_link.owner_ref = weakref(self)
				_link.life_override = 6.0
				_link.position = director.clamp_in_map(global_position + Vector2(48, 0))
				get_parent().add_child(_link)
				register_field(_link)
		"relay":
			director.teamwork.try_fire("puppet_relay_rage" if _cast_raged else "puppet_relay", self)
	SiegeFx.ring(get_parent(), global_position + Vector2(0, -30), 34.0, SiegeTools.COLOR, 0.35)


func strike_tools(c: PlayableCharacter, amount: float, part: String, variant: String) -> bool:
	var now := _t
	if not SiegeTools.alive(c) or now < float(_hits.get(c.get_instance_id(), -INF)):
		return false
	var h := make_tickle(c, amount)
	h.zone = part
	h.reaction_variant = variant
	var ok := c.receive_hit(h)
	if ok:
		_hits[c.get_instance_id()] = now + 0.12
	return ok


func _rage() -> void:
	raged = true
	for key in cds:
		cds[key] = minf(cds[key], SKILL_CD[key] * RAGE_CD_MULT)
	SiegeFx.big_title(self, "魔偶师：机关狂欢！", SiegeTools.COLOR, "双人拖行、六段刷挠，机关接力加快！")
	SiegeFx.screen_flash(self, Color(1, 0.5, 0.75, 0.3), 0.4)
	Fx.burst(get_parent(), global_position + Vector2(0, -40), "thread", 24, 95.0, 0.8, Vector2(0, -30), SiegeTools.COLOR)


func _animate(_delta: float) -> void:
	if skill == "":
		_frame(7 if raged else (2 + int(_t / 0.2) % 2 if velocity.length() > 2 else int(_t / 0.4) % 2))
	if sprite:
		sprite.flip_h = facing.x < -0.1


func _clear_fields() -> void:
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n):
			if n.has_method("_end"):
				n.call("_end")
			n.queue_free()
	_fields.clear()
	_link = null
	for n in _warns:
		if is_instance_valid(n):
			n.queue_free()
	_warns.clear()
	skill = ""


func _on_stunned(duration: float) -> void:
	super(duration)
	_clear_fields()


func _on_died() -> void:
	_clear_fields()
	GameState.boss_changed.emit(null)
	SiegeFx.impact(get_parent(), global_position, 110.0, true, SiegeTools.COLOR)
	SiegeFx.big_title(self, "狂欢挠痒魔偶师被打倒了！", SiegeTools.COLOR)
	if director:
		director.add_crystals(50, global_position)
	super()


func _exit_tree() -> void:
	_clear_fields()
