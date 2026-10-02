class_name WheelTrap
extends Trap
## 痒痒转轮（配套挠痒）：放在束缚陷阱对面（同 group_name），有人被困住时每 turn_time 秒转一面挠一下，
## 每面换一种：羽毛 → 旋转刷 → 机关手。这一下额外算当前那一面对应的陷阱来源（一台就能凑齐多种来源）。

const FACES := ["feather", "brush", "hand"]
const FACE_FX := {"feather": "feather", "brush": "brush", "hand": "hand"}

@export var group_name := ""
@export var turn_time := 0.8
@export var reach := 48.0

var face := 0
var _cd := 0.5

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE


func extra_combo_keys() -> Array:
	return [FACES[face]]


func current_face() -> String:
	return FACES[face]


func held_victim() -> Actor:
	if group_name == "":
		return null
	for n in get_tree().get_nodes_in_group(group_name):
		var r := n as RestraintTrap
		if r and r.is_holding() and r.victim.global_position.distance_to(global_position) <= reach:
			return r.victim
	return null


func _apply_effect(_target: Node) -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	var v := held_victim() if active else null
	if v == null or GameState.in_dialogue:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	_cd = turn_time
	face = (face + 1) % FACES.size()
	sprite.frame = face
	hit_fx = FACE_FX[FACES[face]]
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	if v.receive_hit(make_hit()):
		Audio.play("swish", -6.0, 0.1)


func play_show(_time: float) -> void:
	face = (face + 1) % FACES.size()
	sprite.frame = face
