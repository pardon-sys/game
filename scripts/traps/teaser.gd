class_name TeaserTrap
extends Trap
## 羽毛逗弄器（配套挠痒）：装在束缚陷阱旁（同 group_name），有人被那个束缚陷阱困住时，每 interval 秒伸出来
## 专挠露出的部位（tickle_zones.json 的 follow_exposed）。content 决定挠的东西：
##   feather 羽毛（轻）/ brush 刷子（重，额外算「旋转刷」来源）/ slime 史莱姆（附带黏黏减速，额外算「史莱姆」）/
##   tentacle 小触手（附带短暂定身，额外算「触手」）/
##   drill 肚脐羽毛钻（转着圈的羽毛尖，只钻肚子：露出肚子就钻肚子，没露出就挠腰——zone_focus）。

const CONTENT := {
	"feather": {"tickle": 2.5, "fx": "feather", "extra": [], "row": 0},
	"brush": {"tickle": 3.5, "fx": "brush", "extra": ["brush"], "row": 1},
	"slime": {"tickle": 2.5, "fx": "goo", "extra": ["slime"], "row": 2},
	"tentacle": {"tickle": 3.0, "fx": "sting", "extra": ["tentacle"], "row": 3},
	"drill": {"tickle": 3.5, "fx": "feather", "extra": [], "row": 4, "focus": ["belly", "waist"]},
}

@export var content := "feather"
@export var group_name := ""
@export var interval := 0.35
## 最远够得着多远的人（像素）。
@export var reach := 40.0

## 专挑的部位（TickleZones.pick 用；drill 为 ["belly", "waist"]）。
var zone_focus: Array = []
var _cd := 0.0
var _arm: Line2D

@onready var sprite: Sprite2D = $Sprite


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE
	var c: Dictionary = CONTENT.get(content, CONTENT["feather"])
	tickle = float(c["tickle"])
	hit_fx = str(c["fx"])
	zone_focus = c.get("focus", [])
	sprite.frame_coords = Vector2i(0, int(c["row"]))
	_arm = Line2D.new()
	_arm.width = 2.0
	_arm.default_color = Color(0.85, 0.85, 0.95)
	_arm.z_index = 3
	_arm.visible = false
	add_child(_arm)


## 组合额外来源：刷子 / 史莱姆 / 小触手版本同时算对应的来源。
func extra_combo_keys() -> Array:
	return CONTENT.get(content, CONTENT["feather"])["extra"]


## 同组里正困着人的束缚陷阱的受害者（够得着的）。
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
	_arm.visible = v != null
	sprite.frame_coords.x = 1 if v != null else 0
	if v == null or GameState.in_dialogue:
		return
	var aim := Vector2(0, -14) if content == "drill" else Vector2(0, -10)
	var wob := 3.0 if content == "drill" else 2.0
	var tip := to_local(v.global_position + aim) + Vector2(sin(_t * 18.0) * wob, cos(_t * 18.0 if content == "drill" else _t * 14.0) * wob)
	_arm.points = PackedVector2Array([Vector2(0, -4), tip])
	_cd -= delta
	if _cd > 0.0:
		return
	_cd = interval
	if v.receive_hit(make_hit()):
		Audio.play("tickle", -7.0, 0.15, tickle_pitch)
		match content:
			"slime":
				v.add_buff("sticky", 1.5)
			"tentacle":
				if v.status:
					v.status.apply_root(0.4)


func play_show(time: float) -> void:
	sprite.frame_coords.x = 1
	get_tree().create_timer(time).timeout.connect(func(): if is_instance_valid(sprite): sprite.frame_coords.x = 0)
