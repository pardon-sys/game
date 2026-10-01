class_name HexRune
extends Trap
## 诅咒符文（ON_STEP）：踩上去被诅咒——「易痒诅咒」curse_time 秒（闷笑积累 +30%）、
## 魔力疲倦 +fatigue_percent%，并被符文的光轻挠一下（tickle）。冷却 cooldown_time 秒。

@export var curse_time := 10.0
@export var fatigue_percent := 4.0

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if a == null or a.is_fully_invulnerable():
		return false
	a.add_buff("ticklish", curse_time)
	var pc := a as PlayableCharacter
	if pc and pc.fatigue and MagicFatigue.accumulate:
		pc.fatigue.add_percent(fatigue_percent)
	Audio.play("rune", -3.0, 0.08)
	a.receive_hit(make_hit())
	return true


func _on_idle() -> void:
	sprite.frame = 0
	sprite.modulate.a = 1.0


func _on_activate() -> void:
	sprite.frame = 1
	HitFx.play("curse", get_parent(), global_position + Vector2(0, -2))
	Fx.burst(get_parent(), global_position, "drop", 10, 35.0, 0.45, Vector2(0, -20))
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.15)


func _on_cooldown() -> void:
	sprite.frame = 2
