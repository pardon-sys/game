class_name SiegeSpells
extends RefCounted
## 蓝色公主在城墙上的法术（攻防战；AI 自动放，玩家操控她时用瞄准施法 SpellAim 选点）：
##   ice_rain   冰锥雨：选一个点，落下一片冰锥——范围伤害；也能射断钩索怪的绳子（"siege_cuttable" 组的 cut()）
##   barrier    冰晶结界：原来的魔法，可以选点——冻住范围内的怪和陷阱（IceBarrier.cast_with 的 at）
##   snow       清凉雪花：选一个点——范围内的公主闷笑下降、解开束缚和临时痒痒装备
##   reinforce  冰墙加固：给离这个点最近的那段城墙罩上冰壳（吸收伤害，期间怪物爬不上来）
##   blizzard   暴风雪：一大片持续 6 秒的暴风雪，里面的怪减速、每秒掉血（雪花粒子，范围内略带蓝色）
##   spike      冰川突刺：从城墙脚下朝落点一条直线，冰刺依次冒出，直线上的怪和敌塔都挨一下
##   mirror     冰镜分身：在落点放一个她的冰镜分身，把附近的怪都吸过去（extra_targets + lure），碎掉时冻住周围的怪
## 镇民支援：spell_cd 冷却倍数、fatigue 魔力疲倦倍数（SiegeDirector.town）。
## 每个法术有自己的冷却（存在施法者的 meta siege_cd），放一次加魔力疲倦（满了照常疲倦爆发）。
## 穿着千手痒痒裤时照样有 magic_fail 几率失败（BluePrincess._on_magic_fail）；魔力干扰塔范围内会被打断（director.silenced）。
## 射程：离施法者 RANGE 像素以内。

const ORDER := ["ice_rain", "barrier", "snow", "reinforce", "blizzard", "spike", "mirror"]
const INFO := {
	"ice_rain": {"name": "冰锥雨", "cd": 3.5, "fatigue": 22.0, "radius": 47.0, "damage": 2},
	"barrier": {"name": "冰晶结界", "cd": 14.0, "fatigue": 55.0, "radius": 68.0, "time": 3.0},
	"snow": {"name": "清凉雪花", "cd": 9.0, "fatigue": 35.0, "radius": 57.0, "laugh": 0.4},
	"reinforce": {"name": "冰墙加固", "cd": 16.0, "fatigue": 45.0, "shield": 260.0, "time": 12.0},
	"blizzard": {"name": "暴风雪", "cd": 18.0, "fatigue": 50.0, "radius": 90.0, "time": 6.0, "damage": 1, "slow": 0.4},
	"spike": {"name": "冰川突刺", "cd": 10.0, "fatigue": 40.0, "radius": 12.0, "length": 360.0, "damage": 4},
	"mirror": {"name": "冰镜分身", "cd": 20.0, "fatigue": 40.0, "radius": 60.0, "time": 8.0, "hp": 30, "freeze": 2.0},
}
const RANGE := 640.0
const ICE := Color(0.7, 0.9, 1.0)


static func spell_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", id))


static func radius(id: String) -> float:
	return float(INFO.get(id, {}).get("radius", 24.0))


## AI 放的（蓝色公主没被玩家操控时）：冷却 × AI_CD、魔力疲倦 × AI_FATIGUE（放得更勤，又不会一直疲倦爆发）
const AI_CD := 0.6
const AI_FATIGUE := 0.6


static func cooldown_left(c: Node, id: String) -> float:
	var cd: Dictionary = c.get_meta("siege_cd", {})
	return maxf(0.0, float(cd.get(id, 0.0)) - Time.get_ticks_msec() / 1000.0)


static func ready(c: Node, id: String) -> bool:
	return cooldown_left(c, id) <= 0.0


static func in_range(c: Node2D, point: Vector2) -> bool:
	return c.global_position.distance_to(point) <= RANGE


