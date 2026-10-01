class_name LaughMeter
extends Node
## 闷笑值组件（异常状态，0 ~ max_value）。挂在 Actor 下，节点名 "Laugh"；有它的角色才能被挠痒。
## 阶段和恢复量都按 max_value 的百分比算（以后提高上限只改 max_value）：
##   超过 giggle_ratio（35%）  → GIGGLING：行动变慢，时不时发出笑声
##   超过 helpless_ratio（55%）→ HELPLESS 失控状态 1：无法行动，持续大笑；连打按键挣扎可降低
##   超过 stage2_ratio（70%）  → 失控状态 2（表现不同，行动限制相同）
##   达到 100%                  → overflow：笑到脱力（角色扣血），数值回落到 overflow_reset_ratio（70%）
## 受到攻击或挠痒后 decay_delay 秒内不下降，之后每秒下降 decay_ratio（6.7%）。挣扎一次 -struggle_ratio（2%）。
## giggle_threshold / helpless_threshold / helpless_stage2_threshold / overflow_reset_to 是按比例算出的只读值。

signal changed(value: float, max_value: float)
signal level_changed(level: Level)
signal overflow

enum Level { CALM, GIGGLING, HELPLESS }

const STAGE_NAMES := {"calm": "平静", "giggle": "憋笑", "helpless_1": "失控 1", "helpless_2": "失控 2"}
const STAGE_DESC := {
	"calm": "还能忍住。",
	"giggle": "憋着笑：移动速度减半，时不时笑出声。",
	"helpless_1": "笑到失控：不能行动，连按攻击 / 交互键挣扎。",
	"helpless_2": "笑得停不下来：不能行动，连按攻击 / 交互键挣扎。满了会笑到脱力、扣半颗心。",
}

@export var max_value := 150.0
@export_range(0.0, 1.0) var giggle_ratio := 0.35
@export_range(0.0, 1.0) var helpless_ratio := 0.55
## Presentation only: both helpless poses retain the same action restrictions.
@export_range(0.0, 1.0) var stage2_ratio := 0.70
@export_range(0.0, 1.0) var overflow_reset_ratio := 0.70
@export var decay_delay := 2.0
## 每秒自然下降的比例（10 / 150）。
@export var decay_ratio := 0.0667
## 挣扎一次下降的比例（3 / 150）。
@export var struggle_ratio := 0.02
@export_range(0.0, 1.0) var giggle_speed_multiplier := 0.5

var giggle_threshold: float:
	get: return max_value * giggle_ratio
var helpless_threshold: float:
	get: return max_value * helpless_ratio
var helpless_stage2_threshold: float:
	get: return max_value * stage2_ratio
var overflow_reset_to: float:
	get: return max_value * overflow_reset_ratio

var value := 0.0
var level := Level.CALM
var _since_attacked := INF


func _process(delta: float) -> void:
	_since_attacked += delta
	if value > 0.0 and _since_attacked >= decay_delay:
		_set_value(value - decay_ratio * max_value * delta)


## 被挠痒：累积闷笑值。
func add(amount: float) -> void:
	notify_attacked()
	_set_value(value + amount)
	if value >= max_value:
		overflow.emit()
		_set_value(overflow_reset_to)


func reduce(amount: float) -> void:
	_set_value(value - amount)


## 按上限的比例降低（薄荷糖、骑士帮忙）。
func reduce_ratio(ratio: float) -> void:
	reduce(ratio * max_value)


## 笑瘫时连打按键挣扎。
func struggle() -> void:
	reduce_ratio(struggle_ratio)


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


## 百分比（0 ~ 100）。
func percent() -> float:
	return ratio() * 100.0


## 当前阶段键：calm / giggle / helpless_1 / helpless_2。
func stage() -> String:
	if value > helpless_stage2_threshold:
		return "helpless_2"
	if value > helpless_threshold:
		return "helpless_1"
	if value > giggle_threshold:
		return "giggle"
	return "calm"


func stage_name() -> String:
	return STAGE_NAMES[stage()]


func stage_desc() -> String:
	return STAGE_DESC[stage()]


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
