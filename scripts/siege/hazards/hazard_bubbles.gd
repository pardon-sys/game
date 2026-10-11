class_name HazardBubbles
extends SiegeHazard
## 痒痒泡泡潮：一排大泡泡从战场一边扫到另一边；被包进泡泡的公主飘起来、动不了，泡泡里一直挠，过一会儿泡泡破掉。

const COUNT := 8
const SPEED := 55.0
const R := 11.0
const HOLD := 2.6

var _from_left := true
var _bubbles: Array = []


func _begin() -> void:
	reaction_key = "hazard_bubble"
	life = 40.0
	_from_left = randf() < 0.5
	var ms := director.map_size()
	var x := 20.0 if _from_left else ms.x - 20.0
	for i in COUNT:
		_bubbles.append({"pos": Vector2(x - (i % 2) * 14.0 * (1 if _from_left else -1), global_position.y + (i - COUNT / 2.0) * 22.0), "held": null, "left": 0.0, "pop": false})
	SiegeFx.lane(get_parent(), Vector2(x, global_position.y), Vector2(ms.x - x, global_position.y), COUNT * 22.0, Color(0.6, 0.9, 1.0), WARN)


func _active(delta: float) -> void:
	var dir := 1.0 if _from_left else -1.0
	var alive := 0
	for b in _bubbles:
		if b["pop"]:
			continue
		alive += 1
		var c: PlayableCharacter = b["held"]
		if c and is_instance_valid(c):
			b["left"] = float(b["left"]) - delta
			b["pos"] = (b["pos"] as Vector2) + Vector2(dir * SPEED * 0.4, -6.0) * delta
			c.global_position = (b["pos"] as Vector2) + Vector2(0, 4)
			if randf() < delta * 3.0:
				tickle(c, 4.0, ["sole", "waist", "armpit"].pick_random())
			if float(b["left"]) <= 0.0:
				_pop(b)
			continue
		b["pos"] = (b["pos"] as Vector2) + Vector2(dir * SPEED, sin(_t * 3.0 + (b["pos"] as Vector2).y) * 6.0) * delta
		for ch in chars():
			if not director.is_on_wall(ch) and not ch.get_meta("siege_bubbled", false) and ch.global_position.distance_to(b["pos"]) < R + 4.0:
				b["held"] = ch
				b["left"] = HOLD
				ch.set_meta("siege_bubbled", true)
				ch.set_physics_process(false)
				ch.add_buff("lifted", HOLD)
				Audio.play("bubble", -3.0, 0.1)
				SpeechBubble.say(ch, "泡、泡泡里——飘起来了！" if ch.character_id == "pink" else "……泡泡。……出不去。", 28.0, 1.4)
				break
		var x: float = (b["pos"] as Vector2).x
		if x < -30.0 or x > director.map_size().x + 30.0:
			b["pop"] = true
	if alive == 0:
		life = 0.0


func _pop(b: Dictionary) -> void:
	b["pop"] = true
	var c: PlayableCharacter = b["held"]
	b["held"] = null
	Audio.play("bubble_pop", -3.0, 0.1)
	Fx.burst(get_parent(), b["pos"], "drop", 8, 40.0, 0.4, Vector2(0, 60), Color(0.7, 0.9, 1.0))
	if c and is_instance_valid(c):
		c.set_meta("siege_bubbled", false)
		c.set_physics_process(true)


func _end() -> void:
	for b in _bubbles:
		if b["held"]:
			_pop(b)
	super()


func _draw() -> void:
	if not warned:
		return
	for b in _bubbles:
		if b["pop"]:
			continue
		var p: Vector2 = (b["pos"] as Vector2) - global_position
		draw_circle(p, R, Color(0.7, 0.9, 1.0, 0.25))
		draw_arc(p, R, 0.0, TAU, 24, Color(0.85, 0.97, 1.0, 0.8), 1.0)
		draw_circle(p + Vector2(-4, -4), 2.0, Color(1, 1, 1, 0.8))
