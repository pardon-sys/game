class_name IsoMover
extends RefCounted
## 等距下的移动（可复用；PlayerInputController 在有 IsoView 时用）：
##   from_screen(角色, 屏幕方向)：方向键按屏幕方向，换算成逻辑方向（长度不变）；再做走廊辅助。
##   走廊辅助：等距下只按一个方向键，逻辑上是斜着走；如果其中一个分量被墙挡住，就去掉它、只沿通的方向走（速度不打折）——
##     1 格宽的拐角走廊里按一个键就能顺着走。两个分量都通（空地 / 路口）就照常斜着走。
##   墙角辅助：往某个方向走被墙角卡住、可前面那一格其实是通的（1 格宽的口子没对准）→ 往那一格的中线挪，钻进去（守夜城墙的台阶口卡住过）。

## 往前探多远算「被挡住」：1 格走廊（16 像素）里脚下的碰撞框离上面的墙最多 9 像素左右——探 10 像素就知道这是条走廊
const PROBE := 10.0


static func from_screen(body: Node, v: Vector2) -> Vector2:
	if IsoView.current == null or v == Vector2.ZERO:
		return v
	var w := IsoView.world_dir(v)
	return assist(body as CharacterBody2D, w)


static func assist(body: CharacterBody2D, v: Vector2) -> Vector2:
	if body == null or not body.is_inside_tree() or absf(v.x) < 0.05 or absf(v.y) < 0.05:
		return v
	var xf := body.global_transform
	var bx := body.test_move(xf, Vector2(signf(v.x) * PROBE, 0.0))
	var by := body.test_move(xf, Vector2(0.0, signf(v.y) * PROBE))
	if by and not bx:
		return corner(body, Vector2(signf(v.x), 0.0) * v.length())
	if bx and not by:
		return corner(body, Vector2(0.0, signf(v.y)) * v.length())
	if bx and by:
		# 两个方向都挡：先看哪个方向的口子是通的，往那边对准
		var cx := corner(body, Vector2(signf(v.x), 0.0) * v.length())
		if cx.y != 0.0:
			return cx
		var cy := corner(body, Vector2(0.0, signf(v.y)) * v.length())
		if cy.x != 0.0:
			return cy
	return v


## 墙角辅助：只沿一个轴走（v 只有一个分量）、被墙挡住、前面那一格却是通的 → 加上垂直方向的分量，往那一格的中线挪
static func corner(body: CharacterBody2D, v: Vector2) -> Vector2:
	var lv := Party.level_of(body)
	if lv == null or v == Vector2.ZERO:
		return v
	var along_x := absf(v.x) > absf(v.y)
	var step := Vector2(signf(v.x) * PROBE, 0.0) if along_x else Vector2(0.0, signf(v.y) * PROBE)
	if not body.test_move(body.global_transform, step):
		return v
	var c := GridPath.cell(body.global_position)
	var ahead := c + (Vector2i(int(signf(v.x)), 0) if along_x else Vector2i(0, int(signf(v.y))))
	if not GridPath.walkable(lv, ahead):
		return v
	var mid := GridPath.center(ahead)
	var off := (mid.y - body.global_position.y) if along_x else (mid.x - body.global_position.x)
	if absf(off) < 0.5:
		return v
	var n := v.length()
	return (Vector2(v.x, signf(off) * n * 0.8) if along_x else Vector2(signf(off) * n * 0.8, v.y)).normalized() * n
