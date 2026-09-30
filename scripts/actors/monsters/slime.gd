class_name Slime
extends Monster
## 史莱姆：一跳一跳地移动，果冻般的挤压动画。数值见 data/monsters/slime.tres。


func _move(dir: Vector2, speed: float, delta: float) -> void:
	var hop := 1.0
	if state == State.CHASE:
		hop = 0.4 + 0.6 * maxf(sin(_t * 8.0), 0.0)
	super(dir, speed * hop, delta)


func _animate(_delta: float) -> void:
	var s := sin(_t * (10.0 if state == State.CHASE else 5.0)) * 0.1
	sprite.scale = Vector2(1.0 + s, 1.0 - s)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0


func _on_tickle_performed(_t: Node) -> void:
	# 挠痒时抖一抖（之后可换成专门的动画）
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.25, 0.05)
	tw.tween_property(sprite, "rotation", -0.25, 0.08)
	tw.tween_property(sprite, "rotation", 0.0, 0.05)
