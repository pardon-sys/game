class_name IceTower
extends Actor
## 攻防战的冰塔（建在冰塔格 BuildPad 上：粉色公主选塔付冰晶，蓝色公主从城墙放冰光造出来）。6 种，每种 2 级：
##   icicle   冰锥塔：自动射冰锥打射程内最近的怪（盾甲螃蟹正面挡得住）
##   snowman  雪人召唤塔：每隔一段时间放出小雪人（Snowman），去挠 / 推怪物
##   decoy    诱饵冰雕：有血量，周围 lure 半径内的怪和攻城车优先打它
##   mint     薄荷冰泉：范围内的公主闷笑慢慢下降（粉色公主的 AI 闷笑高时会跑过来）
##   frost    寒霜塔：范围减速，每隔几秒冻住范围里的怪一下
##   repair   冰墙修补塔：慢慢修复它身后的那段城墙
## 数值在 data/siege/towers.json（tools/build/gen_floor06_siege.py 生成）：{种类: {name, cost, upgrade, desc, levels: [{...}, {...}]}}。
## 冰塔挡路（world 层），只有诱饵冰雕在玩家一方的层上（怪物会去打它）。暖炉史莱姆贴着会把塔融化（melt）。
## 图：assets/generated/siege/towers.png 的 tower_<种类>_<级>。

const PATH := "res://data/siege/towers.json"
const TEX := preload("res://assets/generated/siege/towers.png")
const META := "res://assets/generated/siege/towers.json"
## 冰塔被融化的耐久（诱饵冰雕用 levels 里的 hp）
const MELT_HP := 40.0

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
	return ["icicle", "snowman", "decoy", "mint", "frost", "repair"]


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
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.region_enabled = true
	_spr.region_rect = region("tower_%s_%d" % [kind, level])
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	add_child(_spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_soft.tres")
	light.color = Color(0.6, 1.0, 0.85) if kind == "mint" else Color(0.6, 0.85, 1.0)
	light.energy = 0.5
	light.texture_scale = 0.5
	light.position = Vector2(0, -14)
	add_child(light)
	# 破冰而出
	_spr.scale = Vector2(1, 0.1)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "crystal", 16, 60.0, 0.6, Vector2(0, 60), Color(0.8, 0.94, 1.0))


func upgrade() -> void:
	level = mini(level + 1, 2)
	_spr.region_rect = region("tower_%s_%d" % [kind, level])
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	if health:
		health.max_hp = int(p("hp", 60))
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


func collapse() -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "drop", 14, 50.0, 0.6, Vector2(0, 80), Color(0.7, 0.9, 1.0))
	Audio.play("ice_crack", -2.0, 0.1, 0.8)
	if pad and pad.has_method("tower_gone"):
		pad.call("tower_gone")
	queue_free()


func _on_died() -> void:
	collapse()


func _tick(delta: float) -> void:
	_t -= delta
	if director == null or director.get("state") == "failed":
		return
	match kind:
		"icicle": _icicle()
		"snowman": _snowman()
		"mint": _mint(delta)
		"frost": _frost(delta)
		"repair": _repair()


func _icicle() -> void:
	if _t > 0.0:
		return
	var best: Monster = null
	var best_d := float(p("range", 140.0))
	for m in director.enemies_near(global_position, best_d):
		var d := global_position.distance_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		_t = 0.3
		return
	_t = float(p("interval", 1.2))
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -24), best, "proj_icicle", 260.0, func(t: Node):
		if is_instance_valid(t) and t is Actor:
			(t as Actor).receive_hit(HitData.make_attack(self, int(p("damage", 1)), 40.0)))
	Audio.play("ice_crack", -12.0, 0.2, 1.8)


func _snowman() -> void:
	if _t > 0.0:
		return
	_t = float(p("interval", 12.0))
	_snowmen = _snowmen.filter(func(s): return is_instance_valid(s))
	var n := int(p("count", 2))
	for i in n:
		if _snowmen.size() >= n * 2:
			break
		var s := Snowman.new()
		s.hp = int(p("snow_hp", 4))
		get_parent().add_child(s)
		s.global_position = global_position + Vector2(randf_range(-14, 14), 10)
		_snowmen.append(s)
		if director:
			director.extra_targets.append(s)


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
		for m in ms:
			m.stun(float(p("freeze", 1.0)))
		SiegeFx.ring(get_parent(), global_position, r, Color(0.8, 0.95, 1.0, 0.7), 0.5)
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
