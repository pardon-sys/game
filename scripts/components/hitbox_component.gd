class_name HitboxComponent
extends Area2D
## 近战命中判定（公主挥杖、友军挥剑等）。
## 调用 begin() 开始一次挥击，挥击有效期内每帧调用 scan()；每次挥击对每个目标只命中一次。
## 只命中敌对阵营或中立的 Damageable（木桶）。

signal hit_landed(target: Node)

@export var damage := 1
@export var knockback := 170.0
## 大于 0 时这是一次"挠痒"而非攻击。
@export var tickle := 0.0

## 发起者（决定阵营与击退方向），默认为父节点。
var attacker: Node2D
var _hit: Array = []


func _ready() -> void:
	monitorable = false
	if attacker == null:
		attacker = get_parent() as Node2D


func begin() -> void:
	_hit.clear()


func scan() -> void:
	for body in _targets():
		if body == attacker or body in _hit or not Contracts.is_damageable(body):
			continue
		var f := Faction.of(body)
		if f != Faction.Type.NEUTRAL and not Faction.is_hostile(Faction.of(attacker), f):
			continue
		_hit.append(body)
		var hit := HitData.make_tickle(attacker, tickle, knockback) if tickle > 0.0 else HitData.make_attack(attacker, damage, knockback)
		if body.receive_hit(hit):
			hit_landed.emit(body)


## 重叠的物体。Area2D 的 get_overlapping_bodies() 检测不到 StaticBody2D（木桶、武器架、藤蔓），
## 所以再用自身形状做一次物理查询补上。
func _targets() -> Array:
	var out: Array = get_overlapping_bodies()
	for c in get_children():
		var cs := c as CollisionShape2D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.collision_mask = collision_mask
		q.collide_with_bodies = true
		q.collide_with_areas = false
		for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
			var body: Object = r["collider"]
			if body and not out.has(body):
				out.append(body)
	return out
