class_name HazardFog
extends SiegeHazard
## 痒痒迷雾：一大片粉色的雾。粉色公主在雾里时，蓝色公主看不见她、支援不了（SiegeDirector.in_fog）；雾里还会伸出手来挠。
## 迷雾伏击（怪物 + 陷阱）：雾里的怪半透明（meta in_fog），冰塔、弓箭手、法术都打不到；粉色公主一走进雾，雾里的怪全扑过来。

const RADIUS := 126.0

var _poke := 0.0


func _begin() -> void:
	reaction_key = "hazard_fog"
	life = 16.0
	SiegeFx.ring(get_parent(), global_position, RADIUS, Color(1, 0.6, 0.85, 0.6), WARN, 0.05)


func covers(pos: Vector2) -> bool:
	return warned and life > 0.0 and pos.distance_to(global_position) < RADIUS


var _pink_in := false


func _active(delta: float) -> void:
	# 雾里的怪：半透明、打不到
	for m in director.enemies_near(global_position, RADIUS + 20.0):
		var inside := covers(m.global_position)
		if inside != bool(m.get_meta("in_fog", false)):
			m.set_meta("in_fog", inside)
			m.modulate.a = 0.35 if inside else 1.0
	var p := director.pink
	var now_in := p != null and is_instance_valid(p) and covers(p.global_position)
	if now_in and not _pink_in:
		var n := 0
		for m in director.enemies_near(global_position, RADIUS):
			if m.get_meta("in_fog", false):
				m.rally_to(p)
				n += 1
		if n > 0:
			SpeechBubble.say(p, "雾、雾里全是……呀！", 28.0, 1.4)
	_pink_in = now_in
	_poke -= delta
	if _poke > 0.0:
		return
	_poke = 1.2
	for c in chars():
		if covers(c.global_position):
			tickle(c, 3.0, ["waist", "sole", "armpit"].pick_random())
			Fx.burst(get_parent(), c.global_position + Vector2(randf_range(-8, 8), -8), "feather", 2, 20.0, 0.4, Vector2(0, -10))


func _end() -> void:
	for m in director.enemies_near(global_position, RADIUS + 40.0):
		if m.get_meta("in_fog", false):
			m.set_meta("in_fog", false)
			m.modulate.a = 1.0
	super()


func _draw() -> void:
	if not warned:
		return
	# 雾里偶尔伸出的手影
	if int(_t * 2.0) % 3 == 0:
		var hp := Vector2.from_angle(_t) * RADIUS * 0.4
		draw_circle(hp, 5.0, Color(0.6, 0.3, 0.5, 0.35))
		for k in 4:
			draw_line(hp, hp + Vector2(-4 + k * 2.6, -9), Color(0.6, 0.3, 0.5, 0.35), 2.0)
	for i in 14:
		var a := float(i) * 0.9 + _t * 0.3
		var r := RADIUS * (0.35 + 0.55 * fmod(i * 0.37, 1.0))
		draw_circle(Vector2.from_angle(a) * r * 0.6, 26.0 + 6.0 * sin(_t + i), Color(1, 0.7, 0.88, 0.18))
	draw_circle(Vector2.ZERO, RADIUS * 0.7, Color(1, 0.72, 0.9, 0.12))
