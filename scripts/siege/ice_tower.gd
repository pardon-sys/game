class_name IceTower
extends Actor
## 攻防战的冰塔（建在冰塔格 BuildPad 上：粉色公主选塔付冰晶，蓝色公主从城墙放冰光造出来）。6 种，每种 2 级：
##   icicle   冰锥塔：自动射冰锥打射程内最近的怪（盾甲螃蟹正面挡得住）
##   snowman  雪人召唤塔：每隔一段时间放出小雪人（Snowman），去挠 / 推怪物
##   decoy    诱饵冰雕：有血量，周围 lure 半径内的怪和攻城车优先打它
##   mint     薄荷冰泉：范围内的公主闷笑慢慢下降（粉色公主的 AI 闷笑高时会跑过来）
##   frost    寒霜塔：范围减速，每隔几秒冻住范围里的怪一下
##   repair   冰墙修补塔：慢慢修复它身后的那段城墙
##   campfire 篝火塔：一大圈火光（torch 组、light_radius）：幽灵现形、暖炉史莱姆化得更快，圈里友军闷笑慢慢降
##   ballista 冰棱弩炮：射程很远的穿透冰棱，优先打敌塔 / 攻城车 / Boss（对它们 ×3）
##   cocoa    热可可摊：附近友军攻击更快（town_cocoa 状态）、走得更快，粉色公主闷笑降得更快
## 镇民支援的倍数：tower_dmg 伤害、tower_range 射程；snowmen 雪人多召几只（SiegeDirector.town）。
## 范围伤害：冰锥落地溅射（splash）、寒霜塔冻住时冰爆（burst）、小雪人扔雪球（ball_splash）、弩炮射到尽头开冰花（bloom）。
## 随波次解锁（towers.json 的 unlock_wave）：
##   mortar 冰霜迫击炮（抛大冰弹到怪最密处）/ vortex 冰风旋涡塔（身边一圈冰风持续伤害 + 外推）/ resonance 冰晶共鸣塔（冰光连跳）/
##   meteor 冰陨星台（蓄力砸全场最大的怪堆）/ hotspring 温泉治疗泉（降闷笑、士兵回血、修墙）/ lamp 冰灯塔（幽灵现形、怪减速、敌塔变慢）/
##   shield 冰盾发生器（给友军套冰盾 ice_shield，挡掉下一次挠痒 / 抓取）。
## 每种 3 级（MAX_LEVEL），3 级塔身边有一圈慢慢转的光环。
## 数值在 data/siege/towers.json（tools/build/gen_floor06_siege.py 生成）：{种类: {name, cost, upgrade, desc, levels: [{...}, {...}]}}。
## 冰塔挡路（world 层），只有诱饵冰雕在玩家一方的层上（怪物会去打它）。暖炉史莱姆贴着会把塔融化（melt）。
## 图：assets/generated/siege/towers.png 的 tower_<种类>_<级>。

const PATH := "res://data/siege/towers.json"
const TEX := preload("res://assets/generated/siege/towers.png")
const META := "res://assets/generated/siege/towers.json"
## 冰塔被融化的耐久（诱饵冰雕用 levels 里的 hp）
const MELT_HP := 40.0
const MAX_LEVEL := 3

static var _data := {}
static var _meta := {}

@export var kind := "icicle"
@export var level := 1

var pad: Node2D
var director: SiegeDirector
var lure := 0.0
var melt_left := MELT_HP
var _t := 0.0
var _spr: Sprite2D
var _snowmen: Array[Node] = []
## 篝火塔：TickleGhost 按这个半径现形
var light_radius := 0.0
var lit := false


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func info(k: String) -> Dictionary:
	var e: Variant = data().get(k, {})
	return e if e is Dictionary else {}


static func region(key: String) -> Rect2:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
		_meta = parsed if parsed is Dictionary else {}
	var r: Variant = _meta.get(key, [0, 0, 1, 1])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func kinds() -> Array:
	return ["icicle", "snowman", "decoy", "mint", "frost", "repair", "campfire", "ballista", "cocoa",
		"mortar", "vortex", "resonance", "meteor", "hotspring", "lamp", "shield"]


## 第几波开始能造（towers.json 的 unlock_wave，没写 = 1）。
static func unlock_wave(k: String) -> int:
	return int(info(k).get("unlock_wave", 1))


## 现在能不能造（按攻防战导演当前的波次）。
static func unlocked(k: String) -> bool:
	var d := SiegeDirector.current
	return d == null or d.wave >= unlock_wave(k)


func p(key: String, default: Variant = 0.0) -> Variant:
	var lv: Array = info(kind).get("levels", [])
	if lv.is_empty():
		return default
	return (lv[clampi(level - 1, 0, lv.size() - 1)] as Dictionary).get(key, default)


