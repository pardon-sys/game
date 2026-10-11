class_name FeatherBatSwarm
extends SiegeMonster
## 羽毛蝠群：飞在天上——粉色公主的近战够不着（她的攻击打不中），直接越过战场飞上城墙去挠蓝色公主；
## 只有蓝色公主的法术和冰塔能打下来。


func _setup() -> void:
	super()
	collision_mask = 0
	z_index = 8


func block_hit(hit: HitData) -> bool:
	return hit.source is PlayableCharacter and (hit.source as PlayableCharacter).character_id == "pink"


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if director == null:
		return false
	var b := director.blue
	var goal := Vector2(global_position.x, director.wall_top_y())
	if b and is_instance_valid(b) and b.is_alive() and not Downed.is_downed(b):
		goal = b.global_position + Vector2(0, -4)
		target = b
	var d := goal - global_position
	velocity = d.normalized() * stats.chase_speed * stat_mul("speed") + Vector2(sin(_t * 5.0) * 12.0, 0)
	on_wall = director.is_on_wall(self)
	return true
