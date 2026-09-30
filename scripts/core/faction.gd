class_name Faction
extends RefCounted
## 阵营。公主与友军是一边，怪物是另一边；中立（木桶、陷阱）谁都不算敌人。

enum Type { NEUTRAL, PLAYER, ALLY, ENEMY }

## 每个阵营对应的节点组，Actor 会自动加入。
const GROUPS := {Type.PLAYER: "player", Type.ALLY: "ally", Type.ENEMY: "enemy"}


static func of(node: Object) -> Type:
	if node == null:
		return Type.NEUTRAL
	var f: Variant = node.get("faction")
	return f if f is int else Type.NEUTRAL


static func is_hostile(a: Type, b: Type) -> bool:
	if a == Type.NEUTRAL or b == Type.NEUTRAL:
		return false
	return (a == Type.ENEMY) != (b == Type.ENEMY)


static func are_hostile(a: Object, b: Object) -> bool:
	return is_hostile(of(a), of(b))
