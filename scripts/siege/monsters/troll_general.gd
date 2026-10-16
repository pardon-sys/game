class_name TrollGeneral
extends SiegeBoss
## 攻城巨魔将军（攻防战第 3 波的小 Boss；挠痒巨魔的模板：抓取 / 挣脱 / 松手僵直沿用 TickleTroll）。
## 出场：地面连震、裂缝蔓延 → 镜头摇过去 → 从地里钻出来 → 名字大字 + Boss 血条 → 带 4 只盾甲螃蟹护卫。
## 技能（每个都有自己颜色和形状的地面预警 + 蓄力光 + 音效；AI 按距离和场况挑，冷却 ÷ rate）：
##   grab    大手抓挠：抓住粉色公主扳脚挠脚心（脚心暴露），连按挣脱；松手后僵直 2 秒
##   swipe   三连扫掌：前方三道扇形依次扫过，挠痒 + 击退
##   quake   地震重击：蓄力后砸地，冲击波范围扣血击退、士兵掀翻；在墙下时把那段城墙上的蓝色公主震下去（狂暴后两连）
##   throw   投掷小怪上墙：抓起脚边 2~3 只小怪一只接一只扔上墙顶
##   ram     攻城锤冲锋：扛木桩，红线预警后冲撞城墙，路上撞飞人；冲完喘气 1.5 秒
##   leap    跳劈城墙：跳到城墙脚下（落点影子预警）震裂那段墙，2 秒后再跳回战场中间
##   cry     战吼：红色音波，附近的怪发狂 6 秒，范围内的公主僵一下
##   banner  痒痒军旗：插一面有血量的军旗，旗边的怪加速、每 4 秒从地里钻出一只小怪
##   build   召工兵就地搭塔：叫一队地精工兵在身边直接搭敌塔（8 秒，打倒工兵可打断）
##   rage    半血狂暴：变红变大、移速 +40%、召 4 只盾甲螃蟹，之后技能间隔缩短，身上冒红色蒸汽、脚下踩出裂纹
## 图：siege/monsters.png 的 general_0~4（0/1 走、2 蓄力举手、3 扛木桩、4 跳起）。

const META := "res://assets/generated/siege/monsters.json"
const SKILL_CD := {"grab": 8.0, "swipe": 6.0, "quake": 11.0, "throw": 10.0, "ram": 16.0, "leap": 18.0, "cry": 15.0,
	"banner": 24.0, "build": 30.0}
const MINIONS := ["slime", "rat", "caterpillar", "squirrel"]

@export var sprite_key := "general"

var rate := 1.0
## 每个技能剩下的冷却（秒）
var cds := {}
## 用过的技能（测试用）
var used: Array[String] = []
var _phase := 0
var _st := 0.0
var _global_cd := 2.0
var _skill_think := 0.0
var _frame_t := 0.0
var _frame := 0
var _intro_done := false
var _sector_i := 0
var _goal := Vector2.ZERO
var _ammo: Array = []
var _banner: Node2D
var _steam: CPUParticles2D
var _crack_t := 0.0
var _base_scale := 1.0


func _setup() -> void:
	super()
	knockback_resist = 0.9
	stun_time = 2.0
	grab_presses = 12
	grab_max_time = 4.0
	grab_tickle = 7.0
	summon_interval = 99999.0   # 巨魔原来的召蝙蝠不用：空投走号角技能
	slam_chance = 0.0
	for k in SKILL_CD:
		cds[k] = randf_range(1.0, 4.0)
	cds["ram"] = 6.0
	cds["leap"] = 8.0
	cds["build"] = 10.0
	if sprite:
		sprite.region_enabled = true
		sprite.texture = load("res://assets/generated/siege/monsters.png")
		_set_frame(0)
		sprite.scale = Vector2.ONE


func make_mind(_d: Node) -> RefCounted:
	return null


func _set_frame(f: int) -> void:
	if sprite == null:
		return
	sprite.region_rect = SiegeMonster.region("%s_%d" % [sprite_key, f])
	sprite.offset = Vector2(0, -sprite.region_rect.size.y / 2.0 + 2.0)


func _cd(key: String) -> float:
	return float(SKILL_CD.get(key, 10.0)) / rate


