class_name FeatherArm
extends Trap
## 伸缩羽毛臂（墙面陷阱，ON_STEP）：装在墙格上，朝 dir 方向 length 格是探测区。
## 有人进入 → 预警 warn_time 秒（装置亮红灯）→ 羽毛臂伸出横扫整条探测区：
## 扫中的目标定身 root_time 秒 + 挠痒 tickle；然后缩回，冷却 cooldown_time 秒。

const SHEET := preload("res://assets/generated/feather_arm.png")

@export var dir := "down"
@export var length := 2
@export var root_time := 0.6

var lane := Vector2.DOWN
var _mount: Sprite2D
var _arm: Array[Sprite2D] = []


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	lane = Trap.dir_vector(dir)
	# 墙格中心在 (0, -8)（构建器把墙面物件放在格子底边中点）
	var wall_center := Vector2(0, -8)
	_mount = _part(0)
	_mount.position = wall_center + lane * 6.0
	for i in length:
		var s := _part(3 if i == length - 1 else 2)
		s.position = wall_center + lane * 16.0 * (i + 1)
		s.visible = false
		_arm.append(s)
	var rect := RectangleShape2D.new()
	var along := length * 16.0 - 2.0
	rect.size = Vector2(along, 14) if lane.x != 0.0 else Vector2(14, along)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = wall_center + lane * 16.0 * (length + 1) / 2.0


func _part(frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SHEET
	s.hframes = 4
	s.frame = frame
	s.rotation = lane.angle()
	s.z_index = 2
	add_child(s)
	return s


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if a == null or a.is_fully_invulnerable():
		return false
	if a.status:
		a.status.apply_root(root_time)
	return super(target)


func _on_idle() -> void:
	_mount.frame = 0
	for s in _arm:
		s.visible = false


func _on_warn() -> void:
	_mount.frame = 1
	Audio.play("locked", -8.0, 0.05, 1.5)


func _on_activate() -> void:
	Audio.play("swish", -2.0, 0.08, 1.2)
	for i in _arm.size():
		var s := _arm[i]
		s.visible = true
		s.scale = Vector2(0.2, 1.0)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(s, "scale", Vector2.ONE, 0.06)
	var tip := _arm[-1]
	for k in 3:
		get_tree().create_timer(0.05 + k * 0.05, false).timeout.connect(_afterimage.bind(tip))
	var sweep := tip.create_tween().set_loops(3)
	sweep.tween_property(tip, "rotation", lane.angle() + 0.5, 0.05)
	sweep.tween_property(tip, "rotation", lane.angle() - 0.5, 0.05)


## 羽毛尖的残影：复制一份当前姿势，淡出。
func _afterimage(tip: Sprite2D) -> void:
	if not is_instance_valid(tip) or not tip.visible:
		return
	var g := Sprite2D.new()
	g.texture = tip.texture
	g.hframes = tip.hframes
	g.frame = tip.frame
	g.rotation = tip.rotation
	g.position = tip.position
	g.z_index = tip.z_index - 1
	g.modulate = Color(1, 0.8, 0.95, 0.6)
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)


func _on_cooldown() -> void:
	_mount.frame = 0
	for s in _arm:
		s.visible = false
		s.rotation = lane.angle()