func _setup() -> void:
	add_to_group("siege_tower")
	if kind == "mint":
		add_to_group("siege_mint")
	director = SiegeDirector.current
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 8)
	shape.shape = r
	shape.position = Vector2(0, -4)
	add_child(shape)
	collision_mask = 0
	if kind == "decoy":
		set_faction(Faction.Type.PLAYER)
		collision_layer = 2 | 1
		var hc := HealthComponent.new()
		hc.name = "Health"
		hc.max_hp = int(p("hp", 60))
		add_child(hc)
		health = hc
		hc.fill()
		hc.died.connect(_die)
		lure = float(p("lure", 110.0))
		if director:
			director.extra_targets.append(self)
	else:
		set_faction(Faction.Type.NEUTRAL)
		collision_layer = 1
		# 血量：只有抢掠小队会来拆（WaveFeatures 的 raiders），工匠会修；拆掉了基座还在
		var hc2 := HealthComponent.new()
		hc2.name = "Health"
		hc2.max_hp = max_hp_now()
		add_child(hc2)
		health = hc2
		hc2.fill()
		hc2.died.connect(_die)
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.region_enabled = true
	_spr.region_rect = region("tower_%s_%d" % [kind, level])
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	add_child(_spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_soft.tres")
	light.color = {"mint": Color(0.6, 1.0, 0.85), "campfire": Color(1.0, 0.65, 0.35), "cocoa": Color(1.0, 0.8, 0.55)}.get(kind, Color(0.6, 0.85, 1.0))
	light.energy = 0.9 if kind == "campfire" else 0.5
	light.texture_scale = 1.6 if kind == "campfire" else 0.5
	if kind == "campfire":
		lit = true
		light_radius = float(p("radius", 110.0))
		add_to_group("torch")
		_fire = Fx.emitter(self, "flame", 14, 0.7, {"offset": Vector2(0, -12), "dir": Vector2.UP, "spread": 20.0, "speed": [14.0, 30.0],
			"gravity": Vector2(0, -30), "color": Color(1, 0.75, 0.4), "z": 3, "extents": Vector2(5, 2)})
		_fire.emitting = true
		var em := Fx.emitter(self, "ember", 6, 1.4, {"offset": Vector2(0, -16), "dir": Vector2.UP, "spread": 35.0, "speed": [10.0, 22.0],
			"gravity": Vector2(0, -8), "color": Color(1, 0.6, 0.3), "z": 3})
		em.emitting = true
	elif kind == "lamp":
		lit = true
		light_radius = float(p("radius", 140.0))
		add_to_group("torch")
		light.color = Color(0.6, 0.85, 1.0)
		light.energy = 0.9
		light.texture_scale = 1.8
	elif kind == "vortex":
		var sn := Fx.emitter(self, "snow", 18, 1.2, {"offset": Vector2(0, -8), "dir": Vector2.RIGHT, "spread": 180.0, "speed": [30.0, 60.0],
			"gravity": Vector2.ZERO, "color": Color(0.9, 0.97, 1.0), "z": 3, "extents": Vector2(20, 8)})
		sn.emitting = true
	elif kind == "hotspring":
		var st2 := Fx.emitter(self, "steam", 8, 1.8, {"offset": Vector2(0, -12), "dir": Vector2.UP, "spread": 25.0, "speed": [6.0, 14.0],
			"gravity": Vector2(0, -6), "color": Color(1, 1, 1, 0.6), "z": 3, "extents": Vector2(8, 2)})
		st2.emitting = true
	elif kind == "cocoa":
		var st := Fx.emitter(self, "steam", 5, 1.6, {"offset": Vector2(0, -22), "dir": Vector2.UP, "spread": 12.0, "speed": [6.0, 12.0],
			"gravity": Vector2(2, -6), "color": Color(1, 1, 1, 0.6), "z": 3})
		st.emitting = true
	light.position = Vector2(0, -14)
	add_child(light)
	# 破冰而出
	_spr.scale = Vector2(1, 0.1)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "crystal", 16, 60.0, 0.6, Vector2(0, 60), Color(0.8, 0.94, 1.0))


## 普通冰塔每级的血量（诱饵雪人用自己的 hp 参数）
const RAID_HP := [30, 45, 60]


func max_hp_now() -> int:
	return int(p("hp", RAID_HP[clampi(level - 1, 0, 2)]))


