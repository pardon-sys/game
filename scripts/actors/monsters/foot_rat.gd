class_name FootRat
extends Monster
## 挠脚鼠：成群出没、跑得快、一碰就倒；专挑脚心，小口快速地挠。
## 目标动不了（被抓、定身、吟唱、失控）时挠痒加倍。数值见 data/monsters/foot_rat.tres。

@export var immobile_mult := 2.0
@export var zigzag := 0.45


func _tickle_amount(t: Node) -> float:
	var k := immobile_mult if t.has_method("is_immobile") and t.is_immobile() else 1.0
	return stats.tickle_amount * k


## 追击时左右窜动。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if state == State.CHASE and dir != Vector2.ZERO:
		dir = (dir + dir.orthogonal() * sin(_t * 9.0) * zigzag).normalized()
	super(dir, speed, delta)


func _animate(_delta: float) -> void:
	var moving := velocity.length() > 5.0
	sprite.offset.y = -8.0 - (absf(roundf(sin(_t * 18.0))) if moving else 0.0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0


func _on_tickle_performed(_t: Node) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.3, 0.04)
	tw.tween_property(sprite, "rotation", -0.3, 0.06)
	tw.tween_property(sprite, "rotation", 0.0, 0.04)
