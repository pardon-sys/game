class_name WarmSlime
extends SiegeMonster
## 暖炉史莱姆：暖烘烘的，不怕冻（冻不住、不减速），冰锥 / 冰塔 / 蓝色公主的法术都打不动——只能粉色公主打。
## 不攻城，专找最近的冰塔，贴上去把塔慢慢融化（MELT 每秒）。

const MELT := 9.0
const SEEK := 260.0


func stun(_duration: float) -> void:
	pass


func add_buff(id: String, duration := -2.0, stacks := 1) -> void:
	if id == "siege_chill":
		return
	super(id, duration, stacks)


func block_hit(hit: HitData) -> bool:
	var s := hit.source
	return s is IceTower or s is Snowman or (s is PlayableCharacter and (s as PlayableCharacter).character_id == "blue")


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	var best: IceTower = null
	var best_d := SEEK
	for t in get_tree().get_nodes_in_group("siege_tower"):
		var d := (t as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = t
	if best == null:
		return false
	if best_d > 14.0:
		_move(global_position.direction_to(best.global_position), stats.chase_speed, delta)
	else:
		velocity = Vector2.ZERO
		best.melt(MELT * delta)
		if randf() < delta * 3.0:
			Fx.burst(get_parent(), best.global_position + Vector2(0, -10), "drop", 2, 20.0, 0.5, Vector2(0, 40), Color(0.7, 0.9, 1.0))
	return true