## 被抢掠小队打：掉血、抖一下、冒冰屑。
func raid_hit(dmg: int, from: Node2D) -> void:
	if health == null or not is_alive():
		return
	health.damage(dmg)
	flash(Color(1, 0.5, 0.45), 0.12)
	if _spr:
		_spr.position.x = 2.0 if from and from.global_position.x < global_position.x else -2.0
		create_tween().tween_property(_spr, "position:x", 0.0, 0.12)
	Fx.burst(get_parent(), global_position + Vector2(randf_range(-6, 6), -12), "chip", 3, 30.0, 0.3, Vector2(0, 60), Color(0.8, 0.94, 1.0))
	Audio.play("ice_crack", -12.0, 0.2, 1.3)


func upgrade() -> void:
	level = mini(level + 1, MAX_LEVEL)
	_spr.region_rect = region("tower_%s_%d" % [kind, level])
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	if health:
		health.max_hp = max_hp_now()
		health.fill()
	lure = float(p("lure", lure))
	_spr.scale = Vector2(1.2, 0.8)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "crystal", 20, 70.0, 0.6, Vector2(0, 60), Color(0.9, 0.97, 1.0))


func receive_hit(hit: HitData) -> bool:
	if kind != "decoy" or hit.kind != HitData.Kind.ATTACK:
		return false
	return super(hit)


## 暖炉史莱姆贴着：慢慢融化，融完就塌了。
func melt(amount: float) -> void:
	melt_left -= amount
	_spr.modulate = Color(1, 1, 1, 0.5 + 0.5 * maxf(melt_left, 0.0) / MELT_HP)
	if melt_left <= 0.0:
		collapse()


func collapse(keep_pad := false) -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "drop", 14, 50.0, 0.6, Vector2(0, 80), Color(0.7, 0.9, 1.0))
	Audio.play("ice_crack", -2.0, 0.1, 0.8)
	if pad and is_instance_valid(pad):
		if keep_pad and pad.has_method("tower_raided"):
			pad.call("tower_raided")
		elif pad.has_method("tower_gone"):
			pad.call("tower_gone")
	queue_free()


## 被打倒：诱饵雪人连基座一起没了；普通冰塔（被抢掠小队拆）基座留着。
func _on_died() -> void:
	if kind != "decoy":
		Fx.burst(get_parent(), global_position + Vector2(0, -14), "crystal", 18, 70.0, 0.7, Vector2(0, 90), Color(0.8, 0.94, 1.0))
		GameState.notify("%s被抢掠小队拆掉了！（基座还在，按 B 重新造）" % str(info(kind).get("name", kind)))
	collapse(kind != "decoy" or get_meta("fortress_keep_pad",false))


var _fire: CPUParticles2D


func _town(key: String) -> float:
	return director.town.mul(key) if director and director.town else 1.0


func _dmg(base: int) -> int:
	var v := float(base) * _town("tower_dmg")
	return int(v) + (1 if randf() < v - floorf(v) else 0)


func _tick(delta: float) -> void:
	_t -= delta
	if director == null or director.get("state") == "failed":
		return
	queue_redraw()
	match kind:
		"icicle": _icicle()
		"snowman": _snowman()
		"mint": _mint(delta)
		"frost": _frost(delta)
		"repair": _repair()
		"campfire": _campfire(delta)
		"ballista": _ballista()
		"cocoa": _cocoa()
		"mortar": _mortar()
		"vortex": _vortex()
		"resonance": _resonance()
		"meteor": _meteor(delta)
		"hotspring": _hotspring()
		"lamp": _lamp()
		"shield": _shield()


