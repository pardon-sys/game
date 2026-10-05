class_name F6Story
extends RefCounted
## 第六层后续剧情（StoryDirector 调用）：
##   1. 蓝色公主对话里 5 个话题都问过 → 她带主角逛小镇（集市层 → 营地层 → 矿道层 → 回集市层她的小屋门口）→ 进小屋（楼下是主角的房间）
##      → 夜晚降临（剧情标记 night，小屋的门锁住）→ 自由活动：家具都能调查（floor_06/house_objects）、骑马刷凳的小剧场、
##      蓝色公主下楼让她小声点、拿到神秘的钥匙（f6_key）→ 床：Sleep 睡到第二天 → 早上「我要逃离这里」（f6_escape）
##   2. f6_escape 之后矿道层变成潜入模式（StealthDirector）；被抓 → 营地地牢惩罚 → 蓝色公主领回小屋 → 睡一觉再来（vars.f6_caught 次数）
##   3. 粉色公主走进第七层（过场 f7_pink_run）→ 主角换成蓝色公主（blue_is_hero）→ 她在小屋楼上醒来（f7_blue_wake）
##      → 出门时和保卫队队长争吵（f7_blue_argue）→ 去第七层（f7_blue_arrive，塔底有唯一的存档点）
##      → 过场放完、开始自由活动时弹出蓝色公主的魔法介绍板（只一次）
## 剧情标记：f6_tour_started / f6_touring（参观中）/ f6_house_open / night / f6_key / f6_escape / blue_is_hero / f7_argue_done。

const BLUE_FILE := "floor_06/blue_princess"
const TOPICS := 5

static var touring := false


## 蓝色公主的 5 个话题都问过了。
static func topics_done() -> bool:
	for i in TOPICS:
		if not GameState.has_flag("dlg_%s_hub_%d" % [BLUE_FILE, i]):
			return false
	return true


static func on_talk_finished(file: String) -> void:
	if file == BLUE_FILE and topics_done() and not GameState.has_flag("f6_tour_started"):
		start_tour()


static func on_level_entered(floor_id: String) -> void:
	# 蓝色公主到了第七层：塔底的过场放完、开始自由活动时，弹出一次她的魔法介绍板（介绍板自己等过场 / 换关卡都结束）
	if floor_id == "floor_07" and GameState.has_flag("blue_is_hero"):
		GameState.show_blue_intro()
	# 蓝色公主第一次走出小屋：和队长争吵，然后去第七层
	if floor_id == "floor_06_upper" and GameState.has_flag("blue_is_hero") and not GameState.has_flag("f7_argue_done") and StoryDirector.instance:
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play("f7_blue_argue")
		GameState.set_flag("f7_argue_done")
		await StoryDirector.instance.run_sequence([{"level": "floor_07", "spawn": "blue_start", "cutscene": "f7_blue_arrive"}])


static func on_cutscene_finished(id: String) -> void:
	if id == "f7_pink_run" and not GameState.has_flag("blue_is_hero"):
		start_blue_arc()


## 主角换成蓝色公主：从她房间（小屋楼上）开始，状态不带粉色公主的。
static func start_blue_arc() -> void:
	if StoryDirector.instance == null:
		return
	GameState.set_flag("blue_is_hero")
	GameState.set_flag("night", false)
	GameState.carried_player_state = {}
	await StoryDirector.instance.run_sequence([{"level": "floor_06_house_up", "spawn": "start", "keep_state": true}])


## 参观小镇：跨地图的过场序列，最后进小屋、天黑。
static func start_tour() -> void:
	if touring or StoryDirector.instance == null:
		return
	touring = true
	GameState.set_flag("f6_tour_started")
	GameState.set_flag("f6_touring")
	await StoryDirector.instance.run_sequence([
		{"cutscene": "f6_tour_upper"},
		{"level": "floor_06_camp", "spawn": "from_upper", "cutscene": "f6_tour_camp"},
		{"level": "floor_06_mine", "spawn": "from_camp", "cutscene": "f6_tour_mine"},
		{"level": "floor_06_upper", "spawn": "from_camp", "cutscene": "f6_tour_home", "flag": "f6_house_open"},
		{"level": "floor_06_house", "spawn": "from_upper", "cutscene": "f6_house_enter"},
	])
	GameState.set_flag("f6_touring", false)
	touring = false


