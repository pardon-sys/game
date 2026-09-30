class_name PincerCrab
extends Monster
## 钳钳蟹：横着走；挠痒 = 夹住脚趾（定身 pinch_root 秒）再挠一下。数值见 data/monsters/pincer_crab.tres。

@export var pinch_root := 1.0


## 横着走：主要沿水平方向移动。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if dir != Vector2.ZERO:
		var side := signf(dir.x) if absf(dir.x) > 0.05 else (1.0 if sin(_t) > 0.0 else -1.0)
		dir = Vector2(side, dir.y * 0.45).normalized()
	super(dir, speed, delta)


func _on_tickle_performed(t: Node) -> void:
	Audio.play("pinch", -3.0)
	if t is Actor and (t as Actor).status:
		(t as Actor).status.apply_root(pinch_root)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.05)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)


func _animate(_delta: float) -> void:
	var moving := velocity.length() > 5.0
	sprite.rotation = sin(_t * 14.0) * 0.08 if moving else 0.0
