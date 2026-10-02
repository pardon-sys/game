class_name ShowerTrap
extends Trap
## 羽毛雨喷口（配套挠痒 / 触发类）：天花板的喷口，被压力板 / 绊线触发（MANUAL，加入 group_name 组），
## 或同组的束缚陷阱困住人时，对 3×3 区域落 active_time 秒「雨」，每 rain_interval 秒挠区域里的人一下。
## aim = true：落在触发那一刻公主所在的位置。content 同逗弄器：feather / brush / slime / tentacle。

const FEATHER := preload("res://assets/generated/wind_feather.png")
const CONTENT := {
	"feather": {"tickle": 2.0, "fx": "feather", "extra": [], "particle": ""},
	"brush": {"tickle": 2.8, "fx": "brush", "extra": ["brush"], "particle": "chip"},
	"slime": {"tickle": 2.0, "fx": "goo", "extra": ["slime"], "particle": "goo"},
	"tentacle": {"tickle": 2.4, "fx": "sting", "extra": ["tentacle"], "particle": "heart"},
}
const HALF := 24.0

@export var content := "feather"
@export var group_name := ""
@export var aim := false
@export var rain_interval := 0.4

var rain_center := Vector2.ZERO
var _cd := 0.0
var _rain: CPUParticles2D
var _mark: Node2D

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	trigger_mode = TriggerMode.MANUAL
	hit_kind = HitData.Kind.TICKLE
	warn_time = 0.35
	active_time = 2.0
	cooldown_time = 1.5
	var c: Dictionary = CONTENT.get(content, CONTENT["feather"])
	tickle = float(c["tickle"])
	hit_fx = str(c["fx"])
	if group_name != "":
		add_to_group(group_name)
	_rain = CPUParticles2D.new()
	if str(c["particle"]) == "":
		_rain.texture = FEATHER
	else:
		_rain.texture = Fx.PARTICLES[str(c["particle"])]
	_rain.amount = 18
	_rain.lifetime = 0.7
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(HALF, 2)
	_rain.direction = Vector2.DOWN
	_rain.spread = 8.0
	_rain.gravity = Vector2(0, 160)
	_rain.initial_velocity_min = 10.0
	_rain.initial_velocity_max = 30.0
	_rain.emitting = false
	_rain.z_index = 6
	_rain.top_level = true
	add_child(_rain)
	_mark = Node2D.new()
	_mark.top_level = true
	_mark.z_index = -1
	_mark.draw.connect(func(): _mark.draw_rect(Rect2(-HALF, -HALF, HALF * 2, HALF * 2), Color(1, 0.6, 0.85, 0.18)))
	_mark.visible = false
	add_child(_mark)


func extra_combo_keys() -> Array:
	return CONTENT.get(content, CONTENT["feather"])["extra"]


func _on_warn() -> void:
	var p := GameState.player
	rain_center = p.global_position if aim and is_instance_valid(p) else global_position
	_mark.global_position = rain_center
	_mark.visible = true
	_mark.queue_redraw()
	sprite.frame = 1
	Audio.play("puff", -6.0, 0.1, 1.3)


func _on_activate() -> void:
	_rain.global_position = rain_center + Vector2(0, -HALF - 10)
	_rain.emitting = true
	_cd = 0.0


func _on_cooldown() -> void:
	_stop()


func _on_idle() -> void:
	_stop()


func _stop() -> void:
	if _rain:
		_rain.emitting = false
	if _mark:
		_mark.visible = false
	if sprite:
		sprite.frame = 0


func _apply_effect(_target: Node) -> bool:
	return false


func in_rain(p: Vector2) -> bool:
	return absf(p.x - rain_center.x) <= HALF and absf(p.y - rain_center.y) <= HALF


func _physics_process(delta: float) -> void:
	super(delta)
	if GameState.in_dialogue or not active:
		return
	# 同组的束缚陷阱困住人：自动下雨，落在被困的人身上
	if phase == Phase.IDLE and group_name != "":
		for n in get_tree().get_nodes_in_group(group_name):
			var r := n as RestraintTrap
			if r and r.is_holding():
				trigger()
				break
	if phase != Phase.ACTIVE:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	_cd = rain_interval
	for n in get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a and a.is_alive() and _affects(a) and in_rain(a.global_position) and a.receive_hit(make_hit()):
			Audio.play("tickle", -8.0, 0.15, 1.4)
			if content == "slime":
				a.add_buff("sticky", 1.0)
			elif content == "tentacle" and a.status:
				a.status.apply_root(0.3)


func play_show(time: float) -> void:
	rain_center = global_position
	_rain.global_position = rain_center + Vector2(0, -HALF - 10)
	_rain.emitting = true
	get_tree().create_timer(time).timeout.connect(func(): if is_instance_valid(_rain): _rain.emitting = false)
