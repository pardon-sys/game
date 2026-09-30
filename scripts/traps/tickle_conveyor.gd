class_name TickleConveyor
extends Trap
## 痒痒传送带（CONTINUOUS）：从所在格起朝 dir 铺 length 格，站在上面的角色（任何阵营）被送走（push_speed），
## 滚轮每 repeat_interval 秒轻挠 tickle。可接拉杆（switch_disables：拉杆通电 = 停下）。

const SHEET := preload("res://assets/generated/conveyor.png")

@export var dir := "right"
@export var length := 4
@export var push_speed := 40.0

var belt := Vector2.RIGHT
var _anim := 0.0
var _tiles: Array[Sprite2D] = []
var _sound: AudioStreamPlayer2D

@onready var shape: CollisionShape2D = $Shape


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	trigger_mode = TriggerMode.CONTINUOUS
	belt = Trap.dir_vector(dir)
	for i in length:
		var s := Sprite2D.new()
		s.texture = SHEET
		s.hframes = 4
		s.position = belt * 16.0 * i
		s.rotation = belt.angle()
		add_child(s)
		_tiles.append(s)
	var rect := RectangleShape2D.new()
	var along := length * 16.0
	rect.size = Vector2(along, 14) if belt.x != 0.0 else Vector2(14, along)
	shape.shape = rect
	shape.position = belt * 16.0 * (length - 1) / 2.0
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = Audio.loop_stream("conveyor")
	_sound.volume_db = -14.0
	_sound.max_distance = 160.0
	_sound.autoplay = true
	add_child(_sound)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	for body in get_overlapping_bodies():
		if body is Actor:
			(body as Actor).add_push(belt * push_speed)


func _process(delta: float) -> void:
	if is_dangerous():
		_anim += delta
		var f := int(_anim * 8.0) % 4
		for s in _tiles:
			s.frame = f


func _on_switched(on: bool) -> void:
	for s in _tiles:
		s.modulate = Color.WHITE if on else Color(0.6, 0.6, 0.65)
	if on:
		_sound.play()
	else:
		_sound.stop()
