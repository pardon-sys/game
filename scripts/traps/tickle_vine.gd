class_name TickleVine
extends Trap
## 痒痒藤蔓（ON_STEP）：踩上去被缠住脚（定身 root_time 秒），缠住期间每 repeat_interval 秒挠痒 tickle。
## 权杖可以砍断（regrow_time 秒后长回）；星光爆发 1~2 档等同砍断，满蓄力（3 档）直接清除、不再长回。

@export var root_time := 1.0
@export var regrow_time := 8.0

var cut_left := 0.0
var cleared := false
var magic_radius := 6.0
var _rooted := {}

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	stops_slide = true
	hit_kind = HitData.Kind.TICKLE
	add_to_group("magic_reactive")


func _physics_process(delta: float) -> void:
	if cut_left > 0.0 and not GameState.in_dialogue:
		cut_left -= delta
		if cut_left <= 0.0 and not cleared:
			_regrow()
	super(delta)


func is_cut() -> bool:
	return cut_left > 0.0 or cleared


func _on_idle() -> void:
	if not is_cut():
		sprite.frame = 0


func _on_activate() -> void:
	sprite.frame = 1
	_rooted.clear()
	Audio.play("vine", -4.0, 0.1)


## 第一次碰到时缠住，之后按 repeat_interval 挠痒。
func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if a and a.status and not _rooted.has(a.get_instance_id()):
		_rooted[a.get_instance_id()] = true
		a.status.apply_root(root_time)
	return super(target)


## 权杖砍（经由 HitRelay 转交）。
func receive_hit(hit: HitData) -> bool:
	if hit.kind != HitData.Kind.ATTACK or is_cut():
		return false
	cut(false)
	return true


## MagicReactive
func on_magic_burst(tier: int, _caster: Node) -> void:
	if not cleared:
		cut(tier >= 3)


func cut(permanent: bool) -> void:
	cleared = cleared or permanent
	cut_left = regrow_time
	for body in get_overlapping_bodies():
		if body is Actor and (body as Actor).status and _rooted.has(body.get_instance_id()):
			(body as Actor).status.clear_root()
	active = false
	_enter(Phase.IDLE)
	sprite.frame = 2
	sprite.modulate.a = 0.4 if permanent else 1.0
	Fx.puff(get_parent(), global_position)
	Audio.play("vine", -2.0, 0.1, 1.3)


func _regrow() -> void:
	active = true
	_enter(Phase.IDLE)
	sprite.frame = 0
	var tw := create_tween()
	sprite.scale = Vector2(0.4, 0.4)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.3)
