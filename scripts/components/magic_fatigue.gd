class_name MagicFatigue
extends Node
## 魔力疲倦（公主的第二种异常值，节点名 "Fatigue"）：0 ~ max_value（500）。
##   积累：被挠痒时 += 实际挠痒量 × normal_rate（0.5）；暴击时 × special_rate（2）；再乘挠痒来源的 fatigue_mult（魔力水母 3）
##   不随时间下降、复活不清零、跨层保存（只有重新开始游戏清零）
##   laugh_bonus()：按 curve（疲倦值 → 闷笑积累加成）线性插值，先缓后升：200 +5%、300 +10%、400 +30%、500 +50%
##   满值发出 burst（公主据此触发疲倦爆发，见 PlayableCharacter.fatigue_burst）

signal changed(value: float, max_value: float)
signal full

## 被挠痒时是否积累疲倦（只给需要精确闷笑数值的旧测试关掉）。
static var accumulate := true

@export var max_value := 500.0
@export var normal_rate := 0.5
@export var special_rate := 2.0
## (疲倦值, 闷笑积累加成)
@export var curve := PackedVector2Array([Vector2(0, 0), Vector2(100, 0.01), Vector2(200, 0.05),
	Vector2(300, 0.10), Vector2(400, 0.30), Vector2(500, 0.50)])

var value := 0.0


func add(amount: float) -> void:
	if amount <= 0.0 or value >= max_value:
		return
	value = minf(value + amount, max_value)
	changed.emit(value, max_value)
	if value >= max_value:
		full.emit()


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


## 当前疲倦值对应的闷笑积累加成（0.05 = +5%）。
func laugh_bonus(at := -1.0) -> float:
	var v := value if at < 0.0 else at
	for i in range(1, curve.size()):
		if v <= curve[i].x:
			var a := curve[i - 1]
			var b := curve[i]
			return lerpf(a.y, b.y, (v - a.x) / maxf(b.x - a.x, 0.001))
	return curve[curve.size() - 1].y
