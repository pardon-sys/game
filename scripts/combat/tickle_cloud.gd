class_name TickleCloud
extends Area2D
## 痒痒粉雾：在原地停留 duration 秒，每 interval 秒对区域内角色挠痒一次。
## drift：飘动速度（被风扇吹动时设置）。MagicReactive：满蓄力星光爆发会把它吹散。

@export var duration := 2.5
@export var interval := 0.4
@export var tickle := 5.0
@export var radius := 18.0
@export var affects_player := true
@export var affects_allies := true
@export var affects_enemies := false
## 在 princess_reactions.json 的 sources 里对应的键（由喷口传入）。
var reaction_key := ""
## 飘动速度（像素/秒）。
var drift := Vector2.ZERO
## 星光爆发判定时额外的半径（雾有自己的大小）。
var magic_radius := 0.0
var blown := false
## 被风扇卷起（粉末旋风）：挠到公主时触发这个组合技。
var combo_id := ""
var whirled := false

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
	magic_radius = radius
	add_to_group("magic_reactive")
	add_to_group("tickle_cloud")


## MagicReactive：3 档星光爆发把粉雾吹散（不再挠痒，迅速飘走消失）。
func on_magic_burst(tier: int, caster: Node) -> void:
	if tier < 3 or blown:
		return
	blown = true
	var away := global_position - (caster as Node2D).global_position if caster is Node2D else Vector2.UP
	drift = away.normalized() * 160.0 if away != Vector2.ZERO else Vector2.UP * 160.0
	_age = maxf(_age, duration - 0.3)


## 粉末旋风：被风扇卷起后顺风飘、变大、多停留一会儿。
func whirl(wind: Vector2, grow: float, extra_time: float, id: String) -> void:
	if whirled or blown:
		drift = wind
		return
	whirled = true
	drift = wind
	combo_id = id
	duration += extra_time
	set_radius(radius * grow)


## 调整半径（粉末旋风：顺风变大）。
func set_radius(r: float) -> void:
	radius = r
	magic_radius = r
	for c in get_children():
		if c is CollisionShape2D and c.shape is CircleShape2D:
			(c.shape as CircleShape2D).radius = r


func _physics_process(delta: float) -> void:
	if GameState.in_dialogue:
		return
	_age += delta
	_tick -= delta
	global_position += drift * delta
	if _tick <= 0.0 and _age > 0.15 and not blown:
		_tick = interval
		for body in get_overlapping_bodies():
			if _affects(body) and Contracts.is_tickleable(body):
				if body.receive_hit(HitData.make_tickle(self, tickle)) and combo_id != "" \
						and body is PlayableCharacter and (body as PlayableCharacter).combo:
					(body as PlayableCharacter).combo.trigger(combo_id, self)
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