# ------------------------------------------------------------------ 出场
func intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	set_physics_process(false)
	visible = false
	var at := global_position
	SiegeFx.camera_peek(self, at + Vector2(0, -30), 2.4, 0.9)
	Audio.play("boss_quake", -2.0)
	for i in 4:
		get_tree().create_timer(0.25 * i, false).timeout.connect(func():
			if is_instance_valid(self):
				SiegeFx.screen_shake(self, 3.0 + i, 0.25)
				var cr := SiegeFx.Cracks.new()
				cr.radius = 20.0 + i * 14.0
				cr.add_to_group("siege_temp")
				get_parent().add_child(cr)
				cr.global_position = at
				Fx.burst(get_parent(), at + Vector2(randf_range(-20, 20), -4), "rock", 6, 50.0, 0.6, Vector2(0, 140), Color(0.6, 0.5, 0.4)))
	await get_tree().create_timer(1.1, false).timeout
	if not is_instance_valid(self):
		return
	visible = true
	set_physics_process(true)
	SiegeFx.burrow(self)
	SiegeFx.impact(get_parent(), at, 70.0, true, Color(1, 0.6, 0.4))
	Audio.play("boss_roar", 0.0)
	SiegeFx.big_title(self, "攻城巨魔将军", Color(1, 0.55, 0.35), "第 3 波的小 Boss——看清地上的预警！")
	GameState.boss_changed.emit(self)
	_announced = true
	if director:
		director.intel.discover("troll_general")
		for i in 4:
			var c := director.spawn("shield_crab", "", at + Vector2.from_angle(TAU * i / 4.0) * 26.0)
			if c:
				c.set_meta("escort_of", self)
				c.set_meta("escort_off", Vector2.from_angle(TAU * i / 4.0) * 26.0)


# ------------------------------------------------------------------ 主循环
func _tick(delta: float) -> void:
	if not _intro_done:
		intro()
		return
	_t += delta
	for k in cds:
		cds[k] = float(cds[k]) - delta
	if not raged and health and health.hp <= health.max_hp / 2:
		_rage()
	# 抓住 / 松手僵直：巨魔原来的逻辑（挠痒的部位换成脚心）
	if mode == Mode.GRABBING or mode == Mode.STUNNED:
		tickle_zones = {"sole": 10.0} if mode == Mode.GRABBING else {}
		if mode == Mode.GRABBING and randf() < delta * 6.0 and is_instance_valid(victim):
			Fx.burst(get_parent(), (victim as Node2D).global_position + Vector2(randf_range(-4, 4), -2), "bristle", 3, 30.0, 0.4, Vector2(0, 40))
		super(delta)
		return
	var above := not raged and director != null and global_position.y < min_y() - 10.0
	if skill != "":
		_skill_tick(delta)
	elif above:
		# 半血狂暴前只在地图下半部活动：被弄到上半部（击退、过场……）就先走回去，路上不放技能
		velocity = Vector2(0, 1) * stats.chase_speed * 1.2 * stat_mul("speed")
		facing = Vector2.DOWN
	else:
		_walk(delta)
		if not raged and director and global_position.y + velocity.y * delta < min_y():
			velocity.y = maxf(velocity.y, 0.0)
		_global_cd -= delta
		_skill_think -= delta
		if _global_cd <= 0.0 and _skill_think <= 0.0:
			_skill_think = 0.3
			_choose()
	_unstick(delta)
	move_with_push()
	_animate(delta)
	if raged:
		_rage_tick(delta)


func _pink() -> PlayableCharacter:
	var p: PlayableCharacter = director.pink if director else null
	return p if p and is_instance_valid(p) and p.is_alive() and not Downed.is_downed(p) and not director.is_on_wall(p) else null


## 平时：追粉色公主（近的话），不然朝蓝色公主那段城墙走。
func _walk(delta: float) -> void:
	var p := _pink()
	var spd := stats.chase_speed * (1.4 if raged else 1.0) * stat_mul("speed")
	if p and p.global_position.distance_to(global_position) < 320.0:
		target = p
		var to := p.global_position - global_position
		velocity = to.normalized() * spd if to.length() > 22.0 else velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	elif director:
		var gx: float = director.blue.global_position.x if director.blue else global_position.x
		var goal := Vector2(gx, maxf(director.wall_foot_y() + 30.0, min_y() + 10.0))
		var to2 := goal - global_position
		velocity = to2.normalized() * spd * 0.8 if to2.length() > 10.0 else Vector2.ZERO
	if velocity.length() > 1.0:
		facing = velocity.normalized()


