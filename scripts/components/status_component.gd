class_name StatusComponent
extends Node
## 状态效果组件（节点名 "Status"，挂在 Actor 下）。
##   apply_slow(multiplier, duration)          减速（取最强的效果）
##   grab(source, max_time, break_presses)     被抓住：不能行动；连按挣扎 break_presses 次或 max_time 秒后松开
##   apply_root(duration)                      定身：不能移动、冲刺，仍可攻击（藤蔓、钳钳蟹）
##   add_dot(tickle_per_sec, duration, source) 余痒：持续挠痒，每 DOT_INTERVAL 秒结算一次
##   add_tickle_multiplier(k, duration)        易痒：受到的挠痒 ×k（多个同时生效取最大）
##   add_pull(source, speed, duration)         拉扯：持续被拉向 source（触手）
##   is_immobile()                             被抓或定身
## 被抓期间谁来挠痒由抓人者（怪物 / 机关手）决定，本组件只管状态本身。
## 外力推动（风扇、传送带）不在这里，见 Actor.add_push。

signal grabbed(source: Node)
signal released(source: Node, broke_free: bool)
signal slowed(multiplier: float, duration: float)
signal rooted(duration: float)

const DOT_INTERVAL := 0.5

var grabber: Node = null
var _slow_mult := 1.0
var _slow_time := 0.0
var _grab_time := 0.0
var _grab_max := 0.0
var _presses_left := 0
var _root_time := 0.0
## [{rate, time, source, tick}]
var _dots: Array[Dictionary] = []
## [{k, time}]
var _mults: Array[Dictionary] = []
var _pull_src: Node2D = null
var _pull_speed := 0.0
var _pull_time := 0.0


func _process(delta: float) -> void:
	if GameState.in_dialogue:  # 对话期间状态计时暂停
		return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_mult = 1.0
	_root_time = maxf(_root_time - delta, 0.0)
	for m in _mults:
		m["time"] -= delta
	_mults = _mults.filter(func(m: Dictionary): return m["time"] > 0.0)
	_tick_dots(delta)
	if _pull_time > 0.0:
		_pull_time -= delta
		var owner_actor := get_parent() as Actor
		if is_instance_valid(_pull_src) and owner_actor:
			var to := _pull_src.global_position - owner_actor.global_position
			if to.length() > 12.0:
				owner_actor.add_push(to.normalized() * _pull_speed)
		else:
			_pull_time = 0.0
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


# ------------------------------------------------------------------ 定身 / 余痒 / 易痒 / 拉扯
func apply_root(duration: float) -> void:
	_root_time = maxf(_root_time, duration)
	rooted.emit(duration)


## 延长当前定身（没被定身时相当于 apply_root）。
func extend_root(extra: float) -> void:
	apply_root(_root_time + extra)


func clear_root() -> void:
	_root_time = 0.0


func is_rooted() -> bool:
	return _root_time > 0.0


func root_time_left() -> float:
	return _root_time


func is_immobile() -> bool:
	return is_grabbed() or is_rooted()


func add_dot(tickle_per_sec: float, duration: float, source: Node = null) -> void:
	_dots.append({"rate": tickle_per_sec, "time": duration, "source": source, "tick": DOT_INTERVAL})


func has_dot() -> bool:
	return not _dots.is_empty()


func _tick_dots(delta: float) -> void:
	var owner_actor := get_parent()
	for d in _dots:
		d["time"] -= delta
		d["tick"] -= delta
		if d["tick"] <= 0.0:
			d["tick"] += DOT_INTERVAL
			var src: Node = d["source"] if is_instance_valid(d["source"]) else self
			if owner_actor and owner_actor.has_method("receive_hit"):
				owner_actor.receive_hit(HitData.make_tickle(src, d["rate"] * DOT_INTERVAL))
	_dots = _dots.filter(func(d: Dictionary): return d["time"] > 0.0)


func add_tickle_multiplier(k: float, duration: float) -> void:
	_mults.append({"k": k, "time": duration})


func tickle_multiplier() -> float:
	var best := 1.0
	for m in _mults:
		best = maxf(best, m["k"])
	return best


func add_pull(source: Node2D, speed: float, duration: float) -> void:
	_pull_src = source
	_pull_speed = speed
	_pull_time = duration


func is_pulled() -> bool:
	return _pull_time > 0.0


func clear() -> void:
	_slow_mult = 1.0
	_slow_time = 0.0
	_root_time = 0.0
	_dots.clear()
	_mults.clear()
	_pull_time = 0.0
	release(false)
