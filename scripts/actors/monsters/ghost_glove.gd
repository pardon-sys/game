class_name GhostGlove
extends Monster
## 幽灵手套：只挠痒，不打人。地图里用 pair=<名字> 让两只配成一对（同名的两只是一对）。
## 两只都贴在目标身边（pair_range 内）时：这一下挠痒必定暴击，搭档立刻跟着补挠一下（combo_cooldown 秒一次）。

@export var pair := ""
@export var pair_range := 24.0
@export var combo_cooldown := 2.5

var _combo_cd := 0.0
var _pair_strike := false


func _setup() -> void:
	super()
	sprite.hframes = 2
	if pair != "":
		add_to_group("glove_pair_" + pair)


func _tick(delta: float) -> void:
	if not GameState.in_dialogue:
		_combo_cd = maxf(_combo_cd - delta, 0.0)
	super(delta)


## 同一对里的另一只（不在 / 已被打散返回 null）。
func partner() -> GhostGlove:
	if pair == "" or not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group("glove_pair_" + pair):
		if n != self and n is GhostGlove and (n as GhostGlove).is_alive():
			return n
	return null


## 两只都在目标身边、配合技没在冷却。
func pair_ready(t: Node) -> bool:
	var p := partner()
	return p != null and _combo_cd <= 0.0 and t is Node2D \
			and global_position.distance_to((t as Node2D).global_position) <= pair_range \
			and p.global_position.distance_to((t as Node2D).global_position) <= pair_range


func _choose_action(_t: Actor) -> String:
	return "tickle"


func _perform(_action: String, t: Actor) -> bool:
	return tickle(t)


func _force_special(t: Node) -> bool:
	_pair_strike = pair_ready(t)
	return _pair_strike


func _on_special_tickle(t: Node) -> void:
	if not _pair_strike:
		return
	_pair_strike = false
	var p := partner()
	_combo_cd = combo_cooldown
	_pop()
	if p:
		p._combo_cd = combo_cooldown
		p.follow_up(t)


## 搭档的补挠：立即挠一下（普通挠痒，可能随机暴击）。
func follow_up(t: Node) -> void:
	if not is_alive() or not Contracts.is_tickleable(t):
		return
	_pop()
	if deliver_tickle(t, stats.tickle_amount):
		play_tickle_sound(-4.0)
		maybe_taunt(true)


func _pop() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 6.0) % 2
	sprite.offset.y = -10.0 + roundf(sin(_t * 3.0 + (0.0 if pair == "" else float(get_instance_id() % 7))) * 1.5)
	sprite.modulate.a = 0.85 + sin(_t * 4.0) * 0.1
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
