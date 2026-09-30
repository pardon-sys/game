class_name BubbleFish
extends Monster
## 泡泡鱼：和目标保持距离，每 shot_cooldown 秒吐一个泡泡（BubbleShot，射程 shot_range）。
## 泡泡命中：把公主关进泡泡牢笼 trap_time 秒（抓取，连按 trap_presses 次戳破），
## 牢笼里每 trap_interval 秒挠 trap_tickle（算泡泡鱼的挠痒，能暴击）。近身时普通挠痒。

const BUBBLE := preload("res://scenes/combat/bubble_shot.tscn")
const CAGE_TEX := preload("res://assets/generated/bubble_cage.png")

@export var keep_min := 56.0
@export var keep_max := 96.0
@export var shot_cooldown := 3.0
@export var shot_range := 120.0
@export var trap_time := 1.5
@export var trap_presses := 5
@export var trap_tickle := 3.0
@export var trap_interval := 0.4

var victim: Actor
var _shot_cd := 1.2
var _trap_tick := 0.0
var _cage: Sprite2D


func _setup() -> void:
	super()
	sprite.hframes = 2


func _tick(delta: float) -> void:
	if not GameState.in_dialogue:
		_shot_cd -= delta
	super(delta)
	if GameState.in_dialogue:
		return
	_update_trap(delta)
	if state == State.CHASE and is_instance_valid(target) and _shot_cd <= 0.0 and victim == null \
			and not is_stunned() and global_position.distance_to(target.global_position) <= shot_range:
		shoot_bubble()


func shoot_bubble() -> void:
	_shot_cd = shot_cooldown
	var from := global_position + Vector2(0, -6)
	Projectile.fire(BUBBLE, get_parent(), from, from.direction_to(target.global_position + Vector2(0, -4)), self)
	Audio.play("bubble", -4.0, 0.1)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)


## 泡泡命中时调用：关进泡泡牢笼。成功返回 true。
func trap(t: Node) -> bool:
	var a := t as Actor
	if victim != null or a == null or not a.is_alive() or not a.can_be_grabbed():
		return false
	if not a.status.grab(self, trap_time, trap_presses):
		return false
	victim = a
	_trap_tick = 0.2
	_cage = Sprite2D.new()
	_cage.texture = CAGE_TEX
	_cage.z_index = 5
	_cage.position = Vector2(0, -9)
	a.add_child(_cage)
	var tw := _cage.create_tween().set_loops()
	tw.tween_property(_cage, "scale", Vector2(1.06, 0.95), 0.3)
	tw.tween_property(_cage, "scale", Vector2(0.95, 1.06), 0.3)
	maybe_taunt(true)
	return true


func is_trapping() -> bool:
	return victim != null


func _update_trap(delta: float) -> void:
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		_end_trap()
		return
	_trap_tick -= delta
	if _trap_tick <= 0.0:
		_trap_tick = trap_interval
		if deliver_tickle(victim, trap_tickle):
			play_tickle_sound(-6.0)


func _end_trap() -> void:
	if is_instance_valid(victim) and victim.status and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null
	if is_instance_valid(_cage):
		Audio.play("bubble_pop", -2.0, 0.1)
		var c := _cage
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2(1.4, 1.4), 0.08)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.1)
		tw.tween_callback(c.queue_free)
	_cage = null


## 保持距离；牢笼里关着人时绕着她游。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if state != State.CHASE or not is_instance_valid(target):
		super(dir, speed, delta)
		return
	var d := global_position.distance_to(target.global_position)
	if d > keep_max:
		super(dir, speed, delta)
	elif d < keep_min and victim == null:
		super(-dir, speed, delta)
	else:
		super(dir.orthogonal(), speed * 0.5, delta)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 5.0) % 2
	sprite.offset.y = -9.0 + roundf(sin(_t * 3.0))
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0  # 图朝左


func _on_stunned(_duration: float) -> void:
	_end_trap()


func _on_died() -> void:
	_end_trap()
	super()