## 范围类塔在地上画一圈淡淡的范围。
func _draw() -> void:
	var r := 0.0
	var col := Color(1, 1, 1)
	match kind:
		"campfire":
			r = float(p("radius", 110.0))
			col = Color(1, 0.65, 0.3)
		"cocoa":
			r = float(p("radius", 90.0))
			col = Color(1, 0.8, 0.5)
		"mint":
			r = float(p("radius", 60.0))
			col = Color(0.6, 1, 0.85)
		"frost":
			r = float(p("radius", 70.0))
			col = Color(0.7, 0.9, 1)
		"vortex":
			r = float(p("radius", 80.0))
			col = Color(0.8, 0.95, 1)
		"hotspring":
			r = float(p("radius", 110.0))
			col = Color(0.6, 0.95, 1)
		"lamp":
			r = float(p("radius", 140.0))
			col = Color(0.6, 0.85, 1)
		"shield":
			r = float(p("radius", 120.0))
			col = Color(0.75, 0.9, 1)
	var tt := Time.get_ticks_msec() / 1000.0
	# 3 级塔：一圈慢慢转的光环
	if level >= 3:
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, 16.0, tt, tt + TAU * 0.7, 24, Color(1, 0.9, 0.5, 0.75), 1.5)
		draw_arc(Vector2.ZERO, 19.0, -tt * 1.3, -tt * 1.3 + TAU * 0.4, 16, Color(0.8, 0.95, 1, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "vortex":
		# 冰风：几道转着的风线
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
		for i in 4:
			var a0 := tt * 3.0 + i * TAU / 4.0
			draw_arc(Vector2.ZERO, r * (0.45 + 0.13 * i), a0, a0 + 1.4, 16, Color(0.92, 0.98, 1.0, 0.45), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if r <= 0.0:
		return
	var a := 0.05 + 0.02 * sin(Time.get_ticks_msec() / 400.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.25), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _campfire(_delta: float) -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 110.0))
	light_radius = r
	for c in director.town.allies() if director.town else []:
		if c is PlayableCharacter and (c as PlayableCharacter).laugh and c.global_position.distance_to(global_position) <= r:
			(c as PlayableCharacter).laugh.reduce(float(p("decay", 3.0)) * 0.5)
	# 暖炉史莱姆在火边化得更快
	for m in director.enemies_near(global_position, r):
		if m is WarmSlime:
			m.receive_hit(HitData.make_attack(self, 1, 0.0, true))


func _ballista() -> void:
	if _t > 0.0:
		return
	var rng := float(p("range", 420.0)) * _town("tower_range")
	# 先找敌塔 / 大型怪（攻城车、Boss），没有再打最近的怪
	var target: Node2D = null
	var best := rng
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		var d := global_position.distance_to((t as Node2D).global_position)
		if d < best:
			best = d
			target = t
	if target == null:
		for m in director.enemies_near(global_position, rng, false):
			var d2 := FortressRules.distance(m,global_position)
			var big := m is SiegeCart or m.is_in_group("siege_boss")
			if (big and d2 < rng) or (target == null and d2 < best):
				best = d2
				target = m
				if big:
					break
	if target == null:
		_t = 0.4
		return
	_t = float(p("interval", 2.6)) * (director.town.mul("ally_cd") if director.town else 1.0)
	var from := global_position + Vector2(0, -20)
	var dir := from.direction_to(FortressRules.point(target,from) + Vector2(0, -8))
	var reach := rng + 40.0
	var dmg := _dmg(int(p("damage", 3)))
	var pierce := int(p("pierce", 4))
	# 穿透：一条直线上的怪 / 敌塔依次挨打
	var hit: Array[Node2D] = []
	for m in director.enemies_near(from + dir * reach / 2.0, reach / 2.0 + 12.0, false):
		var rel := FortressRules.point(m,from) + Vector2(0, -8) - from
		var along := rel.dot(dir)
		if along > 0.0 and along < reach and absf(rel.cross(dir)) < 12.0:
			hit.append(m)
	hit.sort_custom(func(a, b): return FortressRules.distance(a,from) < FortressRules.distance(b,from))
	hit = hit.slice(0, pierce)
	if target.is_in_group("siege_enemy_tower") and not hit.has(target):
		hit.append(target)
	for n in hit:
		var big2 := n is SiegeCart or n.is_in_group("siege_boss") or n.is_in_group("siege_enemy_tower")
		(n as Actor).receive_hit(HitData.make_attack(self, dmg * (3 if big2 else 1), 80.0, true))
		Fx.burst(get_parent(), n.global_position + Vector2(0, -8), "crystal", 5, 50.0, 0.4, Vector2(0, 60), Color(0.8, 0.95, 1.0))
	var end := from + dir * reach
	# 射到尽头（最后一个打到的东西那里）炸开一大朵冰花
	var bloom_at: Vector2 = FortressRules.point(hit.back(),from) if not hit.is_empty() else end
	var bloom := float(p("bloom", 0.0))
	if bloom > 0.0:
		var bd := _dmg(int(p("bloom_damage", 2)))
		for m in director.enemies_near(bloom_at, bloom, false):
			m.receive_hit(HitData.make_attack(self, bd, 60.0, true))
		SiegeFx.impact(get_parent(), bloom_at, bloom, false, Color(0.8, 0.95, 1.0))
		for i in 10:
			Fx.burst(get_parent(), bloom_at + Vector2.from_angle(TAU * i / 10.0) * bloom * 0.6, "crystal", 2, 30.0, 0.4, Vector2(0, 40), Color(0.85, 0.97, 1.0))
	SiegeFx.beam(get_parent(), from, end, Color(0.75, 0.92, 1.0, 0.9), 0.18, 3.0)
	SiegeFx.lane(get_parent(), from, end, 2.0, Color(1, 1, 1), 0.25)
	if _spr:
		_spr.position = -dir * 2.0
		create_tween().tween_property(_spr, "position", Vector2.ZERO, 0.2)
	Audio.play("icicle", -6.0, 0.1, 0.6)


func _cocoa() -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 90.0))
	if director.town == null:
		return
	for a in director.town.allies():
		if is_instance_valid(a) and a.global_position.distance_to(global_position) <= r:
			a.add_buff("town_cocoa" if level == 1 else "town_cocoa2", 1.0)
			if a is PlayableCharacter and (a as PlayableCharacter).laugh:
				(a as PlayableCharacter).laugh.reduce(float(p("decay", 4.0)) * 0.5)
	if randf() < 0.4:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-r, r) * 0.5, randf_range(-r, r) * 0.3), "heart", 1, 10.0, 0.8, Vector2(0, -20), Color(1, 0.85, 0.6))


