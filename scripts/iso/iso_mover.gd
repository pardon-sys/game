class_name IsoMover
extends RefCounted
## 等距下的移动（可复用；PlayerInputController 在有 IsoView 时用）：
##   from_screen(角色, 屏幕方向)：方向键按屏幕方向，换算成逻辑方向（长度不变）；再做走廊辅助。
##   走廊辅助：等距下只按一个方向键，逻辑上是斜着走；如果其中一个分量被墙挡住，就去掉它、只沿通的方向走（速度不打折）——
##     1 格宽的拐角走廊里按一个键就能顺着走。两个分量都通（空地 / 路口）就照常斜着走。

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
		return Vector2(signf(v.x), 0.0) * v.length()
	if bx and not by:
		return Vector2(0.0, signf(v.y)) * v.length()
	return v
