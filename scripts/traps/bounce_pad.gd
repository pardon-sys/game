class_name BouncePad
extends Trap
## 弹弹床（ON_STEP，强制位移）：踩上去把公主沿 dir 弹出 length 格（飞 flight_time 秒）。
## 飞行中不能操作、不能冲刺，飞过的陷阱不生效（Trap._affects 跳过 is_airborne），落点照常触发脚下的陷阱。
## 弹出前先对准弹弹床中心，落点正好是 length 格外那一格的中心。

@export var dir := "right"
@export var length := 3
@export var flight_time := 0.45

var launch_dir := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	trigger_mode = TriggerMode.ON_STEP
	hit_kind = HitData.Kind.TICKLE
	tickle = 0.0
	warn_time = 0.0
	active_time = 0.15
	cooldown_time = 0.35
	launch_dir = Trap.dir_vector(dir)
	queue_redraw()


## 落点（世界坐标）。
func landing_point() -> Vector2:
	return global_position + launch_dir * length * 16.0


func _apply_effect(target: Node) -> bool:
	var pc := target as PlayableCharacter
	if pc == null or pc.is_force_moving():
		return false
	var from := pc.global_position
	pc.global_position = global_position
	if not pc.force_move(launch_dir * length * 16.0 / flight_time, flight_time, "bounce"):
		pc.global_position = from
		return false
	sprite.frame = 1
	Audio.play("pop", -3.0, 0.1, 0.7)
	Fx.burst(get_parent(), global_position + Vector2(0, 4), "dust", 6, 35.0, 0.35)
	return true


func _on_idle() -> void:
	sprite.frame = 0


func _on_cooldown() -> void:
	sprite.frame = 0


## 弹出方向的小箭头。
func _draw() -> void:
	var tip := launch_dir * 8.0
	var side := launch_dir.orthogonal() * 3.0
	var base := launch_dir * 4.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1, 0.55, 0.8, 0.9))