func _icicle() -> void:
	if _t > 0.0:
		return
	var best: Node2D = null
	var best_d := float(p("range", 140.0)) * _town("tower_range")
	for m in director.enemies_near(global_position, best_d, false):
		var d := FortressRules.distance(m,global_position)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		# 没有怪：打射程内的敌塔
		for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
			var d2 := global_position.distance_to((t as Node2D).global_position)
			if d2 < best_d:
				best_d = d2
				best = t
	if best == null:
		_t = 0.3
		return
	_t = float(p("interval", 1.2)) * (director.town.mul("ally_cd") if director.town else 1.0)
	var dmg := _dmg(int(p("damage", 1)))
	var splash := float(p("splash", 0.0))
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -24), best, "proj_icicle", 260.0,
		_icicle_hit(weakref(self), dmg, splash, global_position))
	Audio.play("icicle", -12.0, 0.2)


## 冰锥命中的回调。写在静态函数里：飞行途中冰塔被拆掉，回调也不会跟着失效（实例方法里的闭包会绑在塔上）。
static func _icicle_hit(wr: WeakRef, dmg: int, splash: float, from: Vector2) -> Callable:
	return func(t: Node):
		if not is_instance_valid(t) or not (t is Actor):
			return
		var me := wr.get_ref() as IceTower
		var src: Node = me if me else t
		(t as Actor).receive_hit(HitData.make_attack(src, dmg, 40.0, true))
		var at := FortressRules.point(t, from)
		# 落地碎开：溅射一小片
		var d := SiegeDirector.current
		if splash > 0.0 and d:
			for m in d.enemies_near(at, splash, false):
				if m != t:
					m.receive_hit(HitData.make_attack(src, maxi(1, dmg - 1), 30.0, true))
			SiegeFx.ring(t.get_parent(), at, splash, Color(0.8, 0.95, 1.0, 0.8), 0.35, 0.15)
		Fx.burst(t.get_parent(), at + Vector2(0, -8), "crystal", 6, 40.0, 0.4, Vector2(0, 60), Color(0.85, 0.95, 1.0))


func _snowman() -> void:
	if _t > 0.0:
		return
	_t = float(p("interval", 12.0))
	_snowmen = _snowmen.filter(func(s): return is_instance_valid(s))
	var n := int(p("count", 2)) + int(director.town.add("snowmen") if director.town else 0.0)
	for i in n:
		if _snowmen.size() >= n * 2:
			break
		var s := Snowman.new()
		s.hp = int(p("snow_hp", 4))
		s.ball_splash = float(p("ball_splash", 18.0))
		s.ball_damage = int(p("ball_damage", 1))
		get_parent().add_child(s)
		s.global_position = global_position + Vector2(randf_range(-14, 14), 10)
		_snowmen.append(s)
		if director:
			director.extra_targets.append(s)
			if director.town:
				director.town.apply_to(s)


func _mint(_delta: float) -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 60.0))
	var per := float(p("decay", 6.0)) * 0.5
	for n in get_tree().get_nodes_in_group("player_chars"):
		var c := n as PlayableCharacter
		if c and c.is_alive() and c.laugh and c.global_position.distance_to(global_position) <= r:
			c.laugh.set_value(maxf(0.0, c.laugh.value - per))
	Fx.burst(get_parent(), global_position + Vector2(randf_range(-r, r) * 0.5, -6), "snow", 2, 18.0, 0.8, Vector2(0, -10), Color(0.7, 1.0, 0.9))


var _freeze_t := 0.0


