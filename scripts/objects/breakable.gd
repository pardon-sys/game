extends StaticBody2D
## 可打碎的木桶（Damageable，中立）：受到攻击后碎裂，按掉落表生成物品。

@export var drops: Array[ItemDrop] = []


func receive_hit(hit: HitData) -> bool:
	if hit.kind != HitData.Kind.ATTACK or is_queued_for_deletion():
		return false
	Audio.play("break", -3.0)
	Fx.puff(get_parent(), global_position + Vector2(0, -8))
	ItemDrop.roll(drops, get_parent(), global_position)
	queue_free()
	return true
