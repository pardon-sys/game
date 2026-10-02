class_name RestraintTrap
extends Trap
## 束缚陷阱基类（ON_STEP）。踩上去被困住，困住期间给公主加「露出部位」（Sensitivity.expose，通用状态 exposed），
## 挠到露出的部位 × 倍率；同组（group_name）的配套挠痒陷阱（逗弄器、转轮、喷口）在有人被困时发动。
##   mode = "grab"    抓住：不能动，连按 presses 次挣脱或 lock_time 秒后松开（倒吊绳套、举手铐柱、夹腿枷台、衣柜、吊环、泥沼）
##   mode = "hobble"  绊住：还能慢慢走（×hobble_speed）、不能冲刺，攻击 / 交互键挣扎（长靴、绑腿）
## 子类改导出参数、重写 _on_restrain(victim) / _on_free(victim) / _hold_point() 做表现；
## 需要自己挠痒时设 self_tickle / self_interval（挠痒来源是陷阱自己，部位按 tickle_zones.json）。

signal restrained(victim: Actor)
signal freed(victim: Actor)

@export var mode := "grab"
@export var lock_time := 3.0
@export var presses := 8
@export var hobble_speed := 0.5
## 露出的部位 {部位 id: 倍率}（图例可写 exposed=sole:1.5,thigh:1.3）。
@export var exposed := {"sole": 1.5}
## 困住期间自己挠痒（0 = 不挠）。
@export var self_tickle := 0.0
@export var self_interval := 0.5
## 配套挠痒陷阱的组名（逗弄器 / 转轮 / 喷口写同样的 group）。
@export var group_name := ""
## 被困时小人的姿势（精灵偏移、旋转）。
@export var pose_offset := Vector2.ZERO
@export var pose_rotation := 0.0
## 松开后多久内同一个人不会再被困（给她走开的时间）。
@export var regrab_delay := 1.5

var victim: Actor
var _tick_t := 0.0
var _immune := {}

@onready var sprite: Sprite2D = get_node_or_null("Sprite")


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	trigger_mode = TriggerMode.ON_STEP
	warn_time = 0.0
	active_time = 0.3
	stops_slide = true
	if group_name != "":
		add_to_group(group_name)
	add_to_group("restraint")
	_restraint_setup()


## 子类钩子：额外设置。
func _restraint_setup() -> void:
	pass


func _physics_process(delta: float) -> void:
	super(delta)
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not _still_held():
		_free()
		return
	if mode == "grab":
		victim.global_position = _hold_point()
	# 困着的时候 ACTIVE 阶段不能先结束
	active_time = maxf(active_time, _t + 0.5)
	if GameState.in_dialogue:
		return
	if self_tickle > 0.0:
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = self_interval
			if victim.receive_hit(make_hit()):
				Audio.play("tickle", -6.0, 0.12, tickle_pitch)
	_while_held(delta)


func _still_held() -> bool:
	if mode == "grab":
		return victim.status.is_grabbed_by(self)
	return victim.status.is_hobbled_by(self)


func make_hit() -> HitData:
	return HitData.make_tickle(self, self_tickle)


## 困住时公主被摆在哪（世界坐标）。
func _hold_point() -> Vector2:
	return global_position + Vector2(0, 4)


func _apply_effect(target: Node) -> bool:
	var a := target as Actor
	if victim != null or a == null or a.status == null or not a.is_alive():
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_immune.get(a.get_instance_id(), -INF)):
		return false
	var ok := false
	if mode == "grab":
		ok = a.can_be_grabbed() and a.status.grab(self, lock_time, presses)
	else:
		ok = not a.is_fully_invulnerable() and a.status.hobble(self, lock_time, presses, hobble_speed)
	if not ok:
		return false
	victim = a
	_tick_t = 0.25
	active_time = lock_time + 1.0
	if a is PlayableCharacter:
		var pc := a as PlayableCharacter
		pc.sensitivity.expose(self, exposed, pc)
		pc.pose_offset = pose_offset
		pc.pose_rotation = pose_rotation
	if sprite and sprite.hframes > 1:
		sprite.frame = 1
	_on_restrain(a)
	restrained.emit(a)
	if not GameState.has_flag("hint_restraint"):
		GameState.set_flag("hint_restraint")
		GameState.notify(ReactionDB.hint("restraint"))
	return true


func is_holding() -> bool:
	return victim != null and is_instance_valid(victim)


func _free() -> void:
	var a := victim
	victim = null
	if is_instance_valid(a):
		if mode == "grab" and a.status.is_grabbed_by(self):
			a.status.release(false)
		elif mode == "hobble" and a.status.is_hobbled_by(self):
			a.status.release_hobble(false)
		if a is PlayableCharacter:
			var pc := a as PlayableCharacter
			pc.sensitivity.unexpose(self, pc)
			pc.pose_offset = Vector2.ZERO
			pc.pose_rotation = 0.0
		_immune[a.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + regrab_delay
		_on_free(a)
		freed.emit(a)
	if sprite and sprite.hframes > 1:
		sprite.frame = 0
	if trigger_mode == TriggerMode.CONTINUOUS:
		_enter(Phase.ACTIVE)
	else:
		_enter(Phase.COOLDOWN if cooldown_time > 0.0 else Phase.IDLE)


func _on_cooldown() -> void:
	if victim != null:
		_free()


## 拖着一根绳子到公主身上（倒吊绳套、吊环用）。
func _rope_to(target: Vector2, from_offset := Vector2(0, -40)) -> void:
	var rope := get_node_or_null("Rope") as Line2D
	if rope == null:
		rope = Line2D.new()
		rope.name = "Rope"
		rope.width = 1.0
		rope.default_color = Color(0.85, 0.7, 0.5)
		rope.z_index = 3
		add_child(rope)
	rope.points = PackedVector2Array([from_offset, to_local(target)])
	rope.visible = true


func _hide_rope() -> void:
	var rope := get_node_or_null("Rope") as Line2D
	if rope:
		rope.visible = false


# ------------------------------------------------------------------ 子类钩子
func _on_restrain(_a: Actor) -> void:
	Audio.play("stocks", -3.0, 0.08)


func _on_free(_a: Actor) -> void:
	pass


func _while_held(_delta: float) -> void:
	pass


## 过场里演一次（只有表现）：合上一会儿再打开。
func play_show(time: float) -> void:
	if sprite and sprite.hframes > 1:
		sprite.frame = 1
		get_tree().create_timer(time).timeout.connect(func(): if is_instance_valid(sprite): sprite.frame = 0)