func _choose() -> void:
	var p := _pink()
	var dp := p.global_position.distance_to(global_position) if p else 99999.0
	var to_wall := global_position.y - director.wall_foot_y() if director else 9999.0
	var picks: Array[String] = []
	if p and dp < 34.0 and float(cds["grab"]) <= 0.0 and p.can_be_grabbed():
		picks.append("grab")
	if p and dp < 72.0 and float(cds["swipe"]) <= 0.0:
		picks.append("swipe")
	if (dp < 100.0 or to_wall < 70.0) and float(cds["quake"]) <= 0.0:
		picks.append("quake")
	if float(cds["throw"]) <= 0.0 and _nearby_minions(80.0).size() >= 1:
		picks.append("throw")
	# 攻城锤冲锋 / 跳劈城墙：狂暴后才用（之前待在下半场）
	if raged and to_wall > 130.0 and float(cds["ram"]) <= 0.0:
		picks.append("ram")
	if raged and to_wall > 160.0 and float(cds["leap"]) <= 0.0:
		picks.append("leap")
	if float(cds["cry"]) <= 0.0 and director and director.enemies_near(global_position, 160.0).size() >= 4:
		picks.append("cry")
	if float(cds["banner"]) <= 0.0 and (_banner == null or not is_instance_valid(_banner)):
		picks.append("banner")
	if float(cds["build"]) <= 0.0:
		picks.append("build")
	if picks.is_empty():
		return
	# 近身技能优先（能抓就抓）
	var s: String = picks[0] if picks[0] in ["grab", "swipe"] else picks.pick_random()
	_start(s)


func _start(s: String) -> void:
	skill = s
	_phase = 0
	_st = 0.0
	cds[s] = _cd(s)
	used.append(s)
	velocity = Vector2.ZERO
	match s:
		"grab": _grab_start()
		"swipe": _sector_i = 0
		"quake": _quake_start()
		"throw": _ammo = _nearby_minions(80.0).slice(0, 3)
		"ram": _ram_start()
		"leap": _leap_start(true)
		"cry": _cry()
		"banner": _plant_banner()
		"build": _call_builders()


func _end_skill(rest := 0.6) -> void:
	skill = ""
	_set_frame(0)
	_global_cd = rest / rate
	if sprite:
		sprite.position = Vector2.ZERO


func _skill_tick(delta: float) -> void:
	_st += delta
	match skill:
		"grab": _grab_skill_tick()
		"swipe": _swipe_tick()
		"quake": _quake_tick()
		"throw": _throw_tick()
		"ram": _ram_tick(delta)
		"leap": _leap_tick()
		_: _end_skill()


# ------------------------------------------------------------------ 1 大手抓挠
func _grab_start() -> void:
	var p := _pink()
	if p == null:
		_end_skill(0.2)
		return
	_goal = p.global_position
	SiegeFx.warn(get_parent(), _goal, "shadow", 16.0, 0.45, Color(1, 0.5, 0.6), 0.0, 1.2, true)
	_set_frame(2)
	flash(Color(1, 0.6, 0.6), 0.45)
	Audio.play("grab", -4.0, 0.05, 0.6)


func _grab_skill_tick() -> void:
	if _st < 0.45:
		return
	var p := _pink()
	if p and p.global_position.distance_to(_goal) < 18.0 and p.can_be_grabbed() and p.status.grab(self, grab_max_time, grab_presses):
		skill = ""
		_set_frame(0)
		mode = Mode.GRABBING
		victim = p
		_grab_tick = 0.15
		if p.combo:
			p.combo._expose("sole", 1.6, grab_max_time)
		Fx.burst(get_parent(), p.global_position + Vector2(0, -2), "dust", 12, 40.0, 0.5, Vector2(0, 20))
		SpeechBubble.say(self, "抓到了！脚心——给我露出来！", 46.0, 1.6)
		SpeechBubble.say(p, "呀——脚、脚被扳起来了！", 28.0, 1.6)
		Audio.play("grab", -1.0, 0.05, 0.7)
	else:
		Fx.burst(get_parent(), _goal, "dust", 8, 30.0, 0.4, Vector2(0, 20))
		_end_skill(0.8)


# ------------------------------------------------------------------ 2 三连扫掌
func _swipe_tick() -> void:
	# 三段：每段先亮扇形预警 step 秒，到点扫下去（左 → 右 → 正前）
	var step := 0.45 / rate
	if _sector_i >= 3:
		_end_skill(0.6)
		return
	if _phase == _sector_i * 2:
		var p := _pink()
		var base := global_position.direction_to(p.global_position).angle() if p else facing.angle()
		var ang: float = base + [-0.6, 0.6, 0.0][_sector_i]
		set_meta("swipe_ang", ang)
		set_meta("swipe_t", _st)
		SiegeFx.warn(get_parent(), global_position, "sector", 66.0, step, Color(1, 0.35, 0.3), ang, 1.25, true)
		_set_frame(2 if _sector_i % 2 == 0 else 0)
		Audio.play("boss_charge", -10.0, 0.1, 1.6)
		_phase += 1
	elif _st - float(get_meta("swipe_t", 0.0)) >= step:
		_swipe_hit(float(get_meta("swipe_ang", 0.0)))
		_sector_i += 1
		_phase += 1


