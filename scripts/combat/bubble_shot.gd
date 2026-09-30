class_name BubbleShot
extends Projectile
## 泡泡鱼的泡泡：命中后由泡泡鱼把目标关进泡泡牢笼（BubbleFish.trap）；关不住（已被抓、冲刺中）就只轻挠一下。


func _on_hit(target: Node) -> void:
	if is_instance_valid(shooter) and shooter is BubbleFish:
		var fish := shooter as BubbleFish
		if not fish.trap(target):
			fish.deliver_tickle(target, tickle)
		return
	super(target)


func _physics_process(delta: float) -> void:
	super(delta)
	var s := get_node_or_null("Sprite") as Sprite2D
	if s:
		s.frame = int(_age * 6.0) % 2
		s.position.y = roundf(sin(_age * 10.0))


func _on_expire() -> void:
	Audio.play("bubble_pop", -8.0, 0.15)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
