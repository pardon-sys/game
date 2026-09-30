class_name TickleCloud
extends Area2D
## 痒痒粉雾：在原地停留 duration 秒，每 interval 秒对区域内角色挠痒一次。

@export var duration := 2.5
@export var interval := 0.4
@export var tickle := 5.0
@export var radius := 18.0
@export var affects_player := true
@export var affects_allies := true
@export var affects_enemies := false
## 在 princess_reactions.json 的 sources 里对应的键（由喷口传入）。
var reaction_key := ""

var _age := 0.0
var _tick := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 6
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	z_index = 2


func _physics_process(delta: float) -> void:
	if GameState.in_dialogue:
		return
	_age += delta
	_tick -= delta
	if _tick <= 0.0 and _age > 0.15:
		_tick = interval
		for body in get_overlapping_bodies():
			if _affects(body) and Contracts.is_tickleable(body):
				body.receive_hit(HitData.make_tickle(self, tickle))
	if _age >= duration:
		queue_free()
	queue_redraw()


func _affects(body: Node) -> bool:
	match Faction.of(body):
		Faction.Type.PLAYER: return affects_player
		Faction.Type.ALLY: return affects_allies
		Faction.Type.ENEMY: return affects_enemies
	return false


func _draw() -> void:
	# 几团粉色雾气，按像素风分级透明度
	var life := clampf(_age / duration, 0.0, 1.0)
	var grow := minf(_age / 0.3, 1.0)
	var alpha := snappedf((1.0 - life) * 0.55, 0.1)
	for i in 6:
		var ang := i * TAU / 6.0 + _age * 0.8
		var p := Vector2.from_angle(ang) * radius * 0.55 * grow
		var r := roundf(radius * 0.55 * grow + sin(_age * 3.0 + i) * 1.5)
		draw_circle(p.round(), r, Color(1.0, 0.62, 0.82, alpha))
	draw_circle(Vector2.ZERO, roundf(radius * 0.6 * grow), Color(1.0, 0.75, 0.9, alpha))
