extends Node2D
## 委托的玩法节点（「小游戏画面」型：扶梯子、足底按摩、篝火舞会排练）：走到委托的地点（errands.json 的 target 格）
## → 开演小游戏（show 脚本：TrainingStage 的子类，await play() 返回做没做完）→ 做完 AfterErrands.complete。
## 失败恢复／Esc规则由show决定；城门穿链允许暂存，原梯子等仍按原规则。

const NEAR := 20.0

var errand_id := ""
var _started := false
var _show: Node
var _source: Node
var _settled := false


func _process(_delta: float) -> void:
	if _started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(GameState.player):
		return
	var info := AfterErrands.info(errand_id)
	if not info.has("target") or not info.has("show"):
		return
	if GameState.player.global_position.distance_to(Cutscene.cell_to_world(info["target"])) > NEAR:
		return
	if AfterStory.running or DayClock.passing or CG.is_busy(): return
	var main := get_tree().get_first_node_in_group("main")
	_source = main.get("level") if main else null
	_started = true
	_show = load(str(info["show"])).new()
	get_tree().root.add_child(_show)
	var ok: bool = await _show.play()
	if is_instance_valid(_show): _show.queue_free()
	if not is_inside_tree() or not is_instance_valid(_source) or not _source.is_inside_tree() or main.get("level") != _source: return
	_settled = true
	if ok:
		AfterErrands.complete(errand_id)
	else:
		AfterErrands.fail(errand_id, "委托没做完……再找委托人说一次就能重来。")
	queue_free()


## 演出挂在root上，必须跟随来源委托取消，不能留到下一张地图结算。
func _exit_tree() -> void:
	if is_instance_valid(_show):
		if _show.has_method("cancel"): _show.cancel()
		_show.queue_free()
	if _started and not _settled and GameState.dialogue_holds <= 0 and not Dialogue.is_active() and not Dialogue.runner.is_running() and not GameState.in_cutscene:
		GameState.in_dialogue = false
