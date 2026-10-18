class_name AfterHouse
extends Node2D
## 蓝色小屋（战后，七日赎罪）的导演，楼上楼下共用：
##   楼下（floor_06_after_house，粉色公主的房间）：进门时演这里自动演的事件（夜里的事件，AfterStory.enter_house）；目标提示 ObjectiveMarker；
##     第 1 天夜里被挠醒之后、梦游还没结束：地上出现三处可以调查的发光手印（CLUES，对话 after_house_objects#clue_*）。
##   楼上（floor_06_after_house_up，蓝色公主的房间）：蓝色公主（节点改名 AfterBlue）白天站着，夜里躺在床上睡；
##     第 1 天夜里三处手印都看过了 → 梦游的结尾（AfterStory.run_upstairs）。
## 图例：X = f6afterhouse

const CLUES := {"clue_bed": [5, 5.6], "clue_tea": [9, 8.6], "clue_stairs": [15.5, 3.8]}
const BLUE_BED := [4, 4.25]

var _clue_nodes: Array[Node] = []
var _lv: Node
var marker: ObjectiveMarker


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	if lv == null:
		return
	_lv = lv
	marker = ObjectiveMarker.new()
	marker.name = "Objective"
	lv.get_node("Entities").add_child(marker)
	GameState.flag_changed.connect(_on_flag_changed)
	_refresh_objective()
	if str(lv.get("floor_id")) == AfterStory.HOUSE_UP:
		_setup_up(lv)
		await AfterStory.run_upstairs()
		return
	_refresh_clues(lv)
	await AfterStory.enter_house()
	_refresh_clues(lv)


func _on_flag_changed(flag: String) -> void:
	if flag == AfterStory.NIGHT_BUSY and is_instance_valid(_lv):
		_refresh_clues(_lv)
	if flag == DayClock.TICK or flag.begins_with("after_"):
		_refresh_objective.call_deferred()


func _refresh_objective() -> void:
	if is_instance_valid(marker) and is_instance_valid(_lv):
		marker.set_target(AfterStory.objective(str(_lv.get("floor_id"))))


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


## 梦游进行中（after_night_busy）：摆出三处手印；结束了就收掉。
func _refresh_clues(lv: Node) -> void:
	var want := GameState.has_flag(AfterStory.NIGHT_BUSY) and DayClock.event() == "d1_sleepwalk"
	if not want:
		for n in _clue_nodes:
			if is_instance_valid(n):
				n.queue_free()
		_clue_nodes.clear()
		return
	if not _clue_nodes.is_empty():
		return
	var ents: Node = lv.get_node_or_null("Entities")
	for id in CLUES:
		var pr: Node2D = load("res://scenes/objects/prop.tscn").instantiate()
		pr.set("kind", "handprint")
		pr.set("action", "talk:floor_06/after_house_objects#" + id)
		pr.name = "Clue_" + id
		(ents if ents else lv).add_child(pr)
		pr.global_position = Cutscene.cell_to_world(CLUES[id])
		_clue_nodes.append(pr)


func _setup_up(lv: Node) -> void:
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		if c.is_controlled():
			continue
		c.name = "AfterBlue"
		if GameState.has_flag("night"):
			Cutscene._lie(c, {"at": BLUE_BED, "sleep": true})
