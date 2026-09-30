class_name LaughMeter
extends Node
## 闷笑值组件（异常状态，0 ~ max_value）。挂在 Actor 下，节点名 "Laugh"；有它的角色才能被挠痒。
##   超过 giggle_threshold（50）  → GIGGLING：行动变慢，时不时发出笑声
##   超过 helpless_threshold（80）→ HELPLESS 失控状态 1：无法行动，持续大笑；连打按键挣扎可降低
##   超过 helpless_stage2_threshold（100）→ 失控状态 2（表现不同，行动限制相同）
##   达到 max_value（150）        → overflow：笑到脱力（角色扣血），数值回落到 overflow_reset_to（100）
## 受到攻击或挠痒后 decay_delay 秒内不下降，之后每秒下降 decay_rate。

signal changed(value: float, max_value: float)
signal level_changed(level: Level)
signal overflow

enum Level { CALM, GIGGLING, HELPLESS }

@export var max_value := 150.0
@export var giggle_threshold := 50.0
@export var helpless_threshold := 80.0
## Presentation only: both helpless poses retain the same action restrictions.
@export var helpless_stage2_threshold := 100.0
@export var decay_delay := 2.0
@export var decay_rate := 10.0
@export var struggle_amount := 3.0
@export var overflow_reset_to := 100.0
@export_range(0.0, 1.0) var giggle_speed_multiplier := 0.5

var value := 0.0
var level := Level.CALM
var _since_attacked := INF


func _process(delta: float) -> void:
	_since_attacked += delta
	if value > 0.0 and _since_attacked >= decay_delay:
		_set_value(value - decay_rate * delta)


## 被挠痒：累积闷笑值。
func add(amount: float) -> void:
	notify_attacked()
	_set_value(value + amount)
	if value >= max_value:
		overflow.emit()
		_set_value(overflow_reset_to)


func reduce(amount: float) -> void:
	_set_value(value - amount)


## 笑瘫时连打按键挣扎。
func struggle() -> void:
	reduce(struggle_amount)


## 受到任何敌方攻击时调用：重置"无攻击"计时，暂停衰减。
func notify_attacked() -> void:
	_since_attacked = 0.0


func clear() -> void:
	_since_attacked = INF
	_set_value(0.0)


func set_value(v: float) -> void:
	_set_value(v)


func is_giggling() -> bool:
	return level >= Level.GIGGLING


func is_helpless() -> bool:
	return level == Level.HELPLESS


## 当前闷笑等级对应的移动速度倍率。
func speed_multiplier() -> float:
	match level:
		Level.GIGGLING: return giggle_speed_multiplier
		Level.HELPLESS: return 0.0
	return 1.0


func ratio() -> float:
	return value / max_value


func level_for(v: float) -> Level:
	if v > helpless_threshold:
		return Level.HELPLESS
	if v > giggle_threshold:
		return Level.GIGGLING
	return Level.CALM


func _set_value(v: float) -> void:
	v = clampf(v, 0.0, max_value)
	if is_equal_approx(v, value):
		return
	value = v
	changed.emit(value, max_value)
	var l := level_for(value)
	if l != level:
		level = l
		level_changed.emit(level)