## 放一个法术。返回是否放出去了（冷却中 / 射程外 / 被打断 / 失败都算没放成，失败也进冷却）。
## force：不看冷却（蓝色公主跟着粉色公主一起放魔法时）。
static func cast(c: PlayableCharacter, id: String, point: Vector2, force := false) -> bool:
	if not INFO.has(id) or (not force and not ready(c, id)) or not c.is_alive() or Downed.is_downed(c):
		return false
	if id != "reinforce" and not in_range(c, point):
		return false
	# 痒痒迷雾：看不见雾里的地方（清凉雪花 / 结界放不进去）
	if id != "reinforce" and SiegeDirector.current and SiegeDirector.current.in_fog(point):
		return false
	var info: Dictionary = INFO[id]
	var dir := SiegeDirector.current
	var cd: Dictionary = c.get_meta("siege_cd", {})
	var ai := not c.is_controlled()
	cd[id] = Time.get_ticks_msec() / 1000.0 + float(info["cd"]) * (dir.town.mul("spell_cd") if dir and dir.town else 1.0) * (AI_CD if ai else 1.0)
	c.set_meta("siege_cd", cd)
	if dir and dir.has_method("silenced") and dir.silenced(c):
		if c.is_controlled():
			GameState.notify("魔力被干扰了！")
		c.shake(0.3)
		if c.laugh:
			c.laugh.add(8.0)
		return false
	# 被吸住 / 被缠住时放不出来（魔力吸吸水母会趁她抬手时专挠腋下）
	if c.status and c.status.is_grabbed():
		if dir:
			for m in dir.enemies_near(c.global_position, 30.0):
				if m.has_method("on_cast_try"):
					m.call("on_cast_try", c)
		if c.is_controlled():
			GameState.notify("被缠住了，魔法放不出来！")
		return false
	if c.stat_add("magic_fail") > 0.0 and randf() < c.stat_add("magic_fail"):
		if c.has_method("_on_magic_fail"):
			c.call("_on_magic_fail", 1)
		return false
	if c.fatigue:
		c.fatigue.add(float(info["fatigue"]) * (dir.town.mul("fatigue") if dir and dir.town else 1.0) * (AI_FATIGUE if not c.is_controlled() else 1.0))
	_cast_fx(c, point)
	if id != "reinforce" and id != "snow":
		SiegeHazard.notify_spell(c.get_tree(), point, float(info.get("radius", 30.0)))
	match id:
		"ice_rain": _ice_rain(c, point, float(info["radius"]), int(info["damage"]))
		"barrier": IceBarrier.cast_with(c, float(info["radius"]), float(info["time"]), 2, point)
		"snow": _snow(c, point, float(info["radius"]), float(info["laugh"]))
		"reinforce":
			var w: SiegeWall = dir.segment_at(point.x) if dir else null
			if w:
				w.reinforce(float(info["shield"]), float(info["time"]))
				Fx.burst(w.get_parent(), Vector2(w.global_position.x, w.foot_y() - 16.0), "crystal", 16, 60.0, 0.7, Vector2(0, 30), ICE)
				Audio.play("chime", -3.0, 0.0, 1.4)
				_reinforce_fx(w)
		"blizzard":
			var bz := Blizzard.new()
			bz.radius = float(info["radius"])
			bz.time = float(info["time"])
			bz.damage = int(info["damage"])
			bz.slow = float(info["slow"])
			bz.caster = c
			c.get_parent().add_child(bz)
			bz.global_position = point
		"spike": _spike(c, point, float(info["length"]), int(info["damage"]))
		"mirror":
			var mr := IceMirror.new()
			mr.life = float(info["time"])
			mr.freeze_r = float(info["radius"])
			mr.freeze = float(info["freeze"])
			mr.caster = c
			c.get_parent().add_child(mr)
			mr.global_position = point
	c.set_meta("siege_last_spell", id)
	return true


## 施法者身上一道冰光射向落点。
static func _cast_fx(c: PlayableCharacter, point: Vector2) -> void:
	c.shake(0.1)
	var beam := Line2D.new()
	beam.width = 2.0
	beam.default_color = Color(0.75, 0.92, 1.0, 0.85)
	beam.points = PackedVector2Array([c.global_position + Vector2(0, -12), point])
	beam.z_index = 30
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = mat
	c.get_parent().add_child(beam)
	beam.global_position = Vector2.ZERO
	var tw := beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.3)
	tw.tween_callback(beam.queue_free)


