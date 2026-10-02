class_name CageTrap
extends Trap
## 落笼：地上先出现影子（预警 warn_time 秒），然后天花板落下痒痒笼子罩住那一格，困住 lock_time 秒（连按 presses 次挣脱）。
##   content = feather  笼里的羽毛自己挠
##   content = slime / tentacle  落下时笼里放出一只真的史莱姆 / 小触手（它们挠就算对应的怪物，笼子升起后留在场上；同时最多 max_spawn 只）
##   PERIODIC（默认，定时落）或 MANUAL（被压力板 / 绊线触发，加入 group_name 组）；aim = true 时影子跟着公主走，落在她身上。

const SHEET := preload("res://assets/generated/cage.png")
const ROWS := {"feather": 0, "slime": 1, "tentacle": 2}
const SPAWN := {"slime": "res://scenes/actors/monsters/slime.tscn", "tentacle": "res://scenes/actors/monsters/mini_tentacle.tscn"}
const CATCH_DIST := 10.0

@export var content := "feather"
@export var group_name := ""
@export var aim := false
@export var lock_time := 3.0
@export var presses := 8
@export var cage_tickle := 3.0
@export var cage_interval := 0.4
@export var max_spawn := 2

var drop_point := Vector2.ZERO
var victim: Actor
var _spawned: Array[Node] = []
var _tick := 0.0
var _cage: Sprite2D
var _shadow: Sprite2D


func _setup() -> void:
	hit_kind = HitData.Kind.TICKLE
	tickle = cage_tickle
	if group_name != "":
		add_to_group(group_name)
		trigger_mode = TriggerMode.MANUAL
	warn_time = 0.6
	active_time = 1.2
	cooldown_time = 1.0
	_shadow = Sprite2D.new()
	_shadow.texture = SHEET
	_shadow.region_enabled = true
	_shadow.region_rect = Rect2(48, 0, 16, 8)
	_shadow.top_level = true
	_shadow.visible = false
	_shadow.z_index = -1
	add_child(_shadow)
	_cage = Sprite2D.new()
	_cage.texture = SHEET
	_cage.region_enabled = true
	_cage.region_rect = Rect2(16 * int(ROWS.get(content, 0)), 0, 16, 24)
	_cage.offset = Vector2(0, -10)
	_cage.top_level = true
	_cage.visible = false
	_cage.z_index = 4
	add_child(_cage)
	drop_point = global_position


func _target_point() -> Vector2:
	var p := GameState.player
	return p.global_position if aim and is_instance_valid(p) and p.is_alive() else global_position


func _on_warn() -> void:
	drop_point = _target_point()
	_shadow.global_position = drop_point
	_shadow.visible = true
	_shadow.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(_shadow, "scale", Vector2.ONE, warn_time)


func _physics_process(delta: float) -> void:
	super(delta)
	if phase == Phase.WARN and aim:
		drop_point = _target_point()
		_shadow.global_position = drop_point
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		_release()
		return
	victim.global_position = drop_point
	active_time = maxf(active_time, _t + 0.5)
	if GameState.in_dialogue or content != "feather":
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = cage_interval
		if victim.receive_hit(make_hit()):
			Audio.play("tickle", -6.0, 0.12, 1.2)


func _on_activate() -> void:
	_shadow.visible = false
	_cage.visible = true
	_cage.global_position = drop_point + Vector2(0, -48)
	var tw := create_tween()
	tw.tween_property(_cage, "global_position", drop_point, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land)


func _land() -> void:
	Audio.play("gate", -2.0, 0.05, 1.3)
	Fx.burst(get_parent(), drop_point, "dust", 8, 40.0, 0.4)
	var p := GameState.player
	var under := is_instance_valid(p) and p.is_alive() and not p.is_airborne() and p.global_position.distance_to(drop_point) <= CATCH_DIST
	if under:
		p.receive_hit(make_hit())  # 落下砸中那一下（不论能不能关住，都算「落笼」来源）
	if under and p.can_be_grabbed() and p.status.grab(self, lock_time, presses):
		victim = p
		_tick = 0.2
		active_time = lock_time + 0.8
		if not GameState.has_flag("hint_cage"):
			GameState.set_flag("hint_cage")
			GameState.notify(ReactionDB.hint("cage"))
	if SPAWN.has(content):
		_spawned = _spawned.filter(func(m): return is_instance_valid(m) and m.is_alive())
		if _spawned.size() < max_spawn:
			var m: Monster = load(SPAWN[content]).instantiate()
			get_parent().add_child(m)
			m.global_position = drop_point + Vector2(randf_range(-3, 3), 2)
			m.target = GameState.player
			m.state = Monster.State.CHASE
			_spawned.append(m)


func _release() -> void:
	if is_instance_valid(victim) and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	_enter(Phase.COOLDOWN)


func _on_cooldown() -> void:
	if victim != null:
		_release()
		return
	_lift()


func _on_idle() -> void:
	if _cage and _cage.visible:
		_lift()


func _lift() -> void:
	var tw := create_tween()
	tw.tween_property(_cage, "global_position", drop_point + Vector2(0, -48), 0.25)
	tw.tween_callback(func(): _cage.visible = false)


func is_holding() -> bool:
	return victim != null and is_instance_valid(victim)


func spawned_monsters() -> Array:
	return _spawned.filter(func(m): return is_instance_valid(m))


func _apply_effect(_target: Node) -> bool:
	return false


func play_show(time: float) -> void:
	drop_point = global_position
	_on_activate()
	get_tree().create_timer(time).timeout.connect(func(): if is_instance_valid(self): _lift())
