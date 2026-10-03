class_name LegTrap
extends RestraintTrap
## 脚 / 大腿内侧 / 屁股的束缚陷阱共用基类（训练营的新陷阱：夹腿羽毛钳、足腿刑架、羽毛秋千、大腿刷环、泡泡足浴盆、
## 泡泡坐浴、弹簧刷座、骑马刷凳、剪刀刷台）。在 RestraintTrap（困住、露出部位、自己挠、多一格拉人）之上加：
##   zone_cycle + cycle_time     轮流挠几个部位（每段一个 {部位: 权重}，cycle_time 秒换一次）
##   struggle_speedup            每挣扎一下，挠的间隔和换部位都快一截（越挣扎越痒）
##   struggle_extend             每挣扎一下多困这么多秒（越挣扎越难挣脱）
##   ramp                        困住期间挠得越来越快（每秒把间隔缩短这个比例）
##   rhythm_on / rhythm_off      按节奏开合：张开 rhythm_on 秒能抓人，合上 rhythm_off 秒不抓（钳子、剪刀台）
##   swing / lift / bob          困住时小人的姿势：左右摆的幅度（弧度）、抬高的像素、上下弹的像素
##   bubbles                     困住时冒泡泡（足浴盆、坐浴）
## 精灵帧：0 = 平时，1 = 困住；有节奏的陷阱 2 = 合上（不抓人的那半拍）。
## lock_zone(部位)：训练营用，只挠这个部位（不再轮流）。

@export var zone_cycle: Array[Dictionary] = []
@export var cycle_time := 0.0
@export var struggle_speedup := 0.0
@export var struggle_extend := 0.0
@export var ramp := 0.0
@export var min_interval := 0.15
@export var rhythm_on := 0.0
@export var rhythm_off := 0.0
@export var swing := 0.0
@export var lift := 0.0
@export var bob := 0.0
@export var bubbles := false

var struggles := 0
var _zone_i := 0
var _cycle_t := 0.0
var _cycle_len := 0.0
var _last_presses := -1
var _rhythm_t := 0.0
var _base_interval := 0.5
var _hold_t := 0.0
var _bubble_fx: CPUParticles2D
var _locked_zone := ""


func _restraint_setup() -> void:
	_base_interval = self_interval
	if not zone_cycle.is_empty():
		tickle_zones = zone_cycle[0].duplicate()
	if bubbles:
		_bubble_fx = Fx.emitter(self, "drop", 10, 0.7, {"offset": Vector2(0, -2), "extents": Vector2(6, 2), "dir": Vector2.UP,
			"speed": [12.0, 26.0], "color": Color(0.75, 0.9, 1.0, 0.9), "z": 3})
		_bubble_fx.emitting = false


## 训练营：只挠这个部位。
func lock_zone(zone: String) -> void:
	_locked_zone = zone
	tickle_zones = {zone: 1.0}
	exposed = {zone: float(exposed.values().max()) if not exposed.is_empty() else 1.4}


## 现在挠的是哪个部位（权重最大的那个）。
func current_zone() -> String:
	var best := ""
	var w := -1.0
	for z in tickle_zones:
		if float(tickle_zones[z]) > w:
			w = float(tickle_zones[z])
			best = str(z)
	return best


## 有节奏的陷阱：现在是不是张开（能抓人）的那半拍。
func is_armed() -> bool:
	if rhythm_on <= 0.0 or victim != null:
		return true
	return fmod(_rhythm_t, rhythm_on + rhythm_off) < rhythm_on


func _victims() -> Array:
	return super() if is_armed() else []


func _physics_process(delta: float) -> void:
	super(delta)
	if rhythm_on > 0.0 and victim == null and not GameState.in_dialogue:
		_rhythm_t += delta
		if sprite and sprite.hframes > 2:
			sprite.frame_coords.x = 0 if is_armed() else 2


func _on_restrain(a: Actor) -> void:
	struggles = 0
	_hold_t = 0.0
	_cycle_t = 0.0
	_zone_i = 0
	_cycle_len = cycle_time
	self_interval = _base_interval
	_last_presses = a.status.presses_left() if a.status and mode == "grab" else -1
	if _bubble_fx:
		_bubble_fx.emitting = true
	Audio.play("stocks", -3.0, 0.08, 1.1)


func _on_free(_a: Actor) -> void:
	self_interval = _base_interval
	if not zone_cycle.is_empty() and _locked_zone == "":
		tickle_zones = zone_cycle[0].duplicate()
	if _bubble_fx:
		_bubble_fx.emitting = false


func _while_held(delta: float) -> void:
	_hold_t += delta
	# 挣扎：按次数加快 / 延长
	if _last_presses >= 0 and victim.status:
		var pl := victim.status.presses_left()
		if pl < _last_presses:
			var n := _last_presses - pl
			struggles += n
			if struggle_speedup > 0.0:
				self_interval = maxf(min_interval, self_interval * pow(1.0 - struggle_speedup, n))
				_cycle_len = maxf(0.15, _cycle_len * pow(1.0 - struggle_speedup, n))
			if struggle_extend > 0.0:
				victim.status.extend_grab(struggle_extend * n)
		_last_presses = victim.status.presses_left()
	if ramp > 0.0:
		self_interval = maxf(min_interval, self_interval * (1.0 - ramp * delta))
	# 轮流挠不同部位
	if _locked_zone == "" and zone_cycle.size() > 1 and _cycle_len > 0.0:
		_cycle_t += delta
		if _cycle_t >= _cycle_len:
			_cycle_t = 0.0
			_zone_i = (_zone_i + 1) % zone_cycle.size()
			tickle_zones = zone_cycle[_zone_i].duplicate()
			Audio.play("swish", -10.0, 0.1, 1.3)
	# 姿势
	if victim is PlayableCharacter:
		var pc := victim as PlayableCharacter
		var amp := swing * (1.0 + 0.12 * struggles)
		if amp > 0.0:
			pc.pose_rotation = sin(_hold_t * (5.0 + struggles * 0.4)) * amp
		if lift > 0.0 or bob > 0.0:
			pc.pose_offset = pose_offset + Vector2(0, -lift + roundf(sin(_hold_t * 14.0) * bob))