static func _ice_rain(c: PlayableCharacter, point: Vector2, r: float, dmg: int) -> void:
	var parent := c.get_parent()
	var mark := SiegeFx.ring(parent, point, r, Color(0.7, 0.9, 1.0, 0.8), 0.45)
	if mark == null:
		return
	# 落点的影子（冰锥从天上落下来之前）
	for i in 6:
		SiegeFx.warn(parent, point + Vector2.from_angle(randf() * TAU) * randf() * r * 0.8, "shadow", 6.0, 0.45, Color(0.7, 0.9, 1.0))
	var wc: WeakRef = weakref(c)
	parent.get_tree().create_timer(0.45).timeout.connect(func():
		var caster := wc.get_ref() as PlayableCharacter
		if caster == null:
			return
		for i in 9:
			var at := point + Vector2.from_angle(randf() * TAU) * randf() * r
			SiegeFx.icicle(parent, at)
		Audio.play("ice_crack", -3.0, 0.15, 1.2)
		Fx.burst(parent, point + Vector2(0, -4), "crystal", 14, r * 1.2, 0.6, Vector2(0, 120), Color(0.85, 0.96, 1.0))
		var dir := SiegeDirector.current
		if dir:
			for m in dir.enemies_near(point, r + 6.0):
				m.receive_hit(HitData.make_attack(caster, dmg, 60.0))
			_hit_towers(caster, point, r + 10.0, dmg)
		for n in caster.get_tree().get_nodes_in_group("siege_cuttable"):
			if n is Node2D and (n as Node2D).global_position.distance_to(point) <= r + 10.0 and n.has_method("cut"):
				n.cut(caster))


static func _snow(c: PlayableCharacter, point: Vector2, r: float, laugh_frac: float) -> void:
	Fx.burst(c.get_parent(), point + Vector2(0, -20), "snow", 22, 50.0, 1.1, Vector2(0, 30), Color(0.9, 0.97, 1.0))
	Fx.burst(c.get_parent(), point + Vector2(0, -40), "snow", 18, 20.0, 1.6, Vector2(0, 25), Color(1, 1, 1))   # 雪片慢慢飘落
	SiegeFx.ring(c.get_parent(), point, r, Color(0.85, 0.97, 1.0, 0.7), 0.5)
	Audio.play("chime", -4.0, 0.05, 1.8)
	for n in c.get_tree().get_nodes_in_group("player_chars"):
		var p := n as PlayableCharacter
		if p == null or not p.is_alive() or p.global_position.distance_to(point) > r + 10.0:
			continue
		if p.laugh:
			p.laugh.set_value(maxf(0.0, p.laugh.value - p.laugh.max_value * laugh_frac))
		if p.status and p.status.is_grabbed():
			p.status.release(true)
		if p.status:
			p.status.clear_root()
		p.fling_latchers()
		var freed := Equipment.release(p.character_id)
		if freed > 0:
			SpeechBubble.say(p, "解开了！" if p.character_id == "pink" else "……解开了。", 26.0)
		p.add_buff("frost_guard", 1.5)
		# 笑瘫 / 倒地的人：清凉雪花让她提前起来（蓝色公主倒地不行，要粉色公主救）
		if p.has_method("siege_wake"):
			p.call("siege_wake")


## 敌塔（和巨魔将军的军旗）也吃法术伤害。
static func _hit_towers(caster: Node, at: Vector2, r: float, dmg: int) -> void:
	for t in caster.get_tree().get_nodes_in_group("siege_enemy_tower") + caster.get_tree().get_nodes_in_group("fortress_target"):
		if t is Actor and (t as Node2D).global_position.distance_to(at) <= r:
			var spell_hit := HitData.make_attack(caster, dmg, 0.0)
			spell_hit.tag = "siege_spell"
			(t as Actor).receive_hit(spell_hit)


