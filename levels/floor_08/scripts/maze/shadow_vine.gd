class_name ShadowVine
extends Trap
## 影子缠腿藤（第八层夜迷宫）：影子里长出来的藤，踩上去缠住大腿定身 ROOT 秒，缠着的时候藤尖慢慢挠大腿内侧
## （每 0.4 秒，来源键 shadow_vine）。冰晶结界冻住它（陷阱暂停）。
## 图例：X = trap type=shadow_vine

const TEX := preload("res://assets/generated/maze/shadow_vine.png")
const ROOT := 2.0

var sprite: Sprite2D


func _setup() -> void:
	trigger_mode = TriggerMode.ON_STEP
	hit_kind = HitData.Kind.TICKLE
	damage = 0
	tickle = 2.5
	reaction_key = "shadow_vine"
	hit_fx = "lines"
	tickle_zones = {"thigh": 1}
	repeat_interval = 0.4
	warn_time = 0.1
	active_time = ROOT
	cooldown_time = 3.0
	collision_layer = 0
	collision_mask = 6
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 10)
	shape.shape = r
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 2
	sprite.offset = Vector2(0, -6)
	add_child(sprite)


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if a and a.status and not a.status.is_rooted():
		a.status.apply_root(ROOT - _t)
	var h := make_hit()
	h.zone = "thigh"
	return target.receive_hit(h)


func _on_activate() -> void:
	sprite.frame = 1
	Audio.play("vine", -6.0, 0.1, 0.8)


func _on_idle() -> void:
	if sprite:
		sprite.frame = 0


func _on_cooldown() -> void:
	sprite.frame = 0
