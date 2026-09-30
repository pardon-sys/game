class_name Trap
extends Area2D
## 陷阱基类（中立危险物，实现 Switchable 接口 set_active）。
## 阶段循环：IDLE → WARN（预警）→ ACTIVE（生效）→ COOLDOWN → IDLE
## 触发方式：
##   PERIODIC  IDLE 持续 idle_time 后自动触发（尖刺）
##   ON_STEP   有目标踩上时触发（羽毛陷阱）
##   MANUAL    只能由代码 / 机关调用 trigger()（压力板等 Triggerable 来源）
##   CONTINUOUS 一直处于 ACTIVE（旋转刷等）
## 效果：ACTIVE 期间对区域内受影响阵营的 Damageable 调用 receive_hit(HitData)（攻击或挠痒）。
##
## 子类重写表现钩子：_on_idle / _on_warn / _on_activate / _on_cooldown / _on_switched(on)
## 需要特殊效果时重写 _apply_effect(target) -> bool。

signal triggered
signal phase_changed(phase: Phase)

enum TriggerMode { PERIODIC, ON_STEP, MANUAL, CONTINUOUS }
enum Phase { IDLE, WARN, ACTIVE, COOLDOWN }

@export var trigger_mode := TriggerMode.PERIODIC
## 是否启用（Switchable）。
@export var active := true
## 拉杆通电时是"关闭"陷阱（true）还是"开启"陷阱（false）。
@export var switch_disables := true
@export_group("效果")
@export var hit_kind := HitData.Kind.ATTACK
@export var damage := 1
@export var tickle := 0.0
@export var knockback := 0.0
@export var affects_player := true
@export var affects_allies := true
@export var affects_enemies := false
## 同一目标在一次 ACTIVE 中再次生效的最短间隔（0 = 每帧都尝试，受目标无敌时间限制）。
@export var repeat_interval := 0.0
## 在 data/princess_reactions.json 的 sources 里对应的键。
@export var reaction_key := ""
## 挠痒果冻音效音高。
@export var tickle_pitch := 1.1
@export_group("时间")
@export var idle_time := 1.4
@export var warn_time := 0.35
@export var active_time := 1.0
@export var cooldown_time := 0.0
## 初始进入周期的偏移（让一排陷阱错开）。
@export var phase_offset := 0.0

var phase := Phase.IDLE
var _t := 0.0
var _last_hit := {}


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	_setup()
	_enter(Phase.ACTIVE if trigger_mode == TriggerMode.CONTINUOUS else Phase.IDLE)
	_t = phase_offset


func _physics_process(delta: float) -> void:
	if not active or GameState.in_dialogue:
		return
	_t += delta
	match phase:
		Phase.IDLE:
			if trigger_mode == TriggerMode.PERIODIC and _t >= idle_time:
				_enter(Phase.WARN)
			elif trigger_mode == TriggerMode.ON_STEP and not _victims().is_empty():
				trigger()
		Phase.WARN:
			if _t >= warn_time:
				_enter(Phase.ACTIVE)
		Phase.ACTIVE:
			_apply_to_overlapping()
			if trigger_mode == TriggerMode.CONTINUOUS:
				_last_hit_cleanup()
			elif _t >= active_time:
				_enter(Phase.COOLDOWN if cooldown_time > 0.0 else Phase.IDLE)
		Phase.COOLDOWN:
			if _t >= cooldown_time:
				_enter(Phase.IDLE)


## 手动触发（机关、脚本）。
func trigger() -> void:
	if active and phase == Phase.IDLE:
		triggered.emit()
		_enter(Phase.WARN if warn_time > 0.0 else Phase.ACTIVE)


## Switchable：拉杆等机关调用。on = 机关"通电"。
func set_active(on: bool) -> void:
	active = not on if switch_disables else on
	if not active:
		_enter(Phase.IDLE)
	elif trigger_mode == TriggerMode.CONTINUOUS:
		_enter(Phase.ACTIVE)
	_on_switched(active)


func is_dangerous() -> bool:
	return active and phase == Phase.ACTIVE


# ------------------------------------------------------------------ 效果
func _victims() -> Array:
	var out := []
	for body in get_overlapping_bodies():
		if _affects(body) and Contracts.is_damageable(body):
			out.append(body)
	return out


func _affects(body: Node) -> bool:
	match Faction.of(body):
		Faction.Type.PLAYER: return affects_player
		Faction.Type.ALLY: return affects_allies
		Faction.Type.ENEMY: return affects_enemies
	return false


func _apply_to_overlapping() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for body in _victims():
		if repeat_interval > 0.0 and now - float(_last_hit.get(body.get_instance_id(), -INF)) < repeat_interval:
			continue
		if _apply_effect(body):
			_last_hit[body.get_instance_id()] = now


func make_hit() -> HitData:
	var h := HitData.make_tickle(self, tickle, knockback) if hit_kind == HitData.Kind.TICKLE else HitData.make_attack(self, damage, knockback)
	return h


## 对单个目标生效。默认调用 receive_hit。
func _apply_effect(target: Node) -> bool:
	var ok: bool = target.receive_hit(make_hit())
	if ok and hit_kind == HitData.Kind.TICKLE:
		Audio.play("tickle", -5.0, 0.12, tickle_pitch)
	return ok


## CONTINUOUS 模式下 _last_hit 不会随阶段清空，这里清掉早已过期的记录。
func _last_hit_cleanup() -> void:
	if _last_hit.size() > 32:
		_last_hit.clear()


func _enter(p: Phase) -> void:
	phase = p
	_t = 0.0
	if p == Phase.ACTIVE:
		_last_hit.clear()
	match p:
		Phase.IDLE: _on_idle()
		Phase.WARN: _on_warn()
		Phase.ACTIVE: _on_activate()
		Phase.COOLDOWN: _on_cooldown()
	phase_changed.emit(p)


# ------------------------------------------------------------------ 钩子
func _setup() -> void:
	pass


func _on_idle() -> void:
	pass


func _on_warn() -> void:
	pass


func _on_activate() -> void:
	pass


func _on_cooldown() -> void:
	pass


func _on_switched(_on: bool) -> void:
	pass
