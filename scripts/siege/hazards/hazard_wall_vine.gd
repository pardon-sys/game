class_name HazardWallVine
extends SiegeHazard
## 城墙爬藤（牺牲互救）：怪物在墙脚种下藤根（Root：敌方 Actor，只有粉色公主打得动），藤蔓顺着墙爬上去缠住城墙上的蓝色公主——
## 她动不了、放不了法术，藤尖一直挠大腿和腰。粉色公主要去墙脚砍藤根：站在藤根旁边时根须缠住她的脚踝挠脚心（ANKLE_TICK），
## 要忍着把它砍断（约 4 秒）。藤根断了 → 藤蔓枯掉，蓝色公主自由。

const REACH := 70.0
const ANKLE := 22.0
const VINE_TICK := 0.6
const ANKLE_TICK := 0.5

var root: Root
var bound: PlayableCharacter
var _vine: Line2D
var _vt := 0.0
var _at := 0.0
var _grow := 0.0


class Root extends Actor:
	var hazard: HazardWallVine

	func _setup() -> void:
		set_faction(Faction.Type.ENEMY)
		add_to_group("siege_vine_root")
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := CircleShape2D.new()
		r.radius = 8.0
		cs.shape = r
		add_child(cs)
		var hc := HealthComponent.new()
		hc.name = "Health"
		hc.max_hp = 8
		add_child(hc)
		health = hc
		hc.fill()
		hc.died.connect(_die)
		hurt_invuln_time = 0.3

	func receive_hit(hit: HitData) -> bool:
		if not (hit.source is PlayableCharacter and (hit.source as PlayableCharacter).character_id == "pink"):
			return false
		return super(hit)

	func _on_died() -> void:
		if hazard and is_instance_valid(hazard):
			hazard.cut()
		Fx.burst(get_parent(), global_position + Vector2(0, -6), "chip", 14, 60.0, 0.6, Vector2(0, 90), Color(0.4, 0.7, 0.3))
		queue_free()

	func _draw() -> void:
		draw_circle(Vector2(0, -4), 8.0, Color(0.3, 0.5, 0.22))
		for i in 5:
			var a := float(i) * 1.25
			draw_line(Vector2(0, -4), Vector2.from_angle(a) * 12.0 + Vector2(0, -2), Color(0.4, 0.65, 0.3), 2.0)


func _begin() -> void:
	reaction_key = "hazard_wall_vine"
	life = 40.0
	global_position = Vector2(global_position.x, director.wall_foot_y() + 6.0)
	SiegeFx.ring(get_parent(), global_position, 18.0, Color(0.5, 0.9, 0.4, 0.8), WARN)


func _on_start() -> void:
	root = Root.new()
	root.hazard = self
	get_parent().add_child(root)
	root.global_position = global_position
	root.queue_redraw()
	_vine = Line2D.new()
	_vine.width = 3.0
	_vine.default_color = Color(0.4, 0.75, 0.35)
	_vine.z_index = 12
	_vine.add_to_group("siege_temp")
	get_parent().add_child(_vine)
	_vine.global_position = Vector2.ZERO
	Audio.play("vine", -2.0, 0.0, 0.8)


func _active(delta: float) -> void:
	if not is_instance_valid(root):
		life = 0.0
		return
	_grow = minf(1.0, _grow + delta * 0.8)
	var top := Vector2(global_position.x, director.wall_top_y())
	var b := director.blue
	if bound == null and _grow >= 1.0 and b and is_instance_valid(b) and director.is_on_wall(b) \
			and absf(b.global_position.x - global_position.x) < REACH and b.status and not b.status.is_grabbed():
		if b.status.grab(root, 999.0, 99999):
			bound = b
			SpeechBubble.say(b, "……藤、藤蔓……缠住了……动不了。", 28.0, 1.8)
			GameState.rule("蓝色公主被城墙爬藤缠住了！粉色公主去墙脚砍断藤根！")
	if bound:
		top = bound.global_position + Vector2(0, -6)
		_vt -= delta
		if _vt <= 0.0:
			_vt = VINE_TICK
			tickle(bound, 4.0, ["thigh", "waist"].pick_random())
	_draw_vine(top)
	# 叶子飘落
	if randf() < delta * 3.0:
		Fx.burst(get_parent(), global_position.lerp(top, randf()) + Vector2(randf_range(-6, 6), 0), "feather", 1, 15.0, 1.0, Vector2(0, 30),
			Color(0.5, 0.85, 0.4))
	# 根须缠住砍藤根的粉色公主的脚踝
	var p := director.pink
	if p and is_instance_valid(p) and p.global_position.distance_to(global_position) < ANKLE:
		_at -= delta
		if p.status:
			p.status.apply_slow(0.3, 0.6)
		if _at <= 0.0:
			_at = ANKLE_TICK
			tickle(p, 4.0, "sole")
			if randf() < 0.3:
				SpeechBubble.say(p, ["根、根须缠住脚踝了……脚心！", "忍、忍住……马上就砍断了……哈哈！", "别挠脚心……我在救人呢——哈哈哈！"].pick_random(), 28.0, 1.4)


func _draw_vine(top: Vector2) -> void:
	if _vine == null or not is_instance_valid(_vine):
		return
	var pts := PackedVector2Array()
	var from := global_position + Vector2(0, -6)
	var to := from.lerp(top, _grow)
	for i in 9:
		var f := i / 8.0
		pts.append(from.lerp(to, f) + Vector2(sin(f * 9.0 + _t * 2.0) * 4.0, 0))
	_vine.points = pts


func cut() -> void:
	if bound and is_instance_valid(bound) and bound.status:
		bound.status.release(true)
		SpeechBubble.say(bound, "……松开了。……谢谢。", 28.0, 1.6)
	bound = null
	life = 0.0


func _end() -> void:
	cut()
	if _vine and is_instance_valid(_vine):
		_vine.queue_free()
	if is_instance_valid(root):
		root.queue_free()
	super()