func _swipe_hit(ang: float) -> void:
	Audio.play("swish", -2.0, 0.1, 0.7)
	var arc := Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(1, 0.9, 0.9, 0.9)
	for k in 9:
		arc.add_point(Vector2.from_angle(ang - 0.6 + 1.2 * k / 8.0) * 56.0 + Vector2(0, -10))
	arc.add_to_group("siege_temp")
	add_child(arc)
	var tw := arc.create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.25)
	tw.tween_callback(arc.queue_free)
	Fx.burst(get_parent(), global_position + Vector2.from_angle(ang) * 40.0, "feather", 6, 60.0, 0.6, Vector2(0, 30))
	for a in _allies_in(global_position, 66.0):
		var d := global_position.direction_to(a.global_position)
		if absf(angle_difference(d.angle(), ang)) <= 0.65:
			if a is PlayableCharacter:
				a.receive_hit(make_tickle(a, 6.0, false, 160.0))
			else:
				a.receive_hit(HitData.make_attack(self, 1, 180.0))


# ------------------------------------------------------------------ 3 地震重击
func _quake_start() -> void:
	_set_frame(2)
	flash(Color(1, 0.3, 0.2), 1.0)
	SiegeFx.warn(get_parent(), global_position, "circle", 110.0, 1.0 / rate, Color(1, 0.45, 0.2), 0.0, 1.2, true)
	Audio.play("boss_charge", -3.0)
	_phase = 0


func _quake_tick() -> void:
	if sprite:
		sprite.position.x = roundf(sin(_st * 60.0)) * 1.0
	var wind := 1.0 / rate
	if _phase == 0 and _st >= wind:
		_quake_hit()
		_phase = 1
		if raged:
			SiegeFx.warn(get_parent(), global_position, "circle", 110.0, 0.6, Color(1, 0.3, 0.2), 0.0, 1.2, true)
	elif _phase == 1 and raged and _st >= wind + 0.6:
		_quake_hit()
		_phase = 2
	if (_phase >= 1 and not raged) or _phase >= 2:
		_end_skill(1.0)


func _quake_hit() -> void:
	_set_frame(0)
	SiegeFx.impact(get_parent(), global_position, 110.0, true, Color(1, 0.6, 0.35))
	Audio.play("boss_quake", 0.0, 0.05)
	for a in _allies_in(global_position, 110.0):
		a.receive_hit(HitData.make_attack(self, 2, 260.0))
		if a is SiegeSoldier:
			(a as SiegeSoldier).health.damage(2)
	if director and global_position.y - director.wall_foot_y() < 140.0:
		var w := director.segment_at(global_position.x)
		if w:
			w.take(120.0)
		var b := director.blue
		if b and is_instance_valid(b) and director.is_on_wall(b) and absf(b.global_position.x - global_position.x) < 160.0:
			director.knock_off(b, "巨魔将军的地震")


# ------------------------------------------------------------------ 4 投掷小怪上墙
func _nearby_minions(r: float) -> Array:
	if director == null:
		return []
	return director.enemies_near(global_position, r).filter(func(m): return m != self and not (m is SiegeBoss) and not m is SiegeCart \
		and not m.get_meta("siege_on_wall", false) and not m.has_meta("in_ladder") and not m.get_meta("airborne", false))


func _throw_tick() -> void:
	var gap := 0.5 / rate
	var i := int(_st / gap)
	if i > _phase and _phase < _ammo.size():
		var m: Variant = _ammo[_phase]
		_phase += 1
		if m != null and is_instance_valid(m) and (m as Actor).is_alive():
			_set_frame(2)
			var spot := Vector2(clampf(global_position.x + randf_range(-90, 90), 30, director.map_size().x - 30), director.wall_top_y() + randf_range(-2, 6))
			if director.blue and director.is_on_wall(director.blue):
				spot.x = director.blue.global_position.x + randf_range(-40, 40)
			SpeechBubble.say(self, "飞——上——去！", 46.0, 0.8)
			Audio.play("swish", -2.0, 0.1, 0.6)
			var mm := m as Monster
			mm.set_meta("airborne", true)
			_trail(mm, 0.9)
			TeamworkEffects._arc(mm, spot, 0.9, 110.0, func():
				mm.set_meta("airborne", false)
				TeamworkEffects.put_on_wall(mm, spot))
	if _phase >= _ammo.size() and _st > gap * (_ammo.size() + 1):
		_end_skill(0.8)


