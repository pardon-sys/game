class_name FeatherBrush
extends Trap
## 旋转羽毛刷：刷臂一直匀速旋转（CONTINUOUS），扫到就挠痒并把人推开；同一目标 repeat_interval 秒内只生效一次。

## 旋转速度（弧度/秒），负数为逆时针。
@export var spin_speed := 1.6


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE


func _physics_process(delta: float) -> void:
	if active and not GameState.in_dialogue:
		rotation += spin_speed * delta
	super(delta)


func _apply_effect(target: Node) -> bool:
	var ok := super(target)
	if ok:
		Audio.play("swish", -8.0, 0.1)
	return ok


func _on_switched(on: bool) -> void:
	modulate.a = 1.0 if on else 0.5
