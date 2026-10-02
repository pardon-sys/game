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
## 额外标记，如星光爆发的 "magic_1" ~ "magic_3"（分裂史莱姆、精灵群据此判断）。
var tag := ""
## 特殊挠痒（暴击）：挠痒量已经乘过 special_mult；魔力疲倦按 2 倍积累。
var special := false
## 魔力疲倦的额外倍率（魔力水母为 3）。
var fatigue_mult := 1.0
## 挠到的部位（TickleZones 的部位 id；没有来源键的挠痒为空）。
var zone := ""


func is_magic() -> bool:
	return tag.begins_with("magic_")


## 星光爆发或疲倦爆发（刺猬滚球、狂热图腾这类"普通攻击打不动"的东西据此判断）。
func is_burst() -> bool:
	return is_magic() or tag == "fatigue_burst"


func magic_tier() -> int:
	return tag.substr(6).to_int() if is_magic() else 0


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
