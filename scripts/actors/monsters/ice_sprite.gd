class_name IceSprite
extends Monster
## 冰糕精灵（厨房冷藏库）：飘着追人，用冰凉的小手和小羽毛挠，挠到的人被冻得走慢一点（CHILL_SLOW，CHILL_TIME 秒）。
## 图：assets/generated/ice_sprite.png（三帧飘 + 一帧伸手）。

const CHILL_SLOW := 0.7
const CHILL_TIME := 1.5

var _anim_t := 0.0
var _snap := 0.0


func _animate(delta: float) -> void:
	_anim_t += delta
	_snap = maxf(0.0, _snap - delta)
	sprite.frame = 3 if _snap > 0.0 else int(_anim_t * 6.0) % 3
	sprite.offset.y = -14.0 + sin(_anim_t * 3.0) * 2.0
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0


func _on_tickle_performed(t: Node) -> void:
	_snap = 0.35
	var a := t as Actor
	if a and a.get("status"):
		a.status.apply_slow(CHILL_SLOW, CHILL_TIME)