## 飞行物身后的拖尾。
func _trail(n: Node2D, time: float) -> void:
	var tw := n.create_tween()
	tw.set_loops(int(time / 0.05))
	tw.tween_callback(func():
		if is_instance_valid(n):
			Fx.burst(n.get_parent(), n.global_position + Vector2(0, -6), "dust", 1, 5.0, 0.3, Vector2.ZERO, Color(1, 0.9, 0.8, 0.7)))
	tw.tween_interval(0.05)


# ------------------------------------------------------------------ 5 攻城锤冲锋
func _ram_start() -> void:
	_set_frame(3)
	_goal = Vector2(global_position.x, director.wall_foot_y() + 18.0)
	SiegeFx.lane(get_parent(), global_position, _goal, 30.0, Color(1, 0.3, 0.25), 1.2 / rate, true)
	SpeechBubble.say(self, "攻城锤——撞开它！", 46.0, 1.2)
	Audio.play("cart_rumble", -2.0, 0.05, 0.7)
	_phase = 0
	set_meta("rammed", [])


func _ram_tick(delta: float) -> void:
	if _phase == 0:
		if sprite:
			sprite.position.x = roundf(sin(_st * 40.0))
		if _st >= 1.2 / rate:
			_phase = 1
		return
	if _phase == 1:
		var dir := global_position.direction_to(_goal)
		velocity = dir * 230.0
		if randf() < delta * 16.0:
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), 2), "dust", 2, 30.0, 0.6, Vector2(0, 10), Color(0.8, 0.7, 0.6))
		var hit: Array = get_meta("rammed", [])
		for a in _allies_in(global_position, 22.0):
			if not hit.has(a):
				hit.append(a)
				a.apply_knockback(global_position, 320.0)
				if a is PlayableCharacter:
					a.receive_hit(make_tickle(a, 8.0))
				else:
					a.receive_hit(HitData.make_attack(self, 2, 0.0))
		set_meta("rammed", hit)
		# 到了墙下 / 撞上东西冲不动了（超时）就停
		if global_position.distance_to(_goal) < 10.0 or global_position.y <= director.wall_foot_y() + 26.0 or _st > 1.2 / rate + 3.0:
			_phase = 2
			_st = 0.0
			velocity = Vector2.ZERO
			var w := director.segment_at(global_position.x)
			if w:
				w.take(260.0)
			var b := director.blue
			if b and is_instance_valid(b) and director.is_on_wall(b) and absf(b.global_position.x - global_position.x) < 90.0:
				director.knock_off(b, "巨魔将军的攻城锤")
			SiegeFx.impact(get_parent(), global_position + Vector2(0, -6), 80.0, true, Color(1, 0.8, 0.5))
			Fx.burst(get_parent(), global_position + Vector2(0, -16), "wood", 16, 90.0, 0.8, Vector2(0, 160), Color(0.8, 0.55, 0.35))
			Audio.play("wall_crash", 0.0, 0.05, 0.8)
			_set_frame(0)
		return
	# 喘气
	if sprite:
		sprite.scale = Vector2(_base_scale, _base_scale * (1.0 + sin(_st * 10.0) * 0.04))
	if randf() < delta * 3.0:
		Fx.burst(get_parent(), global_position + Vector2(6, -36 * _base_scale), "steam", 2, 12.0, 0.6, Vector2(0, -20), Color(1, 1, 1, 0.7))
	if _st >= 1.5:
		_end_skill(0.5)


# ------------------------------------------------------------------ 6 跳劈城墙（再跳回中间）
func _leap_start(to_wall: bool) -> void:
	var x := director.blue.global_position.x if director.blue and director.is_on_wall(director.blue) else global_position.x
	x = clampf(x + randf_range(-40, 40), 40.0, director.map_size().x - 40.0)
	_goal = Vector2(x, director.wall_foot_y() + 22.0) if to_wall else Vector2(director.map_size().x / 2.0 + randf_range(-120, 120), maxf(director.wall_foot_y() + 300.0, director.map_size().y * 0.6))
	SiegeFx.warn(get_parent(), _goal, "shadow", 46.0, 0.9 / rate, Color(1, 0.4, 0.3), 0.0, 1.2, true)
	_set_frame(2)
	flash(Color(1, 0.7, 0.4), 0.5)
	set_meta("leap_back", not to_wall)
	_phase = 0
	_st = 0.0


