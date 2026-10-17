class_name PuppetMaster
extends SiegeBoss
## 第 9 波小 Boss「狂欢挠痒魔偶师」（SiegeBoss，数据 data/siege/bosses.json 的 puppet_master）。八个技能，机关（SiegeTools）独立运行：
##   tether 缎带提线（拉向最近的刷具场）、swap 缎带换位（两位公主互换位置）、brush 双路机关刷挠（连挠几下）、cross 十字刷具阵（两边放刷具场）、
##   link 双子痒感线（HazardLinkRune：一个人被挠另一个也痒）、lift 吊起刷挠（吊起来连挠）、relay 挠痒接力号令（配合技 puppet_relay）、
##   winch 缎带绞盘拖行（拖着人走过刷具场）。弱点由角色决定：粉色公主是脚心，蓝色公主是大腿 / 屁股（SiegeTools.zone）。
## 半血狂暴：冷却 × rage_cd、拖行 / 吊起两个人一起、刷挠次数变多。

@export var sprite_key := "puppet_master"
var _elapsed := 0.0
var _rest := 0.0
var _intro_done := false
var _intro_left := 0.0
var _cast_raged := false
var _link: HazardLinkRune


func _setup() -> void:
	boss_key = "puppet_master"
	super()
	knockback_resist = 0.9
	slam_chance = 0.0
	max_bats = 0
	summon_interval = 99999.0
	reset_cooldowns()
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
	announce("intro")
	SiegeFx.camera_peek(self, global_position + Vector2(0, -40), 1.8, 0.85)
	Audio.play("boss_roar", -2.0, 0.0, 1.15)
	director.intel.discover("puppet_master")
	spawn_escorts()


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
	tick_cooldowns(delta)
	if not raged and health.hp <= health.max_hp / 2:
		_rage()
	if is_stunned():
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
		return
	if skill != "":
		_elapsed += delta
		velocity = Vector2.ZERO
		if _elapsed >= skill_warn(skill):
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
		order.sort_custom(func(a, b): return float(last_used.get(a, -INF)) < float(last_used.get(b, -INF)))
	for key in order:
		if float(cds[key]) <= 0.0 and (used.is_empty() or key != used[-1]) and _start(key):
			return


func _start(key: String) -> bool:
	if not has_skill(key) or skill != "" or not SiegeTools.valid_source(self) or people().is_empty():
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
	put_on_cooldown(key, 2.0 * (rage_cd() if raged else 1.0))
	mark_used(key)
	_frame(4 if key != "winch" else 5)
	for c in people():
		_warns.append(SiegeFx.warn(get_parent(), c.global_position, "circle", 30.0, skill_warn(key), SiegeTools.COLOR, 0.0, 1.2, true))
		if key in ["tether", "swap", "winch"]:
			_warns.append(SiegeFx.lane(get_parent(), global_position + Vector2(0, -40), c.global_position, 6, SiegeTools.COLOR, skill_warn(key), true))
	_warns = _warns.filter(func(n): return is_instance_valid(n))
	SpeechBubble.say(self, skill_name(key), 100.0, 0.6)
	Audio.play("swish", -5.0, 0.0, 1.2)
	return true


func brush_fields() -> Array:
	return live_fields().filter(func(n): return n is SiegeTools.BrushField and n.is_processing())


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


func _rage() -> void:
	raged = true
	for key in cds:
		cds[key] = minf(cds[key], skill_cd(key) * rage_cd())
	announce("rage")
	SiegeFx.screen_flash(self, Color(1, 0.5, 0.75, 0.3), 0.4)
	Fx.burst(get_parent(), global_position + Vector2(0, -40), "thread", 24, 95.0, 0.8, Vector2(0, -30), SiegeTools.COLOR)


func _animate(_delta: float) -> void:
	if skill == "":
		_frame(7 if raged else (2 + int(_t / 0.2) % 2 if velocity.length() > 2 else int(_t / 0.4) % 2))
	if sprite:
		sprite.flip_h = facing.x < -0.1


## 收掉所有机关、预警和痒感线。
func _clear_all() -> void:
	clear_fields()
	clear_warns()
	_link = null
	skill = ""


func _on_stunned(duration: float) -> void:
	super(duration)
	_clear_all()


func _on_died() -> void:
	_clear_all()
	GameState.boss_changed.emit(null)
	SiegeFx.impact(get_parent(), global_position, 110.0, true, SiegeTools.COLOR)
	announce("defeat")
	reward_defeat()
	super()


func _exit_tree() -> void:
	_clear_all()
	super()
