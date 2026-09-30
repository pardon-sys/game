class_name Actor
extends CharacterBody2D
## 角色基类：可操作角色、怪物、友军都继承它。
##
## 约定的子节点（按名字查找，可选）：
##   Sprite (Sprite2D，可带 flash 材质)   Health (HealthComponent)   Laugh (LaughMeter，有它才能被挠痒)
##   Status (StatusComponent，减速/被抓住)
##
## 实现 Damageable 接口：receive_hit(hit: HitData) -> bool
## 子类不要重写 _ready / _physics_process，而是重写下面的虚方法：
##   _setup()                 初始化
##   _tick(delta)             每个物理帧
##   _on_damaged(hit)         受到攻击（已扣血）
##   _on_tickled(hit)         被挠痒（已加闷笑值）
##   _tickle_multiplier(hit)  受到的挠痒倍率（默认 1）
##   _on_laugh_overflow()     闷笑值满（默认扣 1 点血）
##   _on_died()               死亡

signal died(actor: Actor)
## 被挠痒（已加闷笑值；hit.tickle 是乘过倍率后的实际值）。组合技追踪等监听它。
signal tickled(hit: HitData)

@export var faction := Faction.Type.NEUTRAL
## 受到攻击后的无敌时间（只挡攻击，不挡挠痒）。
@export var hurt_invuln_time := 1.0
## 击退抗性 0~1。
@export_range(0.0, 1.0) var knockback_resist := 0.0
@export var flash_color := Color(1, 0.3, 0.35)

@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var health: HealthComponent = get_node_or_null("Health")
@onready var laugh: LaughMeter = get_node_or_null("Laugh")
@onready var status: StatusComponent = get_node_or_null("Status")

var facing := Vector2.DOWN
## 本帧累积的外力（风扇、传送带、拉扯），移动时叠加到速度上，然后清零。
var _push := Vector2.ZERO
## 最近一次成功生效的命中（死亡时可据此判断是被什么打死的）。
var last_hit: HitData
## 这次死亡是笑到脱力（闷笑值满扣血）造成的。
var died_from_laugh := false
## 最近一次挠痒（在加闷笑值之前记录：致命的那一下也能查到是谁挠的）。
var last_tickle: HitData
## 最近一次挠痒的时间（秒，Time.get_ticks_msec 换算）。
var last_tickle_time := -INF
## 死前这么多秒内被挠过，也算"笑倒"（最后一下是普通攻击时）。
const LAUGH_DEFEAT_WINDOW := 2.0
var _attack_invuln := 0.0
var _full_invuln := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("actor")
	if Faction.GROUPS.has(faction):
		add_to_group(Faction.GROUPS[faction])
	if health:
		health.died.connect(_die)
	if laugh:
		laugh.overflow.connect(_on_laugh_overflow)
	_setup()


func _physics_process(delta: float) -> void:
	_attack_invuln = maxf(_attack_invuln - delta, 0.0)
	_full_invuln = maxf(_full_invuln - delta, 0.0)
	_tick(delta)


# ------------------------------------------------------------------ Damageable
func receive_hit(hit: HitData) -> bool:
	if _dead or _full_invuln > 0.0:
		return false
	match hit.kind:
		HitData.Kind.ATTACK:
			if _attack_invuln > 0.0 or health == null:
				return false
			if laugh:
				laugh.notify_attacked()
			_attack_invuln = hurt_invuln_time
			last_hit = hit
			if hit.knockback > 0.0:
				apply_knockback(hit.origin, hit.knockback)
			flash(flash_color)
			health.damage(hit.damage)
			if not _dead:
				_on_damaged(hit)
			return true
		HitData.Kind.TICKLE:
			if laugh == null:
				return false
			if hit.knockback > 0.0:
				apply_knockback(hit.origin, hit.knockback)
			hit.tickle *= _tickle_multiplier(hit)
			last_tickle = hit
			last_tickle_time = Time.get_ticks_msec() / 1000.0
			laugh.add(hit.tickle)
			if not _dead:
				_on_tickled(hit)
				tickled.emit(hit)
			return true
	return false


