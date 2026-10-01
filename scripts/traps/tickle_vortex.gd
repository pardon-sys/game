class_name TickleVortex
extends Trap
## 吸痒漩涡（CONTINUOUS，强制位移）：半径 radius 格内持续把角色往中心吸，越靠近中心吸得越快。
## 公主走路 80：外圈还走得出去，靠近中心就走不出去，只能冲刺挣开（冲刺中不受吸力）。
## 被弹在空中、被抓住 / 定身时不吸。中心通常放足枷台 / 藤蔓。可接拉杆（拉杆通电 = 关掉漩涡）。

const TEX := preload("res://assets/generated/vortex.png")

@export var radius := 3
## 外圈 / 中心的吸力（像素/秒）。
@export var pull_edge := 35.0
@export var pull_center := 110.0
## 漩涡贴图转速（弧度/秒）。
@export var spin_speed := 2.5

var _sprite: Sprite2D
var _particles: CPUParticles2D
var _sound: AudioStreamPlayer2D
var _anim := 0.0


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE
	tickle = 0.0
	var circle := CircleShape2D.new()
	circle.radius = radius * 16.0
	($Shape as CollisionShape2D).shape = circle
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.hframes = 2
	_sprite.scale = Vector2.ONE * (radius * 32.0 / 48.0) * 0.75
	_sprite.modulate = Color(1, 1, 1, 0.85)
	add_child(_sprite)
	# 往中心吸的粉色尘粒
	_particles = Fx.emitter(self, "dust", 10 + radius * 4, 1.1, {"speed": [0.0, 4.0], "color": Color(1, 0.6, 0.85), "z": 1})
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_particles.emission_sphere_radius = radius * 16.0 * 0.9
	_particles.radial_accel_min = -110.0
	_particles.radial_accel_max = -80.0
	_particles.tangential_accel_min = 40.0
	_particles.tangential_accel_max = 60.0
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = Audio.loop_stream("wind")
	_sound.volume_db = -16.0
	_sound.pitch_scale = 0.7
	_sound.max_distance = 160.0
	_sound.autoplay = true
	add_child(_sound)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	for body in _victims():
		var a := body as Actor
		if a == null or not a.is_alive() or not can_pull(a):
			continue
		a.add_push(pull_for(a, delta))


## 这个角色现在会不会被吸（冲刺中、被抓住 / 定身时不吸；弹在空中的 _victims 已经排除）。
func can_pull(a: Actor) -> bool:
	if a.has_method("is_dashing") and a.is_dashing():
		return false
	return not (a.status and (a.status.is_grabbed() or a.status.is_rooted()))


## 对角色的吸力（越靠近中心越快，不会吸过头）。
func pull_for(a: Actor, delta := 1.0 / 60.0) -> Vector2:
	var to := global_position - a.global_position
	var d := to.length()
	if d < 2.0:
		return Vector2.ZERO
	var k := 1.0 - clampf(d / (radius * 16.0), 0.0, 1.0)
	return to / d * minf(lerpf(pull_edge, pull_center, k), d / maxf(delta, 0.001))


## 漩涡本身不挠痒，只吸人。
func _apply_effect(_target: Node) -> bool:
	return false


func _process(delta: float) -> void:
	if is_dangerous():
		_anim += delta
		_sprite.rotation += spin_speed * delta
		_sprite.frame = int(_anim * 6.0) % 2


func _on_switched(on: bool) -> void:
	if _sprite == null:
		return
	_particles.emitting = on
	_sprite.modulate.a = 0.85 if on else 0.3
	if on:
		_sound.play()
	else:
		_sound.stop()
