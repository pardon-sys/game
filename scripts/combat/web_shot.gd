class_name WebShot
extends Projectile
## 蜘蛛丝：命中后减速并少量挠痒，碰撞时留下一团丝的残影。


func _ready() -> void:
	super()
	Audio.play("web", -6.0, 0.1)


func _on_expire() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