## 潜入时被发现（StealthDirector on_caught = f6）：士兵围上来 → 营地地牢的惩罚小剧场（按被抓次数，3 种）
## → 蓝色公主把她领回小屋 → 睡一觉 → 第二天早上可以再试。
## 第 4 次起：统一播 f6_caught_again（象征性地挠一下），直接在矿道入口重新开始，不回小屋、不睡觉。
static func on_caught() -> void:
	if StoryDirector.instance == null:
		return
	var n := int(GameState.vars.get("f6_caught", 0)) + 1
	GameState.vars["f6_caught"] = n
	await Cutscene.play_data("f6_caught_grab", grab_cutscene())
	if n > 3:
		await Cutscene.play("f6_caught_again")
		retry_in_mine()
		return
	await StoryDirector.instance.run_sequence([
		{"level": "floor_06_prison", "spawn": "from_camp", "cutscene": "f6_caught_prison_%d" % mini(n, 3)},
		{"level": "floor_06_house", "spawn": "from_upper", "cutscene": "f6_caught_home"},
	])
	await Sleep.sleep(morning_cutscene())


## 被抓第 4 次起：回到矿道入口（from_camp），潜入状态和巡逻全部重置。
static func retry_in_mine() -> void:
	# 抓人过场里生成的士兵（cg1 / cg2）不留在矿道里
	for id in ["cg1", "cg2"]:
		var n: Node = Cutscene.spawned.get(id)
		if is_instance_valid(n):
			n.queue_free()
		Cutscene.spawned.erase(id)
	var p := GameState.player
	var d := StealthDirector.current
	if d:
		d.reset()
		for sp in d.get_tree().get_nodes_in_group("spawn_point"):
			if str(sp.get("id")) == "from_camp" and d.is_ancestor_of_level(sp) and is_instance_valid(p):
				p.global_position = (sp as Node2D).global_position
	if is_instance_valid(p):
		p.revive()
		p.set_invulnerable(1.0, true)
		if p.camera:
			p.camera.reset_smoothing()
	Cutscene.curtain_clear()
	GameState.notify("回到了矿道入口。……这次小心点。")


## 被发现的那一刻：两个士兵从左右围上来（按公主现在站的格子现场生成）。
static func grab_cutscene() -> Dictionary:
	var c := [0, 0]
	if is_instance_valid(GameState.player):
		var p := GameState.player.global_position
		c = [floori(p.x / 16.0), floori((p.y - 12.0) / 16.0)]
	return {"name": "潜入失败", "letterbox": true, "skippable": false, "steps": [
		{"actions": [{"do": "spawn", "id": "cg1", "kind": "npc:guard", "at": [c[0] - 3, c[1]], "dir": "right"},
			{"do": "spawn", "id": "cg2", "kind": "npc:guard", "at": [c[0] + 3, c[1]], "dir": "left"},
			{"do": "bubble", "who": "princess", "kind": "surprise"}, {"do": "sfx", "sound": "locked"}], "wait": 0.3},
		{"actions": [{"do": "move", "who": "cg1", "to": [c[0] - 1, c[1]], "speed": 70}, {"do": "move", "who": "cg2", "to": [c[0] + 1, c[1]], "speed": 70}]},
		{"speaker": "保卫队员", "text": "找到你了！这么早，跑到矿道深处来干什么？"},
		{"speaker": "公主", "text": "糟、糟了……！", "emotion": "surprise"},
		{"speaker": "保卫队员", "text": "跟我们回营地。队长会好好问你的。", "actions": [{"do": "fade_out", "time": 0.8}]},
	]}


## 睡醒后播哪段早上的过场：被抓过之后是「再试一次」，第一次是「我要逃离这里」。
static func morning_cutscene() -> String:
	if GameState.has_flag("f6_escape") and int(GameState.vars.get("f6_caught", 0)) > 0:
		return "f6_morning_retry"
	return "f6_morning_escape"
