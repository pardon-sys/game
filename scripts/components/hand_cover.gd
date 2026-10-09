class_name HandCover
extends Node
## 身上盖着的手（可复用组件，节点名 "HandCover"，挂在可操作角色下；第八层夜迷宫的紫手用）：
##   每个部位最多 1 只手，大腿 / 屁股（WEAK）不限只数。
##   每只手每 TICK 秒挠一下它盖着的部位（HitData 指定部位 → 闷笑按部位敏感度、弱点倍率涨），来源键 source_key（组合技照常算）。
##   节奏：身上有手时每隔一阵子（手越多越频繁）一起「蓄力」CHARGE 秒，然后同时狠挠一下（每只手 ×RHYTHM_MULT、必定暴击，
##         来源键 rhythm_key）。蓄力期间冲刺、或者 safe_check 返回 true（站在月光灯 / 月光镜的光带里）就挠空了。
##   清除：clear()（月光灯）、shake_off(true)（冰晶结界满蓄力：震掉大腿 / 屁股以外的）、remove_one()（光带里慢慢散）。
## 信号：hands_changed(部位, 这个部位的只数, 总只数)、milestone(节点 id)、rhythm(状态 "charge" / "hit" / "miss")。
## 节点：first（第一只）、total_8 / total_12（总数超过 8 / 12 只）、weak_first（第一次盖到大腿 / 屁股）、weak_4（大腿屁股上超过 4 只）。

signal hands_changed(zone: String, count: int, total: int)
signal milestone(id: String)
signal rhythm(state: String)

const WEAK := ["thigh", "butt"]
const TICK := 0.6
## 每只手每次挠的量（再乘部位敏感度、弱点倍率等）：慢慢涨
const TICKLE := 0.55
const CHARGE := 1.2
const RHYTHM_MULT := 3.0

var hands := {}
var source_key := "maze_hand"
var rhythm_key := "hand_rhythm"
## 判断「这一下狠挠能不能躲掉」（站在光里等）：Callable(角色) -> bool
var safe_check: Callable
## 已经触发过的节点（不重复）；可以从存档的标记恢复
var reached := {}
var _t := 0.0
var _rhythm_cd := 12.0
var _charge := 0.0
var _src: Node2D
var _rhythm_src: Node2D
var _dodged := false


## 挠痒来源（带来源键的小节点，挂在角色下面，跟着走）。
class Source extends Node2D:
	var reaction_key := ""


func host() -> PlayableCharacter:
	return get_parent() as PlayableCharacter


static func of(c: Node) -> HandCover:
	return c.get_node_or_null("HandCover") as HandCover if c else null


static func attach(c: Node) -> HandCover:
	var h := of(c)
	if h:
		return h
	h = HandCover.new()
	h.name = "HandCover"
	c.add_child(h)
	return h


func _ready() -> void:
	_src = Source.new()
	_src.reaction_key = source_key
	host().add_child.call_deferred(_src)
	_rhythm_src = Source.new()
	_rhythm_src.reaction_key = rhythm_key
	host().add_child.call_deferred(_rhythm_src)


func count(zone: String) -> int:
	return int(hands.get(zone, 0))


func total() -> int:
	var n := 0
	for z in hands:
		n += int(hands[z])
	return n


func weak_total() -> int:
	return count("thigh") + count("butt")


## 还能盖手的部位（普通部位没有手的、大腿 / 屁股总是可以）。
func free_zones() -> Array:
	var out := []
	for z in TickleZones.zone_ids():
		if WEAK.has(z) or count(z) == 0:
			out.append(z)
	return out


## 在 zone 上盖一只手；普通部位已经有手就返回 false。
func add(zone: String) -> bool:
	if zone == "" or (not WEAK.has(zone) and count(zone) >= 1):
		return false
	var weak_before := weak_total()
	hands[zone] = count(zone) + 1
	hands_changed.emit(zone, count(zone), total())
	if total() == 1:
		_reach("first")
	if total() > 8:
		_reach("total_8")
	if total() > 12:
		_reach("total_12")
	if WEAK.has(zone) and weak_before == 0:
		_reach("weak_first")
	if weak_total() > 4:
		_reach("weak_4")
	return true