func _frost(delta: float) -> void:
	_freeze_t -= delta
	if _t > 0.0:
		return
	_t = 0.4
	var r := float(p("radius", 70.0))
	var ms := director.enemies_near(global_position, r)
	for m in ms:
		m.add_buff("siege_chill", 0.6)
	if _freeze_t <= 0.0 and not ms.is_empty():
		_freeze_t = 5.0
		var burst := _dmg(int(p("burst", 1)))
		for m in ms:
			m.stun(float(p("freeze", 1.0)))
			m.receive_hit(HitData.make_attack(self, burst, 0.0, true))
		# 冰爆：冲击环 + 一圈冰花
		var rg := SiegeFx.ring(get_parent(), global_position, r * 0.3, Color(0.85, 0.97, 1.0, 0.9), 0.5, 0.2)
		if rg:
			rg.create_tween().tween_property(rg, "scale", Vector2(3.4, 3.4), 0.4)
		for i in 8:
			Fx.burst(get_parent(), global_position + Vector2.from_angle(TAU * i / 8.0) * r * 0.7, "crystal", 3, 30.0, 0.4, Vector2(0, 40), Color(0.85, 0.97, 1.0))
		Audio.play("chime", -10.0, 0.1, 1.9)


func _repair() -> void:
	if _t > 0.0:
		return
	_t = 1.0
	var w: SiegeWall = director.segment_at(global_position.x)
	if w and w.taken > 0.0:
		var got := w.repair(float(p("repair", 3.0)))
		if got > 0.0:
			SiegeFx.beam(get_parent(), global_position + Vector2(0, -20), Vector2(global_position.x, w.foot_y() - 10.0),
				Color(0.6, 0.9, 1.0, 0.6), 0.25, 1.5)



# ------------------------------------------------------------------ 随波次解锁的新塔
## 冰霜迫击炮：往射程里怪最密的地方抛大冰弹，落点影子预警，炸开一大片 + 减速。
func _mortar() -> void:
	if _t > 0.0:
		return
	var rng := float(p("range", 520.0)) * _town("tower_range")
	var at: Variant = director.densest(36.0, global_position, rng)
	if not (at is Vector2):
		_t = 0.6
		return
	_t = float(p("interval", 4.0)) * _town("ally_cd")
	var to: Vector2 = at
	var r := float(p("radius", 48.0))
	var dmg := _dmg(int(p("damage", 2)))
	var fly := clampf(global_position.distance_to(to) / 320.0, 0.6, 1.4)
	SiegeFx.warn(get_parent(), to, "shadow", r, fly, Color(0.75, 0.92, 1.0))
	var ball := Sprite2D.new()
	ball.texture = TEX
	ball.region_enabled = true
	ball.region_rect = region("proj_mortar")
	ball.z_index = 30
	ball.add_to_group("siege_temp")
	get_parent().add_child(ball)
	var from := global_position + Vector2(0, -26)
	var parent := get_parent()
	var wr: WeakRef = weakref(self)
	var tw := ball.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(ball):
			ball.global_position = from.lerp(to, v) + Vector2(0, -sin(v * PI) * 110.0)
			if randf() < 0.5:
				Fx.burst(parent, ball.global_position, "snow", 1, 5.0, 0.4, Vector2.ZERO, Color(0.9, 0.97, 1.0)), 0.0, 1.0, fly)
	tw.tween_callback(func():
		if is_instance_valid(ball):
			ball.queue_free()
		var me := wr.get_ref() as IceTower
		var src: Node = me if me else parent
		var d := SiegeDirector.current
		if d:
			for m in d.enemies_near(to, r, false):
				m.receive_hit(HitData.make_attack(src, dmg, 90.0, true))
				m.add_buff("siege_chill", 2.0)
		SiegeFx.impact(parent, to, r, false, Color(0.8, 0.95, 1.0))
		Fx.burst(parent, to + Vector2(0, -6), "crystal", 16, r * 1.2, 0.6, Vector2(0, 100), Color(0.85, 0.97, 1.0))
		if d and d.on_screen(to):
			SiegeFx.screen_shake(parent, 2.0, 0.2)
		Audio.play("ice_crack", -2.0, 0.1, 0.7))
	Audio.play("swish", -6.0, 0.1, 0.6)


## 冰风旋涡塔：身边一圈冰风，每 0.5 秒掉血、往外推。
func _vortex() -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 80.0))
	var dmg := _dmg(int(p("damage", 1)))
	var push := float(p("push", 40.0))
	for m in director.enemies_near(global_position, r, false):
		m.receive_hit(HitData.make_attack(self, dmg, 0.0, true))
		m.apply_knockback(global_position, push * 3.0)
	if randf() < 0.6:
		var a := randf() * TAU
		Fx.burst(get_parent(), global_position + Vector2.from_angle(a) * r * 0.7 + Vector2(0, -6), "snow", 3, 40.0, 0.5, Vector2.from_angle(a + PI / 2) * 40.0, Color(0.9, 0.97, 1.0))