## 冰墙加固：冰壳从墙脚往上结，闪一下。
static func _reinforce_fx(w: SiegeWall) -> void:
	var parent := w.get_parent()
	for i in 6:
		var x := w.left_x() + w.width_px() * (i + 0.5) / 6.0
		Fx.burst(parent, Vector2(x, w.foot_y() - 2.0), "crystal", 4, 40.0, 0.6, Vector2(0, -40), Color(0.85, 0.96, 1.0))
	SiegeFx.beam(parent, Vector2(w.left_x(), w.foot_y() - 14.0), Vector2(w.right_x(), w.foot_y() - 14.0), Color(0.8, 0.95, 1.0, 0.9), 0.4, 6.0)


## 冰川突刺：从城墙脚下（施法者正下方）朝落点一条直线，冰刺一根接一根冒出来。
static func _spike(c: PlayableCharacter, point: Vector2, length: float, dmg: int) -> void:
	var dir := SiegeDirector.current
	var start := Vector2(c.global_position.x, (dir.wall_foot_y() + 8.0) if dir else c.global_position.y)
	var way := start.direction_to(point)
	if way == Vector2.ZERO:
		way = Vector2.DOWN
	var parent := c.get_parent()
	SiegeFx.lane(parent, start, start + way * length, 22.0, Color(0.7, 0.9, 1.0), 0.35)
	var hit := {}
	var wc: WeakRef = weakref(c)
	var n := int(length / 18.0)
	for i in n:
		parent.get_tree().create_timer(0.35 + i * 0.035).timeout.connect(func():
			var caster := wc.get_ref() as PlayableCharacter
			if caster == null or not is_instance_valid(parent):
				return
			var at := start + way * (i + 1) * 18.0
			var sp := Spike.new()
			parent.add_child(sp)
			sp.global_position = at
			if i % 3 == 0:
				Audio.play("ice_crack", -10.0, 0.2, 1.4)
			if dir:
				for m in dir.enemies_near(at, 16.0):
					if not hit.has(m.get_instance_id()):
						hit[m.get_instance_id()] = true
						m.receive_hit(HitData.make_attack(caster, dmg, 140.0))
				_hit_towers(caster, at, 18.0, dmg))


## 一根冰刺：从地里刺出来、停一下、碎掉。
class Spike extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		Fx.burst(get_parent(), global_position, "crystal", 4, 40.0, 0.5, Vector2(0, 120), Color(0.85, 0.96, 1.0))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 0.7:
			queue_free()

	func _draw() -> void:
		var h := 22.0 * clampf(_t / 0.08, 0.0, 1.0) * (1.0 if _t < 0.5 else clampf((0.7 - _t) / 0.2, 0.0, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(0, -h), Vector2(6, 0)]), Color(0.75, 0.92, 1.0, 0.95))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(0, -h), Vector2(0, 0)]), Color(0.5, 0.75, 0.95, 0.95))
		draw_line(Vector2(1, -2), Vector2(1, -h * 0.7), Color(1, 1, 1, 0.9), 1.0)


