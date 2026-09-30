class_name HitData
extends RefCounted
## 一次命中的数据。所有伤害与挠痒都打包成 HitData，通过 Damageable 接口 receive_hit(hit) 传递。
##   ATTACK：扣血（damage）
##   TICKLE：累积闷笑值（tickle），不扣血

enum Kind { ATTACK, TICKLE }

var kind := Kind.ATTACK
var damage := 0
var tickle := 0.0
var knockback := 0.0
## 发起者（可能随后被释放，使用前用 is_instance_valid 检查）。
var source: Node = null
## 命中来源位置，用于计算击退方向。
var origin := Vector2.ZERO


static func make_attack(src: Node, amount := 1, kb := 0.0) -> HitData:
	var h := HitData.new()
	h.kind = Kind.ATTACK
	h.damage = amount
	h.knockback = kb
	h._set_source(src)
	return h


static func make_tickle(src: Node, amount := 10.0, kb := 0.0) -> HitData:
	var h := HitData.new()
	h.kind = Kind.TICKLE
	h.tickle = amount
	h.knockback = kb
	h._set_source(src)
	return h


func _set_source(src: Node) -> void:
	source = src
	if src is Node2D:
		origin = (src as Node2D).global_position
