class_name TickleGhost
extends Monster
## 痒痒幽灵：半透明、穿墙、慢慢飘近，只会挠痒（单次量大）。
## 进入已点亮火把的光照范围时显形并减速；只有显形时才能被攻击。

@export var reveal_radius := 72.0
@export var hidden_alpha := 0.28
@export var revealed_speed_mult := 0.5

var revealed := false


func _tick(delta: float) -> void:
	_update_reveal()
	super(delta)


func _update_reveal() -> void:
	var r := false
	for t in get_tree().get_nodes_in_group("torch"):
		# 光照半径：火把用 reveal_radius；篝火塔 / 篝火这类自己带 light_radius 的按它算
		var lr: Variant = t.get("light_radius")
		var rad := maxf(reveal_radius, float(lr) if lr != null else 0.0)
		if t.lit and t.global_position.distance_to(global_position) <= rad:
			r = true
			break
	# 攻防战：守夜人的灯笼（友军身边的小光圈）
	var d := SiegeDirector.current
	if not r and d and d.town and d.town.add("lantern") > 0.0:
		var lr2 := d.town.add("lantern")
		for a in d.town.allies():
			if is_instance_valid(a) and a.global_position.distance_to(global_position) <= lr2:
				r = true
				break
	if r != revealed:
		revealed = r
		if revealed:
			flash(Color(1, 1, 1))


func _move(dir: Vector2, speed: float, delta: float) -> void:
	super(dir, speed * (revealed_speed_mult if revealed else 1.0), delta)


## 未显形时攻击会穿过去。
func receive_hit(hit: HitData) -> bool:
	if hit.kind == HitData.Kind.ATTACK and not revealed:
		return false
	return super(hit)


func _choose_action(_t: Actor) -> String:
	return "tickle"


## 只挠痒，挠不到也不会改成攻击。
func _perform(_action: String, t: Actor) -> bool:
	return tickle(t)


func _animate(delta: float) -> void:
	var goal := 0.85 if revealed else hidden_alpha
	sprite.modulate.a = move_toward(sprite.modulate.a, goal, delta * 2.0)
	sprite.offset.y = -10.0 + roundf(sin(_t * 3.0) * 2.0)
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
