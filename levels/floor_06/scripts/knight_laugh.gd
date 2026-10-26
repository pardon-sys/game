class_name KnightLaugh
extends RefCounted
## 骑士篇的「故意笑」（以笑为饵、引手印碎片、Boss 点灯笼 / 引开骑士都用它）：按住 Y（动作 laugh）超过 HOLD 秒，就捂着嘴偷偷笑——
##   闷笑每秒 +RATE（按得越久越响），松开以后闷笑自己慢慢落下来；隔一会儿冒一句气泡、换成憋笑的表情。
##   任务要把这一下先拿去做别的时，tick 的 allow 传 false。
## 测试：force_hold（这一帧当成按住了 Y）。

const HOLD := 0.25
const RATE := 0.22
const SAY_EVERY := 1.1
const LINES := ["……噗、噗嗤……", "……嘻嘻……（捂住嘴）", "……哈……忍、忍不住……", "嘿嘿……来呀……"]

static var force_hold := false
static var _held := 0.0
static var _say := 0.0


## 从头算按住的时间（换任务 / 测试用）
static func reset() -> void:
	_held = 0.0


static func pressed() -> bool:
	return force_hold or Input.is_action_pressed("laugh")


## 每帧调：c 这一帧在故意笑就返回 true（闷笑已经加上了）
static func tick(c: PlayableCharacter, delta: float, allow := true) -> bool:
	if not is_instance_valid(c) or c != GameState.player or not pressed() or GameState.in_dialogue:
		_held = 0.0
		return false
	_held += delta
	if _held < HOLD or not allow:
		return false
	laugh(c, delta)
	return true


## 笑一帧：闷笑上涨、隔一会儿冒气泡
static func laugh(c: PlayableCharacter, delta: float) -> void:
	if c.laugh:
		c.laugh.add(c.laugh.max_value * RATE * delta)
	_say -= delta
	if _say <= 0.0:
		_say = SAY_EVERY
		SpeechBubble.say(c, str(LINES.pick_random()), 30.0, 1.0)
		GameState.emote("giggle", 1.0, false)
