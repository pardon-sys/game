class_name TrapReach
extends RefCounted
## 束缚陷阱多一格的触发范围（RestraintTrap、足枷台共用）：
##   expand(陷阱, reach)    触发区（子节点 Shape 的矩形）每边外扩 reach 格；原来的矩形记在 meta core_rect
##   can_reach(陷阱, 目标)  在原来的格子上 → 能；在外扩的一圈里 → 中间没有墙才能（隔墙不会被拉过去）
##   pull(目标, 位置, delta) 被扣住时把人拉到陷阱上（不是瞬移）
## 图例 reach=0 关掉。

const TILE := 16.0
const PULL_SPEED := 220.0


static func expand(trap: Area2D, reach: int) -> void:
	if reach <= 0 or trap.has_meta("core_rect"):
		return
	var cs := trap.get_node_or_null("Shape") as CollisionShape2D
	if cs == null or not cs.shape is RectangleShape2D:
		return
	# 形状是场景里的子资源，同一种陷阱共用：先复制一份再改
	var r := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
	trap.set_meta("core_rect", Rect2(cs.position - r.size / 2.0, r.size))
	r.size += Vector2.ONE * float(reach) * TILE * 2.0
	cs.shape = r


static func core_center(trap: Area2D) -> Vector2:
	if trap.has_meta("core_rect"):
		return trap.to_global((trap.get_meta("core_rect") as Rect2).get_center())
	return trap.global_position


static func in_core(trap: Area2D, body: Node2D) -> bool:
	if not trap.has_meta("core_rect"):
		return true
	return (trap.get_meta("core_rect") as Rect2).grow(3.0).has_point(trap.to_local(body.global_position))


static func can_reach(trap: Area2D, body: Node2D) -> bool:
	if in_core(trap, body):
		return true
	var q := PhysicsRayQueryParameters2D.create(core_center(trap), body.global_position + Vector2(0, -3), 1)
	q.collide_with_areas = false
	if body is CollisionObject2D:
		q.exclude = [(body as CollisionObject2D).get_rid()]
	return trap.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 往 target 拉一步；到了返回 true。
static func pull(body: Node2D, target: Vector2, delta: float) -> bool:
	body.global_position = body.global_position.move_toward(target, PULL_SPEED * delta)
	return body.global_position.distance_to(target) < 0.5


## 拉人的表现：一串粉色拖痕 + 抓取声。
static func pull_fx(trap: Node2D, body: Node2D) -> void:
	Audio.play("grab", -4.0, 0.08)
	var from := body.global_position + Vector2(0, -6)
	var to := core_center(trap as Area2D) + Vector2(0, -6) if trap is Area2D else trap.global_position
	for i in 4:
		Fx.burst(trap.get_parent(), from.lerp(to, i / 3.0), "dust", 2, 12.0, 0.35, Vector2.ZERO, Color(1, 0.6, 0.85))
