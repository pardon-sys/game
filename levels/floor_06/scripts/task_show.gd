class_name TaskShow
extends Node2D
## 「小游戏画面」型的弥补任务的玩法节点底子（AfterStory.run_task 摆进来，发 finished(ok)）：等对话空下来 → make_show() 开演 → await play() 的结果当成功 / 失败。
## 子类：TaskMice（逃跑的痒痒鼠）、TaskLantern（笑声灯笼）。

signal finished(ok: bool)

var aborted := false
var started := false
var show: Node
var _emitted := false


static func reset_items() -> void:
	pass


static func status_text() -> String:
	return ""


func make_show() -> Node:
	return null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await TrainingDB.wait_dialogue_free()
	started = true
	show = make_show()
	if show == null:
		_emit(true)
		return
	get_tree().root.add_child(show)
	var ok: Variant = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	if ok == null:
		# 小游戏里按 Esc 退出：任务算中断（AfterStory 清掉标记，走回触发点能重新开始），不演失败
		aborted = true
		_emit(false)
		queue_free()
		return
	_emit(bool(ok))


func _exit_tree() -> void:
	if is_instance_valid(show):
		show.queue_free()


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)
