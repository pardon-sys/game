class_name MagicFatigue
extends Node
## 魔力疲倦（公主的第二种异常值，节点名 "Fatigue"）：0 ~ max_value（500）。
##   积累：被挠痒时 += 实际挠痒量 × normal_rate（0.5）；暴击时 × special_rate（2）；再乘挠痒来源的 fatigue_mult（魔力水母 3）
##   不随时间下降、复活不清零、跨层保存（只有重新开始游戏清零）
##   laugh_bonus()：按 curve（疲倦比例 → 闷笑积累加成）线性插值，先缓后升：40% +5%、60% +10%、80% +30%、100% +50%
##   满值发出 full（公主据此触发疲倦爆发，见 PlayableCharacter.fatigue_burst）
##   阶段、加量都按上限的百分比算（add_percent），以后提高上限只改 max_value。

signal changed(value: float, max_value: float)
signal full

## 被挠痒时是否积累疲倦（只给需要精确闷笑数值的旧测试关掉）。
static var accumulate := true

@export var max_value := 500.0
@export var normal_rate := 0.5
@export var special_rate := 2.0
## (疲倦比例, 闷笑积累加成)
@export var curve := PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0.01), Vector2(0.4, 0.05),
	Vector2(0.6, 0.10), Vector2(0.8, 0.30), Vector2(1.0, 0.50)])
## 超过这个比例时公主提醒「快满了」，HUD 疲倦条闪烁。
@export_range(0.0, 1.0) var warn_ratio := 0.9

var value := 0.0


func add(amount: float) -> void:
	if amount <= 0.0 or value >= max_value:
		return
	value = minf(value + amount, max_value)
	changed.emit(value, max_value)
	if value >= max_value:
		full.emit()


## 按上限的百分比增加（4 = +4%）。
func add_percent(p: float) -> void:
	add(p / 100.0 * max_value)


func ratio() -> float:
	return value / max_value


func percent() -> float:
	return ratio() * 100.0


func is_near_full() -> bool:
	return ratio() >= warn_ratio


## 一次挠痒带来的疲倦。
func amount_for(hit: HitData) -> float:
	return hit.tickle * (special_rate if hit.special else normal_rate) * hit.fatigue_mult


func from_tickle(hit: HitData) -> void:
	if accumulate:
		add(amount_for(hit))


func set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	changed.emit(value, max_value)


func clear() -> void:
	set_value(0.0)


## 疲倦值对应的闷笑积累加成（0.05 = +5%）。at 为疲倦值（不是比例），缺省为当前值。
func laugh_bonus(at := -1.0) -> float:
	var v := (value if at < 0.0 else at) / max_value
	for i in range(1, curve.size()):
		if v <= curve[i].x:
			var a := curve[i - 1]
			var b := curve[i]
			return lerpf(a.y, b.y, (v - a.x) / maxf(b.x - a.x, 0.001))
	return curve[curve.size() - 1].y


## 下一档加成（状态页用）：[比例, 加成]，已到最高档返回空数组。
func next_tier() -> Array:
	var r := ratio()
	for pt in curve:
		if pt.x > r + 0.0001:
			return [pt.x, pt.y]
	return []
