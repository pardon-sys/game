class_name QuestRunner
extends Node2D
## 骑士篇支线玩法节点的底子（KnightQuests.make_runner 造、AfterRoom 摆进 Entities，节点名 Quest_<id>）：
##   quest_id、q（这个支线的数据）、pink / blue、_lv；子类重写 setup()（摆东西）、静态 runs_on(图, 阶段)（这一段在不在这张图上）。
##   advance()：这一段做完（KnightQuests.advance）。阶段变了：下一段还在这张图上就收掉摆的东西重新 setup()，不在就自己收走。
##   离开场景树时摆的东西（spawned）跟着收走；子类要还原的状态写在 cleanup()。

var quest_id := ""
var q := {}
var pink: PlayableCharacter
var blue: PlayableCharacter
var spawned: Array = []
var _lv: Node
var _stage := -1


func _ready() -> void:
	quest_id = str(name).trim_prefix("Quest_")
	q = KnightQuests.info(quest_id)
	_lv = get_parent().get_parent()
	for c in get_tree().get_nodes_in_group("player_chars"):
		if c is BluePrincess:
			blue = c
		elif not c is BonfireHost:
			pink = c
	_stage = stage()
	GameState.flag_changed.connect(_on_flag)
	setup()


func _exit_tree() -> void:
	_clear()
	cleanup()


func _clear() -> void:
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()


func _on_flag(flag: String) -> void:
	if flag != KnightStory.STEP_CHANGED or stage() == _stage or not KnightQuests.is_active(quest_id):
		return
	_stage = stage()
	_clear()
	if bool(get_script().call("runs_on", str(_lv.get("floor_id")), _stage)):
		setup()
	else:
		queue_free()


## 子类：摆这一段的东西
func setup() -> void:
	pass


## 子类：节点收走时要还原的东西
func cleanup() -> void:
	pass


func stage() -> int:
	return KnightQuests.stage(quest_id)


func cell(c: Array) -> Vector2:
	return Cutscene.cell_to_world(Vector2(float(c[0]), float(c[1])))


## 摆到地图的实体层（跟着这个节点一起收走）
func put(n: Node, at: Vector2) -> Node:
	get_parent().add_child(n)
	(n as Node2D).global_position = at
	spawned.append(n)
	return n


func say(pool: Variant, time := 2.6) -> void:
	var arr: Array = pool if pool is Array else [pool]
	if not arr.is_empty():
		GameState.princess_reacted.emit(str(arr.pick_random()), time)


## 这一段做完
func advance() -> void:
	await KnightQuests.advance(quest_id)
