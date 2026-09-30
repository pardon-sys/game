class_name FeatherTrap
extends Trap
## 羽毛陷阱（示例）：踩上去后羽毛弹出，挠痒不扣血。

const FRAME_IDLE := 12
const FRAME_WARN := 13
const FRAME_UP := 14

@onready var sprite: Sprite2D = $Sprite


func _on_idle() -> void:
	sprite.frame = FRAME_IDLE


func _on_warn() -> void:
	sprite.frame = FRAME_WARN


func _on_activate() -> void:
	sprite.frame = FRAME_UP
	Audio.play("cloth", -8.0, 0.2)


func _on_switched(on: bool) -> void:
	sprite.modulate.a = 1.0 if on else 0.5
