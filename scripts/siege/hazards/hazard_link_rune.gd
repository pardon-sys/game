class_name HazardLinkRune
extends SiegeHazard
## 痒感连线符文：战场上一块发光的符文石。粉色公主踩到附近时，两位公主之间连上一条粉线——
## 之后谁被挠，另一个也跟着痒一半（SHARE）；粉色公主打碎符文石（Stone，敌方的 Actor，有血量）才断开。

const SHARE := 0.5
const TRIGGER := 18.0

var stone: Stone
var linked := false
var _line: Line2D
var _busy := false


class Stone extends Actor:
	var rune: HazardLinkRune

	func _setup() -> void:
		set_faction(Faction.Type.ENEMY)
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := CircleShape2D.new()
		r.radius = 7.0
		cs.shape = r
		add_child(cs)
		var hc := HealthComponent.new()
		hc.name = "Health"
		hc.max_hp = 6
		add_child(hc)
		health = hc
		hc.fill()
		hc.died.connect(_die)
		hurt_invuln_time = 0.25

	func _on_died() -> void:
		if rune and is_instance_valid(rune):
			rune.unlink()
		Fx.burst(get_parent(), global_position + Vector2(0, -6), "chip", 12, 60.0, 0.6, Vector2(0, 90), Color(1, 0.6, 0.85))
		queue_free()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(7, -8), Vector2(5, 0), Vector2(-5, 0), Vector2(-7, -8)]), Color(0.45, 0.3, 0.5))
		draw_arc(Vector2(0, -8), 3.0, 0.0, TAU, 12, Color(1, 0.55, 0.85), 1.5)


func _begin() -> void:
	reaction_key = "hazard_link"
	life = 40.0
	stone = Stone.new()
	stone.rune = self
	get_parent().add_child(stone)
	stone.global_position = global_position
	stone.queue_redraw()
	SiegeFx.ring(get_parent(), global_position, TRIGGER * 2.0, Color(1, 0.55, 0.85, 0.8), WARN)


func _active(_delta: float) -> void:
	if not is_instance_valid(stone):
		life = 0.0
		return
	var p := director.pink
	if not linked and p and is_instance_valid(p) and p.global_position.distance_to(global_position) < TRIGGER:
		link()
	if linked and _line and is_instance_valid(director.blue) and is_instance_valid(p):
		_line.points = PackedVector2Array([p.global_position + Vector2(0, -10), director.blue.global_position + Vector2(0, -10)])
		_line.default_color.a = 0.5 + 0.3 * sin(_t * 6.0)


func link() -> void:
	linked = true
	for c in chars():
		c.tickled.connect(_on_tickled.bind(c))
	_line = Line2D.new()
	_line.width = 1.5
	_line.default_color = Color(1, 0.55, 0.85, 0.7)
	_line.z_index = 25
	_line.add_to_group("siege_temp")
	get_parent().add_child(_line)
	_line.global_position = Vector2.ZERO
	Audio.play("rune", -3.0, 0.1)
	GameState.notify("痒感连线！一个被挠，另一个也会痒——打碎符文石！")


func _on_tickled(hit: HitData, c: PlayableCharacter) -> void:
	if _busy or not linked or hit.source == self:
		return
	var other: PlayableCharacter = director.blue if c == director.pink else director.pink
	if other == null or not is_instance_valid(other):
		return
	_busy = true
	tickle(other, hit.tickle * SHARE, hit.zone)
	_busy = false


func unlink() -> void:
	if not linked:
		return
	linked = false
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c):
			for conn in c.tickled.get_connections():
				if conn["callable"].get_object() == self:
					c.tickled.disconnect(conn["callable"])
	if _line and is_instance_valid(_line):
		_line.queue_free()
	life = 0.0


func _end() -> void:
	unlink()
	if is_instance_valid(stone):
		stone.queue_free()
	super()