## 暴风雪：radius 范围持续 time 秒：里面的怪减速（siege_chill）、每秒掉 damage 血；雪花粒子 + 蓝色的雪幕。
class Blizzard extends Node2D:
	var radius := 90.0
	var time := 6.0
	var damage := 1
	var slow := 0.4
	var caster: Node
	var _t := 0.0
	var _tick := 0.0
	var _snow: CPUParticles2D

	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 20
		_snow = Fx.emitter(self, "snow", 60, 1.2, {"offset": Vector2(0, -50), "dir": Vector2(0.4, 1).normalized(), "spread": 25.0,
			"speed": [40.0, 80.0], "gravity": Vector2(20, 40), "color": Color(1, 1, 1, 0.9), "z": 21, "extents": Vector2(radius, 30)})
		_snow.emitting = true
		Audio.play("wind", -2.0)

	func _process(delta: float) -> void:
		_t += delta
		_tick -= delta
		queue_redraw()
		var d := SiegeDirector.current
		if _tick <= 0.0 and d:
			_tick = 1.0
			for m in d.enemies_near(global_position, radius):
				m.add_buff("siege_chill", 1.2)
				if is_instance_valid(caster):
					m.receive_hit(HitData.make_attack(caster, damage, 0.0))
			SiegeSpells._hit_towers(caster if is_instance_valid(caster) else self, global_position, radius, damage)
		if _t >= time:
			_snow.emitting = false
			set_process(false)
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.8)
			tw.tween_callback(queue_free)

	func _draw() -> void:
		var a := clampf(_t * 2.0, 0.0, 1.0) * 0.22
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(0.75, 0.88, 1.0, a))
		for i in 4:
			var r := radius * (0.4 + 0.15 * i)
			draw_arc(Vector2.ZERO, r, _t * (1.5 + i * 0.4), _t * (1.5 + i * 0.4) + 2.2, 24, Color(1, 1, 1, 0.35), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 冰镜分身：一个半透明的她的冰像，life 秒，怪物优先打它（lure 半径）；碎掉时冻住 freeze_r 内的怪 freeze 秒。
class IceMirror extends Actor:
	var life := 8.0
	var freeze_r := 60.0
	var freeze := 2.0
	var caster: PlayableCharacter
	var lure := 130.0
	var _t := 0.0

	func _setup() -> void:
		set_faction(Faction.Type.PLAYER)
		add_to_group("siege_temp")
		collision_layer = 2
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := CircleShape2D.new()
		r.radius = 6.0
		cs.shape = r
		add_child(cs)
		var hc := HealthComponent.new()
		hc.name = "Health"
		hc.max_hp = 30
		add_child(hc)
		health = hc
		hc.fill()
		hc.died.connect(shatter)
		sprite = Sprite2D.new()
		if caster and caster.sprite:
			sprite.texture = caster.sprite.texture
			sprite.hframes = caster.sprite.hframes
			sprite.vframes = caster.sprite.vframes
			sprite.frame = caster.sprite.frame
			sprite.offset = caster.sprite.offset
			sprite.region_enabled = caster.sprite.region_enabled
			sprite.region_rect = caster.sprite.region_rect
			sprite.scale = caster.sprite.scale
			sprite.texture_filter = caster.sprite.texture_filter
		sprite.modulate = Color(0.7, 0.9, 1.4, 0.75)
		add_child(sprite)
		var lt := PointLight2D.new()
		lt.texture = load("res://assets/lights/light_soft.tres")
		lt.color = Color(0.6, 0.85, 1.0)
		lt.energy = 0.6
		lt.texture_scale = 0.6
		add_child(lt)
		var d := SiegeDirector.current
		if d:
			d.extra_targets.append(self)
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "crystal", 18, 60.0, 0.6, Vector2(0, 60), Color(0.85, 0.96, 1.0))
		Audio.play("chime", -3.0, 0.0, 1.2)

	func receive_hit(hit: HitData) -> bool:
		# 挠痒也算伤害（怪物多半是来挠的）
		if hit.kind == HitData.Kind.TICKLE:
			hit = HitData.make_attack(hit.source, maxi(1, int(hit.tickle / 4.0)), 0.0)
		var ok := super(hit)
		if ok:
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-5, 5), -12), "crystal", 3, 30.0, 0.3, Vector2(0, 60), Color(0.85, 0.96, 1.0))
		return ok

	func _tick(delta: float) -> void:
		_t += delta
		if sprite:
			sprite.modulate.a = 0.6 + 0.2 * sin(_t * 5.0)
		if randf() < delta * 4.0:
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-8, 8), -randf_range(4, 24)), "crystal", 1, 10.0, 0.6, Vector2(0, -10), Color(0.9, 0.97, 1.0))
		if _t >= life:
			shatter()

	func shatter() -> void:
		if not is_inside_tree():
			return
		var d := SiegeDirector.current
		if d:
			for m in d.enemies_near(global_position, freeze_r):
				m.stun(freeze)
				Fx.burst(get_parent(), m.global_position + Vector2(0, -8), "crystal", 3, 20.0, 0.4, Vector2(0, 40), Color(0.85, 0.96, 1.0))
			d.extra_targets.erase(self)
		SiegeFx.ring(get_parent(), global_position, freeze_r, Color(0.8, 0.95, 1.0, 0.9), 0.6, 0.2)
		Fx.burst(get_parent(), global_position + Vector2(0, -12), "crystal", 26, 80.0, 0.8, Vector2(0, 90), Color(0.85, 0.96, 1.0))
		Audio.play("ice_crack", -1.0, 0.05, 0.9)
		queue_free()
