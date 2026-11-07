class_name OldShoe
extends Monster
## 旧鞋军团（衣帽间；地图标记 shoes）：跳着追人，挠到就套住脚（status.grab，连按挣扎 GRAB_PRESSES 下），鞋里的小刷子挠脚心。
## 把它们引到鞋柜（shoe_closet）旁边按 E 关门：附近的鞋全关进去（PalaceWardrobe.close_closet）。
## 图：assets/generated/old_shoe.png（三帧跳 + 一帧张口）。

const GRAB_TIME := 3.0
const GRAB_PRESSES := 6

var _anim_t := 0.0
var _snap := 0.0   # 刚挠过：张口 / 合上那一帧


func _animate(delta: float) -> void:
	_anim_t += delta
	_snap = maxf(0.0, _snap - delta)
	var moving := velocity.length() > 5.0
	sprite.frame = 3 if _snap > 0.0 else (int(_anim_t * 8.0) % 3 if moving else 0)
	sprite.offset.y = -8.0 - (absf(sin(_anim_t * 8.0)) * 3.0 if moving else 0.0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0


func _on_tickle_performed(t: Node) -> void:
	_snap = 0.35
	var a := t as Actor
	if a and a.get("status") and not a.status.is_grabbed():
		a.status.grab(self, GRAB_TIME, GRAB_PRESSES)
