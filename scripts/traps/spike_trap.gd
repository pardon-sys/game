class_name SpikeTrap
extends Trap
## 尖刺陷阱：周期性升起，扣血。冲刺无敌可以穿过。

const FRAME_DOWN := 8
const FRAME_WARN := 9
const FRAME_UP := 10

@onready var sprite: Sprite2D = $Sprite


func _on_idle() -> void:
	sprite.frame = FRAME_DOWN


func _on_warn() -> void:
	sprite.frame = FRAME_WARN


func _on_activate() -> void:
	sprite.frame = FRAME_UP
	Audio.play("hit", -18.0, 0.2)


func _on_switched(on: bool) -> void:
	sprite.modulate.a = 1.0 if on else 0.5
