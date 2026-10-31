class_name KnightTickle
extends RefCounted
## 骑士 Boss（广场 + 笑雾之中）的挠痒统一走普通战斗的流程：组 HitData 交给 Actor.receive_hit——
##   部位敏感、装备挡、魔力疲倦的闷笑加成都算，疲倦按实际涨的闷笑涨（MagicFatigue.from_tickle：普通 ×0.5、暴击 ×2.0，再乘 fatigue_mult），
##   有命中特效；暴击（BOSS_CRIT，和别的 Boss 一样；或者 forced_specials）闷笑 ×SPECIAL_MULT、金色「暴击！」。
##   hit(角色, 比例, 来源, 部位, …)：打中一下（比例 × 闷笑上限）；
##   over(角色, 每秒比例, delta, 来源, 标签, 部位, …)：持续的（被抓、毒气、沙尘、诅咒、黑雾）——按 TICK 秒攒成一跳结算，不每帧放特效。
##   cap：闷笑最多涨到上限的这个比例（黑雾 0.95、黑气小手 0.985）；fatigue_mult：疲倦另外的倍数（粉色公主被盔甲抱住：闷笑慢、疲倦快）。
## 故意笑（KnightLaugh、AI 陪笑）不算被挠，不走这里。测试：BOSS_CRIT、TICK、hit()、over()、reset()。

const BOSS_CRIT := 0.2
const SPECIAL_MULT := 2.0
const TICK := 0.5

## 持续挠痒的累加：{"角色 id|标签": [累计秒, 累计比例]}
static var _acc := {}
## 测试里关掉随机暴击
static var no_crit := false


static func hit(c: PlayableCharacter, ratio: float, src: Node, zone := "", crit := BOSS_CRIT, cap := 1.0, fatigue_mult := 1.0) -> bool:
	if not is_instance_valid(c) or c.laugh == null or ratio <= 0.0:
		return false
	if c.laugh.value >= c.laugh.max_value * cap:
		return false
	var special := c.forced_specials > 0 or (not no_crit and randf() < crit)
	if c.forced_specials > 0:
		c.forced_specials -= 1
	var h := HitData.make_tickle(src, c.laugh.max_value * ratio * (SPECIAL_MULT if special else 1.0))
	h.special = special
	h.zone = zone
	h.fatigue_mult = fatigue_mult
	var before := c.laugh.value
	var ok := c.receive_hit(h)
	if ok and cap < 1.0 and c.laugh.value > c.laugh.max_value * cap:
		c.laugh.set_value(maxf(before, c.laugh.max_value * cap))
	if ok and special:
		Monster.special_feedback(c)
	return ok


static func over(c: PlayableCharacter, rate: float, delta: float, src: Node, tag: String, zone := "", cap := 1.0, fatigue_mult := 1.0) -> bool:
	if not is_instance_valid(c):
		return false
	var key := "%d|%s" % [c.get_instance_id(), tag]
	var a: Array = _acc.get(key, [0.0, 0.0])
	a[0] = float(a[0]) + delta
	a[1] = float(a[1]) + rate * delta
	if float(a[0]) < TICK - 0.001:
		_acc[key] = a
		return false
	_acc.erase(key)
	return hit(c, float(a[1]), src, zone, BOSS_CRIT, cap, fatigue_mult)


static func reset() -> void:
	_acc.clear()
