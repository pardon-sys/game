class_name SpinWheelTrap
extends RestraintTrap
## 张臂转盘：走到竖着的转盘前被扣住手腕、双臂张开（胸 ×1.5、腋下 ×1.3），转盘一圈一圈地转，
## 每转一圈（spin_time 秒）旁边固定的刷子就扫一次肋骨（挠痒 sweep_tickle）。
## 放开时沿 dir 把人甩出 fling 格（弹在空中，飞过的陷阱不生效，落点照常触发——可以甩进下一个陷阱）。

const SHEET := preload("res://assets/generated/spinwheel.png")

@export var dir := "down"
@export var fling := 2
@export var spin_time := 1.0
@export var sweep_tickle := 4.0
@export var fling_time := 0.4

var spins := 0
var _spin_t := 0.0
var _fling_target: PlayableCharacter
var _fling_wait := 0.0


func _restraint_setup() -> void:
	if sprite:
		sprite.texture = SHEET
		sprite.hframes = 2
		sprite.offset = Vector2(0, -14)


## 甩出的落点（世界坐标）。
func landing_point() -> Vector2:
	return global_position + Trap.dir_vector(dir) * fling * 16.0


func _on_restrain(_a: Actor) -> void:
	Audio.play("unlock", -2.0, 0.05, 0.7)
	_spin_t = 0.0


func _while_held(delta: float) -> void:
	_spin_t += delta
	if sprite:
		sprite.rotation = _spin_t / spin_time * TAU
	if victim is PlayableCharacter:
		(victim as PlayableCharacter).pose_rotation = sin(_spin_t / spin_time * TAU) * 0.35
	if _spin_t >= spin_time * (spins + 1):
		spins += 1
		if victim.receive_hit(HitData.make_tickle(self, sweep_tickle)):
			Audio.play("swish", -4.0, 0.1, 1.1)


func _on_free(a: Actor) -> void:
	if sprite:
		sprite.rotation = 0.0
	if a is PlayableCharacter and a.is_alive():
		_fling_target = a
		_fling_wait = 0.6


func _physics_process(delta: float) -> void:
	super(delta)
	if _fling_target == null:
		return
	_fling_wait -= delta
	if not is_instance_valid(_fling_target) or _fling_wait <= 0.0:
		_fling_target = null
	elif _fling_target.can_be_moved():
		var pc := _fling_target
		_fling_target = null
		pc.global_position = global_position
		if pc.force_move(Trap.dir_vector(dir) * fling * 16.0 / fling_time, fling_time, "bounce"):
			Audio.play("pop", -3.0, 0.1, 0.8)
