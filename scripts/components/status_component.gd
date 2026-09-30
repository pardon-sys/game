class_name StatusComponent
extends Node
## 状态效果组件（节点名 "Status"，挂在 Actor 下）：减速、被抓住。
##   apply_slow(multiplier, duration)          减速（取最强的效果）
##   grab(source, max_time, break_presses)     被抓住：不能行动；连按挣扎 break_presses 次或 max_time 秒后松开
## 被抓期间谁来挠痒由抓人者（怪物 / 机关手）决定，本组件只管状态本身。

signal grabbed(source: Node)
signal released(source: Node, broke_free: bool)
signal slowed(multiplier: float, duration: float)

var grabber: Node = null
var _slow_mult := 1.0
var _slow_time := 0.0
var _grab_time := 0.0
var _grab_max := 0.0
var _presses_left := 0


func _process(delta: float) -> void:
	if GameState.in_dialogue:  # 对话期间状态计时暂停
		return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_mult = 1.0
	if grabber != null:
		_grab_time += delta
		if not is_instance_valid(grabber) or (_grab_max > 0.0 and _grab_time >= _grab_max):
			release(false)


func apply_slow(multiplier: float, duration: float) -> void:
	_slow_mult = minf(_slow_mult, multiplier) if _slow_time > 0.0 else multiplier
	_slow_time = maxf(_slow_time, duration)
	slowed.emit(multiplier, duration)


func speed_multiplier() -> float:
	return _slow_mult if _slow_time > 0.0 else 1.0


func is_slowed() -> bool:
	return _slow_time > 0.0


func grab(source: Node, max_time := 3.5, break_presses := 10) -> bool:
	if is_grabbed():
		return false
	grabber = source
	_grab_time = 0.0
	_grab_max = max_time
	_presses_left = break_presses
	grabbed.emit(source)
	return true


func is_grabbed() -> bool:
	return grabber != null and is_instance_valid(grabber)


func is_grabbed_by(source: Node) -> bool:
	return is_grabbed() and grabber == source


## 挣扎一次，返回是否挣脱。
func struggle() -> bool:
	if not is_grabbed():
		return false
	_presses_left -= 1
	if _presses_left <= 0:
		release(true)
		return true
	return false


func presses_left() -> int:
	return _presses_left


func release(broke_free := false) -> void:
	if grabber == null:
		return
	var src := grabber
	grabber = null
	released.emit(src, broke_free)


func clear() -> void:
	_slow_mult = 1.0
	_slow_time = 0.0
	release(false)
