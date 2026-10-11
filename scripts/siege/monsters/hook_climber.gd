class_name HookClimber
extends SiegeMonster
## 钩索怪：走到城墙前 THROW_DIST 的地方停下，甩钩索勾住城墙（绳子 = siege_cuttable，冰锥雨能射断），
## 然后顺着绳子滑上墙顶，上去就去挠蓝色公主。绳子被射断 / 滑的时候被打一下 → 摔下来。

const THROW_DIST := 110.0
const SLIDE_TIME := 1.6

var _phase := "walk"
var rope: Rope


class Rope extends Line2D:
	var owner_monster: HookClimber

	func _ready() -> void:
		add_to_group("siege_cuttable")
		add_to_group("siege_temp")
		width = 1.5
		default_color = Color(0.8, 0.75, 0.6)
		z_index = 15

	func cut(_by: Node) -> void:
		if owner_monster and is_instance_valid(owner_monster):
			owner_monster.rope_cut()
		queue_free()


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if on_wall:
		wall_hunt(delta)
		return true
	if director == null:
		return false
	match _phase:
		"walk":
			if global_position.y <= director.wall_foot_y() + THROW_DIST:
				_phase = "throw"
				velocity = Vector2.ZERO
				_throw()
				return true
			return false
	velocity = Vector2.ZERO
	return true


func _throw() -> void:
	var top := Vector2(global_position.x + randf_range(-6, 6), director.wall_top_y() + 6.0)
	rope = Rope.new()
	rope.owner_monster = self
	get_parent().add_child(rope)
	rope.global_position = Vector2.ZERO
	rope.points = PackedVector2Array([global_position + Vector2(0, -10), global_position + Vector2(0, -10)])
	Audio.play("swish", -4.0, 0.1, 0.8)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(rope):
			rope.points = PackedVector2Array([global_position + Vector2(0, -10), (global_position + Vector2(0, -10)).lerp(top, v)]), 0.0, 1.0, 0.7)
	tw.tween_callback(func():
		if not is_instance_valid(rope) or not is_alive():
			return
		_phase = "slide"
		var w := director.segment_at(top.x)
		if w and not w.climbable():
			rope_cut()
			return
		climbing = true
		var tw2 := create_tween()
		tw2.tween_property(self, "global_position", top, SLIDE_TIME)
		tw2.tween_callback(func():
			if not climbing:
				return
			climbing = false
			on_wall = true
			collision_mask = 0
			if is_instance_valid(rope):
				rope.queue_free()))


func rope_cut() -> void:
	if _phase == "done":
		return
	_phase = "done"
	if is_instance_valid(rope):
		rope.queue_free()
	if climbing:
		climbing = false
		var tw := create_tween()
		tw.tween_property(self, "global_position", Vector2(global_position.x, director.wall_foot_y() + 20.0), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): if is_alive(): health.damage(2))
	_phase = "walk"


func _on_damaged(hit: HitData) -> void:
	super(hit)
	if climbing:
		rope_cut()


func _on_died() -> void:
	if is_instance_valid(rope):
		rope.queue_free()
	super()