## 冰晶共鸣塔：冰光在怪之间连跳 jumps 下，每下掉血、冻 0.3 秒。
func _resonance() -> void:
	if _t > 0.0:
		return
	var rng := float(p("range", 200.0)) * _town("tower_range")
	var first: Monster = null
	var bd := rng
	for m in director.enemies_near(global_position, rng, false):
		var dd := FortressRules.distance(m,global_position)
		if dd < bd:
			bd = dd
			first = m
	if first == null:
		_t = 0.4
		return
	_t = float(p("interval", 2.2)) * _town("ally_cd")
	var dmg := _dmg(int(p("damage", 2)))
	var hit: Array = [first]
	var cur: Monster = first
	for i in int(p("jumps", 5)) - 1:
		var nxt: Monster = null
		var nd := 70.0
		for m in director.enemies_near(cur.global_position, 70.0, false):
			if hit.has(m):
				continue
			var dd2 := FortressRules.distance(m,cur.global_position)
			if dd2 < nd:
				nd = dd2
				nxt = m
		if nxt == null:
			break
		hit.append(nxt)
		cur = nxt
	var prev := global_position + Vector2(0, -24)
	for i in hit.size():
		var m: Monster = hit[i]
		var at := FortressRules.point(m,prev) + Vector2(0, -8)
		_arc_line(prev, at, i * 0.05)
		# 电弧从上一只怪那里跳过来：唯一打得动盾甲螃蟹的（伤害 ×0.1，见 ShieldCrab）
		var arc := HitData.make_attack(self, dmg, 0.0, true)
		arc.tag = ShieldCrab.RESONANCE_TAG
		m.receive_hit(arc)
		m.stun(0.3)
		Fx.burst(get_parent(), at, "crystal", 4, 30.0, 0.4, Vector2(0, 40), Color(0.85, 0.75, 1.0))
		prev = at
	Audio.play("chime", -6.0, 0.1, 1.7)


## 一段锯齿状的冰光（共鸣塔的连跳）。
func _arc_line(a: Vector2, b: Vector2, delay: float) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.85, 0.75, 1.0, 0.95)
	var n := 6
	for k in n + 1:
		var pt := a.lerp(b, float(k) / n)
		if k > 0 and k < n:
			pt += (b - a).orthogonal().normalized() * randf_range(-5, 5)
		l.add_point(pt)
	l.z_index = 30
	l.add_to_group("siege_temp")
	l.modulate.a = 0.0
	get_parent().add_child(l)
	l.global_position = Vector2.ZERO
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.02)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## 冰陨星台：蓄力 interval 秒（塔顶越来越亮），往全场最大的怪堆砸冰陨星。
var _charge_glow := 0.0


func _meteor(delta: float) -> void:
	var iv := float(p("interval", 12.0)) * _town("ally_cd")
	_charge_glow = clampf(1.0 - _t / iv, 0.0, 1.0)
	if _spr:
		_spr.self_modulate = Color(1, 1, 1).lerp(Color(1.6, 1.8, 2.2), _charge_glow * _charge_glow)
	if _t > 0.0:
		if _t < 1.2 and randf() < delta * 10.0:
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), -30), "crystal", 1, 20.0, 0.5, Vector2(0, -30), Color(0.85, 0.97, 1.0))
		return
	var at: Variant = director.densest(60.0)
	if not (at is Vector2):
		_t = 1.0
		return
	_t = iv
	var to: Vector2 = at
	var r := float(p("radius", 90.0))
	var dmg := _dmg(int(p("damage", 4)))
	var frz := float(p("freeze", 2.0))
	SiegeFx.warn(get_parent(), to, "shadow", r, 1.0, Color(0.7, 0.9, 1.0))
	SiegeFx.beam(get_parent(), global_position + Vector2(0, -30), global_position + Vector2(0, -400), Color(0.8, 0.95, 1.0, 0.9), 0.3, 4.0)
	Audio.play("chime", -2.0, 0.0, 0.8)
	var rock := Sprite2D.new()
	rock.texture = TEX
	rock.region_enabled = true
	rock.region_rect = region("proj_meteor")
	rock.z_index = 40
	rock.scale = Vector2(1.6, 1.6)
	rock.add_to_group("siege_temp")
	var parent := get_parent()
	parent.add_child(rock)
	var start := to + Vector2(-160, -420)
	rock.global_position = start
	var wr: WeakRef = weakref(self)
	var tw := rock.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(rock):
			rock.global_position = start.lerp(to, v)
			rock.rotation += 0.2
			Fx.burst(parent, rock.global_position, "snow", 2, 20.0, 0.5, Vector2(0, -20), Color(0.85, 0.97, 1.0)), 0.0, 1.0, 1.0)
	tw.tween_callback(func():
		if is_instance_valid(rock):
			rock.queue_free()
		var me := wr.get_ref() as IceTower
		var src: Node = me if me else parent
		var d := SiegeDirector.current
		if d:
			for m in d.enemies_near(to, r, false):
				var fall := HitData.make_attack(src, dmg, 160.0, true)
				m.receive_hit(fall)
				m.stun(frz)
			for t in parent.get_tree().get_nodes_in_group("siege_enemy_tower"):
				if (t as Node2D).global_position.distance_to(to) <= r:
					(t as Actor).receive_hit(HitData.make_attack(src, dmg, 0.0, true))
		SiegeFx.impact(parent, to, r, true, Color(0.8, 0.95, 1.0))
		Fx.burst(parent, to + Vector2(0, -8), "crystal", 30, r * 1.5, 0.9, Vector2(0, 120), Color(0.85, 0.97, 1.0))
		Audio.play("wall_crash", 0.0, 0.05, 1.3))


