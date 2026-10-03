class_name ThighBrushRing
extends LegTrap
## 大腿刷环：踩到中心时一圈刷环从地下升起套住双腿，边转边刷大腿内侧，困得越久转得越快。
## 露出部位：thigh ×1.4。共用行为见 LegTrap。


func _while_held(delta: float) -> void:
	super(delta)
	if sprite:
		sprite.frame_coords.x = 1 + int(_hold_t / maxf(self_interval, 0.1)) % 2


var _ring: TrapFx.BristleRing


func _fx_restrain(_a: Actor) -> void:
	_fx_free(null)
	_ring = TrapFx.BristleRing.new()
	fx_parent().add_child(_ring)


## 刷毛光环跟着腿转，挠得越快转得越快。
func _fx_tick(_delta: float) -> void:
	if is_instance_valid(_ring):
		_ring.global_position = body_point("thigh") + Vector2(0, 4)
		_ring.speed = clampf(0.3 / maxf(self_interval, 0.05), 0.6, 3.0)


func _fx_free(_a: Actor) -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _exit_tree() -> void:
	_fx_free(null)
