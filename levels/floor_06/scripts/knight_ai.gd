class_name KnightAI
extends CompanionController
## 骑士篇追逃 / Boss 里没被操控的那位公主（AI 搭档）：复用 CompanionController 的挣扎 / 躲预警（danger 组）/ 打怪 / 跟随，
## 中间插一个 task 行为——问任务给的 plan（Callable(ai) -> Dictionary）这一帧干什么：
##   {"to": 世界坐标, "near": 到了多近就停（默认 8）, "dash": 远的时候冲刺}  走过去
##   {"hold": true}                                                         原地不动
##   {}                                                                     交给后面的行为（打 hooks.priority_target、跟着玩家）
## 冻住、挣扎之类的动作由任务在 plan 里直接调（AI 不按键，任务的按键只认玩家）。
## 用法：KnightAI.install([粉色, 蓝色], plan, hooks, behaviours)：换人时没被操控的那位自动用它（PlayableCharacter.ai_factory），现在没被操控的那位马上装上；
##   KnightAI.uninstall()：还原（任务结束时，没被操控的那位换回平时的跟随）。

const BEHAVIOURS: Array[String] = ["struggle", "dodge", "task", "attack", "follow"]
const DASH_FAR := 60.0

static var _saved_factory := Callable()
static var _installed := false
static var _chars: Array = []

var plan: Callable


static func install(chars: Array, task_plan: Callable, ai_hooks: BattleAIHooks = null, list: Array[String] = BEHAVIOURS) -> void:
	if not _installed:
		_saved_factory = PlayableCharacter.ai_factory
	_installed = true
	_chars = chars.duplicate()
	PlayableCharacter.ai_factory = func(c: PlayableCharacter) -> CharacterController:
		var ai := KnightAI.new()
		ai.plan = task_plan
		ai.hooks = ai_hooks
		ai.behaviours.assign(list)
		return ai
	_refit()


static func uninstall() -> void:
	if not _installed:
		return
	_installed = false
	PlayableCharacter.ai_factory = _saved_factory
	_saved_factory = Callable()
	_refit()
	_chars.clear()


## 没被操控的那位公主换上现在该用的 AI
static func _refit() -> void:
	for c in _chars:
		if is_instance_valid(c) and not (c as PlayableCharacter).is_controlled():
			(c as PlayableCharacter).set_controller((c as PlayableCharacter).make_ai_controller())


func _run(b: String, me: PlayableCharacter) -> bool:
	if b == "task":
		return _task(me)
	return super(b, me)


func _task(me: PlayableCharacter) -> bool:
	if not plan.is_valid():
		return false
	var r: Dictionary = plan.call(me)
	if bool(r.get("hold", false)):
		intent = "task"
		return true
	if not r.has("to"):
		return false
	var to: Vector2 = (r["to"] as Vector2) - me.global_position
	_move = to.normalized() if to.length() > float(r.get("near", 8.0)) else Vector2.ZERO
	if bool(r.get("dash", false)) and to.length() > DASH_FAR and _dash_cd <= 0.0:
		_pressed[&"dash"] = true
		_dash_cd = 0.8
	intent = "task"
	return true
