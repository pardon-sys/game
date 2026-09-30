class_name Projectile
extends Area2D
## 投射物基类：直线飞行，命中敌对的 Damageable 后施加 HitData（和可选的减速），碰到墙消失。
## 发射：Projectile.fire(scene, parent, from, direction, shooter)
## 子类重写 _on_hit(target) 可加特殊效果；_on_expire() 做消失表现。

@export var speed := 120.0
@export var lifetime := 2.0
@export var hit_kind := HitData.Kind.TICKLE
@export var damage := 0
@export var tickle := 3.0
@export var knockback := 0.0
## 命中后减速（1 = 不减速）。
@export var slow_multiplier := 1.0
@export var slow_duration := 0.0

var direction := Vector2.RIGHT
var shooter: Node = null
var _age := 0.0
var _done := false


static func fire(scene: PackedScene, parent: Node, from: Vector2, dir: Vector2, src: Node) -> Projectile:
	var p: Projectile = scene.instantiate()
	p.direction = dir.normalized()
	p.shooter = src
	parent.add_child(p)
	p.global_position = from
	p.rotation = p.direction.angle()
	return p


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done or GameState.in_dialogue:
		return
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		_expire()


func _on_body_entered(body: Node) -> void:
	if _done or body == shooter:
		return
	if Contracts.is_damageable(body):
		if Faction.of(body) == Faction.Type.NEUTRAL or Faction.are_hostile(shooter, body):
			_on_hit(body)
			_expire()
	elif body is TileMapLayer or body is StaticBody2D:
		_expire()


## 命中效果（默认：减速 + 施加 HitData）。
func _on_hit(target: Node) -> void:
	if slow_duration > 0.0 and target is Actor and target.status and not target.is_fully_invulnerable():
		target.status.apply_slow(slow_multiplier, slow_duration)
	var hit := HitData.make_tickle(self, tickle, knockback) if hit_kind == HitData.Kind.TICKLE \
			else HitData.make_attack(self, damage, knockback)
	target.receive_hit(hit)


func _expire() -> void:
	_done = true
	set_deferred("monitoring", false)
	_on_expire()


func _on_expire() -> void:
	queue_free()
