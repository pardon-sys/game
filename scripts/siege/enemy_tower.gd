class_name EnemyTower
extends Actor
## 攻防战的敌塔（敌方区域的地基 EnemySite 上：怪物聚集够多、待够久自己搭起来）。有血量，粉色公主可以拆，拆掉掉冰晶。10 种：
##   控制：vine_pull 藤蔓拉拽（勾住粉色公主拖到塔下，连按挣脱；被拖时蓝色公主可以放冰链救）/ tailor 痒痒裁缝铺（射出临时痒痒装备，打中就强制穿上）/
##         glue 黏胶喷泉（往地上喷黏胶水洼，踩上减速）/ net 吊网（网住粉色公主吊在半空，网眼里伸手挠脚心）/
##         silence 魔力干扰（城墙上这一段蓝色公主施法会被打断并挨挠：SiegeDirector.silenced）/ portal 怪物传送门（不停吐小怪）/
##         windmill 强风风车（周期性吹风，把粉色公主吹向怪群）
##   增益：totem 狂欢图腾（附近的怪加速、挠得更重；立着时蓝色公主的千手痒痒裤发作间隔 ×0.6、力度 ×1.5）
##   挠痒：thigh_tower 腿根揉揉塔（射程够到城墙，专打蓝色公主的大腿 / 屁股；穿着千手痒痒裤时裤子跟着一起动）/
##         sole_tower 脚心刷刷塔（刷子手抓住粉色公主的脚踝，扳脚趾、刷脚心、扳着脚板刮）
## 数值和手法台词在 data/siege/enemy_towers.json（{种类: {name, hp, interval, range, lines: [...]}}；gen_floor06_siege.py 生成）。
## 挠痒的来源键 = enemy_<种类>（reaction_key），三来源组合认它。图：towers 图集的 etower_<种类>。

const PATH := "res://data/siege/enemy_towers.json"
const GLUE_TIME := 8.0

static var _data := {}

@export var kind := "glue"

var site: Node2D
var director: SiegeDirector
## 威力倍数（工兵护送搭成的塔：第一次发动 ×2，发动完回到 1）
var power := 1.0
var reaction_key := ""
var _t := 1.5
var _spr: Sprite2D
var _vine: Line2D
var _dragging := false
var _spawned: Array[Node] = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func info(k: String) -> Dictionary:
	var e: Variant = data().get(k, {})
	return e if e is Dictionary else {}


static func kinds() -> Array:
	return ["vine_pull", "tailor", "glue", "net", "silence", "portal", "windmill", "totem", "thigh_tower", "sole_tower"]


func p(key: String, default: Variant = 0.0) -> Variant:
	return info(kind).get(key, default)


func _setup() -> void:
	set_faction(Faction.Type.ENEMY)
	add_to_group("siege_enemy_tower")
	add_to_group("siege_temp")
	reaction_key = "enemy_" + kind
	director = SiegeDirector.current
	collision_layer = 4 | 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 10)
	shape.shape = r
	shape.position = Vector2(0, -5)
	add_child(shape)
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = int(p("hp", 20))
	add_child(hc)
	health = hc
	hc.fill()
	hc.died.connect(_die)
	hurt_invuln_time = 0.25
	_spr = Sprite2D.new()
	_spr.texture = IceTower.TEX
	_spr.region_enabled = true
	_spr.region_rect = IceTower.region("etower_" + kind)
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	add_child(_spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_soft.tres")
	light.color = Color(0.9, 0.4, 0.85)
	light.energy = 0.5
	light.texture_scale = 0.45
	light.position = Vector2(0, -20)
	add_child(light)
	_spr.scale = Vector2(1, 0.05)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position, "dust", 14, 50.0, 0.6, Vector2(0, -20), Color(0.6, 0.4, 0.6))
	Audio.play("rumble", -6.0, 0.1, 1.2)
	_t = float(p("interval", 6.0)) * 0.5
	if kind == "totem":
		_set_totem(true)