func _leap_tick() -> void:
	var wind := 0.9 / rate
	if _phase == 0 and _st >= wind * 0.3:
		_phase = 1
		_set_frame(4)
		Audio.play("swish", 0.0, 0.05, 0.5)
		set_physics_process(true)
		var from := global_position
		var to := _goal
		var sh := Node2D.new()
		var wr: WeakRef = weakref(self)
		var tw := create_tween()
		tw.tween_method(func(v: float):
			var me := wr.get_ref() as TrollGeneral
			if me:
				me.global_position = from.lerp(to, v)
				if me.sprite:
					me.sprite.position.y = -sin(v * PI) * 120.0, 0.0, 1.0, wind * 0.7)
		tw.tween_callback(func():
			var me := wr.get_ref() as TrollGeneral
			if me:
				me._leap_land())
		sh.queue_free()
	elif _phase == 2 and _st >= 2.0 and not bool(get_meta("leap_back", false)):
		_leap_start(false)
	elif _phase == 2 and bool(get_meta("leap_back", false)) and _st >= 0.6:
		_end_skill(0.8)


func _leap_land() -> void:
	if sprite:
		sprite.position = Vector2.ZERO
	_set_frame(0)
	_phase = 2
	_st = 0.0
	SiegeFx.impact(get_parent(), global_position, 80.0, true, Color(1, 0.55, 0.35))
	Audio.play("boss_quake", 0.0, 0.05, 1.1)
	for a in _allies_in(global_position, 80.0):
		a.receive_hit(HitData.make_attack(self, 2, 280.0))
	if not bool(get_meta("leap_back", false)):
		var w := director.segment_at(global_position.x)
		if w:
			w.take(150.0)
		var b := director.blue
		if b and is_instance_valid(b) and director.is_on_wall(b) and absf(b.global_position.x - global_position.x) < 70.0:
			director.knock_off(b, "巨魔将军的跳劈")


# ------------------------------------------------------------------ 7 战吼
func _cry() -> void:
	_set_frame(2)
	SpeechBubble.say(self, "吼——————！", 46.0, 1.2)
	Audio.play("boss_roar", 0.0, 0.05)
	SiegeFx.screen_shake(self, 3.0, 0.4)
	for i in 3:
		var r := SiegeFx.ring(get_parent(), global_position + Vector2(0, -10), 20.0, Color(1, 0.3, 0.25, 0.9), 0.7, 0.0)
		if r:
			r.modulate.a = 0.0
			var tw := r.create_tween()
			tw.tween_interval(i * 0.18)
			tw.tween_property(r, "modulate:a", 1.0, 0.01)
			tw.parallel().tween_property(r, "scale", Vector2(8, 5.5), 0.6)
	for m in director.enemies_near(global_position, 160.0):
		m.add_buff("siege_frenzy", 6.0)
		if m.sprite:
			var tw2 := m.sprite.create_tween()
			tw2.tween_property(m.sprite, "modulate", Color(1.5, 0.6, 0.6), 0.15)
			tw2.tween_property(m.sprite, "modulate", Color.WHITE, 0.6)
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c) and c.global_position.distance_to(global_position) < 120.0 and c.status:
			c.status.apply_root(0.5)
			c.shake(0.4)
	get_tree().create_timer(0.6, false).timeout.connect(func():
		if is_instance_valid(self) and skill == "cry":
			_end_skill(0.6))


# ------------------------------------------------------------------ 8 痒痒军旗
func _plant_banner() -> void:
	_set_frame(2)
	var b := TrollBanner.new()
	b.general = self
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(signf(randf() - 0.5) * 30.0, 10.0)
	_banner = b
	SpeechBubble.say(self, "插旗！小的们，给我钻出来！", 46.0, 1.4)
	Audio.play("hammer", -2.0, 0.05, 0.6)
	SiegeFx.impact(get_parent(), b.global_position, 30.0, false, Color(1, 0.4, 0.5))
	get_tree().create_timer(0.5, false).timeout.connect(func():
		if is_instance_valid(self) and skill == "banner":
			_end_skill(0.4))


