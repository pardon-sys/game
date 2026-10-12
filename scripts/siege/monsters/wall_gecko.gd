class_name WallGecko
extends SiegeMonster
## 爬墙壁虎：跑得快、血少，走到墙下就贴着墙爬上去（冰墙加固的那段爬不上去，就沿着墙下找别的地方），上墙后在走道上乱窜、挠蓝色公主。

var _retry := 0.0


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if on_wall:
		wall_hunt(delta)
		return true
	if director and global_position.y <= director.wall_foot_y() + 16.0:
		_retry -= delta
		if _retry <= 0.0 and not climb_wall():
			_retry = 0.6
			_move(Vector2(1.0 if randf() < 0.5 else -1.0, 0.0), stats.chase_speed, delta)
		return true
	return false