# ------------------------------------------------------------------ 通用能力
func is_alive() -> bool:
	return not _dead


## 是否处于无敌（任意一种）。
func is_invulnerable() -> bool:
	return _dead or _full_invuln > 0.0 or _attack_invuln > 0.0


## 冲刺等"全无敌"：攻击、挠痒、抓取都无效。
func is_fully_invulnerable() -> bool:
	return _dead or _full_invuln > 0.0


## 能否被抓住（需要 Status 组件）。
func can_be_grabbed() -> bool:
	return status != null and not is_fully_invulnerable() and not status.is_grabbed()


## full = true：攻击和挠痒都挡（冲刺）；false：只挡攻击。
func set_invulnerable(duration: float, full := true) -> void:
	if full:
		_full_invuln = maxf(_full_invuln, duration)
	else:
		_attack_invuln = maxf(_attack_invuln, duration)


func apply_knockback(from: Vector2, force: float) -> void:
	var dir := (global_position - from).normalized()
	if dir == Vector2.ZERO:
		dir = -facing
	velocity = dir * force * (1.0 - knockback_resist)


func flash(color: Color, duration := 0.25) -> void:
	var mat: ShaderMaterial = null
	if sprite:
		mat = sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_color", color)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 0.9, 0.0, duration)


## 外力推动（风扇、传送带、触手拉扯）：每帧调用，只作用于这一帧。
func add_push(v: Vector2) -> void:
	_push += v


## 带外力的 move_and_slide：外力不会累积进 velocity。
func move_with_push() -> void:
	if _push == Vector2.ZERO:
		move_and_slide()
		return
	var base := velocity
	velocity += _push
	_push = Vector2.ZERO
	move_and_slide()
	velocity = base


## 4 方向朝向。
func dir4() -> Vector2:
	if absf(facing.x) > absf(facing.y):
		return Vector2(signf(facing.x), 0)
	return Vector2(0, signf(facing.y) if facing.y != 0 else 1.0)


func dir_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "side"
	return "up" if facing.y < 0 else "down"


## 找最近的、活着的敌对角色。
func nearest_hostile(max_range := INF) -> Actor:
	var best: Actor = null
	var best_d := max_range * max_range
	for n in get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a == null or a == self or not a.is_alive() or not Faction.are_hostile(self, a):
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d <= best_d:
			best_d = d
			best = a
	return best


## 这次倒下算不算"笑倒"：闷笑值溢出致死，或死时正在失控 / 被抓住 / 刚被挠过痒。
## （笑到失控时怪物常用普通攻击扣掉最后一点血，也要算笑倒。）
func is_laugh_defeat() -> bool:
	if died_from_laugh:
		return true
	if laugh and laugh.value > laugh.helpless_threshold:
		return true
	if status and status.is_grabbed():
		return true
	return Time.get_ticks_msec() / 1000.0 - last_tickle_time <= LAUGH_DEFEAT_WINDOW


func revive() -> void:
	_dead = false
	died_from_laugh = false
	last_tickle = null
	last_tickle_time = -INF
	if status:
		status.clear()
	if health:
		health.fill()
	if laugh:
		laugh.clear()


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	_on_died()


# ------------------------------------------------------------------ 虚方法（子类重写）
func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_damaged(_hit: HitData) -> void:
	pass


func _on_tickled(_hit: HitData) -> void:
	pass


## 受到的挠痒倍率（易痒、弱点暴露等）。hit.tickle 会先乘上它再加到闷笑值。
func _tickle_multiplier(_hit: HitData) -> float:
	return status.tickle_multiplier() if status else 1.0


## 笑到脱力：默认扣 1 点血（半颗心）。
func _on_laugh_overflow() -> void:
	if health and not _dead:
		flash(Color(1, 0.6, 0.85))
		died_from_laugh = true
		health.damage(1)
		if not _dead:
			died_from_laugh = false


func _on_died() -> void:
	queue_free()
