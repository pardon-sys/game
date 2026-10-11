class_name TwinGhost
extends SiegeMonster
## 双子痒痒鬼：成对出现——一只（a，粉色）在墙下，一只（b，蓝色）飘上城墙找蓝色公主。
## 要在 PAIR_TIME 秒内把两只都打倒，不然先倒下的那只会复活（满血）。两人同时出手。
## 导演出一只（twin_ghost）时，它自己在城墙上再生出另一半。

const PAIR_TIME := 3.0

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
	var b := director.spawn("twin_ghost", "", Vector2(global_position.x, director.wall_top_y() + 2.0)) as TwinGhost
	if b:
		b.half = "b"
		b._spawned_pair = true
		b.sprite_key = "twin_ghost_b"
		b.collision_mask = 0
		b.on_wall = true
		if b.sprite:
			b.sprite.region_rect = region("twin_ghost_b_0")
		twin = b
		b.twin = self


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if _down_at >= 0.0:
		velocity = Vector2.ZERO
		if Time.get_ticks_msec() / 1000.0 - _down_at >= PAIR_TIME:
			_revive_half()
		return true
	if half == "b":
		wall_hunt(delta)
		return true
	return false


func _die() -> void:
	# 另一半已经倒下（PAIR_TIME 内）→ 两只一起真正消失；否则先「装死」等另一半
	if twin and is_instance_valid(twin) and twin._down_at >= 0.0:
		twin._down_at = -1.0
		twin._finish()
		super()
		return
	if twin == null or not is_instance_valid(twin):
		super()
		return
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
	draw_line(Vector2(0, -10), to_local(twin.global_position) + Vector2(0, -10), Color(1, 0.75, 0.95, a), 1.0)


func _revive_half() -> void:
	_down_at = -1.0
	modulate.a = 1.0
	health.fill()
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "ember", 10, 40.0, 0.5, Vector2(0, -20), Color(1, 0.7, 0.9))
	var r := SiegeFx.ring(get_parent(), global_position, 10.0, Color(0.9, 0.7, 1.0, 0.9), 0.5, 0.2)
	if r:
		r.create_tween().tween_property(r, "scale", Vector2(3, 3), 0.45)
	SpeechBubble.say(self, "复活啦～", 24.0, 1.2)