func _reach(id: String) -> void:
	if reached.has(id):
		return
	reached[id] = true
	milestone.emit(id)


## 选一个部位盖手：偏向大腿 / 屁股；prefer 有值时（被标记的部位）优先。
func pick_zone(prefer := "") -> String:
	var free := free_zones()
	if free.is_empty():
		return ""
	if prefer != "" and free.has(prefer):
		return prefer
	var weights := {}
	for z in free:
		weights[z] = 3.0 if WEAK.has(z) else 1.0
	var sum := 0.0
	for z in weights:
		sum += weights[z]
	var r := randf() * sum
	for z in weights:
		r -= weights[z]
		if r <= 0.0:
			return z
	return free[0]


func clear() -> void:
	if total() == 0:
		return
	hands.clear()
	# 正在蓄力时被清掉（走进月光灯）：这一下算躲开了
	if _charge > 0.0:
		_charge = 0.0
		rhythm.emit("miss")
	hands_changed.emit("", 0, 0)


## 冰晶结界满蓄力：震掉 keep_weak 以外的手（keep_weak = true：大腿 / 屁股上的留着）。返回震掉了几只。
func shake_off(keep_weak := true) -> int:
	var n := 0
	for z in hands.keys():
		if keep_weak and WEAK.has(z):
			continue
		n += count(z)
		hands.erase(z)
	if n > 0:
		hands_changed.emit("", 0, total())
	return n


## 散掉一只（光带里慢慢散）：先散普通部位的，再散大腿 / 屁股的。
func remove_one() -> String:
	var order: Array = hands.keys().filter(func(z): return not WEAK.has(z)) + hands.keys().filter(func(z): return WEAK.has(z))
	for z in order:
		if count(z) > 0:
			hands[z] = count(z) - 1
			if count(z) == 0:
				hands.erase(z)
			hands_changed.emit(z, count(z), total())
			return z
	return ""


func is_charging() -> bool:
	return _charge > 0.0


## 节奏提前：马上开始蓄力（组合「熄灯偷袭」）。
func rhythm_now() -> void:
	if total() > 0 and _charge <= 0.0:
		_rhythm_cd = 0.0


## 紧接着再来一次狠挠（组合「节奏连击」）。
func rhythm_again() -> void:
	_rhythm_cd = minf(_rhythm_cd, 0.3)


func _process(delta: float) -> void:
	var c := host()
	if c == null or not c.is_alive() or GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing():
		return
	if total() == 0:
		_rhythm_cd = maxf(_rhythm_cd, 6.0)
		return
	_t += delta
	if _t >= TICK:
		_t -= TICK
		for z in hands.keys():
			var h := HitData.make_tickle(_src, TICKLE * count(z))
			h.zone = z
			c.receive_hit(h)
	_update_rhythm(c, delta)


func _update_rhythm(c: PlayableCharacter, delta: float) -> void:
	if _charge > 0.0:
		_charge -= delta
		if c.state == PlayableCharacter.State.DASH or (safe_check.is_valid() and safe_check.call(c)):
			_dodged = true
		if _charge <= 0.0:
			if _dodged:
				rhythm.emit("miss")
			else:
				for z in hands.keys():
					var h := HitData.make_tickle(_rhythm_src, TICKLE * count(z) * RHYTHM_MULT * 4.0)
					h.zone = z
					h.special = true
					c.receive_hit(h)
				c.shake(0.35)
				rhythm.emit("hit")
			_rhythm_cd = maxf(5.0, 16.0 - total() * 0.8)
		return
	_rhythm_cd -= delta
	if _rhythm_cd <= 0.0:
		_charge = CHARGE
		_dodged = false
		rhythm.emit("charge")
