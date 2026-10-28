class_name QuestRunner
extends Node2D
## 骑士篇支线玩法节点的底子（KnightQuests.make_runner 造、AfterRoom 摆进 Entities，节点名 Quest_<id>）：
##   quest_id、q（这个支线的数据）、pink / blue、_lv；子类重写 setup()（摆东西）、静态 runs_on(图, 阶段)（这一段在不在这张图上）。
##   advance()：这一段做完（KnightQuests.advance）。阶段变了：下一段还在这张图上就收掉摆的东西重新 setup()，不在就自己收走。
##   离开场景树时摆的东西（spawned）跟着收走；子类要还原的状态写在 cleanup()。
##   玩的时候的闲聊（stages[].chat：[["p" / "b", 台词], …]）：每 CHAT_EVERY 秒按顺序冒一句头顶气泡（p 粉色、b 蓝色，那位不在就跳过），
##     说到哪一句记在 vars.kq_chat_<id>_<段>（出去再进来接着说，说完就不说了）。

var quest_id := ""
var q := {}
var pink: PlayableCharacter
var blue: PlayableCharacter
var spawned: Array = []
var _lv: Node
var _stage := -1
var _chat_t := 0.0

const CHAT_EVERY := 11.0
const CHAT_FIRST := 4.0


func _ready() -> void:
	# Replay_<id>：做完以后再玩一次（不推进支线，AfterRoom 也不会当成别的支线收走）
	quest_id = str(name).trim_prefix("Quest_").trim_prefix("Replay_")
	q = KnightQuests.info(quest_id)
	_lv = get_parent().get_parent()
	for c in get_tree().get_nodes_in_group("player_chars"):
		if c is BluePrincess:
			blue = c
		elif not c is BonfireHost:
			pink = c
	_stage = stage()
	_chat_t = CHAT_FIRST
	GameState.flag_changed.connect(_on_flag)
	setup()
	var tk := Timer.new()
	tk.wait_time = 0.5
	tk.timeout.connect(_chat_tick.bind(0.5))
	add_child(tk)
	tk.start()


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
	# 下一段换了玩法节点（段落的 runner）或者不在这张图上：自己收走，让导演按下一段重新摆
	if KnightQuests.stage_script(quest_id) == get_script() and KnightQuests.runs_on(get_script(), quest_id, str(_lv.get("floor_id"))):
		setup()
	else:
		name = String(name) + "_done"
		queue_free()
		_resync.call_deferred()


## 这个节点还是不是现在这一段的玩法（做完 / 换段以后，收走之前的这一小会儿不要再触发东西）
func live() -> bool:
	return KnightQuests.is_active(quest_id) and stage() == _stage


func _resync() -> void:
	if is_instance_valid(_lv):
		for n in _lv.find_children("*", "", true, false):
			if n.has_method("refresh_objective"):
				n.call("refresh_objective")
				return


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


## 玩的时候的闲聊：下一句（没有了返回 false）
func chat_next() -> bool:
	var lines: Array = KnightQuests.stage_info(quest_id).get("chat", [])
	var key := "kq_chat_%s_%d" % [quest_id, stage()]
	var i := int(GameState.vars.get(key, 0))
	while i < lines.size():
		var who: Node2D = pink if str(lines[i][0]) == "p" else blue
		i += 1
		GameState.vars[key] = i
		# 蓝色公主要在身边（没跟着走、离得远就跳过她的话）
		if is_instance_valid(who) and who.is_inside_tree() and who.visible and (who == pink or not is_instance_valid(pink)
				or who.global_position.distance_to(pink.global_position) <= 120.0):
			SpeechBubble.say(who, str(lines[i - 1][1]), 30.0, 3.2)
			return true
	return false


func _chat_tick(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene:
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = CHAT_EVERY
		chat_next()


func say(pool: Variant, time := 2.6) -> void:
	var arr: Array = pool if pool is Array else [pool]
	if not arr.is_empty():
		GameState.princess_reacted.emit(str(arr.pick_random()), time)


## 这一段做完
func advance() -> void:
	await KnightQuests.advance(quest_id)
