class_name Floor8AIHooks
extends BattleAIHooks
## 千手痒痒魔 Boss 战给 AI 搭档的提示（第八层专属）：千手乱舞的安全圈、阶段二的压力板、本体能打时优先打它、蓝色公主够得着本体时冻住它。

var dir: Floor8Director


func _init(d: Floor8Director) -> void:
	dir = d


func safe_spot_for(ai: PlayableCharacter) -> Variant:
	return dir.safe_spot_for(ai)


func objective_for(ai: PlayableCharacter) -> Variant:
	return dir.plate_for(ai)


func priority_target() -> Variant:
	return dir.priority_target()


## 蓝色公主：本体在打、没被冻住、够得着（72 像素 + 本体半径）时冻住它。
func magic_target(ai: PlayableCharacter) -> Variant:
	var b := dir.boss
	if ai.character_id != "blue" or not is_instance_valid(b) or not b.fighting or b.is_frozen():
		return null
	if b.aim_point().distance_to(ai.global_position) < 72.0 + float(b.get_meta("body_radius", 0.0)):
		return b
	return null
