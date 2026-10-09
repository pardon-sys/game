class_name FeatherCurtain
extends Trap
## 羽毛门帘（第八层夜迷宫）：门洞里的羽毛帘子，一会儿卷起（IDLE，安全）、一会儿放下（ACTIVE）。
## 放下时穿过去 → 羽毛从大腿一路刷过（每 0.5 秒，来源键 feather_curtain）。等它卷起来再过就没事。
## 图例：X = trap type=feather_curtain [offset=秒]

const TEX := preload("res://assets/generated/maze/feather_curtain.png")

var sprite: Sprite2D


func _setup() -> void:
	trigger_mode = TriggerMode.PERIODIC
	hit_kind = HitData.Kind.TICKLE
	damage = 0
	tickle = 3.0
	reaction_key = "feather_curtain"
	hit_fx = "feather"
	tickle_zones = {"thigh": 3, "waist": 1}
	repeat_interval = 0.5
	idle_time = 2.2
	warn_time = 0.35
	active_time = 1.8
	collision_layer = 0
	collision_mask = 6
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 12)
	shape.shape = r
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 2
	sprite.frame = 1
	sprite.offset = Vector2(0, -10)
	add_child(sprite)


func _apply_effect(target: Node) -> bool:
	var h := make_hit()
	h.zone = "thigh"
	return target.receive_hit(h)


func _on_idle() -> void:
	if sprite:
		sprite.frame = 1


func _on_warn() -> void:
	sprite.frame = 0
	sprite.modulate.a = 0.6


func _on_activate() -> void:
	sprite.frame = 0
	sprite.modulate.a = 1.0
	Audio.play("cloth", -8.0, 0.2)
