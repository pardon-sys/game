class_name TwinGhost
extends SiegeMonster
## 双子痒痒鬼：成对出现——一只（a，粉色）在墙下，一只（b，蓝色）飘上城墙找蓝色公主。
## 要在 PAIR_TIME 秒内把两只都打倒，不然先倒下的那只会复活（满血）。两人同时出手。
## 两只相邻登场、同行接近城墙，b 再飘上墙；全程保持实际距离上限。

const PAIR_TIME := 8.0
const SOFT_DISTANCE := 192.0
const MAX_DISTANCE := 240.0
var _rope_fx := 0.0

@export var half := "a"

var twin: TwinGhost
var _down_at := -1.0
var _spawned_pair := false


func _setup() -> void:
	super()
	if half == "a":
		_spawn_pair.call_deferred()
	if half == "b":
		sprite_key = "twin_ghost_b"
		collision_mask = 0
		z_index = 8
		if sprite:
			sprite.region_rect = region(sprite_key + "_0")


## 在城墙上生出另一半（b）。
func _spawn_pair() -> void:
	if _spawned_pair or half != "a" or director == null or not is_inside_tree():
		return
	_spawned_pair = true
	var b := director.spawn("twin_ghost", "", director.clamp_in_map(global_position + Vector2(20, -16), 24, true)) as TwinGhost
	if b:
		b.half = "b"
		b._spawned_pair = true
		b.sprite_key = "twin_ghost_b"
		b.collision_mask = 0
		b.on_wall = director.is_on_wall(b)
		b.z_index = 8
		if b.sprite:
			b.sprite.region_rect = region("twin_ghost_b_0")
		twin = b
		b.twin = self


func _tick(delta: float) -> void:
	_rope_fx = maxf(0.0, _rope_fx - delta)
	if _down_at >= 0.0:
		velocity = Vector2.ZERO
		if not SiegeTools.paused() and Time.get_ticks_msec() / 1000.0 - _down_at >= PAIR_TIME:
			_revive_half()
		return
	super(delta)
	if half == "b" and not on_wall and director and absf(global_position.y - (director.wall_top_y() + 2.0)) < 5.0:
		on_wall = true
		target = null
		state = State.WANDER
	_limit_pair()


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if half == "b":
		if not on_wall:
			var goal := Vector2(global_position.x, director.wall_top_y() + 2.0)
			_move(global_position.direction_to(goal), stats.chase_speed, delta)
			if global_position.distance_to(goal) < 5.0:
				on_wall = true
		else:
			wall_hunt(delta)
		return true
	return false


## 追击 / 受击状态也必须遵守绳长，不只限制 wander。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if is_instance_valid(twin) and global_position.distance_to(twin.global_position) > SOFT_DISTANCE:
		dir = global_position.direction_to(twin.global_position)
		target = null
		state = State.WANDER
	elif half == "b" and not on_wall and director:
		dir = global_position.direction_to(Vector2(twin.global_position.x if is_instance_valid(twin) else global_position.x, director.wall_top_y() + 2.0))
	super(dir, speed, delta)


func move_with_push() -> void:
	if SiegeTools.paused():
		velocity = Vector2.ZERO
		_push = Vector2.ZERO
		return
	if is_instance_valid(twin):
		var dt := get_physics_process_delta_time()
		var next := global_position + (velocity + _push) * dt
		var offset := next - twin.global_position
		if offset.length() > MAX_DISTANCE:
			velocity = (twin.global_position + offset.limit_length(MAX_DISTANCE) - global_position) / maxf(dt, 0.001) - _push
	super()
	_limit_pair()


func _limit_pair() -> void:
	if not is_instance_valid(twin) or twin.is_queued_for_deletion() or SiegeTools.paused():
		return
	var offset := global_position - twin.global_position
	if offset.length() > MAX_DISTANCE:
		var correction := twin.global_position + offset.limit_length(MAX_DISTANCE) - global_position
		# b 本来就无碰撞；a 只做安全回退，不能投影穿过城墙或塔身。
		if collision_mask == 0 or not test_move(global_transform, correction):
			global_position += correction
		else:
			twin.global_position = global_position - offset.limit_length(MAX_DISTANCE)
		velocity = Vector2.ZERO
	if offset.length() > SOFT_DISTANCE and _rope_fx <= 0.0:
		_rope_fx = 0.6
		Fx.burst(get_parent(), (global_position + twin.global_position) / 2.0 + Vector2(0, -10), "spark", 3, 25.0, 0.35, Vector2.ZERO, Color(1, 0.75, 0.95))



func _die() -> void:
	# 另一半已经倒下（PAIR_TIME 内）→ 两只一起真正消失；否则先「装死」等另一半
	if twin and is_instance_valid(twin) and twin._down_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - twin._down_at <= PAIR_TIME:
		twin._down_at = -1.0
		twin._finish()
		super()
		return
	if twin == null or not is_instance_valid(twin):
		super()
		return
	# 死亡回调可能先于另一半的行走更新；超时不能借这一帧补刀成功。
	if twin._down_at >= 0.0:
		twin._revive_half()
	_down_at = Time.get_ticks_msec() / 1000.0
	modulate.a = 0.35
	SpeechBubble.say(self, "嘻嘻……还有另一个哦", 24.0, 1.4)


func _finish() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		super._die()


func is_alive() -> bool:
	return _down_at < 0.0 and super()


## 两只之间一条忽明忽暗的连线。
func _process(_delta: float) -> void:
	if half == "a":
		queue_redraw()


func _draw() -> void:
	if half != "a" or twin == null or not is_instance_valid(twin):
		return
	var a := 0.25 + 0.2 * sin(Time.get_ticks_msec() / 200.0)
	draw_line(Vector2(0, -10), to_local(twin.global_position) + Vector2(0, -10), Color(1, 0.75, 0.95, a + (0.25 if global_position.distance_to(twin.global_position) > SOFT_DISTANCE else 0.0)), 1.8 if global_position.distance_to(twin.global_position) > SOFT_DISTANCE else 1.0)


func _revive_half() -> void:
	_down_at = -1.0
	modulate.a = 1.0
	health.fill()
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "ember", 10, 40.0, 0.5, Vector2(0, -20), Color(1, 0.7, 0.9))
	var r := SiegeFx.ring(get_parent(), global_position, 10.0, Color(0.9, 0.7, 1.0, 0.9), 0.5, 0.2)
	if r:
		r.create_tween().tween_property(r, "scale", Vector2(3, 3), 0.45)
	SpeechBubble.say(self, "复活啦～", 24.0, 1.2)
