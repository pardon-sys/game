class_name ManaJelly
extends Monster
## 魔力水母：慢悠悠地飘，触须挠痒会把魔力一起搅乱（stats.fatigue_mult = 3：给公主的魔力疲倦 ×3）。
## 被打散时留下一小滩疲倦水液（puddle_life 秒），踩进去的怪物获得「力量」。

@export var puddle_life := 12.0
@export var puddle_radius := 16.0


func _setup() -> void:
	super()
	sprite.hframes = 2


## 飘：方向带一点缓慢的左右摇摆。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if dir != Vector2.ZERO:
		dir = dir.rotated(sin(_t * 1.7) * 0.5)
	super(dir, speed, delta)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 3.0) % 2
	sprite.offset.y = -10.0 + roundf(sin(_t * 2.5) * 1.5)


func _on_died() -> void:
	FatiguePuddle.spawn(get_parent(), global_position, puddle_life, puddle_radius)
	super()
