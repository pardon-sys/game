class_name AfterRoom
extends Node2D
## 七日赎罪的小场景导演（药剂师工房 floor_06_after_pharmacy、城门外的战场 floor_06_after_field……）：
##   目标提示（ObjectiveMarker，AfterStory.objective）、走进目标圈演那个事件（AfterStory.trigger）、进图自动演的事件（AfterStory.run_pending）。
##   跟着的蓝色公主（节点改名 AfterBlue）：这张图可以换人（[level] 没写 no_switch 时按 C）。
## 图例：X = f6afterroom

const PARTNER := "floor_06/after_partner"

var marker: ObjectiveMarker
var _objective := {}
var _floor := ""


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	if lv == null:
		return
	_floor = str(lv.get("floor_id"))
	# 镇民（对话文件 floor_06/after_*）的节点改名成对话文件名（过场里用）
	for n in lv.find_children("*", "Resident", true, false):
		var r := n as Resident
		if r.dialogue.begins_with("floor_06/after_"):
			r.name = r.dialogue.get_file()
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		if c is BonfireHost:
			if c.dialogue.begins_with("floor_06/after_"): c.name = c.dialogue.get_file()
			continue
		c.follow = true
		c.partner_talk = PARTNER
		if not c.is_controlled():
			c.start_following(PARTNER)
			c.name = "AfterBlue"
	# 没写 no_switch 的图：C 键随时换人（拆攻城车、修图腾柱……）
	if not bool(lv.get("no_switch")):
		lv.set_meta(&"free_switch", true)
		Duo._bind_tab()
	marker = ObjectiveMarker.new()
	marker.name = "Objective"
	marker.extra = AfterStory.status_text
	lv.get_node("Entities").add_child(marker)
	GameState.flag_changed.connect(_on_flag_changed)
	AfterStory.recover_task()
	refresh_objective()
	await AfterStory.run_pending(_floor)
	refresh_objective()


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _on_flag_changed(flag: String) -> void:
	if flag == DayClock.TICK or flag.begins_with("after_"):
		refresh_objective.call_deferred()


func refresh_objective() -> void:
	if is_instance_valid(marker):
		_objective = AfterStory.objective(_floor)
		marker.set_target(_objective)


func _process(_delta: float) -> void:
	if not bool(_objective.get("trigger", false)) or AfterStory.running or DayClock.passing:
		return
	if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(GameState.player):
		return
	var at: Vector2 = Cutscene.cell_to_world(_objective["cell"])
	if GameState.player.global_position.distance_to(at) <= float(_objective.get("radius", 1.0)) * 16.0:
		_objective = {}
		await AfterStory.trigger(_floor)
		refresh_objective()
