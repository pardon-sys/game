class_name MirrorPuddle
extends Trap
## 镜面水洼（第八层夜迷宫）：地上反着微光的水洼。踩上去 → 倒影里伸出一只手挠屁股（来源键 mirror_puddle），
## 再从水洼里冒出一只紫手（导演 hand_from，优先盖屁股）。之后 COOLDOWN 秒内水面平静。
## 图例：X = trap type=mirror_puddle

const TEX := preload("res://assets/generated/maze/mirror_puddle.png")

var sprite: Sprite2D


func _setup() -> void:
	trigger_mode = TriggerMode.ON_STEP
	hit_kind = HitData.Kind.TICKLE
	damage = 0
	tickle = 6.0
	reaction_key = "mirror_puddle"
	hit_fx = "hand"
	tickle_zones = {"butt": 1}
	warn_time = 0.2
	active_time = 0.3
	cooldown_time = 5.0
	collision_layer = 0
	collision_mask = 6
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 10)
	shape.shape = r
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.z_index = -1
	add_child(sprite)
	if IsoView.enabled:
		add_to_group(IsoView.GROUND_GROUP)   # 等距：水洼贴在地上（压成椭圆）


func _apply_effect(target: Node) -> bool:
	var h := make_hit()
	h.zone = "butt"
	var ok: bool = target.receive_hit(h)
	if ok:
		Audio.play("bubble_pop", -6.0, 0.1, 0.8)
		var dir := get_tree().get_first_node_in_group("maze_director")
		if dir and dir.has_method("hand_from"):
			dir.hand_from(global_position + Vector2(0, 6), "butt")
	return ok


func _on_activate() -> void:
	sprite.modulate = Color(1.4, 1.3, 1.6)


func _on_idle() -> void:
	if sprite:
		sprite.modulate = Color.WHITE