func _on_died() -> void:
	if director:
		director.add_crystals(int(p("reward", 8)), global_position)
	if site and site.has_method("tower_gone"):
		site.call("tower_gone")
	_release_drag()
	if kind == "totem":
		_set_totem(false)
	Fx.burst(get_parent(), global_position + Vector2(0, -12), "chip", 18, 70.0, 0.7, Vector2(0, 100), Color(0.5, 0.3, 0.45))
	Audio.play("break", -2.0, 0.1)
	queue_free()


func _exit_tree() -> void:
	if kind == "totem":
		_set_totem(false)
	_release_drag()


func pink() -> PlayableCharacter:
	return director.pink if director else null


func blue() -> PlayableCharacter:
	return director.blue if director else null


func _alive(c: PlayableCharacter) -> bool:
	return c != null and is_instance_valid(c) and c.is_alive() and not Downed.is_downed(c)


func _tick(delta: float) -> void:
	if director == null or director.get("state") != "fight" or not is_alive():
		return
	if kind == "vine_pull":
		_drag_tick(delta)
	_t -= delta
	if _t > 0.0:
		return
	# 发动间隔按攻防战的频率倍数缩短（waves.json 的 ability_rate）
	_t = float(p("interval", 6.0)) / SiegeDirector.ability_rate()
	var boosted := power > 1.0
	if boosted:
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "ember", 14, 50.0, 0.6, Vector2(0, -20), Color(1, 0.5, 0.9))
	match kind:
		"vine_pull": _vine_throw()
		"tailor": _tailor()
		"glue": _glue()
		"net": _net()
		"silence": _silence_fx()
		"portal": _portal()
		"windmill": _windmill()
		"totem": _totem()
		"thigh_tower": _thigh()
		"sole_tower": _sole()
	if boosted:
		power = 1.0


func _in_range(c: PlayableCharacter, r: float) -> bool:
	return _alive(c) and c.global_position.distance_to(global_position) <= r


func _line(c: PlayableCharacter) -> void:
	var lines: Array = p("lines", [])
	if lines.is_empty() or not _alive(c):
		return
	var t := str(lines.pick_random())
	if c.character_id == "blue":
		var bl: Array = p("lines_blue", [])
		if not bl.is_empty():
			t = str(bl.pick_random())
	if c.is_controlled():
		GameState.princess_reacted.emit(t, 2.2)
	else:
		SpeechBubble.say(c, t, 28.0, 2.0)


func _tickle(c: PlayableCharacter, amount: float, zone: String) -> void:
	if not _alive(c):
		return
	var h := HitData.make_tickle(self, amount * power)
	h.zone = zone
	c.receive_hit(h)


# ------------------------------------------------------------------ 藤蔓拉拽
func _vine_throw() -> void:
	var c := pink()
	if _dragging or not _in_range(c, float(p("range", 200.0))) or c.get_meta("siege_dragged", false):
		return
	if c.status and c.status.grab(self, 5.0, int(p("presses", 12))):
		_dragging = true
		c.set_meta("siege_dragged", true)
		c.set_meta("siege_dragger", self)
		_vine = Line2D.new()
		_vine.width = 2.0
		_vine.default_color = Color(0.45, 0.8, 0.4)
		_vine.z_index = 20
		_vine.add_to_group("siege_temp")
		get_parent().add_child(_vine)
		_vine.global_position = Vector2.ZERO
		Audio.play("vine", -4.0, 0.1)
		_line(c)


func _drag_tick(delta: float) -> void:
	if not _dragging:
		return
	var c := pink()
	if not _alive(c) or c.status == null or not c.status.is_grabbed_by(self):
		_release_drag()
		return
	_vine.points = PackedVector2Array([global_position + Vector2(0, -24), c.global_position + Vector2(0, -8)])
	var d := global_position + Vector2(0, 10) - c.global_position
	if c.get_meta("siege_chained", false):
		return
	if d.length() > 14.0:
		c.global_position += d.normalized() * float(p("pull", 55.0)) * delta
	elif randf() < delta * 2.5:
		_tickle(c, 5.0, ["waist", "armpit", "sole"].pick_random())


