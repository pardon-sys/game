class_name FeatherFan
extends Trap
## 羽毛风扇（CONTINUOUS）：朝 dir 吹出 length 格长的风道，把风道里的角色往外推（push_speed），
## 风里的羽毛每 repeat_interval 秒轻挠 tickle。可接拉杆（switch_disables：拉杆通电 = 关掉风扇）。
## 粉末旋风（条件型组合技 powder_whirlwind）：痒痒粉雾飘进风道后顺风飘动、变大，挠到公主时触发。

const FEATHER := preload("res://assets/generated/wind_feather.png")

@export var dir := "right"
@export var length := 5
@export var push_speed := 70.0
@export var cloud_drift := 40.0
@export var cloud_grow := 1.5
@export var cloud_extra_time := 1.5
## 风道宽度（像素）。
@export var lane_width := 14.0

var wind := Vector2.RIGHT
var _anim := 0.0
var _particles: CPUParticles2D
var _sound: AudioStreamPlayer2D

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	trigger_mode = TriggerMode.CONTINUOUS
	wind = Trap.dir_vector(dir)
	var rect := RectangleShape2D.new()
	var along := length * 16.0
	rect.size = Vector2(along, lane_width) if wind.x != 0.0 else Vector2(lane_width, along)
	shape.shape = rect
	shape.position = wind * (along / 2.0 + 8.0)
	_particles = CPUParticles2D.new()
	_particles.texture = FEATHER
	_particles.amount = 4 + length * 2
	_particles.lifetime = along / 90.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = wind.orthogonal().abs() * (lane_width / 2.0) + Vector2.ONE
	_particles.position = wind * 10.0
	_particles.direction = wind
	_particles.spread = 6.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 80.0
	_particles.initial_velocity_max = 100.0
	_particles.angular_velocity_min = -200.0
	_particles.angular_velocity_max = 200.0
	add_child(_particles)
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = Audio.loop_stream("wind")
	_sound.volume_db = -12.0
	_sound.max_distance = 180.0
	_sound.autoplay = true
	add_child(_sound)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	for body in get_overlapping_bodies():
		if body is Actor:
			(body as Actor).add_push(wind * push_speed)
	for c in get_tree().get_nodes_in_group("tickle_cloud"):
		var cloud := c as TickleCloud
		if cloud and in_lane(cloud.global_position):
			cloud.whirl(wind * cloud_drift, cloud_grow, cloud_extra_time, "powder_whirlwind")


func in_lane(p: Vector2) -> bool:
	var l := to_local(p)
	var along := l.dot(wind)
	return along >= 0.0 and along <= length * 16.0 + 8.0 and absf(l.dot(wind.orthogonal())) <= lane_width / 2.0 + 4.0


func _process(delta: float) -> void:
	if is_dangerous():
		_anim += delta
		sprite.frame = int(_anim * 14.0) % 2


func _on_switched(on: bool) -> void:
	_particles.emitting = on
	sprite.modulate.a = 1.0 if on else 0.6
	if on:
		_sound.play()
	else:
		_sound.stop()
