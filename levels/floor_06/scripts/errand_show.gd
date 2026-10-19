extends Node2D
## 委托的玩法节点（「小游戏画面」型：扶梯子、足底按摩、篝火舞会排练）：走到委托的地点（errands.json 的 target 格）
## → 开演小游戏（show 脚本：TrainingStage 的子类，await play() 返回做没做完）→ 做完 AfterErrands.complete。
## 小游戏里摔下来 / 踢中几次会自己重来；中途 Esc 不能退出。

const NEAR := 20.0

var errand_id := ""
var _started := false


func _process(_delta: float) -> void:
	if _started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(GameState.player):
		return
	var info := AfterErrands.info(errand_id)
	if not info.has("target") or not info.has("show"):
		return
	if GameState.player.global_position.distance_to(Cutscene.cell_to_world(info["target"])) > NEAR:
		return
	_started = true
	var show: Node = load(str(info["show"])).new()
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	show.queue_free()
	if ok:
		AfterErrands.complete(errand_id)
	else:
		AfterErrands.fail(errand_id, "委托没做完……再找委托人说一次就能重来。")
	queue_free()