## 被救回去 / 挣脱 / 塔倒了：松开。
func _release_drag() -> void:
	_dragging = false
	if _vine and is_instance_valid(_vine):
		_vine.queue_free()
	_vine = null
	var c := pink()
	if c and is_instance_valid(c) and c.has_meta("siege_dragger") and c.get_meta("siege_dragger") == self:
		c.set_meta("siege_dragged", false)
		c.set_meta("siege_dragger", null)
		if c.status and c.status.is_grabbed_by(self):
			c.status.release(true)


func release_drag() -> void:
	_release_drag()


# ------------------------------------------------------------------ 裁缝铺
func _tailor() -> void:
	var targets: Array[PlayableCharacter] = []
	if _in_range(pink(), float(p("range", 240.0))):
		targets.append(pink())
	if _in_range(blue(), float(p("range_wall", 520.0))):
		targets.append(blue())
	if targets.is_empty():
		return
	var c: PlayableCharacter = targets.pick_random()
	var pool: Array = p("items", [])
	pool = pool.filter(func(id): return ItemDB.PATHS.has(str(id)))
	if pool.is_empty():
		return
	var id := str(pool.pick_random())
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_equip", 150.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		var how := Equipment.force(tc.character_id, id)
		if how != "":
			var it := ItemDB.get_item(id)
			Fx.burst(tc.get_parent(), tc.global_position + Vector2(0, -10), "heart", 6, 30.0, 0.5, Vector2(0, -10), Color(1, 0.7, 0.9))
			if tc.is_controlled():
				GameState.notify("被强制穿上了「%s」！（20 秒 / 搭档按住 E 帮忙解开）" % (it.display_name if it else id))
			if director and director.intel:
				director.intel.discover(id))
	Audio.play("swish", -6.0, 0.1, 1.3)


# ------------------------------------------------------------------ 黏胶喷泉
func _glue() -> void:
	var c := pink()
	var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, float(p("range", 140.0)))
	if _in_range(c, float(p("range", 140.0)) + 40.0):
		at = c.global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
	GluePuddle.spawn(get_parent(), at, GLUE_TIME)
	Audio.play("puddle", -6.0, 0.1)


# ------------------------------------------------------------------ 吊网
func _net() -> void:
	var c := pink()
	if not _in_range(c, float(p("range", 190.0))):
		return
	var hang := float(p("hang", 3.5))
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "net", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		if tc.status:
			tc.status.apply_root(hang)
		tc.add_buff("lifted", hang)
		var net := Sprite2D.new()
		net.texture = IceTower.TEX
		net.region_enabled = true
		net.region_rect = IceTower.region("net")
		net.position = Vector2(0, -16)
		net.z_index = 5
		tc.add_child(net)
		tc.get_tree().create_timer(hang).timeout.connect(net.queue_free)
		_line(tc)
		# 塔被拆掉以后网眼里的手也停（弱引用，别调到已经释放的塔上）
		var me: WeakRef = weakref(self)
		var tw := tc.create_tween().set_loops(int(hang / 0.5))
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			var t2 := me.get_ref() as EnemyTower
			if t2:
				t2._tickle(tc, 4.0, "sole")))
	Audio.play("swish", -4.0, 0.1, 0.8)


# ------------------------------------------------------------------ 魔力干扰
## 这个人（在城墙上）在不在干扰范围里。
func silences(c: PlayableCharacter) -> bool:
	return is_alive() and director != null and director.is_on_wall(c) and absf(c.global_position.x - global_position.x) <= float(p("width", 130.0))


