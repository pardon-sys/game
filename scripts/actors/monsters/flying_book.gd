class_name FlyingBook
extends Monster
## 飞书（图书馆的飞书群；PalaceLibrary 在 book_swarm 踩到后分三波放出来）：书页像翅膀一样扑扇，夹住脚趾「翻页」挠痒。
## 怕火：粉色公主的攻击 / 魔法打它伤害 ×FIRE_MULT。图：assets/generated/flying_book.png（三帧飞 + 一帧合上夹）。

const FIRE_MULT := 2


func receive_hit(hit: HitData) -> bool:
	if hit.kind == HitData.Kind.ATTACK and (hit.is_magic() or (hit.source is PlayableCharacter and (hit.source as PlayableCharacter).character_id == "pink")):
		hit.damage *= FIRE_MULT
	return super(hit)


var _anim_t := 0.0
var _snap := 0.0   # 刚挠过：张口 / 合上那一帧


func _animate(delta: float) -> void:
	_anim_t += delta
	_snap = maxf(0.0, _snap - delta)
	sprite.frame = 3 if _snap > 0.0 else int(_anim_t * 10.0) % 3
	sprite.offset.y = -14.0 + sin(_anim_t * 4.0) * 2.0
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0


func _on_tickle_performed(_t: Node) -> void:
	_snap = 0.35