# ------------------------------------------------------------------ 9 召工兵就地搭塔
func _call_builders() -> void:
	SpeechBubble.say(self, "哔——！工兵！就在这儿搭！", 46.0, 1.4)
	Audio.play("whistle", -2.0)
	var site := EnemySite.new()
	site.temporary = true
	site.build_time = 8.0
	site.index = 900 + randi() % 99
	get_parent().add_child(site)
	site.global_position = global_position + Vector2(48.0 * (1 if randf() < 0.5 else -1), 20.0)
	site.global_position = director.clamp_in_map(site.global_position) if director.has_method("clamp_in_map") else site.global_position
	site.claim(-1)
	Fx.burst(get_parent(), site.global_position, "wood", 10, 40.0, 0.6, Vector2(0, 100), Color(0.85, 0.6, 0.4))
	for i in 3:
		var e := director.spawn("goblin_engineer", "", site.global_position + Vector2.from_angle(TAU * i / 3.0) * 20.0) as GoblinEngineer
		if e:
			e.squad = -1
			e.site = site
			site.register_builder(e)
	get_tree().create_timer(0.5, false).timeout.connect(func():
		if is_instance_valid(self) and skill == "build":
			_end_skill(0.4))


# ------------------------------------------------------------------ 10 半血狂暴
func _rage() -> void:
	raged = true
	rate = 1.6
	SiegeFx.screen_flash(self, Color(1, 0.15, 0.1, 0.45), 0.6)
	SiegeFx.big_title(self, "将军狂暴了！", Color(1, 0.3, 0.25), "移速变快、技能更频繁，地震重击变成两连！")
	Audio.play("boss_roar", 1.0, 0.0, 0.85)
	SiegeFx.screen_shake(self, 5.0, 0.6)
	_base_scale = 1.15   # 新立绘本身就很大
	if sprite:
		create_tween().tween_property(sprite, "scale", Vector2.ONE * _base_scale, 0.4).set_trans(Tween.TRANS_BACK)
		sprite.self_modulate = Color(1.35, 0.75, 0.7)
	_steam = Fx.emitter(self, "steam", 14, 1.0, {"offset": Vector2(0, -40), "dir": Vector2.UP, "spread": 40.0, "speed": [10.0, 26.0],
		"gravity": Vector2(0, -20), "color": Color(1, 0.45, 0.4, 0.75), "z": 3, "extents": Vector2(14, 8)})
	_steam.emitting = true
	for i in 4:
		var c := director.spawn("shield_crab", "", global_position + Vector2.from_angle(TAU * i / 4.0 + 0.4) * 30.0)
		if c:
			c.set_meta("escort_of", self)
			c.set_meta("escort_off", Vector2.from_angle(TAU * i / 4.0 + 0.4) * 30.0)
	for k in cds:
		cds[k] = minf(float(cds[k]), 2.0)


func _rage_tick(delta: float) -> void:
	_crack_t -= delta
	if velocity.length() > 10.0 and _crack_t <= 0.0:
		_crack_t = 0.45
		var cr := SiegeFx.Cracks.new()
		cr.radius = 14.0
		cr.add_to_group("siege_temp")
		get_parent().add_child(cr)
		cr.global_position = global_position
		Fx.burst(get_parent(), global_position, "rock", 3, 25.0, 0.4, Vector2(0, 80), Color(0.6, 0.45, 0.4))
	if randf() < delta * 2.0:
		var r := SiegeFx.ring(get_parent(), global_position + Vector2(0, -6), 18.0, Color(1, 0.35, 0.3, 0.5), 0.5, 0.0)
		if r:
			r.create_tween().tween_property(r, "scale", Vector2(2.2, 1.6), 0.5)


# ------------------------------------------------------------------ 工具
func _allies_in(at: Vector2, r: float) -> Array[Actor]:
	var out: Array[Actor] = []
	if director == null:
		return out
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c) and c.is_alive() and not Downed.is_downed(c) and not director.is_on_wall(c) \
				and c.global_position.distance_to(at) <= r:
			out.append(c)
	for s in director.soldiers:
		if is_instance_valid(s) and s.is_alive() and s.global_position.distance_to(at) <= r:
			out.append(s)
	for t in director.extra_targets:
		if is_instance_valid(t) and t is Snowman and (t as Actor).is_alive() and t.global_position.distance_to(at) <= r:
			out.append(t)
	return out


