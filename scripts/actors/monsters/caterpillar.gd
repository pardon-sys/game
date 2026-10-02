class_name Caterpillar
extends LatchMonster
## 毛毛虫：爬到脚上吸住后沿着身体往上爬，每 climb_time 秒换一个部位：脚心 → 大腿 → 胸（肋骨）→ 胸（锁骨），
## 越往上挠得越重（每爬一格 +30%）。抖 3 下就掉。没吸住时贴身挠按 tickle_zones.json 的部位。

## 爬升路线：[部位, 小怪在身上的位置]
const CLIMB := [["sole", Vector2(0, -3)], ["thigh", Vector2(2, -8)], ["chest", Vector2(-2, -16)], ["chest", Vector2(0, -21)]]

@export var climb_time := 1.0

var climb := 0
var _climb_t := 0.0


func _on_latch() -> void:
	climb = 0
	_climb_t = 0.0
	_apply_climb()


func _on_latched_tick(delta: float) -> void:
	_climb_t += delta
	if _climb_t >= climb_time and climb < CLIMB.size() - 1:
		_climb_t = 0.0
		climb += 1
		_apply_climb()


func _apply_climb() -> void:
	tickle_zones = {CLIMB[climb][0]: 1}


## 现在爬到的部位（没吸住时为空）。
func current_zone() -> String:
	return str(CLIMB[climb][0]) if is_latched() else ""


func _on_detach() -> void:
	climb = 0
	tickle_zones = {}


func _latch_sprite_pos() -> Vector2:
	return CLIMB[climb][1]


func _latch_amount() -> float:
	return latch_tickle * (1.0 + 0.3 * climb)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * (8.0 if is_latched() else 4.0)) % 2
	if is_latched():
		sprite.rotation = -PI / 2.0 if climb >= 1 else 0.0
		return
	sprite.rotation = 0.0
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
