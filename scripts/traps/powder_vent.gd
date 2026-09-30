class_name PowderVent
extends Trap
## 痒痒粉喷口：周期性预警冒泡 → 喷出一团会停留的粉雾（TickleCloud），站在雾里持续挠痒。

@export var cloud_duration := 2.5
@export var cloud_interval := 0.4
@export var cloud_tickle := 5.0
@export var cloud_radius := 18.0

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE


func _on_idle() -> void:
	sprite.frame = 4


func _on_warn() -> void:
	sprite.frame = 5


func _on_activate() -> void:
	sprite.frame = 6
	Audio.play("puff", -4.0, 0.1)
	var c := TickleCloud.new()
	c.duration = cloud_duration
	c.interval = cloud_interval
	c.tickle = cloud_tickle
	c.radius = cloud_radius
	c.affects_player = affects_player
	c.affects_allies = affects_allies
	c.affects_enemies = affects_enemies
	c.reaction_key = reaction_key
	get_parent().add_child(c)
	c.global_position = global_position + Vector2(0, -4)


## 喷口本身不直接生效，效果都在粉雾里。
func _apply_effect(_target: Node) -> bool:
	return false


func _on_switched(on: bool) -> void:
	sprite.modulate.a = 1.0 if on else 0.5
