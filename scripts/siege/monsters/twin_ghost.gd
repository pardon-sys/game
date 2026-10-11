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
	if half == "b":
		sprite_key = "twin_ghost_b"
		collision_mask = 0
		z_index = 8
		if sprite:
			sprite.region_rect = region(sprite_key + "_0")


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if not _spawned_pair and half == "a" and director:
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


func _revive_half() -> void:
	_down_at = -1.0
	modulate.a = 1.0
	health.fill()
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "ember", 10, 40.0, 0.5, Vector2(0, -20), Color(1, 0.7, 0.9))
	SpeechBubble.say(self, "复活啦～", 24.0, 1.2)
