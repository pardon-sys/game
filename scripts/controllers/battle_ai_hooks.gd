class_name BattleAIHooks
extends RefCounted
## AI 搭档（CompanionController）在战斗里用的「导演提示」（可复用组件的接口）。战斗导演继承它、按需覆盖；全部可选，默认什么也不给。
##   safe_spot_for(ai)    大招时该站的安全点（Vector2；null = 没有）
##   objective_for(ai)    要去站着的点（压力板之类；Vector2 / null）
##   priority_target()    优先攻击的目标（Boss 本体能打时；Node2D / null）
##   magic_target(ai)     值得放魔法的目标（够得着就不退开、直接吟唱；Node2D / null）
##   partner_of(ai)       搭档（默认 Duo.partner_of）
## 用法：Duo.start([角色们], 导演, 你的 hooks)；之后 Duo 里没被操控的那个用 CompanionController，自动读 Duo.hooks。
## 例子：levels/floor_08/scripts/floor8_ai_hooks.gd（千手痒痒魔）。


func safe_spot_for(_ai: PlayableCharacter) -> Variant:
	return null


func objective_for(_ai: PlayableCharacter) -> Variant:
	return null


func priority_target() -> Variant:
	return null


func magic_target(_ai: PlayableCharacter) -> Variant:
	return null


func partner_of(ai: PlayableCharacter) -> PlayableCharacter:
	return Duo.partner_of(ai)
