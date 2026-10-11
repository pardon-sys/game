class_name HazardTornado
extends SiegeHazard
## 痒痒龙卷风：在战场上慢慢游走；卷到公主就把她卷起来转着圈挠（SPIN 秒），然后甩出去。

const RADIUS := 22.0
const SPEED := 34.0
const SPIN := 2.2

var _dir := Vector2.ZERO
var _turn := 0.0
var _caught: PlayableCharacter
var _spin_left := 0.0
var _cool := {}


func _begin() -> void:
	reaction_key = "hazard_tornado"
	life = 18.0
	SiegeFx.ring(get_parent(), global_position, RADIUS * 1.6, Color(0.9, 0.6, 1.0, 0.8), WARN)


func _active(delta: float) -> void:
	_turn -= delta
	if _turn <= 0.0:
		_turn = randf_range(1.0, 2.5)
		var p := director.pink
		_dir = Vector2.from_angle(randf() * TAU)
		if p and randf() < 0.5:
			_dir = global_position.direction_to(p.global_position).rotated(randf_range(-0.6, 0.6))
	global_position += _dir * SPEED * delta
	var ms := director.map_size()
	global_position = global_position.clamp(Vector2(40, director.wall_foot_y() + 40), ms - Vector2(40, 40))
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	if randf() < delta * 6.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), 0), "dust", 2, 50.0, 0.5, Vector2(0, -60), Color(0.9, 0.8, 1.0, 0.6))
	if _caught:
		_spin(delta)
		return
	for c in chars():
		if director.is_on_wall(c) or float(_cool.get(c.character_id, 0.0)) > 0.0:
			continue
		if c.global_position.distance_to(global_position) < RADIUS:
			_caught = c
			_spin_left = SPIN
			c.set_physics_process(false)
			SpeechBubble.say(c, "转、转起来了——！" if c.character_id == "pink" else "……转……转……", 28.0, 1.4)
			Audio.play("wind", -2.0, 0.1)
			break


func _spin(delta: float) -> void:
	var c := _caught
	if not is_instance_valid(c):
		_caught = null
		return
	_spin_left -= delta
	c.global_position = global_position + Vector2.from_angle(_t * 9.0) * 10.0 + Vector2(0, -6)
	if randf() < delta * 4.0:
		tickle(c, 5.0, ["waist", "armpit", "sole", "belly"].pick_random())
	if _spin_left <= 0.0:
		_caught = null
		c.set_physics_process(true)
		c.apply_knockback(global_position, 280.0)
		_cool[c.character_id] = 3.0


func _end() -> void:
	if _caught and is_instance_valid(_caught):
		_caught.set_physics_process(true)
	_caught = null
	super()


func _draw() -> void:
	if not warned:
		return
	for i in 5:
		var r := 6.0 + i * 4.0
		var y := -i * 7.0
		var a := _t * 8.0 + i
		draw_arc(Vector2(sin(a) * 2.0, y), r, 0.0, TAU, 20, Color(0.85, 0.75, 1.0, 0.55), 1.5)
