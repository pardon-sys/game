class_name RaiderMind
extends SiegeMind
## 抢掠小队的大脑（WaveFeatures 的 raiders）：绕开公主，专找最近的冰塔（IceTower.raid_hit）和墙下的士兵打。
## 没有冰塔 / 士兵可打时照常朝城墙行军。头上的小红旗由 WaveFeatures 挂。

const HIT_GAP := 0.8
const REACH := 14.0

var _goal: Node2D
var _hit_cd := 0.0


func wander(m: Monster, delta: float) -> bool:
	if m.get_meta("airborne", false) or m.has_meta("in_ladder"):
		return true
	if m.get_meta("siege_on_wall", false):
		wall_top(m, delta)
		return true
	_hit_cd -= delta
	_think -= delta
	if _think <= 0.0 or _goal == null or not is_instance_valid(_goal) or not (_goal as Actor).is_alive():
		_think = 0.5
		_goal = pick(m)
	if _goal == null or not is_instance_valid(_goal):
		march(m, delta)
		return true
	var to := _goal.global_position + Vector2(0, 6) - m.global_position
	if to.length() > REACH:
		# 离目标远时绕障碍走；贴近了直接过去（冰塔本身就是「障碍」）
		var dir := to.normalized()
		m._move(avoid(m, dir, delta) if to.length() > 40.0 else dir, m.stats.chase_speed, delta)
		return true
	m.velocity = Vector2.ZERO
	if _hit_cd <= 0.0:
		_hit_cd = HIT_GAP
		if _goal is IceTower:
			(_goal as IceTower).raid_hit(1, m)
		else:
			(_goal as Actor).receive_hit(HitData.make_attack(m, 1, 60.0))
		Fx.burst(m.get_parent(), m.global_position + Vector2(0, -8), "dust", 3, 30.0, 0.3, Vector2(0, 40))
	return true


## 最近的冰塔或墙下的士兵（墙顶上的弓箭手够不着）。
func pick(m: Monster) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in m.get_tree().get_nodes_in_group("siege_tower"):
		var t := n as IceTower
		if t and t.health and t.is_alive():
			var d := t.global_position.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = t
	if director:
		for s in director.soldiers:
			if is_instance_valid(s) and s.is_alive() and not director.is_on_wall(s):
				var d2: float = (s as Node2D).global_position.distance_to(m.global_position) * 1.3   # 冰塔优先
				if d2 < best_d:
					best_d = d2
					best = s
	return best
