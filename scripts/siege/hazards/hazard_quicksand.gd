class_name HazardQuicksand
extends SiegeHazard
## 挠痒流沙旋涡：地面裂开一大圈流沙（半径 RADIUS），范围里的人和怪都被慢慢吸向中心（add_push）。
## 公主陷到中心（SINK_R 以内）就被流沙抓住（status.grab，连按 BREAK_PRESSES 下挣脱），沙里伸出小手挠
## （粉色公主挠脚心，蓝色公主挠大腿根 / 屁股）；蓝色公主的冰链也能把粉色公主拉出来（标记 siege_dragged / siege_dragger，
## 冰链救援会调 release_drag）。挣出来后 COOL 秒内不会再被吸住。怪被吸到中心会陷住一会儿（冻住）。来源键 hazard_quicksand。
## 流沙伏兵（第十轮）：沙里不时钻出小怪；公主陷住时附近的怪全部围过来。

const RADIUS := 130.0
const SINK_R := 20.0
const PULL := 46.0
const MOB_PULL := 38.0
const BREAK_PRESSES := 12
const HOLD := 4.0
const TICKLE_GAP := 0.45
const TICKLE := 4.0
const COOL := 3.0
## 流沙伏兵（第十轮）：每 AMBUSH_GAP 秒从沙里钻出 AMBUSH_N 只小怪；公主陷住时 RALLY_R 以内的怪围过来挠
const AMBUSH_GAP := 3.0
const AMBUSH_N := 2
const AMBUSH_KEYS := ["slime", "rat", "mini_tentacle"]
const RALLY_R := 220.0

var sunk: PlayableCharacter
var _tick := 0.0
var _hits := 0
var _cool := {}
var _owned_physics := true
var _hands: Array[Vector2] = []
var _ambush_t := 1.0
## 测试用：沙里钻出来的伏兵有几只
var ambushed := 0


func _begin() -> void:
	reaction_key = "hazard_quicksand"
	life = 13.0
	add_to_group("danger")
	set_meta("radius", RADIUS * 0.6)
	SiegeFx.ring(get_parent(), global_position, RADIUS, Color(0.95, 0.8, 0.45, 0.8), WARN)
	Audio.play("rumble", -4.0, 0.1, 0.9)


func _on_start() -> void:
	SiegeFx.impact(get_parent(), global_position, RADIUS * 0.5, false, Color(0.95, 0.8, 0.5))
	for i in 6:
		_hands.append(Vector2.from_angle(TAU * i / 6.0) * randf_range(6.0, 12.0))


func _active(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	if sunk:
		_hold_tick(delta)
	_ambush_t -= delta
	if _ambush_t <= 0.0:
		_ambush_t = AMBUSH_GAP
		var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(RADIUS * 0.3, RADIUS * 0.7) * Vector2(1, 0.55)
		ambushed += ambush(at, AMBUSH_KEYS, AMBUSH_N, sunk).size()
	for c in chars():
		if c == sunk or director.is_on_wall(c) or float(_cool.get(c.character_id, 0.0)) > 0.0 or not SiegeTools.can_move(null, c):
			continue
		var off := global_position - c.global_position
		var dist := off.length()
		if dist > RADIUS:
			continue
		# 越靠近中心吸得越快
		c.add_push(off.normalized() * PULL * (1.4 - dist / RADIUS))
		if sunk == null and dist <= SINK_R:
			_sink(c)
	for m in director.enemies_near(global_position, RADIUS):
		if not SiegeTools.displaceable(m):
			continue
		var mo := global_position - m.global_position
		m.add_push(mo.normalized() * MOB_PULL)
		if mo.length() <= SINK_R:
			m.stun(0.6)
	if randf() < delta * 10.0:
		Fx.burst(get_parent(), global_position + Vector2.from_angle(randf() * TAU) * randf() * RADIUS, "dust", 2, 18.0, 0.6,
			Vector2(0, -6), Color(0.9, 0.75, 0.45, 0.8))


func _sink(c: PlayableCharacter) -> void:
	if not c.status.grab(self, HOLD, BREAK_PRESSES):
		return
	sunk = c
	_owned_physics = c.is_physics_processing()
	c.set_physics_process(false)
	c.global_position = global_position
	c.set_meta("siege_dragged", true)
	c.set_meta("siege_dragger", self)
	_tick = 0.2
	for m in director.enemies_near(global_position, RALLY_R):
		if SiegeTools.alive(m) and not (m is SiegeBoss) and not (m is SiegeCart):
			m.rally_to(c)
	SpeechBubble.say(c, "陷、陷进去了——拉我一把！" if c.character_id == "pink" else "……陷到腰了。……别伸手进来。", 28.0, 1.6)
	Audio.play("bubble_pop", -4.0, 0.1, 0.8)


func _hold_tick(delta: float) -> void:
	var c := sunk
	if not SiegeTools.alive(c) or not c.status.is_grabbed_by(self):
		release_drag()
		return
	if c.sprite:
		c.sprite.position.y = 6.0 + sin(_t * 6.0)   # 陷在沙里，只露出上半身
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICKLE_GAP
		tickle(c, TICKLE, SiegeTools.zone(c, _hits))
		_hits += 1
		Fx.burst(get_parent(), c.global_position + Vector2(randf_range(-6, 6), 0), "dust", 3, 20.0, 0.4, Vector2(0, -10), Color(0.9, 0.75, 0.45))


## 放出来（挣脱、冰链拉走、流沙消失）：推到圈外一点，COOL 秒内不再吸她。
func release_drag() -> void:
	var c := sunk
	sunk = null
	if not is_instance_valid(c):
		return
	if c.get_meta("siege_dragger", null) == self:
		c.set_meta("siege_dragged", false)
		c.remove_meta("siege_dragger")
	if c.sprite:
		c.sprite.position.y = 0.0
	if c.status and c.status.is_grabbed_by(self):
		c.status.release(false)
	var out := director.clamp_in_map(global_position + Vector2(0, SINK_R + 14.0))
	var safe := SiegeTools.safe_spot(c, out)
	c.global_position = safe if safe != Vector2.INF else out
	c.set_physics_process(_owned_physics)
	_cool[c.character_id] = COOL


func _end() -> void:
	release_drag()
	if is_in_group("danger"):
		remove_from_group("danger")
	super()


func _exit_tree() -> void:
	release_drag()


func _draw() -> void:
	var a := 0.35 if warned else 0.15
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.75, 0.6, 0.35, a))
	for i in 4:
		var r := RADIUS * (1.0 - i * 0.22)
		var start := _t * (1.5 + i * 0.4) + i
		draw_arc(Vector2.ZERO, r, start, start + 2.2, 24, Color(0.95, 0.82, 0.55, a + 0.2), 2.0)
	draw_circle(Vector2.ZERO, SINK_R, Color(0.45, 0.32, 0.2, a + 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not warned:
		return
	# 沙里伸出来的小手
	for i in _hands.size():
		var p := _hands[i] * Vector2(1, 0.55) + Vector2(0, sin(_t * 5.0 + i) * 2.0)
		draw_line(p, p + Vector2(0, -6 - sin(_t * 7.0 + i) * 2.0), Color(1, 0.85, 0.75), 2.0)
		draw_circle(p + Vector2(0, -7 - sin(_t * 7.0 + i) * 2.0), 2.0, Color(1, 0.85, 0.75))
