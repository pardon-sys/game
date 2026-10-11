class_name SiegeAIHooks
extends BattleAIHooks
## 攻防战给粉色公主 AI（CompanionController）的导演提示：
##   safe_spot_for   闷笑 ≥ 60% 时去最近的薄荷冰泉（冰塔）喘口气；没有冰泉就退到城门口
##   objective_for   附近没怪时，去最危险的那段墙下面
##   partner_of      蓝色公主（Duo）

const SAFE_AT := 0.6

var director: Node


func _init(d: Node) -> void:
	director = d


func safe_spot_for(ai: PlayableCharacter) -> Variant:
	if ai.laugh == null or ai.laugh.ratio() < SAFE_AT:
		return null
	var best: Variant = null
	var best_d := INF
	for t in ai.get_tree().get_nodes_in_group("siege_mint"):
		var d := ai.global_position.distance_to((t as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = (t as Node2D).global_position + Vector2(0, 14)
	return best if best != null else director.gate_pos


func objective_for(ai: PlayableCharacter) -> Variant:
	if not director.enemies_near(ai.global_position, 90.0).is_empty():
		return null
	var hot: SiegeWall = director.hottest_wall()
	if hot == null or director.threat(hot) == 0:
		return null
	return Vector2(clampf(ai.global_position.x, hot.left_x() + 16.0, hot.right_x() - 16.0), hot.foot_y() + 40.0)