func _animate(delta: float) -> void:
	if sprite == null or skill in ["ram", "leap", "quake"] or get_meta("siege_spawning", false):
		return
	_frame_t += delta
	if skill == "" and _frame_t >= 0.28:
		_frame_t = 0.0
		_frame = 1 - _frame
		if velocity.length() > 2.0:
			_set_frame(_frame)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	if not raged:
		var s := sin(_t * 4.0) * 0.03
		sprite.scale = Vector2(_base_scale + s, _base_scale - s)


func receive_hit(hit: HitData) -> bool:
	var ok := super(hit)
	if ok and hit.kind == HitData.Kind.ATTACK:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-8, 8), -24), "chip", 3, 30.0, 0.3, Vector2(0, 60), Color(1, 0.85, 0.7))
	return ok


func _on_died() -> void:
	if _banner and is_instance_valid(_banner):
		_banner.call("break_down")
	if _steam:
		_steam.emitting = false
	GameState.boss_changed.emit(null)
	SiegeFx.impact(get_parent(), global_position, 120.0, true, Color(1, 0.9, 0.6))
	SiegeFx.big_title(self, "攻城巨魔将军被打倒了！", Color(1, 0.9, 0.5))
	Fx.burst(get_parent(), global_position + Vector2(0, -20), "crystal", 30, 90.0, 1.0, Vector2(0, 60), Color(0.8, 0.95, 1.0))
	if director:
		director.add_crystals(30)
	super()


## 痒痒军旗：有血量，旗边的怪加速、每 SPAWN_GAP 秒从地里钻出一只小怪；拆掉碎布飞散。
class TrollBanner extends Actor:
	const R := 120.0
	const SPAWN_GAP := 4.0
	var general: Node
	var _t := 0.0
	var _spawn_t := SPAWN_GAP
	var _spr: Sprite2D
	var _glow := 0.0

	func _setup() -> void:
		set_faction(Faction.Type.ENEMY)
		add_to_group("siege_enemy_tower")   # 冰塔 / 士兵 / 法术都会打它
		add_to_group("siege_temp")
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 30)
		cs.shape = r
		cs.position = Vector2(0, -15)
		add_child(cs)
		var hc := HealthComponent.new()
		hc.name = "Health"
		hc.max_hp = 20
		add_child(hc)
		health = hc
		hc.fill()
		hc.died.connect(break_down)
		_spr = Sprite2D.new()
		_spr.texture = IceTower.TEX
		_spr.region_enabled = true
		_spr.region_rect = IceTower.region("banner_0")
		_spr.offset = Vector2(4, -17)
		add_child(_spr)
		sprite = _spr
		hurt_invuln_time = 0.2
		var lt := PointLight2D.new()
		lt.texture = load("res://assets/lights/light_soft.tres")
		lt.color = Color(1, 0.35, 0.4)
		lt.energy = 0.7
		lt.texture_scale = 0.8
		lt.position = Vector2(0, -20)
		add_child(lt)

	func _tick(delta: float) -> void:
		_t += delta
		_spr.region_rect = IceTower.region("banner_%d" % (int(_t * 4.0) % 2))
		queue_redraw()
		var d := SiegeDirector.current
		if d == null or d.state != "fight":
			return
		if int(_t * 2.0) != int((_t - delta) * 2.0):
			for m in d.enemies_near(global_position, R):
				m.add_buff("siege_frenzy", 1.2)
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = SPAWN_GAP
			d.spawn(TrollGeneral.MINIONS.pick_random(), "", global_position + Vector2(randf_range(-40, 40), randf_range(-20, 30)))
			_glow = 1.0
		_glow = maxf(0.0, _glow - delta * 2.0)
		if randf() < delta * 3.0:
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-R, R) * 0.6, randf_range(-R, R) * 0.3), "ember", 1, 10.0, 0.8, Vector2(0, -20), Color(1, 0.4, 0.5))

	func _draw() -> void:
		var a := 0.12 + 0.06 * sin(_t * 3.0) + _glow * 0.2
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, R, Color(1, 0.25, 0.35, a * 0.5))
		draw_arc(Vector2.ZERO, R, _t, _t + TAU * 0.85, 48, Color(1, 0.4, 0.5, a + 0.25), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func break_down() -> void:
		if not is_inside_tree():
			return
		Fx.burst(get_parent(), global_position + Vector2(4, -20), "cloth", 18, 70.0, 0.9, Vector2(0, 90), Color(0.9, 0.25, 0.3))
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "wood", 8, 50.0, 0.6, Vector2(0, 120), Color(0.7, 0.5, 0.35))
		Audio.play("break", -2.0, 0.05)
		GameState.notify("痒痒军旗被拆掉了！")
		queue_free()