func _silence_fx() -> void:
	if director == null:
		return
	var y: float = director.wall_top_y()
	SiegeFx.lane(get_parent(), global_position + Vector2(0, -30), Vector2(global_position.x, y), 2.0, Color(0.7, 0.4, 1.0), 0.8)
	SiegeFx.ring(get_parent(), Vector2(global_position.x, y), float(p("width", 130.0)), Color(0.75, 0.45, 1.0, 0.5), 0.8, 0.08)


# ------------------------------------------------------------------ 传送门
func _portal() -> void:
	_spawned = _spawned.filter(func(m): return is_instance_valid(m) and m.is_alive())
	if _spawned.size() >= int(p("cap", 6)) or director == null:
		return
	var pool: Array = p("spawns", ["slime", "rat"])
	var m: Monster = director.spawn(str(pool.pick_random()), "portal", global_position + Vector2(randf_range(-10, 10), 12))
	if m:
		_spawned.append(m)
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "ember", 8, 40.0, 0.5, Vector2(0, 20), Color(0.9, 0.5, 1.0))


# ------------------------------------------------------------------ 强风风车
func _windmill() -> void:
	var c := pink()
	if not _in_range(c, float(p("range", 170.0))):
		return
	var dir := global_position.direction_to(c.global_position)
	var crowd: Variant = director.densest(40.0, c.global_position, 200.0)
	if crowd is Vector2:
		dir = c.global_position.direction_to(crowd)
	c.apply_knockback(c.global_position - dir * 10.0, float(p("force", 300.0)))
	Fx.burst(get_parent(), c.global_position, "dust", 12, 90.0, 0.5, dir * 80.0, Color(0.9, 0.9, 1.0, 0.7))
	Audio.play("wind", -4.0, 0.1)
	_line(c)


# ------------------------------------------------------------------ 狂欢图腾
func _totem() -> void:
	for m in director.enemies_near(global_position, float(p("range", 120.0))):
		m.add_buff("siege_frenzy", 1.5)
	SiegeFx.ring(get_parent(), global_position, float(p("range", 120.0)), Color(1, 0.6, 0.3, 0.5), 0.6, 0.06)
	Audio.play("totem", -10.0, 0.1)


func _set_totem(on: bool) -> void:
	var b := blue()
	var fx := EquipFx.of(b) if b and is_instance_valid(b) else null
	if fx == null:
		return
	var key := "totem_%d" % get_instance_id()
	if on:
		fx.add_mod(key, 1.0 / 0.6, 1.5)
	else:
		fx.remove_mod(key)


# ------------------------------------------------------------------ 腿根揉揉塔
func _thigh() -> void:
	var c := blue()
	if not _in_range(c, float(p("range", 560.0))):
		c = pink() if _in_range(pink(), 200.0) else null
	if c == null:
		return
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_hand", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		var zone: String = ["thigh", "butt"].pick_random()
		for i in 3:
			_tickle(tc, float(p("amount", 6.0)), zone)
		_line(tc)
		# 穿着千手痒痒裤：裤子跟着一起动
		if tc.has_method("pants_flare") and tc.has_buff("thousand_pants"):
			tc.call("pants_flare", "knead" if zone == "thigh" else "pinch"))
	Audio.play("hand_grab", -8.0, 0.1, 1.2)


# ------------------------------------------------------------------ 脚心刷刷塔
func _sole() -> void:
	var c := pink()
	if not _in_range(c, float(p("range", 220.0))):
		return
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_brush", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		if tc.status:
			tc.status.apply_root(1.6)
		_line(tc)
		var me: WeakRef = weakref(self)
		var amount := float(p("amount", 4.0))
		var tw := tc.create_tween().set_loops(4)
		tw.tween_interval(0.35)
		tw.tween_callback(func():
			var t2 := me.get_ref() as EnemyTower
			if t2:
				t2._tickle(tc, amount, "sole")))
	Audio.play("brush_spin", -8.0, 0.1)
