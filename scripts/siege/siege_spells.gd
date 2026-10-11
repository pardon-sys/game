class_name SiegeSpells
extends RefCounted
## 蓝色公主在城墙上的法术（攻防战；AI 自动放，玩家操控她时用瞄准施法 SpellAim 选点）：
##   ice_rain   冰锥雨：选一个点，落下一片冰锥——范围伤害；也能射断钩索怪的绳子（"siege_cuttable" 组的 cut()）
##   barrier    冰晶结界：原来的魔法，可以选点——冻住范围内的怪和陷阱（IceBarrier.cast_with 的 at）
##   snow       清凉雪花：选一个点——范围内的公主闷笑下降、解开束缚和临时痒痒装备
##   reinforce  冰墙加固：给离这个点最近的那段城墙罩上冰壳（吸收伤害，期间怪物爬不上来）
## 每个法术有自己的冷却（存在施法者的 meta siege_cd），放一次加魔力疲倦（满了照常疲倦爆发）。
## 穿着千手痒痒裤时照样有 magic_fail 几率失败（BluePrincess._on_magic_fail）；魔力干扰塔范围内会被打断（director.silenced）。
## 射程：离施法者 RANGE 像素以内。

const ORDER := ["ice_rain", "barrier", "snow", "reinforce"]
const INFO := {
	"ice_rain": {"name": "冰锥雨", "cd": 3.5, "fatigue": 22.0, "radius": 36.0, "damage": 2},
	"barrier": {"name": "冰晶结界", "cd": 14.0, "fatigue": 55.0, "radius": 52.0, "time": 3.0},
	"snow": {"name": "清凉雪花", "cd": 9.0, "fatigue": 35.0, "radius": 44.0, "laugh": 0.4},
	"reinforce": {"name": "冰墙加固", "cd": 16.0, "fatigue": 45.0, "shield": 260.0, "time": 12.0},
}
const RANGE := 360.0
const ICE := Color(0.7, 0.9, 1.0)


static func spell_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", id))


static func radius(id: String) -> float:
	return float(INFO.get(id, {}).get("radius", 24.0))


static func cooldown_left(c: Node, id: String) -> float:
	var cd: Dictionary = c.get_meta("siege_cd", {})
	return maxf(0.0, float(cd.get(id, 0.0)) - Time.get_ticks_msec() / 1000.0)


static func ready(c: Node, id: String) -> bool:
	return cooldown_left(c, id) <= 0.0


static func in_range(c: Node2D, point: Vector2) -> bool:
	return c.global_position.distance_to(point) <= RANGE


## 放一个法术。返回是否放出去了（冷却中 / 射程外 / 被打断 / 失败都算没放成，失败也进冷却）。
static func cast(c: PlayableCharacter, id: String, point: Vector2) -> bool:
	if not INFO.has(id) or not ready(c, id) or not c.is_alive() or Downed.is_downed(c):
		return false
	if id != "reinforce" and not in_range(c, point):
		return false
	# 痒痒迷雾：看不见雾里的地方（清凉雪花 / 结界放不进去）
	if id != "reinforce" and SiegeDirector.current and SiegeDirector.current.in_fog(point):
		return false
	var info: Dictionary = INFO[id]
	var cd: Dictionary = c.get_meta("siege_cd", {})
	cd[id] = Time.get_ticks_msec() / 1000.0 + float(info["cd"])
	c.set_meta("siege_cd", cd)
	var dir := SiegeDirector.current
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
		c.fatigue.add(float(info["fatigue"]))
	_cast_fx(c, point)
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
	var wc: WeakRef = weakref(c)
	parent.get_tree().create_timer(0.45).timeout.connect(func():
		var caster := wc.get_ref() as PlayableCharacter
		if caster == null:
			return
		for i in 9:
			var at := point + Vector2.from_angle(randf() * TAU) * randf() * r
			SiegeFx.icicle(parent, at)
		Audio.play("ice_crack", -3.0, 0.15, 1.2)
		var dir := SiegeDirector.current
		if dir:
			for m in dir.enemies_near(point, r + 6.0):
				m.receive_hit(HitData.make_attack(caster, dmg, 60.0))
		for n in caster.get_tree().get_nodes_in_group("siege_cuttable"):
			if n is Node2D and (n as Node2D).global_position.distance_to(point) <= r + 10.0 and n.has_method("cut"):
				n.cut(caster))


static func _snow(c: PlayableCharacter, point: Vector2, r: float, laugh_frac: float) -> void:
	Fx.burst(c.get_parent(), point + Vector2(0, -20), "snow", 22, 50.0, 1.1, Vector2(0, 30), Color(0.9, 0.97, 1.0))
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
