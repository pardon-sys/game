class_name StoryDirector
extends Node
## 剧情调度（main.gd 创建，挂在主场景下）：监听「人物对话结束」「换地图」，按剧情标记推进各层的剧情脚本（F6Story……）。
## 跨地图的过场序列：run_sequence([{level, spawn, cutscene}, …])——每一段先换到那张地图（站到到达点），再播那段过场。

static var instance: StoryDirector

var main: Node


func _ready() -> void:
	instance = self
	main = get_parent()
	Dialogue.runner.talk_finished.connect(_on_talk_finished)
	Cutscene.finished.connect(_on_cutscene_finished)
	if main.has_signal("level_changed"):
		main.level_changed.connect(_on_level_changed)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _on_talk_finished(file: String) -> void:
	F6Story.on_talk_finished(file)


func _on_cutscene_finished(id: String) -> void:
	F6Story.on_cutscene_finished(id)


func _on_level_changed(level: Node) -> void:
	await get_tree().process_frame
	if is_instance_valid(level):
		F6Story.on_level_entered(str(level.get("floor_id")))


## 跨地图的过场序列。level 是楼层 id（和当前地图一样就不换），spawn 是到达点 id，cutscene 是过场 id（data/cutscenes/）。
## 每一段之前等对话 / 过场都结束。keep_state = true：不把当前角色的状态带过去（换主角时用）。
func run_sequence(segments: Array) -> void:
	for seg in segments:
		await TrainingDB.wait_dialogue_free()
		var lid := str(seg.get("level", ""))
		var lv: Node = main.get("level")
		if lid != "" and (lv == null or str(lv.get("floor_id")) != lid):
			GameState.pending_spawn = str(seg.get("spawn", ""))
			await main.change_level(Floors.scene(lid), bool(seg.get("keep_state", false)))
			await get_tree().create_timer(0.3).timeout
		if str(seg.get("cutscene", "")) != "":
			await Cutscene.play(str(seg["cutscene"]))
		if seg.has("flag"):
			GameState.set_flag(str(seg["flag"]))
