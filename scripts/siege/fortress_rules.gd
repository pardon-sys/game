class_name FortressRules
extends RefCounted
## Single source used by the director, mechanics, HUD and focused tests.
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/siege/fortress.json"))
	return _data
static func skill(key: String) -> Dictionary:
	return data()["skills"][key]
static func point(actor: Node2D, from: Vector2) -> Vector2:
	return actor.attack_point(from) if actor.has_method("attack_point") else actor.global_position
static func distance(actor: Node2D, from: Vector2) -> float:
	if actor.has_method("footprint") and (actor.footprint() as Rect2).has_point(from): return 0.0
	return from.distance_to(point(actor, from))