## 温泉治疗泉：范围内公主闷笑降、士兵回血、修身后那段城墙。
var _heal_t := 0.0


func _hotspring() -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 110.0))
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c) and c.laugh and c.global_position.distance_to(global_position) <= r:
			c.laugh.reduce_ratio(float(p("decay", 4.0)) / 100.0 * 0.5)
	_heal_t -= 0.5
	if _heal_t <= 0.0:
		_heal_t = 2.0
		var healed := false
		for s2 in director.soldiers:
			if is_instance_valid(s2) and not s2.retreating and s2.global_position.distance_to(global_position) <= r and s2.health.hp < s2.health.max_hp:
				s2.health.heal(int(p("heal", 1)))
				healed = true
				Fx.burst(get_parent(), s2.global_position + Vector2(0, -12), "heart", 2, 15.0, 0.6, Vector2(0, -20), Color(0.6, 1.0, 0.8))
		if healed:
			SiegeFx.ring(get_parent(), global_position, r, Color(0.6, 1.0, 0.9, 0.5), 0.6, 0.05)
	var w: SiegeWall = director.segment_at(global_position.x)
	if w and w.taken > 0.0:
		w.repair(float(p("repair", 2.0)) * 0.5)
	if randf() < 0.5:
		Fx.burst(get_parent(), global_position + Vector2.from_angle(randf() * TAU) * r * randf() * 0.6, "bubble", 1, 10.0, 0.8, Vector2(0, -20), Color(0.8, 1.0, 1.0))


## 冰灯塔：冷光里幽灵现形（torch 组）、怪减速；范围里的敌塔发动变慢（EnemyTower 读 lamp_slow_at）。
func _lamp() -> void:
	if _t > 0.0:
		return
	_t = 0.5
	var r := float(p("radius", 140.0))
	light_radius = r
	var buff := "siege_lamp_%d" % level
	for m in director.enemies_near(global_position, r):
		m.add_buff(buff, 0.8)
	if randf() < 0.5:
		Fx.burst(get_parent(), global_position + Vector2.from_angle(randf() * TAU) * r * randf() * 0.8, "crystal", 1, 6.0, 1.0, Vector2(0, -6), Color(0.75, 0.9, 1.0, 0.8))


## 某个位置被冰灯照着时，敌塔的发动间隔倍数（没有 = 1）。
static func lamp_slow_at(tree: SceneTree, at: Vector2) -> float:
	var k := 1.0
	for n in tree.get_nodes_in_group("siege_tower"):
		var t := n as IceTower
		if t and t.kind == "lamp" and t.global_position.distance_to(at) <= float(t.p("radius", 140.0)):
			k = maxf(k, float(t.p("etower_slow", 1.3)))
	return k


## 冰盾发生器：每 interval 秒给范围内的友军套一层冰盾（ice_shield：挡掉下一次挠痒 / 抓取）。
func _shield() -> void:
	if _t > 0.0:
		return
	_t = float(p("interval", 8.0)) * _town("ally_cd")
	var r := float(p("radius", 120.0))
	var n := 0
	if director.town:
		for a in director.town.allies():
			if is_instance_valid(a) and a.global_position.distance_to(global_position) <= r and not a.has_buff("ice_shield"):
				a.add_buff("ice_shield", 30.0)
				n += 1
				SiegeFx.ring(a.get_parent(), a.global_position + Vector2(0, -8), 10.0, Color(0.7, 0.9, 1.0, 0.9), 0.5, 0.25)
	if n > 0:
		var rg := SiegeFx.ring(get_parent(), global_position, 12.0, Color(0.75, 0.92, 1.0, 0.9), 0.5, 0.1)
		if rg:
			rg.create_tween().tween_property(rg, "scale", Vector2(r / 12.0, r / 12.0 * 0.6), 0.5)
		Audio.play("chime", -6.0, 0.0, 1.5)
