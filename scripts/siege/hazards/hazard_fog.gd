class_name HazardFog
extends SiegeHazard
## 痒痒迷雾：一大片粉色的雾。粉色公主在雾里时，蓝色公主看不见她、支援不了（SiegeDirector.in_fog）；雾里还会伸出手来挠。

const RADIUS := 90.0

var _poke := 0.0


func _begin() -> void:
	reaction_key = "hazard_fog"
	life = 16.0
	SiegeFx.ring(get_parent(), global_position, RADIUS, Color(1, 0.6, 0.85, 0.6), WARN, 0.05)


func covers(pos: Vector2) -> bool:
	return warned and life > 0.0 and pos.distance_to(global_position) < RADIUS


func _active(delta: float) -> void:
	_poke -= delta
	if _poke > 0.0:
		return
	_poke = 1.2
	for c in chars():
		if covers(c.global_position):
			tickle(c, 3.0, ["waist", "sole", "armpit"].pick_random())
			Fx.burst(get_parent(), c.global_position + Vector2(randf_range(-8, 8), -8), "feather", 2, 20.0, 0.4, Vector2(0, -10))


func _draw() -> void:
	if not warned:
		return
	for i in 14:
		var a := float(i) * 0.9 + _t * 0.3
		var r := RADIUS * (0.35 + 0.55 * fmod(i * 0.37, 1.0))
		draw_circle(Vector2.from_angle(a) * r * 0.6, 26.0 + 6.0 * sin(_t + i), Color(1, 0.7, 0.88, 0.18))
	draw_circle(Vector2.ZERO, RADIUS * 0.7, Color(1, 0.72, 0.9, 0.12))
