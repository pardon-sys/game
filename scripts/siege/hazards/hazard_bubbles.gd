class_name HazardBubbles
extends SiegeHazard
## 痒痒泡泡潮：一排大泡泡从战场一边扫到另一边；被包进泡泡的公主飘起来、动不了，泡泡里一直挠，过一会儿泡泡破掉。
## 泡泡运兵（怪物 + 陷阱）：泡泡也会把小怪包进去，一路飘到城墙下放下。

const COUNT := 8
const SPEED := 55.0
const R := 11.0
const HOLD := 2.6

var _from_left := true
var _bubbles: Array = []
var _closed := false


func _begin() -> void:
	reaction_key = "hazard_bubble"
	add_to_group("siege_wind_bubbles")
	life = 40.0
	_from_left = randf() < 0.5
	var ms := director.map_size()
	var x := 20.0 if _from_left else ms.x - 20.0
	for i in COUNT:
		_bubbles.append({"pos": Vector2(x - (i % 2) * 14.0 * (1 if _from_left else -1), global_position.y + (i - COUNT / 2.0) * 22.0), "held": null, "left": 0.0, "pop": false})
	SiegeFx.lane(get_parent(), Vector2(x, global_position.y), Vector2(ms.x - x, global_position.y), COUNT * 22.0, Color(0.6, 0.9, 1.0), WARN)


## 风推动的是每颗泡泡的实际位置，乘员随泡泡碰撞移动。
func blow(motion: Vector2) -> void:
	if _closed or not warned or SiegeTools.paused() or director.state != "fight":
		return
	for b in _bubbles:
		if not b["pop"]:
			_move_bubble(b, motion)
	queue_redraw()


func _move_bubble(b: Dictionary, motion: Vector2) -> void:
	var passenger: Variant = b.get("held")
	if typeof(passenger) != TYPE_OBJECT: passenger = b.get("mob")
	if typeof(passenger) == TYPE_OBJECT:
		if not SiegeTools.alive(passenger) or passenger.get_meta("siege_bubble_owner", null) != self:
			_pop(b)
			return
		var actor := passenger as Actor
		actor.move_and_collide(motion)
		b["pos"] = actor.global_position - Vector2(0, 4)
	else:
		b["pos"] = (b["pos"] as Vector2) + motion
	var at: Vector2 = b["pos"]
	if at.x < -30.0 or at.x > director.map_size().x + 30.0:
		_pop(b)


func _active(delta: float) -> void:
	if _closed: return
	var dir := 1.0 if _from_left else -1.0
	var alive := 0
	for b in _bubbles:
		if b["pop"]:
			continue
		alive += 1
		var mob: Variant = b.get("mob")
		if typeof(mob) == TYPE_OBJECT:
			if not is_instance_valid(mob):
				_pop(b)
				continue
			# 运兵：往城墙那边飘，到墙下就破掉放下
			var goal := Vector2((b["pos"] as Vector2).x, director.wall_foot_y() + 14.0)
			_move_bubble(b, (b["pos"] as Vector2).direction_to(goal) * minf(50.0 * delta, (b["pos"] as Vector2).distance_to(goal)))
			if (b["pos"] as Vector2).distance_to(goal) < 4.0:
				_pop(b)
			continue
		var held: Variant = b.get("held")
		if typeof(held) == TYPE_OBJECT:
			if not is_instance_valid(held):
				_pop(b)
				continue
			var c := held as PlayableCharacter
			b["left"] = float(b["left"]) - delta
			_move_bubble(b, Vector2(dir * SPEED * 0.4, -6.0) * delta)
			if not b["pop"] and randf() < delta * 3.0:
				tickle(c, 4.0, ["sole", "waist", "armpit"].pick_random())
			if float(b["left"]) <= 0.0:
				_pop(b)
			continue
		_move_bubble(b, Vector2(dir * SPEED, sin(_t * 3.0 + (b["pos"] as Vector2).y) * 6.0) * delta)
		if b["pop"]: continue
		for ch in chars():
			if not director.is_on_wall(ch) and SiegeTools.can_move(null, ch) and ch.global_position.distance_to(b["pos"]) < R + 4.0:
				b["held"] = ch
				b["left"] = HOLD
				b["pos"] = ch.global_position - Vector2(0, 4)
				ch.set_meta("siege_bubbled", true)
				ch.set_meta("siege_bubble_owner", self)
				ch.set_physics_process(false)
				ch.add_buff("lifted", HOLD)
				Audio.play("bubble", -3.0, 0.1)
				SpeechBubble.say(ch, "泡、泡泡里——飘起来了！" if ch.character_id == "pink" else "……泡泡。……出不去。", 28.0, 1.4)
				break
		if b.get("held") == null and b.get("mob") == null:
			for m in director.enemies_near(b["pos"], R + 2.0):
				if m is SiegeBoss or m is TrollGeneral or m is SiegeCart or not m.is_physics_processing() or m.get_meta("siege_on_wall", false) \
						or m.get_meta("airborne", false) or m.get_meta("team_transfer", false) or m.has_meta("in_ladder"):
					continue
				b["mob"] = m
				b["pos"] = m.global_position - Vector2(0, 4)
				m.set_meta("siege_bubble_owner", self)
				m.set_physics_process(false)
				break
	if alive == 0:
		life = 0.0


func _pop(b: Dictionary) -> void:
	if b["pop"]: return
	b["pop"] = true
	_release(b)
	Audio.play("bubble_pop", -3.0, 0.1)
	Fx.burst(get_parent(), b["pos"], "drop", 8, 40.0, 0.4, Vector2(0, 60), Color(0.7, 0.9, 1.0))


func _release(b: Dictionary) -> void:
	for key in ["held", "mob"]:
		var passenger: Variant = b.get(key)
		b[key] = null
		if not is_instance_valid(passenger) or passenger.get_meta("siege_bubble_owner", null) != self:
			continue
		passenger.remove_meta("siege_bubble_owner")
		if passenger is PlayableCharacter:
			passenger.set_meta("siege_bubbled", false)
			passenger.remove_buff("lifted")
		passenger.velocity = Vector2.ZERO
		passenger.set_physics_process(true)


func _end() -> void:
	if _closed: return
	_closed = true
	for b in _bubbles:
		_pop(b)
	super()


func _exit_tree() -> void:
	for b in _bubbles:
		_release(b)


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
		# 反光闪烁
		draw_arc(p, R - 2.0, -1.2 + sin(_t * 4.0) * 0.3, -0.4, 8, Color(1, 1, 1, 0.6), 1.0)
