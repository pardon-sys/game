class_name ResonanceMeter
extends RefCounted
## 双人共鸣（图腾柱的双人符文、骑士 Boss 的收尾都用）：两个人的闷笑比例同时停在 [lo, hi] 里才充能，不持有演员、台词或存档。
##   step(dt, a, b)：a / b 是两人的闷笑比例（0~1）。都在区间里 → charge 每秒 +rate；有人不在 → 每秒 −leak；
##   有人到了 crack 以上 → 返回 "crack"（调用方决定怎么罚，charge 不自动清）。
##   充满（charge ≥ 1）返回 "full"；其余 "charging" / "low"（有人太低）/ "high"（有人超过 hi 但没到 crack）。
##   burst(amount)：一次性充能（魔力释放的共鸣爆发）。
## 测试：直接改 charge、调 step。

const LO := 0.4
const HI := 0.75
const CRACK := 0.92
const LEAK := 0.04

var lo := LO
var hi := HI
var crack := CRACK
var rate := 0.1
var leak := LEAK
var charge := 0.0


func in_zone(r: float) -> bool:
	return r >= lo and r <= hi


func state(a: float, b: float) -> String:
	if a >= crack or b >= crack:
		return "crack"
	if in_zone(a) and in_zone(b):
		return "charging"
	return "high" if a > hi or b > hi else "low"


func step(dt: float, a: float, b: float) -> String:
	var s := state(a, b)
	match s:
		"crack":
			return s
		"charging":
			charge = minf(1.0, charge + rate * dt)
		_:
			charge = maxf(0.0, charge - leak * dt)
	return "full" if charge >= 1.0 else s


func burst(amount: float) -> void:
	charge = clampf(charge + amount, 0.0, 1.0)


func reset() -> void:
	charge = 0.0
