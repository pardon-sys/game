class_name FrenzyTotem
extends Trap
## 狂热图腾（CONTINUOUS 光环）：半径 aura_radius 内的怪物持续获得「狂热」（暴击率 +20%、挠痒冷却 ×0.8）。
## 血 max_hp，可以用权杖打碎（经由 HitRelay）；任何档位的星光爆发都能直接打碎（MagicReactive）。
## 本身挡路（Body 在墙层 + breakable 层）。

@export var aura_radius := 64.0
@export var max_hp := 3

var hp := 3
var broken := false
var magic_radius := 8.0
var _anim := 0.0
var _embers: CPUParticles2D

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	affects_player = false
	affects_allies = false
	affects_enemies = true
	repeat_interval = 0.3
	hp = max_hp
	add_to_group("magic_reactive")
	var circle := CircleShape2D.new()
	circle.radius = aura_radius
	($Shape as CollisionShape2D).shape = circle
	($Body as StaticBody2D).collision_layer = 33
	_embers = Fx.emitter(self, "ember", 6, 0.9, {"offset": Vector2(0, -18), "spread": 25.0, "speed": [8.0, 18.0],
			"extents": Vector2(3, 1), "z": 3})


func _process(delta: float) -> void:
	_anim += delta
	if not broken:
		sprite.frame = int(_anim * 4.0) % 2
	queue_redraw()


func _draw() -> void:
	if broken or not active:
		return
	var a := 0.10 + 0.05 * sin(_anim * 3.0)
	draw_circle(Vector2.ZERO, aura_radius, Color(1.0, 0.5, 0.2, a * 0.5))
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.25, a * 2.0), 1.0)


func _apply_effect(target: Node) -> bool:
	if target is Monster and (target as Monster).is_alive():
		var first := not (target as Monster).has_buff("frenzy")
		(target as Monster).add_buff("frenzy")
		if first:
			Audio.play("totem", -10.0, 0.1)
			_hint()
		return true
	return false


func _hint() -> void:
	var p := GameState.player
	if GameState.has_flag("hint_totem") or not is_instance_valid(p) or p.global_position.distance_to(global_position) > 120.0:
		return
	GameState.set_flag("hint_totem")
	GameState.notify(ReactionDB.hint("frenzy_totem"))


## 权杖打（HitRelay 转交）。
func receive_hit(hit: HitData) -> bool:
	if broken or hit.kind != HitData.Kind.ATTACK:
		return false
	if hit.is_burst():
		smash()
		return true
	hp -= maxi(1, hit.damage)
	Audio.play("hit", -4.0, 0.1, 0.8)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.6, 1.3, 1.3), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		smash()
	return true


## MagicReactive：任何档位的星光爆发都能打碎。
func on_magic_burst(_tier: int, _caster: Node) -> void:
	smash()


func smash() -> void:
	if broken:
		return
	broken = true
	hp = 0
	active = false
	_enter(Phase.IDLE)
	sprite.frame = 2
	_embers.emitting = false
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "chip", 10, 50.0, 0.5)
	($Body as StaticBody2D).collision_layer = 0
	Fx.puff(get_parent(), global_position + Vector2(0, -8))
	Audio.play("break", -2.0, 0.05)
	queue_redraw()
